local Players = game:GetService("Players")
local InputService = game:GetService("UserInputService")

local LPlayer = Players.LocalPlayer
local PlayerGui = LPlayer:WaitForChild("PlayerGui")

local TaskAPI = {
	Categories = {},
	Version = { "1.0.0" }
}

getgenv().TaskClient = getgenv().TaskClient or {}
getgenv().TaskClient.API = TaskAPI

if PlayerGui:FindFirstChild("MainUI") then
	PlayerGui.MainUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MainUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

TaskAPI.ScreenGui = ScreenGui

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

	for _, existingCategory in ipairs(self.Categories) do
		if existingCategory.Name == categoryData.Name then
			error(("TaskAPI category '%s' already exists"):format(categoryData.Name))
		end
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

	local moduleFrame = Instance.new("Frame")
	moduleFrame.Name = "Module"
	moduleFrame.Size = UDim2.new(1, 0, 0, 35)
	moduleFrame.Position = UDim2.new(0, 0, 0, 40)
	moduleFrame.BackgroundColor3 = categoryData.ModuleBackgroundColor3 or Color3.fromRGB(17, 17, 17)
	moduleFrame.BorderSizePixel = 0
	moduleFrame.ZIndex = 3
	moduleFrame.Parent = mainFrame

	local moduleLabel = Instance.new("TextLabel")
	moduleLabel.Name = "ModuleText"
	moduleLabel.Size = UDim2.new(1, 0, 1, 0)
	moduleLabel.BackgroundTransparency = 1
	moduleLabel.Text = categoryData.ModuleName or "Module"
	moduleLabel.TextSize = 16
	moduleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	moduleLabel.TextXAlignment = Enum.TextXAlignment.Center
	moduleLabel.TextYAlignment = Enum.TextYAlignment.Center
	moduleLabel.Font = Enum.Font.GothamBold
	moduleLabel.ZIndex = 4
	moduleLabel.Parent = moduleFrame

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
	end)

	local category = {
		Name = categoryData.Name,
		Position = categoryPosition,
		AnchorPoint = categoryAnchorPoint,
		MainFrame = mainFrame,
		TaskFrame = mainFrame,
		SEffect = sEffect,
		CategoryFrame = categoryFrame,
		CategoryLabel = categoryLabel,
		ModuleFrame = moduleFrame,
		ModuleLabel = moduleLabel
	}

	table.insert(self.Categories, category)

	return category
end

getgenv().TaskAPI = TaskAPI

return TaskAPI
