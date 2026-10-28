-- Boss attack alerts: client-visible animation-marker cues, not confirmed hits.
-- All timing follows the actual animation playback speed. No gameplay inputs.
local G=getgenv()
if G.VeyraBossAlerts then G.VeyraBossAlerts.stop() end
local profiles=loadstring(readfile("Veyra/src/parry_profiles.lua"),"parry_profiles.lua")()
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local CollectionService=game:GetService("CollectionService")
local player=Players.LocalPlayer
local state={alive=true,enabled=false,status="Boss alerts off",warnings=0}
G.VeyraBossAlerts=state

local watched,connections,pending={},{},{}
local gui,card,label,bar,heading
local worker,generation=nil,0
local showing=false
local visibilityTween
local ALERT_RANGE=90
local overlap=OverlapParams.new()
overlap.FilterType=Enum.RaycastFilterType.Exclude
overlap.MaxParts=512

local function bossLike(model,profile)
 if profile and profile.name and profile.name:lower():find("boss",1,true) then return true end
 local item=model
 while item and item~=workspace do
  if item:GetAttribute("Boss")==true or item:GetAttribute("IsBoss")==true then return true end
  if item.Name:lower():find("boss",1,true) then return true end
  local ok,tagged=pcall(CollectionService.HasTag,CollectionService,item,"Boss")
  if ok and tagged then return true end
  item=item.Parent
 end
 return false
end
local function modelRoot(model,humanoid)
 return model:FindFirstChild("HumanoidRootPart") or humanoid.RootPart
  or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true)
end
local function makeAlertGui()
 if gui and gui.Parent then return end
 gui=Instance.new("ScreenGui")
 gui.Name="VeyraBossAlert"
 gui.ResetOnSpawn=false
 gui.IgnoreGuiInset=true
 gui.DisplayOrder=10001
 gui.Parent=player:WaitForChild("PlayerGui")

 card=Instance.new("Frame")
 card.Name="BossWindup"
 card.AnchorPoint=Vector2.new(0.5,0)
 card.Position=UDim2.new(0.5,0,0.11,0)
 card.Size=UDim2.new(0.75,0,0,64)
 card.BackgroundColor3=Color3.fromRGB(25,20,24)
 card.BackgroundTransparency=0.08
 card.BorderSizePixel=0
 card.Visible=false
 card.Parent=gui
 local limit=Instance.new("UISizeConstraint")
 limit.MinSize=Vector2.new(260,64)
 limit.MaxSize=Vector2.new(420,64)
 limit.Parent=card
 local corner=Instance.new("UICorner")
 corner.CornerRadius=UDim.new(0,12)
 corner.Parent=card
 local stroke=Instance.new("UIStroke")
 stroke.Color=Color3.fromRGB(234,111,84)
 stroke.Transparency=0.25
 stroke.Thickness=1
 stroke.Parent=card
 local stripe=Instance.new("Frame")
 stripe.Name="Accent"
 stripe.Position=UDim2.fromOffset(0,0)
 stripe.Size=UDim2.new(0,3,1,0)
 stripe.BackgroundColor3=Color3.fromRGB(234,111,84)
 stripe.BorderSizePixel=0
 stripe.Parent=card

 heading=Instance.new("TextLabel")
 heading.Position=UDim2.fromOffset(15,9)
 heading.Size=UDim2.new(1,-28,0,16)
 heading.BackgroundTransparency=1
 heading.Text="VEYRA  /  BOSS WINDUP"
 heading.Font=Enum.Font.GothamBold
 heading.TextSize=10
 heading.TextColor3=Color3.fromRGB(248,164,119)
 heading.TextXAlignment=Enum.TextXAlignment.Left
 heading.Parent=card

 label=Instance.new("TextLabel")
 label.Name="Warning"
 label.Position=UDim2.fromOffset(15,28)
 label.Size=UDim2.new(1,-28,0,20)
 label.BackgroundTransparency=1
 label.Font=Enum.Font.GothamMedium
 label.TextColor3=Color3.fromRGB(246,242,240)
 label.TextSize=13
 label.TextTruncate=Enum.TextTruncate.AtEnd
 label.TextXAlignment=Enum.TextXAlignment.Left
 label.Parent=card

 local track=Instance.new("Frame")
 track.Name="TimerTrack"
 track.Position=UDim2.new(0,15,1,-9)
 track.Size=UDim2.new(1,-30,0,3)
 track.BackgroundColor3=Color3.fromRGB(70,57,60)
 track.BorderSizePixel=0
 track.Parent=card
 local trackCorner=Instance.new("UICorner")
 trackCorner.CornerRadius=UDim.new(0,2)
 trackCorner.Parent=track
 bar=Instance.new("Frame")
 bar.Name="TimeRemaining"
 bar.Size=UDim2.fromScale(1,1)
 bar.BackgroundColor3=Color3.fromRGB(241,144,96)
 bar.BorderSizePixel=0
 bar.Parent=track
 local barCorner=Instance.new("UICorner")
 barCorner.CornerRadius=UDim.new(0,2)
 barCorner.Parent=bar
