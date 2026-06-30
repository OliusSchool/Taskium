local Taskium = (shared and shared.Taskium) or getgenv().Taskium
local Main = Taskium.ExecuteFile("Taskium/Games/Bedwars/Main.lua")

local TaskAPI = Main.TaskAPI

local bedwars = Main.bedwars

local runService = Main.runService
local lplr = Main.lplr

local characterState = Main.characterState

local getSpeed = Main.getSpeed

local Run = Main.Run or function(func)
	return func()
end

local SpeedModule
Run(function()
	local speed = 23
	local wallCheck = true
	local raycast = RaycastParams.new()
	local raycastFilter = {}
	local oldFriction = {}

	raycast.RespectCanCollide = true

	local function setFriction(enabled)
		if enabled then
			local character = lplr and lplr.Character
			if character then
				for _, part in ipairs(character:GetChildren()) do
					if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and not oldFriction[part] then
						oldFriction[part] = part.CustomPhysicalProperties or "none"
						part.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
					end
				end
			end
			return
		end

		for part, properties in pairs(oldFriction) do
			if part and part.Parent then
				part.CustomPhysicalProperties = properties ~= "none" and properties or nil
			end
		end
		table.clear(oldFriction)
	end

	local function resetSpeed()
		pcall(function()
			debug.setconstant(bedwars.WindWalkerController.updateSpeed, 7, "moveSpeedMultiplier")
		end)
		setFriction(false)

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

	SpeedModule = TaskAPI.Categories.Movement:CreateModule({
		Name = "Speed",
		Function = function(callback, runId, module)
			if not callback then
				resetSpeed()
				return
			end

			setFriction(true)
			pcall(function()
				debug.setconstant(bedwars.WindWalkerController.updateSpeed, 7, "constantSpeedMultiplier")
			end)

			module:Clean(resetSpeed)
			module:Clean(runService.PreSimulation:Connect(function(deltaTime)
				if not module:IsActive(runId) then
					return
				end

				local character, humanoid, rootPart = characterState()
				if not (character and humanoid and rootPart and humanoid.Health > 0) then
					return
				end

				local fly = TaskAPI.Modules and TaskAPI.Modules.Fly
				if fly and fly.Enabled then
					return
				end

				if bedwars.StatefulEntityKnockbackController then
					pcall(function()
						bedwars.StatefulEntityKnockbackController.lastImpulseTime = math.huge
					end)
				end

				if humanoid:GetState() == Enum.HumanoidStateType.Climbing then
					return
				end

				local moveDir = humanoid.MoveDirection
				local speedNow = getSpeed and getSpeed() or 20
				local delta = moveDir * math.max(speed - speedNow, 0) * deltaTime

				if wallCheck then
					raycastFilter[1] = character
					raycastFilter[2] = workspace.CurrentCamera
					raycast.FilterDescendantsInstances = raycastFilter
					raycast.CollisionGroup = rootPart.CollisionGroup
					local wall = workspace:Raycast(rootPart.Position, delta, raycast)
					if wall then
						delta = (wall.Position + wall.Normal) - rootPart.Position
					end
				end

				rootPart.CFrame = rootPart.CFrame + delta
				rootPart.AssemblyLinearVelocity = (moveDir * math.min(speedNow, speed)) + Vector3.new(0, rootPart.AssemblyLinearVelocity.Y, 0)
			end))
		end,
		ToolTip = "Increases your speed."
	})

	SpeedModule:CreateSlider({
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
		ToolTip = "Adjusts your speed value."
	})
end)

return SpeedModule
