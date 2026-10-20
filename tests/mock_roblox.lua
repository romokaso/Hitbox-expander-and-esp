--[[
	A small, deliberately boring mock of the Roblox API surface used by
	HitboxEsp.luau. It exists so the whole script — not only the pure helpers —
	can be executed and asserted on from a plain Lua 5.4 interpreter.

	It is not a Roblox emulator. Only the behaviour the script depends on is
	implemented: instances with Parent bookkeeping, signals, tweens that apply
	instantly, a task scheduler, a tiny in-memory file system and just enough
	JSON to exercise the settings round-trip.
]]

local Mock = {}

--------------------------------------------------------------------------------
-- Language helpers
--------------------------------------------------------------------------------

local function shallowCopy(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = value
	end
	return copy
end

local function isFiniteNumber(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

--------------------------------------------------------------------------------
-- Signals
--------------------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _connections = {} }, Signal)
end

function Signal:Connect(handler)
	assert(type(handler) == "function", "Signal:Connect expects a function")
	local connection = {
		Connected = true,
		_handler = handler,
		_signal = self,
	}
	function connection:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		for index, entry in ipairs(self._signal._connections) do
			if entry == self then
				table.remove(self._signal._connections, index)
				break
			end
		end
	end
	table.insert(self._connections, connection)
	return connection
end

function Signal:Fire(...)
	local snapshot = {}
	for index, connection in ipairs(self._connections) do
		snapshot[index] = connection
	end
	for _, connection in ipairs(snapshot) do
		if connection.Connected then
			connection._handler(...)
		end
	end
end

--------------------------------------------------------------------------------
-- Vector / colour / UDim types
--------------------------------------------------------------------------------

local Vector3 = {}
local Vector3MT = { __index = Vector3 }

function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3MT)
end

