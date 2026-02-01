local Library = {}
Library.Settings = {}
Library.UpdatePreview = function() end

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

function Library:MakeDraggable(gui)
	local dragging, dragInput, dragStart, startPos
	local function update(input)
		local delta = input.Position - dragStart
		gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
	gui.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart, startPos = input.Position, gui.Position
			input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
		end
	end)
	gui.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)
	UserInputService.InputChanged:Connect(function(input) if input == dragInput and dragging then update(input) end end)
end

function Library:CreateTitle(parent, text)
	local frame = Instance.new("Frame", parent)
	frame.Size, frame.BackgroundTransparency = UDim2.new(1, -20, 0, 30), 1
	local label = Instance.new("TextLabel", frame)
	label.Size, label.Text = UDim2.new(1, 0, 1, 0), text:upper()
	label.Font, label.TextSize, label.TextColor3 = Enum.Font.Oswald, 14, Color3.fromRGB(180, 100, 255)
	label.TextXAlignment, label.BackgroundTransparency = Enum.TextXAlignment.Left, 1
	local line = Instance.new("Frame", frame)
	line.Size, line.Position, line.BackgroundColor3, line.BackgroundTransparency = UDim2.new(1, 0, 0, 1), UDim2.new(0, 0, 1, -2), Color3.fromRGB(180, 100, 255), 0.6
	Instance.new("UIGradient", line).Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(0.8,0), NumberSequenceKeypoint.new(1,1)})
	return frame
end

function Library:CreateButton(parent, text, color, callback)
	local frame = Instance.new("Frame", parent); frame.Size, frame.BackgroundTransparency = UDim2.new(1, -20, 0, 45), 1
	local btn = Instance.new("TextButton", frame); btn.Size, btn.Position = UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0.5, -20)
	btn.BackgroundColor3, btn.Text = color, text
	btn.Font, btn.TextSize, btn.TextColor3 = Enum.Font.Oswald, 18, Color3.new(1, 1, 1)
	btn.AutoButtonColor = true; Instance.new("UICorner", btn)
	btn.MouseButton1Click:Connect(function() if type(callback) == "function" then callback() end end)
	return btn
end

function Library:CreateSwitch(parent, name, settingKey, extra)
	local frame = Instance.new("Frame", parent); frame.Size, frame.BackgroundTransparency = UDim2.new(0.95, 0, 0, 40), 1
	local label = Instance.new("TextLabel", frame); label.Size, label.Text, label.Font, label.TextSize, label.TextColor3, label.TextXAlignment, label.BackgroundTransparency = UDim2.new(1, -100, 1, 0), name, Enum.Font.Oswald, 18, Color3.new(1,1,1), Enum.TextXAlignment.Left, 1
	local bg = Instance.new("TextButton", frame); bg.Size, bg.Position, bg.AutoButtonColor = UDim2.new(0, 40, 0, 20), UDim2.new(1, -30, 0.5, -10), false; Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)
	local circ = Instance.new("Frame", bg); circ.Size, circ.BackgroundColor3 = UDim2.new(0, 16, 0, 16), Color3.new(1, 1, 1); Instance.new("UICorner", circ).CornerRadius = UDim.new(1, 0)
	
	bg.MouseButton1Click:Connect(function()
		self.Settings[settingKey] = not self.Settings[settingKey]
		if self.UpdatePreview then self.UpdatePreview() end
		if type(extra) == "function" then extra(self.Settings[settingKey]) end
	end)
	
	RunService.RenderStepped:Connect(function()
		circ.Position = self.Settings[settingKey] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
		bg.BackgroundColor3 = self.Settings[settingKey] and Color3.fromRGB(180, 100, 255) or Color3.fromRGB(40, 45, 55)
	end)
	
	if type(extra) == "string" and self.Settings[extra] then
		local cp = Instance.new("TextButton", frame); cp.Size, cp.Position, cp.BackgroundColor3, cp.Text = UDim2.new(0, 22, 0, 22), UDim2.new(1, -60, 0.5, -11), Color3.new(unpack(self.Settings[extra])), ""; Instance.new("UICorner", cp)
		-- Примечание: тут логика пикера упрощена для либки, но в Main она будет работать через настройки
		RunService.RenderStepped:Connect(function() cp.BackgroundColor3 = Color3.new(unpack(self.Settings[extra])) end)
	end
