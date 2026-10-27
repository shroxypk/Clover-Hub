-- Broom speed: pure scaling math plus mount-aware arm lifecycle.
-- Arm/disarm follows the character's Flying attribute, so the scaler is only
-- connected while mounted and always re-arms after the game's own fly step.
local G=getgenv()
local h=assert(G.VeyraController,"Hub not loaded; run main.lua first")
local me=game.Players.LocalPlayer.Character
local root=assert(me:FindFirstChild("HumanoidRootPart"))
local originalFlying=me:GetAttribute("Flying")
local holder=Instance.new("Attachment") holder.Name="Veyra_BroomTestHolder" holder.Parent=root
local lv=Instance.new("LinearVelocity") lv.Parent=holder
local ok,err=xpcall(function()
 local scale=h.scaleBroomVelocity
 h.broomSpeed=2
 -- Grounded: nothing is connected.
 assert(h.testBroomConn()==false,"Grounded scaler connected without a mount")
 -- Mount: the attribute flip re-arms the scaler.
 me:SetAttribute("Flying",true)
 task.wait(0.35)
 assert(h.testBroomConn()==true,"Mounted scaler did not arm")
 lv.VectorVelocity=Vector3.new(40,0,0)
 scale(lv)
 assert(math.abs(lv.VectorVelocity.X-80)<0.01,"2x scale wrong: "..tostring(lv.VectorVelocity.X))
 assert(lv.VectorVelocity.Y==0,"Horizontal scale leaked into vertical")
 lv.VectorVelocity=Vector3.new(40,10,0)
 scale(lv)
 assert(math.abs(lv.VectorVelocity.X-80)<0.01 and lv.VectorVelocity.Y==10,"Vertical not preserved")
 h.broomSpeed=3
 lv.VectorVelocity=Vector3.new(200,0,0)
 scale(lv)
 assert(math.abs(lv.VectorVelocity.X-240)<0.01,"Cap missing: "..tostring(lv.VectorVelocity.X))
 h.broomSpeed=1.5
 lv.VectorVelocity=Vector3.new(40,0,0)
 scale(lv)
 assert(math.abs(lv.VectorVelocity.X-60)<0.01,"1.5x scale wrong")
 h.broomSpeed=1
 lv.VectorVelocity=Vector3.new(40,0,0)
 scale(lv)
 assert(lv.VectorVelocity.X==40,"1x modified velocity")
 -- Dismount: the scaler must release.
 me:SetAttribute("Flying",false)
 task.wait(0.3)
 assert(h.testBroomConn()==false,"Dismounted scaler stayed armed")
 -- 1x mount must not arm at all.
 h.broomSpeed=1
 me:SetAttribute("Flying",true)
 task.wait(0.35)
 assert(h.testBroomConn()==false,"Scaler armed at 1x")
end,tostring)
if originalFlying==nil then me:SetAttribute("Flying",nil) else me:SetAttribute("Flying",originalFlying) end
h.broomSpeed=1 h.armBroom() task.wait(0.15)
holder:Destroy()
assert(ok,err)
return "PASS: scaling, cap, vertical hold, mount-aware arm/disarm, 1x inert"
