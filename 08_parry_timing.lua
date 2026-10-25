-- Pure scheduling in animation-time coordinates (marker times are not wall time).
local T={}
function T.window(now,position,speed,hit,latency,duration)
 if speed<=0.01 then return nil end
 local remaining=(hit-position)/speed
 local latest=now+remaining-latency+0.025
 if latest<now then return nil end
 return now+remaining-latency-duration/2,latest
end
return T
