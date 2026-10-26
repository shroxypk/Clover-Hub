local T=require("./08_parry_timing")
local function near(a,b) assert(math.abs(a-b)<0.00001,tostring(a).." != "..tostring(b)) end
-- A grant should put impact at the middle of the parry window.
for _,speed in ipairs({0.5,1,2,3}) do
 local start,latest=T.window(10,0.2,speed,0.9,0.1,0.25)
 local impact=10+(0.9-0.2)/speed
 near(start+0.1+0.125,impact)
 assert(latest>=start)
end
-- Starting positions and speed changes use current animation coordinates.
local a=T.window(10,0.6,1,0.9,0.1,0.25)
local b=T.window(10,0.6,2,0.9,0.1,0.25)
assert(b<a)
assert(T.window(10,0.2,0,0.9,0.1,0.25)==nil)
assert(T.window(10,0.2,-1,0.9,0.1,0.25)==nil)
assert(T.window(10,0.95,1,0.9,0.1,0.25)==nil)
-- A missed early hit must not discard a later hit in the same animation.
assert(T.window(10,0.8,1,0.5,0.1,0.25)==nil)
assert(T.window(10,0.8,1,1.3,0.1,0.25)~=nil)
local seed=require("./attack_seed")
assert(#seed.records["125957249913572"].hits==1)
near(seed.records["125957249913572"].hits[1],0.896666646)
assert(#seed.records["132013056786173"].hits==2)
assert(#seed.records["16786767788"].hits==6)
local function swing(hit)
 return {track={Speed=1,TimePosition=0,IsPlaying=true},windup=hit,expires=30}
end
local function update(t,now,incoming)
 return T.update(t,now,0.1,0.25,incoming)
end
-- Approaching/turning attacks must survive the initial threat gate.
local approaching=swing(1)
assert(update(approaching,0,false)=="waiting")
approaching.track.TimePosition=0.8
assert(update(approaching,0.8,true)=="ready")
assert(approaching.at<=0.8 and approaching.until_>=0.8)
-- Leaving range and returning before contact must not destroy the swing.
assert(update(approaching,0.81,false)=="waiting")
assert(update(approaching,0.82,true)=="ready")
-- Paused tracks cannot send; resuming recalculates deadlines from the playhead.
approaching.track.Speed=0
assert(update(approaching,4,true)=="waiting")
approaching.track.Speed=0.5
assert(update(approaching,4,true)=="ready")
near(approaching.at,4.175)
approaching.track.Speed=2
assert(update(approaching,4,true)=="ready")
near(approaching.at,3.875)
approaching.track.IsPlaying=false
assert(update(approaching,4,true)=="expired")
-- Replay overlapping windows through a cooldown transition; select earliest.
local swings={swing(1),swing(1.05),swing(2)}
local sends={}
local cooldownUntil=0.85
for frame=0,150 do
 local now=frame/60
 local candidate
 for _,t in ipairs(swings) do
  t.track.TimePosition=now
  if not t.sent and update(t,now,true)=="ready" then
   if not candidate or t.at<candidate.at then candidate=t end
  end
 end
 if candidate and now>=candidate.at and now>=cooldownUntil then
  candidate.sent=true
  table.insert(sends,{time=now,hit=candidate.windup})
  cooldownUntil=now+0.9
 end
end
assert(#sends==2 and sends[1].hit==1 and sends[2].hit==2)
near(sends[1].time,0.85)
for _,send in ipairs(sends) do
 assert(send.time+0.1<=send.hit+0.025)
 assert(send.time+0.1+0.25>=send.hit)
end
local late=swing(0.5)
late.track.TimePosition=0.8
assert(update(late,0.8,true)=="missed")
late.windup=1.3
assert(update(late,0.8,true)=="ready")
assert(update(late,31,true)=="expired")
print("PASS: marker timing, approach/reentry, pause/resume, speed changes, stopped tracks, overlap/cooldown replay, late rejection, multi-hit assets")
