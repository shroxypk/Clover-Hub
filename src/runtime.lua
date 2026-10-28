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
startModule("auto gather",function() loadstring(readfile("Veyra/src/auto_gather.lua"),"auto_gather.lua")() end)
local AP = G.VeyraParry
H.parry=AP
local QA = G.VeyraQuestAssist
local BA = G.VeyraBossAlerts
local MG = G.VeyraMinigames
H.questAssist=QA
H.bossAlerts=BA
H.minigames=MG
H.gather=G.VeyraAutoGather
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
local palette={
 bg=Color3.fromRGB(11,11,13),
 panel=Color3.fromRGB(22,22,26),
 chip=Color3.fromRGB(29,29,34),
 line=Color3.fromRGB(43,43,50),
 text=Color3.fromRGB(237,237,241),
 muted=Color3.fromRGB(138,138,148),
 accent=Color3.fromRGB(229,56,59),
 accentDim=Color3.fromRGB(122,28,31),
 locked=Color3.fromRGB(110,86,88),
 onAccent=Color3.fromRGB(255,255,255),
}
local hover=Color3.fromRGB(31,31,37)
local toggleOn=Color3.fromRGB(200,44,47)
local icons={
 ["Auto Minigames"]="✦",["Quest Assistance"]="◎",["Boss Attack Alerts"]="!",
 ["Broom Speed"]="➤",["Auto Harvest"]="❋",["Auto Mine"]="◆",
}
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
local size=Vector2.new(360,470)
local frame=new("Frame",{Name="Main",Size=UDim2.fromOffset(size.X,size.Y),Position=UDim2.fromOffset(35,140),BackgroundColor3=palette.bg,BorderSizePixel=0,ClipsDescendants=true,Active=true},gui)
corner(frame,14)
new("UIStroke",{Color=palette.line,Thickness=1,Transparency=0.25},frame)
local header=new("TextButton",{Name="DragHeader",Size=UDim2.new(1,-50,0,58),BackgroundTransparency=1,Text="",AutoButtonColor=false},frame)
new("Frame",{Name="AccentBar",Position=UDim2.fromOffset(18,14),Size=UDim2.fromOffset(3,26),BackgroundColor3=palette.accent,BorderSizePixel=0},header)
new("TextLabel",{Position=UDim2.fromOffset(30,9),Size=UDim2.new(1,-40,0,22),BackgroundTransparency=1,Text="VEYRA",Font=Enum.Font.GothamBold,TextSize=16,TextColor3=palette.text,TextXAlignment=Enum.TextXAlignment.Left},header)
new("TextLabel",{Position=UDim2.fromOffset(30,31),Size=UDim2.new(1,-40,0,14),BackgroundTransparency=1,Text="CLOVER RPG · AUTOMATION",Font=Enum.Font.Gotham,TextSize=8,TextColor3=palette.muted,TextXAlignment=Enum.TextXAlignment.Left},header)
local minimize=new("TextButton",{Name="Minimize",Position=UDim2.new(1,-44,0,13),Size=UDim2.fromOffset(30,30),BackgroundColor3=palette.panel,Text="−",TextSize=20,Font=Enum.Font.Gotham,TextColor3=palette.text,BorderSizePixel=0},frame)
corner(minimize,8)
-- Tabs: one scrollable page per category, so nothing ever falls off the panel.
local body
local pages={}
local pageNames={"Automation","Guidance","Movement"}
local tabButtons={}
local activeTab=1
local minimized=false
local order=0
local tabBar=new("Frame",{Name="Tabs",Position=UDim2.fromOffset(14,58),Size=UDim2.new(1,-28,0,26),BackgroundTransparency=1},frame)
new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},tabBar)
local bodyHost=new("Frame",{Name="Body",Position=UDim2.fromOffset(14,92),Size=UDim2.new(1,-28,0,316),BackgroundTransparency=1,BorderSizePixel=0},frame)
local function layoutPages()
 local height=math.max(120,(minimized and 58 or size.Y)-92-58)
 bodyHost.Size=UDim2.new(1,-28,0,height)
 for _,page in ipairs(pages) do page.Size=UDim2.new(1,0,0,height) end
