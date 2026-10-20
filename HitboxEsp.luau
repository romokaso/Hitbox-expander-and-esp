--!nonstrict
--[[
	Hitbox ESP — client-side hitbox expander and ESP with a single-file GUI.

	Version: 2.0.0
	License: MIT (see LICENSE)
	Repository: https://github.com/romokaso/Hitbox-expander-and-esp

	This script only changes objects on your own client. It does not change
	server-side hit detection and it does not talk to any external service.
	Using it in a game may violate that game's rules or the Roblox Terms of Use.
	You are responsible for how you use it.

	Structure of this file:
	   1. Services, constants
	   2. Pure helpers (PURE BEGIN/END — unit-tested by tests/run.lua)
	   3. Settings persistence (validated, backed up, corrupt-file quarantine)
	   4. Palette and UI helpers
	   5. State, connection tracking, single-instance guard
	   6. UI construction
	   7. Buttons and theme engine
	   8. Hitbox module (snapshot/restore, never touches unsnapshotted parts)
	   9. ESP module
	  10. Toggles, status text and settings actions
	  11. Window position
	  12. Player and character tracking
	  13. Unload and input handling
	  14. UI event wiring
	  15. Startup
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local SCRIPT_VERSION = "2.0.0"
local SAVE_FILE = "hitbox_esp_settings.json"
local SAVE_BACKUP = SAVE_FILE .. ".bak"
local SAVE_CORRUPT = SAVE_FILE .. ".corrupt"

local UPDATE_INTERVAL = 0.1
local RESPAWN_DELAY = 0.4
local WINDOW_WIDTH = 260
local WINDOW_HEIGHT = 196
local MINIMIZED_HEIGHT = 58

local THEME_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BUTTON_TWEEN = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local OVERLAY_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- >>> PURE BEGIN
-- Everything between the markers must stay free of Roblox APIs so that it can
-- be loaded and tested by a plain Lua interpreter (tests/run.lua).

local MIN_HITBOX_SIZE = 1
local MAX_HITBOX_SIZE = 50
local VISIBLE_MARGIN = 120
local DEFAULT_HITBOX_SIZE = 10
local SCHEMA_VERSION = 2

local ACTIONS = { "hitbox", "esp", "gui", "minimize", "apply" }

local ACTION_LABELS = {
	hitbox = "Toggle hitbox",
	esp = "Toggle ESP",
	gui = "Toggle GUI",
	minimize = "Minimize",
	apply = "Apply hitbox",
}

local RESERVED_KEYBINDS = {
	Escape = true,
	Unknown = true,
}

local function isFiniteNumber(value)
	if type(value) ~= "number" then
		return false
	end
	-- NaN is the only value that is not equal to itself.
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function clampNumber(value, minimum, maximum)
	if value < minimum then
		return minimum
	end
	if value > maximum then
		return maximum
	end
	return value
end

local function roundToTenth(value)
	return math.floor(value * 10 + 0.5) / 10
end

-- Luau's tostring turns 6.0 into "6", plain Lua turns it into "6.0".
-- Format explicitly so the UI (and the tests) behave the same everywhere.
local function formatSize(value)
	if not isFiniteNumber(value) then
		return "?"
	end
	if value == math.floor(value) then
		return string.format("%d", value)
	end
	return string.format("%.1f", value)
end

-- Returns (size, note) on success and (nil, errorMessage) on invalid input.
-- Out-of-range numbers are clamped instead of rejected; the note explains it.
local function parseSizeInput(text)
	if type(text) ~= "string" then
		return nil, "Enter a number"
	end
	local trimmed = string.match(text, "^%s*(.-)%s*$")
	if trimmed == "" then
		return nil, "Enter a number"
	end
	local value = tonumber(trimmed)
	if not isFiniteNumber(value) then
		return nil, "Not a valid number"
	end
	local rounded = roundToTenth(value)
	local clamped = clampNumber(rounded, MIN_HITBOX_SIZE, MAX_HITBOX_SIZE)
	if clamped ~= rounded then
		return clamped, string.format("Clamped to %s", formatSize(clamped))
	end
	return clamped, nil
end

local function defaultKeybinds()
	return {
		hitbox = "None",
		esp = "None",
		gui = "None",
		minimize = "None",
		apply = "None",
	}
end

local function sanitizeKeybindName(name)
	if type(name) ~= "string" then
		return nil
	end
	if name == "None" then
		return "None"
	end
	if RESERVED_KEYBINDS[name] then
		return nil
	end
	if #name < 1 or #name > 32 then
		return nil
	end
	if not string.match(name, "^%w+$") then
		return nil
	end
	return name
end

-- Guarantees that no two actions share a key. The first action in ACTIONS
-- order wins, which makes the result deterministic for any input order.
local function dedupeKeybinds(keybinds)
	local seen = {}
	for _, action in ipairs(ACTIONS) do
		local name = keybinds[action]
		if name ~= "None" and name ~= nil then
			if seen[name] then
				keybinds[action] = "None"
			else
				seen[name] = true
			end
		end
	end
	return keybinds
end

-- Turns whatever came out of the settings file into a table with known types
-- and safe ranges. Never throws, never returns nil.
local function sanitizeSettings(raw)
	local result = {
		schemaVersion = SCHEMA_VERSION,
		hitboxSize = DEFAULT_HITBOX_SIZE,
		theme = "dark",
		hideParts = false,
		restoreEnabled = false,
		hitboxEnabled = false,
		espEnabled = false,
		keybinds = defaultKeybinds(),
		windowPosition = nil,
	}
	if type(raw) ~= "table" then
		return result
	end
	if isFiniteNumber(raw.hitboxSize) then
		result.hitboxSize = clampNumber(roundToTenth(raw.hitboxSize), MIN_HITBOX_SIZE, MAX_HITBOX_SIZE)
	end
	if raw.theme == "light" or raw.theme == "dark" then
		result.theme = raw.theme
	end
	if type(raw.hideParts) == "boolean" then
		result.hideParts = raw.hideParts
	end
	if type(raw.restoreEnabled) == "boolean" then
		result.restoreEnabled = raw.restoreEnabled
	end
	if type(raw.hitboxEnabled) == "boolean" then
		result.hitboxEnabled = raw.hitboxEnabled
	end
	if type(raw.espEnabled) == "boolean" then
		result.espEnabled = raw.espEnabled
	end
	if type(raw.keybinds) == "table" then
		for _, action in ipairs(ACTIONS) do
			local name = sanitizeKeybindName(raw.keybinds[action])
			if name then
				result.keybinds[action] = name
			end
		end
		dedupeKeybinds(result.keybinds)
	end
	local position = raw.windowPosition
	if type(position) == "table" and isFiniteNumber(position.x) and isFiniteNumber(position.y) then
		result.windowPosition = {
			x = math.floor(position.x),
			y = math.floor(position.y),
		}
	end
	return result
end

-- Assigns a keybind and clears the same key from every other action.
local function applyKeybindToTable(keybinds, action, keyName)
	if keyName ~= "None" then
		for _, other in ipairs(ACTIONS) do
			if other ~= action and keybinds[other] == keyName then
				keybinds[other] = "None"
			end
		end
	end
	keybinds[action] = keyName
	return dedupeKeybinds(keybinds)
end

-- Keeps at least VISIBLE_MARGIN pixels of the window inside the viewport.
local function clampWindowPosition(x, y, width, height, viewportWidth, viewportHeight)
	-- Keep VISIBLE_MARGIN pixels reachable, but never ask for more than the
	-- window or the viewport can provide (tiny/custom viewports).
	local visibleX = math.min(VISIBLE_MARGIN, width, viewportWidth)
	local visibleY = math.min(VISIBLE_MARGIN, height, viewportHeight)
	local clampedX = clampNumber(x, -(width - visibleX), viewportWidth - visibleX)
	local clampedY = clampNumber(y, 0, viewportHeight - visibleY)
	return math.floor(clampedX), math.floor(clampedY)
end

local function formatDistance(studs)
	if not isFiniteNumber(studs) then
		return "? studs"
	end
	return string.format("%d studs", math.floor(studs))
end

local function formatHealth(current, maximum)
	if not isFiniteNumber(current) or not isFiniteNumber(maximum) or maximum <= 0 then
		return ""
	end
	return string.format("%d/%d HP", math.floor(current), math.floor(maximum))
end

local function buildEspLabel(distance, name, healthText, withAt)
	local chunks = { formatDistance(distance) }
	if type(name) == "string" and name ~= "" then
		if withAt then
			table.insert(chunks, "@" .. name)
		else
			table.insert(chunks, name)
		end
	end
	if type(healthText) == "string" and healthText ~= "" then
		table.insert(chunks, healthText)
	end
	return table.concat(chunks, " | ")
end

-- <<< PURE END

--------------------------------------------------------------------------------
-- Settings persistence
--------------------------------------------------------------------------------

local canPersist = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"

local function decodeFile(path)
	if not canPersist or not isfile(path) then
		return nil, "missing"
	end
	local readOk, contents = pcall(readfile, path)
	if not readOk or type(contents) ~= "string" or contents == "" then
		return nil, "unreadable"
	end
	local decodeOk, decoded = pcall(function()
		return HttpService:JSONDecode(contents)
	end)
	if not decodeOk then
		return nil, "corrupt"
	end
	return decoded, nil
end

local function quarantineCorruptFile()
	if not canPersist then
		return
	end
	local readOk, contents = pcall(readfile, SAVE_FILE)
	if readOk and type(contents) == "string" and contents ~= "" then
		pcall(writefile, SAVE_CORRUPT, contents)
	end
end

-- Returns settings and a status key used by the UI:
-- "loaded" | "defaults" | "backup" | "corrupt" | "unavailable"
local function loadSettings()
	if not canPersist then
		return sanitizeSettings(nil), "unavailable"
	end
	local decoded, reason = decodeFile(SAVE_FILE)
	if decoded ~= nil and type(decoded) == "table" then
		return sanitizeSettings(decoded), "loaded"
	end
	if reason == "corrupt" or (decoded ~= nil and type(decoded) ~= "table") then
		reason = "corrupt"
		quarantineCorruptFile()
	end
	local backup = decodeFile(SAVE_BACKUP)
	if backup ~= nil then
		return sanitizeSettings(backup), "backup"
	end
	if reason == "corrupt" then
		return sanitizeSettings(nil), "corrupt"
	end
	return sanitizeSettings(nil), "defaults"
end

local settings, persistStatus = loadSettings()

local function saveSettings()
	if not canPersist then
		persistStatus = "unavailable"
		return false
	end
	local encodeOk, encoded = pcall(function()
		return HttpService:JSONEncode(settings)
	end)
	if not encodeOk or type(encoded) ~= "string" then
		warn("[HitboxESP] Could not encode settings")
		return false
	end
	local writeOk = pcall(function()
		if isfile(SAVE_FILE) then
			local previous = readfile(SAVE_FILE)
			if type(previous) == "string" and previous ~= "" then
				writefile(SAVE_BACKUP, previous)
			end
		end
		writefile(SAVE_FILE, encoded)
	end)
	if not writeOk then
		persistStatus = "error"
		warn("[HitboxESP] Could not write settings file")
		return false
	end
	persistStatus = "saved"
	return true
end

--------------------------------------------------------------------------------
-- Palette and small UI helpers
--------------------------------------------------------------------------------

local PALETTE = {
	error = Color3.fromRGB(235, 70, 70),
	on = Color3.fromRGB(50, 200, 100),
	off = Color3.fromRGB(220, 50, 50),
	accent = Color3.fromRGB(80, 150, 255),
	dark = {
		panel = Color3.fromRGB(20, 20, 25),
		panelAlt = Color3.fromRGB(30, 30, 40),
		border = Color3.fromRGB(60, 60, 70),
		text = Color3.fromRGB(255, 255, 255),
		textMuted = Color3.fromRGB(200, 200, 210),
		textDim = Color3.fromRGB(120, 120, 130),
		field = Color3.fromRGB(40, 40, 50),
		fieldBorder = Color3.fromRGB(80, 80, 90),
	},
	light = {
		panel = Color3.fromRGB(255, 255, 255),
		panelAlt = Color3.fromRGB(245, 245, 250),
		border = Color3.fromRGB(200, 200, 210),
		text = Color3.fromRGB(30, 30, 40),
		textMuted = Color3.fromRGB(60, 60, 70),
		textDim = Color3.fromRGB(100, 100, 110),
		field = Color3.fromRGB(235, 235, 245),
		fieldBorder = Color3.fromRGB(200, 200, 210),
	},
}

local function withDefaults(defaults, overrides)
	local result = {}
	for key, value in pairs(defaults) do
		result[key] = value
	end
	if overrides then
		for key, value in pairs(overrides) do
			result[key] = value
		end
	end
	return result
end

local function create(className, properties, parent)
	local instance = Instance.new(className)
	for property, value in pairs(properties or {}) do
		instance[property] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function addCorner(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function addStroke(parent, color, thickness, transparency)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
	}, parent)
end

local function makeLabel(parent, properties)
	return create(
		"TextLabel",
		withDefaults({
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = PALETTE.dark.textMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}, properties),
		parent
	)
end

local function makeButton(parent, properties)
	return create(
		"TextButton",
		withDefaults({
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = PALETTE.dark.text,
			BackgroundColor3 = PALETTE.dark.field,
		}, properties),
		parent
	)
end

--------------------------------------------------------------------------------
-- State and connection bookkeeping
--------------------------------------------------------------------------------

local state = {
	running = true,
	unloading = false,
	closing = false,
	hitboxEnabled = false,
	espEnabled = false,
	guiVisible = true,
	minimized = false,
	listeningFor = nil,
}

local connections = {}

local function track(connection)
	table.insert(connections, connection)
	return connection
end

local function getSharedGlobals()
	if type(getgenv) == "function" then
		local ok, environment = pcall(getgenv)
		if ok and type(environment) == "table" then
			return environment
		end
	end
	return nil
end

local shared = getSharedGlobals()

-- Single-instance guard: ask a previous copy to unload, then remove any stale GUI.
if shared and type(shared.HitboxESP) == "table" and type(shared.HitboxESP.unload) == "function" then
	pcall(shared.HitboxESP.unload)
end
local staleGui = playerGui:FindFirstChild("HitboxESP") or playerGui:FindFirstChild("HitboxChanger")
if staleGui then
	staleGui:Destroy()
end

local function getViewport()
	local camera = Workspace.CurrentCamera
	local size = camera and camera.ViewportSize
	if size and size.X > 0 and size.Y > 0 then
		return size
	end
	return Vector2.new(1280, 720)
end

-- ScreenGui with IgnoreGuiInset = false offsets every child by the topbar inset.
-- AbsolutePosition includes that offset while Position does not, so positions
-- must be converted in both directions or the window drifts down on every start.
local function getGuiInset()
	local ok, inset = pcall(function()
		return GuiService:GetGuiInset()
	end)
	if ok and inset then
		return inset
	end
	return Vector2.new(0, 0)
end

--------------------------------------------------------------------------------
-- UI construction
--------------------------------------------------------------------------------

local screenGui = create("ScreenGui", {
	Name = "HitboxESP",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 999,
	IgnoreGuiInset = false,
	Enabled = false,
}, playerGui)

local mainFrame = create("Frame", {
	Name = "MainFrame",
	Size = UDim2.fromOffset(WINDOW_WIDTH, WINDOW_HEIGHT),
	Position = UDim2.fromOffset(0, 0),
	BackgroundColor3 = PALETTE.dark.panel,
	BorderSizePixel = 0,
	Active = true,
	ClipsDescendants = true,
}, screenGui)
addCorner(mainFrame, 12)
local mainStroke = addStroke(mainFrame, PALETTE.dark.border, 2, 0.5)
local uiScale = create("UIScale", { Scale = 1 }, mainFrame)

-- Keeps the panel readable on high-DPI screens and usable on small ones.
local function updateUiScale()
	local viewport = getViewport()
	uiScale.Scale = clampNumber(viewport.Y / 720, 0.9, 1.25)
end

local titleBar = create("Frame", {
	Name = "TitleBar",
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundColor3 = PALETTE.dark.panelAlt,
	BorderSizePixel = 0,
}, mainFrame)
addCorner(titleBar, 12)
local titleFix = create("Frame", {
	Size = UDim2.new(1, 0, 0, 12),
	Position = UDim2.new(0, 0, 1, -12),
	BackgroundColor3 = PALETTE.dark.panelAlt,
	BorderSizePixel = 0,
}, titleBar)

local titleLabel = makeLabel(titleBar, {
	Size = UDim2.new(1, -110, 1, 0),
	Position = UDim2.fromOffset(12, 0),
	Text = "Hitbox ESP",
	TextColor3 = PALETTE.dark.text,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
})

local settingsButton = makeButton(titleBar, {
	Name = "SettingsButton",
	Size = UDim2.fromOffset(26, 26),
	Position = UDim2.new(1, -92, 0, 5),
	Text = "⚙",
	TextSize = 13,
})
addCorner(settingsButton, 6)

local minimizeButton = makeButton(titleBar, {
	Name = "MinimizeButton",
	Size = UDim2.fromOffset(26, 26),
	Position = UDim2.new(1, -60, 0, 5),
	Text = "_",
	TextColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundColor3 = Color3.fromRGB(255, 200, 50),
	TextSize = 14,
})
addCorner(minimizeButton, 6)

local closeButton = makeButton(titleBar, {
	Name = "CloseButton",
	Size = UDim2.fromOffset(26, 26),
	Position = UDim2.new(1, -28, 0, 5),
	Text = "X",
	TextColor3 = PALETTE.dark.text,
	BackgroundColor3 = PALETTE.off,
	TextSize = 12,
})
addCorner(closeButton, 6)

local contentFrame = create("Frame", {
	Name = "ContentFrame",
	Size = UDim2.new(1, 0, 1, -36),
	Position = UDim2.fromOffset(0, 36),
	BackgroundColor3 = PALETTE.dark.panel,
	BorderSizePixel = 0,
}, mainFrame)

local sizeLabel = makeLabel(contentFrame, {
	Size = UDim2.fromOffset(80, 28),
	Position = UDim2.fromOffset(12, 10),
	Text = "Hitbox size",
	TextColor3 = PALETTE.dark.textMuted,
})

local sizeBox = create("TextBox", {
	Name = "SizeBox",
	Size = UDim2.fromOffset(80, 28),
	Position = UDim2.fromOffset(94, 10),
	BackgroundColor3 = PALETTE.dark.field,
	BorderSizePixel = 0,
	Text = formatSize(settings.hitboxSize),
	PlaceholderText = "Size",
	PlaceholderColor3 = PALETTE.dark.fieldBorder,
	ClearTextOnFocus = false,
	TextColor3 = PALETTE.dark.text,
	TextSize = 12,
	Font = Enum.Font.Gotham,
}, contentFrame)
addCorner(sizeBox, 7)
local sizeBoxStroke = addStroke(sizeBox, PALETTE.dark.fieldBorder, 1)

local applyButton = makeButton(contentFrame, {
	Name = "ApplyButton",
	Size = UDim2.fromOffset(70, 28),
	Position = UDim2.fromOffset(180, 10),
	Text = "Apply",
	BackgroundColor3 = PALETTE.accent,
})

local statusLabel = makeLabel(contentFrame, {
	Name = "StatusLabel",
	Size = UDim2.new(1, -24, 0, 16),
	Position = UDim2.fromOffset(12, 42),
	Text = "",
	TextSize = 11,
	TextWrapped = true,
	TextTruncate = Enum.TextTruncate.AtEnd,
})

local hitboxToggle = makeButton(contentFrame, {
	Name = "HitboxToggle",
	Size = UDim2.new(1, -24, 0, 30),
	Position = UDim2.fromOffset(12, 62),
	Text = "Hitbox: OFF",
	TextSize = 13,
	BackgroundColor3 = PALETTE.off,
})
addCorner(hitboxToggle, 7)

local espToggle = makeButton(contentFrame, {
	Name = "EspToggle",
	Size = UDim2.new(1, -24, 0, 30),
	Position = UDim2.fromOffset(12, 98),
	Text = "ESP: OFF",
	TextSize = 13,
	BackgroundColor3 = PALETTE.off,
})
addCorner(espToggle, 7)

local footerLabel = makeLabel(contentFrame, {
	Name = "FooterLabel",
	Size = UDim2.new(1, 0, 0, 24),
	Position = UDim2.new(0, 0, 1, -24),
	Text = "by romokaso",
	TextColor3 = PALETTE.dark.textDim,
	TextSize = 10,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Center,
})

local footerLabelMinimized = makeLabel(mainFrame, {
	Name = "FooterLabelMinimized",
	Size = UDim2.new(1, 0, 0, 20),
	Position = UDim2.fromOffset(0, 37),
	Text = "by romokaso",
	TextColor3 = PALETTE.dark.textDim,
	TextSize = 10,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Center,
	Visible = false,
})

-- Confirmation overlay -------------------------------------------------------

local confirmFrame = create("Frame", {
	Name = "ConfirmFrame",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = PALETTE.dark.panel,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 10,
	Active = true,
}, mainFrame)
addCorner(confirmFrame, 12)

local confirmText = makeLabel(confirmFrame, {
	Size = UDim2.new(1, -24, 0, 44),
	Position = UDim2.fromOffset(12, 44),
	Text = "Close Hitbox ESP and restore\nall hitboxes?",
	TextColor3 = PALETTE.dark.text,
	TextSize = 13,
	Font = Enum.Font.GothamBold,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 11,
})

local yesButton = makeButton(confirmFrame, {
	Name = "CloseConfirmButton",
	Size = UDim2.fromOffset(105, 32),
	Position = UDim2.fromOffset(20, 104),
	Text = "Close",
	BackgroundColor3 = PALETTE.on,
	ZIndex = 11,
})
addCorner(yesButton, 7)

local noButton = makeButton(confirmFrame, {
	Name = "CancelButton",
	Size = UDim2.fromOffset(105, 32),
	Position = UDim2.fromOffset(135, 104),
	Text = "Cancel",
	BackgroundColor3 = PALETTE.off,
	ZIndex = 11,
})
addCorner(noButton, 7)

-- Settings overlay -----------------------------------------------------------

local settingsFrame = create("Frame", {
	Name = "SettingsFrame",
	Size = UDim2.fromScale(1, 1),
	Position = UDim2.fromScale(1, 0),
	BackgroundColor3 = PALETTE.dark.panel,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 10,
	Active = true,
}, mainFrame)
addCorner(settingsFrame, 12)

local settingsTitleBar = create("Frame", {
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundColor3 = PALETTE.dark.panelAlt,
	BorderSizePixel = 0,
	ZIndex = 11,
}, settingsFrame)
addCorner(settingsTitleBar, 12)
local settingsTitleFix = create("Frame", {
	Size = UDim2.new(1, 0, 0, 12),
	Position = UDim2.new(0, 0, 1, -12),
	BackgroundColor3 = PALETTE.dark.panelAlt,
	BorderSizePixel = 0,
	ZIndex = 11,
}, settingsTitleBar)

local settingsTitleLabel = makeLabel(settingsTitleBar, {
	Size = UDim2.new(1, -50, 1, 0),
	Position = UDim2.fromOffset(12, 0),
	Text = "Settings",
	TextColor3 = PALETTE.dark.text,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	ZIndex = 11,
})

local backButton = makeButton(settingsTitleBar, {
	Name = "BackButton",
	Size = UDim2.fromOffset(26, 26),
	Position = UDim2.new(1, -32, 0, 5),
	Text = "←",
	TextSize = 14,
	ZIndex = 11,
})
addCorner(backButton, 6)

local settingsContentFrame = create("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, -36),
	Position = UDim2.fromOffset(0, 36),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 11,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = PALETTE.accent,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	CanvasSize = UDim2.fromOffset(0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, settingsFrame)

local themeLabel = makeLabel(settingsContentFrame, {
	Position = UDim2.fromOffset(12, 10),
	Size = UDim2.new(1, -24, 0, 20),
	Text = "Theme",
	TextColor3 = PALETTE.dark.textMuted,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	ZIndex = 11,
})

local darkButton = makeButton(settingsContentFrame, {
	Name = "ThemeDarkButton",
	Size = UDim2.fromOffset(110, 30),
	Position = UDim2.fromOffset(12, 34),
	Text = "Dark",
	BackgroundColor3 = PALETTE.dark.panelAlt,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 13,
	ZIndex = 11,
})
addCorner(darkButton, 7)
local darkStroke = addStroke(darkButton, PALETTE.accent, 2)

local lightButton = makeButton(settingsContentFrame, {
	Name = "ThemeLightButton",
	Size = UDim2.fromOffset(110, 30),
	Position = UDim2.fromOffset(138, 34),
	Text = "Light",
	BackgroundColor3 = Color3.fromRGB(240, 240, 250),
	TextColor3 = Color3.fromRGB(30, 30, 40),
	TextSize = 13,
	ZIndex = 11,
})
addCorner(lightButton, 7)
local lightStroke = addStroke(lightButton, PALETTE.accent, 2)

local hidePartsLabel = makeLabel(settingsContentFrame, {
	Size = UDim2.fromOffset(150, 26),
	Position = UDim2.fromOffset(12, 74),
	Text = "Hide hitbox parts",
	TextColor3 = PALETTE.dark.textMuted,
	ZIndex = 11,
})

local hidePartsButton = makeButton(settingsContentFrame, {
	Name = "HidePartsToggle",
	Size = UDim2.fromOffset(96, 28),
	Position = UDim2.fromOffset(152, 72),
	Text = "OFF",
	BackgroundColor3 = PALETTE.off,
	TextSize = 12,
	ZIndex = 11,
})
addCorner(hidePartsButton, 7)

local restoreLabel = makeLabel(settingsContentFrame, {
	Size = UDim2.fromOffset(150, 26),
	Position = UDim2.fromOffset(12, 108),
	Text = "Restore on start",
	TextColor3 = PALETTE.dark.textMuted,
	ZIndex = 11,
})

local restoreButton = makeButton(settingsContentFrame, {
	Name = "RestoreToggle",
	Size = UDim2.fromOffset(96, 28),
	Position = UDim2.fromOffset(152, 106),
	Text = "OFF",
	BackgroundColor3 = PALETTE.off,
	TextSize = 12,
	ZIndex = 11,
})
addCorner(restoreButton, 7)

local restoreHint = makeLabel(settingsContentFrame, {
	Size = UDim2.new(1, -24, 0, 26),
	Position = UDim2.fromOffset(12, 138),
	Text = "Restore on start re-enables the saved toggles next launch.",
	TextColor3 = PALETTE.dark.textDim,
	TextSize = 10,
	TextWrapped = true,
	ZIndex = 11,
})

local keybindSectionLabel = makeLabel(settingsContentFrame, {
	Size = UDim2.new(1, -24, 0, 20),
	Position = UDim2.fromOffset(12, 172),
	Text = "Keybinds",
	TextColor3 = PALETTE.dark.textMuted,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	ZIndex = 11,
})

local keybindButtons = {}
local keybindStrokes = {}
local keybindLabels = {}

local function makeKeybindRow(action, yPosition)
	local rowLabel = makeLabel(settingsContentFrame, {
		Size = UDim2.fromOffset(132, 28),
		Position = UDim2.fromOffset(12, yPosition),
		Text = ACTION_LABELS[action],
		TextColor3 = PALETTE.dark.textDim,
		ZIndex = 11,
	})
	local rowButton = makeButton(settingsContentFrame, {
		Name = "KeybindButton_" .. action,
		Size = UDim2.fromOffset(96, 28),
		Position = UDim2.fromOffset(152, yPosition),
		Text = "None",
		TextSize = 12,
		ZIndex = 11,
	})
	addCorner(rowButton, 7)
	local rowStroke = addStroke(rowButton, PALETTE.dark.fieldBorder, 1)
	keybindLabels[action] = rowLabel
	keybindButtons[action] = rowButton
	keybindStrokes[action] = rowStroke
end

makeKeybindRow("hitbox", 196)
makeKeybindRow("esp", 230)
makeKeybindRow("gui", 264)
makeKeybindRow("minimize", 298)
makeKeybindRow("apply", 332)

local keybindHint = makeLabel(settingsContentFrame, {
	Size = UDim2.new(1, -24, 0, 26),
	Position = UDim2.fromOffset(12, 366),
	Text = "Click a bind, then press a key. Backspace clears it, Escape cancels.",
	TextColor3 = PALETTE.dark.textDim,
	TextSize = 10,
	TextWrapped = true,
	ZIndex = 11,
})

local resetPositionButton = makeButton(settingsContentFrame, {
	Name = "ResetPositionButton",
	Size = UDim2.fromOffset(120, 28),
	Position = UDim2.fromOffset(12, 398),
	Text = "Reset position",
	TextSize = 12,
	ZIndex = 11,
})
addCorner(resetPositionButton, 7)

local persistLabel = makeLabel(settingsContentFrame, {
	Name = "PersistLabel",
	Size = UDim2.new(1, -24, 0, 30),
	Position = UDim2.fromOffset(12, 432),
	Text = "",
	TextColor3 = PALETTE.dark.textDim,
	TextSize = 10,
	TextWrapped = true,
	ZIndex = 11,
})

local versionLabel = makeLabel(settingsContentFrame, {
	Name = "VersionLabel",
	Size = UDim2.new(1, -24, 0, 16),
	Position = UDim2.fromOffset(12, 466),
	Text = string.format("v%s · MIT", SCRIPT_VERSION),
	TextColor3 = PALETTE.dark.textDim,
	TextSize = 10,
	ZIndex = 11,
})

--------------------------------------------------------------------------------
-- Buttons: base colours and hover
--------------------------------------------------------------------------------

local buttonColors = {}

local function setButtonColor(targetButton, color, animate)
	buttonColors[targetButton] = color
	if animate then
		TweenService:Create(targetButton, BUTTON_TWEEN, { BackgroundColor3 = color }):Play()
	else
		targetButton.BackgroundColor3 = color
	end
end

local function bindButtonColor(targetButton, darkColor, lightColor)
	if darkColor == lightColor then
		buttonColors[targetButton] = darkColor
		targetButton.BackgroundColor3 = darkColor
	else
		buttonColors[targetButton] = settings.theme == "light" and lightColor or darkColor
		targetButton.BackgroundColor3 = buttonColors[targetButton]
	end
end

local function bindHover(targetButton)
	track(targetButton.MouseEnter:Connect(function()
		if state.closing then
			return
		end
		local base = buttonColors[targetButton] or targetButton.BackgroundColor3
		local hoverColor
		if settings.theme == "light" then
			hoverColor = base:Lerp(Color3.fromRGB(0, 0, 0), 0.08)
		else
			hoverColor = base:Lerp(Color3.fromRGB(255, 255, 255), 0.15)
		end
		TweenService:Create(targetButton, BUTTON_TWEEN, { BackgroundColor3 = hoverColor }):Play()
	end))
	track(targetButton.MouseLeave:Connect(function()
		local base = buttonColors[targetButton]
		if base and not state.unloading then
			TweenService:Create(targetButton, BUTTON_TWEEN, { BackgroundColor3 = base }):Play()
		end
	end))
end

local function syncButtonBases()
	for targetButton, _ in pairs(buttonColors) do
		if targetButton.Parent and not state.unloading then
			local base = buttonColors[targetButton]
			TweenService:Create(targetButton, THEME_TWEEN, { BackgroundColor3 = base }):Play()
		end
	end
end

bindButtonColor(settingsButton, PALETTE.dark.field, PALETTE.light.field)
bindButtonColor(minimizeButton, Color3.fromRGB(255, 200, 50), Color3.fromRGB(255, 200, 50))
bindButtonColor(closeButton, PALETTE.off, PALETTE.off)
bindButtonColor(applyButton, PALETTE.accent, PALETTE.accent)
bindButtonColor(hitboxToggle, PALETTE.off, PALETTE.off)
bindButtonColor(espToggle, PALETTE.off, PALETTE.off)
bindButtonColor(darkButton, PALETTE.dark.panelAlt, PALETTE.dark.panelAlt)
bindButtonColor(lightButton, Color3.fromRGB(240, 240, 250), Color3.fromRGB(240, 240, 250))
bindButtonColor(hidePartsButton, PALETTE.off, PALETTE.off)
bindButtonColor(restoreButton, PALETTE.off, PALETTE.off)
bindButtonColor(backButton, PALETTE.dark.field, PALETTE.light.field)
bindButtonColor(yesButton, PALETTE.on, PALETTE.on)
bindButtonColor(noButton, PALETTE.off, PALETTE.off)
bindButtonColor(resetPositionButton, PALETTE.dark.field, PALETTE.light.field)
for _, action in ipairs(ACTIONS) do
	bindButtonColor(keybindButtons[action], PALETTE.dark.field, PALETTE.light.field)
end

for _, targetButton in ipairs({
	settingsButton,
	minimizeButton,
	closeButton,
	applyButton,
	hitboxToggle,
	espToggle,
	darkButton,
	lightButton,
	hidePartsButton,
	restoreButton,
	backButton,
	yesButton,
	noButton,
	resetPositionButton,
	keybindButtons.hitbox,
	keybindButtons.esp,
	keybindButtons.gui,
	keybindButtons.minimize,
	keybindButtons.apply,
}) do
	bindHover(targetButton)
end

--------------------------------------------------------------------------------
-- Theme engine
--------------------------------------------------------------------------------

local themeBindings = {}

local function bindTheme(instance, property, darkValue, lightValue)
	table.insert(themeBindings, {
		instance = instance,
		property = property,
		dark = darkValue,
		light = lightValue,
	})
end

bindTheme(mainFrame, "BackgroundColor3", PALETTE.dark.panel, PALETTE.light.panel)
bindTheme(contentFrame, "BackgroundColor3", PALETTE.dark.panel, PALETTE.light.panel)
bindTheme(mainStroke, "Color", PALETTE.dark.border, PALETTE.light.border)
bindTheme(titleBar, "BackgroundColor3", PALETTE.dark.panelAlt, PALETTE.light.panelAlt)
bindTheme(titleFix, "BackgroundColor3", PALETTE.dark.panelAlt, PALETTE.light.panelAlt)
bindTheme(titleLabel, "TextColor3", PALETTE.dark.text, PALETTE.light.text)
bindTheme(sizeLabel, "TextColor3", PALETTE.dark.textMuted, PALETTE.light.textMuted)
bindTheme(sizeBox, "BackgroundColor3", PALETTE.dark.field, PALETTE.light.field)
bindTheme(sizeBox, "TextColor3", PALETTE.dark.text, PALETTE.light.text)
bindTheme(sizeBox, "PlaceholderColor3", PALETTE.dark.fieldBorder, PALETTE.light.fieldBorder)
bindTheme(sizeBoxStroke, "Color", PALETTE.dark.fieldBorder, PALETTE.light.fieldBorder)
bindTheme(statusLabel, "TextColor3", PALETTE.dark.textMuted, PALETTE.light.textMuted)
bindTheme(footerLabel, "TextColor3", PALETTE.dark.textDim, PALETTE.light.textDim)
bindTheme(footerLabelMinimized, "TextColor3", PALETTE.dark.textDim, PALETTE.light.textDim)
bindTheme(confirmFrame, "BackgroundColor3", PALETTE.dark.panel, PALETTE.light.panel)
bindTheme(confirmText, "TextColor3", PALETTE.dark.text, PALETTE.light.text)
bindTheme(settingsFrame, "BackgroundColor3", PALETTE.dark.panel, PALETTE.light.panel)
bindTheme(settingsTitleBar, "BackgroundColor3", PALETTE.dark.panelAlt, PALETTE.light.panelAlt)
bindTheme(settingsTitleFix, "BackgroundColor3", PALETTE.dark.panelAlt, PALETTE.light.panelAlt)
bindTheme(settingsTitleLabel, "TextColor3", PALETTE.dark.text, PALETTE.light.text)
bindTheme(themeLabel, "TextColor3", PALETTE.dark.textMuted, PALETTE.light.textMuted)
bindTheme(hidePartsLabel, "TextColor3", PALETTE.dark.textMuted, PALETTE.light.textMuted)
bindTheme(restoreLabel, "TextColor3", PALETTE.dark.textMuted, PALETTE.light.textMuted)
bindTheme(restoreHint, "TextColor3", PALETTE.dark.textDim, PALETTE.light.textDim)
bindTheme(keybindSectionLabel, "TextColor3", PALETTE.dark.textMuted, PALETTE.light.textMuted)
bindTheme(keybindHint, "TextColor3", PALETTE.dark.textDim, PALETTE.light.textDim)
bindTheme(persistLabel, "TextColor3", PALETTE.dark.textDim, PALETTE.light.textDim)
bindTheme(versionLabel, "TextColor3", PALETTE.dark.textDim, PALETTE.light.textDim)
bindTheme(settingsButton, "TextColor3", PALETTE.dark.text, PALETTE.light.text)
bindTheme(backButton, "TextColor3", PALETTE.dark.text, PALETTE.light.text)
bindTheme(resetPositionButton, "TextColor3", PALETTE.dark.text, PALETTE.light.text)
for _, action in ipairs(ACTIONS) do
	bindTheme(keybindButtons[action], "TextColor3", PALETTE.dark.text, PALETTE.light.text)
	bindTheme(keybindLabels[action], "TextColor3", PALETTE.dark.textDim, PALETTE.light.textDim)
end

local function renderSelectionStrokes()
	darkStroke.Transparency = settings.theme == "dark" and 0 or 1
	lightStroke.Transparency = settings.theme == "light" and 0 or 1
end

local function renderKeybindStrokes()
	local idleColor = settings.theme == "light" and PALETTE.light.fieldBorder or PALETTE.dark.fieldBorder
	for _, action in ipairs(ACTIONS) do
		local stroke = keybindStrokes[action]
		if state.listeningFor == action then
			stroke.Color = PALETTE.accent
		else
			stroke.Color = idleColor
		end
	end
end

local statusState = { isError = false, token = 0 }

local function renderStatusColors()
	if statusState.isError then
		statusLabel.TextColor3 = PALETTE.error
	elseif settings.theme == "light" then
		statusLabel.TextColor3 = PALETTE.light.textMuted
	else
		statusLabel.TextColor3 = PALETTE.dark.textMuted
	end
end

local function setStatus(text, isError)
	statusState.isError = isError == true
	statusState.token = statusState.token + 1
	local token = statusState.token
	statusLabel.Text = text or ""
	renderStatusColors()
	if text and text ~= "" then
		task.delay(2.5, function()
			if state.running and token == statusState.token then
				statusState.isError = false
				statusLabel.Text = ""
				renderStatusColors()
			end
		end)
	end
end

local function applyThemeVisuals(themeName, animate)
	for _, binding in ipairs(themeBindings) do
		if binding.instance.Parent then
			local target = themeName == "light" and binding.light or binding.dark
			if animate then
				TweenService:Create(binding.instance, THEME_TWEEN, { [binding.property] = target }):Play()
			else
				binding.instance[binding.property] = target
			end
		end
	end
	syncButtonBases()
	renderSelectionStrokes()
	renderKeybindStrokes()
	renderStatusColors()
end

local function setTheme(themeName, persist)
	if settings.theme == themeName then
		renderSelectionStrokes()
		return
	end
	settings.theme = themeName
	applyThemeVisuals(themeName, true)
	if persist then
		saveSettings()
	end
end

--------------------------------------------------------------------------------
-- Hitbox module
--------------------------------------------------------------------------------

local HITBOX_PART_NAMES = {
	"HumanoidRootPart",
	"Head",
	"Torso",
	"Left Arm",
	"Right Arm",
	"Left Leg",
	"Right Leg",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

-- snapshots[player] = { character = Model, parts = { [BasePart] = props } }
local snapshots = {}

local function getTeamColor(targetPlayer)
	if targetPlayer and targetPlayer.Team then
		return targetPlayer.TeamColor.Color
	end
	return Color3.fromRGB(255, 255, 255)
end

local function restoreSnapshot(snapshot)
	if not snapshot then
		return
	end
	for part, props in pairs(snapshot.parts) do
		if part.Parent then
			part.Size = props.size
			part.Transparency = props.transparency
			part.CanCollide = props.canCollide
			part.Color = props.color
			part.Material = props.material
			part.CastShadow = props.castShadow
		end
	end
end

local function clearSnapshot(targetPlayer)
	local snapshot = snapshots[targetPlayer]
	if not snapshot then
		return
	end
	restoreSnapshot(snapshot)
	snapshots[targetPlayer] = nil
end

local function restoreAllHitboxes()
	local targets = {}
	for targetPlayer in pairs(snapshots) do
		table.insert(targets, targetPlayer)
	end
	for _, targetPlayer in ipairs(targets) do
		clearSnapshot(targetPlayer)
	end
end

-- Snapshots are keyed by player and tied to a specific character. They are only
-- discarded when that character is replaced or destroyed, never because
-- character.Parent was briefly nil (games reparent characters all the time).
-- This is what stops an already-expanded character from being re-snapshotted
-- and "restored" to an enlarged size.
local function ensureSnapshot(targetPlayer, character)
	local snapshot = snapshots[targetPlayer]
	if snapshot and snapshot.character == character then
		return snapshot
	end
	if snapshot then
		clearSnapshot(targetPlayer)
	end
	local parts = {}
	for _, partName in ipairs(HITBOX_PART_NAMES) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			parts[part] = {
				size = part.Size,
				transparency = part.Transparency,
				canCollide = part.CanCollide,
				color = part.Color,
				material = part.Material,
				castShadow = part.CastShadow,
			}
		end
	end
	if next(parts) == nil then
		return nil
	end
	snapshot = { character = character, parts = parts }
	snapshots[targetPlayer] = snapshot
	return snapshot
end

local function setIfChanged(instance, property, value)
	if instance[property] ~= value then
		instance[property] = value
	end
end

local function applyHitbox(targetPlayer, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return
	end
	local snapshot = ensureSnapshot(targetPlayer, character)
	if not snapshot then
		return
	end
	local teamColor = getTeamColor(targetPlayer)
	for part in pairs(snapshot.parts) do
		if part.Parent then
			local scale
			if part.Name == "HumanoidRootPart" then
				scale = 1
			elseif part.Name == "Head" then
				scale = 0.8
			else
				scale = 0.7
			end
			local dimension = settings.hitboxSize * scale
			setIfChanged(part, "Size", Vector3.new(dimension, dimension, dimension))
			setIfChanged(part, "CanCollide", false)
			if part.Name == "HumanoidRootPart" then
				setIfChanged(part, "Transparency", 1)
			else
				setIfChanged(part, "Color", teamColor)
				setIfChanged(part, "Material", Enum.Material.SmoothPlastic)
				setIfChanged(part, "Transparency", settings.hideParts and 1 or 0.7)
			end
		end
	end
end

local function getCharacter(targetPlayer)
	local character = targetPlayer.Character
	if character and character.Parent then
		return character
	end
	return nil
end

local function updateHitboxes()
	if not state.hitboxEnabled then
		return
	end
	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if targetPlayer ~= player then
			local character = getCharacter(targetPlayer)
			if character then
				applyHitbox(targetPlayer, character)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- ESP module
--------------------------------------------------------------------------------

-- espEntries[player] = { character, billboard, highlight, infoLabel, displayLabel, ... }
local espEntries = {}

local function removeESP(targetPlayer)
	local entry = espEntries[targetPlayer]
	if not entry then
		return
	end
	espEntries[targetPlayer] = nil
	if entry.billboard then
		entry.billboard:Destroy()
	end
	if entry.highlight then
		entry.highlight:Destroy()
	end
end

local function removeAllESP()
	local targets = {}
	for targetPlayer in pairs(espEntries) do
		table.insert(targets, targetPlayer)
	end
	for _, targetPlayer in ipairs(targets) do
		removeESP(targetPlayer)
	end
end

local function getEspOrigin()
	local originPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if originPart then
		return originPart.Position
	end
	local camera = Workspace.CurrentCamera
	return camera and camera.CFrame.Position or nil
end

-- Fills in or refreshes the distance/health/team colour of one ESP entry.
-- Called both when the entry is created (so no label is ever blank) and from
-- the update loop.
local function refreshEspEntry(targetPlayer, entry, character, origin)
	local teamColor = getTeamColor(targetPlayer)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local distance = nil
	if origin and rootPart then
		distance = (origin - rootPart.Position).Magnitude
	end
	local healthText = ""
	if humanoid then
		healthText = formatHealth(humanoid.Health, humanoid.MaxHealth)
	end
	local text = buildEspLabel(distance, targetPlayer.Name, healthText, entry.hasDisplayName)
	if entry.lastText ~= text then
		entry.infoLabel.Text = text
		entry.lastText = text
	end
	if entry.lastColor ~= teamColor then
		if entry.displayLabel then
			entry.displayLabel.TextColor3 = teamColor
		else
			entry.infoLabel.TextColor3 = teamColor
		end
		entry.highlight.FillColor = teamColor
		entry.highlight.OutlineColor = teamColor
		entry.lastColor = teamColor
	end
end

local function createESP(targetPlayer)
	if targetPlayer == player then
		return
	end
	local character = targetPlayer.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return
	end
	local head = character:FindFirstChild("Head")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local attachPart = head or rootPart
	if not attachPart then
		return
	end

	removeESP(targetPlayer)

	local teamColor = getTeamColor(targetPlayer)
	local hasDisplayName = string.lower(targetPlayer.DisplayName) ~= string.lower(targetPlayer.Name)
	local guiHeight = hasDisplayName and 36 or 20

	local billboard = create("BillboardGui", {
		Name = "HitboxESP_" .. targetPlayer.Name,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(300, guiHeight),
		StudsOffset = Vector3.new(0, 3.2, 0),
	}, attachPart)

	local entry = {
		character = character,
		billboard = billboard,
		hasDisplayName = hasDisplayName,
		lastText = nil,
		lastColor = nil,
	}

	if hasDisplayName then
		entry.displayLabel = create("TextLabel", {
			Name = "DisplayLabel",
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Text = targetPlayer.DisplayName,
			TextColor3 = teamColor,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.3,
			TextSize = 14,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Center,
		}, billboard)
		entry.infoLabel = create("TextLabel", {
			Name = "InfoLabel",
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.fromOffset(0, 18),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = Color3.fromRGB(200, 200, 200),
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.3,
			TextSize = 11,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Center,
		}, billboard)
	else
		entry.infoLabel = create("TextLabel", {
			Name = "InfoLabel",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = teamColor,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.3,
			TextSize = 13,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Center,
		}, billboard)
	end

	entry.highlight = create("Highlight", {
		Adornee = character,
		FillColor = teamColor,
		FillTransparency = 0.5,
		OutlineColor = teamColor,
		OutlineTransparency = 0,
		-- Set explicitly: the engine default for DepthMode has changed before.
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	}, character)

	espEntries[targetPlayer] = entry
	refreshEspEntry(targetPlayer, entry, character, getEspOrigin())
end

local function updateESP()
	local origin = getEspOrigin()

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if targetPlayer ~= player then
			local character = getCharacter(targetPlayer)
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not character or (humanoid and humanoid.Health <= 0) then
				removeESP(targetPlayer)
			else
				local entry = espEntries[targetPlayer]
				if
					not entry
					or entry.character ~= character
					or not entry.billboard.Parent
					or not entry.highlight.Parent
				then
					createESP(targetPlayer)
					entry = espEntries[targetPlayer]
				end
				if entry then
					refreshEspEntry(targetPlayer, entry, character, origin)
				end
			end
		end
	end

	local removed = {}
	for targetPlayer in pairs(espEntries) do
		if not targetPlayer.Parent then
			table.insert(removed, targetPlayer)
		end
	end
	for _, targetPlayer in ipairs(removed) do
		removeESP(targetPlayer)
	end
end

--------------------------------------------------------------------------------
-- Toggles, status text and settings actions
--------------------------------------------------------------------------------

local function renderToggles()
	hitboxToggle.Text = state.hitboxEnabled and "Hitbox: ON" or "Hitbox: OFF"
	espToggle.Text = state.espEnabled and "ESP: ON" or "ESP: OFF"
	setButtonColor(hitboxToggle, state.hitboxEnabled and PALETTE.on or PALETTE.off, true)
	setButtonColor(espToggle, state.espEnabled and PALETTE.on or PALETTE.off, true)
	hidePartsButton.Text = settings.hideParts and "ON" or "OFF"
	setButtonColor(hidePartsButton, settings.hideParts and PALETTE.on or PALETTE.off, true)
	restoreButton.Text = settings.restoreEnabled and "ON" or "OFF"
	setButtonColor(restoreButton, settings.restoreEnabled and PALETTE.on or PALETTE.off, true)
end

local function renderKeybinds()
	for _, action in ipairs(ACTIONS) do
		local label = state.listeningFor == action and "Press a key..." or settings.keybinds[action]
		keybindButtons[action].Text = label or "None"
	end
	renderKeybindStrokes()
end

local function setHitboxEnabled(enabled, persist)
	state.hitboxEnabled = enabled
	if enabled then
		updateHitboxes()
	else
		restoreAllHitboxes()
	end
	renderToggles()
	if persist then
		settings.hitboxEnabled = enabled
		saveSettings()
	end
end

local function setEspEnabled(enabled, persist)
	state.espEnabled = enabled
	if enabled then
		for _, targetPlayer in ipairs(Players:GetPlayers()) do
			if targetPlayer ~= player then
				createESP(targetPlayer)
			end
		end
	else
		removeAllESP()
	end
	renderToggles()
	if persist then
		settings.espEnabled = enabled
		saveSettings()
	end
end

local function updatePersistLabel()
	local messages = {
		unavailable = "Persistence: unavailable (executor has no file API)",
		loaded = "Persistence: settings loaded",
		defaults = "Persistence: defaults (no saved file yet)",
		backup = "Persistence: recovered from backup",
		corrupt = "Persistence: saved file was corrupt, defaults restored",
		saved = "Persistence: saved",
		error = "Persistence: write failed (see console)",
	}
	persistLabel.Text = messages[persistStatus] or ("Persistence: " .. tostring(persistStatus))
end

local function flashButton(targetButton, color)
	local base = buttonColors[targetButton]
	if not base then
		return
	end
	TweenService:Create(targetButton, BUTTON_TWEEN, { BackgroundColor3 = color }):Play()
	task.delay(0.25, function()
		if state.running and targetButton.Parent and buttonColors[targetButton] == base then
			TweenService:Create(targetButton, BUTTON_TWEEN, { BackgroundColor3 = base }):Play()
		end
	end)
end

local function flashInvalidSize()
	TweenService:Create(sizeBoxStroke, BUTTON_TWEEN, { Color = PALETTE.error }):Play()
	task.delay(0.4, function()
		if state.running and sizeBoxStroke.Parent then
			local color = settings.theme == "light" and PALETTE.light.fieldBorder or PALETTE.dark.fieldBorder
			TweenService:Create(sizeBoxStroke, BUTTON_TWEEN, { Color = color }):Play()
		end
	end)
end

local function applySizeFromInput()
	if state.closing then
		return
	end
	local value, note = parseSizeInput(sizeBox.Text)
	if not value then
		setStatus(note or "Enter a number", true)
		flashInvalidSize()
		return
	end
	settings.hitboxSize = value
	sizeBox.Text = formatSize(value)
	if note then
		setStatus(note, false)
	else
		setStatus(string.format("Hitbox size: %s", formatSize(value)), false)
	end
	if state.hitboxEnabled then
		updateHitboxes()
	end
	saveSettings()
	flashButton(applyButton, Color3.fromRGB(50, 220, 120))
end

local function setMinimized(minimized)
	if state.minimized == minimized then
		return
	end
	state.minimized = minimized
	local targetHeight = minimized and MINIMIZED_HEIGHT or WINDOW_HEIGHT
	TweenService:Create(mainFrame, BUTTON_TWEEN, { Size = UDim2.fromOffset(WINDOW_WIDTH, targetHeight) }):Play()
	contentFrame.Visible = not minimized
	footerLabel.Visible = not minimized
	footerLabelMinimized.Visible = minimized
end

local function toggleMinimized()
	if state.closing or state.unloading then
		return
	end
	if confirmFrame.Visible or settingsFrame.Visible then
		return
	end
	setMinimized(not state.minimized)
end

local settingsToken = 0

local function setSettingsOpen(open)
	if state.closing then
		return
	end
	settingsToken = settingsToken + 1
	local token = settingsToken
	if open then
		if state.minimized then
			setMinimized(false)
		end
		settingsFrame.Visible = true
		settingsFrame.Position = UDim2.fromScale(1, 0)
		TweenService:Create(settingsFrame, OVERLAY_TWEEN, { Position = UDim2.fromScale(0, 0) }):Play()
		updatePersistLabel()
	else
		if state.listeningFor then
			state.listeningFor = nil
			renderKeybinds()
		end
		TweenService:Create(settingsFrame, OVERLAY_TWEEN, { Position = UDim2.fromScale(1, 0) }):Play()
		task.delay(0.2, function()
			if state.running and token == settingsToken then
				settingsFrame.Visible = false
			end
		end)
	end
end

local function setConfirmOpen(open)
	confirmFrame.Visible = open
	if open then
		confirmFrame.BackgroundTransparency = 1
		TweenService:Create(confirmFrame, BUTTON_TWEEN, { BackgroundTransparency = 0.05 }):Play()
	end
end

local function setGuiVisible(visible)
	state.guiVisible = visible
	screenGui.Enabled = visible
end

local function setListening(action)
	if state.listeningFor == action then
		state.listeningFor = nil
	else
		state.listeningFor = action
	end
	renderKeybinds()
end

local function assignKeybind(action, keyName)
	if keyName == "Unknown" then
		return
	end
	applyKeybindToTable(settings.keybinds, action, keyName)
	state.listeningFor = nil
	renderKeybinds()
	saveSettings()
	if keyName == "None" then
		setStatus(string.format("%s: cleared", ACTION_LABELS[action]), false)
	else
		setStatus(string.format("%s: %s", ACTION_LABELS[action], keyName), false)
	end
end

local function validateKeybindsAgainstEnum()
	for _, action in ipairs(ACTIONS) do
		local name = settings.keybinds[action]
		if name ~= "None" then
			local ok, keyCode = pcall(function()
				return Enum.KeyCode[name]
			end)
			if not ok or not keyCode then
				settings.keybinds[action] = "None"
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Window position
--------------------------------------------------------------------------------

-- x and y are screen coordinates (the same space as AbsolutePosition).
local function setFramePosition(x, y)
	local viewport = getViewport()
	local size = mainFrame.AbsoluteSize
	local width = size.X > 0 and size.X or WINDOW_WIDTH
	local height = size.Y > 0 and size.Y or WINDOW_HEIGHT
	local clampedX, clampedY = clampWindowPosition(x, y, width, height, viewport.X, viewport.Y)
	local inset = getGuiInset()
	-- Never park the title bar (the only drag handle) under the Roblox topbar.
	clampedY = math.max(clampedY, inset.Y)
	mainFrame.Position = UDim2.fromOffset(clampedX - inset.X, clampedY - inset.Y)
end

local function saveWindowPosition()
	local position = mainFrame.AbsolutePosition
	settings.windowPosition = {
		x = math.floor(position.X),
		y = math.floor(position.Y),
	}
	saveSettings()
end

local function placeWindow()
	local viewport = getViewport()
	local size = mainFrame.AbsoluteSize
	local width = size.X > 0 and size.X or WINDOW_WIDTH
	local height = size.Y > 0 and size.Y or WINDOW_HEIGHT
	if settings.windowPosition then
		setFramePosition(settings.windowPosition.x, settings.windowPosition.y)
	else
		setFramePosition((viewport.X - width) / 2, (viewport.Y - height) / 2)
	end
end

--------------------------------------------------------------------------------
-- Player and character tracking
--------------------------------------------------------------------------------

local playerConnections = {}
local characterConnections = {}

local function watchCharacter(targetPlayer, character)
	local previous = characterConnections[targetPlayer]
	if previous then
		previous:Disconnect()
		characterConnections[targetPlayer] = nil
	end
	characterConnections[targetPlayer] = character.Destroying:Connect(function()
		local snapshot = snapshots[targetPlayer]
		if snapshot and snapshot.character == character then
			-- The parts are gone; there is nothing left to restore.
			snapshots[targetPlayer] = nil
		end
		local entry = espEntries[targetPlayer]
		if entry and entry.character == character then
			removeESP(targetPlayer)
		end
		local connection = characterConnections[targetPlayer]
		if connection then
			connection:Disconnect()
			characterConnections[targetPlayer] = nil
		end
	end)
end

local function onCharacterAdded(targetPlayer, character)
	clearSnapshot(targetPlayer)
	removeESP(targetPlayer)
	watchCharacter(targetPlayer, character)
	task.delay(RESPAWN_DELAY, function()
		if not state.running or state.closing then
			return
		end
		if targetPlayer.Parent == nil or targetPlayer.Character ~= character or not character.Parent then
			return
		end
		if state.hitboxEnabled then
			applyHitbox(targetPlayer, character)
		end
		if state.espEnabled then
			createESP(targetPlayer)
		end
	end)
end

local function setupPlayer(targetPlayer)
	if targetPlayer == player or playerConnections[targetPlayer] then
		return
	end
	playerConnections[targetPlayer] = targetPlayer.CharacterAdded:Connect(function(character)
		onCharacterAdded(targetPlayer, character)
	end)
	local character = targetPlayer.Character
	if character then
		onCharacterAdded(targetPlayer, character)
	end
end

local function teardownPlayer(targetPlayer)
	clearSnapshot(targetPlayer)
	removeESP(targetPlayer)
	local playerConnection = playerConnections[targetPlayer]
	if playerConnection then
		playerConnection:Disconnect()
		playerConnections[targetPlayer] = nil
	end
	local characterConnection = characterConnections[targetPlayer]
	if characterConnection then
		characterConnection:Disconnect()
		characterConnections[targetPlayer] = nil
	end
end

--------------------------------------------------------------------------------
-- Unload (single teardown path)
--------------------------------------------------------------------------------

local unload
local api

function unload()
	if state.unloading then
		return
	end
	state.unloading = true
	state.running = false
	state.closing = true
	state.listeningFor = nil
	state.hitboxEnabled = false
	state.espEnabled = false
	restoreAllHitboxes()
	removeAllESP()
	screenGui.Enabled = false
	for _, connection in ipairs(connections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	connections = {}
	for _, connection in pairs(playerConnections) do
		connection:Disconnect()
	end
	playerConnections = {}
	for _, connection in pairs(characterConnections) do
		connection:Disconnect()
	end
	characterConnections = {}
	screenGui:Destroy()
	if shared and shared.HitboxESP == api then
		shared.HitboxESP = nil
	end
end

local function requestClose()
	if state.closing or state.unloading then
		return
	end
	if settingsFrame.Visible then
		return
	end
	if state.minimized then
		setMinimized(false)
	end
	setConfirmOpen(true)
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

local function handleKeyPress(input, gameProcessed)
	if not state.running or state.unloading or state.closing then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	local keyName = input.KeyCode.Name

	if state.listeningFor then
		if keyName == "Escape" then
			state.listeningFor = nil
			renderKeybinds()
			return
		end
		-- Do not capture keys that the game consumed (chat, menus) or that were
		-- typed into a text field. Otherwise "press a key" binds a letter the
		-- player meant for chat.
		if gameProcessed or UserInputService:GetFocusedTextBox() then
			return
		end
		if keyName == "Backspace" or keyName == "Delete" then
			assignKeybind(state.listeningFor, "None")
			return
		end
		assignKeybind(state.listeningFor, keyName)
		return
	end

	if keyName == "Escape" then
		if confirmFrame.Visible then
			setConfirmOpen(false)
			return
		end
		if settingsFrame.Visible then
			setSettingsOpen(false)
			return
		end
	end

	if gameProcessed then
		return
	end
	if UserInputService:GetFocusedTextBox() then
		return
	end

	local binds = settings.keybinds
	if binds.hitbox ~= "None" and binds.hitbox == keyName then
		setHitboxEnabled(not state.hitboxEnabled, true)
	elseif binds.esp ~= "None" and binds.esp == keyName then
		setEspEnabled(not state.espEnabled, true)
	elseif binds.gui ~= "None" and binds.gui == keyName then
		setGuiVisible(not state.guiVisible)
	elseif binds.minimize ~= "None" and binds.minimize == keyName then
		toggleMinimized()
	elseif binds.apply ~= "None" and binds.apply == keyName then
		applySizeFromInput()
	end
end

--------------------------------------------------------------------------------
-- UI event wiring
--------------------------------------------------------------------------------

track(applyButton.MouseButton1Click:Connect(applySizeFromInput))
track(hitboxToggle.MouseButton1Click:Connect(function()
	setHitboxEnabled(not state.hitboxEnabled, true)
end))
track(espToggle.MouseButton1Click:Connect(function()
	setEspEnabled(not state.espEnabled, true)
end))
track(hidePartsButton.MouseButton1Click:Connect(function()
	settings.hideParts = not settings.hideParts
	renderToggles()
	if state.hitboxEnabled then
		updateHitboxes()
	end
	saveSettings()
end))
track(restoreButton.MouseButton1Click:Connect(function()
	settings.restoreEnabled = not settings.restoreEnabled
	renderToggles()
	saveSettings()
end))
track(minimizeButton.MouseButton1Click:Connect(toggleMinimized))
track(closeButton.MouseButton1Click:Connect(requestClose))
track(settingsButton.MouseButton1Click:Connect(function()
	setSettingsOpen(true)
end))
track(backButton.MouseButton1Click:Connect(function()
	setSettingsOpen(false)
end))
track(darkButton.MouseButton1Click:Connect(function()
	setTheme("dark", true)
end))
track(lightButton.MouseButton1Click:Connect(function()
	setTheme("light", true)
end))
track(resetPositionButton.MouseButton1Click:Connect(function()
	settings.windowPosition = nil
	placeWindow()
	saveWindowPosition()
	setStatus("Window position reset", false)
end))
track(yesButton.MouseButton1Click:Connect(function()
	unload()
end))
track(noButton.MouseButton1Click:Connect(function()
	setConfirmOpen(false)
end))

for _, action in ipairs(ACTIONS) do
	local capturedAction = action
	track(keybindButtons[capturedAction].MouseButton1Click:Connect(function()
		setListening(capturedAction)
	end))
end

track(sizeBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		applySizeFromInput()
	end
end))

track(UserInputService.InputBegan:Connect(handleKeyPress))

-- Dragging: one global InputChanged/InputEnded handler instead of connecting a
-- new input.Changed listener on every mouse-down.
local drag = { active = false, moved = false, startX = 0, startY = 0, originX = 0, originY = 0 }

track(titleBar.InputBegan:Connect(function(input)
	if not state.running or not state.guiVisible or state.closing then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local position = mainFrame.AbsolutePosition
		drag.active = true
		drag.moved = false
		drag.startX = input.Position.X
		drag.startY = input.Position.Y
		drag.originX = position.X
		drag.originY = position.Y
	end
end))

track(UserInputService.InputChanged:Connect(function(input)
	if not drag.active or not state.guiVisible then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local deltaX = input.Position.X - drag.startX
	local deltaY = input.Position.Y - drag.startY
	if math.abs(deltaX) > 1 or math.abs(deltaY) > 1 then
		drag.moved = true
	end
	setFramePosition(drag.originX + deltaX, drag.originY + deltaY)
end))

track(UserInputService.InputEnded:Connect(function(input)
	if not drag.active then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		drag.active = false
		if drag.moved then
			saveWindowPosition()
		end
	end
end))

-- Keep the window on screen when the viewport changes.
local camera = Workspace.CurrentCamera
if camera then
	track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if state.running and not state.unloading and not drag.active then
			updateUiScale()
			local position = mainFrame.AbsolutePosition
			setFramePosition(position.X, position.Y)
		end
	end))
end

--------------------------------------------------------------------------------
-- Startup
--------------------------------------------------------------------------------

validateKeybindsAgainstEnum()
updatePersistLabel()
renderToggles()
renderKeybinds()
applyThemeVisuals(settings.theme, false)
updateUiScale()
setFramePosition(
	settings.windowPosition and settings.windowPosition.x or (getViewport().X - WINDOW_WIDTH) / 2,
	settings.windowPosition and settings.windowPosition.y or (getViewport().Y - WINDOW_HEIGHT) / 2
)
screenGui.Enabled = true
task.defer(function()
	if state.running then
		placeWindow()
	end
end)

for _, targetPlayer in ipairs(Players:GetPlayers()) do
	setupPlayer(targetPlayer)
end
track(Players.PlayerAdded:Connect(setupPlayer))
track(Players.PlayerRemoving:Connect(teardownPlayer))

if settings.restoreEnabled then
	if settings.hitboxEnabled then
		setHitboxEnabled(true, false)
	end
	if settings.espEnabled then
		setEspEnabled(true, false)
	end
end

if persistStatus == "unavailable" then
	setStatus("No file API: settings will not persist", true)
elseif persistStatus == "corrupt" then
	setStatus("Corrupt settings; defaults restored", true)
elseif persistStatus == "backup" then
	setStatus("Recovered settings from backup", false)
end

-- One throttled loop; it exits as soon as unload sets state.running to false.
task.spawn(function()
	while state.running do
		task.wait(UPDATE_INTERVAL)
		if not state.running then
			break
		end
		if state.hitboxEnabled then
			updateHitboxes()
		end
		if state.espEnabled then
			updateESP()
		end
	end
end)

api = {
	version = SCRIPT_VERSION,
	unload = unload,
}
if shared then
	shared.HitboxESP = api
end
