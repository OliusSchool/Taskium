local Taskium = (shared and shared.Taskium) or getgenv().Taskium
local TaskAPI = getgenv().TaskAPI or (Taskium and Taskium.API)

if TaskAPI and TaskAPI.BedwarsMain then
	return TaskAPI.BedwarsMain
end

local EntityTracker = Taskium and Taskium.LoadLibrary and Taskium.LoadLibrary("EntityTracker")

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")
local inputService = game:GetService("UserInputService")
local contextAction = game:GetService("ContextActionService")
local collectionService = game:GetService("CollectionService")
local workspace = game:GetService("Workspace")

local lplr = players.LocalPlayer
local gameCam = workspace.CurrentCamera
local playerGui = lplr and lplr:WaitForChild("PlayerGui")

local Main = {}
if TaskAPI then
	TaskAPI.BedwarsMain = Main
end
getgenv().TaskiumBedwars = Main

local function Run(func)
	return func()
end

local bedwarsStore = {
	attackReach = 0,
	attackReachUpdate = tick(),
	hand = {},
	inventory = {
		inventory = {
			armor = {},
			items = {}
		},
		hotbar = {},
		hotbarSlot = 1,
		invOpened = nil,
		opened = nil
	},
	inventories = {},
	tools = {},
	shopLoaded = false,
	lastHit = 0,
	matchState = 0,
	queueType = "bedwars"
}
getgenv().bedwarsStore = bedwarsStore
getgenv().store = bedwarsStore

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

local bedwarsEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new("BindableEvent")
		return self[index]
	end
})
getgenv().bedwarsEvents = bedwarsEvents

local remotes = rawget(getgenv(), "remotes")
if type(remotes) ~= "table" then
	remotes = {}
	getgenv().remotes = remotes
end

local sides = {}
for _, normal in ipairs(Enum.NormalId:GetEnumItems()) do
	table.insert(sides, Vector3.FromNormalId(normal) * 3)
end

local context = {
	players = players,
	replicatedStorage = replicatedStorage,
	runService = runService,
	tweenService = tweenService,
	inputService = inputService,
	contextAction = contextAction,
	collectionService = collectionService,
	workspace = workspace,
	lplr = lplr,
	gameCam = gameCam,
	playerGui = playerGui,
	EntityTracker = EntityTracker,
	bedwarsStore = bedwarsStore,
	bedwars = bedwars,
	remotes = remotes,
	sides = sides
}
if Taskium then
	Taskium.BedwarsContext = context
end
getgenv().TaskiumBedwarsContext = context

local function runTaskiumFile(path)
	if Taskium and Taskium.ExecuteFile then
		return Taskium.ExecuteFile(path)
	end
	return loadstring(readfile(path), "@" .. path)()
end

local Controllers = runTaskiumFile("Taskium/Games/Bedwars/Controllers/Controllers.lua")
local Remotes = runTaskiumFile("Taskium/Games/Bedwars/Remotes/Remotes.lua")

local function characterState(plr)
	plr = plr or lplr
	local character = plr and plr.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = humanoid and humanoid.RootPart
		or (character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart or character:FindFirstChild("Root")))

	return character, humanoid, rootPart
end
getgenv().characterState = characterState
getgenv().getCharacter = characterState

local function collect(tags, module, customAdd, customRemove)
	tags = typeof(tags) ~= "table" and { tags } or tags
	local objects, connections = {}, {}

	for _, tag in tags do
		table.insert(connections, collectionService:GetInstanceAddedSignal(tag):Connect(function(object)
			if customAdd then
				customAdd(objects, object, tag)
			else
				table.insert(objects, object)
			end
		end))

		table.insert(connections, collectionService:GetInstanceRemovedSignal(tag):Connect(function(object)
			if customRemove then
				customRemove(objects, object, tag)
				return
			end

			local index = table.find(objects, object)
			if index then
				table.remove(objects, index)
			end
		end))

		for _, object in collectionService:GetTagged(tag) do
			if customAdd then
				customAdd(objects, object, tag)
			else
				table.insert(objects, object)
			end
		end
	end

	local clean = function(self)
		for _, connection in connections do
			connection:Disconnect()
		end

		table.clear(connections)
		table.clear(objects)

		if self then
			table.clear(self)
		end
	end

	if module then
		module:Clean(clean)
	end

	return objects, clean
