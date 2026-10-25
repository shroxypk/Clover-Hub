return function(arg1, arg2, arg3) -- line: 1
    local Part = Instance.new("Part")
    Part.CFrame = arg1
    Part.Size = arg2
    Part.Transparency = 0.98
    Part.Color = Color3.fromRGB(85, 255, 127)
    Part.Material = Enum.Material.Neon
    Part.Anchored = true
    Part.CanCollide = false
    Part.Parent = arg3
    _G.Debris(Part, 1.5)

    return Part
end
