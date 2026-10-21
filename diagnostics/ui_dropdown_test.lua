-- Clover UI interaction smoke test
-- No combat, remote calls, or game modifications.
local ok, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
assert(ok and WindUI, "WindUI unavailable: " .. tostring(WindUI))
local window = WindUI:CreateWindow({
    Title="Clover UI Diagnostics",
    Author="Clover",
    Icon="settings",
    Size=UDim2.fromOffset(520,400),
    Theme="Dark",
    ToggleKey=Enum.KeyCode.RightControl
})
local tab = window:Tab({Title="Dropdown Test",Icon="list"})
local menu = tab:Dropdown({
    Title="Single-select close test",
    Values={"Any","Pumpkin","Ogre","Skeleton"},
    Value="Any",
    Multi=false,
    AllowNone=false,
    SearchBarEnabled=true,
    Callback=function(v) print("[Clover UI test] Selected:",v) end
})
tab:Button({Title="Refresh list manually",Callback=function()
    menu:Refresh({"Any","Pumpkin","Ogre","Skeleton","Stone Guardian"})
    print("[Clover UI test] Refreshed")
end})
tab:Paragraph({Title="How to test",Desc="Open menu; select a value; click again; click outside. Check whether the menu opens/closes normally."})
print("[Clover UI test] Ready")
