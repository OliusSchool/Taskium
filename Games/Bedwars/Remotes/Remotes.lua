local Taskium = shared.Taskium or getgenv().Taskium or {}
local context = Taskium.BedwarsContext or getgenv().TaskiumBedwarsContext or {}

local remotes = context.remotes or rawget(getgenv(), "remotes") or {}

local Remotes = {}

local function dumpRemoteName(constants)
	if type(constants) ~= "table" then
		return nil
	end

	for index, value in pairs(constants) do
		if value == "Client" and type(constants[index + 1]) == "string" then
			return constants[index + 1]
		end
	end
end

local function getRemote(controller, method, current)
	if type(current) == "string" and current ~= "" then
		return current
	end

	local remote = controller and controller[method]
	if type(remote) == "string" and remote ~= "" then
		return remote
	end

	if type(remote) == "function" and debug and debug.getconstants then
		local ok, constants = pcall(debug.getconstants, remote)
		return ok and dumpRemoteName(constants) or nil
	end
end

local function getProto(func, index)
	if not (debug and debug.getproto and type(func) == "function") then
		return nil
	end

	local ok, result = pcall(debug.getproto, func, index)
	return ok and result or nil
end

local function resolveEquipItem()
	if type(remotes.EquipItem) == "string" and remotes.EquipItem ~= "" then
		return remotes.EquipItem
	end
	if not debug or not debug.getconstants then
		return nil
	end

	local ok, inventoryEntity = pcall(function()
		return require(game:GetService("ReplicatedStorage").TS.entity.entities["inventory-entity"]).InventoryEntity
	end)
	local equipItem = ok and inventoryEntity and inventoryEntity.equipItem or nil
	if type(equipItem) ~= "function" then
		return nil
	end

	local remoteFunction = getProto(equipItem, 4)
	if type(remoteFunction) == "string" and remoteFunction ~= "" then
		return remoteFunction
	end
	if type(remoteFunction) == "function" then
		local constantsOk, constants = pcall(debug.getconstants, remoteFunction)
		local remoteName = constantsOk and dumpRemoteName(constants) or nil
		if type(remoteName) == "string" and remoteName ~= "" then
			return remoteName
		end
	end

	local constantsOk, constants = pcall(debug.getconstants, equipItem)
	local remoteName = constantsOk and dumpRemoteName(constants) or nil
	return type(remoteName) == "string" and remoteName ~= "" and remoteName or nil
end

function Remotes.load(knit, targetRemotes)
	remotes = targetRemotes or remotes
	local controllers = knit and knit.Controllers

	remotes.AttackEntity = getRemote(controllers and controllers.SwordController, "sendServerRequest", remotes.AttackEntity)
	remotes.FireProjectile = getRemote(controllers and controllers.ProjectileController, "launchProjectileWithValues", remotes.FireProjectile)
	remotes.GroundHit = getRemote(controllers and controllers.FallDamageController, "KnitStart", remotes.GroundHit)
	remotes.EquipItem = remotes.EquipItem or resolveEquipItem()

	getgenv().remotes = remotes
	return remotes
end

return Remotes
