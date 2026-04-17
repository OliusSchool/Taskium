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
	ToolTipFrame = "rbxassetid://109798445140553"
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

local function BuildConfigKey(...)
	local Parts = { ... }
	for Index, Value in ipairs(Parts) do
		Parts[Index] = tostring(Value)
	end

	return table.concat(Parts, "/")
end

local function RegisterConfigValue(Kind, Key, DefaultValue)
	if TaskConfig and type(TaskConfig.Register) == "function" then
		return TaskConfig:Register(Kind, Key, DefaultValue)
	end

	return DefaultValue
end

local function SetConfigValue(Kind, Key, Value)
	if TaskConfig and type(TaskConfig.Set) == "function" then
		return TaskConfig:Set(Kind, Key, Value)
	end

	return Value
end

local function GetClipboardSetter()
	local GlobalEnvironment = type(getgenv) == "function" and getgenv() or _G
	local ClipboardSetterNames = {
		"setclipboard",
		"toclipboard",
		"setrbxclipboard",
		"writeclipboard"
	}

	for _, ClipboardSetterName in ipairs(ClipboardSetterNames) do
		local ClipboardSetter = GlobalEnvironment and GlobalEnvironment[ClipboardSetterName]
		if type(ClipboardSetter) == "function" then
			return ClipboardSetter
		end
	end

	local ClipboardLibrary = GlobalEnvironment and GlobalEnvironment.Clipboard
	if type(ClipboardLibrary) == "table" and type(ClipboardLibrary.set) == "function" then
		return ClipboardLibrary.set
	end

	return nil
end

local function ShutdownAPI(Api)
	if type(Api) ~= "table" then
		return
	end

	local SeenModules = {}

	if type(Api.Modules) == "table" then
		for _, PreviousModule in pairs(Api.Modules) do
			if type(PreviousModule) == "table" and not SeenModules[PreviousModule] then
				SeenModules[PreviousModule] = true

				if type(PreviousModule.SetEnabled) == "function" then
					pcall(function()
						PreviousModule:SetEnabled(false, {
							SkipConfig = true,
							SkipNotify = true
						})
					end)
				end

				PreviousModule.Enabled = false

				if type(PreviousModule.Cleanup) == "function" then
					pcall(function()
						PreviousModule:Cleanup()
					end)
				end
			end
		end
	end

	if type(Api.BlurEffect) == "userdata" or typeof(Api.BlurEffect) == "Instance" then
		pcall(function()
			Api.BlurEffect.Enabled = false
		end)
	end
end

if PreviousTaskAPI and PreviousTaskAPI ~= TaskAPI then
	ShutdownAPI(PreviousTaskAPI)
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

local ToolTipFrame = Instance.new("Frame")
ToolTipFrame.Name = "ModuleToolTip"
ToolTipFrame.Size = UDim2.new(0, 20, 0, 20)
ToolTipFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ToolTipFrame.BackgroundTransparency = 0
ToolTipFrame.BorderSizePixel = 0
ToolTipFrame.ClipsDescendants = true
ToolTipFrame.Visible = false
ToolTipFrame.ZIndex = 50
ToolTipFrame.Parent = ScreenGui

local ToolTipCorner = Instance.new("UICorner")
ToolTipCorner.CornerRadius = UDim.new(0, 20)
ToolTipCorner.Parent = ToolTipFrame

local ToolTipImage = Instance.new("ImageLabel")
ToolTipImage.Name = "ToolTipImage"
ToolTipImage.Size = UDim2.new(1, 0, 1, 0)
ToolTipImage.BackgroundTransparency = 1
ToolTipImage.BorderSizePixel = 0
ToolTipImage.Image = TaskAssets.ToolTipFrame
ToolTipImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
ToolTipImage.ScaleType = Enum.ScaleType.Stretch
ToolTipImage.ZIndex = 49
ToolTipImage.Parent = ToolTipFrame

local ToolTipText = Instance.new("TextLabel")
ToolTipText.Name = "ToolTipText"
ToolTipText.Size = UDim2.new(1, -12, 1, 0)
ToolTipText.Position = UDim2.new(0, 6, 0, 0)
ToolTipText.BackgroundTransparency = 1
ToolTipText.BorderSizePixel = 0
ToolTipText.Text = ""
ToolTipText.TextSize = 12
ToolTipText.TextColor3 = Color3.fromRGB(255, 255, 255)
ToolTipText.TextXAlignment = Enum.TextXAlignment.Center
ToolTipText.TextYAlignment = Enum.TextYAlignment.Center
ToolTipText.Font = Enum.Font.Gotham
ToolTipText.ZIndex = 51
ToolTipText.Parent = ToolTipFrame

local ActiveToolTipText = nil

local function GetViewportSize()
	local Camera = workspace.CurrentCamera
	if Camera then
		return Camera.ViewportSize
	end

	return Vector2.new(1920, 1080)
end

local function UpdateToolTipPosition(MousePosition)
	if not ToolTipFrame.Visible then
		return
	end

	local ViewportSize = GetViewportSize()
	local ToolTipWidth = ToolTipFrame.Size.X.Offset
	local ToolTipHeight = ToolTipFrame.Size.Y.Offset
	local PositionX = math.clamp(MousePosition.X + 14, 6, ViewportSize.X - ToolTipWidth - 6)
	local PositionY = math.clamp(MousePosition.Y + 16, 6, ViewportSize.Y - ToolTipHeight - 6)

	ToolTipFrame.Position = UDim2.new(0, PositionX, 0, PositionY)
end

local function ShowToolTip(Text)
	if type(Text) ~= "string" or Text == "" then
		return
	end

	ActiveToolTipText = Text

	local TextSize = TextService:GetTextSize(Text, 12, Enum.Font.Gotham, Vector2.new(1000, 20))
	local ToolTipWidth = math.max(20, TextSize.X + 14)

	ToolTipFrame.Size = UDim2.new(0, ToolTipWidth, 0, 20)
	ToolTipText.Text = Text
	ToolTipFrame.Visible = true
	UpdateToolTipPosition(InputService:GetMouseLocation())
end

local function HideToolTip()
	ActiveToolTipText = nil
	ToolTipFrame.Visible = false
	ToolTipText.Text = ""
end

local function CleanupItem(Item)
	local ItemType = typeof(Item)

	if ItemType == "RBXScriptConnection" then
		if Item.Connected then
			Item:Disconnect()
		end
		return
	end

	if ItemType == "Instance" then
		if Item.Parent then
			Item:Destroy()
		end
		return
	end

	if type(Item) == "function" then
		pcall(Item)
		return
	end

	if type(Item) == "table" then
		if type(Item.Disconnect) == "function" then
			pcall(function()
				Item:Disconnect()
			end)
			return
		end

		if type(Item.Destroy) == "function" then
			pcall(function()
				Item:Destroy()
			end)
		end
	end
end

