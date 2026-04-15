local HttpService = game:GetService("HttpService")

local RawGitUrl = "https://raw.githubusercontent.com/OliusSchool/Taskium/main/"
local RepoApiUrl = "https://api.github.com/repos/OliusSchool/Taskium/contents/"

local RootFolder = "Taskium"
local BaseFolder = RootFolder .. "/Client/Base"
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
	"Taskium/Client/Base",
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
		MergedFiles = {},
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

local function GetBaseFilePath(path)
	return BaseFolder .. "/" .. path
end

local function ReadBaseContent(path)
	local basePath = GetBaseFilePath(path)
	if isfile(basePath) then
		return readfile(basePath)
	end

	return nil
end

local function WriteBaseContent(path, content)
	local basePath = GetBaseFilePath(path)
	local parentFolder = GetParentFolder(basePath)
	if parentFolder then
		EnsureFolder(parentFolder)
	end

	writefile(basePath, content)
end

local function IsTextContent(content)
	return not string.find(content, "\0", 1, true)
end

local function SplitLines(content)
	local newline = string.find(content, "\r\n", 1, true) and "\r\n" or "\n"
	local normalized = string.gsub(content, "\r\n", "\n")
	local hasTrailingNewline = normalized:sub(-1) == "\n"

	if hasTrailingNewline then
		normalized = normalized:sub(1, -2)
	end

	local lines = {}
	if normalized ~= "" then
		for line in string.gmatch(normalized .. "\n", "(.-)\n") do
			table.insert(lines, line)
		end
	end

	return lines, newline, hasTrailingNewline
end

local function JoinLines(lines, newline, hasTrailingNewline)
	local content = table.concat(lines, newline)
	if hasTrailingNewline then
		content = content .. newline
	end

	return content
end

local function BuildLCSMatches(baseLines, otherLines)
	local baseCount = #baseLines
	local otherCount = #otherLines
	local cellCount = (baseCount + 1) * (otherCount + 1)

	if cellCount > 250000 then
		return nil
	end

	local dp = {}
	for baseIndex = 0, baseCount do
		dp[baseIndex] = {}
		dp[baseIndex][otherCount + 1] = 0
	end

	for otherIndex = 0, otherCount do
		dp[baseCount + 1] = dp[baseCount + 1] or {}
		dp[baseCount + 1][otherIndex] = 0
	end

	for baseIndex = baseCount, 1, -1 do
		for otherIndex = otherCount, 1, -1 do
			if baseLines[baseIndex] == otherLines[otherIndex] then
				dp[baseIndex][otherIndex] = (dp[baseIndex + 1][otherIndex + 1] or 0) + 1
			else
				local nextBase = dp[baseIndex + 1][otherIndex] or 0
				local nextOther = dp[baseIndex][otherIndex + 1] or 0
				dp[baseIndex][otherIndex] = math.max(nextBase, nextOther)
			end
		end
	end

	local matches = {}
	local baseIndex = 1
	local otherIndex = 1

	while baseIndex <= baseCount and otherIndex <= otherCount do
		if baseLines[baseIndex] == otherLines[otherIndex] then
			table.insert(matches, {
				Base = baseIndex,
				Other = otherIndex
			})
			baseIndex = baseIndex + 1
			otherIndex = otherIndex + 1
		else
			local nextBase = dp[baseIndex + 1] and dp[baseIndex + 1][otherIndex] or 0
			local nextOther = dp[baseIndex] and dp[baseIndex][otherIndex + 1] or 0

			if nextBase >= nextOther then
				baseIndex = baseIndex + 1
			else
				otherIndex = otherIndex + 1
			end
		end
	end

	return matches
end

