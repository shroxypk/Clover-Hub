-- Objective-aware, read-only guide. No fabricated coordinates or remote calls.
local G=getgenv()
if G.VeyraQuestAssist then G.VeyraQuestAssist.stop() end
local player=game:GetService("Players").LocalPlayer
local state={alive=true,enabled=false,status="Quest guide off",resolved=0,unresolved=0,mode="compact"}
G.VeyraQuestAssist=state
local index,connections,markers={},{},{}
local worker,gui,hud,holder
local function make(class,props,parent)
 local o=Instance.new(class)
 for k,v in pairs(props) do o[k]=v end
 o.Parent=parent return o
end
local function norm(s)
 return tostring(s or ""):lower():gsub(" respawnable$",""):gsub("[^%w]","")
end
local function canIndex(o)
 return o:IsA("Model") or (o:IsA("BasePart") and o.Parent and not o.Parent:IsA("Model"))
end
local function indexObject(o)
 if not canIndex(o) then return end
 local k=norm(o.Name)
 if k=="" then return end
 local bucket=index[k]
 if not bucket then bucket={} index[k]=bucket end
 bucket[o]=true
end
local function removeObject(o)
 local k=norm(o.Name)
 local bucket=index[k]
 if bucket then bucket[o]=nil if not next(bucket) then index[k]=nil end end
end
local function posOf(o)
 if o:IsA("BasePart") then return o.Position end
 if o:IsA("Model") then return o:GetPivot().Position end
end
local function valuePos(v)
 if typeof(v)=="CFrame" then return v.Position end
 if typeof(v)=="Vector3" and v.Magnitude>0.01 then return v end
end
local function done(t)
 local maximum=t:GetAttribute("TaskMax") or 1
 return maximum>0 and (t:GetAttribute("TaskProgress") or 0)>=maximum
end
local function ready(t,tasks)
 local prereq=t:GetAttribute("Prereq")
 if not prereq or prereq=="" then return true end
 local dep=tasks:FindFirstChild(prereq)
 return dep~=nil and done(dep)
end
local function tracked()
 local gameplay=player.PlayerGui:FindFirstChild("Gameplay")
 local quest=gameplay and gameplay:FindFirstChild("Quest")
 local tracking=quest and quest:FindFirstChild("Tracking")
 return tracking and tracking:FindFirstChild("Quests")
end
local function clearVisuals()
 for key,m in pairs(markers) do
  m.billboard:Destroy()
  if m.highlight then m.highlight:Destroy() end
  markers[key]=nil
 end
 if gui then gui:Destroy() gui=nil hud=nil holder=nil end
end
local function init()
 gui=make("ScreenGui",{Name="VeyraQuestGuide",ResetOnSpawn=false,DisplayOrder=9998,IgnoreGuiInset=false},player.PlayerGui)
 holder=make("Frame",{Name="Guide",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-16,1,-85),Size=UDim2.fromOffset(280,54),BackgroundColor3=Color3.fromRGB(16,22,30),BackgroundTransparency=0.19,BorderSizePixel=0},gui)
 make("UICorner",{CornerRadius=UDim.new(0,9)},holder)
 make("UIStroke",{Color=Color3.fromRGB(63,83,92),Transparency=0.5,Thickness=1},holder)
 hud=make("TextLabel",{Name="Objective",Position=UDim2.fromOffset(10,6),Size=UDim2.new(1,-20,1,-12),BackgroundTransparency=1,TextColor3=Color3.fromRGB(229,241,237),TextSize=11,Font=Enum.Font.GothamMedium,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,Text="Reading tracked quests..."},holder)
end
local function adorneeOf(model)
 if not model then return nil end
 if model:IsA("BasePart") then return model end
 return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true)
