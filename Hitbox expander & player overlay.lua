local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local APP_NAME = "Hitbox expander & player overlay"
local GUI_NAME = "HitboxExpanderPlayerOverlay"
local RUNTIME_KEY = "__HitboxExpanderPlayerOverlayRuntime"
local SETTINGS_FILE = "hitbox_expander_player_overlay_settings.json"
local MIN_EXPANSION_SIZE = 1
local MAX_EXPANSION_SIZE = 100
local EXPANSION_UPDATE_INTERVAL = 1 / 30
local OVERLAY_UPDATE_INTERVAL = 0.1

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

local existingGui = playerGui:FindFirstChild(GUI_NAME)
if existingGui then
	pcall(function()
		existingGui:Destroy()
	end)
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

local function loadSettings()
	if type(readfile) ~= "function" then return nil end
	local ok, result = pcall(function()
		if type(isfile) == "function" and not isfile(SETTINGS_FILE) then
			return nil
		end
		return HttpService:JSONDecode(readfile(SETTINGS_FILE))
	end)
	if ok and type(result) == "table" then return result end
	return nil
end

local savedData = loadSettings()

local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 260, 0, 180)
mainFrame.Position = UDim2.new(0.5, -130, 0.5, -90)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

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

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = titleBar

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

local settingsTopCorner = Instance.new("UICorner")
settingsTopCorner.CornerRadius = UDim.new(0, 6)
settingsTopCorner.Parent = settingsButtonTop

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

local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0, 6)
minimizeCorner.Parent = minimizeButton

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

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

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

local expansionSizeInputCorner = Instance.new("UICorner")
expansionSizeInputCorner.CornerRadius = UDim.new(0, 7)
expansionSizeInputCorner.Parent = expansionSizeInput

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

local applyExpansionCorner = Instance.new("UICorner")
applyExpansionCorner.CornerRadius = UDim.new(0, 7)
applyExpansionCorner.Parent = applyExpansionButton

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

local expanderToggleCorner = Instance.new("UICorner")
expanderToggleCorner.CornerRadius = UDim.new(0, 7)
expanderToggleCorner.Parent = expanderToggleButton

local overlayToggleButton = Instance.new("TextButton")
overlayToggleButton.Size = UDim2.new(0, 236, 0, 32)
overlayToggleButton.Position = UDim2.new(0, 12, 0, 80)
overlayToggleButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
overlayToggleButton.BorderSizePixel = 0
overlayToggleButton.Text = "Player overlay: OFF"
overlayToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
overlayToggleButton.TextSize = 13
overlayToggleButton.Font = Enum.Font.GothamBold
overlayToggleButton.Parent = contentFrame

local overlayToggleCorner = Instance.new("UICorner")
overlayToggleCorner.CornerRadius = UDim.new(0, 7)
overlayToggleCorner.Parent = overlayToggleButton

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
confirmFrame.Visible = false
confirmFrame.ZIndex = 10
confirmFrame.Parent = mainFrame

local confirmCorner = Instance.new("UICorner")
confirmCorner.CornerRadius = UDim.new(0, 12)
confirmCorner.Parent = confirmFrame

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

local yesCorner = Instance.new("UICorner")
yesCorner.CornerRadius = UDim.new(0, 7)
yesCorner.Parent = yesButton

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

local noCorner = Instance.new("UICorner")
noCorner.CornerRadius = UDim.new(0, 7)
noCorner.Parent = noButton

local settingsFrame = Instance.new("Frame")
settingsFrame.Name = "SettingsFrame"
settingsFrame.Size = UDim2.new(1, 0, 1, 0)
settingsFrame.Position = UDim2.new(1, 0, 0, 0)
settingsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
settingsFrame.BorderSizePixel = 0
settingsFrame.Visible = false
settingsFrame.ZIndex = 10
settingsFrame.Parent = mainFrame

local settingsFrameCorner = Instance.new("UICorner")
settingsFrameCorner.CornerRadius = UDim.new(0, 12)
settingsFrameCorner.Parent = settingsFrame

