-- [ SERVICES ]
local UserInputService: UserInputService = game:GetService("UserInputService")
local TweenService: TweenService   = game:GetService("TweenService")
local HttpService: HttpService     = game:GetService("HttpService")
local RunService: RunService       = game:GetService("RunService")
local CoreGui: CoreGui             = game:GetService("CoreGui")
local Players: Players             = game:GetService("Players")

-- [ VARIABLES ]
local Library: any                 = {Settings = {}, UpdatePreview = nil}
local Main: CanvasGroup            = nil
local Container: Frame             = nil
local NavList: Frame               = nil
local SpecFrame: Frame             = nil
local BindHUD: Frame               = nil
local VizRightFixed: Frame         = nil
local Preview: Frame               = nil
local Picker: Frame                = nil
local ColorWheel: ImageButton      = nil
local PBrightnessSlider: Frame     = nil
local PickerDot: Frame             = nil
local BrightnessDot: Frame         = nil
local Confirm: TextButton          = nil
local PreviewCol: Frame            = nil
local PBox: Frame                  = nil
local PBoxStroke: UIStroke         = nil
local PName: TextLabel             = nil
local PHPBar: Frame                = nil
local PHit: Frame                  = nil
local PTracer: Frame               = nil
local PSkel: Frame                 = nil
local Pages: {any}                 = {}
local NavButtons: {any}            = {}
local LocalPlayer: Player          = Players.LocalPlayer
local FolderName: string           = "GeminiAura_Configs"
local MenuVisible: boolean         = true
local CanDrag: boolean             = true
local currentKey: string           = ""
local currentH: number             = 0
local currentS: number             = 0
local currentV: number             = 1
local PickerDragging: boolean      = false
local BrightnessDragging: boolean  = false

-- [ DRAWING OBJECTS ]
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.Color = Color3.fromRGB(180, 100, 255)
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.Visible = false

local TriggerCircle = Drawing.new("Circle")
TriggerCircle.Thickness = 1
TriggerCircle.Color = Color3.fromRGB(255, 50, 50)
TriggerCircle.Filled = false
TriggerCircle.Transparency = 1
TriggerCircle.Visible = false

-- [ INITIALIZATION ]
if not isfolder(FolderName) then
	makefolder(FolderName)
end

-- [ COLOR PICKER SYSTEM ]
local function UpdateColorWithBrightness(): ()
	local finalColor: Color3 = Color3.fromHSV(currentH, currentS, currentV)
	
	if currentKey ~= "" then
		Library.Settings[currentKey] = finalColor
	end

	PreviewCol.BackgroundColor3 = finalColor
	ColorWheel.ImageColor3 = Color3.fromHSV(0, 0, currentV)
end

local function UpdateBrightness(i: InputObject): ()
	local sizeY: number = PBrightnessSlider.AbsoluteSize.Y
	local relY: number = math.clamp(i.Position.Y - PBrightnessSlider.AbsolutePosition.Y, 0, sizeY)
	
	currentV = 1 - (relY / sizeY)
	BrightnessDot.Position = UDim2.new(-0.5, 0, 0, relY - 2)
	UpdateColorWithBrightness()
end

local function UpdatePicker(i: InputObject): ()
	local r: number = ColorWheel.AbsoluteSize.X / 2
	local center: Vector2 = ColorWheel.AbsolutePosition + ColorWheel.AbsoluteSize / 2
	local delta: Vector2 = Vector2.new(i.Position.X, i.Position.Y) - center
	
	if delta.Magnitude <= r then
		PickerDot.Position = UDim2.new(0, delta.X + r - 3, 0, delta.Y + r - 3)
		currentH = (math.pi - math.atan2(delta.Y, delta.X)) / (2 * math.pi)
		currentS = delta.Magnitude / r
		UpdateColorWithBrightness()
	end
end

-- [ CONFIG SYSTEM ]
function Library:SaveConfig(name: string): ()
	local final: string = name
	if name == "MOD_Emergency" then
		local c: number = 1
		while isfile(FolderName .. "/" .. name .. "-" .. c .. ".json") do
			c = c + 1
		end
		final = name .. "-" .. c
	end

	if SpecFrame and BindHUD then 
		self.Settings.SpecListPos = {SpecFrame.Position.X.Scale, SpecFrame.Position.X.Offset, SpecFrame.Position.Y.Scale, SpecFrame.Position.Y.Offset}
		self.Settings.BindHUDPos = {BindHUD.Position.X.Scale, BindHUD.Position.X.Offset, BindHUD.Position.Y.Scale, BindHUD.Position.Y.Offset}
	end

	local encoded: any = {}
	for k, v in pairs(self.Settings) do
		local ks: string = tostring(k)
		if typeof(v) == "EnumItem" then
			encoded[ks] = {__type = "Enum", value = tostring(v)}
		elseif typeof(v) == "Color3" then
			encoded[ks] = {__type = "Color3", value = {v.R, v.G, v.B}}
		else
			encoded[ks] = v
		end
	end

	local s, res = pcall(HttpService.JSONEncode, HttpService, encoded)
	if s then
		writefile(FolderName .. "/" .. final .. ".json", res)
	end
end

