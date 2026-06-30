local Taskium = getgenv().Taskium
local TaskAPI = getgenv().TaskAPI
local EntityTracker = Taskium.LoadLibrary("EntityTracker")

local cloneref = cloneref or function(ref)
    return ref
end

local players = cloneref(game:GetService("Players"))
local replicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local runService = cloneref(game:GetService("RunService"))
local tweenService = cloneref(game:GetService("TweenService"))
local inputService = cloneref(game:GetService("UserInputService"))
local contextAction = cloneref(game:GetService("ContextActionService"))
local collectionService = cloneref(game:GetService("CollectionService"))

local lplr = players.LocalPlayer
local gameCam = workspace.CurrentCamera
local playerGui = lplr:WaitForChild("PlayerGui")

local runtime = rawget(getgenv(), "TaskiumBedwars")
if type(runtime) ~= "table" then
    runtime = {}
    getgenv().TaskiumBedwars = runtime
end

local runtimeState = rawget(getgenv(), "TaskiumRuntimeState")
if type(runtimeState) ~= "table" then
	runtimeState = {}
	getgenv().TaskiumRuntimeState = runtimeState
end

local bedwars = rawget(getgenv(), "bedwars")
if type(bedwars) ~= "table" then
	bedwars = setmetatable({}, {})
	getgenv().bedwars = bedwars
end

local remotes = rawget(getgenv(), "remotes")
if type(remotes) ~= "table" then
	remotes = {}
	getgenv().remotes = remotes
end

local bedwarsEvents = rawget(getgenv(), "bedwarsEvents")
if type(bedwarsEvents) ~= "table" then
	bedwarsEvents = setmetatable({}, {
		__index = function(self, index)
			self[index] = Instance.new("BindableEvent")
			return self[index]
		end
	})
	getgenv().bedwarsEvents = bedwarsEvents
end

local bedwarsStore = rawget(getgenv(), "bedwarsStore")
if type(bedwarsStore) ~= "table" then
	bedwarsStore = {
		attackReach = 0,
		attackReachUpdate = tick(),
		damageBlockFail = 0,
		knockbackBoost = 0,
		knockbackSpeed = 0,
		hand = {},
		inventory = {
			inventory = {
				armor = {},
				items = {}
			},
			hotbar = {},
			hotbarSlot = 1
		},
		inventories = {},
		tools = {},
		shopLoaded = false,
		matchState = 0,
		queueType = "bedwars"
	}
	getgenv().bedwarsStore = bedwarsStore
	getgenv().store = bedwarsStore
end
bedwarsStore.knockbackBoost = bedwarsStore.knockbackBoost or 0
bedwarsStore.knockbackSpeed = bedwarsStore.knockbackSpeed or 0

local function Run(func)
	return func()
end

local function runFile(path)
	if Taskium and Taskium.ExecuteFile then
		return Taskium.ExecuteFile(path)
	end
	return loadstring(readfile(path), "@" .. path)()
end

local Controllers = runFile("Taskium/Games/Bedwars/Controllers/Controllers.lua")
local Remotes = runFile("Taskium/Games/Bedwars/Remotes/Remotes.lua")

local function characterState(plr)
	plr = plr or lplr
	local character = plr and plr.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = humanoid and humanoid.RootPart
	return character, humanoid, rootPart
end

local function collect(tagName, owner, callback)
	local objects = {}
	for _, object in ipairs(collectionService:GetTagged(tagName)) do
		if callback then
			callback(objects, object)
		else
			table.insert(objects, object)
		end
	end

	local connections = {
		collectionService:GetInstanceAddedSignal(tagName):Connect(function(object)
			if callback then
				callback(objects, object)
			else
				table.insert(objects, object)
			end
		end),
		collectionService:GetInstanceRemovedSignal(tagName):Connect(function(object)
			local index = table.find(objects, object)
			if index then
				table.remove(objects, index)
			end
		end)
	}

	local cleaner = function()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		table.clear(objects)
	end
	if owner and type(owner.Clean) == "function" then
		owner:Clean(cleaner)
	end

	return objects, cleaner
end

local function getItems()
	return ((bedwarsStore.inventory or {}).inventory or {}).items or {}
end

local function fillItemTool(item)
	if item and not item.tool then
		for slot, hotbarItem in (bedwarsStore.inventory.hotbar or {}) do
			if hotbarItem.item and hotbarItem.item.itemType == item.itemType then
				item.tool = hotbarItem.item.tool
				item.slot = slot - 1
				break
			end
		end
	end
	return item
end

local function getItem(itemType, exact)
	for slot, item in getItems() do
		if item and (item.itemType == itemType or (not exact and type(item.itemType) == "string" and item.itemType:find(itemType, 1, true))) then
			return fillItemTool(item), slot
		end
	end
	return nil
