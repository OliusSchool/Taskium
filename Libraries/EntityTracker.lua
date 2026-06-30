local EntityTracker = {
	Alive = false,
	Character = {},
	List = {},
	Connections = {},
	PlayerConnections = {},
	EntityThreads = {},
	Running = false,
	Events = setmetatable({}, {
		__index = function(self, name)
			self[name] = {
				Connections = {},
				Connect = function(event, func)
					table.insert(event.Connections, func)
					return {
						Disconnect = function()
							local index = table.find(event.Connections, func)
							if index then
								table.remove(event.Connections, index)
							end
						end
					}
				end,
				Fire = function(event, ...)
					for _, func in event.Connections do
						task.spawn(func, ...)
					end
				end,
				Destroy = function(event)
					table.clear(event.Connections)
					table.clear(event)
				end
			}

			return self[name]
		end
	})
}

local cloneref = cloneref or function(obj)
	return obj
end

local players = cloneref(game:GetService("Players"))
local inputService = cloneref(game:GetService("UserInputService"))
local collectionService = cloneref(game:GetService("CollectionService"))
local lplr = players.LocalPlayer
local gameCam = workspace.CurrentCamera

local function setLocal(entity)
	EntityTracker.Character = entity or {}
	EntityTracker.Alive = entity ~= nil
end

local function getMousePosition()
	if inputService.TouchEnabled then
		return gameCam.ViewportSize / 2
	end

	return inputService:GetMouseLocation()
end

local function clearDeep(tab)
	for index, value in tab do
		if type(value) == "table" then
			clearDeep(value)
		end
		tab[index] = nil
	end
end

local function waitForChildOfType(obj, name, timeout, prop)
	local expire = tick() + timeout
	local found

	repeat
		found = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if found or expire < tick() then
			break
		end
		task.wait()
	until false

	return found
end

local function getShieldAttribute(character)
	local shield = 0
	if not character then
		return shield
	end

	for name, value in character:GetAttributes() do
		if type(name) == "string" and name:find("Shield") and type(value) == "number" and value > 0 then
			shield += value
		end
	end

	return shield
end

local function getTaggedModel(instance)
	if not instance then
		return nil
	end

	if instance:IsA("Model") then
		return instance
	end

	return instance:FindFirstAncestorOfClass("Model")
end

local function getRootPart(character, humanoid)
	if not character then
		return nil
	end

	return (humanoid and humanoid.RootPart)
		or character.PrimaryPart
		or character:FindFirstChild("HumanoidRootPart")
		or character:FindFirstChild("RootPart")
		or character:FindFirstChild("Head")
		or character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
		or character:FindFirstChildWhichIsA("BasePart", true)
end

local function waitForRootPart(character, humanoid, timeout)
	local expire = tick() + timeout
	local rootPart

	repeat
		rootPart = getRootPart(character, humanoid)
		if rootPart or expire < tick() then
			break
		end
		task.wait()
	until false

	return rootPart
end

local function getHealth(character, humanoid)
	local health = character and character:GetAttribute("Health")
	local maxHealth = character and character:GetAttribute("MaxHealth")
	if typeof(health) ~= "number" then
		health = humanoid and humanoid.Health or 100
	end
	if typeof(maxHealth) ~= "number" then
		maxHealth = humanoid and humanoid.MaxHealth or health
	end
	return health + getShieldAttribute(character), maxHealth
end

local function makeNpcHumanoid(character, rootPart)
	local health, maxHealth = getHealth(character)
	return {
		Health = health,
		MaxHealth = maxHealth,
		HipHeight = 0.5,
		FloorMaterial = Enum.Material.Plastic,
		RootPart = rootPart
	}
end

local function hasTag(character, taggedInstance, tag)
	return (character and collectionService:HasTag(character, tag))
		or (taggedInstance and collectionService:HasTag(taggedInstance, tag))
end

