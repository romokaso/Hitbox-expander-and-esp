--[[
	Unit tests for the pure helper block in HitboxEsp.luau.

	The helpers live between the "-- >>> PURE BEGIN" and "-- <<< PURE END"
	markers and must not touch Roblox APIs. Any plain Lua 5.4 interpreter can
	run these tests; CI also uses them, so no Roblox install is required.

	Run from the repository root:
	    lua5.4 tests/run.lua
	    lua tests/run.lua

	The script exits with code 1 when any test fails.
]]

local SCRIPT_PATH = "HitboxEsp.luau"
local PURE_START = "-- >>> PURE BEGIN"
local PURE_END = "-- <<< PURE END"

local EXPORTS = {
	"MIN_HITBOX_SIZE",
	"MAX_HITBOX_SIZE",
	"DEFAULT_HITBOX_SIZE",
	"SCHEMA_VERSION",
	"ACTIONS",
	"isFiniteNumber",
	"clampNumber",
	"roundToTenth",
	"formatSize",
	"parseSizeInput",
	"defaultKeybinds",
	"sanitizeKeybindName",
	"sanitizeSettings",
	"dedupeKeybinds",
	"applyKeybindToTable",
	"clampWindowPosition",
	"formatDistance",
	"formatHealth",
	"buildEspLabel",
}

--------------------------------------------------------------------------------
-- Tiny test harness
--------------------------------------------------------------------------------

local passed = 0
local failed = 0

local function describe(value)
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local function deepEqual(a, b)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in pairs(a) do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function check(condition, message)
	if not condition then
		error(message, 2)
	end
end

local function expectEqual(actual, expected, label)
	if not deepEqual(actual, expected) then
		error(string.format("%s: expected %s, got %s", label or "value", describe(expected), describe(actual)), 2)
	end
end

local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
	else
		failed = failed + 1
		io.stderr:write(string.format("FAIL  %s\n      %s\n", name, tostring(err)))
	end
end

--------------------------------------------------------------------------------
-- Load the pure block
--------------------------------------------------------------------------------

local function readFile(path)
	local handle, openError = io.open(path, "rb")
	if not handle then
		return nil, openError
	end
	local contents = handle:read("*a")
	handle:close()
	return contents
end

