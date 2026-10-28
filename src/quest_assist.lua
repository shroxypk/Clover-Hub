-- Veyra Quest Assistance: reads client-visible quest/objective data only.
-- No remotes, quest completion, fabricated destinations or per-frame scanning.
local G=getgenv()
if G.VeyraQuestAssist then G.VeyraQuestAssist.stop() end
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local state={alive=true,enabled=false,status="Quest guide off",resolved=0,unresolved=0,selected=nil,available=0,progress=0,distance=nil,compact=false,markerMode="NEAR",targetKey=nil}
G.VeyraQuestAssist=state
local namedIndex,hintIndex,indexKeys,connections,markers={},{},{},{},{}
local worker,gui,holder,hud,title,anchorFolder
local stageLabel,detailLabel,metaLabel,progressFill,progressText,cardBody,collapseButton,markerButton,progressTween
local questTextRoot,questTextValues=nil,{}
local questTextConnections,questRootConnections={},{}
local function make(class,props,parent)
 local o=Instance.new(class)
 for k,v in pairs(props) do o[k]=v end
 o.Parent=parent return o
end
local function norm(s)
 local value=tostring(s or ""):lower():gsub("<[^>]*>","")
 value=value:gsub("&amp;","&"):gsub("&apos;","'"):gsub("&#39;","'")
  :gsub("&quot;",'"'):gsub("&nbsp;"," ")
 return value:gsub("^the ",""):gsub("^an? ",""):gsub(" respawnable$",""):gsub("[^%w]","")
end
local function validPos(value)
 if typeof(value)=="CFrame" then value=value.Position end
 if typeof(value)=="Vector3" and value.Magnitude>0.01 then return value end
end
local function posOf(o)
 if o:IsA("BasePart") then return o.Position end
 if o:IsA("Model") then return o:GetPivot().Position end
end
local function bucketAdd(container,key,o)
 if key=="" then return end
 local b=container[key]
 if not b then b={} container[key]=b end
 b[o]=true
end
local function indexObject(o)
 if not (o:IsA("Model") or o:IsA("BasePart") and (o.Parent and not o.Parent:IsA("Model") or o:GetAttribute("HintQuest"))) then return end
 if anchorFolder and o:IsDescendantOf(anchorFolder) then return end
 -- Avoid ever treating another player's character as a quest NPC.
 if o:IsA("Model") and Players:GetPlayerFromCharacter(o) then return end
 local key=norm(o.Name)
 local q=norm(o:GetAttribute("HintQuest"))
 local t=norm(o:GetAttribute("HintTask"))
 local hint=(q~="" and t~="") and (q.."|"..t) or ""
 bucketAdd(namedIndex,key,o)
 bucketAdd(hintIndex,hint,o)
 indexKeys[o]={key,hint}
end
local function removeObject(o)
 local keys=indexKeys[o]
 if not keys then return end
 for i,k in ipairs(keys) do
  local dest=i==1 and namedIndex or hintIndex
  local bucket=dest[k]
  if bucket then bucket[o]=nil if not next(bucket) then dest[k]=nil end end
 end
 indexKeys[o]=nil
end
local function done(t)
 local max=tonumber(t:GetAttribute("TaskMax")) or 1
 return max>0 and (tonumber(t:GetAttribute("TaskProgress")) or 0)>=max
end
local function ready(t,tasks,screenProgress)
 local prereq=t:GetAttribute("Prereq")
 if not prereq or prereq=="" then return true end
 local prev=tasks:FindFirstChild(prereq)
 if not prev then return false end
 local shown=screenProgress and screenProgress[prev]
 return (shown and shown.current>=shown.maximum) or done(prev)
end
local function tracked()
 local gameplay=player.PlayerGui:FindFirstChild("Gameplay")
 local quest=gameplay and gameplay:FindFirstChild("Quest")
 local tracking=quest and quest:FindFirstChild("Tracking")
 return tracking and tracking:FindFirstChild("Quests")
end
local function clearQuestTextCache()
 for _,connection in pairs(questTextConnections) do connection:Disconnect() end
 for _,connection in ipairs(questRootConnections) do connection:Disconnect() end
 table.clear(questTextConnections)
 table.clear(questRootConnections)
 table.clear(questTextValues)
 questTextRoot=nil
end
local function useQuestTextRoot(root)
 if questTextRoot==root then return end
 clearQuestTextCache()
 questTextRoot=root
 if not root then return end
 local function addText(o)
  if (o:IsA("TextLabel") or o:IsA("TextButton")) and questTextValues[o]==nil then
   questTextValues[o]=o.Text
   questTextConnections[o]=o:GetPropertyChangedSignal("Text"):Connect(function()
    questTextValues[o]=o.Text
   end)
  end
 end
 for _,o in ipairs(root:GetDescendants()) do addText(o) end
 table.insert(questRootConnections,root.DescendantAdded:Connect(addText))
 table.insert(questRootConnections,root.DescendantRemoving:Connect(function(o)
  local function removeText(item)
   questTextValues[item]=nil
   local connection=questTextConnections[item]
   if connection then connection:Disconnect() questTextConnections[item]=nil end
  end
  removeText(o)
  for _,item in ipairs(o:GetDescendants()) do removeText(item) end
 end))