function EntityTracker.targetCheck(entity)
	if entity.TeamCheck then
		return entity:TeamCheck()
	end
	if entity.Character and collectionService:HasTag(entity.Character, "petrified-player") then
		return false
	end
	if entity.TaggedInstance and collectionService:HasTag(entity.TaggedInstance, "petrified-player") then
		return false
	end
	if entity.NPC then
		local localTeam = lplr and lplr:GetAttribute("Team")
		local targetTeam = entity.Character and entity.Character:GetAttribute("Team")
		return localTeam == nil or targetTeam == nil or localTeam ~= targetTeam
	end
	local localTeam = lplr and lplr:GetAttribute("Team")
	local playerTeam = entity.Player and entity.Player:GetAttribute("Team")
	if localTeam ~= nil and playerTeam ~= nil then
		return localTeam ~= playerTeam
	end
	if not lplr.Team or not entity.Player or not entity.Player.Team then
		return true
	end
	if entity.Player.Team ~= lplr.Team then
		return true
	end

	return #entity.Player.Team:GetPlayers() == #players:GetPlayers()
end

function EntityTracker.getUpdateConnections(entity)
	local humanoid = entity.Humanoid
	local character = entity.Character
	local signals = {
		character:GetAttributeChangedSignal("Health"),
		character:GetAttributeChangedSignal("MaxHealth"),
	}

	if typeof(humanoid) == "Instance" then
		table.insert(signals, humanoid:GetPropertyChangedSignal("Health"))
		table.insert(signals, humanoid:GetPropertyChangedSignal("MaxHealth"))
	end

	for name, value in character:GetAttributes() do
		if type(name) == "string" and name:find("Shield") and type(value) == "number" then
			table.insert(signals, character:GetAttributeChangedSignal(name))
		end
	end

	if entity.NPC then
		table.insert(signals, {
			Connect = function(_, func)
				return character:GetAttributeChangedSignal("Team"):Connect(function()
					entity.Targetable = EntityTracker.targetCheck(entity)
					func()
				end)
			end
		})
	end

	return signals
end

function EntityTracker.isVulnerable(entity)
	return entity.Health > 0 and not entity.Character:FindFirstChildWhichIsA("ForceField")
end

function EntityTracker.getEntityColor(entity)
	local player = entity.Player
	return player and tostring(player.TeamColor) ~= "White" and player.TeamColor.Color or nil
end

EntityTracker.IgnoreObject = RaycastParams.new()
EntityTracker.IgnoreObject.RespectCanCollide = true

function EntityTracker.Wallcheck(origin, position, ignoreObject)
	if typeof(ignoreObject) ~= "Instance" then
		local ignoreList = {gameCam, lplr.Character}

		for _, entity in EntityTracker.List do
			if entity.Targetable then
				table.insert(ignoreList, entity.Character)
			end
		end

		if typeof(ignoreObject) == "table" then
			for _, obj in ignoreObject do
				table.insert(ignoreList, obj)
			end
		end

		ignoreObject = EntityTracker.IgnoreObject
		ignoreObject.FilterDescendantsInstances = ignoreList
	end

	return workspace:Raycast(origin, position - origin, ignoreObject)
end

function EntityTracker.EntityMouse(settings)
	if EntityTracker.Alive then
		local mouseLocation = settings.MouseOrigin or getMousePosition()
		local sorted = {}

		for _, entity in EntityTracker.List do
			if not settings.Players and entity.Player then continue end
			if not settings.NPCs and entity.NPC then continue end
			if not entity.Targetable then continue end

			local position, visible = gameCam:WorldToViewportPoint(entity[settings.Part].Position)
			if not visible then continue end

			local distance = (mouseLocation - Vector2.new(position.X, position.Y)).Magnitude
			if distance > settings.Range then continue end

			if EntityTracker.isVulnerable(entity) then
				table.insert(sorted, {
					Entity = entity,
					Magnitude = entity.Target and -1 or distance
				})
			end
		end

		table.sort(sorted, settings.Sort or function(a, b)
			return a.Magnitude < b.Magnitude
		end)

		for _, item in sorted do
			if settings.Wallcheck and EntityTracker.Wallcheck(settings.Origin, item.Entity[settings.Part].Position, settings.Wallcheck) then
				continue
			end

			table.clear(settings)
			table.clear(sorted)
			return item.Entity
		end

		table.clear(sorted)
	end

	table.clear(settings)
