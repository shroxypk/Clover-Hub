-- Uses received round data and the game's normal input handlers.
-- No remote firing, argument changes, or metatable hooks.
local G = getgenv()
if G.CRLF_Minigames then G.CRLF_Minigames.stop() end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local state = {enabled = false, alive = true, connections = {}, rings = {}, log = {}, results = {}, paused = false, diagnostics = false, active = false}
G.CRLF_Minigames = state
-- Worker lifecycle: declared early so stop/setEnabled can reach them.
local worker
local missSince = 0
local mine,harvest -- assigned below; the worker resolves them at call time
local startWorker,stopWorker
local function connect(signal, callback)
 local c = signal:Connect(callback)
 table.insert(state.connections, c)
 return c
end
local function log(text)
 table.insert(state.log, string.format("%.3f %s", os.clock(), text))
 if #state.log > 300 then table.remove(state.log, 1) end
 state.dirty = true
end
local function release()
 if state.keyDown then
  state.keyDown = false
  VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
 end
end
function state.stop()
 state.alive = false
 release()
 if worker then worker:Disconnect() worker = nil end
 for _,c in ipairs(state.connections) do c:Disconnect() end
 table.clear(state.connections)
 table.clear(state.rings)
 if G.CRLF_Minigames == state then G.CRLF_Minigames = nil end
end
function state.setEnabled(enabled)
 state.enabled = enabled
 if not enabled then
  release()
  state.active = false
  state.activity = "Waiting for minigame"
  stopWorker()
 end
end
-- Idle cost is zero: no worker connection runs between minigames. Opening
-- events start the worker; Close, the toggle, or the safety net stop it.
function startWorker()
 if worker or not state.alive then return end
 missSince = 0
 worker = RunService.Heartbeat:Connect(function()
  if not state.alive then return end
  if not state.enabled or state.paused or UIS:GetFocusedTextBox() or not state.active then release() return end
  local mining = mine()
  local harvesting = harvest()
  if mining or harvesting then
   missSince = 0
   local activity = mining and "Mining" or "Harvesting"
   if activity ~= state.activity then state.activity = activity end
  elseif missSince == 0 then
   missSince = os.clock()
  elseif os.clock() - missSince > 2 then
   -- Safety net: GUI gone but no Close event arrived - go back to sleep.
   state.active = false
   state.activity = "Waiting for minigame"
   stopWorker()
  end
 end)
end
function stopWorker()
 if worker then worker:Disconnect() worker = nil end
end
state.isWorking = function() return worker ~= nil end
local function receive(kind, action, data)
 if type(data) ~= "table" then return end
 if action == "Open" then
  state[kind] = data.Session
  state.active = true
  state.activity = nil
  startWorker()
  if kind == "mine" then state.round = nil else table.clear(state.rings) end
  if kind == "mine" then release() end
 elseif data.Session ~= state[kind] then return
 elseif action == "Close" then
  state[kind] = nil
  if kind == "mine" then state.round = nil else table.clear(state.rings) end
  if state.mine == nil and state.harvest == nil then
   state.active = false
   state.activity = "Waiting for minigame"
   stopWorker()
  end
 elseif kind == "mine" and action == "Round" then
  release()
  state.round = {data = table.clone(data), pressed = false}
 elseif kind == "harvest" and action == "Ring" then
  state.rings[data.Id] = table.clone(data)
 elseif action == "Result" then
  if kind == "harvest" and data.Id then state.rings[data.Id]=nil end
  local result = tostring(data.Result)
  state.results[kind .. ":" .. result] = (state.results[kind .. ":" .. result] or 0) + 1
  state.lastResult = kind .. ": " .. result
  log("SERVER " .. state.lastResult)
 end
 log(kind .. " " .. action)
end
connect(remotes.HarvestTiming.OnClientEvent, function(a,d) receive("mine",a,d) end)
connect(remotes.HarvestRings.OnClientEvent, function(a,d) receive("harvest",a,d) end)
local function visible(object, root)
 while object and object ~= root do
  if object:IsA("GuiObject") and not object.Visible then return false end
  object = object.Parent
 end
 return object == root and root.Enabled
