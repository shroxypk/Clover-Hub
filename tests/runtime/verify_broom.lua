-- Broom speed scaler: velocity scaling, cap, vertical hold, arm lifecycle.
local G=getgenv()
local h=assert(G.VeyraController,"Hub not loaded; run main.lua first")
local me=game.Players.LocalPlayer.Character
local root=assert(me:FindFirstChild("HumanoidRootPart"))
local holder=Instance.new("Attachment") holder.Name="Veyra_BroomTestHolder" holder.Parent=root
local lv=Instance.new("LinearVelocity") lv.Parent=holder
local ok,err=xpcall(function()
 h.broomSpeed=2
 h.armBroom()
 task.wait(0.3)
 assert(h.testBroomConn~=nil and h.testBroomConn(),"Scaler did not arm")
 local scale=h.scaleBroomVelocity
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
 -- Disarm: speed back to 1 through armBroom must drop the connection.
 h.armBroom()
 task.wait(0.2)
 assert(not h.testBroomConn(),"Scaler stayed armed at 1x")
end,tostring)
holder:Destroy()
assert(ok,err)
return "PASS: broom scaling, cap, vertical hold, arm/disarm"
