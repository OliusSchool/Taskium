local TaskAPI = getgenv().TaskAPI or (getgenv().Taskium and getgenv().Taskium.API)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer and LocalPlayer:WaitForChild("PlayerGui")

if not TaskAPI or not TaskAPI.Categories then
	TaskAPI.Notification("Taskium", "TaskAPI categories were not loaded before Games/Universal.lua", 5, "Error")
	return TaskAPI
end

local CreateTaskiumStore
local SyncTaskiumStore
local EnsureBedwarsRuntime
local GetGroundHitRemote

local function GetCharacterState()
	local Character = LocalPlayer and LocalPlayer.Character
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	return Character, Humanoid, RootPart
end

local function IsLikelyBedwarsPlace()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TSFolder = ReplicatedStorage:FindFirstChild("TS")
	local ItemFolder = TSFolder and TSFolder:FindFirstChild("item")
	return ReplicatedStorage:FindFirstChild("rbxts_include") ~= nil
		and TSFolder ~= nil
		and TSFolder:FindFirstChild("remotes") ~= nil
		and ItemFolder ~= nil
		and ItemFolder:FindFirstChild("item-meta") ~= nil
end

local FlyModule
local FlySpeedValue
local FlyVerticalSpeed
local FlyTPDown
local FlyShowBar
local FlyTpDuration
local FlyUpInput
local FlyDownInput
local FlyOldDeflate
local FlyOldY
local FlyTpTick
local FlyTpToggle
local FlyNextTpDownTick
local FlyResumeAt
local FlyRaycast
local ScriptFlyGeneration

local function ResetFlyState()
	FlyUpInput = 0
	FlyDownInput = 0
	FlyOldY = nil
	FlyTpTick = 0
	FlyTpToggle = true
	FlyNextTpDownTick = tick() + FlyTpDuration
	FlyResumeAt = 0
end

local function GetBedwarsSpeed()
	local GetSpeedFunction = rawget(getgenv(), "getSpeed")
	if type(GetSpeedFunction) == "function" then
		local Success, Result = pcall(GetSpeedFunction)
		if Success and type(Result) == "number" then
			return Result
		end
	end

	return 0
end

local function HasBalloonItem()
	local GetItemFunction = rawget(getgenv(), "getItem")
	if type(GetItemFunction) == "function" then
		local Success, Item = pcall(GetItemFunction, "balloon")
		return Success and Item ~= nil
	end

	return false
end

local function TryInflateBalloon()
	local BedwarsReference = rawget(getgenv(), "bedwars")
	local BalloonController = BedwarsReference and BedwarsReference.BalloonController
	local Character = LocalPlayer and LocalPlayer.Character
	if not (BalloonController and Character and type(BalloonController.inflateBalloon) == "function") then
		return
	end

	if (Character:GetAttribute("InflatedBalloons") or 0) == 0 and HasBalloonItem() then
		pcall(function()
			BalloonController:inflateBalloon()
		end)
	end
end

local function IsFlyAllowed(Character)
	local Store = rawget(getgenv(), "store")
	local InflatedBalloons = Character and (Character:GetAttribute("InflatedBalloons") or 0) or 0
	local MatchState = Store and Store.matchState or 0
	return InflatedBalloons > 0 or MatchState == 2
end

local function IsCharacterGrounded(RootPart)
	local Store = rawget(getgenv(), "store")
	local AirRay = Store and Store.airRay
	if AirRay then
		return workspace:Raycast(RootPart.Position, Vector3.new(0, -4.5, 0), AirRay) ~= nil
	end

	return workspace:Raycast(RootPart.Position, Vector3.new(0, -4.5, 0), FlyRaycast) ~= nil
end

local function CreateFlyProgressBar(Module)
	local ProgressGui = Instance.new("ScreenGui")
	ProgressGui.Name = "TaskiumFlyProgress"
	ProgressGui.ResetOnSpawn = false
	ProgressGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ProgressGui.Parent = PlayerGui

	local ProgressBar = Instance.new("Frame")
	ProgressBar.Name = "FlyBar"
	ProgressBar.AnchorPoint = Vector2.new(0.5, 0)
	ProgressBar.Position = UDim2.new(0.5, 0, 1, -200)
	ProgressBar.Size = UDim2.new(0, 240, 0, 20)
	ProgressBar.BackgroundTransparency = 0.5
	ProgressBar.Visible = false
	ProgressBar.BorderSizePixel = 0
	ProgressBar.BackgroundColor3 = Color3.new()
	ProgressBar.Parent = ProgressGui

	local Fill = Instance.new("Frame")
	Fill.Name = "Frame"
	Fill.AnchorPoint = Vector2.new(0, 0)
	Fill.Position = UDim2.new(0, 0, 0, 0)
	Fill.Size = UDim2.new(1, 0, 1, 0)
	Fill.BackgroundTransparency = 0
	Fill.Visible = true
	Fill.BorderSizePixel = 0
	Fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Fill.Parent = ProgressBar

	local Timer = Instance.new("TextLabel")
	Timer.Text = string.format("%.1fs", FlyTpDuration)
	Timer.Font = Enum.Font.Arimo
	Timer.Name = "Timer"
	Timer.TextStrokeTransparency = 0
	Timer.TextColor3 = Color3.new(0.9, 0.9, 0.9)
	Timer.TextSize = 20
	Timer.Size = UDim2.new(1, 0, 1, 0)
	Timer.BackgroundTransparency = 1
	Timer.Position = UDim2.new(0, 0, -1, 0)
	Timer.Parent = ProgressBar

	Module:Clean(ProgressGui)
	return ProgressBar, Fill, Timer
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

	if FlyModule and FlyModule.Enabled then
		WalkSpeed = FlySpeedValue
		SprintSpeed = FlySpeedValue
	elseif SpeedModule and SpeedModule.Enabled then
		WalkSpeed = SpeedValue
		SprintSpeed = SpeedValue
	end

	Humanoid.WalkSpeed = WalkSpeed
	if SprintController and type(SprintController.setSpeed) == "function" then
		pcall(function()
			SprintController:setSpeed(SprintSpeed)
		end)
	end
