local _ = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function main(arg1) -- line: 4
    -- upvalues:
    --  [1] ReplicatedStorage (copy)

    ReplicatedStorage.Remotes.NPC:FireServer("Quest", arg1.Owner)
end

return main
