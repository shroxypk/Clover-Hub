-- Pure timing/geometry helpers, independent of Roblox services.
local M={}
-- Return the wall-clock delay at which the parry input should start, and the
-- latest delay at which it is still worth sending. `speed` is animation speed,
-- so all animation-time deltas are divided by it. `gate` is an animation-time
-- position before which the swing can still be cancelled (feint window).
function M.window(position,speed,hit,lead,halfWindow,gate)
 if speed<=0.01 then return nil end
 local remaining=(hit-position)/speed
 local target=remaining-lead
 local earliest
 if gate and position<gate then earliest=(gate-position)/speed end
 local at=target-halfWindow
 if earliest and at<earliest then at=earliest end
 if at>remaining+0.02 then return nil end
 local latest=target
  if at>latest then return nil end
 return at,latest
end
function M.inRange(distance,closingSpeed,remaining,range)
 return distance<=range or (remaining>0 and distance-closingSpeed*math.min(remaining,0.25)<=range)
end
-- A track past its authored length (plus slack) is stale; looping attacks must
-- still be observed again rather than rescheduled forever.
function M.stale(position,hit,length,slack)
 if length and length>0 and position>length+slack then return true end
 return position>hit+slack+0.5
end
-- Fold one observed miss into a per-asset scheduling shift. `residual` is
-- impact_time - predicted_impact_time, so a late impact (positive) moves the
-- press later, which means a smaller lead.
function M.learnBias(bias,residual,gain,limit)
 gain=gain or 0.5 limit=limit or 0.15
 return math.clamp((bias or 0)-gain*residual,-limit,limit)
end
-- Classify a hit we actually took against the parry window that was open.
-- `residual` is impact_time - predicted_impact_time and the window is centred
-- on the prediction, so |residual| <= window/2 means the impact landed inside
-- the granted parry and we were still damaged: the attack is not parryable
-- (grab, unblockable skill, boss move, safezone) and it must NOT be learned as
-- a timing error, or it would poison the lead for parryable attacks too.
function M.outcome(residual,window,tolerance)
 tolerance=tolerance or 0.02
 local half=window/2+tolerance
 if residual>=-half and residual<=half then return "inside" end
 if residual>0 then return "late" end
 return "early"
end
-- A single granted parry covers every impact up to this far after the one it
-- was scheduled for.
function M.horizon(remaining,window)
 return remaining+window
end
return M
