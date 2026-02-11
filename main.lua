local Library = {}

local CloneRef = cloneref or function(x) return x end
local Players = CloneRef(game:GetService("Players"))
local TweenService = CloneRef(game:GetService("TweenService"))
local UserInputService = CloneRef(game:GetService("UserInputService"))
local RunService = CloneRef(game:GetService("RunService"))
local CoreGui = CloneRef(game:GetService("CoreGui"))
local HttpService = CloneRef(game:GetService("HttpService"))

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local isStudio = RunService:IsStudio()
local guiParent = isStudio and LocalPlayer.PlayerGui or (gethui and gethui()) or CoreGui

pcall(function()
	local searchParents = {guiParent}
	if guiParent ~= CoreGui then table.insert(searchParents, CoreGui) end
	if gethui and gethui() ~= guiParent then table.insert(searchParents, gethui()) end
	for _, parent in ipairs(searchParents) do
		for _, g in ipairs(parent:GetChildren()) do
			if g:IsA("ScreenGui") and g.Name:sub(1, 9) == "LemonUI2_" then
				g:Destroy()
			end
		end
	end
end)

local Theme = {
	Accent       = Color3.fromRGB(112, 146, 190),
	AccentDark   = Color3.fromRGB(78, 108, 148),
	AccentHover  = Color3.fromRGB(132, 166, 212),
	BgWindow     = Color3.fromRGB(15, 15, 19),
	BgSection    = Color3.fromRGB(19, 19, 25),
	BgHeader     = Color3.fromRGB(23, 23, 30),
	BgInput      = Color3.fromRGB(11, 11, 15),
	BgHover      = Color3.fromRGB(28, 28, 36),
	BgTab        = Color3.fromRGB(18, 18, 23),
	BgTabActive  = Color3.fromRGB(26, 26, 34),
	Border       = Color3.fromRGB(34, 34, 48),
	BorderLight  = Color3.fromRGB(44, 44, 60),
	Text         = Color3.fromRGB(230, 230, 235),
	TextDim      = Color3.fromRGB(90, 90, 105),
	TextMid      = Color3.fromRGB(160, 160, 175),
	Green        = Color3.fromRGB(72, 210, 72),
	Red          = Color3.fromRGB(210, 65, 65),
	Yellow       = Color3.fromRGB(210, 175, 45),
}

