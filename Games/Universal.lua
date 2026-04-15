local TaskAPI = getgenv().TaskAPI or (getgenv().Taskium and getgenv().Taskium.API)
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer and LocalPlayer:WaitForChild("PlayerGui")

if not TaskAPI or not TaskAPI.Categories or not TaskAPI.Categories.Combat or not TaskAPI.Categories.Render then
	error("Required categories were not loaded before Games/Universal.lua")
end

local TestModule
local ArraylistModule
local PrintSpeed = 20
local MoveMode = "Direct"
TestModule = TaskAPI.Categories.Combat:CreateModule({
	Name = "TestModuleA",
	Function = function(enabled, runId, module)
		print(enabled, "module state")

		if enabled then
			TestModule:Clean(Instance.new("Part"))

			repeat
				print("repeat loop!")
				task.wait(math.max(0.05, (41 - PrintSpeed) * 0.05))
			until (not module:IsActive(runId))
		end
	end,
	Tooltip = "This is a test module.",
	Toggles = {
		{
			Name = "Toggle",
			Function = function(callback)
				print(callback, "toggle enabled!")
			end,
			Tooltip = "This is a test toggle."
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
			Tooltip = "Adjusts the speed of the print."
		}
	},
	Dropdowns = {
		{
			Name = "Move Mode",
			List = { "Direct", "InDirect" },
			Function = function(val)
				MoveMode = val
				print(val, "dropdown value changed")
			end,
			Tooltip = "This is a test dropdown."
		}
	}
})

ArraylistModule = TaskAPI.Categories.Render:CreateModule({
	Name = "Arraylist",
	Function = function(enabled, runId, module)
		if not enabled then
			return
		end

		local arraylistGui = Instance.new("ScreenGui")
		arraylistGui.Name = "TaskiumArraylist"
		arraylistGui.ResetOnSpawn = false
		arraylistGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		arraylistGui.Parent = PlayerGui
		module:Clean(arraylistGui)

		local rootFrame = Instance.new("Frame")
		rootFrame.Name = "Root"
		rootFrame.AnchorPoint = Vector2.new(1, 0)
		rootFrame.Position = UDim2.new(1, -12, 0, 12)
		rootFrame.Size = UDim2.new(0, 0, 0, 0)
		rootFrame.BackgroundTransparency = 1
		rootFrame.BorderSizePixel = 0
		rootFrame.Parent = arraylistGui

		local backgroundFrame = Instance.new("Frame")
		backgroundFrame.Name = "Background"
		backgroundFrame.Size = UDim2.new(0, 0, 0, 0)
		backgroundFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		backgroundFrame.BackgroundTransparency = 0.58
		backgroundFrame.BorderSizePixel = 0
		backgroundFrame.Parent = rootFrame

		local entriesHolder = Instance.new("Frame")
		entriesHolder.Name = "EntriesHolder"
		entriesHolder.Size = UDim2.new(0, 0, 0, 0)
		entriesHolder.BackgroundTransparency = 1
		entriesHolder.BorderSizePixel = 0
		entriesHolder.Parent = rootFrame

		local listLayout = Instance.new("UIListLayout")
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Padding = UDim.new(0, 0)
		listLayout.Parent = entriesHolder

		local sideLine = Instance.new("Frame")
		sideLine.Name = "SideLine"
		sideLine.AnchorPoint = Vector2.new(1, 0)
		sideLine.Position = UDim2.new(1, 0, 0, 0)
		sideLine.Size = UDim2.new(0, 3, 0, 0)
		sideLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		sideLine.BorderSizePixel = 0
		sideLine.Parent = rootFrame

		local sideLineGradient = Instance.new("UIGradient")
		sideLineGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
		})
		sideLineGradient.Rotation = 90
		sideLineGradient.Parent = sideLine

		local animatedGradients = {}

		local function applyBlackToWhiteGradient(guiObject, rotation)
			local gradient = Instance.new("UIGradient")
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
			})
			gradient.Rotation = rotation or 0
			gradient.Parent = guiObject
			table.insert(animatedGradients, gradient)
			return gradient
		end

		local function getEnabledModules()
			local enabledModules = {}

			for _, listedModule in pairs(TaskAPI.Modules) do
				if listedModule.Enabled then
					table.insert(enabledModules, listedModule)
				end
			end

			table.sort(enabledModules, function(left, right)
				local leftLength = #left.Name
				local rightLength = #right.Name

				if leftLength == rightLength then
					return left.Name > right.Name
				end

				return leftLength > rightLength
			end)

			return enabledModules
		end

		local function clearEntries()
			for _, child in ipairs(entriesHolder:GetChildren()) do
				if not child:IsA("UIListLayout") then
					child:Destroy()
				end
			end
		end

		local function renderArraylist()
			clearEntries()
			animatedGradients = {}

			local enabledModules = getEnabledModules()
			local maxWidth = 0
			local rowHeight = 26
			local textSize = 17

			for _, listedModule in ipairs(enabledModules) do
				local textBounds = TextService:GetTextSize(listedModule.Name, textSize, Enum.Font.GothamBold, Vector2.new(1000, rowHeight))
				maxWidth = math.max(maxWidth, textBounds.X + 34)
			end

			if maxWidth < 80 then
				maxWidth = 80
			end

			for index, listedModule in ipairs(enabledModules) do
				local row = Instance.new("Frame")
				row.Name = listedModule.Name
				row.Size = UDim2.new(0, maxWidth, 0, rowHeight)
				row.BackgroundTransparency = 1
				row.BorderSizePixel = 0
				row.LayoutOrder = index
				row.Parent = entriesHolder

				local nameLabel = Instance.new("TextLabel")
				nameLabel.Name = "ModuleName"
				nameLabel.Size = UDim2.new(1, -12, 1, 0)
				nameLabel.Position = UDim2.new(0, 0, 0, 0)
				nameLabel.BackgroundTransparency = 1
				nameLabel.Text = listedModule.Name
				nameLabel.TextSize = textSize
				nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				nameLabel.TextXAlignment = Enum.TextXAlignment.Right
				nameLabel.TextYAlignment = Enum.TextYAlignment.Center
				nameLabel.Font = Enum.Font.GothamBold
				nameLabel.Parent = row
				applyBlackToWhiteGradient(nameLabel, 0)
			end

			local totalHeight = #enabledModules * rowHeight
			rootFrame.Size = UDim2.new(0, maxWidth, 0, totalHeight)
			entriesHolder.Size = UDim2.new(0, maxWidth, 0, totalHeight)
			backgroundFrame.Size = UDim2.new(0, maxWidth, 0, totalHeight)
			sideLine.Size = UDim2.new(0, 3, 0, totalHeight)

			local gradientOffset = (tick() * 0.35) % 2 - 1
			sideLineGradient.Offset = Vector2.new(gradientOffset, 0)
			for _, gradient in ipairs(animatedGradients) do
				gradient.Offset = Vector2.new(gradientOffset, 0)
			end
		end

		repeat
			renderArraylist()
			task.wait(0.15)
		until (not module:IsActive(runId))
	end,
	Tooltip = "Displays enabled modules in the top-right corner."
})

return TaskAPI