end

function EntityTracker.EntityPosition(settings)
	if EntityTracker.Alive then
		local localPosition = settings.Origin or EntityTracker.Character.HumanoidRootPart.Position
		local sorted = {}

		for _, entity in EntityTracker.List do
			if not settings.Players and entity.Player then continue end
			if not settings.NPCs and entity.NPC then continue end
			if not entity.Targetable then continue end

			local distance = (entity[settings.Part].Position - localPosition).Magnitude
			if distance > settings.Range then continue end

			if EntityTracker.isVulnerable(entity) then
				table.insert(sorted, {
					Entity = entity,
					Magnitude = entity.Target and -1 or distance
				})
			end
		end

		table.sort(sorted, settings.Sort or function(a, b)
			return a.Magnitude < b.Magnitude
		end)

		if settings.Priority then
			table.sort(sorted, settings.Priority)
		end

		for _, item in sorted do
			if settings.Wallcheck and EntityTracker.Wallcheck(localPosition, item.Entity[settings.Part].Position, settings.Wallcheck) then
				continue
			end

			table.clear(settings)
			table.clear(sorted)
			return item.Entity
		end

		table.clear(sorted)
	end

	table.clear(settings)
end

function EntityTracker.AllPosition(settings)
	local results = {}

	if EntityTracker.Alive then
		local localPosition = settings.Origin or EntityTracker.Character.HumanoidRootPart.Position
		local sorted = {}

		for _, entity in EntityTracker.List do
			if not settings.Players and entity.Player then continue end
			if not settings.NPCs and entity.NPC then continue end
			if not entity.Targetable then continue end

			local distance = (entity[settings.Part].Position - localPosition).Magnitude
			if distance > settings.Range then continue end

			if EntityTracker.isVulnerable(entity) then
				table.insert(sorted, {
					Entity = entity,
					Magnitude = entity.Target and -1 or distance
				})
			end
		end

		table.sort(sorted, settings.Sort or function(a, b)
			return a.Magnitude < b.Magnitude
		end)

		for _, item in sorted do
			if settings.Wallcheck and EntityTracker.Wallcheck(localPosition, item.Entity[settings.Part].Position, settings.Wallcheck) then
				continue
			end

			table.insert(results, item.Entity)
			if #results >= (settings.Limit or math.huge) then
				break
			end
		end

		table.clear(sorted)
	end

	table.clear(settings)
	return results
end

function EntityTracker.getEntity(char)
	for index, entity in EntityTracker.List do
		if entity.Player == char or entity.Character == char then
			return entity, index
		end
	end
end

