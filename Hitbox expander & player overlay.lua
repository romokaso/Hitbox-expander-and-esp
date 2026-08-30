local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local APP_NAME = "Hitbox expander & player overlay"
local GUI_NAME = "HitboxExpanderPlayerOverlay"
local LEGACY_GUI_NAMES = {
	"HitboxExpander",
	"HitboxChanger",
}
local RUNTIME_KEY = "__HitboxExpanderPlayerOverlayRuntime"
local SETTINGS_FILE = "hitbox_expander_player_overlay_settings.json"
local LEGACY_SETTINGS_FILES = {
	"hitbox_expander_settings.json",
	"hitbox_settings.json",
}
local MIN_EXPANSION_SIZE = 1
local MAX_EXPANSION_SIZE = 100
local EXPANSION_UPDATE_INTERVAL = 1 / 30
local OVERLAY_UPDATE_INTERVAL = 0.1
local DEFAULT_TARGET_MODE = "players"
local VALID_TARGET_MODES = {
	all = true,
	players = true,
	npcs = true,
}

local runtimeEnvironment = _G
if type(getgenv) == "function" then
	local ok, environment = pcall(getgenv)
	if ok and type(environment) == "table" then
		runtimeEnvironment = environment
	end
end

local previousShutdown = nil
pcall(function()
	previousShutdown = runtimeEnvironment[RUNTIME_KEY]
end)
if type(previousShutdown) == "function" then
	pcall(previousShutdown)
end
pcall(function()
	runtimeEnvironment[RUNTIME_KEY] = nil
end)

local guiNamesToReplace = {[GUI_NAME] = true}
for _, legacyGuiName in ipairs(LEGACY_GUI_NAMES) do
	guiNamesToReplace[legacyGuiName] = true
end
for _, existingGui in ipairs(playerGui:GetChildren()) do
	if guiNamesToReplace[existingGui.Name] and existingGui:IsA("ScreenGui") then
		pcall(function()
			existingGui:Destroy()
		end)
	end
end

local function isFiniteNumber(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function normalizeExpansionSize(value)
	if type(value) ~= "number" and type(value) ~= "string" then return nil end
	local numberValue = tonumber(value)
	if not isFiniteNumber(numberValue) then return nil end
	return math.clamp(numberValue, MIN_EXPANSION_SIZE, MAX_EXPANSION_SIZE)
end

local function saveSettings(data)
	if type(writefile) ~= "function" then return false end
	local ok = pcall(function()
		writefile(SETTINGS_FILE, HttpService:JSONEncode(data))
	end)
	return ok
end

local function readSettingsFile(fileName)
	local confirmedExistingFile = false
	if type(isfile) == "function" then
		local checkedFile, fileExists = pcall(isfile, fileName)
		if checkedFile then
			if not fileExists then return nil, false end
			confirmedExistingFile = true
		end
	end

	local readOk, contents = pcall(readfile, fileName)
	if not readOk then return nil, confirmedExistingFile end
	local decodeOk, result = pcall(function()
		return HttpService:JSONDecode(contents)
	end)
	if decodeOk and type(result) == "table" then return result, false end
	return nil, true
end

local function loadSettings()
	if type(readfile) ~= "function" then return nil, false end
	local currentSettings, currentSettingsInvalid = readSettingsFile(SETTINGS_FILE)
	if currentSettings then return currentSettings, false end

	local invalidSettingsFound = currentSettingsInvalid
	for _, legacyFileName in ipairs(LEGACY_SETTINGS_FILES) do
		local legacySettings, legacySettingsInvalid = readSettingsFile(legacyFileName)
		if legacySettings then return legacySettings, true end
		invalidSettingsFound = invalidSettingsFound or legacySettingsInvalid
	end
	return nil, invalidSettingsFound
end

local savedData, settingsNeedMigration = loadSettings()
if type(savedData) == "table" then
	local savedKeybinds = savedData.keybinds
	settingsNeedMigration = settingsNeedMigration
		or savedData.hitboxSize ~= nil
		or savedData["disableTransparency"] ~= nil
		or (type(savedKeybinds) == "table" and (
			savedKeybinds.hitbox ~= nil
			or savedKeybinds.esp ~= nil
			or savedKeybinds.apply ~= nil
		))
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 260, 0, 180)
mainFrame.Position = UDim2.new(0.5, -130, 0.5, -90)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

addCorner(mainFrame, UDim.new(0, 12))

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(60, 60, 70)
mainStroke.Thickness = 2
mainStroke.Transparency = 0.5
mainStroke.Parent = mainFrame

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 35)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

addCorner(titleBar, UDim.new(0, 12))

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 12)
titleFix.Position = UDim2.new(0, 0, 1, -12)
titleFix.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
titleFix.BorderSizePixel = 0
titleFix.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -100, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Active = true
titleLabel.Text = APP_NAME
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 15
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local titleTextSizeConstraint = Instance.new("UITextSizeConstraint")
titleTextSizeConstraint.MinTextSize = 8
titleTextSizeConstraint.MaxTextSize = 15
titleTextSizeConstraint.Parent = titleLabel

local settingsButtonTop = Instance.new("TextButton")
settingsButtonTop.Name = "SettingsButtonTop"
settingsButtonTop.Size = UDim2.new(0, 26, 0, 26)
settingsButtonTop.Position = UDim2.new(1, -90, 0, 4)
settingsButtonTop.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
settingsButtonTop.BorderSizePixel = 0
settingsButtonTop.Text = "⚙"
settingsButtonTop.TextColor3 = Color3.fromRGB(255, 255, 255)
settingsButtonTop.TextSize = 14
settingsButtonTop.Font = Enum.Font.GothamBold
settingsButtonTop.Parent = titleBar

addCorner(settingsButtonTop, UDim.new(0, 6))

local minimizeButton = Instance.new("TextButton")
minimizeButton.Name = "MinimizeButton"
minimizeButton.Size = UDim2.new(0, 26, 0, 26)
minimizeButton.Position = UDim2.new(1, -58, 0, 4)
minimizeButton.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
minimizeButton.BorderSizePixel = 0
minimizeButton.Text = "_"
minimizeButton.TextColor3 = Color3.fromRGB(0, 0, 0)
minimizeButton.TextSize = 14
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.Parent = titleBar

addCorner(minimizeButton, UDim.new(0, 6))

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 26, 0, 26)
closeButton.Position = UDim2.new(1, -28, 0, 4)
closeButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
closeButton.BorderSizePixel = 0
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 13
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = titleBar

addCorner(closeButton, UDim.new(0, 6))

local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, 0, 1, -35)
contentFrame.Position = UDim2.new(0, 0, 0, 35)
contentFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
contentFrame.BorderSizePixel = 0
contentFrame.Parent = mainFrame

local expansionSizeLabel = Instance.new("TextLabel")
expansionSizeLabel.Size = UDim2.new(0, 96, 0, 22)
expansionSizeLabel.Position = UDim2.new(0, 12, 0, 8)
expansionSizeLabel.BackgroundTransparency = 1
expansionSizeLabel.Text = "Expansion size:"
expansionSizeLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
expansionSizeLabel.TextSize = 12
expansionSizeLabel.Font = Enum.Font.Gotham
expansionSizeLabel.TextXAlignment = Enum.TextXAlignment.Left
expansionSizeLabel.Parent = contentFrame

local expansionSizeInput = Instance.new("TextBox")
expansionSizeInput.Size = UDim2.new(0, 60, 0, 28)
expansionSizeInput.Position = UDim2.new(0, 110, 0, 6)
expansionSizeInput.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
expansionSizeInput.BorderSizePixel = 0
expansionSizeInput.Text = "10"
expansionSizeInput.PlaceholderText = "Size"
expansionSizeInput.TextColor3 = Color3.fromRGB(255, 255, 255)
expansionSizeInput.TextSize = 12
expansionSizeInput.Font = Enum.Font.Gotham
expansionSizeInput.Parent = contentFrame

addCorner(expansionSizeInput, UDim.new(0, 7))

local expansionSizeInputStroke = Instance.new("UIStroke")
expansionSizeInputStroke.Color = Color3.fromRGB(80, 80, 90)
expansionSizeInputStroke.Thickness = 1
expansionSizeInputStroke.Parent = expansionSizeInput

local applyExpansionButton = Instance.new("TextButton")
applyExpansionButton.Size = UDim2.new(0, 76, 0, 28)
applyExpansionButton.Position = UDim2.new(0, 172, 0, 6)
applyExpansionButton.BackgroundColor3 = Color3.fromRGB(80, 150, 255)
applyExpansionButton.BorderSizePixel = 0
applyExpansionButton.Text = "Apply"
applyExpansionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
applyExpansionButton.TextSize = 12
applyExpansionButton.Font = Enum.Font.GothamBold
applyExpansionButton.Parent = contentFrame

addCorner(applyExpansionButton, UDim.new(0, 7))

local expanderToggleButton = Instance.new("TextButton")
expanderToggleButton.Size = UDim2.new(0, 236, 0, 32)
expanderToggleButton.Position = UDim2.new(0, 12, 0, 42)
expanderToggleButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
expanderToggleButton.BorderSizePixel = 0
expanderToggleButton.Text = "Hitbox expansion: OFF"
expanderToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
expanderToggleButton.TextSize = 13
expanderToggleButton.Font = Enum.Font.GothamBold
expanderToggleButton.Parent = contentFrame

addCorner(expanderToggleButton, UDim.new(0, 7))

local overlayToggleButton = Instance.new("TextButton")
overlayToggleButton.Size = UDim2.new(0, 198, 0, 32)
overlayToggleButton.Position = UDim2.new(0, 12, 0, 80)
overlayToggleButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
overlayToggleButton.BorderSizePixel = 0
overlayToggleButton.Text = "Player overlay: OFF"
overlayToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
overlayToggleButton.TextSize = 13
overlayToggleButton.Font = Enum.Font.GothamBold
overlayToggleButton.Parent = contentFrame

addCorner(overlayToggleButton, UDim.new(0, 7))

local targetModeButton = Instance.new("TextButton")
targetModeButton.Name = "TargetModeButton"
targetModeButton.Size = UDim2.new(0, 32, 0, 32)
targetModeButton.Position = UDim2.new(0, 216, 0, 80)
targetModeButton.BackgroundColor3 = Color3.fromRGB(80, 150, 255)
targetModeButton.BorderSizePixel = 0
targetModeButton.Text = "◎P"
targetModeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
targetModeButton.TextSize = 12
targetModeButton.Font = Enum.Font.GothamBold
targetModeButton.Parent = contentFrame

addCorner(targetModeButton, UDim.new(0, 7))

local footerLabel = Instance.new("TextButton")
footerLabel.Size = UDim2.new(1, 0, 0, 25)
footerLabel.Position = UDim2.new(0, 0, 1, -25)
footerLabel.BackgroundTransparency = 1
footerLabel.Text = "by: romokaso"
footerLabel.TextColor3 = Color3.fromRGB(120, 120, 130)
footerLabel.TextSize = 10
footerLabel.Font = Enum.Font.GothamBold
footerLabel.Parent = contentFrame

local footerLabelMinimized = Instance.new("TextButton")
footerLabelMinimized.Size = UDim2.new(1, 0, 0, 25)
footerLabelMinimized.Position = UDim2.new(0, 0, 0, 35)
footerLabelMinimized.BackgroundTransparency = 1
footerLabelMinimized.Text = "by: romokaso"
footerLabelMinimized.TextColor3 = Color3.fromRGB(120, 120, 130)
footerLabelMinimized.TextSize = 10
footerLabelMinimized.Font = Enum.Font.GothamBold
footerLabelMinimized.Visible = false
footerLabelMinimized.Parent = mainFrame

local confirmFrame = Instance.new("Frame")
confirmFrame.Name = "ConfirmFrame"
confirmFrame.Size = UDim2.new(1, 0, 1, 0)
confirmFrame.Position = UDim2.new(0, 0, 0, 0)
confirmFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
confirmFrame.BackgroundTransparency = 1
confirmFrame.BorderSizePixel = 0
confirmFrame.Active = true
confirmFrame.Visible = false
confirmFrame.ZIndex = 10
confirmFrame.Parent = mainFrame

addCorner(confirmFrame, UDim.new(0, 12))

local confirmText = Instance.new("TextLabel")
confirmText.Size = UDim2.new(1, -24, 0, 40)
confirmText.Position = UDim2.new(0, 12, 0, 45)
confirmText.BackgroundTransparency = 1
confirmText.Text = "Are you sure you want\nto close the GUI?"
confirmText.TextColor3 = Color3.fromRGB(255, 255, 255)
confirmText.TextSize = 13
confirmText.Font = Enum.Font.GothamBold
confirmText.TextWrapped = true
confirmText.ZIndex = 11
confirmText.Parent = confirmFrame

