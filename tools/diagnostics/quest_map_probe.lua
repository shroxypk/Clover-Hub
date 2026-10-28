-- Veyra quest-map probe (read-only): passive HUD + quest state sampling.
-- No remotes, input synthesis, teleportation, automatic toggles or account IDs.
-- Keep the hub enabled and manually interact with its Quest Assistance controls.
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
if not player then warn("[Veyra probe] LocalPlayer unavailable") return end
local G=getgenv()
if G.VeyraQuestMapProbeRunning then
 warn("[Veyra probe] Another capture is running; use its existing result.")
 return
end
G.VeyraQuestMapProbeRunning=true
local DURATION=60
local INTERVAL=2
local MAX_SNAPSHOTS=32
local MAX_WORLD_SCAN=150000
local result={
 schema=1,durationSeconds=DURATION,placeId=game.PlaceId,
 notes={"Passive client-side observations only; no server verification.",
  "Map locations are relative world X/Z positions, not points on the game's native map."},
 snapshots={},issues={},worldMatches={},questTasks={},
 checks={},framerate={},
}
local function clip(value,max)
 local t=tostring(value or "")
 return t:sub(1,max or 100)
end
local function attr(o,key)
 if o then return o:GetAttribute(key) end
end
local function norm(value)
 return clip(value,130):lower():gsub("[^%w]","")
end
local function rounded(n)
 return math.floor(n*10+0.5)/10
end
local function simplePos(value)
 if typeof(value)=="CFrame" then value=value.Position end
 return typeof(value)=="Vector3"
end
local function currentQuest()
 local folder=player:FindFirstChild("Quests")
 local qa=G.VeyraQuestAssist
 local selected=qa and qa.selected
 if not folder or not selected then return nil end
 for _,q in ipairs(folder:GetChildren()) do
  if (q.Name==selected or q:GetAttribute("Quest")==selected) and q:FindFirstChild("Tasks") then
   return q
  end
 end
end
local function visibleObject(o)
 if not o then return false end
 if o:IsA("GuiObject") then return o.Visible end
 if o:IsA("ScreenGui") then return o.Enabled end
 return true
end
local function textOf(o)
 if o and (o:IsA("TextLabel") or o:IsA("TextButton")) then return clip(o.Text,160) end
 return ""
end
local function collectSnapshot(seconds)
 local qa,boss,mg,hub=G.VeyraQuestAssist,G.VeyraBossAlerts,G.VeyraMinigames,G.VeyraController
 local pg=player:FindFirstChild("PlayerGui")
 local gui=pg and pg:FindFirstChild("VeyraQuestGuide")
 local holder=gui and gui:FindFirstChild("Guide")
 local map=gui and gui:FindFirstChild("QuestLocationMap")
 local plot=map and map:FindFirstChild("LocationPlot")
 local pins,pinVisible,pinMaxDistance,pinAlwaysOnTop=0,0,0,0
 if gui then
  for _,o in ipairs(gui:GetDescendants()) do
   if o:IsA("BillboardGui") and o.Name=="QuestObjective" then
    pins+=1
    if o.Enabled then pinVisible+=1 end
    pinMaxDistance=math.max(pinMaxDistance,o.MaxDistance)
    if o.AlwaysOnTop then pinAlwaysOnTop+=1 end
   end
  end
 end
 local dots,visibleDots,clusterSum,clusterMax=0,0,0,0
 local dotSamples={}
 local canvasWidth,canvasHeight=0,0
 if plot then
  canvasWidth=math.floor(plot.AbsoluteSize.X+0.5)
  canvasHeight=math.floor(plot.AbsoluteSize.Y+0.5)
  for _,o in ipairs(plot:GetChildren()) do
   if o.Name=="LocationDot" and o:IsA("TextButton") then
    dots+=1
    if o.Visible then
     visibleDots+=1
     local count=tonumber(o.Text) or 1
     clusterSum+=count
     clusterMax=math.max(clusterMax,count)
     if #dotSamples<12 then
      table.insert(dotSamples,{count=count,x=rounded(o.Position.X.Offset),
       y=rounded(o.Position.Y.Offset)})
     end
    end
   end
  end
 end
 local quest=currentQuest()
 local questFolder=player:FindFirstChild("Quests")
 local indicatorFolder=pg and pg:FindFirstChild("QuestIndicators")
 local indicators={}
 if indicatorFolder then
  for _,indicator in ipairs(indicatorFolder:GetChildren()) do
   if indicator:GetAttribute("status")==true then
    table.insert(indicators,{name=clip(indicator.Name),returning=indicator:GetAttribute("Return")==true})
   end
  end
 end
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local sample={
  t=seconds,characterReady=root~=nil,
  quest=quest and clip(quest.Name) or (qa and qa.selected and clip(qa.selected)) or "",
  indicatorTracking=questFolder and clip(attr(questFolder,"Tracking")) or "",
  activeIndicators=indicators,
  questGuide={loaded=qa~=nil,alive=qa and qa.alive==true or false,
   enabled=qa and qa.enabled==true or false,
   status=qa and clip(qa.status) or "not loaded",
   resolved=qa and qa.resolved or 0,unresolved=qa and qa.unresolved or 0,
   targetDistance=qa and qa.distance or nil,
   markerMode=qa and qa.markerMode or "unavailable",
   mapOpen=qa and qa.mapOpen==true or false,
   compact=qa and qa.compact==true or false},
  ui={rootVisible=gui~=nil and gui.Enabled,
   guideVisible=visibleObject(holder),
   mapVisible=visibleObject(map),mapExists=map~=nil,
   mapButton=textOf(holder and holder:FindFirstChild("ShowQuestMap")),
   pinButton=textOf(holder and holder:FindFirstChild("MarkerVisibility")),
   title=textOf(holder and holder:FindFirstChild("Quest")),
   objective=textOf(holder and holder:FindFirstChild("Details") and holder.Details:FindFirstChild("Objective")),
   mapSummary=textOf(map and map:FindFirstChild("LocationSummary")),
   mapInfo=textOf(map and map:FindFirstChild("MapInfo")),
   plotWidth=canvasWidth,plotHeight=canvasHeight,
   totalWorldPins=pins,enabledWorldPins=pinVisible,
   pinsAlwaysOnTop=pinAlwaysOnTop,pinMaxDistance=pinMaxDistance,
   allocatedMapDots=dots,visibleMapDots=visibleDots,
   representedMapLocations=clusterSum,largestCluster=clusterMax,
   dotSamples=dotSamples},
  otherFeatures={hubAlive=hub and hub.alive==true or false,
   bossEnabled=boss and boss.enabled==true or false,
   bossWarnings=boss and boss.warnings or 0,
   bossStatus=boss and clip(boss.status) or "unavailable",
   minigamesEnabled=mg and mg.enabled==true or false},
 }
 return sample
