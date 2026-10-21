-- CLOVER HUB v3.2 - WindUI / diagnostic-informed build
-- Designed for the observed ReplicatedPackage.Remotes and Entities.Enemies layout.
-- Hotkey: RightControl. Run again to reload cleanly.

local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Lighting = game:GetService('Lighting')
local HttpService = game:GetService('HttpService')
local LP = Players.LocalPlayer
local EN = (getgenv and getgenv()) or _G

if EN.CloverHub and type(EN.CloverHub._Cleanup) == 'function' then
    pcall(EN.CloverHub._Cleanup)
    task.wait(0.15)
end

local running = true
local connections = {}
local modifiedEffects = {}
local savedLighting = nil
local savedSpeed = nil
local speedHumanoid = nil
local activeAttack = false
local lastSpell = 0
local lastMobRefresh = 0
local combatSamples = {}
local MAX_SAMPLES = 75
local logBuffer = {}
local MAX_LOGS = 120
local window
local mobDropdown
local spellDropdown
local statusParagraph
local eventsParagraph
local stats = {attempts=0, initializations=0, hitsObserved=0, missesObserved=0, deathsObserved=0, errors=0, targetChanges=0, outOfRange=0, invalidTargets=0, attackErrors=0, spellsSent=0}
local state = {target=nil, data=nil, lastFetch=0, lastAttack=0, lastTargetName='None', enemies={}, byName={}, lastScan=0, lastHealth=nil, lockedTarget=nil, lastMobNames=''}

local config = {
    FarmEnabled=false, MobFilter='Any', MaxDistance=3000,
    OffsetType='Behind', Distance=6, HeightOffset=0, FaceLock=true,
    AttackSpeed=0.45, AttackMode='Two-stage', InitDelay=0.04,
    AttackRange=12, TeleportToTarget=true, IgnoreCorrupted=false,
    SpeedEnabled=false, SpeedValue=32,
    SpellEnabled=false, SelectedSpell='None', SpellInterval=7,
    PerfEnabled=false, TrackDeaths=true, StickyTarget=true,
    PauseOnLowHealth=false, LowHealthPercent=25, AutoMobRefresh=true,
    SaveSettings=false
}