local settingsTitleBar = Instance.new("Frame")
settingsTitleBar.Size = UDim2.new(1, 0, 0, 35)
settingsTitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
settingsTitleBar.BorderSizePixel = 0
settingsTitleBar.ZIndex = 11
settingsTitleBar.Parent = settingsFrame

local settingsTitleCorner = Instance.new("UICorner")
settingsTitleCorner.CornerRadius = UDim.new(0, 12)
settingsTitleCorner.Parent = settingsTitleBar

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

local backCorner = Instance.new("UICorner")
backCorner.CornerRadius = UDim.new(0, 6)
backCorner.Parent = backButton

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

local darkCorner = Instance.new("UICorner")
darkCorner.CornerRadius = UDim.new(0, 7)
darkCorner.Parent = darkButton

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

local lightCorner = Instance.new("UICorner")
lightCorner.CornerRadius = UDim.new(0, 7)
lightCorner.Parent = lightButton

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

local hideExpandedPartsCorner = Instance.new("UICorner")
hideExpandedPartsCorner.CornerRadius = UDim.new(0, 7)
hideExpandedPartsCorner.Parent = hideExpandedPartsButton

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
local isMinimized = false
local currentTheme = "dark"
local guiVisible = true
local isDragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil
local dragEndConnection = nil
local viewportSizeConnection = nil
local overlayData = {}
local characterConnections = {}
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

local expandablePartNames = {
	"HumanoidRootPart", "Head", "Torso",
	"Left Arm", "Right Arm", "Left Leg", "Right Leg",
	"UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"RightUpperLeg", "RightLowerLeg", "RightFoot"
}

local function getKeyName(keyCode)
	if keyCode == nil then return "None" end
	return keyCode.Name
end