local yesButton = Instance.new("TextButton")
yesButton.Size = UDim2.new(0, 105, 0, 32)
yesButton.Position = UDim2.new(0, 20, 0, 100)
yesButton.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
yesButton.BorderSizePixel = 0
yesButton.Text = "Yes"
yesButton.TextColor3 = Color3.fromRGB(255, 255, 255)
yesButton.TextSize = 13
yesButton.Font = Enum.Font.GothamBold
yesButton.ZIndex = 11
yesButton.Parent = confirmFrame

addCorner(yesButton, UDim.new(0, 7))

local noButton = Instance.new("TextButton")
noButton.Size = UDim2.new(0, 105, 0, 32)
noButton.Position = UDim2.new(0, 135, 0, 100)
noButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
noButton.BorderSizePixel = 0
noButton.Text = "No"
noButton.TextColor3 = Color3.fromRGB(255, 255, 255)
noButton.TextSize = 13
noButton.Font = Enum.Font.GothamBold
noButton.ZIndex = 11
noButton.Parent = confirmFrame

addCorner(noButton, UDim.new(0, 7))

local targetFrame = Instance.new("Frame")
targetFrame.Name = "TargetFrame"
targetFrame.Size = UDim2.new(1, 0, 1, 0)
targetFrame.Position = UDim2.new(1, 0, 0, 0)
targetFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
targetFrame.BorderSizePixel = 0
targetFrame.Active = true
targetFrame.Visible = false
targetFrame.ZIndex = 10
targetFrame.Parent = mainFrame

addCorner(targetFrame, UDim.new(0, 12))

local targetTitleBar = Instance.new("Frame")
targetTitleBar.Size = UDim2.new(1, 0, 0, 35)
targetTitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
targetTitleBar.BorderSizePixel = 0
targetTitleBar.ZIndex = 11
targetTitleBar.Parent = targetFrame

addCorner(targetTitleBar, UDim.new(0, 12))

local targetTitleFix = Instance.new("Frame")
targetTitleFix.Size = UDim2.new(1, 0, 0, 12)
targetTitleFix.Position = UDim2.new(0, 0, 1, -12)
targetTitleFix.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
targetTitleFix.BorderSizePixel = 0
targetTitleFix.ZIndex = 11
targetTitleFix.Parent = targetTitleBar

local targetTitleLabel = Instance.new("TextLabel")
targetTitleLabel.Size = UDim2.new(1, -50, 1, 0)
targetTitleLabel.Position = UDim2.new(0, 10, 0, 0)
targetTitleLabel.BackgroundTransparency = 1
targetTitleLabel.Active = true
targetTitleLabel.Text = "Target selection"
targetTitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
targetTitleLabel.TextSize = 15
targetTitleLabel.Font = Enum.Font.GothamBold
targetTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
targetTitleLabel.ZIndex = 11
targetTitleLabel.Parent = targetTitleBar

local targetBackButton = Instance.new("TextButton")
targetBackButton.Size = UDim2.new(0, 26, 0, 26)
targetBackButton.Position = UDim2.new(1, -28, 0, 4)
targetBackButton.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
targetBackButton.BorderSizePixel = 0
targetBackButton.Text = "←"
targetBackButton.TextColor3 = Color3.fromRGB(255, 255, 255)
targetBackButton.TextSize = 14
targetBackButton.Font = Enum.Font.GothamBold
targetBackButton.ZIndex = 11
targetBackButton.Parent = targetTitleBar

addCorner(targetBackButton, UDim.new(0, 6))

local targetModeButtons = {}
local targetModeButtonDefinitions = {
	{"all", "All"},
	{"players", "Players"},
	{"npcs", "NPC"},
}
for index, definition in ipairs(targetModeButtonDefinitions) do
	local mode = definition[1]
	local modeButton = Instance.new("TextButton")
	modeButton.Name = "Target_" .. mode
	modeButton.Size = UDim2.new(0, 236, 0, 30)
	modeButton.Position = UDim2.new(0, 12, 0, 43 + (index - 1) * 38)
	modeButton.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	modeButton.BorderSizePixel = 0
	modeButton.Text = definition[2]
	modeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	modeButton.TextSize = 13
	modeButton.Font = Enum.Font.GothamBold
	modeButton.ZIndex = 11
	modeButton.Parent = targetFrame

	local modeCorner = Instance.new("UICorner")
	modeCorner.CornerRadius = UDim.new(0, 7)
	modeCorner.Parent = modeButton
	targetModeButtons[mode] = modeButton
end

local settingsFrame = Instance.new("Frame")
settingsFrame.Name = "SettingsFrame"
settingsFrame.Size = UDim2.new(1, 0, 1, 0)
settingsFrame.Position = UDim2.new(1, 0, 0, 0)
settingsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
settingsFrame.BorderSizePixel = 0
settingsFrame.Active = true
settingsFrame.Visible = false
settingsFrame.ZIndex = 10
settingsFrame.Parent = mainFrame

addCorner(settingsFrame, UDim.new(0, 12))

local settingsTitleBar = Instance.new("Frame")
settingsTitleBar.Size = UDim2.new(1, 0, 0, 35)
settingsTitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
settingsTitleBar.BorderSizePixel = 0
settingsTitleBar.ZIndex = 11
settingsTitleBar.Parent = settingsFrame

addCorner(settingsTitleBar, UDim.new(0, 12))

local settingsTitleFix = Instance.new("Frame")
settingsTitleFix.Size = UDim2.new(1, 0, 0, 12)
settingsTitleFix.Position = UDim2.new(0, 0, 1, -12)
settingsTitleFix.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
settingsTitleFix.BorderSizePixel = 0
settingsTitleFix.ZIndex = 11
settingsTitleFix.Parent = settingsTitleBar

local settingsTitleLabel = Instance.new("TextLabel")
settingsTitleLabel.Size = UDim2.new(1, -50, 1, 0)
settingsTitleLabel.Position = UDim2.new(0, 10, 0, 0)
settingsTitleLabel.BackgroundTransparency = 1
settingsTitleLabel.Active = true
settingsTitleLabel.Text = "Settings"
settingsTitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
settingsTitleLabel.TextSize = 15
settingsTitleLabel.Font = Enum.Font.GothamBold
settingsTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
settingsTitleLabel.ZIndex = 11
settingsTitleLabel.Parent = settingsTitleBar

local backButton = Instance.new("TextButton")
backButton.Size = UDim2.new(0, 26, 0, 26)
backButton.Position = UDim2.new(1, -28, 0, 4)
backButton.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
backButton.BorderSizePixel = 0
backButton.Text = "←"
backButton.TextColor3 = Color3.fromRGB(255, 255, 255)
backButton.TextSize = 14
backButton.Font = Enum.Font.GothamBold
backButton.ZIndex = 11
backButton.Parent = settingsTitleBar

addCorner(backButton, UDim.new(0, 6))

local settingsContentFrame = Instance.new("ScrollingFrame")
settingsContentFrame.Size = UDim2.new(1, 0, 1, -35)
settingsContentFrame.Position = UDim2.new(0, 0, 0, 35)
settingsContentFrame.BackgroundTransparency = 1
settingsContentFrame.BorderSizePixel = 0
settingsContentFrame.ZIndex = 11
settingsContentFrame.ScrollBarThickness = 3
settingsContentFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 150, 255)
settingsContentFrame.CanvasSize = UDim2.new(0, 0, 0, 350)
settingsContentFrame.Parent = settingsFrame

local themeLabel = Instance.new("TextLabel")
themeLabel.Size = UDim2.new(1, -24, 0, 22)
themeLabel.Position = UDim2.new(0, 12, 0, 10)
themeLabel.BackgroundTransparency = 1
themeLabel.Text = "Theme:"
themeLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
themeLabel.TextSize = 13
themeLabel.Font = Enum.Font.GothamBold
themeLabel.TextXAlignment = Enum.TextXAlignment.Left
themeLabel.ZIndex = 11
themeLabel.Parent = settingsContentFrame

local darkButton = Instance.new("TextButton")
darkButton.Size = UDim2.new(0, 110, 0, 32)
darkButton.Position = UDim2.new(0, 12, 0, 36)
darkButton.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
darkButton.BorderSizePixel = 0
darkButton.Text = "Dark"
darkButton.TextColor3 = Color3.fromRGB(255, 255, 255)
darkButton.TextSize = 13
darkButton.Font = Enum.Font.GothamBold
darkButton.ZIndex = 11
darkButton.Parent = settingsContentFrame

addCorner(darkButton, UDim.new(0, 7))

local darkStroke = Instance.new("UIStroke")
darkStroke.Color = Color3.fromRGB(80, 150, 255)
darkStroke.Thickness = 3
darkStroke.ZIndex = 11
darkStroke.Parent = darkButton

local lightButton = Instance.new("TextButton")
lightButton.Size = UDim2.new(0, 110, 0, 32)
lightButton.Position = UDim2.new(0, 138, 0, 36)
lightButton.BackgroundColor3 = Color3.fromRGB(240, 240, 250)
lightButton.BorderSizePixel = 0
lightButton.Text = "Light"
lightButton.TextColor3 = Color3.fromRGB(30, 30, 40)
lightButton.TextSize = 13
lightButton.Font = Enum.Font.GothamBold
lightButton.ZIndex = 11
lightButton.Parent = settingsContentFrame

addCorner(lightButton, UDim.new(0, 7))

local lightStroke = Instance.new("UIStroke")
lightStroke.Color = Color3.fromRGB(80, 150, 255)
lightStroke.Thickness = 3
lightStroke.Transparency = 1
lightStroke.ZIndex = 11
lightStroke.Parent = lightButton

local hideExpandedPartsLabel = Instance.new("TextLabel")
hideExpandedPartsLabel.Size = UDim2.new(0, 150, 0, 22)
hideExpandedPartsLabel.Position = UDim2.new(0, 12, 0, 78)
hideExpandedPartsLabel.BackgroundTransparency = 1
hideExpandedPartsLabel.Text = "Hide expanded parts:"
hideExpandedPartsLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
hideExpandedPartsLabel.TextSize = 13
hideExpandedPartsLabel.Font = Enum.Font.GothamBold
hideExpandedPartsLabel.TextXAlignment = Enum.TextXAlignment.Left
hideExpandedPartsLabel.ZIndex = 11
hideExpandedPartsLabel.Parent = settingsContentFrame

local hideExpandedPartsButton = Instance.new("TextButton")
hideExpandedPartsButton.Size = UDim2.new(0, 60, 0, 28)
hideExpandedPartsButton.Position = UDim2.new(0, 178, 0, 76)
hideExpandedPartsButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
hideExpandedPartsButton.BorderSizePixel = 0
hideExpandedPartsButton.Text = "OFF"
hideExpandedPartsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
hideExpandedPartsButton.TextSize = 13
hideExpandedPartsButton.Font = Enum.Font.GothamBold
hideExpandedPartsButton.ZIndex = 11
hideExpandedPartsButton.Parent = settingsContentFrame

addCorner(hideExpandedPartsButton, UDim.new(0, 7))

local keybindSectionLabel = Instance.new("TextLabel")
keybindSectionLabel.Size = UDim2.new(1, -24, 0, 22)
keybindSectionLabel.Position = UDim2.new(0, 12, 0, 116)
keybindSectionLabel.BackgroundTransparency = 1
keybindSectionLabel.Text = "Keybinds:"
keybindSectionLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
keybindSectionLabel.TextSize = 13
keybindSectionLabel.Font = Enum.Font.GothamBold
keybindSectionLabel.TextXAlignment = Enum.TextXAlignment.Left
keybindSectionLabel.ZIndex = 11
keybindSectionLabel.Parent = settingsContentFrame