end

function Library:CreateSlider(parent, name, settingKey, min, max, slidingAmount)
	local step = slidingAmount or 1
	local frame = Instance.new("Frame", parent); frame.Size, frame.BackgroundTransparency = UDim2.new(1, -20, 0, 50), 1
	local label = Instance.new("TextLabel", frame); label.Size, label.Text, label.Font, label.TextSize, label.TextColor3, label.TextXAlignment, label.BackgroundTransparency = UDim2.new(1, -60, 0, 20), name, Enum.Font.Oswald, 16, Color3.new(0.8, 0.8, 0.8), Enum.TextXAlignment.Left, 1
	local sbg = Instance.new("Frame", frame); sbg.Size, sbg.Position, sbg.BackgroundColor3 = UDim2.new(1, 0, 0, 6), UDim2.new(0, 0, 1, -15), Color3.fromRGB(40, 45, 55); Instance.new("UICorner", sbg)
	local fill = Instance.new("Frame", sbg); fill.Size, fill.BackgroundColor3 = UDim2.new(0,0,1,0), Color3.fromRGB(180, 100, 255); Instance.new("UICorner", fill)
	local val = Instance.new("TextBox", frame); val.Size, val.Position, val.Font, val.TextSize, val.TextColor3, val.BackgroundTransparency, val.BackgroundColor3 = UDim2.new(0, 50, 0, 20), UDim2.new(1, -50, 0, 0), Enum.Font.Oswald, 14, Color3.new(1, 1, 1), 0.5, Color3.fromRGB(40, 45, 55)
	val.Text, val.ClearTextOnFocus = tostring(self.Settings[settingKey]), false
	
	local function updateUI(newValue)
		local clamped = math.clamp(newValue, min, max)
		fill.Size = UDim2.new((clamped - min) / (max - min), 0, 1, 0)
		if not val:IsFocused() then val.Text = tostring(math.floor(clamped * 100) / 100) end
	end
	
	RunService.RenderStepped:Connect(function() updateUI(self.Settings[settingKey]) end)
	
	val.FocusLost:Connect(function()
		local inputVal = tonumber(val.Text)
		if inputVal then self.Settings[settingKey] = math.clamp(math.round(inputVal / step) * step, min, max)
		else val.Text = tostring(math.floor(self.Settings[settingKey] * 100) / 100) end
	end)

	local function updateFromMouse(input)
		local pos = math.clamp((input.Position.X - sbg.AbsolutePosition.X) / sbg.AbsoluteSize.X, 0, 1)
		self.Settings[settingKey] = math.clamp(math.round((min + (max - min) * pos) / step) * step, min, max)
	end
	
	sbg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local conn; conn = UserInputService.InputChanged:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseMovement then updateFromMouse(i) end end)
			updateFromMouse(input)
			UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 and conn then conn:Disconnect() end end)
		end
	end)
end

function Library:CreateBind(parent, text, settingKey)
	local frame = Instance.new("Frame", parent); frame.Size, frame.BackgroundTransparency = UDim2.new(1, -20, 0, 35), 1
	local label = Instance.new("TextLabel", frame); label.Size, label.Text, label.Font, label.TextSize, label.TextColor3, label.TextXAlignment, label.BackgroundTransparency = UDim2.new(1, 0, 1, 0), text, Enum.Font.Oswald, 16, Color3.new(0.8, 0.8, 0.8), Enum.TextXAlignment.Left, 1
	local btn = Instance.new("TextButton", frame); btn.Size, btn.Position = UDim2.new(0, 80, 0, 25), UDim2.new(1, -80, 0.5, -12); btn.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
	btn.Font, btn.TextSize, btn.TextColor3 = Enum.Font.Oswald, 14, Color3.new(1, 1, 1); Instance.new("UICorner", btn)
	
	local function UpdateText() local val = self.Settings[settingKey]; btn.Text = (typeof(val) == "EnumItem") and val.Name or "None" end
	task.spawn(function() while frame.Parent do UpdateText(); task.wait(0.5) end end)
	
	btn.MouseButton1Click:Connect(function()
		btn.Text = "..."; btn.TextColor3 = Color3.fromRGB(180, 100, 255)
		local conn; conn = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				self.Settings[settingKey] = (input.KeyCode == Enum.KeyCode.Escape) and Enum.KeyCode.Unknown or input.KeyCode
				UpdateText(); btn.TextColor3 = Color3.new(1, 1, 1); conn:Disconnect()
			end
		end)
	end)
	return frame
