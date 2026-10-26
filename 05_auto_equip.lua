-- Auto equip best weapon: scores the belt's weapons from the game's own item
-- catalog (BaseDamage) and holds the best one through the normal client tool
-- path. Yields to whatever you are holding; never forces a swap mid-swing.
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local H=getgenv().CRLF_HubController
local state={enabled=false,stats={swaps=0,checks=0}}
local ok,Items=pcall(require,game.ReplicatedStorage.Modules.Items)
local function baseName(tool)
 if not (ok and Items) then return nil end
 local okName,name=pcall(Items.GetBaseName,tool.Name)
 return okName and name or tool.Name
end
local function weaponDamage(tool)
 local base=baseName(tool)
 if not base then return nil end
 local okDef,def=pcall(Items.LookupItem,base)
 if not okDef or type(def)~="table" or def.Type~="Weapon" or not def.BaseDamage then return nil end
 return def.BaseDamage
end
local function bestWeapon()
 local belt=player:FindFirstChild("Backpack")
 if not belt then return nil end
 local best,bestScore=nil,-1
 for _,tool in ipairs(belt:GetChildren()) do
  if tool:IsA("Tool") and (tool:GetAttribute("Sword") or tool:GetAttribute("Combat")) then
   local score=weaponDamage(tool)
   if score and score>bestScore then
    best,bestScore=tool,score
   end
  end
 end
 return best
end
local lastSwap=0
function state.check()
 -- Called on belt changes and on a slow cadence while enabled.
 if not state.enabled or not H.alive then return end
 state.stats.checks+=1
 local me=player.Character
 local hum=me and me:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 then return end
 -- Yield to manual weapon choices: if you drew a weapon recently, wait.
 if os.clock()<(H.manualGap or 0) then return end
 local held=me and me:FindFirstChildWhichIsA("Tool")
 local heldScore=held and weaponDamage(held)
 if held and (held:GetAttribute("Sword") or held:GetAttribute("Combat")) and heldScore then
  -- Only swap when the held weapon is strictly worse.
  local best=bestWeapon()
  if not best or best==held then return end
  local bestScore=weaponDamage(best)
  if not bestScore or bestScore<=heldScore then return end
  lastSwap=os.clock()
  state.stats.swaps+=1
  hum:EquipTool(best)
 else
  local best=bestWeapon()
  if best and os.clock()-lastSwap>2 then
   lastSwap=os.clock()
   state.stats.swaps+=1
   hum:EquipTool(best)
  end
 end
end
local connections={}
function state.setEnabled(on)
 state.enabled=on
 if on then
  local belt=player:FindFirstChild("Backpack")
  if belt then
   table.insert(connections,belt.ChildAdded:Connect(function() task.wait(0.4) state.check() end))
  end
  table.insert(connections,player.CharacterAdded:Connect(function() task.wait(1) state.check() end))
  state.check()
 else
  for _,c in ipairs(connections) do c:Disconnect() end
  table.clear(connections)
 end
end
function state.stop()
 state.setEnabled(false)
end
H.equip=state
return state
