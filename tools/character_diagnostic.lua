-- Veyra diagnostic for the local Clover RPG character and tracked quest.
-- Read-only: no remote calls, quest mutations, interaction prompts or uploads.
local player=game:GetService("Players").LocalPlayer
local http=game:GetService("HttpService")
if not player then warn("[Veyra] LocalPlayer unavailable") return end
local out={version=1,placeId=game.PlaceId,player={},character={},statRecords={},traitRecords={},equipment={},questState={},ui={},warnings={}}
local function truncate(value)
 local s=tostring(value or "")
 return #s>160 and s:sub(1,160) or s
end
local function safe(v)
 local t=typeof(v)
 if t=="number" or t=="boolean" then return v end
 if t=="string" then return truncate(v) end
 if t=="Vector3" then return {x=v.X,y=v.Y,z=v.Z} end
 if t=="CFrame" then local p=v.Position return {x=p.X,y=p.Y,z=p.Z} end
 if t=="EnumItem" then return tostring(v) end
 return t
end
local function useful(s)
 s=tostring(s):lower()
 return s:find("strength",1,true) or s:find("agil",1,true) or s:find("vital",1,true)
  or s:find("intelli",1,true) or s:find("magic",1,true)
  or s:find("enduran",1,true) or s:find("stat",1,true)
  or s:find("level",1,true) or s:find("exp",1,true)
  or s:find("trait",1,true) or s:find("skillpoint",1,true)
  or s:find("points",1,true) or s:find("profic",1,true)
  or s:find("mana",1,true) or s:find("pve",1,true)
  or s:find("damage",1,true) or s:find("race",1,true)
  or s:find("family",1,true) or s:find("grimoire",1,true)
  or s:find("weapon",1,true) or s:find("marks",1,true)
  or s:find("insight",1,true) or s:find("class",1,true)
end
local function attrs(o,restrict)
 local a={}
 for k,v in pairs(o:GetAttributes()) do
  if not restrict or useful(k) then a[truncate(k)]=safe(v) end
 end
 return a
end
out.player.attributes=attrs(player,true)
local character=player.Character
if character then
 out.character.attributes=attrs(character,true)
 for _,child in ipairs(character:GetChildren()) do
  if child:IsA("Tool") then
   table.insert(out.equipment,{source="character",name=truncate(child.Name),attributes=attrs(child,true)})
  end
 end
 local hum=character:FindFirstChildOfClass("Humanoid")
 if hum then out.character.health={max=hum.MaxHealth,current=hum.Health} end
end
local backpack=player:FindFirstChild("Backpack")
if backpack then
 for _,tool in ipairs(backpack:GetChildren()) do
  if tool:IsA("Tool") then
   table.insert(out.equipment,{source="backpack",name=truncate(tool.Name),attributes=attrs(tool,true)})
  end
  if #out.equipment>=45 then break end
 end
end
local function beneath(o,folderName)
 local parent=o
 while parent and parent~=player do
  if parent.Name==folderName then return true end
  parent=parent.Parent
 end
 return false
end
local count=0
for _,o in ipairs(player:GetDescendants()) do
 count+=1
 if beneath(o,"Quests") or beneath(o,"PlayerGui") or beneath(o,"Backpack") or (character and o:IsDescendantOf(character)) then
  -- Skip high-volume quest and UI instances, which are reported separately.
 else
  local class=o.ClassName
  local name=o.Name:lower()
  local key=useful(name)
  if class=="Folder" then
   local a=attrs(o,true)
   if next(a) and #out.statRecords<400 then
    table.insert(out.statRecords,{name=truncate(o.Name),parent=truncate(o.Parent and o.Parent.Name),attributes=a,class=class})
   end
  elseif o:IsA("ValueBase") then
   local value=safe(o.Value)
   if key or useful(o.Parent and o.Parent.Name or "") or class=="BoolValue" then
    local rec={name=truncate(o.Name),parent=truncate(o.Parent and o.Parent.Name),value=value,class=class,attributes=attrs(o,true)}
    if o:IsA("BoolValue") and (name:find("trait",1,true) or beneath(o,"Traits") or beneath(o,"UnlockedTraits")) then
     if #out.traitRecords<200 then table.insert(out.traitRecords,rec) end
    elseif #out.statRecords<400 then table.insert(out.statRecords,rec) end
   end
  end
 end
 if count%1300==0 then task.wait() end
end
out.player.descendantsScanned=count
local questFolder=player:FindFirstChild("Quests")
local indicatorFolder=player.PlayerGui:FindFirstChild("QuestIndicators")
if indicatorFolder then
 out.questState.indicators={}
 for _,indicator in ipairs(indicatorFolder:GetChildren()) do
  local status=indicator:GetAttribute("status")
  if typeof(status)=="boolean" then
   table.insert(out.questState.indicators,{id=truncate(indicator.Name),status=status,returning=indicator:GetAttribute("Return"),attributes=attrs(indicator,false)})
  end
 end
end
if questFolder and out.questState.indicators then
 out.questState.tracked={}
 for _,flag in ipairs(out.questState.indicators) do
  if flag.status then
   local q=questFolder:FindFirstChild(flag.id)
   if q then
    local rec={id=truncate(q.Name),attributes=attrs(q,false),tasks={}}
    local tasks=q:FindFirstChild("Tasks")
    if tasks then for _,t in ipairs(tasks:GetChildren()) do
     table.insert(rec.tasks,{name=truncate(t.Name),attributes=attrs(t,false)})
    end end
    table.insert(out.questState.tracked,rec)
   end
  end
 end
end
local pg=player.PlayerGui
local gameplay=pg:FindFirstChild("Gameplay")
local tracker=gameplay and gameplay:FindFirstChild("Quest")
if tracker then
 out.ui.quest={}
 for _,o in ipairs(tracker:GetDescendants()) do
  if #out.ui.quest>=250 then break end
  if (o:IsA("TextLabel") or o:IsA("TextButton")) and o.Text~="" then
   local path={}
   local at=o
   while at and at~=tracker and #path<10 do
    table.insert(path,1,truncate(at.Name))
    at=at.Parent
   end
   table.insert(out.ui.quest,{path=table.concat(path,"/"),text=truncate(o.Text),visible=o.Visible})
  end
 end
end
-- Optional stat and trait panel text: search only likely page branches, not full UI.
out.ui.statHints={}
if gameplay then
 local countGui=0
 for _,o in ipairs(gameplay:GetDescendants()) do
  if #out.ui.statHints>=80 then break end
  if o:IsA("TextLabel") and o.Text~="" then
   local parent=o.Parent
   local relevant=useful(o.Name) or (parent and useful(parent.Name))
   if relevant and (#o.Text<120) then
    table.insert(out.ui.statHints,{name=truncate(o.Name),parent=truncate(parent and parent.Name),text=truncate(o.Text)})
   end
  end
  countGui+=1
  if countGui%1400==0 then task.wait() end
 end
end
if #out.statRecords==0 then table.insert(out.warnings,"No stat ValueBase records detected; open the stat menu and rerun if needed") end
local json=http:JSONEncode(out)
local filename="Veyra_character_diagnostic.json"
if type(writefile)=="function" then
 local ok=pcall(writefile,filename,json)
 if ok then print("[Veyra] Saved "..filename..". Upload this file for a customized PvE build.") return end
end
if type(setclipboard)=="function" and pcall(setclipboard,json) then
 print("[Veyra] Character diagnostic copied to clipboard.")
 return
end
warn("[Veyra] No file/clipboard support; console JSON follows:")
for i=1,#json,1600 do print(json:sub(i,i+1599)) end
