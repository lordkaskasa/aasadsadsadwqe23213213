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

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local isStudio = RunService:IsStudio()
local guiParent = isStudio and player.PlayerGui or CoreGui

local library = {
	flags = {},
	colorPickers = {},
	connections = {},
	opened = true,
	mouseOverUI = false,
}

local theme = {
	bg = Color3.fromRGB(12, 13, 20),
	innerBorder = Color3.fromRGB(40, 40, 52),
	outerBorder = Color3.fromRGB(8, 8, 14),
	panel = Color3.fromRGB(20, 21, 30),
	section = Color3.fromRGB(23, 24, 34),
	sectionBorder = Color3.fromRGB(40, 40, 52),
	accent = Color3.fromRGB(55, 130, 255),
	text = Color3.fromRGB(205, 205, 215),
	textDim = Color3.fromRGB(155, 155, 168),
	toggleOff = Color3.fromRGB(77, 77, 90),
	sliderBg = Color3.fromRGB(71, 71, 85),
	dropBg = Color3.fromRGB(36, 36, 48),
	dropHover = Color3.fromRGB(46, 46, 58),
	line = Color3.fromRGB(45, 45, 58),
	scrollbar = Color3.fromRGB(65, 65, 78),
}

local font = Font.fromEnum(Enum.Font.RobotoMono)
local fontBold = Font.fromEnum(Enum.Font.RobotoMono)
fontBold.Bold = true

local function mk(class: string, parent: Instance?, props: { [string]: any }?): Instance
	local inst = Instance.new(class)
	if props then
		for k, v in props do
			if k ~= "Parent" then (inst :: any)[k] = v end
		end
	end
	if parent then inst.Parent = parent end
	return inst
end

local function tween(inst: Instance, props: { [string]: any }, duration: number?)
	TweenService:Create(inst, TweenInfo.new(duration or 0.15, Enum.EasingStyle.Quad), props):Play()
end