end

local GravityModule
local DefaultWorkspaceGravity
local GravityValue

local function ApplyWorkspaceGravity()
	if GravityModule and GravityModule.Enabled then
		workspace.Gravity = GravityValue
	else
		workspace.Gravity = DefaultWorkspaceGravity
	end
end

local SpeedModule
local SpeedValue
local SpeedBypass
local LongJumpModule

SpeedValue = 23
SpeedBypass = false

SpeedModule = TaskAPI.Categories.Movement:CreateModule({
	Name = "Speed",
	Function = function(Enabled, RunId, Module)
		local function ResetSpeed()
			local _, _, RootPart = GetCharacterState()
			RestoreBaseMovementSpeed()
			if RootPart then
				RootPart.AssemblyLinearVelocity = Vector3.new(
					RootPart.AssemblyLinearVelocity.X,
					RootPart.AssemblyLinearVelocity.Y,
					RootPart.AssemblyLinearVelocity.Z
				)
			end
		end

		if Enabled then
			local NextBypassTick = tick() + 2
			local BypassUntilTick = 0
			local BypassTeleportAccumulator = 0
			local BypassTeleportInterval = 1 / 48

			Module:Clean(RunService.PreSimulation:Connect(function(DeltaTime)
				if not Module:IsActive(RunId) then
					local _, Humanoid, RootPart = GetCharacterState()
					if Humanoid then
						Humanoid.WalkSpeed = 16
					end
					if RootPart then
						RootPart.AssemblyLinearVelocity = Vector3.zero
					end
					return
				end

				local _, Humanoid, RootPart = GetCharacterState()
				if not (Humanoid and RootPart) then
					return
				end

				local BedwarsReference = rawget(getgenv(), "bedwars")
				local SprintController = BedwarsReference and BedwarsReference.SprintController

				if (FlyModule and FlyModule.Enabled) or (LongJumpModule and LongJumpModule.Enabled) then
					Humanoid.WalkSpeed = 0
					if SprintController and type(SprintController.setSpeed) == "function" then
						pcall(function()
							SprintController:setSpeed(20)
						end)
					end
					RootPart.AssemblyLinearVelocity = Vector3.new(
						RootPart.AssemblyLinearVelocity.X,
						RootPart.AssemblyLinearVelocity.Y,
						RootPart.AssemblyLinearVelocity.Z
					)
					return
				end

				local HumanoidState = Humanoid:GetState()
				if HumanoidState == Enum.HumanoidStateType.Climbing then
					return
				end

				Humanoid.WalkSpeed = 0

				local MoveDirection = Humanoid.MoveDirection
				local EffectiveSpeed = SpeedValue
				local BypassActive = false
				if SpeedBypass then
					local CurrentTick = tick()
					if CurrentTick >= NextBypassTick then
						BypassUntilTick = CurrentTick + 0.12
						NextBypassTick = CurrentTick + 2.5
					end
					if CurrentTick <= BypassUntilTick then
						EffectiveSpeed = math.min(SpeedValue + 0.5, 23.5)
						BypassActive = true
					end
				end

				Humanoid.WalkSpeed = EffectiveSpeed
				if SprintController and type(SprintController.setSpeed) == "function" then
					pcall(function()
						SprintController:setSpeed(EffectiveSpeed)
					end)
				end

				if BypassActive and MoveDirection.Magnitude > 0.001 then
					BypassTeleportAccumulator = BypassTeleportAccumulator + DeltaTime
					if BypassTeleportAccumulator >= BypassTeleportInterval then
						BypassTeleportAccumulator = BypassTeleportAccumulator % BypassTeleportInterval
						local TeleportDistance = math.min((EffectiveSpeed + 1.5) * BypassTeleportInterval, 0.28)
						RootPart.CFrame = RootPart.CFrame + (MoveDirection.Unit * TeleportDistance)
					end
				else
					BypassTeleportAccumulator = 0
				end
			end))
		end

		ResetSpeed()
	end,
	ToolTip = "Moves your character with CFrame speed.",
	Sliders = {
		{
			Name = "Speed",
			Min = 1,
			Max = 23,
			Default = 23,
			Function = function(Value)
				SpeedValue = Value
			end,
			ToolTip = "Adjusts the CFrame speed value."
		}
	},
	Toggles = {
		{
			Name = "Bypass",
			Function = function(Callback)
				SpeedBypass = Callback
			end,
			ToolTip = "Every 5 seconds, adds a small teleporty burst with a slight speed boost."
		}
	}
})

FlySpeedValue = 23
FlyVerticalSpeed = 50
FlyTPDown = true
FlyShowBar = true
FlyTpDuration = 2
FlyUpInput = 0
FlyDownInput = 0
FlyOldDeflate = nil
FlyOldY = nil
FlyTpTick = 0
FlyTpToggle = true
FlyNextTpDownTick = 0
FlyResumeAt = 0
FlyRaycast = RaycastParams.new()
FlyRaycast.RespectCanCollide = true
ScriptFlyGeneration = (rawget(getgenv(), "TaskiumFlyGeneration") or 0) + 1
getgenv().TaskiumFlyGeneration = ScriptFlyGeneration

