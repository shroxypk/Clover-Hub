local _ = require(game:GetService("ReplicatedFirst").Services)
local StateManager_m = require(game:GetService("ReplicatedStorage").Modules.StateManager)

local function applyStatus(arg1, arg2) -- line: 7
    -- upvalues:
    --  [1] StateManager_m (copy)

    local v2 = arg2 or {}
    local v3 = StateManager_m.require(arg1)

    if v2.index == "Knocked" then
        local v4 = v2.Time or 0.85

        if not v3:HasState("KnockedCooldown") then
            v3:AddState("KnockedCooldown", 4)
            v3:AddState("Knocked", v4)

            return
        end
    elseif v2.index == "" then
    end
end

return applyStatus
