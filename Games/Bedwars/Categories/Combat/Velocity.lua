local Taskium = (shared and shared.Taskium) or getgenv().Taskium
local Main = Taskium.ExecuteFile("Taskium/Games/Bedwars/Main.lua")

local TaskAPI = Main.TaskAPI
local EntityTracker = Main.EntityTracker

local bedwars = Main.bedwars
local loadBedwars = Main.loadBedwars

local Run = Main.Run or function(func)
	return func()
end

local Velocity

Run(function()
	local Horizontal
	local Vertical
	local Chance
	local TargetCheck
	local rand = Random.new()
	local oldApply
	local wrappedApply

	local function restore()
		if oldApply and wrappedApply and bedwars.KnockbackUtil and bedwars.KnockbackUtil.applyKnockback == wrappedApply then
			bedwars.KnockbackUtil.applyKnockback = oldApply
		end
		oldApply = nil
		wrappedApply = nil
	end

	Velocity = TaskAPI.Categories.Combat:CreateModule({
		Name = "Velocity",
		Function = function(callback, _, module)
			if not callback then
				restore()
				return
			end

			if not (bedwars.KnockbackUtil and type(bedwars.KnockbackUtil.applyKnockback) == "function") and type(loadBedwars) == "function" then
				local loadedBedwars = loadBedwars()
				bedwars = loadedBedwars or bedwars
			end

			if not (bedwars.KnockbackUtil and type(bedwars.KnockbackUtil.applyKnockback) == "function") then
				TaskAPI.Notification("Taskium", "Velocity couldn't find KnockbackUtil.", 5, "Error")
				module:SetEnabled(false, { SkipNotify = true })
				return
			end

			restore()
			oldApply = bedwars.KnockbackUtil.applyKnockback
			wrappedApply = function(root, mass, dir, knockback, ...)
				if rand:NextNumber(0, 100) > Chance.Value then
					return nil
				end

				local check = (not TargetCheck.Enabled) or (EntityTracker and EntityTracker.EntityPosition({
					Range = 50,
					Part = "RootPart",
					Players = true
				}))

				if check then
					knockback = knockback or {}
					if Horizontal.Value == 0 and Vertical.Value == 0 then
						return nil
					end
					knockback.horizontal = (knockback.horizontal or 1) * (Horizontal.Value / 100)
					knockback.vertical = (knockback.vertical or 1) * (Vertical.Value / 100)
				end

				return oldApply(root, mass, dir, knockback, ...)
			end
			bedwars.KnockbackUtil.applyKnockback = wrappedApply

			module:Clean(restore)
		end,
		ToolTip = "Reduces knockback taken."
	})

	Horizontal = Velocity:CreateSlider({
		Name = "Horizontal",
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = "%"
	})

	Vertical = Velocity:CreateSlider({
		Name = "Vertical",
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = "%"
	})

	Chance = Velocity:CreateSlider({
		Name = "Chance",
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = "%"
	})

	TargetCheck = Velocity:CreateToggle({
		Name = "Only when targeting"
	})
end)

return Velocity
