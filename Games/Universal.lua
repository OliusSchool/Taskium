local TaskAPI = getgenv().TaskAPI or (getgenv().TaskClient and getgenv().TaskClient.API)

if not TaskAPI or not TaskAPI.Categories or not TaskAPI.Categories.Combat then
	error("Combat category was not loaded before Games/Universal.lua")
end

local SilentAim
SilentAim = TaskAPI.Categories.Combat:CreateModule({
	Name = "Testa",
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

local Speed
Speed = TaskAPI.Categories.Movement:CreateModule({
	Name = "Speed",
	Function = function(callback)
		local character = game:GetService("Players").LocalPlayer.Character or game:GetService("Players").LocalPlayer.CharacterAdded:Wait()
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")

		if callback then
			local characterConnection = game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function(newCharacter)
				local newHumanoid = newCharacter:WaitForChild("Humanoid")
				newHumanoid.WalkSpeed = 32
			end)

			Speed:Clean(characterConnection)
			Speed:Clean(function()
				local currentCharacter = game:GetService("Players").LocalPlayer.Character
				local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
				if currentHumanoid then
					currentHumanoid.WalkSpeed = 16
				end
			end)

			humanoid.WalkSpeed = 32

			repeat
				local currentCharacter = game:GetService("Players").LocalPlayer.Character
				local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
				if currentHumanoid and currentHumanoid.WalkSpeed ~= 32 then
					currentHumanoid.WalkSpeed = 32
				end
				task.wait(0.1)
			until (not Speed.Enabled)
		end
	end,
	ExtraText = function()
		return "32"
	end,
	Tooltip = "Increases your walk speed."
})

return TaskAPI