end
-- Follow only explicit in-game tracking signals, never pick an unfinished quest.
local function trackedQuest()
 local folder=player:FindFirstChild("Quests")
 if not folder then return nil end
 local known={}
 for _,q in ipairs(folder:GetChildren()) do
  if q:FindFirstChild("Tasks") and q:GetAttribute("Completed")~=true then
   known[norm(q.Name)]=q
   local questName=q:GetAttribute("Quest")
   if type(questName)=="string" then known[norm(questName)]=q end
  end
 end
 -- The game itself stores the selected quest key on the player's Quests
 -- folder. Prefer this explicit replicated value when its UI is still loading.
 local indicators=player.PlayerGui:FindFirstChild("QuestIndicators")
 local tracking=folder:GetAttribute("Tracking")
 if type(tracking)=="string" and tracking~="" then
  local quest=known[norm(tracking)]
  if quest then return quest,indicators and indicators:FindFirstChild(quest.Name) end
 end
 -- Clover RPG: the game maintains a ScreenGui for each quest under
 -- PlayerGui.QuestIndicators. 'status' is the observed tracking flag.
 -- The status flag is a compatibility fallback for older game builds.
 if indicators then
  local active,activeIndicator=nil,nil
  local hasStatus=false
  for _,indicator in ipairs(indicators:GetChildren()) do
   local status=indicator:GetAttribute("status")
   if typeof(status)=="boolean" then
    hasStatus=true
    if status then
     -- Completed quests keep a stale true flag; only live quests select.
     local quest=known[norm(indicator.Name)]
     if quest then
      if active and active~=quest then return nil end -- Ambiguous selection.
      active=quest
      activeIndicator=indicator
     end
    end
   end
  end
  if active then return active,activeIndicator end
  -- When the game's indicator state is present but has no active quest,
  -- do not infer a selection from unrelated journal entries.
  if hasStatus then return nil end
 end
 -- Compatibility path for builds exposing quest rows directly.
 local tracker=tracked()
 if tracker then
  local matched=nil
  for _,row in ipairs(tracker:GetChildren()) do
   if row:IsA("GuiObject") and row.Visible then
    local name=row:GetAttribute("QuestId") or row:GetAttribute("QuestName")
      or row:GetAttribute("Quest") or row.Name
    local candidate=known[norm(name)]
    if candidate then
     if matched and matched~=candidate then return nil end
     matched=candidate
    end
   end
  end
  if matched then return matched end
 end
 -- Explicit record flags are the last fallback; never select arbitrary quests.
 local flagged=nil
 for _,q in ipairs(folder:GetChildren()) do
  if q:FindFirstChild("Tasks") and q:GetAttribute("Completed")~=true and
   (q:GetAttribute("Tracked")==true or q:GetAttribute("IsTracked")==true) then
   if flagged then return nil end
   flagged=q
  end
 end
 return flagged
end
-- When the replicated task progress lags behind the game's left quest HUD,
-- read only the active quest's *visible* tracker text, never unseen templates.
local function visibleIn(root,o)
 local item=o
 while item and item~=root do
  if item:IsA("GuiObject") and not item.Visible then return false end
  if item:IsA("ScreenGui") and not item.Enabled then return false end
  item=item.Parent
 end
 return item==root
end
local function displayedProgress(q)
 local gameplay=player.PlayerGui:FindFirstChild("Gameplay")
 local questUI=gameplay and gameplay:FindFirstChild("Quest")
 local tasks=q:FindFirstChild("Tasks")
 local progress={}
 useQuestTextRoot(questUI)
 if not questUI or not tasks then return false,progress end
 local texts={}
 local questName=norm(q:GetAttribute("Quest") or q.Name)
 local hasName=false
 for o,raw in pairs(questTextValues) do
  if raw~="" and visibleIn(questUI,o) then
   table.insert(texts,raw)
   if norm(raw)==questName then hasName=true end
  end
 end
 -- Quest HUD must explicitly show this quest to prevent cross-quest progress.
 if not hasName then return false,progress end
 local returnNPC=norm(q:GetAttribute("ReturnNPC") or q.Name)
 local returnVisible=false
 for _,raw in ipairs(texts) do
  local label=norm(raw)
  if label:sub(1,8)=="returnto" and returnNPC~="" and label:find(returnNPC,1,true) then
   returnVisible=true
  end
  local n,max=raw:match("%((%d+)%s*/%s*(%d+)%)")
  if n and max then
   for _,taskRecord in ipairs(tasks:GetChildren()) do
    if label:find(norm(taskRecord.Name),1,true) then
     progress[taskRecord]={current=tonumber(n),maximum=tonumber(max)}
    end
   end
  end
 end
 return returnVisible,progress
