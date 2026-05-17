local TaskAPI = getgenv().TaskAPI or (getgenv().Taskium and getgenv().Taskium.API)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer and LocalPlayer:WaitForChild("PlayerGui")

local RunModule = function(RunFunction)
	return RunFunction()
end

if not TaskAPI or not TaskAPI.Categories then
	TaskAPI.Notification("Taskium", "TaskAPI categories were not loaded before Games/Universal.lua", 5, "Error")
	return TaskAPI
end

local CreateTaskiumStore, SyncTaskiumStore, EnsureBedwarsRuntime, EnsureBedwarsShop, GetBedwarsState
local RoundToBlockGrid, GetPlacedBlockAt, GetBlocksInPoints
local RuntimeState = rawget(getgenv(), "TaskiumRuntimeState")

if type(RuntimeState) ~= "table" then
	RuntimeState = {}
	getgenv().TaskiumRuntimeState = RuntimeState
end

local function GetCharacterState(TargetPlayer)
	local Target = TargetPlayer or LocalPlayer
	local Character = Target and Target.Character
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	return Character, Humanoid, RootPart
end

local function IsLikelyBedwarsPlace()
	local TSFolder = ReplicatedStorage:FindFirstChild("TS")
	local ItemFolder = TSFolder and TSFolder:FindFirstChild("item")
	return ReplicatedStorage:FindFirstChild("rbxts_include") ~= nil
		and TSFolder ~= nil
		and TSFolder:FindFirstChild("remotes") ~= nil
		and ItemFolder ~= nil
		and ItemFolder:FindFirstChild("item-meta") ~= nil
end

local FlyModule, LongJumpModule
local GroundRaycast = RaycastParams.new()
GroundRaycast.RespectCanCollide = true

local function GetBedwarsSpeed()
	local BedwarsReference = rawget(getgenv(), "bedwars") or EnsureBedwarsRuntime()
	local SprintController = BedwarsReference and BedwarsReference.SprintController
	local MovementStatusModifier = SprintController and SprintController.getMovementStatusModifier and SprintController:getMovementStatusModifier()
	local Modifiers = MovementStatusModifier and MovementStatusModifier.getModifiers and MovementStatusModifier:getModifiers()
	if type(Modifiers) ~= "table" then
		return 20
	end

	local Multi = 0
	local Increase = true

	for _, Modifier in pairs(Modifiers) do
		local Value = type(Modifier) == "table" and Modifier.constantSpeedMultiplier or 0
		if Value and Value > math.max(Multi, 1) then
			Increase = false
			Multi = Value - (0.06 * math.round(Value))
		end
	end

	for _, Modifier in pairs(Modifiers) do
		local MoveSpeedMultiplier = type(Modifier) == "table" and Modifier.moveSpeedMultiplier or 0
		Multi = Multi + math.max(MoveSpeedMultiplier - 1, 0)
	end

	if Multi > 0 and Increase then
		Multi = Multi + 0.16 + (0.02 * math.round(Multi))
	end

	return 20 * (Multi + 1)
end

local function IsCharacterGrounded(RootPart)
	local Store = rawget(getgenv(), "store")
	local AirRay = Store and Store.airRay
	if AirRay then
		return workspace:Raycast(RootPart.Position, Vector3.new(0, -4.5, 0), AirRay) ~= nil
	end

	GroundRaycast.FilterDescendantsInstances = { LocalPlayer and LocalPlayer.Character, workspace.CurrentCamera }
	GroundRaycast.CollisionGroup = RootPart.CollisionGroup
	return workspace:Raycast(RootPart.Position, Vector3.new(0, -4.5, 0), GroundRaycast) ~= nil
end

local function CancelNoFallRootTween()
	local TweenState = RuntimeState.NoFallTween
	if type(TweenState) ~= "table" then
		return
	end

	if TweenState.Tween then
		pcall(function()
			TweenState.Tween:Cancel()
		end)
	end

	if TweenState.RootPart and TweenState.PreviousAnchored ~= nil then
		pcall(function()
			TweenState.RootPart.Anchored = TweenState.PreviousAnchored
		end)
	end

	TweenState.Tween = nil
	TweenState.RootPart = nil
	TweenState.PreviousAnchored = nil
end

local function TweenRootPartToPosition(RootPart, TargetPosition, Duration, HoldAnchored)
	if not RootPart then
		return nil
	end

	CancelNoFallRootTween()
	RuntimeState.NoFallTween = RuntimeState.NoFallTween or {}

	if HoldAnchored then
		RuntimeState.NoFallTween.PreviousAnchored = RootPart.Anchored
		RootPart.Anchored = true
	else
		RuntimeState.NoFallTween.PreviousAnchored = nil
	end

	local Tween = TweenService:Create(RootPart, TweenInfo.new(Duration or 0.08, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAlong(TargetPosition, RootPart.CFrame.LookVector)
	})

	RuntimeState.NoFallTween.Tween = Tween
	RuntimeState.NoFallTween.RootPart = RootPart

	Tween.Completed:Connect(function()
		if RuntimeState.NoFallTween and RuntimeState.NoFallTween.Tween == Tween then
			if RuntimeState.NoFallTween.RootPart and RuntimeState.NoFallTween.PreviousAnchored ~= nil then
				pcall(function()
					RuntimeState.NoFallTween.RootPart.Anchored = RuntimeState.NoFallTween.PreviousAnchored
				end)
			end
			RuntimeState.NoFallTween.Tween = nil
			RuntimeState.NoFallTween.RootPart = nil
			RuntimeState.NoFallTween.PreviousAnchored = nil
		end
	end)

	Tween:Play()
	return Tween
end

local function TweenRootPartDownToGround(RootPart, GroundY, HeightOffset, Duration, HoldAnchored)
	if not RootPart then
		return nil
	end

	return TweenRootPartToPosition(
		RootPart,
		Vector3.new(RootPart.Position.X, GroundY + (HeightOffset or 2.5), RootPart.Position.Z),
		Duration or 0.08,
		HoldAnchored
	)
end

local function RestoreBaseMovementSpeed()
	local _, Humanoid = GetCharacterState()
	local BedwarsReference = rawget(getgenv(), "bedwars")
	local SprintController = BedwarsReference and BedwarsReference.SprintController
	if not Humanoid then
		return
	end

	local WalkSpeed = 16
	local SprintSpeed = 20

	Humanoid.WalkSpeed = WalkSpeed
	if SprintController and type(SprintController.setSpeed) == "function" then
		pcall(function()
			SprintController:setSpeed(SprintSpeed)
		end)
	end
end

local function IsNetworkOwnerSafe(RootPart)
	if not RootPart then
		return false
	end

	local Success, Result = pcall(function()
		return RootPart:IsNetworkOwner()
	end)
	return Success and Result or true
end

local function HasInventoryItem(ItemType)
	local GetItemFunction = rawget(getgenv(), "getItem")
	if type(GetItemFunction) == "function" then
		local Success, Result = pcall(GetItemFunction, ItemType)
		if Success and Result then
			return true
		end
	end

	local Store = CreateTaskiumStore and CreateTaskiumStore() or rawget(getgenv(), "store")
	local InventoryItems = Store
		and Store.inventory
		and Store.inventory.inventory
		and Store.inventory.inventory.items
		or {}
	for _, Item in pairs(InventoryItems) do
		if Item and Item.itemType == ItemType then
			return true
		end
	end

	local Character = LocalPlayer and LocalPlayer.Character
	local Backpack = LocalPlayer and LocalPlayer:FindFirstChildOfClass("Backpack")
	local function HasTool(Container)
		if not Container then
			return false
		end
		for _, Tool in ipairs(Container:GetChildren()) do
			if Tool:IsA("Tool") and string.find(string.lower(Tool.Name), string.lower(ItemType), 1, true) then
				return true
			end
		end
		return false
	end

	return HasTool(Character) or HasTool(Backpack)
end

local SpeedModule
RunModule(function()
	local SpeedValue = 23 -- CFrame speed target
	local SpeedWallCheck = true -- stop at walls
	local SpeedRaycast = RaycastParams.new()
	local SpeedOldFriction = {}

	SpeedRaycast.RespectCanCollide = true

	local function UpdateSpeedFriction(Enabled)
		if Enabled then
			local Character = LocalPlayer and LocalPlayer.Character
			if Character then
				for _, Descendant in ipairs(Character:GetChildren()) do
					if Descendant:IsA("BasePart") and Descendant.Name ~= "HumanoidRootPart" and not SpeedOldFriction[Descendant] then
						SpeedOldFriction[Descendant] = Descendant.CustomPhysicalProperties or "none"
						Descendant.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
					end
				end
			end
		else
			for Part, Properties in pairs(SpeedOldFriction) do
				if Part and Part.Parent then
					Part.CustomPhysicalProperties = Properties ~= "none" and Properties or nil
				end
			end
			table.clear(SpeedOldFriction)
		end
	end

	SpeedModule = TaskAPI.Categories.Movement:CreateModule({
		Name = "Speed",
		Function = function(Enabled, RunId, Module)
			local function ResetSpeed()
				local BedwarsReference = rawget(getgenv(), "bedwars") or EnsureBedwarsRuntime()
				pcall(function()
					debug.setconstant(BedwarsReference.WindWalkerController.updateSpeed, 7, "moveSpeedMultiplier")
				end)
				UpdateSpeedFriction(false)
				RestoreBaseMovementSpeed()
			end

			if not Enabled then
				ResetSpeed()
				return
			end

			local BedwarsReference = rawget(getgenv(), "bedwars") or EnsureBedwarsRuntime()
			UpdateSpeedFriction(true)
			pcall(function()
				debug.setconstant(BedwarsReference.WindWalkerController.updateSpeed, 7, "constantSpeedMultiplier")
			end)

			Module:Clean(function()
				ResetSpeed()
			end)

			Module:Clean(RunService.PreSimulation:Connect(function(DeltaTime)
				if not Module:IsActive(RunId) then
					return
				end

				local Character, Humanoid, RootPart = GetCharacterState()
				if not (Character and Humanoid and RootPart and Humanoid.Health > 0) then
					return
				end

				if (FlyModule and FlyModule.Enabled) or (LongJumpModule and LongJumpModule.Enabled) then
					return
				end

				if BedwarsReference and BedwarsReference.StatefulEntityKnockbackController then
					pcall(function()
						BedwarsReference.StatefulEntityKnockbackController.lastImpulseTime = math.huge
					end)
				end

				local HumanoidState = Humanoid:GetState()
				if HumanoidState == Enum.HumanoidStateType.Climbing then
					return
				end

				local MoveDirection = Humanoid.MoveDirection
				local Velo = GetBedwarsSpeed()
				local Destination = MoveDirection * math.max(SpeedValue - Velo, 0) * DeltaTime

				if SpeedWallCheck then
					SpeedRaycast.FilterDescendantsInstances = { Character, Workspace.CurrentCamera }
					SpeedRaycast.CollisionGroup = RootPart.CollisionGroup
					local WallRaycast = Workspace:Raycast(RootPart.Position, Destination, SpeedRaycast)
					if WallRaycast then
						Destination = (WallRaycast.Position + WallRaycast.Normal) - RootPart.Position
					end
				end

				RootPart.CFrame = RootPart.CFrame + Destination
				RootPart.AssemblyLinearVelocity = (MoveDirection * math.min(Velo, SpeedValue)) + Vector3.new(0, RootPart.AssemblyLinearVelocity.Y, 0)
			end))
		end,
		ToolTip = "Increases your movement with various methods."
	})

	SpeedModule:CreateSlider({
		Name = "Speed",
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(Value)
			return Value == 1 and "stud" or "studs"
		end,
		Function = function(Value)
			SpeedValue = Value
		end,
		ToolTip = "Adjusts your speed value."
	})
end)

local SprintModule
RunModule(function()
	local SprintHookState = RuntimeState.Sprint or {}

	RuntimeState.Sprint = SprintHookState

	local function RemoveSprintHook(OwnerToken)
		if SprintHookState.Owner ~= OwnerToken then
			return
		end

		if SprintHookState.Controller
			and SprintHookState.OriginalStop
			and SprintHookState.WrappedStop
			and SprintHookState.Controller.stopSprinting == SprintHookState.WrappedStop then
			SprintHookState.Controller.stopSprinting = SprintHookState.OriginalStop
		end

		SprintHookState.Owner = nil
		SprintHookState.Controller = nil
		SprintHookState.OriginalStop = nil
		SprintHookState.WrappedStop = nil
	end

	local function ApplySprintHook(OwnerToken)
		local BedwarsReference = rawget(getgenv(), "bedwars") or EnsureBedwarsRuntime()
		local SprintController = BedwarsReference and BedwarsReference.SprintController
		if not (SprintController and type(SprintController.startSprinting) == "function" and type(SprintController.stopSprinting) == "function") then
			return false
		end

		if SprintHookState.Owner and SprintHookState.Owner ~= OwnerToken then
			RemoveSprintHook(SprintHookState.Owner)
		end

		if SprintHookState.Controller ~= SprintController then
			if SprintHookState.Controller
				and SprintHookState.OriginalStop
				and SprintHookState.WrappedStop
				and SprintHookState.Controller.stopSprinting == SprintHookState.WrappedStop then
				SprintHookState.Controller.stopSprinting = SprintHookState.OriginalStop
			end

			SprintHookState.Controller = SprintController
			SprintHookState.OriginalStop = SprintController.stopSprinting
		end

		SprintHookState.Owner = OwnerToken

		local OriginalStop = SprintHookState.OriginalStop
		local WrappedStop = function(...)
			local Results = { OriginalStop(...) }
			task.defer(function()
				if SprintHookState.Owner == OwnerToken then
					pcall(function()
						SprintController:startSprinting()
					end)
				end
			end)
			return table.unpack(Results)
		end

		SprintHookState.WrappedStop = WrappedStop
		SprintController.stopSprinting = WrappedStop

		pcall(function()
			SprintController:stopSprinting()
		end)

		return true
	end

	SprintModule = TaskAPI.Categories.Movement:CreateModule({
		Name = "Sprint",
		Function = function(Enabled, RunId, Module)
			if not Enabled then
				return
			end

			local OwnerToken = "Sprint_" .. tostring(RunId)

			Module:Clean(function()
				RemoveSprintHook(OwnerToken)
			end)

			task.spawn(function()
				repeat
					task.wait(0.25)
				until not Module:IsActive(RunId) or ApplySprintHook(OwnerToken)
			end)

			Module:Clean(RunService.Heartbeat:Connect(function()
				if not Module:IsActive(RunId) then
					return
				end

				local Character, Humanoid = GetCharacterState()
				local BedwarsReference = rawget(getgenv(), "bedwars") or EnsureBedwarsRuntime()
				local SprintController = BedwarsReference and BedwarsReference.SprintController
				if Character and Humanoid and Humanoid.Health > 0 and SprintController and type(SprintController.startSprinting) == "function" then
					if Humanoid.MoveDirection.Magnitude > 0.01 then
						pcall(function()
							SprintController:startSprinting()
						end)
					end
				end
			end))
		end,
		ToolTip = "Keeps your character sprinting while moving."
	})
end)

RunModule(function()
	local FlySpeed = 23 -- horizontal speed
	local FlyVertical = 50 -- up/down speed
	local FlyPop = true -- pop balloons on disable
	local FlyBar = true -- show progress bar
	local FlyDown = true -- TP down fallback
	local FlyUp = 0
	local FlyDownInput = 0
	local FlyTpTick = 0
	local FlyTpToggle = true
	local FlyOldY
	local FlyOldDeflate
	local FlyAirborneAt = tick()
	local FlyRaycast = RaycastParams.new()
	local FlyBarFrame
	local FlyBarGui
	local FlyBarFill
	local FlyBarTimer
	local FlyOldFriction = {}
	local FlyFrictionConnection

	FlyRaycast.RespectCanCollide = true

	local function ResetFlyState(ResetAirborneState)
		FlyUp = 0
		FlyDownInput = 0
		FlyTpTick = tick()
		FlyTpToggle = true
		FlyOldY = nil
		if ResetAirborneState ~= false then
			FlyAirborneAt = tick()
		end
	end

	local function UpdateFlyFriction(Enabled)
		if Enabled then
			local Character = LocalPlayer and LocalPlayer.Character
			local function ModifyVelocity(Descendant)
				if Descendant:IsA("BasePart") and Descendant.Name ~= "HumanoidRootPart" and not FlyOldFriction[Descendant] then
					FlyOldFriction[Descendant] = Descendant.CustomPhysicalProperties or "none"
					Descendant.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
				end
			end

			if Character then
				for _, Descendant in ipairs(Character:GetDescendants()) do
					ModifyVelocity(Descendant)
				end
				if FlyFrictionConnection then
					FlyFrictionConnection:Disconnect()
				end
				FlyFrictionConnection = Character.DescendantAdded:Connect(ModifyVelocity)
			end
		else
			if FlyFrictionConnection then
				FlyFrictionConnection:Disconnect()
				FlyFrictionConnection = nil
			end
			for Part, Properties in pairs(FlyOldFriction) do
				if Part and Part.Parent then
					Part.CustomPhysicalProperties = Properties ~= "none" and Properties or nil
				end
			end
			table.clear(FlyOldFriction)
		end
	end

	local function EnsureFlyProgressBar()
		if FlyBarFrame and FlyBarFrame.Parent then
			return FlyBarFrame
		end

		local NotificationGuiParent = TaskAPI and TaskAPI.NotificationGui and TaskAPI.NotificationGui.Parent
		if not NotificationGuiParent then
			return nil
		end

		if FlyBarGui and FlyBarGui.Parent then
			FlyBarGui:Destroy()
		end

		local ExistingGui = NotificationGuiParent:FindFirstChild("TaskiumFlyBarGui")
		if ExistingGui then
			ExistingGui:Destroy()
		end

		local BarGui = Instance.new("ScreenGui")
		BarGui.Name = "TaskiumFlyBarGui"
		BarGui.ResetOnSpawn = false
		BarGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		BarGui.Parent = NotificationGuiParent

		local Bar = Instance.new("Frame")
		Bar.Name = "TaskiumFlyBar"
		Bar.AnchorPoint = Vector2.new(0.5, 0)
		Bar.Position = UDim2.new(0.5, 0, 1, -200)
		Bar.Size = UDim2.new(0.2, 0, 0, 20)
		Bar.BackgroundTransparency = 0.5
		Bar.Visible = false
		Bar.BorderSizePixel = 0
		Bar.BackgroundColor3 = Color3.new()
		Bar.Parent = BarGui

		local Fill = Bar:Clone()
		Fill.Name = "Frame"
		Fill.AnchorPoint = Vector2.new(0, 0)
		Fill.Position = UDim2.new(0, 0, 0, 0)
		Fill.Size = UDim2.new(1, 0, 1, 0)
		Fill.BackgroundTransparency = 0
		Fill.Visible = true
		Fill.Parent = Bar

		local Timer = Instance.new("TextLabel")
		Timer.Name = "Timer"
		Timer.Text = "2s"
		Timer.Font = Enum.Font.Arimo
		Timer.TextStrokeTransparency = 0
		Timer.TextColor3 = Color3.new(0.9, 0.9, 0.9)
		Timer.TextSize = 20
		Timer.Size = UDim2.new(1, 0, 1, 0)
		Timer.BackgroundTransparency = 1
		Timer.Position = UDim2.new(0, 0, -1, 0)
		Timer.Parent = Bar

		FlyBarGui = BarGui
		FlyBarFrame = Bar
		FlyBarFill = Fill
		FlyBarTimer = Timer
		return Bar
	end

	local function TryInflateFlyBalloon(BedwarsReference)
		local Character = LocalPlayer and LocalPlayer.Character
		local BalloonController = BedwarsReference and BedwarsReference.BalloonController
		if not (Character and BalloonController and type(BalloonController.inflateBalloon) == "function") then
			return
		end

		if (Character:GetAttribute("InflatedBalloons") or 0) == 0 and HasInventoryItem("balloon") then
			pcall(function()
				BalloonController:inflateBalloon()
			end)
		end
	end

	FlyModule = TaskAPI.Categories.Movement:CreateModule({
		Name = "Fly",
		Function = function(Enabled, RunId, Module)
			local BedwarsReference = rawget(getgenv(), "bedwars") or EnsureBedwarsRuntime()
			local BalloonController = BedwarsReference and BedwarsReference.BalloonController
			local ProgressBar = EnsureFlyProgressBar()
			local ProgressFill = FlyBarFill
			local ProgressTimer = FlyBarTimer

			if not Enabled then
				if BalloonController and FlyOldDeflate then
					BalloonController.deflateBalloon = FlyOldDeflate
				end
				if FlyPop then
					local Character = LocalPlayer and LocalPlayer.Character
					if Character and BalloonController and type(BalloonController.deflateBalloon) == "function" and (Character:GetAttribute("InflatedBalloons") or 0) > 0 then
						for _ = 1, 3 do
							pcall(function()
								BalloonController:deflateBalloon()
							end)
						end
					end
				end
				FlyOldDeflate = nil
				UpdateFlyFriction(false)
				if ProgressBar then
					ProgressBar.Visible = false
				end
				ResetFlyState(false)
				RestoreBaseMovementSpeed()
				return
			end

			if not BedwarsReference then
				Module:SetEnabled(false, {
					SkipNotify = true
				})
				return
			end

			ResetFlyState(false)
			UpdateFlyFriction(true)
			if BalloonController then
				FlyOldDeflate = BalloonController.deflateBalloon
				BalloonController.deflateBalloon = function() end
			end
			TryInflateFlyBalloon(BedwarsReference)

			local InitialStore = CreateTaskiumStore()
			local InitialFlyAllowed = ((LocalPlayer.Character and ((LocalPlayer.Character:GetAttribute("InflatedBalloons") or 0) > 0)) or InitialStore.matchState == 2)
			if ProgressBar and ProgressFill then
				ProgressBar.Visible = FlyBar and not InitialFlyAllowed
			end

			Module:Clean(function()
				local CurrentBalloonController = BedwarsReference and BedwarsReference.BalloonController
				if CurrentBalloonController and FlyOldDeflate then
					CurrentBalloonController.deflateBalloon = FlyOldDeflate
				end
				if FlyPop then
					local Character = LocalPlayer and LocalPlayer.Character
					if Character and CurrentBalloonController and type(CurrentBalloonController.deflateBalloon) == "function" and (Character:GetAttribute("InflatedBalloons") or 0) > 0 then
						for _ = 1, 3 do
							pcall(function()
								CurrentBalloonController:deflateBalloon()
							end)
						end
					end
				end
				FlyOldDeflate = nil
				UpdateFlyFriction(false)
				if ProgressBar then
					ProgressBar.Visible = false
				end
				ResetFlyState(false)
				RestoreBaseMovementSpeed()
			end)

			Module:Clean(LocalPlayer.CharacterAdded:Connect(function()
				ResetFlyState(true)
				task.defer(function()
					if Module:IsActive(RunId) then
						TryInflateFlyBalloon(BedwarsReference)
					end
				end)
			end))

			local Character = LocalPlayer and LocalPlayer.Character
			if Character then
				Module:Clean(Character:GetAttributeChangedSignal("InflatedBalloons"):Connect(function()
					if Module:IsActive(RunId) then
						TryInflateFlyBalloon(BedwarsReference)
					end
				end))
			end

			Module:Clean(RunService.PreSimulation:Connect(function(DeltaTime)
				if not Module:IsActive(RunId) then
					return
				end

				local CurrentCharacter, Humanoid, RootPart = GetCharacterState()
				if not (CurrentCharacter and Humanoid and RootPart and Humanoid.Health > 0) then
					return
				end

				if LongJumpModule and LongJumpModule.Enabled then
					return
				end

				local Store = CreateTaskiumStore()
				local InflatedBalloons = CurrentCharacter:GetAttribute("InflatedBalloons") or 0
				local FlyAllowed = InflatedBalloons > 0 or Store.matchState == 2
				local VerticalInput = 0
				if FlyUp == 1 or UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonA) then
					VerticalInput = VerticalInput + 1
				end
				if FlyDownInput == -1 or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonL2) then
					VerticalInput = VerticalInput - 1
				end
				local Mass = (1.5 + (FlyAllowed and 6 or 0) * ((tick() % 0.4 < 0.2) and -1 or 1)) + (VerticalInput * FlyVertical)
				local MoveDirection = Humanoid.MoveDirection
				local SpeedSuccess, Velo = pcall(GetBedwarsSpeed)
				Velo = SpeedSuccess and Velo or 20
				local Destination = MoveDirection * math.max(FlySpeed - Velo, 0) * DeltaTime

				FlyRaycast.FilterDescendantsInstances = { CurrentCharacter, Workspace.CurrentCamera }
				FlyRaycast.CollisionGroup = RootPart.CollisionGroup

				local WallRaycast = Workspace:Raycast(RootPart.Position, Destination, FlyRaycast)
				if WallRaycast then
					Destination = (WallRaycast.Position + WallRaycast.Normal) - RootPart.Position
				end

				if Humanoid.FloorMaterial ~= Enum.Material.Air and FlyOldY == nil then
					FlyAirborneAt = tick()
					FlyTpToggle = true
					FlyTpTick = tick()
				end

				if ProgressBar and ProgressFill then
					ProgressBar.Visible = FlyBar and not FlyAllowed
					ProgressBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					ProgressFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				end

				if not FlyAllowed and ProgressBar and ProgressBar.Visible and ProgressTimer and ProgressFill then
					GroundRaycast.FilterDescendantsInstances = { CurrentCharacter, Workspace.CurrentCamera }
					GroundRaycast.CollisionGroup = RootPart.CollisionGroup
					local AirTime = tick() + (2 + (FlyAirborneAt - tick()))
					local OnGround = Workspace:Raycast(RootPart.Position, Vector3.new(0, -4.5, 0), GroundRaycast)
					if not OnGround then
						ProgressFill:TweenSize(UDim2.new(0, 0, 0, 20), Enum.EasingDirection.InOut, Enum.EasingStyle.Linear, math.max(AirTime - tick(), 0), true)
					else
						ProgressFill:TweenSize(UDim2.new(1, 0, 0, 20), Enum.EasingDirection.InOut, Enum.EasingStyle.Linear, 0, true)
					end
					ProgressTimer.Text = math.max(OnGround and 2.5 or math.floor((AirTime - tick()) * 10) / 10, 0) .. "s"
				end

				if not FlyAllowed and FlyDown then
					local AirLeft = tick() - FlyAirborneAt
					if FlyTpToggle then
						if AirLeft > 2 and not FlyOldY then
							local GroundRaycastResult = Workspace:Raycast(RootPart.Position, Vector3.new(0, -1000, 0), FlyRaycast)
							if GroundRaycastResult then
								FlyTpToggle = false
								FlyOldY = RootPart.Position.Y
								FlyTpTick = tick() + 0.11
								RootPart.CFrame = CFrame.lookAlong(
									Vector3.new(RootPart.Position.X, GroundRaycastResult.Position.Y + Humanoid.HipHeight, RootPart.Position.Z),
									RootPart.CFrame.LookVector
								)
							end
						end
					elseif FlyOldY then
						if FlyTpTick < tick() then
							RootPart.CFrame = CFrame.lookAlong(
								Vector3.new(RootPart.Position.X, FlyOldY, RootPart.Position.Z),
								RootPart.CFrame.LookVector
							)
							FlyAirborneAt = tick()
							FlyTpTick = tick()
							FlyTpToggle = true
							FlyOldY = nil
						else
							Mass = 0
						end
					end
				end

				RootPart.CFrame = RootPart.CFrame + Destination
				RootPart.AssemblyLinearVelocity = (MoveDirection * Velo) + Vector3.new(0, Mass, 0)
			end))

			Module:Clean(UserInputService.InputBegan:Connect(function(Input)
				if UserInputService:GetFocusedTextBox() then
					return
				end

				if Input.KeyCode == Enum.KeyCode.Space or Input.KeyCode == Enum.KeyCode.ButtonA then
					FlyUp = 1
				elseif Input.KeyCode == Enum.KeyCode.LeftShift or Input.KeyCode == Enum.KeyCode.ButtonL2 then
					FlyDownInput = -1
				end
			end))

			Module:Clean(UserInputService.InputEnded:Connect(function(Input)
				if Input.KeyCode == Enum.KeyCode.Space or Input.KeyCode == Enum.KeyCode.ButtonA then
					FlyUp = 0
				elseif Input.KeyCode == Enum.KeyCode.LeftShift or Input.KeyCode == Enum.KeyCode.ButtonL2 then
					FlyDownInput = 0
				end
			end))

			if UserInputService.TouchEnabled then
				pcall(function()
					local JumpButton = LocalPlayer.PlayerGui.TouchGui.TouchControlFrame.JumpButton
					Module:Clean(JumpButton:GetPropertyChangedSignal("ImageRectOffset"):Connect(function()
						FlyUp = JumpButton.ImageRectOffset.X == 146 and 1 or 0
					end))
				end)
			end
		end,
		ToolTip = "Makes you go zoom."
	})

	FlyModule:CreateSlider({
		Name = "Speed",
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(Value)
			return Value == 1 and "stud" or "studs"
		end,
		Function = function(Value)
			FlySpeed = Value
		end,
		ToolTip = "Adjusts your fly speed."
	})

	FlyModule:CreateSlider({
		Name = "Vertical Speed",
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(Value)
			return Value == 1 and "stud" or "studs"
		end,
		Function = function(Value)
			FlyVertical = Value
		end,
		ToolTip = "Adjusts your fly vertical speed."
	})

	FlyModule:CreateToggle({
		Name = "Pop Balloons",
		Function = function(Callback)
			FlyPop = Callback
		end,
		Default = true,
		ToolTip = "Pops your balloons when Fly turns off."
	})

	FlyModule:CreateToggle({
		Name = "Show Fly Bar",
		Function = function(Callback)
			FlyBar = Callback
			if FlyBarFrame then
				FlyBarFrame.Visible = Callback and FlyBarFrame.Visible or false
			end
		end,
		Default = true,
		ToolTip = "Shows the BedWars-style Fly progress bar."
	})

	FlyModule:CreateToggle({
		Name = "TP Down",
		Function = function(Callback)
			FlyDown = Callback
		end,
		Default = true,
		ToolTip = "Uses the BedWars TP down fallback when balloons are unavailable."
	})
