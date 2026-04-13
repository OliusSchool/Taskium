local BASE_URL = "https://raw.githubusercontent.com/OliusSchool/Taskium/main/"
local ROOT_FOLDER = "Taskium"

local REQUIRED_FOLDERS = {
	"Assets",
	"Assets/GUI",
	"Assets/Icons",
	"Games",
	"GUI",
	"Scripts"
}

local REQUIRED_FILES = {
	"GUI/TaskUI.lua",
	"GUI/Categories.lua",
	"GUI/Notifications.lua",
	"GUI/BetaUI.lua",
	"Games/Universal.lua",
	"Games/Extra.lua",
	"Games/Arsenal.lua",
	"Games/Bedwars.lua",
	"Games/BedwarsLobby.lua",
	"Scripts/InfiniteYield.lua",
	"Scripts/RemoteSpy.lua",
	"Scripts/sUNC.lua",
	"Assets/GUI/test.txt",
	"Assets/Icons/test.txt"
}

local FILE_APIS = {
	isfolder = isfolder,
	makefolder = makefolder,
	isfile = isfile,
	writefile = writefile,
	readfile = readfile
}

for apiName, apiValue in pairs(FILE_APIS) do
	if type(apiValue) ~= "function" then
		error(("Taskium loader requires executor file API '%s'"):format(apiName))
	end
end

local function normalizePath(path)
	return path:gsub("\\", "/")
end

local function joinPath(...)
	return table.concat({ ... }, "/")
end

local function ensureFolder(path)
	path = normalizePath(path)

	if FILE_APIS.isfolder(path) then
		return
	end

	local segments = {}
	for segment in string.gmatch(path, "[^/]+") do
		table.insert(segments, segment)
	end

	local currentPath = ""
	for _, segment in ipairs(segments) do
		currentPath = currentPath == "" and segment or (currentPath .. "/" .. segment)
		if not FILE_APIS.isfolder(currentPath) then
			FILE_APIS.makefolder(currentPath)
		end
	end
end

local function readLocalFile(path)
	if not FILE_APIS.isfile(path) then
		return nil
	end

	return FILE_APIS.readfile(path)
end

local function fetchRemoteFile(relativePath)
	return game:HttpGet(BASE_URL .. relativePath, true)
end

local function syncFile(relativePath)
	local localPath = joinPath(ROOT_FOLDER, normalizePath(relativePath))
	local folderPath = localPath:match("^(.*)/[^/]+$")

	if folderPath then
		ensureFolder(folderPath)
	end

	local remoteSource = fetchRemoteFile(relativePath)
	local localSource = readLocalFile(localPath)

	if localSource ~= remoteSource then
		FILE_APIS.writefile(localPath, remoteSource)
	end

	return localPath, remoteSource
end

local function loadLocalFile(relativePath)
	local localPath, source = syncFile(relativePath)
	local chunk, err = loadstring(source, "@" .. localPath)

	if not chunk then
		error(("Failed to compile %s: %s"):format(relativePath, tostring(err)))
	end

	return chunk()
end

ensureFolder(ROOT_FOLDER)

for _, folder in ipairs(REQUIRED_FOLDERS) do
	ensureFolder(joinPath(ROOT_FOLDER, folder))
end

for _, filePath in ipairs(REQUIRED_FILES) do
	syncFile(filePath)
end

local TaskAPI = loadLocalFile("GUI/TaskUI.lua")
loadLocalFile("GUI/Categories.lua")
loadLocalFile("Games/Universal.lua")

return TaskAPI
