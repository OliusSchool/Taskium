local Players = game:GetService("Players")
local InputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local LogService = game:GetService("LogService")
local TextService = game:GetService("TextService")
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

local PreviousTaskAPI = getgenv().TaskAPI

local TaskAssets = {
	CategoryFrame = "rbxassetid://126645359069961",
	Shadow = "rbxassetid://125043055375567",
	NotificationFrame = "rbxassetid://123298087495168",
	TooltipFrame = "rbxassetid://109798445140553"
}

local NotificationColors = {
	Client = Color3.fromRGB(255, 255, 255),
	Success = Color3.fromRGB(46, 204, 113),
	Error = Color3.fromRGB(231, 76, 60),
	Warning = Color3.fromRGB(241, 196, 15),
	Info = Color3.fromRGB(52, 152, 219)
}

getgenv().Taskium = getgenv().Taskium or {}
getgenv().Taskium.API = TaskAPI
getgenv().TaskAPI = TaskAPI

local TaskConfig = getgenv().Taskium and getgenv().Taskium.Config
TaskAPI.Config = TaskConfig

local function buildConfigKey(...)
	local parts = { ... }
	for index, value in ipairs(parts) do
		parts[index] = tostring(value)
	end

	return table.concat(parts, "/")
end

local function registerConfigValue(kind, key, defaultValue)
	if TaskConfig and type(TaskConfig.Register) == "function" then
		return TaskConfig:Register(kind, key, defaultValue)
	end

	return defaultValue
end

local function setConfigValue(kind, key, value)
	if TaskConfig and type(TaskConfig.Set) == "function" then
		return TaskConfig:Set(kind, key, value)
	end

	return value
end

local function getClipboardSetter()
	if type(setclipboard) == "function" then
		return setclipboard
	end

	if type(toclipboard) == "function" then
		return toclipboard
	end

	if Clipboard and type(Clipboard.set) == "function" then
		return Clipboard.set
	end

	return nil
end

local function shutdownAPI(api)
	if type(api) ~= "table" then
		return
	end

	local seenModules = {}

	if type(api.Modules) == "table" then
		for _, previousModule in pairs(api.Modules) do
			if type(previousModule) == "table" and not seenModules[previousModule] then
				seenModules[previousModule] = true

				if type(previousModule.SetEnabled) == "function" then
					pcall(function()
						previousModule:SetEnabled(false, {
							SkipConfig = true,
							SkipNotify = true
						})
					end)
				end

				previousModule.Enabled = false

				if type(previousModule.Cleanup) == "function" then
					pcall(function()
						previousModule:Cleanup()
					end)
				end
			end
		end
	end

	if type(api.BlurEffect) == "userdata" or typeof(api.BlurEffect) == "Instance" then
		pcall(function()
			api.BlurEffect.Enabled = false
		end)
	end
end

if PreviousTaskAPI and PreviousTaskAPI ~= TaskAPI then
	shutdownAPI(PreviousTaskAPI)
end

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
BlurEffect.Size = 10
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
TaskAPI.Connections = {}

local TooltipFrame = Instance.new("Frame")
TooltipFrame.Name = "ModuleTooltip"
TooltipFrame.Size = UDim2.new(0, 20, 0, 20)
TooltipFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
TooltipFrame.BackgroundTransparency = 0
TooltipFrame.BorderSizePixel = 0
TooltipFrame.ClipsDescendants = true
TooltipFrame.Visible = false
TooltipFrame.ZIndex = 50
TooltipFrame.Parent = ScreenGui

local TooltipCorner = Instance.new("UICorner")
TooltipCorner.CornerRadius = UDim.new(0, 20)
TooltipCorner.Parent = TooltipFrame

local TooltipImage = Instance.new("ImageLabel")
TooltipImage.Name = "TooltipImage"
TooltipImage.Size = UDim2.new(1, 0, 1, 0)
TooltipImage.BackgroundTransparency = 1
TooltipImage.BorderSizePixel = 0
TooltipImage.Image = TaskAssets.TooltipFrame
TooltipImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
TooltipImage.ScaleType = Enum.ScaleType.Stretch
TooltipImage.ZIndex = 49
TooltipImage.Parent = TooltipFrame

local TooltipText = Instance.new("TextLabel")
TooltipText.Name = "TooltipText"
TooltipText.Size = UDim2.new(1, -12, 1, 0)
TooltipText.Position = UDim2.new(0, 6, 0, 0)
TooltipText.BackgroundTransparency = 1
TooltipText.BorderSizePixel = 0
TooltipText.Text = ""
TooltipText.TextSize = 12
TooltipText.TextColor3 = Color3.fromRGB(255, 255, 255)
TooltipText.TextXAlignment = Enum.TextXAlignment.Center
TooltipText.TextYAlignment = Enum.TextYAlignment.Center
TooltipText.Font = Enum.Font.Gotham
TooltipText.ZIndex = 51
TooltipText.Parent = TooltipFrame

local activeTooltipText = nil

local function getViewportSize()
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end

	return Vector2.new(1920, 1080)
end

