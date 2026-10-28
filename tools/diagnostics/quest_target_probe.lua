-- Read-only targeted quest-object probe for false-positive location markers.
-- Does not send inputs, remotes, modify objects, or collect player/account IDs.
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local player=Players.LocalPlayer
if not player then return warn("[Veyra] No player") end
local questId=getgenv().VeyraQuestAssist and getgenv().VeyraQuestAssist.selected
local folder=player:FindFirstChild("Quests")
if not folder or not questId then
 return warn("[Veyra] Enable Quest Assistance and track a quest first")
end
local quest
for _,q in ipairs(folder:GetChildren()) do
 if q:FindFirstChild("Tasks") and (q.Name==questId or q:GetAttribute("Quest")==questId) then
  quest=q break
 end
end
if not quest then return warn("[Veyra] Active quest record unavailable") end
local character=player.Character
local root=character and character:FindFirstChild("HumanoidRootPart")
local limit=75000
local function clip(value,max) return tostring(value or ""):sub(1,max or 100) end
local function vector(value)
 if typeof(value)=="CFrame" then return value.Position end
 if typeof(value)=="Vector3" then return value end
end
local function posOf(o)
 if o:IsA("BasePart") then return o.Position end
 if o:IsA("Model") then return o:GetPivot().Position end
 if o:IsA("Attachment") then return o.WorldPosition end
 if o.Parent and o.Parent:IsA("Attachment") then return o.Parent.WorldPosition end
 if o.Parent and o.Parent:IsA("BasePart") then return o.Parent.Position end
 if o.Parent and o.Parent:IsA("Model") then return o.Parent:GetPivot().Position end
end
local function samplePosition(position,origin)
 if not position or not origin then return nil end
 local relative=position-origin
 return {distance=math.floor(relative.Magnitude+0.5),
  x=math.floor(relative.X+0.5),y=math.floor(relative.Y+0.5),z=math.floor(relative.Z+0.5)}
end
local function isOtherCharacter(o)
 local at=o
 while at and at~=workspace do
  if at:IsA("Model") and Players:GetPlayerFromCharacter(at) then return true end
  at=at.Parent
 end
 return false
end
local function readableAttributes(o)
 local result={}
 for k,v in pairs(o:GetAttributes()) do
  if (k:lower():find("quest",1,true) or k:lower():find("hint",1,true)
   or k:lower():find("task",1,true) or k:lower():find("gather",1,true)
   or k:lower():find("interact",1,true) or k:lower():find("hidden",1,true)
   or k:lower():find("object",1,true))
   and (type(v)=="string" or type(v)=="number" or type(v)=="boolean") then
   result[clip(k,50)]=type(v)=="string" and clip(v,120) or v
  end
 end
 return result
end
local report={version=1,quest=clip(questId),description=clip(quest:GetAttribute("QuestDescription") or quest:GetAttribute("Tip"),350),
 tasks={},questObjects={},scopedWorldObjects={},candidateObjects={},interactions={},nearHints={},limits={},notes={}}
local hints={}
local taskFolder=quest:FindFirstChild("Tasks")
for _,t in ipairs(taskFolder:GetChildren()) do
 if #report.tasks>=50 then break end
 local hint=vector(t:GetAttribute("TrackPosition"))
 local key=clip(t.Name)
 local max=tonumber(t:GetAttribute("TaskMax")) or 1
 local progress=tonumber(t:GetAttribute("TaskProgress")) or 0
 table.insert(report.tasks,{name=key,current=progress,maximum=max,
  object=clip(t:GetAttribute("Object")),type=clip(t:GetAttribute("TaskType")),
  hasTrackPosition=hint~=nil,
  trackPositionRelativeToPlayer=samplePosition(hint,root and root.Position)})
 if hint then table.insert(hints,{name=key,pos=hint}) end
end
local objects=quest:FindFirstChild("Objects")
if objects then
 for _,o in ipairs(objects:GetChildren()) do
  if #report.questObjects>=100 then break end
  table.insert(report.questObjects,{name=clip(o.Name),class=o.ClassName,
   value=(o:IsA("BoolValue") or o:IsA("IntValue") or o:IsA("NumberValue")) and o.Value or nil,
   attributes=readableAttributes(o)})
 end
end
local function relativeToHint(p)
 if not p or #hints==0 then return nil end
 local best,bestName
 for _,h in ipairs(hints) do
  local d=(p-h.pos).Magnitude
  if not best or d<best then best=d bestName=h.name end
 end
 return {distance=math.floor(best+0.5),task=clip(bestName)}
