local Players = game:GetService("Players")
local InputService = game:GetService("UserInputService")

local LPlayer = Players.LocalPlayer
local PlayerGui = LPlayer:WaitForChild("PlayerGui")

local TaskAPI = {
	Categories = {},
	Version = { "1.0.0" }
}

local TaskAssets = {
	CategoryFrame = "rbxassetid://126645359069961",
	Shadow = "rbxassetid://125043055375567"
}

getgenv().TaskClient = getgenv().TaskClient or {}
getgenv().TaskClient.API = TaskAPI

if PlayerGui:FindFirstChild("MainUI") then
	PlayerGui.MainUI:Destroy()
end

local TaskGui = Instance.new("ScreenGui")
TaskGui.Name = "MainUI"
TaskGui.Enabled = true
TaskGui.ResetOnSpawn = false
TaskGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
TaskGui.Parent = PlayerGui

TaskAPI.ScreenGui = TaskGui

function TaskAPI:CreateCategory(categoryData)
	if not categoryData or type(categoryData.Name) ~= "string" or categoryData.Name == "" then
		error("TaskAPI:CreateCategory requires a category name")
	end

	for _, existingCategory in ipairs(self.Categories) do
		if existingCategory.Name == categoryData.Name then
			error(("TaskAPI category '%s' already exists"):format(categoryData.Name))
		end
	end

	local taskFrame = Instance.new("Frame")
	taskFrame.Name = "TaskFrame_" .. categoryData.Name
	taskFrame.Size = categoryData.Size or UDim2.new(0, 165, 0, 82)
	taskFrame.Position = categoryData.Position or UDim2.new(0.5, -82, 0.5, -41)
	taskFrame.BackgroundColor3 = categoryData.BackgroundColor3 or Color3.fromRGB(0, 0, 0)
	taskFrame.BorderSizePixel = 0
	taskFrame.ZIndex = 2
	taskFrame.Parent = TaskGui

	local taskFrameCorner = Instance.new("UICorner")
	taskFrameCorner.CornerRadius = UDim.new(0, 10)
	taskFrameCorner.Parent = taskFrame

	local shadowEffect = Instance.new("ImageLabel")
	shadowEffect.Name = "SEffect"
	shadowEffect.Size = UDim2.new(0, 190, 0, 105)
	shadowEffect.Position = UDim2.new(0, -13, 0, -11)
	shadowEffect.BackgroundTransparency = 1
	shadowEffect.Image = TaskAssets.Shadow
	shadowEffect.ZIndex = 1
	shadowEffect.Parent = taskFrame

	local categoryFrame = Instance.new("ImageLabel")
	categoryFrame.Name = "CategoryFrame"
	categoryFrame.Size = UDim2.new(1, 0, 0, 40)
	categoryFrame.Position = UDim2.new(0, 0, 0, 0)
	categoryFrame.Active = true
	categoryFrame.BackgroundTransparency = 1
	categoryFrame.Image = TaskAssets.CategoryFrame
	categoryFrame.ZIndex = 3
	categoryFrame.Parent = taskFrame

	local categoryLabel = Instance.new("TextLabel")
	categoryLabel.Name = "CategoryText"
	categoryLabel.Size = UDim2.new(1, 0, 1, 0)
	categoryLabel.Active = false
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
	moduleFrame.BackgroundColor3 = Color3.fromHex("#111111")
	moduleFrame.BorderSizePixel = 0
	moduleFrame.ZIndex = 3
	moduleFrame.Parent = taskFrame

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
		startPosition = taskFrame.Position
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
		taskFrame.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end)

	local category = {
		Name = categoryData.Name,
		TaskFrame = taskFrame,
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