local function extractPure(source)
	local startPosition = source:find(PURE_START, 1, true)
	local endPosition = source:find(PURE_END, 1, true)
	if not startPosition or not endPosition or endPosition <= startPosition then
		return nil, "pure block markers not found"
	end
	return source:sub(startPosition + #PURE_START, endPosition - 1)
end

local source = rawget(_G, "HITBOX_SOURCE")
if type(source) ~= "string" then
	local readOk, contents = readFile(SCRIPT_PATH)
	if not readOk then
		readOk, contents = readFile("tests/../" .. SCRIPT_PATH)
	end
	if not readOk then
		error("Could not read " .. SCRIPT_PATH .. ": " .. tostring(contents))
	end
	source = contents
end

local pureSource, extractError = extractPure(source)
assert(pureSource, extractError)

local returnFields = {}
for _, name in ipairs(EXPORTS) do
	table.insert(returnFields, name .. " = " .. name)
end
local chunkSource = pureSource .. "\nreturn {\n" .. table.concat(returnFields, ",\n") .. "\n}\n"

local chunk, compileError = load(chunkSource, "pure-block", "t", setmetatable({}, { __index = _G }))
assert(chunk, "Could not compile the pure block: " .. tostring(compileError))
local helpers = chunk()

for _, name in ipairs(EXPORTS) do
	if helpers[name] == nil then
		error("Pure block did not export " .. name)
	end
end

--------------------------------------------------------------------------------
-- Purity guard
--------------------------------------------------------------------------------

test("pure block stays free of Roblox APIs", function()
	local forbidden = {
		"game:GetService",
		"Instance.new",
		"Enum.",
		"workspace",
		"task%.",
		"typeof%(",
		"wait%(",
	}
	for _, pattern in ipairs(forbidden) do
		local found = pureSource:find(pattern)
		check(found == nil, "pure block must not reference " .. pattern)
	end
end)

--------------------------------------------------------------------------------
-- isFiniteNumber / clampNumber / roundToTenth
--------------------------------------------------------------------------------

test("isFiniteNumber accepts finite numbers only", function()
	check(helpers.isFiniteNumber(0) == true, "0")
	check(helpers.isFiniteNumber(-12.5) == true, "-12.5")
	check(helpers.isFiniteNumber(math.huge) == false, "huge")
	check(helpers.isFiniteNumber(-math.huge) == false, "-huge")
	check(helpers.isFiniteNumber(0 / 0) == false, "nan")
	check(helpers.isFiniteNumber("10") == false, "string")
	check(helpers.isFiniteNumber(nil) == false, "nil")
end)

test("clampNumber clamps both ends", function()
	expectEqual(helpers.clampNumber(5, 1, 50), 5)
	expectEqual(helpers.clampNumber(-5, 1, 50), 1)
	expectEqual(helpers.clampNumber(500, 1, 50), 50)
end)

test("roundToTenth rounds half up", function()
	expectEqual(helpers.roundToTenth(10.44), 10.4)
	expectEqual(helpers.roundToTenth(10.45), 10.5)
	expectEqual(helpers.roundToTenth(-1.24), -1.2)
end)

--------------------------------------------------------------------------------
-- parseSizeInput
--------------------------------------------------------------------------------

test("formatSize never prints a trailing .0", function()
	expectEqual(helpers.formatSize(6), "6")
	expectEqual(helpers.formatSize(6.0), "6")
	expectEqual(helpers.formatSize(6.5), "6.5")
	expectEqual(helpers.formatSize(50), "50")
	expectEqual(helpers.formatSize(math.huge), "?")
end)

test("parseSizeInput accepts plain numbers", function()
	local value, note = helpers.parseSizeInput("10")
	expectEqual(value, 10)
	expectEqual(note, nil)
end)

test("parseSizeInput trims whitespace and keeps decimals", function()
	local value, note = helpers.parseSizeInput("  42.5  ")
	expectEqual(value, 42.5)
	expectEqual(note, nil)
end)

test("parseSizeInput rounds to one decimal", function()
	local value = helpers.parseSizeInput("10.44")
	expectEqual(value, 10.4)
end)

test("parseSizeInput rejects garbage", function()
	local value, note = helpers.parseSizeInput("abc")
	expectEqual(value, nil)
	expectEqual(note, "Not a valid number")
end)

test("parseSizeInput rejects empty and whitespace input", function()
	expectEqual(select(1, helpers.parseSizeInput("")), nil)
	expectEqual(select(1, helpers.parseSizeInput("   ")), nil)
	expectEqual(select(1, helpers.parseSizeInput(nil)), nil)
	expectEqual(select(1, helpers.parseSizeInput(10)), nil)
end)

test("parseSizeInput clamps low values", function()
	local value, note = helpers.parseSizeInput("-5")
	expectEqual(value, 1)
	expectEqual(note, "Clamped to 1")
end)

test("parseSizeInput clamps high values", function()
	local value, note = helpers.parseSizeInput("1000")
	expectEqual(value, 50)
	expectEqual(note, "Clamped to 50")
end)

test("parseSizeInput rejects infinity", function()
	local value = helpers.parseSizeInput("1e400")
	expectEqual(value, nil)
	expectEqual(select(1, helpers.parseSizeInput("-1e400")), nil)
end)

test("parseSizeInput clamp is idempotent", function()
	local first = helpers.parseSizeInput("1000")
	local second, secondNote = helpers.parseSizeInput(tostring(first))
	expectEqual(second, 50)
	expectEqual(secondNote, nil)
end)

--------------------------------------------------------------------------------
-- sanitizeSettings
--------------------------------------------------------------------------------

local function defaults()
	return helpers.sanitizeSettings(nil)
end

test("sanitizeSettings returns defaults for nil and non-tables", function()
	local expected = defaults()
	expectEqual(helpers.sanitizeSettings(nil), expected)
	expectEqual(helpers.sanitizeSettings(123), expected)
	expectEqual(helpers.sanitizeSettings(true), expected)
	expectEqual(helpers.sanitizeSettings("hitboxSize"), expected)
end)

test("sanitizeSettings defaults are sane", function()
	local settings = defaults()
	expectEqual(settings.schemaVersion, helpers.SCHEMA_VERSION)
	expectEqual(settings.hitboxSize, helpers.DEFAULT_HITBOX_SIZE)
	expectEqual(settings.theme, "dark")
	expectEqual(settings.hideParts, false)
	expectEqual(settings.restoreEnabled, false)
	expectEqual(settings.hitboxEnabled, false)
	expectEqual(settings.espEnabled, false)
	expectEqual(settings.windowPosition, nil)
	for _, action in ipairs(helpers.ACTIONS) do
		expectEqual(settings.keybinds[action], "None", action)
	end
end)

test("sanitizeSettings clamps hitboxSize", function()
	expectEqual(helpers.sanitizeSettings({ hitboxSize = 1e9 }).hitboxSize, helpers.MAX_HITBOX_SIZE)
	expectEqual(helpers.sanitizeSettings({ hitboxSize = -3 }).hitboxSize, helpers.MIN_HITBOX_SIZE)
	expectEqual(helpers.sanitizeSettings({ hitboxSize = math.huge }).hitboxSize, helpers.DEFAULT_HITBOX_SIZE)
	expectEqual(helpers.sanitizeSettings({ hitboxSize = 12.34 }).hitboxSize, 12.3)
end)

test("sanitizeSettings ignores wrong types", function()
	expectEqual(helpers.sanitizeSettings({ hitboxSize = "10" }).hitboxSize, helpers.DEFAULT_HITBOX_SIZE)
	expectEqual(helpers.sanitizeSettings({ theme = "neon" }).theme, "dark")
	expectEqual(helpers.sanitizeSettings({ theme = "light" }).theme, "light")
	expectEqual(helpers.sanitizeSettings({ hideParts = "yes" }).hideParts, false)
	expectEqual(helpers.sanitizeSettings({ espEnabled = 1 }).espEnabled, false)
	expectEqual(helpers.sanitizeSettings({ keybinds = "nope" }).keybinds.hitbox, "None")
end)

test("sanitizeSettings keeps valid booleans", function()
	expectEqual(helpers.sanitizeSettings({ hideParts = true }).hideParts, true)
	expectEqual(helpers.sanitizeSettings({ restoreEnabled = true }).restoreEnabled, true)
end)

test("sanitizeSettings validates keybind names", function()
	local settings = helpers.sanitizeSettings({
		keybinds = {
			hitbox = "LeftShift",
			esp = "Escape",
			gui = "bad name",
			minimize = 42,
			apply = "Z",
			unknownAction = "Q",
		},
	})
	expectEqual(settings.keybinds.hitbox, "LeftShift")
	expectEqual(settings.keybinds.esp, "None")
	expectEqual(settings.keybinds.gui, "None")
	expectEqual(settings.keybinds.minimize, "None")
	expectEqual(settings.keybinds.apply, "Z")
	expectEqual(settings.keybinds.unknownAction, nil)
end)

test("sanitizeSettings drops duplicate keybinds deterministically", function()
	local settings = helpers.sanitizeSettings({
		keybinds = { hitbox = "Q", esp = "Q", gui = "Q" },
	})
	expectEqual(settings.keybinds.hitbox, "Q")
	expectEqual(settings.keybinds.esp, "None")
	expectEqual(settings.keybinds.gui, "None")
end)

test("sanitizeSettings validates windowPosition", function()
	expectEqual(
		helpers.sanitizeSettings({ windowPosition = { x = 10.7, y = -20 } }).windowPosition,
		{ x = 10, y = -20 }
	)
	expectEqual(helpers.sanitizeSettings({ windowPosition = { x = "10", y = 5 } }).windowPosition, nil)
	expectEqual(helpers.sanitizeSettings({ windowPosition = { x = math.huge, y = 5 } }).windowPosition, nil)
	expectEqual(helpers.sanitizeSettings({ windowPosition = "10,5" }).windowPosition, nil)
end)

test("sanitizeSettings output is stable when re-sanitized", function()
	local once = helpers.sanitizeSettings({ hitboxSize = 33.33, theme = "light", keybinds = { hitbox = "Q" } })
	local twice = helpers.sanitizeSettings(once)
	expectEqual(twice, once)
end)

--------------------------------------------------------------------------------
-- Keybind helpers
--------------------------------------------------------------------------------

test("applyKeybindToTable clears the key from other actions", function()
	local keybinds = helpers.defaultKeybinds()
	helpers.applyKeybindToTable(keybinds, "hitbox", "Q")
	helpers.applyKeybindToTable(keybinds, "esp", "Q")
	expectEqual(keybinds.esp, "Q")
	expectEqual(keybinds.hitbox, "None")
end)

test("assigning None leaves other binds alone", function()
	local keybinds = helpers.defaultKeybinds()
	helpers.applyKeybindToTable(keybinds, "hitbox", "Q")
	helpers.applyKeybindToTable(keybinds, "esp", "E")
	helpers.applyKeybindToTable(keybinds, "esp", "None")
	expectEqual(keybinds.hitbox, "Q")
	expectEqual(keybinds.esp, "None")
end)

--------------------------------------------------------------------------------
-- clampWindowPosition
--------------------------------------------------------------------------------

test("clampWindowPosition keeps a normal position", function()
	local x, y = helpers.clampWindowPosition(200, 150, 260, 196, 1280, 720)
	expectEqual(x, 200)
	expectEqual(y, 150)
end)

test("clampWindowPosition keeps 120px of the window reachable on the left", function()
	local x = helpers.clampWindowPosition(-10000, 100, 260, 196, 1280, 720)
	expectEqual(x, -140)
end)

test("clampWindowPosition keeps 120px on the right", function()
	local x = helpers.clampWindowPosition(10000, 100, 260, 196, 1280, 720)
	expectEqual(x, 1160)
end)

test("clampWindowPosition never hides the title bar above the screen", function()
	local _, y = helpers.clampWindowPosition(100, -500, 260, 196, 1280, 720)
	expectEqual(y, 0)
end)

test("clampWindowPosition keeps the title bar on screen at the bottom", function()
	local _, y = helpers.clampWindowPosition(100, 10000, 260, 196, 1280, 720)
	expectEqual(y, 600)
end)

test("clampWindowPosition survives a tiny viewport", function()
	local x, y = helpers.clampWindowPosition(50, 50, 260, 196, 100, 80)
	expectEqual(x, 0)
	expectEqual(y, 0)
end)

--------------------------------------------------------------------------------
-- ESP text formatting
--------------------------------------------------------------------------------

test("formatDistance formats studs", function()
	expectEqual(helpers.formatDistance(12.9), "12 studs")
	expectEqual(helpers.formatDistance(0), "0 studs")
	expectEqual(helpers.formatDistance(nil), "? studs")
	expectEqual(helpers.formatDistance(math.huge), "? studs")
end)

test("formatHealth handles valid and invalid values", function()
	expectEqual(helpers.formatHealth(100, 100), "100/100 HP")
	expectEqual(helpers.formatHealth(55.7, 200), "55/200 HP")
	expectEqual(helpers.formatHealth(10, 0), "")
	expectEqual(helpers.formatHealth(nil, 100), "")
	expectEqual(helpers.formatHealth(10, nil), "")
end)

test("buildEspLabel composes name, distance and health", function()
	expectEqual(helpers.buildEspLabel(12, "Bob", "100/100 HP", false), "12 studs | Bob | 100/100 HP")
	expectEqual(helpers.buildEspLabel(12, "Bob", "100/100 HP", true), "12 studs | @Bob | 100/100 HP")
	expectEqual(helpers.buildEspLabel(nil, "Bob", "", false), "? studs | Bob")
	expectEqual(helpers.buildEspLabel(5, "", "", false), "5 studs")
	expectEqual(helpers.buildEspLabel(5, "Bob", "", false), "5 studs | Bob")
end)

--------------------------------------------------------------------------------
-- Summary
--------------------------------------------------------------------------------

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error(string.format("%d test(s) failed", failed), 0)
end
