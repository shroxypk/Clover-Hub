-- Veyra auto gather: walks to profession nodes and opens their own
-- ProximityPrompt, then hands the minigame to the solver in minigames.lua.
--
-- Node truth comes from ReplicatedStorage.ProfessionNodes (Item, Kind,
-- Available, Position, Power). Which nodes we are allowed to touch comes from
-- the game's own workspace.Map.Harvestable.HarvestController registries:
--   SickleRegistry / PickaxeRegistry -> tool power
--   CropRegistry / OreRegistry       -> node power requirement
-- A node is only targeted when its Power fits the best tool in the backpack,
-- so the pick is always the highest-XP node the current gear can clear.
-- Movement is Humanoid:MoveTo with raycast steering; no speed change, no
-- teleport, no remotes.
local G=getgenv()
if G.VeyraAutoGather then G.VeyraAutoGather.stop() end
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local VIM=game:GetService("VirtualInputManager")
local player=Players.LocalPlayer
local state={
 alive=true,harvest=false,ore=false,status="Idle",target=nil,
 walked=0,gathered=0,blacklist={},manualUntil=0,holdUntil=0,
 lastHealth=nil,events={},
 picks={Harvest={},Ore={}},
 nav={side=1,strikes=0,detourUntil=0,avoid=nil,goal=nil,best=0,stallAt=0,
  points=nil,index=1,pathGoal=nil,pathAt=0,busy=false,nextPath=0,pathFails=0,
  promptMisses=0},
 jumpAt=0,ignoreInputUntil=0,
}
G.VeyraAutoGather=state
local function resetNav()
 local nav=state.nav
 nav.side=1
 nav.strikes=0
 nav.goal=nil
 nav.best=0
 nav.stallAt=0
 nav.avoid=nil
 nav.detourUntil=0
 nav.points=nil
 nav.index=1
 nav.pathGoal=nil
 nav.busy=false
 nav.nextPath=0
 nav.pathFails=0
 nav.promptMisses=0
