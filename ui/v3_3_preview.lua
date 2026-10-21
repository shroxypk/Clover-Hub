-- Clover Hub v3.3: UI + diagnostics preview
-- Standalone read-only build. Does not send combat requests or move the character.
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local LP=Players.LocalPlayer
local env=(getgenv and getgenv()) or _G
if env.CloverUIPreview and env.CloverUIPreview.Cleanup then pcall(env.CloverUIPreview.Cleanup) end

local alive=true
local window, mobDropdown, spellDropdown
local lastMobNames={}
local config={Mob="Any",Spell="None",Remember=true}
local SETTINGS="clover_ui_preferences.json"
local function readPrefs()
    if type(isfile)~="function" or type(readfile)~="function" then return end
    if not isfile(SETTINGS) then return end
    local ok,p=pcall(function() return HttpService:JSONDecode(readfile(SETTINGS)) end)
    if ok and type(p)=="table" then
        if type(p.Mob)=="string" then config.Mob=p.Mob end
        if type(p.Spell)=="string" then config.Spell=p.Spell end
        if type(p.Remember)=="boolean" then config.Remember=p.Remember end
    end
end
readPrefs()
local function savePrefs()
    if not config.Remember or type(writefile)~="function" then return end
    pcall(function() writefile(SETTINGS,HttpService:JSONEncode(config)) end)
end
local function enemyNames()
    local names={"Any"}
    local seen={}
    local folder=workspace:FindFirstChild("Entities")
    folder=folder and folder:FindFirstChild("Enemies")
    if folder then
        for _,m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") and not seen[m.Name] then seen[m.Name]=true;table.insert(names,m.Name) end
        end
    end
    table.sort(names,function(a,b) if a=="Any" then return true end if b=="Any" then return false end return a<b end)
    return names
end
local function spellNames()
    local result={"None"}
    local found={}
    for _,parent in ipairs({LP:FindFirstChildOfClass("Backpack"),LP.Character}) do
        if parent then
            for _,tool in ipairs(parent:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("Type")=="Spell" and not found[tool.Name] then
                    found[tool.Name]=true;table.insert(result,tool.Name)
                end
            end
        end
    end
    table.sort(result,function(a,b) if a=="None" then return true end if b=="None" then return false end return a<b end)
    return result
end
local function chooseExisting(value,options,default)
    for _,name in ipairs(options) do if name==value then return value end end
    return default
end
local ok,lib=pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
if not ok or not lib then error("WindUI unavailable: "..tostring(lib)) end

window=lib:CreateWindow({
    Title="Clover Hub v3.3 UI Preview",Author="Clover",Icon="clover",
    Folder="CloverHubPreview",Size=UDim2.fromOffset(600,485),
    Theme="Dark",Transparent=true,SideBarWidth=185,
    ToggleKey=Enum.KeyCode.RightControl
})
local farm=window:Tab({Title="Farm UI",Icon="list-filter"})
local stats=window:Tab({Title="Diagnostics",Icon="activity"})
local settings=window:Tab({Title="Settings",Icon="settings"})
local mobs=enemyNames()
config.Mob=chooseExisting(config.Mob,mobs,"Any")
mobDropdown=farm:Dropdown({
    Title="Mob filter",Values=mobs,Value=config.Mob,Multi=false,
    Callback=function(v)
        if type(v)=="string" then config.Mob=v;savePrefs(); print("[Clover v3.3 UI] Mob:",v) end
    end
})
farm:Paragraph({Title="Dropdown fix",Desc="This list never refreshes automatically while you are clicking. Use Refresh Mob List only when necessary."})
farm:Button({Title="Refresh Mob List",Callback=function()
    local nextNames=enemyNames()
    config.Mob=chooseExisting(config.Mob,nextNames,"Any")
    if mobDropdown and mobDropdown.Refresh then mobDropdown:Refresh(nextNames) end
    lastMobNames=nextNames
    print("[Clover v3.3 UI] Mob names refreshed:",#nextNames-1)
    savePrefs()
end})
local spells=spellNames()
config.Spell=chooseExisting(config.Spell,spells,"None")
spellDropdown=farm:Dropdown({
    Title="Spell selection",Values=spells,Value=config.Spell,Multi=false,
    Callback=function(v)
        if type(v)=="string" then config.Spell=v;savePrefs();print("[Clover v3.3 UI] Spell:",v) end
    end
})
farm:Button({Title="Refresh Spells",Callback=function()
    local nextNames=spellNames()
    config.Spell=chooseExisting(config.Spell,nextNames,"None")
    if spellDropdown and spellDropdown.Refresh then spellDropdown:Refresh(nextNames) end
    savePrefs()
end})
local status=stats:Paragraph({Title="Current state",Desc="Click Refresh Status."})
stats:Button({Title="Refresh Status",Callback=function()
    local folder=workspace:FindFirstChild("Entities")
    folder=folder and folder:FindFirstChild("Enemies")
    local total,aliveCount=0,0
    if folder then
        for _,m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") then
                total=total+1
                local hum=m:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health>0 then aliveCount=aliveCount+1 end
            end
        end
    end
    local s=string.format("Enemy models: %d | Alive: %d\nMob preference: %s | Spell preference: %s",total,aliveCount,config.Mob,config.Spell)
    if status.SetDesc then status:SetDesc(s) end
    print("[Clover v3.3 UI] "..s)
end})
settings:Toggle({Title="Save UI preferences",Value=config.Remember,Callback=function(v)
    config.Remember=v;savePrefs()
end})
settings:Button({Title="Save Preferences Now",Callback=function()savePrefs();print("[Clover v3.3 UI] Preferences saved if file APIs are available")end})
local function cleanup()
    if not alive then return end
    alive=false
    savePrefs()
    if window then pcall(function() window:Destroy() end) end
    if env.CloverUIPreview and env.CloverUIPreview.Cleanup==cleanup then env.CloverUIPreview=nil end
end
settings:Button({Title="Unload UI Preview",Callback=cleanup})
env.CloverUIPreview={Cleanup=cleanup,Config=config}
print("[Clover v3.3 UI] Ready. RightControl toggles UI; no gameplay actions are performed.")