end
-- The guide stays mounted while tracking changes. Only the world markers
-- are recycled, so switching from objectives to return does not flash the HUD.
local function clearMarkers()
 for key,m in pairs(markers) do
  m.billboard:Destroy()
  if m.highlight then m.highlight:Destroy() end
  if m.anchor then m.anchor:Destroy() end
  markers[key]=nil
 end
end
local function clearVisuals()
 clearMarkers()
 if progressTween then progressTween:Cancel() progressTween=nil end
 if anchorFolder then anchorFolder:Destroy() anchorFolder=nil end
 if gui then gui:Destroy() end
 gui,holder,hud,title,cardBody,stageLabel,detailLabel,metaLabel,progressFill,progressText,collapseButton,markerButton=nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil
end
local uiTheme={
 surface=Color3.fromRGB(16,17,21),
 panel=Color3.fromRGB(24,25,30),
 border=Color3.fromRGB(53,55,65),
 main=Color3.fromRGB(243,241,245),
 muted=Color3.fromRGB(153,155,166),
 accent=Color3.fromRGB(229,56,59),
 alert=Color3.fromRGB(251,158,91),
 good=Color3.fromRGB(117,211,174),
}
local function rounded(obj,r)
 make("UICorner",{CornerRadius=UDim.new(0,r)},obj)