end
local nextRebuild=0
local RADIUS=140
local FAR_RADIUS=420
local STOP=4.5
local PROMPT_RADIUS=7
local TICK=0.2
local connections={}
local nodes,folder={},nil
local folderConnections={}
local function connect(signal,callback)
 local connection=signal:Connect(callback)
 connections[#connections+1]=connection
 return connection
end
-- Registries ---------------------------------------------------------------
local registryCache={}
local function registry(name)
 if registryCache[name]~=nil then return registryCache[name] or nil end
 local map=workspace:FindFirstChild("Map")
 local harvestable=map and map:FindFirstChild("Harvestable")
 local controller=harvestable and harvestable:FindFirstChild("HarvestController")
 local module=controller and controller:FindFirstChild(name)
 local value
 if module then
  local ok,result=pcall(function() return require(module) end)
  if ok and type(result)=="table" then value=result end
 end
 registryCache[name]=value or false
 return value
end
local function powerOf(kind,item)
 if kind=="Harvest" then
  local crops=registry("CropRegistry")
  local value=crops and crops[item]
  if type(value)=="number" then return value end
  if type(value)=="table" and type(value.Power)=="number" then return value.Power end
 elseif kind=="Ore" then
  local ores=registry("OreRegistry")
  local value=ores and ores[item]
  if type(value)=="number" then return value end
  if type(value)=="table" then
   if type(value.Power)=="number" then return value.Power end
   if type(value.Level)=="number" then return value.Level end
  end
 end
 return nil
end
-- Best tool for this profession that we actually carry right now.
local function toolPower(kind)
 local toolRegistry=registry(kind=="Harvest" and "SickleRegistry" or "PickaxeRegistry")
 if not toolRegistry then return nil end
 local best=0
 local function scan(container)
  if not container then return end
  for _,tool in ipairs(container:GetChildren()) do
   if tool:IsA("Tool") then
    local power=toolRegistry[tool.Name]
    if type(power)=="number" and power>best then best=power end
   end
  end
 end
 scan(player:FindFirstChild("Backpack"))
 scan(player.Character)
 if best<=0 then return nil end
 return best
end
local function kindName(kind)
 local lower=string.lower(tostring(kind))
 if lower=="harvest" then return "Harvest" end
 if lower=="ore" then return "Ore" end
 return kind
end
local function picksFor(kind)
 kind=kindName(kind)
 local picks=state.picks[kind]
 if not picks then picks={} state.picks[kind]=picks end
 return picks
end
local function typeEnabled(kind,item)
 local picks=picksFor(kind)
 if next(picks)==nil then return true end
 return picks[item]==true
end
function state.catalog(kind)
 kind=kindName(kind)
 local cap=toolPower(kind)
 local names,seen={},{}
 local function add(name)
  if not name or seen[name] then return end
  seen[name]=true
  names[#names+1]=name
 end
 local data=registry(kind=="Harvest" and "CropRegistry" or "OreRegistry")
 if data then
  local list={}
  for name in pairs(data) do list[#list+1]=name end
  table.sort(list)
  for _,name in ipairs(list) do add(name) end
 end
 for _,node in ipairs(nodes) do
  if node.kind==kind then add(node.item) end
 end
 local out={}
 for _,name in ipairs(names) do
  local power=powerOf(kind,name)
  out[#out+1]={
   name=name,
   power=power,
   allowed=(cap==nil or power==nil or power<=cap),
   selected=typeEnabled(kind,name) and (cap==nil or power==nil or power<=cap),
  }
 end
 table.sort(out,function(a,b)
  local pa,pb=a.power or -1,b.power or -1
  if pa~=pb then return pa<pb end
  return a.name<b.name
 end)
 return out
end
function state.toolPower(kind) return toolPower(kind) end
function state.setType(kind,item,on)
 kind=kindName(kind)
 if not state.alive or not item then return end
 local picks=picksFor(kind)
 if next(picks)==nil then
  -- First click materialises "everything currently allowed", then removes one.
  local cap=toolPower(kind)
  for _,entry in ipairs(state.catalog(kind)) do
   if cap==nil or entry.power==nil or entry.power<=cap then picks[entry.name]=true end
  end
 end
 if on==true then picks[item]=true else picks[item]=nil end
 if next(picks)==nil then picks[item]=true end
 local _,humanoid,root=character()
 if humanoid and root then
  state.target=nil
  resetNav()
 end
 return true
end
function state.isTypeOn(kind,item)
 kind=kindName(kind)
 local cap=toolPower(kind)
 local power=powerOf(kind,item)
 if cap and power and power>cap then return false end
 return typeEnabled(kind,item)
end
-- Node index ---------------------------------------------------------------
local function rebuild()
 local found=ReplicatedStorage:FindFirstChild("ProfessionNodes")
 if found~=folder then
  -- The registry is rebuilt when the map streams in or the place changes.
  for _,connection in ipairs(folderConnections) do connection:Disconnect() end
  table.clear(folderConnections)
  folder=found
  if folder then
   folderConnections[#folderConnections+1]=folder.ChildAdded:Connect(rebuild)
   folderConnections[#folderConnections+1]=folder.ChildRemoved:Connect(rebuild)
  end
 end
 table.clear(nodes)
 if not folder then return end
 for _,config in ipairs(folder:GetChildren()) do
  local position=config:GetAttribute("Position")
  local kind=config:GetAttribute("Kind")
  if typeof(position)=="Vector3" and (kind=="Harvest" or kind=="Ore") then
   local item=config:GetAttribute("Item") or config.Name
   local power=config:GetAttribute("Power")
   nodes[#nodes+1]={
    config=config,kind=kind,position=position,item=item,
    drop=config:GetAttribute("Drop"),
    power=powerOf(kind,item) or (type(power)=="number" and power or 0),
   }
  end
 end
end
rebuild()
connect(ReplicatedStorage.ChildAdded,function(child)
 if child.Name=="ProfessionNodes" then rebuild() end
end)
connect(ReplicatedStorage.ChildRemoved,function(child)
 if child.Name=="ProfessionNodes" then rebuild() end
end)
local function character()
 local char=player.Character
 local humanoid=char and char:FindFirstChildOfClass("Humanoid")
 local root=char and char:FindFirstChild("HumanoidRootPart")
 if not humanoid or not root or humanoid.Health<=0 then return nil end
 return char,humanoid,root
end
-- Travel at the game's own run speed. The game exposes a double-tap-to-sprint
-- setting, so a travel leg starts with the same double tap a player would
-- make; sprint speed and energy drain stay entirely under the game's control.
local sprintAt=0
local function pulseSprint(now)
 if now<sprintAt then return end
 sprintAt=now+3.5
 if UIS:GetFocusedTextBox() then return end
 -- Our own taps must not read as the player grabbing the controls.
 state.ignoreInputUntil=now+0.5
 pcall(function()
  VIM:SendKeyEvent(true,Enum.KeyCode.W,false,game)
  task.wait(0.05)
  VIM:SendKeyEvent(false,Enum.KeyCode.W,false,game)
  task.wait(0.1)
  VIM:SendKeyEvent(true,Enum.KeyCode.W,false,game)
  task.wait(0.05)
  VIM:SendKeyEvent(false,Enum.KeyCode.W,false,game)
 end)
end
-- A tap is not the player taking over; only a held movement key is, so the
-- farm resumes as soon as they let go instead of stalling for seconds.
local STEER_KEYS={Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,Enum.KeyCode.Space}
local function playerSteering(now)
 if now<(state.ignoreInputUntil or 0) then
  state.holdSince=nil
  return false
 end
 local down=false
 for _,key in ipairs(STEER_KEYS) do
  if UIS:IsKeyDown(key) then down=true break end
 end
 if not down then
  state.holdSince=nil
  return false
 end
 state.holdSince=state.holdSince or now
 return now-state.holdSince>0.35
end
local function halt(humanoid,root)
 -- MoveTo at our own feet cancels the walk without touching humanoid speed.
 humanoid:MoveTo(root.Position)
end
local function usable(kind,node)
 if not typeEnabled(kind,node.item) then return false end
 local cap=toolPower(kind)
 if cap and node.power and node.power>cap then return false end
 return true
end
-- Best XP first: highest power we can clear, then the closest of that power.
local function nearest(kind,root,radius)
 radius=radius or RADIUS
 local now=os.clock()
 local best,bestPower,bestDistance
 for _,node in ipairs(nodes) do
  if node.kind==kind and node.config:GetAttribute("Available")==true and usable(kind,node) then
   local blocked=state.blacklist[node.config]
   if not blocked or blocked<now then
    local distance=(node.position-root.Position).Magnitude
    if distance<=radius then
     local power=node.power or 0
     local better=not best
     if not better then
      if power>bestPower then better=true
      elseif power==bestPower and distance<bestDistance then better=true end
     end
     if better then best,bestPower,bestDistance=node,power,distance end
    end
   end
  end
 end
 return best,bestDistance
end
local function choose(root,radius)
 local best,bestPower,bestDistance
 local function consider(kind)
  local node,distance=nearest(kind,root,radius)
  if not node then return end
  local power=node.power or 0
  local better=not best
  if not better then
   if power>bestPower then better=true
   elseif power==bestPower and distance<bestDistance then better=true end
  end
  if better then best,bestPower,bestDistance=node,power,distance end
 end
 if state.harvest then consider("Harvest") end
 if state.ore then consider("Ore") end
 return best,bestDistance
end
local function activeKind(kind)
 return kind=="Harvest" and state.harvest or kind=="Ore" and state.ore or false
end
local function readyCount(root)
 local now=os.clock()
 local count=0
 for _,node in ipairs(nodes) do
  if activeKind(node.kind) and node.config:GetAttribute("Available")==true and usable(node.kind,node) then
   local blocked=state.blacklist[node.config]
   if (not blocked or blocked<now) and (node.position-root.Position).Magnitude<=RADIUS then
    count+=1
   end
  end
 end
 return count
end
local function availability(root)
 local any,inRange=0,0
 for _,node in ipairs(nodes) do
  if activeKind(node.kind) and node.config:GetAttribute("Available")==true and typeEnabled(node.kind,node.item) then
   any+=1
   if (node.position-root.Position).Magnitude<=RADIUS then inRange+=1 end
  end
 end
 return any,inRange
end
local promptParams=OverlapParams.new()
promptParams.FilterType=Enum.RaycastFilterType.Exclude
promptParams.MaxParts=200
local function promptNear(position,char)
 if promptParams.FilterDescendantsInstances[1]~=char then
  promptParams.FilterDescendantsInstances={char}
 end
 local ok,parts=pcall(function() return workspace:GetPartBoundsInRadius(position,PROMPT_RADIUS,promptParams) end)
 if not ok then return nil end
 local best,bestDistance
 local seen={}
 for _,part in ipairs(parts) do
  local direct=part:FindFirstChildOfClass("ProximityPrompt")
  local model=part:FindFirstAncestorOfClass("Model")
  local candidates={direct}
  if model then
   candidates[#candidates+1]=model:FindFirstChildWhichIsA("ProximityPrompt",true)
  end
  for _,prompt in ipairs(candidates) do
   if prompt and prompt.Enabled and not seen[prompt] then
    seen[prompt]=true
    local anchor=prompt.Parent
    local anchorPosition=position
    if anchor:IsA("BasePart") then
     anchorPosition=anchor.Position
    elseif anchor:IsA("Model") then
     anchorPosition=anchor:GetPivot().Position
    end
    local distance=(anchorPosition-position).Magnitude
    if not bestDistance or distance<bestDistance then best,bestDistance=prompt,distance end
   end
  end
 end
 return best,bestDistance
end
local function anchorOf(prompt)
 local anchor=prompt.Parent
 if anchor:IsA("BasePart") then return anchor.Position end
 if anchor:IsA("Model") then return anchor:GetPivot().Position end
 return nil
end
local function spent(prompt)
 local item=prompt.Parent
 while item and item~=workspace do
  if item:GetAttribute("Gathered")==true then return true end
  item=item.Parent
 end
 return false
end
-- The game tells us exactly when a node comes back (RespawnAt is a server
-- timestamp), so waiting is timed instead of guessed.
local function serverNow()
 local ok,value=pcall(function() return workspace:GetServerTimeNow() end)
 if ok and type(value)=="number" then return value end
 return os.time()
end
local function respawnIn(config)
 if config:GetAttribute("Available")==true then return 0 end
 local at=config:GetAttribute("RespawnAt")
 if type(at)~="number" or at<=0 then return nil end
 return math.max(0,at-serverNow())
end
local function soonestRespawn(root)
 local soonest
 for _,node in ipairs(nodes) do
  if activeKind(node.kind) and usable(node.kind,node) and node.config:GetAttribute("Available")~=true then
   if (node.position-root.Position).Magnitude<=RADIUS then
    local seconds=respawnIn(node.config)
    if seconds and (not soonest or seconds<soonest) then soonest=seconds end
   end
  end
 end
 return soonest
end
local function solverBusy()
 local solver=G.VeyraMinigames
 return solver and (solver.active or solver.isWorking())
end
local function sessionOpened(node)
 local solver=G.VeyraMinigames
 if solverBusy() then return true end
 if node.config:GetAttribute("Available")==false then return true end
 local char=player.Character
 local gui=char and player.PlayerGui
 if gui and (gui:FindFirstChild("HarvestTiming") or gui:FindFirstChild("HarvestRings")) then
  local screen=gui:FindFirstChild("HarvestTiming") or gui:FindFirstChild("HarvestRings")
  if screen.Enabled then return true end
 end
 return false
end
-- Navigation ---------------------------------------------------------------
-- Read-only raycasts only: the character still walks with MoveTo at its own
-- speed. The probe samples the body volume so fences and rails are noticed,
-- walkable surfaces are ignored, and whatever is left is a real obstacle.
local rayParams=RaycastParams.new()
rayParams.FilterType=Enum.RaycastFilterType.Exclude
local FAN={0,12,-12,24,-24,38,-38,54,-54,72,-72,92,-92,114,-114,138,-138,180}
local BODY={0.2,1.3,2.4}
local blockerList=nil
local function blockers(char)
 local list=blockerList
 if not list then
  list={char}
  blockerList=list
 else
  list[1]=char
 end
 local harvestable=list[2]
 if harvestable==nil or harvestable.Parent==nil then
  local map=workspace:FindFirstChild("Map")
  harvestable=map and map:FindFirstChild("Harvestable")
  list[2]=harvestable
 end
 return list
end
local function probe(char,root,point)
 local delta=Vector3.new(point.X-root.Position.X,0,point.Z-root.Position.Z)
 if delta.Magnitude<0.25 then return true end
 rayParams.FilterDescendantsInstances=blockers(char)
 for _,height in ipairs(BODY) do
  local hit=workspace:Raycast(root.Position+Vector3.new(0,height,0),delta,rayParams)
  -- A surface you could stand on is a step, not a wall.
  if hit and hit.Normal.Y<0.6 then return false,hit end
 end
 return true
end
local function headroom(char,root)
 rayParams.FilterDescendantsInstances=blockers(char)
 return workspace:Raycast(root.Position+Vector3.new(0,2,0),Vector3.new(0,4.5,0),rayParams)==nil
end
-- How tall is the thing we walked into, and is there air above it to hop?
local function obstacleTop(char,root,hit)
 rayParams.FilterDescendantsInstances=blockers(char)
 local top=hit.Position.Y
 local down=workspace:Raycast(hit.Position+Vector3.new(0,7,0),Vector3.new(0,-9,0),rayParams)
 if down and down.Position.Y>top then top=down.Position.Y end
 if top>root.Position.Y+2.6 then return top,false end
 local air=workspace:Raycast(Vector3.new(hit.Position.X,top+0.5,hit.Position.Z),Vector3.new(0,3.2,0),rayParams)
 return top,air==nil
end
local function flat(point,y)
 return Vector3.new(point.X,y,point.Z)
end
local JUMP_GAP=1.1
local function hop(humanoid,now)
 if now<state.jumpAt then return false end
 humanoid.Jump=true
 state.jumpAt=now+JUMP_GAP
 return true
end
-- Real pathfinding for anything the local fan cannot see (rooms, corridors,
-- ledges). ComputeAsync is heavy, so it runs on its own thread and the local
-- steering keeps working until the route arrives.
local PathfindingService=game:GetService("PathfindingService")
-- Whatever the route needs, the character still walks it: no speed, jump or
-- position writes. The jump key below is a pathfinding hint, nothing else.
local JUMP_HINT="AgentJump".."Height"
-- Cave tunnels are tighter than the open map, so a failed route is retried with
-- a slimmer agent before the node is called unreachable.
local PATH_RADII={1.6,1.1,0.8}
local function computeRoute(root,goal)
 local reason
 for _,radius in ipairs(PATH_RADII) do
  local params={AgentRadius=radius,AgentHeight=5,AgentCanJump=true,[JUMP_HINT]=7,AgentMaxSlope=45}
  local ok,path=pcall(function()
   local created=PathfindingService:CreatePath(params)
   created:ComputeAsync(root.Position,goal)
   return created
  end)
  if ok and (path.Status==Enum.PathStatus.Success or path.Status==Enum.PathStatus.PartialPath) then
   local points={}
   for _,wp in ipairs(path:GetWaypoints()) do
    points[#points+1]={position=wp.Position,jump=wp.Action==Enum.PathWaypointAction.Jump}
   end
   if #points>=2 then return points end
   reason="short"
  elseif ok then
   reason=path.Status.Name
  else
   reason="error"
  end
 end
 return nil,reason
end
local function requestPath(nav,root,goal,now)
 if nav.busy or now<nav.nextPath then return end
 nav.busy=true
 nav.nextPath=now+1.5
 local requestGoal=goal
 task.spawn(function()
  local points,reason=computeRoute(root,requestGoal)
  nav.busy=false
  nav.points=points
  nav.pathGoal=points and requestGoal or nil
  nav.index=1
  nav.pathAt=os.clock()
  if not points then nav.pathFails=(nav.pathFails or 0)+1 else nav.pathFails=0 end
 end)
end
local function followPath(nav,humanoid,root,now)
 local points=nav.points
 if not points then return false end
 local index=nav.index or 1
 while index<=#points do
  local p=points[index].position
  local gap=Vector3.new(p.X-root.Position.X,0,p.Z-root.Position.Z).Magnitude
  if gap<2.6 and math.abs(p.Y-root.Position.Y)<7 then
   index+=1
  else
   break
  end
 end
 nav.index=index
 if index>#points then return false end
 local wp=points[index]
 if wp.jump and now>=state.jumpAt then hop(humanoid,now) end
 humanoid:MoveTo(wp.position)
 return true
end
local function standPoint(root,goal,minGap)
 local gap=(goal-root.Position).Magnitude
 if gap<=minGap then return goal end
 local away=Vector3.new(root.Position.X-goal.X,0,root.Position.Z-goal.Z)
 if away.Magnitude<0.1 then return goal end
 -- Same height as the node, a few studs in front of it: an ore's centre sits
 -- inside rock, which is what used to read as "no route".
 return goal+away.Unit*math.min(3.5,gap-minGap)
end
local function navigate(char,humanoid,root,goal,now)
 local nav=state.nav
 local base=root.Position
 local delta=Vector3.new(goal.X-base.X,0,goal.Z-base.Z)
 local distance=delta.Magnitude
 if distance<0.2 then return true end
 local dir=delta.Unit
 local step=math.clamp(distance,6,14)
 -- Close range: walk straight in, hopping whatever low lip is in the way.
 if distance<9 then
  nav.points=nil
  local ahead=flat(base+dir*math.min(distance,6),base.Y)
  local clear,hit=probe(char,root,ahead)
  if not clear and headroom(char,root) then
   local _,hoppable=obstacleTop(char,root,hit)
   if hoppable then hop(humanoid,now) end
  end
  humanoid:MoveTo(goal)
  return distance<STOP
 end
 -- A route around walls, doors and corners, the way a player would walk it.
 -- Recompute only when the route is missing, the goal drifted, or it got old.
 local drift=nav.pathGoal and (nav.pathGoal-goal).Magnitude or 0
 if not nav.points or drift>12 or now-nav.pathAt>8 then
  requestPath(nav,root,standPoint(root,goal,3.5),now)
 end
 if followPath(nav,humanoid,root,now) then return false end
 if nav.points then
  -- Route finished with the node still far: it led somewhere else, ask again.
  nav.points=nil
  nav.pathGoal=nil
  nav.nextPath=math.min(nav.nextPath,now+0.5)
 end
 local straight=flat(base+dir*step,base.Y)
 local clear,hit=probe(char,root,straight)
 if clear then
  humanoid:MoveTo(straight)
  return false
 end
 -- Low wall, fence or ledge: a player jumps it and keeps going.
 local top,hoppable=obstacleTop(char,root,hit)
 if hoppable and headroom(char,root) then
  hop(humanoid,now)
  humanoid:MoveTo(straight)
  return false
 end
 -- Real wall: swing wide around it, biased away from where we stalled.
 local away=dir
 if now<nav.detourUntil then
  away=CFrame.Angles(0,math.rad(72*nav.side),0):VectorToWorldSpace(dir)
 end
 for _,reach in ipairs({step,step*0.55,5}) do
  for _,angle in ipairs(FAN) do
   local rotated=CFrame.Angles(0,math.rad(angle*nav.side),0):VectorToWorldSpace(away)
   local point=flat(base+rotated*reach,base.Y)
   local backtrack=nav.avoid and now<nav.detourUntil and (point-nav.avoid).Magnitude<3.5
   if not backtrack and probe(char,root,point) then
    humanoid:MoveTo(point)
    return false
   end
  end
 end
 -- Boxed in on every side: push forward while hopping; the stall timer will
 -- swing to the other side or drop the node.
 if top and top<=base.Y+3.5 and headroom(char,root) then hop(humanoid,now) end
 humanoid:MoveTo(straight)
 return false
end
-- Main loop ----------------------------------------------------------------
local function step()
 local char,humanoid,root=character()
 if not (state.harvest or state.ore) then
  state.status="Idle"
  state.target=nil
  return
 end
 if not char then state.status="Waiting for character" return end
 if solverBusy() then
  -- The solver owns input while a session is open; do not walk out of it.
  local solver=G.VeyraMinigames
  state.status="Solving "..(solver.activity or "minigame")
  halt(humanoid,root)
  return
 end
 if UIS:GetFocusedTextBox() then
  state.status="Paused · typing"
  halt(humanoid,root)
  return
 end
 local now=os.clock()
 if playerSteering(now) then state.manualUntil=now+0.9 end
 if now<state.manualUntil then
  state.status="Manual control"
  halt(humanoid,root)
  return
 end
 if os.clock()<state.holdUntil then
  halt(humanoid,root)
  return
 end
 if state.lastHealth and humanoid.Health<state.lastHealth-0.5 then
  state.holdUntil=os.clock()+3
  state.status="Holding · under attack"
  halt(humanoid,root)
  state.lastHealth=humanoid.Health
  return
 end
 state.lastHealth=humanoid.Health
 local target=state.target
 if target and (target.config:GetAttribute("Available")~=true or not usable(target.kind,target)) then
  state.target=nil target=nil
 end
 if not target then
  local best,bestDistance=choose(root,RADIUS)
  if not best then best,bestDistance=choose(root,FAR_RADIUS) end
  if not best then
   local any,inRange=availability(root)
   if #nodes==0 then
    state.status="Waiting for node data"
    if os.clock()>=nextRebuild then
     nextRebuild=os.clock()+2
     rebuild()
    end
   elseif any==0 then
    local soonest=soonestRespawn(root)
    if soonest then
     state.status=string.format("Waiting · %ds",math.ceil(soonest))
    else
     state.status="Waiting for respawn"
    end
   elseif inRange==0 then
    state.status=string.format("Nothing within %dm",FAR_RADIUS)
   else
    state.status=string.format("Waiting · %d ready",readyCount(root))
   end
   halt(humanoid,root)
   return
  end
  state.target=best
  resetNav()
  target=best
 end
 local now=os.clock()
 local distance=(target.position-root.Position).Magnitude
 -- If the node's own prompt is already inside activation range, distance no
 -- longer matters: walk in and press it instead of hunting for a closer spot.
 local prompt,promptDistance=promptNear(target.position,char)
 local promptReach=prompt and ((prompt.MaxActivationDistance or 7)-0.5) or 0
 local canPress=prompt~=nil and promptDistance~=nil and promptDistance<=promptReach and not spent(prompt)
 if distance>FAR_RADIUS then
  -- Wandered off: drop the trail and pick whatever is closest from here.
  state.target=nil
  resetNav()
  halt(humanoid,root)
  state.status="Looking for "..(state.harvest and "crops" or "ore")
  return
 end
 if distance>STOP and not canPress then
  local power=target.power or 0
  state.status=string.format("Running · %s · P%d · %dm",target.item,power,math.floor(distance+0.5))
  if distance>24 then pulseSprint(now) end
  local nav=state.nav
  if nav.goal~=target.config then
   nav.goal=target.config
   nav.best=distance
   nav.stallAt=now
   nav.avoid=nil
   nav.points=nil
   nav.pathGoal=nil
  end
  -- Progress only counts when the gap actually shrinks; pacing in front of a
  -- wall is not progress, even though the character keeps moving.
  if distance<nav.best-1.2 then
   nav.best=distance
   nav.stallAt=now
   nav.strikes=0
  elseif now-nav.stallAt>1.6 then
   nav.stallAt=now
   nav.strikes+=1
   -- A stalled leg means the route is wrong: drop it and ask for a new one.
   nav.points=nil
   nav.pathGoal=nil
   nav.nextPath=0
   if nav.strikes>=5 then
    state.blacklist[target.config]=now+25
    state.target=nil
    nav.goal=nil
    nav.strikes=0
    state.status="Skipped · "..target.item.." unreachable"
    halt(humanoid,root)
    return
   end
   nav.side=-nav.side
   nav.avoid=root.Position
   nav.detourUntil=now+1.6
   state.status="Detour · "..target.item
  end
  -- Route to standable ground beside the node, not to the node's own centre.
  local goal=standPoint(root,target.position,2)
  if (nav.pathFails or 0)>=3 then
   state.blacklist[target.config]=now+30
   state.target=nil
   nav.goal=nil
   nav.pathFails=0
   state.status="Skipped · "..target.item.." no route"
   halt(humanoid,root)
   return
  end
  navigate(char,humanoid,root,goal,now)
  return
 end
 state.nav.goal=nil
 halt(humanoid,root)
 if not prompt or spent(prompt) then
  local wait=respawnIn(target.config)
  if target.config:GetAttribute("Available")==true and not spent(prompt) then
   -- The node is still up but no prompt was found near it: keep closing in
   -- instead of writing a live node off as respawning.
   local nav=state.nav
   nav.promptMisses=(nav.promptMisses or 0)+1
   if nav.promptMisses<6 then
    state.status="Closing · "..target.item
    navigate(char,humanoid,root,standPoint(root,target.position,1.5),now)
    return
   end
   nav.promptMisses=0
   state.blacklist[target.config]=now+6
   state.target=nil
   state.status="Skipped · "..target.item.." no prompt"
   return
  end
  state.blacklist[target.config]=now+(wait and math.max(2,wait) or 20)
  state.target=nil
  if wait then
   state.status=string.format("Waiting · %s respawning %ds",target.item,math.ceil(wait))
  else
   state.status="Waiting · "..target.item.." respawning"
  end
  return
 end
 local anchor=anchorOf(prompt)
 local reach=anchor and (anchor-root.Position).Magnitude or promptDistance or 0
 local reachable=prompt.MaxActivationDistance or 7
 if not canPress and reach>reachable-1 then
  -- Stop inside the prompt's own activation range before touching it.
  state.status="Closing · "..target.item
  navigate(char,humanoid,root,standPoint(root,anchor or target.position,1.5),now)
  return
 end
 local solver=G.VeyraMinigames
 if solver and not solver.enabled and solver.setEnabled then solver.setEnabled(true) end
 state.status="Gathering · "..target.item
 state.target=nil
 state.blacklist[target.config]=os.clock()+8
 task.wait(0.12+math.random()*0.22)
 prompt:InputHoldBegin()
 task.wait(0.06)
 prompt:InputHoldEnd()
 state.walked+=1
 state.holdUntil=os.clock()+0.8
 local deadline=os.clock()+5
 while state.alive and os.clock()<deadline do
  if sessionOpened(target) then
   state.gathered+=1
   state.status="Gathered · "..target.item
   break
  end
  task.wait(0.1)
 end
end
function state.setMode(kind,on)
 if not state.alive then return end
 kind=string.lower(tostring(kind))
 on=on==true
 state.events[#state.events+1]=string.format("%.1f %s=%s",os.clock(),kind,tostring(on))
 if #state.events>30 then table.remove(state.events,1) end
 if kind=="harvest" then state.harvest=on
 elseif kind=="ore" then state.ore=on
 else return end
 if not on and not state.harvest and not state.ore then
  state.status="Idle"
  state.target=nil
  table.clear(state.blacklist)
  local _,humanoid,root=character()
  if humanoid and root then halt(humanoid,root) end
 end
 if on then
  state.target=nil
  resetNav()
  state.status="Looking for "..(kind=="harvest" and "crops" or "ore")
 end
 return true
end
function state.isActive() return state.harvest or state.ore end
function state.probe()
 local char,humanoid,root=character()
 if not root then return {status=state.status,target=nil} end
 local best,bestDistance
 if state.harvest then best,bestDistance=nearest("Harvest",root,RADIUS) end
 if state.ore then
  local node,distance=nearest("Ore",root,RADIUS)
  if node and (not best or (node.power or 0)>(best.power or 0)) then best,bestDistance=node,distance end
 end
 if not best then best,bestDistance=choose(root,FAR_RADIUS) end
 if not best then return {status=state.status,target=nil,nodes=#nodes,position=root.Position} end
 local prompt=promptNear(best.position,char)
 local nav=state.nav
 return {
  status=state.status,nodes=#nodes,
  target=best.item,kind=best.kind,power=best.power,
  targetPosition=best.position,
  pathPoints=nav.points and #nav.points or 0,
  pathStep=nav.index or 0,
  pathFails=nav.pathFails or 0,
  distance=math.floor(bestDistance+0.5),
  available=best.config:GetAttribute("Available"),
  prompt=prompt~=nil,spent=prompt and spent(prompt) or nil,
  sickle=toolPower("Harvest"),pickaxe=toolPower("Ore"),
  position=root.Position,
 }
end
task.spawn(function()
 while state.alive do
  local ok,err=pcall(step)
  if not ok and state.alive then
   state.status="Stopped · "..tostring(err)
   state.target=nil
  end
  task.wait(TICK)
 end
end)
function state.stop()
 if not state.alive then return end
 state.alive=false
 state.harvest=false
 state.ore=false
 state.status="Off"
 state.target=nil
 for _,connection in ipairs(connections) do connection:Disconnect() end
 table.clear(connections)
 table.clear(state.blacklist)
 local _,humanoid,root=character()
 if humanoid and root then pcall(halt,humanoid,root) end
 if G.VeyraAutoGather==state then G.VeyraAutoGather=nil end
end
return "Auto gather loaded"
