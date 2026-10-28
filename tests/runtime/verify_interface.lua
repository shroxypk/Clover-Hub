local G=getgenv()
local h=assert(G.VeyraController)
local m=assert(G.VeyraMinigames)
assert(not m.mine and not m.harvest and not m.isWorking(),"Wait until the minigame ends before checking unload")
local gui=h.gui
local panel=gui.Main
local body=assert(panel:FindFirstChild("Body"),"Body host missing")
local pages={}
for _,child in ipairs(body:GetChildren()) do
 if child:IsA("ScrollingFrame") then pages[#pages+1]=child end
end
assert(#pages==3,"Expected three tab pages, got "..#pages)
local function row(name)
 for _,page in ipairs(pages) do
  local found=page:FindFirstChild(name)
  if found then return found,page end
 end
end
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
  step("tabs")
  local tabs=assert(panel:FindFirstChild("Tabs"),"Tab bar missing")
  local automationTab=assert(tabs:FindFirstChild("Automation"),"Automation tab missing")
  local guidanceTab=assert(tabs:FindFirstChild("Guidance"),"Guidance tab missing")
  local movementTab=assert(tabs:FindFirstChild("Movement"),"Movement tab missing")
  assert(pages[1].Visible and not pages[2].Visible,"First tab must be active")
  softActivate(guidanceTab)
  assert(pages[2].Visible and not pages[1].Visible,"Guidance tab did not switch")
  softActivate(movementTab)
  assert(pages[3].Visible and not pages[2].Visible,"Movement tab did not switch")
  assert(pages[3]:FindFirstChild("Broom Speed"),"Movement page missing Broom Speed")
  softActivate(automationTab)
  assert(pages[1].Visible and not pages[3].Visible,"Automation tab did not return")
  step("minigames toggle")
  local VIM=game:GetService("VirtualInputManager")
  local minigamesRow=assert(body:FindFirstChild("Auto Minigames") or pages[1]:FindFirstChild("Auto Minigames"),"Minigames row missing")
  assert(minigamesRow:FindFirstChild("Head")==nil,"Minigames must be its own plain toggle")
  assert(m.enabled==false,"Minigames must default off")
  softActivate(minigamesRow) assert(m.enabled)
  softActivate(minigamesRow) assert(not m.enabled)
  softActivate(minigamesRow) assert(m.enabled)
  step("gather dropdowns")
  local gather=assert(h.gather,"Auto gather not loaded")
  assert(gather.harvest==false and gather.ore==false,"Gather modes must default off")
  local harvestRow=assert(row("Auto Harvest"),"Harvest row missing")
  local harvestHead=assert(harvestRow:FindFirstChild("Head"),"Harvest row head missing")
  local options=assert(harvestRow:FindFirstChild("Options"),"Harvest options missing")
  assert(options.Visible==false,"Harvest options must start collapsed")
  local more=assert(harvestHead:FindFirstChild("More"),"Harvest chevron missing")
  softActivate(harvestHead)
  assert(gather.harvest,"Harvest mode did not start")
  assert(m.enabled,"Gather must enable minigames")
  local collapsed=harvestRow.AbsoluteSize.Y
  softActivate(more)
  task.wait(0.4)
  assert(options.Visible,"Chevron did not expand")
  assert(harvestRow.AbsoluteSize.Y>collapsed,"Card did not grow for the type list")
  local types=assert(options:FindFirstChild("HarvestTypes"),"Harvest type picker missing")
  softActivate(types.Head)
  task.wait(0.3)
  local list=assert(types:FindFirstChild("List"),"Harvest type list missing")
  assert(list.Visible,"Harvest type list did not expand")
  assert(types.AbsoluteSize.Y>28,"Type picker did not grow")
  local picks=0
  for _,row in ipairs(list:GetChildren()) do
   if row:IsA("TextButton") then picks+=1 end
  end
  assert(picks>0,"Harvest type list is empty")
  local first=assert(gather.catalog("Harvest")[1],"Catalog empty")
  local firstRow=list:FindFirstChild(first.name)
  assert(firstRow,"Catalog row "..first.name.." missing from the list")
  local wasOn=gather.isTypeOn("Harvest",first.name)
  softActivate(firstRow)
  assert(gather.isTypeOn("Harvest",first.name)~=wasOn,"Type toggle did not register")
  softActivate(harvestHead)
  assert(not gather.harvest,"Harvest mode did not stop")
  softActivate(more) assert(options.Visible==false,"Chevron did not collapse")
  step("quest toggle")
  local qa=assert(h.questAssist,"Quest guide not loaded")
  assert(qa.enabled==false,"Quest guide must default off")
  local questRow=assert(row("Quest Assistance"),"Quest row missing")
  softActivate(questRow) assert(qa.enabled)
  softActivate(questRow) assert(not qa.enabled)
  assert(workspace:FindFirstChild("VeyraQuestAnchors")==nil,"Disabled guide left anchors")
  step("parry lifecycle")
  local ap=assert(h.parry)
  assert(not ap.enabled and not ap.isWorking(),"Parry must default off")
  ap.setEnabled(true) assert(ap.enabled and ap.isWorking())
  ap.setEnabled(false) assert(not ap.enabled and not ap.isWorking())
  assert(row("Auto Parry")==nil,"Auto Parry row must be hidden")
  step("removed aura rows")
  assert(row("Kill Aura")==nil and row("Fight Only")==nil
   and row("Aura Range")==nil and row("Aura Turn Rate")==nil,"Aura controls still present")
  assert(h.killAura==nil,"Aura still exposed on the hub")
  assert(G.VeyraKillAura==nil or not G.VeyraKillAura.enabled,"Legacy aura still enabled")
  step("boss alerts toggle")
  local ba=assert(h.bossAlerts,"Boss alerts not loaded")
  assert(ba.enabled==false,"Boss alerts must default off")
  local bossRow=assert(row("Boss Attack Alerts"),"Boss alerts row missing")
  softActivate(bossRow) assert(ba.enabled)
  softActivate(bossRow) assert(not ba.enabled)
  step("removed advisor")
  assert(row("Build Advisor")==nil,"Stale build advisor row")
  assert(h.advisor==nil and G.VeyraBuildAdvisor==nil,"Build advisor still exposed")
  local pg=game:GetService("Players").LocalPlayer.PlayerGui
  assert(pg:FindFirstChild("VeyraBuildAdvisor")==nil,"Build advisor GUI still present")
  step("removed rows")
  assert(row("Auto Dodge")==nil and row("Auto Block")==nil and row("Prefer Dodge")==nil,"Stale defense controls")
  assert(row("Auto Loot")==nil and row("Auto Equip Best")==nil,"Stale QoL controls")
  step("broom speed row")
  local broomRow=assert(row("Broom Speed"),"Broom stepper missing")
  assert(broomRow:FindFirstChild("Plus") and broomRow:FindFirstChild("Minus") and broomRow:FindFirstChild("Value"),"Broom stepper incomplete")
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
  local bodyFrame=body
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
  assert(G.VeyraAutoGather==nil,"Auto gather teardown leaked")
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
return "PASS: tabs, parry lifecycle, minigames, broom, idle, keys, minimize, unload, reload"