local function collectAndSave()
	local data = {
		expansionSize = expansionSize,
		theme = currentTheme,
		hideExpandedParts = hideExpandedParts,
		keybinds = {},
	}
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
	if actionName ~= nil and not keybindButtons[actionName] then return end
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
		for otherAction, assignedKey in pairs(keybinds) do
			if otherAction ~= actionName and assignedKey == keyCode then
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
		TweenService:Create(themeLabel, tweenInfo, {TextColor3 = Color3.fromRGB(60, 60, 70)}):Play()
		TweenService:Create(hideExpandedPartsLabel, tweenInfo, {TextColor3 = Color3.fromRGB(60, 60, 70)}):Play()
		TweenService:Create(keybindSectionLabel, tweenInfo, {TextColor3 = Color3.fromRGB(60, 60, 70)}):Play()
		TweenService:Create(settingsButtonTop, tweenInfo, {BackgroundColor3 = Color3.fromRGB(200, 200, 220), TextColor3 = Color3.fromRGB(30, 30, 40)}):Play()
		TweenService:Create(darkStroke, tweenInfo, {Color = Color3.fromRGB(200, 200, 210)}):Play()
		for _, lbl in pairs(keybindLabels) do
			TweenService:Create(lbl, tweenInfo, {TextColor3 = Color3.fromRGB(80, 80, 90)}):Play()
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
		TweenService:Create(themeLabel, tweenInfo, {TextColor3 = Color3.fromRGB(200, 200, 210)}):Play()
		TweenService:Create(hideExpandedPartsLabel, tweenInfo, {TextColor3 = Color3.fromRGB(200, 200, 210)}):Play()
		TweenService:Create(keybindSectionLabel, tweenInfo, {TextColor3 = Color3.fromRGB(200, 200, 210)}):Play()
		TweenService:Create(settingsButtonTop, tweenInfo, {BackgroundColor3 = Color3.fromRGB(100, 100, 120), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		for _, lbl in pairs(keybindLabels) do
			TweenService:Create(lbl, tweenInfo, {TextColor3 = Color3.fromRGB(180, 180, 190)}):Play()
		end
		TweenService:Create(lightStroke, tweenInfo, {Transparency = 1}):Play()
		TweenService:Create(darkStroke, tweenInfo, {Color = Color3.fromRGB(80, 150, 255)}):Play()
	end
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

local function removeManagedOverlayInstances(targetPlayer, character)
	if not targetPlayer or not character then return end
	local managedNames = {
		["PlayerOverlayBillboard_" .. targetPlayer.Name] = true,
		["PlayerOverlayHighlight_" .. targetPlayer.Name] = true,
	}
	local ok, descendants = pcall(function()
		return character:GetDescendants()
	end)
	if not ok then return end
	for _, descendant in ipairs(descendants) do
		if managedNames[descendant.Name] then
			destroyInstance(descendant)
		end
	end
end

local function removePlayerOverlay(targetPlayer)
	local data = overlayData[targetPlayer]
	if not data then return end
	destroyInstance(data.displayLabel)
	destroyInstance(data.infoLabel)
	destroyInstance(data.gui)
	destroyInstance(data.highlight)
	overlayData[targetPlayer] = nil
end

local function removeAllPlayerOverlays()
	local playersToRemove = {}
	for targetPlayer in pairs(overlayData) do
		table.insert(playersToRemove, targetPlayer)
	end
	for _, targetPlayer in ipairs(playersToRemove) do
		removePlayerOverlay(targetPlayer)
	end
	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if targetPlayer ~= player and targetPlayer.Character then
			removeManagedOverlayInstances(targetPlayer, targetPlayer.Character)
		end
	end
end

local function createPlayerOverlay(targetPlayer)
	if isShuttingDown or not targetPlayer or targetPlayer == player then return end
	removePlayerOverlay(targetPlayer)

	local character = targetPlayer.Character
	if not character or not character.Parent then return end
	local head = character:FindFirstChild("Head")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local attachPart = head and head:IsA("BasePart") and head
		or rootPart and rootPart:IsA("BasePart") and rootPart
	if not attachPart then return end
	if not humanoid or humanoid.Health <= 0 then return end

	removeManagedOverlayInstances(targetPlayer, character)
	local teamColor = getTeamColor(targetPlayer)
	local displayName = tostring(targetPlayer.DisplayName or targetPlayer.Name)
	local hasDisplayName = string.lower(displayName) ~= string.lower(targetPlayer.Name)
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

local function updatePlayerOverlays()
	if isShuttingDown or not overlayEnabled then return end
	local localRootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if targetPlayer ~= player then
			local character = targetPlayer.Character
			local head = character and character:FindFirstChild("Head")
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local attachPart = head and head:IsA("BasePart") and head
				or rootPart and rootPart:IsA("BasePart") and rootPart

			if not character or not character.Parent or not attachPart or not humanoid or humanoid.Health <= 0 then
				removePlayerOverlay(targetPlayer)
				if character then removeManagedOverlayInstances(targetPlayer, character) end
			else
				local data = overlayData[targetPlayer]
				local currentDisplayName = tostring(targetPlayer.DisplayName or targetPlayer.Name)
				local currentlyHasDisplayName = string.lower(currentDisplayName) ~= string.lower(targetPlayer.Name)
				local needsRecreate = not data
					or data.character ~= character
					or data.attachPart ~= attachPart
					or data.hasDisplayName ~= currentlyHasDisplayName
					or not data.gui or data.gui.Parent ~= attachPart
					or not data.infoLabel or data.infoLabel.Parent ~= data.gui
					or data.hasDisplayName and (not data.displayLabel or data.displayLabel.Parent ~= data.gui)
					or not data.highlight or data.highlight.Parent ~= character
					or data.highlight.Adornee ~= character

				if needsRecreate then
					createPlayerOverlay(targetPlayer)
					data = overlayData[targetPlayer]
				end

				if data and data.infoLabel and data.infoLabel.Parent then
					local teamColor = getTeamColor(targetPlayer)
					local studsText = "?"
					if localRootPart and rootPart and localRootPart:IsA("BasePart") and rootPart:IsA("BasePart") then
						studsText = tostring(math.floor((localRootPart.Position - rootPart.Position).Magnitude))
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
			end
		end
	end

	local stalePlayers = {}
	for targetPlayer in pairs(overlayData) do
		if not targetPlayer or targetPlayer.Parent ~= Players then
			table.insert(stalePlayers, targetPlayer)
		end
	end
	for _, targetPlayer in ipairs(stalePlayers) do
		removePlayerOverlay(targetPlayer)
	end
end

local function saveOriginalPartSnapshot(targetPlayer, character, part, partName)
	if originalPartData[part] then return true end
	local ok, snapshot = pcall(function()
		local properties = {
			Size = part.Size,
			Transparency = part.Transparency,
			CanCollide = part.CanCollide,
		}
		if partName ~= "HumanoidRootPart" then
			properties.Color = part.Color
			properties.Material = part.Material
		end
		return {
			player = targetPlayer,
			character = character,
			properties = properties,
		}
	end)
	if not ok then return false end
	originalPartData[part] = snapshot
	return true
end

local function restoreOriginalPart(part, snapshot)
	if part and part.Parent and snapshot and snapshot.properties then
		for propertyName, value in pairs(snapshot.properties) do
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

local function applyExpansionToPart(targetPlayer, character, part, partName, teamColor)
	if not saveOriginalPartSnapshot(targetPlayer, character, part, partName) then return end
	pcall(function()
		if partName == "HumanoidRootPart" then
			part.Size = Vector3.new(expansionSize, expansionSize, expansionSize)
			part.Transparency = 1
			part.CanCollide = false
		elseif partName == "Head" then
			part.Size = Vector3.new(expansionSize * 0.8, expansionSize * 0.8, expansionSize * 0.8)
			part.CanCollide = false
			part.Color = teamColor
			part.Material = Enum.Material.ForceField
			part.Transparency = hideExpandedParts and 1 or 0.7
		else
			part.Size = Vector3.new(expansionSize * 0.7, expansionSize * 0.7, expansionSize * 0.7)
			part.CanCollide = false
			part.Color = teamColor
			part.Material = Enum.Material.ForceField
			part.Transparency = hideExpandedParts and 1 or 0.7
		end
	end)
end

local function updateExpandedParts()
	if isShuttingDown or not expanderEnabled then return end
	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if targetPlayer ~= player then
			local character = targetPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if character and character.Parent and humanoid and humanoid.Health > 0 then
				local teamColor = getTeamColor(targetPlayer)
				for _, partName in ipairs(expandablePartNames) do
					local part = character:FindFirstChild(partName)
					if part and part:IsA("BasePart") then
						applyExpansionToPart(targetPlayer, character, part, partName, teamColor)
					end
				end
			elseif character then
				restoreCharacterParts(character)
			end
		end
	end

	local staleParts = {}
	for part, snapshot in pairs(originalPartData) do
		if not part.Parent then
			table.insert(staleParts, {part, nil})
		elseif not snapshot.player or snapshot.player.Parent ~= Players
			or not snapshot.character or snapshot.player.Character ~= snapshot.character
			or not snapshot.character.Parent or not part:IsDescendantOf(snapshot.character) then
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

local function doApplyExpansion()
	if isShuttingDown then return end
	local inputValue = normalizeExpansionSize(expansionSizeInput.Text)
	if inputValue then
		expansionSize = inputValue
		expansionSizeInput.Text = tostring(expansionSize)
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
	if isShuttingDown or not mainFrame.Parent then return end
	local camera = workspace.CurrentCamera
	if not camera then return end

	local absolutePosition = mainFrame.AbsolutePosition
	local absoluteSize = mainFrame.AbsoluteSize
	local viewportSize = camera.ViewportSize
	local topLeftInset, bottomRightInset = GuiService:GetGuiInset()
	local minimumX = topLeftInset.X
	local minimumY = topLeftInset.Y
	local maximumX = math.max(minimumX, viewportSize.X - bottomRightInset.X - absoluteSize.X)
	local maximumY = math.max(minimumY, viewportSize.Y - bottomRightInset.Y - absoluteSize.Y)
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
	if isShuttingDown or confirmFrame.Visible or settingsFrame.Visible then return end
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
	if overlayEnabled then
		TweenService:Create(overlayToggleButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(50, 200, 100)}):Play()
		overlayToggleButton.Text = "Player overlay: ON"
		for _, targetPlayer in ipairs(Players:GetPlayers()) do
			if targetPlayer ~= player then createPlayerOverlay(targetPlayer) end
		end
	else
		TweenService:Create(overlayToggleButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(220, 50, 50)}):Play()
		overlayToggleButton.Text = "Player overlay: OFF"
		removeAllPlayerOverlays()
	end
