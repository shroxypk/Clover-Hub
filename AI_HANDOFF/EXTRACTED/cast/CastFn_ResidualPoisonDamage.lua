local _ = game:GetService("Players")
local _ = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local _ = game:GetService("ServerScriptService")
local _ = game:GetService("ReplicatedStorage")
local _ = ServerStorage.Assets
local _ = Random.new()
local TagPlayers_m = require(ServerStorage.GameModules.TagPlayers)

return function(
    _,
    _,
    _,
    arg4,
    _
) -- line: 13
    -- upvalues:
    --  [1] TagPlayers_m (copy)

    TagPlayers_m.CreateTag(_G.POISON_STATUS, arg4, 1)
end
