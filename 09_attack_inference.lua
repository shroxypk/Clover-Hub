-- Pure leave-one-out-tested priors for attacks that lack explicit HitWindow data.
-- Derived from the game's bundled HitWindow animation timestamps, NOT server hits.
local Inference={}
local function median(values)
 local sorted=table.clone(values)
 table.sort(sorted)
 return sorted[math.ceil(#sorted/2)]
end
local function groupOf(name)
 if type(name)~="string" then return nil end
 return name:match("^(.*)%.")
end
function Inference.new(seedRecords)
 local self={groups={},global={},known=0}
 for _,r in pairs(seedRecords or {}) do
  if type(r)=="table" and r.source=="HitWindow" and type(r.hits)=="table"
   and type(r.length)=="number" and r.length>=0.25 and r.length<=3 then
   local hit=r.hits[1]
   if type(hit)=="number" and hit>=0.08 and hit<r.length then
    local ratio=hit/r.length
    table.insert(self.global,ratio)
    local group=groupOf(r.name)
    if group then
     local entries=self.groups[group]
     if not entries then entries={} self.groups[group]=entries end
     table.insert(entries,ratio)
    end
    self.known+=1
   end
  end
 end
 self.globalMedian=#self.global>0 and median(self.global) or 0.56
 for group,entries in pairs(self.groups) do
  self.groups[group]={count=#entries,ratio=median(entries)}
 end
 function self:estimate(record,length)
  if type(length)~="number" or length<0.25 or length>3 or length~=length then return nil end
  local group=groupOf(record and record.name)
  local sample=group and self.groups[group]
  local ratio=sample and sample.count>=4 and sample.ratio or self.globalMedian
  local source=sample and sample.count>=4 and "group prior" or "global prior"
  local seconds=math.clamp(length*ratio,0.18,math.min(2.4,length*0.93))
  return seconds,source
 end
 return self
end
return Inference