end

local function doToggleGui()
	if isShuttingDown or not mainFrame.Parent then return end
	guiVisible = not guiVisible
	mainFrame.Visible = guiVisible
	if guiVisible then task.defer(clampMainFrameToViewport) end
end

local function disconnectConnection(connection)
	if connection then
		pcall(function()
			connection:Disconnect()
		end)
	end
end

local function trackServiceConnection(connection)
	table.insert(serviceConnections, connection)
	return connection
end

local function refreshViewportTracking()
	disconnectConnection(viewportSizeConnection)
	viewportSizeConnection = nil
	local camera = workspace.CurrentCamera
	if camera then
		viewportSizeConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			task.defer(clampMainFrameToViewport)
		end)
	end
	task.defer(clampMainFrameToViewport)
end

local function disconnectCharacterTracking(targetPlayer)
	local connections = characterConnections[targetPlayer]
	if not connections then return end
	for _, connection in pairs(connections) do
		disconnectConnection(connection)
	end
	characterConnections[targetPlayer] = nil
end

local function handleCharacterAdded(targetPlayer, character)
	if isShuttingDown or not character then return end
	restorePlayerParts(targetPlayer)
	removePlayerOverlay(targetPlayer)
	if expanderEnabled then updateExpandedParts() end
	if overlayEnabled then createPlayerOverlay(targetPlayer) end
