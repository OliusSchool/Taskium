local TaskAPI = getgenv().TaskAPI or (getgenv().Taskium and getgenv().Taskium.API)
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer and LocalPlayer:WaitForChild("PlayerGui")

if not TaskAPI or not TaskAPI.Categories then
	TaskAPI.Notification("Taskium", "TaskAPI categories were not loaded before Games/Universal.lua", 5, "Error")
	return TaskAPI
end

local TestModule
local ArraylistModule
local PrintSpeed = 20
local MoveMode = "Direct"
TestModule = TaskAPI.Categories.Combat:CreateModule({
	Name = "TestModuleA",
	Function = function(Enabled, RunId, Module)
		print(Enabled, "module state")

		if Enabled then
			TestModule:Clean(Instance.new("Part"))

			repeat
				print("repeat loop!")
				task.wait(math.max(0.05, (41 - PrintSpeed) * 0.05))
			until (not Module:IsActive(RunId))
		end
	end,
	ToolTip = "This is a test module.",
	Toggles = {
		{
			Name = "Toggle",
			Function = function(Callback)
				print(Callback, "toggle enabled!")
			end,
			ToolTip = "This is a test toggle."
		}
	},
	Sliders = {
		{
			Name = "Print Speed",
			Min = 1,
			Max = 40,
			Default = 20,
			Function = function(value)
				PrintSpeed = value
			end,
			ToolTip = "Adjusts the speed of the print."
		}
	},
	Dropdowns = {
		{
			Name = "Move Mode",
			List = { "Direct", "InDirect" },
			Function = function(Value)
				MoveMode = Value
				print(Value, "dropdown value changed")
			end,
			ToolTip = "This is a test dropdown."
		}
	}
})

