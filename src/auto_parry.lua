-- Auto Parry: predicts an attack's impact from animation markers, then opens
-- exactly one short block session per predicted impact.
--
-- Mechanics measured in-game (see the notes at the bottom of this file):
--   * a Block Input grants State_Parrying after roughly the round-trip latency,
--   * the granted parry lives about PARRY_WINDOW seconds and survives End Block,
--   * ParryCooldown then gates the next grant,
--   * repeating Block Input while already blocking cannot create a second parry.
-- Marker timings are candidates, not proof that an attack is parryable.
--
-- Lead derivation (why the press is centred where it is):
--   * the animation track is delayed by the inbound leg, so an impact authored
--     at marker time m happens, on this client's clock, at trackStart+m exactly
--     (the inbound delay cancels out);
--   * a press sent at local time S opens the parry at S+outbound;
--   * therefore the press must land outbound..outbound+PARRY_WINDOW before the
--     impact, i.e. centred at outbound+PARRY_WINDOW/2;
--   * `outbound` is measured exactly, and without any clock-sync assumption, by
--     reading StateEnd_Parrying (server clock) and StateDuration_Parrying on the
--     grant: grant_time = StateEnd - StateDuration, so outbound = grant_time -
--     GetServerTimeNow() sampled at send. The observed grant latency is longer
--     (it also carries the inbound leg) and is only used to keep the block
--     session open long enough to see the grant.
-- Marker->impact equality is measured, not assumed: passive observation of
-- other fights put the residual at +0.002s median (tests/data).
local G=getgenv()
if G.VeyraParry then G.VeyraParry.stop() end
local profiles=loadstring(readfile("Veyra/src/parry_profiles.lua"),"parry_profiles.lua")()
local timing=loadstring(readfile("Veyra/src/parry_math.lua"),"parry_math.lua")()
local Players=game:GetService("Players")
local RS=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local storage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer

local wasAttacking=false
local resumeAt=0

local PARRY_WINDOW=0.25   -- how long a granted parry stays active
local SESSION_MIN=0.16    -- keep blocking at least this long so the grant lands
local PULSE_DEADLINE=0.55 -- hard cap on one block session
local PRESS_RATE=0.35     -- minimum spacing between sessions
local ATTACK_RELEASE_HORIZON=1.2 -- release a held attack this early before an inbound impact

local profiles_=profiles
local profileCount=0
for _ in pairs(profiles_) do profileCount+=1 end

local state={enabled=false,alive=true,status="Parry off",profiles=profileCount,
 range=14,leadOffset=0,lead=0.1,grantLag=0.15,attempts=0,grants=0,confirmed=0,damageEvents=0,
 unknown=0,missed=0,covered=0,gated=0,learned=0,calibrated=false,bias={},hitResiduals={},
 unparryable={},unparryableSkips=0,cooldownWait=0,
 unobservedGrants=0,successByAsset={},
 unknownAssets={},log={}}
G.VeyraParry=state

local animators,watches,pending={},{},{}
local discoveryAdded,discoveryRemoved
local seen=setmetatable({},{__mode="k"})
local worker,packet,manager,character,healthConnection,attributeConnection
local session=nil
local lastSent=-math.huge
local nextScan=0
-- outbound send->grant (scheduling lead); observed grant lag (session length)
local lead=0.1
local grantLag=0.15
local calibrateAt,pendingGate
local activeAttempt
local serverAnimations={}
local suitOnly={} -- Hit/Blocks/Parrys reaction animations are not attacks

local animations=storage:FindFirstChild("Animations")
local function index(folder,table_)
 if not folder then return end
 for _,animation in ipairs(folder:GetDescendants()) do
  if animation:IsA("Animation") then
   local id=animation.AnimationId:match("%d+")
   if id then table_[id]=true end
  end
 end
end
if animations then
 index(animations:FindFirstChild("Server"),serverAnimations)
 for _,name in ipairs({"Hit","Blocks","Parrys"}) do index(animations:FindFirstChild(name),suitOnly) end
