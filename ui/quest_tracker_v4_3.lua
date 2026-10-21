-- Clover v4.3: quest tracker and NPC directory (read-only)
-- Standalone UI; no remote calls, teleportation, or prompt activation.
local Players=game:GetService("Players")
local P=Players.LocalPlayer
local E=(getgenv and getgenv()) or _G
if E.CloverQuestTracker and E.CloverQuestTracker.Cleanup then pcall(E.CloverQuestTracker.Cleanup) end
local alive=true
local win
local selectedQuest="None"
local selectedNPC="None"
local function entities() return workspace:FindFirstChild("Entities") end
local function records()
    local e=entities()
    local char=e and e:FindFirstChild(P.Name)
    local st=char and char:FindFirstChild("Status")
    local repl=st and st:FindFirstChild("Replicated")
    local folder=repl and repl:FindFirstChild("Quests")
    local main=repl and repl:FindFirstChild("MainQuestData")
    local out={}
    if folder then
        for _,q in ipairs(folder:GetChildren()) do
            if q:IsA("Folder") then
                local c=q:FindFirstChild("completed")
                local progress=q:FindFirstChild("progress")
                local stage=q:FindFirstChild("Stage")
                local typ=q:FindFirstChild("quest_type")
                table.insert(out,{name=q.Name,completed=c and c:IsA("BoolValue") and c.Value or false,
                    knownCompleted=c and c:IsA("BoolValue") or false,
                    progress=progress and tostring(progress.Value) or nil,
                    stage=stage and tostring(stage.Value) or nil,
                    questType=typ and tostring(typ.Value) or nil})
            end
        end
    end
    table.sort(out,function(a,b)return a.name<b.name end)
    return out,main and tostring(main.Value) or "Unknown"
end
local function npcs()
    local e=entities()
    local dir=e and e:FindFirstChild("Interactions")
    local out={}
    if dir then
        for _,category in ipairs(dir:GetChildren()) do
            if category.Name=="Quests" or category.Name=="Special Interactions" or category.Name=="SpecialEvents" then
                for _,m in ipairs(category:GetChildren()) do
                    if m:IsA("Model") then
                        local prompt=m:FindFirstChildWhichIsA("ProximityPrompt",true)
                        local part=m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                        if prompt and part then
                            table.insert(out,{model=m,prompt=prompt,part=part,category=category.Name,
                                target=prompt:GetAttribute("Target") or "Unknown"})
                        end
                    end
                end
            end
        end
    end
    table.sort(out,function(a,b)return a.model.Name<b.model.Name end)
    return out
end
local function uniqueQuestChoices()
    local rs=records()
    local opts={}
    for _,q in ipairs(rs) do table.insert(opts,q.name) end
    if #opts==0 then opts={"No recorded quests"} end
    return opts
end
local function uniqueNPCChoices()
    local opts={}
    local seen={}
    for _,entry in ipairs(npcs()) do
        local label=entry.model.Name.." ["..entry.category.."] -> "..tostring(entry.target)
        if not seen[label] then table.insert(opts,label); seen[label]=true end
    end
    if #opts==0 then opts={"No NPCs found"} end
    return opts
end
local ok,UI=pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
assert(ok and UI,"WindUI not available: "..tostring(UI))
win=UI:CreateWindow({Title="Clover Quest Tracker v4.3",Author="Clover",Icon="book-open",
    Folder="CloverQuestTracker",Size=UDim2.fromOffset(610,470),
    Theme="Dark",Transparent=true,SideBarWidth=180,
    ToggleKey=Enum.KeyCode.RightControl})
local tab=win:Tab({Title="Quests",Icon="scroll-text"})
local npctab=win:Tab({Title="NPC Directory",Icon="map-pin"})
local status=tab:Paragraph({Title="Quest summary",Desc="Press Refresh Quest Summary"})
local detail=tab:Paragraph({Title="Quest details",Desc="Choose a recorded quest"})
local opts=uniqueQuestChoices()
selectedQuest=opts[1]
local questDropdown=tab:Dropdown({Title="Recorded quest",Values=opts,Value=selectedQuest,Multi=false,
    Callback=function(v)if type(v)=="string" then selectedQuest=v end end})