function Vector3MT.__add(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end

function Vector3MT.__sub(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end

function Vector3MT.__eq(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end

function Vector3MT.__tostring(a)
	return string.format("Vector3(%g, %g, %g)", a.X, a.Y, a.Z)
end

function Vector3MT.__index(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	end
	return Vector3[key]
end

local Vector2 = {}
local Vector2MT = { __index = Vector2 }

function Vector2.new(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, Vector2MT)
end

function Vector2MT.__sub(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end

function Vector2MT.__add(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end

local Color3 = {}
local Color3MT = { __index = Color3 }

local function colorComponent(value)
	if value == nil then
		return 0
	end
	return math.floor(value * 255 + 0.5) / 255
end

function Color3.new(r, g, b)
	return setmetatable({ R = colorComponent(r), G = colorComponent(g), B = colorComponent(b) }, Color3MT)
end

function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end

function Color3MT.__eq(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end

function Color3MT.__tostring(a)
	return string.format(
		"Color3(%d, %d, %d)",
		math.floor(a.R * 255 + 0.5),
		math.floor(a.G * 255 + 0.5),
		math.floor(a.B * 255 + 0.5)
	)
end

function Color3:Lerp(other, alpha)
	return Color3.new(
		self.R + (other.R - self.R) * alpha,
		self.G + (other.G - self.G) * alpha,
		self.B + (other.B - self.B) * alpha
	)
end

local UDim = {}
UDim.__index = UDim
function UDim.new(scale, offset)
	return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, UDim)
end

local UDim2 = {}
UDim2.__index = UDim2
function UDim2.new(scaleX, offsetX, scaleY, offsetY)
	return setmetatable({
		X = UDim.new(scaleX, offsetX),
		Y = UDim.new(scaleY, offsetY),
	}, UDim2)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end

local TweenInfo = {}
TweenInfo.__index = TweenInfo
function TweenInfo.new(duration, style, direction)
	return setmetatable({ Time = duration or 1, EasingStyle = style, EasingDirection = direction }, TweenInfo)
end

--------------------------------------------------------------------------------
-- JSON (only what settings need)
--------------------------------------------------------------------------------

local JSON = {}

local ESCAPES = {
	['"'] = '\\"',
	["\\"] = "\\\\",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}

local function escapeJsonString(value)
	return (
		string.gsub(value, '[%c"\\]', function(character)
			return ESCAPES[character] or string.format("\\u%04x", string.byte(character))
		end)
	)
end

local function encodeJson(value)
	local kind = type(value)
	if kind == "nil" then
		return "null"
	elseif kind == "boolean" then
		return value and "true" or "false"
	elseif kind == "number" then
		if not isFiniteNumber(value) then
			error("cannot encode non-finite number")
		end
		if math.type(value) == "integer" then
			return string.format("%d", value)
		end
		return string.format("%.14g", value)
	elseif kind == "string" then
		return '"' .. escapeJsonString(value) .. '"'
	elseif kind == "table" then
		local keyCount = 0
		local arrayLike = true
		for key in pairs(value) do
			keyCount = keyCount + 1
			if type(key) ~= "number" then
				arrayLike = false
			end
		end
		if arrayLike and keyCount > 0 then
			for index = 1, keyCount do
				if value[index] == nil then
					arrayLike = false
					break
				end
			end
		end
		local parts = {}
		if arrayLike then
			for index = 1, keyCount do
				parts[index] = encodeJson(value[index])
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local keys = {}
		for key in pairs(value) do
			table.insert(keys, tostring(key))
		end
		table.sort(keys)
		for _, key in ipairs(keys) do
			table.insert(parts, encodeJson(key) .. ":" .. encodeJson(value[key]))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	error("cannot encode " .. kind)
end

local Decoder = {}
Decoder.__index = Decoder

local function decodeError(message, position)
	error(string.format("invalid json at %d: %s", position, message), 0)
end

function Decoder:skipWhitespace()
	while true do
		local character = string.sub(self.text, self.position, self.position)
		if character == " " or character == "\t" or character == "\n" or character == "\r" then
			self.position = self.position + 1
		else
			return
		end
	end
end

function Decoder:parseString()
	local text = self.text
	if string.sub(text, self.position, self.position) ~= '"' then
		decodeError("expected string", self.position)
	end
	self.position = self.position + 1
	local chunks = {}
	while true do
		local character = string.sub(text, self.position, self.position)
		if character == "" then
			decodeError("unterminated string", self.position)
		elseif character == '"' then
			self.position = self.position + 1
			return table.concat(chunks)
		elseif character == "\\" then
			local escape = string.sub(text, self.position + 1, self.position + 1)
			local translated = ({
				['"'] = '"',
				["\\"] = "\\",
				["/"] = "/",
				b = "\b",
				f = "\f",
				n = "\n",
				r = "\r",
				t = "\t",
			})[escape]
			if not translated then
				decodeError("bad escape", self.position)
			end
			table.insert(chunks, translated)
			self.position = self.position + 2
		else
			table.insert(chunks, character)
			self.position = self.position + 1
		end
	end
end

function Decoder:parseNumber()
	local numberText = string.match(self.text, "^-?%d+%.?%d*[eE]?[+-]?%d*", self.position)
	if not numberText or numberText == "" then
		decodeError("expected number", self.position)
	end
	local value = tonumber(numberText)
	if not value then
		decodeError("bad number", self.position)
	end
	self.position = self.position + #numberText
	return value
end

function Decoder:parseValue()
	self:skipWhitespace()
	local text = self.text
	local character = string.sub(text, self.position, self.position)
	if character == "{" then
		self.position = self.position + 1
		local object = {}
		self:skipWhitespace()
		if string.sub(text, self.position, self.position) == "}" then
			self.position = self.position + 1
			return object
		end
		while true do
			self:skipWhitespace()
			local key = self:parseString()
			self:skipWhitespace()
			if string.sub(text, self.position, self.position) ~= ":" then
				decodeError("expected colon", self.position)
			end
			self.position = self.position + 1
			object[key] = self:parseValue()
			self:skipWhitespace()
			local delimiter = string.sub(text, self.position, self.position)
			self.position = self.position + 1
			if delimiter == "}" then
				return object
			elseif delimiter ~= "," then
				decodeError("expected comma or closing brace", self.position - 1)
			end
		end
	elseif character == "[" then
		self.position = self.position + 1
		local array = {}
		self:skipWhitespace()
		if string.sub(text, self.position, self.position) == "]" then
			self.position = self.position + 1
			return array
		end
		while true do
			table.insert(array, self:parseValue())
			self:skipWhitespace()
			local delimiter = string.sub(text, self.position, self.position)
			self.position = self.position + 1
			if delimiter == "]" then
				return array
			elseif delimiter ~= "," then
				decodeError("expected comma or closing bracket", self.position - 1)
			end
		end
	elseif character == '"' then
		return self:parseString()
	elseif string.sub(text, self.position, self.position + 3) == "true" then
		self.position = self.position + 4
		return true
	elseif string.sub(text, self.position, self.position + 4) == "false" then
		self.position = self.position + 5
		return false
	elseif string.sub(text, self.position, self.position + 3) == "null" then
		self.position = self.position + 4
		return nil
	else
		return self:parseNumber()
	end
end

function JSON.encode(value)
	return encodeJson(value)
end

function JSON.decode(text)
	assert(type(text) == "string", "JSON.decode expects a string")
	local decoder = setmetatable({ text = text, position = 1 }, Decoder)
	local result = decoder:parseValue()
	decoder:skipWhitespace()
	if decoder.position <= #text then
		decodeError("trailing data", decoder.position)
	end
	return result
end

--------------------------------------------------------------------------------
-- Enums
--------------------------------------------------------------------------------

local function enumItem(name)
	return { Name = name, Value = 0 }
end

local function permissiveEnum(...)
	local members = {}
	for _, name in ipairs({ ... }) do
		members[name] = enumItem(name)
	end
	return setmetatable(members, {
		__index = function(self, key)
			local item = enumItem(key)
			rawset(self, key, item)
			return item
		end,
	})
end

local KEY_CODE_NAMES = {
	"A",
	"B",
	"C",
	"D",
	"E",
	"F",
	"G",
	"H",
	"I",
	"J",
	"K",
	"L",
	"M",
	"N",
	"O",
	"P",
	"Q",
	"R",
	"S",
	"T",
	"U",
	"V",
	"W",
	"X",
	"Y",
	"Z",
	"Zero",
	"One",
	"Two",
	"Three",
	"Four",
	"Five",
	"Six",
	"Seven",
	"Eight",
	"Nine",
	"F1",
	"F2",
	"F3",
	"F4",
	"F5",
	"F6",
	"F7",
	"F8",
	"F9",
	"F10",
	"F11",
	"F12",
	"LeftShift",
	"RightShift",
	"LeftControl",
	"RightControl",
	"LeftAlt",
	"RightAlt",
	"Space",
	"Tab",
	"Escape",
	"Backspace",
	"Delete",
	"Return",
	"Unknown",
	"LeftBracket",
	"RightBracket",
	"Semicolon",
	"Quote",
	"Comma",
	"Period",
	"Slash",
}

local KeyCode = {}
for _, name in ipairs(KEY_CODE_NAMES) do
	KeyCode[name] = enumItem(name)
end

local Enum = {
	KeyCode = KeyCode,
	UserInputType = permissiveEnum("Keyboard", "MouseMovement", "MouseButton1", "Touch"),
	UserInputState = permissiveEnum("Begin", "Change", "End"),
	Font = permissiveEnum("Gotham", "GothamBold", "SourceSans"),
	Material = permissiveEnum("Plastic", "SmoothPlastic", "Neon", "ForceField"),
	EasingStyle = permissiveEnum("Linear", "Quad", "Sine"),
	EasingDirection = permissiveEnum("In", "Out", "InOut"),
	TextXAlignment = permissiveEnum("Left", "Center", "Right"),
	TextTruncate = permissiveEnum("None", "AtEnd", "Split"),
	TextYAlignment = permissiveEnum("Top", "Center", "Bottom"),
	ZIndexBehavior = permissiveEnum("Global", "Sibling"),
	AutomaticSize = permissiveEnum("None", "X", "Y", "XY"),
	ScrollingDirection = permissiveEnum("X", "Y", "XY"),
	HighlightDepthMode = permissiveEnum("AlwaysOnTop", "Occluded"),
}

--------------------------------------------------------------------------------
-- Instance system
--------------------------------------------------------------------------------

local SIGNAL_NAMES = {
	MouseButton1Click = true,
	MouseEnter = true,
	MouseLeave = true,
	InputBegan = true,
	InputChanged = true,
	InputEnded = true,
	FocusLost = true,
	Changed = true,
	Destroying = true,
	CharacterAdded = true,
	CharacterRemoving = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	ChildAdded = true,
	ChildRemoved = true,
	Completed = true,
}

local CLASS_ANCESTORS = {
	ScreenGui = { "LayerCollector", "GuiBase2d", "Instance" },
	Frame = { "GuiObject", "GuiBase2d", "Instance" },
	TextLabel = { "GuiObject", "GuiBase2d", "Instance" },
	TextButton = { "GuiObject", "GuiBase2d", "Instance" },
	TextBox = { "GuiObject", "GuiBase2d", "Instance" },
	ScrollingFrame = { "GuiObject", "GuiBase2d", "Instance" },
	BillboardGui = { "LayerCollector", "Instance" },
	UICorner = { "UIComponent", "Instance" },
	UIStroke = { "UIComponent", "Instance" },
	Highlight = { "Instance" },
	Part = { "BasePart", "PVInstance", "Instance" },
	MeshPart = { "BasePart", "PVInstance", "Instance" },
	Humanoid = { "Instance" },
	Model = { "PVInstance", "Instance" },
	Player = { "Instance" },
	Camera = { "Instance" },
	Folder = { "Instance" },
}

local CLASS_DEFAULTS = {
	Frame = { Visible = true, BackgroundTransparency = 0 },
	TextLabel = { Visible = true, Text = "", TextTransparency = 0, BackgroundTransparency = 0 },
	TextButton = { Visible = true, Text = "", TextTransparency = 0, BackgroundTransparency = 0 },
	TextBox = { Visible = true, Text = "", TextTransparency = 0, BackgroundTransparency = 0 },
	ScrollingFrame = { Visible = true },
	ScreenGui = { Enabled = true },
	BillboardGui = { Enabled = true, AlwaysOnTop = false },
	UIStroke = { Transparency = 0 },
	Part = {
		Transparency = 0,
		CanCollide = true,
		CastShadow = true,
		Anchored = false,
		Position = Vector3.new(0, 0, 0),
	},
	Humanoid = { Health = 100, MaxHealth = 100 },
}

local InstanceMethods = {}

function InstanceMethods:GetChildren()
	local children = {}
	for index, child in ipairs(self._children) do
		children[index] = child
	end
	return children
end

function InstanceMethods:GetDescendants()
	local descendants = {}
	local function collect(instance)
		for _, child in ipairs(instance._children) do
			table.insert(descendants, child)
			collect(child)
		end
	end
	collect(self)
	return descendants
end

function InstanceMethods:FindFirstChild(name)
	for _, child in ipairs(self._children) do
		if child._props.Name == name then
			return child
		end
	end
	return nil
end

function InstanceMethods:FindFirstChildOfClass(className)
	for _, child in ipairs(self._children) do
		if child._class == className then
			return child
		end
	end
	return nil
end

function InstanceMethods:FindFirstChildWhichIsA(className)
	for _, child in ipairs(self._children) do
		if child:IsA(className) then
			return child
		end
	end
	return nil
end

function InstanceMethods:IsA(className)
	if self._class == className then
		return true
	end
	local ancestors = CLASS_ANCESTORS[self._class]
	if ancestors then
		for _, ancestor in ipairs(ancestors) do
			if ancestor == className then
				return true
			end
		end
	end
	return false
end

function InstanceMethods:GetPropertyChangedSignal(property)
	local signal = self._changed[property]
	if not signal then
		signal = Signal.new()
		self._changed[property] = signal
	end
	return signal
end

function InstanceMethods:WaitForChild(name)
	local existing = self:FindFirstChild(name)
	if existing then
		return existing
	end
	error("mock WaitForChild(" .. tostring(name) .. ") timed out", 2)
end

function InstanceMethods:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	local destroying = self._signals.Destroying
	if destroying then
		destroying:Fire()
	end
	local children = self:GetChildren()
	for _, child in ipairs(children) do
		child:Destroy()
	end
	local parent = self._parent
	if parent then
		for index, sibling in ipairs(parent._children) do
			if sibling == self then
				table.remove(parent._children, index)
				break
			end
		end
	end
	self._parent = nil
end

local function makeInstanceFactory(world)
	local function viewportSize()
		local camera = world.camera
		local size = camera and camera._props.ViewportSize
		if size and size.X > 0 and size.Y > 0 then
			return size
		end
		return Vector2.new(1280, 720)
	end

	local function absolutePosition(instance)
		local position = instance._props.Position or UDim2.fromOffset(0, 0)
		local viewport = viewportSize()
		local inset = world.guiInset or Vector2.new(0, 0)
		return Vector2.new(
			position.X.Offset + position.X.Scale * viewport.X + inset.X,
			position.Y.Offset + position.Y.Scale * viewport.Y + inset.Y
		)
	end

	local function absoluteSize(instance)
		local size = instance._props.Size or UDim2.fromOffset(0, 0)
		local viewport = viewportSize()
		return Vector2.new(size.X.Offset + size.X.Scale * viewport.X, size.Y.Offset + size.Y.Scale * viewport.Y)
	end

	local instanceIndex
	instanceIndex = function(self, key)
		if key == "ClassName" then
			return self._class
		elseif key == "Parent" then
			return self._parent
		elseif key == "AbsolutePosition" then
			return absolutePosition(self)
		elseif key == "AbsoluteSize" then
			return absoluteSize(self)
		end
		local method = InstanceMethods[key]
		if method then
			return method
		end
		local signal = self._signals[key]
		if signal then
			return signal
		end
		if SIGNAL_NAMES[key] then
			signal = Signal.new()
			self._signals[key] = signal
			return signal
		end
		return self._props[key]
	end

	local instanceNewIndex = function(self, key, value)
		if key == "Parent" then
			local previous = self._parent
			if previous == value then
				return
			end
			if previous then
				for index, sibling in ipairs(previous._children) do
					if sibling == self then
						table.remove(previous._children, index)
						break
					end
				end
			end
			self._parent = value
			if value then
				table.insert(value._children, self)
			end
			return
		end
		local previous = self._props[key]
		self._props[key] = value
		if previous ~= value then
			local signal = self._changed[key]
			if signal then
				signal:Fire(value, previous)
			end
		end
	end

	local instanceMethods = {
		__index = instanceIndex,
		__newindex = instanceNewIndex,
		__tostring = function(self)
			return string.format("%s(%s)", self._class, tostring(self._props.Name or ""))
		end,
	}

	local function newInstance(className, properties)
		local defaults = CLASS_DEFAULTS[className]
		local props = {}
		if defaults then
			for key, value in pairs(defaults) do
				props[key] = value
			end
		end
		if className == "Part" and props.Color == nil then
			props.Color = Color3.new(1, 1, 1)
		end
		local instance = setmetatable({
			_class = className,
			_parent = nil,
			_children = {},
			_props = props,
			_signals = {},
			_changed = {},
			_destroyed = false,
		}, instanceMethods)
		if properties then
			for key, value in pairs(properties) do
				instance[key] = value
			end
		end
		return instance
	end

	return newInstance
end

--------------------------------------------------------------------------------
-- Task scheduler
--------------------------------------------------------------------------------

local World = {}
World.__index = World

local function addSeconds(base, delay)
	if type(delay) ~= "number" then
		return base
	end
	return base + delay
end

function World:_schedule(thread, due, args)
	table.insert(self._threads, { thread = thread, due = due, args = args or {} })
end

function World:_resume(entry)
	local results = table.pack(coroutine.resume(entry.thread, table.unpack(entry.args)))
	if not results[1] then
		error(results[2], 0)
	end
	if coroutine.status(entry.thread) == "suspended" then
		local delay = results[2]
		self:_schedule(entry.thread, self.clock + (tonumber(delay) or 0), {})
	end
end

function World:_runDue()
	while true do
		local dueIndex
		for index, entry in ipairs(self._threads) do
			if entry.due <= self.clock then
				dueIndex = index
				break
			end
		end
		if not dueIndex then
			return
		end
		local entry = table.remove(self._threads, dueIndex)
		self:_resume(entry)
	end
end

function World:step(seconds, interval)
	local remaining = seconds or 0.1
	interval = interval or 0.05
	while remaining > 0 do
		local slice = math.min(interval, remaining)
		self.clock = self.clock + slice
		self:_runDue()
		remaining = remaining - slice
	end
end

--------------------------------------------------------------------------------
-- Input objects
--------------------------------------------------------------------------------

function World:keyInput(keyName)
	return {
		UserInputType = Enum.UserInputType.Keyboard,
		KeyCode = Enum.KeyCode[keyName],
		Position = Vector3.new(0, 0, 0),
		UserInputState = Enum.UserInputState.Begin,
	}
end

function World:pressKey(keyName, gameProcessed)
	self.userInputService.InputBegan:Fire(self:keyInput(keyName), gameProcessed == true)
end

function World:mouseInput(inputType, x, y)
	return {
		UserInputType = inputType,
		Position = Vector3.new(x or 0, y or 0, 0),
		UserInputState = inputType == Enum.UserInputType.MouseMovement and Enum.UserInputState.Change
			or Enum.UserInputState.Begin,
	}
end

function World:mouseDown(instance, x, y)
	instance.InputBegan:Fire(self:mouseInput(Enum.UserInputType.MouseButton1, x, y))
end

function World:mouseMove(x, y)
	self.userInputService.InputChanged:Fire(self:mouseInput(Enum.UserInputType.MouseMovement, x, y))
end

function World:mouseUp(x, y)
	local input = self:mouseInput(Enum.UserInputType.MouseButton1, x, y)
	input.UserInputState = Enum.UserInputState.End
	self.userInputService.InputEnded:Fire(input)
end

function World:click(button)
	button.MouseButton1Click:Fire()
end

--------------------------------------------------------------------------------
-- Players and characters
--------------------------------------------------------------------------------

local CHARACTER_PARTS = {
	{ "HumanoidRootPart", 2, 2, 1, 1 },
	{ "Head", 2, 1, 1, 0 },
	{ "Torso", 2, 2, 1, 0 },
	{ "Left Arm", 1, 2, 1, 0 },
	{ "Right Arm", 1, 2, 1, 0 },
	{ "Left Leg", 1, 2, 1, 0 },
	{ "Right Leg", 1, 2, 1, 0 },
}

function World:addPlayer(name)
	local player = self.newInstance("Player", {
		Name = name,
		DisplayName = name,
	})
	player.Parent = self.playersService
	player.Character = nil
	table.insert(self.playersService._list, player)
	self.playersService.PlayerAdded:Fire(player)
	return player
end

function World:removePlayer(player)
	for index, entry in ipairs(self.playersService._list) do
		if entry == player then
			table.remove(self.playersService._list, index)
			break
		end
	end
	player.Parent = nil
	self.playersService.PlayerRemoving:Fire(player)
end

function World:loadCharacter(player, nameSuffix)
	local model = self.newInstance("Model", { Name = (nameSuffix or player.Name) })
	model.Parent = self.characterFolder
	for _, spec in ipairs(CHARACTER_PARTS) do
		local partName, x, y, z, transparency = spec[1], spec[2], spec[3], spec[4], spec[5]
		self.newInstance("Part", {
			Name = partName,
			Size = Vector3.new(x, y, z),
			Transparency = transparency,
			CanCollide = partName ~= "HumanoidRootPart",
			CastShadow = partName ~= "HumanoidRootPart",
			Material = Enum.Material.Plastic,
		}).Parent =
			model
	end
	self.newInstance("Humanoid", { Name = "Humanoid" }).Parent = model
	player.Character = model
	player.CharacterAdded:Fire(model)
	return model
end

function World:findPart(character, partName)
	return character:FindFirstChild(partName)
end

--------------------------------------------------------------------------------
-- Bootstrap
--------------------------------------------------------------------------------

function Mock.newWorld()
	local world = setmetatable({
		clock = 0,
		_threads = {},
		files = {},
		warnings = {},
		genv = {},
		-- Default Roblox topbar inset; tests exercise the Position/AbsolutePosition
		-- conversion with it instead of assuming it is zero.
		guiInset = Vector2.new(0, 36),
	}, World)

	local newInstance = makeInstanceFactory(world)
	world.newInstance = newInstance

	local camera = newInstance("Camera", {
		Name = "Camera",
		ViewportSize = Vector2.new(1280, 720),
		CFrame = { Position = Vector3.new(0, 10, 0) },
	})
	world.camera = camera

	local characterFolder = newInstance("Folder", { Name = "WorkspaceCharacters" })
	world.characterFolder = characterFolder

	local playersService = {
		_list = {},
		_children = {},
		PlayerAdded = Signal.new(),
		PlayerRemoving = Signal.new(),
	}
	function playersService:GetPlayers()
		local result = {}
		for index, player in ipairs(self._list) do
			result[index] = player
		end
		return result
	end
	world.playersService = playersService

	local localPlayer = newInstance("Player", { Name = "LocalPlayer", DisplayName = "LocalPlayer" })
	localPlayer.Parent = playersService
	localPlayer.Character = nil
	table.insert(playersService._list, localPlayer)
	playersService.LocalPlayer = localPlayer
	world.localPlayer = localPlayer

	local playerGui = newInstance("Folder", { Name = "PlayerGui" })
	playerGui.Parent = localPlayer
	world.playerGui = playerGui

	local userInputService = {
		InputBegan = Signal.new(),
		InputChanged = Signal.new(),
		InputEnded = Signal.new(),
		_focusedTextBox = nil,
	}
	function userInputService:GetFocusedTextBox()
		return self._focusedTextBox
	end
	world.userInputService = userInputService

	local tweenService = {}
	function tweenService:Create(instance, _, properties)
		local tween = { Completed = Signal.new() }
		function tween:Play()
			for property, value in pairs(properties) do
				instance[property] = value
			end
			self.Completed:Fire()
		end
		function tween:Cancel() end
		return tween
	end
	world.tweenService = tweenService

	local httpService = {}
	function httpService:JSONEncode(value)
		return JSON.encode(value)
	end
	function httpService:JSONDecode(text)
		return JSON.decode(text)
	end
	world.httpService = httpService

	local workspaceService = { CurrentCamera = camera, _folder = characterFolder }
	world.workspaceService = workspaceService

	local guiService = {
		GetGuiInset = function()
			return world.guiInset
		end,
	}
	world.guiService = guiService

	local services = {
		Players = playersService,
		RunService = {},
		TweenService = tweenService,
		UserInputService = userInputService,
		HttpService = httpService,
		Workspace = workspaceService,
		GuiService = guiService,
	}
	world.services = services
	world.game = {
		GetService = function(_, serviceName)
			return services[serviceName]
		end,
	}

	local files = world.files
	world.fs = {
		writefile = function(path, contents)
			assert(type(path) == "string", "writefile path must be a string")
			assert(type(contents) == "string", "writefile contents must be a string")
			files[path] = contents
		end,
		readfile = function(path)
			local contents = files[path]
			if contents == nil then
				error("mock readfile: no such file " .. tostring(path), 2)
			end
			return contents
		end,
		isfile = function(path)
			return files[path] ~= nil
		end,
	}

	local task = {}
	function task.spawn(fn, ...)
		local thread = coroutine.create(fn)
		local results = table.pack(coroutine.resume(thread, ...))
		if not results[1] then
			error(results[2], 0)
		end
		if coroutine.status(thread) == "suspended" then
			world:_schedule(thread, world.clock + (tonumber(results[2]) or 0), {})
		end
	end
	function task.defer(fn, ...)
		world:_schedule(coroutine.create(fn), world.clock, { ... })
	end
	function task.delay(delay, fn, ...)
		world:_schedule(coroutine.create(fn), world.clock + (delay or 0), { ... })
	end
	function task.wait(delay)
		coroutine.yield(delay or 0)
		return delay or 0
	end
	function task.cancel() end
	world.task = task

	world.env = {
		game = world.game,
		Instance = { new = newInstance },
		Enum = Enum,
		Vector2 = Vector2,
		Vector3 = Vector3,
		Color3 = Color3,
		UDim = UDim,
		UDim2 = UDim2,
		TweenInfo = TweenInfo,
		task = task,
		warn = function(...)
			local chunks = {}
			for index = 1, select("#", ...) do
				chunks[index] = tostring((select(index, ...)))
			end
			table.insert(world.warnings, table.concat(chunks, " "))
		end,
		getgenv = function()
			return world.genv
		end,
		writefile = world.fs.writefile,
		readfile = world.fs.readfile,
		isfile = world.fs.isfile,
	}
	world.env._G = world.env
	setmetatable(world.env, { __index = _G })

	return world
end

function World:boot(source)
	local chunk, compileError = load(source, "HitboxEsp.luau", "t", self.env)
	if not chunk then
		error("compile error: " .. tostring(compileError), 0)
	end
	chunk()
	return self.genv.HitboxESP
end

function World:find(instance, path)
	local current = instance
	for name in string.gmatch(path, "[^/]+") do
		current = current:FindFirstChild(name)
		if not current then
			return nil
		end
	end
	return current
end

function World:screenGui()
	return self.playerGui:FindFirstChild("HitboxESP")
end

function World:mainFrame()
	local gui = self:screenGui()
	return gui and gui:FindFirstChild("MainFrame")
end

function World:control(name)
	local frame = self:mainFrame()
	if not frame then
		return nil
	end
	for _, descendant in ipairs(frame:GetDescendants()) do
		if descendant._props.Name == name then
			return descendant
		end
	end
	return nil
end

function World:settingsText()
	return self.files["hitbox_esp_settings.json"]
end

function World:settingsValue()
	local contents = self:settingsText()
	if not contents then
		return nil
	end
	local ok, decoded = pcall(JSON.decode, contents)
	if not ok then
		return nil
	end
	return decoded
end

Mock.Vector2 = Vector2
Mock.Vector3 = Vector3
Mock.Color3 = Color3
Mock.UDim2 = UDim2
Mock.Enum = Enum
Mock.JSON = JSON

return Mock