local function updateTooltipPosition(mousePosition)
	if not TooltipFrame.Visible then
		return
	end

	local viewportSize = getViewportSize()
	local tooltipWidth = TooltipFrame.Size.X.Offset
	local tooltipHeight = TooltipFrame.Size.Y.Offset
	local positionX = math.clamp(mousePosition.X + 14, 6, viewportSize.X - tooltipWidth - 6)
	local positionY = math.clamp(mousePosition.Y + 16, 6, viewportSize.Y - tooltipHeight - 6)

	TooltipFrame.Position = UDim2.new(0, positionX, 0, positionY)
end

local function showTooltip(text)
	if type(text) ~= "string" or text == "" then
		return
	end

	activeTooltipText = text

	local textSize = TextService:GetTextSize(text, 12, Enum.Font.Gotham, Vector2.new(1000, 20))
	local tooltipWidth = math.max(20, textSize.X + 14)

	TooltipFrame.Size = UDim2.new(0, tooltipWidth, 0, 20)
	TooltipText.Text = text
	TooltipFrame.Visible = true
	updateTooltipPosition(InputService:GetMouseLocation())
end

local function hideTooltip()
	activeTooltipText = nil
	TooltipFrame.Visible = false
	TooltipText.Text = ""
end

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

local function updateModuleLayout(module)
	local rowHeight = 35
	local optionsHeight = 0
	if module.Expanded and module.OptionsLayout then
		optionsHeight = module.OptionsLayout.AbsoluteContentSize.Y
	end

	module.OptionsHolder.Size = UDim2.new(1, 0, 0, optionsHeight)
	module.Container.Size = UDim2.new(1, 0, 0, rowHeight + optionsHeight)
	module.ArrowButton.Visible = (#module.ToggleList + #module.SliderList + #module.DropdownList) > 0
	module.ArrowButton.Text = module.Expanded and "v" or ">"
end

local function normalizeNotificationData(title, message, duration, notificationType)
	if type(title) == "table" then
		return {
			Title = tostring(title.Title or title.Name or "Notification"),
			Message = tostring(title.Message or "No message has been set for this notification."),
			Duration = tonumber(title.Duration) or 3,
			Type = title.Type or "Client",
			CopyText = title.CopyText,
			ClickToCopy = not not title.ClickToCopy
		}
	end

	return {
		Title = tostring(title or "Notification"),
		Message = tostring(message or "No message has been set for this notification."),
		Duration = tonumber(duration) or 3,
		Type = notificationType or "Client",
		CopyText = nil,
		ClickToCopy = false
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

	local clickButton = Instance.new("TextButton")
	clickButton.Name = "ClickArea"
	clickButton.Size = UDim2.new(1, 0, 1, 0)
	clickButton.BackgroundTransparency = 1
	clickButton.BorderSizePixel = 0
	clickButton.AutoButtonColor = false
	clickButton.Text = ""
	clickButton.ZIndex = 12
	clickButton.Active = notificationData.ClickToCopy
	clickButton.Visible = notificationData.ClickToCopy
	clickButton.Parent = notificationFrame

	if notificationData.ClickToCopy then
		clickButton.MouseButton1Click:Connect(function()
			local clipboardSetter = getClipboardSetter()
			if clipboardSetter then
				clipboardSetter(tostring(notificationData.CopyText or notificationData.Message))
			end
		end)
	end

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

local function getConsoleNotificationType(messageType)
	if messageType == Enum.MessageType.MessageError then
		return "Error"
	end

	if messageType == Enum.MessageType.MessageWarning then
		return "Warning"
	end
end

local function getConsoleNotificationTitle(messageType)
	if messageType == Enum.MessageType.MessageError then
		return "Console Error"
	end

	if messageType == Enum.MessageType.MessageWarning then
		return "Console Warning"
	end
end

local function updateCategorySize(category)
	local defaultHeight = category.DefaultSize.Y.Offset
	local totalContentHeight = 0
	local minimumContentHeight = 35
	local bottomPadding = 7

	if category.ModulesLayout then
		totalContentHeight = category.ModulesLayout.AbsoluteContentSize.Y
	else
		for _, module in ipairs(category.ModuleList) do
			totalContentHeight = totalContentHeight + module.Container.Size.Y.Offset
		end
	end

	totalContentHeight = math.max(totalContentHeight, minimumContentHeight)

	local totalHeight = math.max(defaultHeight, 40 + totalContentHeight + bottomPadding)

	category.MainFrame.Size = UDim2.new(
		category.MainFrame.Size.X.Scale,
		category.MainFrame.Size.X.Offset,
		0,
		totalHeight
	)

	category.ModulesHolder.Size = UDim2.new(1, 0, 0, totalContentHeight)
	updateShadowSize(category)
end

local function refreshModuleDisplay(module)
	if module.Button == nil or module.Button.Parent == nil then
		return
	end

	module.Button.BackgroundColor3 = module.Enabled and Color3.fromRGB(36, 36, 36) or Color3.fromRGB(17, 17, 17)
	module.NameLabel.TextColor3 = module.Enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(205, 205, 205)
	module.ArrowButton.TextColor3 = module.Enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 170, 170)
	module.NameLabel.Text = module.Name
	module.ArrowButton.Visible = (#module.ToggleList + #module.SliderList + #module.DropdownList) > 0
	module.ArrowButton.Text = module.Expanded and "v" or ">"
end

local function refreshToggleDisplay(toggle)
	if toggle.Button == nil or toggle.Button.Parent == nil then
		return
	end

	local toggleEnabled = toggle.Value

	toggle.Button.BackgroundColor3 = toggleEnabled and Color3.fromRGB(32, 32, 32) or Color3.fromRGB(22, 22, 22)
	toggle.NameLabel.TextColor3 = toggleEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(190, 190, 190)
	toggle.StateLabel.Text = toggleEnabled and "On" or "Off"
	toggle.StateLabel.TextColor3 = toggleEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 170, 170)
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
		ModulesLayout = modulesLayout,
		ModuleList = {},
		Modules = {}
	}

	modulesLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		updateCategorySize(category)
	end)

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

		local moduleContainer = Instance.new("Frame")
		moduleContainer.Name = moduleData.Name .. "_Container"
		moduleContainer.Size = UDim2.new(1, 0, 0, 35)
		moduleContainer.BackgroundTransparency = 1
		moduleContainer.BorderSizePixel = 0
		moduleContainer.ZIndex = 4
		moduleContainer.Parent = self.ModulesHolder

		local moduleButton = Instance.new("TextButton")
		moduleButton.Name = moduleData.Name
		moduleButton.Size = UDim2.new(1, 0, 0, 35)
		moduleButton.BackgroundColor3 = Color3.fromRGB(17, 17, 17)
		moduleButton.BorderSizePixel = 0
		moduleButton.AutoButtonColor = false
		moduleButton.Text = ""
		moduleButton.TextSize = 16
		moduleButton.ZIndex = 4
		moduleButton.Parent = moduleContainer

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "ModuleName"
		nameLabel.Size = UDim2.new(1, -34, 1, 0)
		nameLabel.Position = UDim2.new(0, 8, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = moduleData.Name
		nameLabel.TextSize = 16
		nameLabel.TextColor3 = Color3.fromRGB(205, 205, 205)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextYAlignment = Enum.TextYAlignment.Center
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.ZIndex = 5
		nameLabel.Parent = moduleButton

		local arrowButton = Instance.new("TextButton")
		arrowButton.Name = "ExpandArrow"
		arrowButton.Size = UDim2.new(0, 18, 1, 0)
		arrowButton.AnchorPoint = Vector2.new(1, 0)
		arrowButton.Position = UDim2.new(1, -6, 0, 0)
		arrowButton.BackgroundTransparency = 1
		arrowButton.AutoButtonColor = false
		arrowButton.Text = ">"
		arrowButton.TextSize = 16
		arrowButton.TextColor3 = Color3.fromRGB(170, 170, 170)
		arrowButton.Font = Enum.Font.GothamBold
		arrowButton.Visible = false
		arrowButton.ZIndex = 6
		arrowButton.Parent = moduleButton

		local optionsHolder = Instance.new("Frame")
		optionsHolder.Name = "OptionsHolder"
		optionsHolder.Size = UDim2.new(1, 0, 0, 0)
		optionsHolder.Position = UDim2.new(0, 0, 0, 35)
		optionsHolder.BackgroundTransparency = 1
		optionsHolder.BorderSizePixel = 0
		optionsHolder.ClipsDescendants = true
		optionsHolder.ZIndex = 4
		optionsHolder.Parent = moduleContainer

		local optionsLayout = Instance.new("UIListLayout")
		optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		optionsLayout.Padding = UDim.new(0, 0)
		optionsLayout.Parent = optionsHolder

		local module = {
			Name = moduleData.Name,
			ConfigKey = buildConfigKey(self.Name, moduleData.Name),
			Enabled = false,
			Expanded = false,
			RunId = 0,
			Function = moduleData.Function,
			Tooltip = moduleData.Tooltip,
			Container = moduleContainer,
			Button = moduleButton,
			NameLabel = nameLabel,
			ArrowButton = arrowButton,
			OptionsHolder = optionsHolder,
			OptionsLayout = optionsLayout,
			ToggleList = {},
			Toggles = {},
			SliderList = {},
			Sliders = {},
			DropdownList = {},
			Dropdowns = {},
			Category = self,
			Cleanups = {}
		}

		optionsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			updateModuleLayout(module)
			updateCategorySize(module.Category)
		end)

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

		function module:GetRunId()
			return self.RunId
		end

		function module:IsActive(runId)
			if runId == nil then
				return self.Enabled
			end

			return self.Enabled and self.RunId == runId
		end

		function module:SetEnabled(state, options)
			options = options or {}
			state = not not state
			if self.Enabled == state then
				return
			end

			self.Enabled = state
			self.RunId = self.RunId + 1
			local currentRunId = self.RunId
			refreshModuleDisplay(self)

			if not options.SkipConfig then
				setConfigValue("module", self.ConfigKey, self.Enabled)
			end

			if not options.SkipNotify then
				TaskAPI.Notification({
					Title = "Taskium",
					Message = self.Name .. ": " .. (self.Enabled and "Enabled" or "Disabled"),
					Duration = 3,
					Type = self.Enabled and "Success" or "Info"
				})
			end

			if self.Function then
				if self.Enabled then
					task.spawn(function()
						local ok, err = pcall(self.Function, true, currentRunId, self)
						if not ok then
							warn(("TaskAPI module '%s' failed: %s"):format(self.Name, tostring(err)))
							self.Enabled = false
							refreshModuleDisplay(self)
							setConfigValue("module", self.ConfigKey, false)
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
					local ok, err = pcall(self.Function, false, currentRunId, self)
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

			for _, toggle in ipairs(self.ToggleList) do
				toggle:ApplyCurrentState()
			end

			if not self.Enabled then
				self:Cleanup()
			end
		end

		function module:Toggle()
			self:SetEnabled(not self.Enabled)
		end

		function module:SetExpanded(state)
			self.Expanded = not not state
			updateModuleLayout(self)
			updateCategorySize(self.Category)
			refreshModuleDisplay(self)
		end

		function module:CreateToggle(toggleData)
			if not toggleData or type(toggleData.Name) ~= "string" or toggleData.Name == "" then
				error(("Module '%s' requires a valid toggle name"):format(self.Name))
			end

			if self.Toggles[toggleData.Name] then
				error(("Toggle '%s' already exists in module '%s'"):format(toggleData.Name, self.Name))
			end

			if toggleData.Function ~= nil and type(toggleData.Function) ~= "function" then
				error(("Toggle '%s' Function must be a function"):format(toggleData.Name))
			end

			local toggleButton = Instance.new("TextButton")
			toggleButton.Name = toggleData.Name
			toggleButton.Size = UDim2.new(1, 0, 0, 30)
			toggleButton.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
			toggleButton.BorderSizePixel = 0
			toggleButton.AutoButtonColor = false
			toggleButton.Text = ""
			toggleButton.ZIndex = 4
			toggleButton.Parent = self.OptionsHolder

			local toggleNameLabel = Instance.new("TextLabel")
			toggleNameLabel.Name = "ToggleName"
			toggleNameLabel.Size = UDim2.new(1, -76, 1, 0)
			toggleNameLabel.Position = UDim2.new(0, 18, 0, 0)
			toggleNameLabel.BackgroundTransparency = 1
			toggleNameLabel.Text = toggleData.Name
			toggleNameLabel.TextSize = 14
			toggleNameLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			toggleNameLabel.TextXAlignment = Enum.TextXAlignment.Left
			toggleNameLabel.TextYAlignment = Enum.TextYAlignment.Center
			toggleNameLabel.Font = Enum.Font.Gotham
			toggleNameLabel.ZIndex = 5
			toggleNameLabel.Parent = toggleButton

			local toggleStateLabel = Instance.new("TextLabel")
			toggleStateLabel.Name = "ToggleState"
			toggleStateLabel.Size = UDim2.new(0, 44, 1, 0)
			toggleStateLabel.AnchorPoint = Vector2.new(1, 0)
			toggleStateLabel.Position = UDim2.new(1, -8, 0, 0)
			toggleStateLabel.BackgroundTransparency = 1
			toggleStateLabel.Text = "Off"
			toggleStateLabel.TextSize = 13
			toggleStateLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
			toggleStateLabel.TextXAlignment = Enum.TextXAlignment.Right
			toggleStateLabel.TextYAlignment = Enum.TextYAlignment.Center
			toggleStateLabel.Font = Enum.Font.Gotham
			toggleStateLabel.ZIndex = 5
			toggleStateLabel.Parent = toggleButton

			local toggle = {
				Name = toggleData.Name,
				ConfigKey = buildConfigKey(self.ConfigKey, toggleData.Name),
				Enabled = false,
				Value = false,
				Active = false,
				Function = toggleData.Function,
				Tooltip = toggleData.Tooltip,
				Button = toggleButton,
				NameLabel = toggleNameLabel,
				StateLabel = toggleStateLabel,
				Module = self,
				ControlHeight = 30
			}

			function toggle:ApplyCurrentState(forceCallback)
				refreshToggleDisplay(self)

				if not self.Function or not self.Module then
					self.Enabled = false
					self.Active = false
					return
				end

				local shouldRun = self.Module.Enabled and self.Value
				self.Enabled = shouldRun
				if not forceCallback and self.Active == shouldRun then
					return
				end

				self.Active = shouldRun
				local ok, err = pcall(self.Function, shouldRun)
				if not ok then
					warn(("TaskAPI toggle '%s' failed: %s"):format(self.Name, tostring(err)))
					TaskAPI.Notification({
						Title = "Taskium",
						Message = tostring(err),
						Duration = 4,
						Type = "Error"
					})
				end
			end

			function toggle:SetEnabled(state, options)
				options = options or {}
				state = not not state
				if self.Value == state then
					refreshToggleDisplay(self)
					return
				end

				self.Value = state
				refreshToggleDisplay(self)

				if not options.SkipConfig then
					setConfigValue("toggle", self.ConfigKey, self.Value)
				end

				if self.Module and self.Module.Enabled then
					self:ApplyCurrentState()
				else
					self.Enabled = false
					self.Active = false
				end
			end

			function toggle:Toggle()
				self:SetEnabled(not self.Value)
			end

			toggleButton.MouseButton1Click:Connect(function()
				toggle:Toggle()
			end)

			table.insert(self.ToggleList, toggle)
			self.Toggles[toggle.Name] = toggle
			updateModuleLayout(self)
			updateCategorySize(self.Category)
			refreshModuleDisplay(self)
			toggle.Value = registerConfigValue("toggle", toggle.ConfigKey, false)
			toggle.Enabled = false
			toggle.Active = false
			refreshToggleDisplay(toggle)

			return toggle
		end

		function module:CreateSlider(sliderData)
			if not sliderData or type(sliderData.Name) ~= "string" or sliderData.Name == "" then
				error(("Module '%s' requires a valid slider name"):format(self.Name))
			end

			if self.Sliders[sliderData.Name] then
				error(("Slider '%s' already exists in module '%s'"):format(sliderData.Name, self.Name))
			end

			if sliderData.Function ~= nil and type(sliderData.Function) ~= "function" then
				error(("Slider '%s' Function must be a function"):format(sliderData.Name))
			end

			local minValue = tonumber(sliderData.Min or sliderData.Minimum or 0) or 0
			local maxValue = tonumber(sliderData.Max or sliderData.Maximum or 100) or 100
			local defaultValue = tonumber(sliderData.Default or sliderData.Value or minValue) or minValue

			if maxValue < minValue then
				minValue, maxValue = maxValue, minValue
			end

			defaultValue = math.clamp(defaultValue, minValue, maxValue)

			local sliderButton = Instance.new("TextButton")
			sliderButton.Name = sliderData.Name
			sliderButton.Size = UDim2.new(1, 0, 0, 46)
			sliderButton.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
			sliderButton.BorderSizePixel = 0
			sliderButton.AutoButtonColor = false
			sliderButton.Text = ""
			sliderButton.ZIndex = 4
			sliderButton.Parent = self.OptionsHolder

			local sliderNameLabel = Instance.new("TextLabel")
			sliderNameLabel.Name = "SliderName"
			sliderNameLabel.Size = UDim2.new(1, -76, 0, 18)
			sliderNameLabel.Position = UDim2.new(0, 18, 0, 5)
			sliderNameLabel.BackgroundTransparency = 1
			sliderNameLabel.Text = sliderData.Name
			sliderNameLabel.TextSize = 14
			sliderNameLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			sliderNameLabel.TextXAlignment = Enum.TextXAlignment.Left
			sliderNameLabel.TextYAlignment = Enum.TextYAlignment.Center
			sliderNameLabel.Font = Enum.Font.Gotham
			sliderNameLabel.ZIndex = 5
			sliderNameLabel.Parent = sliderButton

			local sliderValueLabel = Instance.new("TextLabel")
			sliderValueLabel.Name = "SliderValue"
			sliderValueLabel.Size = UDim2.new(0, 50, 0, 18)
			sliderValueLabel.AnchorPoint = Vector2.new(1, 0)
			sliderValueLabel.Position = UDim2.new(1, -8, 0, 5)
			sliderValueLabel.BackgroundTransparency = 1
			sliderValueLabel.Text = tostring(defaultValue)
			sliderValueLabel.TextSize = 13
			sliderValueLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
			sliderValueLabel.TextXAlignment = Enum.TextXAlignment.Right
			sliderValueLabel.TextYAlignment = Enum.TextYAlignment.Center
			sliderValueLabel.Font = Enum.Font.Gotham
			sliderValueLabel.ZIndex = 5
			sliderValueLabel.Parent = sliderButton

			local sliderTrack = Instance.new("Frame")
			sliderTrack.Name = "SliderTrack"
			sliderTrack.Size = UDim2.new(1, -24, 0, 4)
			sliderTrack.Position = UDim2.new(0, 12, 0, 31)
			sliderTrack.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			sliderTrack.BorderSizePixel = 0
			sliderTrack.ZIndex = 5
			sliderTrack.Parent = sliderButton

			local sliderFill = Instance.new("Frame")
			sliderFill.Name = "SliderFill"
			sliderFill.Size = UDim2.new(0, 0, 1, 0)
			sliderFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			sliderFill.BorderSizePixel = 0
			sliderFill.ZIndex = 6
			sliderFill.Parent = sliderTrack

			local sliderKnob = Instance.new("Frame")
			sliderKnob.Name = "SliderKnob"
			sliderKnob.Size = UDim2.new(0, 8, 0, 8)
			sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
			sliderKnob.Position = UDim2.new(0, 0, 0.5, 0)
			sliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			sliderKnob.BorderSizePixel = 0
			sliderKnob.ZIndex = 7
			sliderKnob.Parent = sliderTrack

			local sliderKnobCorner = Instance.new("UICorner")
			sliderKnobCorner.CornerRadius = UDim.new(1, 0)
			sliderKnobCorner.Parent = sliderKnob

			local slider = {
				Name = sliderData.Name,
				ConfigKey = buildConfigKey(self.ConfigKey, sliderData.Name),
				Min = minValue,
				Max = maxValue,
				Value = defaultValue,
				Function = sliderData.Function,
				Tooltip = sliderData.Tooltip,
				Button = sliderButton,
				NameLabel = sliderNameLabel,
				ValueLabel = sliderValueLabel,
				Track = sliderTrack,
				Fill = sliderFill,
				Knob = sliderKnob,
				Module = self,
				ControlHeight = 46
			}

			local function setSliderVisuals(value)
				local alpha = 0
				if slider.Max > slider.Min then
					alpha = (value - slider.Min) / (slider.Max - slider.Min)
				end

				slider.ValueLabel.Text = tostring(value)
				slider.Fill.Size = UDim2.new(alpha, 0, 1, 0)
				slider.Knob.Position = UDim2.new(alpha, 0, 0.5, 0)
			end

			function slider:SetValue(value, skipCallback, options)
				options = options or {}
				value = math.clamp(math.floor((tonumber(value) or self.Value) + 0.5), self.Min, self.Max)
				if self.Value == value then
					setSliderVisuals(value)
					if not skipCallback and options.ForceCallback and self.Function then
						local ok, err = pcall(self.Function, self.Value)
						if not ok then
							warn(("TaskAPI slider '%s' failed: %s"):format(self.Name, tostring(err)))
							TaskAPI.Notification({
								Title = "Taskium",
								Message = tostring(err),
								Duration = 4,
								Type = "Error"
							})
						end
					end
					return
				end

				self.Value = value
				setSliderVisuals(value)

				if not options.SkipConfig then
					setConfigValue("slider", self.ConfigKey, self.Value)
				end

				if not skipCallback and self.Function then
					local ok, err = pcall(self.Function, self.Value)
					if not ok then
						warn(("TaskAPI slider '%s' failed: %s"):format(self.Name, tostring(err)))
						TaskAPI.Notification({
							Title = "Taskium",
							Message = tostring(err),
							Duration = 4,
							Type = "Error"
						})
					end
				end
			end

			local draggingSlider = false

			local function setFromMousePosition(mouseX)
				local alpha = math.clamp((mouseX - slider.Track.AbsolutePosition.X) / slider.Track.AbsoluteSize.X, 0, 1)
				local value = slider.Min + ((slider.Max - slider.Min) * alpha)
				slider:SetValue(value)
			end

			sliderButton.MouseButton1Down:Connect(function(mouseX)
				draggingSlider = true
				setFromMousePosition(mouseX)
			end)

			InputService.InputChanged:Connect(function(input)
				if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
					setFromMousePosition(input.Position.X)
				end
			end)

			InputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					draggingSlider = false
				end
			end)

			table.insert(self.SliderList, slider)
			self.Sliders[slider.Name] = slider
			updateModuleLayout(self)
			updateCategorySize(self.Category)
			slider:SetValue(registerConfigValue("slider", slider.ConfigKey, defaultValue), false, {
				SkipConfig = true,
				ForceCallback = true
			})

			return slider
		end

		function module:CreateDropdown(dropdownData)
			if not dropdownData or type(dropdownData.Name) ~= "string" or dropdownData.Name == "" then
				error(("Module '%s' requires a valid dropdown name"):format(self.Name))
			end

			if self.Dropdowns[dropdownData.Name] then
				error(("Dropdown '%s' already exists in module '%s'"):format(dropdownData.Name, self.Name))
			end

			if dropdownData.Function ~= nil and type(dropdownData.Function) ~= "function" then
				error(("Dropdown '%s' Function must be a function"):format(dropdownData.Name))
			end

			if type(dropdownData.List) ~= "table" or #dropdownData.List == 0 then
				error(("Dropdown '%s' requires a non-empty List"):format(dropdownData.Name))
			end

			local dropdownContainer = Instance.new("Frame")
			dropdownContainer.Name = dropdownData.Name .. "_Dropdown"
			dropdownContainer.Size = UDim2.new(1, 0, 0, 30)
			dropdownContainer.BackgroundTransparency = 1
			dropdownContainer.BorderSizePixel = 0
			dropdownContainer.ZIndex = 4
			dropdownContainer.Parent = self.OptionsHolder

			local dropdownButton = Instance.new("TextButton")
			dropdownButton.Name = dropdownData.Name
			dropdownButton.Size = UDim2.new(1, 0, 0, 30)
			dropdownButton.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
			dropdownButton.BorderSizePixel = 0
			dropdownButton.AutoButtonColor = false
			dropdownButton.Text = ""
			dropdownButton.ZIndex = 4
			dropdownButton.Parent = dropdownContainer

			local dropdownNameLabel = Instance.new("TextLabel")
			dropdownNameLabel.Name = "DropdownName"
			dropdownNameLabel.Size = UDim2.new(0.5, -18, 1, 0)
			dropdownNameLabel.Position = UDim2.new(0, 18, 0, 0)
			dropdownNameLabel.BackgroundTransparency = 1
			dropdownNameLabel.Text = dropdownData.Name
			dropdownNameLabel.TextSize = 14
			dropdownNameLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			dropdownNameLabel.TextXAlignment = Enum.TextXAlignment.Left
			dropdownNameLabel.TextYAlignment = Enum.TextYAlignment.Center
			dropdownNameLabel.Font = Enum.Font.Gotham
			dropdownNameLabel.ZIndex = 5
			dropdownNameLabel.Parent = dropdownButton

			local dropdownValueLabel = Instance.new("TextLabel")
			dropdownValueLabel.Name = "DropdownValue"
			dropdownValueLabel.Size = UDim2.new(0.5, -34, 1, 0)
			dropdownValueLabel.AnchorPoint = Vector2.new(1, 0)
			dropdownValueLabel.Position = UDim2.new(1, -24, 0, 0)
			dropdownValueLabel.BackgroundTransparency = 1
			dropdownValueLabel.Text = ""
			dropdownValueLabel.TextSize = 13
			dropdownValueLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
			dropdownValueLabel.TextXAlignment = Enum.TextXAlignment.Right
			dropdownValueLabel.TextYAlignment = Enum.TextYAlignment.Center
			dropdownValueLabel.Font = Enum.Font.Gotham
			dropdownValueLabel.ZIndex = 5
			dropdownValueLabel.Parent = dropdownButton

			local dropdownArrow = Instance.new("TextButton")
			dropdownArrow.Name = "DropdownArrow"
			dropdownArrow.Size = UDim2.new(0, 18, 1, 0)
			dropdownArrow.AnchorPoint = Vector2.new(1, 0)
			dropdownArrow.Position = UDim2.new(1, -6, 0, 0)
			dropdownArrow.BackgroundTransparency = 1
			dropdownArrow.AutoButtonColor = false
			dropdownArrow.Text = ">"
			dropdownArrow.TextSize = 14
			dropdownArrow.TextColor3 = Color3.fromRGB(170, 170, 170)
			dropdownArrow.Font = Enum.Font.GothamBold
			dropdownArrow.ZIndex = 6
			dropdownArrow.Parent = dropdownButton

			local listHolder = Instance.new("Frame")
			listHolder.Name = "ListHolder"
			listHolder.Size = UDim2.new(1, 0, 0, 0)
			listHolder.Position = UDim2.new(0, 0, 0, 30)
			listHolder.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
			listHolder.BackgroundTransparency = 0
			listHolder.BorderSizePixel = 0
			listHolder.ClipsDescendants = true
			listHolder.ZIndex = 4
			listHolder.Parent = dropdownContainer

			local listLayout = Instance.new("UIListLayout")
			listLayout.SortOrder = Enum.SortOrder.LayoutOrder
			listLayout.Padding = UDim.new(0, 0)
			listLayout.Parent = listHolder

			local dropdown = {
				Name = dropdownData.Name,
				ConfigKey = buildConfigKey(self.ConfigKey, dropdownData.Name),
				List = {},
				Value = nil,
				Expanded = false,
				Function = dropdownData.Function,
				Tooltip = dropdownData.Tooltip,
				Container = dropdownContainer,
				Button = dropdownButton,
				NameLabel = dropdownNameLabel,
				ValueLabel = dropdownValueLabel,
				ArrowButton = dropdownArrow,
				ListHolder = listHolder,
				Options = {},
				Module = self,
				ControlHeight = 30
			}

			for _, option in ipairs(dropdownData.List) do
				table.insert(dropdown.List, tostring(option))
			end

			local function updateDropdownDisplay()
				dropdown.ValueLabel.Text = tostring(dropdown.Value or "")
				dropdown.ArrowButton.Text = dropdown.Expanded and "v" or ">"

				local optionHeight = 28
				local totalHeight = 0
				if dropdown.Expanded and #dropdown.Options > 0 then
					totalHeight = #dropdown.Options * optionHeight
				end
				dropdown.ListHolder.Size = UDim2.new(1, 0, 0, totalHeight)
				dropdown.Container.Size = UDim2.new(1, 0, 0, 30 + totalHeight)
				dropdown.ControlHeight = 30 + totalHeight

				for _, optionButton in ipairs(dropdown.Options) do
					local isSelected = optionButton:GetAttribute("OptionValue") == dropdown.Value
					optionButton.BackgroundColor3 = isSelected and Color3.fromRGB(32, 32, 32) or Color3.fromRGB(22, 22, 22)
					local optionLabel = optionButton:FindFirstChild("OptionLabel")
					if optionLabel then
						optionLabel.TextColor3 = isSelected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(190, 190, 190)
					end
				end
			end

			function dropdown:SetExpanded(state)
				self.Expanded = not not state
				updateDropdownDisplay()
				updateModuleLayout(self.Module)
				updateCategorySize(self.Module.Category)
				refreshModuleDisplay(self.Module)
			end

			function dropdown:SetValue(value, skipCallback, options)
				options = options or {}
				value = tostring(value)

				local matchedValue = nil
				for _, optionValue in ipairs(self.List) do
					if optionValue == value then
						matchedValue = optionValue
						break
					end
				end

				if matchedValue == nil then
					return
				end

				if self.Value == matchedValue then
					updateDropdownDisplay()
					if not skipCallback and options.ForceCallback and self.Function then
						local ok, err = pcall(self.Function, self.Value)
						if not ok then
							warn(("TaskAPI dropdown '%s' failed: %s"):format(self.Name, tostring(err)))
							TaskAPI.Notification({
								Title = "Taskium",
								Message = tostring(err),
								Duration = 4,
								Type = "Error"
							})
						end
					end
					return
				end

				self.Value = matchedValue
				updateDropdownDisplay()

				if not options.SkipConfig then
					setConfigValue("dropdown", self.ConfigKey, self.Value)
				end

				if not skipCallback and self.Function then
					local ok, err = pcall(self.Function, self.Value)
					if not ok then
						warn(("TaskAPI dropdown '%s' failed: %s"):format(self.Name, tostring(err)))
						TaskAPI.Notification({
							Title = "Taskium",
							Message = tostring(err),
							Duration = 4,
							Type = "Error"
						})
					end
				end
			end

			for _, optionValue in ipairs(dropdown.List) do
				local optionButton = Instance.new("TextButton")
				optionButton.Name = optionValue
				optionButton.Size = UDim2.new(1, 0, 0, 28)
				optionButton.Position = UDim2.new(0, 0, 0, 0)
				optionButton.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
				optionButton.BorderSizePixel = 0
				optionButton.AutoButtonColor = false
				optionButton.Text = ""
				optionButton.ZIndex = 5
				optionButton:SetAttribute("OptionValue", optionValue)
				optionButton.Parent = dropdown.ListHolder

				local optionLabel = Instance.new("TextLabel")
				optionLabel.Name = "OptionLabel"
				optionLabel.Size = UDim2.new(1, -36, 1, 0)
				optionLabel.Position = UDim2.new(0, 18, 0, 0)
				optionLabel.BackgroundTransparency = 1
				optionLabel.Text = optionValue
				optionLabel.TextSize = 13
				optionLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
				optionLabel.TextXAlignment = Enum.TextXAlignment.Left
				optionLabel.TextYAlignment = Enum.TextYAlignment.Center
				optionLabel.Font = Enum.Font.Gotham
				optionLabel.ZIndex = 6
				optionLabel.Parent = optionButton

				optionButton.MouseButton1Click:Connect(function()
					dropdown:SetValue(optionValue)
					dropdown:SetExpanded(false)
				end)

				table.insert(dropdown.Options, optionButton)
			end

			dropdownButton.MouseButton1Click:Connect(function()
				dropdown:SetExpanded(not dropdown.Expanded)
			end)

			dropdownArrow.MouseButton1Click:Connect(function()
				dropdown:SetExpanded(not dropdown.Expanded)
			end)

			dropdownButton.MouseEnter:Connect(function()
				showTooltip(dropdown.Tooltip)
			end)

			dropdownButton.MouseLeave:Connect(function()
				hideTooltip()
			end)

			table.insert(self.DropdownList, dropdown)
			self.Dropdowns[dropdown.Name] = dropdown
			updateDropdownDisplay()
			updateModuleLayout(self)
			updateCategorySize(self.Category)
			refreshModuleDisplay(self)

			local defaultValue = tostring(dropdownData.Default or dropdown.List[1])
			dropdown:SetValue(registerConfigValue("dropdown", dropdown.ConfigKey, defaultValue), false, {
				SkipConfig = true,
				ForceCallback = true
			})

			return dropdown
		end

		if type(moduleData.Toggles) == "table" then
			for _, toggleData in ipairs(moduleData.Toggles) do
				module:CreateToggle(toggleData)
			end
		end

		if type(moduleData.Sliders) == "table" then
			for _, sliderData in ipairs(moduleData.Sliders) do
				module:CreateSlider(sliderData)
			end
		end

		if type(moduleData.Dropdowns) == "table" then
			for _, dropdownData in ipairs(moduleData.Dropdowns) do
				module:CreateDropdown(dropdownData)
			end
		end

		moduleButton.MouseButton1Click:Connect(function()
			module:Toggle()
		end)

		moduleButton.MouseEnter:Connect(function()
			showTooltip(module.Tooltip)
		end)

		moduleButton.MouseLeave:Connect(function()
			hideTooltip()
		end)

		moduleButton.MouseButton2Click:Connect(function()
			if (#module.ToggleList + #module.SliderList + #module.DropdownList) > 0 then
				module:SetExpanded(not module.Expanded)
			end
		end)

		arrowButton.MouseButton1Click:Connect(function()
			module:SetExpanded(not module.Expanded)
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

		updateModuleLayout(module)
		updateCategorySize(self)
		refreshModuleDisplay(module)

		local savedModuleState = registerConfigValue("module", module.ConfigKey, false)
		if savedModuleState then
			task.defer(function()
				if module.Button and module.Button.Parent then
					module:SetEnabled(true, {
						SkipConfig = true,
						SkipNotify = true
					})
				end
			end)
		end

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
		if not ScreenGui.Enabled then
			hideTooltip()
		end
	end
end)

InputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement and activeTooltipText then
		updateTooltipPosition(input.Position)
	end
end)

table.insert(TaskAPI.Connections, LogService.MessageOut:Connect(function(message, messageType)
	if messageType ~= Enum.MessageType.MessageError and messageType ~= Enum.MessageType.MessageWarning then
		return
	end

	TaskAPI.Notification({
		Title = getConsoleNotificationTitle(messageType),
		Message = tostring(message),
		Duration = 5,
		Type = getConsoleNotificationType(messageType),
		ClickToCopy = messageType == Enum.MessageType.MessageError,
		CopyText = tostring(message)
	})
end))

function TaskAPI:Shutdown()
	if type(self.Connections) == "table" then
		for index = #self.Connections, 1, -1 do
			local connection = self.Connections[index]
			if typeof(connection) == "RBXScriptConnection" and connection.Connected then
				connection:Disconnect()
			end
			table.remove(self.Connections, index)
		end
	end

	shutdownAPI(self)
end

return TaskAPI
