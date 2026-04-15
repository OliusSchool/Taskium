local TaskAPI = getgenv().TaskAPI or (getgenv().Taskium and getgenv().Taskium.API)

if not TaskAPI or not TaskAPI.Categories or not TaskAPI.Categories.Combat then
	error("Required categories were not loaded before Games/Universal.lua")
end

local TestModule
local PrintSpeed = 20
local MoveMode = "Direct"
TestModule = TaskAPI.Categories.Combat:CreateModule({
	Name = "TestModule",
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
			List = { "InDirect", "Direct" },
			Function = function(val)
				MoveMode = val
				print(val, "dropdown value changed")
			end,
			Tooltip = "This is a test dropdown."
		}
	}
})

return TaskAPI
