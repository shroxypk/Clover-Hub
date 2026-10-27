-- Passive parry-timing observer. Read-only: it never moves the character,
-- never attacks, and never fires a remote. It watches replicated fights
-- (attacker animations + victim damage) and records how far each real impact
-- lands from the marker our profile would schedule on.
--
-- Usage: load in a live server with the Veyra files present, then
--   writefile("Veyra_parry_obs.json", game:GetService("HttpService"):JSONEncode(
--     {records = getgenv().__veyraObs.records}))
-- Convert the records with tools/summarise_parry_obs.py.
local HttpService=game:GetService("HttpService")
local profiles=loadstring(readfile("Veyra/src/parry_profiles.lua"),"parry_profiles.lua")()
local obs={started=os.clock(),anims=0,damage=0,players={},records={}}
getgenv().__veyraObs=obs
for _,player in ipairs(game:GetService("Players"):GetPlayers()) do
 table.insert(obs.players,player.Name)
end

local watched,active={},{}
local function rootOf(model)
 return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
end

local function watch(object)
 if watched[object] then return end
 watched[object]=true
 if object:IsA("Animator") then
  object.AnimationPlayed:Connect(function(track)
   local id
   pcall(function() id=tostring(track.Animation and track.Animation.AnimationId or ""):match("%d+") end)
   if not id then return end
   obs.anims+=1
   local model=object:FindFirstAncestorOfClass("Model")
   if model then
    table.insert(active,{model=model,id=id,start=os.clock(),speed=track.Speed or 1})
   end
  end)
 elseif object:IsA("Humanoid") then
  local last=object.Health
  object.HealthChanged:Connect(function(value)
   local damage=last-value
   last=value
   if damage<=0 then return end
   obs.damage+=1
   local victim=object.Parent
   local victimRoot=rootOf(victim)
   if not victimRoot then return end
   local now=os.clock()
   local candidates={}
   for index=#active,1,-1 do
    local entry=active[index]
    if now-entry.start>6 then
     table.remove(active,index)
    elseif entry.model~=victim then
     local attackerRoot=rootOf(entry.model)
     local profile=profiles[entry.id]
     if attackerRoot and profile then
      local distance=(victimRoot.Position-attackerRoot.Position).Magnitude
      if distance<30 then
       local elapsed=now-entry.start
       local nearest,nearestDistance
       for _,hit in ipairs(profile.hits) do
        local difference=elapsed*entry.speed-hit
        if not nearestDistance or math.abs(difference)<nearestDistance then
         nearest,nearestDistance=hit,math.abs(difference)
        end
       end
       if nearest then
        local players=game:GetService("Players")
        table.insert(candidates,{
         asset=entry.id,name=profile.name,speed=entry.speed,
         elapsed=elapsed,marker=nearest/entry.speed,
         delta=elapsed-nearest/entry.speed,dist=distance,
         attacker=entry.model.Name,victim=victim.Name,damage=damage,
         attackerIsPlayer=players:GetPlayerFromCharacter(entry.model)~=nil,
         victimIsPlayer=players:GetPlayerFromCharacter(victim)~=nil,
         fit=math.abs(elapsed-nearest/entry.speed)})
       end
      end
     end
    end
   end
   if #candidates>0 and #obs.records<6000 then
    table.sort(candidates,function(a,b) return a.fit<b.fit end)
    table.insert(obs.records,{t=now,candidates=candidates})
   end
  end)
 end
end

local function scan()
 for _,item in ipairs(workspace:GetDescendants()) do
  if item:IsA("Animator") or item:IsA("Humanoid") then watch(item) end
 end
end
scan()
workspace.DescendantAdded:Connect(function(item)
 if item:IsA("Animator") or item:IsA("Humanoid") then watch(item) end
end)
task.spawn(function()
 while getgenv().__veyraObs==obs do
  pcall(scan)
  local now=os.clock()
  for index=#active,1,-1 do
   if now-active[index].start>6 then table.remove(active,index) end
  end
  task.wait(1)
 end
end)
print("parry observer: recording replicated impacts")