end

local function handleCharacterRemoving(targetPlayer, character)
	restoreCharacterParts(character)
	local data = overlayData[targetPlayer]
	if data and data.character == character then
		removePlayerOverlay(targetPlayer)
	end
	removeManagedOverlayInstances(targetPlayer, character)
end

local function setupCharacterTracking(targetPlayer)
	if isShuttingDown or not targetPlayer or targetPlayer == player then return end
	disconnectCharacterTracking(targetPlayer)
	characterConnections[targetPlayer] = {
		added = targetPlayer.CharacterAdded:Connect(function(character)
			handleCharacterAdded(targetPlayer, character)
		end),
		removing = targetPlayer.CharacterRemoving:Connect(function(character)
			handleCharacterRemoving(targetPlayer, character)
		end),
	}
end

local function applyLoadedSettings()
	if type(savedData) ~= "table" then
		applyTheme("dark", false)
		return
	end

	local loadedSize = normalizeExpansionSize(savedData.expansionSize)
	if loadedSize then
		expansionSize = loadedSize
		expansionSizeInput.Text = tostring(expansionSize)
	end

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

local registeredShutdown = nil
local function shutdownRuntime(animateClose, guiAlreadyDestroying)
	if isShuttingDown then return end
	isShuttingDown = true
	expanderEnabled = false
	overlayEnabled = false
	isDragging = false
	listeningFor = nil
	disconnectConnection(dragEndConnection)
	dragEndConnection = nil
	disconnectConnection(viewportSizeConnection)
	viewportSizeConnection = nil

	forceRestoreAllExpandedParts()
	removeAllPlayerOverlays()

	local trackedPlayers = {}
	for targetPlayer in pairs(characterConnections) do
		table.insert(trackedPlayers, targetPlayer)
	end
	for _, targetPlayer in ipairs(trackedPlayers) do
		disconnectCharacterTracking(targetPlayer)
	end
	for _, connection in ipairs(serviceConnections) do
		disconnectConnection(connection)
	end
	table.clear(serviceConnections)

	pcall(function()
		if runtimeEnvironment[RUNTIME_KEY] == registeredShutdown then
			runtimeEnvironment[RUNTIME_KEY] = nil
		end
	end)

	if animateClose and screenGui.Parent and mainFrame.Parent then
		TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			Size = UDim2.new(0, 0, 0, 0),
			Position = UDim2.new(
				mainFrame.Position.X.Scale,
				mainFrame.Position.X.Offset + 130,
				mainFrame.Position.Y.Scale,
				mainFrame.Position.Y.Offset + 90
			),
		}):Play()
		task.wait(0.3)
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