local function makeKeybindRow(labelText, yPos)
	local rowLabel = Instance.new("TextLabel")
	rowLabel.Size = UDim2.new(0, 130, 0, 28)
	rowLabel.Position = UDim2.new(0, 12, 0, yPos)
	rowLabel.BackgroundTransparency = 1
	rowLabel.Text = labelText
	rowLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
	rowLabel.TextSize = 12
	rowLabel.Font = Enum.Font.Gotham
	rowLabel.TextXAlignment = Enum.TextXAlignment.Left
	rowLabel.ZIndex = 11
	rowLabel.Parent = settingsContentFrame

	local rowButton = Instance.new("TextButton")
	rowButton.Size = UDim2.new(0, 90, 0, 28)
	rowButton.Position = UDim2.new(0, 152, 0, yPos)
	rowButton.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	rowButton.BorderSizePixel = 0
	rowButton.Text = "None"
	rowButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	rowButton.TextSize = 12
	rowButton.Font = Enum.Font.GothamBold
	rowButton.ZIndex = 11
	rowButton.Parent = settingsContentFrame

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 7)
	rowCorner.Parent = rowButton

	local rowStroke = Instance.new("UIStroke")
	rowStroke.Color = Color3.fromRGB(80, 80, 100)
	rowStroke.Thickness = 1
	rowStroke.ZIndex = 11
	rowStroke.Parent = rowButton

	return rowLabel, rowButton, rowStroke
end

local keybindExpanderLabel, keybindExpanderButton, keybindExpanderStroke = makeKeybindRow("Toggle expander:", 142)
local keybindOverlayLabel, keybindOverlayButton, keybindOverlayStroke = makeKeybindRow("Toggle overlay:", 178)
local keybindGuiLabel, keybindGuiButton, keybindGuiStroke = makeKeybindRow("Toggle GUI:", 214)
local keybindMinimizeLabel, keybindMinimizeButton, keybindMinimizeStroke = makeKeybindRow("Minimize:", 250)
local keybindApplyExpansionLabel, keybindApplyExpansionButton, keybindApplyExpansionStroke = makeKeybindRow("Apply expansion:", 286)

local expansionSize = 10
local expanderEnabled = false
local overlayEnabled = false
local hideExpandedParts = false
local targetMode = DEFAULT_TARGET_MODE
local isMinimized = false
local currentTheme = "dark"
local guiVisible = true
local isDragging = false
local dragPointerInput = nil
local dragStart = nil
local startPos = nil
local dragEndConnection = nil
local viewportSizeConnection = nil
local viewportClampScheduled = false
local overlayData = {}
local npcOverlayData = {}
local npcCharacters = {}
local characterConnections = {}
local trackedCharacters = {}
local originalPartData = {}
local serviceConnections = {}
local animatingButtons = setmetatable({}, {__mode = "k"})
local expansionUpdateAccumulator = 0
local overlayUpdateAccumulator = 0
local isShuttingDown = false

local keybinds = {
	expander = nil,
	overlay = nil,
	gui = nil,
	minimize = nil,
	applyExpansion = nil,
}

local listeningFor = nil

local keybindButtons = {
	expander = keybindExpanderButton,
	overlay = keybindOverlayButton,
	gui = keybindGuiButton,
	minimize = keybindMinimizeButton,
	applyExpansion = keybindApplyExpansionButton,
}

local keybindStrokes = {
	expander = keybindExpanderStroke,
	overlay = keybindOverlayStroke,
	gui = keybindGuiStroke,
	minimize = keybindMinimizeStroke,
	applyExpansion = keybindApplyExpansionStroke,
}

local keybindLabels = {
	expander = keybindExpanderLabel,
	overlay = keybindOverlayLabel,
	gui = keybindGuiLabel,
	minimize = keybindMinimizeLabel,
	applyExpansion = keybindApplyExpansionLabel,
}

local keybindActionNames = {
	"expander",
	"overlay",
	"gui",
	"minimize",
	"applyExpansion",
}

local legacyKeybindActionNames = {
	expander = "hitbox",
	overlay = "esp",
	applyExpansion = "apply",
}

local expandablePartNames = {
	"HumanoidRootPart", "Head", "Torso",
	"Left Arm", "Right Arm", "Left Leg", "Right Leg",
	"UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"RightUpperLeg", "RightLowerLeg", "RightFoot"
}

local partSettings = {}
local partSettingControls = {}

local partSettingsSectionLabel = Instance.new("TextLabel")
partSettingsSectionLabel.Size = UDim2.new(1, -24, 0, 22)
partSettingsSectionLabel.Position = UDim2.new(0, 12, 0, 322)
partSettingsSectionLabel.BackgroundTransparency = 1
partSettingsSectionLabel.Text = "Per-part expansion (blank = global):"
partSettingsSectionLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
partSettingsSectionLabel.TextSize = 12
partSettingsSectionLabel.Font = Enum.Font.GothamBold
partSettingsSectionLabel.TextXAlignment = Enum.TextXAlignment.Left
partSettingsSectionLabel.ZIndex = 11
partSettingsSectionLabel.Parent = settingsContentFrame

for index, partName in ipairs(expandablePartNames) do
	partSettings[partName] = {
		enabled = true,
		sizeOverride = nil,
	}

	local rowY = 350 + (index - 1) * 34
	local partLabel = Instance.new("TextLabel")
	partLabel.Name = "PartLabel_" .. partName
	partLabel.Size = UDim2.new(0, 106, 0, 28)
	partLabel.Position = UDim2.new(0, 12, 0, rowY)
	partLabel.BackgroundTransparency = 1
	partLabel.Text = partName
	partLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
	partLabel.TextSize = 10
	partLabel.Font = Enum.Font.Gotham
	partLabel.TextXAlignment = Enum.TextXAlignment.Left
	partLabel.ZIndex = 11
	partLabel.Parent = settingsContentFrame

	local partToggle = Instance.new("TextButton")
	partToggle.Name = "PartToggle_" .. partName
	partToggle.Size = UDim2.new(0, 48, 0, 28)
	partToggle.Position = UDim2.new(0, 122, 0, rowY)
	partToggle.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
	partToggle.BorderSizePixel = 0
	partToggle.Text = "ON"
	partToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
	partToggle.TextSize = 11
	partToggle.Font = Enum.Font.GothamBold
	partToggle.ZIndex = 11
	partToggle.Parent = settingsContentFrame

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 7)
	toggleCorner.Parent = partToggle

	local partSizeInput = Instance.new("TextBox")
	partSizeInput.Name = "PartSize_" .. partName
	partSizeInput.Size = UDim2.new(0, 64, 0, 28)
	partSizeInput.Position = UDim2.new(0, 178, 0, rowY)
	partSizeInput.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	partSizeInput.BorderSizePixel = 0
	partSizeInput.ClearTextOnFocus = false
	partSizeInput.Text = ""
	partSizeInput.PlaceholderText = "Default"
	partSizeInput.TextColor3 = Color3.fromRGB(255, 255, 255)
	partSizeInput.PlaceholderColor3 = Color3.fromRGB(140, 140, 150)
	partSizeInput.TextSize = 10
	partSizeInput.Font = Enum.Font.Gotham
	partSizeInput.ZIndex = 11
	partSizeInput.Parent = settingsContentFrame

	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = UDim.new(0, 7)
	inputCorner.Parent = partSizeInput

	local inputStroke = Instance.new("UIStroke")
	inputStroke.Color = Color3.fromRGB(80, 80, 100)
	inputStroke.Thickness = 1
	inputStroke.ZIndex = 11
	inputStroke.Parent = partSizeInput

	partSettingControls[partName] = {
		label = partLabel,
		toggle = partToggle,
		input = partSizeInput,
		stroke = inputStroke,
	}
end
settingsContentFrame.CanvasSize = UDim2.new(0, 0, 0, 1080)

local function isRuntimeGuiMounted()
	return player.Parent == Players
		and playerGui.Parent == player
		and screenGui.Parent == playerGui
		and mainFrame.Parent == screenGui
end

local function targetModeIncludesPlayers()
	return targetMode == "all" or targetMode == "players"
end

local function targetModeIncludesNpcs()
	return targetMode == "all" or targetMode == "npcs"
end

local function getDefaultPartSize(partName)
	if partName == "HumanoidRootPart" then return expansionSize end
	if partName == "Head" then return expansionSize * 0.8 end
	return expansionSize * 0.7
end

local function getEffectivePartSize(partName)
	local setting = partSettings[partName]
	return setting and setting.sizeOverride or getDefaultPartSize(partName)
end

local function updatePartSettingVisual(partName)
	local setting = partSettings[partName]
	local controls = partSettingControls[partName]
	if not setting or not controls then return end
	controls.toggle.Text = setting.enabled and "ON" or "OFF"
	controls.toggle.BackgroundColor3 = setting.enabled
		and Color3.fromRGB(50, 200, 100)
		or Color3.fromRGB(220, 50, 50)
	controls.input.Text = setting.sizeOverride and tostring(setting.sizeOverride) or ""
	controls.input.PlaceholderText = tostring(getDefaultPartSize(partName))
end

local function updateAllPartSettingVisuals()
	for _, partName in ipairs(expandablePartNames) do
		updatePartSettingVisual(partName)
	end
end

local function updateTargetModeVisual()
	local abbreviations = {
		all = "◎A",
		players = "◎P",
		npcs = "◎N",
	}
	targetModeButton.Text = abbreviations[targetMode] or "◎P"
	for mode, button in pairs(targetModeButtons) do
		local selected = mode == targetMode
		button.BackgroundColor3 = selected and Color3.fromRGB(80, 150, 255)
			or currentTheme == "light" and Color3.fromRGB(225, 225, 235)
			or Color3.fromRGB(40, 40, 55)
		button.TextColor3 = (selected or currentTheme ~= "light")
			and Color3.fromRGB(255, 255, 255)
			or Color3.fromRGB(40, 40, 50)
	end
end

local function getKeyName(keyCode)
	if keyCode == nil then return "None" end
	return keyCode.Name
end

local function collectAndSave()
	local data = {
		expansionSize = expansionSize,
		theme = currentTheme,
		hideExpandedParts = hideExpandedParts,
		targetMode = targetMode,
		partSettings = {},
		keybinds = {},
	}
	for _, partName in ipairs(expandablePartNames) do
		local setting = partSettings[partName]
		local savedSetting = {enabled = setting.enabled}
		if setting.sizeOverride then savedSetting.sizeOverride = setting.sizeOverride end
		data.partSettings[partName] = savedSetting
	end
	for _, actionName in ipairs(keybindActionNames) do
		local keyCode = keybinds[actionName]
		data.keybinds[actionName] = keyCode and keyCode.Name or "None"
	end
	saveSettings(data)
end

local function updateKeybindVisual(actionName)
	local button = keybindButtons[actionName]
	local stroke = keybindStrokes[actionName]
	if not button or not button.Parent or not stroke or not stroke.Parent then return end
	button.Text = getKeyName(keybinds[actionName])
	TweenService:Create(stroke, TweenInfo.new(0.1), {Color = Color3.fromRGB(80, 80, 100)}):Play()
	TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(40, 40, 55)}):Play()
end

local function setListening(actionName)
	if isShuttingDown then return end
	if actionName ~= nil and (
		not keybindButtons[actionName]
		or not guiVisible
		or not settingsFrame.Parent
		or not settingsFrame.Visible
		or not isRuntimeGuiMounted()
	) then return end
	if listeningFor then
		updateKeybindVisual(listeningFor)
	end
	listeningFor = actionName
	if not actionName then return end

	local button = keybindButtons[actionName]
	local stroke = keybindStrokes[actionName]
	if button and button.Parent and stroke and stroke.Parent then
		button.Text = "Press key..."
		TweenService:Create(stroke, TweenInfo.new(0.1), {Color = Color3.fromRGB(80, 150, 255)}):Play()
		TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30, 50, 80)}):Play()
	end
end

local function applyKeybind(actionName, keyCode)
	if not keybindButtons[actionName] then return end
	if keyCode == Enum.KeyCode.Unknown then return end

	if keyCode then
		for _, otherAction in ipairs(keybindActionNames) do
			if otherAction ~= actionName and keybinds[otherAction] == keyCode then
				keybinds[otherAction] = nil
				updateKeybindVisual(otherAction)
			end
		end
	end

	keybinds[actionName] = keyCode
	updateKeybindVisual(actionName)
	collectAndSave()
end

for actionName, btn in pairs(keybindButtons) do
	local capturedAction = actionName
	btn.MouseButton1Click:Connect(function()
		if listeningFor == capturedAction then
			setListening(nil)
		else
			setListening(capturedAction)
		end
	end)
	btn.MouseEnter:Connect(function()
		if listeningFor ~= capturedAction then
			TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(55, 55, 75)}):Play()
		end
	end)
	btn.MouseLeave:Connect(function()
		if listeningFor ~= capturedAction then
			TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(40, 40, 55)}):Play()
		end
	end)
end

local function getTeamColor(targetPlayer)
	if targetPlayer and targetPlayer.Team then
		return targetPlayer.TeamColor.Color
	end
	return Color3.fromRGB(255, 255, 255)
end