end

local function log(message)
 if #state.log>=120 then table.remove(state.log,1) end
 table.insert(state.log,string.format("%.3f %s",os.clock(),message))
end
local function send(action)
 if not packet then return false end
 local ok,err=pcall(function() packet.send({Action=action}) end)
 if not ok then log("send "..action..": "..tostring(err)) return false end
 return true
end
local function endSession(reason)
 if not session then return end
 send("End Block")
 if activeAttempt then activeAttempt.ended=os.clock() end
 if reason=="timeout" and not session.granted then
  if not session.calibration then state.unobservedGrants+=1 end
  log("no grant observed within session")
 end
 session=nil
end
local function clearCharacter()
 endSession("reset")
 table.clear(pending)
 table.clear(seen)
 activeAttempt=nil
 if healthConnection then healthConnection:Disconnect() healthConnection=nil end
 if attributeConnection then attributeConnection:Disconnect() attributeConnection=nil end
 wasAttacking=false
 resumeAt=0
 character,manager=nil,nil
end
local function bindCharacter(c)
 clearCharacter()
 character=c
 if not c then return end
 local ok,result=pcall(function() return require(storage.Modules.StateManager).require(c) end)
 if ok then manager=result else log("state manager: "..tostring(result)) end
 local humanoid=c:FindFirstChildOfClass("Humanoid")
 if humanoid then
  local previous=humanoid.Health
  healthConnection=humanoid.HealthChanged:Connect(function(value)
   if state.enabled and value<previous then
    state.damageEvents+=1
    local now=os.clock()
    local note="with no attempt"
    if activeAttempt then
     note=string.format("after %s (%.2fs)",activeAttempt.name,now-activeAttempt.time)
     if activeAttempt.impactAt and activeAttempt.asset then
       -- Health replication supplies neither the attacker nor the impact time.
       -- Record residuals for inspection, not automatic timing calibration.
      local residual=now-activeAttempt.impactAt
      if math.abs(residual)<=0.4 then
       local granted=activeAttempt.granted==true
        -- Proximity to the predicted impact is not proof of damage attribution
        -- or of overlap with the actual server window. Keep this diagnostic
        -- count, but do not blacklist an asset or learn timing from it.
       if granted and timing.outcome(residual,PARRY_WINDOW,-0.02)=="inside" then
        local strikes=(state.unparryable[activeAttempt.asset] or 0)+1
        state.unparryable[activeAttempt.asset]=strikes
        table.insert(state.hitResiduals,string.format("%s %+.3f near prediction -> ambiguous (%d)",
         activeAttempt.name,residual,strikes))
        note=note..string.format(" residual %+.3fs near prediction (ambiguous damage)",residual)
       else
         table.insert(state.hitResiduals,string.format("%s %+.3f unattributed damage",
          activeAttempt.name,residual))
         note=note..string.format(" residual %+.3fs (unattributed)",residual)
       end
       while #state.hitResiduals>20 do table.remove(state.hitResiduals,1) end
      end
     end
    end
    log(string.format("damage %.1f %s",previous-value,note))
   end
   previous=value
   if value<=0 then endSession("dead") table.clear(pending) state.status="Parry: waiting for respawn" end
  end)
 end
 attributeConnection=c.AttributeChanged:Connect(function(name)
  if not state.enabled or c:GetAttribute(name)~=true then return end
  if name=="State_Parrying" then
   state.grants+=1
   if session and not session.granted then
    session.granted=true
    if activeAttempt and not session.calibration then activeAttempt.granted=true end
    local observed=os.clock()-session.sentAt
    if observed>0 and observed<1 then
     -- Observed lag: send -> attribute visible. Ends the block session.
     grantLag=grantLag*0.75+observed*0.25
     state.grantLag=grantLag
    end
    -- Exact send->grant lag in server time, free of clock-offset error.
    local endAt=c:GetAttribute("StateEnd_Parrying")
    local duration=c:GetAttribute("StateDuration_Parrying")
    if endAt and duration and session.sendServer then
     local outbound=(endAt-duration)-session.sendServer
     if outbound>-0.05 and outbound<0.4 then
      outbound=math.max(outbound,0)
      lead=math.clamp(lead*0.75+outbound*0.25,0.01,0.3)
      state.lead=lead state.learned+=1 state.calibrated=true
     end
    end
    log(string.format("grant in %.3fs (lead %.3f)",observed,lead))
    endSession("grant")
   else
    log("grant without an active session")
   end
  elseif name=="State_ParriedAttack" then
   state.confirmed+=1
   if activeAttempt and not activeAttempt.confirmed then
    activeAttempt.confirmed=true
    if activeAttempt.asset then
     local id=activeAttempt.asset
     state.successByAsset[id]=(state.successByAsset[id] or 0)+1
    end
   end
   log("CONFIRMED deflection"..(activeAttempt and (" near "..activeAttempt.name) or ""))
   endSession("parried")
  end
 end)
