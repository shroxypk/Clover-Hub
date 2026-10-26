local G=getgenv()
local h=assert(G.CRLF_HubController)
local m=assert(G.CRLF_Minigames)
assert(not m.mine and not m.harvest,"Wait until the minigame ends before checking unload")
local gui=h.gui
local body=gui.Main.Body
local mark=""
local function step(text) mark=text end
local function softActivate(button)
 assert(button,"Missing control: "..mark)
 for _,c in ipairs(getconnections(button.Activated)) do
  if c.Function then pcall(c.Function) end
 end
end
local function guard()
 local ok,err=pcall(function()
  step("minigames toggle")
  local VIM=game:GetService("VirtualInputManager")
  assert(m.enabled==false,"Minigames must default off")
  softActivate(body["Auto Minigames"]) assert(m.enabled)
  softActivate(body["Auto Minigames"]) assert(not m.enabled)
  softActivate(body["Auto Minigames"]) assert(m.enabled)
  step("parry toggle")
  assert(h.parry==false,"Parry must default off")
  softActivate(body["Auto Parry"]) assert(h.parry==true)
  softActivate(body["Auto Parry"]) assert(h.parry==false)
  softActivate(body["Auto Parry"]) assert(h.parry==true)
  step("removed rows")
  assert(body:FindFirstChild("Auto Dodge")==nil and body:FindFirstChild("Auto Block")==nil and body:FindFirstChild("Prefer Dodge")==nil,"Stale defense controls")
  assert(body:FindFirstChild("Quest Tracker")==nil and body:FindFirstChild("Low Effects")==nil,"Stale overlay controls")
   step("broom speed row")
   local broomRow=body:FindFirstChild("Broom Speed")
   assert(broomRow and broomRow:FindFirstChild("Plus") and broomRow:FindFirstChild("Minus") and broomRow:FindFirstChild("Value"),"Broom stepper incomplete")
   softActivate(broomRow.Plus) assert(h.broomSpeed==1.25,"Plus did not step")
   softActivate(broomRow.Plus) assert(h.broomSpeed==1.5)
   softActivate(broomRow.Minus) assert(h.broomSpeed==1.25,"Minus did not step")
   softActivate(broomRow.Minus) assert(h.broomSpeed==1,"Floor broken")
   softActivate(broomRow.Minus) assert(h.broomSpeed==1,"Below floor")
  step("resize grips")
  local frame=gui.Main
  assert(frame:FindFirstChild("ResizeGrip") and frame:FindFirstChild("ResizeGrip").Visible,"Corner grip missing")
  assert(frame:FindFirstChild("ResizeRight") and frame:FindFirstChild("ResizeBottom"),"Edge grips missing")
  step("minigame idle")
  assert(m.isWorking~=nil and m.isWorking()==false,"Idle minigame worker still running")
  step("keybinds")
  local bodyFrame=frame:FindFirstChild("Body")
  local function key(code,processed) h.testKeybind({KeyCode=code,UserInputType=Enum.UserInputType.Keyboard},processed) end
  key(Enum.KeyCode.Delete,true)
  assert(bodyFrame.Visible==true,"Processed keybind fired")
  key(Enum.KeyCode.Delete,false)
  assert(bodyFrame.Visible==false,"Delete keybind did not minimize")
  key(Enum.KeyCode.Delete,false)
  assert(bodyFrame.Visible==true,"Delete keybind did not restore")
  local wideBefore=frame.AbsoluteSize.X
  key(Enum.KeyCode.Insert,false)
  task.wait(0.3)
  assert(frame.AbsoluteSize.X>wideBefore,"Insert keybind did not resize")
  key(Enum.KeyCode.Insert,false)
  key(Enum.KeyCode.Insert,false)
  task.wait(0.3)
  assert(math.abs(frame.AbsoluteSize.X-wideBefore)<2,"Resize cycle did not wrap")
  step("minimize")
  local minimize=frame:FindFirstChild("Minimize")
  assert(minimize,"No minimize button")
  local function clickMinimize()
   for _,c in ipairs(getconnections(minimize.Activated)) do if c.Function then c.Function() end end
  end
  clickMinimize()
  assert(bodyFrame and bodyFrame.Visible==false,"Minimize did not hide body")
  clickMinimize()
  assert(bodyFrame and bodyFrame.Visible==true,"Minimize did not restore body")
   step("state snapshot")
   assert(gui.Parent==game:GetService("Players").LocalPlayer.PlayerGui,"GUI must be accessible to ordinary event callbacks")
   step("heartbeat GUI access")
   local callbackFailure
   local frames=0
   local probe=game:GetService("RunService").Heartbeat:Connect(function()
    local passed,message=xpcall(function()
     assert(gui.Enabled~=nil and frame.Status.Text~=nil)
     frames+=1
    end,tostring)
    if not passed then callbackFailure=message end
   end)
   task.wait(0.75)
   probe:Disconnect()
   assert(not callbackFailure,callbackFailure)
   assert(frames>0,"No heartbeat callbacks observed")
   step("state snapshot")
  local hubConnections=table.clone(h.connections)
  local engineConnections=table.clone(m.connections)
  local engineAliveBefore=m.alive
  assert(engineAliveBefore)
  local heldBefore=h.autoHeld==true
  step("unload")
  h.unload()
   assert(h.alive==false and m.alive==false)
   if h.catalog then assert(not h.catalog.alive and #h.catalog.pending==0,"Catalog did not stop") end
  assert(gui.Parent==nil)
  assert(G.CRLF_HubController==nil and G.CRLF_Minigames==nil)
  for _,c in ipairs(hubConnections) do assert(not c.Connected,"Hub connection leaked: "..mark) end
  for _,c in ipairs(engineConnections) do assert(not c.Connected,"Engine connection leaked: "..mark) end
 if heldBefore then
   step("keydown check")
   -- If the user is physically holding F, the key stays down by design; only
   -- flag it when we also saw no manual press during the hold.
   local uiS=game:GetService("UserInputService")
   if uiS:IsKeyDown(Enum.KeyCode.F) and h.userF==false then
    print("WARN: F still down after unload; likely user-held key")
   end
  end
  step("reload")
   loadstring(readfile("CloverRPG/main.lua"),"main.lua")()
  assert(G.CRLF_HubController.alive and G.CRLF_Minigames.alive)
 end)
 return ok,err
end
local ok,err=guard()
if not ok then
  -- Roll the fresh install back out so a failed verify leaves no GUI behind.
  if G.CRLF_HubController then pcall(G.CRLF_HubController.unload) end
  return "FAIL: step="..mark.." err="..tostring(err)
end
return "PASS: defaults off, toggles, broom stepper, grips, idle worker, keybinds, minimize, unload, reload"
