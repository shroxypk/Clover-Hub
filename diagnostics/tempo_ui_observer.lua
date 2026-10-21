-- Clover Tempo UI Observer v1.0
-- Read-only GUI inventory. Does NOT decompile scripts, hook functions,
-- intercept network traffic, inspect protected closures, or alter Tempo.
-- Run AFTER opening Tempo Hub, then interact with its menus and run again.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
assert(player, "LocalPlayer missing")
local guiRoots = {}
local pg = player:FindFirstChildOfClass("PlayerGui")
if pg then table.insert(guiRoots, pg) end
local okCore, core = pcall(function() return game:GetService("CoreGui") end)
if okCore and core then table.insert(guiRoots, core) end

local function safe(f)
    local ok, result = pcall(f)
    if ok then return result end
    return nil
end
local function vec2(v) return v and {x=v.X,y=v.Y} or nil end
local function color(c)
    return c and {r=math.floor(c.R*255+0.5),g=math.floor(c.G*255+0.5),b=math.floor(c.B*255+0.5)} or nil
end
local function dim(d)
    return d and {xs=d.X.Scale,xo=d.X.Offset,ys=d.Y.Scale,yo=d.Y.Offset} or nil
end
local function textShort(t)
    if type(t)~="string" then return nil end
    return t:sub(1,300)
end
local function describe(obj, rootName)
    local item = {
        class=obj.ClassName,
        name=obj.Name,
        root=rootName,
        path=safe(function() return obj:GetFullName() end),
        visible=safe(function() return obj.Visible end),
        absolutePosition=vec2(safe(function() return obj.AbsolutePosition end)),
        absoluteSize=vec2(safe(function() return obj.AbsoluteSize end)),
        position=dim(safe(function() return obj.Position end)),
        size=dim(safe(function() return obj.Size end)),
        backgroundColor=color(safe(function() return obj.BackgroundColor3 end)),
        backgroundTransparency=safe(function() return obj.BackgroundTransparency end),
        zIndex=safe(function() return obj.ZIndex end),
    }
    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        item.text=textShort(safe(function() return obj.Text end))
        item.textColor=color(safe(function() return obj.TextColor3 end))
        item.textSize=safe(function() return obj.TextSize end)
        item.font=safe(function() return tostring(obj.FontFace.Family) end)
    elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
        item.image=safe(function() return obj.Image end)
        item.imageColor=color(safe(function() return obj.ImageColor3 end))
    elseif obj:IsA("UICorner") then
        item.cornerRadius=tostring(safe(function() return obj.CornerRadius end))
    elseif obj:IsA("UIStroke") then
        item.thickness=safe(function() return obj.Thickness end)
        item.strokeColor=color(safe(function() return obj.Color end))
    elseif obj:IsA("UIListLayout") or obj:IsA("UIGridLayout") then
        item.layoutType=obj.ClassName
    end
    return item
end
local keywords={"tempo","hub","main","window"}
local function relevant(screen)
    local name=screen.Name:lower()
    for _,word in ipairs(keywords) do
        if name:find(word,1,true) then return true end
    end
    -- Other ScreenGuis may be obfuscated or generically named.
    return false
end
local all={}
local summaries={}
local limit=2500
local rootCount=0
for _,root in ipairs(guiRoots) do
    for _,screen in ipairs(root:GetChildren()) do
        if screen:IsA("ScreenGui") then
            rootCount=rootCount+1
            local items={}
            local descendants=screen:GetDescendants()
            local textHits=0
            for _,obj in ipairs(descendants) do
                if obj:IsA("GuiObject") or obj:IsA("UIComponent") or obj:IsA("UILayout") then
                    if #items < limit then
                        local entry=describe(obj,root.Name)
                        table.insert(items,entry)
                        local t=entry.text
                        if type(t)=="string" and t:lower():find("tempo",1,true) then textHits=textHits+1 end
                    end
                end
            end
            local rank=(relevant(screen) and 2 or 0)+(textHits>0 and 3 or 0)
            table.insert(summaries,{name=screen.Name,root=root.Name,descendants=#descendants,uiElements=#items,tempoTextHits=textHits,rank=rank})
            table.insert(all,{name=screen.Name,root=root.Name,rank=rank,objects=items})
        end
    end
end
table.sort(all,function(a,b) return a.rank>b.rank end)
table.sort(summaries,function(a,b) return a.rank>b.rank end)
local candidates={}
for _,entry in ipairs(all) do
    if entry.rank>0 then table.insert(candidates,entry) end
end
local report={
    version="1.0",
    timestamp=os.time(),
    playerGuiAvailable=pg~=nil,
    coreGuiAvailable=okCore and core~=nil,
    screenGuiCount=rootCount,
    screens=summaries,
    candidates=candidates,
    note="Only screens with Tempo in the ScreenGui name or text are exported in detail. Other screen names appear in summaries. All values are client-visible GUI properties."
}
local json=HttpService:JSONEncode(report)
print("[Clover Tempo observer] ScreenGuis: "..rootCount.." | candidate screens: "..#candidates.." | JSON bytes: "..#json)
for i,entry in ipairs(summaries) do
    if i<=30 then print(string.format("[Clover Tempo observer] %s / %s | objects=%d | score=%d",entry.root,entry.name,entry.uiElements,entry.rank)) end
end
if type(writefile)=="function" then
    local filename="clover_tempo_ui_observation.json"
    local ok,err=pcall(writefile,filename,json)
    if ok then
        print("[Clover Tempo observer] Saved "..filename)
    else
        warn("[Clover Tempo observer] File export failed: "..tostring(err))
    end
else
    warn("[Clover Tempo observer] writefile unsupported; JSON will be printed to console.")
    print("[Clover Tempo observer] JSON_BEGIN"..json.."JSON_END")
end
print("[Clover Tempo observer] Done. Open additional Tempo tabs and run again for an updated snapshot.")