end
local lastZone
local previousSpinner,previousTime,previousToken
-- Cached GUI path per session; the visibility chain is only re-walked when the
-- parent references go stale, not on every frame.
local mineUI,harvestUI={},{}
function mine()
 local cache=mineUI
 local pg=player.PlayerGui
 local screen=cache.screen
 if not screen or screen.Parent~=pg then
  screen=pg:FindFirstChild("HarvestTiming")
  cache.screen=screen
  cache.session=nil
 end
 if not screen then return false end
 local session=cache.session
 if not session or session.Parent~=screen then
  session=screen:FindFirstChild("Session")
  cache.session=session
  cache.ring=nil
 end
 if not session or not visible(session,screen) then return false end
 local ring=cache.ring
 if not ring or ring.Parent~=session then ring=session:FindFirstChild("Ring") cache.ring=ring end
 local spinner=ring and ring:FindFirstChild("Spinner")
 if not spinner then return true end
 local target, width, token
 local round = state.round
 if round then
  local d = round.data
  if round.pressed or workspace:GetServerTimeNow() < d.StartTime then return true end
  target, width, token = (d.RedStart + d.RedSize/2)*360, d.RedSize*360, round
 else
  -- A session already open when this patch loads has no received round yet.
  for _,outline in ipairs(ring:GetChildren()) do
   local zones = outline.Name == "Outline" and outline:FindFirstChild("Zones")
   local crit = zones and zones:FindFirstChild("CritZone")
   if crit and visible(crit,screen) then
    local x,y,n = 0,0,0
    for _,seg in ipairs(crit:GetChildren()) do
     if seg:IsA("GuiObject") then
      x += math.sin(math.rad(seg.Rotation))
      y += math.cos(math.rad(seg.Rotation))
      n += 1
     end
    end
    if n>0 then target,width,token = math.deg(math.atan2(x,y)),math.max(2,n),crit end
   end
  end
 end
 if not target or token == lastZone then return true end
 local clock=os.clock()
 local rotation=spinner.Rotation
 local velocity=0
 if previousToken==token and previousTime and clock>previousTime and clock-previousTime<0.1 then
  velocity=((rotation-previousSpinner+180)%360-180)/(clock-previousTime)
 end
 previousSpinner,previousTime,previousToken=rotation,clock,token
 local gap = math.abs((spinner.Rotation-target+180)%360-180)
 -- Lead by one short input frame only when the predicted position remains
 -- inside the critical zone. This catches narrow zones between frames.
 local predicted=math.abs((rotation+velocity/120-target+180)%360-180)
 if gap <= math.max(0.5, width*0.35) or (math.abs(velocity)>1 and predicted<=width*0.25) then
  lastZone = token
  if round then round.pressed = true end
  state.keyDown = true
  VIM:SendKeyEvent(true,Enum.KeyCode.Space,false,game)
  log(string.format("INPUT mine Space gap=%.2f",gap))
  task.delay(0.025,release)
 end
 return true
end
local lastMouse = 0
function harvest()
 local cache=harvestUI
 local pg=player.PlayerGui
 local screen=cache.screen
 if not screen or screen.Parent~=pg then
  screen=pg:FindFirstChild("HarvestRings")
  cache.screen=screen
  cache.holder=nil
 end
 if not screen then return false end
 local holder=cache.holder
 if not holder or holder.Parent~=screen then holder=screen:FindFirstChild("Holder") cache.holder=holder end
 if not holder or not visible(holder,screen) then return false end
 local arena=cache.arena
 if not arena or arena.Parent~=holder then arena=holder:FindFirstChild("Arena") cache.arena=arena end
 local basin=arena and (cache.basin and cache.basin.Parent==arena and cache.basin or arena:FindFirstChild("Player"))
 cache.basin=basin
 if not basin then return true end
 local now = workspace:GetServerTimeNow()
 local chosen, deadline
 for id,d in pairs(state.rings) do
  local finish = d.StartTime+d.Travel
   if now > finish then state.rings[id] = nil
  elseif not deadline or finish<deadline then chosen,deadline=d,finish end
 end
 local angle
 if chosen then
  -- Start steering early: the real client limits turn rate to 540 deg/s.
  angle = chosen.GapCenter+(chosen.Spin or 0)*chosen.Travel
 else
  local rings = arena:FindFirstChild("Rings")
  local smallest
  if rings then
   for _,r in ipairs(rings:GetChildren()) do
    local stroke = r:FindFirstChildOfClass("UIStroke")
    if r:IsA("GuiObject") and r.Visible and (not stroke or stroke.Transparency<0.05) then
     if not smallest or r.AbsoluteSize.X<smallest.AbsoluteSize.X then smallest=r end
    end
   end
  end
  if smallest then angle=smallest.Rotation+90 end
 end
 if angle and os.clock()-lastMouse >= 1/60 then
  lastMouse=os.clock()
  local center=basin.AbsolutePosition+basin.AbsoluteSize/2
  local a=math.rad(angle)
  -- Exact coordinate space used by the game: GetMouseLocation minus basin center.
  VIM:SendMouseMoveEvent(math.round(center.X+math.sin(a)*110), math.round(center.Y-math.cos(a)*110), game)
 end
 return true
end
-- One immediate touch at load only, to adopt a session already in progress.
task.defer(function()
 if state.alive and state.enabled and (mine() or harvest()) then
  state.active = true
  startWorker()
 end
end)
log("solver loaded")
return "Minigames engine loaded"
