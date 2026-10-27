-- Veyra mechanics study: passive client-side state and movement recording.
-- No remote calls, script decompilation, hook installation, or character edits.
-- Run during normal movement/combat. Saves a bounded JSON report to Madium.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Http=game:GetService("HttpService")
local player=Players.LocalPlayer
if not player then warn("[Veyra] No local player") return end
local global=getgenv()
if global.VeyraMechanicsProbe and global.VeyraMechanicsProbe.stop then
 pcall(global.VeyraMechanicsProbe.stop,"restarted")
end
local PERIOD=35
local filename="Veyra_mechanics_probe_"..tostring(os.time())..".json"
local started=os.clock()
local probe={active=true,connections={},characterConnections={},events={},samples={},limit=1000}
global.VeyraMechanicsProbe=probe
local report={
 version=1,placeId=game.PlaceId,startedAt=os.time(),
 modules={},localScripts={},values={},initial={},
 events=probe.events,samples=probe.samples,
 notes="Only local and replicated client-visible state. No evidence of server acceptance or vulnerability by itself."
}
local function scalar(value)
 local t=typeof(value)
 if t=="number" then
  if value~=value or math.abs(value)>1e12 then return nil end
  return math.floor(value*1000+0.5)/1000
 elseif t=="boolean" then return value
 elseif t=="string" then return value:sub(1,110)
 elseif t=="EnumItem" then return tostring(value)
 elseif t=="Vector3" then
  return {x=math.floor(value.X*100)/100,y=math.floor(value.Y*100)/100,z=math.floor(value.Z*100)/100}
 end
 return nil
end
local function relevant(k)
 k=tostring(k):lower()
 for _,word in ipairs({"speed","walk","jump","dash","dodge","sprint","fly","flying",
  "stamina","energy","mana","combat","attack","block","parry","cooldown","state",
  "skill","cast","spell","stun","ragdoll","occupied","weapon","guard","shield",
  "knock","force","velocity","gravity","endurance","charge","invulner","iframe"}) do
  if k:find(word,1,true) then return true end
 end
 return false
end
local function attrs(obj)
 local a={}
 if not obj then return a end
 local n=0
 for k,v in pairs(obj:GetAttributes()) do
  if relevant(k) and n<130 then
   local s=scalar(v)
   if s~=nil then a[k]=s n+=1 end
  end
 end
 return a
end
local function addEvent(kind,detail)
 if not probe.active or #report.events>=probe.limit then return end
 table.insert(report.events,{t=math.floor((os.clock()-started)*100)/100,kind=kind,data=detail})
end
local function connect(signal,callback,isCharacter)
 local c=signal:Connect(callback)
 table.insert(isCharacter and probe.characterConnections or probe.connections,c)
 return c
end
local function localPath(obj,root)
 local p={}
 local steps=0
 while obj and obj~=root and steps<12 do
  table.insert(p,1,obj.Name)
  obj=obj.Parent steps+=1
 end
 if obj~=root then return nil end
 return table.concat(p,"/"):sub(1,190)
end
local function captureTool(char)
 local tool=char and char:FindFirstChildOfClass("Tool")
 if not tool then return nil end
 return {name=tool.Name:sub(1,90),attributes=attrs(tool)}
end
local function captureMotion()
 local c=player.Character
 local h=c and c:FindFirstChildOfClass("Humanoid")
 local root=c and c:FindFirstChild("HumanoidRootPart")
 local rec={t=math.floor((os.clock()-started)*100)/100}
 if h then
  rec.health=scalar(h.Health)
  rec.walkSpeed=scalar(h.WalkSpeed)
  rec.jumpPower=scalar(h.JumpPower)
  rec.jumpHeight=scalar(h.JumpHeight)
  rec.useJumpPower=h.UseJumpPower
  rec.humanoidState=tostring(h:GetState())
  rec.floor=tostring(h.FloorMaterial)
  rec.moveInput=scalar(h.MoveDirection.Magnitude)
 end
 if root then
  local v=root.AssemblyLinearVelocity
  rec.horizontalSpeed=scalar(Vector3.new(v.X,0,v.Z).Magnitude)
  rec.verticalSpeed=scalar(v.Y)
  rec.anchored=root.Anchored
  rec.rootAttributes=attrs(root)
  local lv=root:FindFirstChildWhichIsA("LinearVelocity",true)
  if lv then
   rec.linearVelocity={name=lv.Name:sub(1,80),enabled=lv.Enabled,
    relativeTo=tostring(lv.RelativeTo),vector=scalar(lv.VectorVelocity)}
  end
 end
 if c then
  rec.characterAttributes=attrs(c)
  rec.equipped=captureTool(c)
 end
 local hub=global.VeyraController
 if hub then rec.veyraBroomMultiplier=hub.broomSpeed end
 return rec
end
local watchedValues={}
local function attachValue(obj)
 if watchedValues[obj] or not obj:IsA("ValueBase") then return end
 if not relevant(obj.Name) and not relevant(obj.Parent and obj.Parent.Name or "") then return end
 if #report.values>=180 then return end
 watchedValues[obj]=true
 local label=localPath(obj,player)
 if not label then return end
 local v=scalar(obj.Value)
 table.insert(report.values,{path=label,class=obj.ClassName,value=v,attributes=attrs(obj)})
 local previous=v
 connect(obj.Changed,function()
  local cur=scalar(obj.Value)
  if cur~=previous then
   addEvent("value",{path=label,old=previous,new=cur})
   previous=cur
  end
 end)
end
local function clearCharacter()
 for _,conn in ipairs(probe.characterConnections) do conn:Disconnect() end
 table.clear(probe.characterConnections)
