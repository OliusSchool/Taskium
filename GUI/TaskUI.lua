local Players = game:GetService("Players")
local InputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local LPlayer = Players.LocalPlayer
local PlayerGui = LPlayer:WaitForChild("PlayerGui")

local TaskAPI = {
	Categories = {},
	CategoryList = {},
	Modules = {},
	Version = { "1.0.0" }
}

getgenv().TaskClient = getgenv().TaskClient or {}
getgenv().TaskClient.API = TaskAPI
getgenv().TaskAPI = TaskAPI

if PlayerGui:FindFirstChild("MainUI") then
	PlayerGui.MainUI:Destroy()
end

if Lighting:FindFirstChild("TaskUIBlur") then
	Lighting.TaskUIBlur:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MainUI"
ScreenGui.Enabled = false
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local BlurEffect = Instance.new("BlurEffect")
BlurEffect.Name = "TaskUIBlur"
BlurEffect.Size = 20
BlurEffect.Enabled = false
BlurEffect.Parent = Lighting

TaskAPI.ScreenGui = ScreenGui
TaskAPI.BlurEffect = BlurEffect

local function cleanupItem(item)
	local itemType = typeof(item)

	if itemType == "RBXScriptConnection" then
		if item.Connected then
			item:Disconnect()
		end
		return
	end

	if itemType == "Instance" then
		if item.Parent then
			item:Destroy()
		end
		return
	end

	if type(item) == "function" then
		pcall(item)
		return
	end

	if type(item) == "table" then
		if type(item.Disconnect) == "function" then
			pcall(function()
				item:Disconnect()
			end)
			return
		end

		if type(item.Destroy) == "function" then
			pcall(function()
				item:Destroy()
			end)
		end
	end
end

local function updateShadowSize(category)
	local widthOffset = category.MainFrame.Size.X.Offset
	local heightOffset = category.MainFrame.Size.Y.Offset

	category.SEffect.Size = UDim2.new(0, widthOffset + 25, 0, heightOffset + 23)
end

local function updateCategorySize(category)
	local moduleCount = #category.ModuleList
	local baseHeight = 40
	local moduleHeight = 35
	local visibleModuleRows = math.max(1, moduleCount)
	local defaultHeight = category.DefaultSize.Y.Offset
	local contentHeight = baseHeight + (visibleModuleRows * moduleHeight)
	local totalHeight = math.max(defaultHeight, contentHeight)
	local bodyHeight = totalHeight - baseHeight

	category.MainFrame.Size = UDim2.new(
		category.MainFrame.Size.X.Scale,
		category.MainFrame.Size.X.Offset,
		0,
		totalHeight
	)

	category.BodyFrame.Size = UDim2.new(1, 0, 0, bodyHeight)
	category.ModulesHolder.Size = UDim2.new(1, 0, 0, moduleCount * moduleHeight)
	updateShadowSize(category)
end

local function refreshModuleDisplay(module)
	if module.Button == nil or module.Button.Parent == nil then
		return
	end

	module.Button.BackgroundColor3 = module.Enabled and Color3.fromRGB(36, 36, 36) or Color3.fromRGB(17, 17, 17)
	module.Button.TextColor3 = module.Enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(205, 205, 205)

	local extraText = ""
	if type(module.ExtraText) == "function" then
		local ok, result = pcall(module.ExtraText)
		if ok and result ~= nil then
			extraText = tostring(result)
		end
	elseif module.ExtraText ~= nil then
		extraText = tostring(module.ExtraText)
	end

	module.ExtraLabel.Text = extraText
end