FlyModule = TaskAPI.Categories.Movement:CreateModule({
	Name = "Fly",
	Function = function(Enabled, RunId, Module)
		local ActiveFlyId = nil

		local function ResetCharacter()
			RestoreBaseMovementSpeed()
		end

		if Enabled then
			ActiveFlyId = (rawget(getgenv(), "TaskiumActiveFlyId") or 0) + 1
			getgenv().TaskiumActiveFlyId = ActiveFlyId
			ResetFlyState()
			Module:Clean(function()
				if rawget(getgenv(), "TaskiumActiveFlyId") == ActiveFlyId then
					getgenv().TaskiumActiveFlyId = nil
				end
				local BedwarsReference = rawget(getgenv(), "bedwars")
				local BalloonController = BedwarsReference and BedwarsReference.BalloonController
				if BalloonController and FlyOldDeflate then
					BalloonController.deflateBalloon = FlyOldDeflate
				end
				FlyOldDeflate = nil
				ResetFlyState()
				ResetCharacter()
			end)

			local ProgressBar, ProgressFill, ProgressTimer = CreateFlyProgressBar(Module)
			local BedwarsReference = rawget(getgenv(), "bedwars")
			local BalloonController = BedwarsReference and BedwarsReference.BalloonController
			FlyOldDeflate = BalloonController and BalloonController.deflateBalloon
			local AirborneStartedAt = tick()

			if BalloonController and type(FlyOldDeflate) == "function" then
				BalloonController.deflateBalloon = function() end
				Module:Clean(function()
					if BalloonController.deflateBalloon ~= FlyOldDeflate then
						BalloonController.deflateBalloon = FlyOldDeflate
					end
				end)
			end

			local function AttachCharacter(Character)
				if not Character then
					return
				end

				Module:Clean(Character:GetAttributeChangedSignal("InflatedBalloons"):Connect(function()
					if Module:IsActive(RunId) then
						TryInflateBalloon()
					end
				end))
				TryInflateBalloon()
			end

			AttachCharacter(LocalPlayer and LocalPlayer.Character)
			Module:Clean(LocalPlayer.CharacterAdded:Connect(function(Character)
				task.defer(function()
					if Module:IsActive(RunId) then
						AttachCharacter(Character)
					end
				end)
			end))

			FlyUpInput = (UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonA)) and 1 or 0
			FlyDownInput = (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonL2)) and -1 or 0
			local FlyUpActionName = "TaskiumFlyUp_" .. tostring(RunId)
			local FlyDownActionName = "TaskiumFlyDown_" .. tostring(RunId)

			ContextActionService:BindAction(FlyUpActionName, function(_, InputState)
				if InputState == Enum.UserInputState.Begin then
					FlyUpInput = 1
				elseif InputState == Enum.UserInputState.End or InputState == Enum.UserInputState.Cancel then
					FlyUpInput = 0
				end
				return Enum.ContextActionResult.Pass
			end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

			ContextActionService:BindAction(FlyDownActionName, function(_, InputState)
				if InputState == Enum.UserInputState.Begin then
					FlyDownInput = -1
				elseif InputState == Enum.UserInputState.End or InputState == Enum.UserInputState.Cancel then
					FlyDownInput = 0
				end
				return Enum.ContextActionResult.Pass
			end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL2)

			Module:Clean(function()
				ContextActionService:UnbindAction(FlyUpActionName)
				ContextActionService:UnbindAction(FlyDownActionName)
			end)

			Module:Clean(UserInputService.InputBegan:Connect(function(InputObject)
				if InputObject.KeyCode == Enum.KeyCode.Space or InputObject.KeyCode == Enum.KeyCode.ButtonA then
					FlyUpInput = 1
				elseif InputObject.KeyCode == Enum.KeyCode.LeftShift or InputObject.KeyCode == Enum.KeyCode.ButtonL2 then
					FlyDownInput = -1
				end
			end))

			Module:Clean(UserInputService.InputEnded:Connect(function(InputObject)
				if InputObject.KeyCode == Enum.KeyCode.Space or InputObject.KeyCode == Enum.KeyCode.ButtonA then
					FlyUpInput = 0
				elseif InputObject.KeyCode == Enum.KeyCode.LeftShift or InputObject.KeyCode == Enum.KeyCode.ButtonL2 then
					FlyDownInput = 0
				end
			end))

			pcall(function()
				if UserInputService.TouchEnabled then
					local JumpButton = LocalPlayer.PlayerGui.TouchGui.TouchControlFrame.JumpButton
					Module:Clean(JumpButton:GetPropertyChangedSignal("ImageRectOffset"):Connect(function()
						FlyUpInput = JumpButton.ImageRectOffset.X == 146 and 1 or 0
					end))
				end
			end)

			Module:Clean(RunService.PreSimulation:Connect(function(DeltaTime)
				if not Module:IsActive(RunId)
					or rawget(getgenv(), "TaskiumFlyGeneration") ~= ScriptFlyGeneration
					or rawget(getgenv(), "TaskiumActiveFlyId") ~= ActiveFlyId then
					ResetFlyState()
					ResetCharacter()
					return
				end

				local CharacterNow, Humanoid, RootPart = GetCharacterState()
				if not (CharacterNow and Humanoid and RootPart) then
					return
				end

				local SprintController = BedwarsReference and BedwarsReference.SprintController
				FlyRaycast.FilterDescendantsInstances = { CharacterNow, workspace.CurrentCamera }
				FlyRaycast.CollisionGroup = RootPart.CollisionGroup

				local MoveDirection = Humanoid.MoveDirection
				local Velo = math.min(GetBedwarsSpeed(), FlySpeedValue)
				local Destination = MoveDirection * math.max(FlySpeedValue - Velo, 0) * DeltaTime
				local UpInput = FlyUpInput
				local DownInput = FlyDownInput
				if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonA) then
					UpInput = 1
				end
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonL2) then
					DownInput = -1
				end
				local FlyAllowed = IsFlyAllowed(CharacterNow)
				local Grounded = IsCharacterGrounded(RootPart)
				if Grounded then
					Humanoid.WalkSpeed = FlySpeedValue
					if SprintController and type(SprintController.setSpeed) == "function" then
						pcall(function()
							SprintController:setSpeed(FlySpeedValue)
						end)
					end
					Destination = Vector3.zero
				else
					Humanoid.WalkSpeed = 0
					if SprintController and type(SprintController.setSpeed) == "function" then
						pcall(function()
							SprintController:setSpeed(FlySpeedValue)
						end)
					end
				end
				if Grounded then
					AirborneStartedAt = tick()
				end
				local AirLeft = tick() - AirborneStartedAt
				local Mass = (1.5 + ((FlyAllowed and 6 or 0) * ((tick() % 0.4 < 0.2) and -1 or 1))) + ((UpInput + DownInput) * FlyVerticalSpeed)

				if FlyResumeAt > tick() then
					RootPart.AssemblyLinearVelocity = Vector3.new(0, RootPart.AssemblyLinearVelocity.Y, 0)
					return
				end

				local WallRaycast = workspace:Raycast(RootPart.Position, Destination, FlyRaycast)
				if WallRaycast then
					Destination = (WallRaycast.Position + WallRaycast.Normal) - RootPart.Position
				end

				if ProgressBar then
					ProgressBar.Visible = FlyShowBar and FlyTPDown and not FlyAllowed
					if FlyShowBar and FlyTPDown and not FlyAllowed then
						if FlyTpToggle then
							local Remaining = math.max(FlyTpDuration - AirLeft, 0)
							ProgressFill.Size = UDim2.new(math.clamp(Remaining / FlyTpDuration, 0, 1), 0, 1, 0)
							ProgressTimer.Text = string.format("%.1fs", Remaining)
						else
							local Remaining = math.max(FlyTpTick - tick(), 0)
							ProgressFill.Size = UDim2.new(0, 0, 1, 0)
							ProgressTimer.Text = string.format("%.1fs", Remaining)
						end
					end
				end

				if FlyTPDown then
					if FlyTpToggle then
						if not FlyAllowed and AirLeft > FlyTpDuration and not FlyOldY then
							local GroundRaycast = workspace:Raycast(RootPart.Position, Vector3.new(0, -1000, 0), FlyRaycast)
							if GroundRaycast then
								FlyTpToggle = false
								FlyOldY = RootPart.Position.Y
								FlyTpTick = tick() + 0.13
								RootPart.CFrame = CFrame.lookAlong(
									Vector3.new(RootPart.Position.X, GroundRaycast.Position.Y + Humanoid.HipHeight, RootPart.Position.Z),
									RootPart.CFrame.LookVector
								)
							end
						end
					else
						if FlyOldY then
							if FlyTpTick < tick() then
								RootPart.CFrame = CFrame.lookAlong(
									Vector3.new(RootPart.Position.X, FlyOldY, RootPart.Position.Z),
									RootPart.CFrame.LookVector
								)
								FlyTpToggle = true
								FlyOldY = nil
								AirborneStartedAt = tick()
								FlyNextTpDownTick = tick() + FlyTpDuration
								FlyResumeAt = tick() + 0.12
							else
								Mass = 0
							end
						end
					end
				end

				RootPart.CFrame = RootPart.CFrame + Destination
				RootPart.AssemblyLinearVelocity = Vector3.new(
					Grounded and RootPart.AssemblyLinearVelocity.X or (MoveDirection.X * Velo),
					Mass,
					Grounded and RootPart.AssemblyLinearVelocity.Z or (MoveDirection.Z * Velo)
				)
			end))
		else
			if rawget(getgenv(), "TaskiumActiveFlyId") == ActiveFlyId then
				getgenv().TaskiumActiveFlyId = nil
			end
			local BedwarsReference = rawget(getgenv(), "bedwars")
			local BalloonController = BedwarsReference and BedwarsReference.BalloonController
			if BalloonController and FlyOldDeflate then
				BalloonController.deflateBalloon = FlyOldDeflate
			end
			FlyOldDeflate = nil
		end

		ResetFlyState()
		ResetCharacter()
	end,
	ToolTip = "Makes you go zoom.",
	Toggles = {
		{
			Name = "TP Down",
			Function = function(Callback)
				FlyTPDown = Callback
				if not Callback then
					local _, _, RootPart = GetCharacterState()
					if FlyOldY and RootPart then
						RootPart.CFrame = RootPart.CFrame + Vector3.new(
							0,
							FlyOldY - RootPart.Position.Y,
							0
						)
					end
					ResetFlyState()
				end
			end,
			ToolTip = "TPs to ground every 2s to bypass anticheat, then back up."
		},
		{
			Name = "Show Fly Bar",
			Function = function(Callback)
				FlyShowBar = Callback
			end,
			ToolTip = "Shows the fly timer bar."
		}
	},
	Sliders = {
		{
			Name = "Speed",
			Min = 1,
			Max = 23,
			Default = 23,
			Function = function(Value)
				FlySpeedValue = Value
			end,
			ToolTip = "Horizontal fly speed."
		},
		{
			Name = "Vertical Speed",
			Min = 1,
			Max = 150,
			Default = 50,
			Function = function(Value)
				FlyVerticalSpeed = Value
			end,
			ToolTip = "Up/down speed. Space = up, Shift = down."
		}
	},
	Dropdowns = {}
})

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

