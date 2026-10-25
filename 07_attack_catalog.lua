-- Reads animation assets; never plays animations or sends combat requests.
local Catalog={}
-- Contact-like marker names are estimates until combat confirms their meaning.
-- Projectile launch/release/throw markers are deliberately not impact timings.
local contactMarkers={Attack=true,Attack1=true,Attack2=true,Attack3=true,Attack4=true,
 Kick=true,RightSlash=true,LeftSlash=true,Slash=true,Strike=true,FinalStrike=true,
 Slam=true,Impact=true,SpinWindow=true,SpinWindow2=true}
local function resolve(r)
 if #r.hits>0 then r.source="HitWindow" return r end
 local seen={}
 for _,m in ipairs(r.markers or {}) do
  if contactMarkers[m.name] and type(m.time)=="number" and m.time>=0 and m.time<=r.length and not seen[m.time] then
   seen[m.time]=true
   table.insert(r.hits,m.time)
  end
 end
 table.sort(r.hits)
 r.source=#r.hits>0 and "contact-marker estimate" or "unknown"
 return r
end
function Catalog.new(seed)
 local self={records={},pending={},queued={},alive=true,loaded=0,failed=0,busy=false,attacks={},noncombat={}}
 local Http=game:GetService("HttpService")
 local provider=game:GetService("KeyframeSequenceProvider")
 local path="CloverRPG/attack_catalog_"..game.PlaceId..".json"
 local function accept(records)
  if type(records)~="table" then return end
  for id,r in pairs(records) do
   if type(id)=="string" and id:match("^%d+$") and type(r)=="table"
    and type(r.hits)=="table" and type(r.length)=="number" and r.length>=0 and r.length<math.huge then
    local hits={}
    for _,t in ipairs(r.hits) do
     if type(t)=="number" and t==t and t>=0 and t<=r.length then table.insert(hits,t) end
    end
    table.sort(hits)
    local entry={hits=hits,length=r.length,name=r.name,markers=r.markers,source=r.source}
    -- Preserve the distinction when reloading derived contact estimates.
     entry=r.source=="contact-marker estimate" and entry or resolve(entry)
     local previous=self.records[id]
     local function rank(record)
      return record.source=="HitWindow" and 3 or (#record.hits>0 and 2 or 1)
     end
     -- An older disk estimate must not replace explicit bundled hit markers.
     if not previous or rank(entry)>=rank(previous) then self.records[id]=entry end
   end
  end
 end
 if seed and seed.placeId==game.PlaceId then accept(seed.records) end
 if isfile(path) then
  local ok,saved=xpcall(function() return Http:JSONDecode(readfile(path)) end,tostring)
  if ok and type(saved)=="table" and saved.version==1 and saved.placeId==game.PlaceId then
   accept(saved.records)
  end
 end
 function self:save()
  local ok,err=xpcall(function()
   if not isfolder("CloverRPG") then makefolder("CloverRPG") end
   writefile(path,Http:JSONEncode({version=1,placeId=game.PlaceId,records=self.records}))
  end,tostring)
  if not ok then self.lastError=err end
 end
 function self:request(animation)
  local id=animation.AnimationId:match("%d+")
  if not id or self.records[id] or self.queued[id] then return end
  self.queued[id]=true
  table.insert(self.pending,{id=id,name=animation:GetFullName()})
  if self.busy then return end
  self.busy=true
  task.spawn(function()
   while self.alive and #self.pending>0 do
    local item=table.remove(self.pending,1)
    local ok,result=xpcall(function()
     local seq=provider:GetKeyframeSequenceAsync("rbxassetid://"..item.id)
     local hits,markers,seen={},{},{}
     local length=0
     for _,frame in ipairs(seq:GetKeyframes()) do
      length=math.max(length,frame.Time)
      local hit=frame.Name=="HitWindow"
      for _,marker in ipairs(frame:GetMarkers()) do
       table.insert(markers,{name=marker.Name,time=frame.Time,value=marker.Value})
       if marker.Name=="HitWindow" then hit=true end
      end
      if hit and not seen[frame.Time] then
       seen[frame.Time]=true
       table.insert(hits,frame.Time)
      end
     end
     seq:Destroy()
     table.sort(hits)
     return resolve({hits=hits,length=length,markers=markers,name=item.name})
    end,tostring)
    if not self.alive then break end
     if ok then self.records[item.id]=result self.loaded+=1
     else
      self.failed+=1 self.lastError=result
      item.attempts=(item.attempts or 0)+1
      -- Retry transient asset failures, bounded to three attempts per session.
      if item.attempts<3 then table.insert(self.pending,item) end
     end
    if self.loaded%20==0 then self:save() end
    task.wait(0.1)
   end
   self.busy=false
   self:save()
  end)
 end
  function self:classify(animation,root)
   if not root or not animation:IsDescendantOf(root) then return end
   local attackFolders={Server=true,Skills=true,Combat=true,NPCS=true,Crit=true,Aerials=true,Uppercuts=true,Magic=true,Rigs=true}
   local folder=animation
   while folder.Parent and folder.Parent~=root do folder=folder.Parent end
   local id=animation.AnimationId:match("%d+")
   if id then
    if attackFolders[folder.Name] then self.attacks[id]=true else self.noncombat[id]=true end
   end
  end
  function self:scan(root)
   if not root then return end
   for _,animation in ipairs(root:GetDescendants()) do
    if animation:IsA("Animation") then
     self:classify(animation,root)
    self:request(animation)
   end
  end
 end
 function self:stop()
  self.alive=false
  table.clear(self.pending)
  self:save()
 end
 return self
end
return Catalog