local function UpdateShadowSize(Category)
	local WidthOffset = Category.MainFrame.Size.X.Offset
	local HeightOffset = Category.MainFrame.Size.Y.Offset

	Category.ShadowEffect.Size = UDim2.new(0, WidthOffset + 25, 0, HeightOffset + 23)
	Category.ContainerFrame.Size = Category.MainFrame.Size
end

local function TweenYSize(InstanceObject, TargetHeight, TweenStore, TweenKey)
	if not InstanceObject then
		return
	end

	if TweenStore and TweenKey and TweenStore[TweenKey] then
		TweenStore[TweenKey]:Cancel()
		TweenStore[TweenKey] = nil
	end

	local Tween = TweenService:Create(
		InstanceObject,
		TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{
			Size = UDim2.new(InstanceObject.Size.X.Scale, InstanceObject.Size.X.Offset, 0, TargetHeight)
		}
	)

	if TweenStore and TweenKey then
		TweenStore[TweenKey] = Tween
	end

	Tween.Completed:Connect(function()
		if TweenStore and TweenKey and TweenStore[TweenKey] == Tween then
			TweenStore[TweenKey] = nil
		end
	end)

	Tween:Play()
end

local function UpdateModuleLayout(Module, Animate)
	local RowHeight = 35
	local OptionsHeight = 0
	if Module.Expanded and Module.OptionsLayout then
		OptionsHeight = Module.OptionsLayout.AbsoluteContentSize.Y
	end

	if Animate then
		TweenYSize(Module.OptionsHolder, OptionsHeight, Module.Tweens, "OptionsHolder")
		TweenYSize(Module.Container, RowHeight + OptionsHeight, Module.Tweens, "Container")
	else
		Module.OptionsHolder.Size = UDim2.new(1, 0, 0, OptionsHeight)
		Module.Container.Size = UDim2.new(1, 0, 0, RowHeight + OptionsHeight)
	end

	Module.ArrowButton.Visible = (#Module.ToggleList + #Module.SliderList + #Module.DropdownList) > 0
	Module.ArrowButton.Text = Module.Expanded and "v" or ">"
end

local function NormalizeNotificationData(Title, Message, Duration, NotificationType)
	if type(Title) == "table" then
		return {
			Title = tostring(Title.Title or Title.Name or "Notification"),
			Message = tostring(Title.Message or "No message has been set for this notification."),
			Duration = tonumber(Title.Duration) or 3,
			Type = Title.Type or "Client",
			CopyText = Title.CopyText,
			ClickToCopy = not not Title.ClickToCopy
		}
	end

	return {
		Title = tostring(Title or "Notification"),
		Message = tostring(Message or "No message has been set for this notification."),
		Duration = tonumber(Duration) or 3,
		Type = NotificationType or "Client",
		CopyText = nil,
		ClickToCopy = false
	}
end

function TaskAPI.Notification(Title, Message, Duration, NotificationType)
	local NotificationData = NormalizeNotificationData(Title, Message, Duration, NotificationType)

	local Holder = Instance.new("Frame")
	Holder.Name = "NotificationHolder"
	Holder.Size = UDim2.new(0, 270, 0, 60)
	Holder.BackgroundTransparency = 1
	Holder.BorderSizePixel = 0
	Holder.ClipsDescendants = true
	Holder.LayoutOrder = #TaskAPI.Notifications + 1
	Holder.Parent = NotificationsContainer

	local NotificationFrame = Instance.new("ImageLabel")
	NotificationFrame.Name = "NotificationFrame"
	NotificationFrame.Size = UDim2.new(0, 270, 0, 60)
	NotificationFrame.Position = UDim2.new(1, 0, 0, 0)
	NotificationFrame.BackgroundTransparency = 1
	NotificationFrame.Image = TaskAssets.NotificationFrame
	NotificationFrame.ScaleType = Enum.ScaleType.Stretch
	NotificationFrame.ImageColor3 = Color3.fromRGB(255, 255, 255)
	NotificationFrame.ZIndex = 10
	NotificationFrame.Parent = Holder

	local TitleLabel = Instance.new("TextLabel")
	TitleLabel.Name = "NotificationTitle"
	TitleLabel.Size = UDim2.new(1, -34, 0, 18)
	TitleLabel.Position = UDim2.new(0, 18, 0, 12)
	TitleLabel.BackgroundTransparency = 1
	TitleLabel.Text = NotificationData.Title
	TitleLabel.TextSize = 16
	TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	TitleLabel.TextYAlignment = Enum.TextYAlignment.Center
	TitleLabel.Font = Enum.Font.GothamBold
	TitleLabel.ZIndex = 11
	TitleLabel.Parent = NotificationFrame

	local MessageLabel = Instance.new("TextLabel")
	MessageLabel.Name = "MessageText"
	MessageLabel.Size = UDim2.new(1, -34, 0, 22)
	MessageLabel.Position = UDim2.new(0, 18, 0, 30)
	MessageLabel.BackgroundTransparency = 1
	MessageLabel.Text = NotificationData.Message
	MessageLabel.TextSize = 13
	MessageLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
	MessageLabel.TextWrapped = true
	MessageLabel.TextXAlignment = Enum.TextXAlignment.Left
	MessageLabel.TextYAlignment = Enum.TextYAlignment.Top
	MessageLabel.Font = Enum.Font.Gotham
	MessageLabel.ZIndex = 11
	MessageLabel.Parent = NotificationFrame

	local ClickButton = Instance.new("TextButton")
	ClickButton.Name = "ClickArea"
	ClickButton.Size = UDim2.new(1, 0, 1, 0)
	ClickButton.BackgroundTransparency = 1
	ClickButton.BorderSizePixel = 0
	ClickButton.AutoButtonColor = false
	ClickButton.Text = ""
	ClickButton.ZIndex = 12
	ClickButton.Active = NotificationData.ClickToCopy
	ClickButton.Visible = NotificationData.ClickToCopy
	ClickButton.Parent = NotificationFrame

	if NotificationData.ClickToCopy then
		ClickButton.MouseButton1Click:Connect(function()
			local ClipboardSetter = GetClipboardSetter()
			if ClipboardSetter then
				ClipboardSetter(tostring(NotificationData.CopyText or NotificationData.Message))
			end
		end)
	end

	table.insert(TaskAPI.Notifications, Holder)

	local SlideInTween = TweenService:Create(NotificationFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0)
	})

	local SlideOutTween = TweenService:Create(NotificationFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
		Position = UDim2.new(1, 0, 0, 0)
	})

	SlideInTween:Play()

	task.spawn(function()
		task.wait(NotificationData.Duration)
		SlideOutTween:Play()
		SlideOutTween.Completed:Wait()

		local NotificationIndex = table.find(TaskAPI.Notifications, Holder)
		if NotificationIndex then
			table.remove(TaskAPI.Notifications, NotificationIndex)
		end

		Holder:Destroy()
	end)

	return Holder
end

function TaskAPI:Notify(NotificationData)
	return TaskAPI.Notification(NotificationData)
end