end)

local NoFallModule
RunModule(function()
	local NoFallRange = 60 -- ground search distance
	local NoFallMinHeight = 15 -- minimum fall height
	local NoFallMaxRiseVelocity = 2 -- ignore upward motion
	local NoFallDelay = 0.1 -- time before trigger
	local NoFallGrace = 0.6 -- delay after fly/longjump
	local NoFallRaycast = RaycastParams.new()

	NoFallRaycast.RespectCanCollide = true

	local function GetNoFallGroundRaycast(Character, RootPart, MaxDistance)
		local Store = rawget(getgenv(), "store")
		local AirRay = Store and Store.airRay
		if AirRay then
			return Workspace:Raycast(RootPart.Position, Vector3.new(0, -(MaxDistance or NoFallRange), 0), AirRay)
		end

		NoFallRaycast.FilterDescendantsInstances = { Character, Workspace.CurrentCamera }
		NoFallRaycast.CollisionGroup = RootPart.CollisionGroup
		return Workspace:Raycast(RootPart.Position, Vector3.new(0, -(MaxDistance or NoFallRange), 0), NoFallRaycast)
	end

	NoFallModule = TaskAPI.Categories.Movement:CreateModule({
		Name = "NoFall",
		Function = function(Enabled, RunId, Module)
			local FallStartPosition
			local FallStartY
			local FallStartedAt = 0
			local WasGrounded = true
			local TeleportedThisFall = false
			local BlockedUntil = 0

			local function ResetNoFallState()
				FallStartPosition = nil
				FallStartY = nil
				FallStartedAt = 0
				WasGrounded = true
				TeleportedThisFall = false
				BlockedUntil = 0
				CancelNoFallRootTween()
			end

			if not Enabled then
				ResetNoFallState()
				return
			end

			Module:Clean(ResetNoFallState)
			Module:Clean(LocalPlayer.CharacterAdded:Connect(function()
				ResetNoFallState()
			end))

			Module:Clean(RunService.PreSimulation:Connect(function()
				if not Module:IsActive(RunId) then
					return
				end

				local Character, Humanoid, RootPart = GetCharacterState()
				if not (Character and Humanoid and RootPart and Humanoid.Health > 0) then
					return
				end

				if (FlyModule and FlyModule.Enabled) or (LongJumpModule and LongJumpModule.Enabled) then
					FallStartPosition = nil
					FallStartY = nil
					FallStartedAt = 0
					WasGrounded = true
					TeleportedThisFall = false
					BlockedUntil = tick() + NoFallGrace
					return
				end

				if tick() < BlockedUntil then
					return
				end

				local HumanoidState = Humanoid:GetState()
				if HumanoidState == Enum.HumanoidStateType.Seated
					or HumanoidState == Enum.HumanoidStateType.Climbing
					or HumanoidState == Enum.HumanoidStateType.Swimming then
					ResetNoFallState()
					return
				end

				local Grounded = IsCharacterGrounded(RootPart)
				if Grounded then
					FallStartPosition = RootPart.Position
					FallStartY = RootPart.Position.Y
					FallStartedAt = tick()
					WasGrounded = true
					TeleportedThisFall = false
					return
				end

				if WasGrounded then
					FallStartPosition = RootPart.Position
					FallStartY = RootPart.Position.Y
					FallStartedAt = tick()
					WasGrounded = false
					TeleportedThisFall = false
				end

				if not FallStartPosition or not FallStartY or TeleportedThisFall then
					return
				end

				if (tick() - FallStartedAt) < NoFallDelay then
					return
				end

				if RootPart.AssemblyLinearVelocity.Y > NoFallMaxRiseVelocity then
					return
				end

				local GroundRaycast = GetNoFallGroundRaycast(Character, RootPart, NoFallRange)
				if not GroundRaycast then
					return
				end

				if (FallStartY - GroundRaycast.Position.Y) < NoFallMinHeight then
					return
				end

				TeleportedThisFall = true
				Character:PivotTo(CFrame.lookAlong(
					Vector3.new(
						RootPart.Position.X,
						GroundRaycast.Position.Y + Humanoid.HipHeight + 0.15,
						RootPart.Position.Z
					),
					RootPart.CFrame.LookVector
				))
				RootPart.AssemblyLinearVelocity = Vector3.new(
					RootPart.AssemblyLinearVelocity.X,
					math.min(RootPart.AssemblyLinearVelocity.Y, -2),
					RootPart.AssemblyLinearVelocity.Z
				)
			end))
		end,
		ToolTip = "Only works on falls above 5 blocks, and teleports after 0.1 seconds in the fall."
	})
end)
RunModule(function()
	local LongJumpSpeed
	local LJCooldownDuration
	local LongJumpNextUse
	local LJCooldownNotification
	local LJCooldownNotifToken
	local LJNoCooldown

	local function ShowLJCooldownNotif()
		local RemainingCooldown = math.max(LongJumpNextUse - tick(), 0)
		if RemainingCooldown <= 0 then
			LJCooldownNotification = nil
			return
		end

		LJCooldownNotifToken = LJCooldownNotifToken + 1
		local NotificationToken = LJCooldownNotifToken

		if not (LJCooldownNotification and LJCooldownNotification.Parent) then
			LJCooldownNotification = TaskAPI.Notification(
				"Taskium",
				string.format("LongJump cooldown: %.1fs", RemainingCooldown),
				math.max(RemainingCooldown, 0.1),
				"Warning"
			)
		end

		local Holder = LJCooldownNotification
		task.spawn(function()
			while NotificationToken == LJCooldownNotifToken and Holder and Holder.Parent and tick() < LongJumpNextUse do
				local NotificationFrame = Holder:FindFirstChild("NotificationFrame")
				local MessageLabel = NotificationFrame and NotificationFrame:FindFirstChild("MessageText")
				if MessageLabel then
					MessageLabel.Text = string.format("LongJump cooldown: %.1fs", math.max(LongJumpNextUse - tick(), 0))
				end
				task.wait(0.05)
			end

			if NotificationToken == LJCooldownNotifToken then
				LJCooldownNotification = nil
			end
		end)
	end

	LongJumpSpeed = 58
	LJCooldownDuration = 5
	LongJumpNextUse = 0
	LJCooldownNotification = nil
	LJCooldownNotifToken = 0
	LJNoCooldown = false

	local function FindLongJumpItem(BedwarsReference)
		local Store = CreateTaskiumStore()
		local GetItemFunction = rawget(getgenv(), "getItem")
		local Supported = {
			"fireball",
			"grappling_hook",
			"jade_hammer",
			"void_axe",
			"wood_dao",
			"stone_dao",
			"iron_dao",
			"diamond_dao",
			"emerald_dao"
		}
		local SupportedLookup = {}
		for _, ItemType in ipairs(Supported) do
			SupportedLookup[ItemType] = true
		end

		local function ResolveTool(ItemType)
			if not ItemType then
				return nil
			end

			if type(GetItemFunction) == "function" then
				local Success, ItemData = pcall(GetItemFunction, ItemType)
				if Success and type(ItemData) == "table" and ItemData.tool then
					return ItemData.tool
				end
			end

			local Character = LocalPlayer.Character
			local Backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
			for _, Container in ipairs({Character, Backpack}) do
				if Container then
					for _, Child in ipairs(Container:GetChildren()) do
						if Child:IsA("Tool") then
							local ToolMeta = BedwarsReference.ItemMeta[Child.Name]
							local ToolItemType = ToolMeta and ToolMeta.itemType or Child.Name
							if ToolItemType == ItemType or Child.Name == ItemType then
								return Child
							end
						end
					end
				end
			end

			return nil
		end

		if type(GetItemFunction) == "function" then
			for _, ItemType in ipairs(Supported) do
				local Success, ItemData = pcall(GetItemFunction, ItemType)
				if Success and type(ItemData) == "table" and ItemData.tool then
					return {
						itemType = ItemType,
						tool = ItemData.tool
					}, ItemType
				end
			end
		end

		if Store.hand and Store.hand.tool and SupportedLookup[Store.hand.tool.Name] then
			local HandToolName = Store.hand.tool.Name
			local HandItemData = nil
			if type(GetItemFunction) == "function" then
				local Success, ItemData = pcall(GetItemFunction, HandToolName)
				if Success and type(ItemData) == "table" then
					HandItemData = ItemData
				end
			end
			return HandItemData or {
				itemType = Store.hand.itemType or HandToolName,
				tool = Store.hand.tool
			}, HandToolName
		end

		if Store.hand and Store.hand.itemType and SupportedLookup[Store.hand.itemType] and Store.hand.tool then
			return {
				itemType = Store.hand.itemType,
				tool = Store.hand.tool
			}, Store.hand.itemType
		end

		local InventoryItems = Store.inventory and Store.inventory.inventory and Store.inventory.inventory.items or {}
		for _, Item in pairs(InventoryItems) do
			if Item and SupportedLookup[Item.itemType] then
				return {
					itemType = Item.itemType,
					tool = ResolveTool(Item.itemType) or Item.tool
				}, Item.itemType
			end
		end

		for _, ItemType in ipairs(Supported) do
			if type(GetItemFunction) == "function" then
				local Success, ItemData = pcall(GetItemFunction, ItemType)
				if Success and type(ItemData) == "table" and (ItemData.tool or ItemData.itemType) then
					return ItemData, ItemType
				end
			end
		end

		return nil, nil
	end

	local function TriggerLongJumpItem(BedwarsReference, ItemData, MethodName, RootPart)
		if not (BedwarsReference and RootPart) then
			return nil
		end

		local FlatDirection = RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		if FlatDirection.Magnitude <= 0.001 then
			FlatDirection = Vector3.new(0, 0, -1)
		end
		FlatDirection = FlatDirection.Unit

		local SwitchItemFunction = rawget(getgenv(), "switchItem")
		local AbilityController = BedwarsReference.AbilityController
		local ItemType = MethodName or (ItemData and ItemData.itemType)
		if not ItemType then
			return nil
		end
		if not (ItemData and ItemData.tool) then
			local GetItemFunction = rawget(getgenv(), "getItem")
			if type(GetItemFunction) == "function" then
				local Success, ResolvedItem = pcall(GetItemFunction, ItemType)
				if Success and type(ResolvedItem) == "table" then
					ItemData = ResolvedItem
				end
			end
		end

		if ItemType == "fireball" then
			local ProjectileController = BedwarsReference.ProjectileController
			local ProjectileMeta = BedwarsReference.ProjectileMeta
			local BowConstants = BedwarsReference.BowConstantsTable
			local SoundManager = BedwarsReference.SoundManager
			if not (ProjectileController and ProjectileMeta and ProjectileMeta.fireball and BowConstants and type(ProjectileController.createLocalProjectile) == "function" and BedwarsReference.Client) then
				return nil
			end

			local FireProjectileCall = nil
			pcall(function()
				FireProjectileCall = BedwarsReference.Client:Get("FireProjectile")
			end)
			if not FireProjectileCall then
				return nil
			end

			local LaunchPosition = RootPart.Position + Vector3.new(0, 2.5, 0)
			local AimOrigin = LaunchPosition - (FlatDirection * 0.1)
			local ShootCFrame = (CFrame.lookAlong(AimOrigin, Vector3.new(0, -60, 0)) * CFrame.new(Vector3.new(-BowConstants.RelX, -BowConstants.RelY, -BowConstants.RelZ)))
			if type(SwitchItemFunction) == "function" and ItemData and ItemData.tool then
				pcall(SwitchItemFunction, ItemData.tool, 0)
			end
			task.wait(0.1)

			local ProjectileVelocity = ShootCFrame.LookVector * 60
			pcall(function()
				ProjectileController:createLocalProjectile(ProjectileMeta.fireball, "fireball", "fireball", ShootCFrame.Position, "", ProjectileVelocity, { drawDurationSeconds = 1 })
			end)
			pcall(function()
				if type(FireProjectileCall.InvokeServer) == "function" then
					FireProjectileCall:InvokeServer(ItemData and ItemData.tool, "fireball", "fireball", ShootCFrame.Position, LaunchPosition, ProjectileVelocity, HttpService:GenerateGUID(false), { drawDurationSeconds = 1 }, Workspace:GetServerTimeNow() - 0.045)
				elseif FireProjectileCall.instance and type(FireProjectileCall.instance.InvokeServer) == "function" then
					FireProjectileCall.instance:InvokeServer(ItemData and ItemData.tool, "fireball", "fireball", ShootCFrame.Position, LaunchPosition, ProjectileVelocity, HttpService:GenerateGUID(false), { drawDurationSeconds = 1 }, Workspace:GetServerTimeNow() - 0.045)
				end
			end)
			pcall(function()
				local LaunchSound = BedwarsReference.ItemMeta[ItemType] and BedwarsReference.ItemMeta[ItemType].projectileSource and BedwarsReference.ItemMeta[ItemType].projectileSource.launchSound
				if SoundManager and LaunchSound and LaunchSound[1] then
					SoundManager:playSound(LaunchSound[math.random(1, #LaunchSound)])
				end
			end)
			return {
				Speed = 56,
				Duration = 0.9,
				Upward = 24,
				Direction = FlatDirection
			}
		end

		if ItemType == "grappling_hook" then
			local ProjectileController = BedwarsReference.ProjectileController
			local ProjectileMeta = BedwarsReference.ProjectileMeta
			local BowConstants = BedwarsReference.BowConstantsTable
			if not (ProjectileController and ProjectileMeta and ProjectileMeta.grappling_hook_projectile and BowConstants and type(ProjectileController.createLocalProjectile) == "function" and BedwarsReference.Client) then
				return nil
			end

			local FireProjectileCall = nil
			pcall(function()
				FireProjectileCall = BedwarsReference.Client:Get("FireProjectile")
			end)
			if not FireProjectileCall then
				return nil
			end

			local LaunchPosition = RootPart.Position + Vector3.new(0, 2.5, 0)
			local AimOrigin = LaunchPosition - (FlatDirection * 0.1)
			local ShootCFrame = (CFrame.lookAlong(AimOrigin, Vector3.new(0, -140, 0)) * CFrame.new(Vector3.new(-BowConstants.RelX, -BowConstants.RelY, -BowConstants.RelZ)))
			if type(SwitchItemFunction) == "function" and ItemData and ItemData.tool then
				pcall(SwitchItemFunction, ItemData.tool, 0)
			end
			task.wait(0.1)

			local ProjectileVelocity = ShootCFrame.LookVector * 140
			pcall(function()
				ProjectileController:createLocalProjectile(ProjectileMeta.grappling_hook_projectile, "grappling_hook_projectile", "grappling_hook_projectile", ShootCFrame.Position, "", ProjectileVelocity, { drawDurationSeconds = 1 })
			end)
			pcall(function()
				if type(FireProjectileCall.InvokeServer) == "function" then
					FireProjectileCall:InvokeServer(ItemData and ItemData.tool, "grappling_hook_projectile", "grappling_hook_projectile", ShootCFrame.Position, LaunchPosition, ProjectileVelocity, HttpService:GenerateGUID(false), { drawDurationSeconds = 1 }, Workspace:GetServerTimeNow() - 0.045)
				elseif FireProjectileCall.instance and type(FireProjectileCall.instance.InvokeServer) == "function" then
					FireProjectileCall.instance:InvokeServer(ItemData and ItemData.tool, "grappling_hook_projectile", "grappling_hook_projectile", ShootCFrame.Position, LaunchPosition, ProjectileVelocity, HttpService:GenerateGUID(false), { drawDurationSeconds = 1 }, Workspace:GetServerTimeNow() - 0.045)
				end
			end)
			return {
				Speed = 62,
				Duration = 1.0,
				Upward = 26,
				Direction = FlatDirection
			}
		end

		if ItemType == "jade_hammer" or ItemType == "void_axe" then
			if AbilityController and type(AbilityController.canUseAbility) == "function" and type(AbilityController.useAbility) == "function" then
				local AbilityName = ItemType .. "_jump"
				if not AbilityController:canUseAbility(AbilityName) then
					return nil
				end
				pcall(function()
					AbilityController:useAbility(AbilityName)
				end)
				return {
					Speed = 81,
					Duration = 1.0,
					Upward = 18,
					Direction = FlatDirection
				}
			end
			return nil
		end

		if ItemType == "wood_dao" or ItemType == "stone_dao" or ItemType == "iron_dao" or ItemType == "diamond_dao" or ItemType == "emerald_dao" then
			if not (AbilityController and type(AbilityController.canUseAbility) == "function" and AbilityController:canUseAbility("dash")) then
				return nil
			end

			local CanDashNext = (LocalPlayer.Character and LocalPlayer.Character:GetAttribute("CanDashNext")) or 0
			if CanDashNext > Workspace:GetServerTimeNow() then
				return nil
			end

			local AbilityEvents = ReplicatedStorage:FindFirstChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events")
			local UseAbilityRemote = AbilityEvents and AbilityEvents:FindFirstChild("useAbility")
			if not UseAbilityRemote then
				return nil
			end

			if type(SwitchItemFunction) == "function" and ItemData and ItemData.tool then
				pcall(SwitchItemFunction, ItemData.tool, 0.1)
			end
			pcall(function()
				UseAbilityRemote:FireServer("dash", {
					direction = FlatDirection,
					origin = RootPart.Position,
					weapon = ItemType
				})
			end)
			return {
				Speed = 261,
				Duration = 0.9,
				Upward = 12,
				Direction = FlatDirection
			}
		end

		return nil
	end

	local function RunLongJumpSequence(Module, RunId, Humanoid, RootPart, SprintController, TriggerData)
		local LockActionName = "TaskiumLongJumpLock_" .. tostring(RunId)
		local CharacterControls
		local function SinkMovementAction()
			return Enum.ContextActionResult.Sink
		end
		local function Lerp(NumberA, NumberB, Alpha)
			return NumberA + ((NumberB - NumberA) * Alpha)
		end

		pcall(function()
			local PlayerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
			local PlayerModule = PlayerScripts and PlayerScripts:FindFirstChild("PlayerModule")
			if PlayerModule then
				local ControlsModule = require(PlayerModule)
				if ControlsModule and type(ControlsModule.GetControls) == "function" then
					CharacterControls = ControlsModule:GetControls()
				end
			end
		end)

		if ContextActionService.BindActionAtPriority then
			ContextActionService:BindActionAtPriority(
				LockActionName,
				SinkMovementAction,
				false,
				Enum.ContextActionPriority.High.Value,
				Enum.PlayerActions.CharacterForward,
				Enum.PlayerActions.CharacterBackward,
				Enum.PlayerActions.CharacterLeft,
				Enum.PlayerActions.CharacterRight,
				Enum.PlayerActions.CharacterJump,
				Enum.KeyCode.W,
				Enum.KeyCode.A,
				Enum.KeyCode.S,
				Enum.KeyCode.D,
				Enum.KeyCode.Up,
				Enum.KeyCode.Down,
				Enum.KeyCode.Left,
				Enum.KeyCode.Right,
				Enum.KeyCode.Space
			)
		else
			ContextActionService:BindAction(
				LockActionName,
				SinkMovementAction,
				false,
				Enum.PlayerActions.CharacterForward,
				Enum.PlayerActions.CharacterBackward,
				Enum.PlayerActions.CharacterLeft,
				Enum.PlayerActions.CharacterRight,
				Enum.PlayerActions.CharacterJump,
				Enum.KeyCode.W,
				Enum.KeyCode.A,
				Enum.KeyCode.S,
				Enum.KeyCode.D,
				Enum.KeyCode.Up,
				Enum.KeyCode.Down,
				Enum.KeyCode.Left,
				Enum.KeyCode.Right,
				Enum.KeyCode.Space
			)
		end

		local FlatLook = RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		if FlatLook.Magnitude <= 0.001 then
			FlatLook = Vector3.new(0, 0, -1)
		end
		FlatLook = FlatLook.Unit

		local StartTick = tick()
		local JumpDuration = 0.7
		local StrongBoostDuration = 0.28
		local EndFadeDuration = 0.1
		local Ended = false
		local GroundedAtStart = IsCharacterGrounded(RootPart)
		local UpwardBoost = 17
		local JumpSpeedValue = LongJumpSpeed
		if TriggerData then
			JumpSpeedValue = TriggerData.Speed or JumpSpeedValue
			JumpDuration = TriggerData.Duration or JumpDuration
			UpwardBoost = TriggerData.Upward or UpwardBoost
			FlatLook = TriggerData.Direction or FlatLook
		end
		local TeleportAccumulator = 0
		local TeleportStepInterval = 1 / 45
		local MaxBufferedTeleportTime = TeleportStepInterval * 2
		local PreviousAutoRotate = Humanoid.AutoRotate
		Humanoid.AutoRotate = false
		if CharacterControls and type(CharacterControls.Disable) == "function" then
			pcall(function()
				CharacterControls:Disable()
			end)
		end
		Module:Clean(function()
			ContextActionService:UnbindAction(LockActionName)
			if CharacterControls and type(CharacterControls.Enable) == "function" then
				pcall(function()
					CharacterControls:Enable()
				end)
			end
			if Humanoid then
				Humanoid.AutoRotate = PreviousAutoRotate
			end
			RestoreBaseMovementSpeed()
		end)

		if GroundedAtStart then
			RootPart.AssemblyLinearVelocity = Vector3.new(0, 24, 0)
		end

		local function FinishJump()
			if Ended then
				return
			end
			Ended = true
			if Module:IsActive(RunId) then
				Module:SetEnabled(false, {
					SkipNotify = true
				})
			end
		end

		Module:Clean(FinishJump)
		Module:Clean(RunService.PreSimulation:Connect(function(DeltaTime)
			if not Module:IsActive(RunId) then
				return
			end

			local _, CurrentHumanoid, CurrentRootPart = GetCharacterState()
			if not (CurrentHumanoid and CurrentRootPart and CurrentHumanoid.Health > 0) then
				FinishJump()
				return
			end

			local Elapsed = tick() - StartTick
			if Elapsed >= JumpDuration then
				FinishJump()
				return
			end

			local CurrentSpeedMultiplier = 0.58
			local StrongEndTime = math.max(StrongBoostDuration, 0.08)
			local MidEndTime = math.max(JumpDuration - EndFadeDuration - 0.08, StrongEndTime)

			if Elapsed < 0.08 then
				local Alpha = math.clamp(Elapsed / 0.08, 0, 1)
				CurrentSpeedMultiplier = Lerp(1.08, 0.94, Alpha)
			elseif Elapsed < StrongEndTime then
				local Alpha = math.clamp((Elapsed - 0.08) / math.max(StrongEndTime - 0.08, 0.001), 0, 1)
				CurrentSpeedMultiplier = Lerp(0.94, 0.8, Alpha)
			elseif Elapsed < MidEndTime then
				local Alpha = math.clamp((Elapsed - StrongEndTime) / math.max(MidEndTime - StrongEndTime, 0.001), 0, 1)
				CurrentSpeedMultiplier = Lerp(0.8, 0.64, Alpha)
			end

			local CurrentSpeed = JumpSpeedValue * CurrentSpeedMultiplier
			local RemainingTime = JumpDuration - Elapsed
			if RemainingTime < EndFadeDuration then
				local EndAlpha = math.clamp(RemainingTime / EndFadeDuration, 0, 1)
				CurrentSpeed = CurrentSpeed * (0.45 + (0.55 * EndAlpha))
			end

			if GroundedAtStart and Elapsed < 0.06 then
				CurrentSpeed = CurrentSpeed * 0.92
			end

			local CurrentUpwardBoost = 0
			if Elapsed < 0.1 then
				CurrentUpwardBoost = UpwardBoost
			elseif Elapsed < 0.18 then
				CurrentUpwardBoost = UpwardBoost * 0.4
			end
			if RemainingTime < EndFadeDuration then
				CurrentUpwardBoost = 0
			end

			CurrentHumanoid.WalkSpeed = 0
			CurrentHumanoid:Move(Vector3.zero, false)
			if CharacterControls and type(CharacterControls.Disable) == "function" then
				pcall(function()
					CharacterControls:Disable()
				end)
			end
			if SprintController and type(SprintController.setSpeed) == "function" then
				pcall(function()
					SprintController:setSpeed(0)
				end)
			end

			TeleportAccumulator = math.min(TeleportAccumulator + DeltaTime, MaxBufferedTeleportTime)
			if TeleportAccumulator >= TeleportStepInterval then
				TeleportAccumulator = TeleportAccumulator - TeleportStepInterval
				local TeleportDistance = math.min(CurrentSpeed * TeleportStepInterval, RemainingTime < EndFadeDuration and 0.55 or 1.1)
				CurrentRootPart.CFrame = CurrentRootPart.CFrame + (FlatLook * TeleportDistance) + Vector3.new(0, CurrentUpwardBoost * TeleportStepInterval, 0)
			end
			CurrentRootPart.AssemblyLinearVelocity = Vector3.new(
				0,
				math.max(CurrentRootPart.AssemblyLinearVelocity.Y, CurrentUpwardBoost),
				0
			)
		end))
	end

	LongJumpModule = TaskAPI.Categories.Movement:CreateModule({
		Name = "LongJump",
		Function = function(Enabled, RunId, Module)
			if not Enabled then
				return
			end

			local Character, Humanoid, RootPart = GetCharacterState()
			if not (Character and Humanoid and RootPart and Humanoid.Health > 0) then
				Module:SetEnabled(false, {
					SkipNotify = true
				})
				return
			end

			local BedwarsReference = rawget(getgenv(), "bedwars") or EnsureBedwarsRuntime()
			local ItemData, MethodName = FindLongJumpItem(BedwarsReference)
			local TriggerData = TriggerLongJumpItem(BedwarsReference, ItemData, MethodName, RootPart)
			if not TriggerData then
				TaskAPI.Notification("Taskium", "LongJump needs a supported item like fireball, Dao, or jade hammer.", 5, "Warning")
				Module:SetEnabled(false, {
					SkipNotify = true
				})
				return
			end
			RunLongJumpSequence(Module, RunId, Humanoid, RootPart, BedwarsReference and BedwarsReference.SprintController, TriggerData)
		end,
		ToolTip = "Uses fireball, Dao, and similar BedWars items to launch you farther."
	})
	LongJumpModule:CreateSlider({
		Name = "Speed",
		Min = 1,
		Max = 37,
		Default = 37,
		Function = function(Value)
			LongJumpSpeed = Value
		end,
		ToolTip = "Changes the item-assisted LongJump speed."
	})

	local LongJumpV2Module = TaskAPI.Categories.Movement:CreateModule({
		Name = "LongJumpV2",
		Function = function(Enabled, RunId, Module)
			if not Enabled then
				return
			end

			if (not LJNoCooldown) and tick() < LongJumpNextUse then
				ShowLJCooldownNotif()
				Module:SetEnabled(false, {
					SkipNotify = true
				})
				return
			end

			local Character, Humanoid, RootPart = GetCharacterState()
			if not (Character and Humanoid and RootPart and Humanoid.Health > 0) then
				Module:SetEnabled(false, {
					SkipNotify = true
				})
				return
			end

			if LJNoCooldown then
				LongJumpNextUse = 0
			else
				LongJumpNextUse = tick() + LJCooldownDuration
				ShowLJCooldownNotif()
			end

			local BedwarsReference = rawget(getgenv(), "bedwars") or EnsureBedwarsRuntime()
			RunLongJumpSequence(Module, RunId, Humanoid, RootPart, BedwarsReference and BedwarsReference.SprintController, nil)
		end,
		ToolTip = "Plain LongJump without needing fireball, Dao, or any other item."
	})

	LongJumpV2Module:CreateToggle({
		Name = "No Cooldown",
		Function = function(Callback)
			LJNoCooldown = Callback
			if Callback then
				LongJumpNextUse = 0
				LJCooldownNotification = nil
			end
		end,
		ToolTip = "Removes the LongJumpV2 cooldown."
	})
end)

local GravityModule
RunModule(function()
	local DefaultWorkspaceGravity
	local GravityValue

	local function ApplyWorkspaceGravity()
		if GravityModule and GravityModule.Enabled then
			workspace.Gravity = GravityValue
		else
			workspace.Gravity = DefaultWorkspaceGravity
		end
	end

	DefaultWorkspaceGravity = workspace.Gravity
	GravityValue = DefaultWorkspaceGravity

	GravityModule = TaskAPI.Categories.Movement:CreateModule({
		Name = "Gravity",
		Function = function(Enabled, RunId, Module)
			if Enabled then
				workspace.Gravity = GravityValue
				Module:Clean(function()
					ApplyWorkspaceGravity()
				end)
				return
			end

			ApplyWorkspaceGravity()
		end,
		ToolTip = "Changes your local gravity."
	})

	GravityModule:CreateSlider({
		Name = "Gravity",
		Min = 1,
		Max = 196,
		Default = math.floor(DefaultWorkspaceGravity + 0.5),
		Function = function(Value)
			GravityValue = Value
			if GravityModule and GravityModule.Enabled then
				workspace.Gravity = GravityValue
			end
		end,
		ToolTip = "Adjusts your gravity value."
	})
end)

local AntiVoidModule
local AntiHitModule
local ClimbModule

local function GetAntiVoidLowGround(BedwarsReference)
	local BlockController = BedwarsReference and BedwarsReference.BlockController
	local BlockStore = BlockController and type(BlockController.getStore) == "function" and BlockController:getStore()
	if not (BlockStore and type(BlockStore.getAllBlockPositions) == "function") then
		return nil
	end

	local LowestY = math.huge
	for _, BlockPosition in BlockStore:getAllBlockPositions() do
		local WorldPosition = BlockPosition * 3
		local UpperBlock = GetPlacedBlockAt(BedwarsReference, WorldPosition + Vector3.new(0, 3, 0))
		if WorldPosition.Y < LowestY and not UpperBlock then
			LowestY = WorldPosition.Y
		end
	end

	if LowestY == math.huge then
		return nil
	end

	return LowestY
end

local function GetNearestAntiHitTarget(LocalRootPart, MaxDistance)
	local NearestTarget = nil
	local NearestDistance = MaxDistance or 30

	local function IsFriendlyPlayer(Player)
		if not Player or Player == LocalPlayer then
			return true
		end
		if LocalPlayer.Team ~= nil and Player.Team ~= nil and LocalPlayer.Team == Player.Team then
			return true
		end
		local LocalTeam = LocalPlayer:GetAttribute("Team")
		local TargetTeam = Player:GetAttribute("Team")
		if LocalTeam ~= nil and TargetTeam ~= nil and LocalTeam == TargetTeam then
			return true
		end
		return false
	end

	local function ConsiderCharacter(Character, Player)
		if not Character or Character == LocalPlayer.Character then
			return
		end

		if Player then
			if IsFriendlyPlayer(Player) then
				return
			end
		else
			if CollectionService:HasTag(Character, "inventory-entity")
				and not CollectionService:HasTag(Character, "Monster")
				and not CollectionService:HasTag(Character, "trainingRoomDummy") then
				return
			end

			if CollectionService:HasTag(Character, "Drone") then
				local DronePlayerUserId = Character:GetAttribute("PlayerUserId")
				local DronePlayer = type(DronePlayerUserId) == "number" and Players:GetPlayerByUserId(DronePlayerUserId) or nil
				if DronePlayer and IsFriendlyPlayer(DronePlayer) then
					return
				end
			end

			local LocalTeam = LocalPlayer:GetAttribute("Team")
			local TargetTeam = Character:GetAttribute("Team")
			if LocalTeam ~= nil and TargetTeam ~= nil and LocalTeam == TargetTeam then
				return
			end
		end

		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		local RootPart = (Humanoid and Humanoid.RootPart) or Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart
		if not (Humanoid and RootPart and Humanoid.Health > 0) then
			return
		end

		local Distance = (RootPart.Position - LocalRootPart.Position).Magnitude
		if Distance <= NearestDistance then
			NearestDistance = Distance
			NearestTarget = {
				Player = Player,
				Character = Character,
				Humanoid = Humanoid,
				RootPart = RootPart,
				Distance = Distance
			}
		end
	end

	for _, Player in ipairs(Players:GetPlayers()) do
		ConsiderCharacter(Player.Character, Player)
	end

	for _, EntityCharacter in ipairs(CollectionService:GetTagged("entity")) do
		if EntityCharacter:IsA("Model") then
			ConsiderCharacter(EntityCharacter, Players:GetPlayerFromCharacter(EntityCharacter))
		end
	end

	return NearestTarget
end

RunModule(function()
	local AntiVoidMode = "Normal" -- Normal, Collide, Velocity
	local AntiVoidMaterial = "ForceField" -- rescue platform material
	local AntiVoidRange = 10 -- rescue search range
	local AntiVoidPart
	local AntiVoidDirection
	local AntiVoidOpacity = 50 -- platform opacity %
	local AntiVoidMaterials = { "ForceField" }

	for _, Material in ipairs(Enum.Material:GetEnumItems()) do
		if Material.Name ~= "ForceField" then
			table.insert(AntiVoidMaterials, Material.Name)
		end
	end

	local function GetAntiVoidNearGround(BedwarsReference, Range)
		local _, _, RootPart = GetCharacterState()
		if not RootPart then
			return nil
		end

		local SearchRange = Vector3.new(3, 3, 3) * (Range or AntiVoidRange or 10)
		local LocalPosition = RootPart.Position
		local StartPoint = Vector3.new(
			math.round((LocalPosition.X - SearchRange.X) / 3),
			math.round((LocalPosition.Y - SearchRange.Y) / 3),
			math.round((LocalPosition.Z - SearchRange.Z) / 3)
		)
		local EndPoint = Vector3.new(
			math.round((LocalPosition.X + SearchRange.X) / 3),
			math.round((LocalPosition.Y + SearchRange.Y) / 3),
			math.round((LocalPosition.Z + SearchRange.Z) / 3)
		)

		local ClosestDistance = 60
		local ClosestPosition = nil
		for _, WorldPosition in ipairs(GetBlocksInPoints(BedwarsReference, StartPoint, EndPoint)) do
			local UpperBlock = GetPlacedBlockAt(BedwarsReference, WorldPosition + Vector3.new(0, 3, 0))
			if not UpperBlock then
				local Distance = (LocalPosition - WorldPosition).Magnitude
				if Distance < ClosestDistance then
					ClosestDistance = Distance
					ClosestPosition = WorldPosition + Vector3.new(0, 3, 0)
				end
			end
		end

		return ClosestPosition
	end

	local function UpdateAntiVoidPartAppearance()
		if not AntiVoidPart then
			return
		end

		AntiVoidPart.Material = Enum.Material[AntiVoidMaterial] or Enum.Material.ForceField
		AntiVoidPart.Transparency = 1 - math.clamp(AntiVoidOpacity / 100, 0, 1)
		AntiVoidPart.CanCollide = AntiVoidMode == "Collide"
	end

	AntiVoidModule = TaskAPI.Categories.Movement:CreateModule({
		Name = "AntiVoid",
		Function = function(Enabled, RunId, Module)
			AntiVoidDirection = nil
			AntiVoidPart = nil

			if not Enabled then
				return
			end

			local BedwarsReference = rawget(getgenv(), "bedwars") or EnsureBedwarsRuntime()
			local Store = CreateTaskiumStore()

			repeat
				task.wait()
				Store = CreateTaskiumStore()
			until not Module:IsActive(RunId) or (Store and Store.matchState ~= 0)

			if not Module:IsActive(RunId) then
				return
			end

			BedwarsReference = rawget(getgenv(), "bedwars") or EnsureBedwarsRuntime() or BedwarsReference
			local LowGroundY = GetAntiVoidLowGround(BedwarsReference)
			if not LowGroundY then
				TaskAPI.Notification("Taskium", "AntiVoid couldn't find BedWars ground data.", 5, "Error")
				Module:SetEnabled(false, {
					SkipNotify = true
				})
				return
			end

			local RescuePart = Instance.new("Part")
			RescuePart.Name = "TaskiumAntiVoidPart"
			RescuePart.Size = Vector3.new(10000, 1, 10000)
			RescuePart.Position = Vector3.new(0, LowGroundY - 2, 0)
			RescuePart.Anchored = true
			RescuePart.CanQuery = false
			RescuePart.CanTouch = true
			RescuePart.Color = Color3.fromRGB(255, 255, 255)
			RescuePart.Parent = Workspace
			AntiVoidPart = RescuePart
			UpdateAntiVoidPartAppearance()
			Module:Clean(RescuePart)
			Module:Clean(function()
				AntiVoidDirection = nil
				if AntiVoidPart == RescuePart then
					AntiVoidPart = nil
				end
			end)

			local TouchDebounce = 0
			Module:Clean(RescuePart.Touched:Connect(function(TouchedPart)
				if not Module:IsActive(RunId) or TouchDebounce > tick() then
					return
				end

				local Character, Humanoid, RootPart = GetCharacterState()
				if not (Character and Humanoid and RootPart and Humanoid.Health > 0) then
					return
				end

				if TouchedPart.Parent ~= Character then
					return
				end

				TouchDebounce = tick() + 0.1
				if AntiVoidMode == "Velocity" then
					RootPart.Velocity = Vector3.new(RootPart.Velocity.X, 100, RootPart.Velocity.Z)
					return
				end

				if AntiVoidMode ~= "Normal" then
					return
				end

				local RescuePosition = GetAntiVoidNearGround(BedwarsReference, AntiVoidRange)
				if not RescuePosition then
					return
				end

				local LastTeleported = LocalPlayer:GetAttribute("LastTeleported")
				local RayCheck = RaycastParams.new()
				RayCheck.RespectCanCollide = true

				local RescueConnection
				RescueConnection = RunService.PreSimulation:Connect(function()
					if not Module:IsActive(RunId) then
						AntiVoidDirection = nil
						RescueConnection:Disconnect()
						return
					end

					if (FlyModule and FlyModule.Enabled) or (LongJumpModule and LongJumpModule.Enabled) then
						AntiVoidDirection = nil
						RescueConnection:Disconnect()
						return
					end

					local CurrentCharacter, CurrentHumanoid, CurrentRootPart = GetCharacterState()
					if not (CurrentCharacter and CurrentHumanoid and CurrentRootPart and CurrentHumanoid.Health > 0) then
						AntiVoidDirection = nil
						RescueConnection:Disconnect()
						return
					end

					if LocalPlayer:GetAttribute("LastTeleported") ~= LastTeleported then
						AntiVoidDirection = nil
						RescueConnection:Disconnect()
						return
					end

					local Delta = (RescuePosition - CurrentRootPart.Position) * Vector3.new(1, 0, 1)
					AntiVoidDirection = Delta.Unit == Delta.Unit and Delta.Unit or Vector3.zero
					CurrentRootPart.Velocity = CurrentRootPart.Velocity * Vector3.new(1, 0, 1)
					RayCheck.FilterDescendantsInstances = { Workspace.CurrentCamera, CurrentCharacter }
					RayCheck.CollisionGroup = CurrentRootPart.CollisionGroup

					local WallRaycast = Workspace:Raycast(CurrentRootPart.Position, AntiVoidDirection, RayCheck)
					if WallRaycast then
						for _ = 1, 10 do
							local ShiftedPosition = RoundToBlockGrid(WallRaycast.Position + (WallRaycast.Normal * 1.5)) + Vector3.new(0, 3, 0)
							if not GetPlacedBlockAt(BedwarsReference, ShiftedPosition) then
								RescuePosition = Vector3.new(RescuePosition.X, LowGroundY, RescuePosition.Z)
								break
							end
						end
					end

					CurrentRootPart.CFrame = CurrentRootPart.CFrame + Vector3.new(0, RescuePosition.Y - CurrentRootPart.Position.Y, 0)
					CurrentRootPart.AssemblyLinearVelocity = (AntiVoidDirection * math.max(GetBedwarsSpeed(), 16)) + Vector3.new(0, CurrentRootPart.AssemblyLinearVelocity.Y, 0)

					if Delta.Magnitude < 1 then
						AntiVoidDirection = nil
						RescueConnection:Disconnect()
					end
				end)
				Module:Clean(RescueConnection)
			end))
		end,
		ToolTip = "Prevents you from falling into the void in BedWars."
	})

	AntiVoidModule:CreateDropdown({
		Name = "Move Mode",
		List = { "Normal", "Collide", "Velocity" },
		Function = function(Value)
			AntiVoidMode = Value
			UpdateAntiVoidPartAppearance()
		end,
		ToolTip = "Normal moves you to nearby ground, Collide lets you stand on the platform, Velocity launches you upward."
	})

	AntiVoidModule:CreateDropdown({
		Name = "Material",
		List = AntiVoidMaterials,
		Function = function(Value)
			AntiVoidMaterial = Value
			UpdateAntiVoidPartAppearance()
		end,
		ToolTip = "Changes the AntiVoid platform material."
	})

	AntiVoidModule:CreateSlider({
		Name = "Opacity",
		Min = 0,
		Max = 100,
		Default = 50,
		Function = function(Value)
			AntiVoidOpacity = Value
			UpdateAntiVoidPartAppearance()
		end,
		Suffix = "%",
		ToolTip = "Adjusts how visible the AntiVoid platform is."
	})

	AntiVoidModule:CreateSlider({
		Name = "Search Range",
		Min = 4,
		Max = 20,
		Default = 10,
		Function = function(Value)
			AntiVoidRange = Value
		end,
		ToolTip = "How far AntiVoid looks for nearby rescue ground."
	})
end)

RunModule(function()
	local AntiHitRange = 30 -- enemy trigger range
	local AntiHitInterval = 0.5 -- repeat interval
	local AntiHitDownOffset = 12 -- drop depth
	local AntiHitSafeDepth = 140 -- lowest safe depth
	local AntiHitHoldTime = 0.01 -- return delay
	local AntiHitLowGroundY
	local AntiHitInCycle = false
	local AntiHitNextBounceAt = 0
	local AntiHitCycleToken = 0
	local AntiHitBlockGroundHitUntil = 0
	local AntiHitHealthRestoreUntil = 0
	local AntiHitHealthBaseline

	AntiHitModule = TaskAPI.Categories.Movement:CreateModule({
		Name = "AntiHit",
		Function = function(Enabled, RunId, Module)
			local HookOwnerToken = "AntiHit_" .. tostring(RunId) .. "_" .. tostring(math.floor(os.clock() * 1000))
			local AntiHitHookState = RuntimeState.AntiHitHook or {}
			RuntimeState.AntiHitHook = AntiHitHookState
			local PendingReturnAt = 0
			local PendingReturnCharacter
			local PendingReturnPivot
			local PendingCameraCFrame
			local PendingCameraFocus

			local function ResetAntiHitState()
				AntiHitCycleToken = AntiHitCycleToken + 1
				AntiHitInCycle = false
				AntiHitNextBounceAt = 0
				AntiHitBlockGroundHitUntil = 0
				AntiHitHealthRestoreUntil = 0
				AntiHitHealthBaseline = nil
				PendingReturnAt = 0
				PendingReturnCharacter = nil
				PendingReturnPivot = nil
				PendingCameraCFrame = nil
				PendingCameraFocus = nil
			end

			local function RestoreAntiHitHealth(Character, Humanoid)
				if not AntiHitHealthBaseline then
					return
				end
				if Humanoid and Humanoid.Health < AntiHitHealthBaseline then
					Humanoid.Health = AntiHitHealthBaseline
				end
				if Character then
					local AttributeHealth = Character:GetAttribute("Health")
					if type(AttributeHealth) == "number" and AttributeHealth < AntiHitHealthBaseline then
						Character:SetAttribute("Health", AntiHitHealthBaseline)
					end
				end
			end

			local function RemoveAntiHitGroundHitHook()
				if AntiHitHookState.OwnerToken ~= HookOwnerToken then
					return
				end
				if AntiHitHookState.Client and AntiHitHookState.WrappedGet and AntiHitHookState.Client.Get == AntiHitHookState.WrappedGet then
					AntiHitHookState.Client.Get = AntiHitHookState.OriginalGet
				end
				AntiHitHookState.Client = nil
				AntiHitHookState.OriginalGet = nil
				AntiHitHookState.WrappedGet = nil
				AntiHitHookState.OwnerToken = nil
				AntiHitHookState.RemoteName = nil
			end

			local function ApplyAntiHitGroundHitHook(BedwarsReference, RemoteTable)
				local Client = BedwarsReference and BedwarsReference.Client
				local RemoteName = RemoteTable and RemoteTable.GroundHit
				if not (Client and type(Client.Get) == "function" and type(RemoteName) == "string" and RemoteName ~= "") then
					return
				end
				if AntiHitHookState.Client ~= Client or AntiHitHookState.RemoteName ~= RemoteName then
					if AntiHitHookState.Client and AntiHitHookState.WrappedGet and AntiHitHookState.Client.Get == AntiHitHookState.WrappedGet then
						AntiHitHookState.Client.Get = AntiHitHookState.OriginalGet
					end
					AntiHitHookState.Client = Client
					AntiHitHookState.OriginalGet = Client.Get
					AntiHitHookState.RemoteName = RemoteName
				end

				AntiHitHookState.OwnerToken = HookOwnerToken
				local OriginalGet = AntiHitHookState.OriginalGet
				local WrappedGet = function(Self, RequestedRemoteName)
					local Call = OriginalGet(Self, RequestedRemoteName)
					if AntiHitHookState.OwnerToken ~= HookOwnerToken or RequestedRemoteName ~= RemoteName then
						return Call
					end
					if tick() >= AntiHitBlockGroundHitUntil then
						return Call
					end

					local FakeInstance = setmetatable({
						FireServer = function()
							return nil
						end
					}, {
						__index = function(_, Key)
							return Call and Call.instance and Call.instance[Key]
						end
					})

					return setmetatable({
						instance = FakeInstance,
						SendToServer = function()
							return nil
						end,
						FireServer = function()
							return nil
						end
					}, {
						__index = function(_, Key)
							return Call and Call[Key]
						end
					})
				end

				AntiHitHookState.WrappedGet = WrappedGet
				Client.Get = WrappedGet
			end

			local function HoldAntiHitCamera()
				local Camera = Workspace.CurrentCamera
				if Camera and PendingCameraCFrame and PendingCameraFocus then
					Camera.CFrame = PendingCameraCFrame
					Camera.Focus = PendingCameraFocus
				end
			end

			if not Enabled then
				RemoveAntiHitGroundHitHook()
				ResetAntiHitState()
				return
			end

			local BedwarsReference = rawget(getgenv(), "bedwars") or EnsureBedwarsRuntime()
			local RemoteTable = rawget(getgenv(), "remotes") or {}
			local Store = CreateTaskiumStore()

			repeat
				task.wait()
				Store = CreateTaskiumStore()
			until not Module:IsActive(RunId) or (Store and Store.matchState ~= 0)

			if not Module:IsActive(RunId) then
				return
			end

			BedwarsReference = rawget(getgenv(), "bedwars") or EnsureBedwarsRuntime() or BedwarsReference
			RemoteTable = rawget(getgenv(), "remotes") or RemoteTable
			AntiHitLowGroundY = GetAntiVoidLowGround(BedwarsReference)
			if not AntiHitLowGroundY then
				TaskAPI.Notification("Taskium", "AntiHit couldn't find BedWars ground data.", 5, "Error")
				Module:SetEnabled(false, {
					SkipNotify = true
				})
				return
			end

			Module:Clean(ResetAntiHitState)
			Module:Clean(RemoveAntiHitGroundHitHook)
			Module:Clean(LocalPlayer.CharacterAdded:Connect(function()
				ResetAntiHitState()
			end))

			Module:Clean(RunService.PreSimulation:Connect(function()
				local CurrentBedwarsReference, CurrentRemotes = EnsureBedwarsRuntime()
				BedwarsReference = CurrentBedwarsReference or BedwarsReference
				RemoteTable = CurrentRemotes or RemoteTable
				ApplyAntiHitGroundHitHook(BedwarsReference, RemoteTable)

				local LoopCharacter, LoopHumanoid = GetCharacterState()
				if tick() < AntiHitHealthRestoreUntil then
					RestoreAntiHitHealth(LoopCharacter, LoopHumanoid)
				end

				if not Module:IsActive(RunId) then
					return
				end

				if AntiHitInCycle then
					HoldAntiHitCamera()
					if tick() < PendingReturnAt then
						return
					end

					local FinalCharacter, FinalHumanoid, FinalRootPart = GetCharacterState()
					if FinalCharacter == PendingReturnCharacter and PendingReturnPivot and FinalHumanoid and FinalRootPart and FinalHumanoid.Health > 0 then
						FinalCharacter:PivotTo(PendingReturnPivot)
						FinalRootPart.AssemblyLinearVelocity = Vector3.zero
						HoldAntiHitCamera()
						RestoreAntiHitHealth(FinalCharacter, FinalHumanoid)
					end

					PendingReturnAt = 0
					PendingReturnCharacter = nil
					PendingReturnPivot = nil
					PendingCameraCFrame = nil
					PendingCameraFocus = nil
					AntiHitInCycle = false
					return
				end

				if tick() < AntiHitNextBounceAt then
					return
				end
				if (FlyModule and FlyModule.Enabled) or (LongJumpModule and LongJumpModule.Enabled) then
					return
				end

				local Character, Humanoid, RootPart = GetCharacterState()
				if not (Character and Humanoid and RootPart and Humanoid.Health > 0) then
					return
				end

				local HumanoidState = Humanoid:GetState()
				if HumanoidState == Enum.HumanoidStateType.Seated
					or HumanoidState == Enum.HumanoidStateType.Climbing
					or HumanoidState == Enum.HumanoidStateType.Swimming then
					return
				end

				local TargetData = GetNearestAntiHitTarget(RootPart, AntiHitRange)
				if not TargetData then
					return
				end

				local SavedPivot = Character:GetPivot()
				local SavedPosition = SavedPivot.Position
				local SavedRotation = SavedPivot - SavedPosition
				local LowGroundY = AntiHitLowGroundY or GetAntiVoidLowGround(BedwarsReference)
				if not LowGroundY then
					return
				end
				AntiHitLowGroundY = LowGroundY

				local DownTargetY = math.max(LowGroundY - AntiHitDownOffset, LowGroundY - AntiHitSafeDepth)
				AntiHitInCycle = true
				AntiHitNextBounceAt = tick() + AntiHitInterval
				AntiHitCycleToken = AntiHitCycleToken + 1
				AntiHitBlockGroundHitUntil = tick() + 0.35
				AntiHitHealthRestoreUntil = tick() + 0.35
				AntiHitHealthBaseline = Humanoid.Health
				PendingReturnAt = tick() + AntiHitHoldTime
				PendingReturnCharacter = Character
				PendingReturnPivot = SavedPivot
				local Camera = Workspace.CurrentCamera
				PendingCameraCFrame = Camera and Camera.CFrame or nil
				PendingCameraFocus = Camera and Camera.Focus or nil

				Character:PivotTo(CFrame.new(Vector3.new(SavedPosition.X, DownTargetY, SavedPosition.Z)) * SavedRotation)
				RootPart.AssemblyLinearVelocity = Vector3.zero
				HoldAntiHitCamera()
			end))
		end,
		ToolTip = "Teleports you below the map and back every 0.5 seconds while an enemy is nearby."
	})
end)

RunModule(function()
	local ClimbWallLength = 3.5 -- front wall check
	local ClimbUpSpeed = 24 -- upward push
	local ClimbLedgeHeight = 3.5 -- ledge probe height
	local ClimbForward = 1.35 -- forward ledge probe
	local ClimbDown = 6 -- downward ledge probe
	local ClimbSnap = 0.75 -- snap onto ledge

	ClimbModule = TaskAPI.Categories.Movement:CreateModule({
		Name = "Climb",
		Function = function(Enabled, RunId, Module)
			if not Enabled then
				return
			end

			local ClimbRaycast = RaycastParams.new()
			ClimbRaycast.RespectCanCollide = true

			Module:Clean(RunService.PreSimulation:Connect(function()
				if not Module:IsActive(RunId) then
					return
				end

				local Character, Humanoid, RootPart = GetCharacterState()
				if not (Character and Humanoid and RootPart and Humanoid.Health > 0) then
					return
				end

				local BedwarsReference = rawget(getgenv(), "bedwars") or EnsureBedwarsRuntime()
				if BedwarsReference and BedwarsReference.StatefulEntityKnockbackController then
					pcall(function()
						BedwarsReference.StatefulEntityKnockbackController.lastImpulseTime = math.huge
					end)
				end

				if (FlyModule and FlyModule.Enabled) or (LongJumpModule and LongJumpModule.Enabled) then
					return
				end

				local HumanoidState = Humanoid:GetState()
				if HumanoidState == Enum.HumanoidStateType.Swimming or HumanoidState == Enum.HumanoidStateType.Seated then
					return
				end

				local MoveDirection = Humanoid.MoveDirection
				if MoveDirection.Magnitude <= 0.001 then
					return
				end

				ClimbRaycast.FilterDescendantsInstances = { Character, Workspace.CurrentCamera }
				ClimbRaycast.CollisionGroup = RootPart.CollisionGroup

				local WallRaycast = Workspace:Raycast(RootPart.Position, MoveDirection.Unit * ClimbWallLength, ClimbRaycast)
				if not WallRaycast or math.abs(WallRaycast.Normal.Y) > 0.3 then
					return
				end

				local CurrentVelocity = RootPart.AssemblyLinearVelocity
				local HorizontalVelocity = MoveDirection.Unit * math.max(GetBedwarsSpeed(), 16)
				RootPart.AssemblyLinearVelocity = Vector3.new(
					HorizontalVelocity.X,
					math.max(CurrentVelocity.Y, ClimbUpSpeed),
					HorizontalVelocity.Z
				)

				local LedgeProbeOrigin = RootPart.Position + Vector3.new(0, Humanoid.HipHeight + ClimbLedgeHeight, 0)
				local LedgeForwardOffset = MoveDirection.Unit * ClimbForward
				local UpperWallRaycast = Workspace:Raycast(LedgeProbeOrigin, LedgeForwardOffset, ClimbRaycast)
				if not UpperWallRaycast then
					local LedgeDownRaycast = Workspace:Raycast(
						LedgeProbeOrigin + LedgeForwardOffset,
						Vector3.new(0, -ClimbDown, 0),
						ClimbRaycast
					)
					if LedgeDownRaycast and LedgeDownRaycast.Normal.Y > 0.6 then
						local SnapPosition = Vector3.new(
							LedgeDownRaycast.Position.X,
							LedgeDownRaycast.Position.Y + Humanoid.HipHeight + ClimbSnap,
							LedgeDownRaycast.Position.Z
						)
						pcall(function()
							RootPart.CFrame = CFrame.lookAlong(SnapPosition, RootPart.CFrame.LookVector)
							RootPart.AssemblyLinearVelocity = Vector3.new(
								HorizontalVelocity.X,
								math.max(RootPart.AssemblyLinearVelocity.Y, ClimbUpSpeed * 0.35),
								HorizontalVelocity.Z
							)
						end)
					end
				end
			end))
		end,
		ToolTip = "Climbs walls while you move into them."
	})

	ClimbModule:CreateSlider({
		Name = "Speed",
		Min = 8,
		Max = 60,
		Default = 24,
		Function = function(Value)
			ClimbUpSpeed = Value
		end,
		ToolTip = "Adjusts how fast Climb pushes you upward."
	})
end)

local ScaffoldModule

local ScaffoldAdjacentOffsets = {}
for X = -3, 3, 3 do
	for Y = -3, 3, 3 do
		for Z = -3, 3, 3 do
			local Offset = Vector3.new(X, Y, Z)
			if Offset ~= Vector3.zero then
				table.insert(ScaffoldAdjacentOffsets, Offset)
			end
		end
	end
end

RoundToBlockGrid = function(Position)
	local RoundFunction = rawget(getgenv(), "roundPos")
	if type(RoundFunction) == "function" then
		local Success, Result = pcall(RoundFunction, Position)
		if Success and typeof(Result) == "Vector3" then
			return Result
		end
	end

	return Vector3.new(
		math.round(Position.X / 3) * 3,
		math.round(Position.Y / 3) * 3,
		math.round(Position.Z / 3) * 3
	)
end

GetPlacedBlockAt = function(BedwarsReference, Position)
	local GetPlacedBlockFunction = rawget(getgenv(), "getPlacedBlock")
	if type(GetPlacedBlockFunction) == "function" then
		local Success, Block, BlockPosition = pcall(GetPlacedBlockFunction, Position)
		if Success then
			return Block, BlockPosition
		end
	end

	local BlockController = BedwarsReference and BedwarsReference.BlockController
	local BlockStore = BlockController and type(BlockController.getStore) == "function" and BlockController:getStore()
	if BlockController and BlockStore and type(BlockController.getBlockPosition) == "function" and type(BlockStore.getBlockAt) == "function" then
		local BlockPosition = BlockController:getBlockPosition(Position)
		local BlockData = BlockStore:getBlockAt(BlockPosition)
		if BlockData then
			return BlockData, BlockPosition
		end
		return nil, BlockPosition
	end

	return nil, nil
end

local function GetBlockHealth(BedwarsReference, Block, BlockPosition)
	local BlockController = BedwarsReference and BedwarsReference.BlockController
	local BlockStore = BlockController and type(BlockController.getStore) == "function" and BlockController:getStore()
	if BlockStore and type(BlockStore.getBlockData) == "function" then
		local BlockData = BlockStore:getBlockData(BlockPosition)
		if BlockData then
			return BlockData:GetAttribute("1") or BlockData:GetAttribute("Health") or Block:GetAttribute("Health")
		end
	end

	return Block and (Block:GetAttribute("Health") or Block:GetAttribute("MaxHealth")) or nil
end

local BreakerPathSides = {}
for _, Normal in ipairs(Enum.NormalId:GetEnumItems()) do
	table.insert(BreakerPathSides, Vector3.FromNormalId(Normal) * 3)
end

local function GetBlockHitCost(BedwarsReference, Block, BlockWorldPosition)
	if not Block then
		return math.huge
	end

	local Store = CreateTaskiumStore()
	local BreakMeta = BedwarsReference and BedwarsReference.ItemMeta and BedwarsReference.ItemMeta[Block.Name]
	local BreakType = BreakMeta and BreakMeta.block and BreakMeta.block.breakType
	local ToolData = BreakType and Store and Store.tools and Store.tools[BreakType]
	local ToolMeta = ToolData and ToolData.itemType and BedwarsReference.ItemMeta and BedwarsReference.ItemMeta[ToolData.itemType]
	local ToolStrength = ToolMeta and ToolMeta.breakBlock and ToolMeta.breakBlock[BreakType] or 2
	local _, BlockPosition = GetPlacedBlockAt(BedwarsReference, BlockWorldPosition)
	local Health = BlockPosition and GetBlockHealth(BedwarsReference, Block, BlockPosition) or (Block:GetAttribute("Health") or 1)
	return (Health or 1) / math.max(ToolStrength or 2, 0.01)
end

local function CalculateBreakerPath(BedwarsReference, TargetBlock, StartWorldPosition, Sorting, MaxAngle, LocalRootPart)
	local OpenList = { { Cost = 0, Position = StartWorldPosition } }
	local Visited = {}
	local Distances = {
		[StartWorldPosition] = 0
	}
	local AirNodes = {}
	local Path = {}
	local LocalPosition = LocalRootPart.Position
	local LocalFacing = LocalRootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	local AngleLimit = math.rad(MaxAngle or 360) / 2

	for _ = 1, 10000 do
		table.sort(OpenList, function(Left, Right)
			return Left.Cost < Right.Cost
		end)

		local Node = table.remove(OpenList, 1)
		if not Node then
			break
		end

		if Visited[Node.Position] then
			continue
		end

		Visited[Node.Position] = true

		for _, Side in ipairs(BreakerPathSides) do
			local NextPosition = Node.Position + Side
			if not Visited[NextPosition] then
				local NextBlock = GetPlacedBlockAt(BedwarsReference, NextPosition)
				if not NextBlock or NextBlock:GetAttribute("NoBreak") or NextBlock == TargetBlock then
					if not NextBlock then
						AirNodes[Node.Position] = true
					end
				else
					local Delta = (NextBlock.Position - LocalPosition) * Vector3.new(1, 0, 1)
					if Delta.Magnitude > 0 and LocalFacing.Magnitude > 0 and AngleLimit < math.pi then
						local Dot = math.clamp(LocalFacing.Unit:Dot(Delta.Unit), -1, 1)
						local Angle = math.acos(Dot)
						if Angle > AngleLimit then
							continue
						end
					end

					local StepCost
					if Sorting == "Distance" then
						StepCost = (LocalPosition - NextBlock.Position).Magnitude
					else
						StepCost = GetBlockHitCost(BedwarsReference, NextBlock, NextPosition)
					end

					local NewCost = Node.Cost + StepCost
					if NewCost < (Distances[NextPosition] or math.huge) then
						Distances[NextPosition] = NewCost
						Path[NextPosition] = Node.Position
						table.insert(OpenList, {
							Cost = NewCost,
							Position = NextPosition
						})
					end
				end
			end
		end
	end

	local BestPosition = nil
	local BestCost = math.huge
	for WorldPosition in pairs(AirNodes) do
		local Cost = Distances[WorldPosition] or math.huge
		if Cost < BestCost then
			BestPosition = WorldPosition
			BestCost = Cost
		end
	end

	return BestPosition, BestCost, Path
end

GetBlocksInPoints = function(BedwarsReference, StartPoint, EndPoint)
	local BlockController = BedwarsReference and BedwarsReference.BlockController
	local BlockStore = BlockController and type(BlockController.getStore) == "function" and BlockController:getStore()
	if not (BlockController and BlockStore and type(BlockStore.getBlockAt) == "function") then
		return {}
	end

	local StartX, EndX = math.min(StartPoint.X, EndPoint.X), math.max(StartPoint.X, EndPoint.X)
	local StartY, EndY = math.min(StartPoint.Y, EndPoint.Y), math.max(StartPoint.Y, EndPoint.Y)
	local StartZ, EndZ = math.min(StartPoint.Z, EndPoint.Z), math.max(StartPoint.Z, EndPoint.Z)
	local Blocks = {}

	for X = StartX, EndX do
		for Y = StartY, EndY do
			for Z = StartZ, EndZ do
				local Vector = Vector3.new(X, Y, Z)
				if BlockStore:getBlockAt(Vector) then
					table.insert(Blocks, Vector * 3)
				end
			end
		end
	end

	return Blocks
end

local function NearCorner(PositionCheck, Position)
	local StartPosition = PositionCheck - Vector3.new(3, 3, 3)
	local EndPosition = PositionCheck + Vector3.new(3, 3, 3)
	local Direction = Position - PositionCheck
	local Check = PositionCheck
	if Direction.Magnitude > 0 then
		Check = PositionCheck + Direction.Unit * 100
	end

	return Vector3.new(
		math.clamp(Check.X, StartPosition.X, EndPosition.X),
		math.clamp(Check.Y, StartPosition.Y, EndPosition.Y),
		math.clamp(Check.Z, StartPosition.Z, EndPosition.Z)
	)
end

local function BlockProximity(BedwarsReference, Position)
	local BlockController = BedwarsReference and BedwarsReference.BlockController
	if not (BlockController and type(BlockController.getBlockPosition) == "function") then
		return nil
	end

	local Magnitude = 60
	local Returned = nil
	local Blocks = GetBlocksInPoints(
		BedwarsReference,
		BlockController:getBlockPosition(Position - Vector3.new(21, 21, 21)),
		BlockController:getBlockPosition(Position + Vector3.new(21, 21, 21))
	)

	for _, BlockPosition in ipairs(Blocks) do
		local CornerPosition = NearCorner(BlockPosition, Position)
		local NewMagnitude = (Position - CornerPosition).Magnitude
		if NewMagnitude < Magnitude then
			Magnitude = NewMagnitude
			Returned = CornerPosition
		end
	end

	return Returned
end

local function CheckAdjacentBlock(BedwarsReference, Position)
	for _, Offset in ipairs(ScaffoldAdjacentOffsets) do
		if GetPlacedBlockAt(BedwarsReference, Position + Offset) then
			return true
		end
	end

	return false
end

local function GetInventoryItemsFromStore(Store)
	return Store
		and Store.inventory
		and Store.inventory.inventory
		and Store.inventory.inventory.items
		or {}
end

local function GetWoolFromStore(Store)
	for _, Item in ipairs(GetInventoryItemsFromStore(Store)) do
		if type(Item.itemType) == "string" and Item.itemType:find("wool") then
			return Item.itemType, Item.amount or 0
		end
	end

	return nil, 0
end

local function GetScaffoldBlock(BedwarsReference, Store, LimitItem)
	if Store
		and Store.hand
		and Store.hand.toolType == "block"
		and Store.hand.tool
		and Store.hand.tool.Name then
		return Store.hand.tool.Name, Store.hand.amount or 0
	end

	if not LimitItem then
		local WoolItemType, WoolAmount = GetWoolFromStore(Store)
		if WoolItemType then
			return WoolItemType, WoolAmount
		end

		for _, Item in ipairs(GetInventoryItemsFromStore(Store)) do
			local ItemMeta = BedwarsReference
				and BedwarsReference.ItemMeta
				and BedwarsReference.ItemMeta[Item.itemType]
			if ItemMeta and ItemMeta.block then
				return Item.itemType, Item.amount or 0
			end
		end
	end

	return nil, 0
end

RunModule(function()
	local ScaffoldExpand = 1 -- forward placement distance
	local ScaffoldTower = true -- vertical tower jump
	local ScaffoldDownwards = true -- shift downward mode
	local ScaffoldDiagonal = true -- diagonal smoothing
	local ScaffoldLimitItem = false -- only use held block
	local ScaffoldRequireMouseDown = false -- require left click

	ScaffoldModule = TaskAPI.Categories.Movement:CreateModule({
		Name = "Scaffold",
		Function = function(Enabled, RunId, Module)
			if not Enabled then
				return
			end

			local BedwarsReference = rawget(getgenv(), "bedwars") or EnsureBedwarsRuntime()
			if not (BedwarsReference and type(BedwarsReference.placeBlock) == "function") then
				TaskAPI.Notification("Taskium", "Scaffold couldn't find BedWars block placement.", 5, "Error")
				Module:SetEnabled(false, {
					SkipNotify = true
				})
				return
			end

			task.spawn(function()
				local LastPosition = Vector3.zero

				repeat
					local Character, Humanoid, RootPart = GetCharacterState()
					local BedwarsNow = rawget(getgenv(), "bedwars") or BedwarsReference
					if not (BedwarsNow and type(BedwarsNow.placeBlock) == "function") then
						BedwarsNow = EnsureBedwarsRuntime() or BedwarsNow
						BedwarsReference = BedwarsNow or BedwarsReference
					end
					local PlaceBlockFunction = BedwarsNow and BedwarsNow.placeBlock
					local Store = BedwarsNow and SyncTaskiumStore(BedwarsNow) or nil

					if Character and Humanoid and RootPart and Humanoid.Health > 0 and type(PlaceBlockFunction) == "function" then
						local BlockItemType = GetScaffoldBlock(BedwarsNow, Store, ScaffoldLimitItem)
						if ScaffoldRequireMouseDown and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
							BlockItemType = nil
						end

						if BlockItemType then
							if ScaffoldTower and UserInputService:IsKeyDown(Enum.KeyCode.Space) and not UserInputService:GetFocusedTextBox() then
								RootPart.Velocity = Vector3.new(RootPart.Velocity.X, 38, RootPart.Velocity.Z)
							end

							for Index = ScaffoldExpand, 1, -1 do
								local CurrentPosition = RoundToBlockGrid(
									RootPart.Position
									- Vector3.new(0, Humanoid.HipHeight + ((ScaffoldDownwards and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)) and 4.5 or 1.5), 0)
									+ Humanoid.MoveDirection * (Index * 3)
								)

								if ScaffoldDiagonal then
									if math.abs(math.round(math.deg(math.atan2(-Humanoid.MoveDirection.X, -Humanoid.MoveDirection.Z)) / 45) * 45) % 90 == 45 then
										local Delta = LastPosition - CurrentPosition
										if ((Delta.X == 0 and Delta.Z ~= 0) or (Delta.X ~= 0 and Delta.Z == 0))
											and ((LastPosition - RootPart.Position) * Vector3.new(1, 0, 1)).Magnitude < 2.5 then
											CurrentPosition = LastPosition
										end
									end
								end

								local ExistingBlock, BlockPosition = GetPlacedBlockAt(BedwarsNow, CurrentPosition)
								if not ExistingBlock and BlockPosition then
									local PlacementPosition = CheckAdjacentBlock(BedwarsNow, BlockPosition * 3) and (BlockPosition * 3) or BlockProximity(BedwarsNow, CurrentPosition)
									if PlacementPosition then
										task.spawn(PlaceBlockFunction, PlacementPosition, BlockItemType, false)
									end
								end

								LastPosition = CurrentPosition
							end
						end
					end

					task.wait(0.03)
				until not Module:IsActive(RunId)
			end)
		end,
		ToolTip = "Helps you make bridges/scaffold walk."
	})

	ScaffoldModule:CreateToggle({
		Name = "Tower",
		Function = function(Callback)
			ScaffoldTower = Callback
		end,
		Default = true,
		ToolTip = "Jumps upward while scaffolding when Space is held."
	})

	ScaffoldModule:CreateToggle({
		Name = "Downwards",
		Function = function(Callback)
			ScaffoldDownwards = Callback
		end,
		Default = true,
		ToolTip = "Places lower when LeftShift is held."
	})

	ScaffoldModule:CreateToggle({
		Name = "Diagonal",
		Function = function(Callback)
			ScaffoldDiagonal = Callback
		end,
		Default = true,
		ToolTip = "Keeps diagonal scaffold placement stable."
	})

	ScaffoldModule:CreateToggle({
		Name = "Limit To Items",
		Function = function(Callback)
			ScaffoldLimitItem = Callback
		end,
		ToolTip = "Only uses the block item currently in your hand."
	})

	ScaffoldModule:CreateToggle({
		Name = "Require Mouse Down",
		Function = function(Callback)
			ScaffoldRequireMouseDown = Callback
		end,
		ToolTip = "Only places blocks while left click is held."
	})

	ScaffoldModule:CreateSlider({
		Name = "Expand",
		Min = 1,
		Max = 6,
		Default = 1,
		Function = function(Value)
			ScaffoldExpand = Value
		end,
		ToolTip = "How far ahead to place blocks."
	})
end)

local ESPModule
RunModule(function()
	local ShowTeammates = false
	local UseTeamColors = true

	local function IsTeammate(Player)
		if not Player or Player == LocalPlayer then
			return false
		end

		if LocalPlayer.Team ~= nil and Player.Team ~= nil then
			return Player.Team == LocalPlayer.Team
		end

		if LocalPlayer.TeamColor ~= nil and Player.TeamColor ~= nil then
			return Player.TeamColor == LocalPlayer.TeamColor
		end

		return false
	end

	local function GetESPColor(Player)
		if UseTeamColors and Player and Player.TeamColor then
			return Player.TeamColor.Color
		end

		if IsTeammate(Player) then
			return Color3.fromRGB(85, 170, 255)
		end

		return Color3.fromRGB(255, 85, 85)
	end

	local function BrightenESPColor(Color)
		return Color:Lerp(Color3.new(1, 1, 1), 0.2)
	end

	local function GetESPDisplayName(Player)
		if not Player then
			return "Unknown"
		end

		return tostring(Player.DisplayName or Player.Name or "Unknown")
	end

	ESPModule = TaskAPI.Categories.Render:CreateModule({
		Name = "ESP",
		Function = function(Enabled, RunId, Module)
			if not Enabled then
				return
			end

			local ESPFolder = Instance.new("Folder")
			ESPFolder.Name = "TaskiumESP"
			ESPFolder.Parent = workspace
			Module:Clean(ESPFolder)

			local ESPGui = Instance.new("ScreenGui")
			ESPGui.Name = "TaskiumESPOverlay"
			ESPGui.ResetOnSpawn = false
			ESPGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			ESPGui.Parent = PlayerGui
			Module:Clean(ESPGui)

			local Highlights = {}
			local Billboards = {}

			local function RemoveHighlight(Player)
				local Highlight = Highlights[Player]
				if Highlight then
					Highlights[Player] = nil
					Highlight:Destroy()
				end

				local Billboard = Billboards[Player]
				if Billboard then
					Billboards[Player] = nil
					Billboard:Destroy()
				end
			end

			local function UpdateHighlight(Player)
				if Player == LocalPlayer then
					RemoveHighlight(Player)
					return
				end

				-- Using the updated GetCharacterState
				local Character, Humanoid, RootPart = GetCharacterState(Player)

				local ShouldShow = Character ~= nil
					and Humanoid ~= nil
					and Humanoid.Health > 0
					and RootPart ~= nil
					and (ShowTeammates or not IsTeammate(Player))

				if not ShouldShow then
					RemoveHighlight(Player)
					return
				end

				local Highlight = Highlights[Player]
				if not Highlight then
					Highlight = Instance.new("Highlight")
					Highlight.Name = Player.Name .. "_ESP"
					Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					Highlight.FillTransparency = 0.82
					Highlight.OutlineTransparency = 0.15
					Highlight.Parent = ESPFolder
					Highlights[Player] = Highlight
				end

				local HighlightColor = BrightenESPColor(GetESPColor(Player))
				Highlight.Adornee = Character
				Highlight.FillColor = HighlightColor
				Highlight.OutlineColor = HighlightColor
				Highlight.FillTransparency = 0.68
				Highlight.OutlineTransparency = 0
				Highlight.Enabled = true

				local Head = Character:FindFirstChild("Head")
				if not Head then
					return
				end

				local Billboard = Billboards[Player]
				if not Billboard then
					Billboard = Instance.new("BillboardGui")
					Billboard.Name = Player.Name .. "_ESPInfo"
					Billboard.AlwaysOnTop = true
					Billboard.LightInfluence = 0
					Billboard.MaxDistance = 10000
					Billboard.Size = UDim2.fromOffset(20, 20)
					Billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
					Billboard.Parent = ESPGui
					Billboards[Player] = Billboard

					local Background = Instance.new("Frame")
					Background.Name = "Background"
					Background.AnchorPoint = Vector2.new(0.5, 0.5)
					Background.Position = UDim2.new(0.5, 0, 0.5, 0)
					Background.Size = UDim2.new(1, 0, 1, 0)
					Background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
					Background.BackgroundTransparency = 0
					Background.BorderSizePixel = 0
					Background.Parent = Billboard

					local BackgroundCorner = Instance.new("UICorner")
					BackgroundCorner.CornerRadius = UDim.new(0, 20)
					BackgroundCorner.Parent = Background

					local InfoLabel = Instance.new("TextLabel")
					InfoLabel.Name = "InfoLabel"
					InfoLabel.BackgroundTransparency = 1
					InfoLabel.Position = UDim2.new(0, 8, 0, 0)
					InfoLabel.Size = UDim2.new(1, -16, 1, 0)
					InfoLabel.Font = Enum.Font.GothamBold
					InfoLabel.TextSize = 12
					InfoLabel.TextXAlignment = Enum.TextXAlignment.Center
					InfoLabel.TextYAlignment = Enum.TextYAlignment.Center
					InfoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
					InfoLabel.Parent = Background

					local InfoStroke = Instance.new("UIStroke")
					InfoStroke.Color = Color3.fromRGB(0, 0, 0)
					InfoStroke.Thickness = 1
					InfoStroke.Parent = InfoLabel
				end

				-- Grab the LocalPlayer state to calculate distance
				local _, _, LocalRootPart = GetCharacterState()
				local Distance = LocalRootPart and math.floor((LocalRootPart.Position - RootPart.Position).Magnitude + 0.5) or 0
				local Health = math.max(math.floor(Humanoid.Health + 0.5), 0)
				local NameText = GetESPDisplayName(Player)
				local InfoText = string.format("%s | %d health | %d", NameText, Health, Distance)
				local InfoBounds = TextService:GetTextSize(InfoText, 12, Enum.Font.GothamBold, Vector2.new(1000, 1000))
				local FrameWidth = math.max(20, InfoBounds.X + 20)
				local FrameHeight = 20

				Billboard.Adornee = Head
				Billboard.Enabled = true
				Billboard.Size = UDim2.fromOffset(FrameWidth, FrameHeight)
				Billboard.Background.InfoLabel.Position = UDim2.new(0, 8, 0, 0)
				Billboard.Background.InfoLabel.Size = UDim2.new(1, -16, 1, 0)
				Billboard.Background.InfoLabel.TextColor3 = HighlightColor
				Billboard.Background.InfoLabel.Text = InfoText
			end

			Module:Clean(Players.PlayerRemoving:Connect(function(Player)
				RemoveHighlight(Player)
			end))

			Module:Clean(RunService.Heartbeat:Connect(function()
				if not Module:IsActive(RunId) then
					return
				end

				for _, Player in ipairs(Players:GetPlayers()) do
					UpdateHighlight(Player)
				end
			end))
		end,
		ToolTip = "Highlights players through walls."
	})

	ESPModule:CreateToggle({
		Name = "Teammates",
		Function = function(Callback)
			ShowTeammates = Callback
		end,
		ToolTip = "Shows teammates too."
	})

	ESPModule:CreateToggle({
		Name = "Team Colors",
		Function = function(Callback)
			UseTeamColors = Callback
		end,
		ToolTip = "Uses Roblox team colors when available."
	})
end)

local SettingsModule
RunModule(function()
	local ArraylistToggle
	local ArraylistState = {
		TextSize = 16,
		GuiInstance = nil,
		AnimationConnection = nil,
		LayoutSignature = nil
	}

	local function StopArraylist()
		if ArraylistState.AnimationConnection then
			ArraylistState.AnimationConnection:Disconnect()
			ArraylistState.AnimationConnection = nil
		end

		if ArraylistState.GuiInstance then
			ArraylistState.GuiInstance:Destroy()
			ArraylistState.GuiInstance = nil
		end

		ArraylistState.LayoutSignature = nil
	end

	local function StartArraylist()
		StopArraylist()

		local ArraylistGui = Instance.new("ScreenGui")
		ArraylistGui.Name = "TaskiumArraylist"
		ArraylistGui.ResetOnSpawn = false
		ArraylistGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		ArraylistGui.Parent = PlayerGui
		ArraylistState.GuiInstance = ArraylistGui

		if SettingsModule then
			SettingsModule:Clean(ArraylistGui)
		end

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
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(235, 235, 235)),
				ColorSequenceKeypoint.new(0.03, Color3.fromRGB(235, 235, 235)),
				ColorSequenceKeypoint.new(0.10, Color3.fromRGB(120, 120, 120)),
				ColorSequenceKeypoint.new(0.22, Color3.fromRGB(8, 8, 8)),
				ColorSequenceKeypoint.new(0.78, Color3.fromRGB(8, 8, 8)),
				ColorSequenceKeypoint.new(0.90, Color3.fromRGB(120, 120, 120)),
				ColorSequenceKeypoint.new(0.97, Color3.fromRGB(235, 235, 235)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(235, 235, 235))
			})
		end

		local AnimatedTextGradients = {}

		local function ApplyBlackToWhiteGradient(GuiObject, Rotation)
			local Gradient = Instance.new("UIGradient")
			CreateMovingGradient(Gradient)
			Gradient.Rotation = Rotation or 0
			Gradient.Parent = GuiObject
			table.insert(AnimatedTextGradients, Gradient)
			return Gradient
		end

		local SideLineGradient = ApplyBlackToWhiteGradient(SideLine, 90)

		local function GetEnabledModules()
			local EnabledModules = {}

			for _, ListedModule in pairs(TaskAPI.Modules) do
				if ListedModule.Enabled and ListedModule ~= SettingsModule then
					table.insert(EnabledModules, ListedModule)
				end
			end

			table.sort(EnabledModules, function(Left, Right)
				local LeftWidth = TextService:GetTextSize(Left.Name, ArraylistState.TextSize, Enum.Font.GothamBold, Vector2.new(1000, 24)).X
				local RightWidth = TextService:GetTextSize(Right.Name, ArraylistState.TextSize, Enum.Font.GothamBold, Vector2.new(1000, 24)).X

				if LeftWidth == RightWidth then
					return Left.Name > Right.Name
				end

				return LeftWidth > RightWidth
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

		local function BuildArraylistSignature(EnabledModules)
			local SignatureParts = { tostring(ArraylistState.TextSize) }

			for _, ListedModule in ipairs(EnabledModules) do
				table.insert(SignatureParts, ListedModule.Name)
			end

			return table.concat(SignatureParts, "|")
		end

		local function RebuildArraylist(EnabledModules)
			ClearEntries()
			AnimatedTextGradients = {}

			local MaxWidth = 0
			local RowHeight = 24
			local TextSize = ArraylistState.TextSize
			local BackgroundPadding = 10

			for _, ListedModule in ipairs(EnabledModules) do
				local TextBounds = TextService:GetTextSize(ListedModule.Name, TextSize, Enum.Font.GothamBold, Vector2.new(1000, RowHeight))
				MaxWidth = math.max(MaxWidth, TextBounds.X + BackgroundPadding + 4)
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
		end

		local function UpdateGradientAnimation()
			local GradientOffset = (time() * 1.1) % 2 - 1
			SideLineGradient.Offset = Vector2.new(0, GradientOffset)
			for _, Gradient in ipairs(AnimatedTextGradients) do
				Gradient.Offset = Vector2.new(GradientOffset, 0)
			end
		end

		ArraylistState.AnimationConnection = RunService.RenderStepped:Connect(function()
			local EnabledModules = GetEnabledModules()
			local CurrentLayoutSignature = BuildArraylistSignature(EnabledModules)

			if CurrentLayoutSignature ~= ArraylistState.LayoutSignature then
				ArraylistState.LayoutSignature = CurrentLayoutSignature
				RebuildArraylist(EnabledModules)
			end

			UpdateGradientAnimation()
		end)
	end

	SettingsModule = TaskAPI.Categories.Other:CreateModule({
		Name = "Settings",
		Function = function(Enabled)
			if not Enabled then
				StopArraylist()
			end
		end,
		ToolTip = "Contains persistent Taskium settings."
	})

	SettingsModule:CreateToggle({
		Name = "Arraylist",
		Function = function(Enabled)
			if Enabled then
				StartArraylist()
			else
				StopArraylist()
			end
		end,
		ToolTip = "Displays enabled modules in the top-right corner."
	})

	SettingsModule:CreateSlider({
		Name = "Text Size",
		Min = 12,
		Max = 30,
		Default = 16,
		Function = function(Value)
			ArraylistState.TextSize = Value
			ArraylistState.LayoutSignature = nil
		end,
		ToolTip = "Adjusts the Arraylist text size."
	})

	ArraylistToggle = SettingsModule.Toggles and SettingsModule.Toggles.Arraylist

	local OriginalSettingsSetEnabled = SettingsModule.SetEnabled
	function SettingsModule:SetEnabled(State, Options)
		if not State then
			return
		end

		return OriginalSettingsSetEnabled(self, true, Options)
	end

	function SettingsModule:Toggle()
		if not self.Enabled then
			self:SetEnabled(true, {
				SkipConfig = true,
				SkipNotify = true
			})
		end
	end

	task.defer(function()
		if not SettingsModule or not SettingsModule.Button or not SettingsModule.Button.Parent then
			return
		end

		OriginalSettingsSetEnabled(SettingsModule, true, {
			SkipConfig = true,
			SkipNotify = true
		})

		if ArraylistToggle and type(ArraylistToggle.ApplyCurrentState) == "function" then
			ArraylistToggle:ApplyCurrentState(true)
		end
	end)
end)

