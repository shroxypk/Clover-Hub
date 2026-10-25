-- Pure timing estimator; callers must reject ambiguous combat events.
local L={}
function L.new(saved)
 local self={records={}}
 if type(saved)=="table" and saved.version==1 and type(saved.records)=="table" then
  for id,r in pairs(saved.records) do
   if type(id)=="string" and id:match("^%d+$") and type(r)=="table"
    and type(r.time)=="number" and r.time==r.time and r.time>=0.08 and r.time<=5
    and type(r.count)=="number" and r.count>=3 then
    self.records[id]={time=r.time,count=math.min(r.count,10000),samples={}}
   end
  end
 end
 function self:observe(id,time)
  if type(id)~="string" or not id:match("^%d+$") then return false end
  if type(time)~="number" or time~=time or time<0.08 or time>5 then return false end
  local r=self.records[id]
  if not r then r={samples={},count=0} self.records[id]=r end
  table.insert(r.samples,time)
  if #r.samples>7 then table.remove(r.samples,1) end
  if #r.samples<3 then return false end
  local sorted=table.clone(r.samples)
  table.sort(sorted)
  local median=sorted[math.ceil(#sorted/2)]
  local agreeing=0
  for _,v in ipairs(sorted) do if math.abs(v-median)<=0.08 then agreeing+=1 end end
  if agreeing<3 or agreeing/#sorted<0.7 then return false end
  r.time=r.time and r.time+math.clamp(median-r.time,-0.04,0.04) or median
  r.count=math.min(10000,r.count+1)
  return true,r.time
 end
 function self:export()
  local records={}
  for id,r in pairs(self.records) do
   if r.time then records[id]={time=r.time,count=math.max(3,r.count)} end
  end
  return {version=1,records=records}
 end
 return self
end
return L
