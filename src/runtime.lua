-- Veyra: minigames, experimental melee parry, broom speed, and quest guidance.
local G = getgenv()
if G.VeyraController then G.VeyraController.unload() end
if G.VeyraMinigames then G.VeyraMinigames.stop() end
if G.VeyraQuestAssist then G.VeyraQuestAssist.stop() end
if G.VeyraParry then G.VeyraParry.stop() end
if G.VeyraBossAlerts then G.VeyraBossAlerts.stop() end
  -- Legacy guard: builds before v2 kept a Kill Aura module here. Reloading the
  -- hub must release its held mouse button, or it keeps swinging on its own.
  if G.VeyraKillAura and G.VeyraKillAura.stop then G.VeyraKillAura.stop() end
  G.VeyraKillAura=nil
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local player = Players.LocalPlayer
local H = {alive=true, connections={}, tweens={}, broomSpeed=1}
G.VeyraController = H
local function connect(signal, callback)
 local c=signal:Connect(callback)
 table.insert(H.connections,c)
 return c
end
-- Hidden UI access is optional; use PlayerGui even in runtimes without gethui.
local uiRoots={player.PlayerGui,game:GetService("CoreGui")}
if type(gethui)=="function" then
 local ok,hidden=pcall(gethui)
 if ok and hidden and hidden~=player.PlayerGui then table.insert(uiRoots,hidden) end
end
for _,root in ipairs(uiRoots) do
 local ok,children=pcall(function() return root:GetChildren() end)
 if ok then
  for _,child in ipairs(children) do
   if child.Name=="VeyraPanel" then child:Destroy() end
  end
 end