local function GetConsoleNotificationType(MessageType)
	if MessageType == Enum.MessageType.MessageError then
		return "Error"
	end

	if MessageType == Enum.MessageType.MessageWarning then
		return "Warning"
	end
end

local function GetConsoleNotificationTitle(MessageType)
	if MessageType == Enum.MessageType.MessageError then
		return "Console Error"
	end

	if MessageType == Enum.MessageType.MessageWarning then
		return "Console Warning"
	end
end

local function UpdateCategorySize(Category)
	local DefaultHeight = Category.DefaultSize.Y.Offset
	local TotalContentHeight = 0
	local MinimumContentHeight = 35
	local BottomPadding = 7

	if Category.ModulesLayout then
		TotalContentHeight = Category.ModulesLayout.AbsoluteContentSize.Y
	else
		for _, Module in ipairs(Category.ModuleList) do
			TotalContentHeight = TotalContentHeight + Module.Container.Size.Y.Offset
		end
	end

	TotalContentHeight = math.max(TotalContentHeight, MinimumContentHeight)

	local TotalHeight = math.max(DefaultHeight, 40 + TotalContentHeight + BottomPadding)

	Category.MainFrame.Size = UDim2.new(
		Category.MainFrame.Size.X.Scale,
		Category.MainFrame.Size.X.Offset,
		0,
		TotalHeight
	)

	Category.ModulesHolder.Size = UDim2.new(1, 0, 0, TotalContentHeight)
	UpdateShadowSize(Category)
end

local function RefreshModuleDisplay(Module)
	if Module.Button == nil or Module.Button.Parent == nil then
		return
	end

	Module.Button.BackgroundColor3 = Module.Enabled and Color3.fromRGB(36, 36, 36) or Color3.fromRGB(17, 17, 17)
	Module.NameLabel.TextColor3 = Module.Enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(205, 205, 205)
	Module.ArrowButton.TextColor3 = Module.Enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 170, 170)
	Module.NameLabel.Text = Module.Name
	Module.ArrowButton.Visible = (#Module.ToggleList + #Module.SliderList + #Module.DropdownList) > 0
	Module.ArrowButton.Text = Module.Expanded and "v" or ">"
end

local function RefreshToggleDisplay(Toggle)
	if Toggle.Button == nil or Toggle.Button.Parent == nil then
		return
	end

	local ToggleEnabled = Toggle.Value

	Toggle.Button.BackgroundColor3 = ToggleEnabled and Color3.fromRGB(32, 32, 32) or Color3.fromRGB(22, 22, 22)
	Toggle.NameLabel.TextColor3 = ToggleEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(190, 190, 190)
	Toggle.StateLabel.Text = ToggleEnabled and "On" or "Off"
	Toggle.StateLabel.TextColor3 = ToggleEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 170, 170)
end

