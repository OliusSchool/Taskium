local TaskUI = getgenv().TaskUI

if not TaskUI then
	error("TaskUI was not loaded before Categories.lua")
end

TaskUI:CreateCategory({
	Name = "Other",
	Position = UDim2.new(0.9, 0, 0.2, 0)
})

return TaskUI