LongJumpModule = TaskAPI.Categories.Movement:CreateModule({
	Name = "LongJump",
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
		local BedwarsReference = rawget(getgenv(), "bedwars")
		local SprintController = BedwarsReference and BedwarsReference.SprintController
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
			RootPart.AssemblyLinearVelocity = Vector3.new(
				0,
				24,
				0
			)
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

			local CurrentSpeed = LongJumpSpeed * CurrentSpeedMultiplier

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
	end,
	ToolTip = "Launches you farther forward!",
	Toggles = {
		{
			Name = "No Cooldown",
			Function = function(Callback)
				LJNoCooldown = Callback
				if Callback then
					LongJumpNextUse = 0
					LJCooldownNotification = nil
				end
			end,
			ToolTip = "Removes the LongJump cooldown."
		}
	},
	Sliders = {},
	Dropdowns = {}
})

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
	ToolTip = "Changes your local gravity.",
	Sliders = {
		{
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
		}
	},
	Toggles = {},
	Dropdowns = {}
})

local ScaffoldModule
local ScaffoldExpand = 1
local ScaffoldTower = true
local ScaffoldDownwards = true
local ScaffoldDiagonal = true

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

local function RoundToBlockGrid(Position)
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

local function GetPlacedBlockAt(BedwarsReference, Position)
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