end
local moduleErrors={}
local function startModule(name,start)
 local ok,err=pcall(start)
 if not ok then
  table.insert(moduleErrors,name..": "..tostring(err))
  warn("Veyra: "..moduleErrors[#moduleErrors])
 end
end
startModule("minigames",function() loadstring(readfile("Veyra/src/minigames.lua"),"minigames.lua")() end)
startModule("quest assist",function() loadstring(readfile("Veyra/src/quest_assist.lua"),"quest_assist.lua")() end)
startModule("boss alerts",function() loadstring(readfile("Veyra/src/boss_alerts.lua"),"boss_alerts.lua")() end)
startModule("auto parry",function() loadstring(readfile("Veyra/src/auto_parry.lua"),"auto_parry.lua")() end)
local AP = G.VeyraParry
H.parry=AP
local QA = G.VeyraQuestAssist
local BA = G.VeyraBossAlerts
local MG = G.VeyraMinigames
H.questAssist=QA
H.bossAlerts=BA
H.minigames=MG
-- Broom velocity is set by the game's own flight controller. Madium A/B
-- captures showed 80 studs/s at BOTH 1x and 2x even though this scaler was
-- armed: the game's PreSimulation write replaced our scheduled write.
-- Watch changes to the active LinearVelocity instead and scale the value
-- immediately after the game supplies it. Keep all vertical movement intact.
local function boostedBroomVector(v,mult)
 if mult<=1 then return nil end
 local mag=math.sqrt(v.X*v.X+v.Z*v.Z)
 if mag<1 or mag>250 then return nil end
 local target=math.min(mag*mult,240)
 if target<=mag+0.001 then return nil end
 return Vector3.new(v.X/mag*target,v.Y,v.Z/mag*target)
end
-- One scaling path for both the watcher and manual calls, so a value we
-- already boosted is never boosted a second time (40 -> 80 -> 160 -> cap was
-- reachable when the signal and a direct call overlapped).
local lastWritten
local function scaleBroomVelocity(lv)
 local raw=lv.VectorVelocity
 if lastWritten and (raw-lastWritten).Magnitude<=0.001 then return false end
 local boosted=boostedBroomVector(raw,H.broomSpeed)
 if not boosted then return false end
 lastWritten=boosted
 H.broomDebug.appliedWrites+=1
 H.broomDebug.lastBase=math.sqrt(raw.X*raw.X+raw.Z*raw.Z)
 H.broomDebug.lastBoost=math.sqrt(boosted.X*boosted.X+boosted.Z*boosted.Z)
 lv.VectorVelocity=boosted
 return true
end
local broomScaler
local broomRoot,broomVelocity,broomVelocityConn
local broomGeneration=0
local mountConnection
H.broomDebug={observedWrites=0,appliedWrites=0,attached=false,lastBase=0,lastBoost=0}
local function detachBroomVelocity()
 lastWritten=nil
 if broomVelocityConn then broomVelocityConn:Disconnect() broomVelocityConn=nil end
 broomVelocity=nil
 H.broomDebug.attached=false
end
local function watchBroomVelocity(lv,generation,character)
 if broomVelocity==lv then return end
 detachBroomVelocity()
 broomVelocity=lv
 if not lv then return end
 local function onVelocityChanged()
  if not H.alive or generation~=broomGeneration or character~=player.Character
   or not character:GetAttribute("Flying") or not lv.Parent then return end
  H.broomDebug.observedWrites+=1
  scaleBroomVelocity(lv)
 end
 broomVelocityConn=lv:GetPropertyChangedSignal("VectorVelocity"):Connect(onVelocityChanged)
 H.broomDebug.attached=true
 onVelocityChanged()
end
local function armBroom()
 broomGeneration+=1
 local generation=broomGeneration
 if broomScaler then broomScaler:Disconnect() broomScaler=nil end
 detachBroomVelocity()
 broomRoot=nil
 local character=player.Character
 if H.alive and H.broomSpeed>1 and character and character:GetAttribute("Flying") then
  -- Locate the live actuator as soon as it exists; do not assume callback
  -- order on PreSimulation. The property watcher handles controller writes.
  task.delay(0.1,function()
   if generation==broomGeneration and H.alive and H.broomSpeed>1
    and character==player.Character and character:GetAttribute("Flying") and not broomScaler then
    broomScaler=RS.PreSimulation:Connect(function()
     local me=player.Character
     if not me or not me:GetAttribute("Flying") then return end
     local root=me:FindFirstChild("HumanoidRootPart")
     if root~=broomRoot then
      broomRoot=root
      detachBroomVelocity()
     end
     local lv=root and root:FindFirstChildWhichIsA("LinearVelocity",true)
     if lv~=broomVelocity then watchBroomVelocity(lv,generation,character) end
    end)
   end
  end)
 end
end
local function wireBroomCharacter(char)
 if mountConnection then mountConnection:Disconnect() mountConnection=nil end
 if not char then return end
 mountConnection=char:GetAttributeChangedSignal("Flying"):Connect(function()
  if H.alive then armBroom() end
 end)
 armBroom()
end
H.scaleBroomVelocity=scaleBroomVelocity
H.armBroom=armBroom
H.testBroomConn=function() return broomScaler~=nil end
H.testBroomWatcher=function() return broomVelocityConn~=nil end
local palette={bg=Color3.fromRGB(15,18,25),panel=Color3.fromRGB(24,29,39),line=Color3.fromRGB(47,57,72),text=Color3.fromRGB(233,239,246),muted=Color3.fromRGB(139,155,175),accent=Color3.fromRGB(103,224,179)}
local hover=Color3.fromRGB(30,37,49)
local toggleOn=Color3.fromRGB(42,119,92)
local function new(class,props,parent)
 local o=Instance.new(class)
 for k,v in pairs(props) do o[k]=v end
 o.Parent=parent
 return o
end
local function corner(o,r) new("UICorner",{CornerRadius=UDim.new(0,r or 10)},o) end
local function tween(o,props)
 if H.tweens[o] then H.tweens[o]:Cancel() end
 local t=TS:Create(o,TweenInfo.new(0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props)
 H.tweens[o]=t
 t:Play()
end
-- Event callbacks can access PlayerGui without gethui's Plugin capability.
local gui=new("ScreenGui",{Name="VeyraPanel",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=10000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},player.PlayerGui)
H.gui=gui
local size=Vector2.new(360,420)
local frame=new("Frame",{Name="Main",Size=UDim2.fromOffset(size.X,size.Y),Position=UDim2.fromOffset(35,140),BackgroundColor3=palette.bg,BorderSizePixel=0,ClipsDescendants=true,Active=true},gui)
corner(frame,14)
new("UIStroke",{Color=palette.line,Thickness=1,Transparency=0.2},frame)
local header=new("TextButton",{Name="DragHeader",Size=UDim2.new(1,-50,0,58),BackgroundTransparency=1,Text="",AutoButtonColor=false},frame)
new("TextLabel",{Position=UDim2.fromOffset(18,9),Size=UDim2.new(1,-20,0,24),BackgroundTransparency=1,Text="VEYRA",Font=Enum.Font.GothamBold,TextSize=17,TextColor3=palette.text,TextXAlignment=Enum.TextXAlignment.Left},header)
new("TextLabel",{Position=UDim2.fromOffset(18,33),Size=UDim2.new(1,-20,0,15),BackgroundTransparency=1,Text="CONTROLS",Font=Enum.Font.Gotham,TextSize=9,TextColor3=palette.accent,TextXAlignment=Enum.TextXAlignment.Left},header)
local minimize=new("TextButton",{Name="Minimize",Position=UDim2.new(1,-44,0,13),Size=UDim2.fromOffset(30,30),BackgroundColor3=palette.panel,Text="−",TextSize=22,Font=Enum.Font.Gotham,TextColor3=palette.text,BorderSizePixel=0},frame)
corner(minimize,8)
local body=new("Frame",{Name="Body",Position=UDim2.fromOffset(14,60),Size=UDim2.new(1,-28,0,278),BackgroundTransparency=1,BorderSizePixel=0},frame)
new("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},body)
local order=0
local toggleRefresh={}
local function toggle(name,description,initial,callback,getState)
 local on=initial
 order+=1
 local b=new("TextButton",{Name=name,LayoutOrder=order,Size=UDim2.new(1,-5,0,49),BackgroundColor3=palette.panel,BorderSizePixel=0,Text="",AutoButtonColor=false},body)
 corner(b,9)
 new("TextLabel",{Position=UDim2.fromOffset(12,7),Size=UDim2.new(1,-74,0,18),BackgroundTransparency=1,Text=name,Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=palette.text,TextXAlignment=Enum.TextXAlignment.Left},b)
 new("TextLabel",{Position=UDim2.fromOffset(12,27),Size=UDim2.new(1,-74,0,14),BackgroundTransparency=1,Text=description,Font=Enum.Font.Gotham,TextSize=10,TextColor3=palette.muted,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd},b)
 local track=new("Frame",{Position=UDim2.new(1,-49,0.5,-10),Size=UDim2.fromOffset(36,20),BorderSizePixel=0},b)
 corner(track,10)
 local knob=new("Frame",{Size=UDim2.fromOffset(14,14),BackgroundColor3=palette.text,BorderSizePixel=0},track)
 corner(knob,8)
 local function paint()
  tween(track,{BackgroundColor3=on and toggleOn or palette.line})
  tween(knob,{Position=UDim2.fromOffset(on and 19 or 3,3)})
 end
 paint()
 connect(b.Activated,function()
  if getState then on=getState() end
  on=not on callback(on)
  if getState then on=getState() end
  paint()
 end)
 if getState then
  table.insert(toggleRefresh,function()
   local current=getState()
   if current~=on then on=current paint() end
  end)
 end
 connect(b.MouseEnter,function() tween(b,{BackgroundColor3=hover}) end)
 connect(b.MouseLeave,function() tween(b,{BackgroundColor3=palette.panel}) end)
 return b
end
local function stepper(name,description,minValue,maxValue,step,initial,format,callback)
 order+=1
 local b=new("Frame",{Name=name,LayoutOrder=order,Size=UDim2.new(1,-5,0,49),BackgroundColor3=palette.panel,BorderSizePixel=0},body)
 corner(b,9)
 new("TextLabel",{Position=UDim2.fromOffset(12,7),Size=UDim2.new(1,-74,0,18),BackgroundTransparency=1,Text=name,Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=palette.text,TextXAlignment=Enum.TextXAlignment.Left},b)
 new("TextLabel",{Position=UDim2.fromOffset(12,27),Size=UDim2.new(1,-74,0,14),BackgroundTransparency=1,Text=description,Font=Enum.Font.Gotham,TextSize=10,TextColor3=palette.muted,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd},b)
 local valueLabel=new("TextLabel",{Name="Value",Position=UDim2.new(1,-124,0.5,-9),Size=UDim2.fromOffset(52,18),BackgroundTransparency=1,Text=format(initial),Font=Enum.Font.GothamBold,TextSize=12,TextColor3=palette.accent,TextXAlignment=Enum.TextXAlignment.Right},b)
 local value=initial
 local function paint()
  valueLabel.Text=format(value)
 end
 local function adjust(delta)
  value=math.clamp(math.floor((value+delta)*100+0.5)/100,minValue,maxValue)
  callback(value)
  paint()
 end
 local function button(symbol,label,offset)
  local btn=new("TextButton",{Name=label,Position=UDim2.new(1,offset,0.5,-12),Size=UDim2.fromOffset(26,24),BackgroundColor3=palette.line,BorderSizePixel=0,Text=symbol,Font=Enum.Font.GothamBold,TextSize=16,TextColor3=palette.text},b)
  corner(btn,7)
  connect(btn.Activated,function() adjust(label=="Plus" and step or -step) end)
  connect(btn.MouseEnter,function() tween(btn,{BackgroundColor3=hover}) end)
  connect(btn.MouseLeave,function() tween(btn,{BackgroundColor3=palette.line}) end)
 end
 button("-","Minus",-64)
 button("+","Plus",-34)
 paint()
 return b
end
toggle("Auto Minigames","Mining + harvesting · off by default",false,function(on) if MG then MG.setEnabled(on) end end)
-- Auto Parry hidden from menu (experimental, not fully reliable)
-- toggle("Auto Parry","Experimental melee timing · equip weapon",false,function(on) if AP then AP.setEnabled(on) end end,function() return AP and AP.enabled end)
toggle("Quest Assistance","Tracked objectives · minimal HUD",false,function(on) if QA then QA.setEnabled(on) end end)
toggle("Boss Attack Alerts","Warnings for profiled boss windups · off by default",false,function(on) if BA then BA.setEnabled(on) end end,function() return BA and BA.enabled end)
stepper("Broom Speed","Flight velocity multiplier · 1 = normal",1,3,0.25,1,
 function(v) return string.format("%.2fx",v) end,
 function(v) H.broomSpeed=v armBroom() end)
local status=new("TextLabel",{Name="Status",Position=UDim2.new(0,18,1,-48),Size=UDim2.new(1,-117,0,18),BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=10,TextColor3=palette.accent,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Text="Minigames off"},frame)
local footer=new("TextLabel",{Position=UDim2.new(0,18,1,-28),Size=UDim2.new(1,-60,0,15),BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=9,TextColor3=palette.muted,TextXAlignment=Enum.TextXAlignment.Left,Text="RightCtrl: hide · Delete: minimize · Insert: size"},frame)
local unload=new("TextButton",{Position=UDim2.new(1,-92,1,-50),Size=UDim2.fromOffset(72,24),BackgroundColor3=Color3.fromRGB(57,33,40),BorderSizePixel=0,Text="Unload",Font=Enum.Font.GothamMedium,TextSize=10,TextColor3=Color3.fromRGB(242,160,164)},frame)
corner(unload,7)
local grip=new("TextButton",{Name="ResizeGrip",Position=UDim2.new(1,-24,1,-24),Size=UDim2.fromOffset(24,24),BackgroundTransparency=1,Text="◢",TextColor3=palette.muted,TextSize=15},frame)
local edgeR=new("TextButton",{Name="ResizeRight",Position=UDim2.new(1,-5,0,0),Size=UDim2.new(0,5,1,-24),BackgroundTransparency=1,Text="",AutoButtonColor=false},frame)
local edgeB=new("TextButton",{Name="ResizeBottom",Position=UDim2.new(0,0,1,-5),Size=UDim2.new(1,-24,0,5),BackgroundTransparency=1,Text="",AutoButtonColor=false},frame)
local minimized=false
local drag,resize,startMouse,startPos,startSize
local sizePresets={Vector2.new(360,420),Vector2.new(420,460),Vector2.new(480,500)}
local presetIndex=1
local function setMinimized(state)
 minimized=state
 body.Visible=not minimized status.Visible=not minimized footer.Visible=not minimized unload.Visible=not minimized
 minimize.Text=minimized and "+" or "−"
 tween(frame,{Size=UDim2.fromOffset(size.X,minimized and 58 or size.Y)})
end
local function cycleSize()
 presetIndex=presetIndex%#sizePresets+1
 size=sizePresets[presetIndex]
 if not minimized then tween(frame,{Size=UDim2.fromOffset(size.X,size.Y)}) end
end
local function begin(input,mode)
 if minimized then return end
 if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
 drag=mode=="drag" resize=mode=="resize"
 startMouse=Vector2.new(input.Position.X,input.Position.Y)
 startPos=frame.AbsolutePosition startSize=frame.AbsoluteSize
end
connect(header.InputBegan,function(i) begin(i,"drag") end)
connect(grip.InputBegan,function(i) begin(i,"resize") end)
connect(edgeR.InputBegan,function(i) begin(i,"resize") end)
connect(edgeB.InputBegan,function(i) begin(i,"resize") end)
connect(grip.MouseEnter,function() tween(grip,{TextColor3=palette.text}) end)
connect(grip.MouseLeave,function() tween(grip,{TextColor3=palette.muted}) end)
local function viewport() return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080) end
connect(UIS.InputChanged,function(i)
 if not drag and not resize then return end
 if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end
 local delta=Vector2.new(i.Position.X,i.Position.Y)-startMouse
 local view=viewport()
 if drag then
  frame.Position=UDim2.fromOffset(math.clamp(startPos.X+delta.X,0,math.max(0,view.X-frame.AbsoluteSize.X)),math.clamp(startPos.Y+delta.Y,0,math.max(0,view.Y-frame.AbsoluteSize.Y)))
 else
  if H.tweens[frame] then H.tweens[frame]:Cancel() end
    size=Vector2.new(math.clamp(startSize.X+delta.X,300,math.max(300,math.min(560,view.X))),math.clamp(startSize.Y+delta.Y,420,math.max(420,math.min(760,view.Y))))
  frame.Size=UDim2.fromOffset(size.X,size.Y)
 end
end)
connect(UIS.InputEnded,function(i)
 if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false resize=false end
end)
connect(minimize.Activated,function() setMinimized(not minimized) end)
local cursor=new("TextLabel",{Name="HubCursor",Size=UDim2.fromOffset(18,24),BackgroundTransparency=1,Text="↖",Font=Enum.Font.GothamBold,TextSize=22,TextColor3=Color3.new(1,1,1),TextStrokeTransparency=0.25,ZIndex=100,Visible=false},gui)
local savedCursor,ownsCursor=false,false
local function cursorRelease()
 if ownsCursor then UIS.MouseIconEnabled=savedCursor ownsCursor=false end
 cursor.Visible=false if MG then MG.paused=false end
end
local cursorBound=false
local nextStatus=0
local function refreshStatus()
 for _,refresh in ipairs(toggleRefresh) do refresh() end
 local label=not MG and "Minigames unavailable" or (not MG.enabled and "Minigames off" or MG.paused and "Minigames paused" or MG.activity or "Waiting for minigame")
 if MG and MG.lastResult and MG.enabled and not MG.paused then label=label.." · "..MG.lastResult end
 if QA and QA.enabled then
  label=MG and MG.enabled and (label.." · Quest guide on") or QA.status
 end
 if BA and BA.enabled then label=label.." · Boss alerts on" end
 if #moduleErrors>0 then label=label.." · "..moduleErrors[1] end
 if status.Text~=label then status.Text=label end
end
local function updatePanel()
 local now=os.clock()
 if now>=nextStatus then nextStatus=now+0.5 refreshStatus() end
 local mouse=UIS:GetMouseLocation()
 local p,s=frame.AbsolutePosition,frame.AbsoluteSize
 local inside=mouse.X>=p.X and mouse.X<=p.X+s.X and mouse.Y>=p.Y and mouse.Y<=p.Y+s.Y
 header.Modal=inside or drag or resize or false
 if inside or drag or resize then
  if not ownsCursor then savedCursor=UIS.MouseIconEnabled ownsCursor=true end
  UIS.MouseIconEnabled=true
  cursor.Position=UDim2.fromOffset(mouse.X,mouse.Y)
  cursor.Visible=true
  if MG then MG.paused=true end
 else
  cursorRelease()
 end
end
local function showPanel(enabled)
 gui.Enabled=enabled
 if enabled then
  if not cursorBound then
   cursorBound=true
   RS:BindToRenderStep("VeyraCursor",Enum.RenderPriority.Last.Value+1,updatePanel)
  end
  nextStatus=0
  refreshStatus()
 else
  if cursorBound then
   cursorBound=false
   RS:UnbindFromRenderStep("VeyraCursor")
  end
  header.Modal=false
  cursorRelease()
 end
end
local function handleHubKeys(i,processed)
 if processed or not H.alive then return end
 if i.KeyCode==Enum.KeyCode.RightControl then
  showPanel(not gui.Enabled)
 elseif i.KeyCode==Enum.KeyCode.Delete then
  setMinimized(not minimized)
 elseif i.KeyCode==Enum.KeyCode.Insert then
  cycleSize()
 end
end
connect(UIS.InputBegan,handleHubKeys)
H.testKeybind=handleHubKeys
H.isCursorActive=function() return cursorBound end
wireBroomCharacter(player.Character)
connect(player.CharacterAdded,function(char) task.defer(wireBroomCharacter,char) end)
function H.unload()
 if not H.alive then return end
 H.alive=false
 broomGeneration+=1
 if mountConnection then mountConnection:Disconnect() mountConnection=nil end
 if broomScaler then broomScaler:Disconnect() broomScaler=nil end
 detachBroomVelocity()
 showPanel(false)
 if MG and MG.stop then MG.stop() end
 if QA and QA.stop then QA.stop() end
 if BA and BA.stop then BA.stop() end
 if AP and AP.stop then AP.stop() end
 for _,c in ipairs(H.connections) do c:Disconnect() end
 table.clear(H.connections)
 for _,t in pairs(H.tweens) do t:Cancel() end
 table.clear(H.tweens)
 gui:Destroy()
 if G.VeyraController==H then G.VeyraController=nil end
end
connect(unload.Activated,H.unload)
showPanel(true)
return "Veyra ready"

