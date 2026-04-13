local Players = game:GetService("Players")
local InputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local LPlayer = Players.LocalPlayer
local PlayerGui = LPlayer:WaitForChild("PlayerGui")

local TaskAPI = {
	Categories = {},
	CategoryList = {},
	Modules = {},
	Notifications = {},
	Version = { "1.0.0" }
}

local TaskAssets = {
	CategoryFrame = "rbxassetid://126645359069961",
	Shadow = "rbxassetid://125043055375567",
	NotificationFrame = "rbxassetid://123298087495168"
}

local NotificationColors = {
	Client = Color3.fromRGB(255, 255, 255),
	Success = Color3.fromRGB(46, 204, 113),
	Error = Color3.fromRGB(231, 76, 60),
	Warning = Color3.fromRGB(241, 196, 15),
	Info = Color3.fromRGB(52, 152, 219)
}

getgenv().TaskClient = getgenv().TaskClient or {}
getgenv().TaskClient.API = TaskAPI
getgenv().TaskAPI = TaskAPI

if PlayerGui:FindFirstChild("MainUI") then
	PlayerGui.MainUI:Destroy()
end

if PlayerGui:FindFirstChild("TaskNotifications") then
	PlayerGui.TaskNotifications:Destroy()
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

local NotificationGui = Instance.new("ScreenGui")
NotificationGui.Name = "TaskNotifications"
NotificationGui.ResetOnSpawn = false
NotificationGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
NotificationGui.Parent = PlayerGui

local NotificationsContainer = Instance.new("Frame")
NotificationsContainer.Name = "NotificationsContainer"
NotificationsContainer.Size = UDim2.new(0, 290, 0.4, 0)
NotificationsContainer.AnchorPoint = Vector2.new(1, 1)
NotificationsContainer.Position = UDim2.new(1, -8, 1, -8)
NotificationsContainer.BackgroundTransparency = 1
NotificationsContainer.Parent = NotificationGui

local NotificationListLayout = Instance.new("UIListLayout")
NotificationListLayout.SortOrder = Enum.SortOrder.LayoutOrder
NotificationListLayout.Padding = UDim.new(0, 10)
NotificationListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
NotificationListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
NotificationListLayout.Parent = NotificationsContainer

TaskAPI.ScreenGui = ScreenGui
TaskAPI.BlurEffect = BlurEffect
TaskAPI.NotificationGui = NotificationGui
TaskAPI.NotificationsContainer = NotificationsContainer

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
	category.ContainerFrame.Size = category.MainFrame.Size
end

local function normalizeNotificationData(title, message, duration, notificationType)
	if type(title) == "table" then
		return {
			Title = tostring(title.Title or title.Name or "Notification"),
			Message = tostring(title.Message or "No message has been set for this notification."),
			Duration = tonumber(title.Duration) or 3,
			Type = title.Type or "Client"
		}
	end

	return {
		Title = tostring(title or "Notification"),
		Message = tostring(message or "No message has been set for this notification."),
		Duration = tonumber(duration) or 3,
		Type = notificationType or "Client"
	}
end

function TaskAPI.Notification(title, message, duration, notificationType)
	local notificationData = normalizeNotificationData(title, message, duration, notificationType)
	local accentColor = NotificationColors[notificationData.Type] or NotificationColors.Info

	local holder = Instance.new("Frame")
	holder.Name = "NotificationHolder"
	holder.Size = UDim2.new(0, 270, 0, 60)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.ClipsDescendants = true
	holder.LayoutOrder = #TaskAPI.Notifications + 1
	holder.Parent = NotificationsContainer

	local notificationFrame = Instance.new("ImageLabel")
	notificationFrame.Name = "NotificationFrame"
	notificationFrame.Size = UDim2.new(0, 270, 0, 60)
	notificationFrame.Position = UDim2.new(1, 0, 0, 0)
	notificationFrame.BackgroundTransparency = 1
	notificationFrame.Image = TaskAssets.NotificationFrame
	notificationFrame.ScaleType = Enum.ScaleType.Stretch
	notificationFrame.ImageColor3 = Color3.fromRGB(255, 255, 255)
	notificationFrame.ZIndex = 10
	notificationFrame.Parent = holder

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "NotificationTitle"
	titleLabel.Size = UDim2.new(1, -34, 0, 18)
	titleLabel.Position = UDim2.new(0, 18, 0, 12)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = notificationData.Title
	titleLabel.TextSize = 16
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextYAlignment = Enum.TextYAlignment.Center
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.ZIndex = 11
	titleLabel.Parent = notificationFrame

	local messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "MessageText"
	messageLabel.Size = UDim2.new(1, -34, 0, 22)
	messageLabel.Position = UDim2.new(0, 18, 0, 30)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Text = notificationData.Message
	messageLabel.TextSize = 13
	messageLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
	messageLabel.TextWrapped = true
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.TextYAlignment = Enum.TextYAlignment.Top
	messageLabel.Font = Enum.Font.Gotham
	messageLabel.ZIndex = 11
	messageLabel.Parent = notificationFrame

	table.insert(TaskAPI.Notifications, holder)

	local slideInTween = TweenService:Create(notificationFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0)
	})

	local slideOutTween = TweenService:Create(notificationFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
		Position = UDim2.new(1, 0, 0, 0)
	})

	slideInTween:Play()

	task.spawn(function()
		task.wait(notificationData.Duration)
		slideOutTween:Play()
		slideOutTween.Completed:Wait()

		local notificationIndex = table.find(TaskAPI.Notifications, holder)
		if notificationIndex then
			table.remove(TaskAPI.Notifications, notificationIndex)
		end

		holder:Destroy()
	end)

	return holder