local function GetBlocksInPoints(BedwarsReference, StartPoint, EndPoint)
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
	local CheckAdjacentFunction = rawget(getgenv(), "checkAdjacent")
	if type(CheckAdjacentFunction) == "function" then
		local Success, Result = pcall(CheckAdjacentFunction, Position)
		if Success then
			return Result
		end
	end

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

local function GetScaffoldBlock(BedwarsReference, Store)
	if Store
		and Store.hand
		and Store.hand.toolType == "block"
		and Store.hand.tool
		and Store.hand.tool.Name then
		return Store.hand.tool.Name, Store.hand.amount or 0
	end

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

	return nil, 0
end

ScaffoldModule = TaskAPI.Categories.Movement:CreateModule({
	Name = "Scaffold",
	Function = function(Enabled, RunId, Module)
		local SwitchTime = tick()
		local IsScaffolding = false

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

		local function StopScaffold()
			if IsScaffolding then
				IsScaffolding = false
			end
		end

		Module:Clean(StopScaffold)

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
					local BlockItemType = GetScaffoldBlock(BedwarsNow, Store)

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
									SwitchTime = tick() + 0.25
									IsScaffolding = true
								end
							end

							LastPosition = CurrentPosition
						end
					end
				end

				if IsScaffolding and tick() > SwitchTime then
					IsScaffolding = false
				end

				task.wait(0.03)
			until not Module:IsActive(RunId)
		end)
	end,
	ToolTip = "Helps you make bridges/scaffold walk.",
	Toggles = {
		{
			Name = "Tower",
			Function = function(Callback)
				ScaffoldTower = Callback
			end,
			Default = true,
			ToolTip = "Jumps upward while scaffolding when Space is held."
		},
		{
			Name = "Downwards",
			Function = function(Callback)
				ScaffoldDownwards = Callback
			end,
			Default = true,
			ToolTip = "Places lower when LeftShift is held."
		},
		{
			Name = "Diagonal",
			Function = function(Callback)
				ScaffoldDiagonal = Callback
			end,
			Default = true,
			ToolTip = "Keeps diagonal scaffold placement stable."
		}
	},
	Sliders = {
		{
			Name = "Expand",
			Min = 1,
			Max = 6,
			Default = 1,
			Function = function(Value)
				ScaffoldExpand = Value
			end,
			ToolTip = "How far ahead to place blocks."
		}
	},
	Dropdowns = {}
})

local ESPModule
local ESPShowTeammates = false
local ESPUseTeamColors = true

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
	if ESPUseTeamColors and Player and Player.TeamColor then
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

			local Character = Player.Character
			local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
			local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
			local ShouldShow = Character ~= nil
				and Humanoid ~= nil
				and Humanoid.Health > 0
				and RootPart ~= nil
				and (ESPShowTeammates or not IsTeammate(Player))

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

			local LocalCharacter = LocalPlayer and LocalPlayer.Character
			local LocalRootPart = LocalCharacter and LocalCharacter:FindFirstChild("HumanoidRootPart")
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
	ToolTip = "Highlights players through walls.",
	Toggles = {
		{
			Name = "Teammates",
			Function = function(Callback)
				ESPShowTeammates = Callback
			end,
			ToolTip = "Shows teammates too."
		},
		{
			Name = "Team Colors",
			Function = function(Callback)
				ESPUseTeamColors = Callback
			end,
			ToolTip = "Uses Roblox team colors when available."
		}
	}
})

local SettingsModule
local ArraylistToggle
local ArraylistTextSize = 16
local ArraylistGuiInstance = nil
local ArraylistAnimationConnection = nil
local ArraylistLayoutSignature = nil

local function StopArraylist()
	if ArraylistAnimationConnection then
		ArraylistAnimationConnection:Disconnect()
		ArraylistAnimationConnection = nil
	end

	if ArraylistGuiInstance then
		ArraylistGuiInstance:Destroy()
		ArraylistGuiInstance = nil
	end

	ArraylistLayoutSignature = nil
end