end
local selectTab
for i,name in ipairs(pageNames) do
 local page=new("ScrollingFrame",{Name=name.."Page",Size=UDim2.new(1,0,0,316),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=palette.line,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ElasticBehavior=Enum.ElasticBehavior.Never,Visible=false},bodyHost)
 new("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},page)
 pages[i]=page
 local btn=new("TextButton",{Name=name,LayoutOrder=i,Size=UDim2.new(1/#pageNames,-4,0,26),BackgroundColor3=palette.panel,BorderSizePixel=0,Text=name,Font=Enum.Font.GothamMedium,TextSize=10,TextColor3=palette.muted,AutoButtonColor=false},tabBar)
 corner(btn,7)
 tabButtons[i]=btn
 connect(btn.Activated,function() selectTab(i) end)
end
function selectTab(i)
 activeTab=i or 1
 for idx,page in ipairs(pages) do page.Visible=(idx==activeTab) and not minimized end
 for idx,btn in ipairs(tabButtons) do
  local on=idx==activeTab
  btn.BackgroundColor3=on and toggleOn or palette.panel
  btn.TextColor3=on and palette.onAccent or palette.muted
 end
 body=pages[activeTab]
end
layoutPages()
selectTab(1)
local toggleRefresh={}
-- Small glyph chip that gives each row a landmark without shipping image assets.
local function iconChip(parent,name,y,sizePx)
 local glyph=icons[name]
 if not glyph then return 0 end
 local chip=new("Frame",{Name="Icon",Position=UDim2.fromOffset(10,y-1),Size=UDim2.fromOffset(20,20),BackgroundColor3=palette.chip,BorderSizePixel=0},parent)
 corner(chip,6)
 new("TextLabel",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=glyph,Font=Enum.Font.GothamBold,TextSize=11,TextColor3=palette.accent},chip)
 return 26
end
local function heading(text)
 order+=1
 return new("TextLabel",{Name="Section "..text,LayoutOrder=order,Size=UDim2.new(1,-5,0,16),BackgroundTransparency=1,Text=text:upper(),Font=Enum.Font.GothamBold,TextSize=9,TextColor3=palette.muted,TextXAlignment=Enum.TextXAlignment.Left},body)
end
local function toggle(name,description,initial,callback,getState)
 local on=initial
 order+=1
 local b=new("TextButton",{Name=name,LayoutOrder=order,Size=UDim2.new(1,-5,0,49),BackgroundColor3=palette.panel,BorderSizePixel=0,Text="",AutoButtonColor=false},body)
 corner(b,9)
 local pad=iconChip(b,name,8)
 new("TextLabel",{Position=UDim2.fromOffset(12+pad,7),Size=UDim2.new(1,-74-pad,0,18),BackgroundTransparency=1,Text=name,Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=palette.text,TextXAlignment=Enum.TextXAlignment.Left},b)
 new("TextLabel",{Position=UDim2.fromOffset(12+pad,27),Size=UDim2.new(1,-74-pad,0,14),BackgroundTransparency=1,Text=description,Font=Enum.Font.Gotham,TextSize=10,TextColor3=palette.muted,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd},b)
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
-- A row that can reveal sub-options. The card grows downwards, taking the
-- panel with it, so the extra rows never overlap the status strip.
local function expandToggle(name,description,initial,callback,getState,buildChildren)
 order+=1
 local card=new("Frame",{Name=name,LayoutOrder=order,Size=UDim2.new(1,-5,0,49),BackgroundColor3=palette.panel,BorderSizePixel=0},body)
 corner(card,9)
 local head=new("TextButton",{Name="Head",Size=UDim2.new(1,0,0,49),BackgroundColor3=palette.panel,BorderSizePixel=0,Text="",AutoButtonColor=false},card)
 corner(head,9)
 local pad=iconChip(head,name,9)
 new("TextLabel",{Position=UDim2.fromOffset(12+pad,7),Size=UDim2.new(1,-74-pad,0,18),BackgroundTransparency=1,Text=name,Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=palette.text,TextXAlignment=Enum.TextXAlignment.Left},head)
 new("TextLabel",{Position=UDim2.fromOffset(12+pad,27),Size=UDim2.new(1,-74-pad,0,14),BackgroundTransparency=1,Text=description,Font=Enum.Font.Gotham,TextSize=10,TextColor3=palette.muted,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd},head)
 local track=new("Frame",{Name="Track",Position=UDim2.new(1,-49,0.5,-10),Size=UDim2.fromOffset(36,20),BorderSizePixel=0},head)
 corner(track,10)
 local knob=new("Frame",{Name="Knob",Size=UDim2.fromOffset(14,14),BackgroundColor3=palette.text,BorderSizePixel=0},track)
 corner(knob,8)
 local on=initial
 local function paint()
  tween(track,{BackgroundColor3=on and toggleOn or palette.line})
  tween(knob,{Position=UDim2.fromOffset(on and 19 or 3,3)})
 end
 paint()
 connect(head.Activated,function()
  if getState then on=getState() end
  on=not on
  callback(on)
  if getState then on=getState() end
  paint()
 end)
 if getState then
  table.insert(toggleRefresh,function()
   local current=getState()
   if current~=on then on=current paint() end
  end)
 end
 local options=new("Frame",{Name="Options",Position=UDim2.fromOffset(7,47),Size=UDim2.new(1,-14,0,0),BackgroundTransparency=1,Visible=false},card)
 new("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},options)
 local extra=0
 local expanded=false
 -- Sub-rows call grow() when they open their own list so the card, body and
 -- window stay in sync instead of overlapping the status strip.
 local function grow(delta)
  extra+=delta
  if not expanded then return end
  card.Size=UDim2.new(1,-5,0,49+extra)
 end
 local initial=buildChildren and buildChildren(options,grow) or 0
 extra=initial
 local more=new("TextButton",{Name="More",Position=UDim2.new(1,-72,0,7),Size=UDim2.fromOffset(18,18),BackgroundTransparency=1,Text="▾",Font=Enum.Font.GothamBold,TextSize=14,TextColor3=palette.muted,AutoButtonColor=false},head)
 if not buildChildren then more.Visible=false end
 local function setOpen(value)
  if value==expanded then return end
  expanded=value
  options.Visible=expanded
  more.Text=expanded and "▴" or "▾"
  card.Size=UDim2.new(1,-5,0,49+(expanded and extra or 0))
 end
 if buildChildren then
  connect(more.Activated,function() setOpen(not expanded) end)
 end
 H.expandAutoMinigames=function() setOpen(true) end
 return head
end
-- Multi-select list of node types shown under Auto Harvest / Auto Mine.
local function typePicker(parent,kind,index,title,grow)
 local label=kind:sub(1,1):upper()..kind:sub(2)
 local box=new("Frame",{Name=label.."Types",LayoutOrder=index,Size=UDim2.new(1,0,0,28),BackgroundColor3=palette.bg,BorderSizePixel=0},parent)
 corner(box,7)
 local head=new("TextButton",{Name="Head",Size=UDim2.new(1,0,0,28),BackgroundColor3=palette.bg,BorderSizePixel=0,Text="",AutoButtonColor=false},box)
 corner(head,7)
 new("TextLabel",{Position=UDim2.fromOffset(10,0),Size=UDim2.new(1,-120,0,28),BackgroundTransparency=1,Text=title,Font=Enum.Font.GothamMedium,TextSize=10,TextColor3=palette.text,TextXAlignment=Enum.TextXAlignment.Left},head)
 local summary=new("TextLabel",{Name="Summary",Position=UDim2.new(1,-112,0,0),Size=UDim2.fromOffset(84,28),BackgroundTransparency=1,Text="",Font=Enum.Font.Gotham,TextSize=9,TextColor3=palette.muted,TextXAlignment=Enum.TextXAlignment.Right,TextTruncate=Enum.TextTruncate.AtEnd},head)
 new("TextLabel",{Name="Arrow",Position=UDim2.new(1,-24,0,0),Size=UDim2.fromOffset(16,28),BackgroundTransparency=1,Text="▾",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=palette.muted},head)
 local list=new("ScrollingFrame",{Name="List",Position=UDim2.fromOffset(4,26),Size=UDim2.new(1,-8,0,0),BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ScrollBarThickness=3,ScrollBarImageColor3=palette.line,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ElasticBehavior=Enum.ElasticBehavior.Never},box)
 new("UIListLayout",{Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder},list)
 local rowHeight=24
 local maxRows=5
 local open=false
 local openHeight=0
 local entries={}
 local function current()
  return H.gather and H.gather.catalog(kind) or {}
 end
 local function updateSummary()
  local total,on=0,0
  for _,entry in ipairs(entries) do
   if entry.allowed then
    total+=1
    if H.gather and H.gather.isTypeOn(kind,entry.name) then on+=1 end
   end
  end
  if total==0 then summary.Text="no gear"
  elseif on==total then summary.Text=total.." types"
  else summary.Text=on.."/"..total end
 end
 local function paintRow(row,entry)
  local check=row:FindFirstChild("Check")
  local enabled=H.gather and H.gather.isTypeOn(kind,entry.name) or false
  if check then
   check.BackgroundColor3=enabled and toggleOn or palette.line
   local tick=check:FindFirstChild("Tick")
   if tick then tick.Visible=enabled end
  end
  local tag=row:FindFirstChild("Tag")
  if tag then
   if entry.allowed then
    tag.Text=entry.power and ("P"..tostring(entry.power)) or ""
    tag.TextColor3=enabled and palette.accent or palette.muted
   else
    tag.Text="locked"
    tag.TextColor3=palette.locked
   end
  end
  row.TextTransparency=entry.allowed and 0 or 0.45
 end
 local function rebuildRows()
  for _,child in ipairs(list:GetChildren()) do
   if child:IsA("TextButton") then child:Destroy() end
  end
  entries=current()
  for i,entry in ipairs(entries) do
   local row=new("TextButton",{Name=entry.name,LayoutOrder=i,Size=UDim2.new(1,-4,0,rowHeight),BackgroundColor3=palette.panel,BorderSizePixel=0,Text="",AutoButtonColor=false},list)
   corner(row,6)
   local check=new("Frame",{Name="Check",Position=UDim2.fromOffset(6,5),Size=UDim2.fromOffset(14,14),BackgroundColor3=palette.line,BorderSizePixel=0},row)
   corner(check,4)
   new("TextLabel",{Name="Tick",Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="✓",Font=Enum.Font.GothamBold,TextSize=10,TextColor3=palette.onAccent},check)
   new("TextLabel",{Position=UDim2.fromOffset(26,0),Size=UDim2.new(1,-70,0,rowHeight),BackgroundTransparency=1,Text=entry.name,Font=Enum.Font.Gotham,TextSize=10,TextColor3=palette.text,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd},row)
   new("TextLabel",{Name="Tag",Position=UDim2.new(1,-58,0,0),Size=UDim2.fromOffset(52,rowHeight),BackgroundTransparency=1,Text="",Font=Enum.Font.GothamMedium,TextSize=9,TextColor3=palette.muted,TextXAlignment=Enum.TextXAlignment.Right},row)
   paintRow(row,entry)
   connect(row.Activated,function()
    if not H.gather then return end
    if not entry.allowed then return end
    H.gather.setType(kind,entry.name,not H.gather.isTypeOn(kind,entry.name))
    paintRow(row,entry)
    updateSummary()
   end)
  end
  updateSummary()
  local rows=math.min(#entries,maxRows)
  return rows>0 and (rows*rowHeight+(rows-1)*2) or 0
 end
 local function setOpen(value)
  if value==open then return end
  open=value
  if open then
   local height=rebuildRows()
   openHeight=height+4
   list.Size=UDim2.new(1,-8,0,height)
   list.Visible=true
   box.Size=UDim2.new(1,0,0,26+openHeight)
   head.Size=UDim2.new(1,0,0,26)
   grow(openHeight)
  else
   list.Visible=false
   box.Size=UDim2.new(1,0,0,28)
   head.Size=UDim2.new(1,0,0,28)
   grow(-openHeight)
   openHeight=0
  end
  local arrow=head:FindFirstChild("Arrow")
  if arrow then arrow.Text=open and "▴" or "▾" end
 end
 updateSummary()
 connect(head.Activated,function() setOpen(not open) end)
 connect(head.MouseEnter,function() tween(head,{BackgroundColor3=palette.panel}) end)
 connect(head.MouseLeave,function() tween(head,{BackgroundColor3=palette.bg}) end)
 local shown=true
 local function show(value)
  value=value==true
  shown=value
  box.Visible=value
 end
 return box
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
body=pages[1]
heading("Automation")
toggle("Auto Minigames","Solves every harvest + mining minigame for you",false,
 function(on) if MG then MG.setEnabled(on) end end,
 function() return MG and MG.enabled end)
local function gatherToggle(kind,title,description)
 expandToggle(title,description,false,
  function(on)
   if on and MG and not MG.enabled then MG.setEnabled(true) end
   if H.gather then H.gather.setMode(kind,on) end
  end,
  function() return H.gather and H.gather[kind] or false end,
  function(options,grow)
   typePicker(options,kind,1,kind=="Harvest" and "Crop types" or "Ore types",grow)
   return 28
  end)
end
gatherToggle("harvest","Auto Harvest","AFK farming · best crop your sickle can clear")
gatherToggle("ore","Auto Mine","AFK farming · best ore your pickaxe can clear")
-- Auto Parry hidden from menu (experimental, not fully reliable)
-- toggle("Auto Parry","Experimental melee timing · equip weapon",false,function(on) if AP then AP.setEnabled(on) end end,function() return AP and AP.enabled end)
body=pages[2]
heading("Guidance")
toggle("Quest Assistance","Tracked objectives · minimal HUD",false,function(on) if QA then QA.setEnabled(on) end end)
toggle("Boss Attack Alerts","Warnings for profiled boss windups",false,function(on) if BA then BA.setEnabled(on) end end,function() return BA and BA.enabled end)
body=pages[3]
heading("Movement")
stepper("Broom Speed","Flight velocity multiplier · 1 = normal",1,3,0.25,1,
 function(v) return string.format("%.2fx",v) end,
 function(v) H.broomSpeed=v armBroom() end)
local status=new("TextLabel",{Name="Status",Position=UDim2.new(0,18,1,-48),Size=UDim2.new(1,-117,0,18),BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=10,TextColor3=palette.accent,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Text="Minigames off"},frame)
local footer=new("TextLabel",{Position=UDim2.new(0,18,1,-28),Size=UDim2.new(1,-60,0,15),BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=9,TextColor3=palette.muted,TextXAlignment=Enum.TextXAlignment.Left,Text="RightCtrl: hide · Delete: minimize · Insert: size"},frame)
local unload=new("TextButton",{Position=UDim2.new(1,-92,1,-50),Size=UDim2.fromOffset(72,24),BackgroundColor3=Color3.fromRGB(36,18,20),BorderSizePixel=0,Text="Unload",Font=Enum.Font.GothamMedium,TextSize=10,TextColor3=palette.accent},frame)
corner(unload,7)
new("UIStroke",{Color=palette.accentDim,Thickness=1,Transparency=0.35},unload)
connect(unload.MouseEnter,function() tween(unload,{BackgroundColor3=Color3.fromRGB(58,24,26)}) end)
connect(unload.MouseLeave,function() tween(unload,{BackgroundColor3=Color3.fromRGB(36,18,20)}) end)
local grip=new("TextButton",{Name="ResizeGrip",Position=UDim2.new(1,-24,1,-24),Size=UDim2.fromOffset(24,24),BackgroundTransparency=1,Text="◢",TextColor3=palette.muted,TextSize=15},frame)
local edgeR=new("TextButton",{Name="ResizeRight",Position=UDim2.new(1,-5,0,0),Size=UDim2.new(0,5,1,-24),BackgroundTransparency=1,Text="",AutoButtonColor=false},frame)
local edgeB=new("TextButton",{Name="ResizeBottom",Position=UDim2.new(0,0,1,-5),Size=UDim2.new(1,-24,0,5),BackgroundTransparency=1,Text="",AutoButtonColor=false},frame)
local drag,resize,startMouse,startPos,startSize
local sizePresets={Vector2.new(360,470),Vector2.new(420,500),Vector2.new(480,540)}
local presetIndex=1
local function setMinimized(state)
 minimized=state
 selectTab(activeTab)
 bodyHost.Visible=not minimized status.Visible=not minimized footer.Visible=not minimized unload.Visible=not minimized
 minimize.Text=minimized and "+" or "−"
 tween(frame,{Size=UDim2.fromOffset(size.X,minimized and 58 or size.Y)})
 layoutPages()
end
local function cycleSize()
 presetIndex=presetIndex%#sizePresets+1
 size=sizePresets[presetIndex]
 layoutPages()
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
  layoutPages()
 end
end)
connect(UIS.InputEnded,function(i)
 if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false resize=false end
end)
connect(minimize.Activated,function() setMinimized(not minimized) end)
local cursor=new("TextLabel",{Name="HubCursor",Size=UDim2.fromOffset(18,24),BackgroundTransparency=1,Text="↖",Font=Enum.Font.GothamBold,TextSize=22,TextColor3=Color3.new(1,1,1),TextStrokeTransparency=0.25,ZIndex=100,Visible=false},gui)
local savedCursor,ownsCursor=false,false
local hovering=false
local function cursorRelease()
 if ownsCursor then UIS.MouseIconEnabled=savedCursor ownsCursor=false end
 header.Modal=false
 hovering=false
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
 if H.gather and H.gather.isActive() then label=H.gather.status end
 if #moduleErrors>0 then label=label.." · "..moduleErrors[1] end
 if status.Text~=label then status.Text=label end
end
local function cursorFree()
 -- A locked mouse means gameplay owns the pointer. The panel must never take
 -- it over then: setting Modal or MouseIconEnabled mid-game makes the game
 -- treat the cursor as free and drop character movement.
 return UIS.MouseBehavior~=Enum.MouseBehavior.LockCenter
end
local function updatePanel()
 local now=os.clock()
 if now>=nextStatus then nextStatus=now+0.5 refreshStatus() end
 local mouse=UIS:GetMouseLocation()
 local p,s=frame.AbsolutePosition,frame.AbsoluteSize
 local free=cursorFree()
 local inside=free and mouse.X>=p.X and mouse.X<=p.X+s.X and mouse.Y>=p.Y and mouse.Y<=p.Y+s.Y
 local want=inside or drag or resize
 -- Transition only. Re-asserting this every frame fights the game's input
 -- state; touching it once on enter and once on leave does not.
 if want~=hovering then
  hovering=want
  header.Modal=want
  if want then
   if not ownsCursor then savedCursor=UIS.MouseIconEnabled ownsCursor=true end
   UIS.MouseIconEnabled=true
   if MG then MG.paused=true end
  else
   cursorRelease()
  end
 end
 if hovering then
  cursor.Position=UDim2.fromOffset(mouse.X,mouse.Y)
  cursor.Visible=true
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
 if H.gather and H.gather.stop then H.gather.stop() end
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