end
local seen={mapOpened=false,mapClosed=false,questSelected=false,
 modeALL=false,modeNEAR=false,modeOFF=false,compact=false,expanded=false,
 mapWithLocations=false,worldPins=false,bossWarnings=false,respawnObserved=false}
local seenMissingRoot=false
local function updateSeen(s)
 local q=s.questGuide
 seen.mapOpened=seen.mapOpened or q.mapOpen
 seen.mapClosed=seen.mapClosed or not q.mapOpen
 seen.questSelected=seen.questSelected or s.quest~=""
 seen["mode"..q.markerMode]=true
 seen.compact=seen.compact or q.compact
 seen.expanded=seen.expanded or not q.compact
 seen.mapWithLocations=seen.mapWithLocations or s.ui.representedMapLocations>0
 seen.worldPins=seen.worldPins or s.ui.enabledWorldPins>0
 seen.bossWarnings=seen.bossWarnings or s.otherFeatures.bossWarnings>0
 if not s.characterReady then seenMissingRoot=true end
 if seenMissingRoot and s.characterReady then seen.respawnObserved=true end
end
local function inspect(s)
 local q,ui=s.questGuide,s.ui
 if q.enabled and not ui.rootVisible and s.t>=4 then
  table.insert(result.issues,{t=s.t,type="enabled-but-quest-GUI-missing"})
 end
 if q.enabled and ui.mapExists and q.mapOpen~=ui.mapVisible then
  table.insert(result.issues,{t=s.t,type="map-visibility-state-mismatch"})
 end
 if q.enabled and q.markerMode=="OFF" and s.t>=4 and ui.totalWorldPins>0 then
  table.insert(result.issues,{t=s.t,type="off-mode-kept-world-pins",count=ui.totalWorldPins})
 end
 if ui.totalWorldPins>24 then
  table.insert(result.issues,{t=s.t,type="world-pin-cap-exceeded",count=ui.totalWorldPins})
 end
 if ui.totalWorldPins>0 and ui.pinMaxDistance<2000 then
  table.insert(result.issues,{t=s.t,type="pin-distance-too-small",distance=ui.pinMaxDistance})
 end
 if q.mapOpen and ui.plotWidth<40 then
  table.insert(result.issues,{t=s.t,type="map-plot-too-small",width=ui.plotWidth})
 end
 if q.mapOpen and ui.mapSummary:find("loaded spots") then
  local expected=tonumber(ui.mapSummary:match("(%d+) loaded spots"))
  if expected and expected~=ui.representedMapLocations then
   table.insert(result.issues,{t=s.t,type="map-count-mismatch",
    shown=expected,represented=ui.representedMapLocations})
  end
 end