local function mk(cls, parent, props)
	local inst = Instance.new(cls)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function tw(obj, props, dur, style, dir)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(dur or 0.18, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function twSpring(obj, props, dur)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(dur or 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function twSnap(obj, props, dur)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(dur or 0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function formatColor(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local function parseHex(hex)
	hex = hex:gsub("#", "")
	if #hex == 6 then
		local r = tonumber(hex:sub(1, 2), 16)
		local g = tonumber(hex:sub(3, 4), 16)
		local b = tonumber(hex:sub(5, 6), 16)
		if r and g and b then
			return Color3.fromRGB(r, g, b)
		end
	end
	return nil
end

function Library:CreateWindow(config)
	config = config or {}
	local title = config.Title or "lemon.lua"
	local size = config.Size or UDim2.fromOffset(720, 480)
	local toggleKey = config.ToggleKey or Enum.KeyCode.Insert

	local Window = {}
	local tabs = {}
	local currentTabIndex = 0
	local visible = true
	local connections = {}
	local activeSlider = nil
	local notifOrder = 0

	local screenGui = mk("ScreenGui", guiParent, {
		Name = "LemonUI2_" .. math.random(100000, 999999),
		DisplayOrder = 99998,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	-- protect gui from detection / enumeration
	pcall(function()
		if syn and syn.protect_gui then
			syn.protect_gui(screenGui)
		elseif protect_gui then
			protect_gui(screenGui)
		end
	end)
	pcall(function()
		if sethiddenproperty then
			sethiddenproperty(screenGui, "Name", screenGui.Name)
		end
	end)

	-- ══════════════ WATERMARK ══════════════

	local watermarkFrame = mk("Frame", screenGui, {
		Name = "Watermark",
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.BgWindow,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 5,
	})
	mk("UICorner", watermarkFrame, { CornerRadius = UDim.new(0, 4) })
	mk("UIStroke", watermarkFrame, { Color = Theme.Border, Thickness = 1, Transparency = 0.3 })
	mk("UIPadding", watermarkFrame, {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	})

	local watermarkLabel = mk("TextLabel", watermarkFrame, {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Theme.TextMid,
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		ZIndex = 5,
	})

	local wmFpsCount = 0
	local wmFpsTimer = 0
	local wmCurrentFps = 0

	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		if not watermarkFrame.Visible then return end
		wmFpsCount = wmFpsCount + 1
		wmFpsTimer = wmFpsTimer + dt
		if wmFpsTimer >= 0.5 then
			wmCurrentFps = math.floor(wmFpsCount / wmFpsTimer)
			wmFpsCount = 0
			wmFpsTimer = 0
			local parts = { title }
			pcall(function()
				local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
				table.insert(parts, ping .. "ms")
			end)
			table.insert(parts, wmCurrentFps .. "fps")
			pcall(function()
				table.insert(parts, #Players:GetPlayers() .. "plr")
			end)
			watermarkLabel.Text = table.concat(parts, "  |  ")
		end
	end))

	-- ══════════════ NOTIFICATION HOLDER ══════════════

	local notifHolder = mk("Frame", screenGui, {
		Name = "Notifications",
		Size = UDim2.new(0, 260, 1, -20),
		Position = UDim2.new(1, -270, 0, 10),
		BackgroundTransparency = 1,
		ZIndex = 8,
	})
	mk("UIListLayout", notifHolder, {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})

	-- ══════════════ WINDOW FRAME ══════════════

	local windowFrame = mk("Frame", screenGui, {
		Name = "Window",
		Size = size,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.BgWindow,
		BorderSizePixel = 0,
		ZIndex = 1,
	})
	mk("UICorner", windowFrame, { CornerRadius = UDim.new(0, 6) })
	mk("UIStroke", windowFrame, { Color = Theme.Border, Thickness = 1, Transparency = 0.4 })

	local shadow = mk("ImageLabel", windowFrame, {
		Size = UDim2.new(1, 30, 1, 30),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = "rbxassetid://6014261993",
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.5,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		ZIndex = 0,
	})

	-- ══════════════ TITLE BAR ══════════════

	local titleBar = mk("Frame", windowFrame, {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Theme.BgWindow,
		BorderSizePixel = 0,
		ZIndex = 2,
	})
	mk("UICorner", titleBar, { CornerRadius = UDim.new(0, 6) })
	mk("Frame", titleBar, {
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.new(0, 0, 1, -10),
		BackgroundColor3 = Theme.BgWindow,
		BorderSizePixel = 0,
		ZIndex = 2,
	})

	local accentDot = mk("Frame", titleBar, {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.new(0.5, -50, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	mk("UICorner", accentDot, { CornerRadius = UDim.new(1, 0) })

	mk("TextLabel", titleBar, {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Theme.Text,
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		ZIndex = 3,
	})

	-- ══════════════ TAB BAR ══════════════

	local tabBar = mk("Frame", windowFrame, {
		Name = "TabBar",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 36),
		BackgroundColor3 = Theme.BgTab,
		BorderSizePixel = 0,
		ZIndex = 2,
	})
	mk("Frame", tabBar, {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Theme.Border,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 3,
	})

	local tabButtonContainer = mk("Frame", tabBar, {
		Name = "Buttons",
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.new(0, 8, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 3,
	})
	mk("UIListLayout", tabButtonContainer, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
	})

	-- ══════════════ CONTENT CONTAINER ══════════════

	local contentContainer = mk("Frame", windowFrame, {
		Name = "Content",
		Size = UDim2.new(1, 0, 1, -67),
		Position = UDim2.new(0, 0, 0, 67),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 1,
	})

	-- ══════════════ DROPDOWN OVERLAY ══════════════

	local ddOverlay = mk("Frame", screenGui, {
		Name = "DropdownOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
	})
	local activeDropdown = nil

	local function closeDropdown()
		if activeDropdown then
			local dd = activeDropdown
			activeDropdown = nil
			tw(dd, { BackgroundTransparency = 1, Size = dd.Size - UDim2.fromOffset(0, 10) }, 0.12).Completed:Connect(function()
				dd:Destroy()
			end)
			ddOverlay.Visible = false
		end
	end

	mk("TextButton", ddOverlay, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 10,
	}).MouseButton1Click:Connect(closeDropdown)

	-- ══════════════ SHARED COLOR PICKER ══════════════

	local cpOverlay = mk("Frame", screenGui, {
		Name = "ColorPickerOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 12,
	})

	mk("TextButton", cpOverlay, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 12,
	}).MouseButton1Click:Connect(function()
		cpOverlay.Visible = false
	end)

	local cpPanel = mk("Frame", cpOverlay, {
		Size = UDim2.fromOffset(220, 206),
		BackgroundColor3 = Theme.BgSection,
		BorderSizePixel = 0,
		ZIndex = 13,
	})
	mk("UICorner", cpPanel, { CornerRadius = UDim.new(0, 6) })
	mk("UIStroke", cpPanel, { Color = Theme.BorderLight, Thickness = 1, Transparency = 0.3 })

	local cpH, cpS, cpV = 0, 1, 1
	local cpTarget = nil
	local cpSvDrag, cpHueDrag = false, false

	local cpSvBox = mk("TextButton", cpPanel, {
		Size = UDim2.fromOffset(162, 130),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.fromHSV(0, 1, 1),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 14,
	})
	mk("UICorner", cpSvBox, { CornerRadius = UDim.new(0, 4) })

	local cpWhite = mk("Frame", cpSvBox, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 15,
	})
	mk("UICorner", cpWhite, { CornerRadius = UDim.new(0, 4) })
	mk("UIGradient", cpWhite, {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
		Transparency = NumberSequence.new(0, 1),
		Rotation = 0,
	})

	local cpBlack = mk("Frame", cpSvBox, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 16,
	})
	mk("UICorner", cpBlack, { CornerRadius = UDim.new(0, 4) })
	mk("UIGradient", cpBlack, {
		Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.new(0, 0, 0)),
		Transparency = NumberSequence.new(1, 0),
		Rotation = 90,
	})

	local cpSvCursor = mk("Frame", cpSvBox, {
		Size = UDim2.fromOffset(10, 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 18,
	})
	mk("UICorner", cpSvCursor, { CornerRadius = UDim.new(1, 0) })
	mk("UIStroke", cpSvCursor, { Color = Color3.new(0, 0, 0), Thickness = 1.5 })

	local cpHueBar = mk("TextButton", cpPanel, {
		Size = UDim2.fromOffset(22, 130),
		Position = UDim2.fromOffset(180, 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 14,
	})
	mk("UICorner", cpHueBar, { CornerRadius = UDim.new(0, 4) })
	mk("UIGradient", cpHueBar, {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
			ColorSequenceKeypoint.new(0.167, Color3.fromHSV(0.167, 1, 1)),
			ColorSequenceKeypoint.new(0.333, Color3.fromHSV(0.333, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
			ColorSequenceKeypoint.new(0.667, Color3.fromHSV(0.667, 1, 1)),
			ColorSequenceKeypoint.new(0.833, Color3.fromHSV(0.833, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
		}),
		Rotation = 90,
	})

	local cpHueCursor = mk("Frame", cpHueBar, {
		Size = UDim2.new(1, 6, 0, 5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 18,
	})
	mk("UICorner", cpHueCursor, { CornerRadius = UDim.new(0, 2) })
	mk("UIStroke", cpHueCursor, { Color = Color3.new(0, 0, 0), Thickness = 1 })

	local cpHexBox = mk("TextBox", cpPanel, {
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(8, 146),
		BackgroundColor3 = Theme.BgInput,
		BorderSizePixel = 0,
		Text = "#FFFFFF",
		TextColor3 = Theme.Text,
		TextSize = 11,
		Font = Enum.Font.Code,
		ClearTextOnFocus = false,
		ZIndex = 14,
	})
	mk("UICorner", cpHexBox, { CornerRadius = UDim.new(0, 4) })
	mk("UIStroke", cpHexBox, { Color = Theme.Border, Thickness = 1, Transparency = 0.5 })
	mk("UIPadding", cpHexBox, { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })

	local cpRgbLabel = mk("TextLabel", cpPanel, {
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 174),
		BackgroundTransparency = 1,
		Text = "R: 255  G: 255  B: 255",
		TextColor3 = Theme.TextDim,
		TextSize = 10,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 14,
	})

	local cpPreview = mk("Frame", cpPanel, {
		Size = UDim2.fromOffset(30, 14),
		Position = UDim2.fromOffset(170, 178),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 14,
	})
	mk("UICorner", cpPreview, { CornerRadius = UDim.new(0, 3) })

	local function updateCpVisuals()
		local color = Color3.fromHSV(cpH, cpS, cpV)
		cpSvBox.BackgroundColor3 = Color3.fromHSV(cpH, 1, 1)
		cpSvCursor.Position = UDim2.new(cpS, 0, 1 - cpV, 0)
		cpHueCursor.Position = UDim2.new(0.5, 0, cpH, 0)
		cpHexBox.Text = formatColor(color)
		cpRgbLabel.Text = string.format("R: %d  G: %d  B: %d",
			math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))
		cpPreview.BackgroundColor3 = color
		if cpTarget then
			cpTarget.previewBtn.BackgroundColor3 = color
			cpTarget.element.Value = color
			if cpTarget.callback then
				cpTarget.callback(cpTarget.element, color)
			end
		end
	end

	cpSvBox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			cpSvDrag = true
			local p = cpSvBox.AbsolutePosition
			local s = cpSvBox.AbsoluteSize
			cpS = math.clamp((input.Position.X - p.X) / s.X, 0, 1)
			cpV = math.clamp(1 - (input.Position.Y - p.Y) / s.Y, 0, 1)
			updateCpVisuals()
		end
	end)

	cpHueBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			cpHueDrag = true
			local p = cpHueBar.AbsolutePosition
			local s = cpHueBar.AbsoluteSize
			cpH = math.clamp((input.Position.Y - p.Y) / s.Y, 0, 0.999)
			updateCpVisuals()
		end
	end)

	cpHexBox.FocusLost:Connect(function()
		local c = parseHex(cpHexBox.Text)
		if c then
			cpH, cpS, cpV = Color3.toHSV(c)
			updateCpVisuals()
		else
			cpHexBox.Text = formatColor(Color3.fromHSV(cpH, cpS, cpV))
		end
	end)

	local function openColorPicker(absPos, absSize, color, element, callback)
		cpH, cpS, cpV = Color3.toHSV(color)
		cpTarget = { element = element, callback = callback, previewBtn = element._previewBtn }
		local vp = Camera.ViewportSize
		local px = math.clamp(absPos.X, 10, vp.X - 230)
		local py = math.clamp(absPos.Y + absSize.Y + 4, 10, vp.Y - 216)
		cpPanel.Position = UDim2.fromOffset(px, py)
		updateCpVisuals()
		cpOverlay.Visible = true
	end

	-- ══════════════ GLOBAL INPUT TRACKING ══════════════

	local dragging, dragStart, startPos

	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = windowFrame.Position
		end
	end)

	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if dragging then
				local delta = input.Position - dragStart
				windowFrame.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + delta.X,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y
				)
			end
			if activeSlider then
				activeSlider(input)
			end
			if cpSvDrag then
				local p = cpSvBox.AbsolutePosition
				local s = cpSvBox.AbsoluteSize
				cpS = math.clamp((input.Position.X - p.X) / s.X, 0, 1)
				cpV = math.clamp(1 - (input.Position.Y - p.Y) / s.Y, 0, 1)
				updateCpVisuals()
			end
			if cpHueDrag then
				local p = cpHueBar.AbsolutePosition
				local s = cpHueBar.AbsoluteSize
				cpH = math.clamp((input.Position.Y - p.Y) / s.Y, 0, 0.999)
				updateCpVisuals()
			end
		end
	end))

	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
			activeSlider = nil
			cpSvDrag = false
			cpHueDrag = false
		end
	end))

	-- ══════════════ TOGGLE KEY ══════════════

	local isAnimating = false
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == toggleKey and not isAnimating then
			isAnimating = true
			visible = not visible
			if visible then
				windowFrame.Visible = true
				windowFrame.BackgroundTransparency = 0.4
				local reduced = size - UDim2.fromOffset(20, 20)
				windowFrame.Size = reduced
				tw(windowFrame, { Size = size, BackgroundTransparency = 0 }, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out).Completed:Connect(function()
					isAnimating = false
				end)
				for _, desc in ipairs(windowFrame:GetDescendants()) do
					if desc:IsA("Frame") and desc.BackgroundTransparency == 0 then
					elseif desc:IsA("TextLabel") then
						desc.TextTransparency = 0
					end
				end
			else
				tw(windowFrame, {
					Size = size - UDim2.fromOffset(15, 15),
					BackgroundTransparency = 0.6,
				}, 0.14).Completed:Connect(function()
					windowFrame.Visible = false
					isAnimating = false
				end)
			end
		end
	end))

	-- ══════════════ TAB SWITCHING ══════════════

	local function showTab(index)
		for i, tab in ipairs(tabs) do
			local active = (i == index)
			tab.scrollFrame.Visible = active
			if tab.button then
				tw(tab.buttonLabel, {
					TextColor3 = active and Theme.Text or Theme.TextDim,
				}, 0.15)
				tw(tab.indicator, {
					BackgroundTransparency = active and 0 or 1,
				}, 0.15)
				tw(tab.button, {
					BackgroundColor3 = active and Theme.BgTabActive or Theme.BgTab,
				}, 0.15)
			end
		end
		currentTabIndex = index
	end

	-- ══════════════ WINDOW:CREATETAB ══════════════

	function Window:CreateTab(name)
		local Tab = {}
		local tabIndex = #tabs + 1
		local sectionCount = 0

		local tabWidth = math.floor(1 / math.max(tabIndex, 1))

		local btn = mk("TextButton", tabButtonContainer, {
			Name = "Tab_" .. name,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.BgTab,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = tabIndex,
			ZIndex = 3,
		})
		mk("UIPadding", btn, {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
		})

		local indicator = mk("Frame", btn, {
			Size = UDim2.new(1, 0, 0, 2),
			Position = UDim2.new(0, 0, 1, -2),
			BackgroundColor3 = Theme.Accent,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 4,
		})

		local btnLabel = mk("TextLabel", btn, {
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = Theme.TextDim,
			TextSize = 12,
			Font = Enum.Font.GothamSemibold,
			ZIndex = 4,
		})

		local scrollFrame = mk("ScrollingFrame", contentContainer, {
			Name = "Scroll_" .. name,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme.Accent,
			ScrollBarImageTransparency = 0.5,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = (tabIndex == 1),
			ZIndex = 1,
		})

		local tabContent = mk("Frame", scrollFrame, {
			Name = "TabContent",
			Size = UDim2.new(1, -8, 0, 0),
			Position = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		})

		local leftCol = mk("Frame", tabContent, {
			Name = "Left",
			Size = UDim2.new(0.5, -5, 0, 0),
			Position = UDim2.fromOffset(6, 6),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		})
		mk("UIListLayout", leftCol, {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		})

		local rightCol = mk("Frame", tabContent, {
			Name = "Right",
			Size = UDim2.new(0.5, -5, 0, 0),
			Position = UDim2.new(0.5, 3, 0, 6),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		})
		mk("UIListLayout", rightCol, {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		})

		local tabData = {
			button = btn,
			buttonLabel = btnLabel,
			indicator = indicator,
			scrollFrame = scrollFrame,
			leftCol = leftCol,
			rightCol = rightCol,
		}
		tabs[tabIndex] = tabData

		btn.MouseEnter:Connect(function()
			if currentTabIndex ~= tabIndex then
				tw(btn, { BackgroundColor3 = Theme.BgHover }, 0.1)
			end
		end)
		btn.MouseLeave:Connect(function()
			if currentTabIndex ~= tabIndex then
				tw(btn, { BackgroundColor3 = Theme.BgTab }, 0.1)
			end
		end)
		btn.MouseButton1Click:Connect(function()
			closeDropdown()
			if cpOverlay.Visible then cpOverlay.Visible = false end
			showTab(tabIndex)
		end)

		if tabIndex == 1 then
			showTab(1)
		end

		-- ══════════════ TAB:CREATESECTION ══════════════

		function Tab:CreateSection(sectionTitle)
			local Section = {}
			local elementOrder = 0
			sectionCount = sectionCount + 1

			local targetCol = (sectionCount % 2 == 1) and leftCol or rightCol

			local sectionFrame = mk("Frame", targetCol, {
				Name = "S_" .. sectionTitle,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.BgSection,
				BorderSizePixel = 0,
				LayoutOrder = sectionCount,
			})
			mk("UICorner", sectionFrame, { CornerRadius = UDim.new(0, 5) })
			mk("UIStroke", sectionFrame, { Color = Theme.Border, Thickness = 1, Transparency = 0.6 })

			local header = mk("Frame", sectionFrame, {
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundColor3 = Theme.BgHeader,
				BorderSizePixel = 0,
			})
			mk("UICorner", header, { CornerRadius = UDim.new(0, 5) })
			mk("Frame", header, {
				Size = UDim2.new(1, 0, 0, 8),
				Position = UDim2.new(0, 0, 1, -8),
				BackgroundColor3 = Theme.BgHeader,
				BorderSizePixel = 0,
			})

			mk("Frame", header, {
				Size = UDim2.fromOffset(3, 12),
				Position = UDim2.new(0, 8, 0.5, -6),
				BackgroundColor3 = Theme.Accent,
				BorderSizePixel = 0,
			})

			mk("TextLabel", header, {
				Size = UDim2.new(1, -20, 1, 0),
				Position = UDim2.fromOffset(16, 0),
				BackgroundTransparency = 1,
				Text = sectionTitle,
				TextColor3 = Theme.Text,
				TextSize = 11,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			})

			local body = mk("Frame", sectionFrame, {
				Name = "Body",
				Size = UDim2.new(1, -12, 0, 0),
				Position = UDim2.fromOffset(6, 30),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
			})
			mk("UIListLayout", body, {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 3),
			})
			mk("UIPadding", body, { PaddingBottom = UDim.new(0, 8) })

			local function nextOrder()
				elementOrder = elementOrder + 1
				return elementOrder
			end

			-- ═══════ CHECKBOX ═══════

			function Section:Checkbox(cfg)
				local value = cfg.Value or false
				local cb = cfg.Callback
				local el = { Value = value }

				local row = mk("TextButton", body, {
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					Text = "",
					AutoButtonColor = false,
					LayoutOrder = nextOrder(),
				})

				local box = mk("Frame", row, {
					Size = UDim2.fromOffset(13, 13),
					Position = UDim2.new(0, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = value and Theme.Accent or Theme.BgInput,
					BorderSizePixel = 0,
				})
				mk("UICorner", box, { CornerRadius = UDim.new(0, 3) })
				mk("UIStroke", box, { Color = value and Theme.AccentDark or Theme.Border, Thickness = 1, Transparency = 0.4 })

				local check = mk("TextLabel", box, {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "\xE2\x9C\x93",
					TextColor3 = Theme.Text,
					TextSize = 10,
					Font = Enum.Font.GothamBold,
					TextTransparency = value and 0 or 1,
				})

				local lbl = mk("TextLabel", row, {
					Size = UDim2.new(1, -20, 1, 0),
					Position = UDim2.fromOffset(20, 0),
					BackgroundTransparency = 1,
					Text = cfg.Label or "",
					TextColor3 = Theme.TextMid,
					TextSize = 11,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				row.MouseEnter:Connect(function()
					tw(lbl, { TextColor3 = Theme.Text }, 0.08)
				end)
				row.MouseLeave:Connect(function()
					tw(lbl, { TextColor3 = Theme.TextMid }, 0.08)
				end)

				row.MouseButton1Click:Connect(function()
					value = not value
					el.Value = value
					twSpring(box, { BackgroundColor3 = value and Theme.Accent or Theme.BgInput }, 0.2)
					local stroke = box:FindFirstChildOfClass("UIStroke")
					if stroke then tw(stroke, { Color = value and Theme.AccentDark or Theme.Border }, 0.15) end
					if value then
						check.TextTransparency = 0
						check.TextSize = 6
						twSpring(check, { TextSize = 10 }, 0.2)
					else
						tw(check, { TextTransparency = 1 }, 0.1)
					end
					if cb then cb(el, value) end
				end)

				function el:SetValue(v)
					value = v
					el.Value = v
					box.BackgroundColor3 = v and Theme.Accent or Theme.BgInput
					local stroke = box:FindFirstChildOfClass("UIStroke")
					if stroke then stroke.Color = v and Theme.AccentDark or Theme.Border end
					check.TextTransparency = v and 0 or 1
				end

				return el
			end

			-- ═══════ SLIDER ═══════

			function Section:Slider(cfg)
				local value = cfg.Value or 0
				local min = cfg.MinValue or cfg.Min or 0
				local max = cfg.MaxValue or cfg.Max or 100
				local increment = cfg.Increment or 1
				local cb = cfg.Callback
				local el = { Value = value }

				local frame = mk("Frame", body, {
					Size = UDim2.new(1, 0, 0, 32),
					BackgroundTransparency = 1,
					LayoutOrder = nextOrder(),
				})

				local lbl = mk("TextLabel", frame, {
					Size = UDim2.new(0.65, 0, 0, 14),
					BackgroundTransparency = 1,
					Text = cfg.Label or "",
					TextColor3 = Theme.TextMid,
					TextSize = 11,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				local valLabel = mk("TextLabel", frame, {
					Size = UDim2.new(0.35, 0, 0, 14),
					Position = UDim2.new(0.65, 0, 0, 0),
					BackgroundTransparency = 1,
					Text = tostring(value),
					TextColor3 = Theme.Accent,
					TextSize = 11,
					Font = Enum.Font.GothamMedium,
					TextXAlignment = Enum.TextXAlignment.Right,
				})

				local track = mk("TextButton", frame, {
					Size = UDim2.new(1, 0, 0, 6),
					Position = UDim2.fromOffset(0, 20),
					BackgroundColor3 = Theme.BgInput,
					BorderSizePixel = 0,
					Text = "",
					AutoButtonColor = false,
				})
				mk("UICorner", track, { CornerRadius = UDim.new(1, 0) })

				local ratio = math.clamp((value - min) / math.max(max - min, 1), 0, 1)

				local fill = mk("Frame", track, {
					Size = UDim2.new(ratio, 0, 1, 0),
					BackgroundColor3 = Theme.Accent,
					BorderSizePixel = 0,
				})
				mk("UICorner", fill, { CornerRadius = UDim.new(1, 0) })

				local fillGlow = mk("Frame", fill, {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundColor3 = Theme.AccentHover,
					BackgroundTransparency = 0.7,
					BorderSizePixel = 0,
				})
				mk("UICorner", fillGlow, { CornerRadius = UDim.new(1, 0) })

				local thumb = mk("Frame", track, {
					Size = UDim2.fromOffset(10, 10),
					Position = UDim2.new(ratio, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Theme.Text,
					BorderSizePixel = 0,
					ZIndex = 2,
				})
				mk("UICorner", thumb, { CornerRadius = UDim.new(1, 0) })

				local function formatVal(v)
					if increment < 1 then
						local decimals = math.ceil(-math.log10(increment))
						return string.format("%." .. decimals .. "f", v)
					end
					return tostring(math.floor(v))
				end

				local function updateFromInput(input)
					local absX = track.AbsolutePosition.X
					local absW = track.AbsoluteSize.X
					local r = math.clamp((input.Position.X - absX) / absW, 0, 1)
					local raw = min + r * (max - min)
					local newVal = math.floor(raw / increment + 0.5) * increment
					newVal = math.clamp(newVal, min, max)
					if newVal ~= value then
						value = newVal
						el.Value = value
						valLabel.Text = formatVal(value)
						local nr = (value - min) / math.max(max - min, 1)
						fill.Size = UDim2.new(nr, 0, 1, 0)
						thumb.Position = UDim2.new(nr, 0, 0.5, 0)
						if cb then cb(el, value) end
					end
				end

				track.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						activeSlider = updateFromInput
						updateFromInput(input)
					end
				end)

				function el:SetValue(v)
					value = math.clamp(v, min, max)
					el.Value = value
					local r = (value - min) / math.max(max - min, 1)
					valLabel.Text = formatVal(value)
					fill.Size = UDim2.new(r, 0, 1, 0)
					thumb.Position = UDim2.new(r, 0, 0.5, 0)
				end

				return el
			end

			-- ═══════ COMBO ═══════

			function Section:Combo(cfg)
				local selected = cfg.Selected or cfg.Value or ""
				local items = cfg.Items or cfg.Options or {}
				local cb = cfg.Callback
				local internal = { items = items }

				local frame = mk("Frame", body, {
					Size = UDim2.new(1, 0, 0, 22),
					BackgroundTransparency = 1,
					LayoutOrder = nextOrder(),
				})

				mk("TextLabel", frame, {
					Size = UDim2.new(0.45, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = cfg.Label or "",
					TextColor3 = Theme.TextMid,
					TextSize = 11,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				local btnFrame = mk("Frame", frame, {
					Size = UDim2.new(0.55, 0, 1, 0),
					Position = UDim2.new(0.45, 0, 0, 0),
					BackgroundColor3 = Theme.BgInput,
					BorderSizePixel = 0,
				})
				mk("UICorner", btnFrame, { CornerRadius = UDim.new(0, 3) })
				mk("UIStroke", btnFrame, { Color = Theme.Border, Thickness = 1, Transparency = 0.6 })

				local selBtn = mk("TextButton", btnFrame, {
					Size = UDim2.new(1, -8, 1, 0),
					Position = UDim2.fromOffset(6, 0),
					BackgroundTransparency = 1,
					Text = tostring(selected) .. "  \xE2\x96\xBE",
					TextColor3 = Theme.TextMid,
					TextSize = 11,
					Font = Enum.Font.Gotham,
					AutoButtonColor = false,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				})

				local el

				local function openDropdownMenu()
					closeDropdown()

					local absPos = btnFrame.AbsolutePosition
					local absSize = btnFrame.AbsoluteSize
					local vp = Camera.ViewportSize
					local maxH = math.min(#internal.items * 22 + 6, 180)

					local ddX = math.clamp(absPos.X, 4, vp.X - absSize.X - 4)
					local ddY = absPos.Y + absSize.Y + 2
					if ddY + maxH > vp.Y - 10 then
						ddY = absPos.Y - maxH - 2
					end

					local dd = mk("Frame", ddOverlay, {
						Size = UDim2.fromOffset(absSize.X, 0),
						Position = UDim2.fromOffset(ddX, ddY),
						BackgroundColor3 = Theme.BgSection,
						BorderSizePixel = 0,
						ZIndex = 11,
						ClipsDescendants = true,
					})
					mk("UICorner", dd, { CornerRadius = UDim.new(0, 4) })
					mk("UIStroke", dd, { Color = Theme.BorderLight, Thickness = 1, Transparency = 0.3 })

					twSpring(dd, { Size = UDim2.fromOffset(absSize.X, maxH) }, 0.2)

					local scroll = mk("ScrollingFrame", dd, {
						Size = UDim2.new(1, -4, 1, -4),
						Position = UDim2.fromOffset(2, 2),
						BackgroundTransparency = 1,
						ScrollBarThickness = 2,
						ScrollBarImageColor3 = Theme.Accent,
						BorderSizePixel = 0,
						CanvasSize = UDim2.fromOffset(0, #internal.items * 22),
						ZIndex = 11,
					})
					mk("UIListLayout", scroll, {
						SortOrder = Enum.SortOrder.LayoutOrder,
					})

					for idx, item in ipairs(internal.items) do
						local isActive = (item == selected)
						local opt = mk("TextButton", scroll, {
							Size = UDim2.new(1, 0, 0, 22),
							BackgroundColor3 = Theme.Accent,
							BackgroundTransparency = isActive and 0.75 or 1,
							Text = "",
							AutoButtonColor = false,
							LayoutOrder = idx,
							ZIndex = 12,
						})

						local optLabel = mk("TextLabel", opt, {
							Size = UDim2.new(1, -14, 1, 0),
							Position = UDim2.fromOffset(8, 0),
							BackgroundTransparency = 1,
							Text = tostring(item),
							TextColor3 = isActive and Theme.Text or Theme.TextMid,
							TextSize = 11,
							Font = Enum.Font.Gotham,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex = 12,
						})

						opt.MouseEnter:Connect(function()
							if item ~= selected then
								tw(opt, { BackgroundTransparency = 0.85 }, 0.08)
								tw(optLabel, { TextColor3 = Theme.Text }, 0.08)
							end
						end)
						opt.MouseLeave:Connect(function()
							if item ~= selected then
								tw(opt, { BackgroundTransparency = 1 }, 0.08)
								tw(optLabel, { TextColor3 = Theme.TextMid }, 0.08)
							end
						end)
						opt.MouseButton1Click:Connect(function()
							selected = item
							rawset(el, "Value", selected)
							selBtn.Text = tostring(selected) .. "  \xE2\x96\xBE"
							if cb then cb(el, selected) end
							closeDropdown()
						end)
					end

					activeDropdown = dd
					ddOverlay.Visible = true
				end

				selBtn.MouseButton1Click:Connect(openDropdownMenu)

				el = setmetatable({}, {
					__newindex = function(t, k, v)
						if k == "Items" then
							internal.items = v
							local found = false
							for _, item in ipairs(v) do
								if item == selected then found = true; break end
							end
							if not found and #v > 0 then
								selected = v[1]
								rawset(t, "Value", selected)
								selBtn.Text = tostring(selected) .. "  \xE2\x96\xBE"
							end
						else
							rawset(t, k, v)
						end
					end,
					__index = function(t, k)
						if k == "Items" then return internal.items end
						return rawget(t, k)
					end,
				})

				el.Value = selected

				function el:SetItems(newItems)
					internal.items = newItems
				end

				function el:SetValue(v)
					selected = v
					rawset(el, "Value", v)
					selBtn.Text = tostring(v) .. "  \xE2\x96\xBE"
				end

				return el
			end

			-- ═══════ COLOR PICKER ═══════

			function Section:ColorPicker(cfg)
				local value = cfg.Value or Color3.fromRGB(255, 255, 255)
				local cb = cfg.Callback
				local el = { Value = value }

				local frame = mk("Frame", body, {
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					LayoutOrder = nextOrder(),
				})

				mk("TextLabel", frame, {
					Size = UDim2.new(1, -46, 1, 0),
					BackgroundTransparency = 1,
					Text = cfg.Label or "",
					TextColor3 = Theme.TextMid,
					TextSize = 11,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				local previewBtn = mk("TextButton", frame, {
					Size = UDim2.new(0, 36, 0, 14),
					Position = UDim2.new(1, -36, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = value,
					BorderSizePixel = 0,
					Text = "",
					AutoButtonColor = false,
				})
				mk("UICorner", previewBtn, { CornerRadius = UDim.new(0, 3) })
				mk("UIStroke", previewBtn, { Color = Theme.Border, Thickness = 1, Transparency = 0.4 })

				el._previewBtn = previewBtn

				previewBtn.MouseButton1Click:Connect(function()
					if cpOverlay.Visible and cpTarget and cpTarget.element == el then
						cpOverlay.Visible = false
						return
					end
					openColorPicker(
						previewBtn.AbsolutePosition,
						previewBtn.AbsoluteSize,
						value,
						el,
						function(element, c)
							value = c
							if cb then cb(element, c) end
						end
					)
				end)

				function el:SetValue(c)
					value = c
					el.Value = c
					previewBtn.BackgroundColor3 = c
				end

				return el
			end

			-- ═══════ KEYBIND ═══════

			function Section:Keybind(cfg)
				local value = cfg.Value or Enum.KeyCode.Unknown
				local cb = cfg.Callback
				local listening = false
				local el = { Value = value }

				local frame = mk("Frame", body, {
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					LayoutOrder = nextOrder(),
				})

				mk("TextLabel", frame, {
					Size = UDim2.new(1, -62, 1, 0),
					BackgroundTransparency = 1,
					Text = cfg.Label or "",
					TextColor3 = Theme.TextMid,
					TextSize = 11,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				local keyBtn = mk("TextButton", frame, {
					Size = UDim2.new(0, 56, 0, 18),
					Position = UDim2.new(1, -56, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = Theme.BgInput,
					BorderSizePixel = 0,
					Text = "[" .. (value.Name or "None") .. "]",
					TextColor3 = Theme.TextDim,
					TextSize = 10,
					Font = Enum.Font.GothamMedium,
					AutoButtonColor = false,
				})
				mk("UICorner", keyBtn, { CornerRadius = UDim.new(0, 3) })
				mk("UIStroke", keyBtn, { Color = Theme.Border, Thickness = 1, Transparency = 0.6 })

				local listenConn
				keyBtn.MouseButton1Click:Connect(function()
					if listening then return end
					listening = true
					keyBtn.Text = "[...]"
					tw(keyBtn, { BackgroundColor3 = Theme.AccentDark }, 0.12)

					listenConn = UserInputService.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.Keyboard then
							if input.KeyCode == Enum.KeyCode.Escape then
								keyBtn.Text = "[" .. value.Name .. "]"
							else
								value = input.KeyCode
								el.Value = value
								keyBtn.Text = "[" .. value.Name .. "]"
								if cb then cb(el, value) end
							end
							tw(keyBtn, { BackgroundColor3 = Theme.BgInput }, 0.12)
							listening = false
							if listenConn then listenConn:Disconnect() end
						end
					end)
				end)

				function el:SetValue(v)
					value = v
					el.Value = v
					keyBtn.Text = "[" .. v.Name .. "]"
				end

				return el
			end

			-- ═══════ INPUT TEXT ═══════

			function Section:InputText(cfg)
				local value = cfg.Value or ""
				local cb = cfg.Callback
				local el = {}

				local frame = mk("Frame", body, {
					Size = UDim2.new(1, 0, 0, 22),
					BackgroundTransparency = 1,
					LayoutOrder = nextOrder(),
				})

				mk("TextLabel", frame, {
					Size = UDim2.new(0.38, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = cfg.Label or "",
					TextColor3 = Theme.TextMid,
					TextSize = 11,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				local inputBox = mk("TextBox", frame, {
					Size = UDim2.new(0.62, 0, 1, 0),
					Position = UDim2.new(0.38, 0, 0, 0),
					BackgroundColor3 = Theme.BgInput,
					BorderSizePixel = 0,
					Text = value,
					PlaceholderText = cfg.PlaceHolder or cfg.Placeholder or "",
					PlaceholderColor3 = Color3.fromRGB(50, 50, 58),
					TextColor3 = Theme.Text,
					TextSize = 11,
					Font = Enum.Font.Gotham,
					ClearTextOnFocus = false,
					TextTruncate = Enum.TextTruncate.AtEnd,
				})
				mk("UICorner", inputBox, { CornerRadius = UDim.new(0, 3) })
				mk("UIPadding", inputBox, { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
				local iStroke = mk("UIStroke", inputBox, { Color = Theme.Border, Thickness = 1, Transparency = 0.6 })

				inputBox.Focused:Connect(function()
					tw(iStroke, { Color = Theme.Accent, Transparency = 0.2 }, 0.15)
				end)
				inputBox.FocusLost:Connect(function()
					value = inputBox.Text
					tw(iStroke, { Color = Theme.Border, Transparency = 0.6 }, 0.15)
					if cb then cb(el, value) end
				end)

				function el:GetValue()
					return inputBox.Text
				end
				function el:SetValue(v)
					inputBox.Text = v
					value = v
				end

				return el
			end

			-- ═══════ BUTTON ═══════

			function Section:Button(cfg)
				local cb = cfg.Callback
				local el = {}

				local btn = mk("TextButton", body, {
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundColor3 = Theme.BgInput,
					BorderSizePixel = 0,
					Text = cfg.Text or "Button",
					TextColor3 = Theme.TextMid,
					TextSize = 11,
					Font = Enum.Font.GothamMedium,
					AutoButtonColor = false,
					LayoutOrder = nextOrder(),
				})
				mk("UICorner", btn, { CornerRadius = UDim.new(0, 4) })
				mk("UIStroke", btn, { Color = Theme.Border, Thickness = 1, Transparency = 0.6 })

				btn.MouseEnter:Connect(function()
					tw(btn, { BackgroundColor3 = Theme.AccentDark, TextColor3 = Theme.Text }, 0.12)
				end)
				btn.MouseLeave:Connect(function()
					tw(btn, { BackgroundColor3 = Theme.BgInput, TextColor3 = Theme.TextMid }, 0.1)
				end)
				btn.MouseButton1Down:Connect(function()
					twSnap(btn, { Size = UDim2.new(1, -4, 0, 22) }, 0.05)
				end)
				btn.MouseButton1Up:Connect(function()
					twSpring(btn, { Size = UDim2.new(1, 0, 0, 24) }, 0.15)
				end)
				btn.MouseButton1Click:Connect(function()
					if cb then cb() end
				end)

				return el
			end

			-- ═══════ LABEL ═══════

			function Section:Label(cfg)
				local el = {}

				local lbl = mk("TextLabel", body, {
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					Text = cfg.Text or "",
					TextColor3 = Theme.TextDim,
					TextSize = 11,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = nextOrder(),
				})

				function el:SetText(t)
					lbl.Text = t
				end

				return el
			end

			-- ═══════ SEPARATOR ═══════

			function Section:Separator()
				mk("Frame", body, {
					Size = UDim2.new(1, 0, 0, 1),
					BackgroundColor3 = Theme.Border,
					BackgroundTransparency = 0.4,
					BorderSizePixel = 0,
					LayoutOrder = nextOrder(),
				})
			end

			return Section
		end

		return Tab
	end

	-- ══════════════ NOTIFY ══════════════

	function Window:Notify(cfg)
		cfg = cfg or {}
		local nTitle = cfg.Title or "Notification"
		local nText = cfg.Text or ""
		local duration = cfg.Duration or 3
		local nType = cfg.Type or "info"

		notifOrder = notifOrder + 1

		local accentColor =
			nType == "success" and Theme.Green or
			nType == "warning" and Theme.Yellow or
			nType == "error" and Theme.Red or
			Theme.Accent

		local card = mk("Frame", notifHolder, {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.BgWindow,
			BorderSizePixel = 0,
			LayoutOrder = notifOrder,
			ClipsDescendants = true,
			ZIndex = 8,
		})
		mk("UICorner", card, { CornerRadius = UDim.new(0, 6) })
		mk("UIStroke", card, { Color = Theme.Border, Thickness = 1, Transparency = 0.4 })

		mk("Frame", card, {
			Name = "AccentBar",
			Size = UDim2.new(0, 3, 1, 0),
			BackgroundColor3 = accentColor,
			BorderSizePixel = 0,
			ZIndex = 9,
		})

		local contentFrame = mk("Frame", card, {
			Size = UDim2.new(1, -16, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(12, 0),
			BackgroundTransparency = 1,
			ZIndex = 8,
		})
		mk("UIListLayout", contentFrame, {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		})
		mk("UIPadding", contentFrame, {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		})

		mk("TextLabel", contentFrame, {
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
			Text = nTitle,
			TextColor3 = Theme.Text,
			TextSize = 12,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			ZIndex = 8,
		})

		if nText ~= "" then
			mk("TextLabel", contentFrame, {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = nText,
				TextColor3 = Theme.TextMid,
				TextSize = 11,
				Font = Enum.Font.Gotham,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				LayoutOrder = 2,
				ZIndex = 8,
			})
		end

		local progressBar = mk("Frame", card, {
			Size = UDim2.new(1, 0, 0, 2),
			Position = UDim2.new(0, 0, 1, -2),
			BackgroundColor3 = accentColor,
			BorderSizePixel = 0,
			ZIndex = 9,
		})

		tw(progressBar, { Size = UDim2.new(0, 0, 0, 2) }, duration, Enum.EasingStyle.Linear)

		task.delay(duration, function()
			if card and card.Parent then
				tw(card, { BackgroundTransparency = 1 }, 0.3)
				for _, desc in ipairs(card:GetDescendants()) do
					if desc:IsA("TextLabel") then
						tw(desc, { TextTransparency = 1 }, 0.3)
					elseif desc:IsA("Frame") then
						tw(desc, { BackgroundTransparency = 1 }, 0.3)
					elseif desc:IsA("UIStroke") then
						tw(desc, { Transparency = 1 }, 0.3)
					end
				end
				task.delay(0.35, function()
					if card and card.Parent then card:Destroy() end
				end)
			end
		end)
	end

	-- ══════════════ WINDOW METHODS ══════════════

	function Window:SetVisible(v)
		visible = v
		windowFrame.Visible = v
	end

	function Window:Close()
		windowFrame.Visible = false
		visible = false
	end

	function Window:Destroy()
		for _, conn in ipairs(connections) do
			if conn and conn.Connected then
				conn:Disconnect()
			end
		end
		connections = {}
		screenGui:Destroy()
	end

	function Window:IsVisible()
		return visible
	end

	function Window:SetWatermarkVisible(v)
		watermarkFrame.Visible = v
	end

	function Window:UpdateWatermark(text)
		watermarkLabel.Text = text
	end

	Window.Window = windowFrame
	Window.ScreenGui = screenGui

	return Window
end

return Library