tab:Button({Title="Inspect Selected Quest",Callback=function()
    local rs=records()
    local desc="No matching record"
    for _,q in ipairs(rs) do
        if q.name==selectedQuest then
            local state=q.knownCompleted and (q.completed and "Completed" or "Not completed") or "Not specified"
            desc="Name: "..q.name.."\nCompletion: "..state.."\nType: "..tostring(q.questType or "Unknown")
                .."\nStage: "..tostring(q.stage or "Unknown").."\nProgress: "..tostring(q.progress or "Unknown")
            break
        end
    end
    if detail.SetDesc then detail:SetDesc(desc) end
    print("[Clover Quests] "..desc:gsub("\n"," | "))
end})
tab:Button({Title="Refresh Quest Summary",Callback=function()
    local r,main=records()
    local completed,unknown=0,0
    for _,q in ipairs(r) do
        if q.knownCompleted and q.completed then completed=completed+1
        elseif not q.knownCompleted then unknown=unknown+1 end
    end
    local s="Main quest stage: "..main.."\nRecorded quests: "..#r..
        "\nCompleted: "..completed.." | Unspecified: "..unknown
    if status.SetDesc then status:SetDesc(s) end
    print("[Clover Quests] "..s:gsub("\n"," | "))
end})
tab:Button({Title="Refresh Quest List",Callback=function()
    local choices=uniqueQuestChoices()
    selectedQuest=choices[1]
    if questDropdown and questDropdown.Refresh then questDropdown:Refresh(choices) end
    print("[Clover Quests] List refreshed")
end})
local npcDetail=npctab:Paragraph({Title="NPC details",Desc="Select an NPC and inspect it."})
local npcOpts=uniqueNPCChoices()
selectedNPC=npcOpts[1]
local npcDropdown=npctab:Dropdown({Title="NPC",Values=npcOpts,Value=selectedNPC,Multi=false,
    Callback=function(v)if type(v)=="string" then selectedNPC=v end end})
npctab:Button({Title="Inspect NPC",Callback=function()
    for _,entry in ipairs(npcs()) do
        local label=entry.model.Name.." ["..entry.category.."] -> "..tostring(entry.target)
        if label==selectedNPC then
            local pos=entry.part.Position
            local root=P.Character and P.Character:FindFirstChild("HumanoidRootPart")
            local dist=root and math.floor((root.Position-pos).Magnitude) or -1
            local desc=entry.model.Name.."\nCategory: "..entry.category..
                "\nInteraction: "..tostring(entry.target)..
                "\nPosition: "..math.floor(pos.X)..", "..math.floor(pos.Y)..", "..math.floor(pos.Z)..
                "\nDistance: "..(dist>=0 and tostring(dist).." studs" or "Unknown")
            if npcDetail.SetDesc then npcDetail:SetDesc(desc) end
            print("[Clover NPC] "..desc:gsub("\n"," | "))
            return
        end
    end
    if npcDetail.SetDesc then npcDetail:SetDesc("NPC not currently available") end
end})
npctab:Button({Title="Refresh NPC List",Callback=function()
    local choices=uniqueNPCChoices()
    selectedNPC=choices[1]
    if npcDropdown and npcDropdown.Refresh then npcDropdown:Refresh(choices) end
    print("[Clover NPC] List refreshed")
end})
local settings=win:Tab({Title="Settings",Icon="settings"})
local function cleanup()
    if not alive then return end
    alive=false
    if win then pcall(function()win:Destroy()end)end
    if E.CloverQuestTracker and E.CloverQuestTracker.Cleanup==cleanup then E.CloverQuestTracker=nil end
end
settings:Button({Title="Unload Tracker",Callback=cleanup})
E.CloverQuestTracker={Cleanup=cleanup,Records=records,NPCs=npcs}
print("[Clover Quest Tracker v4.3] Ready. Read-only quest and NPC browser.")