function Library:LoadConfig(name: string): ()
	local path: string = FolderName .. "/" .. name .. ".json"
	if isfile(path) then
		local s, data = pcall(HttpService.JSONDecode, HttpService, readfile(path))
		if s then
			for k, v in pairs(data) do
				if typeof(v) == "table" and v.__type == "Enum" then
					local en, ei = v.value:match("Enum%.(%w+)%.(%w+)")
					if en and ei then
						self.Settings[k] = Enum[en][ei]
					end
				elseif typeof(v) == "table" and v.__type == "Color3" then
					self.Settings[k] = Color3.new(unpack(v.value))
				else
					self.Settings[k] = v
				end
			end
			
			if SpecFrame and self.Settings.SpecListPos then
				SpecFrame.Position = UDim2.new(unpack(self.Settings.SpecListPos))
			end
			if BindHUD and self.Settings.BindHUDPos then
				BindHUD.Position = UDim2.new(unpack(self.Settings.BindHUDPos))
			end
			
			if _G.UpdateLighting then
				_G.UpdateLighting()
			end
			self:UpdateBindHUD()
			self:UpdateSpecList()
		end
	end
end

-- [ DRAG SYSTEM ]
function Library:MakeDraggable(gui: any): ()
	local d, di, ds, sp
	
	gui.InputBegan:Connect(function(i: InputObject)
		if i.UserInputType == Enum.UserInputType.MouseButton1 and CanDrag and not PickerDragging and not BrightnessDragging then
			d = true
			ds = i.Position
			sp = gui.Position
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					d = false
				end
			end)
		end
	end)

	gui.InputChanged:Connect(function(i: InputObject)
		if i.UserInputType == Enum.UserInputType.MouseMovement then
			di = i
		end
	end)
	
	UserInputService.InputChanged:Connect(function(i: InputObject)
		if i == di and d and not PickerDragging and not BrightnessDragging then
			local dt = i.Position - ds
			gui.Position = UDim2.new(sp.X.Scale, sp.X.Offset + dt.X, sp.Y.Scale, sp.Y.Offset + dt.Y)
		end
	end)
end

-- [ UI HELPER FUNCTIONS ]
local function CreatePickerUI(parent: Instance): ()
	Picker = Instance.new("Frame", parent)
	Picker.Name = "ColorPicker"
	Picker.Size = UDim2.new(0, 180, 0, 190)
	Picker.Position = UDim2.new(1, 20, 0, 0)
	Picker.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
	Picker.Visible = false
	Picker.ZIndex = 20
	
	local stroke = Instance.new("UIStroke", Picker)
	stroke.Color = Color3.fromRGB(40, 45, 60)
	
	Instance.new("UICorner", Picker)

	ColorWheel = Instance.new("ImageButton", Picker)
	ColorWheel.Size = UDim2.new(0, 120, 0, 120)
	ColorWheel.Position = UDim2.new(0, 10, 0, 10)
	ColorWheel.Image = "rbxassetid://6020299385"
	ColorWheel.BackgroundTransparency = 1
	ColorWheel.ZIndex = 21

	PickerDot = Instance.new("Frame", Picker)
	PickerDot.Size = UDim2.new(0, 6, 0, 6)
	PickerDot.BackgroundColor3 = Color3.new(1, 1, 1)
	PickerDot.BorderSizePixel = 0
	PickerDot.ZIndex = 22
	Instance.new("UICorner", PickerDot).CornerRadius = UDim.new(1, 0)

	PBrightnessSlider = Instance.new("Frame", Picker)
	PBrightnessSlider.Size = UDim2.new(0, 10, 0, 120)
	PBrightnessSlider.Position = UDim2.new(0, 140, 0, 10)
	PBrightnessSlider.BackgroundColor3 = Color3.new(1, 1, 1)
	PBrightnessSlider.ZIndex = 21
	
	local grad = Instance.new("UIGradient", PBrightnessSlider)
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0, 0, 0))

	BrightnessDot = Instance.new("Frame", PBrightnessSlider)
	BrightnessDot.Size = UDim2.new(0, 14, 0, 4)
	BrightnessDot.BackgroundColor3 = Color3.new(1, 1, 1)
	BrightnessDot.Position = UDim2.new(-0.2, 0, 0, 0)
	BrightnessDot.ZIndex = 23
	Instance.new("UIStroke", BrightnessDot).Thickness = 1

	PreviewCol = Instance.new("Frame", Picker)
	PreviewCol.Size = UDim2.new(0, 60, 0, 30)
	PreviewCol.Position = UDim2.new(0, 10, 0, 145)
	PreviewCol.BackgroundColor3 = Color3.new(1, 1, 1)
	Instance.new("UICorner", PreviewCol)

	Confirm = Instance.new("TextButton", Picker)
	Confirm.Size = UDim2.new(0, 80, 0, 30)
	Confirm.Position = UDim2.new(0, 80, 0, 145)
	Confirm.BackgroundColor3 = Color3.fromRGB(180, 100, 255)
	Confirm.Text = "OK"
	Confirm.Font = Enum.Font.Oswald
	Confirm.TextColor3 = Color3.new(1, 1, 1)
	Confirm.TextSize = 14
	Instance.new("UICorner", Confirm)
end