end
local function init()
 if gui then return end
 anchorFolder=make("Folder",{Name="VeyraQuestAnchors"},workspace)
 gui=make("ScreenGui",{Name="VeyraQuestGuide",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=9998,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},player.PlayerGui)
 holder=make("Frame",{Name="Guide",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-18,1,-78),Size=UDim2.fromOffset(336,state.compact and 60 or 168),BackgroundColor3=uiTheme.surface,BackgroundTransparency=0.06,BorderSizePixel=0,ClipsDescendants=true},gui)
 rounded(holder,13)
 make("UIStroke",{Color=uiTheme.border,Transparency=0.15,Thickness=1},holder)
 local accent=make("Frame",{Name="Accent",Position=UDim2.fromOffset(0,0),Size=UDim2.new(0,3,1,0),BackgroundColor3=uiTheme.accent,BorderSizePixel=0},holder)
 local brand=make("TextLabel",{Name="Brand",Position=UDim2.fromOffset(15,10),Size=UDim2.fromOffset(170,15),BackgroundTransparency=1,Text="VEYRA  /  QUEST TRACKER",Font=Enum.Font.GothamBold,TextSize=9,TextColor3=uiTheme.accent,TextXAlignment=Enum.TextXAlignment.Left},holder)
 title=make("TextLabel",{Name="Quest",Position=UDim2.fromOffset(15,28),Size=UDim2.new(1,-142,0,21),BackgroundTransparency=1,Text="No quest tracked",Font=Enum.Font.GothamBold,TextSize=14,TextColor3=uiTheme.main,TextTruncate=Enum.TextTruncate.AtEnd,TextXAlignment=Enum.TextXAlignment.Left},holder)
 stageLabel=make("TextLabel",{Name="Stage",Position=UDim2.new(1,-103,0,13),Size=UDim2.fromOffset(64,19),BackgroundColor3=uiTheme.panel,Text="IDLE",Font=Enum.Font.GothamBold,TextSize=9,TextColor3=uiTheme.muted},holder)
 rounded(stageLabel,6)
 collapseButton=make("TextButton",{Name="Collapse",Position=UDim2.new(1,-32,0,13),Size=UDim2.fromOffset(22,22),BackgroundColor3=uiTheme.panel,BorderSizePixel=0,Text=state.compact and "+" or "-",Font=Enum.Font.GothamBold,TextSize=15,TextColor3=uiTheme.main,AutoButtonColor=true},holder)
 rounded(collapseButton,6)
 markerButton=make("TextButton",{Name="MarkerVisibility",Position=UDim2.new(1,-111,0,36),Size=UDim2.fromOffset(78,21),BackgroundColor3=uiTheme.panel,BorderSizePixel=0,Text="PINS: "..state.markerMode,Font=Enum.Font.GothamBold,TextSize=9,TextColor3=uiTheme.muted,AutoButtonColor=true},holder)
 rounded(markerButton,6)
 markerButton.Activated:Connect(function()
  if not state.enabled then return end
  state.markerMode=state.markerMode=="NEAR" and "ALL" or state.markerMode=="ALL" and "OFF" or "NEAR"
  markerButton.Text="PINS: "..state.markerMode
  markerButton.TextColor3=state.markerMode=="OFF" and uiTheme.muted or uiTheme.good
  clearMarkers()
 end)
 markerButton.TextColor3=state.markerMode=="OFF" and uiTheme.muted or uiTheme.good
 -- The title area doubles as a drag handle, away from the two action buttons.
 local handle=make("TextButton",{Name="DragHandle",Position=UDim2.fromOffset(8,4),Size=UDim2.fromOffset(205,52),BackgroundTransparency=1,Text="",AutoButtonColor=false},holder)
 local dragStart,anchorStart,dragTouch
 local dragging=false
 handle.InputBegan:Connect(function(input)
  if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
  dragging=true
  dragTouch=input.UserInputType==Enum.UserInputType.Touch and input or nil
  dragStart=input.Position
  anchorStart=holder.AbsolutePosition+holder.AbsoluteSize
 end)
 table.insert(connections,UserInputService.InputChanged:Connect(function(input)
  if not dragging or not holder or not dragStart or not anchorStart then return end
  if dragTouch and input~=dragTouch then return end
  if not dragTouch and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
  local offset=input.Position-dragStart
  local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
  if not viewport then return end
  local size=holder.AbsoluteSize
  local x=math.clamp(anchorStart.X+offset.X,size.X+8,math.max(size.X+8,viewport.X-8))
  local y=math.clamp(anchorStart.Y+offset.Y,size.Y+8,math.max(size.Y+8,viewport.Y-8))
  holder.Position=UDim2.fromOffset(x,y)
 end))
 table.insert(connections,UserInputService.InputEnded:Connect(function(input)
  if (dragTouch and input==dragTouch) or (not dragTouch and input.UserInputType==Enum.UserInputType.MouseButton1) then
   dragging=false dragTouch=nil
  end
 end))
 cardBody=make("Frame",{Name="Details",Position=UDim2.fromOffset(15,60),Size=UDim2.new(1,-30,0,99),BackgroundTransparency=1,Visible=not state.compact},holder)
 make("Frame",{Name="Divider",Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,1),BackgroundColor3=uiTheme.border,BorderSizePixel=0},cardBody)
 hud=make("TextLabel",{Name="Objective",Position=UDim2.fromOffset(0,9),Size=UDim2.new(1,0,0,21),BackgroundTransparency=1,Text="Track a quest in the journal",Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=uiTheme.main,TextTruncate=Enum.TextTruncate.AtEnd,TextXAlignment=Enum.TextXAlignment.Left},cardBody)
 detailLabel=make("TextLabel",{Name="Direction",Position=UDim2.fromOffset(0,31),Size=UDim2.new(1,0,0,16),BackgroundTransparency=1,Text="Press J to choose a quest",Font=Enum.Font.Gotham,TextSize=11,TextColor3=uiTheme.good,TextTruncate=Enum.TextTruncate.AtEnd,TextXAlignment=Enum.TextXAlignment.Left},cardBody)
 metaLabel=make("TextLabel",{Name="Nearby",Position=UDim2.fromOffset(0,49),Size=UDim2.new(1,0,0,15),BackgroundTransparency=1,Text="",Font=Enum.Font.Gotham,TextSize=10,TextColor3=uiTheme.muted,TextTruncate=Enum.TextTruncate.AtEnd,TextXAlignment=Enum.TextXAlignment.Left},cardBody)
 local progressTrack=make("Frame",{Name="ProgressTrack",Position=UDim2.fromOffset(0,72),Size=UDim2.new(1,0,0,5),BackgroundColor3=uiTheme.border,BorderSizePixel=0},cardBody)
 rounded(progressTrack,3)
 progressFill=make("Frame",{Name="ProgressFill",Size=UDim2.fromScale(0,1),BackgroundColor3=uiTheme.accent,BorderSizePixel=0},progressTrack)
 rounded(progressFill,3)
 progressText=make("TextLabel",{Name="Progress",Position=UDim2.fromOffset(0,80),Size=UDim2.new(1,0,0,15),BackgroundTransparency=1,Text="No active progress",Font=Enum.Font.Gotham,TextSize=10,TextColor3=uiTheme.muted,TextXAlignment=Enum.TextXAlignment.Left},cardBody)
 collapseButton.Activated:Connect(function()
  if not state.enabled or not holder then return end
  state.compact=not state.compact
  collapseButton.Text=state.compact and "+" or "-"
  if not state.compact then cardBody.Visible=true end
  -- Hide the contents after the collapse finishes, not before it starts.
  -- The state guard prevents an interrupted collapse from hiding an expanded card.
  local collapsing=state.compact
  local tween=TweenService:Create(holder,TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(336,collapsing and 60 or 168)})
  tween.Completed:Once(function(playback)
   if playback==Enum.PlaybackState.Completed and collapsing and state.compact and cardBody then
    cardBody.Visible=false
   end
  end)
  tween:Play()
 end)
