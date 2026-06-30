local Taskium = (shared and shared.Taskium) or getgenv().Taskium
local Main = Taskium.ExecuteFile("Taskium/Games/Bedwars/Main.lua")

local TaskAPI = Main.TaskAPI

local bedwars = Main.bedwars
local bedwarsStore = Main.bedwarsStore

local runService = Main.runService
local inputService = Main.inputService
local lplr = Main.lplr

local characterState = Main.characterState
local getSpeed = Main.getSpeed

local Run = Main.Run or function(func)
	return func()
end

local FlyModule
Run(function()
	local speed = 23
	local vertical = 50
	local pop = true
	local showBar = true
	local tpDown = true
	local noFallVelocity = true
	local up = 0
	local down = 0
	local tpTick = 0
	local tpToggle = true
	local oldY
	local oldDeflate
	local airborneAt = tick()
	local raycast = RaycastParams.new()
	local groundRaycast = RaycastParams.new()
	local raycastFilter = {}
	local groundRaycastFilter = {}
	local barFrame
	local barGui
	local barFill
	local barTimer
	local barFillState
	local barText
	local oldFriction = {}
	local frictionConnection

	raycast.RespectCanCollide = true
	groundRaycast.RespectCanCollide = true

	local function resetState(resetAir)
		up = 0
		down = 0
		tpTick = tick()
		tpToggle = true
		oldY = nil
		if resetAir ~= false then
			airborneAt = tick()
		end
	end

	local function setFriction(enabled)
		if enabled then
			local character, _, rootPart = characterState()
			local function edit(part)
				if part:IsA("BasePart") and part ~= rootPart and not oldFriction[part] then
					oldFriction[part] = part.CustomPhysicalProperties or "none"
					part.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
				end
			end

			if character then
				for _, part in ipairs(character:GetDescendants()) do
					edit(part)
				end
				if frictionConnection then
					frictionConnection:Disconnect()
				end
				frictionConnection = character.DescendantAdded:Connect(edit)
			end
			return
		end

		if frictionConnection then
			frictionConnection:Disconnect()
			frictionConnection = nil
		end
		for part, properties in pairs(oldFriction) do
			if part and part.Parent then
				part.CustomPhysicalProperties = properties ~= "none" and properties or nil
			end
		end
		table.clear(oldFriction)
	end

	local function resetMovement()
		local _, humanoid = characterState()
		if humanoid then
			humanoid.WalkSpeed = 16
		end
		if bedwars.SprintController and type(bedwars.SprintController.setSpeed) == "function" then
			pcall(function()
				bedwars.SprintController:setSpeed(20)
			end)
		end
	end

	local function hasItem(name)
		local items = ((bedwarsStore.inventory or {}).inventory or {}).items or {}
		for _, item in items do
			if item and item.itemType == name then
				return true
			end
		end
		return false
	end

	local function makeBar()
		if barFrame and barFrame.Parent then
			return barFrame
		end

		local parent = TaskAPI.NotificationGui and TaskAPI.NotificationGui.Parent
		if not parent then
			return nil
		end

		if barGui and barGui.Parent then
			barGui:Destroy()
		end

		for _, name in ipairs({ "TaskiumFlyBarGui", "FlyBarGui" }) do
			local oldGui = parent:FindFirstChild(name)
			if oldGui then
				oldGui:Destroy()
			end
		end

		local gui = Instance.new("ScreenGui")
		gui.Name = "FlyBarGui"
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = parent

		local bar = Instance.new("Frame")
		bar.Name = "FlyBar"
		bar.AnchorPoint = Vector2.new(0.5, 0)
		bar.Position = UDim2.new(0.5, 0, 1, -200)
		bar.Size = UDim2.new(0.2, 0, 0, 20)
		bar.BackgroundTransparency = 0.5
		bar.Visible = false
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = Color3.new()
		bar.ClipsDescendants = true
		bar.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = bar

		local fill = bar:Clone()
		fill.Name = "Frame"
		fill.AnchorPoint = Vector2.new(0, 0)
		fill.Position = UDim2.new(0, 0, 0, 0)
		fill.Size = UDim2.new(1, 0, 1, 0)
		fill.BackgroundTransparency = 0
		fill.Visible = true
		fill.Parent = bar

		local timer = Instance.new("TextLabel")
		timer.Name = "Timer"
		timer.Text = "2s"
		timer.Font = Enum.Font.Arimo
		timer.TextStrokeTransparency = 0
		timer.TextColor3 = Color3.new(0.9, 0.9, 0.9)
		timer.TextSize = 20
		timer.Size = UDim2.new(1, 0, 1, 0)
		timer.BackgroundTransparency = 1
		timer.Position = UDim2.new(0, 0, -1, 0)
		timer.Parent = bar

		barGui = gui
		barFrame = bar
		barFill = fill
		barTimer = timer
		barFillState = nil
		barText = nil
		return bar
	end

	local function updateBarVisible(bar, allowed)
		if bar then
			bar.Visible = FlyModule and FlyModule.Enabled and showBar and not allowed
		end
	end

	local function inflate()
		local character = lplr and lplr.Character
		local balloonController = bedwars.BalloonController
		if character
			and balloonController
			and type(balloonController.inflateBalloon) == "function"
			and (character:GetAttribute("InflatedBalloons") or 0) == 0
			and hasItem("balloon") then
			pcall(function()
				balloonController:inflateBalloon()
			end)
		end
	end

	local function moveDirection(humanoid)
		local moveDir = humanoid and humanoid.MoveDirection or Vector3.zero
		if moveDir.Magnitude > 0.001 then
			return moveDir
		end

		local camera = workspace.CurrentCamera
		if not camera then
			return Vector3.zero
		end

		local forward = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
		local right = camera.CFrame.RightVector * Vector3.new(1, 0, 1)
		local dir = Vector3.zero

		if forward.Magnitude > 0.001 then
			forward = forward.Unit
			if inputService:IsKeyDown(Enum.KeyCode.W) then dir += forward end
			if inputService:IsKeyDown(Enum.KeyCode.S) then dir -= forward end
		end
		if right.Magnitude > 0.001 then
			right = right.Unit
			if inputService:IsKeyDown(Enum.KeyCode.D) then dir += right end
			if inputService:IsKeyDown(Enum.KeyCode.A) then dir -= right end
		end

		return dir.Magnitude > 0.001 and dir.Unit or Vector3.zero
	end

	local function velocityNoFall(humanoid, rootPart, force)
		local match = bedwars and bedwars.Knit and bedwars.Knit.Controllers and bedwars.Knit.Controllers.MatchController
		if match and type(match.getMatchState) == "function" and match:getMatchState() ~= 1 then
			return
		end

		if humanoid and rootPart and (force or rootPart.Velocity.Y < -35) then
			local velocity = rootPart.Velocity
			rootPart.Velocity = Vector3.new(0, 2.5, 0)
			humanoid:ChangeState(Enum.HumanoidStateType.PlatformStanding)
			runService.PreRender:Wait()
			if rootPart and rootPart.Parent then
				rootPart.Velocity = velocity
			end
		end
	end

	local function cleanup()
		local balloonController = bedwars.BalloonController
		if balloonController and oldDeflate then
			balloonController.deflateBalloon = oldDeflate
		end

		if pop then
			local character = lplr and lplr.Character
			if character and balloonController and type(balloonController.deflateBalloon) == "function" and (character:GetAttribute("InflatedBalloons") or 0) > 0 then
				for _ = 1, 3 do
					pcall(function()
						balloonController:deflateBalloon()
					end)
				end
			end
		end

		oldDeflate = nil
		setFriction(false)
		if barFrame then
			barFrame.Visible = false
		end
		barFillState = nil
		barText = nil
		resetState(false)
		resetMovement()
	end

	FlyModule = TaskAPI.Categories.Movement:CreateModule({
		Name = "Fly",
		Function = function(callback, runId, module)
			local balloonController = bedwars.BalloonController
			local progressBar = makeBar()

			local function flyAllowed(character)
				return ((character and ((character:GetAttribute("InflatedBalloons") or 0) > 0)) or bedwarsStore.matchState == 2)
			end

			if not callback then
				cleanup()
				return
			end

			resetState(false)
			setFriction(true)
			if balloonController then
				oldDeflate = balloonController.deflateBalloon
				balloonController.deflateBalloon = function() end
			end
			inflate()

			updateBarVisible(progressBar, flyAllowed(lplr and lplr.Character))
			module:Clean(cleanup)

			module:Clean(lplr.CharacterAdded:Connect(function()
				resetState(true)
				task.defer(function()
					if module:IsActive(runId) then
						inflate()
					end
				end)
			end))

			local character = lplr and lplr.Character
			if character then
				module:Clean(character:GetAttributeChangedSignal("InflatedBalloons"):Connect(function()
					if module:IsActive(runId) then
						inflate()
					end
				end))
			end

			module:Clean(runService.Heartbeat:Connect(function()
				if not (module:IsActive(runId) and noFallVelocity) then
					return
				end

				local _, humanoid, rootPart = characterState()
				if humanoid and rootPart and humanoid.Health > 0 then
					velocityNoFall(humanoid, rootPart)
				end
			end))

			module:Clean(runService.PreSimulation:Connect(function(deltaTime)
				if not module:IsActive(runId) then
					return
				end

				local currentCharacter, humanoid, rootPart = characterState()
				if not (currentCharacter and humanoid and rootPart and humanoid.Health > 0) then
					return
				end

				local allowed = flyAllowed(currentCharacter)
				local verticalInput = 0
				if up == 1 or inputService:IsKeyDown(Enum.KeyCode.Space) or inputService:IsKeyDown(Enum.KeyCode.ButtonA) then
					verticalInput += 1
				end
				if down == -1 or inputService:IsKeyDown(Enum.KeyCode.LeftShift) or inputService:IsKeyDown(Enum.KeyCode.ButtonL2) then
					verticalInput -= 1
				end

				local moveDir = moveDirection(humanoid)
				local mass = (1.5 + (allowed and 6 or 0) * ((tick() % 0.4 < 0.2) and -1 or 1)) + (verticalInput * vertical)
				local velo = getSpeed and getSpeed() or 20
				local dest = moveDir * math.max(speed - velo, 0) * deltaTime

				raycastFilter[1] = currentCharacter
				raycastFilter[2] = workspace.CurrentCamera
				raycast.FilterDescendantsInstances = raycastFilter
				raycast.CollisionGroup = rootPart.CollisionGroup
				local wall = workspace:Raycast(rootPart.Position, dest, raycast)
				if wall then
					dest = (wall.Position + wall.Normal) - rootPart.Position
				end

				if humanoid.FloorMaterial ~= Enum.Material.Air and oldY == nil then
					airborneAt = tick()
					tpToggle = true
					tpTick = tick()
				end

				if progressBar and barFill then
					updateBarVisible(progressBar, allowed)
					progressBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					barFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				end

				if not allowed and progressBar and progressBar.Visible and barTimer and barFill then
					groundRaycastFilter[1] = currentCharacter
					groundRaycastFilter[2] = workspace.CurrentCamera
					groundRaycast.FilterDescendantsInstances = groundRaycastFilter
					groundRaycast.CollisionGroup = rootPart.CollisionGroup
					local now = tick()
					local airTime = now + (2 + (airborneAt - now))
					local onGround = workspace:Raycast(rootPart.Position, Vector3.new(0, -4.5, 0), groundRaycast)
					local nextFillState = onGround and "full" or "empty"
					if barFillState ~= nextFillState then
						barFillState = nextFillState
						barFill:TweenSize(
							onGround and UDim2.new(1, 0, 0, 20) or UDim2.new(0, 0, 0, 20),
							Enum.EasingDirection.InOut,
							Enum.EasingStyle.Linear,
							onGround and 0 or math.max(airTime - now, 0),
							true
						)
					end

					local nextText = math.max(onGround and 2.5 or math.floor((airTime - now) * 10) / 10, 0) .. "s"
					if barText ~= nextText then
						barText = nextText
						barTimer.Text = nextText
					end
				end

				if not allowed and tpDown then
					local airLeft = tick() - airborneAt
					if tpToggle then
						if airLeft > 2 then
							if not oldY then
								oldY = rootPart.Position.Y
							end
							local ground = workspace:Raycast(rootPart.Position, Vector3.new(0, -1000, 0), raycast)
							if ground then
								if noFallVelocity then
									task.spawn(velocityNoFall, humanoid, rootPart, true)
								end
								rootPart.CFrame = CFrame.lookAlong(Vector3.new(rootPart.Position.X, ground.Position.Y + humanoid.HipHeight, rootPart.Position.Z), rootPart.CFrame.LookVector)
								tpTick = tick() + 0.11
								tpToggle = false
								mass = 0
							end
					end
					elseif oldY then
						if tpTick < tick() then
							if noFallVelocity then
								task.spawn(velocityNoFall, humanoid, rootPart, true)
							end
							rootPart.CFrame = CFrame.lookAlong(Vector3.new(rootPart.Position.X, oldY, rootPart.Position.Z), rootPart.CFrame.LookVector)
							airborneAt = tick()
							tpTick = tick()
							tpToggle = true
							oldY = nil
						else
							mass = 0
						end
					end
				end

				rootPart.CFrame = rootPart.CFrame + dest
				rootPart.AssemblyLinearVelocity = (moveDir * velo) + Vector3.new(0, mass, 0)
			end))

			module:Clean(inputService.InputBegan:Connect(function(input)
				if inputService:GetFocusedTextBox() then
					return
				end

				if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
					up = 1
				elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
					down = -1
				end
			end))

			module:Clean(inputService.InputEnded:Connect(function(input)
				if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
					up = 0
				elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
					down = 0
				end
			end))

			if inputService.TouchEnabled then
				pcall(function()
					local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
					module:Clean(jumpButton:GetPropertyChangedSignal("ImageRectOffset"):Connect(function()
						up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
					end))
				end)
			end
		end,
		ToolTip = "You can fly in the air that's polluted."
	})

	FlyModule:CreateSlider({
		Name = "Speed",
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(value)
			return value == 1 and "speed" or "speed"
		end,
		Function = function(value)
			speed = value
		end,
		ToolTip = "Adjusts your fly speed."
	})

	FlyModule:CreateSlider({
		Name = "Vertical Speed",
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(value)
			return value == 1 and "speed" or "speed"
		end,
		Function = function(value)
			vertical = value
		end,
		ToolTip = "Adjusts your fly vertical speed."
	})

	FlyModule:CreateToggle({
		Name = "Pop Balloons",
		Function = function(value)
			pop = value
		end,
		Default = true,
		ToolTip = "Pops your balloons when Fly turns off."
	})

	FlyModule:CreateToggle({
		Name = "Show Fly Bar",
		Function = function(value)
			showBar = value
			local bar = barFrame or makeBar()
			local character = lplr and lplr.Character
			local allowed = (character and ((character:GetAttribute("InflatedBalloons") or 0) > 0)) or bedwarsStore.matchState == 2
			updateBarVisible(bar, allowed)
		end,
		Default = true,
		ToolTip = "Progress Bar"
	})

	FlyModule:CreateToggle({
		Name = "TP Down",
		Function = function(value)
			tpDown = value
		end,
		Default = true,
		ToolTip = "Tp down"
	})

	FlyModule:CreateToggle({
		Name = "NoFall Velocity",
		Function = function(value)
			noFallVelocity = value
		end,
		Default = true,
		ToolTip = "Uses NoFall's Velocity method while Fly is enabled."
	})
end)

return FlyModule
