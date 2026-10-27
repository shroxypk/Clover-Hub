-- Veyra broom speed diagnostic. Read-only: no input, remotes, or physics edits.
-- First load main.lua. Fly with Broom Speed 1x, then change it to 2x.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Http=game:GetService("HttpService")
local player=Players.LocalPlayer
local G=getgenv()
if G.VeyraBroomProbe and G.VeyraBroomProbe.stop then G.VeyraBroomProbe.stop("restarted") end

local seconds=24
local start=os.clock()
local path="Veyra_broom_speed_probe_"..tostring(os.time())..".json"
local probe={active=true,connections={},samples={},changes={},maxSamples=450}
G.VeyraBroomProbe=probe
local report={version=1,placeId=game.PlaceId,samples=probe.samples,changes=probe.changes,
 notes="Passive client measurements only. Requested velocity is not proof of server-accepted movement."}
local function number(x)
 if type(x)=="number" and x==x and x~=math.huge and x~=-math.huge then
  return math.floor(x*100+0.5)/100
 end
end
local function horizontal(v)
 return number(math.sqrt(v.X*v.X+v.Z*v.Z))
end
local function read()
 local h=G.VeyraController
 local c=player.Character
 local root=c and c:FindFirstChild("HumanoidRootPart")
 local lv=root and root:FindFirstChildWhichIsA("LinearVelocity",true)
 local row={t=number(os.clock()-start),hubLoaded=h~=nil}
 if h then
  row.multiplier=h.broomSpeed
  if type(h.testBroomConn)=="function" then
   local ok,armed=pcall(h.testBroomConn)
   row.scalerArmed=ok and armed or false
  end
  local gui=h.gui
  local body=gui and gui:FindFirstChild("Main") and gui.Main:FindFirstChild("Body")
  local item=body and body:FindFirstChild("Broom Speed")
  local label=item and item:FindFirstChild("Value")
  row.hubLabel=label and label.Text or nil
 end
 row.flying=c and c:GetAttribute("Flying")==true or false
 row.hasRoot=root~=nil
 row.linearVelocityFound=lv~=nil
 if root then
  row.actualHorizontal=horizontal(root.AssemblyLinearVelocity)
  row.actualVertical=number(root.AssemblyLinearVelocity.Y)
 end
 if lv then
  row.velocityPath=lv.Parent and lv.Parent.Name or "unknown"
  row.velocityEnabled=lv.Enabled
  row.requestedHorizontal=horizontal(lv.VectorVelocity)
  row.requestedVertical=number(lv.VectorVelocity.Y)
  row.relativeTo=tostring(lv.RelativeTo)
 end
 return row
end
local function addEvent(kind,value)
 if not probe.active or #report.changes>=50 then return end
 table.insert(report.changes,{t=number(os.clock()-start),kind=kind,value=value})
end
local lastMultiplier,lastFlying,lastArmed,lastLV,lastLabel
local function track(row)
 if row.multiplier~=lastMultiplier then
  lastMultiplier=row.multiplier
  addEvent("multiplier",row.multiplier or "missing")
 end
 if row.flying~=lastFlying then
  lastFlying=row.flying
  addEvent("flying",row.flying)
 end
 if row.scalerArmed~=lastArmed then
  lastArmed=row.scalerArmed
  addEvent("scalerArmed",row.scalerArmed)
 end
 if row.linearVelocityFound~=lastLV then
  lastLV=row.linearVelocityFound
  addEvent("linearVelocityFound",row.linearVelocityFound)
 end
 if row.hubLabel~=lastLabel then
  lastLabel=row.hubLabel
  addEvent("panelLabel",row.hubLabel or "missing")
 end
end
local phases={PreSimulation=0,PostSimulation=0,Heartbeat=0}
local function sample(phase)
 if not probe.active or #report.samples>=probe.maxSamples then return end
 local now=os.clock()
 if now-phases[phase]<0.22 then return end
 phases[phase]=now
 local row=read()
 row.phase=phase
 table.insert(report.samples,row)
 if phase=="Heartbeat" then track(row) end
end
table.insert(probe.connections,RunService.PreSimulation:Connect(function() sample("PreSimulation") end))
table.insert(probe.connections,RunService.PostSimulation:Connect(function() sample("PostSimulation") end))
table.insert(probe.connections,RunService.Heartbeat:Connect(function() sample("Heartbeat") end))

local function summarize()
 local buckets={}
 for _,row in ipairs(report.samples) do
  if row.flying and row.multiplier and row.actualHorizontal and row.requestedHorizontal then
   local name=string.format("%s %.2fx",row.phase,row.multiplier)
   local b=buckets[name] or {samples=0,actualSum=0,requestedSum=0,maxActual=0,maxRequested=0,scalerArmedSamples=0}
   buckets[name]=b
   b.samples+=1
   b.actualSum+=row.actualHorizontal
   b.requestedSum+=row.requestedHorizontal
   b.maxActual=math.max(b.maxActual,row.actualHorizontal)
   b.maxRequested=math.max(b.maxRequested,row.requestedHorizontal)
   if row.scalerArmed then b.scalerArmedSamples+=1 end
  end
 end
 for _,b in pairs(buckets) do
  b.meanActual=number(b.actualSum/b.samples)
  b.meanRequested=number(b.requestedSum/b.samples)
  b.actualSum=nil
  b.requestedSum=nil
 end
 return buckets
end
local function save(final)
 report.elapsed=number(os.clock()-start)
 report.summary=summarize()
 report.startHubLoaded=report.startHubLoaded
 local ok,json=pcall(function() return Http:JSONEncode(report) end)
 if not ok then warn("[Veyra Broom] Could not encode report: "..tostring(json)) return end
 if type(writefile)=="function" then
  local saved=pcall(writefile,path,json)
  if saved then return end
 end
 if final and type(setclipboard)=="function" then
  if pcall(setclipboard,json) then
   print("[Veyra Broom] Copied report to clipboard")
   return
  end
 end
 if final then
  print("[Veyra Broom] Report JSON:")
  for i=1,#json,1400 do print(json:sub(i,i+1399)) end
 end
end
function probe.stop(reason)
 if not probe.active then return end
 addEvent("stop",reason or "manual")
 probe.active=false
 for _,conn in ipairs(probe.connections) do conn:Disconnect() end
 table.clear(probe.connections)
 save(true)
 if G.VeyraBroomProbe==probe then G.VeyraBroomProbe=nil end
 print("[Veyra Broom] Finished. Report: "..path)
end

report.startHubLoaded=G.VeyraController~=nil
print("[Veyra Broom] Recording for 24 seconds. Fly at 1x for about 10 seconds, then choose 2x and keep flying.")
if not report.startHubLoaded then
 warn("[Veyra Broom] Hub not loaded: run Veyra main.lua first; report cannot test speed scaling yet.")
end
task.spawn(function()
 while probe.active and os.clock()-start<seconds do task.wait(0.5) end
 if probe.active then probe.stop("24-second capture complete") end
end)
return probe
