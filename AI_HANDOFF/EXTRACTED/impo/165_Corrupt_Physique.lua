local function main(u1: userdata, _: userdata, arg1: any) -- line: 7
    local v1 = 0

    if table.find(arg1.AttackTypes, "P") then
        if u1:FindFirstChild(`{script.Name}`) then
            v1 = 0.025
        end
    end

    return v1
end

return main