end

local function gateReason(c)
 for _,name in ipairs({"Attacking","ParryCooldown","Parrying","Blocking","SwordBlocking",
  "Stunned","SkillActive","Dodging","BlockBroken","Ragdoll","Occupied","Knocked","Downed",
  -- A successful parry leaves a ~0.5s APF grace where further hits are already
  -- negated, so pressing again only buys the ~1s lockout.
  "APF","Parried","ParriedAttack"}) do
  if c:GetAttribute("State_"..name)==true then return name end
 end
 return "CanParry=false"
end
local function ready(ignoreCooldown)
 local c=player.Character
 local h=c and c:FindFirstChildOfClass("Humanoid")
 if not h or h.Health<=0 then return nil,"waiting for respawn" end
 local root=c:FindFirstChild("HumanoidRootPart")
 if not root then return nil,"waiting for character" end
 local tool=c:FindFirstChildOfClass("Tool")
 if not tool or not (tool:GetAttribute("Sword") or tool:GetAttribute("Combat")) then return nil,"equip a combat weapon" end
 if UIS:GetFocusedTextBox() then return nil,"typing" end
 local bind=player:FindFirstChild("Binds")
 local block=bind and bind:FindFirstChild("Block")
 local key=block and tostring(block.Value) or "F"
 local code=Enum.KeyCode[key:match("[^.]+$") or "F"]
 if code and UIS:IsKeyDown(code) then return nil,"manual block" end
 if not manager then return nil,"state manager unavailable" end
 -- Damage is discarded inside a safezone, so a press there only costs the lockout.
 if h:GetAttribute("InSafezone")==true then return nil,"safezone" end
  if not manager:CanParry() then
   -- A cooldown timestamp may relax only the cooldown gate. Match the other
   -- CanParry predicates rather than trusting the first diagnostic reason.
   if not ignoreCooldown or not manager:HasState("ParryCooldown")
    or manager:IsBlocking() or manager:IsIncapacitated() or manager:IsDodging()
    or manager:IsParrying() or manager:IsUsingSkill() or manager:IsFlying()
    or manager:HasAnyState("Occupied","Attacking") then
    return nil,gateReason(c)
   end
  end
 -- Post-parry grace: hits are already negated for ~APF seconds.
 if c:GetAttribute("State_APF")==true then return nil,"APF grace" end
 return root
end
-- The replicated ParryCooldown state clears one inbound leg late, so a press
-- that waits for it lands ~2*outbound after the server is actually ready. The
-- server also publishes the cooldown's end time, which lets us aim the press at
-- the real expiry instead of at the stale attribute.
local function cooldownReadyAt(c,now)
 local endAt=c:GetAttribute("StateEnd_ParryCooldown")
 if type(endAt)~="number" then return -math.huge end
 local ok,server=pcall(function() return workspace:GetServerTimeNow() end)
 if not ok or type(server)~="number" then return -math.huge end
 return now+math.max(0,endAt-server)
