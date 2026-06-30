local cloneref = cloneref or function(ref)
	return ref
end

local replicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local players = cloneref(game:GetService("Players"))
local localPlayer = players.LocalPlayer

local bedwars = rawget(getgenv(), "bedwars")
if type(bedwars) ~= "table" then
	bedwars = {}
	getgenv().bedwars = bedwars
end

local Controllers = {}

local function req(func)
	local ok, result = pcall(func)
	return ok and result or nil
end

local function getField(key)
	return rawget(bedwars, key)
end

local function setDefault(key, value)
	if value ~= nil then
		rawset(bedwars, key, value)
	end
	return rawget(bedwars, key)
end

local function hasRequiredControllers(knit)
	local controllers = knit and knit.Controllers
	return controllers
		and controllers.SwordController
		and controllers.BlockBreakController
		and controllers.BlockPlacementController
		and controllers.BedwarsShopController
		and controllers.ProjectileController
end

local function knitStarted(knit)
	if not (debug and debug.getupvalue and knit and type(knit.Start) == "function") then
		return true
	end

	local ok, started = pcall(debug.getupvalue, knit.Start, 1)
	return ok and started ~= nil
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

	for _ = 1, 100 do
		if knitStarted(knit) and hasRequiredControllers(knit) then
			break
		end
		task.wait(0.1)
	end

	rawset(bedwars, "Knit", knit)
	setDefault("Client", req(function()
		return require(replicatedStorage.TS.remotes).default.Client
	end))
	setDefault("BlockController", req(function()
		return require(replicatedStorage.rbxts_include.node_modules["@easy-games"]["block-engine"].out).BlockEngine
	end))
	setDefault("BlockEngine", req(function()
		return require(localPlayer.PlayerScripts.TS.lib["block-engine"]["client-block-engine"]).ClientBlockEngine
	end))
	setDefault("BlockPlacer", req(function()
		return require(replicatedStorage.rbxts_include.node_modules["@easy-games"]["block-engine"].out.client.placement["block-placer"]).BlockPlacer
	end))
	setDefault("BlockSelector", req(function()
		return require(replicatedStorage.rbxts_include.node_modules["@easy-games"]["block-engine"].out.client.select["block-selector"]).BlockSelector
	end))
	setDefault("BlockPlacementController", knit.Controllers and knit.Controllers.BlockPlacementController)
	setDefault("BlockBreakController", knit.Controllers and knit.Controllers.BlockBreakController)
	setDefault("BlockBreaker", getField("BlockBreakController") and getField("BlockBreakController").blockBreaker)
	setDefault("CombatConstant", req(function()
		return require(replicatedStorage.TS.combat["combat-constant"]).CombatConstant
	end))
	setDefault("KnockbackUtil", req(function()
		return require(replicatedStorage.TS.damage["knockback-util"]).KnockbackUtil
	end))
	setDefault("AnimationType", req(function()
		return require(replicatedStorage.TS.animation["animation-type"]).AnimationType
	end))
	if not next(getField("ItemMeta") or {}) then
		rawset(bedwars, "ItemMeta", req(function()
		return require(replicatedStorage.TS.item["item-meta"]).items
		end) or {})
	end
	setDefault("ProjectileMeta", req(function()
		return require(replicatedStorage.TS.projectile["projectile-meta"]).ProjectileMeta
	end) or {})
	setDefault("ZapNetworking", req(function()
		return require(localPlayer.PlayerScripts.TS.lib.network)
	end))
	setDefault("ClickHold", req(function()
		return require(replicatedStorage.rbxts_include.node_modules["@easy-games"]["game-core"].out.client.ui.lib.util["click-hold"]).ClickHold
	end))
	setDefault("Store", req(function()
		return require(localPlayer.PlayerScripts.TS.ui.store).ClientStore
	end))
	setDefault("BedwarsShopController", knit.Controllers and knit.Controllers.BedwarsShopController)
	setDefault("SoundManager", req(function()
		return require(replicatedStorage.rbxts_include.node_modules["@easy-games"]["game-core"].out).SoundManager
	end))
	setDefault("SoundList", req(function()
		return require(replicatedStorage.TS.sound["game-sound"]).GameSound
	end) or {})
	setDefault("ProjectileController", knit.Controllers and knit.Controllers.ProjectileController)
	setDefault("SwordController", knit.Controllers and knit.Controllers.SwordController)
	setDefault("ScytheController", knit.Controllers and knit.Controllers.ScytheController)
	setDefault("ViewmodelController", knit.Controllers and knit.Controllers.ViewmodelController)
	setDefault("AbilityController", knit.Controllers and knit.Controllers.AbilityController)
	setDefault("SummonerClawController", knit.Controllers and knit.Controllers.SummonerClawController)
	setDefault("SummonerClawHandController", knit.Controllers and knit.Controllers.SummonerClawHandController)
	setDefault("SummonerKitBalance", req(function()
		return require(replicatedStorage.TS.games.bedwars.kit.kits.summoner["summoner-kit-balance"]).SummonerKitBalance
	end) or {})

	for name, controller in knit.Controllers or {} do
		setDefault(name, controller)
	end

	getgenv().bedwars = bedwars
	return bedwars, knit
end

return Controllers
