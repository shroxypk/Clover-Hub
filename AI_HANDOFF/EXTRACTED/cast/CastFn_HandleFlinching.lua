local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _ = game:GetService("ServerStorage")
local Hit = ReplicatedStorage.Animations.Hit
local t = { ["Blackfyre Boar"] = Hit.Boar:GetChildren() }
local t_1 = { Hit.FlinchLeft, Hit.FlinchRight }

local function main(arg1, arg2) -- line: 15
    -- upvalues:
    --  [1] t (copy)
    --  [2] t_1 (copy)

    if arg1:HasTag("Inanimate") then
        return
    end

    local v1 = t[arg1.Name]
    local v2 = if not v1 then t_1[math.random(#t_1)] else v1[math.random(#v1)]
    local v3 = arg2.Animator:LoadAnimation(v2)
    v3.Priority = Enum.AnimationPriority.Action
    v3:Play(0)
    v3:AdjustSpeed(v2:GetAttribute("Speed") or 1)
end

return main
