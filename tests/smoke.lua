--[[
	End-to-end smoke tests for HitboxEsp.luau, driven through the mock Roblox
	API in tests/mock_roblox.lua. These cover the behaviour that the pure unit
	tests in tests/run.lua cannot reach: UI wiring, toggles, snapshots, ESP
	lifecycle, keybinds, dragging, persistence and unload.

	Run from the repository root:
	    lua5.4 tests/smoke.lua
	    lua tests/smoke.lua
]]

local Mock = rawget(_G, "MOCK_SOURCE") and assert(load(rawget(_G, "MOCK_SOURCE"), "mock_roblox.lua"))()
	or dofile("tests/mock_roblox.lua")

local SOURCE_PATH = "HitboxEsp.luau"
local SAVE_FILE = "hitbox_esp_settings.json"

local source = rawget(_G, "HITBOX_SOURCE")
if type(source) ~= "string" then
	local handle = assert(io.open(SOURCE_PATH, "rb"))
	source = handle:read("*a")
	handle:close()
end

local passed = 0
local failed = 0

local function check(condition, message)
	if not condition then
		error(message, 2)
	end
end

local function expectEqual(actual, expected, label)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", label or "value", tostring(expected), tostring(actual)), 2)
	end
end

local function expectVector(actual, x, y, z, label)
	if not actual then
		error((label or "vector") .. ": expected a Vector3, got nil", 2)
	end
	if actual.X ~= x or actual.Y ~= y or actual.Z ~= z then
		error(
			string.format(
				"%s: expected (%g, %g, %g), got (%g, %g, %g)",
				label or "vector",
				x,
				y,
				z,
				actual.X,
				actual.Y,
				actual.Z
			),
			2
		)
	end
end

local function expectContains(haystack, needle, label)
	if type(haystack) ~= "string" or not string.find(haystack, needle, 1, true) then
		error(string.format("%s: expected %q to contain %q", label or "text", tostring(haystack), tostring(needle)), 2)
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

local function newWorld(files)
	local world = Mock.newWorld()
	if files then
		for path, contents in pairs(files) do
			world.files[path] = contents
		end
	end
	return world
end

local function boot(world)
	local api = world:boot(source)
	world:step(0.3)
	return api
end

local function control(world, name)
	local instance = world:control(name)
	check(instance ~= nil, "missing control " .. name)
	return instance
end

local function settings(world)
	return world:settingsValue() or {}
end

--------------------------------------------------------------------------------
-- Boot and UI
--------------------------------------------------------------------------------

