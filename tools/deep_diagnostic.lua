-- Veyra Deep Diagnostic: read-only profession/progression capture.
-- Automatically saves during the session. No remotes, hooks, bytecode dumps, or XP changes.
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local RS=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local global=getgenv()
if global.VeyraDeepDiagnostic and global.VeyraDeepDiagnostic.stop then
 global.VeyraDeepDiagnostic.stop("restarted")
end
local profile=player:FindFirstChild("Professions") or player:WaitForChild("Professions",10)
if not profile then warn("[VeyraDeep] Professions folder unavailable") return end
local names={"Mining","Harvesting","Alchemy","Crafting","Combat","Broom Flying"}
local started=os.clock()
local epoch=os.time()
local baseName="Veyra_deep_diagnostic_"..epoch..".json"
local d={active=true,connections={},events={},session=epoch,limit=1500}
global.VeyraDeepDiagnostic=d
local function short(v,limit)
 local t=typeof(v)
 if t=="number" or t=="boolean" then return v end
 if t=="string" then return v:sub(1,limit or 120) end
 if t=="Vector3" then return {x=v.X,y=v.Y,z=v.Z} end
 return nil
end
local function attrs(o)
 local a={}
 for k,v in pairs(o:GetAttributes()) do
  local s=short(v)
  if s~=nil then a[tostring(k):sub(1,70)]=s end
 end
 return a
end
local function event(kind,detail)
 if not d.active or #d.events>=d.limit then return end
 table.insert(d.events,{t=math.floor((os.clock()-started)*100)/100,kind=kind,detail=detail})
end
local function connect(sig,fn)
 table.insert(d.connections,sig:Connect(fn))
end
local function stats()
 local result={}
 for _,name in ipairs(names) do
  local row={}
  for _,suffix in ipairs({"","XP","MXP"}) do
   local v=profile:FindFirstChild(name..suffix)
   if v and v:IsA("ValueBase") then row[suffix=="" and "level" or suffix]=short(v.Value) end
  end
  result[name]=row
 end
 return result
end
d.initial=stats()
local function path(o)
 local parts={}
 for i=1,8 do
  if not o then break end
  table.insert(parts,1,o.Name)
  o=o.Parent
 end
 return table.concat(parts,"."):sub(1,210)
end
-- Inventory + profession configuration visible to the client, capped for size.
local info={placeId=game.PlaceId,started=epoch,professionValues={},moduleIndex={},clientScripts={},uiInitial={},attributes={},hints={}}
for _,child in ipairs(profile:GetChildren()) do
 if child:IsA("ValueBase") then
  table.insert(info.professionValues,{name=child.Name,value=short(child.Value,300),attributes=attrs(child)})
 elseif next(child:GetAttributes()) then
  table.insert(info.professionValues,{name=child.Name,attributes=attrs(child)})
 end
end
local pf=player:FindFirstChild("PlayerFolder")
if pf then
 for k,v in pairs(attrs(pf)) do
  if tostring(k):lower():find("xp") or tostring(k):lower():find("level") or tostring(k):lower():find("point") then
   info.attributes[k]=v
  end
 end
end
local function relevant(n)
 n=n:lower()
 return n:find("profession",1,true) or n:find("mining",1,true)
 or n:find("harvest",1,true) or n:find("craft",1,true)
 or n:find("alchemy",1,true) or n:find("combat",1,true)
 or n:find("broom",1,true) or n:find("potion",1,true)
 or n:find("exp",1,true) or n:find("level",1,true)
 or n:find("recipe",1,true) or n:find("reward",1,true)
end
local scan=0
for _,o in ipairs(RS:GetDescendants()) do
 if relevant(o.Name) or relevant(o.Parent and o.Parent.Name or "") then
  if o:IsA("ModuleScript") and #info.moduleIndex<280 then
   table.insert(info.moduleIndex,{path=path(o),attributes=attrs(o)})
  elseif o:IsA("ValueBase") and #info.professionValues<350 then
   table.insert(info.professionValues,{name=path(o),value=short(o.Value),attributes=attrs(o)})
  end
 end
 scan+=1
 if scan%1000==0 then task.wait() end
