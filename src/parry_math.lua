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
 if latest<at then latest=at end
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
return M
