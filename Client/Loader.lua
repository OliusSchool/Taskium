local players = game:GetService("Players")
local http = game:GetService("HttpService")
repeat task.wait() until game:IsLoaded()

local folder = "Taskium"
local commitPath = folder .. "/Client/Commit.txt"
local raw = "https://raw.githubusercontent.com/OliusSchool/Taskium/"
local repo = "https://github.com/OliusSchool/Taskium"
local tree = "https://api.github.com/repos/OliusSchool/Taskium/git/trees/"
local mark = "--Taskium cached file, remove this line to keep local edits after updates.\n"

local Taskium = getgenv().Taskium or {}
getgenv().Taskium = Taskium
shared.Taskium = Taskium
Taskium.Libraries = Taskium.Libraries or {}

local del = delfile or function(path)
	writefile(path, "")
end

local function make(path)
	if not isfolder(path) then
		makefolder(path)
	end
end

local function cached(path)
	return isfile(path) and readfile(path):sub(1, #mark) == mark
end

local function clean(path)
	if not isfolder(path) then
		return
	end

	for _, item in ipairs(listfiles(path)) do
		if isfolder(item) then
			clean(item)
		elseif not item:lower():find("loader", 1, true) and cached(item) then
			del(item)
		end
	end
end

local function commit()
	local ok, body = pcall(game.HttpGet, game, repo, true)
	local at = ok and body:find("currentOid")
	local sha = at and body:sub(at + 13, at + 52) or "main"
	return #sha == 40 and sha or "main"
end

local function repoFiles(sha)
	local ok, body = pcall(game.HttpGet, game, tree .. sha .. "?recursive=1", true)
	if not ok then
		error(tostring(body))
	end

	local dirs, files = { folder }, {}
	for _, item in ipairs((http:JSONDecode(body).tree or {})) do
		if item.path and item.type == "tree" then
			table.insert(dirs, folder .. "/" .. item.path)
		elseif item.path and item.type == "blob" then
			table.insert(files, item.path)
		end
	end

	table.sort(dirs, function(a, b)
		return #a == #b and a < b or #a < #b
	end)
	table.sort(files)

	return dirs, files
end

local function dl(rel)
	local path = folder .. "/" .. rel
	if not isfile(path) or cached(path) then
		local ok, body = pcall(game.HttpGet, game, raw .. readfile(commitPath) .. "/" .. rel, true)
		if not ok or body == "404: Not Found" then
			warn("Failed to download " .. rel .. ": " .. tostring(body))
			return isfile(path) and readfile(path) or ""
		end
		writefile(path, rel:find("%.lua$") and (mark .. body) or body)
	end
	return readfile(path)
end

local function exec(path)
	local rel = path:gsub("^" .. folder .. "/", "")
	local src = isfile(path) and readfile(path) or dl(rel)
	if src == "" then
		return nil
	end
	local fn, err = loadstring(src:gsub("^" .. mark:gsub("%-", "%%-"), ""), "@" .. path)
	if not fn then
		return warn("Failed to load " .. path .. ": " .. tostring(err))
	end

	local ok, res = pcall(fn)
	if not ok then
		return warn("Failed to run " .. path .. ": " .. tostring(res))
	end
	return res
end

local function luaFiles(path, list)
	list = list or {}
	if not isfolder(path) then
		return list
	end

	for _, item in ipairs(listfiles(path)) do
		if isfolder(item) then
			luaFiles(item, list)
		elseif item:sub(-4) == ".lua" then
			table.insert(list, item)
		end
	end

	table.sort(list)
	return list
end

local function loadBedwars()
	local main = folder .. "/Games/Bedwars/Main.lua"
	if not isfile(main) and isfile(folder .. "/Games/Bedwars/Categories/Main.lua") then
		writefile(main, readfile(folder .. "/Games/Bedwars/Categories/Main.lua"))
	end

	exec(main)

	for _, path in ipairs(luaFiles(folder .. "/Games/Bedwars/Categories")) do
		exec(path)
	end
end

local function sync()
	make(folder)
	make(folder .. "/Client")

	local sha = commit()
	if (isfile(commitPath) and readfile(commitPath) or "") ~= sha then
		for _, path in ipairs({ folder .. "/Client", folder .. "/Games", folder .. "/GUI", folder .. "/Libraries", folder .. "/Scripts" }) do
			clean(path)
		end
		writefile(commitPath, sha)
	end

	local dirs, files = repoFiles(readfile(commitPath))
	for _, path in ipairs(dirs) do
		make(path)
	end
	for _, file in ipairs(files) do
		dl(file)
	end
end

local function qtp()
	return queue_on_teleport or queueonteleport or syn and syn.queue_on_teleport or fluxus and fluxus.queue_on_teleport
end

function Taskium.QueueTaskiumOnTeleport()
	local q = qtp()
	local gameFile = Taskium.GameFile
	local script = 'repeat task.wait() until game:IsLoaded()\nlocal path = "Taskium/Client/Loader.lua"\nlocal src = isfile and isfile(path) and readfile(path)\nif src then loadstring(src, "@" .. path)() end'
	if type(gameFile) == "string" and gameFile ~= "" then
		script = ("getgenv().TaskiumGameFile = %q\n"):format(gameFile) .. script
	end
	Taskium.TeleportQueueArmed = q and pcall(q, script) or false
	return Taskium.TeleportQueueArmed
end

function Taskium.ArmTeleportQueueWatcher()
	if Taskium.TeleportQueueConnection then
		pcall(function()
			Taskium.TeleportQueueConnection:Disconnect()
		end)
	end

	local plr, queued = players.LocalPlayer, false
	Taskium.TeleportQueueConnection = plr and plr.OnTeleport:Connect(function()
		if not queued then
			queued = Taskium.QueueTaskiumOnTeleport()
		end
	end) or nil

	return Taskium.TeleportQueueConnection ~= nil
end

function Taskium.ExecuteFile(path)
	return exec(path)
end

function Taskium.LoadLibrary(name)
	if Taskium.Libraries[name] then
		return Taskium.Libraries[name]
	end

	local lib = exec(folder .. "/Libraries/" .. name .. ".lua")
	Taskium.Libraries[name] = lib
	return lib
end

function Taskium.SyncTaskiumFiles()
	sync()
	return { CreatedFolders = {}, CreatedFiles = {}, MergedFiles = {}, UpdatedFiles = {}, PreservedFiles = {}, FailedFiles = {} }
end

function Taskium.RestartTaskium()
	if Taskium.API and type(Taskium.API.Shutdown) == "function" then
		pcall(function()
			Taskium.API:Shutdown()
		end)
	end

	local cfg = exec(folder .. "/Client/Config.lua")
	local api = exec(folder .. "/GUI/TaskUI.lua")
	if not api then
		return warn("Taskium bootstrap could not find Taskium/GUI/TaskUI.lua")
	end

	getgenv().TaskAPI = api
	Taskium.API = api
	Taskium.Config = cfg
	api.Config = cfg
	api.BedwarsMain = nil

	exec(folder .. "/GUI/Categories.lua")

	local games = exec(folder .. "/Games/Games.lua") or {}
	local queuedGameFile = getgenv().TaskiumGameFile
	if queuedGameFile == "" then
		queuedGameFile = nil
	end

	local gameFile = queuedGameFile
		or (games.GameIds and games.GameIds[game.GameId])
		or (games.PlaceIds and games.PlaceIds[game.PlaceId])
		or games.Default
		or "Universal.lua"
	getgenv().TaskiumGameFile = nil
	Taskium.GameFile = gameFile

	if gameFile == "Bedwars/Main.lua" then
		loadBedwars()
	else
		exec(folder .. "/Games/" .. gameFile)
	end

	return api
end

sync()

local api = Taskium.RestartTaskium()
pcall(Taskium.ArmTeleportQueueWatcher)
if api then
	api.Notification("Taskium", "Taskium initialized successfully!", 3, "Success")
end

return api
