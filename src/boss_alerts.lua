-- Boss attack alerts: observe profiled animation windups and display a warning.
-- This module never sends gameplay input or changes character/game state.
local G=getgenv()
if G.VeyraBossAlerts then G.VeyraBossAlerts.stop() end
local profiles=loadstring(readfile("Veyra/src/parry_profiles.lua"),"parry_profiles.lua")()
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local CollectionService=game:GetService("CollectionService")
local player=Players.LocalPlayer
local state={alive=true,enabled=false,status="Boss alerts off",warnings=0}
G.VeyraBossAlerts=state
local watched,connections,pending={}, {}, {}
local gui,label
local worker,generation= nil,0
local ALERT_LEAD=2.5
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
 gui.DisplayOrder=10001
 gui.Parent=player:WaitForChild("PlayerGui")
 label=Instance.new("TextLabel")
 label.Name="Warning"
 label.AnchorPoint=Vector2.new(0.5,0)
 label.Position=UDim2.new(0.5,0,0.12,0)
 label.Size=UDim2.fromOffset(420,42)
 label.BackgroundColor3=Color3.fromRGB(78,27,24)
 label.BackgroundTransparency=0.12
 label.BorderSizePixel=0
 label.Font=Enum.Font.GothamBold
 label.TextColor3=Color3.fromRGB(255,239,223)
 label.TextSize=17
 label.Text="BOSS ATTACK"
 label.Visible=false
 label.Parent=gui
 local corner=Instance.new("UICorner")
 corner.CornerRadius=UDim.new(0,9)
 corner.Parent=label
 local stroke=Instance.new("UIStroke")
 stroke.Color=Color3.fromRGB(255,132,91)
 stroke.Transparency=0.25
 stroke.Thickness=1
 stroke.Parent=label
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
  local adjusted=hit+(profile.offset or 0)
  if adjusted>track.TimePosition then table.insert(hits,adjusted) end
 end
 if #hits==0 then return end
 table.sort(hits)
 pending[track]={model=model,humanoid=humanoid,root=root,track=track,
  name=profile.name or model.Name,hits=hits,index=1,expires=os.clock()+12}
end
local function watch(animator,model,humanoid,keep)
 keep[animator]=true
 if not watched[animator] then
  local connection=animator.AnimationPlayed:Connect(function(track)
   observe(model,humanoid,track)
  end)
  watched[animator]=connection
  for _,track in ipairs(animator:GetPlayingAnimationTracks()) do observe(model,humanoid,track) end
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
 if not root then return end
 overlap.FilterDescendantsInstances={character}
 local parts=workspace:GetPartBoundsInRadius(root.Position,90,overlap)
 local keep,seenModels={},{}
 for _,part in ipairs(parts) do
  local model,humanoid=npcForPart(part)
  if model and model~=character and not seenModels[model]
   and humanoid.Health>0 and not Players:GetPlayerFromCharacter(model) then
   seenModels[model]=true
   local targetRoot=modelRoot(model,humanoid)
   if targetRoot and (targetRoot.Position-root.Position).Magnitude<=90 then
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
 local best,bestRemaining
 for track,item in pairs(pending) do
  local valid=item.expires>now and track.IsPlaying and item.humanoid.Health>0
   and item.root.Parent and root and (item.root.Position-root.Position).Magnitude<=90
  if not valid then
   pending[track]=nil
  else
   local speed=track.Speed
   if speed<=0.01 then
    pending[track]=nil
   else
    local remaining=item.hits[item.index]
     and (item.hits[item.index]-track.TimePosition)/speed or 0
    if item.index<=#item.hits and remaining<=0 then
     state.warnings+=1
     item.index+=1
     if item.hits[item.index] then
      remaining=(item.hits[item.index]-track.TimePosition)/speed
     else
      item.expires=math.min(item.expires,now+0.55)
     end
    end
    if item.index<=#item.hits and remaining>=0 and remaining<=ALERT_LEAD
     and (not bestRemaining or remaining<bestRemaining) then
     best,bestRemaining=item,remaining
    elseif item.index>#item.hits and item.expires>now and item.expires-now<=0.55
     and (not bestRemaining or 0<bestRemaining) then
     best,bestRemaining=item,0
    end
   end
  end
 end
 if best and label then
  label.Visible=true
  label.Text=bestRemaining>0.08
   and string.format("BOSS ATTACK · %s · ~%.1fs",best.name,bestRemaining)
   or string.format("BOSS ATTACK · %s · NOW",best.name)
 elseif label then
  label.Visible=false
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
 for _,connection in pairs(watched) do connection:Disconnect() end
 table.clear(watched)
 table.clear(pending)
 if not on then
  state.status="Boss alerts off"
  if gui then gui:Destroy() gui=nil label=nil end
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
   updateWarnings()
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

