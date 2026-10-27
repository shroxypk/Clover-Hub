-- Veyra Quest Diagnostic: READ ONLY. Run in Clover RPG with quests tracked.
-- Exports objective metadata and nearby world matches; does not fire remotes,
-- complete quests, modify objects, or upload data anywhere.
local Players=game:GetService("Players")
local HTTP=game:GetService("HttpService")
local RS=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
if not player then warn("[Veyra] No LocalPlayer") return end
local output={version=1,placeId=game.PlaceId,quests={},tracked={},worldMatches={},registryHints={},warnings={}}
local function clip(s)
 s=tostring(s or "")
 return #s>200 and s:sub(1,200) or s
end
local function safe(v)
 local kind=typeof(v)
 if kind=="string" then return clip(v) end
 if kind=="number" or kind=="boolean" then return v end
 if kind=="Vector3" then return {x=v.X,y=v.Y,z=v.Z} end
 if kind=="CFrame" then local p=v.Position return {x=p.X,y=p.Y,z=p.Z} end
 if kind=="Instance" then return {name=clip(v.Name),class=v.ClassName} end
 if kind=="EnumItem" then return tostring(v) end
 return clip(kind)
end
local function attrs(o)
 local out={}
 for k,v in pairs(o:GetAttributes()) do
  if #tostring(k)<=100 then out[k]=safe(v) end
 end
 return out
end
local function children(o,maxCount)
 local out={}
 if not o then return out end
 for _,child in ipairs(o:GetChildren()) do
  if #out>=(maxCount or 60) then break end
  table.insert(out,child)
 end
 return out
end
local wanted={}
local function normalize(s)
 return tostring(s or ""):lower():gsub(" respawnable$",""):gsub("[^%w]","")
end
local function want(name)
 if type(name)~="string" then return end
 local n=name:gsub("^the ",""):gsub("^a ",""):gsub("^an ","")
 local k=normalize(n)
 if #k>2 and #k<80 then
  wanted[k]=n
  if k:sub(-1)=="s" then wanted[k:sub(1,-2)]=n end
 end
end
local function described(o)
 return {name=clip(o.Name),class=o.ClassName,attributes=attrs(o)}
end
local questFolder=player:FindFirstChild("Quests")
if not questFolder then table.insert(output.warnings,"LocalPlayer.Quests was missing") end
for _,q in ipairs(children(questFolder,250)) do
 local entry=described(q)
 entry.tasks={} entry.objects={}
 want(q:GetAttribute("ReturnNPC"))
 local tasks=q:FindFirstChild("Tasks")
 for _,taskObject in ipairs(children(tasks,100)) do
  local taskEntry=described(taskObject)
  if taskObject:IsA("ValueBase") then taskEntry.value=safe(taskObject.Value) end
  taskEntry.children={}
  for _,c in ipairs(children(taskObject,24)) do
   local e=described(c)
   if c:IsA("ValueBase") then e.value=safe(c.Value) end
   table.insert(taskEntry.children,e)
  end
  for _,key in ipairs({"Object","NPC","Target","TargetNPC","TargetName","Location"}) do
   want(taskObject:GetAttribute(key))
  end
  local name=taskObject.Name:match("^[Tt]alk to (.+)") or taskObject.Name:match("^[Ss]peak to (.+)")
   or taskObject.Name:match("^[Ff]ind (.+)") or taskObject.Name:match("^[Gg]ather (.+)")
   or taskObject.Name:match("^[Cc]ollect (.+)") or taskObject.Name:match("^[Rr]eturn to (.+)")
   or taskObject.Name:match("^[Dd]eliver .- to (.+)") or taskObject.Name:match("^[Ll]ight (.+)")
  if name then want(name) end
  table.insert(entry.tasks,taskEntry)
 end
 local objects=q:FindFirstChild("Objects")
 for _,c in ipairs(children(objects,80)) do
  local e=described(c)
  if c:IsA("ValueBase") then e.value=safe(c.Value) end
  table.insert(entry.objects,e)
  want(c.Name)
 end
 table.insert(output.quests,entry)
end
local gameplay=player.PlayerGui:FindFirstChild("Gameplay")
local questUI=gameplay and gameplay:FindFirstChild("Quest")
local tracking=questUI and questUI:FindFirstChild("Tracking")
local tracked=tracking and tracking:FindFirstChild("Quests")
if not tracked then table.insert(output.warnings,"Gameplay.Quest.Tracking.Quests was missing") end
for _,row in ipairs(children(tracked,80)) do
 local e=described(row)
 if row:IsA("GuiObject") then e.visible=row.Visible end
 e.text={}
 for _,d in ipairs(row:GetDescendants()) do
  if #e.text>=12 then break end
  if d:IsA("TextLabel") or d:IsA("TextButton") then
   if d.Text~="" then table.insert(e.text,clip(d.Text)) end
  end
 end
 table.insert(output.tracked,e)
end
-- Only inspect names of potentially quest-related shared definitions.
for _,o in ipairs(RS:GetDescendants()) do
 if #output.registryHints>=120 then break end
 if o:IsA("ModuleScript") or o:IsA("Folder") then
  local name=o.Name:lower()
  local par=o.Parent and o.Parent.Name:lower() or ""
  if name:find("quest",1,true) or name:find("objective",1,true)
   or par:find("quest",1,true) then
   table.insert(output.registryHints,{name=clip(o.Name),parent=clip(o.Parent and o.Parent.Name),class=o.ClassName})
  end
 end
end
local count=0
for _,o in ipairs(workspace:GetDescendants()) do
 if (o:IsA("Model") or o:IsA("BasePart")) and (not o.Parent or not o.Parent:IsA("Model") or o:IsA("Model")) then
  local key=normalize(o.Name)
  if wanted[key] then
   local playerCharacter=false
   local parent=o
   for _=1,4 do
    if not parent then break end
    if parent:IsA("Model") and Players:GetPlayerFromCharacter(parent) then playerCharacter=true break end
    parent=parent.Parent
   end
   if not playerCharacter then
    local bucket=output.worldMatches[key]
    if not bucket then bucket={query=wanted[key],total=0,examples={}} output.worldMatches[key]=bucket end
    bucket.total+=1
    if #bucket.examples<12 then
     local pos=o:IsA("BasePart") and o.Position or o:GetPivot().Position
     table.insert(bucket.examples,{name=clip(o.Name),class=o.ClassName,
      position={x=math.floor(pos.X*10+0.5)/10,y=math.floor(pos.Y*10+0.5)/10,z=math.floor(pos.Z*10+0.5)/10},
      attributes=attrs(o)})
    end
   end
  end
 end
 count+=1
 if count%1000==0 then task.wait() end
end
output.worldObjectsScanned=count
output.queries=0
for _ in pairs(wanted) do output.queries+=1 end
local json=HTTP:JSONEncode(output)
local name="Veyra_quest_diagnostic.json"
if type(writefile)=="function" then
 local ok,err=pcall(writefile,name,json)
 if ok then print("[Veyra] Quest diagnostic saved as "..name.." ("..#json.." bytes). Upload the file here.") return end
 warn("[Veyra] File save failed: "..tostring(err))
end
if type(setclipboard)=="function" then
 local ok=pcall(setclipboard,json)
 if ok then print("[Veyra] Diagnostic copied to clipboard. Paste it into a text file and upload.") return end
end
warn("[Veyra] No writefile or clipboard. Copy these console lines in order:")
for i=1,#json,1600 do print(json:sub(i,i+1599)) end
