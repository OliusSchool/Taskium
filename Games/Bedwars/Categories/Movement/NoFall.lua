local Taskium = (shared and shared.Taskium) or getgenv().Taskium
local Main = Taskium.ExecuteFile("Taskium/Games/Bedwars/Main.lua")

local TaskAPI = Main.TaskAPI

local bedwars = Main.bedwars

local runService = Main.runService
local lplr = Main.lplr

local characterState = Main.characterState

local Run = Main.Run or function(func)
	return func()
end

local NoFallModule
Run(function()
	local mode = "Blink"
	local raycast = RaycastParams.new()
	local raycastFilter = {}
	local rates = {}
	local raknetHooked = false
	local state = {}

	raycast.RespectCanCollide = true

	local function setRates(physicsRate, senderRate)
		if type(setfflag) ~= "function" then return end
		if rates.Physics == physicsRate and rates.Sender == senderRate then return end
		pcall(setfflag, "PhysicsSenderMaxBandwidthBps", tostring(physicsRate))
		pcall(setfflag, "DataSenderRate", tostring(senderRate))
		rates.Physics = physicsRate
		rates.Sender = senderRate
	end

	local function resetRates()
		setRates(38760, 120)
		table.clear(rates)
	end

	local function raknetHook(packet)
		if packet.AsArray[1] ~= 0x1b then return end
		local data = packet.AsBuffer
		buffer.writef32(data, 13, 0)
		buffer.writef32(data, 17, 0)
		buffer.writef32(data, 21, 0)
		buffer.writef32(data, 25, 0)
		buffer.writef32(data, 29, 0)
		buffer.writef32(data, 33, 0)
		packet:SetData(data)
	end

	local function setRaknet(enabled)
		if enabled then
			if raknetHooked then return true end
			if not (buffer and raknet and raknet.add_send_hook and pcall(raknet.add_send_hook, function() end)) then
				TaskAPI.Notification("Taskium", "This feature requires RakNet.", 5, "Warning")
				return false
			end
			raknet.add_send_hook(raknetHook)
			raknetHooked = true
			return true
		end

		if raknetHooked and raknet and type(raknet.remove_send_hook) == "function" then
			pcall(raknet.remove_send_hook, raknetHook)
		end
		raknetHooked = false
		return true
	end

	local function castDown(character, rootPart, distance)
		local store = rawget(getgenv(), "store")
		if store and store.airRay then
			return workspace:Raycast(rootPart.Position, Vector3.new(0, -(distance or 60), 0), store.airRay)
		end

		raycastFilter[1] = character
		raycastFilter[2] = workspace.CurrentCamera
		raycast.FilterDescendantsInstances = raycastFilter
		raycast.CollisionGroup = rootPart.CollisionGroup
		return workspace:Raycast(rootPart.Position, Vector3.new(0, -(distance or 60), 0), raycast)
	end

	local function isGrounded(character, rootPart)
		return castDown(character, rootPart, 4.5) ~= nil
	end

	local function flyEnabled()
		local fly = TaskAPI.Modules and TaskAPI.Modules.Fly
		return fly and fly.Enabled
	end

	local function clearBlink()
		state.Blinking = false
		state.LastPulse = 0
		resetRates()
	end

	local function reset()
		clearBlink()
		setRaknet(false)
		table.clear(state)
		state.Grounded = true
	end

	local function pulse(module, runId)
		state.LastPulse = tick()
		setRates(38760, 60)
		task.defer(function()
			if module:IsActive(runId) and state.Blinking then
				setRates(0, 60)
			end
		end)
	end

	local function raknetNoFall(character, rootPart)
		clearBlink()

		local velocity = rootPart.AssemblyLinearVelocity
		if velocity.Y >= -10 then
			state.RakY = nil
			return
		end

		state.RakY = state.RakY or rootPart.Position.Y
		if ((state.RakY - rootPart.Position.Y) / 3) < 7 then return end
		if not castDown(character, rootPart, 99935) then return end
		if not raknetHooked and not setRaknet(true) then
			mode = "Blink"
		end
	end

	local function blinkNoFall(character, humanoid, rootPart, module, runId)
		if flyEnabled() then
			state.FallPos, state.FallY, state.Started = nil, nil, 0
			state.Grounded, state.Blocked, state.Fly = true, tick() + 0.6, true
			clearBlink()
			return
		end

		if state.Fly then
			state.Fly = false
			if humanoid.FloorMaterial == Enum.Material.Air then
				state.Blocked = 0
			end
		end

		local now = tick()
		if now < (state.Blocked or 0) then return end

		if isGrounded(character, rootPart) then
			if not state.Grounded then clearBlink() end
			state.FallPos, state.FallY, state.Started = rootPart.Position, rootPart.Position.Y, now
			state.Grounded = true
			return
		end

		if state.Grounded then
			state.FallPos, state.FallY, state.Started = rootPart.Position, rootPart.Position.Y, now
			state.Grounded = false
			state.Pulsed = {}
		end

		if not state.FallY or (now - (state.Started or 0)) < 0.1 or rootPart.AssemblyLinearVelocity.Y > 2 then return end

		local currentHeight = state.FallY - rootPart.Position.Y
		local ray = castDown(character, rootPart, math.max(60, currentHeight + 160))
		local totalHeight = ray and (state.FallY - ray.Position.Y) or currentHeight
		if totalHeight < 15 then return end

		state.Blinking = true
		local groundDistance = ray and (rootPart.Position.Y - ray.Position.Y) or math.huge
		local horizontal = (Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z) - Vector3.new(state.FallPos.X, 0, state.FallPos.Z)).Magnitude
		local progress = math.clamp(currentHeight / math.max(totalHeight, 1), 0, 1)
		local checks = {
			Start = currentHeight >= 15,
			StartMiddle = (progress >= 0.25 or currentHeight >= 25 or horizontal >= 25) and groundDistance > 18,
			Middle = (progress >= 0.5 or currentHeight >= 35 or horizontal >= 35) and groundDistance > 14,
			LandingMiddle = (progress >= 0.75 or currentHeight >= 50 or horizontal >= 50) and groundDistance > 12,
			Landing = groundDistance <= 12
		}

		for name, allowed in pairs(checks) do
			if allowed and not state.Pulsed[name] then
				state.Pulsed[name] = true
				pulse(module, runId)
				return
			end
		end

		if (state.LastPulse or 0) > 0 and now - state.LastPulse >= 1 then
			pulse(module, runId)
			return
		end

		setRates(0, 60)
	end

	local function velocityNoFall(module, runId)
		local match = bedwars and bedwars.Knit and bedwars.Knit.Controllers and bedwars.Knit.Controllers.MatchController
		if match and type(match.getMatchState) == "function" and match:getMatchState() ~= 1 then return end

		local _, humanoid, rootPart = characterState()
		if humanoid and rootPart and rootPart.Velocity.Y < -35 then
			local velocity = rootPart.Velocity
			rootPart.Velocity = Vector3.new(0, 2.5, 0)
			humanoid:ChangeState(Enum.HumanoidStateType.PlatformStanding)
			runService.PreRender:Wait()
			if rootPart and rootPart.Parent then
				rootPart.Velocity = velocity
			end
		end
	end

	NoFallModule = TaskAPI.Categories.Movement:CreateModule({
		Name = "NoFall",
		Function = function(enabled, runId, module)
			if not enabled then
				reset()
				return
			end

			reset()
			module:Clean(reset)
			module:Clean(lplr.CharacterAdded:Connect(reset))

			module:Clean(runService.Heartbeat:Connect(function()
				if module:IsActive(runId) and mode == "Velocity" then
					velocityNoFall(module, runId)
				end
			end))

			module:Clean(runService.PreSimulation:Connect(function()
				if not module:IsActive(runId) or mode == "Velocity" then return end

				local character, humanoid, rootPart = characterState()
				if not (character and humanoid and rootPart and humanoid.Health > 0) then return end
				if mode == "Raknet" then
					raknetNoFall(character, rootPart)
				else
					blinkNoFall(character, humanoid, rootPart, module, runId)
				end
			end))
		end,
		ToolTip = "Prevents fall damage."
	})

	NoFallModule:CreateDropdown({
		Name = "Mode",
		List = { "Blink", "Raknet", "Velocity" },
		Function = function(value)
			mode = value
			if mode ~= "Raknet" then
				setRaknet(false)
			end
			if mode ~= "Blink" then
				clearBlink()
			end
		end,
		ToolTip = "Three Methods"
	})
end)

return NoFallModule