local function log(s)
    s = tostring(s)
    local line = os.date('%H:%M:%S') .. ' ' .. s
    logBuffer[#logBuffer+1] = line
    if #logBuffer > MAX_LOGS then table.remove(logBuffer,1) end
    print('[Clover v3.2] ' .. s)
end

local function protect(label, fn)
    local ok, err = pcall(fn)
    if not ok then stats.errors=stats.errors+1; log(label .. ': ' .. tostring(err)) end
    return ok
end

local function connect(signal, callback)
    local c=signal:Connect(callback)
    connections[#connections+1]=c
    return c
end

local remotes = RS:WaitForChild('ReplicatedPackage', 12)
remotes = remotes and remotes:WaitForChild('Remotes', 12)
assert(remotes, '[Clover] ReplicatedPackage.Remotes is missing')
local action = remotes:FindFirstChild('action')
local fetch = remotes:FindFirstChild('fetch')
local localEvents = remotes:FindFirstChild('_local')
local questEvent = remotes:FindFirstChild('updatelocalquests')

local function myParts()
    local char=LP.Character
    return char, char and char:FindFirstChild('HumanoidRootPart'), char and char:FindFirstChildOfClass('Humanoid')
end

local function enemiesFolder()
    local e=workspace:FindFirstChild('Entities')
    return e and e:FindFirstChild('Enemies')
end

local function isValidTarget(entry)
    return entry and entry.model and entry.model.Parent
        and entry.root and entry.root.Parent and entry.humanoid and entry.humanoid.Parent
        and entry.humanoid.Health > 0
end

local function scanEnemies(force)
    local now=os.clock()
    if not force and now-state.lastScan < 0.4 then return state.enemies end
    state.lastScan=now
    local _,root=myParts()
    local folder=enemiesFolder()
    state.enemies={}
    state.byName={}
    if not root or not folder then return state.enemies end
    for _,model in ipairs(folder:GetChildren()) do
        if model:IsA('Model') and not (config.IgnoreCorrupted and model:GetAttribute('corrupted')) then
            local hum=model:FindFirstChildOfClass('Humanoid')
            local enemyRoot=model:FindFirstChild('HumanoidRootPart') or model.PrimaryPart
            if hum and hum.Health>0 and enemyRoot then
                local distance=(enemyRoot.Position-root.Position).Magnitude
                if distance <= config.MaxDistance then
                    local record={model=model,humanoid=hum,root=enemyRoot,distance=distance}
                    state.enemies[#state.enemies+1]=record
                    state.byName[model.Name]=state.byName[model.Name] or {}
                    table.insert(state.byName[model.Name],record)
                end
            end
        end
    end
    table.sort(state.enemies,function(a,b) return a.distance<b.distance end)
    for _,bucket in pairs(state.byName) do
        table.sort(bucket,function(a,b) return a.distance<b.distance end)
    end
    return state.enemies
end

local function getTarget()
    local enemies=scanEnemies(false)
    if config.StickyTarget and isValidTarget(state.lockedTarget) then
        local sticky=state.lockedTarget
        if (config.MobFilter=='Any' or sticky.model.Name==config.MobFilter)
            and not (config.IgnoreCorrupted and sticky.model:GetAttribute('corrupted')) then
            local _,myRoot=myParts()
            if myRoot and (sticky.root.Position-myRoot.Position).Magnitude <= config.MaxDistance then
                state.target=sticky
                return sticky
            end
        end
    end
    local target
    if config.MobFilter=='Any' then target=enemies[1]
    else
        local group=state.byName[config.MobFilter]
        target=group and group[1]
    end
    if not isValidTarget(target) then target=nil end
    if target and (not state.target or state.target.model~=target.model) then
        stats.targetChanges=stats.targetChanges+1
        state.lastTargetName=target.model.Name
    end
    state.target=target
    state.lockedTarget=target
    return target
end

local function approachPosition(targetRoot)
    local p=targetRoot.Position
    local offset=Vector3.new(0,config.HeightOffset,0)
    if config.OffsetType=='Above' then
        offset=offset+Vector3.new(0,config.Distance,0)
    elseif config.OffsetType=='Below' then
        offset=offset-Vector3.new(0,config.Distance,0)
    elseif config.OffsetType=='Behind' then
        offset=offset-targetRoot.CFrame.LookVector*config.Distance
    elseif config.OffsetType=='Front' then
        offset=offset+targetRoot.CFrame.LookVector*config.Distance
    end
    return p+offset
end

local function trackAttack(target, initialHealth, distance, mode)
    task.delay(0.35,function()
        if not running then return end
        local current=target.humanoid and target.humanoid.Health
        local changed=type(current)=='number' and current < initialHealth
        local gone=not isValidTarget(target)
        local record={time=os.clock(),mob=target.model.Name,range=math.floor(distance*10)/10,
            protocol=mode,oldHP=initialHealth,newHP=current,damageObserved=changed,
            targetGone=gone}
        combatSamples[#combatSamples+1]=record
        if #combatSamples>MAX_SAMPLES then table.remove(combatSamples,1) end
        if changed then stats.hitsObserved=stats.hitsObserved+1
        elseif type(current)=='number' then stats.missesObserved=stats.missesObserved+1 end
    end)
end

local function doAttack(target, manual)
    if activeAttack then return end
    if not action or not action:IsA('RemoteEvent') then return end
    if not isValidTarget(target) then stats.invalidTargets=stats.invalidTargets+1; return end
    local _,root,hum=myParts()
    if not root or not hum or hum.Health<=0 then return end
    if config.PauseOnLowHealth and hum.MaxHealth>0
        and (hum.Health/hum.MaxHealth)*100<=config.LowHealthPercent then return end
    activeAttack=true
    local ok,err=pcall(function()
        if config.TeleportToTarget then
            local p=approachPosition(target.root)
            if config.FaceLock and (p-target.root.Position).Magnitude>0.1 then
                root.CFrame=CFrame.lookAt(p,target.root.Position)
            else root.CFrame=CFrame.new(p) end
        end
        local distance=(root.Position-target.root.Position).Magnitude
        if distance>config.AttackRange then
            stats.outOfRange=stats.outOfRange+1
            return
        end
        local initialHealth=target.humanoid.Health
        if config.AttackMode=='Two-stage' then
            action:FireServer('M1',{password='Spirit'})
            stats.initializations=stats.initializations+1
            task.wait(config.InitDelay)
            if not running or (not manual and not config.FarmEnabled)
                or not isValidTarget(target) then return end
        end
        action:FireServer('M1',{CastHit=target.root.CFrame})
        stats.attempts=stats.attempts+1
        trackAttack(target,initialHealth,distance,config.AttackMode)
    end)
    activeAttack=false
    if not ok then stats.attackErrors=stats.attackErrors+1; error(err) end
end

local function collectSpells()
    local options={'None'}
    local found={}
    local char=LP.Character
    local backpack=LP:FindFirstChildOfClass('Backpack')
    for _,parent in ipairs({backpack,char}) do
        if parent then
            for _,tool in ipairs(parent:GetChildren()) do
                if tool:IsA('Tool') and tool:GetAttribute('Type')=='Spell' and not found[tool.Name] then
                    found[tool.Name]=true
                    options[#options+1]=tool.Name
                end
            end
        end
    end
    table.sort(options,function(a,b)
        if a=='None' then return true end
        if b=='None' then return false end
        return a<b
    end)
    return options
end

local function findSpell(name)
    if name=='None' then return nil end
    for _,parent in ipairs({LP.Character, LP:FindFirstChildOfClass('Backpack')}) do
        if parent then
            local item=parent:FindFirstChild(name)
            if item and item:IsA('Tool') then return item end
        end
    end
end

local function castSpell(force)
    if (not force and not config.SpellEnabled) or not action then return end
    local tool=findSpell(config.SelectedSpell)
    if not tool then return end
    if not force and os.clock()-lastSpell < math.max(1,config.SpellInterval) then return end
    action:FireServer('Toolbar',{mousetype='M1',Tool=tool})
    lastSpell=os.clock()
    stats.spellsSent=stats.spellsSent+1
    log('Spell request sent: '..tool.Name..' (not verified)')
end

local function fetchData()
    if not fetch or not fetch:IsA('RemoteFunction') then return end
    local result=fetch:InvokeServer()
    if type(result)=='table' then
        state.data=result
        state.lastFetch=os.clock()
        log('Fetched server state; keys available: '..tostring(#(function()
            local keys={}; for k in pairs(result) do keys[#keys+1]=k end; return keys
        end)()))
    end
end

local function startPerf()
    if config.PerfEnabled then return end
    config.PerfEnabled=true
    savedLighting={FogStart=Lighting.FogStart,FogEnd=Lighting.FogEnd,GlobalShadows=Lighting.GlobalShadows}
    for _,effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA('PostEffect') then modifiedEffects[effect]=effect.Enabled; effect.Enabled=false end
    end
    local fx=workspace:FindFirstChild('Effects')
    if fx then
        for _,obj in ipairs(fx:GetDescendants()) do
            if obj:IsA('ParticleEmitter') or obj:IsA('Beam') or obj:IsA('Trail')
                or obj:IsA('Fire') or obj:IsA('Smoke') or obj:IsA('Sparkles')
                or obj:IsA('PointLight') or obj:IsA('SpotLight') then
                modifiedEffects[obj]=obj.Enabled
                obj.Enabled=false
            end
        end
    end
    Lighting.GlobalShadows=false
    Lighting.FogStart=1000000
    Lighting.FogEnd=1000000
    log('Performance mode enabled')
end

local function stopPerf()
    if not config.PerfEnabled then return end
    config.PerfEnabled=false
    for obj,prior in pairs(modifiedEffects) do
        if obj and obj.Parent then pcall(function() obj.Enabled=prior end) end
    end
    table.clear(modifiedEffects)
    if savedLighting then
        pcall(function()
            Lighting.FogStart=savedLighting.FogStart
            Lighting.FogEnd=savedLighting.FogEnd
            Lighting.GlobalShadows=savedLighting.GlobalShadows
        end)
    end
    savedLighting=nil
    log('Performance settings restored')
end

local function updateSpeed()
    local _,_,hum=myParts()
    if speedHumanoid and speedHumanoid~=hum and savedSpeed~=nil then
        pcall(function() if speedHumanoid.Parent then speedHumanoid.WalkSpeed=savedSpeed end end)
        savedSpeed=nil
        speedHumanoid=nil
    end
    if not hum then return end
    if config.SpeedEnabled then
        if savedSpeed==nil then savedSpeed=hum.WalkSpeed; speedHumanoid=hum end
        if hum.WalkSpeed~=config.SpeedValue then hum.WalkSpeed=config.SpeedValue end
    elseif savedSpeed~=nil then
        if speedHumanoid and speedHumanoid.Parent then speedHumanoid.WalkSpeed=savedSpeed end
        savedSpeed=nil
        speedHumanoid=nil
    end
end

local function cleanup()
    if not running then return end
    running=false
    config.FarmEnabled=false
    config.SpellEnabled=false
    config.SpeedEnabled=false
    protect('speed restore',updateSpeed)
    protect('performance restore',stopPerf)
    for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    state.target=nil
    state.lockedTarget=nil
    if window then pcall(function() window:Destroy() end) end
    if EN.CloverHub and EN.CloverHub._Cleanup==cleanup then EN.CloverHub=nil end
    log('Unloaded cleanly')
end

EN.CloverHub={Config=config,State=state,Stats=stats,ScanEnemies=scanEnemies,GetTarget=getTarget,
    Fetch=fetchData,Logs=logBuffer,_Cleanup=cleanup}
EN.CloverConfig=config

connect(LP.CharacterAdded,function()
    state.target=nil
    state.lockedTarget=nil
    -- updateSpeed will restore the old humanoid, if it still exists.
    state.lastScan=0
    log('Character respawned; target reset')
end)
if localEvents and localEvents:IsA('RemoteEvent') then
    connect(localEvents.OnClientEvent,function(kind)
        if config.TrackDeaths and kind=='Death' then stats.deathsObserved=stats.deathsObserved+1 end
    end)
end
if questEvent and questEvent:IsA('RemoteEvent') then
    connect(questEvent.OnClientEvent,function()
        log('Quest update received')
    end)
end

-- Background tasks stop on reload / cleanup.
task.spawn(function()
    while running do
        if config.FarmEnabled then
            protect('farm',function()
                local target=getTarget()
                if target then doAttack(target) end
            end)
        end
        task.wait(math.max(0.08,config.AttackSpeed))
    end
end)
task.spawn(function()
    while running do
        protect('movement',updateSpeed)
        task.wait(0.3)
    end
end)
task.spawn(function()
    while running do
        if config.SpellEnabled then protect('spell',castSpell) end
        task.wait(math.max(1,config.SpellInterval))
    end
end)

local ok,WindUI=pcall(function()
    return loadstring(game:HttpGet('https://github.com/Footagesus/WindUI/releases/latest/download/main.lua'))()
end)
if not ok or not WindUI then
    cleanup()
    error('[Clover] WindUI failed to load: '..tostring(WindUI))
end

window=WindUI:CreateWindow({
    Title='Clover Hub v3.2',Author='Clover',Icon='clover',Folder='CloverHub',
    Size=UDim2.fromOffset(600,485),Theme='Dark',Transparent=true,
    SideBarWidth=185,ToggleKey=Enum.KeyCode.RightControl
})

local farm=window:Tab({Title='Farm',Icon='sword'})
farm:Toggle({Title='Enable Farm',Value=false,Callback=function(v)
    config.FarmEnabled=v
    if not v then state.target=nil; state.lockedTarget=nil end
    log('Farm '..(v and 'enabled' or 'disabled'))
end})
mobDropdown=farm:Dropdown({Title='Mob Filter',Values={'Any'},Value='Any',Callback=function(v)
    if type(v)=='string' then config.MobFilter=v; state.lockedTarget=nil end
end})
farm:Toggle({Title='Auto Refresh Mob List',Value=true,Callback=function(v) config.AutoMobRefresh=v end})
farm:Button({Title='Refresh Mob Names',Callback=function()
    scanEnemies(true)
    local names={'Any'}
    for name in pairs(state.byName) do names[#names+1]=name end
    table.sort(names,function(a,b) if a=='Any' then return true end if b=='Any' then return false end return a<b end)
    if mobDropdown and mobDropdown.Refresh then mobDropdown:Refresh(names) end
    log('Found '..tostring(#state.enemies)..' eligible enemies and '..tostring(#names-1)..' mob types')
end})
farm:Dropdown({Title='Offset Position',Values={'Behind','Above','Below','Front','None'},Value='Behind',Callback=function(v) config.OffsetType=v end})
farm:Slider({Title='Offset Distance',Step=1,Value={Min=1,Max=30,Default=6},Callback=function(v) config.Distance=v end})
farm:Slider({Title='Height Offset',Step=1,Value={Min=-15,Max=20,Default=0},Callback=function(v) config.HeightOffset=v end})
farm:Slider({Title='Scan Distance',Step=100,Value={Min=100,Max=8000,Default=3000},Callback=function(v) config.MaxDistance=v end})
farm:Toggle({Title='Stay On Current Enemy Until Defeated',Value=true,Callback=function(v) config.StickyTarget=v; state.lockedTarget=nil end})
farm:Toggle({Title='Pause Farm On Low Health',Value=false,Callback=function(v) config.PauseOnLowHealth=v end})
farm:Slider({Title='Low Health Threshold (%)',Step=5,Value={Min=5,Max=80,Default=25},Callback=function(v) config.LowHealthPercent=v end})
farm:Toggle({Title='Face Target',Value=true,Callback=function(v) config.FaceLock=v end})
farm:Toggle({Title='Move to Target (CFrame)',Value=true,Callback=function(v) config.TeleportToTarget=v end})
farm:Toggle({Title='Ignore Corrupted Mobs',Value=false,Callback=function(v) config.IgnoreCorrupted=v; state.lastScan=0; state.lockedTarget=nil end})

local combat=window:Tab({Title='Combat',Icon='swords'})
combat:Dropdown({Title='M1 Protocol',Values={'Two-stage','CastHit only'},Value='Two-stage',Callback=function(v) config.AttackMode=v end})
combat:Slider({Title='Attack Interval (seconds)',Step=0.05,Value={Min=0.1,Max=1.5,Default=0.45},Callback=function(v) config.AttackSpeed=v end})
combat:Slider({Title='Maximum Attack Distance',Step=1,Value={Min=3,Max=30,Default=12},Callback=function(v) config.AttackRange=v end})
combat:Slider({Title='Init Delay (seconds)',Step=0.01,Value={Min=0,Max=0.2,Default=0.04},Callback=function(v) config.InitDelay=v end})
combat:Paragraph({Title='Attack validation',Desc='Sent requests are not confirmed hits. The diagnostic recorded unchanged target health at long range.'})
combat:Button({Title='One Attack (selected target)',Callback=function()
    protect('manual attack',function() local target=getTarget(); if target then doAttack(target,true) else log('No target found') end end)
end})

local spell=window:Tab({Title='Spells',Icon='wand-sparkles'})
spell:Toggle({Title='Enable Spell Requests',Value=false,Callback=function(v) config.SpellEnabled=v end})
spellDropdown=spell:Dropdown({Title='Selected Spell',Values=collectSpells(),Value='None',Callback=function(v) config.SelectedSpell=v end})
spell:Button({Title='Refresh Spells',Callback=function()
    local names=collectSpells()
    if spellDropdown and spellDropdown.Refresh then spellDropdown:Refresh(names) end
    log('Spell list refreshed ('..tostring(#names-1)..')')
end})
spell:Slider({Title='Spell Interval (seconds)',Step=1,Value={Min=2,Max=30,Default=7},Callback=function(v) config.SpellInterval=v end})
spell:Button({Title='Cast Selected Spell Once',Callback=function() protect('manual spell',function() castSpell(true) end) end})
spell:Paragraph({Title='Note',Desc='Spell request shape is inferred from earlier observations; server acceptance and cooldowns are not yet verified.'})

local movement=window:Tab({Title='Movement',Icon='footprints'})
movement:Toggle({Title='Override WalkSpeed',Value=false,Callback=function(v) config.SpeedEnabled=v; protect('speed',updateSpeed) end})
movement:Slider({Title='WalkSpeed',Step=1,Value={Min=16,Max=150,Default=32},Callback=function(v) config.SpeedValue=v end})
movement:Button({Title='Restore Original Speed',Callback=function()
    config.SpeedEnabled=false
    protect('restore speed',updateSpeed)
end})

local perf=window:Tab({Title='Performance',Icon='zap'})
perf:Toggle({Title='Reduce Visual Effects',Value=false,Callback=function(v)
    protect('performance',function() if v then startPerf() else stopPerf() end end)
end})
perf:Paragraph({Title='Restorable Settings',Desc='Saves effect states and selected lighting settings, then restores them on unload. Newly created effects are not tracked.'})

local diagnostics=window:Tab({Title='Diagnostics',Icon='activity'})
statusParagraph=diagnostics:Paragraph({Title='Session Status',Desc='Press Refresh Status to inspect current session.'})
eventsParagraph=diagnostics:Paragraph({Title='Recent Logs',Desc='No logs yet.'})
local function summary()
    scanEnemies(true)
    local target=state.target
    local name=isValidTarget(target) and target.model.Name or 'None'
    return 'Farm: '..tostring(config.FarmEnabled)..' | Enemies: '..#state.enemies..' | Target: '..name
        ..'\nM1 requests: '..stats.attempts..' | HP drops observed: '..stats.hitsObserved
        ..' | No HP drop: '..stats.missesObserved..' | Death events: '..stats.deathsObserved
        ..'\nOut of range: '..stats.outOfRange..' | Attack errors: '..stats.attackErrors
        ..' | Spells sent: '..stats.spellsSent
        ..'\nTarget changes: '..stats.targetChanges..' | Errors: '..stats.errors
end
diagnostics:Button({Title='Refresh Status',Callback=function()
    local s=summary(); log(s:gsub('\n',' | '))
    if statusParagraph and statusParagraph.SetDesc then statusParagraph:SetDesc(s) end
end})
diagnostics:Button({Title='Fetch State Once',Callback=function() task.spawn(function() protect('fetch',fetchData) end) end})
diagnostics:Button({Title='Show Recent Logs',Callback=function()
    local lines={}
    for i=math.max(1,#logBuffer-9),#logBuffer do lines[#lines+1]=logBuffer[i] end
    local s=table.concat(lines,'\n')
    if eventsParagraph and eventsParagraph.SetDesc then eventsParagraph:SetDesc(s) end
    print('[Clover v3.2] Recent logs:\n'..s)
end})
diagnostics:Button({Title='Export Session JSON',Callback=function()
    local payload={version='3.2',stats=stats,logs=logBuffer,combatSamples=combatSamples,settings={
        attackMode=config.AttackMode,attackInterval=config.AttackSpeed,attackRange=config.AttackRange,
        mobFilter=config.MobFilter,teleportToTarget=config.TeleportToTarget,
        selectedSpell=config.SelectedSpell,stickyTarget=config.StickyTarget,ignoreCorrupted=config.IgnoreCorrupted
    }}
    local json=HttpService:JSONEncode(payload)
    if type(writefile)=='function' then protect('export file',function() writefile('clover_v3_1_session.json',json) end) end
    if type(setclipboard)=='function' then protect('export clipboard',function() setclipboard(json) end) end
    log('Session JSON exported ('..#json..' bytes)')
end})
diagnostics:Button({Title='Unload Clover Hub',Callback=cleanup})

-- Populate drop-down without relying on automatic refresh on older WindUI versions.
protect('initial mob scan',function()
    scanEnemies(true)
    local names={'Any'}
    for name in pairs(state.byName) do names[#names+1]=name end
    table.sort(names,function(a,b) if a=='Any' then return true end if b=='Any' then return false end return a<b end)
    if mobDropdown and mobDropdown.Refresh then mobDropdown:Refresh(names) end
end)
-- Periodic dropdown update, independent of target scan interval.
task.spawn(function()
    while running do
        task.wait(4)
        if running and config.AutoMobRefresh and mobDropdown then
            protect('mob refresh',function()
                scanEnemies(true)
                local names={'Any'}
                for name in pairs(state.byName) do names[#names+1]=name end
                table.sort(names,function(a,b)
                    if a=='Any' then return true end
                    if b=='Any' then return false end
                    return a<b
                end)
                local signature=table.concat(names,'|')
                if signature~=state.lastMobNames and mobDropdown.Refresh then
                    mobDropdown:Refresh(names)
                    state.lastMobNames=signature
                end
            end)
        end
    end
end)
log('Clover Hub v3.2 ready. RightControl toggles the UI.')