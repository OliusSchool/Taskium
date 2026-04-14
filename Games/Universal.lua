local TaskAPI = getgenv().TaskAPI or (getgenv().Taskium and getgenv().Taskium.API)

if not TaskAPI or not TaskAPI.Categories or not TaskAPI.Categories.Combat then
	error("Required categories were not loaded before Games/Universal.lua")
end

local TestModule
TestModule = TaskAPI.Categories.Combat:CreateModule({
	Name = "TestModule",
	Function = function(enabled)
		print(enabled, "module state")

		if enabled then
			TestModule:Clean(Instance.new("Part"))

			repeat
				print("repeat loop!")
				task.wait(1)
			until (not TestModule.Enabled)
		end
	end,
	ExtraText = function()
		return "Test"
	end,
	Tooltip = "This is a test module."
})

return TaskAPI