function EntityTracker.addEntity(char, player, teamCheck, taggedInstance)
	if not char then
		return
	end
	if EntityTracker.getEntity(char) or EntityTracker.EntityThreads[char] then
		return
	end

	EntityTracker.EntityThreads[char] = task.spawn(function()
		local humanoid = player and waitForChildOfType(char, "Humanoid", 10) or char:FindFirstChildOfClass("Humanoid")
		local rootPart = player and humanoid and waitForChildOfType(humanoid, "RootPart", workspace.StreamingEnabled and 9e9 or 10, true) or waitForRootPart(char, humanoid, 10)
		local head = char:FindFirstChild("Head") or rootPart

		if rootPart then
			humanoid = humanoid or makeNpcHumanoid(char, rootPart)
			local health, maxHealth = getHealth(char, humanoid)
			local entity = {
				Connections = {},
				Character = char,
				Health = health,
				Head = head,
				Humanoid = humanoid,
				HumanoidRootPart = rootPart,
				HipHeight = (humanoid.HipHeight or 0.5) + (rootPart.Size.Y / 2) + (humanoid.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
				MaxHealth = maxHealth,
				NPC = player == nil,
				Player = player,
				RootPart = rootPart,
				TaggedInstance = taggedInstance,
				TeamCheck = teamCheck
			}

			if player == lplr then
				setLocal(entity)
				EntityTracker.Events.LocalAdded:Fire(entity)
			else
				entity.Targetable = EntityTracker.targetCheck(entity)

				for _, signal in EntityTracker.getUpdateConnections(entity) do
					table.insert(entity.Connections, signal:Connect(function()
						local newHealth, newMaxHealth = getHealth(char, typeof(humanoid) == "Instance" and humanoid or nil)
						entity.Health = newHealth
						entity.MaxHealth = newMaxHealth
						EntityTracker.Events.EntityUpdated:Fire(entity)
					end))
				end

				table.insert(EntityTracker.List, entity)
				EntityTracker.Events.EntityAdded:Fire(entity)
			end

			table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
				if part == rootPart or part == head or part == humanoid then
					local newRootPart = getRootPart(char, typeof(humanoid) == "Instance" and humanoid or nil)
					if newRootPart and newRootPart ~= rootPart then
						rootPart = newRootPart
						entity.RootPart = rootPart
						entity.HumanoidRootPart = rootPart
						entity.Head = char:FindFirstChild("Head") or rootPart
						return
					end
					EntityTracker.removeEntity(char, player == lplr)
				end
			end))
		end

		EntityTracker.EntityThreads[char] = nil
	end)
end

function EntityTracker.removeEntity(char, localCheck)
	if localCheck then
		if EntityTracker.Alive then
			local old = EntityTracker.Character
			for _, connection in old.Connections or {} do
				connection:Disconnect()
			end
			if old.Connections then
				table.clear(old.Connections)
			end
			setLocal(nil)
			EntityTracker.Events.LocalRemoved:Fire(old)
		end
		return
	end

	if not char then
		return
	end

	if EntityTracker.EntityThreads[char] then
		task.cancel(EntityTracker.EntityThreads[char])
		EntityTracker.EntityThreads[char] = nil
	end

	local entity, index = EntityTracker.getEntity(char)
	if index then
		for _, connection in entity.Connections do
			connection:Disconnect()
		end
		table.clear(entity.Connections)
		table.remove(EntityTracker.List, index)
		EntityTracker.Events.EntityRemoved:Fire(entity)
	end
end

function EntityTracker.refreshEntity(char, player, teamCheck, taggedInstance)
	EntityTracker.removeEntity(char, player == lplr)
	EntityTracker.addEntity(char, player, teamCheck, taggedInstance)
end

function EntityTracker.addCustomEntity(instance, tagName)
	local character = getTaggedModel(instance)
	if not character or players:GetPlayerFromCharacter(character) then
		return
	end

	if tagName == "entity"
		and hasTag(character, instance, "inventory-entity")
		and not hasTag(character, instance, "Monster")
		and not hasTag(character, instance, "trainingRoomDummy") then
		return
	end

	local teamCheck = function(entity)
		if hasTag(character, instance, "Drone") then
			local droneUserId = character:GetAttribute("PlayerUserId")
			local dronePlayer = type(droneUserId) == "number" and players:GetPlayerByUserId(droneUserId) or nil
			return not dronePlayer or lplr:GetAttribute("Team") ~= dronePlayer:GetAttribute("Team")
		end

		local localTeam = lplr:GetAttribute("Team")
		local targetTeam = character:GetAttribute("Team")
		return localTeam == nil or targetTeam == nil or localTeam ~= targetTeam
	end

	EntityTracker.addEntity(character, nil, teamCheck, instance)