end
getgenv().collect = collect
getgenv().collection = collect

local function getItem(name, inventory)
	for slot, item in (inventory or bedwarsStore.inventory.inventory.items) do
		if item and item.itemType == name then
			return item, slot
		end
	end

	return nil
end
getgenv().getItem = getItem

local function getBestArmor(slot)
	local bestArmor, bestReduction = nil, 0

	for _, item in bedwarsStore.inventory.inventory.items do
		local meta = item and bedwars.ItemMeta and bedwars.ItemMeta[item.itemType]
		local armor = meta and meta.armor
		local reduction = armor and armor.slot == slot and (armor.damageReductionMultiplier or 0) or 0

		if reduction > bestReduction then
			bestArmor, bestReduction = item, reduction
		end
	end

	return bestArmor
end
getgenv().getBestArmor = getBestArmor

local function getSword()
	local bestSword, bestSlot, bestDamage = nil, nil, 0

	for slot, item in bedwarsStore.inventory.inventory.items do
		local meta = item and bedwars.ItemMeta and bedwars.ItemMeta[item.itemType]
		local sword = meta and meta.sword
		local damage = sword and (sword.damage or 0) or 0

		if damage > bestDamage then
			bestSword, bestSlot, bestDamage = item, slot, damage
		end
	end

	return bestSword, bestSlot
end
getgenv().getSword = getSword

local function getBow()
	local bestBow, bestSlot, bestDamage = nil, nil, 0

	for slot, item in bedwarsStore.inventory.inventory.items do
		local meta = item and bedwars.ItemMeta and bedwars.ItemMeta[item.itemType]
		local bow = meta and meta.projectileSource
		local damage = 0

		if bow and table.find(bow.ammoItemTypes or {}, "arrow") then
			local projectileType = type(bow.projectileType) == "function" and bow.projectileType("arrow") or bow.projectileType
			local projectile = bedwars.ProjectileMeta and bedwars.ProjectileMeta[projectileType]
			damage = projectile and projectile.combat and projectile.combat.damage or 0
		end

		if damage > bestDamage then
			bestBow, bestSlot, bestDamage = item, slot, damage
		end
	end

	return bestBow, bestSlot
end
getgenv().getBow = getBow

local function getTool(breakType)
	local bestTool, bestSlot, bestDamage = nil, nil, 0

	for slot, item in bedwarsStore.inventory.inventory.items do
		local meta = item and bedwars.ItemMeta and bedwars.ItemMeta[item.itemType]
		local tool = meta and meta.breakBlock
		local damage = tool and (tool[breakType] or 0) or 0

		if damage > bestDamage then
			bestTool, bestSlot, bestDamage = item, slot, damage
		end
	end

	return bestTool, bestSlot
end
getgenv().getTool = getTool

local function getWool()
	for _, item in bedwarsStore.inventory.inventory.items do
		if item and type(item.itemType) == "string" and item.itemType:find("wool") then
			return item.itemType, item.amount or 0
		end
	end

	return nil, 0
end
getgenv().getWool = getWool



local function getSpeed()
	local sprintController = bedwars.SprintController
	if not (sprintController and sprintController.getMovementStatusModifier) then
		return 20
	end

	local modifier = sprintController:getMovementStatusModifier()
	local modifiers = modifier and modifier:getModifier() or {}
	local multi, increase = 0, true

	for _, value in modifiers do
		local constant = value.constantSpeedMultiplier or 0
		if constant > math.max(multi, 1) then
			increase = false
			multi = constant - (0.06 * math.round(constant))
		end
	end

	for _, value in modifiers do
		multi += math.max((value.moveSpeedMultiplier or 0) - 1, 0)
	end

	if multi > 0 and increase then
		multi += 0.16 + (0.02 * math.round(multi))
	end

	return 20 * (multi + 1)