end
-- Update only changed values. Progress animates on actual progress changes,
-- never every 0.75 s poll, and the guide survives quest/phase transitions.
local function renderGuide(info)
 if not gui then init() end
 if title.Text~=info.quest then title.Text=info.quest end
 if hud.Text~=info.objective then hud.Text=info.objective end
 if detailLabel.Text~=info.detail then detailLabel.Text=info.detail end
 if metaLabel.Text~=info.meta then metaLabel.Text=info.meta end
 if progressText.Text~=info.progressText then progressText.Text=info.progressText end
 local stage=info.stage or "TRACKING"
 if stageLabel.Text~=stage then stageLabel.Text=stage end
 local tint=stage=="RETURN" and uiTheme.good or stage=="WAITING" and uiTheme.alert or stage=="TRACKING" and uiTheme.accent or uiTheme.muted
 if stageLabel.TextColor3~=tint then stageLabel.TextColor3=tint end
 detailLabel.TextColor3=info.kind=="combat" and uiTheme.alert or uiTheme.good
 local fraction=math.clamp(info.progress or 0,0,1)
 if state.progress~=fraction then
  state.progress=fraction
  if progressTween then progressTween:Cancel() end
  progressTween=TweenService:Create(progressFill,TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.fromScale(fraction,1)})
  progressTween:Play()
 end
end
-- Progress is based only on replicated tasks and visible tracker values,
-- never inferred from the number of nearby NPCs or world markers.
local function questProgress(q,screenProgress,returning)
 local tasks=q:FindFirstChild("Tasks")
 local total,finished,portion=0,0,0
 if tasks then
  for _,t in ipairs(tasks:GetChildren()) do
   total+=1
   local shown=screenProgress and screenProgress[t]
   local max=math.max(1,shown and shown.maximum or (tonumber(t:GetAttribute("TaskMax")) or 1))
   local current=shown and shown.current or (tonumber(t:GetAttribute("TaskProgress")) or 0)
   local ratio=math.clamp(current/max,0,1)
   portion+=ratio
   if ratio>=1 then finished+=1 end
  end
 end
 local fraction=total>0 and portion/total or 0
 if returning then fraction=1 end
 local caption=total>0 and string.format("%d/%d steps complete  ·  %d%%",finished,total,math.floor(fraction*100+0.5))
  or (returning and "Objectives complete  ·  return for reward" or "Waiting for quest objectives")
 return fraction,caption
end
local function adorneeOf(o)
 if not o then return nil end
 if o:IsA("BasePart") then return o end
 return o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart",true)
end
local palette={objective=Color3.fromRGB(135,238,188),combat=Color3.fromRGB(255,158,126)}
local function marker(key,t)
 local a=t.model
 local anchor
 if not a then
  anchor=make("Part",{Name="QuestMarker",Transparency=1,Size=Vector3.one,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CFrame=CFrame.new(t.pos)},anchorFolder)
  a=anchor
 end
 local tint=t.kind=="combat" and palette.combat or palette.objective
 local bb=make("BillboardGui",{Name="QuestObjective",Adornee=adorneeOf(a),AlwaysOnTop=false,Size=UDim2.fromOffset(155,34),StudsOffsetWorldSpace=Vector3.new(0,3,0),MaxDistance=260},gui)
 local label=make("TextLabel",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(18,25,32),BackgroundTransparency=0.15,TextColor3=tint,TextSize=11,Font=Enum.Font.GothamBold,TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd},bb)
 make("UICorner",{CornerRadius=UDim.new(0,7)},label)
 local highlight
 if t.model then
  highlight=make("Highlight",{Adornee=t.model,FillColor=t.kind=="combat" and Color3.fromRGB(255,120,96) or Color3.fromRGB(101,221,169),FillTransparency=0.85,OutlineTransparency=0.24,DepthMode=Enum.HighlightDepthMode.Occluded},workspace)
 end
 markers[key]={billboard=bb,label=label,highlight=highlight,anchor=anchor,model=t.model}
end
local function removeMarker(key,m)
 m.billboard:Destroy()
 if m.highlight then m.highlight:Destroy() end
 if m.anchor then m.anchor:Destroy() end
 markers[key]=nil
