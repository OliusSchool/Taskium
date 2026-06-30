local remotes = rawget(getgenv(), "remotes")
if type(remotes) ~= "table" then
	remotes = {}
	getgenv().remotes = remotes
end

local Remotes = {}

local function filled(value, blocked)
	return type(value) == "string" and value ~= "" and not (blocked and blocked[value])
end

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
	if filled(current) then
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

local function getUpvalueRemote(func, index, current)
	if filled(current) then
		return current
	end
	if not (debug and debug.getupvalue and type(func) == "function") then
		return nil
	end

	local ok, result = pcall(debug.getupvalue, func, index)
	if ok and type(result) == "string" and result ~= "" then
		return result
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
	if filled(remotes.EquipItem, { SetInvItem = true }) then
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

local function resolveConsumeItem(controller)
	if filled(remotes.ConsumeItem, { ConsumeItem = true }) then
		return remotes.ConsumeItem
	end

	local remote = controller and controller.onEnable
	if type(remote) == "function" then
		local proto = getProto(remote, 1)
		if type(proto) == "string" and proto ~= "" then
			return proto
		end
		if type(proto) == "function" and debug and debug.getconstants then
			local ok, constants = pcall(debug.getconstants, proto)
			local remoteName = ok and dumpRemoteName(constants) or nil
			if type(remoteName) == "string" and remoteName ~= "" then
				return remoteName
			end
		end
	end

	return getRemote(controller, "onEnable", remotes.ConsumeItem)
end

local function resolveAfkStatus(controller)
	if filled(remotes.AfkStatus) then
		return remotes.AfkStatus
	end

	local proto = getProto(controller and controller.KnitStart, 1)
	if type(proto) == "string" and proto ~= "" then
		return proto
	end
	if type(proto) == "function" and debug and debug.getconstants then
		local ok, constants = pcall(debug.getconstants, proto)
		local remoteName = ok and dumpRemoteName(constants) or nil
		if type(remoteName) == "string" and remoteName ~= "" then
			return remoteName
		end
	end

	return getRemote(controller, "KnitStart", remotes.AfkStatus)
end

function Remotes.load(knit, targetRemotes)
	remotes = targetRemotes or remotes
	local controllers = knit and knit.Controllers

	remotes.AttackEntity = getRemote(controllers and controllers.SwordController, "sendServerRequest", remotes.AttackEntity)
	remotes.FireProjectile = getUpvalueRemote(controllers and controllers.ProjectileController and controllers.ProjectileController.launchProjectileWithValues, 2, remotes.FireProjectile)
		or getRemote(controllers and controllers.ProjectileController, "launchProjectileWithValues", remotes.FireProjectile)
	remotes.GroundHit = getRemote(controllers and controllers.FallDamageController, "KnitStart", remotes.GroundHit)
	remotes.ConsumeItem = resolveConsumeItem(controllers and controllers.ConsumeController) or (filled(remotes.ConsumeItem, { ConsumeItem = true }) and remotes.ConsumeItem or nil)
	remotes.AfkStatus = resolveAfkStatus(controllers and controllers.AfkController)
	remotes.EquipItem = resolveEquipItem() or (filled(remotes.EquipItem, { SetInvItem = true }) and remotes.EquipItem or nil)

	getgenv().remotes = remotes
	return remotes
end

return Remotes