test("boots, builds the GUI and exposes an api", function()
	local world = newWorld()
	local api = boot(world)
	check(api ~= nil, "api not published")
	expectEqual(api.version, "2.0.0")
	local gui = world:screenGui()
	check(gui ~= nil, "ScreenGui missing")
	check(gui.Enabled == true, "ScreenGui should be enabled")
	local frame = world:mainFrame()
	expectEqual(frame.AbsoluteSize.X, 260)
	expectEqual(frame.AbsoluteSize.Y, 196)
	for _, name in ipairs({ "SizeBox", "ApplyButton", "StatusLabel", "HitboxToggle", "EspToggle", "SettingsButton" }) do
		control(world, name)
	end
	expectEqual(#world.warnings, 0, "warnings")
end)

test("centers the window and survives the first layout pass", function()
	local world = newWorld()
	boot(world)
	local frame = world:mainFrame()
	local position = frame.AbsolutePosition
	expectEqual(position.X, 510)
	expectEqual(position.Y, 262)
	-- ScreenGui keeps IgnoreGuiInset = false, so Position is 36 px above the
	-- absolute (screen) position. This is what used to drift on every launch.
	expectEqual(frame.Position.Y.Offset, 226)
	expectEqual(frame.Position.X.Offset, 510)
end)

test("does not write the settings file just from loading", function()
	local original = '{"hitboxSize":7,"theme":"dark"}'
	local world = newWorld({ [SAVE_FILE] = original })
	boot(world)
	expectEqual(world.files[SAVE_FILE], original)
end)

--------------------------------------------------------------------------------
-- Hitbox
--------------------------------------------------------------------------------

test("hitbox toggle expands and restores every R6 part", function()
	local world = newWorld()
	boot(world)
	local bob = world:addPlayer("Bob")
	local character = world:loadCharacter(bob)
	world:step(0.2)

	local root = world:findPart(character, "HumanoidRootPart")
	local head = world:findPart(character, "Head")
	local torso = world:findPart(character, "Torso")

	world:click(control(world, "HitboxToggle"))
	world:step(0.2)

	expectVector(root.Size, 10, 10, 10, "root size")
	expectVector(head.Size, 8, 8, 8, "head size")
	expectVector(torso.Size, 7, 7, 7, "torso size")
	expectEqual(head.Transparency, 0.7, "head transparency")
	expectEqual(head.Material.Name, "SmoothPlastic", "head material")
	expectEqual(head.CanCollide, false, "head collide")
	expectEqual(control(world, "HitboxToggle").Text, "Hitbox: ON")

	world:click(control(world, "HitboxToggle"))
	world:step(0.2)

	expectVector(root.Size, 2, 2, 1, "restored root size")
	expectVector(head.Size, 2, 1, 1, "restored head size")
	expectVector(torso.Size, 2, 2, 1, "restored torso size")
	expectEqual(head.Transparency, 0, "restored head transparency")
	expectEqual(head.Material.Name, "Plastic", "restored head material")
	expectEqual(head.CanCollide, true, "restored head collide")
	expectEqual(root.Transparency, 1, "restored root transparency")
	expectEqual(torso.CastShadow, true, "restored cast shadow")
end)

test("hitbox ignores dead characters", function()
	local world = newWorld()
	boot(world)
	local bob = world:addPlayer("Bob")
	local character = world:loadCharacter(bob)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	humanoid.Health = 0
	local root = world:findPart(character, "HumanoidRootPart")

	world:click(control(world, "HitboxToggle"))
	world:step(0.3)

	expectVector(root.Size, 2, 2, 1, "dead character must not be resized")
end)

test("does not touch the local player's own character", function()
	local world = newWorld()
	boot(world)
	local character = world:loadCharacter(world.localPlayer)
	local root = world:findPart(character, "HumanoidRootPart")

	world:click(control(world, "HitboxToggle"))
	world:step(0.3)

	expectVector(root.Size, 2, 2, 1, "local root size")
end)

test("reparenting a character does not corrupt the snapshot", function()
	local world = newWorld()
	boot(world)
	local bob = world:addPlayer("Bob")
	local character = world:loadCharacter(bob)
	local root = world:findPart(character, "HumanoidRootPart")
	world:step(0.2)

	world:click(control(world, "HitboxToggle"))
	world:step(0.2)
	expectVector(root.Size, 10, 10, 10, "expanded size")

	-- Games commonly reparent characters (death lobby, round cleanup). This must
	-- not drop the snapshot and re-snapshot the expanded parts.
	character.Parent = nil
	world:step(0.5)
	character.Parent = world.characterFolder
	world:step(0.3)
	expectVector(root.Size, 10, 10, 10, "still expanded after reparent")

	world:click(control(world, "HitboxToggle"))
	world:step(0.2)
	expectVector(root.Size, 2, 2, 1, "restored after reparent")
end)

test("respawns re-snapshot the new character", function()
	local world = newWorld()
	boot(world)
	local bob = world:addPlayer("Bob")
	local first = world:loadCharacter(bob)
	world:step(0.2)
	world:click(control(world, "HitboxToggle"))
	world:step(0.2)

	local second = world:loadCharacter(bob, "Bob2")
	world:step(0.6)

	local newRoot = world:findPart(second, "HumanoidRootPart")
	expectVector(newRoot.Size, 10, 10, 10, "new character expanded")

	world:click(control(world, "HitboxToggle"))
	world:step(0.2)
	expectVector(newRoot.Size, 2, 2, 1, "new character restored")
end)

test("closing never mutates characters it never snapshotted", function()
	local world = newWorld()
	boot(world)
	local bob = world:addPlayer("Bob")
	local character = world:loadCharacter(bob)
	local torso = world:findPart(character, "Torso")
	local head = world:findPart(character, "Head")
	world:step(0.2)

	world:click(control(world, "CloseButton"))
	world:click(control(world, "CloseConfirmButton"))
	world:step(0.3)

	expectEqual(torso.CanCollide, true, "untouched torso collide")
	expectEqual(torso.Size.Y, 2, "untouched torso size")
	expectEqual(head.Transparency, 0, "untouched head transparency")
	expectEqual(world:screenGui(), nil, "gui removed")
end)

--------------------------------------------------------------------------------
-- Size input
--------------------------------------------------------------------------------

test("clamps oversized input and persists the clamped value", function()
	local world = newWorld()
	boot(world)
	local sizeBox = control(world, "SizeBox")
	sizeBox.Text = "1000"
	world:click(control(world, "ApplyButton"))
	world:step(0.1)

	expectEqual(settings(world).hitboxSize, 50, "clamped size")
	expectEqual(sizeBox.Text, "50")
	expectContains(control(world, "StatusLabel").Text, "Clamped")
end)

test("rejects garbage input without changing the size", function()
	local world = newWorld()
	boot(world)
	local sizeBox = control(world, "SizeBox")
	sizeBox.Text = "1000"
	world:click(control(world, "ApplyButton"))
	world:step(0.1)
	sizeBox.Text = "abc"
	world:click(control(world, "ApplyButton"))
	world:step(0.1)

	expectEqual(settings(world).hitboxSize, 50, "size must stay clamped")
	expectContains(control(world, "StatusLabel").Text, "Not a valid number")
end)

test("clamps tiny input up to the minimum", function()
	local world = newWorld()
	boot(world)
	local sizeBox = control(world, "SizeBox")
	sizeBox.Text = "0"
	world:click(control(world, "ApplyButton"))
	world:step(0.1)
	expectEqual(settings(world).hitboxSize, 1, "minimum size")
end)

test("Enter in the size box applies the value", function()
	local world = newWorld()
	boot(world)
	local sizeBox = control(world, "SizeBox")
	sizeBox.Text = "12.5"
	sizeBox.FocusLost:Fire(true)
	world:step(0.1)
	expectEqual(settings(world).hitboxSize, 12.5, "size applied on Enter")
end)

test("apply keybind works while the GUI is hidden", function()
	local world = newWorld({ [SAVE_FILE] = '{"hitboxSize":5,"keybinds":{"apply":"F"}}' })
	boot(world)
	local sizeBox = control(world, "SizeBox")
	sizeBox.Text = "9"
	world:pressKey("F")
	world:step(0.1)
	expectEqual(settings(world).hitboxSize, 9, "size applied by keybind")
end)

--------------------------------------------------------------------------------
-- Persistence
--------------------------------------------------------------------------------

test("loads saved settings including theme and keybinds", function()
	local world = newWorld({
		[SAVE_FILE] = '{"hitboxSize":7.5,"theme":"light","hideParts":true,"keybinds":{"hitbox":"Q"}}',
	})
	boot(world)
	expectEqual(control(world, "SizeBox").Text, "7.5")
	expectEqual(control(world, "HidePartsToggle").Text, "ON")
	expectEqual(control(world, "KeybindButton_hitbox").Text, "Q")
	local background = world:mainFrame().BackgroundColor3
	expectEqual(background.R, 1, "light background red")
	expectEqual(background.G, 1, "light background green")
end)

test("quarantines a corrupt settings file and keeps defaults", function()
	local world = newWorld({ [SAVE_FILE] = "{oops" })
	boot(world)
	expectEqual(world.files[SAVE_FILE .. ".corrupt"], "{oops")
	expectEqual(control(world, "SizeBox").Text, "10")
	expectContains(control(world, "StatusLabel").Text, "Corrupt settings")
end)

test("quarantines JSON that is not an object", function()
	local world = newWorld({ [SAVE_FILE] = "123" })
	boot(world)
	expectEqual(world.files[SAVE_FILE .. ".corrupt"], "123")
	expectEqual(control(world, "SizeBox").Text, "10")
end)

test("recovers from the backup when the main file is unreadable", function()
	local world = newWorld({
		[SAVE_FILE] = "{oops",
		[SAVE_FILE .. ".bak"] = '{"hitboxSize":6}',
	})
	boot(world)
	expectEqual(control(world, "SizeBox").Text, "6")
	expectEqual(settings(world).hitboxSize, nil, "settings not written until an action")
end)

test("drops invalid saved keybinds instead of crashing", function()
	local world = newWorld({ [SAVE_FILE] = '{"keybinds":{"hitbox":"NotAKey"}}' })
	boot(world)
	expectEqual(control(world, "KeybindButton_hitbox").Text, "None")
end)

test("reports unavailable persistence instead of failing silently", function()
	local world = newWorld()
	world.env.writefile = nil
	world.env.readfile = nil
	world.env.isfile = nil
	boot(world)
	expectContains(control(world, "PersistLabel").Text, "unavailable")
	world:click(control(world, "ApplyButton"))
	world:step(0.1)
end)

--------------------------------------------------------------------------------
-- ESP
--------------------------------------------------------------------------------

test("ESP creates labels and a highlight, then removes them", function()
	local world = newWorld()
	boot(world)
	local bob = world:addPlayer("Bob")
	local character = world:loadCharacter(bob)
	world:step(0.2)

	world:click(control(world, "EspToggle"))
	world:step(0.2)

	local head = world:findPart(character, "Head")
	local billboard = head:FindFirstChild("HitboxESP_Bob")
	check(billboard ~= nil, "billboard missing")
	local info = billboard:FindFirstChild("InfoLabel")
	check(info ~= nil, "info label missing")
	expectContains(info.Text, "studs")
	expectContains(info.Text, "Bob")
	expectContains(info.Text, "100/100 HP")
	check(character:FindFirstChildOfClass("Highlight") ~= nil, "highlight missing")

	world:click(control(world, "EspToggle"))
	world:step(0.2)
	expectEqual(head:FindFirstChild("HitboxESP_Bob"), nil, "billboard removed")
	expectEqual(character:FindFirstChildOfClass("Highlight"), nil, "highlight removed")
end)

test("ESP updates distance and removes dead players", function()
	local world = newWorld()
	boot(world)
	local bob = world:addPlayer("Bob")
	local character = world:loadCharacter(bob)
	world:step(0.2)
	world:click(control(world, "EspToggle"))
	world:step(0.2)

	local root = world:findPart(character, "HumanoidRootPart")
	root.Position = Mock.Vector3.new(50, 0, 0)
	world:step(0.3)
	local info = world:findPart(character, "Head"):FindFirstChild("HitboxESP_Bob"):FindFirstChild("InfoLabel")
	expectContains(info.Text, "50 studs")

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	humanoid.Health = 0
	world:step(0.3)
	expectEqual(world:findPart(character, "Head"):FindFirstChild("HitboxESP_Bob"), nil, "dead player ESP removed")
end)

test("ESP shows the display name on a second line", function()
	local world = newWorld()
	boot(world)
	local bob = world:addPlayer("Bob")
	bob.DisplayName = "Bobby"
	local character = world:loadCharacter(bob)
	world:step(0.2)

	world:click(control(world, "EspToggle"))
	world:step(0.2)

	local billboard = world:findPart(character, "Head"):FindFirstChild("HitboxESP_Bob")
	check(billboard ~= nil, "billboard missing")
	expectEqual(billboard.Size.Y.Offset, 36, "two-line height")
	local display = billboard:FindFirstChild("DisplayLabel")
	check(display ~= nil, "display label missing")
	expectEqual(display.Text, "Bobby")
	local info = billboard:FindFirstChild("InfoLabel")
	expectContains(info.Text, "@Bob")
end)

--------------------------------------------------------------------------------
-- Keybinds
--------------------------------------------------------------------------------

test("captures a keybind, persists it and fires the action", function()
	local world = newWorld()
	boot(world)
	world:click(control(world, "SettingsButton"))
	world:step(0.3)

	world:click(control(world, "KeybindButton_hitbox"))
	world:pressKey("Q")
	world:step(0.1)
	expectEqual(control(world, "KeybindButton_hitbox").Text, "Q")
	expectEqual(settings(world).keybinds.hitbox, "Q")

	world:pressKey("Q")
	world:step(0.1)
	expectEqual(control(world, "HitboxToggle").Text, "Hitbox: ON")
end)

test("keybinds are ignored while a text box has focus", function()
	local world = newWorld({ [SAVE_FILE] = '{"keybinds":{"hitbox":"Q"}}' })
	boot(world)
	world.userInputService._focusedTextBox = control(world, "SizeBox")
	world:pressKey("Q")
	world:step(0.1)
	expectEqual(control(world, "HitboxToggle").Text, "Hitbox: OFF")
end)

test("binding a key that is already used moves it instead of duplicating", function()
	local world = newWorld({ [SAVE_FILE] = '{"keybinds":{"hitbox":"Q"}}' })
	boot(world)
	world:click(control(world, "SettingsButton"))
	world:step(0.3)
	world:click(control(world, "KeybindButton_esp"))
	world:pressKey("Q")
	world:step(0.1)

	expectEqual(control(world, "KeybindButton_esp").Text, "Q")
	expectEqual(control(world, "KeybindButton_hitbox").Text, "None")
	expectEqual(settings(world).keybinds.hitbox, "None")
end)

test("Backspace clears a bind and Escape cancels listening", function()
	local world = newWorld({ [SAVE_FILE] = '{"keybinds":{"hitbox":"Q"}}' })
	boot(world)
	world:click(control(world, "SettingsButton"))
	world:step(0.3)

	world:click(control(world, "KeybindButton_hitbox"))
	world:pressKey("Backspace")
	world:step(0.1)
	expectEqual(control(world, "KeybindButton_hitbox").Text, "None")

	world:click(control(world, "KeybindButton_esp"))
	world:pressKey("Escape")
	world:step(0.1)
	world:pressKey("E")
	world:step(0.1)
	expectEqual(control(world, "KeybindButton_esp").Text, "None")
end)

test("GUI toggle keybind hides and shows the interface", function()
	local world = newWorld({ [SAVE_FILE] = '{"keybinds":{"gui":"G"}}' })
	boot(world)
	world:pressKey("G")
	world:step(0.1)
	expectEqual(world:screenGui().Enabled, false, "gui hidden")
	world:pressKey("G")
	world:step(0.1)
	expectEqual(world:screenGui().Enabled, true, "gui shown")
end)

test("minimize keybind and button both collapse the window", function()
	local world = newWorld()
	boot(world)
	local frame = world:mainFrame()
	world:click(control(world, "MinimizeButton"))
	world:step(0.1)
	expectEqual(frame.Size.Y.Offset, 58, "minimized height")
	expectEqual(control(world, "ContentFrame").Visible, false, "content hidden")
	world:click(control(world, "MinimizeButton"))
	world:step(0.1)
	expectEqual(frame.Size.Y.Offset, 196, "restored height")
end)

--------------------------------------------------------------------------------
-- Theme and window position
--------------------------------------------------------------------------------

test("theme switch applies instantly and persists", function()
	local world = newWorld()
	boot(world)
	world:click(control(world, "SettingsButton"))
	world:step(0.3)
	world:click(control(world, "ThemeLightButton"))
	world:step(0.2)

	expectEqual(world:mainFrame().BackgroundColor3.R, 1, "light theme applied")
	expectEqual(settings(world).theme, "light")
	expectEqual(control(world, "SizeBox").TextColor3.R, 30 / 255, "text color")

	world:click(control(world, "ThemeDarkButton"))
	world:step(0.2)
	expectEqual(settings(world).theme, "dark")
end)

test("dragging clamps the window to the viewport and persists the position", function()
	local world = newWorld()
	boot(world)
	local frame = world:mainFrame()
	local titleBar = frame:FindFirstChild("TitleBar")

	world:mouseDown(titleBar, 600, 300)
	world:mouseMove(-5000, -5000)
	world:mouseUp(-5000, -5000)
	world:step(0.1)

	local position = frame.AbsolutePosition
	expectEqual(position.X, -140, "clamped left")
	expectEqual(position.Y, 36, "clamped to the topbar inset")
	expectEqual(settings(world).windowPosition.x, -140)
	expectEqual(settings(world).windowPosition.y, 36)
end)

test("a saved off-screen position is pulled back on screen", function()
	local world = newWorld({ [SAVE_FILE] = '{"windowPosition":{"x":-9000,"y":-9000}}' })
	boot(world)
	local position = world:mainFrame().AbsolutePosition
	expectEqual(position.X, -140)
	expectEqual(position.Y, 36)
end)

test("viewport changes re-clamp the window", function()
	local world = newWorld()
	boot(world)
	local frame = world:mainFrame()
	local titleBar = frame:FindFirstChild("TitleBar")
	world:mouseDown(titleBar, 600, 300)
	world:mouseMove(5000, 5000)
	world:mouseUp(5000, 5000)
	world:step(0.1)
	expectEqual(frame.AbsolutePosition.X, 1160, "clamped right")

	world.camera.ViewportSize = Mock.Vector2.new(800, 600)
	world:step(0.3)
	expectEqual(frame.AbsolutePosition.X, 680, "re-clamped right")
	expectEqual(frame.AbsolutePosition.Y, 480, "re-clamped bottom")
end)

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

test("closing unloads every connection and stops all work", function()
	local world = newWorld()
	local api = boot(world)
	local bob = world:addPlayer("Bob")
	local character = world:loadCharacter(bob)
	local root = world:findPart(character, "HumanoidRootPart")
	world:step(0.2)

	world:click(control(world, "HitboxToggle"))
	world:click(control(world, "EspToggle"))
	world:step(0.2)
	check(character:FindFirstChildOfClass("Highlight") ~= nil, "highlight missing before close")

	world:click(control(world, "CloseButton"))
	world:step(0.05)
	check(control(world, "ConfirmFrame").Visible == true, "confirmation not shown")
	world:click(control(world, "CloseConfirmButton"))
	world:step(0.3)

	expectEqual(world:screenGui(), nil, "gui destroyed")
	expectVector(root.Size, 2, 2, 1, "hitboxes restored")
	expectEqual(character:FindFirstChildOfClass("Highlight"), nil, "highlight removed")
	expectEqual(world.genv.HitboxESP, nil, "api unpublished")
	expectEqual(api.unload ~= nil, true, "api keeps its unload function")

	-- Nothing may keep running after unload.
	world:step(2)
	expectVector(root.Size, 2, 2, 1, "no work after unload")
end)

test("the close confirmation can be cancelled", function()
	local world = newWorld()
	boot(world)
	world:click(control(world, "CloseButton"))
	world:step(0.05)
	world:click(control(world, "CancelButton"))
	world:step(0.2)
	expectEqual(control(world, "ConfirmFrame").Visible, false, "confirmation hidden")
	check(world:screenGui() ~= nil, "gui must stay open")
end)

test("booting twice replaces the previous instance instead of stacking", function()
	local world = newWorld()
	boot(world)
	local firstGui = world:screenGui()
	check(firstGui ~= nil, "first gui missing")

	boot(world)
	local guiCount = 0
	for _, child in ipairs(world.playerGui:GetChildren()) do
		if child.Name == "HitboxESP" then
			guiCount = guiCount + 1
		end
	end
	expectEqual(guiCount, 1, "exactly one gui")
	check(world:screenGui() ~= firstGui, "gui should be a fresh instance")
	expectEqual(firstGui.Parent, nil, "old gui destroyed")
end)

test("unload is idempotent and safe to call twice", function()
	local world = newWorld()
	local api = boot(world)
	api.unload()
	api.unload()
	world:step(0.2)
	expectEqual(world:screenGui(), nil)
end)

test("hide parts toggle makes hitbox parts invisible and restores them", function()
	local world = newWorld()
	boot(world)
	world:click(control(world, "SettingsButton"))
	world:step(0.3)
	local bob = world:addPlayer("Bob")
	local character = world:loadCharacter(bob)
	local head = world:findPart(character, "Head")
	world:step(0.2)

	world:click(control(world, "HitboxToggle"))
	world:step(0.2)
	expectEqual(head.Transparency, 0.7)

	world:click(control(world, "HidePartsToggle"))
	world:step(0.2)
	expectEqual(head.Transparency, 1, "parts hidden")
	expectEqual(control(world, "HidePartsToggle").Text, "ON")

	world:click(control(world, "HitboxToggle"))
	world:step(0.2)
	expectEqual(head.Transparency, 0, "original transparency restored")
end)

--------------------------------------------------------------------------------
-- Summary
--------------------------------------------------------------------------------

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error(string.format("%d smoke test(s) failed", failed), 0)
end