end
local function resolve(q,root,forceReturn,screenProgress)
 local targets,notes={},{}
 state.resolved=0 state.unresolved=0
 local tasks=q:FindFirstChild("Tasks")
 local function target(key,label,pos,model,kind)
  if pos then targets[key]={key=key,label=label,pos=pos,model=model,kind=kind} end
 end
 local function matches(bucket,label,kind,closest)
  local seen=false
  local nearest,nearDist
  local limited={}
  for o in pairs(bucket or {}) do
   if o.Parent and o:IsDescendantOf(workspace) and o:GetAttribute("Gathered")~=true and o:GetAttribute("Hidden")~=true then
    local hum=o:FindFirstChildOfClass("Humanoid")
    -- Combat names must be living mobs; map props may share a name.
    if (kind~="combat" or hum) and (not hum or hum.Health>0) then
     local pos=posOf(o)
     if pos then
      seen=true
      local distance=(pos-root.Position).Magnitude
      if closest then
       if not nearDist or distance<nearDist then nearest={o=o,pos=pos} nearDist=distance end
      elseif #limited<4 then
       table.insert(limited,{o=o,pos=pos,d=distance})
      else
       local worst,d=1,limited[1].d
       for i=2,#limited do if limited[i].d>d then worst,d=i,limited[i].d end end
       if distance<d then limited[worst]={o=o,pos=pos,d=distance} end
      end
     end
    end
   end
  end
  if nearest then target(nearest.o,label,nearest.pos,nearest.o,kind) end
  for _,m in ipairs(limited) do target(m.o,label,m.pos,m.o,kind) end
  return seen
 end
 local function named(name,label,kind,closest)
  local key=norm(name)
  if key=="" then return false end
  local found=matches(namedIndex[key],label,kind,closest)
  if not found and key:sub(-3)=="ies" then found=matches(namedIndex[key:sub(1,-4).."y"],label,kind,closest) end
  if not found and key:sub(-1)=="s" then found=matches(namedIndex[key:sub(1,-2)],label,kind,closest) end
  -- Irregular plurals used by combat objectives: wolves -> wolf, knives -> knife.
  if not found and key:sub(-3)=="ves" then
   found=matches(namedIndex[key:sub(1,-4).."f"],label,kind,closest)
   if not found then found=matches(namedIndex[key:sub(1,-4).."fe"],label,kind,closest) end
  end
  if not found and kind=="collect" and label:lower():find(" ore",1,true) then
   found=matches(namedIndex[key.."ore"],label,kind,closest)
  end
  if not found and kind=="collect" and key:sub(-3)=="ore" then
   found=matches(namedIndex[key:sub(1,-4)],label,kind,closest)
  end
  return found
 end
 local remaining=false
 if tasks and not forceReturn then
  for _,t in ipairs(tasks:GetChildren()) do
   local shown=screenProgress and screenProgress[t]
   local current=shown and shown.current or (tonumber(t:GetAttribute("TaskProgress")) or 0)
   local max=shown and shown.maximum or (tonumber(t:GetAttribute("TaskMax")) or 1)
   if current<max then
    remaining=true
    if t:GetAttribute("Hidden")~=true and ready(t,tasks,screenProgress) then
     local low=t.Name:lower()
     local combat=low:match("^(hunt) ") or low:match("^(defeat) ") or low:match("^(exterminate) ")
      or low:match("^(eliminate) ") or low:match("^(kill) ")
     local craft=low:match("^(brew) ") or low:match("^(craft) ") or low:match("^(forge) ") or low:match("^(cook) ")
     local gather=low:match("^(gather) ") or low:match("^(collect) ") or low:match("^(harvest) ")
     local kind=combat and "combat" or craft and "craft" or (gather or t:GetAttribute("TaskType")=="Collect") and "collect" or "visit"
     local progress=current
     local label=t.Name.." ("..progress.."/"..max..")"
     local found=false
     local pos=validPos(t:GetAttribute("TrackPosition"))
     if pos then target(t,label,pos,nil,kind) found=true end
     local hintKey=norm(q.Name).."|"..norm(t.Name)
     found=matches(hintIndex[hintKey],label,kind,kind=="combat") or found
     local altHint=norm(q:GetAttribute("Quest")).."|"..norm(t.Name)
     if altHint~=hintKey then found=matches(hintIndex[altHint],label,kind,kind=="combat") or found end
     local object=t:GetAttribute("Object")
     if not craft and type(object)=="string" and object~="" then
      found=named(object,label,kind,kind=="combat") or found
     end
     if craft and low:match("^brew ") then found=named("Cauldron",label,kind,true) or found end
     local name=t.Name:match("^Talk to (.+)") or t.Name:match("^Speak to (.+)")
      or t.Name:match("^Report to (.+)") or t.Name:match("^Return to (.+)")
      or t.Name:match("^Deliver .- to (.+)") or t.Name:match("^Meet (.+)")
      or t.Name:match("^Find (.+)") or t.Name:match("^Locate (.+)")
      or t.Name:match("^Gather (.+)") or t.Name:match("^Collect (.+)") or t.Name:match("^Harvest (.+)")
      or t.Name:match("^Retrieve (.+)") or t.Name:match("^Get (.+)")
      or t.Name:match("^Light (.+)") or t.Name:match("^Activate (.+)")
      or t.Name:match("^Interact with (.+)") or t.Name:match("^Inspect (.+)")
      or t.Name:match("^Repair (.+)") or t.Name:match("^Visit (.+)")
      or t.Name:match("^Defeat (.+)") or t.Name:match("^Hunt (.+)")
      or t.Name:match("^Exterminate (.+)")
     if name then
      name=name:gsub("%.$",""):gsub(" at .+$",""):gsub(" in .+$","")
      -- Combat keeps several candidates so the two nearest mobs are marked;
      -- other kinds only need their single best match here.
      found=named(name,label,kind,false) or found
      -- "Hunt wild wolves" -> also try the final noun "wolves".
      if not found then
       local tail=name:match("([%a']+)$")
       if tail and tail~=name then found=named(tail,label,kind,false) or found end
      end
     end
     -- Quest Objects values can be flags (Bucket, Lantern1, etc.). Only match
     -- exact world names; discard bookkeeping flags, never guess coordinates.
     local objects=q:FindFirstChild("Objects")
     if objects and not combat and not craft and (not object or object=="") then
      for _,obj in ipairs(objects:GetChildren()) do
       if not obj.Name:match("^Starter") and not obj.Name:match("^Picked_") then
        found=named(obj.Name,label,kind,false) or found
       end
      end
     end
     if found then
      state.resolved+=1
     else
      state.unresolved+=1
      local tip=q:GetAttribute("Tip") or q:GetAttribute("QuestDescription")
      local prefix=combat and "Combat" or craft and "Craft" or "Find"
      table.insert(notes,prefix..": "..label..(type(tip)=="string" and tip~="" and (" · "..tip) or " · No location in loaded world"))
     end
    end
   end
  end
 end
 if forceReturn or not remaining then
  local npc=q:GetAttribute("ReturnNPC")
  if not npc or npc=="" then npc=q.Name end
  local label="Return to "..npc
  local pos=validPos(q:GetAttribute("ReturnPosition"))
  if pos then target(q,label,pos,nil,"return") state.resolved+=1
  elseif named(npc,label,"return",true) then state.resolved+=1
  else state.unresolved+=1 table.insert(notes,label.." · Location unavailable") end
 end
 return targets,notes