local function isCharacterInWorkspace(character)
	return character ~= nil and character:IsDescendantOf(workspace)
end

local function animateButton(button)
	if isShuttingDown or not button or not button.Parent or animatingButtons[button] then return end
	animatingButtons[button] = true
	local originalSize = button.Size
	local tweenInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(button, tweenInfo, {
		Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset + 4, originalSize.Y.Scale, originalSize.Y.Offset + 4),
	}):Play()
	task.delay(0.08, function()
		if not isShuttingDown and button.Parent then
			TweenService:Create(button, tweenInfo, {Size = originalSize}):Play()
		end
		task.delay(0.1, function()
			animatingButtons[button] = nil
		end)
	end)
end

local function applyTheme(theme, shouldSave)
	if isShuttingDown then return end
	if theme ~= "light" then theme = "dark" end
	currentTheme = theme
	local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if theme == "light" then
		TweenService:Create(mainFrame, tweenInfo, {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		TweenService:Create(contentFrame, tweenInfo, {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		TweenService:Create(mainStroke, tweenInfo, {Color = Color3.fromRGB(200, 200, 210)}):Play()
		TweenService:Create(titleBar, tweenInfo, {BackgroundColor3 = Color3.fromRGB(245, 245, 250)}):Play()
		TweenService:Create(titleFix, tweenInfo, {BackgroundColor3 = Color3.fromRGB(245, 245, 250)}):Play()
		TweenService:Create(titleLabel, tweenInfo, {TextColor3 = Color3.fromRGB(30, 30, 40)}):Play()
		TweenService:Create(expansionSizeLabel, tweenInfo, {TextColor3 = Color3.fromRGB(60, 60, 70)}):Play()
		TweenService:Create(expansionSizeInput, tweenInfo, {BackgroundColor3 = Color3.fromRGB(235, 235, 245), TextColor3 = Color3.fromRGB(30, 30, 40)}):Play()
		TweenService:Create(expansionSizeInputStroke, tweenInfo, {Color = Color3.fromRGB(200, 200, 210)}):Play()
		TweenService:Create(footerLabel, tweenInfo, {TextColor3 = Color3.fromRGB(100, 100, 110)}):Play()
		TweenService:Create(footerLabelMinimized, tweenInfo, {TextColor3 = Color3.fromRGB(100, 100, 110)}):Play()
		TweenService:Create(confirmFrame, tweenInfo, {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		TweenService:Create(confirmText, tweenInfo, {TextColor3 = Color3.fromRGB(30, 30, 40)}):Play()
		TweenService:Create(settingsFrame, tweenInfo, {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		TweenService:Create(settingsTitleBar, tweenInfo, {BackgroundColor3 = Color3.fromRGB(245, 245, 250)}):Play()
		TweenService:Create(settingsTitleFix, tweenInfo, {BackgroundColor3 = Color3.fromRGB(245, 245, 250)}):Play()
		TweenService:Create(settingsTitleLabel, tweenInfo, {TextColor3 = Color3.fromRGB(30, 30, 40)}):Play()
		TweenService:Create(targetFrame, tweenInfo, {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		TweenService:Create(targetTitleBar, tweenInfo, {BackgroundColor3 = Color3.fromRGB(245, 245, 250)}):Play()
		TweenService:Create(targetTitleFix, tweenInfo, {BackgroundColor3 = Color3.fromRGB(245, 245, 250)}):Play()
		TweenService:Create(targetTitleLabel, tweenInfo, {TextColor3 = Color3.fromRGB(30, 30, 40)}):Play()
		TweenService:Create(themeLabel, tweenInfo, {TextColor3 = Color3.fromRGB(60, 60, 70)}):Play()
		TweenService:Create(hideExpandedPartsLabel, tweenInfo, {TextColor3 = Color3.fromRGB(60, 60, 70)}):Play()
		TweenService:Create(keybindSectionLabel, tweenInfo, {TextColor3 = Color3.fromRGB(60, 60, 70)}):Play()
		TweenService:Create(partSettingsSectionLabel, tweenInfo, {TextColor3 = Color3.fromRGB(60, 60, 70)}):Play()
		TweenService:Create(settingsButtonTop, tweenInfo, {BackgroundColor3 = Color3.fromRGB(200, 200, 220), TextColor3 = Color3.fromRGB(30, 30, 40)}):Play()
		TweenService:Create(darkStroke, tweenInfo, {Color = Color3.fromRGB(200, 200, 210)}):Play()
		for _, lbl in pairs(keybindLabels) do
			TweenService:Create(lbl, tweenInfo, {TextColor3 = Color3.fromRGB(80, 80, 90)}):Play()
		end
		for _, controls in pairs(partSettingControls) do
			TweenService:Create(controls.label, tweenInfo, {TextColor3 = Color3.fromRGB(80, 80, 90)}):Play()
			TweenService:Create(controls.input, tweenInfo, {
				BackgroundColor3 = Color3.fromRGB(235, 235, 245),
				TextColor3 = Color3.fromRGB(30, 30, 40),
				PlaceholderColor3 = Color3.fromRGB(120, 120, 130),
			}):Play()
			TweenService:Create(controls.stroke, tweenInfo, {Color = Color3.fromRGB(200, 200, 210)}):Play()
		end
		TweenService:Create(lightStroke, tweenInfo, {Transparency = 0}):Play()
	else
		TweenService:Create(mainFrame, tweenInfo, {BackgroundColor3 = Color3.fromRGB(20, 20, 25)}):Play()
		TweenService:Create(contentFrame, tweenInfo, {BackgroundColor3 = Color3.fromRGB(20, 20, 25)}):Play()
		TweenService:Create(mainStroke, tweenInfo, {Color = Color3.fromRGB(60, 60, 70)}):Play()
		TweenService:Create(titleBar, tweenInfo, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)}):Play()
		TweenService:Create(titleFix, tweenInfo, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)}):Play()
		TweenService:Create(titleLabel, tweenInfo, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		TweenService:Create(expansionSizeLabel, tweenInfo, {TextColor3 = Color3.fromRGB(200, 200, 210)}):Play()
		TweenService:Create(expansionSizeInput, tweenInfo, {BackgroundColor3 = Color3.fromRGB(40, 40, 50), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		TweenService:Create(expansionSizeInputStroke, tweenInfo, {Color = Color3.fromRGB(80, 80, 90)}):Play()
		TweenService:Create(footerLabel, tweenInfo, {TextColor3 = Color3.fromRGB(120, 120, 130)}):Play()
		TweenService:Create(footerLabelMinimized, tweenInfo, {TextColor3 = Color3.fromRGB(120, 120, 130)}):Play()
		TweenService:Create(confirmFrame, tweenInfo, {BackgroundColor3 = Color3.fromRGB(15, 15, 20)}):Play()
		TweenService:Create(confirmText, tweenInfo, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		TweenService:Create(settingsFrame, tweenInfo, {BackgroundColor3 = Color3.fromRGB(20, 20, 25)}):Play()
		TweenService:Create(settingsTitleBar, tweenInfo, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)}):Play()
		TweenService:Create(settingsTitleFix, tweenInfo, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)}):Play()
		TweenService:Create(settingsTitleLabel, tweenInfo, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		TweenService:Create(targetFrame, tweenInfo, {BackgroundColor3 = Color3.fromRGB(20, 20, 25)}):Play()
		TweenService:Create(targetTitleBar, tweenInfo, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)}):Play()
		TweenService:Create(targetTitleFix, tweenInfo, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)}):Play()
		TweenService:Create(targetTitleLabel, tweenInfo, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		TweenService:Create(themeLabel, tweenInfo, {TextColor3 = Color3.fromRGB(200, 200, 210)}):Play()
		TweenService:Create(hideExpandedPartsLabel, tweenInfo, {TextColor3 = Color3.fromRGB(200, 200, 210)}):Play()
		TweenService:Create(keybindSectionLabel, tweenInfo, {TextColor3 = Color3.fromRGB(200, 200, 210)}):Play()
		TweenService:Create(partSettingsSectionLabel, tweenInfo, {TextColor3 = Color3.fromRGB(200, 200, 210)}):Play()
		TweenService:Create(settingsButtonTop, tweenInfo, {BackgroundColor3 = Color3.fromRGB(100, 100, 120), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		for _, lbl in pairs(keybindLabels) do
			TweenService:Create(lbl, tweenInfo, {TextColor3 = Color3.fromRGB(180, 180, 190)}):Play()
		end
		for _, controls in pairs(partSettingControls) do
			TweenService:Create(controls.label, tweenInfo, {TextColor3 = Color3.fromRGB(180, 180, 190)}):Play()
			TweenService:Create(controls.input, tweenInfo, {
				BackgroundColor3 = Color3.fromRGB(40, 40, 55),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				PlaceholderColor3 = Color3.fromRGB(140, 140, 150),
			}):Play()
			TweenService:Create(controls.stroke, tweenInfo, {Color = Color3.fromRGB(80, 80, 100)}):Play()
		end
		TweenService:Create(lightStroke, tweenInfo, {Transparency = 1}):Play()
		TweenService:Create(darkStroke, tweenInfo, {Color = Color3.fromRGB(80, 150, 255)}):Play()
	end
	updateTargetModeVisual()
	if shouldSave ~= false then
		collectAndSave()
	end
end

local function destroyInstance(instance)
	if not instance then return end
	pcall(function()
		instance:Destroy()
	end)
end

local function removeManagedOverlayInstances(targetIdentifier, character)
	if type(targetIdentifier) ~= "string" or not character then return end
	local managedClasses = {
		["PlayerOverlayBillboard_" .. targetIdentifier] = "BillboardGui",
		["PlayerOverlayHighlight_" .. targetIdentifier] = "Highlight",
	}
	local ok, descendants = pcall(function()
		return character:GetDescendants()
	end)
	if not ok then return end
	for _, descendant in ipairs(descendants) do
		local expectedClass = managedClasses[descendant.Name]
		if expectedClass and descendant:IsA(expectedClass) then
			destroyInstance(descendant)
		end
	end
end

local function destroyOverlayData(data)
	if not data then return end
	destroyInstance(data.displayLabel)
	destroyInstance(data.infoLabel)
	destroyInstance(data.gui)
	destroyInstance(data.highlight)
end

local function removePlayerOverlay(targetPlayer)
	local data = overlayData[targetPlayer]
	if not data then return end
	destroyOverlayData(data)
	overlayData[targetPlayer] = nil
end

local function removeNpcOverlay(character)
	local data = npcOverlayData[character]
	if not data then return end
	destroyOverlayData(data)
	npcOverlayData[character] = nil
end

local function isNpcCharacter(character)
	return character ~= nil
		and character:IsA("Model")
		and isCharacterInWorkspace(character)
		and character:FindFirstChildOfClass("Humanoid") ~= nil
		and Players:GetPlayerFromCharacter(character) == nil
end

local function registerNpcDescendant(descendant)
	if not descendant or not descendant:IsA("Humanoid") then return end
	local character = descendant.Parent
	if isNpcCharacter(character) then
		npcCharacters[character] = true
	end
end

local function removeAllPlayerOverlays()
	local playersToRemove = {}
	for targetPlayer in pairs(overlayData) do
		table.insert(playersToRemove, targetPlayer)
	end
	for _, targetPlayer in ipairs(playersToRemove) do
		removePlayerOverlay(targetPlayer)
	end

	local npcsToRemove = {}
	for character in pairs(npcOverlayData) do
		table.insert(npcsToRemove, character)
	end
	for _, character in ipairs(npcsToRemove) do
		removeNpcOverlay(character)
	end

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if targetPlayer ~= player and targetPlayer.Character then
			removeManagedOverlayInstances(targetPlayer.Name, targetPlayer.Character)
		end
	end
	for character in pairs(npcCharacters) do
		if character then removeManagedOverlayInstances(character.Name, character) end
	end
end

local function createPlayerOverlay(targetPlayer)
	if isShuttingDown or not targetPlayer or targetPlayer == player then return end
	removePlayerOverlay(targetPlayer)

	local character = targetPlayer.Character
	if not isCharacterInWorkspace(character) then return end
	local head = character:FindFirstChild("Head")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local attachPart = head and head:IsA("BasePart") and head
		or rootPart and rootPart:IsA("BasePart") and rootPart
	if not attachPart then return end
	if not humanoid or humanoid.Health <= 0 then return end

	removeManagedOverlayInstances(targetPlayer.Name, character)
	local teamColor = getTeamColor(targetPlayer)
	local displayName = tostring(targetPlayer.DisplayName or targetPlayer.Name)
	local hasDisplayName = displayName ~= targetPlayer.Name
	local guiHeight = hasDisplayName and 36 or 20

	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "PlayerOverlayBillboard_" .. targetPlayer.Name
	billboardGui.AlwaysOnTop = true
	billboardGui.Size = UDim2.new(0, 300, 0, guiHeight)
	billboardGui.StudsOffset = Vector3.new(0, 3.2, 0)
	billboardGui.Parent = attachPart

	local displayLabel = nil
	local infoLabel = nil
	if hasDisplayName then
		displayLabel = Instance.new("TextLabel")
		displayLabel.Name = "DisplayLabel"
		displayLabel.Size = UDim2.new(1, 0, 0, 16)
		displayLabel.Position = UDim2.new(0, 0, 0, 0)
		displayLabel.BackgroundTransparency = 1
		displayLabel.TextColor3 = teamColor
		displayLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		displayLabel.TextStrokeTransparency = 0.3
		displayLabel.TextSize = 14
		displayLabel.Font = Enum.Font.GothamBold
		displayLabel.Text = displayName
		displayLabel.TextXAlignment = Enum.TextXAlignment.Center
		displayLabel.Parent = billboardGui

		infoLabel = Instance.new("TextLabel")
		infoLabel.Name = "InfoLabel"
		infoLabel.Size = UDim2.new(1, 0, 0, 16)
		infoLabel.Position = UDim2.new(0, 0, 0, 18)
		infoLabel.BackgroundTransparency = 1
		infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		infoLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		infoLabel.TextStrokeTransparency = 0.3
		infoLabel.TextSize = 11
		infoLabel.Font = Enum.Font.Gotham
		infoLabel.Text = ""
		infoLabel.TextXAlignment = Enum.TextXAlignment.Center
		infoLabel.Parent = billboardGui
	else
		infoLabel = Instance.new("TextLabel")
		infoLabel.Name = "InfoLabel"
		infoLabel.Size = UDim2.new(1, 0, 1, 0)
		infoLabel.BackgroundTransparency = 1
		infoLabel.TextColor3 = teamColor
		infoLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		infoLabel.TextStrokeTransparency = 0.3
		infoLabel.TextSize = 13
		infoLabel.Font = Enum.Font.GothamBold
		infoLabel.Text = ""
		infoLabel.TextXAlignment = Enum.TextXAlignment.Center
		infoLabel.Parent = billboardGui
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "PlayerOverlayHighlight_" .. targetPlayer.Name
	highlight.Adornee = character
	highlight.FillColor = teamColor
	highlight.OutlineColor = teamColor
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	overlayData[targetPlayer] = {
		character = character,
		attachPart = attachPart,
		gui = billboardGui,
		displayLabel = displayLabel,
		infoLabel = infoLabel,
		highlight = highlight,
		hasDisplayName = hasDisplayName,
	}
end

local function createNpcOverlay(character)
	if isShuttingDown or not isNpcCharacter(character) then return end
	removeNpcOverlay(character)

	local head = character:FindFirstChild("Head")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local attachPart = head and head:IsA("BasePart") and head
		or rootPart and rootPart:IsA("BasePart") and rootPart
	if not attachPart or not humanoid or humanoid.Health <= 0 then return end

	local identifier = character.Name
	removeManagedOverlayInstances(identifier, character)
	local overlayColor = Color3.fromRGB(255, 255, 255)
	local humanoidDisplayName = tostring(humanoid.DisplayName or "")
	local displayName = humanoidDisplayName ~= "" and humanoidDisplayName or identifier
	local hasDisplayName = displayName ~= identifier
	local guiHeight = hasDisplayName and 36 or 20

	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "PlayerOverlayBillboard_" .. identifier
	billboardGui.AlwaysOnTop = true
	billboardGui.Size = UDim2.new(0, 300, 0, guiHeight)
	billboardGui.StudsOffset = Vector3.new(0, 3.2, 0)
	billboardGui.Parent = attachPart

	local displayLabel = nil
	local infoLabel = nil
	if hasDisplayName then
		displayLabel = Instance.new("TextLabel")
		displayLabel.Name = "DisplayLabel"
		displayLabel.Size = UDim2.new(1, 0, 0, 16)
		displayLabel.BackgroundTransparency = 1
		displayLabel.TextColor3 = overlayColor
		displayLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		displayLabel.TextStrokeTransparency = 0.3
		displayLabel.TextSize = 14
		displayLabel.Font = Enum.Font.GothamBold
		displayLabel.Text = displayName
		displayLabel.TextXAlignment = Enum.TextXAlignment.Center
		displayLabel.Parent = billboardGui

		infoLabel = Instance.new("TextLabel")
		infoLabel.Name = "InfoLabel"
		infoLabel.Size = UDim2.new(1, 0, 0, 16)
		infoLabel.Position = UDim2.new(0, 0, 0, 18)
		infoLabel.BackgroundTransparency = 1
		infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		infoLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		infoLabel.TextStrokeTransparency = 0.3
		infoLabel.TextSize = 11
		infoLabel.Font = Enum.Font.Gotham
		infoLabel.Text = ""
		infoLabel.TextXAlignment = Enum.TextXAlignment.Center
		infoLabel.Parent = billboardGui
	else
		infoLabel = Instance.new("TextLabel")
		infoLabel.Name = "InfoLabel"
		infoLabel.Size = UDim2.new(1, 0, 1, 0)
		infoLabel.BackgroundTransparency = 1
		infoLabel.TextColor3 = overlayColor
		infoLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		infoLabel.TextStrokeTransparency = 0.3
		infoLabel.TextSize = 13
		infoLabel.Font = Enum.Font.GothamBold
		infoLabel.Text = ""
		infoLabel.TextXAlignment = Enum.TextXAlignment.Center
		infoLabel.Parent = billboardGui
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "PlayerOverlayHighlight_" .. identifier
	highlight.Adornee = character
	highlight.FillColor = overlayColor
	highlight.OutlineColor = overlayColor
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	npcOverlayData[character] = {
		character = character,
		identifier = identifier,
		attachPart = attachPart,
		gui = billboardGui,
		displayLabel = displayLabel,
		infoLabel = infoLabel,
		highlight = highlight,
		hasDisplayName = hasDisplayName,
	}
end

local function getLocalDistancePart()
	local localCharacter = player.Character
	if not isCharacterInWorkspace(localCharacter) then return nil end
	local localRootPart = localCharacter:FindFirstChild("HumanoidRootPart")
	local localHead = localCharacter:FindFirstChild("Head")
	if localRootPart and localRootPart:IsA("BasePart") then return localRootPart end
	if localHead and localHead:IsA("BasePart") then return localHead end
	return nil
end

local function updatePlayerOverlayTarget(targetPlayer, localDistancePart)
	local character = targetPlayer.Character
	local head = character and character:FindFirstChild("Head")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local attachPart = head and head:IsA("BasePart") and head
		or rootPart and rootPart:IsA("BasePart") and rootPart
	local distancePart = rootPart and rootPart:IsA("BasePart") and rootPart or attachPart

	if not isCharacterInWorkspace(character) or not attachPart or not humanoid or humanoid.Health <= 0 then
		local hadOverlay = overlayData[targetPlayer] ~= nil
		removePlayerOverlay(targetPlayer)
		if hadOverlay and character then removeManagedOverlayInstances(targetPlayer.Name, character) end
		return
	end

	local data = overlayData[targetPlayer]
	local currentDisplayName = tostring(targetPlayer.DisplayName or targetPlayer.Name)
	local currentlyHasDisplayName = currentDisplayName ~= targetPlayer.Name
	local expectedBillboardName = "PlayerOverlayBillboard_" .. targetPlayer.Name
	local expectedHighlightName = "PlayerOverlayHighlight_" .. targetPlayer.Name
	local needsRecreate = not data
		or data.character ~= character
		or data.attachPart ~= attachPart
		or data.hasDisplayName ~= currentlyHasDisplayName
		or not data.gui or data.gui.Parent ~= attachPart
		or data.gui.Name ~= expectedBillboardName
		or not data.infoLabel or data.infoLabel.Parent ~= data.gui
		or data.hasDisplayName and (not data.displayLabel or data.displayLabel.Parent ~= data.gui)
		or not data.highlight or data.highlight.Parent ~= character
		or data.highlight.Name ~= expectedHighlightName
		or data.highlight.Adornee ~= character

	if needsRecreate then
		createPlayerOverlay(targetPlayer)
		data = overlayData[targetPlayer]
	end
	if not data or not data.infoLabel or not data.infoLabel.Parent then return end

	local teamColor = getTeamColor(targetPlayer)
	local studsText = "?"
	if localDistancePart and distancePart then
		studsText = tostring(math.floor((localDistancePart.Position - distancePart.Position).Magnitude))
	end
	local hpText = math.floor(math.max(0, humanoid.Health))
		.. "/" .. math.floor(math.max(0, humanoid.MaxHealth)) .. " HP"

	if data.hasDisplayName then
		if data.displayLabel and data.displayLabel.Parent then
			data.displayLabel.Text = currentDisplayName
			data.displayLabel.TextColor3 = teamColor
		end
		data.infoLabel.Text = studsText .. " studs | @" .. targetPlayer.Name .. " | " .. hpText
	else
		data.infoLabel.Text = studsText .. " studs | " .. targetPlayer.Name .. " | " .. hpText
		data.infoLabel.TextColor3 = teamColor
	end
	data.highlight.FillColor = teamColor
	data.highlight.OutlineColor = teamColor
end

local function updateNpcOverlayTarget(character, localDistancePart)
	local head = character and character:FindFirstChild("Head")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local attachPart = head and head:IsA("BasePart") and head
		or rootPart and rootPart:IsA("BasePart") and rootPart
	local distancePart = rootPart and rootPart:IsA("BasePart") and rootPart or attachPart

	if not isNpcCharacter(character) or not attachPart or not humanoid or humanoid.Health <= 0 then
		local data = npcOverlayData[character]
		removeNpcOverlay(character)
		if data then removeManagedOverlayInstances(data.identifier or character.Name, character) end
		return
	end

	local identifier = character.Name
	local humanoidDisplayName = tostring(humanoid.DisplayName or "")
	local currentDisplayName = humanoidDisplayName ~= "" and humanoidDisplayName or identifier
	local currentlyHasDisplayName = currentDisplayName ~= identifier
	local expectedBillboardName = "PlayerOverlayBillboard_" .. identifier
	local expectedHighlightName = "PlayerOverlayHighlight_" .. identifier
	local data = npcOverlayData[character]
	local needsRecreate = not data
		or data.identifier ~= identifier
		or data.attachPart ~= attachPart
		or data.hasDisplayName ~= currentlyHasDisplayName
		or not data.gui or data.gui.Parent ~= attachPart
		or data.gui.Name ~= expectedBillboardName
		or not data.infoLabel or data.infoLabel.Parent ~= data.gui
		or data.hasDisplayName and (not data.displayLabel or data.displayLabel.Parent ~= data.gui)
		or not data.highlight or data.highlight.Parent ~= character
		or data.highlight.Name ~= expectedHighlightName
		or data.highlight.Adornee ~= character

	if needsRecreate then
		createNpcOverlay(character)
		data = npcOverlayData[character]
	end
	if not data or not data.infoLabel or not data.infoLabel.Parent then return end

	local overlayColor = Color3.fromRGB(255, 255, 255)
	local studsText = "?"
	if localDistancePart and distancePart then
		studsText = tostring(math.floor((localDistancePart.Position - distancePart.Position).Magnitude))
	end
	local hpText = math.floor(math.max(0, humanoid.Health))
		.. "/" .. math.floor(math.max(0, humanoid.MaxHealth)) .. " HP"

	if data.hasDisplayName then
		if data.displayLabel and data.displayLabel.Parent then
			data.displayLabel.Text = currentDisplayName
			data.displayLabel.TextColor3 = overlayColor
		end
		data.infoLabel.Text = studsText .. " studs | " .. identifier .. " | " .. hpText
	else
		data.infoLabel.Text = studsText .. " studs | " .. identifier .. " | " .. hpText
		data.infoLabel.TextColor3 = overlayColor
	end
	data.highlight.FillColor = overlayColor
	data.highlight.OutlineColor = overlayColor
end

local function updatePlayerOverlays()
	if isShuttingDown or not overlayEnabled then return end
	local localDistancePart = getLocalDistancePart()

	if targetModeIncludesPlayers() then
		for _, targetPlayer in ipairs(Players:GetPlayers()) do
			if targetPlayer ~= player then
				updatePlayerOverlayTarget(targetPlayer, localDistancePart)
			end
		end
	end

	local stalePlayers = {}
	for targetPlayer in pairs(overlayData) do
		if not targetModeIncludesPlayers() or not targetPlayer or targetPlayer.Parent ~= Players then
			table.insert(stalePlayers, targetPlayer)
		end
	end
	for _, targetPlayer in ipairs(stalePlayers) do
		removePlayerOverlay(targetPlayer)
	end

	if targetModeIncludesNpcs() then
		for character in pairs(npcCharacters) do
			if isNpcCharacter(character) then
				updateNpcOverlayTarget(character, localDistancePart)
			else
				removeNpcOverlay(character)
				if not isCharacterInWorkspace(character) or Players:GetPlayerFromCharacter(character) ~= nil then
					npcCharacters[character] = nil
				end
			end
		end
	end

	local staleNpcs = {}
	for character in pairs(npcOverlayData) do
		if not targetModeIncludesNpcs() or not isNpcCharacter(character) then
			table.insert(staleNpcs, character)
		end
	end
	for _, character in ipairs(staleNpcs) do
		removeNpcOverlay(character)
	end
end

local function saveOriginalPartSnapshot(targetPlayer, character, part, partName)
	local existingSnapshot = originalPartData[part]
	if existingSnapshot then return existingSnapshot end

	local ok, snapshot = pcall(function()
		return {
			player = targetPlayer,
			character = character,
			partName = partName,
			properties = {
				Size = part.Size,
				Transparency = part.Transparency,
				CanCollide = part.CanCollide,
				Color = part.Color,
				Material = part.Material,
			},
			modifiedProperties = {},
		}
	end)
	if not ok then return nil end
	originalPartData[part] = snapshot
	return snapshot
end

local function restoreOriginalPart(part, snapshot)
	if part and snapshot and snapshot.properties and snapshot.modifiedProperties then
		for propertyName in pairs(snapshot.modifiedProperties) do
			local value = snapshot.properties[propertyName]
			pcall(function()
				part[propertyName] = value
			end)
		end
	end
	originalPartData[part] = nil
end

local function restoreCharacterParts(character)
	if not character then return end
	local partsToRestore = {}
	for part, snapshot in pairs(originalPartData) do
		if snapshot.character == character then
			table.insert(partsToRestore, {part, snapshot})
		end
	end
	for _, item in ipairs(partsToRestore) do
		restoreOriginalPart(item[1], item[2])
	end
end

local function restorePlayerParts(targetPlayer)
	if not targetPlayer then return end
	local partsToRestore = {}
	for part, snapshot in pairs(originalPartData) do
		if snapshot.player == targetPlayer then
			table.insert(partsToRestore, {part, snapshot})
		end
	end
	for _, item in ipairs(partsToRestore) do
		restoreOriginalPart(item[1], item[2])
	end
end

local function forceRestoreAllExpandedParts()
	local partsToRestore = {}
	for part, snapshot in pairs(originalPartData) do
		table.insert(partsToRestore, {part, snapshot})
	end
	for _, item in ipairs(partsToRestore) do
		restoreOriginalPart(item[1], item[2])
	end
end

local function applyExpansionToPart(targetPlayer, character, part, partName, teamColor, targetSize)
	local existingSnapshot = originalPartData[part]
	if existingSnapshot and (
		existingSnapshot.player ~= targetPlayer
		or existingSnapshot.character ~= character
		or existingSnapshot.partName ~= partName
	) then
		restoreOriginalPart(part, existingSnapshot)
	end

	local snapshot = saveOriginalPartSnapshot(targetPlayer, character, part, partName)
	if not snapshot then return end
	local modifiedProperties = snapshot.modifiedProperties

	modifiedProperties.Size = true
	modifiedProperties.Transparency = true
	modifiedProperties.CanCollide = true
	if partName == "HumanoidRootPart" then
		part.Size = targetSize
		part.Transparency = 1
		part.CanCollide = false
	else
		modifiedProperties.Color = true
		modifiedProperties.Material = true
		part.Size = targetSize
		part.CanCollide = false
		part.Color = teamColor
		part.Material = Enum.Material.ForceField
		part.Transparency = hideExpandedParts and 1 or 0.7
	end
end

local function expandCharacterParts(targetPlayer, character, teamColor, expandedPartsThisUpdate)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not isCharacterInWorkspace(character) or not humanoid or humanoid.Health <= 0 then
		if character then restoreCharacterParts(character) end
		return
	end

	for _, partName in ipairs(expandablePartNames) do
		local setting = partSettings[partName]
		if setting and setting.enabled then
			local part = character:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				local size = getEffectivePartSize(partName)
				local targetSize = Vector3.new(size, size, size)
				expandedPartsThisUpdate[part] = true
				applyExpansionToPart(targetPlayer, character, part, partName, teamColor, targetSize)
			end
		end
	end
end

local function updateExpandedParts()
	if isShuttingDown or not expanderEnabled then return end
	local expandedPartsThisUpdate = {}

	if targetModeIncludesPlayers() then
		for _, targetPlayer in ipairs(Players:GetPlayers()) do
			if targetPlayer ~= player then
				expandCharacterParts(
					targetPlayer,
					targetPlayer.Character,
					getTeamColor(targetPlayer),
					expandedPartsThisUpdate
				)
			end
		end
	end

	if targetModeIncludesNpcs() then
		for character in pairs(npcCharacters) do
			if isNpcCharacter(character) then
				expandCharacterParts(nil, character, Color3.fromRGB(255, 255, 255), expandedPartsThisUpdate)
			elseif not isCharacterInWorkspace(character) or Players:GetPlayerFromCharacter(character) ~= nil then
				npcCharacters[character] = nil
			end
		end
	end

	local staleParts = {}
	for part, snapshot in pairs(originalPartData) do
		if not part.Parent
			or not expandedPartsThisUpdate[part]
			or not snapshot.character
			or not part:IsDescendantOf(snapshot.character) then
			table.insert(staleParts, {part, snapshot})
		end
	end
	for _, item in ipairs(staleParts) do
		if item[2] then
			restoreOriginalPart(item[1], item[2])
		else
			originalPartData[item[1]] = nil
		end
	end
end

local function resetExpandedParts()
	forceRestoreAllExpandedParts()
end

local function disconnectConnection(connection)
	if connection then
		pcall(function()
			connection:Disconnect()
		end)
	end
end

local function cancelWindowDrag()
	isDragging = false
	dragPointerInput = nil
	dragStart = nil
	startPos = nil
	local activeDragEndConnection = dragEndConnection
	dragEndConnection = nil
	disconnectConnection(activeDragEndConnection)
end

local function doApplyExpansion()
	if isShuttingDown then return end
	local inputValue = normalizeExpansionSize(expansionSizeInput.Text)
	if inputValue then
		expansionSize = inputValue
		expansionSizeInput.Text = tostring(expansionSize)
		updateAllPartSettingVisuals()
		if expanderEnabled then
			updateExpandedParts()
		end
		collectAndSave()
		animateButton(applyExpansionButton)
		TweenService:Create(applyExpansionButton, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(50, 220, 120)}):Play()
		task.delay(0.25, function()
			if not isShuttingDown and applyExpansionButton.Parent then
				TweenService:Create(applyExpansionButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(80, 150, 255)}):Play()
			end
		end)
	else
		TweenService:Create(expansionSizeInputStroke, TweenInfo.new(0.08), {Color = Color3.fromRGB(220, 50, 50)}):Play()
		task.delay(0.4, function()
			if not isShuttingDown and expansionSizeInputStroke.Parent then
				local color = currentTheme == "light" and Color3.fromRGB(200, 200, 210) or Color3.fromRGB(80, 80, 90)
				TweenService:Create(expansionSizeInputStroke, TweenInfo.new(0.1), {Color = color}):Play()
			end
		end)
	end
end

local function clampMainFrameToViewport()
	if isShuttingDown or not isRuntimeGuiMounted() then return end

	local canvasPosition = screenGui.AbsolutePosition
	local canvasSize = screenGui.AbsoluteSize
	local absolutePosition = mainFrame.AbsolutePosition
	local absoluteSize = mainFrame.AbsoluteSize
	if canvasSize.X <= 0 or canvasSize.Y <= 0 or absoluteSize.X <= 0 or absoluteSize.Y <= 0 then return end

	local minimumX = canvasPosition.X
	local minimumY = canvasPosition.Y
	local maximumX = math.max(minimumX, canvasPosition.X + canvasSize.X - absoluteSize.X)
	local maximumY = math.max(minimumY, canvasPosition.Y + canvasSize.Y - absoluteSize.Y)
	local correctionX = math.clamp(absolutePosition.X, minimumX, maximumX) - absolutePosition.X
	local correctionY = math.clamp(absolutePosition.Y, minimumY, maximumY) - absolutePosition.Y
	if correctionX ~= 0 or correctionY ~= 0 then
		mainFrame.Position = UDim2.new(
			mainFrame.Position.X.Scale,
			mainFrame.Position.X.Offset + correctionX,
			mainFrame.Position.Y.Scale,
			mainFrame.Position.Y.Offset + correctionY
		)
	end
end

local function doMinimize()
	if isShuttingDown or confirmFrame.Visible or settingsFrame.Visible or targetFrame.Visible then return end
	cancelWindowDrag()
	isMinimized = not isMinimized
	if isMinimized then
		TweenService:Create(mainFrame, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 260, 0, 60)}):Play()
		contentFrame.Visible = false
		footerLabel.Visible = false
		footerLabelMinimized.Visible = true
	else
		TweenService:Create(mainFrame, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 260, 0, 180)}):Play()
		contentFrame.Visible = true
		footerLabel.Visible = true
		footerLabelMinimized.Visible = false
		task.delay(0.11, clampMainFrameToViewport)
	end