end
local function setShowing(on)
 if showing==on or not card then return end
 showing=on
 if visibilityTween then visibilityTween:Cancel() end
 if on then
  card.Visible=true
  card.BackgroundTransparency=1
 end
 local tween=TweenService:Create(card,TweenInfo.new(0.14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
  BackgroundTransparency=on and 0.08 or 1
 })
 visibilityTween=tween
 tween.Completed:Once(function(result)
  if result==Enum.PlaybackState.Completed and not showing and card then card.Visible=false end
 end)
 tween:Play()
end
local function observe(model,humanoid,track)
 local animation=track.Animation
 local id=animation and animation.AnimationId:match("%d+")
 local profile=id and profiles[id]
 if not profile or track.Looped or not bossLike(model,profile) then return end
 local root=modelRoot(model,humanoid)
 if not root then return end
 local hits={}
 for _,hit in ipairs(profile.hits or {}) do
  -- Positive profile offset means the measured impact is EARLIER.
  -- Using +offset here would systematically warn too late.
  local adjusted=hit-(profile.offset or 0)
  if adjusted>track.TimePosition then table.insert(hits,adjusted) end
 end
 if #hits==0 then return end
 table.sort(hits)
 pending[track]={
  model=model,humanoid=humanoid,root=root,track=track,
  name=profile.name or model.Name,hits=hits,index=1,
  expires=os.clock()+math.clamp((hits[#hits]-track.TimePosition)/math.max(track.Speed,0.1)+1,3,18)
 }
end
local function watch(animator,model,humanoid,keep)
 keep[animator]=true
 if not watched[animator] then
  watched[animator]=animator.AnimationPlayed:Connect(function(track)
   observe(model,humanoid,track)
  end)
  for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
   observe(model,humanoid,track)
  end
 end
end
local function npcForPart(part)
 local item=part
 while item and item~=workspace do
  if item:IsA("Model") then
   local humanoid=item:FindFirstChildOfClass("Humanoid")
   if humanoid then return item,humanoid end
  end
  item=item.Parent
 end
end
local function scanNearby()
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 if not root then
  for animator,connection in pairs(watched) do
   connection:Disconnect() watched[animator]=nil
  end
  table.clear(pending)
  return
 end
 overlap.FilterDescendantsInstances={character}
 local parts=workspace:GetPartBoundsInRadius(root.Position,ALERT_RANGE,overlap)
 local keep,seenModels={},{}
 for _,part in ipairs(parts) do
  local model,humanoid=npcForPart(part)
  if model and model~=character and not seenModels[model]
   and humanoid.Health>0 and not Players:GetPlayerFromCharacter(model) then
   seenModels[model]=true
   local targetRoot=modelRoot(model,humanoid)
   if targetRoot and (targetRoot.Position-root.Position).Magnitude<=ALERT_RANGE then
    local animator=humanoid:FindFirstChildOfClass("Animator")
    if animator then watch(animator,model,humanoid,keep) end
   end
  end
 end
 for animator,connection in pairs(watched) do
  if not keep[animator] then connection:Disconnect() watched[animator]=nil end
 end
end
local function updateWarnings()
 local now=os.clock()
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local best,bestRemaining,bestLead,bestDistance
 for track,item in pairs(pending) do
  local valid=item.expires>now and track.IsPlaying and item.humanoid.Health>0
   and item.root.Parent and root
  if not valid then
   pending[track]=nil
  else
   local distance=(item.root.Position-root.Position).Magnitude
   if distance>ALERT_RANGE then
    pending[track]=nil
   elseif track.Speed>0.01 then
    -- TimePosition advances in animation-time; divide by playback speed.
    local remaining=(item.hits[item.index]-track.TimePosition)/track.Speed
    while remaining<0 and item.index<#item.hits do
     item.index+=1
     remaining=(item.hits[item.index]-track.TimePosition)/track.Speed
    end
    if remaining<0 then
     pending[track]=nil
    else
     -- Slightly earlier cue for distant bosses, shorter for nearby ones.
     -- This adjusts display lead, not the game's animation marker itself.
     local lead=0.70+0.35*math.clamp(distance/ALERT_RANGE,0,1)
     if remaining<=lead then
      if item.announcedIndex~=item.index then
       item.announcedIndex=item.index
       state.warnings+=1
      end
      if not bestRemaining or remaining<bestRemaining
       or (math.abs(remaining-bestRemaining)<0.04 and distance<bestDistance) then
       best,bestRemaining,bestLead,bestDistance=item,remaining,lead,distance
      end
     end
    end
   end -- Paused animations are kept until expiry, but never shown.
  end
 end
 if best and label then
  setShowing(true)
  local short=best.name:len()>28 and best.name:sub(1,27).."…" or best.name
  local text=string.format("%s  ·  marker in ~%.1fs",short,bestRemaining)
  if bestRemaining<=0.12 then text=short.."  ·  IMMINENT" end
  if label.Text~=text then label.Text=text end
  heading.TextColor3=bestRemaining<=0.30 and Color3.fromRGB(255,108,100)
   or Color3.fromRGB(248,164,119)
  bar.BackgroundColor3=bestRemaining<=0.30 and Color3.fromRGB(255,108,100)
   or Color3.fromRGB(241,144,96)
  bar.Size=UDim2.fromScale(math.clamp(bestRemaining/bestLead,0,1),1)
  state.status=string.format("Boss marker ~%.1fs · %d studs",bestRemaining,math.floor(bestDistance))
 else
  setShowing(false)
  state.status="Listening for profiled boss attacks"
 end
end
function state.setEnabled(on)
 if not state.alive then return end
 on=on==true
 if on==state.enabled then return end
 generation+=1
 local current=generation
 state.enabled=on
 if worker then task.cancel(worker) worker=nil end
 for _,connection in ipairs(connections) do connection:Disconnect() end
 table.clear(connections)
 for animator,connection in pairs(watched) do connection:Disconnect() watched[animator]=nil end
 table.clear(pending)
 if visibilityTween then visibilityTween:Cancel() visibilityTween=nil end
 showing=false
 if not on then
  state.status="Boss alerts off"
  if gui then gui:Destroy() gui=nil card=nil label=nil bar=nil heading=nil end
  return
 end
 makeAlertGui()
 state.status="Listening for profiled boss attacks"
 worker=task.spawn(function()
  local nextScan=0
  while state.alive and state.enabled and generation==current do
   local now=os.clock()
   if now>=nextScan then
    local ok,err=pcall(scanNearby)
    if not ok then state.status="Boss alert scan unavailable" warn("[Veyra Boss Alert] "..tostring(err)) end
    nextScan=now+0.35
   end
   local ok,err=pcall(updateWarnings)
   if not ok then state.status="Boss alert timing unavailable" warn("[Veyra Boss Alert] "..tostring(err)) end
   task.wait(0.05)
  end
 end)
end
function state.stop()
 state.setEnabled(false)
 state.alive=false
 if G.VeyraBossAlerts==state then G.VeyraBossAlerts=nil end
end
return state