local ArraylistModule
ArraylistModule = TaskAPI.Categories.Render:CreateModule({
	Name = "Arraylist",
	Function = function(Enabled, RunId, Module)
		if not Enabled then
			return
		end

		local ArraylistGui = Instance.new("ScreenGui")
		ArraylistGui.Name = "TaskiumArraylist"
		ArraylistGui.ResetOnSpawn = false
		ArraylistGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		ArraylistGui.Parent = PlayerGui
		Module:Clean(ArraylistGui)

		local RootFrame = Instance.new("Frame")
		RootFrame.Name = "Root"
		RootFrame.AnchorPoint = Vector2.new(1, 0)
		RootFrame.Position = UDim2.new(1, -12, 0, 12)
		RootFrame.Size = UDim2.new(0, 0, 0, 0)
		RootFrame.BackgroundTransparency = 1
		RootFrame.BorderSizePixel = 0
		RootFrame.Parent = ArraylistGui

		local BackgroundFrame = Instance.new("Frame")
		BackgroundFrame.Name = "Background"
		BackgroundFrame.Size = UDim2.new(0, 0, 0, 0)
		BackgroundFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		BackgroundFrame.BackgroundTransparency = 1
		BackgroundFrame.BorderSizePixel = 0
		BackgroundFrame.Parent = RootFrame

		local EntriesHolder = Instance.new("Frame")
		EntriesHolder.Name = "EntriesHolder"
		EntriesHolder.Size = UDim2.new(0, 0, 0, 0)
		EntriesHolder.BackgroundTransparency = 1
		EntriesHolder.BorderSizePixel = 0
		EntriesHolder.Parent = RootFrame

		local ListLayout = Instance.new("UIListLayout")
		ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		ListLayout.Padding = UDim.new(0, 0)
		ListLayout.Parent = EntriesHolder

		local SideLine = Instance.new("Frame")
		SideLine.Name = "SideLine"
		SideLine.AnchorPoint = Vector2.new(1, 0)
		SideLine.Position = UDim2.new(1, 0, 0, 0)
		SideLine.Size = UDim2.new(0, 3, 0, 0)
		SideLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		SideLine.BorderSizePixel = 0
		SideLine.Parent = RootFrame

		local function CreateMovingGradient(Gradient)
			Gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(0, 0, 0)),
				ColorSequenceKeypoint.new(0.35, Color3.fromRGB(0, 0, 0)),
				ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.65, Color3.fromRGB(0, 0, 0)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(0, 0, 0))
			})
		end

		local SideLineGradient = Instance.new("UIGradient")
		CreateMovingGradient(SideLineGradient)
		SideLineGradient.Rotation = 90
		SideLineGradient.Parent = SideLine

		local AnimatedGradients = {}

		local function ApplyBlackToWhiteGradient(GuiObject, Rotation)
			local Gradient = Instance.new("UIGradient")
			CreateMovingGradient(Gradient)
			Gradient.Rotation = Rotation or 0
			Gradient.Parent = GuiObject
			table.insert(AnimatedGradients, Gradient)
			return Gradient
		end

		local function GetEnabledModules()
			local EnabledModules = {}

			for _, ListedModule in pairs(TaskAPI.Modules) do
				if ListedModule.Enabled then
					table.insert(EnabledModules, ListedModule)
				end
			end

			table.sort(EnabledModules, function(Left, Right)
				local LeftLength = #Left.Name
				local RightLength = #Right.Name

				if LeftLength == RightLength then
					return Left.Name > Right.Name
				end

				return LeftLength > RightLength
			end)

			return EnabledModules
		end

		local function ClearEntries()
			for _, Child in ipairs(EntriesHolder:GetChildren()) do
				if not Child:IsA("UIListLayout") then
					Child:Destroy()
				end
			end
		end

		local function RenderArraylist()
			ClearEntries()
			AnimatedGradients = {}

			local EnabledModules = GetEnabledModules()
			local MaxWidth = 0
			local RowHeight = 28
			local TextSize = 18
			local BackgroundPadding = 24

			for _, ListedModule in ipairs(EnabledModules) do
				local TextBounds = TextService:GetTextSize(ListedModule.Name, TextSize, Enum.Font.GothamBold, Vector2.new(1000, RowHeight))
				MaxWidth = math.max(MaxWidth, TextBounds.X + BackgroundPadding + 10)
			end

			if MaxWidth < 80 then
				MaxWidth = 80
			end

			for Index, ListedModule in ipairs(EnabledModules) do
				local TextBounds = TextService:GetTextSize(ListedModule.Name, TextSize, Enum.Font.GothamBold, Vector2.new(1000, RowHeight))
				local BackgroundWidth = TextBounds.X + BackgroundPadding

				local Row = Instance.new("Frame")
				Row.Name = ListedModule.Name
				Row.Size = UDim2.new(0, MaxWidth, 0, RowHeight)
				Row.BackgroundTransparency = 1
				Row.BorderSizePixel = 0
				Row.LayoutOrder = Index
				Row.Parent = EntriesHolder

				local RowBackground = Instance.new("Frame")
				RowBackground.Name = "RowBackground"
				RowBackground.AnchorPoint = Vector2.new(1, 0)
				RowBackground.Position = UDim2.new(1, -3, 0, 0)
				RowBackground.Size = UDim2.new(0, BackgroundWidth, 1, 0)
				RowBackground.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				RowBackground.BackgroundTransparency = 0.58
				RowBackground.BorderSizePixel = 0
				RowBackground.Parent = Row

				local NameLabel = Instance.new("TextLabel")
				NameLabel.Name = "ModuleName"
				NameLabel.Size = UDim2.new(0, BackgroundWidth - 12, 1, 0)
				NameLabel.AnchorPoint = Vector2.new(1, 0)
				NameLabel.Position = UDim2.new(1, -9, 0, 0)
				NameLabel.BackgroundTransparency = 1
				NameLabel.Text = ListedModule.Name
				NameLabel.TextSize = TextSize
				NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				NameLabel.TextXAlignment = Enum.TextXAlignment.Right
				NameLabel.TextYAlignment = Enum.TextYAlignment.Center
				NameLabel.Font = Enum.Font.GothamBold
				NameLabel.Parent = Row
				ApplyBlackToWhiteGradient(NameLabel, 0)
			end

			local TotalHeight = #EnabledModules * RowHeight
			RootFrame.Size = UDim2.new(0, MaxWidth, 0, TotalHeight)
			EntriesHolder.Size = UDim2.new(0, MaxWidth, 0, TotalHeight)
			BackgroundFrame.Size = UDim2.new(0, MaxWidth, 0, TotalHeight)
			SideLine.Size = UDim2.new(0, 3, 0, TotalHeight)

			local GradientOffset = (tick() * 0.85) % 2 - 1
			SideLineGradient.Offset = Vector2.new(GradientOffset, 0)
			for _, Gradient in ipairs(AnimatedGradients) do
				Gradient.Offset = Vector2.new(GradientOffset, 0)
			end
		end

		repeat
			RenderArraylist()
			task.wait(0.15)
		until (not Module:IsActive(RunId))
	end,
	ToolTip = "Displays enabled modules in the top-right corner."
})

return TaskAPI