end

function TaskAPI:Notify(notificationData)
	return TaskAPI.Notification(notificationData)
end

local function updateCategorySize(category)
	local moduleCount = #category.ModuleList
	local moduleHeight = 35
	local defaultHeight = category.DefaultSize.Y.Offset
	local extraModules = math.max(0, moduleCount - 1)
	local totalHeight = defaultHeight + (extraModules * moduleHeight)

	category.MainFrame.Size = UDim2.new(
		category.MainFrame.Size.X.Scale,
		category.MainFrame.Size.X.Offset,
		0,
		totalHeight
	)

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
	module.Button.Text = module.Name
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

	local containerFrame = Instance.new("Frame")
	containerFrame.Name = "CategoryContainer_" .. categoryData.Name
	containerFrame.Size = categoryData.Size or UDim2.new(0, 165, 0, 82)
	containerFrame.AnchorPoint = categoryAnchorPoint
	containerFrame.Position = categoryPosition
	containerFrame.BackgroundTransparency = 1
	containerFrame.BorderSizePixel = 0
	containerFrame.ZIndex = 1
	containerFrame.Parent = ScreenGui

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame_" .. categoryData.Name
	mainFrame.Size = categoryData.Size or UDim2.new(0, 165, 0, 82)
	mainFrame.Position = UDim2.new(0, 0, 0, 0)
	mainFrame.BackgroundColor3 = categoryData.BackgroundColor3 or Color3.fromRGB(0, 0, 0)
	mainFrame.BorderSizePixel = 0
	mainFrame.ClipsDescendants = true
	mainFrame.ZIndex = 2
	mainFrame.Parent = containerFrame

	local mainFrameCorner = Instance.new("UICorner")
	mainFrameCorner.CornerRadius = UDim.new(0, 10)
	mainFrameCorner.Parent = mainFrame

	local sEffect = Instance.new("ImageLabel")
	sEffect.Name = "SEffect"
	sEffect.Size = UDim2.new(0, 190, 0, 105)
	sEffect.Position = UDim2.new(0, -13, 0, -11)
	sEffect.BackgroundTransparency = 1
	sEffect.Image = TaskAssets.Shadow
	sEffect.ZIndex = 1
	sEffect.Parent = containerFrame

	local categoryFrame = Instance.new("ImageLabel")
	categoryFrame.Name = "CategoryFrame"
	categoryFrame.Size = UDim2.new(1, 0, 0, 40)
	categoryFrame.Position = UDim2.new(0, 0, 0, 0)
	categoryFrame.Active = true
	categoryFrame.BackgroundTransparency = 1
	categoryFrame.Image = categoryData.CategoryImage or TaskAssets.CategoryFrame
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

	local modulesHolder = Instance.new("Frame")
	modulesHolder.Name = "ModulesHolder"
	modulesHolder.Size = UDim2.new(1, 0, 0, 0)
	modulesHolder.Position = UDim2.new(0, 0, 0, 40)
	modulesHolder.BackgroundTransparency = 1
	modulesHolder.ZIndex = 4
	modulesHolder.Parent = mainFrame

	local modulesLayout = Instance.new("UIListLayout")
	modulesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	modulesLayout.Padding = UDim.new(0, 0)
	modulesLayout.Parent = modulesHolder

	local category = {
		Name = categoryData.Name,
		Position = categoryPosition,
		AnchorPoint = categoryAnchorPoint,
		DefaultSize = categoryData.Size or UDim2.new(0, 165, 0, 82),
		ContainerFrame = containerFrame,
		MainFrame = mainFrame,
		TaskFrame = containerFrame,
		SEffect = sEffect,
		CategoryFrame = categoryFrame,
		CategoryLabel = categoryLabel,
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
		extraLabel.Size = UDim2.new(0, 60, 1, 0)
		extraLabel.AnchorPoint = Vector2.new(1, 0)
		extraLabel.Position = UDim2.new(1, -10, 0, 0)
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

			TaskAPI.Notification({
				Title = "Taskium",
				Message = self.Name .. ": " .. (self.Enabled and "Enabled" or "Disabled"),
				Duration = 3,
				Type = self.Enabled and "Success" or "Info"
			})

			if self.Function then
				if self.Enabled then
					task.spawn(function()
						local ok, err = pcall(self.Function, true)
						if not ok then
							warn(("TaskAPI module '%s' failed: %s"):format(self.Name, tostring(err)))
							self.Enabled = false
							refreshModuleDisplay(self)
							self:Cleanup()
							TaskAPI.Notification({
								Title = "Taskium",
								Message = tostring(err),
								Duration = 4,
								Type = "Error"
							})
						end
					end)
				else
					local ok, err = pcall(self.Function, false)
					if not ok then
						warn(("TaskAPI module '%s' disable failed: %s"):format(self.Name, tostring(err)))
						TaskAPI.Notification({
							Title = "Taskium",
							Message = tostring(err),
							Duration = 4,
							Type = "Error"
						})
					end
				end
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
		startPosition = containerFrame.Position
	end)

	categoryFrame.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
			category.Position = containerFrame.Position
		end
	end)

	InputService.InputChanged:Connect(function(input)
		if not dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end

		local delta = input.Position - dragStart
		containerFrame.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
		category.Position = containerFrame.Position
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