local function StartArraylist()
	StopArraylist()

	local ArraylistGui = Instance.new("ScreenGui")
	ArraylistGui.Name = "TaskiumArraylist"
	ArraylistGui.ResetOnSpawn = false
	ArraylistGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ArraylistGui.Parent = PlayerGui
	ArraylistGuiInstance = ArraylistGui

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
			local LeftWidth = TextService:GetTextSize(Left.Name, ArraylistTextSize, Enum.Font.GothamBold, Vector2.new(1000, 24)).X
			local RightWidth = TextService:GetTextSize(Right.Name, ArraylistTextSize, Enum.Font.GothamBold, Vector2.new(1000, 24)).X

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
		local SignatureParts = { tostring(ArraylistTextSize) }

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
		local TextSize = ArraylistTextSize
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

	ArraylistAnimationConnection = RunService.RenderStepped:Connect(function()
		local EnabledModules = GetEnabledModules()
		local CurrentLayoutSignature = BuildArraylistSignature(EnabledModules)

		if CurrentLayoutSignature ~= ArraylistLayoutSignature then
			ArraylistLayoutSignature = CurrentLayoutSignature
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
	ToolTip = "Contains persistent Taskium settings.",
	Toggles = {
		{
			Name = "Arraylist",
			Function = function(Enabled)
				if Enabled then
					StartArraylist()
				else
					StopArraylist()
				end
			end,
			ToolTip = "Displays enabled modules in the top-right corner."
		}
	},
	Sliders = {
		{
			Name = "Text Size",
			Min = 12,
			Max = 30,
			Default = 16,
			Function = function(Value)
				ArraylistTextSize = Value
				ArraylistLayoutSignature = nil
			end,
			ToolTip = "Adjusts the Arraylist text size."
		}
	}
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

local KillauraModule
local KillauraHitFixEnabled = true
local KillauraOriginalClientGet
local KillauraSwingRange = 22
local KillauraAttackRange = 22
local KillauraUpdateRate = 120
local KillauraAttackMode = "Switch"
local KillauraMaxTargets = 5
local KillauraSwingInterval = 0.11
local KillauraAnimationEnabled = false
local KillauraAnimationMode = "Normal"
local KillauraAnimationSpeed = 1
local KillauraAnimationResetTween
local KillauraCurrentAnimationTween
local KillauraBaseC0
local KillauraAnimationToken = 0
local KillauraAnimationBusy = false

local KillauraAnimations = {
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
	}
}