end

function EntityTracker.removeCustomEntity(instance)
	local character = getTaggedModel(instance) or instance
	EntityTracker.removeEntity(character)
end

function EntityTracker.addPlayer(player)
	if player.Character then
		EntityTracker.refreshEntity(player.Character, player)
	end

	EntityTracker.PlayerConnections[player] = {
		player.CharacterAdded:Connect(function(char)
			EntityTracker.refreshEntity(char, player)
		end),
		player.CharacterRemoving:Connect(function(char)
			EntityTracker.removeEntity(char, player == lplr)
		end),
		player:GetPropertyChangedSignal("Team"):Connect(function()
			for _, entity in EntityTracker.List do
				local targetable = EntityTracker.targetCheck(entity)
				if entity.Targetable ~= targetable then
					entity.Targetable = targetable
					EntityTracker.Events.EntityUpdated:Fire(entity)
				end
			end

			if player ~= lplr and player.Character then
				EntityTracker.refreshEntity(player.Character, player)
			end
		end)
	}
end

function EntityTracker.removePlayer(player)
	if EntityTracker.PlayerConnections[player] then
		for _, connection in EntityTracker.PlayerConnections[player] do
			connection:Disconnect()
		end
		table.clear(EntityTracker.PlayerConnections[player])
		EntityTracker.PlayerConnections[player] = nil
	end

	EntityTracker.removeEntity(player.Character or player, player == lplr)
end

function EntityTracker.start()
	if EntityTracker.Running then
		EntityTracker.stop()
	end

	table.insert(EntityTracker.Connections, players.PlayerAdded:Connect(function(player)
		EntityTracker.addPlayer(player)
	end))
	table.insert(EntityTracker.Connections, players.PlayerRemoving:Connect(function(player)
		EntityTracker.removePlayer(player)
	end))
	table.insert(EntityTracker.Connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		gameCam = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA("Camera")
	end))

	for _, player in players:GetPlayers() do
		EntityTracker.addPlayer(player)
	end

	for _, tagName in { "entity", "Monster", "trainingRoomDummy" } do
		for _, instance in collectionService:GetTagged(tagName) do
			EntityTracker.addCustomEntity(instance, tagName)
		end
		table.insert(EntityTracker.Connections, collectionService:GetInstanceAddedSignal(tagName):Connect(function(instance)
			EntityTracker.addCustomEntity(instance, tagName)
		end))
		table.insert(EntityTracker.Connections, collectionService:GetInstanceRemovedSignal(tagName):Connect(function(instance)
			EntityTracker.removeCustomEntity(instance)
		end))
	end

	EntityTracker.Running = true
end

function EntityTracker.stop()
	for _, connection in EntityTracker.Connections do
		connection:Disconnect()
	end

	for _, connections in EntityTracker.PlayerConnections do
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end

	EntityTracker.removeEntity(nil, true)

	local entities = table.clone(EntityTracker.List)
	for _, entity in entities do
		EntityTracker.removeEntity(entity.Character)
	end

	for _, thread in EntityTracker.EntityThreads do
		task.cancel(thread)
	end

	table.clear(entities)
	table.clear(EntityTracker.PlayerConnections)
	table.clear(EntityTracker.EntityThreads)
	table.clear(EntityTracker.Connections)
	EntityTracker.Running = false
end

function EntityTracker.refresh()
	local entities = table.clone(EntityTracker.List)
	for _, entity in entities do
		EntityTracker.refreshEntity(entity.Character, entity.Player, entity.TeamCheck, entity.TaggedInstance)
	end
	table.clear(entities)
end

function EntityTracker.kill()
	if EntityTracker.Running then
		EntityTracker.stop()
	end

	for _, event in EntityTracker.Events do
		event:Destroy()
	end

	EntityTracker.IgnoreObject:Destroy()
	clearDeep(EntityTracker)
end

EntityTracker.start()

return EntityTracker
