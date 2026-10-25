-- Clover RPG passive combat intelligence collector
-- Read-only: no remote calls, attacks, movement, or simulated inputs.
-- Stop/export: getgenv().CloverPassive.stop()
local G = (getgenv and getgenv()) or _G
if G.CloverPassive and G.CloverPassive.stop then pcall(G.CloverPassive.stop) end

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Workspace = game:GetService('Workspace')
local HttpService = game:GetService('HttpService')
local CollectionService = game:GetService('CollectionService')
local LP = Players.LocalPlayer

local S = { running=true, started=os.clock(), connections={}, actors=setmetatable({}, {__mode='k'}), tracks=setmetatable({}, {__mode='k'}), animations={}, modules={}, actorsSeen={}, events={}, counts={}, dropped=0, errors={}, lastSave=0 }
G.CloverPassive = S
local MAX_EVENTS=3500
local MAX_ANIMS=5000
local MAX_ACTORS=750
local MAX_MODULES=2000
local ROOTS = { ReplicatedStorage, Workspace, game:GetService('StarterPlayer'), game:GetService('StarterPack') }
local function safe(f, default) local ok,v=pcall(f); return ok and v or default end
local function nameOf(obj) return safe(function() return obj:GetFullName() end, tostring(obj)) end
local function keep(e)
 if #S.events>=MAX_EVENTS then table.remove(S.events,1); S.dropped+=1 end
 e.t=math.floor((os.clock()-S.started)*1000+0.5)
 S.events[#S.events+1]=e
 S.counts[e.type]=(S.counts[e.type] or 0)+1
end
local function attrs(obj)
 local a={}
 local raw=safe(function() return obj:GetAttributes() end, {})
 for k,v in pairs(raw) do
  if type(v)=='string' or type(v)=='number' or type(v)=='boolean' then a[k]=v
  else a[k]=tostring(v) end
 end
 return a
end
local function tags(obj) return safe(function() return CollectionService:GetTags(obj) end, {}) end
local function animationID(value)
 local id=tostring(value or ''):match('%d+')
 return id
end
local function registerAnimation(a)
 local id=animationID(safe(function() return a.AnimationId end, ''))
 if not id then return end
 if not S.animations[id] and S.counts.catalog_total and S.counts.catalog_total>=MAX_ANIMS then return end
 if not S.animations[id] then S.animations[id]={paths={}}; S.counts.catalog_total=(S.counts.catalog_total or 0)+1 end
 local entry=S.animations[id]
 if #entry.paths<8 then entry.paths[#entry.paths+1]=nameOf(a) end
end
local function registerModule(obj)
 if #S.modules>=MAX_MODULES then return end
 local path=nameOf(obj)
 if path:lower():match('combat') or path:lower():match('parry') or path:lower():match('npc') or path:lower():match('attack') or path:lower():match('skill') or path:lower():match('anim') or path:lower():match('hitbox') then
  S.modules[#S.modules+1]={path=path,class=obj.ClassName,attributes=attrs(obj)}
 end
end
local function trackStarted(model,track,already)
 if S.tracks[track] then return end
 S.tracks[track]=true
 local id=animationID(safe(function() return track.Animation.AnimationId end,''))
 keep({type='animation_start',actor=nameOf(model),id=id,alreadyPlaying=already or false,
  length=safe(function() return track.Length end,0),speed=safe(function() return track.Speed end,1),
  position=safe(function() return track.TimePosition end,0),looped=safe(function() return track.Looped end,false),
  priority=tostring(safe(function() return track.Priority end,''))})
 local conn=track.Stopped:Connect(function()
  if not S.running then return end
  keep({type='animation_stop',actor=nameOf(model),id=id,position=safe(function() return track.TimePosition end,0)})
 end)
 S.connections[#S.connections+1]=conn
end
local function watchActor(model)
 if S.actors[model] or (LP and model==LP.Character) then return end
 local hum=model:FindFirstChildOfClass('Humanoid')
 if not hum then return end
 S.actors[model]=true
 if #S.actorsSeen<MAX_ACTORS then
  S.actorsSeen[#S.actorsSeen+1]={path=nameOf(model),name=model.Name,attributes=attrs(model),tags=tags(model),humanoidAttributes=attrs(hum)}
 end
 keep({type='actor_seen',actor=nameOf(model)})
 local animator=hum:FindFirstChildOfClass('Animator')
 if not animator then animator=safe(function() return hum:WaitForChild('Animator',2) end,nil) end
 if animator then
  S.connections[#S.connections+1]=animator.AnimationPlayed:Connect(function(track) if S.running then trackStarted(model,track,false) end end)
  for _,track in ipairs(safe(function() return animator:GetPlayingAnimationTracks() end,{})) do trackStarted(model,track,true) end
 end
end
local function scan(obj)
 if obj:IsA('Animation') then registerAnimation(obj)
 elseif obj:IsA('ModuleScript') or obj:IsA('LocalScript') then registerModule(obj)
 elseif obj:IsA('Humanoid') and obj.Parent and obj.Parent:IsA('Model') then watchActor(obj.Parent)
 end
end
local function snapshot()
 local char=LP and LP.Character
 local output={version=1,gameId=game.GameId,placeId=game.PlaceId,elapsedSeconds=math.floor(os.clock()-S.started),
  characterState=char and attrs(char) or {},animations=S.animations,modules=S.modules,actors=S.actorsSeen,
  events=S.events,counts=S.counts,droppedEvents=S.dropped,errors=S.errors,
  caveat='Client-observable data only; no guaranteed server hit or parry times.'}
 return output
end
function S.export()
 local data=snapshot()
 local ok,json=pcall(function() return HttpService:JSONEncode(data) end)
 if not ok then warn('[CloverPassive] Encode failed: '..tostring(json)); return nil end
 local filename='CloverRPG_Passive_'..tostring(game.PlaceId)..'.json'
 if type(writefile)=='function' then
  local wrote,err=pcall(writefile,filename,json)
  if wrote then print('[CloverPassive] Saved '..filename..' ('..#json..' bytes)') else warn('[CloverPassive] Save failed: '..tostring(err)) end
 else warn('[CloverPassive] writefile unavailable; inspect getgenv().CloverPassive.export()') end
 return json
end
function S.stop()
 if not S.running then return end
 S.running=false
 for _,c in ipairs(S.connections) do pcall(function() c:Disconnect() end) end
 S.export()
 print('[CloverPassive] Stopped.')
end
for _,root in ipairs(ROOTS) do
 local ok,all=pcall(function() return root:GetDescendants() end)
 if ok then for i,obj in ipairs(all) do
  local good,err=pcall(scan,obj)
  if not good and #S.errors<30 then S.errors[#S.errors+1]=tostring(err) end
  if i%1000==0 then task.wait() end
 end end
 S.connections[#S.connections+1]=root.DescendantAdded:Connect(function(obj)
  if S.running then pcall(scan,obj) end
 end)
end
-- Observe replicated attributes on the local character without affecting combat.
local function watchSelf(char)
 if not char then return end
 local function changed(attr)
  if S.running and (attr:match('State') or attr:lower():match('parry') or attr:lower():match('block')) then
   keep({type='local_state',name=attr,value=tostring(char:GetAttribute(attr))})
  end
 end
 S.connections[#S.connections+1]=char.AttributeChanged:Connect(changed)
 local hum=char:FindFirstChildOfClass('Humanoid')
 if hum then
  S.connections[#S.connections+1]=hum.HealthChanged:Connect(function(h)
   if S.running then keep({type='local_health',value=h}) end
  end)
 end
end
if LP then
 watchSelf(LP.Character)
 S.connections[#S.connections+1]=LP.CharacterAdded:Connect(watchSelf)
end
S.export()
task.spawn(function()
 while S.running do
  task.wait(30)
  if S.running then S.export() end
 end
end)
print('[CloverPassive] Collecting passively. No combat required. Stop: getgenv().CloverPassive.stop()')