local function CreatePreviewUI(parent: Instance): ()
	VizRightFixed = Instance.new("Frame", parent)
	VizRightFixed.Name = "VizFixed"
	VizRightFixed.Size = UDim2.new(0, 190, 1, -40)
	VizRightFixed.Position = UDim2.new(1, -200, 0, 20)
	VizRightFixed.BackgroundTransparency = 1

	Preview = Instance.new("Frame", VizRightFixed)
	Preview.Name = "PreviewBox"
	Preview.Size = UDim2.new(1, 0, 0, 250)
	Preview.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
	Instance.new("UICorner", Preview)

	PBox = Instance.new("Frame", Preview)
	PBox.Size = UDim2.new(0, 100, 0, 180)
	PBox.AnchorPoint = Vector2.new(0.5, 0.5)
	PBox.Position = UDim2.new(0.5, 0, 0.5, 0)
	PBox.BackgroundTransparency = 1
	
	PBoxStroke = Instance.new("UIStroke", PBox)
	PBoxStroke.Thickness = 2
	PBoxStroke.Color = Color3.new(1, 0, 0)

	PName = Instance.new("TextLabel", Preview)
	PName.Text = "Player"
	PName.Position = UDim2.new(0.5, 0, 0, 10)
	PName.AnchorPoint = Vector2.new(0.5, 0)
	PName.BackgroundTransparency = 1
	PName.TextColor3 = Color3.new(1, 1, 1)
	PName.Font = Enum.Font.Oswald
	PName.TextSize = 14

	PHPBar = Instance.new("Frame", PBox)
	PHPBar.Size = UDim2.new(0, 4, 1, 0)
	PHPBar.Position = UDim2.new(0, -8, 0, 0)
	PHPBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	
	PHit = Instance.new("Frame", PHPBar)
	PHit.Size = UDim2.new(1, 0, 0.8, 0)
	PHit.Position = UDim2.new(0, 0, 0.2, 0)
	PHit.BackgroundColor3 = Color3.new(0, 1, 0)

	PTracer = Instance.new("Frame", Preview)
	PTracer.Size = UDim2.new(0, 2, 0, 100)
	PTracer.AnchorPoint = Vector2.new(0.5, 1)
	PTracer.Position = UDim2.new(0.5, 0, 1, -10)
	PTracer.BackgroundColor3 = Color3.new(1, 1, 1)
	PTracer.BorderSizePixel = 0

	PSkel = Instance.new("Frame", PBox)
	PSkel.BackgroundTransparency = 1
	PSkel.Size = UDim2.new(1, 0, 1, 0)
	
	local head = Instance.new("Frame", PSkel)
	head.Size = UDim2.new(0, 20, 0, 20)
	head.Position = UDim2.new(0.5, -10, 0, 0)
	
	local spine = Instance.new("Frame", PSkel)
	spine.Size = UDim2.new(0, 2, 0, 60)
	spine.Position = UDim2.new(0.5, -1, 0, 20)
end

-- [ UI INITIALIZATION ]
function Library:Init(): (ScreenGui, CanvasGroup, Frame, Frame)
	local sg: ScreenGui = Instance.new("ScreenGui", CoreGui)
	sg.Name = "GeminiAura"
	
	Main = Instance.new("CanvasGroup", sg)
	Main.Size = UDim2.new(0, 750, 0, 450)
	Main.Position = UDim2.new(0.5, -375, 0.5, -225)
	Main.BackgroundColor3 = Color3.fromRGB(11, 14, 22)
	Main.BorderSizePixel = 0
	Main.BackgroundTransparency = 0.02
	Main.ClipsDescendants = true
	Instance.new("UICorner", Main)
	self:MakeDraggable(Main)
	
	local side: Frame = Instance.new("Frame", Main)
	side.Size = UDim2.new(0, 170, 1, 0)
	side.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
	Instance.new("UICorner", side)
	
	local title: TextLabel = Instance.new("TextLabel", side)
	title.Size = UDim2.new(1, 0, 0, 60)
	title.Text = "GEMINI AURA"
	title.Font = Enum.Font.Oswald
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(180, 100, 255)
	title.BackgroundTransparency = 1
	
	NavList = Instance.new("Frame", side)
	NavList.Name = "Nav"
	NavList.Size = UDim2.new(1, 0, 1, -70)
	NavList.Position = UDim2.new(0, 0, 0, 70)
	NavList.BackgroundTransparency = 1
	
	local nl: UIListLayout = Instance.new("UIListLayout", NavList)
	nl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	nl.Padding = UDim.new(0, 5)
	
	Container = Instance.new("Frame", Main)
	Container.Name = "Container"
	Container.Size = UDim2.new(1, -190, 1, -40)
	Container.Position = UDim2.new(0, 185, 0, 20)
	Container.BackgroundTransparency = 1
	
	BindHUD = Instance.new("Frame", sg)
	BindHUD.Visible = false
	BindHUD.Size = UDim2.new(0, 180, 0, 30)
	BindHUD.Position = UDim2.new(1, -20, 0.4, 0)
	BindHUD.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
	BindHUD.BackgroundTransparency = 0.65
	BindHUD.AnchorPoint = Vector2.new(1, 0)
	BindHUD.AutomaticSize = Enum.AutomaticSize.Y
	
	local hs: UIStroke = Instance.new("UIStroke", BindHUD)
	hs.Color = Color3.fromRGB(40, 45, 60)
	hs.Thickness = 1
	
	Instance.new("UICorner", BindHUD).CornerRadius = UDim.new(0, 4)
	
	local ht: TextLabel = Instance.new("TextLabel", BindHUD)
	ht.Size = UDim2.new(1, 0, 0, 25)
	ht.Text = " Keybinds"
	ht.Font = Enum.Font.Oswald
	ht.TextSize = 16
	ht.TextColor3 = Color3.fromRGB(180, 100, 255)
	ht.BackgroundTransparency = 1
	ht.TextXAlignment = Enum.TextXAlignment.Left
	
	local hl: Frame = Instance.new("Frame", BindHUD)
	hl.Name = "List"
	hl.Size = UDim2.new(1, -10, 1, -30)
	hl.Position = UDim2.new(0, 5, 0, 28)
	hl.BackgroundTransparency = 1
	Instance.new("UIListLayout", hl).Padding = UDim.new(0, 2)
	self:MakeDraggable(BindHUD)
	
	SpecFrame = Instance.new("Frame", sg)
	SpecFrame.Size = UDim2.new(0, 180, 0, 30)
	SpecFrame.Position = UDim2.new(0, 20, 0.4, 0)
	SpecFrame.BackgroundColor3 = Color3.fromRGB(11, 14, 22)
	SpecFrame.BackgroundTransparency = 0.2
	Instance.new("UICorner", SpecFrame)
	self:MakeDraggable(SpecFrame)
	
	local st: TextLabel = Instance.new("TextLabel", SpecFrame)
	st.Size = UDim2.new(1, 0, 1, 0)
	st.Text = "Spectators List"
	st.Font = Enum.Font.Oswald
	st.TextSize = 16
	st.TextColor3 = Color3.fromRGB(180, 100, 255)
	st.BackgroundTransparency = 1
	
	local sl: Frame = Instance.new("Frame", SpecFrame)
	sl.Name = "List"
	sl.Size = UDim2.new(1, 0, 0, 0)
	sl.Position = UDim2.new(0, 0, 1, 5)
	sl.BackgroundTransparency = 1
	sl.AutomaticSize = Enum.AutomaticSize.Y
	Instance.new("UIListLayout", sl).Padding = UDim.new(0, 2)
	
	CreatePickerUI(sg)
	CreatePreviewUI(Main)
	
	return sg, Main, NavList, Container
