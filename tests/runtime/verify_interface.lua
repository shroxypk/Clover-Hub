local G=getgenv()
local h=assert(G.VeyraController)
local m=assert(G.VeyraMinigames)
assert(not m.mine and not m.harvest and not m.isWorking(),"Wait until the minigame ends before checking unload")
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
  step("quest toggle")
  local qa=assert(h.questAssist,"Quest guide not loaded")
  assert(qa.enabled==false,"Quest guide must default off")
  softActivate(body["Quest Assistance"]) assert(qa.enabled)
  softActivate(body["Quest Assistance"]) assert(not qa.enabled)
   assert(workspace:FindFirstChild("VeyraQuestAnchors")==nil,"Disabled guide left anchors")
   step("parry lifecycle")
   local ap=assert(h.parry)
   assert(not ap.enabled and not ap.isWorking(),"Parry must default off")
   ap.setEnabled(true) assert(ap.enabled and ap.isWorking())
   ap.setEnabled(false) assert(not ap.enabled and not ap.isWorking())
   assert(body:FindFirstChild("Auto Parry")==nil,"Auto Parry row must be hidden")
   step("removed aura rows")
   assert(body:FindFirstChild("Kill Aura")==nil and body:FindFirstChild("Fight Only")==nil
    and body:FindFirstChild("Aura Range")==nil and body:FindFirstChild("Aura Turn Rate")==nil,"Aura controls still present")
   assert(h.killAura==nil,"Aura still exposed on the hub")
   assert(G.VeyraKillAura==nil or not G.VeyraKillAura.enabled,"Legacy aura still enabled")
   step("boss alerts toggle")
   local ba=assert(h.bossAlerts,"Boss alerts not loaded")
   assert(ba.enabled==false,"Boss alerts must default off")
   softActivate(body["Boss Attack Alerts"]) assert(ba.enabled)
   softActivate(body["Boss Attack Alerts"]) assert(not ba.enabled)
   step("removed advisor")
   assert(body:FindFirstChild("Build Advisor")==nil,"Stale build advisor row")
   assert(h.advisor==nil and G.VeyraBuildAdvisor==nil,"Build advisor still exposed")
   local pg=game:GetService("Players").LocalPlayer.PlayerGui
   assert(pg:FindFirstChild("VeyraBuildAdvisor")==nil,"Build advisor GUI still present")
   step("removed rows")
   assert(body:FindFirstChild("Auto Dodge")==nil and body:FindFirstChild("Auto Block")==nil and body:FindFirstChild("Prefer Dodge")==nil,"Stale defense controls")
  assert(body:FindFirstChild("Auto Loot")==nil and body:FindFirstChild("Auto Equip Best")==nil,"Stale QoL controls")
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
  assert(h.isCursorActive(),"Visible UI cursor is not connected")
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
  step("unload")
  h.unload()
   assert(h.alive==false and m.alive==false)
  assert(gui.Parent==nil)
   assert(G.VeyraController==nil and G.VeyraMinigames==nil)
   assert(G.VeyraParry==nil and not ap.isWorking() and not ap.alive,"Parry teardown leaked")
   assert(G.VeyraBossAlerts==nil,"Boss alerts teardown leaked")
  for _,c in ipairs(hubConnections) do assert(not c.Connected,"Hub connection leaked: "..mark) end
  for _,c in ipairs(engineConnections) do assert(not c.Connected,"Engine connection leaked: "..mark) end
  step("reload")
   loadstring(readfile("Veyra/main.lua"),"main.lua")()
  assert(G.VeyraController.alive and G.VeyraMinigames.alive)
 end)
 return ok,err
end
local ok,err=guard()
if not ok then
  -- Roll the fresh install back out so a failed verify leaves no GUI behind.
  if G.VeyraController then pcall(G.VeyraController.unload) end
  return "FAIL: step="..mark.." err="..tostring(err)
end
return "PASS: parry lifecycle, minigames, broom, idle, keys, minimize, unload, reload"
