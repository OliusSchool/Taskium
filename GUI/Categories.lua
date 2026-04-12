local TaskAPI = getgenv().TaskAPI or (getgenv().TaskClient and getgenv().TaskClient.API)

if not TaskAPI then
	error("TaskAPI was not loaded before Categories.lua")
end

TaskAPI:CreateCategory({
	Name = "Other",
	Position = UDim2.new(0.9, 0, 0.2, 0)
})

TaskAPI:CreateCategory({
	Name = "Combat",
	Position = UDim2.new(0.7, 0, 0.2, 0)
})

return TaskAPI