end
local function update()
 local selected,indicator=trackedQuest()
 state.available=selected and 1 or 0
 if not selected then
  if state.selected then clearMarkers() end
  state.selected=nil
  state.phase=nil
  state.targetKey=nil
  state.distance=nil
  useQuestTextRoot(nil)
  -- Distinguish "nothing tracked" from a stale flag left on a finished quest.
  local stale=false
  local indicators=player.PlayerGui:FindFirstChild("QuestIndicators")
  if indicators then
   for _,entry in ipairs(indicators:GetChildren()) do
    if entry:GetAttribute("status")==true then stale=true break end
   end
  end
  state.status=stale and "Tracked quest is complete · track another (J)"
   or "Track a quest in the game journal (J)"
  renderGuide({
   quest=stale and "Quest finished" or "No quest tracked",
   stage=stale and "DONE" or "IDLE",
   objective=stale and "Choose your next quest" or "Track an objective to begin",
   detail="Open your quest journal (J)",
   meta="Only the game's tracked quest is shown",
   progress=0,progressText="No active progress",
  })
  return
 end
 if state.selected~=selected.Name then
  clearMarkers()
  state.phase=nil
  state.targetKey=nil
  state.selected=selected.Name
 end
 local questName=tostring(selected:GetAttribute("Quest") or selected.Name)
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if not root then
  state.targetKey=nil
  if next(markers) then clearMarkers() end
  state.status="Waiting for character"
  state.distance=nil
  renderGuide({quest=questName,stage="WAITING",objective="Character not ready",
   detail="Tracking resumes when you spawn",meta="Quest data is still available",
   progress=0,progressText="Waiting for character"})
  return
 end
 local uiReturning,screenProgress=displayedProgress(selected)
 local returning=(indicator and indicator:GetAttribute("Return")==true) or uiReturning
 local phase=returning and "return" or "objectives"
 if state.phase~=phase then
  clearMarkers()
  state.targetKey=nil
  state.phase=phase
 end
 local targets,notes=resolve(selected,root,returning,screenProgress)
 local sorted={}
 for _,t in pairs(targets) do
  t.distance=(t.pos-root.Position).Magnitude
  table.insert(sorted,t)
 end
 table.sort(sorted,function(a,b)
  -- The main HUD should point to the actually closest target, rather than
  -- prioritizing distant noncombat objectives over nearby enemies.
  if math.abs(a.distance-b.distance)<0.5 then return a.label<b.label end
  return a.distance<b.distance
 end)
 if not gui then init() end
 local keep={}
 local shownObjective,shownCombat=0,0
 local maxCombat=state.markerMode=="ALL" and 2 or state.markerMode=="NEAR" and 1 or 0
 local maxObjective=state.markerMode=="ALL" and 4 or state.markerMode=="NEAR" and 1 or 0
 for _,t in ipairs(sorted) do
  local combat=t.kind=="combat"
  -- Combat targets are the actual nearby mobs (nearest first), capped tighter.
  if (combat and shownCombat<maxCombat) or (not combat and shownObjective<maxObjective) then
   if combat then shownCombat+=1 else shownObjective+=1 end
   keep[t.key]=true
   local m=markers[t.key]
   if m and (m.model~=t.model or m.kind~=t.kind) then removeMarker(t.key,m) m=nil end
   if not m then marker(t.key,t) m=markers[t.key] m.kind=t.kind end
   if m.anchor then m.anchor.Position=t.pos end
   m.billboard.Adornee=adorneeOf(t.model or m.anchor)
   m.billboard.Enabled=true
   local label=t.label.." · "..math.floor(t.distance).." studs"
   if m.label.Text~=label then m.label.Text=label end
  end
 end
 for key,m in pairs(markers) do if not keep[key] then removeMarker(key,m) end end
 local nearest=sorted[1]
 -- A small distance advantage should not switch the HUD target every poll.
 -- Switching quests, phases or respawning resets this preference.
 if nearest and state.targetKey and nearest.key~=state.targetKey then
  for _,candidate in ipairs(sorted) do
   if candidate.key==state.targetKey and candidate.distance<=nearest.distance+12 then
    nearest=candidate break
   end
  end
 end
 state.targetKey=nearest and nearest.key or nil
 local fraction,progressCaption=questProgress(selected,screenProgress,returning)
 local objective,detail,meta,kind
 if nearest then
  local camera=workspace.CurrentCamera
  local delta=camera and camera.CFrame:VectorToObjectSpace(nearest.pos-camera.CFrame.Position)
  local direction=delta and
   (math.abs(delta.X)>math.abs(delta.Z) and (delta.X>0 and "RIGHT" or "LEFT")
     or (delta.Z<0 and "AHEAD" or "BEHIND")) or "TARGET"
  objective=nearest.label -- Keep exact task count (e.g. 4/10) visible.
  detail=string.format("%s  ·  %d studs away",direction,math.floor(nearest.distance))
  meta=string.format("%d known locations  ·  %d located / %d unknown",#sorted,state.resolved,state.unresolved)
  kind=nearest.kind
  state.distance=math.floor(nearest.distance)
 else
  objective=notes[1] or "Objective in progress"
  detail=returning and "Return location is not streamed" or "Location not found in loaded world"
  meta=string.format("%d located / %d unknown  ·  keep exploring",state.resolved,state.unresolved)
  kind="visit"
  state.distance=nil
 end
 renderGuide({
  quest=questName,stage=returning and "RETURN" or "TRACKING",
  objective=objective,detail=detail,meta=meta,kind=kind,
  progress=fraction,progressText=progressCaption,
 })
 state.status=state.resolved.." located · "..state.unresolved.." unknown"
end
function state.setEnabled(on)
 if not state.alive then return end
 on=on==true
 if on==state.enabled then return end
 state.generation=(state.generation or 0)+1
 state.enabled=on
 if worker then task.cancel(worker) worker=nil end
 for _,c in ipairs(connections) do c:Disconnect() end
 table.clear(connections)
 table.clear(namedIndex)
 table.clear(hintIndex)
 table.clear(indexKeys)
 clearVisuals()
 clearQuestTextCache()
 if not on then state.status="Quest guide off" state.phase=nil state.targetKey=nil state.distance=nil state.progress=0 return end
 init()
 local generation=state.generation
 worker=task.spawn(function()
  local indexed=false
  while state.alive and state.enabled and state.generation==generation do
   local current=trackedQuest()
   if current and not indexed then
    table.insert(connections,workspace.DescendantAdded:Connect(indexObject))
    table.insert(connections,workspace.DescendantRemoving:Connect(removeObject))
    local descendants=workspace:GetDescendants()
    for i,o in ipairs(descendants) do
     if not state.alive or not state.enabled or state.generation~=generation then return end
     indexObject(o)
     if i%3000==0 then task.wait() end
    end
    descendants=nil
    indexed=true
   end
   local ok,err=pcall(update)
   if not ok then state.status="Quest data unavailable" warn("[Veyra Quest] "..tostring(err)) end
   task.wait(0.75)
  end
 end)
end
function state.stop()
 state.setEnabled(false)
 state.alive=false
 if G.VeyraQuestAssist==state then G.VeyraQuestAssist=nil end
end
return state

