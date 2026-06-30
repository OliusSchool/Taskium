local TaskAPI = getgenv().TaskAPI or (getgenv().Taskium and getgenv().Taskium.API)

local CategoryNames = { "Combat", "Movement", "Render", "Player", "Inventory", "Utility", "World" }
local CategoryWidth = 150
local CategoryGap = 15
local StepX = CategoryWidth + CategoryGap
local CenterOffset = ((#CategoryNames - 1) * StepX) / 2

for Index, Name in ipairs(CategoryNames) do
	if not TaskAPI.Categories[Name] then
		TaskAPI:CreateCategory({
			Name = Name,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, ((Index - 1) * StepX) - CenterOffset, 0.2, 0)
		})
	end
end

return TaskAPI