end

local function doToggleExpander()
	if isShuttingDown then return end
	expanderEnabled = not expanderEnabled
	expansionUpdateAccumulator = 0
	if expanderEnabled then
		TweenService:Create(expanderToggleButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(50, 200, 100)}):Play()
		expanderToggleButton.Text = "Hitbox expansion: ON"
		updateExpandedParts()
	else
		TweenService:Create(expanderToggleButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(220, 50, 50)}):Play()
		expanderToggleButton.Text = "Hitbox expansion: OFF"
		resetExpandedParts()
	end
end

local function doToggleOverlay()
	if isShuttingDown then return end
	overlayEnabled = not overlayEnabled
	overlayUpdateAccumulator = 0
	if overlayEnabled then
		TweenService:Create(overlayToggleButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(50, 200, 100)}):Play()
		overlayToggleButton.Text = "Player overlay: ON"
		updatePlayerOverlays()
	else
		TweenService:Create(overlayToggleButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(220, 50, 50)}):Play()
		overlayToggleButton.Text = "Player overlay: OFF"
		removeAllPlayerOverlays()
	end
end

local function setTargetMode(mode, shouldSave)
	if isShuttingDown or not VALID_TARGET_MODES[mode] then return end
	targetMode = mode
	removeAllPlayerOverlays()
	updateTargetModeVisual()
	if expanderEnabled then updateExpandedParts() end
	if overlayEnabled then updatePlayerOverlays() end
	if shouldSave ~= false then collectAndSave() end