end

local function observe(model,track)
 if seen[track] then return end
 seen[track]=true
 local id=track.Animation and track.Animation.AnimationId:match("%d+")
 if id and suitOnly[id] then return end
 local profile=id and profiles_[id]
 if not profile then
  if id and serverAnimations[id] and not state.unknownAssets[id] then
   state.unknownAssets[id]=true state.unknown+=1 log("unsupported melee asset "..id)
  end
  return
 end
 if track.Looped then return end
 for _,hit in ipairs(profile.hits) do
  table.insert(pending,{model=model,track=track,hit=hit,name=profile.name,id=id,
   gate=profile.gate,length=profile.length,offset=profile.offset,
   expires=os.clock()+12})
 end
 log("observed "..model.Name.." / "..profile.name..(profile.gate and " (feint-gated)" or ""))
end
local function unwatch(animator)
 local watch=watches[animator]
 if watch then watch.connection:Disconnect() watches[animator]=nil end
end
local function scan()
 local c=player.Character
 local root=c and c:FindFirstChild("HumanoidRootPart")
 local keep={}
 if root then
  for item in pairs(animators) do
   if item.Parent then
    local h=item.Parent
    local model=h and h.Parent
    local other=model and model:FindFirstChild("HumanoidRootPart")
    if h:IsA("Humanoid") and h.Health>0 and model~=c and other
     and not Players:GetPlayerFromCharacter(model)
     and (other.Position-root.Position).Magnitude<=90 then
     keep[item]=true
     if not watches[item] then
      watches[item]={connection=item.AnimationPlayed:Connect(function(track)
       -- A reused track is a new attack even if no scan saw it stop.
       seen[track]=nil
       for i=#pending,1,-1 do if pending[i].track==track then table.remove(pending,i) end end
       observe(model,track)
      end)}
     end
     for _,track in ipairs(item:GetPlayingAnimationTracks()) do observe(model,track) end
    end
   end
  end
 end
 for animator in pairs(watches) do if not keep[animator] then unwatch(animator) end end
 for track in pairs(seen) do if not track.IsPlaying then seen[track]=nil end end
end
-- An interrupted attacker's swing will never resolve, so pressing for it only
-- burns the ~1s lockout.
local INTERRUPTED={"Stunned","Parried","ParriedAttack","Ragdoll","Downed","Knocked","BlockBroken"}
local function interrupted(model)
 for _,name in ipairs(INTERRUPTED) do
  if model:GetAttribute("State_"..name)==true then return true end
 end
 return false
end
local function incoming(candidate,root,remaining)
 local model=candidate.model
 local h=model:FindFirstChildOfClass("Humanoid")
 local other=model:FindFirstChild("HumanoidRootPart")
 if not h or h.Health<=0 or not other then return false,"attacker unavailable" end
 if interrupted(model) then return false,"attacker interrupted" end
 local delta=root.Position-other.Position
 local distance=delta.Magnitude
 if distance<8 then return true end -- spin/circle attacks: facing is unreliable
 if math.abs(delta.Y)>10 then return false,"height" end
 local direction=delta.Unit
 local closing=(other.AssemblyLinearVelocity-root.AssemblyLinearVelocity):Dot(direction)
 if not timing.inRange(distance,closing,remaining,state.range) then return false,string.format("range %.1f",distance) end
 if other.CFrame.LookVector:Dot(direction)<0.25 then return false,"attacker facing away" end
 return true
end

local function startSession(now,name,calibration)
 local okServer,sendServer=pcall(function() return workspace:GetServerTimeNow() end)
 if not send("Block Input") then return false end
 lastSent=now
 -- Keep the session open long enough to observe the grant, then release.
 session={sentAt=now,sendServer=okServer and sendServer or nil,
  deadline=now+math.min(PULSE_DEADLINE,math.max(SESSION_MIN,grantLag+0.06)),
  calibration=calibration or nil}
 if not calibration then
  calibrateAt=nil
  state.attempts+=1
  activeAttempt={name=name,time=now}
  log(string.format("input %s lead=%.3f gate=%s",name,lead,
   pendingGate and string.format("%.2f",pendingGate) or "-"))
 else
  log("calibration pulse; waiting for grant")
 end
 return true