for _, targetPlayer in ipairs(Players:GetPlayers()) do
	if targetPlayer ~= player then
		if targetPlayer.Character then
			removeManagedOverlayInstances(targetPlayer, targetPlayer.Character)
		end
		setupCharacterTracking(targetPlayer)
	end
end

trackServiceConnection(Players.PlayerAdded:Connect(function(newPlayer)
	if isShuttingDown then return end
	setupCharacterTracking(newPlayer)
	if newPlayer.Character then
		handleCharacterAdded(newPlayer, newPlayer.Character)
	end
end))

trackServiceConnection(Players.PlayerRemoving:Connect(function(removedPlayer)
	local character = removedPlayer.Character
	restorePlayerParts(removedPlayer)
	removePlayerOverlay(removedPlayer)
	removeManagedOverlayInstances(removedPlayer, character)
	disconnectCharacterTracking(removedPlayer)
end))

trackServiceConnection(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if not isShuttingDown then refreshViewportTracking() end
end))
trackServiceConnection(GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
	if not isShuttingDown then task.defer(clampMainFrameToViewport) end
end))
refreshViewportTracking()

applyExpansionButton.MouseButton1Click:Connect(function()
	doApplyExpansion()
end)

expansionSizeInput.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		doApplyExpansion()
	end
end)

expanderToggleButton.MouseButton1Click:Connect(function()
	animateButton(expanderToggleButton)
	doToggleExpander()
end)

overlayToggleButton.MouseButton1Click:Connect(function()
	animateButton(overlayToggleButton)
	doToggleOverlay()
end)

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
	if isShuttingDown or confirmFrame.Visible or settingsFrame.Visible then return end
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
	if isShuttingDown or confirmFrame.Visible or settingsFrame.Visible then return end
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
	animateButton(backButton)
	if listeningFor then setListening(nil) end
	TweenService:Create(settingsFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(1, 0, 0, 0)}):Play()
	task.wait(0.2)
	if not isShuttingDown and settingsFrame.Parent then
		settingsFrame.Visible = false
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
	if isShuttingDown or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
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
	if gameProcessed then return end

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
	if not screenGui.Parent then
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
	if isShuttingDown or not guiVisible then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isDragging = true
		dragStart = input.Position
		startPos = mainFrame.Position
		disconnectConnection(dragEndConnection)
		dragEndConnection = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				isDragging = false
				disconnectConnection(dragEndConnection)
				dragEndConnection = nil
			end
		end)
	end
end

local function captureWindowDragInput(input)
	if isShuttingDown or not guiVisible then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end

titleLabel.InputBegan:Connect(beginWindowDrag)
titleLabel.InputChanged:Connect(captureWindowDragInput)
settingsTitleLabel.InputBegan:Connect(beginWindowDrag)
settingsTitleLabel.InputChanged:Connect(captureWindowDragInput)

trackServiceConnection(UserInputService.InputChanged:Connect(function(input)
	if isShuttingDown or not guiVisible then return end
	if input == dragInput and isDragging then
		local delta = input.Position - dragStart
		local proposedPosition = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
		mainFrame.Position = proposedPosition
		clampMainFrameToViewport()
	end
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