local function GetKillauraWrist()
	local Camera = workspace.CurrentCamera
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

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

	local BedwarsReference = ExistingBedwars or {
		Client = ClientRemoteLibrary,
		AppController = AppControllerSuccess and AppController or nil,
		BlockController = BlockControllerSuccess and BlockController or nil,
		BlockEngine = BlockEngineSuccess and BlockEngine or nil,
		BlockPlacer = BlockPlacerSuccess and BlockPlacer or nil,
		BowConstantsTable = BowConstantsSuccess and BowConstantsTable or { RelX = 0, RelY = 0, RelZ = 0 },
		ClientDamageBlock = ClientDamageBlockSuccess and ClientDamageBlock or nil,
		Flamework = FlameworkSuccess and Flamework or nil,
		InventoryUtil = InventoryUtilSuccess and InventoryUtil or nil,
		ItemMeta = ItemMetaSuccess and ItemMeta or {},
		Knit = KnitClient,
		ProjectileMeta = ProjectileMetaSuccess and ProjectileMeta or nil,
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
	BedwarsReference.BowConstantsTable = BedwarsReference.BowConstantsTable or (BowConstantsSuccess and BowConstantsTable or { RelX = 0, RelY = 0, RelZ = 0 })
	BedwarsReference.ClientDamageBlock = BedwarsReference.ClientDamageBlock or (ClientDamageBlockSuccess and ClientDamageBlock or nil)
	BedwarsReference.Flamework = BedwarsReference.Flamework or (FlameworkSuccess and Flamework or nil)
	BedwarsReference.InventoryUtil = BedwarsReference.InventoryUtil or (InventoryUtilSuccess and InventoryUtil or nil)
	BedwarsReference.ItemMeta = next(BedwarsReference.ItemMeta or {}) and BedwarsReference.ItemMeta or (ItemMetaSuccess and ItemMeta or {})
	BedwarsReference.Knit = BedwarsReference.Knit or KnitClient
	BedwarsReference.ProjectileMeta = BedwarsReference.ProjectileMeta or (ProjectileMetaSuccess and ProjectileMeta or nil)
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

GetGroundHitRemote = function()
	local BedwarsReference, RemoteTable = EnsureBedwarsRuntime()
	if not (BedwarsReference and BedwarsReference.Client and RemoteTable and RemoteTable.GroundHit) then
		return nil
	end

	local Success, RemoteInstance = pcall(function()
		return BedwarsReference.Client:Get(RemoteTable.GroundHit).instance
	end)
	if not Success or not RemoteInstance then
		return nil
	end

	return RemoteInstance
end

local function GetSwordData()
	local Store = CreateTaskiumStore()
	local BedwarsReference = EnsureBedwarsRuntime()
	if not (Store and BedwarsReference and BedwarsReference.ItemMeta) then
		return nil
	end

	local SwordData = Store.tools.sword
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
	local Meta = BedwarsReference.ItemMeta[ToolName]
	if not (Meta and Meta.sword) then
		return nil
	end

	return SwordData, Meta
end

local function CollectKillauraTargets(LocalRootPart)
	local Targets = {}
	local LocalFacing = LocalRootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	local AddedCharacters = {}

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
		if Distance > KillauraSwingRange then
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
	else
		local Character = LocalPlayer and LocalPlayer.Character
		local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
		if Humanoid and SwordData.tool.Parent ~= Character then
			pcall(function()
				Humanoid:EquipTool(SwordData.tool)
			end)
		end
	end

	local TargetPosition = TargetData.RootPart.Position
	local Direction = CFrame.lookAt(SelfPosition, TargetPosition).LookVector
	local Position = SelfPosition + Direction * math.max(Delta.Magnitude - 14.4, 0)

	pcall(function()
		BedwarsReference.SwordController.lastAttack = workspace:GetServerTimeNow()
	end)

	Store.attackReach = math.floor(Delta.Magnitude * 100) / 100
	Store.attackReachUpdate = tick() + 1

	return pcall(function()
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
end

KillauraModule = TaskAPI.Categories.Combat:CreateModule({
	Name = "Killaura",
	Function = function(Enabled, RunId, Module)
		local KillauraClient = nil
		local AnimationActiveUntil = 0

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

		local function RemoveKillauraHitFixHook()
			if KillauraOriginalClientGet and KillauraClient then
				KillauraClient.Get = KillauraOriginalClientGet
			end
			KillauraOriginalClientGet = nil
			KillauraClient = nil
		end

		local function ApplyKillauraHitFixHook(BedwarsReference, RemoteTable)
			if not KillauraHitFixEnabled then
				RemoveKillauraHitFixHook()
				return
			end

			if not (BedwarsReference and BedwarsReference.Client and RemoteTable and RemoteTable.AttackEntity) then
				return
			end

			local Client = BedwarsReference.Client
			if KillauraClient ~= Client then
				RemoveKillauraHitFixHook()
				KillauraClient = Client
			end

			if not KillauraOriginalClientGet then
				KillauraOriginalClientGet = Client.Get
			end

			local OriginalGet = KillauraOriginalClientGet
			Client.Get = function(Self, RemoteName)
				local Call = OriginalGet(Self, RemoteName)
				if not Module:IsActive(RunId) or not KillauraHitFixEnabled or RemoteName ~= RemoteTable.AttackEntity then
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
		end

		if not Enabled then
			RemoveKillauraHitFixHook()
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
			RemoveKillauraHitFixHook()
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
				ApplyKillauraHitFixHook(BedwarsReference, RemoteTable)

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

						local Targets = CollectKillauraTargets(RootPart)
						if #Targets > 0 then
							AnimationActiveUntil = tick() + 0.2
							local SelfPosition = RootPart.Position

							if tick() > SwitchCooldown and KillauraAttackMode == "Switch" then
								SwitchCooldown = tick() + 0.7
								TargetIndex = TargetIndex + 1
							end

							if not Targets[TargetIndex] then
								TargetIndex = 1
							end

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

								if CanAttackNow and PerformKillauraAttack(TargetData, SwordData, SwordMeta, AttackRemote, SelfPosition) then
									LastAttackTick = tick()
									AttackedCount = AttackedCount + 1
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
	ToolTip = "Attack players around you without aiming at them.",
	Sliders = {
		{
			Name = "Swing Range",
			Min = 1,
			Max = 22,
			Default = 22,
			Function = function(Value)
				KillauraSwingRange = Value
			end,
			ToolTip = "How far Killaura can look for targets."
		},
		{
			Name = "Attack Range",
			Min = 1,
			Max = 22,
			Default = 22,
			Function = function(Value)
				KillauraAttackRange = Value
			end,
			ToolTip = "How far Killaura can hit targets."
		},
		{
			Name = "Max Targets",
			Min = 1,
			Max = 5,
			Default = 5,
			Function = function(Value)
				KillauraMaxTargets = Value
			end,
			ToolTip = "Maximum targets used in Multi mode."
		},
		{
			Name = "Animation Speed",
			Min = 1,
			Max = 20,
			Default = 10,
			Function = function(Value)
				KillauraAnimationSpeed = Value / 10
			end,
			ToolTip = "Changes how fast the custom sword animation plays."
		}
	},
	Toggles = {
		{
			Name = "Custom Animation",
			Function = function(Value)
				KillauraAnimationEnabled = Value
				if not Value then
					KillauraAnimationBusy = false
					ResetKillauraAnimation(0.1)
				end
			end,
			ToolTip = "Plays a custom sword animation while Killaura is attacking."
		},
		{
			Name = "HitFix",
			Function = function(Value)
				KillauraHitFixEnabled = Value
			end,
			ToolTip = "Uses the BedWars-style attack remote hook for better hit registration."
		}
	},
	Dropdowns = {
		{
			Name = "Attack Mode",
			List = { "Single", "Multi", "Switch" },
			Function = function(Value)
				KillauraAttackMode = Value
			end,
			ToolTip = "Single attacks one target, Multi attacks several, Switch rotates targets."
		},
		{
			Name = "Animation Mode",
			List = { "Normal", "Random", "Horizontal Spin", "Vertical Spin", "Exhibition", "Exhibition Old" },
			Function = function(Value)
				KillauraAnimationMode = Value
			end,
			ToolTip = "Changes the custom sword swing animation."
		}
	}
})

local BreakerModule
local BreakerRange = 30
local BreakerBreakSpeed = 0.25
local BreakerUpdateRate = 60
local BreakerBreakBed = true
local BreakerBreakTesla = true
local BreakerBreakHive = true
local BreakerBreakLuckyBlock = true
local BreakerBreakIronOre = true
local BreakerAnimation = false
local BreakerInstantBreak = false
local BreakerSelfBreak = false
local BreakerEffects = true

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

	AddTagged("bed", BreakerBreakBed)
	AddTagged("tesla-trap", BreakerBreakTesla, function(Object)
		local Player = Players:GetPlayerByUserId(Object:GetAttribute("PlacedByUserId") or 0)
		return not Player or not IsSameTeam(LocalPlayer, Player)
	end)
	AddTagged("beehive", BreakerBreakHive, function(Object)
		local Player = Players:GetPlayerByUserId(Object:GetAttribute("PlacedByUserId") or 0)
		return not Player or not IsSameTeam(LocalPlayer, Player)
	end)
	AddTagged("LuckyBlock", BreakerBreakLuckyBlock)
	AddTagged("iron_ore_mesh_block", BreakerBreakIronOre)

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
			if (BlockPosition - LocalPosition).Magnitude < BreakerRange and BlockController:isBlockBreakable({ blockPosition = BlockPosition / 3 }, LocalPlayer) then
				if not BreakerSelfBreak and Block:GetAttribute("PlacedByUserId") == LocalPlayer.UserId then
					continue
				end

				if (Block:GetAttribute("BedShieldEndTime") or 0) > workspace:GetServerTimeNow() then
					continue
				end

				BreakBlockFunction(Block, BreakerEffects, BreakerAnimation, nil, BreakerInstantBreak, false, "Health", 360)
				task.wait(BreakerInstantBreak and 0 or BreakerBreakSpeed)
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
				task.wait(1 / math.max(BreakerUpdateRate, 1))
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
	ToolTip = "Breaks nearby BedWars blocks automatically.",
	Sliders = {
		{
			Name = "Break Range",
			Min = 1,
			Max = 30,
			Default = 30,
			Function = function(Value)
				BreakerRange = Value
			end,
			ToolTip = "How far Breaker can look for blocks."
		},
		{
			Name = "Break Speed",
			Min = 0,
			Max = 30,
			Default = 25,
			Function = function(Value)
				BreakerBreakSpeed = Value / 100
			end,
			ToolTip = "Delay between block break attempts."
		},
		{
			Name = "Update Rate",
			Min = 1,
			Max = 120,
			Default = 60,
			Function = function(Value)
				BreakerUpdateRate = Value
			end,
			ToolTip = "How often Breaker scans for blocks."
		}
	},
	Toggles = {
		{
			Name = "Break Bed",
			Default = true,
			Function = function(Value)
				BreakerBreakBed = Value
			end
		},
		{
			Name = "Break Tesla",
			Default = true,
			Function = function(Value)
				BreakerBreakTesla = Value
			end
		},
		{
			Name = "Break Hive",
			Default = true,
			Function = function(Value)
				BreakerBreakHive = Value
			end
		},
		{
			Name = "Break Lucky Block",
			Default = true,
			Function = function(Value)
				BreakerBreakLuckyBlock = Value
			end
		},
		{
			Name = "Break Iron Ore",
			Default = true,
			Function = function(Value)
				BreakerBreakIronOre = Value
			end
		},
		{
			Name = "Animation",
			Function = function(Value)
				BreakerAnimation = Value
			end
		},
		{
			Name = "Instant Break",
			Function = function(Value)
				BreakerInstantBreak = Value
			end
		},
		{
			Name = "Self Break",
			Function = function(Value)
				BreakerSelfBreak = Value
			end
		},
		{
			Name = "Show Effects",
			Default = true,
			Function = function(Value)
				BreakerEffects = Value
			end
		}
	}
})

