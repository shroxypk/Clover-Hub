-- Pure marker-prior tests; no Roblox services or executor required.
local Inference=dofile("09_attack_inference.lua")
local c=Inference.new({
 a={source="HitWindow",length=0.5,hits={0.30},name="RS.Animations.Server.Attack1"},
 b={source="HitWindow",length=0.6,hits={0.36},name="RS.Animations.Server.Attack2"},
 c={source="HitWindow",length=0.7,hits={0.42},name="RS.Animations.Server.Attack3"},
 d={source="HitWindow",length=0.8,hits={0.48},name="RS.Animations.Server.Attack4"},
 no={source="pose-motion estimate",length=1,hits={0.95},name="RS.Animations.Server.Idle"},
})
assert(c.known==4)
local t,source=c:estimate({name="RS.Animations.Server.NewAttack"},1)
assert(source=="group prior")
assert(math.abs(t-0.6)<0.001)
local t2,s2=c:estimate({name="RS.Animations.Other.Unknown"},1)
assert(source=="group prior" and s2=="global prior")
assert(math.abs(t2-0.6)<0.001)
assert(c:estimate({name="x"},0.1)==nil)
return "PASS: group prior, global prior, ignore pose estimates, length bounds"