function TaskAPI:CreateCategory(categoryData)
	if not categoryData or type(categoryData.Name) ~= "string" or categoryData.Name == "" then
		error("TaskAPI:CreateCategory requires a category name")
	end

	if categoryData.Position and typeof(categoryData.Position) ~= "UDim2" then
		error("TaskAPI:CreateCategory requires Position to be a UDim2")
	end

	if categoryData.AnchorPoint and typeof(categoryData.AnchorPoint) ~= "Vector2" then
		error("TaskAPI:CreateCategory requires AnchorPoint to be a Vector2")
	end

	if self.Categories[categoryData.Name] then
		error(("TaskAPI category '%s' already exists"):format(categoryData.Name))
	end

	local categoryPosition = categoryData.Position or UDim2.new(0, 0, 0, 0)
	local categoryAnchorPoint = categoryData.AnchorPoint or Vector2.new(0, 0)

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame_" .. categoryData.Name
	mainFrame.Size = categoryData.Size or UDim2.new(0, 165, 0, 82)
	mainFrame.AnchorPoint = categoryAnchorPoint
	mainFrame.Position = categoryPosition
	mainFrame.BackgroundColor3 = categoryData.BackgroundColor3 or Color3.fromRGB(0, 0, 0)
	mainFrame.BorderSizePixel = 0
	mainFrame.ZIndex = 2
	mainFrame.Parent = ScreenGui

	local mainFrameCorner = Instance.new("UICorner")
	mainFrameCorner.CornerRadius = UDim.new(0, 10)
	mainFrameCorner.Parent = mainFrame

	local sEffect = Instance.new("ImageLabel")
	sEffect.Name = "SEffect"
	sEffect.Size = UDim2.new(0, 190, 0, 105)
	sEffect.Position = UDim2.new(0, -13, 0, -11)
	sEffect.BackgroundTransparency = 1
	sEffect.Image = "rbxassetid://125043055375567"
	sEffect.ZIndex = 1
	sEffect.Parent = mainFrame

	local categoryFrame = Instance.new("ImageLabel")
	categoryFrame.Name = "CategoryFrame"
	categoryFrame.Size = UDim2.new(1, 0, 0, 40)
	categoryFrame.Position = UDim2.new(0, 0, 0, 0)
	categoryFrame.Active = true
	categoryFrame.BackgroundTransparency = 1
	categoryFrame.Image = categoryData.CategoryImage or "rbxassetid://126645359069961"
	categoryFrame.ImageColor3 = categoryData.CategoryColor3 or Color3.fromRGB(255, 255, 255)
	categoryFrame.ZIndex = 3
	categoryFrame.Parent = mainFrame

	local categoryLabel = Instance.new("TextLabel")
	categoryLabel.Name = "CategoryText"
	categoryLabel.Size = UDim2.new(1, 0, 1, 0)
	categoryLabel.BackgroundTransparency = 1
	categoryLabel.Text = categoryData.Name
	categoryLabel.TextSize = 18
	categoryLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	categoryLabel.TextXAlignment = Enum.TextXAlignment.Center
	categoryLabel.TextYAlignment = Enum.TextYAlignment.Center
	categoryLabel.Font = Enum.Font.GothamBold
	categoryLabel.ZIndex = 4
	categoryLabel.Parent = categoryFrame

	local bodyFrame = Instance.new("Frame")
	bodyFrame.Name = "BodyFrame"
	bodyFrame.Size = UDim2.new(1, 0, 0, 35)
	bodyFrame.Position = UDim2.new(0, 0, 0, 40)
	bodyFrame.BackgroundColor3 = categoryData.ModuleBackgroundColor3 or Color3.fromRGB(17, 17, 17)
	bodyFrame.BorderSizePixel = 0
	bodyFrame.ZIndex = 3
	bodyFrame.Parent = mainFrame

	local bodyFrameCorner = Instance.new("UICorner")
	bodyFrameCorner.CornerRadius = UDim.new(0, 10)
	bodyFrameCorner.Parent = bodyFrame

	local modulesHolder = Instance.new("Frame")
	modulesHolder.Name = "ModulesHolder"
	modulesHolder.Size = UDim2.new(1, 0, 0, 0)
	modulesHolder.Position = UDim2.new(0, 0, 0, 0)
	modulesHolder.BackgroundTransparency = 1
	modulesHolder.ZIndex = 4
	modulesHolder.Parent = bodyFrame

	local modulesLayout = Instance.new("UIListLayout")
	modulesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	modulesLayout.Padding = UDim.new(0, 0)
	modulesLayout.Parent = modulesHolder

	local category = {
		Name = categoryData.Name,
		Position = categoryPosition,
		AnchorPoint = categoryAnchorPoint,
		DefaultSize = categoryData.Size or UDim2.new(0, 165, 0, 82),
		MainFrame = mainFrame,
		TaskFrame = mainFrame,
		SEffect = sEffect,
		CategoryFrame = categoryFrame,
		CategoryLabel = categoryLabel,
		BodyFrame = bodyFrame,
		ModulesHolder = modulesHolder,
		ModuleList = {},
		Modules = {}
	}

	function category:CreateModule(moduleData)
		if not moduleData or type(moduleData.Name) ~= "string" or moduleData.Name == "" then
			error(("TaskAPI category '%s' requires a valid module name"):format(self.Name))
		end

		if self.Modules[moduleData.Name] then
			error(("Module '%s' already exists in category '%s'"):format(moduleData.Name, self.Name))
		end

		if moduleData.Function ~= nil and type(moduleData.Function) ~= "function" then
			error(("Module '%s' Function must be a function"):format(moduleData.Name))
		end

		local moduleButton = Instance.new("TextButton")
		moduleButton.Name = moduleData.Name
		moduleButton.Size = UDim2.new(1, 0, 0, 35)
		moduleButton.BackgroundColor3 = Color3.fromRGB(17, 17, 17)
		moduleButton.BorderSizePixel = 0
		moduleButton.AutoButtonColor = false
		moduleButton.Text = moduleData.Name
		moduleButton.TextSize = 16
		moduleButton.TextColor3 = Color3.fromRGB(205, 205, 205)
		moduleButton.TextXAlignment = Enum.TextXAlignment.Left
		moduleButton.TextYAlignment = Enum.TextYAlignment.Center
		moduleButton.Font = Enum.Font.GothamBold
		moduleButton.ZIndex = 4
		moduleButton.Parent = self.ModulesHolder

		local buttonPadding = Instance.new("UIPadding")
		buttonPadding.PaddingLeft = UDim.new(0, 10)
		buttonPadding.PaddingRight = UDim.new(0, 10)
		buttonPadding.Parent = moduleButton

		local extraLabel = Instance.new("TextLabel")
		extraLabel.Name = "ExtraText"
		extraLabel.Size = UDim2.new(0.45, 0, 1, 0)
		extraLabel.Position = UDim2.new(0.55, 0, 0, 0)
		extraLabel.BackgroundTransparency = 1
		extraLabel.Text = ""
		extraLabel.TextSize = 14
		extraLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
		extraLabel.TextXAlignment = Enum.TextXAlignment.Right
		extraLabel.TextYAlignment = Enum.TextYAlignment.Center
		extraLabel.Font = Enum.Font.Gotham
		extraLabel.ZIndex = 5
		extraLabel.Parent = moduleButton

		local module = {
			Name = moduleData.Name,
			Enabled = false,
			Function = moduleData.Function,
			ExtraText = moduleData.ExtraText,
			Tooltip = moduleData.Tooltip,
			Button = moduleButton,
			ExtraLabel = extraLabel,
			Category = self,
			Cleanups = {}
		}

		function module:Clean(item)
			table.insert(self.Cleanups, item)
			return item
		end

		function module:Cleanup()
			for index = #self.Cleanups, 1, -1 do
				cleanupItem(self.Cleanups[index])
				table.remove(self.Cleanups, index)
			end
		end

		function module:SetEnabled(state)
			state = not not state
			if self.Enabled == state then
				return
			end

			self.Enabled = state
			refreshModuleDisplay(self)

			if self.Function then
				task.spawn(function()
					local ok, err = pcall(self.Function, state)
					if not ok then
						warn(("TaskAPI module '%s' failed: %s"):format(self.Name, tostring(err)))
					end
				end)
			end

			if not self.Enabled then
				self:Cleanup()
			end
		end

		function module:Toggle()
			self:SetEnabled(not self.Enabled)
		end

		moduleButton.MouseButton1Click:Connect(function()
			module:Toggle()
		end)

		task.spawn(function()
			while moduleButton.Parent do
				refreshModuleDisplay(module)
				task.wait(0.15)
			end
		end)

		table.insert(self.ModuleList, module)
		self.Modules[module.Name] = module
		TaskAPI.Modules[module.Name] = module

		updateCategorySize(self)
		refreshModuleDisplay(module)

		return module
	end

	local dragging = false
	local dragStart
	local startPosition

	categoryFrame.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		dragging = true
		dragStart = input.Position
		startPosition = mainFrame.Position
	end)

	categoryFrame.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
			category.Position = mainFrame.Position
		end
	end)

	InputService.InputChanged:Connect(function(input)
		if not dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end

		local delta = input.Position - dragStart
		mainFrame.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
		category.Position = mainFrame.Position
	end)

	self.Categories[category.Name] = category
	table.insert(self.CategoryList, category)
	updateCategorySize(category)

	return category
end

InputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.RightShift then
		ScreenGui.Enabled = not ScreenGui.Enabled
		BlurEffect.Enabled = ScreenGui.Enabled
	end
end)

return TaskAPI