local function ExtractInsertedBlocks(baseContent, localContent)
	local baseLines = SplitLines(baseContent)
	local localLines = SplitLines(localContent)
	local matches = BuildLCSMatches(baseLines, localLines)

	if not matches then
		return nil
	end

	local insertions = {}
	local previousBase = 0
	local previousLocal = 0

	for _, match in ipairs(matches) do
		local baseGap = match.Base - previousBase - 1
		local localGap = match.Other - previousLocal - 1

		if localGap > 0 and baseGap == 0 then
			insertions[previousBase] = insertions[previousBase] or {}
			for localIndex = previousLocal + 1, match.Other - 1 do
				table.insert(insertions[previousBase], localLines[localIndex])
			end
		end

		previousBase = match.Base
		previousLocal = match.Other
	end

	local remainingBaseGap = #baseLines - previousBase
	local remainingLocalGap = #localLines - previousLocal
	if remainingLocalGap > 0 and remainingBaseGap == 0 then
		insertions[previousBase] = insertions[previousBase] or {}
		for localIndex = previousLocal + 1, #localLines do
			table.insert(insertions[previousBase], localLines[localIndex])
		end
	end

	return insertions
end

local function MergeLocalAdditions(baseContent, localContent, remoteContent)
	if not IsTextContent(baseContent) or not IsTextContent(localContent) or not IsTextContent(remoteContent) then
		return nil
	end

	local insertions = ExtractInsertedBlocks(baseContent, localContent)
	if not insertions then
		return nil
	end

	local baseLines = SplitLines(baseContent)
	local remoteLines, remoteNewline, remoteTrailingNewline = SplitLines(remoteContent)
	local remoteMatches = BuildLCSMatches(baseLines, remoteLines)
	if not remoteMatches then
		return nil
	end

	local remoteByBase = {}
	local baseByRemote = {}
	for _, match in ipairs(remoteMatches) do
		remoteByBase[match.Base] = match.Other
		baseByRemote[match.Other] = match.Base
	end

	local mergedLines = {}

	local function appendInsertionsFor(baseIndex)
		local pending = insertions[baseIndex]
		if pending then
			for _, line in ipairs(pending) do
				table.insert(mergedLines, line)
			end
		end
	end

	appendInsertionsFor(0)

	for remoteIndex, line in ipairs(remoteLines) do
		local matchedBaseIndex = baseByRemote[remoteIndex]

		table.insert(mergedLines, line)

		if matchedBaseIndex then
			appendInsertionsFor(matchedBaseIndex)
		end
	end

	if not remoteByBase[#baseLines] then
		appendInsertionsFor(#baseLines)
	end

	return JoinLines(mergedLines, remoteNewline, remoteTrailingNewline)
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
		local preservedLocalFile = false
		local mergedLocalFile = false

		if fileExists then
			local oldContent = readfile(savePath)
			local localHash = ComputeHash(oldContent)
			local syncedHash = SyncState.FileHashes[path]
			local baseContent = ReadBaseContent(path)

			if localHash == remoteHash then
				shouldWrite = false
				SyncState.FileHashes[path] = remoteHash
				WriteBaseContent(path, response.Body)
			elseif not forceUpdate and baseContent and oldContent ~= baseContent then
				local mergedContent = MergeLocalAdditions(baseContent, oldContent, response.Body)
				if mergedContent and mergedContent ~= oldContent then
					writefile(savePath, mergedContent)
					WriteBaseContent(path, response.Body)
					SyncState.FileHashes[path] = remoteHash
					shouldWrite = false
					mergedLocalFile = true
					if report then
						table.insert(report.MergedFiles, savePath)
					end
				else
					shouldWrite = false
					preservedLocalFile = true
					if report then
						table.insert(report.PreservedFiles, savePath)
					end
				end
			elseif not forceUpdate then
				if syncedHash and localHash ~= syncedHash then
					shouldWrite = false
					preservedLocalFile = true
					if report then
						table.insert(report.PreservedFiles, savePath)
					end
				elseif not syncedHash then
					shouldWrite = false
					preservedLocalFile = true
					if report then
						table.insert(report.PreservedFiles, savePath)
					end
				end
			end
		end

		if shouldWrite then
			writefile(savePath, response.Body)
			WriteBaseContent(path, response.Body)
			SyncState.FileHashes[path] = remoteHash
			if report then
				if fileExists then
					table.insert(report.UpdatedFiles, savePath)
				else
					table.insert(report.CreatedFiles, savePath)
				end
			end
		elseif fileExists and isfile(savePath) and not preservedLocalFile and not mergedLocalFile then
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
