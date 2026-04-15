local HttpService = game:GetService("HttpService")

local RawGitUrl = "https://raw.githubusercontent.com/OliusSchool/Taskium/main/"
local RepoApiUrl = "https://api.github.com/repos/OliusSchool/Taskium/contents/"

local RootFolder = "Taskium"
local SyncStatePath = RootFolder .. "/Client/SyncState.json"
local Taskium = getgenv().Taskium or {}
getgenv().Taskium = Taskium

local BootstrapFiles = {
	"Client/Config.lua",
	"GUI/TaskUI.lua",
	"GUI/Categories.lua",
	"Games/Universal.lua"
}

local Folders = {
	"Taskium",
	"Taskium/Assets",
	"Taskium/Assets/GUI",
	"Taskium/Assets/Icons",
	"Taskium/Client",
	"Taskium/Games",
	"Taskium/GUI",
	"Taskium/Scripts"
}

local function HttpRequest(url)
	local response

	if syn and syn.request then
		response = syn.request({
			Url = url,
			Method = "GET"
		})
	elseif request then
		response = request({
			Url = url,
			Method = "GET"
		})
	elseif http_request then
		response = http_request({
			Url = url,
			Method = "GET"
		})
	else
		error("Taskium loader requires syn.request, request, or http_request")
	end

	return response
end

local function GetParentFolder(path)
	return path:match("^(.*)/[^/]+$")
end

local function CreateSyncReport()
	return {
		CreatedFolders = {},
		CreatedFiles = {},
		UpdatedFiles = {},
		PreservedFiles = {},
		FailedFiles = {}
	}
end

local SyncState = {
	FileHashes = {}
}

local function EnsureFolder(path, report)
	if not isfolder(path) then
		makefolder(path)
		if report then
			table.insert(report.CreatedFolders, path)
		end
	end
end

local function ComputeHash(content)
	local hash = 2166136261

	for index = 1, #content do
		hash = bit32.bxor(hash, string.byte(content, index))
		hash = (hash * 16777619) % 4294967296
	end

	return string.format("%08x", hash)
end

local function LoadSyncState()
	EnsureFolder(RootFolder)
	EnsureFolder(RootFolder .. "/Client")

	if isfile(SyncStatePath) then
		local success, decoded = pcall(function()
			return HttpService:JSONDecode(readfile(SyncStatePath))
		end)

		if success and type(decoded) == "table" then
			SyncState = decoded
		end
	end

	SyncState.FileHashes = SyncState.FileHashes or {}
end

local function SaveSyncState()
	EnsureFolder(RootFolder)
	EnsureFolder(RootFolder .. "/Client")
	writefile(SyncStatePath, HttpService:JSONEncode(SyncState))
end

local function DownloadFile(path, forceUpdate, report)
	local url = RawGitUrl .. path
	local savePath = RootFolder .. "/" .. path
	local fileExists = isfile(savePath)
	local parentFolder = GetParentFolder(savePath)

	if parentFolder then
		EnsureFolder(parentFolder, report)
	end

	local response = HttpRequest(url)

	if response.StatusCode == 200 then
		local remoteHash = ComputeHash(response.Body)
		local shouldWrite = true

		if fileExists then
			local oldContent = readfile(savePath)
			local localHash = ComputeHash(oldContent)
			local syncedHash = SyncState.FileHashes[path]

			if localHash == remoteHash then
				shouldWrite = false
			elseif not forceUpdate then
				if syncedHash and localHash ~= syncedHash then
					shouldWrite = false
					if report then
						table.insert(report.PreservedFiles, savePath)
					end
				elseif not syncedHash then
					shouldWrite = false
					if report then
						table.insert(report.PreservedFiles, savePath)
					end
				end
			end
		end

		if shouldWrite then
			writefile(savePath, response.Body)
			SyncState.FileHashes[path] = remoteHash
			if report then
				if fileExists then
					table.insert(report.UpdatedFiles, savePath)
				else
					table.insert(report.CreatedFiles, savePath)
				end
			end
		elseif fileExists and isfile(savePath) then
			SyncState.FileHashes[path] = ComputeHash(readfile(savePath))
		end

		return true
	end

	warn("Failed to download: " .. url)
	if report then
		table.insert(report.FailedFiles, savePath)
	end
	return false