end

function Library:ToggleMenu(): ()
	MenuVisible = not MenuVisible
	local alpha, pos = MenuVisible and 1 or 0, MenuVisible and UDim2.new(0.5, -375, 0.5, -225) or UDim2.new(0.5, -375, 0.5, -200)
	
	TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {GroupTransparency = 1 - alpha, Position = pos}):Play()
	
	if MenuVisible then
		Main.Visible = true
	else
		task.delay(0.3, function()
			if not MenuVisible then
				Main.Visible = false
			end
		end)
	end
end

-- [ PICKER EVENTS ]
function Library:InitPickerLogic(): ()
	ColorWheel.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			PickerDragging = true
			UpdatePicker(i)
		end
	end)
	
	PBrightnessSlider.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			BrightnessDragging = true
			UpdateBrightness(i)
		end
	end)
	
	UserInputService.InputChanged:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseMovement then 
			if PickerDragging then
				UpdatePicker(i)
			elseif BrightnessDragging then
				UpdateBrightness(i)
			end 
		end
	end)
	
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			PickerDragging = false
			BrightnessDragging = false
		end
	end)
	
	Confirm.MouseButton1Click:Connect(function()
		Picker.Visible = false
	end)
end

-- [ UI CONTENT BUILDER ]
function Library:CreatePage(name: string, layout: number?): ScrollingFrame
	local p: ScrollingFrame = Instance.new("ScrollingFrame", Container)
	p.Name = name
	p.Size = UDim2.new(1, 0, 1, 0)
	p.Visible = false
	p.BackgroundTransparency = 1
	p.BorderSizePixel = 0
	p.ScrollBarThickness = 0
	p.CanvasSize = UDim2.new(0, 0, 0, 0)
	p.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Pages[name] = p
	
	local pl: UIListLayout = Instance.new("UIListLayout", p)
	pl.Padding = UDim.new(0, 5)
	pl.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local b: TextButton = Instance.new("TextButton", NavList)
	b.Size = UDim2.new(0, 140, 0, 45)
	b.Text = "  "..name
	b.Font = Enum.Font.Oswald
	b.TextSize = 20
	b.BackgroundTransparency = 1
	b.AutoButtonColor = false
	b.LayoutOrder = layout or 0
	b.TextColor3 = (name == "Visuals") and Color3.new(1, 1, 1) or Color3.new(0.6, 0.6, 0.6)
	NavButtons[name] = b

	b.MouseButton1Click:Connect(function()
		for k, pg in pairs(Pages) do 
			pg.Visible = (k == name)
			if k == name then
				if name == "Visuals" and VizRightFixed then
					VizRightFixed.Parent = pg
					Preview.Visible = true
				elseif name == "Lighting" and VizRightFixed then
					VizRightFixed.Parent = pg
					Preview.Visible = false
				end
			end
		end
		for k, nb in pairs(NavButtons) do
			nb.TextColor3 = (k == name) and Color3.new(1, 1, 1) or Color3.new(0.6, 0.6, 0.6)
		end
	end)
	return p
end

function Library:CreateTitle(parent: Instance, text: string): Frame
	local f: Frame = Instance.new("Frame", parent)
	f.Size = UDim2.new(1, -20, 0, 30)
	f.BackgroundTransparency = 1
	
	local l: TextLabel = Instance.new("TextLabel", f)
	l.Size = UDim2.new(1, 0, 1, 0)
	l.Text = text:upper()
	l.Font = Enum.Font.Oswald
	l.TextSize = 14
	l.TextColor3 = Color3.fromRGB(180, 100, 255)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.BackgroundTransparency = 1
	
	local ln: Frame = Instance.new("Frame", f)
	ln.Size = UDim2.new(1, 0, 0, 1)
	ln.Position = UDim2.new(0, 0, 1, -2)
	ln.BackgroundColor3 = Color3.fromRGB(180, 100, 255)
	ln.BackgroundTransparency = 0.6
	
	local g = Instance.new("UIGradient", ln)
	g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(0.8,0), NumberSequenceKeypoint.new(1,1)})
	return f
end

function Library:CreateButton(parent: Instance, text: string, color: Color3, callback: () -> ()): TextButton
	local f: Frame = Instance.new("Frame", parent)
	f.Size = UDim2.new(1, -20, 0, 45)
	f.BackgroundTransparency = 1
	
	local b: TextButton = Instance.new("TextButton", f)
	b.Size = UDim2.new(1, 0, 0, 40)
	b.Position = UDim2.new(0, 0, 0.5, -20)
	b.BackgroundColor3 = color
	b.Text = text
	b.Font = Enum.Font.Oswald
	b.TextSize = 18
	b.TextColor3 = Color3.new(1, 1, 1)
	Instance.new("UICorner", b)
	
	b.MouseButton1Click:Connect(callback)
	return b
