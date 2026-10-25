local _ = game:GetService("ReplicatedStorage")
local _ = game:GetService("ServerStorage")
local _ = game:GetService("ServerScriptService")

return function(arg1, arg2) -- line: 7
    local States = arg1.States
    local Energy = States.Energy
    local MaxEnergy = States.MaxEnergy
    arg2 = arg2 or 0.04
    local v1 = math.min(Energy.Value + 0.04 * MaxEnergy.Value, MaxEnergy.Value)
    Energy.Value = math.floor(v1)
end
