-- Auto equip best: scores every equipment item in the Inventory using the
-- game's own catalog (weapon BaseDamage, armor ArmorType + stat rolls) and
-- sends the normal Inventory.Equip packet for strict per-slot upgrades.
-- Weapons are held through the normal client tool path. Yields to whatever
-- you are holding; never swaps mid-swing.
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local H=getgenv().CRLF_HubController
local state={enabled=false,stats={equips=0,swaps=0,checks=0}}
local ok,Items=pcall(require,game.ReplicatedStorage.Modules.Items)
local okPack,Packets=pcall(require,game.ReplicatedStorage.Modules.Packets)
local equipPacket=okPack and Packets.Inventory and Packets.Inventory.packets and Packets.Inventory.packets.Equip or nil
local okBU,BU=pcall(require,game.ReplicatedStorage.Modules.BackpackUtils)
local armorSlots=okBU and BU._armorStats or {}
local connections={}
local slotCooldown={}
local lastSwap=0
local function def(item)
 if not (ok and Items) then return nil end
 local okName,name=pcall(Items.GetBaseName,item.Name)
 if not okName or not name then return nil end
 local okDef,def=pcall(Items.LookupItem,name)
 if not okDef then return nil end
 return def
end
local function parseStats(text)
 local sum=0
 if type(text)=="string" and text~="" then
  for stat in text:gmatch("[^,]+") do
   local value=tonumber(stat:match("%d+"))
   if value then sum+=value end
  end
 end
 return sum
end
local function itemScore(item,definition)
 local d=definition or def(item)
 if not d then return nil,nil end
 if d.Type=="Weapon" and d.BaseDamage then
  return d.BaseDamage,"Weapon"
 end
 if d.Type=="Armor" and d.ArmorType then
  local score=0
  local base=d._attributes and d._attributes.Base
  if type(base)=="table" then
   for _,v in pairs(base) do
    if type(v)=="number" then score+=v end
   end
  end
  score+=parseStats(item:GetAttribute("Stats"))
  return score,d.ArmorType
 end
 return nil,nil
end
local function equippedScore(slotName)
 -- The game names equipped armor containers Equipped<Slot> on the character.
 local me=player.Character
 local child=me and me:FindFirstChild(armorSlots[slotName] and armorSlots[slotName].Equipped or "Equipped"..slotName)
 if not child then return nil end
 for _,item in ipairs(player.Inventory:GetChildren()) do
  local id=item:GetAttribute("ID")
  if id and child:GetAttribute("ID")==id then
   local score=itemScore(item)
   if score then return score end
  end
 end
 -- Equipped with unknown score: treat as unbeatable so we never spam equips.
 return math.huge
end
local function bestForSlot(slotName)
 local inventory=player:FindFirstChild("Inventory")
 if not inventory then return nil end
 local best,bestScore=nil,-1
 for _,item in ipairs(inventory:GetChildren()) do
  local score,slot=itemScore(item)
  if score and slot==slotName and score>bestScore then
   best,bestScore=item,score
  end
 end
 return best,bestScore
end
local function bestWeapon()
 local belt=player:FindFirstChild("Backpack")
 if not belt then return nil end
 local best,bestScore=nil,-1
 for _,tool in ipairs(belt:GetChildren()) do
  if tool:IsA("Tool") and (tool:GetAttribute("Sword") or tool:GetAttribute("Combat")) then
   local score=weaponScore(tool)
   if score and score>bestScore then
    best,bestScore=tool,score
   end
  end
 end
 return best
end
function weaponScore(tool)
 local d=def(tool)
 if d and d.Type=="Weapon" and d.BaseDamage then return d.BaseDamage end
 return nil
end
local function checkArmor()
 local me=player.Character
 if not me then return end
 for slotName in pairs(armorSlots) do
  local current=equippedScore(slotName)
  local best,bestScore=bestForSlot(slotName)
  if best and bestScore and (not current or bestScore>current) then
   local now=os.clock()
   if now-(slotCooldown[slotName] or 0)>30 then
    slotCooldown[slotName]=now
    if equipPacket then
     state.stats.equips+=1
     equipPacket.send({Item=best})
    end
   end
  end
 end
end
local function checkWeapon()
 local me=player.Character
 local hum=me and me:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 then return end
 -- Yield to manual weapon choices: if you drew a weapon recently, wait.
 if os.clock()<(H.manualGap or 0) then return end
 local held=me:FindFirstChildWhichIsA("Tool")
 local heldScore=held and weaponScore(held)
 if held and heldScore then
  local best=bestWeapon()
  if not best or best==held then return end
  if weaponScore(best)<=heldScore then return end
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
function state.check()
 if not state.enabled or not H.alive then return end
 state.stats.checks+=1
 local me=player.Character
 local hum=me and me:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 then return end
 checkArmor()
 checkWeapon()
end
function state.setEnabled(on)
 state.enabled=on
 for _,c in ipairs(connections) do c:Disconnect() end
 table.clear(connections)
 if on then
  local inventory=player:FindFirstChild("Inventory")
  if inventory then
   table.insert(connections,inventory.ChildAdded:Connect(function() task.wait(0.5) state.check() end))
  end
  table.insert(connections,player.CharacterAdded:Connect(function() task.wait(1) state.check() end))
  table.insert(connections,player.CharacterAdded:Connect(function(char)
   -- Re-run armor comparison once the character finishes loading.
   task.delay(2.5,state.check)
  end))
  state.check()
 end
end
function state.stop()
 state.setEnabled(false)
end
H.equip=state
return state