end

local function getSword()
	local bestSword, bestSlot, bestDamage = nil, nil, 0
	for slot, item in getItems() do
		local meta = item and bedwars.ItemMeta and bedwars.ItemMeta[item.itemType]
		local sword = meta and meta.sword
		local damage = sword and (sword.damage or 0) or 0
		if damage > bestDamage then
			bestSword, bestSlot, bestDamage = item, slot, damage
		end
	end
	return fillItemTool(bestSword), bestSlot
end

local function getTool(breakType)
	local bestTool, bestSlot, bestStrength = nil, nil, 0
	for slot, item in getItems() do
		local meta = item and bedwars.ItemMeta and bedwars.ItemMeta[item.itemType]
		local block = meta and meta.breakBlock
		local strength = block and (block[breakType] or block.default or 0) or 0
		if strength > bestStrength then
			bestTool, bestSlot, bestStrength = item, slot, strength
		end
	end
	return fillItemTool(bestTool), bestSlot
end

local function getWool()
	for _, item in getItems() do
		if item and type(item.itemType) == "string" and item.itemType:find("wool", 1, true) then
			return item.itemType, item.amount or 0
		end
	end
	return nil, 0
end

local function getSpeed()
	local sprintController = bedwars.SprintController
	if not (sprintController and sprintController.getMovementStatusModifier) then
		return 20
	end

	local modifier = sprintController:getMovementStatusModifier()
	local modifiers = modifier and modifier:getModifiers() or {}
	local multi, increase = 0, true
	for _, value in modifiers do
		if type(value) == "table" then
			local constant = value.constantSpeedMultiplier or 0
			if constant > math.max(multi, 1) then
				increase = false
				multi = constant - (0.06 * math.round(constant))
			end
		end
	end
	for _, value in modifiers do
		if type(value) == "table" then
			multi += math.max((value.moveSpeedMultiplier or 0) - 1, 0)
		end
	end
	if multi > 0 and increase then
		multi += 0.16 + (0.02 * math.round(multi))
	end
	local boost = (bedwarsStore.knockbackBoost or 0) > tick() and (bedwarsStore.knockbackSpeed or 0) or 0
	return (20 + boost) * (multi + 1)
end

local function getHotbar(tool)
	for index, value in (bedwarsStore.inventory.hotbar or {}) do
		if value.item and value.item.tool == tool then
			return index - 1
		end
	end
	return nil
end

local function hotbarSwitch(slot)
	if slot and bedwars.Store and bedwarsStore.inventory.hotbarSlot ~= slot then
		bedwars.Store:dispatch({
			type = "InventorySelectHotbarSlot",
			slot = slot
		})
		local changed = false
		local connection = bedwarsEvents.InventoryChanged.Event:Connect(function()
			changed = true
		end)
		local timeout = tick() + 0.15
		repeat
			task.wait()
		until changed or bedwarsStore.inventory.hotbarSlot == slot or tick() > timeout
		connection:Disconnect()
		return true
	end
	return false
end

local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild("HandInvItem")
	if check and tool and check.Value ~= tool and tool.Parent ~= nil then
		task.spawn(function()
			if bedwars.Client then
				local remoteName = remotes.EquipItem
				if not remoteName then
					return
				end
				local ok, remote = pcall(function()
					return bedwars.Client:Get(remoteName)
				end)
				if ok and remote and type(remote.CallServerAsync) == "function" then
					remote:CallServerAsync({ hand = tool })
				end
			end
		end)
		check.Value = tool
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
	return check and tool and check.Value == tool
end

