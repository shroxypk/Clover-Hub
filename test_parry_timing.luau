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
print("PASS: marker coordinates, speed changes, paused/reversed tracks, late rejection, multi-hit assets")