end
local function addMarker(key,t)
 local a=t.model
 local billboard=make("BillboardGui",{Name="QuestObjective",Adornee=adorneeOf(a),AlwaysOnTop=false,Size=UDim2.fromOffset(160,39),StudsOffsetWorldSpace=Vector3.new(0,3.5,0),MaxDistance=350},gui)
 local label=make("TextLabel",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(18,25,32),BackgroundTransparency=0.15,TextColor3=Color3.fromRGB(135,238,188),TextSize=11,Font=Enum.Font.GothamBold,TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd},billboard)
 make("UICorner",{CornerRadius=UDim.new(0,7)},label)
 local highlight
 if a then highlight=make("Highlight",{Adornee=a,FillColor=Color3.fromRGB(101,221,169),FillTransparency=0.85,OutlineTransparency=0.2,DepthMode=Enum.HighlightDepthMode.Occluded},workspace) end
 markers[key]={billboard=billboard,label=label,highlight=highlight}
end
local function resolve()
 local ui=tracked()
 local quests=player:FindFirstChild("Quests")
 local targets,notes={},{}
 state.resolved=0 state.unresolved=0
 if not ui or not quests then return targets,{"Track a quest to see guidance"} end
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local function target(key,label,pos,model,kind)
  if pos then targets[key]={key=key,label=label,pos=pos,model=model,kind=kind} end
 end
 local function named(name,label,kind,nearest)
  if not name or name=="" then return false end
  local k=norm(name)
  local bucket=index[k] or index[k:gsub("s$","")]
  local best,bestDist,found=nil,nil,false
  for o in pairs(bucket or {}) do
   if o.Parent and o:IsDescendantOf(workspace) and o:GetAttribute("Hidden")~=true and o:GetAttribute("Gathered")~=true then
    local hum=o:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health>0 then
     local p=posOf(o)
     if p then
      found=true
      if nearest and root then
       local dist=(p-root.Position).Magnitude
       if not bestDist or dist<bestDist then best,bestDist=o,dist end
      else target(o,label,p,o,kind) end
     end
    end
   end
  end
  if best then target(best,label,posOf(best),best,kind) end
  return found
 end
 for _,row in ipairs(ui:GetChildren()) do
  local q=quests:FindFirstChild(row.Name)
  if q and q:GetAttribute("Completed")~=true and (not row:IsA("GuiObject") or row.Visible) then
   local tasks=q:FindFirstChild("Tasks")
   local remaining=false
   if tasks then
    for _,t in ipairs(tasks:GetChildren()) do
     if not done(t) then
      remaining=true
      if t:GetAttribute("Hidden")~=true and ready(t,tasks) then
       local low=t.Name:lower()
       local combat=low:match("^hunt ") or low:match("^defeat ") or low:match("^exterminate ") or low:match("^eliminate ") or low:match("^kill ")
       local craft=low:match("^brew ") or low:match("^craft ") or low:match("^forge ") or low:match("^cook ")
       local kind=combat and "combat" or craft and "craft" or t:GetAttribute("TaskType")=="Collect" and "collect" or "visit"
       local maximum=t:GetAttribute("TaskMax") or 1
       local progress=t:GetAttribute("TaskProgress") or 0
       local label=t.Name.." ("..progress.."/"..maximum..")"
       local found=false
       local p=valuePos(t:GetAttribute("TrackPosition"))
       if p then target(t,label,p,nil,kind) found=true end
       local object=t:GetAttribute("Object")
       if type(object)=="string" and object~="" and not craft then
        found=named(object,label,kind,combat~=nil) or found
       end
       if craft and low:match("^brew ") then found=named("Cauldron",label,kind,true) or found end
       local objects=q:FindFirstChild("Objects")
       if objects and not combat and not craft and (not object or object=="") then
        for _,o in ipairs(objects:GetChildren()) do found=named(o.Name,label,kind,false) or found end
       end
       local npc=t.Name:match("^Talk to (.+)") or t.Name:match("^Speak to (.+)") or t.Name:match("^Return to (.+)")
        or t.Name:match("^Deliver .- to (.+)") or t.Name:match("^Meet (.+)") or t.Name:match("^Find (.+)")
        or t.Name:match("^Defeat (.+)") or t.Name:match("^Hunt the (.+)") or t.Name:match("^Exterminate (.+)")
       if npc and not (combat and p) then
        npc=npc:gsub("%.$",""):gsub(" at .+$","")
        found=named(npc,label,kind,combat~=nil) or found
       end
       if found then state.resolved+=1 else
        state.unresolved+=1
        local tip=q:GetAttribute("Tip") or q:GetAttribute("QuestDescription")
        local prefix=combat and "Fight" or craft and "Craft" or "Find"
        table.insert(notes,prefix.." · "..label..(tip and tip~="" and (" · "..tip) or " · No known location"))
       end
      end
     end
    end
   end
   if not remaining then
    local npc=q:GetAttribute("ReturnNPC")
    if not npc or npc=="" then npc=q.Name end
    local label="Return to "..npc
    local p=valuePos(q:GetAttribute("ReturnPosition"))
    if p then target(q,label,p,nil,"return") state.resolved+=1
    elseif named(npc,label,"return",true) then state.resolved+=1
    else state.unresolved+=1 table.insert(notes,label.." · Location unavailable") end
   end
  end
 end
 return targets,notes