end

local function doToggleGui()
	if isShuttingDown or not isRuntimeGuiMounted() then return end
	guiVisible = not guiVisible
	if not guiVisible then
		cancelWindowDrag()
		if listeningFor then setListening(nil) end
	end
	mainFrame.Visible = guiVisible
	if guiVisible then task.defer(clampMainFrameToViewport) end
end

local function trackServiceConnection(connection)
	table.insert(serviceConnections, connection)
	return connection
end

local function scheduleViewportClamp()
	if isShuttingDown or viewportClampScheduled then return end
	viewportClampScheduled = true
	task.defer(function()
		viewportClampScheduled = false
		clampMainFrameToViewport()
	end)
end

local function refreshViewportTracking()
	disconnectConnection(viewportSizeConnection)
	viewportSizeConnection = nil
	local camera = workspace.CurrentCamera
	if camera then
		viewportSizeConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(scheduleViewportClamp)
	end
	scheduleViewportClamp()
end

local function disconnectCharacterTracking(targetPlayer)
	local connections = characterConnections[targetPlayer]
	if not connections then
		trackedCharacters[targetPlayer] = nil
		return
	end
	for _, connection in pairs(connections) do
		disconnectConnection(connection)
	end
	characterConnections[targetPlayer] = nil
	trackedCharacters[targetPlayer] = nil
end