local function makePlaceBlock()
	if not (bedwars.BlockController and bedwars.BlockPlacer and bedwars.BlockEngine) then
		local loadedBedwars = Controllers and Controllers.load and Controllers.load(bedwars)
		bedwars = loadedBedwars or bedwars
	end
	if not (bedwars.BlockController and bedwars.BlockPlacer and bedwars.BlockEngine) then
		return nil
	end

	bedwars.placeBlock = function(position, itemType)
		if not (getItem and getItem(itemType)) then
			return nil
		end

		local function makePlacer()
			local ok, placer = pcall(function()
				return bedwars.BlockPlacer.new(bedwars.BlockEngine, itemType or "wool_white")
			end)
			if ok and placer then
				bedwarsStore.blockPlacer = placer
			end
		end

		if (not bedwarsStore.blockPlacer or type(bedwarsStore.blockPlacer.placeBlock) ~= "function" or bedwarsStore.blockPlacer.blockType ~= itemType) then
			makePlacer()
		end

		if not (bedwarsStore.blockPlacer and type(bedwarsStore.blockPlacer.placeBlock) == "function") then
			return nil
		end

		bedwarsStore.blockPlacer.blockType = itemType
		local blockPosition = bedwars.BlockController:getBlockPosition(position)
		local ok, result = pcall(function()
			return bedwarsStore.blockPlacer:placeBlock(blockPosition)
		end)
		if ok and result then
			return result
		end

		pcall(function()
			if bedwarsStore.blockPlacer and type(bedwarsStore.blockPlacer.disable) == "function" then
				bedwarsStore.blockPlacer:disable()
			end
		end)
		bedwarsStore.blockPlacer = nil
		makePlacer()
		if bedwarsStore.blockPlacer and type(bedwarsStore.blockPlacer.placeBlock) == "function" then
			bedwarsStore.blockPlacer.blockType = itemType
			local retryOk, retryResult = pcall(function()
				return bedwarsStore.blockPlacer:placeBlock(blockPosition)
			end)
			return retryOk and retryResult or nil
		end
	end

	return bedwars.placeBlock
end

local function getPlacedBlocks(position)
	if not (position and bedwars.BlockController and type(bedwars.BlockController.getBlockPosition) == "function") then
		return nil
	end
	local blockPosition = bedwars.BlockController:getBlockPosition(position)
	local blockStore = bedwars.BlockController:getStore()
	return blockStore and blockStore:getBlockAt(blockPosition), blockPosition
end

local function getBlocksInPoints(startPoint, endPoint)
	local list = {}
	local difference = endPoint - startPoint
	local steps = math.max(math.abs(difference.X), math.abs(difference.Y), math.abs(difference.Z)) / 3
	for index = 0, steps do
		local position = startPoint:Lerp(endPoint, steps == 0 and 0 or index / steps)
		table.insert(list, Vector3.new(math.round(position.X / 3) * 3, math.round(position.Y / 3) * 3, math.round(position.Z / 3) * 3))
	end
	return list
end

local function getPower(entity)
	local power = 0
	local items = entity and entity.Player and bedwarsStore.inventories[entity.Player] or getItems()
	for _, item in items or {} do
		local meta = item and bedwars.ItemMeta and bedwars.ItemMeta[item.itemType]
		if meta and meta.sword and (meta.sword.damage or 0) > power then
			power = meta.sword.damage or 0
		end
	end
	return power
end

local sortMethods = {
	Distance = function(a, b)
		local entityA = a.Entity or a
		local entityB = b.Entity or b
		local _, _, rootPart = characterState()
		local position = rootPart and rootPart.Position or Vector3.zero
		local distanceA = a.Magnitude or (entityA.RootPart and (entityA.RootPart.Position - position).Magnitude) or math.huge
		local distanceB = b.Magnitude or (entityB.RootPart and (entityB.RootPart.Position - position).Magnitude) or math.huge
		return distanceA < distanceB
	end,
	Health = function(a, b)
		local entityA = a.Entity or a
		local entityB = b.Entity or b
		local healthA = entityA.Health or (entityA.Humanoid and entityA.Humanoid.Health) or math.huge
		local healthB = entityB.Health or (entityB.Humanoid and entityB.Humanoid.Health) or math.huge
		return healthA < healthB
	end,
	Threat = function(a, b)
		return getPower(a.Entity or a) > getPower(b.Entity or b)
	end
}

local breakMethods = {
	Health = true,
	Distance = true
}

local function loadBedwars()
	local loadedBedwars, knit = Controllers and Controllers.load and Controllers.load(bedwars)
	bedwars = loadedBedwars or bedwars
	if Remotes and Remotes.load then
		remotes = Remotes.load(knit or bedwars.Knit, remotes) or remotes
	end
	return bedwars, remotes
end

local function syncDamageEvent()
	if runtimeState.damageEventConnection or not (bedwars.ZapNetworking and bedwars.ZapNetworking.EntityDamageEventZap) then
		return
	end

	local ok, connection = pcall(function()
		return bedwars.ZapNetworking.EntityDamageEventZap.On(function(...)
			bedwarsEvents.Damage:Fire({
				entityInstance = ...,
				damage = select(2, ...),
				damageType = select(3, ...),
				fromPosition = select(4, ...),
				fromEntity = select(5, ...),
				knockbackMultiplier = select(6, ...),
				knockbackId = select(7, ...),
				disableDamageHighlight = select(13, ...)
			})
		end)
	end)
	if ok and connection then
		runtimeState.damageEventConnection = connection
	end
end

