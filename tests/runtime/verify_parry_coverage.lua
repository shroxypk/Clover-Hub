-- Offline proof of the press-timing margin, using the same parry_math the
-- script ships with.
--
-- Model: a press sent at local time S opens the parry at S+outbound, and the
-- granted window lasts PARRY_WINDOW. An impact authored at marker time m lands
-- on this client's clock at m (the inbound animation delay cancels), so a press
-- is correct when [S+outbound, S+outbound+window] contains the impact.
--
-- The scheduler runs on 60 Hz frames, so a press can only happen on a tick
-- boundary. This test measures how much of the marker->impact error the shipped
-- constants actually absorb, and fails if that band shrinks.
local M=require("../../src/parry_math")
local OUTBOUND=0.066     -- measured send->grant lag, 0.056..0.073 over 8 pulses
local WINDOW=0.25        -- StateDuration_Parrying, constant
local HALF=WINDOW/2
local FRAME=1/60
-- Band the empirical residual distribution has to stay inside
-- (tests/data/parry_marker_residuals.json; the Python suite enforces the bounds).
local SAFE_LOW=-0.10
local SAFE_HIGH=0.13
-- Markers earlier than roughly outbound+window/2 (+ one frame) leave no room to
-- press at all; the sweep therefore starts at 0.30s. Attacks that telegraph for
-- less than ~0.20s cannot be parried by any client-side predictor.

local function covered(marker,residual,lead)
 local impact=marker+residual
 local press
 local tick=0
 while tick<240 do
  local time=tick*FRAME
  local at,latest=M.window(time,1,marker,lead,HALF,nil)
  if at and at<=0 and latest>=0 then press=time break end
  tick+=1
 end
 if not press then return false end
 -- The window opens at the physical send->grant lag, not at the scheduling lead.
 local opens=press+OUTBOUND
 return impact>=opens and impact<=opens+WINDOW
end

local function sweep(lead)
 local tested,missed=0,0
 local worst
 for marker=0.30,0.90,0.05 do
  for step=-200,200 do
   local residual=step/1000
   tested+=1
   if not covered(marker,residual,lead) then
    missed+=1
    if residual>=SAFE_LOW and residual<=SAFE_HIGH then
     error(string.format("residual %+.3f at marker %.2f is inside the guaranteed band but missed",
      residual,marker))
    end
    if not worst or math.abs(residual)<math.abs(worst) then worst=residual end
   end
  end
 end
 return tested,missed,worst
end

local tested,missed,worst=sweep(OUTBOUND)
assert(tested>1000,"sweep did not run")
assert(missed<tested,string.format("no residual is covered (%d/%d)",missed,tested))
-- The guaranteed band must be covered exactly, with no gaps.
for marker=0.30,0.90,0.05 do
 for step=math.ceil(SAFE_LOW*1000),math.floor(SAFE_HIGH*1000) do
  local residual=step/1000
  assert(covered(marker,residual,OUTBOUND),string.format(
   "missed residual %+.3f at marker %.2f",residual,marker))
 end
end
-- Centring matters. `lead` is the measured send->grant lag (0.066s) and the
-- scheduler presses `lead + window/2` early, which puts the granted window
-- exactly on the marker. Using the raw *observed* grant lag as the lead (0.15s,
-- the pre-fix code) presses too early and loses the late half of the band.
-- (The window itself always opens at press+outbound, so the lead cannot cancel.)
local centredMisses,lateMisses=0,0
for marker=0.30,0.90,0.05 do
 for step=math.ceil(SAFE_LOW*1000),math.floor(SAFE_HIGH*1000) do
  local residual=step/1000
  if not covered(marker,residual,OUTBOUND) then centredMisses+=1 end
  if not covered(marker,residual,0.15) then lateMisses+=1 end
 end
end
assert(centredMisses==0,string.format("centred lead missed %d band residuals",centredMisses))
assert(lateMisses>50,string.format(
 "an early press should lose the late band: centred %d vs early %d",centredMisses,lateMisses))

-- Learning direction: a late impact (positive residual) moves the press later,
-- i.e. shrinks the lead; the shift is clamped.
assert(M.learnBias(0,0.10,0.5,0.15)<0,"late impact must shrink the lead")
assert(M.learnBias(0,-0.10,0.5,0.15)>0,"early impact must grow the lead")
assert(M.learnBias(0.14,-0.10,0.5,0.15)==0.15,"clamped high")
assert(M.learnBias(-0.14,0.10,0.5,0.15)==-0.15,"clamped low")
assert(math.abs(M.learnBias(0.14,0.10,0.5,0.15)-0.09)<1e-9,"inside the clamp it just steps")
assert(M.horizon(0.2,WINDOW)==0.45,"coverage horizon")

-- Reference numbers for the README: with the shipped constants the press lands
-- 0.191s before the marker and the window spans 0.25s.
local marker=0.60
local press
for tick=0,240 do
 local time=tick*FRAME
 local at,latest=M.window(time,1,marker,OUTBOUND,HALF,nil)
 if at and at<=0 and latest>=0 then press=time break end
end
assert(press,marker.." was never scheduled")
print(string.format("press %.3fs, window [%.3f, %.3f] for a marker at %.2f",
 press,press+OUTBOUND,press+OUTBOUND+WINDOW,marker))
assert(math.abs((marker-(press+OUTBOUND+HALF)))<=FRAME,
 string.format("window should be centred on the marker, off by %.3f",
 marker-(press+OUTBOUND+HALF)))
print(string.format("PASS: centred press covers every residual in [%+.3f, %+.3f] "
 .."for markers 0.30-0.90s; old 0.15s lead missed %d of those",
 SAFE_LOW,SAFE_HIGH,lateMisses))