end

local function step()
 local now=os.clock()
 if player.Character~=character then bindCharacter(player.Character) end
 if session and now>=session.deadline then endSession("timeout") end
 if now>=nextScan then nextScan=now+0.4 scan() end
 local root,reason=ready()
 local available=root~=nil
 local myRoot=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local nearestInbound,nearestInboundName
 local notBefore=-math.huge
 if root then
  state.status=string.format("Parry · %d inputs · %d parried · %d hit",state.attempts,state.confirmed,state.damageEvents)
  state.blockedReason=nil
 elseif reason=="ParryCooldown" then
  -- Still schedule: aim the press at the server's real cooldown expiry so the
  -- window opens when the server accepts it, not one round trip later.
  local c=player.Character
   local r=ready(true)
   if c and r then
   local readyAt=cooldownReadyAt(c,now)
   if readyAt>-math.huge then
    root=r
    -- send -> grant is `lead`; the server must receive it after the expiry.
    notBefore=readyAt-lead+0.02
    state.cooldownWait=math.max(0,notBefore-now)
   end
  end
  state.status="Parry: "..reason
  if state.blockedReason~=reason then log("waiting: "..reason) end
  state.blockedReason=reason
 else
  state.status="Parry: "..reason
  if state.blockedReason~=reason then log("waiting: "..reason) end
  state.blockedReason=reason
 end
 if session then return end
 -- Measure this machine's real grant latency once, in place and with no
 -- attack pending, instead of trusting GetNetworkPing.
  if calibrateAt and now>=calibrateAt then
   calibrateAt=nil
   if #pending==0 and available and now-lastSent>=PRESS_RATE then
   startSession(now,nil,true)
   return
  end
 end
  -- Calibration is optional: a pending attack must never be blocked by it.
 local best,bestLatest
 for i=#pending,1,-1 do
  local candidate=pending[i]
  local track=candidate.track
  local position=track.TimePosition
  if not candidate.model:IsDescendantOf(workspace) or not track.IsPlaying or now>candidate.expires
   or timing.stale(position,candidate.hit,candidate.length,0.3) then
   table.remove(pending,i)
  else
   local remaining=(candidate.hit-position)/track.Speed
    -- Soonest inbound swing, regardless of press timing: a held attack may
    -- have to be released well before the press is due.
    if myRoot and remaining<=ATTACK_RELEASE_HORIZON then
     local ok2,inb=pcall(incoming,candidate,myRoot,remaining)
     if ok2 and inb and (not nearestInbound or remaining<nearestInbound) then
      nearestInbound=remaining
      nearestInboundName=candidate.name
     end
    end
   -- Learned per-asset shift: runtime misses override the baked measurement.
   local effective=lead+state.leadOffset+(state.bias[candidate.id] or candidate.offset or 0)
   local at,latest=timing.window(position,track.Speed,candidate.hit,effective,
    PARRY_WINDOW/2,candidate.gate)
   if latest and latest< -0.05 then
    table.remove(pending,i)
    state.missed+=1
    log("missed "..candidate.name..": "..(candidate.blocked or "no eligible frame observed"))
    elseif at and at<=0 and latest>=0 then
     local eligible,why=false,reason
     if root then eligible,why=incoming(candidate,root,remaining) end
     if not eligible then
      candidate.blocked=why or "not ready"
     elseif now<notBefore then
      candidate.blocked="cooldown arrival deadline"
     elseif now-lastSent<PRESS_RATE then
      candidate.blocked="input rate limit"
     elseif not bestLatest or latest<bestLatest then
      best,bestLatest=candidate,latest
      best.remaining=remaining
     end
   end
  end
 end
  -- Release a held attack early: the server keeps Attacking until the current
  -- swing finishes, and CanParry is false while Attacking, so M1 must drop
  -- ahead of the press deadline (which is only lead+window before impact).
  -- Never steal the button during a minigame round: mining and harvesting use
  -- the same held input, and yanking it mid-round fails the minigame for the
  -- player. The hub's other modules must not fight over one mouse button.
  local minigames=G.VeyraMinigames
  local busy=minigames~=nil and (minigames.active==true or minigames.round~=nil)
  if nearestInbound and not wasAttacking and manager and myRoot and not busy then
   local okA,isAttacking=pcall(function() return manager:HasState("Attacking") end)
   if okA and isAttacking then
    local vim=game:GetService("VirtualInputManager")
    local ok=pcall(function() vim:SendMouseButtonEvent(0,0,0,false,game,0) end)
    if ok then
     wasAttacking=true
     resumeAt=now+nearestInbound+0.25
     log(string.format("released attack for inbound %s (%.2fs)",nearestInboundName,nearestInbound))
    end
   end
  end
  -- Resume after the impact passes and nothing else is inbound, or straight
  -- away if a minigame round started and needs the button back.
  if wasAttacking and (busy or (now>=resumeAt and not nearestInbound)) then
   local vim=game:GetService("VirtualInputManager")
   pcall(function() vim:SendMouseButtonEvent(0,0,0,true,game,0) end)
   wasAttacking=false
   log("resumed attack")
  end

   if best and now-lastSent>=PRESS_RATE and now>=notBefore then
  pendingGate=best.gate
   if startSession(now,best.name,false) then
   activeAttempt.asset=best.id
   activeAttempt.offset=best.offset
   activeAttempt.impactAt=now+best.remaining
    -- Sending input is not a grant. Keep other attacks eligible for subsequent
    -- evaluation; cooldown/state gates prevent redundant presses.
   for i=#pending,1,-1 do
    local candidate=pending[i]
    if candidate==best then
     table.remove(pending,i)
    end
   end
  end
  pendingGate=nil
 end
   if activeAttempt and now-activeAttempt.time>1 then activeAttempt=nil end
 end