local VelocityModule
local HorizontalStrength = 0
local VerticalStrength = 0
local Chance = 100
local rand = Random.new()
local old = nil
local KnockbackUtil = nil

VelocityModule = TaskAPI.Categories.Combat:CreateModule({
	Name = "Velocity",
	Function = function(Enabled, RunId, Module)
		print(Enabled, "Velocity module state")

		if not KnockbackUtil then
			local replicatedStorage = game:GetService("ReplicatedStorage")
			local ok, result = pcall(function()
				return require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil
			end)
			if ok and result then
				KnockbackUtil = result
				print("KnockbackUtil loaded:", tostring(KnockbackUtil))
			else
				warn("KnockbackUtil failed to load:", tostring(result))
				return
			end
		end

		if Enabled then
			old = KnockbackUtil.applyKnockback
			KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
				if not Module:IsActive(RunId) then
					return old(root, mass, dir, knockback, ...)
				end

				if rand:NextNumber(0, 100) > Chance then
					return old(root, mass, dir, knockback, ...)
				end

				if HorizontalStrength == 0 and VerticalStrength == 0 then
					return
				end

				knockback = knockback or {}
				knockback.horizontal = (knockback.horizontal or 1) * (HorizontalStrength / 100)
				knockback.vertical = (knockback.vertical or 1) * (VerticalStrength / 100)

				return old(root, mass, dir, knockback, ...)
			end
		else
			if old and KnockbackUtil then
				KnockbackUtil.applyKnockback = old
				old = nil
			end
		end
	end,
	ToolTip = "Reduces knockback taken.",
	Toggles = {},
	Sliders = {
		{
			Name = "Horizontal",
			Min = 0,
			Max = 100,
			Default = 0,
			Function = function(Value)
				HorizontalStrength = Value
			end,
			ToolTip = "0 = no horizontal KB, 100 = full."
		},
		{
			Name = "Vertical",
			Min = 0,
			Max = 100,
			Default = 0,
			Function = function(Value)
				VerticalStrength = Value
			end,
			ToolTip = "0 = no vertical KB, 100 = full."
		},
		{
			Name = "Chance",
			Min = 0,
			Max = 100,
			Default = 100,
			Function = function(Value)
				Chance = Value
			end,
			ToolTip = "% chance to block KB. 100 = always."
		}
	},
	Dropdowns = {}
})

return TaskAPI