end
local gui=player:FindFirstChildOfClass("PlayerGui")
local function uiRelevant(o)
 local p=o
 for _=1,8 do
  if not p then return false end
  if relevant(p.Name) then return true end
  p=p.Parent
 end
 return false
end
local uiSeen={}
local function noteLabel(o)
 if not (o:IsA("TextLabel") or o:IsA("TextButton")) or not uiRelevant(o) then return end
 if #info.uiInitial<300 and o.Text~="" then
  table.insert(info.uiInitial,{path=path(o),text=short(o.Text),visible=o.Visible})
 end
 -- Log only actual changes rather than polling entire GUI continuously.
 if #d.connections>=650 then return end
 local old=o.Text
 connect(o:GetPropertyChangedSignal("Text"),function()
  local value=o.Text
  if value~=old then
   if relevant(o.Name) or relevant(o.Parent and o.Parent.Name or "") or o.Name=="Result" or o.Name=="Power" then
    event("ui",{path=path(o),text=short(value)})
   end
   old=value
  end
 end)
end
if gui then
 for _,o in ipairs(gui:GetDescendants()) do
  if o:IsA("LocalScript") and uiRelevant(o) and #info.clientScripts<120 then
   table.insert(info.clientScripts,path(o))
  end
  noteLabel(o)
 end
 connect(gui.DescendantAdded,function(o)
  if o:IsA("LocalScript") and uiRelevant(o) and #info.clientScripts<120 then
   table.insert(info.clientScripts,path(o))
  end
  noteLabel(o)
 end)
end
for _,name in ipairs(names) do
 for _,suffix in ipairs({"","XP","MXP"}) do
  local o=profile:FindFirstChild(name..suffix)
  if o and o:IsA("ValueBase") then
   local prev=o.Value
   connect(o.Changed,function()
    local nextVal=o.Value
    if nextVal~=prev then
     event("progress",{profession=name,field=suffix=="" and "level" or suffix,old=short(prev),new=short(nextVal),delta=type(prev)=="number" and type(nextVal)=="number" and (nextVal-prev) or nil})
     prev=nextVal
    end
   end)
  end
 end
end
local function save()
 local out={info=info,events=d.events,initial=d.initial,current=stats(),
  elapsed=math.floor((os.clock()-started)*100)/100,
  notes="Read-only replicated data. No server-only scripts, packet contents or hidden award rules are available."}
 local ok,json=pcall(function()return Http:JSONEncode(out) end)
 if not ok then warn("[VeyraDeep] JSON encode failed: "..tostring(json)) return end
 if type(writefile)=="function" then
  local success=pcall(writefile,baseName,json)
  if success then return end
 end
 if type(setclipboard)=="function" then
  pcall(setclipboard,json)
  return
 end
 print("[VeyraDeep] Executor lacks writefile/setclipboard; output follows")
 for i=1,#json,1400 do print(json:sub(i,i+1399)) end
end
function d.stop(reason)
 if not d.active then return end
 event("session",{reason=reason or "manual stop"})
 save()
 d.active=false
 for _,c in ipairs(d.connections) do c:Disconnect() end
 table.clear(d.connections)
 if global.VeyraDeepDiagnostic==d then global.VeyraDeepDiagnostic=nil end
 print("[VeyraDeep] Finished. File: "..baseName)
end
save()
print("[VeyraDeep] Recording automatically for 3 minutes. File: "..baseName)
task.spawn(function()
 local last=0
 while d.active and os.clock()-started<180 do
  task.wait(3)
  local elapsed=os.clock()-started
  if elapsed-last>=15 then
   last=elapsed
   save()
  end
 end
 if d.active then d.stop("three minute capture complete") end
end)
