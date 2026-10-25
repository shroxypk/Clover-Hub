local Players = game:GetService("Players")
local Modules = game:GetService("ReplicatedStorage").Modules
local StateManager_m = require(Modules.StateManager)
local GrimoireRarity_m = require(Modules.GrimoireRarity)

return function(arg1, arg2) -- line: 11
    -- upvalues:
    --  [1] Players (copy)
    --  [2] StateManager_m (copy)
    --  [3] GrimoireRarity_m (copy)

    local playerFromCharacter = Players:GetPlayerFromCharacter(arg1)
    local t = {}
    local v1 = StateManager_m.require(arg2)

    if playerFromCharacter then
        local v2 = GrimoireRarity_m:GetPlayerVariant(arg1)

        if v2 then
            t.Color = v2.Primary
        end
    end

    v1:AddState("StatusFire", 4, nil, t)
end
