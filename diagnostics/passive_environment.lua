-- Clover passive environment diagnostics
-- Read-only: does not fire remotes, change character state, or move anything.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local HttpService=game:GetService("HttpService")
local LP=Players.LocalPlayer
local result={version="1.0",timestamp=os.time(),enemyTypes={},spellTools={},remoteNames={},character={}}
local entities=workspace:FindFirstChild("Entities")
local folder=entities and entities:FindFirstChild("Enemies")
local counts={}
local alive=0
if folder then
    for _,model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") then
            counts[model.Name]=(counts[model.Name] or 0)+1
            local h=model:FindFirstChildOfClass("Humanoid")
            if h and h.Health>0 then alive=alive+1 end
        end
    end
end
result.enemyTypes=counts
result.aliveEnemies=alive
local p=RS:FindFirstChild("ReplicatedPackage")
local r=p and p:FindFirstChild("Remotes")
if r then
    for _,item in ipairs(r:GetChildren()) do
        if item:IsA("RemoteEvent") or item:IsA("RemoteFunction") then
            table.insert(result.remoteNames,{name=item.Name,class=item.ClassName})
        end
    end
end
table.sort(result.remoteNames,function(a,b)return a.name<b.name end)
local seen={}
for _,parent in ipairs({LP:FindFirstChildOfClass("Backpack"),LP.Character}) do
    if parent then
        for _,tool in ipairs(parent:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("Type")=="Spell" and not seen[tool.Name] then
                table.insert(result.spellTools,tool.Name)
                seen[tool.Name]=true
            end
        end
    end
end
table.sort(result.spellTools)
local char=LP.Character
local hum=char and char:FindFirstChildOfClass("Humanoid")
if hum then result.character={health=hum.Health,maxHealth=hum.MaxHealth,walkSpeed=hum.WalkSpeed} end
local json=HttpService:JSONEncode(result)
print("[Clover passive diagnostics] "..json)
if type(writefile)=="function" then
    local ok,err=pcall(writefile,"clover_passive_diagnostics.json",json)
    if not ok then warn("[Clover passive diagnostics] file export: "..tostring(err)) end
end
print("[Clover passive diagnostics] Completed (read-only)")