end
local function observeAttributes(obj,label)
 if not obj then return end
 connect(obj.AttributeChanged,function(name)
  if relevant(name) then
   addEvent("attribute",{object=label,key=name,value=scalar(obj:GetAttribute(name))})
  end
 end,true)
end
local function characterAdded(c)
 clearCharacter()
 addEvent("character",{phase=c and "appeared" or "missing"})
 if not c then return end
 observeAttributes(c,"Character")
 local hum=c:FindFirstChildOfClass("Humanoid")
 local root=c:FindFirstChild("HumanoidRootPart")
 observeAttributes(hum,"Humanoid")
 observeAttributes(root,"HumanoidRootPart")
 if hum then
  connect(hum.StateChanged,function(old,new)
   addEvent("humanoidState",{from=tostring(old),to=tostring(new)})
  end,true)
 end
 connect(c.ChildAdded,function(obj)
  if obj:IsA("Tool") then
   addEvent("toolEquipped",{name=obj.Name:sub(1,90),attributes=attrs(obj)})
   observeAttributes(obj,"EquippedTool")
  end
 end,true)
 connect(c.ChildRemoved,function(obj)
  if obj:IsA("Tool") then addEvent("toolUnequipped",{name=obj.Name:sub(1,90)}) end
 end,true)
 local tool=c:FindFirstChildOfClass("Tool")
 observeAttributes(tool,"EquippedTool")
end
report.initial.playerAttributes=attrs(player)
report.initial.motion=captureMotion()
report.initial.characterAttributes=attrs(player.Character)
report.initial.tool=captureTool(player.Character)
characterAdded(player.Character)
connect(player.CharacterAdded,characterAdded)
observeAttributes(player,"LocalPlayer")
-- Scan only replicated module names, not their executable contents.
task.spawn(function()
 local count=0
 for _,obj in ipairs(RS:GetDescendants()) do
  if not probe.active then return end
  if obj:IsA("ModuleScript") and (relevant(obj.Name) or (obj.Parent and relevant(obj.Parent.Name)))
   and #report.modules<240 then
   table.insert(report.modules,{path=localPath(obj,RS),attributes=attrs(obj)})
  end
  count+=1
  if count%900==0 then task.wait() end
 end
 addEvent("moduleScan",{scanned=count,matched=#report.modules})
end)
task.spawn(function()
 local roots={player:FindFirstChild("PlayerScripts"),player:FindFirstChild("PlayerGui")}
 for _,root in ipairs(roots) do
  if root then
   local n=0
   for _,obj in ipairs(root:GetDescendants()) do
    if not probe.active then return end
    if obj:IsA("LocalScript") and
     (relevant(obj.Name) or relevant(obj.Parent and obj.Parent.Name or "")) and
     #report.localScripts<160 then
     table.insert(report.localScripts,{root=root.Name,path=localPath(obj,root)})
    end
    n+=1
    if n%900==0 then task.wait() end
   end
  end
 end
end)
task.spawn(function()
 local n=0
 for _,obj in ipairs(player:GetDescendants()) do
  if not probe.active then return end
  if obj:IsA("ValueBase") and not obj:IsDescendantOf(player.PlayerGui) then
   attachValue(obj)
  end
  n+=1
  if n%900==0 then task.wait() end
 end
 addEvent("valueScan",{scanned=n,matched=#report.values})
end)
connect(player.DescendantAdded,function(obj)
 if obj:IsA("ValueBase") and not obj:IsDescendantOf(player.PlayerGui) then
  attachValue(obj)
 end
end)
local accumulator=0
connect(RunService.Heartbeat,function(dt)
 if not probe.active then return end
 accumulator+=dt
 if accumulator>=0.25 then
  accumulator=0
  if #report.samples<180 then
   local s=captureMotion()
   s.frameDelta=scalar(dt)
   table.insert(report.samples,s)
  end
 end
end)
function probe.mark(note)
 addEvent("mark",{note=tostring(note or ""):sub(1,100)})
end
local function save(final)
 report.elapsed=math.floor((os.clock()-started)*100)/100
 report.initial.ended=captureMotion()
 report.eventCount=#report.events
 local ok,encoded=pcall(function() return Http:JSONEncode(report) end)
 if not ok then warn("[Veyra mechanics] JSON error: "..tostring(encoded)) return end
 if type(writefile)=="function" then
  local worked=pcall(writefile,filename,encoded)
  if worked then return end
 end
 if final and type(setclipboard)=="function" then
  if pcall(setclipboard,encoded) then print("[Veyra mechanics] JSON copied to clipboard") return end
 end
 if final then
  print("[Veyra mechanics] No file or clipboard support; JSON follows:")
  for i=1,#encoded,1400 do print(encoded:sub(i,i+1399)) end
 end
end
function probe.stop(why)
 if not probe.active then return end
 addEvent("finish",{reason=why or "manual"})
 probe.active=false
 for _,conn in ipairs(probe.connections) do conn:Disconnect() end
 clearCharacter()
 save(true)
 if global.VeyraMechanicsProbe==probe then global.VeyraMechanicsProbe=nil end
 print("[Veyra mechanics] Saved report: "..filename)
end
print("[Veyra mechanics] Recording 35 seconds. Play normally: move, dash, cast, block, and (optionally) fly.")
save(false)
task.spawn(function()
 local last=0
 while probe.active and os.clock()-started<PERIOD do
  task.wait(1)
  if os.clock()-started-last>=6 then
   last=os.clock()-started
   save(false)
  end
 end
 if probe.active then probe.stop("35 second capture complete") end
end)
return probe