end

function Library:CreateDropdown(parent: any, text: string, options: {string}, configTable: any, configKey: string): Frame
	local dropdownFrame: Frame = Instance.new("Frame", parent)
	dropdownFrame.Size, dropdownFrame.BackgroundTransparency = UDim2.new(1, -20, 0, 35), 1
	dropdownFrame.ZIndex = 5

	local label: TextLabel = Instance.new("TextLabel", dropdownFrame)
	label.Size, label.Text = UDim2.new(0.4, 0, 1, 0), text
	label.Font, label.TextSize, label.TextColor3 = Enum.Font.Oswald, 16, Color3.new(0.8, 0.8, 0.8)
	label.TextXAlignment, label.BackgroundTransparency = Enum.TextXAlignment.Left, 1

	local mainBtn: TextButton = Instance.new("TextButton", dropdownFrame)
	mainBtn.Size, mainBtn.Position = UDim2.new(0.35, 0, 0, 28), UDim2.new(1, -195, 0.5, -14)
	mainBtn.BackgroundColor3, mainBtn.Text = Color3.fromRGB(20, 26, 38), configTable[configKey]
	mainBtn.Font, mainBtn.TextSize, mainBtn.TextColor3 = Enum.Font.Oswald, 14, Color3.new(1, 1, 1)
	mainBtn.AutoButtonColor = false
	Instance.new("UICorner", mainBtn)

	local stroke: UIStroke = Instance.new("UIStroke", mainBtn)
	stroke.Color, stroke.Thickness, stroke.ApplyStrokeMode = Color3.fromRGB(40, 45, 60), 1, Enum.ApplyStrokeMode.Border

	local list: Frame = Instance.new("Frame", mainBtn)
	list.Name = "List"
	list.Size, list.Position, list.Visible = UDim2.new(1, 0, 0, 0), UDim2.new(0, 0, 1, 5), false
	list.BackgroundColor3, list.BorderSizePixel, list.ZIndex = Color3.fromRGB(16, 22, 32), 0, 100
	Instance.new("UICorner", list)

	local listLayout: UIListLayout = Instance.new("UIListLayout", list)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder

	mainBtn.MouseButton1Click:Connect(function()
		list.Visible = not list.Visible
		if list.Visible then
			list.Size = UDim2.new(1, 0, 0, #options * 28)
			stroke.Color = Color3.fromRGB(180, 100, 255)
			dropdownFrame.ZIndex = 10
		else
			stroke.Color = Color3.fromRGB(40, 45, 60)
			dropdownFrame.ZIndex = 5
		end
	end)
	
	for _, opt in pairs(options) do
		local optBtn: TextButton = Instance.new("TextButton", list)
		optBtn.Name, optBtn.Size, optBtn.Text = opt, UDim2.new(1, 0, 0, 28), opt
		optBtn.BackgroundColor3, optBtn.BackgroundTransparency = Color3.fromRGB(25, 30, 45), 1
		optBtn.Font, optBtn.TextSize, optBtn.TextColor3, optBtn.ZIndex = Enum.Font.Oswald, 14, Color3.new(0.6, 0.6, 0.6), 101
		optBtn.MouseEnter:Connect(function()
			optBtn.BackgroundTransparency = 0.8
			optBtn.TextColor3 = Color3.new(1, 1, 1)
		end)
		
		optBtn.MouseLeave:Connect(function()
			optBtn.BackgroundTransparency = 1
			optBtn.TextColor3 = Color3.new(0.6, 0.6, 0.6)
		end)
		
		optBtn.MouseButton1Click:Connect(function()
			mainBtn.Text = opt
			list.Visible = false
			stroke.Color = Color3.fromRGB(40, 45, 60)
			dropdownFrame.ZIndex = 5
			configTable[configKey] = opt

			if self.UpdatePreview then
				self.UpdatePreview()
			end
		end)
	end
	
	return dropdownFrame
end

return Library