function TaskAPI:CreateCategory(CategoryData)
	if not CategoryData or type(CategoryData.Name) ~= "string" or CategoryData.Name == "" then
		error("TaskAPI:CreateCategory requires a Category name")
	end

	if CategoryData.Position and typeof(CategoryData.Position) ~= "UDim2" then
		error("TaskAPI:CreateCategory requires Position to be a UDim2")
	end

	if CategoryData.AnchorPoint and typeof(CategoryData.AnchorPoint) ~= "Vector2" then
		error("TaskAPI:CreateCategory requires AnchorPoint to be a Vector2")
	end

	if self.Categories[CategoryData.Name] then
		error(("TaskAPI Category '%s' already exists"):format(CategoryData.Name))
	end

	local CategoryPosition = CategoryData.Position or UDim2.new(0, 0, 0, 0)
	local CategoryAnchorPoint = CategoryData.AnchorPoint or Vector2.new(0, 0)

	local ContainerFrame = Instance.new("Frame")
	ContainerFrame.Name = "CategoryContainer_" .. CategoryData.Name
	ContainerFrame.Size = CategoryData.Size or UDim2.new(0, 165, 0, 82)
	ContainerFrame.AnchorPoint = CategoryAnchorPoint
	ContainerFrame.Position = CategoryPosition
	ContainerFrame.BackgroundTransparency = 1
	ContainerFrame.BorderSizePixel = 0
	ContainerFrame.ZIndex = 1
	ContainerFrame.Parent = ScreenGui

	local MainFrame = Instance.new("Frame")
	MainFrame.Name = "MainFrame_" .. CategoryData.Name
	MainFrame.Size = CategoryData.Size or UDim2.new(0, 165, 0, 82)
	MainFrame.Position = UDim2.new(0, 0, 0, 0)
	MainFrame.BackgroundColor3 = CategoryData.BackgroundColor3 or Color3.fromRGB(0, 0, 0)
	MainFrame.BorderSizePixel = 0
	MainFrame.ClipsDescendants = true
	MainFrame.ZIndex = 2
	MainFrame.Parent = ContainerFrame

	local MainFrameCorner = Instance.new("UICorner")
	MainFrameCorner.CornerRadius = UDim.new(0, 10)
	MainFrameCorner.Parent = MainFrame

	local ShadowEffect = Instance.new("ImageLabel")
	ShadowEffect.Name = "ShadowEffect"
	ShadowEffect.Size = UDim2.new(0, 190, 0, 105)
	ShadowEffect.Position = UDim2.new(0, -13, 0, -11)
	ShadowEffect.BackgroundTransparency = 1
	ShadowEffect.Image = TaskAssets.Shadow
	ShadowEffect.ZIndex = 1
	ShadowEffect.Parent = ContainerFrame

	local CategoryFrame = Instance.new("ImageLabel")
	CategoryFrame.Name = "CategoryFrame"
	CategoryFrame.Size = UDim2.new(1, 0, 0, 40)
	CategoryFrame.Position = UDim2.new(0, 0, 0, 0)
	CategoryFrame.Active = true
	CategoryFrame.BackgroundTransparency = 1
	CategoryFrame.Image = CategoryData.CategoryImage or TaskAssets.CategoryFrame
	CategoryFrame.ImageColor3 = CategoryData.CategoryColor3 or Color3.fromRGB(255, 255, 255)
	CategoryFrame.ZIndex = 3
	CategoryFrame.Parent = MainFrame

	local CategoryLabel = Instance.new("TextLabel")
	CategoryLabel.Name = "CategoryText"
	CategoryLabel.Size = UDim2.new(1, 0, 1, 0)
	CategoryLabel.BackgroundTransparency = 1
	CategoryLabel.Text = CategoryData.Name
	CategoryLabel.TextSize = 18
	CategoryLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	CategoryLabel.TextXAlignment = Enum.TextXAlignment.Center
	CategoryLabel.TextYAlignment = Enum.TextYAlignment.Center
	CategoryLabel.Font = Enum.Font.GothamBold
	CategoryLabel.ZIndex = 4
	CategoryLabel.Parent = CategoryFrame

	local ModulesHolder = Instance.new("Frame")
	ModulesHolder.Name = "ModulesHolder"
	ModulesHolder.Size = UDim2.new(1, 0, 0, 0)
	ModulesHolder.Position = UDim2.new(0, 0, 0, 40)
	ModulesHolder.BackgroundTransparency = 1
	ModulesHolder.ZIndex = 4
	ModulesHolder.Parent = MainFrame

	local ModulesLayout = Instance.new("UIListLayout")
	ModulesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ModulesLayout.Padding = UDim.new(0, 0)
	ModulesLayout.Parent = ModulesHolder

	local Category = {
		Name = CategoryData.Name,
		Position = CategoryPosition,
		AnchorPoint = CategoryAnchorPoint,
		DefaultSize = CategoryData.Size or UDim2.new(0, 165, 0, 82),
		ContainerFrame = ContainerFrame,
		MainFrame = MainFrame,
		TaskFrame = ContainerFrame,
		ShadowEffect = ShadowEffect,
		CategoryFrame = CategoryFrame,
		CategoryLabel = CategoryLabel,
		ModulesHolder = ModulesHolder,
		ModulesLayout = ModulesLayout,
		ModuleList = {},
		Modules = {}
	}

	ModulesLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		UpdateCategorySize(Category)
	end)

	MainFrame:GetPropertyChangedSignal("Size"):Connect(function()
		UpdateShadowSize(Category)
	end)

	function Category:CreateModule(ModuleData)
		if not ModuleData or type(ModuleData.Name) ~= "string" or ModuleData.Name == "" then
			error(("TaskAPI Category '%s' requires a valid Module name"):format(self.Name))
		end

		if self.Modules[ModuleData.Name] then
			error(("Module '%s' already exists in Category '%s'"):format(ModuleData.Name, self.Name))
		end

		if ModuleData.Function ~= nil and type(ModuleData.Function) ~= "function" then
			error(("Module '%s' Function must be a function"):format(ModuleData.Name))
		end

		local ModuleContainer = Instance.new("Frame")
		ModuleContainer.Name = ModuleData.Name .. "_Container"
		ModuleContainer.Size = UDim2.new(1, 0, 0, 35)
		ModuleContainer.BackgroundTransparency = 1
		ModuleContainer.BorderSizePixel = 0
		ModuleContainer.ZIndex = 4
		ModuleContainer.Parent = self.ModulesHolder

		local ModuleButton = Instance.new("TextButton")
		ModuleButton.Name = ModuleData.Name
		ModuleButton.Size = UDim2.new(1, 0, 0, 35)
		ModuleButton.BackgroundColor3 = Color3.fromRGB(17, 17, 17)
		ModuleButton.BorderSizePixel = 0
		ModuleButton.AutoButtonColor = false
		ModuleButton.Text = ""
		ModuleButton.TextSize = 16
		ModuleButton.ZIndex = 4
		ModuleButton.Parent = ModuleContainer

		local NameLabel = Instance.new("TextLabel")
		NameLabel.Name = "ModuleName"
		NameLabel.Size = UDim2.new(1, -34, 1, 0)
		NameLabel.Position = UDim2.new(0, 8, 0, 0)
		NameLabel.BackgroundTransparency = 1
		NameLabel.Text = ModuleData.Name
		NameLabel.TextSize = 16
		NameLabel.TextColor3 = Color3.fromRGB(205, 205, 205)
		NameLabel.TextXAlignment = Enum.TextXAlignment.Left
		NameLabel.TextYAlignment = Enum.TextYAlignment.Center
		NameLabel.Font = Enum.Font.GothamBold
		NameLabel.ZIndex = 5
		NameLabel.Parent = ModuleButton

		local ArrowButton = Instance.new("TextButton")
		ArrowButton.Name = "ExpandArrow"
		ArrowButton.Size = UDim2.new(0, 18, 1, 0)
		ArrowButton.AnchorPoint = Vector2.new(1, 0)
		ArrowButton.Position = UDim2.new(1, -6, 0, 0)
		ArrowButton.BackgroundTransparency = 1
		ArrowButton.AutoButtonColor = false
		ArrowButton.Text = ">"
		ArrowButton.TextSize = 16
		ArrowButton.TextColor3 = Color3.fromRGB(170, 170, 170)
		ArrowButton.Font = Enum.Font.GothamBold
		ArrowButton.Visible = false
		ArrowButton.ZIndex = 6
		ArrowButton.Parent = ModuleButton

		local OptionsHolder = Instance.new("Frame")
		OptionsHolder.Name = "OptionsHolder"
		OptionsHolder.Size = UDim2.new(1, 0, 0, 0)
		OptionsHolder.Position = UDim2.new(0, 0, 0, 35)
		OptionsHolder.BackgroundTransparency = 1
		OptionsHolder.BorderSizePixel = 0
		OptionsHolder.ClipsDescendants = true
		OptionsHolder.ZIndex = 4
		OptionsHolder.Parent = ModuleContainer

		local OptionsLayout = Instance.new("UIListLayout")
		OptionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		OptionsLayout.Padding = UDim.new(0, 0)
		OptionsLayout.Parent = OptionsHolder

		local Module = {
			Name = ModuleData.Name,
			ConfigKey = BuildConfigKey(self.Name, ModuleData.Name),
			Enabled = false,
			Expanded = false,
			RunId = 0,
			Function = ModuleData.Function,
			ToolTip = ModuleData.ToolTip or ModuleData.Tooltip,
			Container = ModuleContainer,
			Button = ModuleButton,
			NameLabel = NameLabel,
			ArrowButton = ArrowButton,
			OptionsHolder = OptionsHolder,
			OptionsLayout = OptionsLayout,
			ToggleList = {},
			Toggles = {},
			SliderList = {},
			Sliders = {},
			DropdownList = {},
			Dropdowns = {},
			Category = self,
			Cleanups = {},
			Tweens = {}
		}

		OptionsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			UpdateModuleLayout(Module)
			UpdateCategorySize(Module.Category)
		end)

		function Module:Clean(item)
			table.insert(self.Cleanups, item)
			return item
		end

		function Module:Cleanup()
			for index = #self.Cleanups, 1, -1 do
				CleanupItem(self.Cleanups[index])
				table.remove(self.Cleanups, index)
			end
		end

		function Module:GetRunId()
			return self.RunId
		end

		function Module:IsActive(runId)
			if runId == nil then
				return self.Enabled
			end

			return self.Enabled and self.RunId == runId
		end

		function Module:SetEnabled(state, options)
			options = options or {}
			state = not not state
			if self.Enabled == state then
				return
			end

			self.Enabled = state
			self.RunId = self.RunId + 1
			local currentRunId = self.RunId
			RefreshModuleDisplay(self)

			if not options.SkipConfig then
				SetConfigValue("Module", self.ConfigKey, self.Enabled)
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
							warn(("TaskAPI Module '%s' failed: %s"):format(self.Name, tostring(err)))
							self.Enabled = false
							RefreshModuleDisplay(self)
							SetConfigValue("Module", self.ConfigKey, false)
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
						warn(("TaskAPI Module '%s' disable failed: %s"):format(self.Name, tostring(err)))
						TaskAPI.Notification({
							Title = "Taskium",
							Message = tostring(err),
							Duration = 4,
							Type = "Error"
						})
					end
				end
			end

			for _, Toggle in ipairs(self.ToggleList) do
				Toggle:ApplyCurrentState()
			end

			if not self.Enabled then
				self:Cleanup()
			end
		end

		function Module:Toggle()
			self:SetEnabled(not self.Enabled)
		end

		function Module:SetExpanded(state)
			self.Expanded = not not state
			UpdateModuleLayout(self, true)
			UpdateCategorySize(self.Category)
			RefreshModuleDisplay(self)
		end

		function Module:CreateToggle(ToggleData)
			if not ToggleData or type(ToggleData.Name) ~= "string" or ToggleData.Name == "" then
				error(("Module '%s' requires a valid Toggle name"):format(self.Name))
			end

			if self.Toggles[ToggleData.Name] then
				error(("Toggle '%s' already exists in Module '%s'"):format(ToggleData.Name, self.Name))
			end

			if ToggleData.Function ~= nil and type(ToggleData.Function) ~= "function" then
				error(("Toggle '%s' Function must be a function"):format(ToggleData.Name))
			end

			local ToggleButton = Instance.new("TextButton")
			ToggleButton.Name = ToggleData.Name
			ToggleButton.Size = UDim2.new(1, 0, 0, 30)
			ToggleButton.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
			ToggleButton.BorderSizePixel = 0
			ToggleButton.AutoButtonColor = false
			ToggleButton.Text = ""
			ToggleButton.ZIndex = 4
			ToggleButton.Parent = self.OptionsHolder

			local ToggleNameLabel = Instance.new("TextLabel")
			ToggleNameLabel.Name = "ToggleName"
			ToggleNameLabel.Size = UDim2.new(1, -76, 1, 0)
			ToggleNameLabel.Position = UDim2.new(0, 18, 0, 0)
			ToggleNameLabel.BackgroundTransparency = 1
			ToggleNameLabel.Text = ToggleData.Name
			ToggleNameLabel.TextSize = 14
			ToggleNameLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			ToggleNameLabel.TextXAlignment = Enum.TextXAlignment.Left
			ToggleNameLabel.TextYAlignment = Enum.TextYAlignment.Center
			ToggleNameLabel.Font = Enum.Font.Gotham
			ToggleNameLabel.ZIndex = 5
			ToggleNameLabel.Parent = ToggleButton

			local ToggleStateLabel = Instance.new("TextLabel")
			ToggleStateLabel.Name = "ToggleState"
			ToggleStateLabel.Size = UDim2.new(0, 44, 1, 0)
			ToggleStateLabel.AnchorPoint = Vector2.new(1, 0)
			ToggleStateLabel.Position = UDim2.new(1, -8, 0, 0)
			ToggleStateLabel.BackgroundTransparency = 1
			ToggleStateLabel.Text = "Off"
			ToggleStateLabel.TextSize = 13
			ToggleStateLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
			ToggleStateLabel.TextXAlignment = Enum.TextXAlignment.Right
			ToggleStateLabel.TextYAlignment = Enum.TextYAlignment.Center
			ToggleStateLabel.Font = Enum.Font.Gotham
			ToggleStateLabel.ZIndex = 5
			ToggleStateLabel.Parent = ToggleButton

			local Toggle = {
				Name = ToggleData.Name,
				ConfigKey = BuildConfigKey(self.ConfigKey, ToggleData.Name),
				Enabled = false,
				Value = false,
				Active = false,
				Function = ToggleData.Function,
				ToolTip = ToggleData.ToolTip or ToggleData.Tooltip,
				Button = ToggleButton,
				NameLabel = ToggleNameLabel,
				StateLabel = ToggleStateLabel,
				Module = self,
				ControlHeight = 30
			}

			function Toggle:ApplyCurrentState(forceCallback)
				RefreshToggleDisplay(self)

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
					warn(("TaskAPI Toggle '%s' failed: %s"):format(self.Name, tostring(err)))
					TaskAPI.Notification({
						Title = "Taskium",
						Message = tostring(err),
						Duration = 4,
						Type = "Error"
					})
				end
			end

			function Toggle:SetEnabled(state, options)
				options = options or {}
				state = not not state
				if self.Value == state then
					RefreshToggleDisplay(self)
					return
				end

				self.Value = state
				RefreshToggleDisplay(self)

				if not options.SkipConfig then
					SetConfigValue("Toggle", self.ConfigKey, self.Value)
				end

				if self.Module and self.Module.Enabled then
					self:ApplyCurrentState()
				else
					self.Enabled = false
					self.Active = false
				end
			end

			function Toggle:Toggle()
				self:SetEnabled(not self.Value)
			end

			ToggleButton.MouseButton1Click:Connect(function()
				Toggle:Toggle()
			end)

			table.insert(self.ToggleList, Toggle)
			self.Toggles[Toggle.Name] = Toggle
			UpdateModuleLayout(self)
			UpdateCategorySize(self.Category)
			RefreshModuleDisplay(self)
			Toggle.Value = RegisterConfigValue("Toggle", Toggle.ConfigKey, false)
			Toggle.Enabled = false
			Toggle.Active = false
			RefreshToggleDisplay(Toggle)

			return Toggle
		end

		function Module:CreateSlider(SliderData)
			if not SliderData or type(SliderData.Name) ~= "string" or SliderData.Name == "" then
				error(("Module '%s' requires a valid Slider name"):format(self.Name))
			end

			if self.Sliders[SliderData.Name] then
				error(("Slider '%s' already exists in Module '%s'"):format(SliderData.Name, self.Name))
			end

			if SliderData.Function ~= nil and type(SliderData.Function) ~= "function" then
				error(("Slider '%s' Function must be a function"):format(SliderData.Name))
			end

			local MinValue = tonumber(SliderData.Min or SliderData.Minimum or 0) or 0
			local MaxValue = tonumber(SliderData.Max or SliderData.Maximum or 100) or 100
			local DefaultValue = tonumber(SliderData.Default or SliderData.Value or MinValue) or MinValue

			if MaxValue < MinValue then
				MinValue, MaxValue = MaxValue, MinValue
			end

			DefaultValue = math.clamp(DefaultValue, MinValue, MaxValue)

			local SliderButton = Instance.new("TextButton")
			SliderButton.Name = SliderData.Name
			SliderButton.Size = UDim2.new(1, 0, 0, 46)
			SliderButton.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
			SliderButton.BorderSizePixel = 0
			SliderButton.AutoButtonColor = false
			SliderButton.Text = ""
			SliderButton.ZIndex = 4
			SliderButton.Parent = self.OptionsHolder

			local SliderNameLabel = Instance.new("TextLabel")
			SliderNameLabel.Name = "SliderName"
			SliderNameLabel.Size = UDim2.new(1, -76, 0, 18)
			SliderNameLabel.Position = UDim2.new(0, 18, 0, 5)
			SliderNameLabel.BackgroundTransparency = 1
			SliderNameLabel.Text = SliderData.Name
			SliderNameLabel.TextSize = 14
			SliderNameLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			SliderNameLabel.TextXAlignment = Enum.TextXAlignment.Left
			SliderNameLabel.TextYAlignment = Enum.TextYAlignment.Center
			SliderNameLabel.Font = Enum.Font.Gotham
			SliderNameLabel.ZIndex = 5
			SliderNameLabel.Parent = SliderButton

			local SliderValueLabel = Instance.new("TextLabel")
			SliderValueLabel.Name = "SliderValue"
			SliderValueLabel.Size = UDim2.new(0, 50, 0, 18)
			SliderValueLabel.AnchorPoint = Vector2.new(1, 0)
			SliderValueLabel.Position = UDim2.new(1, -8, 0, 5)
			SliderValueLabel.BackgroundTransparency = 1
			SliderValueLabel.Text = tostring(DefaultValue)
			SliderValueLabel.TextSize = 13
			SliderValueLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
			SliderValueLabel.TextXAlignment = Enum.TextXAlignment.Right
			SliderValueLabel.TextYAlignment = Enum.TextYAlignment.Center
			SliderValueLabel.Font = Enum.Font.Gotham
			SliderValueLabel.ZIndex = 5
			SliderValueLabel.Parent = SliderButton

			local SliderTrack = Instance.new("Frame")
			SliderTrack.Name = "SliderTrack"
			SliderTrack.Size = UDim2.new(1, -24, 0, 4)
			SliderTrack.Position = UDim2.new(0, 12, 0, 31)
			SliderTrack.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			SliderTrack.BorderSizePixel = 0
			SliderTrack.ZIndex = 5
			SliderTrack.Parent = SliderButton

			local SliderFill = Instance.new("Frame")
			SliderFill.Name = "SliderFill"
			SliderFill.Size = UDim2.new(0, 0, 1, 0)
			SliderFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			SliderFill.BorderSizePixel = 0
			SliderFill.ZIndex = 6
			SliderFill.Parent = SliderTrack

			local SliderKnob = Instance.new("Frame")
			SliderKnob.Name = "SliderKnob"
			SliderKnob.Size = UDim2.new(0, 8, 0, 8)
			SliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
			SliderKnob.Position = UDim2.new(0, 0, 0.5, 0)
			SliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			SliderKnob.BorderSizePixel = 0
			SliderKnob.ZIndex = 7
			SliderKnob.Parent = SliderTrack

			local SliderKnobCorner = Instance.new("UICorner")
			SliderKnobCorner.CornerRadius = UDim.new(1, 0)
			SliderKnobCorner.Parent = SliderKnob

			local Slider = {
				Name = SliderData.Name,
				ConfigKey = BuildConfigKey(self.ConfigKey, SliderData.Name),
				Min = MinValue,
				Max = MaxValue,
				Value = DefaultValue,
				Function = SliderData.Function,
				ToolTip = SliderData.ToolTip or SliderData.Tooltip,
				Button = SliderButton,
				NameLabel = SliderNameLabel,
				ValueLabel = SliderValueLabel,
				Track = SliderTrack,
				Fill = SliderFill,
				Knob = SliderKnob,
				Module = self,
				ControlHeight = 46
			}

			local function SetSliderVisuals(value)
				local Alpha = 0
				if Slider.Max > Slider.Min then
					Alpha = (value - Slider.Min) / (Slider.Max - Slider.Min)
				end

				Slider.ValueLabel.Text = tostring(value)
				Slider.Fill.Size = UDim2.new(Alpha, 0, 1, 0)
				Slider.Knob.Position = UDim2.new(Alpha, 0, 0.5, 0)
			end

			function Slider:SetValue(value, skipCallback, options)
				options = options or {}
				value = math.clamp(math.floor((tonumber(value) or self.Value) + 0.5), self.Min, self.Max)
				if self.Value == value then
					SetSliderVisuals(value)
					if not skipCallback and options.ForceCallback and self.Function then
						local ok, err = pcall(self.Function, self.Value)
						if not ok then
							warn(("TaskAPI Slider '%s' failed: %s"):format(self.Name, tostring(err)))
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
				SetSliderVisuals(value)

				if not options.SkipConfig then
					SetConfigValue("Slider", self.ConfigKey, self.Value)
				end

				if not skipCallback and self.Function then
					local ok, err = pcall(self.Function, self.Value)
					if not ok then
						warn(("TaskAPI Slider '%s' failed: %s"):format(self.Name, tostring(err)))
						TaskAPI.Notification({
							Title = "Taskium",
							Message = tostring(err),
							Duration = 4,
							Type = "Error"
						})
					end
				end
			end

			local DraggingSlider = false

			local function SetFromMousePosition(mouseX)
				local Alpha = math.clamp((mouseX - Slider.Track.AbsolutePosition.X) / Slider.Track.AbsoluteSize.X, 0, 1)
				local value = Slider.Min + ((Slider.Max - Slider.Min) * Alpha)
				Slider:SetValue(value)
			end

			SliderButton.MouseButton1Down:Connect(function(mouseX)
				DraggingSlider = true
				SetFromMousePosition(mouseX)
			end)

			InputService.InputChanged:Connect(function(Input)
				if DraggingSlider and Input.UserInputType == Enum.UserInputType.MouseMovement then
					SetFromMousePosition(Input.Position.X)
				end
			end)

			InputService.InputEnded:Connect(function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 then
					DraggingSlider = false
				end
			end)

			table.insert(self.SliderList, Slider)
			self.Sliders[Slider.Name] = Slider
			UpdateModuleLayout(self)
			UpdateCategorySize(self.Category)
			Slider:SetValue(RegisterConfigValue("Slider", Slider.ConfigKey, DefaultValue), false, {
				SkipConfig = true,
				ForceCallback = true
			})

			return Slider
		end

		function Module:CreateDropdown(DropdownData)
			if not DropdownData or type(DropdownData.Name) ~= "string" or DropdownData.Name == "" then
				error(("Module '%s' requires a valid Dropdown name"):format(self.Name))
			end

			if self.Dropdowns[DropdownData.Name] then
				error(("Dropdown '%s' already exists in Module '%s'"):format(DropdownData.Name, self.Name))
			end

			if DropdownData.Function ~= nil and type(DropdownData.Function) ~= "function" then
				error(("Dropdown '%s' Function must be a function"):format(DropdownData.Name))
			end

			if type(DropdownData.List) ~= "table" or #DropdownData.List == 0 then
				error(("Dropdown '%s' requires a non-empty List"):format(DropdownData.Name))
			end

			local DropdownContainer = Instance.new("Frame")
			DropdownContainer.Name = DropdownData.Name .. "_Dropdown"
			DropdownContainer.Size = UDim2.new(1, 0, 0, 30)
			DropdownContainer.BackgroundTransparency = 1
			DropdownContainer.BorderSizePixel = 0
			DropdownContainer.ZIndex = 4
			DropdownContainer.Parent = self.OptionsHolder

			local DropdownButton = Instance.new("TextButton")
			DropdownButton.Name = DropdownData.Name
			DropdownButton.Size = UDim2.new(1, 0, 0, 30)
			DropdownButton.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
			DropdownButton.BorderSizePixel = 0
			DropdownButton.AutoButtonColor = false
			DropdownButton.Text = ""
			DropdownButton.ZIndex = 4
			DropdownButton.Parent = DropdownContainer

			local DropdownNameLabel = Instance.new("TextLabel")
			DropdownNameLabel.Name = "DropdownName"
			DropdownNameLabel.Size = UDim2.new(0.5, -18, 1, 0)
			DropdownNameLabel.Position = UDim2.new(0, 18, 0, 0)
			DropdownNameLabel.BackgroundTransparency = 1
			DropdownNameLabel.Text = DropdownData.Name
			DropdownNameLabel.TextSize = 14
			DropdownNameLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			DropdownNameLabel.TextXAlignment = Enum.TextXAlignment.Left
			DropdownNameLabel.TextYAlignment = Enum.TextYAlignment.Center
			DropdownNameLabel.Font = Enum.Font.Gotham
			DropdownNameLabel.ZIndex = 5
			DropdownNameLabel.Parent = DropdownButton

			local DropdownValueLabel = Instance.new("TextLabel")
			DropdownValueLabel.Name = "DropdownValue"
			DropdownValueLabel.Size = UDim2.new(0.5, -34, 1, 0)
			DropdownValueLabel.AnchorPoint = Vector2.new(1, 0)
			DropdownValueLabel.Position = UDim2.new(1, -24, 0, 0)
			DropdownValueLabel.BackgroundTransparency = 1
			DropdownValueLabel.Text = ""
			DropdownValueLabel.TextSize = 13
			DropdownValueLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
			DropdownValueLabel.TextXAlignment = Enum.TextXAlignment.Right
			DropdownValueLabel.TextYAlignment = Enum.TextYAlignment.Center
			DropdownValueLabel.Font = Enum.Font.Gotham
			DropdownValueLabel.ZIndex = 5
			DropdownValueLabel.Parent = DropdownButton

			local DropdownArrow = Instance.new("TextButton")
			DropdownArrow.Name = "DropdownArrow"
			DropdownArrow.Size = UDim2.new(0, 18, 1, 0)
			DropdownArrow.AnchorPoint = Vector2.new(1, 0)
			DropdownArrow.Position = UDim2.new(1, -6, 0, 0)
			DropdownArrow.BackgroundTransparency = 1
			DropdownArrow.AutoButtonColor = false
			DropdownArrow.Text = ">"
			DropdownArrow.TextSize = 14
			DropdownArrow.TextColor3 = Color3.fromRGB(170, 170, 170)
			DropdownArrow.Font = Enum.Font.GothamBold
			DropdownArrow.ZIndex = 6
			DropdownArrow.Parent = DropdownButton

			local ListHolder = Instance.new("Frame")
			ListHolder.Name = "ListHolder"
			ListHolder.Size = UDim2.new(1, 0, 0, 0)
			ListHolder.Position = UDim2.new(0, 0, 0, 30)
			ListHolder.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
			ListHolder.BackgroundTransparency = 0
			ListHolder.BorderSizePixel = 0
			ListHolder.ClipsDescendants = true
			ListHolder.ZIndex = 4
			ListHolder.Parent = DropdownContainer

			local ListLayout = Instance.new("UIListLayout")
			ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
			ListLayout.Padding = UDim.new(0, 0)
			ListLayout.Parent = ListHolder

			local Dropdown = {
				Name = DropdownData.Name,
				ConfigKey = BuildConfigKey(self.ConfigKey, DropdownData.Name),
				List = {},
				Value = nil,
				Expanded = false,
				Function = DropdownData.Function,
				ToolTip = DropdownData.ToolTip or DropdownData.Tooltip,
				Container = DropdownContainer,
				Button = DropdownButton,
				NameLabel = DropdownNameLabel,
				ValueLabel = DropdownValueLabel,
				ArrowButton = DropdownArrow,
				ListHolder = ListHolder,
				Options = {},
				Module = self,
				ControlHeight = 30,
				Tweens = {}
			}

			for _, option in ipairs(DropdownData.List) do
				table.insert(Dropdown.List, tostring(option))
			end

			local function UpdateDropdownDisplay(Animate)
				Dropdown.ValueLabel.Text = tostring(Dropdown.Value or "")
				Dropdown.ArrowButton.Text = Dropdown.Expanded and "v" or ">"

				local OptionHeight = 28
				local TotalHeight = 0
				if Dropdown.Expanded and #Dropdown.Options > 0 then
					TotalHeight = #Dropdown.Options * OptionHeight
				end

				if Animate then
					TweenYSize(Dropdown.ListHolder, TotalHeight, Dropdown.Tweens, "ListHolder")
					TweenYSize(Dropdown.Container, 30 + TotalHeight, Dropdown.Tweens, "Container")
				else
					Dropdown.ListHolder.Size = UDim2.new(1, 0, 0, TotalHeight)
					Dropdown.Container.Size = UDim2.new(1, 0, 0, 30 + TotalHeight)
				end

				Dropdown.ControlHeight = 30 + TotalHeight

				for _, OptionButton in ipairs(Dropdown.Options) do
					local isSelected = OptionButton:GetAttribute("OptionValue") == Dropdown.Value
					OptionButton.BackgroundColor3 = isSelected and Color3.fromRGB(32, 32, 32) or Color3.fromRGB(22, 22, 22)
					local OptionLabel = OptionButton:FindFirstChild("OptionLabel")
					if OptionLabel then
						OptionLabel.TextColor3 = isSelected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(190, 190, 190)
					end
				end
			end

			function Dropdown:SetExpanded(state)
				self.Expanded = not not state
				UpdateDropdownDisplay(true)
				UpdateModuleLayout(self.Module)
				UpdateCategorySize(self.Module.Category)
				RefreshModuleDisplay(self.Module)
			end

			function Dropdown:SetValue(value, skipCallback, options)
				options = options or {}
				value = tostring(value)

				local matchedValue = nil
				for _, OptionValue in ipairs(self.List) do
					if OptionValue == value then
						matchedValue = OptionValue
						break
					end
				end

				if matchedValue == nil then
					return
				end

				if self.Value == matchedValue then
					UpdateDropdownDisplay(false)
					if not skipCallback and options.ForceCallback and self.Function then
						local ok, err = pcall(self.Function, self.Value)
						if not ok then
							warn(("TaskAPI Dropdown '%s' failed: %s"):format(self.Name, tostring(err)))
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
				UpdateDropdownDisplay(false)

				if not options.SkipConfig then
					SetConfigValue("Dropdown", self.ConfigKey, self.Value)
				end

				if not skipCallback and self.Function then
					local ok, err = pcall(self.Function, self.Value)
					if not ok then
						warn(("TaskAPI Dropdown '%s' failed: %s"):format(self.Name, tostring(err)))
						TaskAPI.Notification({
							Title = "Taskium",
							Message = tostring(err),
							Duration = 4,
							Type = "Error"
						})
					end
				end
			end

			for _, OptionValue in ipairs(Dropdown.List) do
				local OptionButton = Instance.new("TextButton")
				OptionButton.Name = OptionValue
				OptionButton.Size = UDim2.new(1, 0, 0, 28)
				OptionButton.Position = UDim2.new(0, 0, 0, 0)
				OptionButton.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
				OptionButton.BorderSizePixel = 0
				OptionButton.AutoButtonColor = false
				OptionButton.Text = ""
				OptionButton.ZIndex = 5
				OptionButton:SetAttribute("OptionValue", OptionValue)
				OptionButton.Parent = Dropdown.ListHolder

				local OptionLabel = Instance.new("TextLabel")
				OptionLabel.Name = "OptionLabel"
				OptionLabel.Size = UDim2.new(1, -36, 1, 0)
				OptionLabel.Position = UDim2.new(0, 18, 0, 0)
				OptionLabel.BackgroundTransparency = 1
				OptionLabel.Text = OptionValue
				OptionLabel.TextSize = 13
				OptionLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
				OptionLabel.TextXAlignment = Enum.TextXAlignment.Left
				OptionLabel.TextYAlignment = Enum.TextYAlignment.Center
				OptionLabel.Font = Enum.Font.Gotham
				OptionLabel.ZIndex = 6
				OptionLabel.Parent = OptionButton

				OptionButton.MouseButton1Click:Connect(function()
					Dropdown:SetValue(OptionValue)
					Dropdown:SetExpanded(false)
				end)

				table.insert(Dropdown.Options, OptionButton)
			end

			DropdownButton.MouseButton2Click:Connect(function()
				Dropdown:SetExpanded(not Dropdown.Expanded)
			end)

			DropdownArrow.MouseButton2Click:Connect(function()
				Dropdown:SetExpanded(not Dropdown.Expanded)
			end)

			DropdownButton.MouseEnter:Connect(function()
				ShowToolTip(Dropdown.ToolTip)
			end)

			DropdownButton.MouseLeave:Connect(function()
				HideToolTip()
			end)

			table.insert(self.DropdownList, Dropdown)
			self.Dropdowns[Dropdown.Name] = Dropdown
			UpdateDropdownDisplay(false)
			UpdateModuleLayout(self)
			UpdateCategorySize(self.Category)
			RefreshModuleDisplay(self)

			local DefaultValue = tostring(DropdownData.Default or Dropdown.List[1])
			Dropdown:SetValue(RegisterConfigValue("Dropdown", Dropdown.ConfigKey, DefaultValue), false, {
				SkipConfig = true,
				ForceCallback = true
			})

			return Dropdown
		end

		if type(ModuleData.Toggles) == "table" then
			for _, ToggleData in ipairs(ModuleData.Toggles) do
				Module:CreateToggle(ToggleData)
			end
		end

		if type(ModuleData.Sliders) == "table" then
			for _, SliderData in ipairs(ModuleData.Sliders) do
				Module:CreateSlider(SliderData)
			end
		end

		if type(ModuleData.Dropdowns) == "table" then
			for _, DropdownData in ipairs(ModuleData.Dropdowns) do
				Module:CreateDropdown(DropdownData)
			end
		end

		ModuleButton.MouseButton1Click:Connect(function()
			Module:Toggle()
		end)

		ModuleButton.MouseEnter:Connect(function()
			ShowToolTip(Module.ToolTip)
		end)

		ModuleButton.MouseLeave:Connect(function()
			HideToolTip()
		end)

		ModuleButton.MouseButton2Click:Connect(function()
			if (#Module.ToggleList + #Module.SliderList + #Module.DropdownList) > 0 then
				Module:SetExpanded(not Module.Expanded)
			end
		end)

		ArrowButton.MouseButton1Click:Connect(function()
			Module:SetExpanded(not Module.Expanded)
		end)

		task.spawn(function()
			while ModuleButton.Parent do
				RefreshModuleDisplay(Module)
				task.wait(0.15)
			end
		end)

		table.insert(self.ModuleList, Module)
		self.Modules[Module.Name] = Module
		TaskAPI.Modules[Module.Name] = Module

		UpdateModuleLayout(Module)
		UpdateCategorySize(self)
		RefreshModuleDisplay(Module)

		local SavedModuleState = RegisterConfigValue("Module", Module.ConfigKey, false)
		if SavedModuleState then
			task.defer(function()
				if Module.Button and Module.Button.Parent then
					Module:SetEnabled(true, {
						SkipConfig = true,
						SkipNotify = true
					})
				end
			end)
		end

		return Module
	end

	local Dragging = false
	local DragStart
	local StartPosition

	CategoryFrame.InputBegan:Connect(function(Input)
		if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		Dragging = true
		DragStart = Input.Position
		StartPosition = ContainerFrame.Position
	end)

	CategoryFrame.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			Dragging = false
			Category.Position = ContainerFrame.Position
		end
	end)

	InputService.InputChanged:Connect(function(Input)
		if not Dragging or Input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end

		local Delta = Input.Position - DragStart
		ContainerFrame.Position = UDim2.new(
			StartPosition.X.Scale,
			StartPosition.X.Offset + Delta.X,
			StartPosition.Y.Scale,
			StartPosition.Y.Offset + Delta.Y
		)
		Category.Position = ContainerFrame.Position
	end)

	self.Categories[Category.Name] = Category
	table.insert(self.CategoryList, Category)
	UpdateCategorySize(Category)

	return Category
end

InputService.InputBegan:Connect(function(Input, GameProcessed)
	if GameProcessed then
		return
	end

	if Input.KeyCode == Enum.KeyCode.RightShift then
		ScreenGui.Enabled = not ScreenGui.Enabled
		BlurEffect.Enabled = ScreenGui.Enabled
		if not ScreenGui.Enabled then
			HideToolTip()
		end
	end
end)

InputService.InputChanged:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.MouseMovement and ActiveToolTipText then
		UpdateToolTipPosition(Input.Position)
	end
end)

table.insert(TaskAPI.Connections, LogService.MessageOut:Connect(function(message, messageType)
	if messageType ~= Enum.MessageType.MessageError and messageType ~= Enum.MessageType.MessageWarning then
		return
	end

	TaskAPI.Notification({
		Title = GetConsoleNotificationTitle(messageType),
		Message = tostring(message),
		Duration = 5,
		Type = GetConsoleNotificationType(messageType),
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

	ShutdownAPI(self)
end

return TaskAPI