local function syncStore()
	loadBedwars()
	syncDamageEvent()
	if not (bedwars.Store and type(bedwars.Store.getState) == "function") then
		return bedwarsStore
	end

	local function update(newState, oldState)
		newState = newState or {}
		oldState = oldState or {}
		if newState.Game then
			bedwarsStore.matchState = newState.Game.matchState or bedwarsStore.matchState
			bedwarsStore.queueType = newState.Game.queueType or bedwarsStore.queueType
		end

		if newState.Inventory ~= oldState.Inventory then
			local newInventory = newState.Inventory and newState.Inventory.observedInventory or bedwarsStore.inventory
			local oldInventory = oldState.Inventory and oldState.Inventory.observedInventory or { inventory = {} }
			bedwarsStore.inventory = newInventory

			if newInventory ~= oldInventory then
				bedwarsEvents.InventoryChanged:Fire()
			end
			if newInventory.inventory and oldInventory.inventory and newInventory.inventory.items ~= oldInventory.inventory.items then
				bedwarsEvents.InventoryAmountChanged:Fire()
				bedwarsStore.tools.sword = getSword()
				for _, breakType in ipairs({ "stone", "wood", "wool" }) do
					bedwarsStore.tools[breakType] = getTool(breakType)
				end
			end
			if newInventory.inventory and oldInventory.inventory and newInventory.inventory.hand ~= oldInventory.inventory.hand then
				local currentHand = newInventory.inventory.hand
				local handMeta = currentHand and bedwars.ItemMeta and bedwars.ItemMeta[currentHand.itemType]
				bedwarsStore.hand = {
					tool = currentHand and currentHand.tool,
					amount = currentHand and currentHand.amount or 0,
					toolType = handMeta and (handMeta.sword and "sword" or handMeta.block and "block" or currentHand.itemType:find("bow") and "bow") or ""
				}
			end
		end

		if newState.Game ~= oldState.Game and bedwarsEvents.MatchStateChanged then
			bedwarsEvents.MatchStateChanged:Fire(newState.Game, oldState.Game)
		end
	end

	local oldConnection = rawget(getgenv(), "TaskiumStoreConnection")
	if oldConnection then
		pcall(function()
			oldConnection:Disconnect()
		end)
	end
	if bedwars.Store.changed then
		getgenv().TaskiumStoreConnection = bedwars.Store.changed:connect(update)
	end
	local ok, state = pcall(function()
		return bedwars.Store:getState()
	end)
	if ok then
		update(state, {})
	end

	local function hookAttributes(character)
		bedwarsStore.attributeCharacter = character
		if bedwarsStore.attributeConnection then
			bedwarsStore.attributeConnection:Disconnect()
			bedwarsStore.attributeConnection = nil
		end
		if not character then
			return
		end
		bedwarsStore.attributeConnection = character.AttributeChanged:Connect(function(attribute)
			if bedwarsEvents.AttributeChanged then
				bedwarsEvents.AttributeChanged:Fire(attribute)
			end
		end)
	end
	if not bedwarsStore.characterAddedConnection then
		bedwarsStore.characterAddedConnection = lplr.CharacterAdded:Connect(hookAttributes)
	end
	if lplr.Character and bedwarsStore.attributeCharacter ~= lplr.Character then
		bedwarsStore.attributeCharacter = lplr.Character
		hookAttributes(lplr.Character)
	end
	return bedwarsStore
end

runtime.TaskAPI = TaskAPI
runtime.Run = Run
runtime.players = players
runtime.replicatedStorage = replicatedStorage
runtime.runService = runService
runtime.tweenService = tweenService
runtime.inputService = inputService
runtime.contextAction = contextAction
runtime.collectionService = collectionService
runtime.lplr = lplr
runtime.gameCam = gameCam
runtime.playerGui = playerGui
runtime.EntityTracker = EntityTracker
runtime.bedwarsStore = bedwarsStore
runtime.bedwars = bedwars
runtime.remotes = remotes
runtime.runtimeState = runtimeState
runtime.characterState = characterState
runtime.collect = collect
runtime.getItem = getItem
runtime.getSword = getSword
runtime.getTool = getTool
runtime.getWool = getWool
runtime.getSpeed = getSpeed
runtime.getPower = getPower
runtime.getHotbar = getHotbar
runtime.hotbarSwitch = hotbarSwitch
runtime.switchItem = switchItem
runtime.makePlaceBlock = makePlaceBlock
runtime.getPlacedBlocks = getPlacedBlocks
runtime.getBlocksInPoints = getBlocksInPoints
runtime.sortMethods = sortMethods
runtime.breakMethods = breakMethods
runtime.loadBedwars = loadBedwars
runtime.syncStore = syncStore

loadBedwars()
syncStore()

return runtime
