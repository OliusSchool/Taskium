local TaskAPI = getgenv().TaskAPI or (getgenv().Taskium and getgenv().Taskium.API)

if not TaskAPI then
	error("TaskAPI was not loaded before Categories.lua")
end

TaskAPI:CreateCategory({
	Name = "Combat",
	Position = UDim2.new(0.1, 0, 0.2, 0)
})

TaskAPI:CreateCategory({ 
	Name = "Movement",
	Position = UDim2.new(0.25, 0, 0.2, 0)
})

TaskAPI:CreateCategory({ 
	Name = "Render",
	Position = UDim2.new(0.35, 0, 0.2, 0)
})

TaskAPI:CreateCategory({ 
	Name = "Player",
	Position = UDim2.new(0.45, 0, 0.2, 0)
})

TaskAPI:CreateCategory({ 
	Name = "Other",
	Position = UDim2.new(0.55, 0, 0.2, 0)
})

return TaskAPI