function state.setEnabled(on)
 if not state.alive then return false end
 on=on==true
 if on==state.enabled then return on end
 if not on then
  state.enabled=false
  if worker then worker:Disconnect() worker=nil end
  if discoveryAdded then discoveryAdded:Disconnect() discoveryAdded=nil end
  if discoveryRemoved then discoveryRemoved:Disconnect() discoveryRemoved=nil end
  table.clear(animators)
  for animator in pairs(watches) do unwatch(animator) end
  clearCharacter()
  state.status="Parry off"
  return false
 end
 local ok,result=pcall(function() return require(storage.Modules.Packets).Combat.packets.BlockInput end)
 if not ok or not result or type(result.send)~="function" then
  state.status="Parry: input unavailable" log(tostring(result)) return false
 end
 packet=result state.enabled=true nextScan=0
 calibrateAt=(not state.calibrated) and (os.clock()+0.8) or nil
 discoveryAdded=workspace.DescendantAdded:Connect(function(item)
  if item:IsA("Animator") then animators[item]=true end
 end)
 discoveryRemoved=workspace.DescendantRemoving:Connect(function(item)
  if animators[item] then animators[item]=nil unwatch(item) end
 end)
 for _,item in ipairs(workspace:GetDescendants()) do
  if item:IsA("Animator") then animators[item]=true end
 end
 bindCharacter(player.Character)
 worker=RS.Heartbeat:Connect(function()
  local success,err=pcall(step)
  if not success then
   state.setEnabled(false)
   state.status="Parry error: "..tostring(err)
   log(state.status)
  end
 end)
 return true
end
function state.stop()
 state.setEnabled(false)
 state.alive=false
 if G.VeyraParry==state then G.VeyraParry=nil end
end
function state.isWorking() return worker~=nil end
return state