end
-- Inspect the authoritative quest-object groups separately from the
-- broad name-search list: a 130-result cap must not hide Lantern2, etc.
local wsObjects=workspace:FindFirstChild("Objects")
local qsObjects=wsObjects and wsObjects:FindFirstChild("QuestObjects")
if qsObjects then
 for _,task in ipairs(report.tasks) do
  local plural=task.name:match("([%a]+)$")
  if plural then
   for _,group in ipairs(qsObjects:GetChildren()) do
    if group.Name:lower()==plural:lower() then
     for _,o in ipairs(group:GetChildren()) do
      if #report.scopedWorldObjects>=100 then break end
      local prompt=o:FindFirstChildWhichIsA("ProximityPrompt",true)
      table.insert(report.scopedWorldObjects,{
       group=clip(group.Name),name=clip(o.Name),class=o.ClassName,
       fromPlayer=samplePosition(posOf(o),root and root.Position),
       nearestTaskHint=relativeToHint(posOf(o)),
       hasPrompt=prompt~=nil,promptEnabled=prompt and prompt.Enabled or false,
       attributes=readableAttributes(o)
      })
     end
    end
   end
  end
 end
end
local matches={"lantern","lamp","statue","uxie","coffee","scatter","missing"}
local function candidateName(name)
 local n=name:lower()
 for _,k in ipairs(matches) do if n:find(k,1,true) then return true end end
 return false
end
local prompts,models,partCandidates=0,0,0
local scanned=0
for _,o in ipairs(workspace:GetDescendants()) do
 scanned+=1
 if scanned>limit then table.insert(report.notes,"Workspace scan capped") break end
 if not isOtherCharacter(o) and o:IsA("ProximityPrompt") then
  prompts+=1
  local pos=posOf(o)
  local at=o.Parent
  local path={}
  while at and at~=workspace and #path<4 do
   table.insert(path,1,clip(at.Name,80))
   at=at.Parent
  end
  local text=clip(o.ActionText.." "..o.ObjectText,130)
  local near=relativeToHint(pos)
  local relevant=candidateName(text.." "..table.concat(path," ")) or (near and near.distance<=120)
  if relevant and #report.interactions<130 then
   table.insert(report.interactions,{name=clip(o.Name),action=clip(o.ActionText),
    object=clip(o.ObjectText),enabled=o.Enabled,
    parentChain=table.concat(path," / "),
    fromPlayer=samplePosition(pos,root and root.Position),
    nearestTaskHint=relativeToHint(pos)})
  end
 elseif not isOtherCharacter(o) and (o:IsA("Model") or o:IsA("BasePart")) then
  if o:IsA("Model") then models+=1 end
  local isCandidate=candidateName(o.Name)
  local attrs=readableAttributes(o)
  if next(attrs) then
   local qi=tostring(attrs.HintQuest or "")
   if qi==questId or qi==quest:GetAttribute("Quest") then isCandidate=true end
  end
  if isCandidate and #report.candidateObjects<130 then
   local pos=posOf(o)
   table.insert(report.candidateObjects,{name=clip(o.Name),class=o.ClassName,
    parent=clip(o.Parent and o.Parent.Name),attributes=attrs,
    hasPrompt=o:FindFirstChildWhichIsA("ProximityPrompt",true)~=nil,
    fromPlayer=samplePosition(pos,root and root.Position),
    nearestTaskHint=relativeToHint(pos)})
   partCandidates+=1
  end
 end
 if scanned%3000==0 then task.wait() end
end
report.limits={scanned=scanned,totalPrompts=prompts,models=models,candidateCount=partCandidates,
 candidateListTruncated=#report.candidateObjects>=130,interactionListTruncated=#report.interactions>=130}
report.notes[ #report.notes+1]="All positions are offsets from your avatar or quest hint, not absolute coordinates."
report.notes[ #report.notes+1]="Matching names and prompts are candidates; they do not prove a quest item."
local json=HttpService:JSONEncode(report)
local file="Veyra_quest_target_probe.json"
if type(writefile)=="function" and pcall(writefile,file,json) then
 print("[Veyra Target Probe] Saved "..file.." ("..#json.." bytes). Share after reviewing.")
elseif type(setclipboard)=="function" and pcall(setclipboard,json) then
 print("[Veyra Target Probe] JSON copied to clipboard; paste it into ChatGPT.")
else
 for i=1,#json,1600 do print("[Veyra Target Probe] "..json:sub(i,i+1599)) end
end
return report
