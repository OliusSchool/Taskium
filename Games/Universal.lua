local TaskAPI = getgenv().TaskAPI or (getgenv().TaskClient and getgenv().TaskClient.API)

if not TaskAPI or not TaskAPI.Categories or not TaskAPI.Categories.Combat then
	error("Combat category was not loaded before Games/Universal.lua")
end

local SilentAim
SilentAim = TaskAPI.Categories.Combat:CreateModule({
	Name = "Test",
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

local LocalPlayer = Players.LocalPlayer
local DEFAULT_SPEED = 16
local BOOST_SPEED = 32

local Speed
Speed = TaskAPI.Categories.Movement:CreateModule({
	Name = "Speed",
	Function = function(enabled)
		local function applySpeed(character, walkSpeed)
			if not character then
				return
			end

			local humanoid = character:FindFirstChildOfClass("Humanoid") or character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = walkSpeed
			end
		end

		if enabled then
			local respawnConnection = LocalPlayer.CharacterAdded:Connect(function(character)
				local humanoid = character:WaitForChild("Humanoid")
				humanoid.WalkSpeed = BOOST_SPEED
			end)

			Speed:Clean(respawnConnection)
			Speed:Clean(function()
				applySpeed(LocalPlayer.Character, DEFAULT_SPEED)
			end)

			applySpeed(LocalPlayer.Character, BOOST_SPEED)
			return
		end

		applySpeed(LocalPlayer.Character, DEFAULT_SPEED)
	end,
	ExtraText = function()
		return tostring(BOOST_SPEED)
	end,
	Tooltip = "Increases your walk speed."
})

return TaskAPI