local function connect(signal: RBXScriptSignal, callback: (...any) -> ())
	local conn = signal:Connect(callback)
	library.connections[#library.connections + 1] = conn
	return conn
end

local function draggable(frame: Frame)
	local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
	connect(frame.InputBegan, function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end
	end)
	connect(frame.InputEnded, function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	connect(UserInputService.InputChanged, function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			dragInput = input
		end
	end)
	connect(dragInput or UserInputService.InputChanged, function(input: InputObject)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

function library:init(props: { [string]: any }?)
	props = props or {}
	local title = props.title or "UI Library"
	local size = props.size or Vector2.new(660, 560)
	local accentColor = props.accent or theme.accent
	theme.accent = accentColor
	
	for _, existing in guiParent:GetChildren() do
		if existing:IsA("ScreenGui") and existing.Name:find("^LibUI_") then
			existing:Destroy()
		end
	end
	
	local screenGui = mk("ScreenGui", guiParent, {
		Name = "LibUI_" .. HttpService:GenerateGUID(false),
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
	})
	
	local mainFrame = mk("Frame", screenGui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = theme.bg,
		BorderSizePixel = 0,
	})
	mk("UICorner", mainFrame, { CornerRadius = UDim.new(0, 4) })
	mk("UIStroke", mainFrame, { Color = theme.outerBorder, Thickness = 1 })
	
	local topBar = mk("Frame", mainFrame, {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = theme.panel,
		BorderSizePixel = 0,
	})
	mk("UICorner", topBar, { CornerRadius = UDim.new(0, 4) })
	draggable(topBar)
	
	local titleLabel = mk("TextLabel", topBar, {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = theme.text,
		TextSize = 14,
		FontFace = fontBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	
	local tabsHolder = mk("Frame", mainFrame, {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(0, 74, 1, -30),
		BackgroundColor3 = theme.panel,
		BorderSizePixel = 0,
	})
	mk("UIListLayout", tabsHolder, {
		Padding = UDim.new(0, 4),
		FillDirection = Enum.FillDirection.Vertical,
	})
	mk("UIPadding", tabsHolder, {
		PaddingTop = UDim.new(0, 9),
		PaddingBottom = UDim.new(0, 9),
	})
	
	local pagesHolder = mk("Frame", mainFrame, {
		Position = UDim2.fromOffset(74, 30),
		Size = UDim2.new(1, -74, 1, -30),
		BackgroundColor3 = theme.bg,
		BorderSizePixel = 0,
	})
	
	local window = {
		tabs = {},
		mainFrame = mainFrame,
		tabsHolder = tabsHolder,
		pagesHolder = pagesHolder,
	}
	
	connect(UserInputService.InputBegan, function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.RightShift then
			library.opened = not library.opened
			tween(mainFrame, { Size = library.opened and UDim2.fromOffset(size.X, size.Y) or UDim2.fromOffset(0, 0) }, 0.3)
		end
	end)
	
	function window:tab(props: { [string]: any }?)
		props = props or {}
		local name = props.name or "Tab"
		local icon = props.icon or ""
		
		local tabButton = mk("Frame", tabsHolder, {
			Size = UDim2.new(1, 0, 0, 72),
			BackgroundTransparency = 1,
		})
		
		local tabBorder = mk("Frame", tabButton, {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = theme.outerBorder,
			BorderSizePixel = 0,
			Visible = false,
		})
		mk("UICorner", tabBorder, { CornerRadius = UDim.new(0, 2) })
		
		local tabIcon = mk("ImageLabel", tabButton, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(50, 50),
			BackgroundTransparency = 1,
			Image = icon,
			ImageColor3 = Color3.fromRGB(100, 100, 115),
		})
		
		local tabBtn = mk("TextButton", tabButton, {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
		})
		
		local pageFrame = mk("Frame", pagesHolder, {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Visible = false,
		})
		
		local pageLeft = mk("Frame", pageFrame, {
			Position = UDim2.fromOffset(20, 20),
			Size = UDim2.new(0.5, -30, 1, -40),
			BackgroundTransparency = 1,
		})
		mk("UIListLayout", pageLeft, {
			Padding = UDim.new(0, 18),
			FillDirection = Enum.FillDirection.Vertical,
		})
		
		local pageRight = mk("Frame", pageFrame, {
			Position = UDim2.new(0.5, 10, 0, 20),
			Size = UDim2.new(0.5, -30, 1, -40),
			BackgroundTransparency = 1,
		})
		mk("UIListLayout", pageRight, {
			Padding = UDim.new(0, 18),
			FillDirection = Enum.FillDirection.Vertical,
		})
		
		local tab = {
			button = tabButton,
			page = pageFrame,
			left = pageLeft,
			right = pageRight,
			open = false,
		}
		
		function tab:show()
			for _, t in window.tabs do
				if t.open then
					t.page.Visible = false
					t.open = false
					tween(t.button:FindFirstChildOfClass("ImageLabel"), { ImageColor3 = Color3.fromRGB(100, 100, 115) })
					t.button:FindFirstChild("Frame", true).Visible = false
				end
			end
			tab.open = true
			tab.page.Visible = true
			tabBorder.Visible = true
			tween(tabIcon, { ImageColor3 = Color3.fromRGB(255, 255, 255) })
		end
		
		connect(tabBtn.MouseButton1Click, function()
			if not tab.open then tab:show() end
		end)
		
		connect(tabBtn.MouseEnter, function()
			if not tab.open then
				tween(tabIcon, { ImageColor3 = Color3.fromRGB(172, 172, 185) })
			end
		end)
		
		connect(tabBtn.MouseLeave, function()
			if not tab.open then
				tween(tabIcon, { ImageColor3 = Color3.fromRGB(100, 100, 115) })
			end
		end)
		
		if #window.tabs == 0 then tab:show() end
		window.tabs[#window.tabs + 1] = tab
		
		function tab:section(props: { [string]: any }?)
			props = props or {}
			local sectionName = props.name or "Section"
			local sectionSize = props.size or 150
			local side = props.side or "left"
			local parent = side == "left" and pageLeft or pageRight
			
			local holder = mk("Frame", parent, {
				Size = UDim2.new(1, 0, 0, sectionSize),
				BackgroundColor3 = theme.sectionBorder,
				BorderSizePixel = 0,
			})
			mk("UICorner", holder, { CornerRadius = UDim.new(0, 3) })
			mk("UIStroke", holder, {
				Color = theme.outerBorder,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			})
			
			local holderFrame = mk("Frame", holder, {
				Position = UDim2.fromOffset(1, 1),
				Size = UDim2.new(1, -2, 1, -2),
				BackgroundColor3 = theme.section,
				BorderSizePixel = 0,
			})
			mk("UICorner", holderFrame, { CornerRadius = UDim.new(0, 3) })
			
			local titleLabel = mk("TextLabel", holder, {
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -24, 0, 15),
				BackgroundTransparency = 1,
				Text = "<b>" .. sectionName .. "</b>",
				TextColor3 = theme.text,
				TextSize = 11,
				FontFace = fontBold,
				RichText = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			
			local contentScroll = mk("ScrollingFrame", holderFrame, {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 5,
				ScrollBarImageColor3 = theme.scrollbar,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(0, 0, 0, 0),
			})
			mk("UIListLayout", contentScroll, {
				Padding = UDim.new(0, 0),
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			})
			mk("UIPadding", contentScroll, {
				PaddingTop = UDim.new(0, 15),
				PaddingBottom = UDim.new(0, 15),
			})
			
			local section = {
				holder = contentScroll,
			}
			
			function section:toggle(props: { [string]: any }?)
				props = props or {}
				local toggleName = props.name or "Toggle"
				local flag = props.flag
				local default = props.default or false
				local callback = props.callback or function() end
				
				local holder = mk("Frame", contentScroll, {
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
				})
				
				local outline = mk("Frame", holder, {
					Position = UDim2.fromOffset(20, 5),
					Size = UDim2.fromOffset(8, 8),
					BackgroundColor3 = theme.outerBorder,
					BorderSizePixel = 0,
				})
				mk("UICorner", outline, { CornerRadius = UDim.new(0, 2) })
				
				local checkFrame = mk("Frame", outline, {
					Position = UDim2.fromOffset(1, 1),
					Size = UDim2.new(1, -2, 1, -2),
					BackgroundColor3 = theme.toggleOff,
					BorderSizePixel = 0,
				})
				mk("UICorner", checkFrame, { CornerRadius = UDim.new(0, 2) })
				
				mk("TextLabel", holder, {
					Position = UDim2.fromOffset(41, 0),
					Size = UDim2.new(1, -41, 1, 0),
					BackgroundTransparency = 1,
					Text = toggleName,
					TextColor3 = theme.text,
					TextSize = 9,
					FontFace = font,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				
				local btn = mk("TextButton", holder, {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = "",
				})
				
				local state = default
				
				local function set(val: boolean)
					state = val
					tween(checkFrame, {
						BackgroundColor3 = state and theme.accent or theme.toggleOff
					})
					if flag then library.flags[flag] = state end
					callback(state)
				end
				
				connect(btn.MouseButton1Click, function()
					set(not state)
				end)
				
				set(default)
				
				return {
					set = set,
					get = function() return state end,
				}
			end
			
			function section:slider(props: { [string]: any }?)
				props = props or {}
				local sliderName = props.name
				local flag = props.flag
				local min = props.min or 0
				local max = props.max or 100
				local default = props.default or min
				local decimals = props.decimals or 1
				local suffix = props.suffix or ""
				local callback = props.callback or function() end
				
				local h = sliderName and 29 or 18
				local holder = mk("Frame", contentScroll, {
					Size = UDim2.new(1, 0, 0, h),
					BackgroundTransparency = 1,
				})
				
				if sliderName then
					mk("TextLabel", holder, {
						Position = UDim2.fromOffset(41, 4),
						Size = UDim2.new(1, -41, 0, 10),
						BackgroundTransparency = 1,
						Text = sliderName,
						TextColor3 = theme.text,
						TextSize = 9,
						FontFace = font,
						TextXAlignment = Enum.TextXAlignment.Left,
					})
				end
				
				local sy = sliderName and 18 or 5
				local outline = mk("Frame", holder, {
					Position = UDim2.fromOffset(40, sy),
					Size = UDim2.new(1, -99, 0, 7),
					BackgroundColor3 = theme.outerBorder,
					BorderSizePixel = 0,
				})
				mk("UICorner", outline, { CornerRadius = UDim.new(0, 2) })
				
				local track = mk("Frame", outline, {
					Position = UDim2.fromOffset(1, 1),
					Size = UDim2.new(1, -2, 1, -2),
					BackgroundColor3 = theme.sliderBg,
					BorderSizePixel = 0,
				})
				mk("UICorner", track, { CornerRadius = UDim.new(0, 2) })
				
				local fill = mk("Frame", track, {
					Size = UDim2.new(0, 0, 1, 0),
					BackgroundColor3 = theme.accent,
					BorderSizePixel = 0,
				})
				mk("UICorner", fill, { CornerRadius = UDim.new(0, 2) })
				
				local valLabel = mk("TextLabel", fill, {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(1, 0, 0.5, 1),
					Size = UDim2.new(0, 2, 1, 0),
					BackgroundTransparency = 1,
					Text = "",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 11,
					FontFace = fontBold,
					TextStrokeTransparency = 0.5,
					RichText = true,
				})
				
				local hitBtn = mk("TextButton", holder, {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = "",
				})
				
				local holding = false
				local state = default
				
				local function set(val: number)
					state = math.clamp(math.round(val * (1 / decimals)) / (1 / decimals), min, max)
					valLabel.Text = "<b>" .. state .. suffix .. "</b>"
					fill.Size = UDim2.new(1 - ((max - state) / (max - min)), 0, 1, 0)
					if flag then library.flags[flag] = state end
					callback(state)
				end
				
				local function refresh()
					local mousePos = UserInputService:GetMouseLocation()
					local raw = min + (max - min) * math.clamp((mousePos.X - fill.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
					set(math.floor(raw * (1 / decimals)) / (1 / decimals))
				end
				
				connect(hitBtn.MouseButton1Down, function()
					refresh()
					holding = true
				end)
				
				connect(UserInputService.InputChanged, function()
					if holding then refresh() end
				end)
				
				connect(UserInputService.InputEnded, function(input: InputObject)
					if holding and input.UserInputType == Enum.UserInputType.MouseButton1 then
						holding = false
					end
				end)
				
				set(default)
				
				return {
					set = set,
					get = function() return state end,
				}
			end
			
			function section:dropdown(props: { [string]: any }?)
				props = props or {}
				local dropName = props.name or "Dropdown"
				local flag = props.flag
				local options = props.options or { "Option 1", "Option 2" }
				local default = props.default or 1
				local callback = props.callback or function() end
				
				local holder = mk("Frame", contentScroll, {
					Size = UDim2.new(1, 0, 0, 39),
					BackgroundTransparency = 1,
				})
				
				mk("TextLabel", holder, {
					Position = UDim2.fromOffset(41, 4),
					Size = UDim2.new(1, -41, 0, 10),
					BackgroundTransparency = 1,
					Text = dropName,
					TextColor3 = theme.text,
					TextSize = 9,
					FontFace = font,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				
				local dropOutline = mk("Frame", holder, {
					Position = UDim2.fromOffset(40, 15),
					Size = UDim2.new(1, -98, 0, 20),
					BackgroundColor3 = theme.outerBorder,
					BorderSizePixel = 0,
				})
				mk("UICorner", dropOutline, { CornerRadius = UDim.new(0, 2) })
				
				local dropFrame = mk("Frame", dropOutline, {
					Position = UDim2.fromOffset(1, 1),
					Size = UDim2.new(1, -2, 1, -2),
					BackgroundColor3 = theme.dropBg,
					BorderSizePixel = 0,
				})
				mk("UICorner", dropFrame, { CornerRadius = UDim.new(0, 2) })
				
				local dropTitle = mk("TextLabel", dropFrame, {
					Position = UDim2.fromOffset(8, 0),
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = "",
					TextColor3 = theme.textDim,
					TextSize = 9,
					FontFace = font,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				
				mk("ImageLabel", dropFrame, {
					Position = UDim2.new(1, -11, 0.5, -4),
					Size = UDim2.fromOffset(7, 6),
					BackgroundTransparency = 1,
					Image = "rbxassetid://8532000591",
					ImageColor3 = Color3.fromRGB(255, 255, 255),
				})
				
				local hitBtn = mk("TextButton", holder, {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = "",
				})
				
				local state = default
				local open = false
				
				local function set(idx: number)
					state = idx
					dropTitle.Text = tostring(options[state] or "")
					if flag then library.flags[flag] = state end
					callback(state)
				end
				
				connect(hitBtn.MouseButton1Click, function()
					open = not open
					-- TODO: implement dropdown menu
				end)
				
				connect(hitBtn.MouseEnter, function()
					tween(dropFrame, { BackgroundColor3 = theme.dropHover })
				end)
				
				connect(hitBtn.MouseLeave, function()
					tween(dropFrame, { BackgroundColor3 = theme.dropBg })
				end)
				
				set(default)
				
				return {
					set = set,
					get = function() return state end,
				}
			end
			
			function section:colorpicker(props: { [string]: any }?)
				props = props or {}
				local colorName = props.name or "Color"
				local flag = props.flag
				local default = props.default or Color3.fromRGB(255, 255, 255)
				local callback = props.callback or function() end
				
				local holder = mk("Frame", contentScroll, {
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
				})
				
				mk("TextLabel", holder, {
					Position = UDim2.fromOffset(41, 0),
					Size = UDim2.new(1, -41, 1, 0),
					BackgroundTransparency = 1,
					Text = colorName,
					TextColor3 = theme.text,
					TextSize = 9,
					FontFace = font,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				
				local colorOutline = mk("Frame", holder, {
					Position = UDim2.new(1, -38, 0, 4),
					Size = UDim2.fromOffset(17, 9),
					BackgroundColor3 = theme.outerBorder,
					BorderSizePixel = 0,
				})
				mk("UICorner", colorOutline, { CornerRadius = UDim.new(0, 2) })
				
				local colorFrame = mk("Frame", colorOutline, {
					Position = UDim2.fromOffset(1, 1),
					Size = UDim2.new(1, -2, 1, -2),
					BackgroundColor3 = default,
					BorderSizePixel = 0,
				})
				mk("UICorner", colorFrame, { CornerRadius = UDim.new(0, 2) })
				
				local hitBtn = mk("TextButton", holder, {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = "",
				})
				
				local state = default
				
				local function set(col: Color3)
					state = col
					colorFrame.BackgroundColor3 = state
					if flag then library.flags[flag] = state end
					callback(state)
				end
				
				connect(hitBtn.MouseButton1Click, function()
					-- TODO: implement color picker
				end)
				
				set(default)
				
				return {
					set = set,
					get = function() return state end,
				}
			end
			
			function section:keybind(props: { [string]: any }?)
				props = props or {}
				local kbName = props.name or "Keybind"
				local flag = props.flag
				local default = props.default or Enum.KeyCode.E
				local mode = props.mode or "toggle"
				local callback = props.callback or function() end
				
				local holder = mk("Frame", contentScroll, {
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
				})
				
				mk("TextLabel", holder, {
					Position = UDim2.fromOffset(41, 0),
					Size = UDim2.new(1, -41, 1, 0),
					BackgroundTransparency = 1,
					Text = kbName,
					TextColor3 = theme.text,
					TextSize = 9,
					FontFace = font,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				
				local valLabel = mk("TextLabel", holder, {
					Position = UDim2.fromOffset(41, 0),
					Size = UDim2.new(1, -61, 1, 0),
					BackgroundTransparency = 1,
					Text = "[-]",
					TextColor3 = Color3.fromRGB(114, 114, 130),
					TextSize = 9,
					FontFace = font,
					TextStrokeColor3 = Color3.fromRGB(15, 15, 22),
					TextStrokeTransparency = 0,
					TextXAlignment = Enum.TextXAlignment.Right,
				})
				
				local hitBtn = mk("TextButton", holder, {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = "",
				})
				
				local state = default
				local binding = false
				
				local function set(key: Enum.KeyCode?)
					state = key
					valLabel.Text = key and "[" .. key.Name .. "]" or "[-]"
					if flag then library.flags[flag] = state end
					callback(state)
				end
				
				connect(hitBtn.MouseButton1Click, function()
					binding = true
					valLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
				end)
				
				connect(UserInputService.InputBegan, function(input: InputObject)
					if binding then
						if input.KeyCode ~= Enum.KeyCode.Unknown then
							set(input.KeyCode)
							binding = false
							valLabel.TextColor3 = Color3.fromRGB(114, 114, 130)
						end
					end
				end)
				
				set(default)
				
				return {
					set = set,
					get = function() return state end,
				}
			end
			
			function section:button(props: { [string]: any }?)
				props = props or {}
				local btnName = props.name or "Button"
				local callback = props.callback or function() end
				
				local holder = mk("Frame", contentScroll, {
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 1,
				})
				
				local button = mk("TextButton", holder, {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.new(1, -40, 0, 24),
					BackgroundColor3 = theme.panel,
					BorderSizePixel = 0,
					Text = btnName,
					TextColor3 = theme.text,
					TextSize = 10,
					FontFace = font,
				})
				mk("UICorner", button, { CornerRadius = UDim.new(0, 3) })
				mk("UIStroke", button, {
					Color = theme.line,
					Thickness = 1,
				})
				
				connect(button.MouseButton1Click, function()
					callback()
				end)
				
				connect(button.MouseEnter, function()
					tween(button, { BackgroundColor3 = theme.dropHover })
				end)
				
				connect(button.MouseLeave, function()
					tween(button, { BackgroundColor3 = theme.panel })
				end)
			end
			
			function section:label(props: { [string]: any }?)
				props = props or {}
				local text = props.text or "Label"
				
				local label = mk("TextLabel", contentScroll, {
					Size = UDim2.new(1, -40, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = text,
					TextColor3 = theme.textDim,
					TextSize = 9,
					FontFace = font,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				mk("UIPadding", label, {
					PaddingLeft = UDim.new(0, 20),
					PaddingRight = UDim.new(0, 20),
					PaddingTop = UDim.new(0, 4),
					PaddingBottom = UDim.new(0, 4),
				})
				
				return {
					setText = function(newText: string)
						label.Text = newText
					end,
				}
			end
			
			return section
		end
		
		return tab
	end
	
	return window
end

function library:destroy()
	for _, conn in library.connections do
		conn:Disconnect()
	end
	for _, gui in guiParent:GetChildren() do
		if gui:IsA("ScreenGui") and gui.Name:find("^LibUI_") then
			gui:Destroy()
		end
	end
end

return library