end

function Library:CreateSwitch(parent: Instance, name: string, settingKey: string, extra: any?): ()
	local f: Frame = Instance.new("Frame", parent)
	f.Size = UDim2.new(0.95, 0, 0, 40)
	f.BackgroundTransparency = 1
	
	local l: TextLabel = Instance.new("TextLabel", f)
	l.Size = UDim2.new(1, -100, 1, 0)
	l.Text = name
	l.Font = Enum.Font.Oswald
	l.TextSize = 18
	l.TextColor3 = Color3.new(1,1,1)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.BackgroundTransparency = 1
	
	local b: TextButton = Instance.new("TextButton", f)
	b.Size = UDim2.new(0, 40, 0, 20)
	b.Position = UDim2.new(1, -30, 0.5, -10)
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundColor3 = self.Settings[settingKey] and Color3.fromRGB(180, 100, 255) or Color3.fromRGB(40, 45, 55)
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
	
	local c: Frame = Instance.new("Frame", b)
	c.Size = UDim2.new(0, 16, 0, 16)
	c.BackgroundColor3 = Color3.new(1, 1, 1)
	Instance.new("UICorner", c).CornerRadius = UDim.new(1, 0)
	c.Position = self.Settings[settingKey] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)

	b.MouseButton1Click:Connect(function()
		self.Settings[settingKey] = not self.Settings[settingKey]
		if self.UpdatePreview then
			self.UpdatePreview()
		end
		
		if type(extra) == "function" then
			extra(self.Settings[settingKey])
		end
		
		TweenService:Create(c, TweenInfo.new(0.2), {Position = self.Settings[settingKey] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}):Play()
		TweenService:Create(b, TweenInfo.new(0.2), {BackgroundColor3 = self.Settings[settingKey] and Color3.fromRGB(180, 100, 255) or Color3.fromRGB(40, 45, 55)}):Play()
	end)

	if type(extra) == "string" then
		local cp: TextButton = Instance.new("TextButton", f)
		cp.Size = UDim2.new(0, 22, 0, 22)
		cp.Position = UDim2.new(1, -60, 0.5, -11)
		cp.Text = ""
		Instance.new("UICorner", cp)
		cp.BackgroundColor3 = typeof(self.Settings[extra]) == "Color3" and self.Settings[extra] or Color3.new(unpack(self.Settings[extra]))
		
		cp.MouseButton1Click:Connect(function()
			currentKey = extra
			Picker.Visible = true
			PickerDot.Position = UDim2.new(0, 53, 0, 53)
			BrightnessDot.Position = UDim2.new(-0.2, 0, 0, 0)
		end)
		
		RunService.RenderStepped:Connect(function()
			local col = self.Settings[extra]
			cp.BackgroundColor3 = typeof(col) == "Color3" and col or Color3.new(unpack(col))
		end)
	end
end

function Library:CreateSlider(parent: Instance, name: string, settingKey: string, min: number, max: number, slidingAmount: number?): ()
	local step: number = slidingAmount or 1
	local f: Frame = Instance.new("Frame", parent)
	f.Size = UDim2.new(1, -20, 0, 50)
	f.BackgroundTransparency = 1
	
	local l: TextLabel = Instance.new("TextLabel", f)
	l.Size = UDim2.new(1, -60, 0, 20)
	l.Text = name
	l.Font = Enum.Font.Oswald
	l.TextSize = 16
	l.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.BackgroundTransparency = 1
	
	local sbg: Frame = Instance.new("Frame", f)
	sbg.Size = UDim2.new(1, 0, 0, 6)
	sbg.Position = UDim2.new(0, 0, 1, -15)
	sbg.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
	Instance.new("UICorner", sbg)
	
	local fill: Frame = Instance.new("Frame", sbg)
	fill.BackgroundColor3 = Color3.fromRGB(180, 100, 255)
	Instance.new("UICorner", fill)
	
	local val: TextBox = Instance.new("TextBox", f)
	val.Size = UDim2.new(0, 50, 0, 20)
	val.Position = UDim2.new(1, -50, 0, 0)
	val.Font = Enum.Font.Oswald
	val.TextSize = 14
	val.TextColor3 = Color3.new(1, 1, 1)
	val.BackgroundTransparency = 0.5
	val.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
	val.BorderSizePixel = 0
	val.TextXAlignment = Enum.TextXAlignment.Right
	val.ClearTextOnFocus = false
	
	local function updateUI()
		local cur: number = self.Settings[settingKey]
		fill.Size = UDim2.new((cur - min) / (max - min), 0, 1, 0)
		if not val:IsFocused() then
			val.Text = tostring(math.floor(cur * 100) / 100)
		end
	end
	
	val.FocusLost:Connect(function()
		local n: number? = tonumber(val.Text)
		if n then
			self.Settings[settingKey] = math.clamp(math.round(n / step) * step, min, max)
		end
		updateUI()
	end)

	local active: boolean = false
	local function updateFromMouse(i: InputObject)
		local p: number = math.clamp((i.Position.X - sbg.AbsolutePosition.X) / sbg.AbsoluteSize.X, 0, 1)
		self.Settings[settingKey] = math.clamp(math.round((min + (max - min) * p) / step) * step, min, max)
		if self.UpdatePreview then
			self.UpdatePreview()
		end
	end

	sbg.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			active = true
			PickerDragging = true
			CanDrag = false
			updateFromMouse(i)
		end
	end)
	
	UserInputService.InputChanged:Connect(function(i)
		if active and i.UserInputType == Enum.UserInputType.MouseMovement then
			updateFromMouse(i)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			active = false
			PickerDragging = false
			CanDrag = true
		end
	end)
	
	RunService.RenderStepped:Connect(updateUI)
