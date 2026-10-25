local _ = require(game:GetService("ReplicatedFirst").Services)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _ = game:GetService("CollectionService")
local StateManager_m = require(ReplicatedStorage.Modules.StateManager)
local t = { "Locked", "Knocked", "Detained", "Airborne" }

local function canForce(arg1, arg2) -- line: 10
    -- upvalues:
    --  [1] StateManager_m (copy)
    --  [2] t (copy)

    if not arg1:HasTag("NonHumanoid") then
        if arg1:HasTag("IgnoreForce") then
            return
        end

        local v2 = StateManager_m.require(arg1)
        local v3 = arg2 or t

        if v2:HasAnyState(v3) then
            return false
        end

        return true
    else
        return
    end
end

return canForce
