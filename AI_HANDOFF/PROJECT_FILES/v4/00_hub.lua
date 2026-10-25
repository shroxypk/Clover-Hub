-- Clover Hub v4: automation only (minigames + parry), minimal overhead.
local G = getgenv()
if G.CRLF_HubController then G.CRLF_HubController.unload() end
if G.CRLF_Minigames then G.CRLF_Minigames.stop() end
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local VIM = game:GetService("VirtualInputManager")
local PacketsReq = require(game:GetService("ReplicatedStorage").Modules.Packets)
local BlockPacket = PacketsReq.Combat and PacketsReq.Combat.packets and PacketsReq.Combat.packets.BlockInput
local player = Players.LocalPlayer
local H = {alive=true, connections={}, tweens={}, parry=true, watched={}, containers={}}
G.CRLF_HubController = H
local function connect(signal, callback)
 local c=signal:Connect(callback)
 table.insert(H.connections,c)
 return c
end
for _,root in ipairs({player.PlayerGui, gethui(), game:GetService("CoreGui")}) do
 for _,child in ipairs(root:GetChildren()) do
  if child.Name=="CRLF_Hub" then child:Destroy() end
 end
end
loadstring(readfile("CloverRPG/03_minigames_fix.lua"),"03_minigames_fix.lua")()
local MG = G.CRLF_Minigames
local palette={bg=Color3.fromRGB(15,18,25),panel=Color3.fromRGB(24,29,39),line=Color3.fromRGB(47,57,72),text=Color3.fromRGB(233,239,246),muted=Color3.fromRGB(139,155,175),accent=Color3.fromRGB(103,224,179)}
local hover=Color3.fromRGB(30,37,49)
local toggleOn=Color3.fromRGB(42,119,92)
local function new(class,props,parent)
 local o=Instance.new(class)
 for k,v in pairs(props) do o[k]=v end
 o.Parent=parent
 return o