end
local samples={open={frames=0,seconds=0,slow=0},closed={frames=0,seconds=0,slow=0}}
local frameConnection=RunService.RenderStepped:Connect(function(dt)
 local qa=G.VeyraQuestAssist
 local key=qa and qa.mapOpen and "open" or "closed"
 local sample=samples[key]
 sample.frames+=1
 sample.seconds+=dt
 if dt>1/30 then sample.slow+=1 end
end)
print("[Veyra probe] Recording 60 seconds. While it runs: track a multi-item quest, open MAP,")
print("[Veyra probe] move around, select dots, cycle PINS ALL/OFF/NEAR, collapse/reopen the card.")
local ok,err=pcall(function()
 local start=os.clock()
 while os.clock()-start<DURATION and #result.snapshots<MAX_SNAPSHOTS do
  local snapshot=collectSnapshot(rounded(os.clock()-start))
  table.insert(result.snapshots,snapshot)
  updateSeen(snapshot)
  inspect(snapshot)
  task.wait(INTERVAL)
 end
 result.finalQuest=result.snapshots[#result.snapshots] and result.snapshots[#result.snapshots].quest or ""
 local q=currentQuest()
 if q then
  result.questName=clip(q.Name)
  result.questAttributes={
   returning=attr(q,"ReturnNPC"),returnPositionKnown=simplePos(attr(q,"ReturnPosition")),
   description=clip(attr(q,"QuestDescription"),150)}
  local tasks=q:FindFirstChild("Tasks")
  if tasks then
   for _,t in ipairs(tasks:GetChildren()) do
    if #result.questTasks>=50 then break end
    local item={name=clip(t.Name),type=clip(attr(t,"TaskType")),
     object=clip(attr(t,"Object")),hidden=attr(t,"Hidden")==true,
     prerequisite=clip(attr(t,"Prereq")),
     current=attr(t,"TaskProgress"),maximum=attr(t,"TaskMax"),
     positionKnown=simplePos(attr(t,"TrackPosition"))}
    table.insert(result.questTasks,item)
   end
  end
  -- One bounded workspace scan at the end. Names/hints and nearby relative
  -- positions only; no players, account identifiers, or raw full-world dump.
  local keys={}
  for _,t in ipairs(result.questTasks) do
   if t.object~="" then keys[norm(t.object)]=true end
   local name=t.name:match("^[^ ]+ (.+)")
   if name then keys[norm(name)]=true end
  end
  local function isPlayerCharacterObject(o)
   local parent=o
   while parent and parent~=workspace do
    if parent:IsA("Model") and Players:GetPlayerFromCharacter(parent) then return true end
    parent=parent.Parent
   end
   return false
  end
  local character=player.Character
  local origin=character and character:FindFirstChild("HumanoidRootPart")
  local count,matchCount,byName=0,0,{}
  for _,o in ipairs(workspace:GetDescendants()) do
   count+=1
   if count>MAX_WORLD_SCAN then
    table.insert(result.notes,"Workspace scan capped at "..MAX_WORLD_SCAN.." descendants")
    break
   end
   if (o:IsA("Model") or o:IsA("BasePart") and o.Parent and not o.Parent:IsA("Model"))
    and not isPlayerCharacterObject(o) then
    local hintQuest=attr(o,"HintQuest")
    local hintTask=attr(o,"HintTask")
    local key=norm(o.Name)
    local relevant=keys[key]==true or hintQuest and
     (norm(hintQuest)==norm(q.Name) or norm(hintQuest)==norm(attr(q,"Quest")))
    if relevant and not (attr(o,"Gathered")==true or attr(o,"Hidden")==true) then
     local p=nil
     if o:IsA("BasePart") then p=o.Position
     elseif o:IsA("Model") then p=o:GetPivot().Position end
     if p then
      matchCount+=1
      byName[o.Name]=(byName[o.Name] or 0)+1
      if #result.worldMatches<70 then
       local offset=origin and p-origin.Position
       table.insert(result.worldMatches,{
        name=clip(o.Name),class=o.ClassName,
        hintTask=clip(hintTask),hintQuest=clip(hintQuest),
        distance=offset and math.floor(offset.Magnitude+0.5) or nil,
        offset=offset and {x=rounded(offset.X),z=rounded(offset.Z)} or nil})
      end
     end
    end
   end
   if count%3000==0 then task.wait() end
  end
  result.workspaceScan={descendants=count,matches=matchCount,byName=byName}
 end
end)
frameConnection:Disconnect()
if not ok then table.insert(result.issues,{type="probe-error",message=clip(err,220)}) end
result.checks=seen
for key,entry in pairs(samples) do
 result.framerate[key]={
  averageFps=entry.seconds>0 and rounded(entry.frames/entry.seconds) or 0,
  frames=entry.frames,framesOver33ms=entry.slow}
end
G.VeyraQuestMapProbeRunning=nil
local encodedOk,json=pcall(function() return HttpService:JSONEncode(result) end)
if not encodedOk then warn("[Veyra probe] Could not encode report: "..tostring(json)) return end
local filename="Veyra_quest_map_probe.json"
if type(writefile)=="function" then
 local saved=pcall(writefile,filename,json)
 if saved then
  print("[Veyra probe] Saved "..filename.." ("..#json.." bytes). Upload that file to ChatGPT.")
  print("[Veyra probe] Checks: "..HttpService:JSONEncode(result.checks).." · issues: "..#result.issues)
  return result
 end
end
if type(setclipboard)=="function" and pcall(setclipboard,json) then
 print("[Veyra probe] JSON copied to clipboard; paste it into ChatGPT.")
 return result
end
warn("[Veyra probe] Save/clipboard unavailable; copy the numbered JSON fragments below.")
for i=1,#json,1600 do print("[Veyra probe] "..json:sub(i,i+1599)) end
return result
