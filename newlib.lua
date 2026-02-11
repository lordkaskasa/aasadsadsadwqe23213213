--!strict
--!native
--!optimize 2

local CloneRef = cloneref or function(x) return x end
local Players = CloneRef(game:GetService("Players"))
local TweenService = CloneRef(game:GetService("TweenService"))
local UserInputService = CloneRef(game:GetService("UserInputService"))
local RunService = CloneRef(game:GetService("RunService"))
local TextService = CloneRef(game:GetService("TextService"))
local CoreGui = CloneRef(game:GetService("CoreGui"))
local HttpService = CloneRef(game:GetService("HttpService"))

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local isStudio = RunService:IsStudio()
local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end
local GetHUI = gethui or function() return CoreGui end

local guiParent = isStudio and LocalPlayer:WaitForChild("PlayerGui") or (function()
	local ok, result = pcall(function() return GetHUI() end)
	return ok and result or CoreGui
end)()

pcall(function()
	for _, g in guiParent:GetChildren() do
		if g:IsA("ScreenGui") and g.Name:sub(1, 8) == "NeonLib_" then
			g:Destroy()
		end
	end
end)

local Toggles = {}
local Options = {}
local Library = {
	ScreenGui = nil :: ScreenGui?,
	Unloaded = false,
	ToggleKey = Enum.KeyCode.RightShift,
	Watermark = nil,
	WatermarkVisible = false,
	Notifications = {},
	Flags = {},
	Toggled = true,
}

getgenv().NeonLib = { Toggles = Toggles, Options = Options }
getgenv().Toggles = Toggles
getgenv().Options = Options

local Theme = {
	Accent = Color3.fromRGB(130, 180, 255),
	AccentDark = Color3.fromRGB(90, 140, 210),
	BgMain = Color3.fromRGB(18, 18, 22),
	BgWindow = Color3.fromRGB(22, 22, 28),
	BgElement = Color3.fromRGB(28, 28, 36),
	BgElementHover = Color3.fromRGB(35, 35, 44),
	BgField = Color3.fromRGB(20, 20, 26),
	Border = Color3.fromRGB(44, 44, 56),
	BorderAccent = Color3.fromRGB(60, 60, 78),
	Text = Color3.fromRGB(210, 210, 220),
	TextDim = Color3.fromRGB(140, 140, 155),
	TextDark = Color3.fromRGB(90, 90, 105),
	Shadow = Color3.fromRGB(8, 8, 12),
	Success = Color3.fromRGB(100, 220, 140),
	Warning = Color3.fromRGB(240, 200, 80),
	Error = Color3.fromRGB(240, 90, 90),
}

local FONT = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local FONT_BOLD = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
local FONT_MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

local TWEEN_FAST = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_MED = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_SLOW = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function tween(obj, info, props)
	TweenService:Create(obj, info, props):Play()
end

local function mk(class: string, parent: Instance?, props: {[string]: any}?): Instance
	local inst = Instance.new(class)
	if props then
		for k, v in props do
			if k ~= "Parent" then
				(inst :: any)[k] = v
			end
		end
	end
	if parent then
		inst.Parent = parent
	elseif props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function textSize(text: string, size: number, font: Font, bounds: Vector2?): Vector2
	local params = Instance.new("GetTextBoundsParams")
	params.Text = text
	params.Size = size
	params.Font = font
	params.Width = bounds and bounds.X or math.huge
	local ok, result = pcall(function()
		return TextService:GetTextBoundsAsync(params)
	end)
	if ok then return result end
	return Vector2.new(#text * size * 0.5, size)
end

local function enableDrag(frame: Frame)
	local dragging = false
	local dragStart: Vector3
	local startPos: UDim2

	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

local function isMouseOver(obj: GuiObject): boolean
	local pos = UserInputService:GetMouseLocation()
	local absPos = obj.AbsolutePosition
	local absSize = obj.AbsoluteSize
	return pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NeonLib_" .. HttpService:GenerateGUID(false):sub(1, 8)
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
pcall(ProtectGui, screenGui)
screenGui.Parent = guiParent
Library.ScreenGui = screenGui

local tooltipLabel: TextLabel
local tooltipFrame: Frame

do
	tooltipFrame = mk("Frame", screenGui, {
		Name = "Tooltip",
		BackgroundColor3 = Theme.BgWindow,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(200, 24),
		Visible = false,
		ZIndex = 200,
	}) :: Frame
	mk("UICorner", tooltipFrame, { CornerRadius = UDim.new(0, 4) })
	mk("UIStroke", tooltipFrame, { Color = Theme.Border, Thickness = 1 })
	mk("UIPadding", tooltipFrame, {
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
	})
	tooltipLabel = mk("TextLabel", tooltipFrame, {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = FONT,
		TextSize = 13,
		TextColor3 = Theme.TextDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}) :: TextLabel
end

local function showTooltip(text: string)
	if not text or text == "" then return end
	tooltipLabel.Text = text
	tooltipFrame.Visible = true
	local sz = textSize(text, 13, FONT, Vector2.new(250, math.huge))
	tooltipFrame.Size = UDim2.fromOffset(sz.X + 18, sz.Y + 10)
end

local function moveTooltip()
	local pos = UserInputService:GetMouseLocation()
	tooltipFrame.Position = UDim2.fromOffset(pos.X + 14, pos.Y + 4)
end

local function hideTooltip()
	tooltipFrame.Visible = false
end

RunService.RenderStepped:Connect(function()
	if tooltipFrame.Visible then
		moveTooltip()
	end
end)

-- notification container
local notifContainer = mk("Frame", screenGui, {
	Name = "Notifications",
	BackgroundTransparency = 1,
	Size = UDim2.new(0, 300, 1, -20),
	Position = UDim2.new(1, -310, 0, 10),
	ZIndex = 150,
}) :: Frame
mk("UIListLayout", notifContainer, {
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Top,
	Padding = UDim.new(0, 6),
})

function Library:Notify(text: string, duration: number?, notifType: string?)
	duration = duration or 4
	notifType = notifType or "info"

	local barColor = Theme.Accent
	if notifType == "success" then barColor = Theme.Success
	elseif notifType == "warning" then barColor = Theme.Warning
	elseif notifType == "error" then barColor = Theme.Error end

	local notif = mk("Frame", notifContainer, {
		Name = "Notif",
		BackgroundColor3 = Theme.BgWindow,
		Size = UDim2.new(1, 0, 0, 0),
		ClipsDescendants = true,
		BackgroundTransparency = 0.05,
	}) :: Frame
	mk("UICorner", notif, { CornerRadius = UDim.new(0, 5) })
	mk("UIStroke", notif, { Color = Theme.Border, Thickness = 1, Transparency = 0.3 })

	local accentBar = mk("Frame", notif, {
		Name = "Bar",
		BackgroundColor3 = barColor,
		Size = UDim2.new(0, 3, 1, 0),
		BorderSizePixel = 0,
	})
	mk("UICorner", accentBar, { CornerRadius = UDim.new(0, 2) })

	local notifText = mk("TextLabel", notif, {
		Name = "Text",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -16, 1, 0),
		FontFace = FONT,
		TextSize = 14,
		TextColor3 = Theme.Text,
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextTransparency = 1,
	}) :: TextLabel

	local textSz = textSize(text, 14, FONT, Vector2.new(270, math.huge))
	local targetH = math.max(32, textSz.Y + 14)

	tween(notif, TWEEN_MED, { Size = UDim2.new(1, 0, 0, targetH) })
	tween(notifText, TWEEN_MED, { TextTransparency = 0 })

	task.delay(duration, function()
		tween(notifText, TWEEN_FAST, { TextTransparency = 1 })
		tween(notif, TWEEN_MED, { Size = UDim2.new(1, 0, 0, 0) })
		task.wait(0.25)
		notif:Destroy()
	end)
end

