-- Veyra Quest Assistance: reads client-visible quest/objective data only.
-- No remotes, quest completion, fabricated destinations or per-frame scanning.
local G=getgenv()
if G.VeyraQuestAssist then G.VeyraQuestAssist.stop() end
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local state={alive=true,enabled=false,status="Quest guide off",resolved=0,unresolved=0,selected=nil,available=0}
G.VeyraQuestAssist=state
local namedIndex,hintIndex,indexKeys,connections,markers={},{},{},{},{}
local worker,gui,holder,hud,title,anchorFolder
local function make(class,props,parent)
 local o=Instance.new(class)
 for k,v in pairs(props) do o[k]=v end
 o.Parent=parent return o
end
local function norm(s)
 return tostring(s or ""):lower():gsub("^the ",""):gsub("^an? ",""):gsub(" respawnable$",""):gsub("[^%w]","")
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
local function ready(t,tasks)
 local prereq=t:GetAttribute("Prereq")
 if not prereq or prereq=="" then return true end
 local prev=tasks:FindFirstChild(prereq)
 return prev~=nil and done(prev)
end
local function tracked()
 local gameplay=player.PlayerGui:FindFirstChild("Gameplay")
 local quest=gameplay and gameplay:FindFirstChild("Quest")
 local tracking=quest and quest:FindFirstChild("Tracking")
 return tracking and tracking:FindFirstChild("Quests")
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
 -- Clover RPG: the game maintains a ScreenGui for each quest under
 -- PlayerGui.QuestIndicators. 'status' is the observed tracking flag.
 -- This source takes priority over journal selection and template widgets.
 local indicators=player.PlayerGui:FindFirstChild("QuestIndicators")
 if indicators then
  local active=nil
  local hasStatus=false
  for _,indicator in ipairs(indicators:GetChildren()) do
   local status=indicator:GetAttribute("status")
   if typeof(status)=="boolean" then
    hasStatus=true
    if status then
     local quest=known[norm(indicator.Name)]
     if not quest then return nil end -- Unknown active quest; don't guess.
     if active and active~=quest then return nil end -- Ambiguous selection.
     active=quest
    end
   end
  end
  if active then return active end
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
local function clearVisuals()
 for key,m in pairs(markers) do
  m.billboard:Destroy()
  if m.highlight then m.highlight:Destroy() end
  if m.anchor then m.anchor:Destroy() end
  markers[key]=nil
 end
 if anchorFolder then anchorFolder:Destroy() anchorFolder=nil end
 if gui then gui:Destroy() gui=nil holder=nil hud=nil title=nil end
end
local function init()
 anchorFolder=make("Folder",{Name="VeyraQuestAnchors"},workspace)
 gui=make("ScreenGui",{Name="VeyraQuestGuide",ResetOnSpawn=false,DisplayOrder=9998},player.PlayerGui)
 holder=make("Frame",{Name="Guide",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-14,1,-78),Size=UDim2.fromOffset(292,72),BackgroundColor3=Color3.fromRGB(16,22,30),BackgroundTransparency=0.19,BorderSizePixel=0},gui)
 make("UICorner",{CornerRadius=UDim.new(0,9)},holder)
 make("UIStroke",{Color=Color3.fromRGB(63,83,92),Transparency=0.5,Thickness=1},holder)
 title=make("TextLabel",{Name="Quest",Position=UDim2.fromOffset(10,5),Size=UDim2.new(1,-20,0,18),BackgroundTransparency=1,TextColor3=Color3.fromRGB(135,238,188),Font=Enum.Font.GothamBold,TextSize=11,TextTruncate=Enum.TextTruncate.AtEnd,TextXAlignment=Enum.TextXAlignment.Left,Text="Quest guide"},holder)
 hud=make("TextLabel",{Name="Objective",Position=UDim2.fromOffset(10,24),Size=UDim2.new(1,-20,1,-30),BackgroundTransparency=1,TextColor3=Color3.fromRGB(229,241,237),TextSize=11,Font=Enum.Font.GothamMedium,TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,Text="Loading objectives..."},holder)
end
local function adorneeOf(o)
 if not o then return nil end
 if o:IsA("BasePart") then return o end
 return o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart",true)
end
local function marker(key,t)
 local a=t.model
 local anchor
 if not a then
  anchor=make("Part",{Name="QuestMarker",Transparency=1,Size=Vector3.one,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CFrame=CFrame.new(t.pos)},anchorFolder)
  a=anchor
 end
 local bb=make("BillboardGui",{Name="QuestObjective",Adornee=adorneeOf(a),AlwaysOnTop=false,Size=UDim2.fromOffset(155,34),StudsOffsetWorldSpace=Vector3.new(0,3,0),MaxDistance=260},gui)
 local label=make("TextLabel",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(18,25,32),BackgroundTransparency=0.15,TextColor3=Color3.fromRGB(135,238,188),TextSize=11,Font=Enum.Font.GothamBold,TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd},bb)
 make("UICorner",{CornerRadius=UDim.new(0,7)},label)
 local highlight
 if t.model then
  highlight=make("Highlight",{Adornee=t.model,FillColor=Color3.fromRGB(101,221,169),FillTransparency=0.85,OutlineTransparency=0.24,DepthMode=Enum.HighlightDepthMode.Occluded},workspace)
 end
 markers[key]={billboard=bb,label=label,highlight=highlight,anchor=anchor,model=t.model}