end
getgenv().getSpeed = getSpeed

local function getPower(player)
	if not player.Player then
		return 0
	end

	local power = 0
	for _, item in (bedwarsStore.inventories[player.Player] or { items = {} }).items do
		local meta = bedwars.ItemMeta and bedwars.ItemMeta[item.itemType]
		if meta and meta.sword and meta.sword.damage > power then
			power = meta.sword.damage
		end
	end

	return power
end
getgenv().getPower = getPower

local function getHotbar(tool)
	for i, item in (bedwarsStore.inventory.hotbar or {}) do
		if item.item and item.item.tool == tool then
			return i - 1
		end
	end
	return nil
end
getgenv().getHotbar = getHotbar

local function hotbarSwitch(slot)
	if slot and bedwarsStore.inventory.hotbarSlot ~= slot then
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
getgenv().hotbarSwitch = hotbarSwitch

local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild("HandInvItem") or nil
	if check and check.Value ~= tool and tool and tool.Parent ~= nil then
		task.spawn(function()
			if bedwars.Client and remotes.EquipItem then
				bedwars.Client:Get(remotes.EquipItem):CallServerAsync({ hand = tool })
			end
		end)
		check.Value = tool
		local meta = bedwars.ItemMeta and bedwars.ItemMeta[tool.Name]
		bedwarsStore.hand = {
			tool = tool,
			amount = 1,
			toolType = meta and (meta.sword and "sword" or meta.block and "block" or tool.Name:find("bow") and "bow") or "sword"
		}
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
end
getgenv().switchItem = switchItem

local function getPlacedBlocks(position)
	if not (position and bedwars.BlockController and bedwars.BlockController.getBlockPosition) then
		return nil
	end

	local blockPosition = bedwars.BlockController:getBlockPosition(position)
	local blockStore = bedwars.BlockController:getStore()
	return blockStore and blockStore:getBlockAt(blockPosition), blockPosition
end
getgenv().getPlacedBlocks = getPlacedBlocks
getgenv().getPlacedBlock = getPlacedBlocks

local function getBlocksInPoints(startPoint, endPoint)
	local blockStore = bedwars.BlockController and bedwars.BlockController:getStore()
	local list = {}

	if not blockStore then
		return list
	end

	for x = startPoint.X, endPoint.X do
		for y = startPoint.Y, endPoint.Y do
			for z = startPoint.Z, endPoint.Z do
				local vector = Vector3.new(x, y, z)
				if blockStore:getBlockAt(vector) or blockStore:getBlock(vector) then
					table.insert(list, vector * 3)
				end
			end
		end
	end

	return list
end
getgenv().getBlocksInPoints = getBlocksInPoints

local getBlockHits
local sortMethods, breakMethods = {
	Damage = function(x, y)
		return x.Entity.Character:GetAttribute("LastDamageTakenTime") < y.Entity.Character:GetAttribute("LastDamageTakenTime")
	end,
	Health = function(x, y)
		return x.Entity.Health < y.Entity.Health
	end,
	Threat = function(x, y)
		return getPower(x.Entity) > getPower(y.Entity)
	end
}, {
	Health = function(...)
		return getBlockHits and getBlockHits(...) or 0
	end,
	Distance = function(x)
		local position = (EntityTracker and EntityTracker.Alive and (EntityTracker.Character.RootPart.Position - Vector3.new(0, 1, 0)) or Vector3.zero)
		return (position - Vector3.new(x.Position.X, position.Y, x.Position.Z)).Magnitude
	end
}
getgenv().sortMethods = sortMethods
getgenv().breakMethods = breakMethods