-- watermark
local watermarkFrame: Frame
local watermarkText: TextLabel
do
	watermarkFrame = mk("Frame", screenGui, {
		Name = "Watermark",
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.BgWindow,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 100,
	}) :: Frame
	mk("UICorner", watermarkFrame, { CornerRadius = UDim.new(0, 4) })
	mk("UIStroke", watermarkFrame, { Color = Theme.Border, Thickness = 1, Transparency = 0.3 })
	mk("UIPadding", watermarkFrame, {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	})

	local wmBar = mk("Frame", watermarkFrame, {
		Name = "Bar",
		BackgroundColor3 = Theme.Accent,
		Size = UDim2.new(1, 28, 0, 2),
		Position = UDim2.new(0, -14, 1, -1),
		BorderSizePixel = 0,
	})
	mk("UICorner", wmBar, { CornerRadius = UDim.new(0, 1) })

	watermarkText = mk("TextLabel", watermarkFrame, {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = FONT_BOLD,
		TextSize = 13,
		TextColor3 = Theme.Text,
		Text = "NeonLib",
	}) :: TextLabel
	Library.Watermark = watermarkFrame
end

function Library:SetWatermark(text: string)
	watermarkText.Text = text
end

function Library:SetWatermarkVisibility(visible: boolean)
	Library.WatermarkVisible = visible
	watermarkFrame.Visible = visible
end

function Library:SetToggleKey(key: Enum.KeyCode)
	Library.ToggleKey = key
end

function Library:Toggle(state: boolean?)
	if state ~= nil then
		Library.Toggled = state
	else
		Library.Toggled = not Library.Toggled
	end
end

function Library:Unload()
	Library.Unloaded = true
	screenGui:Destroy()
end

-- ══════════════════════════════════════════════════════
--  WINDOW
-- ══════════════════════════════════════════════════════