end
local function update()
 local targets,notes=resolve()
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if not root then
  clearVisuals() state.status="Waiting for character" return
 end
 local sorted={}
 for _,t in pairs(targets) do
  t.distance=(t.pos-root.Position).Magnitude
  table.insert(sorted,t)
 end
 table.sort(sorted,function(a,b) return a.distance<b.distance end)
 local keep={}
 -- Render at most four markers, only two text billboards. Combat uses areas, not enemy ESP.
 for i=1,math.min(4,#sorted) do
  local t=sorted[i]
  if t.kind~="combat" then
   keep[t.key]=true
   if not markers[t.key] then addMarker(t.key,t) end
   local m=markers[t.key]
   m.billboard.Enabled=i<=2 and t.model~=nil
   m.billboard.Adornee=adorneeOf(t.model)
   local label=t.label.." · "..math.floor(t.distance).." studs"
   if m.label.Text~=label then m.label.Text=label end
  end
 end
 for key,m in pairs(markers) do
  if not keep[key] then
   m.billboard:Destroy() if m.highlight then m.highlight:Destroy() end
   markers[key]=nil
  end
 end
 local nearest=sorted[1]
 if not nearest and #notes==0 then
  clearVisuals() state.status="No active quest objectives" return
 end
 if not gui then init() end
 state.status=state.resolved.." located · "..state.unresolved.." unlocated"
 local text
 if nearest then
  local v=workspace.CurrentCamera and workspace.CurrentCamera.CFrame:VectorToObjectSpace(nearest.pos-root.Position)
  local direction=v and (math.abs(v.X)>math.abs(v.Z) and (v.X>0 and "RIGHT" or "LEFT") or (v.Z<0 and "AHEAD" or "BEHIND")) or "TARGET"
  local prefix=nearest.kind=="combat" and "Combat area" or nearest.kind=="craft" and "Crafting station" or "Objective"
  text=prefix.." · "..direction.." · "..math.floor(nearest.distance).." studs\n"..nearest.label
 else text=notes[1] end
 if hud.Text~=text then hud.Text=text end
end
function state.setEnabled(on)
 if not state.alive then return end
 on=on==true
 if on==state.enabled then return end
 state.enabled=on
 if worker then task.cancel(worker) worker=nil end
 for _,c in ipairs(connections) do c:Disconnect() end
 table.clear(connections) table.clear(index)
 clearVisuals()
 if not on then state.status="Quest guide off" return end
 for _,o in ipairs(workspace:GetDescendants()) do indexObject(o) end
 table.insert(connections,workspace.DescendantAdded:Connect(indexObject))
 table.insert(connections,workspace.DescendantRemoving:Connect(removeObject))
 worker=task.spawn(function()
  while state.alive and state.enabled do
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