end

function Library:CreateBind(parent: Instance, text: string, settingKey: string): Frame
	local f: Frame = Instance.new("Frame", parent)
	f.Size = UDim2.new(1, -20, 0, 35)
	f.BackgroundTransparency = 1
	
	local l: TextLabel = Instance.new("TextLabel", f)
	l.Size = UDim2.new(1, 0, 1, 0)
	l.Text = text
	l.Font = Enum.Font.Oswald
	l.TextSize = 16
	l.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.BackgroundTransparency = 1
	
	local b: TextButton = Instance.new("TextButton", f)
	b.Size = UDim2.new(0, 80, 0, 25)
	b.Position = UDim2.new(1, -80, 0.5, -12)
	b.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
	b.Font = Enum.Font.Oswald
	b.TextSize = 14
	Instance.new("UICorner", b)
	
	local binding: boolean = false
	
	local function update()
		local v = self.Settings[settingKey]
		b.Text = (typeof(v) == "EnumItem") and v.Name or "None"
	end
	
	b.MouseButton1Click:Connect(function()
		if binding then return end
		binding = true
		b.Text = "..."
		b.TextColor3 = Color3.fromRGB(180, 100, 255)
		
		local c
		c = UserInputService.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Keyboard then
				local k = i.KeyCode == Enum.KeyCode.Escape and Enum.KeyCode.Unknown or i.KeyCode
				self.Settings[settingKey] = k
				update()
				b.TextColor3 = Color3.new(1,1,1)
				binding = false
				c:Disconnect()
			end
		end)
	end)
	
	task.spawn(function()
		while f and f.Parent do
			if not binding then update() end
			task.wait(0.5)
		end
	end)
	return f
end