function Library:CreateWindow(config: {[string]: any})
	local title = config.Title or "NeonLib"
	local size = config.Size or UDim2.fromOffset(580, 440)
	local center = config.Center ~= false
	local autoShow = config.AutoShow ~= false

	local Window = { Tabs = {} }

	local mainFrame = mk("Frame", screenGui, {
		Name = "Window",
		BackgroundColor3 = Theme.BgMain,
		Size = size,
		Position = center and UDim2.new(0.5, -290, 0.5, -220) or (config.Position or UDim2.fromOffset(100, 100)),
		BorderSizePixel = 0,
		Visible = autoShow,
		ClipsDescendants = true,
	}) :: Frame
	mk("UICorner", mainFrame, { CornerRadius = UDim.new(0, 6) })

	local shadow = mk("ImageLabel", mainFrame, {
		Name = "Shadow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(-20, -20),
		Size = UDim2.new(1, 40, 1, 40),
		Image = "rbxassetid://6015897843",
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.5,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		ZIndex = -1,
	})

	local outerStroke = mk("UIStroke", mainFrame, {
		Color = Theme.Border,
		Thickness = 1,
		Transparency = 0.2,
	})

	-- title bar
	local titleBar = mk("Frame", mainFrame, {
		Name = "TitleBar",
		BackgroundColor3 = Theme.BgWindow,
		Size = UDim2.new(1, 0, 0, 36),
		BorderSizePixel = 0,
	}) :: Frame
	mk("UICorner", titleBar, { CornerRadius = UDim.new(0, 6) })

	local titleBarFix = mk("Frame", titleBar, {
		Name = "Fix",
		BackgroundColor3 = Theme.BgWindow,
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.new(0, 0, 1, -12),
		BorderSizePixel = 0,
	})

	enableDrag(titleBar)

	local accentLine = mk("Frame", titleBar, {
		Name = "Accent",
		BackgroundColor3 = Theme.Accent,
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.new(0, 0, 1, -2),
		BorderSizePixel = 0,
		ZIndex = 2,
	})

	local titleLabel = mk("TextLabel", titleBar, {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -14, 1, 0),
		FontFace = FONT_BOLD,
		TextSize = 15,
		TextColor3 = Theme.Text,
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- sidebar
	local sidebar = mk("Frame", mainFrame, {
		Name = "Sidebar",
		BackgroundColor3 = Theme.BgWindow,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(0, 150, 1, -36),
		BorderSizePixel = 0,
	}) :: Frame

	local sidebarFix = mk("Frame", sidebar, {
		BackgroundColor3 = Theme.BgWindow,
		Size = UDim2.new(0, 6, 1, 0),
		Position = UDim2.new(1, -6, 0, 0),
		BorderSizePixel = 0,
	})

	mk("UICorner", sidebar, { CornerRadius = UDim.new(0, 6) })

	local sidebarDivider = mk("Frame", sidebar, {
		Name = "Divider",
		BackgroundColor3 = Theme.Border,
		Size = UDim2.new(0, 1, 1, -8),
		Position = UDim2.new(1, 0, 0, 4),
		BorderSizePixel = 0,
		BackgroundTransparency = 0.4,
	})

	local tabButtonContainer = mk("ScrollingFrame", sidebar, {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -4, 1, -8),
		Position = UDim2.fromOffset(2, 4),
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
	}) :: ScrollingFrame
	mk("UIListLayout", tabButtonContainer, {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
	})
	mk("UIPadding", tabButtonContainer, {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	})

	-- content area
	local contentArea = mk("Frame", mainFrame, {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(152, 38),
		Size = UDim2.new(1, -154, 1, -40),
		BorderSizePixel = 0,
	})

	local currentTab = nil

	local function switchTab(tabObj)
		if currentTab == tabObj then return end

		for _, tab in Window.Tabs do
			tab.Button.BackgroundTransparency = 1
			tween(tab.Button, TWEEN_FAST, { BackgroundTransparency = 1 })
			tween(tab.ButtonLabel, TWEEN_FAST, { TextColor3 = Theme.TextDim })
			if tab.Indicator then
				tween(tab.Indicator, TWEEN_FAST, { BackgroundTransparency = 1 })
			end
			tab.Page.Visible = false
		end

		tabObj.Button.BackgroundTransparency = 0.92
		tween(tabObj.Button, TWEEN_FAST, { BackgroundTransparency = 0.92 })
		tween(tabObj.ButtonLabel, TWEEN_FAST, { TextColor3 = Theme.Accent })
		if tabObj.Indicator then
			tween(tabObj.Indicator, TWEEN_FAST, { BackgroundTransparency = 0 })
		end
		tabObj.Page.Visible = true
		currentTab = tabObj
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Library.ToggleKey then
			Library.Toggled = not Library.Toggled
			mainFrame.Visible = Library.Toggled
		end
	end)

	-- ══════════════════════════════════════════════════════
	--  TABS
	-- ══════════════════════════════════════════════════════

	function Window:AddTab(tabTitle: string)
		tabTitle = tabTitle or "Tab"
		local Tab = {
			Groupboxes = {},
		}

		local tabButton = mk("TextButton", tabButtonContainer, {
			Name = tabTitle,
			BackgroundColor3 = Theme.Accent,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			AutoButtonColor = false,
			Text = "",
			BorderSizePixel = 0,
		}) :: TextButton
		mk("UICorner", tabButton, { CornerRadius = UDim.new(0, 4) })

		local tabIndicator = mk("Frame", tabButton, {
			Name = "Indicator",
			BackgroundColor3 = Theme.Accent,
			Size = UDim2.new(0, 3, 0, 18),
			Position = UDim2.new(0, 0, 0.5, -9),
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
		}) :: Frame
		mk("UICorner", tabIndicator, { CornerRadius = UDim.new(0, 2) })

		local tabLabel = mk("TextLabel", tabButton, {
			Name = "Label",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -12, 1, 0),
			FontFace = FONT,
			TextSize = 14,
			TextColor3 = Theme.TextDim,
			Text = tabTitle,
			TextXAlignment = Enum.TextXAlignment.Left,
		}) :: TextLabel

		local page = mk("ScrollingFrame", contentArea, {
			Name = tabTitle,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = Theme.Accent,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BorderSizePixel = 0,
			Visible = false,
			TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
			MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
			BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		}) :: ScrollingFrame

		local columnsFrame = mk("Frame", page, {
			Name = "Columns",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		})
		mk("UIListLayout", columnsFrame, {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		})
		mk("UIPadding", columnsFrame, {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
		})

		local leftCol = mk("Frame", columnsFrame, {
			Name = "Left",
			BackgroundTransparency = 1,
			Size = UDim2.new(0.5, -4, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
		})
		mk("UIListLayout", leftCol, {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		})

		local rightCol = mk("Frame", columnsFrame, {
			Name = "Right",
			BackgroundTransparency = 1,
			Size = UDim2.new(0.5, -4, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
		})
		mk("UIListLayout", rightCol, {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		})

		Tab.Button = tabButton
		Tab.ButtonLabel = tabLabel
		Tab.Indicator = tabIndicator
		Tab.Page = page

		tabButton.MouseButton1Click:Connect(function()
			switchTab(Tab)
		end)

		if #Window.Tabs == 0 then
			task.defer(function()
				switchTab(Tab)
			end)
		end

		table.insert(Window.Tabs, Tab)

		-- ══════════════════════════════════════════════════════
		--  GROUPBOX
		-- ══════════════════════════════════════════════════════

		local function createGroupbox(groupTitle: string, parent: Frame)
			local Groupbox = {}

			local groupFrame = mk("Frame", parent, {
				Name = groupTitle,
				BackgroundColor3 = Theme.BgWindow,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BorderSizePixel = 0,
			}) :: Frame
			mk("UICorner", groupFrame, { CornerRadius = UDim.new(0, 5) })
			mk("UIStroke", groupFrame, { Color = Theme.Border, Thickness = 1, Transparency = 0.4 })

			local groupLabel = mk("TextLabel", groupFrame, {
				Name = "Title",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 28),
				FontFace = FONT_BOLD,
				TextSize = 13,
				TextColor3 = Theme.TextDim,
				Text = "  " .. groupTitle,
				TextXAlignment = Enum.TextXAlignment.Left,
			})

			local groupDivider = mk("Frame", groupFrame, {
				Name = "Divider",
				BackgroundColor3 = Theme.Border,
				Size = UDim2.new(1, -12, 0, 1),
				Position = UDim2.new(0, 6, 0, 28),
				BorderSizePixel = 0,
				BackgroundTransparency = 0.5,
			})

			local elemContainer = mk("Frame", groupFrame, {
				Name = "Elements",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 32),
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			})
			mk("UIListLayout", elemContainer, {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			})
			mk("UIPadding", elemContainer, {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 2),
				PaddingBottom = UDim.new(0, 8),
			})

			-- ════════════════════════════════
			--  LABEL
			-- ════════════════════════════════

			function Groupbox:AddLabel(text: string)
				local Label = {}

				local label = mk("TextLabel", elemContainer, {
					Name = "Label",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 20),
					FontFace = FONT,
					TextSize = 14,
					TextColor3 = Theme.Text,
					Text = text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
					AutomaticSize = Enum.AutomaticSize.Y,
				}) :: TextLabel

				Label.Instance = label

				function Label:SetText(newText: string)
					label.Text = newText
				end

				function Label:AddColorPicker(flag: string, info: {[string]: any})
					return Groupbox:AddColorPicker(flag, info, label)
				end

				return Label
			end

			-- ════════════════════════════════
			--  BUTTON
			-- ════════════════════════════════

			function Groupbox:AddButton(info: {[string]: any})
				local text = info.Text or "Button"
				local callback = info.Callback or function() end
				local tooltip = info.Tooltip

				local Button = {}

				local btn = mk("TextButton", elemContainer, {
					Name = "Btn_" .. text,
					BackgroundColor3 = Theme.BgElement,
					Size = UDim2.new(1, 0, 0, 28),
					AutoButtonColor = false,
					Text = "",
					BorderSizePixel = 0,
				}) :: TextButton
				mk("UICorner", btn, { CornerRadius = UDim.new(0, 4) })
				mk("UIStroke", btn, { Color = Theme.Border, Thickness = 1, Transparency = 0.5 })

				local btnLabel = mk("TextLabel", btn, {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					FontFace = FONT,
					TextSize = 14,
					TextColor3 = Theme.Text,
					Text = text,
				})

				btn.MouseEnter:Connect(function()
					tween(btn, TWEEN_FAST, { BackgroundColor3 = Theme.BgElementHover })
					if tooltip then showTooltip(tooltip) end
				end)
				btn.MouseLeave:Connect(function()
					tween(btn, TWEEN_FAST, { BackgroundColor3 = Theme.BgElement })
					hideTooltip()
				end)
				btn.MouseButton1Click:Connect(function()
					tween(btn, TweenInfo.new(0.06), { BackgroundColor3 = Theme.Accent })
					task.wait(0.08)
					tween(btn, TWEEN_FAST, { BackgroundColor3 = Theme.BgElement })
					callback()
				end)

				Button.Instance = btn
				return Button
			end

			-- ════════════════════════════════
			--  DIVIDER
			-- ════════════════════════════════

			function Groupbox:AddDivider()
				mk("Frame", elemContainer, {
					Name = "Divider",
					BackgroundColor3 = Theme.Border,
					Size = UDim2.new(1, 0, 0, 1),
					BorderSizePixel = 0,
					BackgroundTransparency = 0.5,
				})
			end

			-- ════════════════════════════════
			--  TOGGLE
			-- ════════════════════════════════

			function Groupbox:AddToggle(flag: string, info: {[string]: any})
				local text = info.Text or "Toggle"
				local default = info.Default or false
				local callback = info.Callback
				local tooltip = info.Tooltip

				local Toggle = {
					Value = default,
					Type = "Toggle",
				}

				local toggleFrame = mk("Frame", elemContainer, {
					Name = "Toggle_" .. flag,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 22),
				}) :: Frame

				local checkboxOuter = mk("Frame", toggleFrame, {
					Name = "Checkbox",
					BackgroundColor3 = Theme.BgField,
					Size = UDim2.fromOffset(18, 18),
					Position = UDim2.fromOffset(0, 2),
					BorderSizePixel = 0,
				}) :: Frame
				mk("UICorner", checkboxOuter, { CornerRadius = UDim.new(0, 4) })
				mk("UIStroke", checkboxOuter, { Color = Theme.Border, Thickness = 1 })

				local checkMark = mk("Frame", checkboxOuter, {
					Name = "Check",
					BackgroundColor3 = Theme.Accent,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = default and UDim2.fromOffset(10, 10) or UDim2.fromOffset(0, 0),
					BorderSizePixel = 0,
					BackgroundTransparency = default and 0 or 1,
				}) :: Frame
				mk("UICorner", checkMark, { CornerRadius = UDim.new(0, 3) })

				local toggleLabel = mk("TextLabel", toggleFrame, {
					Name = "Label",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(26, 0),
					Size = UDim2.new(1, -60, 0, 22),
					FontFace = FONT,
					TextSize = 14,
					TextColor3 = Theme.Text,
					Text = text,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				local clickBtn = mk("TextButton", toggleFrame, {
					Name = "Click",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Text = "",
					ZIndex = 3,
				})

				local function updateVisual()
					local sz = Toggle.Value and UDim2.fromOffset(10, 10) or UDim2.fromOffset(0, 0)
					local t = Toggle.Value and 0 or 1
					local strokeColor = Toggle.Value and Theme.Accent or Theme.Border
					tween(checkMark, TWEEN_FAST, { Size = sz, BackgroundTransparency = t })
					tween(checkboxOuter:FindFirstChildOfClass("UIStroke") :: UIStroke, TWEEN_FAST, { Color = strokeColor })
				end

				local function set(val: boolean, noCallback: boolean?)
					Toggle.Value = val
					updateVisual()
					if not noCallback then
						if callback then callback(val) end
						for _, fn in Toggle._changeCallbacks do fn(val) end
					end
				end

				Toggle._changeCallbacks = {}

				function Toggle:OnChanged(fn: (boolean) -> ())
					table.insert(Toggle._changeCallbacks, fn)
				end

				function Toggle:SetValue(val: boolean)
					set(val)
				end

				clickBtn.MouseButton1Click:Connect(function()
					set(not Toggle.Value)
				end)

				if tooltip then
					clickBtn.MouseEnter:Connect(function() showTooltip(tooltip) end)
					clickBtn.MouseLeave:Connect(function() hideTooltip() end)
				end

				-- keybind addon
				function Toggle:AddKeybind(kbFlag: string, kbInfo: {[string]: any})
					local kbDefault = kbInfo.Default or Enum.KeyCode.Unknown
					local kbMode = kbInfo.Mode or "Toggle"
					local kbChangedCb = kbInfo.ChangedCallback

					local Keybind = {
						Value = kbDefault,
						Mode = kbMode,
						Type = "Keybind",
						_changeCallbacks = {},
					}

					local kbBtn = mk("TextButton", toggleFrame, {
						Name = "KB",
						BackgroundColor3 = Theme.BgField,
						Size = UDim2.fromOffset(50, 18),
						Position = UDim2.new(1, -52, 0, 2),
						AutoButtonColor = false,
						Text = "",
						BorderSizePixel = 0,
						ZIndex = 4,
					}) :: TextButton
					mk("UICorner", kbBtn, { CornerRadius = UDim.new(0, 3) })
					mk("UIStroke", kbBtn, { Color = Theme.Border, Thickness = 1 })

					local kbLabel = mk("TextLabel", kbBtn, {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						FontFace = FONT_MONO,
						TextSize = 11,
						TextColor3 = Theme.TextDim,
						Text = kbDefault == Enum.KeyCode.Unknown and "..." or kbDefault.Name,
					})

					local listening = false

					kbBtn.MouseButton1Click:Connect(function()
						listening = true
						kbLabel.Text = "..."
						kbLabel.TextColor3 = Theme.Accent
					end)

					UserInputService.InputBegan:Connect(function(input, processed)
						if listening then
							listening = false
							if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Escape then
								Keybind.Value = Enum.KeyCode.Unknown
								kbLabel.Text = "..."
							else
								Keybind.Value = input.KeyCode
								kbLabel.Text = input.KeyCode.Name
							end
							kbLabel.TextColor3 = Theme.TextDim
							if kbChangedCb then kbChangedCb(Keybind.Value) end
							for _, fn in Keybind._changeCallbacks do fn(Keybind.Value) end
							Options[kbFlag] = Keybind
							return
						end

						if processed then return end
						if input.KeyCode == Keybind.Value and Keybind.Value ~= Enum.KeyCode.Unknown then
							if Keybind.Mode == "Toggle" then
								set(not Toggle.Value)
							elseif Keybind.Mode == "Hold" then
								set(true)
							end
						end
					end)

					if kbMode == "Hold" then
						UserInputService.InputEnded:Connect(function(input)
							if input.KeyCode == Keybind.Value and Keybind.Value ~= Enum.KeyCode.Unknown then
								if Keybind.Mode == "Hold" then
									set(false)
								end
							end
						end)
					end

					function Keybind:OnChanged(fn)
						table.insert(Keybind._changeCallbacks, fn)
					end

					function Keybind:SetValue(key: Enum.KeyCode)
						Keybind.Value = key
						kbLabel.Text = key == Enum.KeyCode.Unknown and "..." or key.Name
					end

					Options[kbFlag] = Keybind
					return Keybind
				end

				-- colorpicker addon for toggle
				function Toggle:AddColorPicker(cpFlag: string, cpInfo: {[string]: any})
					return Groupbox:AddColorPicker(cpFlag, cpInfo, toggleFrame)
				end

				if default then
					task.defer(function()
						if callback then callback(default) end
					end)
				end

				Toggles[flag] = Toggle
				return Toggle
			end

			-- ════════════════════════════════
			--  SLIDER
			-- ════════════════════════════════

			function Groupbox:AddSlider(flag: string, info: {[string]: any})
				local text = info.Text or "Slider"
				local default = info.Default or 0
				local min = info.Min or 0
				local max = info.Max or 100
				local rounding = info.Rounding or 0
				local suffix = info.Suffix or ""
				local compact = info.Compact or false
				local callback = info.Callback
				local tooltip = info.Tooltip

				local Slider = {
					Value = default,
					Min = min,
					Max = max,
					Type = "Slider",
					_changeCallbacks = {},
				}

				local sliderFrame = mk("Frame", elemContainer, {
					Name = "Slider_" .. flag,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, compact and 22 or 38),
				})

				if not compact then
					local sliderLabel = mk("TextLabel", sliderFrame, {
						Name = "Label",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, -60, 0, 18),
						FontFace = FONT,
						TextSize = 14,
						TextColor3 = Theme.Text,
						Text = text,
						TextXAlignment = Enum.TextXAlignment.Left,
					})

					if tooltip then
						sliderLabel.MouseEnter:Connect(function() showTooltip(tooltip) end)
						sliderLabel.MouseLeave:Connect(function() hideTooltip() end)
					end
				end

				local valueLabel = mk("TextLabel", sliderFrame, {
					Name = "Value",
					BackgroundTransparency = 1,
					Size = UDim2.new(0, 56, 0, 18),
					Position = UDim2.new(1, -56, 0, 0),
					FontFace = FONT_MONO,
					TextSize = 12,
					TextColor3 = Theme.TextDim,
					Text = tostring(default) .. suffix,
					TextXAlignment = Enum.TextXAlignment.Right,
				})

				local sliderBg = mk("Frame", sliderFrame, {
					Name = "Track",
					BackgroundColor3 = Theme.BgField,
					Size = UDim2.new(1, 0, 0, 14),
					Position = compact and UDim2.fromOffset(0, 4) or UDim2.fromOffset(0, 22),
					BorderSizePixel = 0,
				}) :: Frame
				mk("UICorner", sliderBg, { CornerRadius = UDim.new(0, 4) })
				mk("UIStroke", sliderBg, { Color = Theme.Border, Thickness = 1, Transparency = 0.5 })

				local sliderFill = mk("Frame", sliderBg, {
					Name = "Fill",
					BackgroundColor3 = Theme.Accent,
					Size = UDim2.fromScale(math.clamp((default - min) / (max - min), 0, 1), 1),
					BorderSizePixel = 0,
					BackgroundTransparency = 0.15,
				}) :: Frame
				mk("UICorner", sliderFill, { CornerRadius = UDim.new(0, 4) })

				local sliderBtn = mk("TextButton", sliderBg, {
					Name = "Input",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Text = "",
					ZIndex = 3,
				})

				local function roundVal(v)
					if rounding == 0 then return math.floor(v + 0.5) end
					local mult = 10 ^ rounding
					return math.floor(v * mult + 0.5) / mult
				end

				local function updateSlider(val, noCallback)
					val = roundVal(math.clamp(val, min, max))
					Slider.Value = val
					valueLabel.Text = tostring(val) .. suffix
					local pct = (val - min) / (max - min)
					tween(sliderFill, TweenInfo.new(0.04), { Size = UDim2.fromScale(math.clamp(pct, 0, 1), 1) })
					if not noCallback then
						if callback then callback(val) end
						for _, fn in Slider._changeCallbacks do fn(val) end
					end
				end

				local draggingSlider = false
				sliderBtn.MouseButton1Down:Connect(function()
					draggingSlider = true
				end)

				UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						draggingSlider = false
					end
				end)

				RunService.RenderStepped:Connect(function()
					if draggingSlider then
						local mouseX = UserInputService:GetMouseLocation().X
						local relX = mouseX - sliderBg.AbsolutePosition.X
						local pct = math.clamp(relX / sliderBg.AbsoluteSize.X, 0, 1)
						local val = min + (max - min) * pct
						updateSlider(val)
					end
				end)

				function Slider:SetValue(val: number)
					updateSlider(val)
				end

				function Slider:OnChanged(fn)
					table.insert(Slider._changeCallbacks, fn)
				end

				updateSlider(default, true)
				Options[flag] = Slider
				return Slider
			end

			-- ════════════════════════════════
			--  TEXTBOX / INPUT
			-- ════════════════════════════════

			function Groupbox:AddInput(flag: string, info: {[string]: any})
				local text = info.Text or "Input"
				local default = info.Default or ""
				local placeholder = info.Placeholder or ""
				local numeric = info.Numeric or false
				local callback = info.Callback
				local tooltip = info.Tooltip

				local Input = {
					Value = default,
					Type = "Input",
					_changeCallbacks = {},
				}

				local inputFrame = mk("Frame", elemContainer, {
					Name = "Input_" .. flag,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 42),
				})

				local inputLabel = mk("TextLabel", inputFrame, {
					Name = "Label",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 18),
					FontFace = FONT,
					TextSize = 14,
					TextColor3 = Theme.Text,
					Text = text,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				if tooltip then
					inputLabel.MouseEnter:Connect(function() showTooltip(tooltip) end)
					inputLabel.MouseLeave:Connect(function() hideTooltip() end)
				end

				local inputBox = mk("Frame", inputFrame, {
					Name = "Box",
					BackgroundColor3 = Theme.BgField,
					Size = UDim2.new(1, 0, 0, 22),
					Position = UDim2.fromOffset(0, 20),
					BorderSizePixel = 0,
				})
				mk("UICorner", inputBox, { CornerRadius = UDim.new(0, 4) })
				mk("UIStroke", inputBox, { Color = Theme.Border, Thickness = 1 })

				local textBox = mk("TextBox", inputBox, {
					Name = "Field",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -10, 1, 0),
					Position = UDim2.fromOffset(5, 0),
					FontFace = FONT,
					TextSize = 13,
					TextColor3 = Theme.Text,
					PlaceholderColor3 = Theme.TextDark,
					PlaceholderText = placeholder,
					Text = default,
					TextXAlignment = Enum.TextXAlignment.Left,
					ClearTextOnFocus = false,
				}) :: TextBox

				textBox.FocusLost:Connect(function()
					local val = textBox.Text
					if numeric then
						val = tostring(tonumber(val) or 0)
						textBox.Text = val
					end
					Input.Value = val
					if callback then callback(val) end
					for _, fn in Input._changeCallbacks do fn(val) end
				end)

				function Input:SetValue(val: string)
					textBox.Text = val
					Input.Value = val
				end

				function Input:OnChanged(fn)
					table.insert(Input._changeCallbacks, fn)
				end

				Options[flag] = Input
				return Input
			end

			-- ════════════════════════════════
			--  DROPDOWN
			-- ════════════════════════════════

			function Groupbox:AddDropdown(flag: string, info: {[string]: any})
				local text = info.Text or "Dropdown"
				local values = info.Values or {}
				local default = info.Default
				local multi = info.Multi or false
				local allowNull = info.AllowNull or false
				local callback = info.Callback
				local tooltip = info.Tooltip

				local Dropdown = {
					Value = multi and {} or (default or (allowNull and nil or values[1])),
					Values = values,
					Type = "Dropdown",
					Multi = multi,
					_changeCallbacks = {},
				}

				if multi and default then
					if type(default) == "table" then
						Dropdown.Value = default
					else
						Dropdown.Value = { [default] = true }
					end
				end

				local dropFrame = mk("Frame", elemContainer, {
					Name = "Drop_" .. flag,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 42),
					ClipsDescendants = false,
					ZIndex = 5,
				})

				local dropLabel = mk("TextLabel", dropFrame, {
					Name = "Label",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 18),
					FontFace = FONT,
					TextSize = 14,
					TextColor3 = Theme.Text,
					Text = text,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				if tooltip then
					dropLabel.MouseEnter:Connect(function() showTooltip(tooltip) end)
					dropLabel.MouseLeave:Connect(function() hideTooltip() end)
				end

				local dropBtn = mk("TextButton", dropFrame, {
					Name = "Selector",
					BackgroundColor3 = Theme.BgField,
					Size = UDim2.new(1, 0, 0, 22),
					Position = UDim2.fromOffset(0, 20),
					AutoButtonColor = false,
					Text = "",
					BorderSizePixel = 0,
					ZIndex = 5,
				}) :: TextButton
				mk("UICorner", dropBtn, { CornerRadius = UDim.new(0, 4) })
				mk("UIStroke", dropBtn, { Color = Theme.Border, Thickness = 1 })

				local function getDisplayText(): string
					if multi then
						local selected = {}
						for _, v in values do
							if Dropdown.Value[v] then
								table.insert(selected, v)
							end
						end
						if #selected == 0 then return "..." end
						return table.concat(selected, ", ")
					else
						return Dropdown.Value and tostring(Dropdown.Value) or "..."
					end
				end

				local dropText = mk("TextLabel", dropBtn, {
					Name = "Text",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -24, 1, 0),
					Position = UDim2.fromOffset(6, 0),
					FontFace = FONT,
					TextSize = 13,
					TextColor3 = Theme.TextDim,
					Text = getDisplayText(),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 5,
				})

				local arrow = mk("TextLabel", dropBtn, {
					Name = "Arrow",
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(20, 22),
					Position = UDim2.new(1, -22, 0, 0),
					FontFace = FONT,
					TextSize = 12,
					TextColor3 = Theme.TextDark,
					Text = "▼",
					ZIndex = 5,
				})

				local listFrame = mk("Frame", dropBtn, {
					Name = "List",
					BackgroundColor3 = Theme.BgField,
					Size = UDim2.new(1, 0, 0, 0),
					Position = UDim2.new(0, 0, 1, 2),
					BorderSizePixel = 0,
					ClipsDescendants = true,
					Visible = false,
					ZIndex = 50,
				}) :: Frame
				mk("UICorner", listFrame, { CornerRadius = UDim.new(0, 4) })
				mk("UIStroke", listFrame, { Color = Theme.Border, Thickness = 1 })

				local listScroll = mk("ScrollingFrame", listFrame, {
					Name = "Scroll",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					CanvasSize = UDim2.new(0, 0, 0, 0),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollBarThickness = 2,
					ScrollBarImageColor3 = Theme.Accent,
					BorderSizePixel = 0,
					ZIndex = 50,
					TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
					MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
					BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
				}) :: ScrollingFrame
				mk("UIListLayout", listScroll, { SortOrder = Enum.SortOrder.LayoutOrder })

				local isOpen = false
				local optionButtons = {}

				local function refreshOptions()
					for _, b in optionButtons do
						b:Destroy()
					end
					table.clear(optionButtons)

					for i, v in values do
						local isSelected = multi and Dropdown.Value[v] or (Dropdown.Value == v)

						local optBtn = mk("TextButton", listScroll, {
							Name = v,
							BackgroundColor3 = Theme.BgElement,
							BackgroundTransparency = isSelected and 0.5 or 1,
							Size = UDim2.new(1, 0, 0, 22),
							AutoButtonColor = false,
							Text = "",
							BorderSizePixel = 0,
							ZIndex = 51,
						}) :: TextButton

						local optLabel = mk("TextLabel", optBtn, {
							BackgroundTransparency = 1,
							Size = UDim2.new(1, -10, 1, 0),
							Position = UDim2.fromOffset(8, 0),
							FontFace = FONT,
							TextSize = 13,
							TextColor3 = isSelected and Theme.Accent or Theme.TextDim,
							Text = v,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex = 51,
						})

						optBtn.MouseEnter:Connect(function()
							tween(optBtn, TWEEN_FAST, { BackgroundTransparency = 0.6 })
						end)
						optBtn.MouseLeave:Connect(function()
							local sel = multi and Dropdown.Value[v] or (Dropdown.Value == v)
							tween(optBtn, TWEEN_FAST, { BackgroundTransparency = sel and 0.5 or 1 })
						end)

						optBtn.MouseButton1Click:Connect(function()
							if multi then
								Dropdown.Value[v] = not Dropdown.Value[v] or nil
								local sel = Dropdown.Value[v]
								tween(optLabel, TWEEN_FAST, { TextColor3 = sel and Theme.Accent or Theme.TextDim })
								tween(optBtn, TWEEN_FAST, { BackgroundTransparency = sel and 0.5 or 1 })
							else
								Dropdown.Value = v
								for _, ob in optionButtons do
									local ol = ob:FindFirstChildOfClass("TextLabel")
									if ol then
										tween(ol, TWEEN_FAST, { TextColor3 = Theme.TextDim })
									end
									tween(ob, TWEEN_FAST, { BackgroundTransparency = 1 })
								end
								tween(optLabel, TWEEN_FAST, { TextColor3 = Theme.Accent })
								tween(optBtn, TWEEN_FAST, { BackgroundTransparency = 0.5 })

								isOpen = false
								tween(listFrame, TWEEN_FAST, { Size = UDim2.new(1, 0, 0, 0) })
								task.wait(0.1)
								listFrame.Visible = false
								arrow.Text = "▼"
							end

							dropText.Text = getDisplayText()
							if callback then callback(Dropdown.Value) end
							for _, fn in Dropdown._changeCallbacks do fn(Dropdown.Value) end
						end)

						table.insert(optionButtons, optBtn)
					end
				end

				refreshOptions()

				dropBtn.MouseButton1Click:Connect(function()
					isOpen = not isOpen
					if isOpen then
						listFrame.Visible = true
						local h = math.min(#values * 22, 150)
						tween(listFrame, TWEEN_FAST, { Size = UDim2.new(1, 0, 0, h) })
						arrow.Text = "▲"
					else
						tween(listFrame, TWEEN_FAST, { Size = UDim2.new(1, 0, 0, 0) })
						task.wait(0.1)
						listFrame.Visible = false
						arrow.Text = "▼"
					end
				end)

				function Dropdown:SetValue(val)
					Dropdown.Value = val
					dropText.Text = getDisplayText()
					refreshOptions()
				end

				function Dropdown:SetValues(newValues)
					Dropdown.Values = newValues
					values = newValues
					refreshOptions()
				end

				function Dropdown:OnChanged(fn)
					table.insert(Dropdown._changeCallbacks, fn)
				end

				if not multi and default then
					task.defer(function()
						if callback then callback(default) end
					end)
				end

				Options[flag] = Dropdown
				return Dropdown
			end

			-- ════════════════════════════════
			--  COLORPICKER
			-- ════════════════════════════════

			function Groupbox:AddColorPicker(flag: string, info: {[string]: any}, attachTo: Instance?)
				local default = info.Default or Color3.fromRGB(255, 255, 255)
				local title = info.Title or "Color"
				local transparency = info.Transparency
				local callback = info.Callback

				local ColorPicker = {
					Value = default,
					Transparency = transparency or 0,
					Type = "ColorPicker",
					_changeCallbacks = {},
				}

				local parent = attachTo or elemContainer
				local isInline = attachTo ~= nil

				local previewSize = 16
				local previewBtn: TextButton

				if isInline then
					previewBtn = mk("TextButton", parent, {
						Name = "CP_" .. flag,
						BackgroundColor3 = default,
						Size = UDim2.fromOffset(previewSize, previewSize),
						Position = UDim2.new(1, -(previewSize + 4), 0, 3),
						AnchorPoint = Vector2.new(0, 0),
						AutoButtonColor = false,
						Text = "",
						BorderSizePixel = 0,
						ZIndex = 4,
					}) :: TextButton
				else
					local cpRow = mk("Frame", elemContainer, {
						Name = "CP_" .. flag,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 22),
					})
					mk("TextLabel", cpRow, {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, -24, 1, 0),
						FontFace = FONT,
						TextSize = 14,
						TextColor3 = Theme.Text,
						Text = title,
						TextXAlignment = Enum.TextXAlignment.Left,
					})
					previewBtn = mk("TextButton", cpRow, {
						Name = "Preview",
						BackgroundColor3 = default,
						Size = UDim2.fromOffset(previewSize, previewSize),
						Position = UDim2.new(1, -(previewSize + 2), 0, 3),
						AutoButtonColor = false,
						Text = "",
						BorderSizePixel = 0,
						ZIndex = 4,
					}) :: TextButton
				end

				mk("UICorner", previewBtn, { CornerRadius = UDim.new(0, 4) })
				mk("UIStroke", previewBtn, { Color = Theme.Border, Thickness = 1 })

				local pickerOpen = false
				local pickerGui: Frame? = nil

				local h, s, v = default:ToHSV()

				local function updateColor()
					local col = Color3.fromHSV(h, s, v)
					ColorPicker.Value = col
					previewBtn.BackgroundColor3 = col
					if callback then callback(col) end
					for _, fn in ColorPicker._changeCallbacks do fn(col) end
				end

				local function openPicker()
					if pickerGui then return end
					pickerOpen = true

					local absPos = previewBtn.AbsolutePosition
					local pickerW, pickerH = 200, transparency and 190 or 170

					pickerGui = mk("Frame", screenGui, {
						Name = "Picker_" .. flag,
						BackgroundColor3 = Theme.BgWindow,
						Size = UDim2.fromOffset(pickerW, pickerH),
						Position = UDim2.fromOffset(absPos.X - pickerW - 4, absPos.Y),
						BorderSizePixel = 0,
						ZIndex = 100,
					}) :: Frame
					mk("UICorner", pickerGui, { CornerRadius = UDim.new(0, 5) })
					mk("UIStroke", pickerGui, { Color = Theme.Border, Thickness = 1 })

					local pickerTitle = mk("TextLabel", pickerGui, {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 22),
						FontFace = FONT_BOLD,
						TextSize = 12,
						TextColor3 = Theme.TextDim,
						Text = title,
					})

					-- SV square
					local svFrame = mk("Frame", pickerGui, {
						Name = "SV",
						BackgroundColor3 = Color3.fromHSV(h, 1, 1),
						Size = UDim2.fromOffset(150, 100),
						Position = UDim2.fromOffset(8, 24),
						BorderSizePixel = 0,
						ZIndex = 101,
					}) :: Frame
					mk("UICorner", svFrame, { CornerRadius = UDim.new(0, 3) })

					local whiteGrad = mk("UIGradient", svFrame, {
						Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0),
							NumberSequenceKeypoint.new(1, 1),
						}),
					})

					local blackOverlay = mk("Frame", svFrame, {
						BackgroundColor3 = Color3.new(0, 0, 0),
						Size = UDim2.fromScale(1, 1),
						BorderSizePixel = 0,
						ZIndex = 102,
					})
					mk("UICorner", blackOverlay, { CornerRadius = UDim.new(0, 3) })
					mk("UIGradient", blackOverlay, {
						Rotation = 90,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(1, 0),
						}),
					})

					local svCursor = mk("Frame", svFrame, {
						Name = "Cursor",
						BackgroundColor3 = Color3.new(1, 1, 1),
						Size = UDim2.fromOffset(8, 8),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(s, 1 - v),
						BorderSizePixel = 0,
						ZIndex = 104,
					})
					mk("UICorner", svCursor, { CornerRadius = UDim.new(1, 0) })
					mk("UIStroke", svCursor, { Color = Color3.new(0, 0, 0), Thickness = 1 })

					local svInput = mk("TextButton", svFrame, {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						Text = "",
						ZIndex = 103,
					})

					-- hue bar
					local hueBar = mk("Frame", pickerGui, {
						Name = "Hue",
						BackgroundColor3 = Color3.new(1, 1, 1),
						Size = UDim2.fromOffset(18, 100),
						Position = UDim2.fromOffset(166, 24),
						BorderSizePixel = 0,
						ZIndex = 101,
					})
					mk("UICorner", hueBar, { CornerRadius = UDim.new(0, 3) })
					mk("UIGradient", hueBar, {
						Rotation = 90,
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
							ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
							ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
							ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
							ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
							ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
						}),
					})

					local hueCursor = mk("Frame", hueBar, {
						Name = "Cursor",
						BackgroundColor3 = Color3.new(1, 1, 1),
						Size = UDim2.new(1, 0, 0, 4),
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromScale(0, h),
						BorderSizePixel = 0,
						ZIndex = 104,
					})
					mk("UICorner", hueCursor, { CornerRadius = UDim.new(0, 2) })
					mk("UIStroke", hueCursor, { Color = Color3.new(0, 0, 0), Thickness = 1 })

					local hueInput = mk("TextButton", hueBar, {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						Text = "",
						ZIndex = 103,
					})

					-- hex input
					local hexRow = mk("Frame", pickerGui, {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, -16, 0, 20),
						Position = UDim2.fromOffset(8, 130),
						ZIndex = 101,
					})
					local hexLabel = mk("TextLabel", hexRow, {
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(24, 20),
						FontFace = FONT_MONO,
						TextSize = 12,
						TextColor3 = Theme.TextDim,
						Text = "#",
						ZIndex = 101,
					})
					local hexBox = mk("TextBox", hexRow, {
						BackgroundColor3 = Theme.BgField,
						Size = UDim2.new(1, -28, 0, 18),
						Position = UDim2.fromOffset(24, 1),
						FontFace = FONT_MONO,
						TextSize = 12,
						TextColor3 = Theme.Text,
						Text = default:ToHex(),
						BorderSizePixel = 0,
						ZIndex = 101,
						ClearTextOnFocus = false,
					}) :: TextBox
					mk("UICorner", hexBox, { CornerRadius = UDim.new(0, 3) })
					mk("UIStroke", hexBox, { Color = Theme.Border, Thickness = 1 })
					mk("UIPadding", hexBox, { PaddingLeft = UDim.new(0, 4) })

					hexBox.FocusLost:Connect(function()
						local ok, col = pcall(function()
							return Color3.fromHex(hexBox.Text)
						end)
						if ok then
							h, s, v = col:ToHSV()
							svFrame.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
							svCursor.Position = UDim2.fromScale(s, 1 - v)
							hueCursor.Position = UDim2.fromScale(0, h)
							updateColor()
						end
						hexBox.Text = ColorPicker.Value:ToHex()
					end)

					-- transparency bar
					if transparency then
						local alphaBar = mk("Frame", pickerGui, {
							Name = "Alpha",
							BackgroundColor3 = Color3.new(1, 1, 1),
							Size = UDim2.new(1, -16, 0, 12),
							Position = UDim2.fromOffset(8, 156),
							BorderSizePixel = 0,
							ZIndex = 101,
						})
						mk("UICorner", alphaBar, { CornerRadius = UDim.new(0, 3) })
						mk("UIGradient", alphaBar, {
							Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0, 0, 0)),
						})

						local alphaCursor = mk("Frame", alphaBar, {
							BackgroundColor3 = Color3.new(1, 1, 1),
							Size = UDim2.new(0, 4, 1, 0),
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.fromScale(ColorPicker.Transparency, 0),
							BorderSizePixel = 0,
							ZIndex = 104,
						})
						mk("UICorner", alphaCursor, { CornerRadius = UDim.new(0, 2) })
						mk("UIStroke", alphaCursor, { Color = Color3.new(0, 0, 0), Thickness = 1 })

						local alphaInput = mk("TextButton", alphaBar, {
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(1, 1),
							Text = "",
							ZIndex = 103,
						})

						local draggingAlpha = false
						alphaInput.MouseButton1Down:Connect(function() draggingAlpha = true end)
						UserInputService.InputEnded:Connect(function(inp)
							if inp.UserInputType == Enum.UserInputType.MouseButton1 then draggingAlpha = false end
						end)
						RunService.RenderStepped:Connect(function()
							if draggingAlpha then
								local mx = UserInputService:GetMouseLocation().X
								local pct = math.clamp((mx - alphaBar.AbsolutePosition.X) / alphaBar.AbsoluteSize.X, 0, 1)
								alphaCursor.Position = UDim2.fromScale(pct, 0)
								ColorPicker.Transparency = pct
								updateColor()
							end
						end)
					end

					-- SV drag
					local draggingSV = false
					svInput.MouseButton1Down:Connect(function() draggingSV = true end)
					UserInputService.InputEnded:Connect(function(inp)
						if inp.UserInputType == Enum.UserInputType.MouseButton1 then draggingSV = false end
					end)
					RunService.RenderStepped:Connect(function()
						if draggingSV then
							local pos = UserInputService:GetMouseLocation()
							local relX = math.clamp((pos.X - svFrame.AbsolutePosition.X) / svFrame.AbsoluteSize.X, 0, 1)
							local relY = math.clamp((pos.Y - svFrame.AbsolutePosition.Y) / svFrame.AbsoluteSize.Y, 0, 1)
							s = relX
							v = 1 - relY
							svCursor.Position = UDim2.fromScale(s, 1 - v)
							hexBox.Text = Color3.fromHSV(h, s, v):ToHex()
							updateColor()
						end
					end)

					-- Hue drag
					local draggingHue = false
					hueInput.MouseButton1Down:Connect(function() draggingHue = true end)
					UserInputService.InputEnded:Connect(function(inp)
						if inp.UserInputType == Enum.UserInputType.MouseButton1 then draggingHue = false end
					end)
					RunService.RenderStepped:Connect(function()
						if draggingHue then
							local my = UserInputService:GetMouseLocation().Y
							local pct = math.clamp((my - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 0.999)
							h = pct
							hueCursor.Position = UDim2.fromScale(0, h)
							svFrame.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
							hexBox.Text = Color3.fromHSV(h, s, v):ToHex()
							updateColor()
						end
					end)

					-- close on click outside
					task.spawn(function()
						while pickerOpen and pickerGui do
							task.wait(0.1)
							if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
								if not isMouseOver(pickerGui) and not isMouseOver(previewBtn) then
									pickerOpen = false
									if pickerGui then
										pickerGui:Destroy()
										pickerGui = nil
									end
									break
								end
							end
						end
					end)
				end

				local function closePicker()
					if pickerGui then
						pickerGui:Destroy()
						pickerGui = nil
					end
					pickerOpen = false
				end

				previewBtn.MouseButton1Click:Connect(function()
					if pickerOpen then
						closePicker()
					else
						openPicker()
					end
				end)

				function ColorPicker:SetValue(col: Color3)
					h, s, v = col:ToHSV()
					ColorPicker.Value = col
					previewBtn.BackgroundColor3 = col
				end

				function ColorPicker:OnChanged(fn)
					table.insert(ColorPicker._changeCallbacks, fn)
				end

				Options[flag] = ColorPicker
				return ColorPicker
			end

			-- ════════════════════════════════
			--  KEYBIND (standalone)
			-- ════════════════════════════════

			function Groupbox:AddKeybind(flag: string, info: {[string]: any})
				local text = info.Text or "Keybind"
				local default = info.Default or Enum.KeyCode.Unknown
				local callback = info.Callback
				local tooltip = info.Tooltip
				local mode = info.Mode or "Always"

				local Keybind = {
					Value = default,
					Mode = mode,
					Type = "Keybind",
					_changeCallbacks = {},
				}

				local kbFrame = mk("Frame", elemContainer, {
					Name = "KB_" .. flag,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 22),
				})

				local kbLabel = mk("TextLabel", kbFrame, {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -60, 1, 0),
					FontFace = FONT,
					TextSize = 14,
					TextColor3 = Theme.Text,
					Text = text,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				if tooltip then
					kbLabel.MouseEnter:Connect(function() showTooltip(tooltip) end)
					kbLabel.MouseLeave:Connect(function() hideTooltip() end)
				end

				local kbBtn = mk("TextButton", kbFrame, {
					BackgroundColor3 = Theme.BgField,
					Size = UDim2.fromOffset(54, 18),
					Position = UDim2.new(1, -56, 0, 2),
					AutoButtonColor = false,
					Text = "",
					BorderSizePixel = 0,
				}) :: TextButton
				mk("UICorner", kbBtn, { CornerRadius = UDim.new(0, 3) })
				mk("UIStroke", kbBtn, { Color = Theme.Border, Thickness = 1 })

				local kbBtnLabel = mk("TextLabel", kbBtn, {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					FontFace = FONT_MONO,
					TextSize = 11,
					TextColor3 = Theme.TextDim,
					Text = default == Enum.KeyCode.Unknown and "..." or default.Name,
				})

				local listening = false

				kbBtn.MouseButton1Click:Connect(function()
					listening = true
					kbBtnLabel.Text = "..."
					kbBtnLabel.TextColor3 = Theme.Accent
				end)

				UserInputService.InputBegan:Connect(function(input, processed)
					if listening then
						listening = false
						if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Escape then
							Keybind.Value = Enum.KeyCode.Unknown
							kbBtnLabel.Text = "..."
						else
							Keybind.Value = input.KeyCode
							kbBtnLabel.Text = input.KeyCode.Name
						end
						kbBtnLabel.TextColor3 = Theme.TextDim
						for _, fn in Keybind._changeCallbacks do fn(Keybind.Value) end
						return
					end

					if processed then return end
					if input.KeyCode == Keybind.Value and Keybind.Value ~= Enum.KeyCode.Unknown then
						if callback then callback(Keybind.Value) end
					end
				end)

				function Keybind:OnChanged(fn)
					table.insert(Keybind._changeCallbacks, fn)
				end

				function Keybind:SetValue(key: Enum.KeyCode)
					Keybind.Value = key
					kbBtnLabel.Text = key == Enum.KeyCode.Unknown and "..." or key.Name
				end

				Options[flag] = Keybind
				return Keybind
			end

			-- ════════════════════════════════
			--  DEPENDENCY BOX
			-- ════════════════════════════════

			function Groupbox:AddDependencyBox()
				local DepBox = {}
				local deps = {}

				local depFrame = mk("Frame", elemContainer, {
					Name = "DepBox",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Visible = false,
					ClipsDescendants = true,
				})
				mk("UIListLayout", depFrame, {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				})

				local origContainer = elemContainer
				elemContainer = depFrame

				-- mirror all groupbox methods
				for name, fn in Groupbox do
					if type(fn) == "function" and name ~= "AddDependencyBox" then
						DepBox[name] = function(_, ...)
							local savedContainer = elemContainer
							elemContainer = depFrame
							local result = fn(Groupbox, ...)
							elemContainer = savedContainer
							return result
						end
					end
				end

				function DepBox:AddDependencyBox()
					local savedContainer = elemContainer
					elemContainer = depFrame
					local result = Groupbox.AddDependencyBox(Groupbox)
					elemContainer = savedContainer
					return result
				end

				function DepBox:SetupDependencies(dependencies: {{any}})
					deps = dependencies

					local function check()
						local visible = true
						for _, dep in deps do
							local obj = dep[1]
							local expected = dep[2]

							if obj.Type == "Toggle" then
								if obj.Value ~= expected then
									visible = false
									break
								end
							elseif obj.Type == "Dropdown" then
								if obj.Multi then
									if not obj.Value[expected] then
										visible = false
										break
									end
								else
									if obj.Value ~= expected then
										visible = false
										break
									end
								end
							end
						end
						depFrame.Visible = visible
					end

					for _, dep in deps do
						local obj = dep[1]
						if obj._changeCallbacks then
							table.insert(obj._changeCallbacks, check)
						end
					end

					check()
				end

				elemContainer = origContainer
				return DepBox
			end

			Tab.Groupboxes[groupTitle] = Groupbox
			return Groupbox
		end

		function Tab:AddLeftGroupbox(groupTitle: string)
			return createGroupbox(groupTitle, leftCol)
		end

		function Tab:AddRightGroupbox(groupTitle: string)
			return createGroupbox(groupTitle, rightCol)
		end

		-- tabbox support
		function Tab:AddLeftTabbox(tabboxTitle: string)
			return Tab:_createTabbox(tabboxTitle, leftCol)
		end

		function Tab:AddRightTabbox(tabboxTitle: string)
			return Tab:_createTabbox(tabboxTitle, rightCol)
		end

		function Tab:_createTabbox(tabboxTitle: string, parent: Frame)
			local Tabbox = { InnerTabs = {} }

			local tbFrame = mk("Frame", parent, {
				Name = "Tabbox_" .. tabboxTitle,
				BackgroundColor3 = Theme.BgWindow,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BorderSizePixel = 0,
			})
			mk("UICorner", tbFrame, { CornerRadius = UDim.new(0, 5) })
			mk("UIStroke", tbFrame, { Color = Theme.Border, Thickness = 1, Transparency = 0.4 })

			local tbHeader = mk("Frame", tbFrame, {
				Name = "Header",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 26),
				ClipsDescendants = true,
			})
			mk("UIListLayout", tbHeader, {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
			})

			local tbContent = mk("Frame", tbFrame, {
				Name = "Content",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 28),
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			})

			local currentInnerTab = nil

			function Tabbox:AddTab(innerTitle: string)
				local innerTabBtn = mk("TextButton", tbHeader, {
					Name = innerTitle,
					BackgroundTransparency = 1,
					Size = UDim2.new(0, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					AutoButtonColor = false,
					Text = "",
					BorderSizePixel = 0,
				}) :: TextButton
				mk("UIPadding", innerTabBtn, {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
				})

				local innerLabel = mk("TextLabel", innerTabBtn, {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					AutomaticSize = Enum.AutomaticSize.X,
					FontFace = FONT,
					TextSize = 13,
					TextColor3 = Theme.TextDim,
					Text = innerTitle,
				})

				local innerPage = mk("Frame", tbContent, {
					Name = innerTitle,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Visible = false,
				})
				mk("UIListLayout", innerPage, {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				})
				mk("UIPadding", innerPage, {
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 8),
					PaddingTop = UDim.new(0, 2),
					PaddingBottom = UDim.new(0, 8),
				})

				local InnerTab = {}
				local origElemContainer = innerPage

				-- mirror groupbox methods to inner tab
				local fakeGroupbox = createGroupbox("_inner", innerPage)
				-- we actually want to redirect all methods to use innerPage as container
				-- let's build it manually

				for name, fn in pairs(fakeGroupbox) do
					if type(fn) == "function" then
						InnerTab[name] = fn
					end
				end

				-- remove the frame that createGroupbox made and use innerPage directly
				local firstChild = innerPage:FindFirstChild("_inner")
				if firstChild then
					for _, c in firstChild:FindFirstChild("Elements"):GetChildren() do
						c.Parent = innerPage
					end
					firstChild:Destroy()
				end

				InnerTab._btn = innerTabBtn
				InnerTab._label = innerLabel
				InnerTab._page = innerPage

				innerTabBtn.MouseButton1Click:Connect(function()
					for _, it in Tabbox.InnerTabs do
						it._page.Visible = false
						tween(it._label, TWEEN_FAST, { TextColor3 = Theme.TextDim })
					end
					innerPage.Visible = true
					tween(innerLabel, TWEEN_FAST, { TextColor3 = Theme.Accent })
					currentInnerTab = InnerTab
				end)

				if #Tabbox.InnerTabs == 0 then
					task.defer(function()
						innerPage.Visible = true
						innerLabel.TextColor3 = Theme.Accent
						currentInnerTab = InnerTab
					end)
				end

				table.insert(Tabbox.InnerTabs, InnerTab)
				return InnerTab
			end

			return Tabbox
		end

		return Tab
	end

	return Window
end

return Library
