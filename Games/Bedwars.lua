local TaskAPI = getgenv().TaskAPI or (getgenv().Taskium and getgenv().Taskium.API)

local RunModule = function(RunFunction)
	return RunFunction()
end

if not TaskAPI or not TaskAPI.Categories then
	TaskAPI.Notification("Taskium", "TaskAPI categories were not loaded before Games/Bedwars.lua", 5, "Error")
	return TaskAPI
end

return TaskAPI