local function handleCharacterAdded(targetPlayer, character)
	if isShuttingDown or not character or targetPlayer.Parent ~= Players or targetPlayer.Character ~= character then return end
	restorePlayerParts(targetPlayer)
	removePlayerOverlay(targetPlayer)
	removeManagedOverlayInstances(targetPlayer.Name, character)
	if expanderEnabled then updateExpandedParts() end
	if overlayEnabled then updatePlayerOverlays() end
end

local function handleCharacterRemoving(targetPlayer, character)
	if isShuttingDown then return end
	restoreCharacterParts(character)
	local data = overlayData[targetPlayer]
	if data and data.character == character then
		removePlayerOverlay(targetPlayer)
	end
	removeManagedOverlayInstances(targetPlayer.Name, character)
end

local function setupCharacterTracking(targetPlayer)
	if isShuttingDown or not targetPlayer or targetPlayer == player or targetPlayer.Parent ~= Players then return end
	disconnectCharacterTracking(targetPlayer)
	characterConnections[targetPlayer] = {
		added = targetPlayer.CharacterAdded:Connect(function(character)
			if isShuttingDown or targetPlayer.Parent ~= Players or targetPlayer.Character ~= character then return end
			if trackedCharacters[targetPlayer] == character then return end
			trackedCharacters[targetPlayer] = character
			handleCharacterAdded(targetPlayer, character)
		end),
		removing = targetPlayer.CharacterRemoving:Connect(function(character)
			if isShuttingDown then return end
			if trackedCharacters[targetPlayer] == character then
				trackedCharacters[targetPlayer] = nil
			end
			handleCharacterRemoving(targetPlayer, character)
		end),
	}

	local currentCharacter = targetPlayer.Character
	if currentCharacter and trackedCharacters[targetPlayer] ~= currentCharacter then
		trackedCharacters[targetPlayer] = currentCharacter
		handleCharacterAdded(targetPlayer, currentCharacter)
	end
end

local function unregisterNpcCharacter(character)
	if not character or not npcCharacters[character] then return end
	restoreCharacterParts(character)
	local data = npcOverlayData[character]
	removeNpcOverlay(character)
	removeManagedOverlayInstances(data and data.identifier or character.Name, character)
	npcCharacters[character] = nil
end

local function applyLoadedSettings()
	if type(savedData) ~= "table" then
		applyTheme("dark", false)
		updateAllPartSettingVisuals()
		return
	end

	local loadedSize = normalizeExpansionSize(savedData.expansionSize)
	if not loadedSize then loadedSize = normalizeExpansionSize(savedData.hitboxSize) end
	if loadedSize then
		expansionSize = loadedSize
		expansionSizeInput.Text = tostring(expansionSize)
	end

	if type(savedData.targetMode) == "string" and VALID_TARGET_MODES[savedData.targetMode] then
		targetMode = savedData.targetMode
	end

	if type(savedData.partSettings) == "table" then
		for _, partName in ipairs(expandablePartNames) do
			local loadedPartSetting = savedData.partSettings[partName]
			if type(loadedPartSetting) == "table" then
				if type(loadedPartSetting.enabled) == "boolean" then
					partSettings[partName].enabled = loadedPartSetting.enabled
				end
				local loadedOverride = normalizeExpansionSize(loadedPartSetting.sizeOverride)
				if not loadedOverride then loadedOverride = normalizeExpansionSize(loadedPartSetting.size) end
				partSettings[partName].sizeOverride = loadedOverride
			end
		end
	end
	updateAllPartSettingVisuals()

	local loadedHideSetting = savedData.hideExpandedParts
	if type(loadedHideSetting) ~= "boolean" then
		loadedHideSetting = savedData["disableTransparency"]
	end
	if type(loadedHideSetting) == "boolean" then
		hideExpandedParts = loadedHideSetting
	end
	if hideExpandedParts then
		hideExpandedPartsButton.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
		hideExpandedPartsButton.Text = "ON"
	else
		hideExpandedPartsButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
		hideExpandedPartsButton.Text = "OFF"
	end

	if type(savedData.keybinds) == "table" then
		local usedKeys = {}
		for _, actionName in ipairs(keybindActionNames) do
			local keyName = savedData.keybinds[actionName]
			local legacyActionName = legacyKeybindActionNames[actionName]
			if type(keyName) ~= "string" and legacyActionName then
				keyName = savedData.keybinds[legacyActionName]
			end
			if type(keyName) == "string" and keyName ~= "None" then
				local ok, keyCode = pcall(function()
					return Enum.KeyCode[keyName]
				end)
				if ok and keyCode and keyCode ~= Enum.KeyCode.Unknown and not usedKeys[keyCode] then
					keybinds[actionName] = keyCode
					usedKeys[keyCode] = true
				end
			end
			updateKeybindVisual(actionName)
		end
	end

	local loadedTheme = savedData.theme == "light" and "light" or "dark"
	applyTheme(loadedTheme, false)
end

local function loadedSettingsNeedRewrite()
	if type(savedData) ~= "table" then return false end
	if savedData.expansionSize ~= expansionSize
		or savedData.theme ~= currentTheme
		or savedData.hideExpandedParts ~= hideExpandedParts
		or savedData.targetMode ~= targetMode
		or type(savedData.partSettings) ~= "table"
		or type(savedData.keybinds) ~= "table" then
		return true
	end
	for _, partName in ipairs(expandablePartNames) do
		local setting = partSettings[partName]
		local savedSetting = savedData.partSettings[partName]
		if type(savedSetting) ~= "table"
			or savedSetting.enabled ~= setting.enabled
			or savedSetting.sizeOverride ~= setting.sizeOverride
			or savedSetting.size ~= nil then
			return true
		end
	end
	for _, actionName in ipairs(keybindActionNames) do
		local keyCode = keybinds[actionName]
		local expectedKeyName = keyCode and keyCode.Name or "None"
		if savedData.keybinds[actionName] ~= expectedKeyName then return true end
	end
	return false
end

local registeredShutdown = nil
local function shutdownRuntime(animateClose, guiAlreadyDestroying)
	if isShuttingDown then return end
	isShuttingDown = true
	expanderEnabled = false
	overlayEnabled = false
	cancelWindowDrag()
	listeningFor = nil
	disconnectConnection(viewportSizeConnection)
	viewportSizeConnection = nil

	pcall(forceRestoreAllExpandedParts)
	pcall(removeAllPlayerOverlays)
	table.clear(npcCharacters)
	table.clear(npcOverlayData)

	local trackedPlayers = {}
	for targetPlayer in pairs(characterConnections) do
		table.insert(trackedPlayers, targetPlayer)
	end
	for _, targetPlayer in ipairs(trackedPlayers) do
		disconnectCharacterTracking(targetPlayer)
	end
	table.clear(trackedCharacters)
	for _, connection in ipairs(serviceConnections) do
		disconnectConnection(connection)
	end
	table.clear(serviceConnections)

	pcall(function()
		if runtimeEnvironment[RUNTIME_KEY] == registeredShutdown then
			runtimeEnvironment[RUNTIME_KEY] = nil
		end
	end)

	if animateClose and isRuntimeGuiMounted() then
		local animationStarted = pcall(function()
			TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
				Size = UDim2.new(0, 0, 0, 0),
				Position = UDim2.new(
					mainFrame.Position.X.Scale,
					mainFrame.Position.X.Offset + 130,
					mainFrame.Position.Y.Scale,
					mainFrame.Position.Y.Offset + 90
				),
			}):Play()
		end)
		if animationStarted then task.wait(0.3) end
	end

	if not guiAlreadyDestroying then
		destroyInstance(screenGui)
	end
end

registeredShutdown = function()
	shutdownRuntime(false)
end
pcall(function()
	runtimeEnvironment[RUNTIME_KEY] = registeredShutdown
end)

trackServiceConnection(screenGui.Destroying:Connect(function()
	if not isShuttingDown then
		shutdownRuntime(false, true)
	end
end))
trackServiceConnection(mainFrame.Destroying:Connect(function()
	task.defer(function()
		if not isShuttingDown and mainFrame.Parent ~= screenGui then
			shutdownRuntime(false)
		end
	end)
end))
screenGui.Parent = playerGui

local workspaceDescendantAdded = workspace.DescendantAdded
if workspaceDescendantAdded then
	trackServiceConnection(workspaceDescendantAdded:Connect(function(descendant)
		if isShuttingDown then return end
		registerNpcDescendant(descendant)
		if descendant and descendant:IsA("Humanoid") then
			if expanderEnabled then updateExpandedParts() end
			if overlayEnabled then updatePlayerOverlays() end
		end
	end))
end

local workspaceDescendantRemoving = workspace.DescendantRemoving
if workspaceDescendantRemoving then
	trackServiceConnection(workspaceDescendantRemoving:Connect(function(descendant)
		if isShuttingDown or not descendant then return end
		local character = nil
		if descendant:IsA("Humanoid") then
			character = descendant.Parent
		elseif descendant:IsA("Model") and npcCharacters[descendant] then
			character = descendant
		end
		if character then unregisterNpcCharacter(character) end
	end))
end

local descendantsLoaded, workspaceDescendants = pcall(function()
	return workspace:GetDescendants()
end)
if descendantsLoaded and type(workspaceDescendants) == "table" then
	for _, descendant in ipairs(workspaceDescendants) do
		registerNpcDescendant(descendant)
	end
end

for _, targetPlayer in ipairs(Players:GetPlayers()) do
	if targetPlayer ~= player then
		setupCharacterTracking(targetPlayer)
	end
end

trackServiceConnection(Players.PlayerAdded:Connect(function(newPlayer)
	if isShuttingDown then return end
	setupCharacterTracking(newPlayer)
end))

trackServiceConnection(Players.PlayerRemoving:Connect(function(removedPlayer)
	if isShuttingDown then return end
	if removedPlayer == player then
		shutdownRuntime(false)
		return
	end
	local character = removedPlayer.Character
	restorePlayerParts(removedPlayer)
	removePlayerOverlay(removedPlayer)
	removeManagedOverlayInstances(removedPlayer.Name, character)
	disconnectCharacterTracking(removedPlayer)
end))

trackServiceConnection(screenGui:GetPropertyChangedSignal("AbsolutePosition"):Connect(scheduleViewportClamp))
trackServiceConnection(screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleViewportClamp))
trackServiceConnection(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if not isShuttingDown then refreshViewportTracking() end
end))
local windowFocusReleased = UserInputService.WindowFocusReleased
if windowFocusReleased then
	trackServiceConnection(windowFocusReleased:Connect(cancelWindowDrag))
end
refreshViewportTracking()

applyExpansionButton.MouseButton1Click:Connect(function()
	doApplyExpansion()
end)

expansionSizeInput.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		doApplyExpansion()
	end
end)

for _, partName in ipairs(expandablePartNames) do
	local capturedPartName = partName
	local controls = partSettingControls[capturedPartName]
	controls.toggle.MouseButton1Click:Connect(function()
		if isShuttingDown then return end
		animateButton(controls.toggle)
		partSettings[capturedPartName].enabled = not partSettings[capturedPartName].enabled
		updatePartSettingVisual(capturedPartName)
		if expanderEnabled then updateExpandedParts() end
		collectAndSave()
	end)
	controls.input.FocusLost:Connect(function()
		if isShuttingDown then return end
		local inputText = tostring(controls.input.Text or "")
		local newOverride = nil
		local isValid = string.match(inputText, "^%s*$") ~= nil
		if not isValid then
			newOverride = normalizeExpansionSize(inputText)
			isValid = newOverride ~= nil
		end
		if isValid then
			partSettings[capturedPartName].sizeOverride = newOverride
			updatePartSettingVisual(capturedPartName)
			if expanderEnabled then updateExpandedParts() end
			collectAndSave()
		else
			updatePartSettingVisual(capturedPartName)
			TweenService:Create(controls.stroke, TweenInfo.new(0.08), {Color = Color3.fromRGB(220, 50, 50)}):Play()
			task.delay(0.4, function()
				if not isShuttingDown and controls.stroke.Parent then
					local color = currentTheme == "light" and Color3.fromRGB(200, 200, 210)
						or Color3.fromRGB(80, 80, 100)
					TweenService:Create(controls.stroke, TweenInfo.new(0.1), {Color = color}):Play()
				end
			end)
		end
	end)
end

expanderToggleButton.MouseButton1Click:Connect(function()
	animateButton(expanderToggleButton)
	doToggleExpander()
end)

overlayToggleButton.MouseButton1Click:Connect(function()
	animateButton(overlayToggleButton)
	doToggleOverlay()
end)

