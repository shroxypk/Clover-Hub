-- Veyra XP Lab: read-only profession reward timing recorder.
-- Only observes local replicated values, UI labels and explicit manual annotations.
-- No remote interception, calls, modified XP, anti-cheat bypass or network upload.
local P=game:GetService("Players").LocalPlayer
local J=game:GetService("HttpService")
local G=getgenv()
if G.VeyraXPLab and G.VeyraXPLab.stop then G.VeyraXPLab.stop("restart") end
local root=P:WaitForChild("Professions",8)
if not root then warn("[VeyraXPLab] Player.Professions missing") return end
local names={"Alchemy","Crafting","Harvesting","Mining","Combat","Broom Flying"}
local lab={running=true,events={},connections={},started=os.clock(),session=os.time(),version=1,cap=1500}
G.VeyraXPLab=lab
local function record(kind,data)
 if not lab.running or #lab.events>=lab.cap then return end
 table.insert(lab.events,{elapsed=math.floor((os.clock()-lab.started)*1000)/1000,kind=kind,data=data})
end
local function slim(v)
 local t=typeof(v)
 if t=="string" then return v:sub(1,115) end
 if t=="number" or t=="boolean" then return v end
 return tostring(v):sub(1,75)
end
local function connect(signal,handler)
 table.insert(lab.connections,signal:Connect(handler))
end
local function values()
 local x={}
 for _,name in ipairs(names) do
  local level=root:FindFirstChild(name)
  local xp=root:FindFirstChild(name.."XP")
  local max=root:FindFirstChild(name.."MXP")
  x[name]={level=level and level.Value,xp=xp and xp.Value,nextXP=max and max.Value}
 end
 return x
end
lab.initial=values()
local function snapshot(reason)
 record("snapshot",{reason=reason,professions=values()})
end
function lab.mark(label,details)
 record("userMark",{label=slim(label or "action"),details=slim(details or "")})
 print("[VeyraXPLab] MARK "..tostring(label))
end
function lab.snapshot(label) snapshot(label or "manual") end
for _,name in ipairs(names) do
 for _,suffix in ipairs({"","XP","MXP"}) do
  local item=root:FindFirstChild(name..suffix)
  if item and item:IsA("ValueBase") then
   local old=item.Value
   connect(item.Changed,function(new)
    if typeof(new)=="Instance" then new=item.Value end
    if new~=old then
     record("professionChanged",{profession=name,field=suffix=="" and "level" or suffix,value=slim(new),previous=slim(old),delta=type(new)=="number" and type(old)=="number" and new-old or nil})
     old=new
    end
   end)
  end
 end
end
local ui=P:FindFirstChildOfClass("PlayerGui")
local clues={"HarvestRings","MiningRings","MineRings","AlchemyUI","CraftingUI","CraftUI"}
local function watchLabel(o)
 if not (o:IsA("TextLabel") or o:IsA("TextButton")) then return end
 local owner=o
 local inScope=false
 for _=1,8 do
  if not owner then break end
  for _,name in ipairs(clues) do if owner.Name==name then inScope=true break end end
  if inScope then break end
  owner=owner.Parent
 end
 if not inScope then return end
 local name=o.Name:lower()
 if name~="result" and name~="title" and name~="power" and name~="status" and name~="header" and name~="amount" and name~="xp" and name~="label" then return end
 local old=o.Text
 connect(o:GetPropertyChangedSignal("Text"),function()
  local new=o.Text
  if new~=old then
   record("uiText",{screen=owner and owner.Name or "",label=o.Name,text=slim(new)})
   old=new
  end
 end)
end
if ui then
 for _,o in ipairs(ui:GetDescendants()) do watchLabel(o) end
 connect(ui.DescendantAdded,watchLabel)
end
-- Capture broad client-visible API names without touching remote objects.
local RS=game:GetService("ReplicatedStorage")
lab.moduleCandidates={}
for _,o in ipairs(RS:GetDescendants()) do
 if o:IsA("ModuleScript") and #lab.moduleCandidates<90 then
  local low=o.Name:lower()
  if low:find("profession") or low:find("craft") or low:find("alchemy") or low:find("xp")
    or low:find("harvest") or low:find("mining") or low:find("combat") then
   table.insert(lab.moduleCandidates,o:GetFullName():sub(1,220))
  end
 end
end
snapshot("start")
function lab.stop(reason)
 if not lab.running then return end
 snapshot(reason or "stop")
 lab.running=false
 for _,c in ipairs(lab.connections) do c:Disconnect() end
 table.clear(lab.connections)
 local output={version=lab.version,placeId=game.PlaceId,session=lab.session,initial=lab.initial,final=values(),moduleCandidates=lab.moduleCandidates,events=lab.events,notes="Local read-only observation; XP changes alone cannot prove server award errors. No remote or anti-cheat interception."}
 local filename="Veyra_xp_lab_"..lab.session..".json"
 local json=J:JSONEncode(output)
 if type(writefile)=="function" and pcall(writefile,filename,json) then
  print("[VeyraXPLab] Saved "..filename.." ("..#lab.events.." events)")
 elseif type(setclipboard)=="function" and pcall(setclipboard,json) then
  print("[VeyraXPLab] Copied results to clipboard")
 else
  for i=1,#json,1500 do print(json:sub(i,i+1499)) end
 end
 if G.VeyraXPLab==lab then G.VeyraXPLab=nil end
end
print("[VeyraXPLab] Recording. Mark actions: getgenv().VeyraXPLab.mark('Brew', 'Minor Vitality x5')")
print("[VeyraXPLab] When finished: getgenv().VeyraXPLab.stop()")
