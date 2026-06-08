local Taskium = shared.Taskium or getgenv().Taskium or {}
local context = Taskium.BedwarsContext or getgenv().TaskiumBedwarsContext or {}

local replicatedStorage = context.replicatedStorage or game:GetService("ReplicatedStorage")
local localPlayer = context.lplr or game:GetService("Players").LocalPlayer
local bedwars = context.bedwars or rawget(getgenv(), "bedwars") or {}

local Controllers = {}

local function req(func)
	local ok, result = pcall(func)
	return ok and result or nil
end

local function getKnit()
	local knit = req(function()
		return require(replicatedStorage.rbxts_include.node_modules["@easy-games"].knit.src).KnitClient
	end)
	if knit then
		return knit
	end

	local scripts = localPlayer and localPlayer:FindFirstChild("PlayerScripts")
	local knitModule = scripts and scripts:FindFirstChild("TS") and scripts.TS:FindFirstChild("knit")
	if knitModule and debug and debug.getupvalue then
		return req(function()
			return debug.getupvalue(require(knitModule).setup, 9)
		end)
	end
end

function Controllers.load(targetBedwars)
	bedwars = targetBedwars or bedwars

	local knit = getKnit()
	if not knit then
		return bedwars, nil
	end

	for _ = 1, 50 do
		if knit.Controllers and next(knit.Controllers) ~= nil then
			break
		end
		task.wait(0.1)
	end

	bedwars.Knit = knit
	bedwars.Client = bedwars.Client or req(function()
		return require(replicatedStorage.TS.remotes).default.Client
	end)
	bedwars.BlockController = bedwars.BlockController or req(function()
		return require(replicatedStorage.rbxts_include.node_modules["@easy-games"]["block-engine"].out).BlockEngine
	end)
	bedwars.BlockEngine = bedwars.BlockEngine or req(function()
		return require(localPlayer.PlayerScripts.TS.lib["block-engine"]["client-block-engine"]).ClientBlockEngine
	end)
	bedwars.BlockPlacer = bedwars.BlockPlacer or req(function()
		return require(replicatedStorage.rbxts_include.node_modules["@easy-games"]["block-engine"].out.client.placement["block-placer"]).BlockPlacer
	end)
	bedwars.BlockSelector = bedwars.BlockSelector or req(function()
		return require(replicatedStorage.rbxts_include.node_modules["@easy-games"]["block-engine"].out.client.select["block-selector"]).BlockSelector
	end)
	bedwars.CombatConstant = bedwars.CombatConstant or req(function()
		return require(replicatedStorage.TS.combat["combat-constant"]).CombatConstant
	end)
	bedwars.KnockbackUtil = bedwars.KnockbackUtil or req(function()
		return require(replicatedStorage.TS.damage["knockback-util"]).KnockbackUtil
	end)
	bedwars.AnimationType = bedwars.AnimationType or req(function()
		return require(replicatedStorage.TS.animation["animation-type"]).AnimationType
	end)
	bedwars.ItemMeta = next(bedwars.ItemMeta or {}) and bedwars.ItemMeta or req(function()
		return require(replicatedStorage.TS.item["item-meta"]).items
	end) or {}
	bedwars.ProjectileMeta = bedwars.ProjectileMeta or req(function()
		return require(replicatedStorage.TS.projectile["projectile-meta"]).ProjectileMeta
	end) or {}
	bedwars.Store = bedwars.Store or req(function()
		return require(localPlayer.PlayerScripts.TS.ui.store).ClientStore
	end)
	bedwars.SwordController = bedwars.SwordController or (knit.Controllers and knit.Controllers.SwordController)
	bedwars.ScytheController = bedwars.ScytheController or (knit.Controllers and knit.Controllers.ScytheController)
	bedwars.ViewmodelController = bedwars.ViewmodelController or (knit.Controllers and knit.Controllers.ViewmodelController)

	local bedwarsMetatable = getmetatable(bedwars) or {}
	local oldIndex = bedwarsMetatable.__index
	bedwarsMetatable.__index = function(self, index)
		local controller = knit.Controllers and knit.Controllers[index]
		if controller ~= nil then
			rawset(self, index, controller)
			return controller
		end

		if type(oldIndex) == "function" then
			return oldIndex(self, index)
		elseif type(oldIndex) == "table" then
			return oldIndex[index]
		end
	end
	setmetatable(bedwars, bedwarsMetatable)

	getgenv().bedwars = bedwars
	return bedwars, knit
end

return Controllers