end
local function removeMarker(key,m)
 m.billboard:Destroy()
 if m.highlight then m.highlight:Destroy() end
 if m.anchor then m.anchor:Destroy() end
 markers[key]=nil
end
local function resolve(q,root)
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
    if not hum or hum.Health>0 then
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
  if not found and kind=="collect" and label:lower():find(" ore",1,true) then
   found=matches(namedIndex[key.."ore"],label,kind,closest)
  end
  if not found and kind=="collect" and key:sub(-3)=="ore" then
   found=matches(namedIndex[key:sub(1,-4)],label,kind,closest)
  end
  return found
 end
 local remaining=false
 if tasks then
  for _,t in ipairs(tasks:GetChildren()) do
   if not done(t) then
    remaining=true
    if t:GetAttribute("Hidden")~=true and ready(t,tasks) then
     local low=t.Name:lower()
     local combat=low:match("^(hunt) ") or low:match("^(defeat) ") or low:match("^(exterminate) ")
      or low:match("^(eliminate) ") or low:match("^(kill) ")
     local craft=low:match("^(brew) ") or low:match("^(craft) ") or low:match("^(forge) ") or low:match("^(cook) ")
     local gather=low:match("^(gather) ") or low:match("^(collect) ") or low:match("^(harvest) ")
     local kind=combat and "combat" or craft and "craft" or (gather or t:GetAttribute("TaskType")=="Collect") and "collect" or "visit"
     local progress=tonumber(t:GetAttribute("TaskProgress")) or 0
     local max=tonumber(t:GetAttribute("TaskMax")) or 1
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
      found=named(name,label,kind,kind=="combat") or found
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
 if not remaining then
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
 local selected=trackedQuest()
 state.available=selected and 1 or 0
 if not selected then
  state.selected=nil
  clearVisuals()
  state.status="Track a quest in the game journal (J)"
  return
 end
 if state.selected~=selected.Name then
  clearVisuals()
  state.selected=selected.Name
 end
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if not root then state.status="Waiting for character" return end
 local targets,notes=resolve(selected,root)
 local sorted={}
 for _,t in pairs(targets) do
  t.distance=(t.pos-root.Position).Magnitude
  table.insert(sorted,t)
 end
 table.sort(sorted,function(a,b)
  if (a.kind=="combat")~=(b.kind=="combat") then return a.kind~="combat" end
  if a.distance==b.distance then return a.label<b.label end
  return a.distance<b.distance
 end)
 if not gui then init() end
 local keep={}
 local shown=0
 for _,t in ipairs(sorted) do
  if t.kind~="combat" and shown<4 then
   shown+=1
   keep[t.key]=true
   local m=markers[t.key]
   if m and m.model~=t.model then removeMarker(t.key,m) m=nil end
   if not m then marker(t.key,t) m=markers[t.key] end
   if m.anchor then m.anchor.Position=t.pos end
   m.billboard.Adornee=adorneeOf(t.model or m.anchor)
   m.billboard.Enabled=shown<=2
   local label=t.label.." · "..math.floor(t.distance).." studs"
   if m.label.Text~=label then m.label.Text=label end
  end
 end
 for key,m in pairs(markers) do if not keep[key] then removeMarker(key,m) end end
 local nearest=sorted[1]
 local text
 if nearest then
  local camera=workspace.CurrentCamera
  local delta=camera and camera.CFrame:VectorToObjectSpace(nearest.pos-camera.CFrame.Position)
  local direction=delta and
   (math.abs(delta.X)>math.abs(delta.Z) and (delta.X>0 and "RIGHT" or "LEFT")
     or (delta.Z<0 and "AHEAD" or "BEHIND")) or "TARGET"
  local typeLabel=nearest.kind=="combat" and "Combat area" or nearest.kind=="craft" and "Crafting" or "Objective"
  text=typeLabel.." · "..direction.." · "..math.floor(nearest.distance).." studs\n"..nearest.label
 else
  text=notes[1] or "Objective in progress · no known position"
 end
 local newTitle=tostring(selected:GetAttribute("Quest") or selected.Name)
 if title.Text~=newTitle then title.Text=newTitle end
 if hud.Text~=text then hud.Text=text end
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
 if not on then state.status="Quest guide off" return end
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
