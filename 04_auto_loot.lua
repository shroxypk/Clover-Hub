-- Auto loot: fires the game's own ProximityPrompt for loot bags and chests
-- when the player is in range. Normal input path only; small randomized delay
-- so repeated loots do not look machine-regular.
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local H=getgenv().CRLF_HubController
local state={enabled=false,stats={fired=0,skipped=0}}
local connections={}
local recent={}
local function connect(signal,callback)
 local c=signal:Connect(callback)
 table.insert(connections,c)
 return c
end
local function isChestContainer(model)
 if not model:IsA("Model") and not model:IsA("BasePart") then return false end
 local name=model.Name:lower()
 if not name:find("chest",1,true) then return false end
 return model:FindFirstChildWhichIsA("ProximityPrompt",true)~=nil
end
local function inRange(prompt)
 local me=player.Character
 local root=me and me:FindFirstChild("HumanoidRootPart")
 local holder=prompt.Parent
 if not root or not holder then return false end
 local part=holder:IsA("BasePart") and holder or holder.PrimaryPart or holder:FindFirstChildWhichIsA("BasePart",true)
 if not part then return false end
 return (part.Position-root.Position).Magnitude<=14
end
local function tryFire(prompt)
 if not state.enabled or not prompt or not prompt.Enabled then return end
 local model=prompt:FindFirstAncestorOfClass("Model") or prompt.Parent
 if not model or recent[model] then return end
 if os.clock()-(recent[model] or 0)<8 then return end
 if not inRange(prompt) then return end
 recent[model]=os.clock()
 state.stats.fired+=1
 -- Human-ish: never fire on the same frame the bag appeared.
 task.delay(0.2+math.random()*0.4,function()
  if state.enabled and prompt.Parent and inRange(prompt) and prompt.Enabled then
   fireproximityprompt(prompt)
  else
   state.stats.skipped+=1
  end
 end)
end
local function scan(root)
 for _,d in ipairs(root:GetDescendants()) do
  if d:IsA("ProximityPrompt") and isChestContainer(d.Parent) then tryFire(d) end
 end
end
local scanThread
function state.setEnabled(on)
 state.enabled=on
 if on then
  connect(workspace.DescendantAdded,function(d)
   if d:IsA("ProximityPrompt") then
    local model=d:FindFirstAncestorOfClass("Model")
    if model and isChestContainer(model) then tryFire(d) end
   end
  end)
  -- Periodic pass for bags/chests that spawned or were always present.
  scanThread=task.spawn(function()
   while state.enabled and H.alive do
    scan(workspace.Objects)
    scan(workspace.Map:FindFirstChild("Structures") or workspace.Map)
    task.wait(2+math.random())
   end
  end)
 else
  table.clear(recent)
 end
end
function state.stop()
 state.enabled=false
 for _,c in ipairs(connections) do c:Disconnect() end
 table.clear(connections)
 table.clear(recent)
end
H.loot=state
return state
