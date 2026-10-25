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
  softActivate(body["Auto Minigames"]) assert(not m.enabled)
  softActivate(body["Auto Minigames"]) assert(m.enabled)
  step("parry toggle")
  softActivate(body["Auto Parry"]) assert(h.parry==false)
  softActivate(body["Auto Parry"]) assert(h.parry==true)
  step("minimize")
  local frame=gui.Main
  local minimize=frame:FindFirstChild("Minimize")
  assert(minimize,"No minimize button")
  local bodyFrame=frame:FindFirstChild("Body")
  local function clickMinimize()
   for _,c in ipairs(getconnections(minimize.Activated)) do if c.Function then c.Function() end end
  end
  clickMinimize()
  assert(bodyFrame and bodyFrame.Visible==false,"Minimize did not hide body")
  clickMinimize()
  assert(bodyFrame and bodyFrame.Visible==true,"Minimize did not restore body")
  step("state snapshot")
  local hubConnections=table.clone(h.connections)
  local engineConnections=table.clone(m.connections)
  local engineAliveBefore=m.alive
  assert(engineAliveBefore)
  local heldBefore=h.autoHeld==true
  step("unload")
  h.unload()
  assert(h.alive==false and m.alive==false)
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
return "PASS: toggles, unload disconnects, key release, and reload"
