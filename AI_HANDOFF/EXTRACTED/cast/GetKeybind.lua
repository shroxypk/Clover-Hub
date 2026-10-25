local _ = require(game:GetService("ReplicatedFirst").Services)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _ = game:GetService("ContextActionService")
local _ = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PadBinds_m = require(ReplicatedStorage.Modules.PadBinds)
local LocalPlayer = Players.LocalPlayer

local function main(arg1) -- line: 13
    -- upvalues:
    --  [1] PadBinds_m (copy)
    --  [2] LocalPlayer (copy)
    --  [3] UserInputService (copy)

    if PadBinds_m.isDown(arg1) then
        return true
    end

    local Value = LocalPlayer.Binds[arg1].Value
    local v2 = Enum.KeyCode:FromName(Value) or Enum.UserInputType:FromName(Value)

    if v2 then
        if v2.EnumType == Enum.KeyCode then
            return UserInputService:IsKeyDown(v2)
        end

        return UserInputService:IsMouseButtonPressed(v2)
    else
        return
    end
end

return main