local function loadBedwars()
	if Controllers and Controllers.load then
		local loadedBedwars, knit = Controllers.load(bedwars)
		bedwars = loadedBedwars or bedwars
		context.bedwars = bedwars

		if Remotes and Remotes.load then
			remotes = Remotes.load(knit or bedwars.Knit, remotes)
			context.remotes = remotes
		end
	end

	getgenv().bedwars = bedwars
	getgenv().remotes = remotes
	Main.bedwars = bedwars
	Main.remotes = remotes
	return bedwars, remotes
end
getgenv().loadBedwars = loadBedwars

local function syncStore()
	if not (bedwars.Store and type(bedwars.Store.getState) == "function") then
		return bedwarsStore
	end

	local function update(newState, oldState)
		newState = type(newState) == "table" and newState or {}
		oldState = type(oldState) == "table" and oldState or {}

		local gameState, oldGameState = newState.Game or {}, oldState.Game or {}
		if gameState ~= oldGameState then
			bedwarsStore.matchState = gameState.matchState or 0
			bedwarsStore.queueType = gameState.queueType or "bedwars"
		end

		local inventoryState, oldInventoryState = newState.Inventory or {}, oldState.Inventory or {}
		if inventoryState ~= oldInventoryState then
			local oldInventory = oldInventoryState.observedInventory or { inventory = {} }
			local newInventory = inventoryState.observedInventory or bedwarsStore.inventory
			bedwarsStore.inventory = newInventory

			if newInventory ~= oldInventory then
				bedwarsEvents.InventoryChanged:Fire()
			end

			if newInventory.inventory.items ~= oldInventory.inventory.items then
				bedwarsEvents.InventoryAmountChanged:Fire()
				bedwarsStore.tools.sword = getSword()

				for _, breakType in ipairs({ "wood", "stone", "wool" }) do
					bedwarsStore.tools[breakType] = getTool(breakType)
				end
			end

			if newInventory.inventory.hand ~= oldInventory.inventory.hand then
				local currentHand = newInventory.inventory.hand
				local handMeta = currentHand and bedwars.ItemMeta and bedwars.ItemMeta[currentHand.itemType]
				bedwarsStore.hand = {
					tool = currentHand and currentHand.tool,
					amount = currentHand and currentHand.amount or 0,
					toolType = handMeta and (handMeta.sword and "sword" or handMeta.block and "block" or currentHand.itemType:find("bow") and "bow") or ""
				}
			end
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

	return bedwarsStore
end
getgenv().syncStore = syncStore

Main.Taskium = Taskium
Main.TaskAPI = TaskAPI
Main.context = context
Main.Run = Run
Main.players = players
Main.replicatedStorage = replicatedStorage
Main.runService = runService
Main.tweenService = tweenService
Main.inputService = inputService
Main.contextAction = contextAction
Main.collectionService = collectionService
Main.workspace = workspace
Main.lplr = lplr
Main.gameCam = gameCam
Main.playerGui = playerGui
Main.EntityTracker = EntityTracker
Main.bedwarsStore = bedwarsStore
Main.bedwars = bedwars
Main.remotes = remotes
Main.bedwarsEvents = bedwarsEvents
Main.sides = sides
Main.runtimeState = runtimeState
Main.characterState = characterState
Main.collect = collect
Main.getItem = getItem
Main.getBestArmor = getBestArmor
Main.getSword = getSword
Main.getBow = getBow
Main.getTool = getTool
Main.getWool = getWool
Main.getSpeed = getSpeed
Main.getPower = getPower
Main.getHotbar = getHotbar
Main.hotbarSwitch = hotbarSwitch
Main.switchItem = switchItem
Main.getPlacedBlocks = getPlacedBlocks
Main.getBlocksInPoints = getBlocksInPoints
Main.sortMethods = sortMethods
Main.breakMethods = breakMethods
Main.loadBedwars = loadBedwars
Main.syncStore = syncStore

loadBedwars()
syncStore()

return Main