local AutoPlayModule
local ShopBypassModule
local ShopTierHookState = RuntimeState.ShopBypass or {}

RuntimeState.ShopBypass = ShopTierHookState

local function SafeGetBedwarsState(BedwarsReference)
	if type(GetBedwarsState) ~= "function" then
		return {}
	end

	local Success, CurrentState = pcall(GetBedwarsState, BedwarsReference)
	if Success and type(CurrentState) == "table" then
		return CurrentState
	end

	return {}
end

local function SafeSyncTaskiumStore(BedwarsReference)
	if type(SyncTaskiumStore) ~= "function" then
		return {}
	end

	local Success, Store = pcall(SyncTaskiumStore, BedwarsReference)
	if Success and type(Store) == "table" then
		return Store
	end

	return {}
end

local function IsAutoPlayEveryoneDead(BedwarsReference)
	local CurrentState = SafeGetBedwarsState(BedwarsReference)
	local PartyState = CurrentState.Party or {}
	local PartyMembers = PartyState.members or {}
	return #PartyMembers <= 0
end

local function TryAutoPlayJoin(RandomQueue)
	local BedwarsReference = rawget(getgenv(), "bedwars") or EnsureBedwarsRuntime()
	if not BedwarsReference then
		return false
	end

	local QueueController = BedwarsReference.QueueController
	if not (QueueController and type(QueueController.joinQueue) == "function") then
		return false
	end

	local CurrentState = SafeGetBedwarsState(BedwarsReference)
	local GameState = CurrentState.Game or {}
	local PartyState = CurrentState.Party or {}
	local PartyLeader = PartyState.leader or {}
	if GameState.customMatch or PartyLeader.userId ~= LocalPlayer.UserId or (PartyState.queueState or 0) ~= 0 then
		return false
	end

	local QueueType = CreateTaskiumStore().queueType or "bedwars_test"
	if RandomQueue then
		local QueueChoices = {}
		for QueueName, QueueData in pairs(BedwarsReference.QueueMeta or {}) do
			if type(QueueData) == "table" and not QueueData.disabled and not QueueData.voiceChatOnly and not QueueData.rankCategory then
				table.insert(QueueChoices, QueueName)
			end
		end
		if #QueueChoices > 0 then
			QueueType = QueueChoices[math.random(1, #QueueChoices)]
		end
	end

	local JoinSuccess = pcall(function()
		QueueController:joinQueue(QueueType)
	end)
	return JoinSuccess
end

local function RemoveShopBypassHook(OwnerToken)
	if ShopTierHookState.Owner ~= OwnerToken then
		return
	end

	if ShopTierHookState.Shop and ShopTierHookState.OriginalGetShop then
		ShopTierHookState.Shop.getShop = ShopTierHookState.OriginalGetShop
	end

	for ShopItem, TieredValue in pairs(ShopTierHookState.StoredTiered or {}) do
		if ShopItem then
			ShopItem.tiered = TieredValue
		end
	end

	for ShopItem, NextTierValue in pairs(ShopTierHookState.StoredNextTier or {}) do
		if ShopItem then
			ShopItem.nextTier = NextTierValue
		end
	end

	ShopTierHookState.Owner = nil
	ShopTierHookState.Shop = nil
	ShopTierHookState.OriginalGetShop = nil
	ShopTierHookState.StoredTiered = nil
	ShopTierHookState.StoredNextTier = nil
end

local function ApplyShopBypassHook(OwnerToken)
	local BedwarsReference = rawget(getgenv(), "bedwars") or EnsureBedwarsRuntime()
	local Shop = EnsureBedwarsShop(BedwarsReference)
	local ShopItems = BedwarsReference and (BedwarsReference.ShopItems or (Shop and Shop.ShopItems))
	if not (Shop and type(Shop.getShop) == "function" and type(ShopItems) == "table") then
		return false
	end

	if ShopTierHookState.Owner and ShopTierHookState.Owner ~= OwnerToken then
		RemoveShopBypassHook(ShopTierHookState.Owner)
	end

	ShopTierHookState.Owner = OwnerToken
	ShopTierHookState.Shop = Shop
	ShopTierHookState.OriginalGetShop = Shop.getShop
	ShopTierHookState.StoredTiered = {}
	ShopTierHookState.StoredNextTier = {}

	for _, ShopItem in pairs(ShopItems) do
		if type(ShopItem) == "table" then
			ShopTierHookState.StoredTiered[ShopItem] = ShopItem.tiered
			ShopTierHookState.StoredNextTier[ShopItem] = ShopItem.nextTier
			ShopItem.tiered = nil
			ShopItem.nextTier = nil
		end
	end

	Shop.getShop = function(...)
		local ShopResults = { ShopTierHookState.OriginalGetShop(...) }
		local ShopEntries = ShopResults[1]
		if type(ShopEntries) == "table" then
			for _, ShopEntry in pairs(ShopEntries) do
				if type(ShopEntry) == "table" then
					ShopEntry.tiered = nil
					ShopEntry.nextTier = nil
				end
			end
		end
		return table.unpack(ShopResults)
	end

	return true
end

local BlinkModule
RunModule(function()
	local BlinkType = "Movement Only" -- packet choke type
	local BlinkAutoSend = false -- auto flush packets
	local BlinkShowServerBody = true -- show server body clone
	local BlinkAutoSendLength = 0.5 -- auto flush interval
	local BlinkOldPhysicsRate
	local BlinkOldSenderRate
	local BlinkServerPivot
	local BlinkServerBody

	local function SetBlinkNetworkRates(PhysicsRate, SenderRate)
		if type(setfflag) ~= "function" then
			return
		end
		if BlinkOldPhysicsRate ~= PhysicsRate or BlinkOldSenderRate ~= SenderRate then
			pcall(setfflag, "PhysicsSenderMaxBandwidthBps", tostring(PhysicsRate))
			pcall(setfflag, "DataSenderRate", tostring(SenderRate))
			BlinkOldPhysicsRate = PhysicsRate
			BlinkOldSenderRate = SenderRate
		end
	end

	local function ResetBlinkNetworkRates()
		SetBlinkNetworkRates(38760, 60)
		BlinkOldPhysicsRate = nil
		BlinkOldSenderRate = nil
	end

	local function CreateBlinkServerBody(Character)
		if not Character then
			return nil
		end
		local PreviousArchivable = Character.Archivable
		Character.Archivable = true
		local Success, ServerBody = pcall(function()
			return Character:Clone()
		end)
		Character.Archivable = PreviousArchivable
		if not Success or not ServerBody then
			return nil
		end

		ServerBody.Name = "TaskiumBlinkServerBody"
		for _, Descendant in ipairs(ServerBody:GetDescendants()) do
			if Descendant:IsA("BasePart") then
				Descendant.Anchored = true
				Descendant.CanCollide = false
				Descendant.CanTouch = false
				Descendant.CanQuery = false
				Descendant:SetAttribute("BlinkBaseTransparency", Descendant.Transparency)
				Descendant.Transparency = math.max(Descendant.Transparency, 0.25)
			elseif Descendant:IsA("Decal") or Descendant:IsA("Texture") then
				Descendant:SetAttribute("BlinkBaseTransparency", Descendant.Transparency)
				Descendant.Transparency = math.max(Descendant.Transparency, 0.25)
			elseif Descendant:IsA("Script") or Descendant:IsA("LocalScript") then
				Descendant:Destroy()
			elseif Descendant:IsA("Humanoid") then
				Descendant.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				Descendant.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
				Descendant.NameDisplayDistance = 0
			end
		end

		ServerBody.Parent = Workspace
		return ServerBody
	end

	local function EnsureBlinkServerBody(Character)
		if BlinkServerBody and BlinkServerBody.Parent then
			return BlinkServerBody
		end
		BlinkServerBody = CreateBlinkServerBody(Character)
		return BlinkServerBody
	end

	local function ClearBlinkServerBody()
		if BlinkServerBody and BlinkServerBody.Parent then
			BlinkServerBody:Destroy()
		end
		BlinkServerBody = nil
	end

	local function IsBlinkFirstPerson(Character)
		local Camera = Workspace.CurrentCamera
		local Head = Character and Character:FindFirstChild("Head")
		if not (Camera and Head) then
			return false
		end
		return (Camera.CFrame.Position - Head.Position).Magnitude <= 1
	end

	local function SetBlinkServerBodyVisible(ServerBody, Visible)
		if not ServerBody then
			return
		end
		for _, Descendant in ipairs(ServerBody:GetDescendants()) do
			if Descendant:IsA("BasePart") then
				local BaseTransparency = Descendant:GetAttribute("BlinkBaseTransparency")
				if type(BaseTransparency) ~= "number" then
					BaseTransparency = 0
				end
				Descendant.Transparency = Visible and math.max(BaseTransparency, 0.25) or 1
			elseif Descendant:IsA("Decal") or Descendant:IsA("Texture") then
				local BaseTransparency = Descendant:GetAttribute("BlinkBaseTransparency")
				if type(BaseTransparency) ~= "number" then
					BaseTransparency = 0
				end
				Descendant.Transparency = Visible and math.max(BaseTransparency, 0.25) or 1
			end
		end
	end

	local function UpdateBlinkServerBodyPose(CurrentCharacter, CurrentRootPart, ServerBody, DisplayPivot)
		if not (CurrentCharacter and CurrentRootPart and ServerBody and DisplayPivot) then
			return
		end
		local DisplayRootCFrame = CFrame.new(DisplayPivot.Position + (DisplayPivot.LookVector * -1.75)) * (DisplayPivot - DisplayPivot.Position)
		local SourceParts = {}
		for _, Descendant in ipairs(CurrentCharacter:GetDescendants()) do
			if Descendant:IsA("BasePart") then
				SourceParts[Descendant.Name] = Descendant
			end
		end
		for _, Descendant in ipairs(ServerBody:GetDescendants()) do
			if Descendant:IsA("BasePart") then
				local SourcePart = SourceParts[Descendant.Name]
				if SourcePart then
					local LocalOffset = CurrentRootPart.CFrame:ToObjectSpace(SourcePart.CFrame)
					Descendant.CFrame = DisplayRootCFrame * LocalOffset
				end
			end
		end
	end

	BlinkModule = TaskAPI.Categories.Other:CreateModule({
		Name = "Blink",
		Function = function(Enabled, RunId, Module)
			local Teleported = false

			local function ResetBlinkState()
				ResetBlinkNetworkRates()
				BlinkServerPivot = nil
				ClearBlinkServerBody()
			end

			if not Enabled then
				ResetBlinkState()
				return
			end

			if type(setfflag) ~= "function" then
				TaskAPI.Notification("Taskium", "Blink needs setfflag support in your executor.", 5, "Error")
				Module:SetEnabled(false, {
					SkipNotify = true
				})
				return
			end

			local Character, Humanoid, RootPart = GetCharacterState()
			if Character and Humanoid and RootPart and Humanoid.Health > 0 then
				BlinkServerPivot = Character:GetPivot()
			end

			Module:Clean(ResetBlinkState)
			Module:Clean(LocalPlayer.OnTeleport:Connect(function()
				ResetBlinkNetworkRates()
				Teleported = true
			end))
			Module:Clean(LocalPlayer.CharacterAdded:Connect(function(NewCharacter)
				local NewRootPart = NewCharacter and NewCharacter:WaitForChild("HumanoidRootPart", 5)
				if NewRootPart then
					BlinkServerPivot = NewCharacter:GetPivot()
				end
			end))

			Module:Clean(RunService.Heartbeat:Connect(function()
				if not Module:IsActive(RunId) then
					return
				end

				local CurrentCharacter, CurrentHumanoid, CurrentRootPart = GetCharacterState()
				if not (CurrentCharacter and CurrentHumanoid and CurrentRootPart and CurrentHumanoid.Health > 0) then
					return
				end

				if not BlinkShowServerBody then
					ClearBlinkServerBody()
					return
				end

				local ServerBody = EnsureBlinkServerBody(CurrentCharacter)
				if ServerBody then
					local DisplayPivot = BlinkServerPivot or CurrentCharacter:GetPivot()
					UpdateBlinkServerBodyPose(CurrentCharacter, CurrentRootPart, ServerBody, DisplayPivot)
					SetBlinkServerBodyVisible(ServerBody, not IsBlinkFirstPerson(CurrentCharacter))
				end
			end))

			task.spawn(function()
				repeat
					local PhysicsRate = 0
					local SenderRate = BlinkType == "All" and -1 or 60
					local ShouldSend = false

					if BlinkAutoSend then
						local Window = BlinkAutoSendLength + 0.1
						if Window > 0 and (tick() % Window) > BlinkAutoSendLength then
							ShouldSend = true
						end
					end

					if ShouldSend then
						PhysicsRate = 38760
						SenderRate = 60
						local CurrentCharacter, CurrentHumanoid, CurrentRootPart = GetCharacterState()
						if CurrentCharacter and CurrentHumanoid and CurrentRootPart and CurrentHumanoid.Health > 0 then
							BlinkServerPivot = CurrentCharacter:GetPivot()
						end
					end

					SetBlinkNetworkRates(PhysicsRate, SenderRate)
					task.wait(0.03)
				until not Module:IsActive(RunId) or Teleported
			end)
		end,
		ToolTip = "Chokes packets until disabled, while showing a semi-transparent server-side body."
	})

	BlinkModule:CreateDropdown({
		Name = "Type",
		List = { "Movement Only", "All" },
		Function = function(Value)
			BlinkType = Value
		end,
		ToolTip = "Movement Only chokes movement packets, All chokes remotes and movement."
	})

	BlinkModule:CreateToggle({
		Name = "Auto Send",
		Function = function(Value)
			BlinkAutoSend = Value
		end,
		ToolTip = "Automatically sends packets in intervals."
	})

	BlinkModule:CreateToggle({
		Name = "Show Server Body",
		Function = function(Value)
			BlinkShowServerBody = Value
			if not Value then
				ClearBlinkServerBody()
			end
		end,
		ToolTip = "Shows or hides the server-side Blink body."
	})

	BlinkModule:CreateSlider({
		Name = "Send Threshold",
		Min = 10,
		Max = 1000,
		Default = 500,
		Function = function(Value)
			BlinkAutoSendLength = Value / 1000
		end,
		Suffix = "ms",
		ToolTip = "How long Blink waits before briefly sending packets again."
	})
end)

RunModule(function()
	local AutoPlayRandom = false -- random queue selection

	AutoPlayModule = TaskAPI.Categories.Player:CreateModule({
		Name = "AutoPlay",
		Function = function(Enabled, RunId, Module)
			if not Enabled then
				return
			end

			local PendingJoin = false
			local NextJoinAttemptAt = 0
			local LastMatchState
			local EventsHooked = false

			local function QueueJoin()
				PendingJoin = true
				NextJoinAttemptAt = 0
			end

			local function AttemptJoin(CurrentState)
				if not PendingJoin or tick() < NextJoinAttemptAt then
					return
				end

				local PartyState = CurrentState.Party or {}
				if (PartyState.queueState or 0) ~= 0 then
					PendingJoin = false
					return
				end

				NextJoinAttemptAt = tick() + 1
				PendingJoin = not TryAutoPlayJoin(AutoPlayRandom)
			end

			local function HookAutoPlayEvents(BedwarsReference)
				if EventsHooked or not (BedwarsReference and BedwarsReference.Client and type(BedwarsReference.Client.WaitFor) == "function") then
					return
				end

				EventsHooked = true

				pcall(function()
					BedwarsReference.Client:WaitFor("EntityDeathEvent"):andThen(function(Connection)
						if not Module:IsActive(RunId) or not (Connection and type(Connection.Connect) == "function") then
							return
						end

						Module:Clean(Connection:Connect(function(DeathTable)
							local Character = LocalPlayer.Character
							local Store = SafeSyncTaskiumStore(BedwarsReference)
							if type(DeathTable) == "table"
								and DeathTable.finalKill
								and DeathTable.entityInstance == Character
								and IsAutoPlayEveryoneDead(BedwarsReference)
								and (Store.matchState or 0) ~= 2 then
								QueueJoin()
							end
						end))
					end)
				end)

				pcall(function()
					BedwarsReference.Client:WaitFor("MatchEndEvent"):andThen(function(Connection)
						if not Module:IsActive(RunId) or not (Connection and type(Connection.Connect) == "function") then
							return
						end

						Module:Clean(Connection:Connect(function()
							QueueJoin()
						end))
					end)
				end)
			end

			Module:Clean(RunService.Heartbeat:Connect(function()
				if not Module:IsActive(RunId) then
					return
				end

				local BedwarsReference = rawget(getgenv(), "bedwars") or EnsureBedwarsRuntime()
				if not BedwarsReference then
					return
				end

				HookAutoPlayEvents(BedwarsReference)

				local CurrentState = SafeGetBedwarsState(BedwarsReference)
				local Store = SafeSyncTaskiumStore(BedwarsReference)
				local MatchState = (Store and Store.matchState) or 0
				local PartyState = CurrentState.Party or {}
				local QueueState = PartyState.queueState or 0

				if LastMatchState ~= nil and LastMatchState ~= 0 and MatchState == 0 then
					QueueJoin()
				end

				if QueueState ~= 0 then
					PendingJoin = false
				end

				LastMatchState = MatchState

				AttemptJoin(CurrentState)
			end))
		end,
		ToolTip = "Automatically queues after the match ends."
	})

	AutoPlayModule:CreateToggle({
		Name = "Random",
		Function = function(Callback)
			AutoPlayRandom = Callback
		end,
		ToolTip = "Chooses a random queue instead of your current one."
	})
end)

ShopBypassModule = TaskAPI.Categories.Player:CreateModule({
	Name = "ShopBypass",
	Function = function(Enabled, RunId, Module)
		if not Enabled then
			return
		end

		local OwnerToken = "ShopBypass_" .. tostring(RunId)

		Module:Clean(function()
			RemoveShopBypassHook(OwnerToken)
		end)

		task.spawn(function()
			repeat
				task.wait(0.25)
				if not Module:IsActive(RunId) or ShopTierHookState.Owner == OwnerToken then
					break
				end
			until ApplyShopBypassHook(OwnerToken)
		end)
	end,
	ToolTip = "Lets you buy tiered shop items early."
})

local KillauraModule, CollectKillauraTargets

local function DumpRemoteName(ConstantList)
	if type(ConstantList) ~= "table" then
		return ""
	end

	local ClientIndex = nil
	for Index, Value in pairs(ConstantList) do
		if Value == "Client" then
			ClientIndex = Index
			break
		end
	end

	if not ClientIndex then
		return ""
	end

	local RemoteName = ConstantList[ClientIndex + 1]
	return type(RemoteName) == "string" and RemoteName or ""
end

local function ResolveAttackRemoteName(KnitClient, ExistingRemotes)
	local SwordController = KnitClient
		and KnitClient.Controllers
		and KnitClient.Controllers.SwordController

	local SendServerRequest = SwordController and SwordController.sendServerRequest
	if type(SendServerRequest) == "string" and SendServerRequest ~= "" then
		return SendServerRequest
	end

	if type(SendServerRequest) == "function" and debug and debug.getconstants then
		local ConstantSuccess, Constants = pcall(debug.getconstants, SendServerRequest)
		if ConstantSuccess then
			local RemoteName = DumpRemoteName(Constants)
			if RemoteName ~= "" then
				return RemoteName
			end
		end
	end

	if type(ExistingRemotes) == "table" and type(ExistingRemotes.AttackEntity) == "string" and ExistingRemotes.AttackEntity ~= "" then
		return ExistingRemotes.AttackEntity
	end

	return nil
end

local function ResolveGroundHitRemoteName(KnitClient, ExistingRemotes)
	local FallDamageController = KnitClient
		and KnitClient.Controllers
		and KnitClient.Controllers.FallDamageController

	local KnitStart = FallDamageController and FallDamageController.KnitStart
	if type(KnitStart) == "string" and KnitStart ~= "" then
		return KnitStart
	end

	if type(KnitStart) == "function" and debug and debug.getconstants then
		local ConstantSuccess, Constants = pcall(debug.getconstants, KnitStart)
		if ConstantSuccess then
			local RemoteName = DumpRemoteName(Constants)
			if RemoteName ~= "" then
				return RemoteName
			end
		end
	end

	if type(ExistingRemotes) == "table" and type(ExistingRemotes.GroundHit) == "string" and ExistingRemotes.GroundHit ~= "" then
		return ExistingRemotes.GroundHit
	end

	return nil
end

local function IsSameTeam(PlayerOne, PlayerTwo)
	if not (PlayerOne and PlayerTwo) then
		return false
	end

	if PlayerOne.Team ~= nil and PlayerTwo.Team ~= nil and PlayerOne.Team == PlayerTwo.Team then
		return true
	end

	local TeamAttributeOne = PlayerOne:GetAttribute("Team")
	local TeamAttributeTwo = PlayerTwo:GetAttribute("Team")
	if TeamAttributeOne ~= nil and TeamAttributeTwo ~= nil and TeamAttributeOne == TeamAttributeTwo then
		return true
	end

	return false
end

CreateTaskiumStore = function()
	local ExistingStore = rawget(getgenv(), "store")
	if type(ExistingStore) == "table" then
		ExistingStore.attackReach = ExistingStore.attackReach or 0
		ExistingStore.attackReachUpdate = ExistingStore.attackReachUpdate or tick()
		ExistingStore.hand = ExistingStore.hand or {}
		ExistingStore.inventory = ExistingStore.inventory or {
			inventory = {
				items = {},
				armor = {}
			},
			hotbar = {}
		}
		ExistingStore.inventories = ExistingStore.inventories or {}
		ExistingStore.matchState = ExistingStore.matchState or 0
		ExistingStore.queueType = ExistingStore.queueType or "bedwars_test"
		ExistingStore.shopLoaded = not not ExistingStore.shopLoaded
		ExistingStore.tools = ExistingStore.tools or {}
		return ExistingStore
	end

	local NewStore = {
		attackReach = 0,
		attackReachUpdate = tick(),
		hand = {},
		inventory = {
			inventory = {
				items = {},
				armor = {}
			},
			hotbar = {}
		},
		inventories = {},
		matchState = 0,
		queueType = "bedwars_test",
		shopLoaded = false,
		tools = {}
	}
	getgenv().store = NewStore
	return NewStore
end

local function GetBestSwordFromStore(BedwarsReference, StoreTable)
	local BestSword, BestDamage = nil, 0
	local InventoryItems = StoreTable
		and StoreTable.inventory
		and StoreTable.inventory.inventory
		and StoreTable.inventory.inventory.items
		or {}

	for _, Item in pairs(InventoryItems) do
		local ItemMeta = BedwarsReference.ItemMeta[Item.itemType]
		local SwordMeta = ItemMeta and ItemMeta.sword
		local SwordDamage = SwordMeta and (SwordMeta.damage or 0) or 0
		if SwordDamage > BestDamage then
			BestSword = Item
			BestDamage = SwordDamage
		end
	end

	return BestSword
end

SyncTaskiumStore = function(BedwarsReference)
	local TaskiumStore = CreateTaskiumStore()
	local StoreController = BedwarsReference and BedwarsReference.Store
	if not (StoreController and type(StoreController.getState) == "function") then
		return TaskiumStore
	end

	local function UpdateStore(NewState, OldState)
		NewState = type(NewState) == "table" and NewState or {}
		OldState = type(OldState) == "table" and OldState or {}

		local NewGame = NewState.Game or {}
		local OldGame = OldState.Game or {}
		if NewGame ~= OldGame then
			TaskiumStore.matchState = NewGame.matchState or 0
			TaskiumStore.queueType = NewGame.queueType or "bedwars_test"
		end

		local NewBedwarsState = NewState.Bedwars or {}
		local OldBedwarsState = OldState.Bedwars or {}
		if NewBedwarsState ~= OldBedwarsState then
			TaskiumStore.equippedKit = NewBedwarsState.kit ~= "none" and NewBedwarsState.kit or ""
		end

		local NewInventoryState = NewState.Inventory or {}
		local OldInventoryState = OldState.Inventory or {}
		if NewInventoryState ~= OldInventoryState then
			local NewObservedInventory = NewInventoryState.observedInventory or {
				inventory = {
					items = {},
					armor = {}
				},
				hotbar = {}
			}
			local OldObservedInventory = OldInventoryState.observedInventory or {
				inventory = {
					items = {},
					armor = {}
				},
				hotbar = {}
			}

			TaskiumStore.inventory = NewObservedInventory

			if NewObservedInventory.inventory.items ~= OldObservedInventory.inventory.items then
				TaskiumStore.tools.sword = GetBestSwordFromStore(BedwarsReference, TaskiumStore)
			end

			if NewObservedInventory.inventory.hand ~= OldObservedInventory.inventory.hand then
				local CurrentHand = NewObservedInventory.inventory.hand
				local ToolType = nil
				if CurrentHand then
					local HandData = BedwarsReference.ItemMeta[CurrentHand.itemType]
					if HandData then
						ToolType = HandData.sword and "sword"
							or HandData.block and "block"
							or (CurrentHand.itemType:find("bow") or CurrentHand.itemType:find("headhunter")) and "bow"
							or nil
					end
				end

				TaskiumStore.hand = {
					tool = CurrentHand and CurrentHand.tool,
					amount = CurrentHand and CurrentHand.amount or 0,
					toolType = ToolType,
					itemType = CurrentHand and CurrentHand.itemType or nil
				}
			end
		end
	end

	local ExistingConnection = rawget(getgenv(), "TaskiumStoreConnection")
	local ExistingStoreObject = rawget(getgenv(), "TaskiumStoreController")
	if ExistingConnection and ExistingStoreObject ~= StoreController then
		pcall(function()
			ExistingConnection:Disconnect()
		end)
		getgenv().TaskiumStoreConnection = nil
		getgenv().TaskiumStoreController = nil
	end

	if not rawget(getgenv(), "TaskiumStoreConnection") and StoreController.changed then
		local Connection = StoreController.changed:connect(UpdateStore)
		getgenv().TaskiumStoreConnection = Connection
		getgenv().TaskiumStoreController = StoreController
	end

	local StateSuccess, CurrentState = pcall(function()
		return StoreController:getState()
	end)
	if StateSuccess and type(CurrentState) == "table" then
		UpdateStore(CurrentState, {})
	end

	return TaskiumStore
end

EnsureBedwarsRuntime = function()
	local ExistingBedwars = rawget(getgenv(), "bedwars")
	local ExistingRemotes = rawget(getgenv(), "remotes")

	if not IsLikelyBedwarsPlace() then
		if ExistingBedwars then
			return ExistingBedwars, ExistingRemotes or {}
		end
		return nil, nil
	end

	local KnitClient = nil

	local function TryResolveKnitClient()
		local KnitSuccess, KnitResult = pcall(function()
			return require(ReplicatedStorage.rbxts_include.node_modules["@easy-games"].knit.src).KnitClient
		end)
		if KnitSuccess and KnitResult then
			return KnitResult
		end

		local PlayerScripts = LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts")
		local KnitModule = PlayerScripts and PlayerScripts:FindFirstChild("TS") and PlayerScripts.TS:FindFirstChild("knit")
		if KnitModule and debug and debug.getupvalue then
			local FallbackSuccess, FallbackKnit = pcall(function()
				return debug.getupvalue(require(KnitModule).setup, 9)
			end)
			if FallbackSuccess and FallbackKnit then
				return FallbackKnit
			end
		end

		return nil
	end

	KnitClient = TryResolveKnitClient()
	if KnitClient then
		if debug and debug.getupvalue and KnitClient.Start then
			local StartSuccess, StartUpvalue = pcall(debug.getupvalue, KnitClient.Start, 1)
			if StartSuccess and not StartUpvalue then
				for _ = 1, 100 do
					local RetrySuccess, RetryUpvalue = pcall(debug.getupvalue, KnitClient.Start, 1)
					if RetrySuccess and RetryUpvalue then
						break
					end
					task.wait()
				end
			end
		end

		for _ = 1, 50 do
			if KnitClient.Controllers and next(KnitClient.Controllers) ~= nil then
				break
			end
			task.wait(0.1)
		end
	end

	if not KnitClient or not KnitClient.Controllers or next(KnitClient.Controllers) == nil then
		if ExistingBedwars then
			local RemoteTable = ExistingRemotes or {}
			if not RemoteTable.GroundHit then
				RemoteTable.GroundHit = ResolveGroundHitRemoteName({
					Controllers = {
						FallDamageController = ExistingBedwars.FallDamageController
					}
				}, ExistingRemotes)
			end
			getgenv().bedwars = ExistingBedwars
			getgenv().remotes = RemoteTable
			return ExistingBedwars, RemoteTable
		end
		return nil, nil
	end

	local ClientSuccess, ClientRemoteLibrary = pcall(function()
		return require(ReplicatedStorage.TS.remotes).default.Client
	end)
	if not ClientSuccess or not ClientRemoteLibrary then
		return nil, nil
	end

	local FlameworkSuccess, Flamework = pcall(function()
		return require(ReplicatedStorage.rbxts_include.node_modules["@flamework"].core.out).Flamework
	end)
	local AppControllerSuccess, AppController = pcall(function()
		return require(ReplicatedStorage.rbxts_include.node_modules["@easy-games"]["game-core"].out.client.controllers["app-controller"]).AppController
	end)
	local BlockControllerSuccess, BlockController = pcall(function()
		return require(ReplicatedStorage.rbxts_include.node_modules["@easy-games"]["block-engine"].out).BlockEngine
	end)
	local BlockEngineSuccess, BlockEngine = pcall(function()
		return require(LocalPlayer.PlayerScripts.TS.lib["block-engine"]["client-block-engine"]).ClientBlockEngine
	end)
	local BlockPlacerSuccess, BlockPlacer = pcall(function()
		return require(ReplicatedStorage.rbxts_include.node_modules["@easy-games"]["block-engine"].out.client.placement["block-placer"]).BlockPlacer
	end)
	local BlockSelectorSuccess, BlockSelector = pcall(function()
		return require(ReplicatedStorage.rbxts_include.node_modules["@easy-games"]["block-engine"].out.client.select["block-selector"]).BlockSelector
	end)
	local CombatConstantSuccess, CombatConstant = pcall(function()
		return require(ReplicatedStorage.TS.combat["combat-constant"]).CombatConstant
	end)
	local UILayersSuccess, UILayers = pcall(function()
		return require(ReplicatedStorage.rbxts_include.node_modules["@easy-games"]["game-core"].out).UILayers
	end)
	local ItemMetaSuccess, ItemMeta = pcall(function()
		return require(ReplicatedStorage.TS.item["item-meta"]).items
	end)
	local StoreSuccess, StoreController = pcall(function()
		return require(LocalPlayer.PlayerScripts.TS.ui.store).ClientStore
	end)
	local QueryUtilSuccess, QueryUtil = pcall(function()
		return require(ReplicatedStorage.rbxts_include.node_modules["@easy-games"]["game-core"].out).GameQueryUtil
	end)
	local QueueMetaSuccess, QueueMeta = pcall(function()
		return require(ReplicatedStorage.TS.game["queue-meta"]).QueueMeta
	end)
	local ProjectileMetaSuccess, ProjectileMeta = pcall(function()
		return require(ReplicatedStorage.TS.projectile["projectile-meta"]).ProjectileMeta
	end)
	local ClientDamageBlockSuccess, ClientDamageBlock = pcall(function()
		return require(ReplicatedStorage.rbxts_include.node_modules["@easy-games"]["block-engine"].out.shared.remotes).BlockEngineRemotes.Client
	end)
	local AnimationUtilSuccess, AnimationUtil = pcall(function()
		return require(ReplicatedStorage.rbxts_include.node_modules["@easy-games"]["game-core"].out.shared.util["animation-util"]).AnimationUtil
	end)
	local SoundManagerSuccess, SoundManager = pcall(function()
		return require(ReplicatedStorage.rbxts_include.node_modules["@easy-games"]["game-core"].out).SoundManager
	end)
	local InventoryUtilSuccess, InventoryUtil = pcall(function()
		return require(ReplicatedStorage.TS.inventory["inventory-util"]).InventoryUtil
	end)
	local BowConstantsSuccess, BowConstantsTable = pcall(function()
		return debug and debug.getupvalue and debug.getupvalue(KnitClient.Controllers.ProjectileController.enableBeam, 8) or { RelX = 0, RelY = 0, RelZ = 0 }
	end)
	local DamageIndicatorSuccess, DamageIndicator = pcall(function()
		return KnitClient.Controllers.DamageIndicatorController.spawnDamageIndicator
	end)

	local BedwarsReference = ExistingBedwars or {
		Client = ClientRemoteLibrary,
		AppController = AppControllerSuccess and AppController or nil,
		BlockController = BlockControllerSuccess and BlockController or nil,
		BlockEngine = BlockEngineSuccess and BlockEngine or nil,
		BlockPlacer = BlockPlacerSuccess and BlockPlacer or nil,
		BlockSelector = BlockSelectorSuccess and BlockSelector or nil,
		BowConstantsTable = BowConstantsSuccess and BowConstantsTable or { RelX = 0, RelY = 0, RelZ = 0 },
		ClientDamageBlock = ClientDamageBlockSuccess and ClientDamageBlock or nil,
		CombatConstant = CombatConstantSuccess and CombatConstant or nil,
		DamageIndicator = DamageIndicatorSuccess and DamageIndicator or nil,
		Flamework = FlameworkSuccess and Flamework or nil,
		InventoryUtil = InventoryUtilSuccess and InventoryUtil or nil,
		ItemMeta = ItemMetaSuccess and ItemMeta or {},
		Knit = KnitClient,
		ProjectileMeta = ProjectileMetaSuccess and ProjectileMeta or nil,
		QueueMeta = QueueMetaSuccess and QueueMeta or {},
		QueryUtil = QueryUtilSuccess and QueryUtil or nil,
		AnimationUtil = AnimationUtilSuccess and AnimationUtil or nil,
		SoundManager = SoundManagerSuccess and SoundManager or nil,
		Store = StoreSuccess and StoreController or nil,
		UILayers = UILayersSuccess and UILayers or nil
	}
	BedwarsReference.Client = BedwarsReference.Client or ClientRemoteLibrary
	BedwarsReference.AppController = BedwarsReference.AppController or (AppControllerSuccess and AppController or nil)
	BedwarsReference.BlockController = BedwarsReference.BlockController or (BlockControllerSuccess and BlockController or nil)
	BedwarsReference.BlockEngine = BedwarsReference.BlockEngine or (BlockEngineSuccess and BlockEngine or nil)
	BedwarsReference.BlockPlacer = BedwarsReference.BlockPlacer or (BlockPlacerSuccess and BlockPlacer or nil)
	BedwarsReference.BlockSelector = BedwarsReference.BlockSelector or (BlockSelectorSuccess and BlockSelector or nil)
	BedwarsReference.BowConstantsTable = BedwarsReference.BowConstantsTable or (BowConstantsSuccess and BowConstantsTable or { RelX = 0, RelY = 0, RelZ = 0 })
	BedwarsReference.ClientDamageBlock = BedwarsReference.ClientDamageBlock or (ClientDamageBlockSuccess and ClientDamageBlock or nil)
	BedwarsReference.CombatConstant = BedwarsReference.CombatConstant or (CombatConstantSuccess and CombatConstant or nil)
	BedwarsReference.DamageIndicator = BedwarsReference.DamageIndicator or (DamageIndicatorSuccess and DamageIndicator or nil)
	BedwarsReference.Flamework = BedwarsReference.Flamework or (FlameworkSuccess and Flamework or nil)
	BedwarsReference.InventoryUtil = BedwarsReference.InventoryUtil or (InventoryUtilSuccess and InventoryUtil or nil)
	BedwarsReference.ItemMeta = next(BedwarsReference.ItemMeta or {}) and BedwarsReference.ItemMeta or (ItemMetaSuccess and ItemMeta or {})
	BedwarsReference.Knit = BedwarsReference.Knit or KnitClient
	BedwarsReference.ProjectileMeta = BedwarsReference.ProjectileMeta or (ProjectileMetaSuccess and ProjectileMeta or nil)
	BedwarsReference.QueueMeta = BedwarsReference.QueueMeta or (QueueMetaSuccess and QueueMeta or {})
	BedwarsReference.QueryUtil = BedwarsReference.QueryUtil or (QueryUtilSuccess and QueryUtil or nil)
	BedwarsReference.AnimationUtil = BedwarsReference.AnimationUtil or (AnimationUtilSuccess and AnimationUtil or nil)
	BedwarsReference.SoundManager = BedwarsReference.SoundManager or (SoundManagerSuccess and SoundManager or nil)
	BedwarsReference.Store = BedwarsReference.Store or (StoreSuccess and StoreController or nil)
	BedwarsReference.UILayers = BedwarsReference.UILayers or (UILayersSuccess and UILayers or nil)

	if getmetatable(BedwarsReference) == nil then
		setmetatable(BedwarsReference, {
			__index = function(Self, Index)
				local Controller = KnitClient.Controllers and KnitClient.Controllers[Index]
				if Controller ~= nil then
					rawset(Self, Index, Controller)
					return Controller
				end
				return nil
			end
		})
	end

	local RemoteTable = ExistingRemotes or {}
	RemoteTable.AttackEntity = ResolveAttackRemoteName(KnitClient, ExistingRemotes)
	RemoteTable.GroundHit = ResolveGroundHitRemoteName(KnitClient, ExistingRemotes)

	getgenv().bedwars = BedwarsReference
	getgenv().remotes = RemoteTable
	local TaskiumStore = SyncTaskiumStore(BedwarsReference)
	if TaskiumStore and BedwarsReference.BlockPlacer and BedwarsReference.BlockEngine and (not TaskiumStore.blockPlacer or type(TaskiumStore.blockPlacer.placeBlock) ~= "function") then
		local BlockPlacerSuccessResult, BlockPlacerObject = pcall(function()
			return BedwarsReference.BlockPlacer.new(BedwarsReference.BlockEngine, "wool_white")
		end)
		if BlockPlacerSuccessResult then
			TaskiumStore.blockPlacer = BlockPlacerObject
		end
	end

	if TaskiumStore and BedwarsReference.BlockController and type(BedwarsReference.BlockController.getBlockPosition) == "function" then
		BedwarsReference.placeBlock = function(Position, ItemType)
			local CurrentStore = CreateTaskiumStore()
			if (not CurrentStore.blockPlacer or type(CurrentStore.blockPlacer.placeBlock) ~= "function")
				and BedwarsReference.BlockPlacer
				and BedwarsReference.BlockEngine then
				local BlockPlacerSuccessResult, BlockPlacerObject = pcall(function()
					return BedwarsReference.BlockPlacer.new(BedwarsReference.BlockEngine, ItemType or "wool_white")
				end)
				if BlockPlacerSuccessResult then
					CurrentStore.blockPlacer = BlockPlacerObject
				end
			end

			if not (CurrentStore.blockPlacer and type(CurrentStore.blockPlacer.placeBlock) == "function") then
				return nil
			end

			local GetItemFunction = rawget(getgenv(), "getItem")
			if type(GetItemFunction) == "function" then
				local ItemSuccess, InventoryItem = pcall(GetItemFunction, ItemType)
				if not (ItemSuccess and InventoryItem) then
					return nil
				end
			end

			CurrentStore.blockPlacer.blockType = ItemType
			return CurrentStore.blockPlacer:placeBlock(BedwarsReference.BlockController:getBlockPosition(Position))
		end
	end

	if type(BedwarsReference.breakBlock) ~= "function"
		and BedwarsReference.BlockController
		and BedwarsReference.ClientDamageBlock
		and type(BedwarsReference.ClientDamageBlock.Get) == "function" then
		BedwarsReference.breakBlock = function(Block, Effects, Animate, CustomHealthbar, InstantBreak, Legit, Sorting, Angle)
			local _, Humanoid, RootPart = GetCharacterState()
			if not (Block and Humanoid and RootPart and Humanoid.Health > 0) then
				return nil
			end

			if LocalPlayer:GetAttribute("DenyBlockBreak") then
				return nil
			end

			local HandlerRegistry = type(BedwarsReference.BlockController.getHandlerRegistry) == "function" and BedwarsReference.BlockController:getHandlerRegistry()
			local Handler = HandlerRegistry and type(HandlerRegistry.getHandler) == "function" and HandlerRegistry:getHandler(Block.Name)
			local Positions = (Handler and type(Handler.getContainedPositions) == "function" and Handler:getContainedPositions(Block)) or { Block.Position / 3 }
			local BestCost = math.huge
			local BestPosition = nil
			local BestTarget = nil
			local BestPath = nil
			local BestMagnitude = math.huge

			for _, GridPosition in ipairs(Positions) do
				local WorldPosition = type(BedwarsReference.BlockController.getWorldPosition) == "function"
					and BedwarsReference.BlockController:getWorldPosition(GridPosition)
					or (GridPosition * 3)
				local PathPosition, PathCost, PathMap = CalculateBreakerPath(BedwarsReference, Block, WorldPosition, Sorting or "Health", Angle or 360, RootPart)
				local PathMagnitude = PathPosition and (RootPart.Position - PathPosition).Magnitude or math.huge
				if PathPosition and (PathCost < BestCost or (PathCost == BestCost and PathMagnitude < BestMagnitude)) then
					BestCost = PathCost
					BestPosition = PathPosition
					BestTarget = WorldPosition
					BestPath = PathMap
				end
			end

			local HitPosition = BestPosition

			if not HitPosition then
				return nil
			end

			if (RootPart.Position - HitPosition).Magnitude > 30 then
				return nil
			end

			local PlacedBlock, ActualBlockPosition = GetPlacedBlockAt(BedwarsReference, HitPosition)
			if not (PlacedBlock and ActualBlockPosition) then
				return nil
			end

			if (workspace:GetServerTimeNow() - ((BedwarsReference.SwordController and BedwarsReference.SwordController.lastAttack) or 0)) > 0.4 then
				local BreakMeta = BedwarsReference.ItemMeta[PlacedBlock.Name]
				local BreakType = BreakMeta and BreakMeta.block and BreakMeta.block.breakType
				local Tool = BreakType and TaskiumStore and TaskiumStore.tools and TaskiumStore.tools[BreakType]
				if Tool and Tool.tool then
					local SwitchItemFunction = rawget(getgenv(), "switchItem")
					if Legit then
						local GetHotbarFunction = rawget(getgenv(), "getHotbar")
						local HotbarSwitchFunction = rawget(getgenv(), "hotbarSwitch")
						local Hotbar = type(GetHotbarFunction) == "function" and GetHotbarFunction(Tool.tool) or nil
						if Hotbar and type(HotbarSwitchFunction) == "function" then
							pcall(HotbarSwitchFunction, Hotbar)
						end
					elseif type(SwitchItemFunction) == "function" then
						pcall(SwitchItemFunction, Tool.tool, 0)
					end
				end
			end

			local DamageRemote = BedwarsReference.ClientDamageBlock:Get("DamageBlock")
			if not (DamageRemote and type(DamageRemote.CallServerAsync) == "function") then
				return nil
			end

			local DamageCall = DamageRemote:CallServerAsync({
				blockRef = { blockPosition = ActualBlockPosition },
				hitPosition = HitPosition,
				hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
			})

			if DamageCall and type(DamageCall.andThen) == "function" then
				DamageCall:andThen(function(Result)
					if Result and Result ~= "cancelled" and Animate then
						local AnimationController = type(BedwarsReference.BlockController.getAnimationController) == "function" and BedwarsReference.BlockController:getAnimationController()
						local AssetId = AnimationController and type(AnimationController.getAssetId) == "function" and AnimationController:getAssetId(1)
						local PlayedAnimation = BedwarsReference.AnimationUtil and AssetId and BedwarsReference.AnimationUtil:playAnimation(LocalPlayer, AssetId)
						if BedwarsReference.ViewmodelController and type(BedwarsReference.ViewmodelController.playAnimation) == "function" then
							pcall(function()
								BedwarsReference.ViewmodelController:playAnimation(15)
							end)
						end
						if PlayedAnimation then
							task.delay(0.3, function()
								pcall(function()
									PlayedAnimation:Stop()
									PlayedAnimation:Destroy()
								end)
							end)
						end
					end
				end)
			end

			if Effects then
				return HitPosition, BestPath, BestTarget
			end

			return HitPosition
		end
	end

	return BedwarsReference, RemoteTable
end

GetBedwarsState = function(BedwarsReference)
	local StoreController = BedwarsReference and BedwarsReference.Store
	if not (StoreController and type(StoreController.getState) == "function") then
		return {}
	end

	local StateSuccess, CurrentState = pcall(function()
		return StoreController:getState()
	end)
	if StateSuccess and type(CurrentState) == "table" then
		return CurrentState
	end

	return {}
end

EnsureBedwarsShop = function(BedwarsReference)
	if not BedwarsReference then
		return nil
	end

	local TaskiumStore = CreateTaskiumStore()

	if BedwarsReference.Shop and (type(BedwarsReference.Shop.ShopItems) == "table" or type(BedwarsReference.ShopItems) == "table") then
		TaskiumStore.shopLoaded = true
		return BedwarsReference.Shop
	end

	local ShopSuccess, ShopModule = pcall(function()
		return require(ReplicatedStorage.TS.games.bedwars.shop["bedwars-shop"]).BedwarsShop
	end)
	if not ShopSuccess or not ShopModule then
		return nil
	end

	BedwarsReference.Shop = BedwarsReference.Shop or ShopModule
	if type(ShopModule.getShopItem) == "function" then
		pcall(function()
			ShopModule.getShopItem("iron_sword", LocalPlayer)
		end)
	end
	if not BedwarsReference.ShopItems then
		if type(BedwarsReference.Shop.ShopItems) == "table" then
			BedwarsReference.ShopItems = BedwarsReference.Shop.ShopItems
		elseif type(ShopModule.ShopItems) == "table" then
			BedwarsReference.ShopItems = ShopModule.ShopItems
		elseif debug and debug.getupvalue and type(ShopModule.getShopItem) == "function" then
			pcall(function()
				BedwarsReference.ShopItems = debug.getupvalue(debug.getupvalue(ShopModule.getShopItem, 1), 2)
			end)
		end
	end

	TaskiumStore.shopLoaded = type(BedwarsReference.ShopItems) == "table"

	return BedwarsReference.Shop
end

RunModule(function()
	local KillauraHitFixEnabled = true -- use attack remote hitfix
	local KillauraHitFixClient -- current hooked client
	local KillauraSwingRange = 18 -- target search range
	local KillauraAttackRange = 18 -- actual hit range
	local KillauraUpdateRate = 120 -- loop rate
	local KillauraAttackMode = "Switch" -- attack mode
	local KillauraMaxTargets = 5 -- multi attack cap
	local KillauraSwingInterval = 0.11 -- local swing effect rate
	local KillauraFaceTargetEnabled = false -- turn toward target
	local KillauraKnockbackRedirectEnabled = false -- enable redirect
	local KillauraKnockbackRedirectDistance = 18 -- redirect trigger distance
	local KillauraKnockbackRedirectOffset = 4 -- side offset
	local KillauraKnockbackRedirectCooldown = 0.5 -- redirect cooldown
	local KillauraKnockbackRedirectTweenSpeed = 5 -- redirect tween speed
	local KillauraAnimationEnabled = false -- custom animation toggle
	local KillauraAnimationMode = "Normal" -- selected animation
	local KillauraAnimationSpeed = 1 -- animation rate
	local KillauraAnimationResetTween -- wrist reset tween
	local KillauraCurrentAnimationTween -- active swing tween
	local KillauraBaseC0 -- base wrist pose
	local KillauraAnimationToken = 0 -- animation loop token
	local KillauraAnimationBusy = false -- animation active flag
	local KillauraHookState = RuntimeState.KillauraHitFix or {}
	local KillauraRedirectState = RuntimeState.KillauraRedirect or {
		NextSide = 1,
		LastTarget = nil,
		LastTeleportAt = 0,
		ActiveTween = nil,
		TargetAxis = nil,
		Raycast = RaycastParams.new()
	}
	RuntimeState.KillauraHitFix = KillauraHookState
	RuntimeState.KillauraRedirect = KillauraRedirectState
	KillauraRedirectState.NextSide = KillauraRedirectState.NextSide or 1
	KillauraRedirectState.LastTeleportAt = KillauraRedirectState.LastTeleportAt or 0
	if KillauraRedirectState.Raycast == nil then
		KillauraRedirectState.Raycast = RaycastParams.new()
	end
	KillauraRedirectState.Raycast.RespectCanCollide = true

	local KillauraAnimations = {
		Default = {
			{ CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.12 },
			{ CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.08 },
			{ CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.04 },
			{ CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.04 },
			{ CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.05 },

			{ CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.12 },
			{ CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.08 },
			{ CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.04 },
			{ CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.04 },
			{ CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.05 },

			{ CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.12 },
			{ CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.08 },
			{ CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.04 },
			{ CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.04 },
			{ CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.05 }
		},
		Normal = {
			{ CFrame = CFrame.new(-0.17, -0.14, -0.12) * CFrame.Angles(math.rad(-53), math.rad(50), math.rad(-64)), Time = 0.1 },
			{ CFrame = CFrame.new(-0.55, -0.59, -0.1) * CFrame.Angles(math.rad(-161), math.rad(54), math.rad(-6)), Time = 0.08 },
			{ CFrame = CFrame.new(-0.62, -0.68, -0.07) * CFrame.Angles(math.rad(-167), math.rad(47), math.rad(-1)), Time = 0.03 },
			{ CFrame = CFrame.new(-0.56, -0.86, 0.23) * CFrame.Angles(math.rad(-167), math.rad(49), math.rad(-1)), Time = 0.03 }
		},
		Random = {},
		["Horizontal Spin"] = {
			{ CFrame = CFrame.Angles(math.rad(-10), math.rad(-90), math.rad(-80)), Time = 0.12 },
			{ CFrame = CFrame.Angles(math.rad(-10), math.rad(180), math.rad(-80)), Time = 0.12 },
			{ CFrame = CFrame.Angles(math.rad(-10), math.rad(90), math.rad(-80)), Time = 0.12 },
			{ CFrame = CFrame.Angles(math.rad(-10), 0, math.rad(-80)), Time = 0.12 }
		},
		["Vertical Spin"] = {
			{ CFrame = CFrame.Angles(math.rad(-90), 0, math.rad(15)), Time = 0.12 },
			{ CFrame = CFrame.Angles(math.rad(180), 0, math.rad(15)), Time = 0.12 },
			{ CFrame = CFrame.Angles(math.rad(90), 0, math.rad(15)), Time = 0.12 },
			{ CFrame = CFrame.Angles(0, 0, math.rad(15)), Time = 0.12 }
		},
		Exhibition = {
			{ CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.1 },
			{ CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.2 }
		},
		["Exhibition Old"] = {
			{ CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.15 },
			{ CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.05 },
			{ CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.1 },
			{ CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.05 },
			{ CFrame = CFrame.new(0.63, -0.1, 1.37) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.15 }
		},
	}

	local function GetKillauraWrist()
		local Camera = Workspace.CurrentCamera
		local Viewmodel = Camera and Camera:FindFirstChild("Viewmodel")
		local RightHand = Viewmodel and Viewmodel:FindFirstChild("RightHand")
		return RightHand and RightHand:FindFirstChild("RightWrist")
	end

	local function ResetKillauraAnimation(Duration)
		local Wrist = GetKillauraWrist()
		if not Wrist then
			return
		end

		KillauraBaseC0 = KillauraBaseC0 or Wrist.C0
		if not KillauraBaseC0 then
			return
		end

		if KillauraCurrentAnimationTween then
			pcall(function()
				KillauraCurrentAnimationTween:Cancel()
			end)
			KillauraCurrentAnimationTween = nil
		end

		if KillauraAnimationResetTween then
			pcall(function()
				KillauraAnimationResetTween:Cancel()
			end)
		end

		KillauraAnimationResetTween = TweenService:Create(Wrist, TweenInfo.new(Duration or 0.15, Enum.EasingStyle.Exponential), {
			C0 = KillauraBaseC0
		})
		KillauraAnimationResetTween:Play()
	end

	local function GetAttackRemote()
	local BedwarsReference, RemoteTable = EnsureBedwarsRuntime()
	if not (BedwarsReference and BedwarsReference.Client and RemoteTable and RemoteTable.AttackEntity) then
		return nil
	end

	local Success, RemoteObject = pcall(function()
		return BedwarsReference.Client:Get(RemoteTable.AttackEntity)
	end)
	if not Success or not RemoteObject then
		return nil
	end

	if type(RemoteObject.SendToServer) == "function" then
		return {
			instance = RemoteObject.instance,
			FireServer = function(_, ...)
				return RemoteObject:SendToServer(...)
			end
		}
	end

	local RemoteInstance = RemoteObject.instance
	if RemoteInstance and type(RemoteInstance.FireServer) == "function" then
		return RemoteInstance
	end

	return nil
end

local function GetSwordData()
	local Store = CreateTaskiumStore()
	local BedwarsReference = EnsureBedwarsRuntime()
	if not (Store and BedwarsReference and BedwarsReference.ItemMeta) then
		return nil
	end

	local SwordData = Store.tools and Store.tools.sword or nil
	if Store.hand and Store.hand.tool and Store.hand.toolType == "sword" then
		SwordData = Store.hand
	end

	if not (SwordData and SwordData.tool) then
		local Character = LocalPlayer and LocalPlayer.Character
		local Backpack = LocalPlayer and LocalPlayer:FindFirstChildOfClass("Backpack")
		local CandidateTools = {}

		if Character then
			for _, Item in ipairs(Character:GetChildren()) do
				if Item:IsA("Tool") then
					table.insert(CandidateTools, Item)
				end
			end
		end

		if Backpack then
			for _, Item in ipairs(Backpack:GetChildren()) do
				if Item:IsA("Tool") then
					table.insert(CandidateTools, Item)
				end
			end
		end

		local BestTool = nil
		local BestMeta = nil
		local BestDamage = -math.huge
		for _, Tool in ipairs(CandidateTools) do
			local Meta = BedwarsReference.ItemMeta[Tool.Name]
			local SwordMeta = Meta and Meta.sword
			local Damage = SwordMeta and (SwordMeta.damage or 0) or nil
			if Damage and Damage > BestDamage then
				BestTool = Tool
				BestMeta = Meta
				BestDamage = Damage
			end
		end

		if BestTool and BestMeta then
			return {
				tool = BestTool,
				toolType = "sword"
			}, BestMeta
		end

		return nil
	end

	local ToolName = SwordData.tool.Name
	local Meta = BedwarsReference.ItemMeta[ToolName] or (SwordData.itemType and BedwarsReference.ItemMeta[SwordData.itemType])
	if not (Meta and Meta.sword) then
		return nil
	end

	return SwordData, Meta
end

CollectKillauraTargets = function(LocalRootPart, MaxDistance)
	local Targets = {}
	local LocalFacing = LocalRootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	local AddedCharacters = {}
	local RangeLimit = MaxDistance or KillauraSwingRange

	local function AddTarget(Character, Player)
		if not Character or AddedCharacters[Character] or Character == LocalPlayer.Character then
			return
		end

		if Player then
			if Player == LocalPlayer or IsSameTeam(LocalPlayer, Player) then
				return
			end
		else
			if CollectionService:HasTag(Character, "inventory-entity")
				and not CollectionService:HasTag(Character, "Monster")
				and not CollectionService:HasTag(Character, "trainingRoomDummy") then
				return
			end

			if CollectionService:HasTag(Character, "Drone") then
				local DronePlayerUserId = Character:GetAttribute("PlayerUserId")
				local DronePlayer = type(DronePlayerUserId) == "number" and Players:GetPlayerByUserId(DronePlayerUserId) or nil
				if DronePlayer and IsSameTeam(LocalPlayer, DronePlayer) then
					return
				end
			end

			local LocalTeam = LocalPlayer and LocalPlayer:GetAttribute("Team")
			local TargetTeam = Character:GetAttribute("Team")
			if LocalTeam ~= nil and TargetTeam ~= nil and LocalTeam == TargetTeam then
				return
			end
		end

		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		local RootPart = (Humanoid and Humanoid.RootPart) or Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart
		if not (Humanoid and RootPart and Humanoid.Health > 0) then
			return
		end

		local Delta = RootPart.Position - LocalRootPart.Position
		local Distance = Delta.Magnitude
		if Distance > RangeLimit then
			return
		end

		local FlatDelta = Delta * Vector3.new(1, 0, 1)
		local Angle = 0
		if FlatDelta.Magnitude > 0 and LocalFacing.Magnitude > 0 then
			local Dot = math.clamp(LocalFacing.Unit:Dot(FlatDelta.Unit), -1, 1)
			Angle = math.deg(math.acos(Dot))
		end

		if Angle > 180 then
			return
		end

		AddedCharacters[Character] = true
		table.insert(Targets, {
			Player = Player,
			Character = Character,
			Humanoid = Humanoid,
			RootPart = RootPart,
			Distance = Distance,
			Angle = Angle
		})
	end

	for _, Player in ipairs(Players:GetPlayers()) do
		AddTarget(Player.Character, Player)
	end

	for _, EntityCharacter in ipairs(CollectionService:GetTagged("entity")) do
		if EntityCharacter:IsA("Model") then
			local Player = Players:GetPlayerFromCharacter(EntityCharacter)
			AddTarget(EntityCharacter, Player)
		end
	end

	table.sort(Targets, function(Left, Right)
		if Left.Distance == Right.Distance then
			return Left.Angle < Right.Angle
		end
		return Left.Distance < Right.Distance
	end)

	return Targets
end

local function GetKillauraAttackData()
	local SwordData, Meta = GetSwordData()
	if not (SwordData and SwordData.tool and Meta) then
		return nil
	end

	return SwordData, Meta
end

local function GetKillauraRedirectCFrame(TargetData, RootPart)
	if not (KillauraKnockbackRedirectEnabled and TargetData and TargetData.RootPart and RootPart) then
		return nil
	end

	if (tick() - (KillauraRedirectState.LastTeleportAt or 0)) < KillauraKnockbackRedirectCooldown then
		return nil
	end

	if (TargetData.Distance or (TargetData.RootPart.Position - RootPart.Position).Magnitude) > KillauraKnockbackRedirectDistance then
		return nil
	end

	local TargetPosition = TargetData.RootPart.Position
	local SelfPosition = RootPart.Position
	local FlatAxis = KillauraRedirectState.TargetAxis
	if not FlatAxis then
		local TargetRight = TargetData.RootPart.CFrame.RightVector
		FlatAxis = Vector3.new(TargetRight.X, 0, TargetRight.Z)
		if FlatAxis.Magnitude <= 0.05 then
			local FlatDelta = Vector3.new(TargetPosition.X - SelfPosition.X, 0, TargetPosition.Z - SelfPosition.Z)
			if FlatDelta.Magnitude > 0.05 then
				local FlatForward = FlatDelta.Unit
				FlatAxis = Vector3.new(-FlatForward.Z, 0, FlatForward.X)
			else
				FlatAxis = FlatDelta
			end
		end
		if FlatAxis.Magnitude <= 0.05 then
			return nil
		end
		FlatAxis = FlatAxis.Unit
		KillauraRedirectState.TargetAxis = FlatAxis
	end

	if FlatAxis.Magnitude <= 0.05 then
		return nil
	end

	if KillauraRedirectState.LastTarget ~= TargetData.Character then
		KillauraRedirectState.LastTarget = TargetData.Character
		KillauraRedirectState.TargetAxis = FlatAxis
		local Relative = Vector3.new(SelfPosition.X - TargetPosition.X, 0, SelfPosition.Z - TargetPosition.Z)
		if Relative.Magnitude > 0.05 then
			local CurrentSide = FlatAxis:Dot(Relative.Unit)
			KillauraRedirectState.NextSide = CurrentSide >= 0 and -1 or 1
		else
			KillauraRedirectState.NextSide = 1
		end
	end

	local SideVector = FlatAxis * (KillauraKnockbackRedirectOffset * KillauraRedirectState.NextSide)
	local CloseVector = Vector3.zero
	local RedirectPosition = Vector3.new(
		TargetPosition.X + SideVector.X + CloseVector.X,
		SelfPosition.Y,
		TargetPosition.Z + SideVector.Z + CloseVector.Z
	)
	local LookAtPosition = Vector3.new(TargetPosition.X, SelfPosition.Y + 0.001, TargetPosition.Z)
	local FlatLook = Vector3.new(LookAtPosition.X - RedirectPosition.X, 0, LookAtPosition.Z - RedirectPosition.Z)
	if FlatLook.Magnitude <= 0.05 then
		return nil
	end

	return CFrame.lookAt(RedirectPosition, LookAtPosition)
end

local function GetSafeKillauraRedirectCFrame(Character, RootPart, TargetCFrame)
	if not (Character and RootPart and TargetCFrame) then
		return nil
	end

	local Direction = TargetCFrame.Position - RootPart.Position
	if Direction.Magnitude <= 0.05 then
		return TargetCFrame
	end

	KillauraRedirectState.Raycast.FilterDescendantsInstances = {
		Character,
		KillauraRedirectState.LastTarget,
		workspace.CurrentCamera
	}
	KillauraRedirectState.Raycast.CollisionGroup = RootPart.CollisionGroup

	local WallRaycast = workspace:Raycast(RootPart.Position, Direction, KillauraRedirectState.Raycast)
	if not WallRaycast then
		return TargetCFrame
	end

	local SafeDistance = math.max(WallRaycast.Distance - math.max(RootPart.Size.X, RootPart.Size.Z, 2), 0)
	if SafeDistance <= 0.05 then
		return nil
	end

	local SafePosition = RootPart.Position + Direction.Unit * SafeDistance
	local LookAtPosition = Vector3.new(TargetCFrame.Position.X, SafePosition.Y + 0.001, TargetCFrame.Position.Z)
	local FlatLook = Vector3.new(LookAtPosition.X - SafePosition.X, 0, LookAtPosition.Z - SafePosition.Z)
	if FlatLook.Magnitude <= 0.05 then
		FlatLook = Vector3.new(TargetCFrame.LookVector.X, 0, TargetCFrame.LookVector.Z)
	end
	if FlatLook.Magnitude <= 0.05 then
		return nil
	end

	return CFrame.lookAt(SafePosition, SafePosition + FlatLook.Unit)
end

local function TweenKillauraRedirect(Character, RootPart, TargetCFrame)
	if not (Character and RootPart and TargetCFrame) then
		return false
	end

	local SafeTargetCFrame = GetSafeKillauraRedirectCFrame(Character, RootPart, TargetCFrame)
	if not SafeTargetCFrame then
		return false
	end

	if KillauraRedirectState.ActiveTween then
		pcall(function()
			KillauraRedirectState.ActiveTween:Cancel()
		end)
		KillauraRedirectState.ActiveTween = nil
	end

	local StartCFrame = RootPart.CFrame
	local TweenDuration = math.clamp(1 / math.max(KillauraKnockbackRedirectTweenSpeed, 0.1), 0.04, 0.35)
	local StartedAt = tick()
	local MovementState = { Cancelled = false }
	function MovementState:Cancel()
		self.Cancelled = true
	end

	KillauraRedirectState.ActiveTween = MovementState

	repeat
		if KillauraRedirectState.ActiveTween ~= MovementState or MovementState.Cancelled then
			return false
		end

		local CurrentRootPart = Character:FindFirstChild("HumanoidRootPart")
		if not CurrentRootPart then
			break
		end

		local Alpha = math.clamp((tick() - StartedAt) / TweenDuration, 0, 1)
		local DesiredCFrame = StartCFrame:Lerp(SafeTargetCFrame, Alpha)

		if Alpha < 1 then
			local StepDirection = DesiredCFrame.Position - CurrentRootPart.Position
			if StepDirection.Magnitude > 0.05 then
				KillauraRedirectState.Raycast.FilterDescendantsInstances = {
					Character,
					KillauraRedirectState.LastTarget,
					workspace.CurrentCamera
				}
				KillauraRedirectState.Raycast.CollisionGroup = CurrentRootPart.CollisionGroup
				local StepRaycast = workspace:Raycast(CurrentRootPart.Position, StepDirection, KillauraRedirectState.Raycast)
				if StepRaycast then
					local SafeDistance = math.max(StepRaycast.Distance - math.max(CurrentRootPart.Size.X, CurrentRootPart.Size.Z, 2), 0)
					if SafeDistance <= 0.05 then
						break
					end

					local SafePosition = CurrentRootPart.Position + StepDirection.Unit * SafeDistance
					local LookAtPosition = Vector3.new(SafeTargetCFrame.Position.X, SafePosition.Y + 0.001, SafeTargetCFrame.Position.Z)
					local FlatLook = Vector3.new(LookAtPosition.X - SafePosition.X, 0, LookAtPosition.Z - SafePosition.Z)
					if FlatLook.Magnitude > 0.05 then
						DesiredCFrame = CFrame.lookAt(SafePosition, SafePosition + FlatLook.Unit)
					end
				end
			end
		end

		Character:PivotTo(DesiredCFrame)
		CurrentRootPart.AssemblyLinearVelocity = Vector3.new(0, CurrentRootPart.AssemblyLinearVelocity.Y, 0)
		if Alpha >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	until false

	if KillauraRedirectState.ActiveTween == MovementState then
		KillauraRedirectState.ActiveTween = nil
	end
	return true
end

local function PerformKillauraAttack(TargetData, SwordData, SwordMeta, AttackRemote, SelfPosition)
	local BedwarsReference = rawget(getgenv(), "bedwars")
	local Store = CreateTaskiumStore()
	if not (TargetData and SwordData and SwordData.tool and SwordMeta and BedwarsReference and AttackRemote and type(AttackRemote.FireServer) == "function") then
		return false
	end

	local Delta = TargetData.RootPart.Position - SelfPosition
	local EffectiveAttackRange = KillauraAttackRange + (KillauraHitFixEnabled and 0.3 or 0)
	if Delta.Magnitude > EffectiveAttackRange then
		return false
	end

	local SwitchItemFunction = rawget(getgenv(), "switchItem")
	if type(SwitchItemFunction) == "function" then
		pcall(SwitchItemFunction, SwordData.tool, 0)
	end

	local Character = LocalPlayer and LocalPlayer.Character
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	if Humanoid and SwordData.tool.Parent ~= Character then
		pcall(function()
			Humanoid:EquipTool(SwordData.tool)
		end)
	end

	local TargetPosition = TargetData.RootPart.Position
	local Direction = CFrame.lookAt(SelfPosition, TargetPosition).LookVector
	local Position = SelfPosition + Direction * math.max(Delta.Magnitude - 14.4, 0)

	pcall(function()
		BedwarsReference.SwordController.lastAttack = workspace:GetServerTimeNow()
	end)

	Store.attackReach = math.floor(Delta.Magnitude * 100) / 100
	Store.attackReachUpdate = tick() + 1

	local Success = pcall(function()
		AttackRemote:FireServer({
			weapon = SwordData.tool,
			chargedAttack = {
				chargeRatio = 0
			},
			entityInstance = TargetData.Character,
			validate = {
				raycast = {
					cameraPosition = {
						value = Position
					},
					cursorDirection = {
						value = Direction
					}
				},
				targetPosition = {
					value = TargetPosition
				},
				selfPosition = {
					value = Position
				}
			}
		})
	end)
	return Success
end

local function ResetKillauraRedirectState()
	KillauraRedirectState.NextSide = 1
	KillauraRedirectState.LastTarget = nil
	KillauraRedirectState.LastTeleportAt = 0
	KillauraRedirectState.TargetAxis = nil
	if KillauraRedirectState.ActiveTween then
		KillauraRedirectState.ActiveTween:Cancel()
		KillauraRedirectState.ActiveTween = nil
	end
end

local function RemoveKillauraHitFixHook(HookOwnerToken)
	if KillauraHookState.OwnerToken ~= HookOwnerToken then
		return
	end

	if KillauraHookState.Client and KillauraHookState.WrappedGet and KillauraHookState.Client.Get == KillauraHookState.WrappedGet then
		KillauraHookState.Client.Get = KillauraHookState.OriginalGet
	end

	KillauraHookState.Client = nil
	KillauraHookState.OriginalGet = nil
	KillauraHookState.WrappedGet = nil
	KillauraHookState.OwnerToken = nil
	KillauraHitFixClient = nil
end

local function ApplyKillauraHitFixHook(BedwarsReference, RemoteTable, HookOwnerToken, IsHookActive)
	if not KillauraHitFixEnabled then
		RemoveKillauraHitFixHook(HookOwnerToken)
		return
	end

	if not (BedwarsReference and BedwarsReference.Client and RemoteTable and RemoteTable.AttackEntity) then
		return
	end

	local Client = BedwarsReference.Client
	if KillauraHitFixClient ~= Client then
		if KillauraHookState.Client and KillauraHookState.Client ~= Client and KillauraHookState.WrappedGet and KillauraHookState.Client.Get == KillauraHookState.WrappedGet then
			KillauraHookState.Client.Get = KillauraHookState.OriginalGet
		end
		KillauraHitFixClient = Client
	end

	if KillauraHookState.Client ~= Client then
		KillauraHookState.Client = Client
		KillauraHookState.OriginalGet = Client.Get
	end

	KillauraHookState.OwnerToken = HookOwnerToken
	local OriginalGet = KillauraHookState.OriginalGet
	local WrappedGet = function(Self, RemoteName)
		local Call = OriginalGet(Self, RemoteName)
		if KillauraHookState.OwnerToken ~= HookOwnerToken or not IsHookActive() or not KillauraHitFixEnabled or RemoteName ~= RemoteTable.AttackEntity then
			return Call
		end

		return setmetatable({
			instance = Call and Call.instance,
			SendToServer = function(_, AttackTable, ...)
				local Validate = AttackTable and AttackTable.validate
				local SelfPositionValue = Validate and Validate.selfPosition and Validate.selfPosition.value
				local TargetPositionValue = Validate and Validate.targetPosition and Validate.targetPosition.value
				if typeof(SelfPositionValue) == "Vector3" and typeof(TargetPositionValue) == "Vector3" then
					local Store = CreateTaskiumStore()
					Store.attackReach = math.floor((SelfPositionValue - TargetPositionValue).Magnitude * 100) / 100
					Store.attackReachUpdate = tick() + 1
					Validate.raycast = Validate.raycast or {}
					Validate.selfPosition.value = SelfPositionValue + CFrame.lookAt(SelfPositionValue, TargetPositionValue).LookVector * math.max((SelfPositionValue - TargetPositionValue).Magnitude - 14.399, 0)
				end

				if type(Call.SendToServer) == "function" then
					return Call:SendToServer(AttackTable, ...)
				end
				if Call and Call.instance and type(Call.instance.FireServer) == "function" then
					return Call.instance:FireServer(AttackTable, ...)
				end
			end
		}, {
			__index = function(_, Key)
				return Call and Call[Key]
			end
		})
	end
	KillauraHookState.WrappedGet = WrappedGet
	Client.Get = WrappedGet
end

KillauraModule = TaskAPI.Categories.Combat:CreateModule({
	Name = "Killaura",
	Function = function(Enabled, RunId, Module)
		local AnimationActiveUntil = 0
		local HookOwnerToken = "Killaura_" .. tostring(RunId) .. "_" .. tostring(math.floor(os.clock() * 1000))
		local function IsHookActive()
			return Module:IsActive(RunId)
		end

		local function StartKillauraAnimationLoop()
			KillauraAnimationToken = KillauraAnimationToken + 1
			local CurrentToken = KillauraAnimationToken

			task.spawn(function()
				local Started = false

				repeat
					if (getgenv().Attacking or tick() < AnimationActiveUntil) and KillauraAnimationEnabled then
						local Wrist = GetKillauraWrist()
						if Wrist then
							KillauraBaseC0 = KillauraBaseC0 or Wrist.C0
							local FirstFrame = not Started
							Started = true
							KillauraAnimationBusy = true

							local AnimationFrames = KillauraAnimations[KillauraAnimationMode] or KillauraAnimations.Normal
							if KillauraAnimationMode == "Random" then
								AnimationFrames = {
									{
										CFrame = CFrame.Angles(
											math.rad(math.random(1, 360)),
											math.rad(math.random(1, 360)),
											math.rad(math.random(1, 360))
										),
										Time = 0.12
									}
								}
							end

							for _, FrameData in ipairs(AnimationFrames) do
								local ActiveWrist = GetKillauraWrist()
								if not ActiveWrist or not Module:IsActive(RunId) or not (getgenv().Attacking or tick() < AnimationActiveUntil) or not KillauraAnimationEnabled or KillauraAnimationToken ~= CurrentToken then
									break
								end

								if KillauraCurrentAnimationTween then
									pcall(function()
										KillauraCurrentAnimationTween:Cancel()
									end)
								end

								local Duration = ((FirstFrame and 0.1 or FrameData.Time) / math.max(KillauraAnimationSpeed, 0.1))
								KillauraCurrentAnimationTween = TweenService:Create(ActiveWrist, TweenInfo.new(Duration, Enum.EasingStyle.Linear), {
									C0 = KillauraBaseC0 * FrameData.CFrame
								})
								KillauraCurrentAnimationTween:Play()
								KillauraCurrentAnimationTween.Completed:Wait()
								FirstFrame = false
							end
						end
					elseif Started then
						Started = false
						KillauraAnimationBusy = false
						ResetKillauraAnimation(0.15)
					else
						task.wait(1 / math.max(KillauraUpdateRate, 1))
					end
				until not Module:IsActive(RunId) or KillauraAnimationToken ~= CurrentToken

				if KillauraAnimationToken == CurrentToken then
					KillauraAnimationBusy = false
					ResetKillauraAnimation(0.15)
				end
			end)
		end

		if not Enabled then
			RemoveKillauraHitFixHook(HookOwnerToken)
			getgenv().Attacking = false
			local Store = rawget(getgenv(), "store")
			if Store then
				Store.KillauraTarget = nil
			end
			return
		end

		getgenv().Attacking = false
		local AttackRemote = {
			FireServer = function()
			end
		}
		local AttackRemoteResolved = false
		local LastAnimationTick = tick()
		local LastAttackTick = 0
		local LastWarningTick = 0
		local TargetIndex = 1
		local SwitchCooldown = tick()

		StartKillauraAnimationLoop()

		task.spawn(function()
			while Module:IsActive(RunId) do
				local ResolvedRemote = GetAttackRemote()
				if ResolvedRemote then
					AttackRemote = ResolvedRemote
					AttackRemoteResolved = true
					break
				end
				task.wait(0.1)
			end
		end)

		Module:Clean(function()
			AnimationActiveUntil = 0
			KillauraAnimationToken = KillauraAnimationToken + 1
			KillauraAnimationBusy = false
			RemoveKillauraHitFixHook(HookOwnerToken)
			ResetKillauraRedirectState()
			getgenv().Attacking = false
			local Store = rawget(getgenv(), "store")
			if Store then
				Store.KillauraTarget = nil
			end
			if KillauraCurrentAnimationTween then
				KillauraCurrentAnimationTween:Cancel()
				KillauraCurrentAnimationTween = nil
			end
			if KillauraAnimationResetTween then
				KillauraAnimationResetTween:Cancel()
			end
			ResetKillauraAnimation(0.1)
		end)

		task.spawn(function()
			repeat
				local BedwarsReference, RemoteTable = EnsureBedwarsRuntime()
				local Store = CreateTaskiumStore()
				local SwordData, SwordMeta = GetKillauraAttackData()
				getgenv().Attacking = false
				Store.KillauraTarget = nil
				ApplyKillauraHitFixHook(BedwarsReference, RemoteTable, HookOwnerToken, IsHookActive)

				local ResolvedRemote = GetAttackRemote()
				if ResolvedRemote then
					AttackRemote = ResolvedRemote
					AttackRemoteResolved = true
				end

				if SwordData and SwordMeta and Store.matchState ~= 0 and AttackRemoteResolved then
					local Character, Humanoid, RootPart = GetCharacterState()
					if Character and Humanoid and RootPart and Humanoid.Health > 0 then
						local SwitchItemFunction = rawget(getgenv(), "switchItem")
						if type(SwitchItemFunction) == "function" then
							pcall(SwitchItemFunction, SwordData.tool, 0)
						end
						if SwordData.tool.Parent ~= Character then
							pcall(function()
								Humanoid:EquipTool(SwordData.tool)
							end)
						end

						local Targets = CollectKillauraTargets(RootPart)
						if #Targets > 0 then
							AnimationActiveUntil = tick() + 0.2
							local SelfPosition = RootPart.Position

							if KillauraFaceTargetEnabled and Targets[1] and Targets[1].RootPart then
								local TargetPosition = Targets[1].RootPart.Position
								RootPart.CFrame = CFrame.lookAt(
									RootPart.Position,
									Vector3.new(TargetPosition.X, RootPart.Position.Y + 0.001, TargetPosition.Z)
								)
								SelfPosition = RootPart.Position
							end

							if tick() > SwitchCooldown and KillauraAttackMode == "Switch" then
								SwitchCooldown = tick() + 0.7
								TargetIndex = TargetIndex + 1
							end

							if not Targets[TargetIndex] then
								TargetIndex = 1
							end

							local PrimaryTarget = KillauraAttackMode == "Switch" and Targets[TargetIndex] or Targets[1]
							local AttackLimit = KillauraAttackMode == "Single" and 1 or KillauraMaxTargets
							local AttackedCount = 0
							local VisualAttackInterval = KillauraSwingInterval
							local ActualAttackInterval = 1 / math.max(KillauraUpdateRate, 1)
							local CanAttackNow = (tick() - LastAttackTick) >= ActualAttackInterval

							for Index, TargetData in ipairs(Targets) do
								if KillauraAttackMode == "Switch" and Index ~= TargetIndex then
									continue
								end

								getgenv().Attacking = true
								Store.KillauraTarget = TargetData.Character
								local AttackSelfPosition = SelfPosition

								if CanAttackNow and LastAnimationTick < tick() and not KillauraAnimationEnabled then
									LastAnimationTick = tick() + VisualAttackInterval
									pcall(function()
										BedwarsReference.SwordController:playSwordEffect(SwordMeta, false)
									end)
									if SwordMeta.displayName and SwordMeta.displayName:find(" Scythe") and BedwarsReference.ScytheController and type(BedwarsReference.ScytheController.playLocalAnimation) == "function" then
										pcall(function()
											BedwarsReference.ScytheController:playLocalAnimation()
										end)
									end
								end

								if KillauraKnockbackRedirectEnabled then
									local RedirectCFrame = TargetData == PrimaryTarget and GetKillauraRedirectCFrame(TargetData, RootPart) or nil
									if RedirectCFrame then
										if TweenKillauraRedirect(Character, RootPart, RedirectCFrame) then
											AttackSelfPosition = RootPart.Position
											KillauraRedirectState.LastTeleportAt = tick()
											KillauraRedirectState.NextSide = KillauraRedirectState.NextSide == 1 and -1 or 1
											SelfPosition = RootPart.Position
										end
									end
								end

								if CanAttackNow and PerformKillauraAttack(TargetData, SwordData, SwordMeta, AttackRemote, AttackSelfPosition) then
									LastAttackTick = tick()
									AttackedCount = AttackedCount + 1
									SelfPosition = RootPart.Position
									if KillauraAttackMode ~= "Multi" or AttackedCount >= AttackLimit then
										break
									end
								end
							end
						end
					end
				end

				task.wait(1 / math.max(KillauraUpdateRate, 1))
			until not Module:IsActive(RunId)
		end)
	end,
	ToolTip = "Attack players around you without aiming at them."
})

KillauraModule:CreateSlider({
	Name = "Swing Range",
	Min = 1,
	Max = 18,
	Default = 18,
	Function = function(Value)
		KillauraSwingRange = Value
	end,
	ToolTip = "How far Killaura can look for targets."
})

KillauraModule:CreateSlider({
	Name = "Attack Range",
	Min = 1,
	Max = 18,
	Default = 18,
	Function = function(Value)
		KillauraAttackRange = Value
	end,
	ToolTip = "How far Killaura can hit targets."
})

KillauraModule:CreateSlider({
	Name = "Max Targets",
	Min = 1,
	Max = 5,
	Default = 5,
	Function = function(Value)
		KillauraMaxTargets = Value
	end,
	ToolTip = "Maximum targets used in Multi mode."
})

KillauraModule:CreateSlider({
	Name = "Animation Speed",
	Min = 1,
	Max = 20,
	Default = 10,
	Function = function(Value)
		KillauraAnimationSpeed = Value / 10
	end,
	ToolTip = "Changes how fast the custom sword animation plays."
})

KillauraModule:CreateToggle({
	Name = "Custom Animation",
	Function = function(Value)
		KillauraAnimationEnabled = Value
		if not Value then
			KillauraAnimationBusy = false
			ResetKillauraAnimation(0.1)
		end
	end,
	ToolTip = "Plays a custom sword animation while Killaura is attacking."
})

KillauraModule:CreateToggle({
	Name = "HitFix",
	Function = function(Value)
		KillauraHitFixEnabled = Value
	end,
	ToolTip = "Uses the BedWars-style attack remote hook for better hit registration."
})

KillauraModule:CreateToggle({
	Name = "Face Target",
	Function = function(Value)
		KillauraFaceTargetEnabled = Value
	end,
	ToolTip = "Turns your character toward the current Killaura target."
})

KillauraModule:CreateToggle({
	Name = "Knockback Redirect",
	Function = function(Value)
		KillauraKnockbackRedirectEnabled = Value
		ResetKillauraRedirectState()
	end,
	ToolTip = "Tweens your character to alternating sides of the target during Killaura attacks."
})

KillauraModule:CreateSlider({
	Name = "Redirect Distance",
	Min = 1,
	Max = 18,
	Default = 18,
	Function = function(Value)
		KillauraKnockbackRedirectDistance = Value
	end,
	ToolTip = "How close the target must be before Knockback Redirect can trigger."
})

KillauraModule:CreateSlider({
	Name = "Redirect Offset",
	Min = 1,
	Max = 14,
	Default = 4,
	Function = function(Value)
		KillauraKnockbackRedirectOffset = Value
	end,
	ToolTip = "How far around the target Knockback Redirect moves you."
})

KillauraModule:CreateSlider({
	Name = "Tween Speed",
	Min = 1,
	Max = 5,
	Default = 5,
	Function = function(Value)
		KillauraKnockbackRedirectTweenSpeed = Value
	end,
	ToolTip = "Changes how fast Knockback Redirect tweens you into position without snapping."
})

KillauraModule:CreateDropdown({
	Name = "Attack Mode",
	List = { "Single", "Multi", "Switch" },
	Function = function(Value)
		KillauraAttackMode = Value
	end,
	ToolTip = "Single attacks one target, Multi attacks several, Switch rotates targets."
})

KillauraModule:CreateDropdown({
	Name = "Animation Mode",
	List = { "Default", "Normal", "Random", "Horizontal Spin", "Vertical Spin", "Exhibition", "Exhibition Old" },
	Function = function(Value)
		KillauraAnimationMode = Value
	end,
	ToolTip = "Changes the custom sword swing animation."
})
end)

local AimAssistModule
local AimAssistState = {
	Part = "HumanoidRootPart",
	Distance = 18,
	Speed = 14,
	MaxAngle = 360,
	RequireRightClick = true,
	UseKillauraTarget = true
}

local function GetAimAssistPart(TargetData)
	if not TargetData then
		return nil
	end

	local Character = TargetData.Character
	if AimAssistState.Part == "Head" and Character then
		return Character:FindFirstChild("Head") or TargetData.RootPart
	end

	if TargetData.RootPart then
		return TargetData.RootPart
	end

	if Character then
		return Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart
	end

	return nil
end

local function GetAimAssistTarget(LocalRootPart)
	local Camera = workspace.CurrentCamera
	local Targets = Camera and CollectKillauraTargets(LocalRootPart) or nil
	if not (Camera and Targets and #Targets > 0) then
		return nil, nil
	end

	local BestTarget = nil
	local BestPart = nil
	local BestScore = nil

	for _, TargetData in ipairs(Targets) do
		local AimPartNow = GetAimAssistPart(TargetData)
		if AimPartNow and TargetData.Distance <= AimAssistState.Distance then
			local Delta = AimPartNow.Position - Camera.CFrame.Position
			if Delta.Magnitude > 0.001 then
				local Angle = math.deg(math.acos(math.clamp(Camera.CFrame.LookVector:Dot(Delta.Unit), -1, 1)))
				if Angle <= AimAssistState.MaxAngle then
					local Score = Angle + (TargetData.Distance * 0.05)
					if AimAssistState.UseKillauraTarget and KillauraModule and KillauraModule.Enabled and TargetData == Targets[1] then
						Score = Score - 5
					end
					if not BestScore or Score < BestScore then
						BestScore = Score
						BestTarget = TargetData
						BestPart = AimPartNow
					end
				end
			end
		end
	end

	return BestTarget, BestPart
end

AimAssistModule = TaskAPI.Categories.Combat:CreateModule({
	Name = "Aim Assist",
	Function = function(Enabled, RunId, Module)
		if not Enabled then
			return
		end

		local RightClickHeld = false

		Module:Clean(UserInputService.InputBegan:Connect(function(Input, GameProcessed)
			if GameProcessed then
				return
			end

			if Input.UserInputType == Enum.UserInputType.MouseButton2 then
				RightClickHeld = true
			end
		end))

		Module:Clean(UserInputService.InputEnded:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton2 then
				RightClickHeld = false
			end
		end))

		Module:Clean(RunService.RenderStepped:Connect(function(DeltaTime)
			if not Module:IsActive(RunId) then
				return
			end

			if AimAssistState.RequireRightClick and not RightClickHeld then
				return
			end

			local Character, Humanoid, RootPart = GetCharacterState()
			local Camera = workspace.CurrentCamera
			if not (Character and Humanoid and RootPart and Camera and Humanoid.Health > 0) then
				return
			end

			local TargetData, AimPartNow = GetAimAssistTarget(RootPart)
			if not (TargetData and AimPartNow) then
				return
			end

			local DesiredLook = AimPartNow.Position - Camera.CFrame.Position
			if DesiredLook.Magnitude <= 0.001 then
				return
			end

			local Alpha = math.clamp(DeltaTime * AimAssistState.Speed, 0, 1)
			local SmoothedLook = Camera.CFrame.LookVector:Lerp(DesiredLook.Unit, Alpha)
			if SmoothedLook.Magnitude <= 0.001 then
				return
			end

			Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, Camera.CFrame.Position + SmoothedLook.Unit)
		end))
	end,
	ToolTip = "Smoothly aims toward nearby BedWars targets."
})

AimAssistModule:CreateDropdown({
	Name = "Part",
	List = { "HumanoidRootPart", "Head" },
	Function = function(Value)
		AimAssistState.Part = Value
	end,
	ToolTip = "Changes which target part Aim Assist tracks."
})

AimAssistModule:CreateSlider({
	Name = "Distance",
	Min = 1,
	Max = 30,
	Default = 18,
	Function = function(Value)
		AimAssistState.Distance = Value
	end,
	Suffix = function(Value)
		return Value == 1 and "stud" or "studs"
	end,
	ToolTip = "How far Aim Assist can search for targets."
})

AimAssistModule:CreateSlider({
	Name = "Aim Speed",
	Min = 1,
	Max = 30,
	Default = 14,
	Function = function(Value)
		AimAssistState.Speed = Value
	end,
	ToolTip = "How quickly Aim Assist moves your camera."
})

AimAssistModule:CreateSlider({
	Name = "Max Angle",
	Min = 1,
	Max = 360,
	Default = 360,
	Function = function(Value)
		AimAssistState.MaxAngle = Value
	end,
	Suffix = function(Value)
		return Value == 1 and "degree" or "degrees"
	end,
	ToolTip = "Limits how far off-screen a target can be."
})

AimAssistModule:CreateToggle({
	Name = "Require Right Click",
	Default = true,
	Function = function(Value)
		AimAssistState.RequireRightClick = Value
	end,
	ToolTip = "Only aims while right click is held."
})

AimAssistModule:CreateToggle({
	Name = "Use Killaura Target",
	Default = true,
	Function = function(Value)
		AimAssistState.UseKillauraTarget = Value
	end,
	ToolTip = "Prefers Killaura's current target when possible."
})

local BreakerModule
local BreakerState = {
	Range = 30,
	BreakSpeed = 0.25,
	UpdateRate = 60,
	BreakBed = true,
	BreakTesla = true,
	BreakHive = true,
	BreakLuckyBlock = true,
	BreakIronOre = true,
	Animation = false,
	InstantBreak = false,
	SelfBreak = false,
	Effects = true
}

local function GetBreakerObjectPosition(Object)
	if Object == nil then
		return nil
	end

	if Object:IsA("BasePart") then
		return Object.Position
	end

	if Object:IsA("Model") then
		local PrimaryPart = Object.PrimaryPart or Object:FindFirstChildWhichIsA("BasePart")
		return PrimaryPart and PrimaryPart.Position or nil
	end

	return nil
end

local function GetBreakerTargets()
	local Targets = {}

	local function AddTagged(TagName, Enabled, ExtraCheck)
		if not Enabled then
			return
		end

		for _, Object in ipairs(CollectionService:GetTagged(TagName)) do
			if Object and Object.Parent and GetBreakerObjectPosition(Object) then
				if not ExtraCheck or ExtraCheck(Object) then
					table.insert(Targets, Object)
				end
			end
		end
	end

	AddTagged("bed", BreakerState.BreakBed)
	AddTagged("tesla-trap", BreakerState.BreakTesla, function(Object)
		local Player = Players:GetPlayerByUserId(Object:GetAttribute("PlacedByUserId") or 0)
		return not Player or not IsSameTeam(LocalPlayer, Player)
	end)
	AddTagged("beehive", BreakerState.BreakHive, function(Object)
		local Player = Players:GetPlayerByUserId(Object:GetAttribute("PlacedByUserId") or 0)
		return not Player or not IsSameTeam(LocalPlayer, Player)
	end)
	AddTagged("LuckyBlock", BreakerState.BreakLuckyBlock)
	AddTagged("iron_ore_mesh_block", BreakerState.BreakIronOre)

	return Targets
end

local function AttemptBreaker(BedwarsReference, Targets, LocalPosition)
	if not Targets or #Targets == 0 then
		return false
	end

	table.sort(Targets, function(Left, Right)
		local LeftPosition = GetBreakerObjectPosition(Left) or Vector3.zero
		local RightPosition = GetBreakerObjectPosition(Right) or Vector3.zero
		return (LocalPosition - LeftPosition).Magnitude < (LocalPosition - RightPosition).Magnitude
	end)

	local BreakBlockFunction = (BedwarsReference and BedwarsReference.breakBlock) or (rawget(getgenv(), "bedwars") and rawget(getgenv(), "bedwars").breakBlock)
	local BlockController = BedwarsReference and BedwarsReference.BlockController
	if type(BreakBlockFunction) ~= "function" or not BlockController or type(BlockController.isBlockBreakable) ~= "function" then
		return false
	end

	for _, Block in ipairs(Targets) do
		local BlockPosition = GetBreakerObjectPosition(Block)
		if Block and Block.Parent and BlockPosition then
			if (BlockPosition - LocalPosition).Magnitude < BreakerState.Range and BlockController:isBlockBreakable({ blockPosition = BlockPosition / 3 }, LocalPlayer) then
				if not BreakerState.SelfBreak and Block:GetAttribute("PlacedByUserId") == LocalPlayer.UserId then
					continue
				end

				if (Block:GetAttribute("BedShieldEndTime") or 0) > workspace:GetServerTimeNow() then
					continue
				end

				BreakBlockFunction(Block, BreakerState.Effects, BreakerState.Animation, nil, BreakerState.InstantBreak, false, "Health", 360)
				task.wait(BreakerState.InstantBreak and 0 or BreakerState.BreakSpeed)
				return true
			end
		end
	end

	return false
end

BreakerModule = TaskAPI.Categories.Other:CreateModule({
	Name = "Breaker",
	Function = function(Enabled, RunId, Module)
		if not Enabled then
			return
		end

		local MissingBreakWarned = false
		task.spawn(function()
			repeat
				task.wait(1 / math.max(BreakerState.UpdateRate, 1))
				if not Module:IsActive(RunId) then
					break
				end

				local Character, Humanoid, RootPart = GetCharacterState()
				local BedwarsReference = EnsureBedwarsRuntime()
				local BreakBlockFunction = (BedwarsReference and BedwarsReference.breakBlock) or (rawget(getgenv(), "bedwars") and rawget(getgenv(), "bedwars").breakBlock)
				if type(BreakBlockFunction) ~= "function" then
					if not MissingBreakWarned then
						MissingBreakWarned = true
						TaskAPI.Notification("Taskium", "Breaker could not find bedwars.breakBlock.", 5, "Error")
					end
					continue
				end

				if Character and Humanoid and RootPart and Humanoid.Health > 0 then
					local LocalPosition = RootPart.Position
					local Targets = GetBreakerTargets()
					AttemptBreaker(BedwarsReference, Targets, LocalPosition)
				end
			until not Module:IsActive(RunId)
		end)
	end,
	ToolTip = "Breaks nearby BedWars blocks automatically."
})

BreakerModule:CreateSlider({
	Name = "Break Range",
	Min = 1,
	Max = 30,
	Default = 30,
	Function = function(Value)
		BreakerState.Range = Value
	end,
	ToolTip = "How far Breaker can look for blocks."
})

BreakerModule:CreateSlider({
	Name = "Break Speed",
	Min = 0,
	Max = 30,
	Default = 25,
	Function = function(Value)
		BreakerState.BreakSpeed = Value / 100
	end,
	ToolTip = "Delay between block break attempts."
})

BreakerModule:CreateSlider({
	Name = "Update Rate",
	Min = 1,
	Max = 120,
	Default = 60,
	Function = function(Value)
		BreakerState.UpdateRate = Value
	end,
	ToolTip = "How often Breaker scans for blocks."
})

BreakerModule:CreateToggle({
	Name = "Break Bed",
	Default = true,
	Function = function(Value)
		BreakerState.BreakBed = Value
	end
})

BreakerModule:CreateToggle({
	Name = "Break Tesla",
	Default = true,
	Function = function(Value)
		BreakerState.BreakTesla = Value
	end
})

BreakerModule:CreateToggle({
	Name = "Break Hive",
	Default = true,
	Function = function(Value)
		BreakerState.BreakHive = Value
	end
})

BreakerModule:CreateToggle({
	Name = "Break Lucky Block",
	Default = true,
	Function = function(Value)
		BreakerState.BreakLuckyBlock = Value
	end
})

BreakerModule:CreateToggle({
	Name = "Break Iron Ore",
	Default = true,
	Function = function(Value)
		BreakerState.BreakIronOre = Value
	end
})

BreakerModule:CreateToggle({
	Name = "Animation",
	Function = function(Value)
		BreakerState.Animation = Value
	end
})

BreakerModule:CreateToggle({
	Name = "Instant Break",
	Function = function(Value)
		BreakerState.InstantBreak = Value
	end
})

BreakerModule:CreateToggle({
	Name = "Self Break",
	Function = function(Value)
		BreakerState.SelfBreak = Value
	end
})

BreakerModule:CreateToggle({
	Name = "Show Effects",
	Default = true,
	Function = function(Value)
		BreakerState.Effects = Value
	end
})

local VelocityModule
local VelocityHookState = RuntimeState.VelocityHook or {}

RuntimeState.VelocityHook = VelocityHookState

RunModule(function()
	local Horizontal = 0 -- horizontal knockback %
	local Vertical = 0 -- vertical knockback %
	local Chance = 100 -- application chance %
	local Rand = Random.new()
	local KnockbackUtil

	VelocityModule = TaskAPI.Categories.Combat:CreateModule({
		Name = "Velocity",
		Function = function(Enabled, RunId, Module)
			local HookOwnerToken = "Velocity_" .. tostring(RunId) .. "_" .. tostring(math.floor(os.clock() * 1000))

			if not KnockbackUtil then
				local ok, result = pcall(function()
					return require(ReplicatedStorage.TS.damage["knockback-util"]).KnockbackUtil
				end)
				if ok and result then
					KnockbackUtil = result
				else
					warn("KnockbackUtil failed to load:", tostring(result))
					return
				end
			end

			if Enabled then
				if VelocityHookState.Util ~= KnockbackUtil then
					if VelocityHookState.Util and VelocityHookState.WrappedApplyKnockback and VelocityHookState.Util.applyKnockback == VelocityHookState.WrappedApplyKnockback then
						VelocityHookState.Util.applyKnockback = VelocityHookState.OriginalApplyKnockback
					end
					VelocityHookState.Util = KnockbackUtil
					VelocityHookState.OriginalApplyKnockback = KnockbackUtil.applyKnockback
				end

				VelocityHookState.OwnerToken = HookOwnerToken
				local OriginalApplyKnockback = VelocityHookState.OriginalApplyKnockback
				local WrappedApplyKnockback = function(root, mass, dir, knockback, ...)
					if VelocityHookState.OwnerToken ~= HookOwnerToken or not Module:IsActive(RunId) then
						return OriginalApplyKnockback(root, mass, dir, knockback, ...)
					end

					if Rand:NextNumber(0, 100) > Chance then
						return OriginalApplyKnockback(root, mass, dir, knockback, ...)
					end

					if Horizontal == 0 and Vertical == 0 then
						return
					end

					knockback = knockback or {}
					knockback.horizontal = (knockback.horizontal or 1) * (Horizontal / 100)
					knockback.vertical = (knockback.vertical or 1) * (Vertical / 100)

					return OriginalApplyKnockback(root, mass, dir, knockback, ...)
				end

				VelocityHookState.WrappedApplyKnockback = WrappedApplyKnockback
				KnockbackUtil.applyKnockback = WrappedApplyKnockback
			else
				if VelocityHookState.OwnerToken == HookOwnerToken and KnockbackUtil and VelocityHookState.WrappedApplyKnockback and KnockbackUtil.applyKnockback == VelocityHookState.WrappedApplyKnockback then
					KnockbackUtil.applyKnockback = VelocityHookState.OriginalApplyKnockback
					VelocityHookState.OwnerToken = nil
					VelocityHookState.WrappedApplyKnockback = nil
				end
			end
		end,
		ToolTip = "Reduces knockback taken."
	})

	VelocityModule:CreateSlider({
		Name = "Horizontal",
		Min = 0,
		Max = 100,
		Default = 0,
		Function = function(Value)
			Horizontal = Value
		end,
		ToolTip = "0 = no horizontal KB, 100 = full."
	})

	VelocityModule:CreateSlider({
		Name = "Vertical",
		Min = 0,
		Max = 100,
		Default = 0,
		Function = function(Value)
			Vertical = Value
		end,
		ToolTip = "0 = no vertical KB, 100 = full."
	})

	VelocityModule:CreateSlider({
		Name = "Chance",
		Min = 0,
		Max = 100,
		Default = 100,
		Function = function(Value)
			Chance = Value
		end,
		ToolTip = "% chance to block KB. 100 = always."
	})
end)

return TaskAPI