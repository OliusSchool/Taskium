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

function EntityTracker.targetCheck(entity)
	if entity.TeamCheck then
		return entity:TeamCheck()
	end
	if entity.NPC then
		return true
	end
	if not lplr.Team or not entity.Player.Team then
		return true
	end
	if entity.Player.Team ~= lplr.Team then
		return true
	end

	return #entity.Player.Team:GetPlayers() == #players:GetPlayers()
end

function EntityTracker.getUpdateConnections(entity)
	local humanoid = entity.Humanoid
	return {
		humanoid:GetPropertyChangedSignal("Health"),
		humanoid:GetPropertyChangedSignal("MaxHealth")
	}
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

function EntityTracker.addEntity(char, player, teamCheck)
	if not char then
		return
	end

	EntityTracker.EntityThreads[char] = task.spawn(function()
		local humanoid = waitForChildOfType(char, "Humanoid", 10)
		local rootPart = humanoid and waitForChildOfType(humanoid, "RootPart", workspace.StreamingEnabled and 9e9 or 10, true)
		local head = char:WaitForChild("Head", 10) or rootPart

		if humanoid and rootPart then
			local entity = {
				Connections = {},
				Character = char,
				Health = humanoid.Health,
				Head = head,
				Humanoid = humanoid,
				HumanoidRootPart = rootPart,
				HipHeight = humanoid.HipHeight + (rootPart.Size.Y / 2) + (humanoid.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
				MaxHealth = humanoid.MaxHealth,
				NPC = player == nil,
				Player = player,
				RootPart = rootPart,
				TeamCheck = teamCheck
			}

			if player == lplr then
				setLocal(entity)
				EntityTracker.Events.LocalAdded:Fire(entity)
			else
				entity.Targetable = EntityTracker.targetCheck(entity)

				for _, signal in EntityTracker.getUpdateConnections(entity) do
					table.insert(entity.Connections, signal:Connect(function()
						entity.Health = humanoid.Health
						entity.MaxHealth = humanoid.MaxHealth
						EntityTracker.Events.EntityUpdated:Fire(entity)
					end))
				end

				table.insert(EntityTracker.List, entity)
				EntityTracker.Events.EntityAdded:Fire(entity)
			end
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

function EntityTracker.refreshEntity(char, player, teamCheck)
	EntityTracker.removeEntity(char, player == lplr)
	EntityTracker.addEntity(char, player, teamCheck)
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
		EntityTracker.refreshEntity(entity.Character, entity.Player, entity.TeamCheck)
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