function Library:CreateDropdown(parent: Instance, text: string, options: {string}, settingKey: string): Frame
	local f: Frame = Instance.new("Frame", parent)
	f.Size = UDim2.new(1, -20, 0, 35)
	f.BackgroundTransparency = 1
	f.ZIndex = 5
	
	local l: TextLabel = Instance.new("TextLabel", f)
	l.Size = UDim2.new(0.4, 0, 1, 0)
	l.Text = text
	l.Font = Enum.Font.Oswald
	l.TextSize = 16
	l.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.BackgroundTransparency = 1
	
	local b: TextButton = Instance.new("TextButton", f)
	b.Size = UDim2.new(0.35, 0, 0, 28)
	b.Position = UDim2.new(1, -195, 0.5, -14)
	b.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
	b.Text = self.Settings[settingKey]
	b.Font = Enum.Font.Oswald
	b.TextSize = 14
	Instance.new("UICorner", b)
	
	local s = Instance.new("UIStroke", b)
	s.Color = Color3.fromRGB(40, 45, 60)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	
	local lst: Frame = Instance.new("Frame", b)
	lst.Size = UDim2.new(1, 0, 0, 0)
	lst.Position = UDim2.new(0, 0, 1, 5)
	lst.Visible = false
	lst.BackgroundColor3 = Color3.fromRGB(16, 22, 32)
	lst.BorderSizePixel = 0
	lst.ZIndex = 100
	Instance.new("UICorner", lst)
	Instance.new("UIListLayout", lst)

	b.MouseButton1Click:Connect(function()
		lst.Visible = not lst.Visible
		lst.Size = UDim2.new(1, 0, 0, #options * 28)
		s.Color = lst.Visible and Color3.fromRGB(180, 100, 255) or Color3.fromRGB(40, 45, 60)
		f.ZIndex = lst.Visible and 10 or 5
	end)

	for _, opt in pairs(options) do
		local o: TextButton = Instance.new("TextButton", lst)
		o.Size = UDim2.new(1, 0, 0, 28)
		o.Text = opt
		o.BackgroundTransparency = 1
		o.Font = Enum.Font.Oswald
		o.TextSize = 14
		o.TextColor3 = Color3.new(0.6, 0.6, 0.6)
		o.ZIndex = 101
		
		o.MouseEnter:Connect(function()
			o.BackgroundTransparency = 0.8
			o.TextColor3 = Color3.new(1,1,1)
		end)
		
		o.MouseLeave:Connect(function()
			o.BackgroundTransparency = 1
			o.TextColor3 = Color3.new(0.6, 0.6, 0.6)
		end)
		
		o.MouseButton1Click:Connect(function()
			b.Text = opt
			lst.Visible = false
			self.Settings[settingKey] = opt
			s.Color = Color3.fromRGB(40, 45, 60)
			f.ZIndex = 5
			if self.UpdatePreview then
				self.UpdatePreview()
			end
		end)
	end
	return f
end

-- [ CONFIG UI ELEMENTS ]
function Library:CreateConfigHeader(parent: Instance): ()
	local h: Frame = Instance.new("Frame", parent)
	h.Size = UDim2.new(1, 0, 0, 95)
	h.BackgroundTransparency = 1
	
	local l: UIListLayout = Instance.new("UIListLayout", h)
	l.Padding = UDim.new(0, 10)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local i: TextBox = Instance.new("TextBox", h)
	i.Size = UDim2.new(1, -15, 0, 40)
	i.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
	i.PlaceholderText = "Config name..."
	i.Font = Enum.Font.Oswald
	i.TextSize = 18
	i.TextColor3 = Color3.new(1, 1, 1)
	i.Text = ""
	Instance.new("UICorner", i)

	local b: TextButton = Instance.new("TextButton", h)
	b.Size = UDim2.new(1, -15, 0, 40)
	b.BackgroundColor3 = Color3.fromRGB(180, 100, 255)
	b.Text = "Create"
	b.Font = Enum.Font.Oswald
	b.TextSize = 20
	b.TextColor3 = Color3.new(1, 1, 1)
	Instance.new("UICorner", b)
	
	i:GetPropertyChangedSignal("Text"):Connect(function() 
		b.Text = isfile(FolderName .. "/" .. i.Text .. ".json") and "Save" or "Create" 
	end)

	b.MouseButton1Click:Connect(function() 
		if i.Text ~= "" then 
			self:SaveConfig(i.Text)
			i.Text = ""
			self:RefreshConfigs() 
		end 
	end)
end

function Library:CreateConfigItem(parent: Instance, name: string, path: string): Frame
	local f: Frame = Instance.new("Frame", parent)
	f.Size = UDim2.new(1, -15, 0, 60)
	f.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
	Instance.new("UICorner", f)

	local t: TextLabel = Instance.new("TextLabel", f)
	t.Size = UDim2.new(1, -160, 1, 0)
	t.Text = "  " .. name
	t.Font = Enum.Font.Oswald
	t.TextSize = 18
	t.TextColor3 = Color3.new(1, 1, 1)
	t.BackgroundTransparency = 1
	t.TextXAlignment = Enum.TextXAlignment.Left

	local l: TextButton = Instance.new("TextButton", f)
	l.Size = UDim2.new(0, 70, 0.6, 0)
	l.Position = UDim2.new(1, -150, 0.2, 0)
	l.Text = "LOAD"
	l.BackgroundColor3 = Color3.fromRGB(180, 100, 255)
	l.Font = Enum.Font.Oswald
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextSize = 14
	Instance.new("UICorner", l)

	l.MouseButton1Click:Connect(function() 
		self:LoadConfig(name)
		if _G.UpdateSkinsUI then
			_G.UpdateSkinsUI()
		end
		if self.UpdatePreview then
			self.UpdatePreview()
		end 
	end)

	local d: TextButton = Instance.new("TextButton", f)
	d.Size = UDim2.new(0, 70, 0.6, 0)
	d.Position = UDim2.new(1, -75, 0.2, 0)
	d.Text = "DEL"
	d.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
	d.Font = Enum.Font.Oswald
	d.TextColor3 = Color3.new(1, 1, 1)
	d.TextSize = 14
	Instance.new("UICorner", d)

	d.MouseButton1Click:Connect(function() 
		if isfile(path) then
			delfile(path)
		end
		self:RefreshConfigs() 
	end)
	return f
end

function Library:RefreshConfigs(): ()
	if not self.ConfigList then return end
	
	for _, v in pairs(self.ConfigList:GetChildren()) do
		if not v:IsA("Frame") then continue end
		v:Destroy()
	end
	
	for _, path in pairs(listfiles(FolderName)) do
		local name: string = path:match("([^/%\\]+)%.json$") or path
		self:CreateConfigItem(self.ConfigList, name, path)
	end
end

-- [ SECURITY SYSTEM ]
function Library:CreateModNotify(modName: string): ()
	local ui: ScreenGui = CoreGui:FindFirstChild("ModUI") or Instance.new("ScreenGui", CoreGui)
	ui.Name = "ModUI"
	
	local f: Frame = Instance.new("Frame", ui)
	f.Name = "ModNotify"
	f.Size = UDim2.new(0, 260, 0, 130)
	f.Position = UDim2.new(1, 50, 0.5, -65)
	f.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	f.BackgroundTransparency = 0.025
	Instance.new("UICorner", f)
	
	local s: UIStroke = Instance.new("UIStroke", f)
	s.Color = Color3.fromRGB(255, 60, 60)
	s.Thickness = 2
	
	local t: TextLabel = Instance.new("TextLabel", f)
	t.Size = UDim2.new(1, 0, 0, 45)
	t.Text = "🚨 MODERATOR JOINED:\n" .. modName
	t.Font = Enum.Font.Oswald
	t.TextSize = 18
	t.TextColor3 = Color3.new(1, 1, 1)
	t.BackgroundTransparency = 1
	
	local d: TextLabel = Instance.new("TextLabel", f)
	d.Size = UDim2.new(1, 0, 0, 30)
	d.Position = UDim2.new(0, 0, 0, 45)
	d.Text = "Safe save & Leave?"
	d.Font = Enum.Font.Oswald
	d.TextSize = 14
	d.TextColor3 = Color3.fromRGB(200, 200, 200)
	d.BackgroundTransparency = 1
	
	local acc: TextButton = Instance.new("TextButton", f)
	acc.Size = UDim2.new(0, 110, 0, 35)
	acc.Position = UDim2.new(0, 15, 1, -45)
	acc.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	acc.Text = "ACCEPT (SAVE)"
	acc.Font = Enum.Font.Oswald
	acc.TextSize = 14
	acc.TextColor3 = Color3.new(1, 1, 1)
	Instance.new("UICorner", acc)
	
	local dec: TextButton = Instance.new("TextButton", f)
	dec.Size = UDim2.new(0, 110, 0, 35)
	dec.Position = UDim2.new(1, -125, 1, -45)
	dec.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	dec.Text = "DECLINE"
	dec.Font = Enum.Font.Oswald
	dec.TextSize = 14
	dec.TextColor3 = Color3.new(1, 1, 1)
	Instance.new("UICorner", dec)
	
	f:TweenPosition(UDim2.new(1, -270, 0.5, -65), "Out", "Quad", 0.5, true)
	
	acc.MouseButton1Click:Connect(function()
		self:SaveConfig("MOD_Emergency")
		if _G.ServerHop then
			_G.ServerHop()
		end
	end)
	
	dec.MouseButton1Click:Connect(function()
		f:TweenPosition(UDim2.new(1, 50, 0.5, -65), "In", "Quad", 0.5, true, function()
			f:Destroy()
		end)
	end)
end

-- [ UPDATE SYSTEMS ]
function Library:UpdateBindHUD(): ()
	if not BindHUD then return end
	
	for _, v in pairs(BindHUD.List:GetChildren()) do
		if not v:IsA("TextLabel") then continue end
		v:Destroy()
	end
	
	local binds: {any} = {
		{n = "ESP", k = "espEnabled", e = self.Settings.espEnabled},
		{n = "Silent Aim", k = "silentAimEnabled", e = self.Settings.silentAimEnabled},
		{n = "Third Person", k = "thirdPerson", e = self.Settings.thirdPerson},
		{n = "Bhop", k = "bhop", e = self.Settings.bhop},
		{n = "Speed", k = "speedHack", e = self.Settings.speedHack},
		{n = "Fly", k = "fly", e = self.Settings.fly},
		{n = "NoClip", k = "NoClip", e = self.Settings.NoClip},
		{n = "Kill All", k = "killAll", e = self.Settings.killAll},
		{n = "Aspect Ratio", k = "aspectRatio", e = self.Settings.aspectRatio},
		{n = "Trigger Bot", k = "triggerBot", e = self.Settings.triggerBot},
		{n = "Menu", k = "Menu", e = Main.Visible}
	}
	
	local active: number = 0
	for _, data in pairs(binds) do
		local key: any = self.Settings[data.k .. "Bind"] or self.Settings[data.k .. "Key"] or self.Settings[data.k]
		if not (typeof(key) == "EnumItem" and key ~= Enum.KeyCode.Unknown) then continue end
		
		active += 1
		local l: TextLabel = Instance.new("TextLabel", BindHUD.List)
		l.Size = UDim2.new(1, -5, 0, 22)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Oswald
		l.TextSize = 14
		l.TextColor3 = data.e and Color3.fromRGB(180, 100, 255) or Color3.fromRGB(150, 150, 150)
		l.Text = string.format(" %s: %s [%s]", data.n, data.e and "ON" or "OFF", key.Name)
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.ZIndex = 10
	end
	BindHUD.Visible = active > 0
end

function Library:UpdateSpecList(): ()
	if not SpecFrame then return end
	
	for _, v in pairs(SpecFrame.List:GetChildren()) do
		if not v:IsA("TextLabel") then continue end
		v:Destroy()
	end
	
	if not self.Settings.showSpecList then
		SpecFrame.Visible = false
		return
	end
	SpecFrame.Visible = true
	
	for _, v: Player in pairs(Players:GetPlayers()) do
		if v == LocalPlayer then continue end
		local s = v:FindFirstChild("Status")
		if not s then continue end
		
		if (s:FindFirstChild("Team") and s.Team.Value == "Spectator") or (s:FindFirstChild("Alive") and s.Alive.Value == false) then
			local t: TextLabel = Instance.new("TextLabel", SpecFrame.List)
			t.Size = UDim2.new(1, 0, 0, 20)
			t.BackgroundTransparency = 0.5
			t.Text = v.Name
			t.BackgroundColor3 = Color3.fromRGB(16, 22, 32)
			t.TextColor3 = Color3.new(1, 1, 1)
			t.Font = Enum.Font.Oswald
			t.TextSize = 15
			Instance.new("UICorner", t)
		end
	end
end

-- [ INTERNAL UPDATE ]
function Library:UpdateVisuals(): ()
	self:UpdateBindHUD()
	
	local s = self.Settings
	local cam: Camera = workspace.CurrentCamera
	local screenCenter: Vector2 = cam.ViewportSize / 2
	
	-- FOV Drawings
	if FOVCircle then
		local vis: boolean = s.showFOV and s.silentAimEnabled
		FOVCircle.Visible = vis
		if vis then
			FOVCircle.Position = screenCenter
			FOVCircle.Radius = s.silentAimFOV
		end
	end
	
	if TriggerCircle then
		local vis: boolean = s.showTriggerFOV and s.triggerBot
		TriggerCircle.Visible = vis
		if vis then
			TriggerCircle.Position = screenCenter
			TriggerCircle.Radius = s.triggerFOV
		end
	end

	-- ESP Preview
	if Preview and PBox then
		local en: boolean = s.espEnabled
		PBox.Visible = en and s.showBox
		PBoxStroke.Color = typeof(s.boxColor) == "Color3" and s.boxColor or Color3.new(unpack(s.boxColor))
		
		PName.Visible = en and s.showNames
		PName.TextColor3 = typeof(s.nameColor) == "Color3" and s.nameColor or Color3.new(unpack(s.nameColor))
		
		PHPBar.Visible = en and s.healthBar
		PHit.BackgroundColor3 = typeof(s.hpBarColor) == "Color3" and s.hpBarColor or Color3.new(unpack(s.hpBarColor))
		
		PTracer.Visible = en and s.showTracers
		PTracer.BackgroundColor3 = typeof(s.tracerColor) == "Color3" and s.tracerColor or Color3.new(unpack(s.tracerColor))
		
		local pw: any = PBox:FindFirstChild("WeaponPreview")
		if pw then
			pw.Visible = en and s.showWeaponText
			pw.TextColor3 = typeof(s.weaponTextColor) == "Color3" and s.weaponTextColor or Color3.new(unpack(s.weaponTextColor))
		end
		
		PSkel.Visible = en and s.showSkeleton
		for _, v in pairs(PSkel:GetChildren()) do
			if v:IsA("Frame") then
				v.BackgroundColor3 = typeof(s.skeletonColor) == "Color3" and s.skeletonColor or Color3.new(unpack(s.skeletonColor))
			end
		end
	end
end

return Library
