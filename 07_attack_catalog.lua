-- Reads animation assets; never plays animations or sends combat requests.
local Catalog={}
local attackFolders={Server=true,Skills=true,Combat=true,NPCS=true,Crit=true,Aerials=true,Uppercuts=true,Magic=true,Rigs=true}

local function recordRank(record)
 return record.source=="HitWindow" and 3 or (#record.hits>0 and 2 or 1)
end
-- Contact-like marker names are estimates until combat confirms their meaning.
-- Projectile launch/release/throw markers are deliberately not impact timings.
local contactMarkers={Attack=true,Attack1=true,Attack2=true,Attack3=true,Attack4=true,
 Kick=true,RightSlash=true,LeftSlash=true,Slash=true,Strike=true,FinalStrike=true,
 Slam=true,Impact=true,SpinWindow=true,SpinWindow2=true}
local function resolve(r)
 if #r.hits>0 then r.source="HitWindow" return r end
 local seen={}
 for _,m in ipairs(r.markers or {}) do
  if type(m)=="table" and contactMarkers[m.name] and type(m.time)=="number" and m.time>=0 and m.time<=r.length and not seen[m.time] then
   seen[m.time]=true
   table.insert(r.hits,m.time)
  end
 end
 table.sort(r.hits)
 r.source=#r.hits>0 and "contact-marker estimate" or "unknown"
 return r
end
function Catalog.new(seed)
 local self={records={},pending={},queued={},urgentRetried={},processingId=nil,alive=true,loaded=0,failed=0,busy=false,dirty=false,attacks={},noncombat={}}
 local Http=game:GetService("HttpService")
 local provider=game:GetService("KeyframeSequenceProvider")
 local clipProvider=game:GetService("AnimationClipProvider")
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
    local entry={hits=hits,length=r.length,name=r.name,markers=type(r.markers)=="table" and r.markers or {},source=r.source}
    -- Preserve the distinction when reloading derived contact estimates.
     entry=r.source=="contact-marker estimate" and entry or resolve(entry)
     local previous=self.records[id]
     -- An older disk estimate must not replace explicit bundled hit markers.
     if not previous or recordRank(entry)>=recordRank(previous) then self.records[id]=entry end
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
  if not self.dirty then return end
  local ok,err=xpcall(function()
   if not isfolder("CloverRPG") then makefolder("CloverRPG") end
   writefile(path,Http:JSONEncode({version=1,placeId=game.PlaceId,records=self.records}))
  end,tostring)
  if ok then self.dirty=false else self.lastError=err end
 end
  function self:request(animation,urgent)
   if not self.alive then return end
   local id=animation.AnimationId:match("%d+")
   if not id then return end
   -- Background scans reuse cached unknowns; a live attack gets one retry
   -- to recover improved marker data without flooding the asset provider.
   if self.records[id] and (#self.records[id].hits>0 or not urgent) then return end
   if self.queued[id] then
    local stillPending=false
    for i,item in ipairs(self.pending) do
     if item.id==id then
      stillPending=true
      if urgent then table.remove(self.pending,i) table.insert(self.pending,1,item) end
      break
     end
    end
    if stillPending or self.processingId==id then return end
    -- Permit one extra high-priority pass for a previously completed
    -- unknown result. Failed fetches without a record stay bounded.
    if not (urgent and self.records[id] and #self.records[id].hits==0
     and not self.urgentRetried[id]) then return end
    self.urgentRetried[id]=true
   end
   self.queued[id]=true
   table.insert(self.pending,urgent and 1 or #self.pending+1,{id=id,name=animation:GetFullName()})
  if self.busy then return end
  self.busy=true
  task.spawn(function()
   while self.alive and #self.pending>0 do
    local item=table.remove(self.pending,1)
    self.processingId=item.id
    local ok,result=xpcall(function()
     local asset="rbxassetid://"..item.id
     local seq
     local okClip,clip=pcall(function() return clipProvider:GetAnimationClipAsync(asset) end)
     if okClip and clip and clip:IsA("KeyframeSequence") then seq=clip
     else
      if okClip and clip then clip:Destroy() end
      seq=provider:GetKeyframeSequenceAsync(asset)
     end
     -- Release the fetched instance even if a malformed clip cannot be parsed.
     local parsedOk,parsed=pcall(function()
      local hits,markers,seen={},{},{}
      local length=0
      for _,frame in ipairs(seq:GetKeyframes()) do
       length=math.max(length,frame.Time)
       local hit=frame.Name=="HitWindow"
       if contactMarkers[frame.Name] then
        table.insert(markers,{name=frame.Name,time=frame.Time})
       end
       for _,marker in ipairs(frame:GetMarkers()) do
        table.insert(markers,{name=marker.Name,time=frame.Time,value=marker.Value})
        if marker.Name=="HitWindow" then hit=true end
       end
       if hit and not seen[frame.Time] then
        seen[frame.Time]=true
        table.insert(hits,frame.Time)
       end
      end
      table.sort(hits)
      return resolve({hits=hits,length=length,markers=markers,name=item.name})
     end)
     seq:Destroy()
     if not parsedOk then error(parsed) end
     return parsed
    end,tostring)
    self.processingId=nil
    if not self.alive then break end
     if ok then
      self.records[item.id]=result
      self.loaded+=1
      self.dirty=true
      if self.loaded%20==0 then self:save() end
     else
      self.failed+=1 self.lastError=result
      item.attempts=(item.attempts or 0)+1
      -- Retry transient asset failures, bounded to three attempts per session.
      if item.attempts<3 then table.insert(self.pending,item) end
     end
    task.wait(0.1)
   end
   self.busy=false
   self:save()
  end)
 end
  function self:classify(animation,root)
   if not root or not animation:IsDescendantOf(root) then return end
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
  if not self.alive then return end
  self.alive=false
  table.clear(self.pending)
  self:save()
 end
 return self
end
return Catalog