end
local function corner(o,r) new("UICorner",{CornerRadius=UDim.new(0,r or 10)},o) end
local function tween(o,props)
 if H.tweens[o] then H.tweens[o]:Cancel() end
 local t=TS:Create(o,TweenInfo.new(0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props)
 H.tweens[o]=t
 t:Play()
end
local gui=new("ScreenGui",{Name="CRLF_Hub",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=10000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},gethui())
H.gui=gui
local size=Vector2.new(360,210)
local frame=new("Frame",{Name="Main",Size=UDim2.fromOffset(size.X,size.Y),Position=UDim2.fromOffset(35,140),BackgroundColor3=palette.bg,BorderSizePixel=0,ClipsDescendants=true,Active=true},gui)
corner(frame,14)
new("UIStroke",{Color=palette.line,Thickness=1,Transparency=0.2},frame)
local header=new("TextButton",{Name="DragHeader",Size=UDim2.new(1,-50,0,58),BackgroundTransparency=1,Text="",AutoButtonColor=false},frame)
new("TextLabel",{Position=UDim2.fromOffset(18,9),Size=UDim2.new(1,-20,0,24),BackgroundTransparency=1,Text="CLOVER",Font=Enum.Font.GothamBold,TextSize=17,TextColor3=palette.text,TextXAlignment=Enum.TextXAlignment.Left},header)
new("TextLabel",{Position=UDim2.fromOffset(18,33),Size=UDim2.new(1,-20,0,15),BackgroundTransparency=1,Text="AUTOMATION",Font=Enum.Font.Gotham,TextSize=9,TextColor3=palette.accent,TextXAlignment=Enum.TextXAlignment.Left},header)
local minimize=new("TextButton",{Name="Minimize",Position=UDim2.new(1,-44,0,13),Size=UDim2.fromOffset(30,30),BackgroundColor3=palette.panel,Text="−",TextSize=22,Font=Enum.Font.Gotham,TextColor3=palette.text,BorderSizePixel=0},frame)
corner(minimize,8)
local body=new("Frame",{Name="Body",Position=UDim2.fromOffset(14,60),Size=UDim2.new(1,-28,0,106),BackgroundTransparency=1,BorderSizePixel=0},frame)
new("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},body)
local order=0
local function toggle(name,description,initial,callback)
 local on=initial
 order+=1
 local b=new("TextButton",{Name=name,LayoutOrder=order,Size=UDim2.new(1,-5,0,49),BackgroundColor3=palette.panel,BorderSizePixel=0,Text="",AutoButtonColor=false},body)
 corner(b,9)
 new("TextLabel",{Position=UDim2.fromOffset(12,7),Size=UDim2.new(1,-74,0,18),BackgroundTransparency=1,Text=name,Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=palette.text,TextXAlignment=Enum.TextXAlignment.Left},b)
 new("TextLabel",{Position=UDim2.fromOffset(12,27),Size=UDim2.new(1,-74,0,14),BackgroundTransparency=1,Text=description,Font=Enum.Font.Gotham,TextSize=10,TextColor3=palette.muted,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd},b)
 local track=new("Frame",{Position=UDim2.new(1,-49,0.5,-10),Size=UDim2.fromOffset(36,20),BorderSizePixel=0},b)
 corner(track,10)
 local knob=new("Frame",{Size=UDim2.fromOffset(14,14),BackgroundColor3=palette.text,BorderSizePixel=0},track)
 corner(knob,8)
 local function paint()
  tween(track,{BackgroundColor3=on and toggleOn or palette.line})
  tween(knob,{Position=UDim2.fromOffset(on and 19 or 3,3)})
 end
 paint()
 connect(b.Activated,function() on=not on callback(on) paint() end)
 connect(b.MouseEnter,function() tween(b,{BackgroundColor3=hover}) end)
 connect(b.MouseLeave,function() tween(b,{BackgroundColor3=palette.panel}) end)
 return b
end
toggle("Auto Minigames","Mining + harvesting · idle outside sessions",true,function(on) MG.setEnabled(on) end)
toggle("Auto Parry","Holds block through incoming attacks",true,function(on) H.parry=on end)
local status=new("TextLabel",{Name="Status",Position=UDim2.new(0,18,1,-48),Size=UDim2.new(1,-117,0,18),BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=10,TextColor3=palette.accent,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Text="Waiting for minigame"},frame)
local footer=new("TextLabel",{Position=UDim2.new(0,18,1,-28),Size=UDim2.new(1,-60,0,15),BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=9,TextColor3=palette.muted,TextXAlignment=Enum.TextXAlignment.Left,Text="RightCtrl: hide  ·  drag header  ·  resize corner"},frame)
local unload=new("TextButton",{Position=UDim2.new(1,-92,1,-50),Size=UDim2.fromOffset(72,24),BackgroundColor3=Color3.fromRGB(57,33,40),BorderSizePixel=0,Text="Unload",Font=Enum.Font.GothamMedium,TextSize=10,TextColor3=Color3.fromRGB(242,160,164)},frame)
corner(unload,7)
local grip=new("TextButton",{Position=UDim2.new(1,-20,1,-20),Size=UDim2.fromOffset(18,18),BackgroundTransparency=1,Text="◢",TextColor3=palette.muted,TextSize=14},frame)
grip.Visible=false
local minimized=false
local drag,resize,startMouse,startPos,startSize
local function begin(input,mode)
 if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
 drag=mode=="drag" resize=mode=="resize"
 startMouse=Vector2.new(input.Position.X,input.Position.Y)
 startPos=frame.AbsolutePosition startSize=frame.AbsoluteSize
end
connect(header.InputBegan,function(i) begin(i,"drag") end)
connect(grip.InputBegan,function(i) begin(i,"resize") end)
local function viewport() return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080) end
connect(UIS.InputChanged,function(i)
 if not drag and not resize then return end
 if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end
 local delta=Vector2.new(i.Position.X,i.Position.Y)-startMouse
 local view=viewport()
 if drag then
  frame.Position=UDim2.fromOffset(math.clamp(startPos.X+delta.X,0,math.max(0,view.X-frame.AbsoluteSize.X)),math.clamp(startPos.Y+delta.Y,0,math.max(0,view.Y-frame.AbsoluteSize.Y)))
 else
  if H.tweens[frame] then H.tweens[frame]:Cancel() end
  size=Vector2.new(math.clamp(startSize.X+delta.X,300,math.max(300,math.min(560,view.X))),math.clamp(startSize.Y+delta.Y,200,math.max(200,math.min(760,view.Y))))
  frame.Size=UDim2.fromOffset(size.X,size.Y)
 end
end)
connect(UIS.InputEnded,function(i)
 if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false resize=false end
end)
connect(minimize.Activated,function()
 minimized=not minimized
 body.Visible=not minimized status.Visible=not minimized footer.Visible=not minimized unload.Visible=not minimized
 minimize.Text=minimized and "+" or "−"
 tween(frame,{Size=UDim2.fromOffset(size.X,minimized and 58 or size.Y)})
end)
local cursor=new("TextLabel",{Name="HubCursor",Size=UDim2.fromOffset(18,24),BackgroundTransparency=1,Text="↖",Font=Enum.Font.GothamBold,TextSize=22,TextColor3=Color3.new(1,1,1),TextStrokeTransparency=0.25,ZIndex=100,Visible=false},gui)
local savedCursor,ownsCursor=false,false
local function cursorRelease()
 if ownsCursor then UIS.MouseIconEnabled=savedCursor ownsCursor=false end
 cursor.Visible=false MG.paused=false
end
connect(UIS.InputBegan,function(i,processed)
 if not processed and i.KeyCode==Enum.KeyCode.RightControl then
  gui.Enabled=not gui.Enabled
  if not gui.Enabled then cursorRelease() end
 end
end)
-- Modal releases a locked gameplay mouse while interacting with the panel.
header.Modal=false
RS:BindToRenderStep("CloverHubCursor",Enum.RenderPriority.Last.Value+1,function()
 if not gui.Enabled then return end
 local mouse=UIS:GetMouseLocation()
 local p,s=frame.AbsolutePosition,frame.AbsoluteSize
 local inside=mouse.X>=p.X and mouse.X<=p.X+s.X and mouse.Y>=p.Y and mouse.Y<=p.Y+s.Y
 header.Modal=inside or drag or resize or false
 if inside or drag or resize then
  if not ownsCursor then savedCursor=UIS.MouseIconEnabled ownsCursor=true end
  UIS.MouseIconEnabled=true
  cursor.Position=UDim2.fromOffset(mouse.X,mouse.Y)
  cursor.Visible=true
  MG.paused=true
 else cursorRelease() end
end)
-- Parry = a Block hold. Server-side blocking is resolved by the block key
-- being DOWN when the hit lands, and attack animations replicate after the
-- server has already front-loaded part of the damage, so a fixed tap cannot
-- cover the damage window. Instead: on every attack-shaped animation of a
-- fighter attacking ME, hold F for that attack's window; further attacks
-- extend the same hold; release after. One smooth press, no flapping,
-- passive input only.
local RANGE=24
local POINT_BLANK=10 -- a swing starting this close is on me regardless of turn angle
-- Server parry mechanics, measured live (05_parry_window_probe):
-- a fresh Block Input grants State_Parrying ~GRANT_LATENCY after the first
-- packet, the state lives ~PARRY_WINDOW seconds, and ParryCooldown
-- (~PARRY_COOLDOWN) gates re-grants; while it runs a hold is only a plain
-- damage-soaking block. Parrying survives End Block, so holds stay SHORT.
local GRANT_LATENCY=0.10
local PARRY_WINDOW=0.25
local PARRY_COOLDOWN=1.05
local SESSION=0.16 -- hold just long enough for the grant to register
local pendingBlock=nil -- {at, until_, anim, model, plain, t0, windup}
local parriedCount=0
local lastGrant=0 -- os.clock() of our last Parrying grant (cooldown model)
local lastDamageAt=0
local blockSession=false
local threats={}
local sentAt
local grantObserved=false
-- Windup cache: attack animation id -> seconds from anim start to hit landing.
-- Tentative correlations from recorded fights. Unknown animations use a
-- fallback estimate; their timing is not yet validated.
local WINDUP_DEFAULT=0.40
local windups={
 ["125957249913572"]=0.92,
 ["73629219095110"]=0.90,
}
H.windups=windups
local Http=game:GetService("HttpService")
local learningPath="CloverRPG/parry_learning_"..game.PlaceId..".json"
local savedLearning
if isfile(learningPath) then
 local ok,data=xpcall(function() return Http:JSONDecode(readfile(learningPath)) end,tostring)
 if ok then savedLearning=data end
end
local learner=loadstring(readfile("CloverRPG/06_parry_learning.lua"),"06_parry_learning.lua")().new(savedLearning)
for id,r in pairs(learner.records) do if r.time then windups[id]=r.time end end
local recentAttacks={}
local learningDirty=false
local saveScheduled=false
local function saveLearning()
 if not learningDirty then return end
 local ok,err=xpcall(function() writefile(learningPath,Http:JSONEncode(learner:export())) end,tostring)
 if ok then learningDirty=false else warn("Clover learning save: "..err) end
end
H.learning=learner
H.autoHeld=false
H.userF=false
H.telemetry={}
local function tele(text)
 table.insert(H.telemetry,string.format("%.1f %s",os.clock()%1000,text))
 if #H.telemetry>50 then table.remove(H.telemetry,1) end
end
H.tele=tele
local function learnOutcome(kind)
 local now=os.clock()
 local candidate
 for i=#recentAttacks,1,-1 do
  local a=recentAttacks[i]
  if now-a.started>3 then table.remove(recentAttacks,i)
  elseif a.model.Parent and now-a.started<=math.min(3,a.length+0.4) then
   -- Multiple plausible swings invalidate attribution, including consumed ones.
   if candidate then tele("learning skipped: overlapping attacks") return end
   candidate=a
  end
 end
 local a=candidate
 if not a or a.consumed or a.track.Speed~=a.speed then return end
 a.consumed=true
 local me=player.Character
 local root=me and me:FindFirstChild("HumanoidRootPart")
 local other=a.model:FindFirstChild("HumanoidRootPart")
 if not root or not other or (root.Position-other.Position).Magnitude>12 then return end
 local observed=a.position+(now-a.started)*a.speed
 if observed>a.length or observed<0.08 then return end
 local changed,time=learner:observe(a.id,observed)
 tele("learning sample "..kind.." id="..a.id)
 if changed then
  windups[a.id]=time
  learningDirty=true
  tele(string.format("learned id=%s time=%.3f",a.id,time))
  if not saveScheduled then
   saveScheduled=true
   task.delay(5,function() saveScheduled=false saveLearning() end)
  end
 end
end
H.skipped={}
local function inRange(model)
 if not model then return false end
 local me=player.Character
 local myRoot=me and me:FindFirstChild("HumanoidRootPart")
 local root=model:FindFirstChild("HumanoidRootPart")
 local hum=model:FindFirstChildOfClass("Humanoid")
 return myRoot and root and hum and hum.Health>0 and (root.Position-myRoot.Position).Magnitude<=RANGE
end
-- "Actually getting hit" gate: an attack only counts if the attacker is
-- alive, within strike range, and FACING me as the swing starts. At point
-- blank the turn angle cannot be trusted (spin attacks, circling wolves), so
-- anything swinging from inside POINT_BLANK counts. An NPC trading blows with
-- someone else outside that never makes me block.
local function strikeAtUs(model)
 local me=player.Character
 local myRoot=me and me:FindFirstChild("HumanoidRootPart")
 if not myRoot then return false end
 local root=model:FindFirstChild("HumanoidRootPart")
 if not root then return false end
 local delta=myRoot.Position-root.Position
 local dist=delta.Magnitude
 if dist>POINT_BLANK then
  if dist>RANGE then return false end
  if root.CFrame.LookVector:Dot(delta/dist)<0.3 then return false end
 end
 local hum=model:FindFirstChildOfClass("Humanoid")
 return hum~=nil and hum.Health>0
end
H.strike=strikeAtUs
-- Generalized attack detection, mob-agnostic: attack animations are one-shot
-- action tracks (never looped, roughly 0.25-2.2 s); idle, walk, sprint,
-- startle and aggro cycles all loop, which excludes every movement animation.
-- The gate still requires the fighter to be facing me or swinging point
-- blank, so nobody else's fight produces a hold.
local BENIGN={
 [9839904022]=true,[103048719190843]=true,[105273448305185]=true,
 [124572427631698]=true,[73807165586659]=true,[13641430401]=true,
}
-- Resolve reaction IDs from the game's catalog. Flinches are responses to
-- OUR attacks, not incoming swings; treating them as attacks wastes cooldown.
local animationCatalog=game:GetService("ReplicatedStorage"):FindFirstChild("Animations")
if animationCatalog then
 for _,folderName in ipairs({"Hit","Blocks","Parrys"}) do
  local folder=animationCatalog:FindFirstChild(folderName)
  if folder then
   for _,animation in ipairs(folder:GetDescendants()) do
    if animation:IsA("Animation") then
     local id=tonumber(animation.AnimationId:match("%d+"))
     if id then BENIGN[id]=true windups[tostring(id)]=nil learner.records[tostring(id)]=nil end
    end
   end
  end
 end
end
local function rawLength(track)
 local ok,length=pcall(function() return track.Length end)
 return ok and length or 0
end
local function onAttack(model,track)
 if not H.alive or not H.parry then return end
 local animation=track.Animation
 if not animation then return end
 local id=animation.AnimationId:match("%d+")
 local len=rawLength(track)
 local looped=track.Looped
 if looped or (len>0 and (len<0.25 or len>2.2)) or (id and BENIGN[tonumber(id)]) then
  return
 end
 local me=player.Character
 local myRoot=me and me:FindFirstChild("HumanoidRootPart")
 local root=model:FindFirstChild("HumanoidRootPart")
 local dist=root and myRoot and (root.Position-myRoot.Position).Magnitude or 999
 if not id or not strikeAtUs(model) then
  if id and dist<=16 and not H.skipped[id] then
   H.skipped[id]=true
   tele(string.format("attack GATED id=%s dist=%.1f",id,dist))
  end
  return
 end
 tele(string.format("attack OPEN id=%s dist=%.1f",id or "?",dist))
 local speed=math.abs(track.Speed)
 if speed<0.01 then return end
 if #recentAttacks>=32 then table.remove(recentAttacks,1) end
 table.insert(recentAttacks,{id=id,model=model,track=track,started=os.clock(),
  position=track.TimePosition,speed=speed,length=len})
 local remaining=((windups[id] or WINDUP_DEFAULT)-track.TimePosition)/speed
 local at=os.clock()+math.max(0,remaining-GRANT_LATENCY-PARRY_WINDOW/2)
 if #threats>=32 then table.remove(threats,1) end
 table.insert(threats,{at=at,until_=at+SESSION,model=model,track=track,anim=id,
  windup=windups[id] or WINDUP_DEFAULT,expires=os.clock()+math.max(3,len/speed+0.5)})
end
local function watch(model)
 if model==player.Character or H.watched[model] then return end
 local hum=model:FindFirstChildOfClass("Humanoid")
 if not hum then return end
 recentAttacks={}
 H.watched[model]=hum.AnimationPlayed:Connect(function(track) onAttack(model,track) end)
 connect(hum.Died,function()
  local c=H.watched[model] if c then c:Disconnect() H.watched[model]=nil end
 end)
end
-- Event-driven watching: containers and characters are wired once at startup;
-- ChildAdded/Removed and CharacterAdded/Removing do all further work. No
-- per-second rescanning of the workspace.
local function freshCharacter(p)
 if p~=player then
  if p.Character then watch(p.Character) end
  connect(p.CharacterAdded,watch)
  connect(p.CharacterRemoving,function(ch)
   local c=H.watched[ch] if c then c:Disconnect() H.watched[ch]=nil end
  end)
 end
end
local function scanContainers()
 for _,name in ipairs({"FightableNPCS","NPCS","OtherHumanoids"}) do
  local root=workspace:FindFirstChild(name)
  if root and not H.containers[root] then
   H.containers[root]=true
   for _,m in ipairs(root:GetChildren()) do if m:IsA("Model") then watch(m) end end
   connect(root.ChildAdded,function(child) if child:IsA("Model") then watch(child) end end)
   connect(root.ChildRemoved,function(child)
    local c=H.watched[child] if c then c:Disconnect() H.watched[child]=nil end
   end)
  end
 end
end
for _,p in ipairs(Players:GetPlayers()) do freshCharacter(p) end
connect(Players.PlayerAdded,freshCharacter)
scanContainers()
connect(workspace.ChildAdded,function() task.defer(scanContainers) end)
-- Include nested and newly streamed mobs, not only named top-level folders.
for _,obj in ipairs(workspace:GetDescendants()) do
 if obj:IsA("Humanoid") and obj.Parent:IsA("Model") then watch(obj.Parent) end
end
connect(workspace.DescendantAdded,function(obj)
 if obj:IsA("Humanoid") and obj.Parent and obj.Parent:IsA("Model") then watch(obj.Parent) end
end)
local nextStatus=0
local function refreshStatus(now)
 nextStatus=now+0.5
 local text=not MG.enabled and "Minigames off" or MG.paused and "Menu interaction · automation paused" or MG.activity or "Waiting for minigame"
 if H.autoHeld then text=text.."  ·  deflecting" end
 if parriedCount>0 then text=text.."  ·  parried "..parriedCount end
 if MG.lastResult and not MG.paused then text=text.."  ·  "..MG.lastResult end
 if status.Text~=text then status.Text=text end
end
connect(UIS.InputBegan,function(i,processed)
 if i.KeyCode==Enum.KeyCode.F and not processed then H.userF=true end
end)
connect(UIS.InputEnded,function(i)
 if i.KeyCode==Enum.KeyCode.F then H.userF=false end
end)
-- Damage arming: a hit on my health means I am being attacked, period.
-- Respond with an immediate short deflect so follow-up swings inside the
-- combo are covered too - without a long hold eating your attacks.
local function armNearby()
 lastDamageAt=os.clock()
end
local lastHealth
local function wireOwn(char)
 if not char then return end
 local hum=char:WaitForChild("Humanoid",5)
 if not hum then return end
 local lastHealth=hum.Health
 connect(char:GetAttributeChangedSignal("State_Parrying"),function()
  if char:GetAttribute("State_Parrying") then
   lastGrant=os.clock()
   if sentAt and blockSession then
    local observed=lastGrant-sentAt
    if observed>0.02 and observed<0.5 then
     GRANT_LATENCY=GRANT_LATENCY*0.8+observed*0.2
    end
    grantObserved=true
   end
   tele("server granted Parrying")
  end
 end)
 connect(char:GetAttributeChangedSignal("State_ParriedAttack"),function()
  if char:GetAttribute("State_ParriedAttack") then
   parriedCount+=1
   H.parriedCount=parriedCount
    tele("own parry payoff confirmed")
    learnOutcome("parry")
  end
 end)
 connect(hum.HealthChanged,function(value)
  if value<lastHealth then
   lastHealth=value
    tele(string.format("damaged %.0f",value))
    -- Health loss alone cannot identify a source (falls, DOT, other attackers).
    -- Never use it as a timing label.
   armNearby()
  else
   lastHealth=value
  end
 end)
end
wireOwn(player.Character)
connect(player.CharacterAdded,function(char) task.defer(wireOwn,char) end)
-- Server-side blocking is the State_Blocking attribute, readable on our own
-- character: authoritative feedback for whether the session engaged.
local function blockingState()
 local me=player.Character
 return me and (me:GetAttribute("State_Blocking") or me:GetAttribute("State_SwordBlocking"))
end
local function endBlock()
 blockSession=false
 sentAt=nil
 grantObserved=false
 H.autoHeld=false
 if not H.userF then BlockPacket.send({Action="End Block"}) end
end
connect(RS.Heartbeat,function()
 local now=os.clock()
 local me=player.Character
 local hum=me and me:FindFirstChildOfClass("Humanoid")
 local tool=me and me:FindFirstChildWhichIsA("Tool")
 local enabled=H.alive and H.parry and not H.userF and hum and hum.Health>0
  and tool and (tool:GetAttribute("Sword") or tool:GetAttribute("Combat"))
 if not enabled then
  for i=#threats,1,-1 do threats[i]=nil end
  pendingBlock=nil
  if blockSession then endBlock() end
 else
  local candidate
  for i=#threats,1,-1 do
   local t=threats[i]
   local speed=t.track.Speed
   if now>t.expires or not t.track.IsPlaying or not strikeAtUs(t.model) then
    table.remove(threats,i)
   elseif speed>0.01 then
    local remaining=(t.windup-t.track.TimePosition)/speed
    if remaining < -PARRY_WINDOW then
     table.remove(threats,i)
    else
     t.at=now+remaining-GRANT_LATENCY-PARRY_WINDOW/2
     t.until_=now+remaining-GRANT_LATENCY+0.04
     if not candidate or t.at<candidate.at then candidate=t end
    end
   end
  end
  if not blockSession then pendingBlock=candidate end
 end
 -- Scheduled deflect sessions: while inside the window, spam the block
 -- packet exactly like a keyed F hold; when it lapses, End Block so your
 -- own attacks are free again.
 local pend=pendingBlock
 if pend and (not H.alive or not H.parry or H.userF or not me or not pend.track.IsPlaying or not strikeAtUs(pend.model)) then
  if blockSession then endBlock() end
  H.autoHeld=false
  pendingBlock=nil
  pend=nil
 end
 if pend then
  if now>=pend.at and now<=pend.until_ then
    if not blockSession and me:GetAttribute("State_Attacking") then return end
     if not blockSession and me:GetAttribute("State_ParryCooldown") then return end
     if not blockSession and (me:GetAttribute("State_Parrying") or me:GetAttribute("State_Stunned") or me:GetAttribute("State_BlockBroken")) then return end
   if now>=pend.at then
    if not blockSession then
     blockSession=true
     sentAt=now
     grantObserved=false
     pend.until_=math.min(pend.until_,now+SESSION)
     for i=#threats,1,-1 do if threats[i]==pend then table.remove(threats,i) end end
    H.autoHeld=true
    tele("deflect START id="..pend.anim)
   end
   local ok=pcall(function() BlockPacket.send({Action="Block Input"}) end)
   if not ok then tele("send FAILED") end
   end -- close the now>=pend.at session-active check
   elseif now>pend.until_ then
   if blockSession then
    tele("release attr="..tostring(blockingState()))
    endBlock()
    H.autoHeld=false
   end
   pendingBlock=nil
  end
  if blockSession and grantObserved then
   endBlock()
   pendingBlock=nil
  end
 end
 -- Idle: nothing scheduled, nothing to stream - loop does nothing this frame.
 if not pendingBlock and not blockSession and nextStatus>now then return end
 if gui.Enabled and now>=nextStatus then refreshStatus(now) end
end)
function H.unload()
 if not H.alive then return end
 H.alive=false
 saveLearning()
 RS:UnbindFromRenderStep("CloverHubCursor")
 cursorRelease()
 H.autoHeld=false
 if blockSession then endBlock() end
 if MG and MG.stop then pcall(MG.stop) end
 for _,c in ipairs(H.connections) do c:Disconnect() end
 for _,c in pairs(H.watched) do c:Disconnect() end
 for k in pairs(H.watched) do H.watched[k]=nil end
 for k in pairs(H.containers) do H.containers[k]=nil end
 for _,t in pairs(H.tweens) do t:Cancel() end
 gui:Destroy()
 if G.CRLF_HubController==H then G.CRLF_HubController=nil end
end
connect(unload.Activated,H.unload)
return "Clover Hub v4 loaded: automation, cursor, resize, unload"
