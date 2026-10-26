-- Pure scheduling in animation-time coordinates (marker times are not wall time).
local T={}
function T.window(now,position,speed,hit,latency,duration)
 if speed<=0.01 then return nil end
 local remaining=(hit-position)/speed
 local latest=now+remaining-latency+0.025
 if latest<now then return nil end
 return now+remaining-latency-duration/2,latest
end
-- Keep temporarily irrelevant/paused swings until their marker passes or track ends.
function T.update(t,now,latency,duration,incoming)
 if now>t.expires or not t.track.IsPlaying then return "expired" end
 local speed=t.track.Speed
 if speed<=0.01 then return "waiting" end
 local at,latest=T.window(now,t.track.TimePosition,speed,t.windup,latency,duration)
 if not at then return "missed" end
 t.at=at
 t.until_=latest
 return incoming and "ready" or "waiting"
end
return T
