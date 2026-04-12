local TaskAPI = getgenv().TaskAPI or (getgenv().TaskClient and getgenv().TaskClient.API)

if not TaskAPI then
	error("TaskAPI was not loaded before Categories.lua")
end

TaskAPI:CreateCategory({
	Name = "Combat",
	Position = UDim2.new(0.15, 0, 0.2, 0)
})

TaskAPI:CreateCategory({ 
	Name = "Movement",
	Position = UDim2.new(0.3, 0, 0.2, 0)
})

TaskAPI:CreateCategory({ 
	Name = "Render",
	Position = UDim2.new(0.45, 0, 0.2, 0)
})

TaskAPI:CreateCategory({ 
	Name = "Player",
	Position = UDim2.new(0.6, 0, 0.2, 0)
})

TaskAPI:CreateCategory({ 
	Name = "Other",
	Position = UDim2.new(0.75, 0, 0.2, 0)
})

return TaskAPI