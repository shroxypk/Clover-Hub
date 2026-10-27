-- Run with the Luau CLI from the repository root. No live character mutation.
local M=require("../../src/parry_math")
local function near(a,b) assert(math.abs(a-b)<1e-6,tostring(a).." ~= "..tostring(b)) end
local at,latest=M.window(0.1,1,0.5,0.1,0.08)
near(at,0.22) near(latest,0.3)
-- Double-speed animation: advance by animation playhead, not wall-clock delay.
at,latest=M.window(0.1,2,0.5,0.1,0.08)
near(at,0.02) near(latest,0.1)
assert(M.window(0.1,0,0.5,0.1,0.08)==nil)
at,latest=M.window(0.49,1,0.5,0.1,0.08)
assert(latest<0,"late arrivals must not be treated as a fresh windup")
-- Feint gate: the press must not be scheduled before CloseFeint.
at,latest=M.window(0.1,1,0.45,0.1,0.08,0.3)
near(at,0.2) near(latest,0.25)
-- A feint gate cannot extend the deadline imposed by input transit time.
assert(M.window(0.1,1,0.45,0.1,0.08,0.4)==nil)
assert(M.window(0.1,1,0.4,0.2,0.08,0.35)==nil)
-- Gate past the impact means there is no valid press at all.
assert(M.window(0.1,1,0.3,0.2,0.08,0.45)==nil,"gate after impact must not schedule")
assert(M.inRange(10,0,0.1,14))
assert(M.inRange(16,20,0.1,14))
assert(not M.inRange(16,-20,0.1,14))
assert(not M.inRange(30,20,2,14),"prediction horizon must stay bounded")
assert(M.stale(2,1,1.2,0.3),"track past authored length is stale")
assert(not M.stale(0.5,1,1.2,0.3))
assert(M.stale(3,0.5,0,1),"unknown-length track expires after its hit")
-- Window outcome classification: only hits genuinely inside the granted parry
-- window are treated as unparryable; anything outside is a timing error.
assert(M.outcome(0,0.25)=="inside")
assert(M.outcome(0.11,0.25)=="inside")
assert(M.outcome(-0.11,0.25)=="inside")
assert(M.outcome(0.20,0.25)=="late")
assert(M.outcome(-0.20,0.25)=="early")
assert(M.outcome(0.11,0.25,-0.02)=="late","strict margin rejects edge hits")
assert(M.outcome(0.10,0.25,-0.02)=="inside")
assert(M.learnBias(0,0.2,0.5,0.15)<0,"late impact shrinks the lead")
print("PASS: speed, pause, late-arrival, feint gate, range, staleness, outcome")
