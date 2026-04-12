local TaskUI = getgenv().TaskUI

if not TaskUI then
	error("TaskUI was not loaded before Categories.lua")
end

TaskAPI:CreateCategory({
	Name = "Combat",
	Position = UDim2.new(0.1, 0, 0.2, 0)
})

TaskAPI:CreateCategory({ 
	Name = "Movement",
	Position = UDim2.new(0.3, 0, 0.2, 0)
})

TaskAPI:CreateCategory({ 
	Name = "Render",
	Position = UDim2.new(0.5, 0, 0.2, 0)
})

TaskAPI:CreateCategory({ 
	Name = "Player",
	Position = UDim2.new(0.7, 0, 0.2, 0)
})

TaskAPI:CreateCategory({ 
	Name = "Other",
	Position = UDim2.new(0.9, 0, 0.2, 0)
})

return TaskUI
