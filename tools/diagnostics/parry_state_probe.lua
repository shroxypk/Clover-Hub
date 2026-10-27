--[[
	Veyra / parry state probe (read-only)

	Dumps every attribute the game mirrors onto the local character and a short
	time series of the parry-related ones, so the timing model can be checked
	against the real state machine instead of guessed.

	It does not fire a remote, move the character, or change progress. Output is
	printed and, when the executor has a filesystem, written to
	Veyra_parry_state_probe.json in the workspace.
]]

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character
if not character then
	warn("Veyra probe: no character")
	return
end

local SAMPLES = 40
local INTERVAL = 0.1
local WATCH = { "Parry", "State", "Block", "Attack", "Facing", "Combat" }

local function serialise(value)
	local kind = typeof(value)
	if kind == "number" then
		return string.format("%.6f", value)
	elseif kind == "string" or kind == "boolean" then
		return tostring(value)
	end
	return kind
end

local function snapshot()
	local attributes = {}
	for name, value in pairs(character:GetAttributes()) do
		attributes[name] = serialise(value)
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return {
		t = os.clock(),
		server = game:GetService("Workspace"):GetServerTimeNow(),
		attributes = attributes,
		humanoidState = humanoid and humanoid:GetState().Name or nil,
		humanoidHealth = humanoid and humanoid.Health or nil,
	}
end

local report = {
	placeId = game.PlaceId,
	attributeNames = {},
	series = {},
	changed = {},
}

local first = snapshot()
for name in pairs(first.attributes) do
	table.insert(report.attributeNames, name)
end
table.sort(report.attributeNames)

local previous = first.attributes
local changed = {}
for _ = 1, SAMPLES do
	task.wait(INTERVAL)
	local sample = snapshot()
	local watched = {}
	local anyWatch = false
	for name, value in pairs(sample.attributes) do
		local interesting = false
		for _, key in ipairs(WATCH) do
			if string.find(name, key, 1, true) then
				interesting = true
				break
			end
		end
		if interesting then
			watched[name] = value
			anyWatch = true
		end
		if previous[name] ~= value then
			changed[name] = (changed[name] or 0) + 1
		end
	end
	if anyWatch then
		table.insert(report.series, { t = sample.t, server = sample.server, attributes = watched })
	end
	previous = sample.attributes
end
report.changed = changed

local names = table.concat(report.attributeNames, ", ")
print("Veyra probe: " .. tostring(#report.attributeNames) .. " character attributes")
print("Veyra probe: " .. names)

for _, name in ipairs(report.attributeNames) do
	if string.find(name, "Parry", 1, true) then
		print(string.format("Veyra probe: %s = %s", name, tostring(first.attributes[name])))
	end
end

local changedNames = {}
for name, count in pairs(changed) do
	table.insert(changedNames, string.format("%s x%d", name, count))
end
table.sort(changedNames)
print("Veyra probe: changed during " .. tostring(SAMPLES * INTERVAL) .. "s: " .. table.concat(changedNames, ", "))

local ok, encoded = pcall(function()
	return game:GetService("HttpService"):JSONEncode(report)
end)

if ok then
	local wrote = pcall(function()
		writefile("Veyra_parry_state_probe.json", encoded)
	end)
	print("Veyra probe: " .. (wrote and "written to Veyra_parry_state_probe.json" or "no filesystem, see printed output"))
	if not wrote and setclipboard then
		pcall(setclipboard, encoded)
	end
end

return report