targetModeButton.MouseButton1Click:Connect(function()
	if isShuttingDown or confirmFrame.Visible or settingsFrame.Visible or targetFrame.Visible then return end
	cancelWindowDrag()
	animateButton(targetModeButton)
	targetFrame.Visible = true
	targetFrame.Position = UDim2.new(1, 0, 0, 0)
	TweenService:Create(targetFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0),
	}):Play()
end)

targetBackButton.MouseButton1Click:Connect(function()
	if isShuttingDown then return end
	cancelWindowDrag()
	animateButton(targetBackButton)
	TweenService:Create(targetFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(1, 0, 0, 0),
	}):Play()
	task.wait(0.2)
	if not isShuttingDown and targetFrame.Parent then targetFrame.Visible = false end
end)

for mode, modeButton in pairs(targetModeButtons) do
	local capturedMode = mode
	local capturedButton = modeButton
	capturedButton.MouseButton1Click:Connect(function()
		if isShuttingDown then return end
		animateButton(capturedButton)
		setTargetMode(capturedMode)
	end)
end

hideExpandedPartsButton.MouseButton1Click:Connect(function()
	if isShuttingDown then return end
	animateButton(hideExpandedPartsButton)
	hideExpandedParts = not hideExpandedParts
	if hideExpandedParts then
		TweenService:Create(hideExpandedPartsButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(50, 200, 100)}):Play()
		hideExpandedPartsButton.Text = "ON"
	else
		TweenService:Create(hideExpandedPartsButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(220, 50, 50)}):Play()
		hideExpandedPartsButton.Text = "OFF"
	end
	if expanderEnabled then updateExpandedParts() end
	collectAndSave()
end)

minimizeButton.MouseButton1Click:Connect(function()
	animateButton(minimizeButton)
	doMinimize()
end)

closeButton.MouseButton1Click:Connect(function()
	if isShuttingDown or confirmFrame.Visible or settingsFrame.Visible or targetFrame.Visible then return end
	cancelWindowDrag()
	animateButton(closeButton)
	if isMinimized then
		isMinimized = false
		TweenService:Create(mainFrame, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 260, 0, 180)}):Play()
		contentFrame.Visible = true
		footerLabel.Visible = true
		footerLabelMinimized.Visible = false
		task.delay(0.11, clampMainFrameToViewport)
	end
	confirmFrame.Visible = true
	TweenService:Create(confirmFrame, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.05}):Play()
end)

yesButton.MouseButton1Click:Connect(function()
	animateButton(yesButton)
	shutdownRuntime(true)
end)

noButton.MouseButton1Click:Connect(function()
	if isShuttingDown then return end
	animateButton(noButton)
	TweenService:Create(confirmFrame, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
	task.wait(0.1)
	if not isShuttingDown and confirmFrame.Parent then
		confirmFrame.Visible = false
	end
end)

settingsButtonTop.MouseButton1Click:Connect(function()
	if isShuttingDown or confirmFrame.Visible or settingsFrame.Visible or targetFrame.Visible then return end
	cancelWindowDrag()
	animateButton(settingsButtonTop)
	if isMinimized then
		isMinimized = false
		TweenService:Create(mainFrame, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 260, 0, 180)}):Play()
		contentFrame.Visible = true
		footerLabel.Visible = true
		footerLabelMinimized.Visible = false
		task.delay(0.11, clampMainFrameToViewport)
	end
	settingsFrame.Visible = true
	settingsFrame.Position = UDim2.new(1, 0, 0, 0)
	TweenService:Create(settingsFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
end)

backButton.MouseButton1Click:Connect(function()
	if isShuttingDown then return end
	cancelWindowDrag()
	animateButton(backButton)
	if listeningFor then setListening(nil) end
	TweenService:Create(settingsFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(1, 0, 0, 0)}):Play()
	task.wait(0.2)
	if not isShuttingDown then
		if listeningFor then setListening(nil) end
		if settingsFrame.Parent then settingsFrame.Visible = false end
	end
end)

darkButton.MouseButton1Click:Connect(function()
	animateButton(darkButton)
	applyTheme("dark")
end)

lightButton.MouseButton1Click:Connect(function()
	animateButton(lightButton)
	applyTheme("light")
end)

footerLabel.MouseButton1Click:Connect(function()
	animateButton(footerLabel)
end)

footerLabelMinimized.MouseButton1Click:Connect(function()
	animateButton(footerLabelMinimized)
end)

trackServiceConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if isShuttingDown or input.UserInputType ~= Enum.UserInputType.Keyboard or not isRuntimeGuiMounted() then return end
	if listeningFor and (not guiVisible or not settingsFrame.Parent or not settingsFrame.Visible) then
		setListening(nil)
		return
	end
	if listeningFor then
		if input.KeyCode == Enum.KeyCode.Escape then
			setListening(nil)
		elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
			local actionName = listeningFor
			applyKeybind(actionName, nil)
			setListening(nil)
		elseif input.KeyCode ~= Enum.KeyCode.Unknown then
			local actionName = listeningFor
			applyKeybind(actionName, input.KeyCode)
			setListening(nil)
		end
		return
	end
	if gameProcessed or UserInputService:GetFocusedTextBox() then return end

	if keybinds.expander and input.KeyCode == keybinds.expander then
		doToggleExpander()
	elseif keybinds.overlay and input.KeyCode == keybinds.overlay then
		doToggleOverlay()
	elseif keybinds.gui and input.KeyCode == keybinds.gui then
		doToggleGui()
	elseif keybinds.minimize and input.KeyCode == keybinds.minimize then
		doMinimize()
	elseif keybinds.applyExpansion and input.KeyCode == keybinds.applyExpansion then
		doApplyExpansion()
	end
end))

trackServiceConnection(RunService.Heartbeat:Connect(function(deltaTime)
	if isShuttingDown then return end
	if not isRuntimeGuiMounted() then
		shutdownRuntime(false)
		return
	end

	if expanderEnabled then
		expansionUpdateAccumulator = expansionUpdateAccumulator + deltaTime
		if expansionUpdateAccumulator >= EXPANSION_UPDATE_INTERVAL then
			expansionUpdateAccumulator = expansionUpdateAccumulator % EXPANSION_UPDATE_INTERVAL
			updateExpandedParts()
		end
	else
		expansionUpdateAccumulator = 0
	end

	if overlayEnabled then
		overlayUpdateAccumulator = overlayUpdateAccumulator + deltaTime
		if overlayUpdateAccumulator >= OVERLAY_UPDATE_INTERVAL then
			overlayUpdateAccumulator = overlayUpdateAccumulator % OVERLAY_UPDATE_INTERVAL
			updatePlayerOverlays()
		end
	else
		overlayUpdateAccumulator = 0
	end
end))

local function beginWindowDrag(input)
	if isShuttingDown or not guiVisible or isDragging or not isRuntimeGuiMounted() then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isDragging = true
		dragPointerInput = input
		dragStart = input.Position
		startPos = mainFrame.Position
		disconnectConnection(dragEndConnection)
		dragEndConnection = input.Changed:Connect(function()
			local inputState = input.UserInputState
			if (inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel)
				and dragPointerInput == input then
				cancelWindowDrag()
			end
		end)
	end
end

titleLabel.InputBegan:Connect(beginWindowDrag)
settingsTitleLabel.InputBegan:Connect(beginWindowDrag)
targetTitleLabel.InputBegan:Connect(beginWindowDrag)

trackServiceConnection(UserInputService.InputChanged:Connect(function(input)
	if isShuttingDown or not guiVisible or not isDragging or not dragPointerInput then return end
	if not isRuntimeGuiMounted() then
		cancelWindowDrag()
		return
	end
	local isTouchMovement = dragPointerInput.UserInputType == Enum.UserInputType.Touch and input == dragPointerInput
	local isMouseMovement = dragPointerInput.UserInputType == Enum.UserInputType.MouseButton1
		and input.UserInputType == Enum.UserInputType.MouseMovement
	if not isTouchMovement and not isMouseMovement then return end

	local delta = input.Position - dragStart
	local proposedPosition = UDim2.new(
		startPos.X.Scale,
		startPos.X.Offset + delta.X,
		startPos.Y.Scale,
		startPos.Y.Offset + delta.Y
	)
	mainFrame.Position = proposedPosition
	clampMainFrameToViewport()
end))

applyExpansionButton.MouseEnter:Connect(function()
	TweenService:Create(applyExpansionButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(100, 170, 255)}):Play()
end)
applyExpansionButton.MouseLeave:Connect(function()
	TweenService:Create(applyExpansionButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(80, 150, 255)}):Play()
end)
minimizeButton.MouseEnter:Connect(function()
	TweenService:Create(minimizeButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(255, 220, 80)}):Play()
end)
minimizeButton.MouseLeave:Connect(function()
	TweenService:Create(minimizeButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(255, 200, 50)}):Play()
end)
closeButton.MouseEnter:Connect(function()
	TweenService:Create(closeButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(255, 70, 70)}):Play()
end)
closeButton.MouseLeave:Connect(function()
	TweenService:Create(closeButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(220, 50, 50)}):Play()
end)
settingsButtonTop.MouseEnter:Connect(function()
	if currentTheme == "dark" then
		TweenService:Create(settingsButtonTop, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(120, 120, 140)}):Play()
	else
		TweenService:Create(settingsButtonTop, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(220, 220, 240)}):Play()
	end
end)
settingsButtonTop.MouseLeave:Connect(function()
	if currentTheme == "dark" then
		TweenService:Create(settingsButtonTop, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(100, 100, 120)}):Play()
	else
		TweenService:Create(settingsButtonTop, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(200, 200, 220)}):Play()
	end
end)
yesButton.MouseEnter:Connect(function()
	TweenService:Create(yesButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(70, 220, 120)}):Play()
end)
yesButton.MouseLeave:Connect(function()
	TweenService:Create(yesButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(50, 200, 100)}):Play()
end)
noButton.MouseEnter:Connect(function()
	TweenService:Create(noButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(255, 70, 70)}):Play()
end)
noButton.MouseLeave:Connect(function()
	TweenService:Create(noButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(220, 50, 50)}):Play()
end)
backButton.MouseEnter:Connect(function()
	TweenService:Create(backButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(100, 100, 110)}):Play()
end)
backButton.MouseLeave:Connect(function()
	TweenService:Create(backButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(80, 80, 90)}):Play()
end)
darkButton.MouseEnter:Connect(function()
	TweenService:Create(darkButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(40, 40, 50)}):Play()
end)
darkButton.MouseLeave:Connect(function()
	TweenService:Create(darkButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30, 30, 40)}):Play()
end)
lightButton.MouseEnter:Connect(function()
	TweenService:Create(lightButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
end)
lightButton.MouseLeave:Connect(function()
	TweenService:Create(lightButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(240, 240, 250)}):Play()
end)
expanderToggleButton.MouseEnter:Connect(function()
	if expanderEnabled then
		TweenService:Create(expanderToggleButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(70, 220, 120)}):Play()
	else
		TweenService:Create(expanderToggleButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(255, 70, 70)}):Play()
	end
end)
expanderToggleButton.MouseLeave:Connect(function()
	if expanderEnabled then
		TweenService:Create(expanderToggleButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(50, 200, 100)}):Play()
	else
		TweenService:Create(expanderToggleButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(220, 50, 50)}):Play()
	end
end)
overlayToggleButton.MouseEnter:Connect(function()
	if overlayEnabled then
		TweenService:Create(overlayToggleButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(70, 220, 120)}):Play()
	else
		TweenService:Create(overlayToggleButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(255, 70, 70)}):Play()
	end
end)
overlayToggleButton.MouseLeave:Connect(function()
	if overlayEnabled then
		TweenService:Create(overlayToggleButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(50, 200, 100)}):Play()
	else
		TweenService:Create(overlayToggleButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(220, 50, 50)}):Play()
	end
end)
hideExpandedPartsButton.MouseEnter:Connect(function()
	if hideExpandedParts then
		TweenService:Create(hideExpandedPartsButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(70, 220, 120)}):Play()
	else
		TweenService:Create(hideExpandedPartsButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(255, 70, 70)}):Play()
	end
end)
hideExpandedPartsButton.MouseLeave:Connect(function()
	if hideExpandedParts then
		TweenService:Create(hideExpandedPartsButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(50, 200, 100)}):Play()
	else
		TweenService:Create(hideExpandedPartsButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(220, 50, 50)}):Play()
	end
end)

applyLoadedSettings()
if settingsNeedMigration or loadedSettingsNeedRewrite() then collectAndSave() end
