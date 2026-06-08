local Taskium = (shared and shared.Taskium) or getgenv().Taskium
local Main = Taskium.ExecuteFile("Taskium/Games/Bedwars/Main.lua")

local TaskAPI = Main.TaskAPI

local bedwars = Main.bedwars

local runService = Main.runService

local characterState = Main.characterState
local runtimeState = Main.runtimeState

local Run = Main.Run or function(func)
	return func()
end

local SprintModule
Run(function()
	local state = runtimeState.Sprint or {}
	runtimeState.Sprint = state

	local function restoreStop()
		if state.Controller
			and state.OriginalStop
			and state.WrappedStop
			and state.Controller.stopSprinting == state.WrappedStop then
			state.Controller.stopSprinting = state.OriginalStop
		end
	end

	local function removeHook(owner)
		if state.Owner ~= owner then
			return
		end

		restoreStop()
		state.Owner = nil
		state.Controller = nil
		state.OriginalStop = nil
		state.WrappedStop = nil
	end

	local function applyHook(owner)
		local sprintController = bedwars and bedwars.SprintController
		if not (sprintController
			and type(sprintController.startSprinting) == "function"
			and type(sprintController.stopSprinting) == "function") then
			return false
		end

		if state.Owner and state.Owner ~= owner then
			removeHook(state.Owner)
		end

		if state.Controller ~= sprintController then
			restoreStop()
			state.Controller = sprintController
			state.OriginalStop = sprintController.stopSprinting
		end

		state.Owner = owner
		local oldStop = state.OriginalStop
		local newStop = function(...)
			local results = { oldStop(...) }
			task.defer(function()
				if state.Owner == owner then
					pcall(function()
						sprintController:startSprinting()
					end)
				end
			end)
			return table.unpack(results)
		end

		state.WrappedStop = newStop
		sprintController.stopSprinting = newStop

		pcall(function()
			sprintController:stopSprinting()
		end)

		return true
	end

	SprintModule = TaskAPI.Categories.Movement:CreateModule({
		Name = "Sprint",
		Function = function(callback, runId, module)
			if not callback then
				return
			end

			local owner = "Sprint_" .. tostring(runId)
			module:Clean(function()
				removeHook(owner)
			end)

			task.spawn(function()
				repeat
					task.wait(0.25)
				until not module:IsActive(runId) or applyHook(owner)
			end)

			module:Clean(runService.Heartbeat:Connect(function()
				if not module:IsActive(runId) then
					return
				end

				local _, humanoid = characterState()
				local sprintController = bedwars and bedwars.SprintController
				if humanoid
					and humanoid.Health > 0
					and humanoid.MoveDirection.Magnitude > 0.01
					and sprintController
					and type(sprintController.startSprinting) == "function" then
					pcall(function()
						sprintController:startSprinting()
					end)
				end
			end))
		end,
		ToolTip = "Keeps your character sprinting while moving."
	})
end)

return SprintModule