end

local function GetAllFilesRecursive(folder, collectedFiles)
	collectedFiles = collectedFiles or {}

	local apiUrl = RepoApiUrl .. folder
	local response = HttpRequest(apiUrl)

	if response.StatusCode ~= 200 then
		warn("Failed to get directory listing for: " .. folder)
		return collectedFiles
	end

	local data = HttpService:JSONDecode(response.Body)

	for _, item in ipairs(data) do
		if item.type == "file" then
			table.insert(collectedFiles, item.path or (folder .. "/" .. item.name))
		elseif item.type == "dir" then
			GetAllFilesRecursive(item.path or (folder .. "/" .. item.name), collectedFiles)
		end
	end

	return collectedFiles
end

local function SyncTaskiumFiles(forceUpdate)
	local report = CreateSyncReport()
	local queuedFiles = {}

	for _, folder in ipairs(Folders) do
		EnsureFolder(folder, report)
	end

	local files = GetAllFilesRecursive("")
	if #files == 0 then
		warn("No files found in repository.")
	end

	for _, file in ipairs(files) do
		queuedFiles[file] = true
	end

	for file in pairs(queuedFiles) do
		DownloadFile(file, forceUpdate, report)
	end

	SaveSyncState()

	Taskium.LastSyncReport = report
	return report
end

local function EnsureBootstrapFiles(report)
	for _, file in ipairs(BootstrapFiles) do
		local savePath = RootFolder .. "/" .. file
		if not isfile(savePath) then
			local success = DownloadFile(file, true, report)
			if not success then
				warn("Failed to bootstrap file: " .. file)
			end
		end
	end

	SaveSyncState()
end

local function ExecuteFile(path)
	local success, content = pcall(readfile, path)
	if not success then
		warn("Failed to read file: " .. path)
		return nil
	end

	local fn, err = loadstring(content, "@" .. path)
	if not fn then
		warn("Failed to load " .. path .. ": " .. tostring(err))
		return nil
	end

	return fn()
end

local function BootTaskium()
	EnsureBootstrapFiles(Taskium.LastSyncReport or CreateSyncReport())

	if Taskium.API and type(Taskium.API.Shutdown) == "function" then
		pcall(function()
			Taskium.API:Shutdown()
		end)
	end

	local config = ExecuteFile("Taskium/Client/Config.lua")
	Taskium.Config = config

	local TaskAPI = ExecuteFile("Taskium/GUI/TaskUI.lua")
	if not TaskAPI then
		warn("Taskium bootstrap could not find Taskium/GUI/TaskUI.lua")
		return nil
	end

	getgenv().TaskAPI = TaskAPI
	Taskium.API = TaskAPI
	TaskAPI.Config = config

	ExecuteFile("Taskium/GUI/Categories.lua")
	ExecuteFile("Taskium/Games/Universal.lua")

	return TaskAPI
end

local function RestartTaskium()
	return BootTaskium()
end

Taskium.SyncTaskiumFiles = SyncTaskiumFiles
Taskium.ExecuteFile = ExecuteFile
Taskium.RestartTaskium = RestartTaskium
Taskium.LastSyncReport = nil

LoadSyncState()

local InitialSyncReport = SyncTaskiumFiles(false)
EnsureBootstrapFiles(InitialSyncReport)
Taskium.LastSyncReport = InitialSyncReport

local TaskAPI = BootTaskium()

if TaskAPI then
	local createdFolderCount = #InitialSyncReport.CreatedFolders
	local createdFileCount = #InitialSyncReport.CreatedFiles
	local updatedFileCount = #InitialSyncReport.UpdatedFiles

	if createdFolderCount > 0 then
		TaskAPI.Notification("Taskium", ("Created %d folder(s)."):format(createdFolderCount), 3, "Info")
	end

	if createdFileCount > 0 or updatedFileCount > 0 then
		TaskAPI.Notification("Taskium", ("Files synced: %d new, %d updated."):format(createdFileCount, updatedFileCount), 3, "Success")
	end

	if Taskium and Taskium.API then
		TaskAPI.Notification("Taskium", "Taskium initialized successfully!", 3, "Success")
	else
		TaskAPI.Notification("Taskium", "Taskium failed to initialize properly", 5, "Error")
	end
end

return TaskAPI
