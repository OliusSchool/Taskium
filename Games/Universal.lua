local TaskAPI = getgenv().TaskAPI or (getgenv().TaskClient and getgenv().TaskClient.API)

if not TaskAPI or not TaskAPI.Categories or not TaskAPI.Categories.Combat then
	error("Combat category was not loaded before Games/Universal.lua")
end

local SilentAim
SilentAim = TaskAPI.Categories.Combat:CreateModule({
	Name = "SilentAim",
	Function = function(callback)
		print(callback, "module state")

		if callback then
			SilentAim:Clean(Instance.new("Part"))

			repeat
				print("repeat loop!")
				task.wait(1)
			until (not SilentAim.Enabled)
		end
	end,
	ExtraText = function()
		return "Test"
	end,
	Tooltip = "This is a test module."
})

return TaskAPI
