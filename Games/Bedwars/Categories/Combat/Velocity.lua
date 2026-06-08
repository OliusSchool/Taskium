local Main = (shared.Taskium or getgenv().Taskium).ExecuteFile("Taskium/Games/Bedwars/Main.lua")

local TaskAPI = Main.TaskAPI
local EntityTracker = Main.EntityTracker

local bedwars = Main.bedwars

local Run = Main.Run or function(func)
	return func()
end

Run(function()
	local Velocity
	local Horizontal
	local Vertical
	local Chance
	local TargetCheck
	local rand, old = Random.new()

	Velocity = TaskAPI.Categories.Combat:CreateModule({
		Name = "Velocity",
		Function = function(callback)
			local KnockbackUtil = bedwars.KnockbackUtil
			if not KnockbackUtil then
				warn("KnockbackUtil failed to load.")
				return
			end

			if callback then
				old = KnockbackUtil.applyKnockback
				KnockbackUtil.applyKnockback = function(root, mass, direction, knockback, ...)
					if rand:NextNumber(0, 100) > Chance.Value then
						return
					end

					local check = (not TargetCheck.Enabled) or (EntityTracker and EntityTracker.EntityPosition({
						Range = 50,
						Part = "RootPart",
						Players = true
					}))

					if check then
						knockback = knockback or {}
						if Horizontal.Value == 0 and Vertical.Value == 0 then
							return
						end
						knockback.horizontal = (knockback.horizontal or 1) * (Horizontal.Value / 100)
						knockback.vertical = (knockback.vertical or 1) * (Vertical.Value / 100)
					end

					return old(root, mass, direction, knockback, ...)
				end
			elseif old then
				KnockbackUtil.applyKnockback = old
			end
		end,
		ToolTip = "Reduces knockback taken."
	})

	Horizontal = Velocity:CreateSlider({
		Name = "Horizontal",
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = "%",
		ToolTip = "Horizontal knockback"
	})

	Vertical = Velocity:CreateSlider({
		Name = "Vertical",
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = "%",
		ToolTip = "Vertical knockback"
	})

	Chance = Velocity:CreateSlider({
		Name = "Chance",
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = "%",
		ToolTip = "Chance for Velocity to activate"
	})

	TargetCheck = Velocity:CreateToggle({
		Name = "Only when targeting"
	})
end)
