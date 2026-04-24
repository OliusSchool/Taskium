local HttpService = game:GetService("HttpService")

local RawRepositoryUrl = "https://raw.githubusercontent.com/OliusSchool/Taskium/main/"
local RepositoryContentsApiUrl = "https://api.github.com/repos/OliusSchool/Taskium/contents/"

local WorkspaceRootFolder = "Taskium"
local WorkspaceBaseFolder = WorkspaceRootFolder .. "/Client/Base"
local SyncStateFilePath = WorkspaceRootFolder .. "/Client/SyncState.json"

local Taskium = getgenv().Taskium or {}
getgenv().Taskium = Taskium

local BootstrapFilePaths = {
	"Client/Config.lua",
	"GUI/TaskUI.lua",
	"GUI/Categories.lua",
	"Games/Universal.lua"
}

local RequiredFolderPaths = {
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

local function SendHttpRequest(RequestUrl)
	local HttpResponse

	if syn and syn.request then
		HttpResponse = syn.request({
			Url = RequestUrl,
			Method = "GET"
		})
	elseif request then
		HttpResponse = request({
			Url = RequestUrl,
			Method = "GET"
		})
	elseif http_request then
		HttpResponse = http_request({
			Url = RequestUrl,
			Method = "GET"
		})
	else
		error("Taskium loader requires syn.request, request, or http_request")
	end

	return HttpResponse
end

local function GetParentFolderPath(FilePath)
	return FilePath:match("^(.*)/[^/]+$")
end

local function CreateEmptySyncReport()
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

local function EnsureFolderExists(FolderPath, SyncReport)
	if not isfolder(FolderPath) then
		makefolder(FolderPath)
		if SyncReport then
			table.insert(SyncReport.CreatedFolders, FolderPath)
		end
	end
end

local function ComputeContentHash(FileContent)
	local RunningHash = 2166136261

	for ByteIndex = 1, #FileContent do
		RunningHash = bit32.bxor(RunningHash, string.byte(FileContent, ByteIndex))
		RunningHash = (RunningHash * 16777619) % 4294967296
	end

	return string.format("%08x", RunningHash)
end

local function LoadSyncState()
	EnsureFolderExists(WorkspaceRootFolder)
	EnsureFolderExists(WorkspaceRootFolder .. "/Client")

	if isfile(SyncStateFilePath) then
		local LoadedSuccessfully, DecodedSyncState = pcall(function()
			return HttpService:JSONDecode(readfile(SyncStateFilePath))
		end)

		if LoadedSuccessfully and type(DecodedSyncState) == "table" then
			SyncState = DecodedSyncState
		end
	end

	SyncState.FileHashes = SyncState.FileHashes or {}
end

local function SaveSyncState()
	EnsureFolderExists(WorkspaceRootFolder)
	EnsureFolderExists(WorkspaceRootFolder .. "/Client")
	writefile(SyncStateFilePath, HttpService:JSONEncode(SyncState))
end

local function GetBaseSnapshotFilePath(RelativeFilePath)
	return WorkspaceBaseFolder .. "/" .. RelativeFilePath
end

local function ReadBaseSnapshotContent(RelativeFilePath)
	local BaseSnapshotFilePath = GetBaseSnapshotFilePath(RelativeFilePath)
	if isfile(BaseSnapshotFilePath) then
		return readfile(BaseSnapshotFilePath)
	end

	return nil
end

local function WriteBaseSnapshotContent(RelativeFilePath, FileContent)
	local BaseSnapshotFilePath = GetBaseSnapshotFilePath(RelativeFilePath)
	local ParentFolderPath = GetParentFolderPath(BaseSnapshotFilePath)
	if ParentFolderPath then
		EnsureFolderExists(ParentFolderPath)
	end

	writefile(BaseSnapshotFilePath, FileContent)
end

local function IsTextFileContent(FileContent)
	return not string.find(FileContent, "\0", 1, true)
end

local function SplitContentIntoLines(FileContent)
	local NewLineSequence = string.find(FileContent, "\r\n", 1, true) and "\r\n" or "\n"
	local NormalizedContent = string.gsub(FileContent, "\r\n", "\n")
	local HasTrailingNewLine = NormalizedContent:sub(-1) == "\n"

	if HasTrailingNewLine then
		NormalizedContent = NormalizedContent:sub(1, -2)
	end

	local LineList = {}
	if NormalizedContent ~= "" then
		for LineText in string.gmatch(NormalizedContent .. "\n", "(.-)\n") do
			table.insert(LineList, LineText)
		end
	end

	return LineList, NewLineSequence, HasTrailingNewLine
end

local function JoinLinesIntoContent(LineList, NewLineSequence, HasTrailingNewLine)
	local JoinedContent = table.concat(LineList, NewLineSequence)
	if HasTrailingNewLine then
		JoinedContent = JoinedContent .. NewLineSequence
	end

	return JoinedContent
end

local function BuildLCSMatches(BaseLineList, OtherLineList)
	local BaseLineCount = #BaseLineList
	local OtherLineCount = #OtherLineList
	local DynamicProgrammingCellCount = (BaseLineCount + 1) * (OtherLineCount + 1)

	if DynamicProgrammingCellCount > 250000 then
		return nil
	end

	local DynamicProgrammingTable = {}
	for BaseLineIndex = 0, BaseLineCount do
		DynamicProgrammingTable[BaseLineIndex] = {}
		DynamicProgrammingTable[BaseLineIndex][OtherLineCount + 1] = 0
	end

	for OtherLineIndex = 0, OtherLineCount do
		DynamicProgrammingTable[BaseLineCount + 1] = DynamicProgrammingTable[BaseLineCount + 1] or {}
		DynamicProgrammingTable[BaseLineCount + 1][OtherLineIndex] = 0
	end

	for BaseLineIndex = BaseLineCount, 1, -1 do
		for OtherLineIndex = OtherLineCount, 1, -1 do
			if BaseLineList[BaseLineIndex] == OtherLineList[OtherLineIndex] then
				DynamicProgrammingTable[BaseLineIndex][OtherLineIndex] = (DynamicProgrammingTable[BaseLineIndex + 1][OtherLineIndex + 1] or 0) + 1
			else
				local NextBaseScore = DynamicProgrammingTable[BaseLineIndex + 1][OtherLineIndex] or 0
				local NextOtherScore = DynamicProgrammingTable[BaseLineIndex][OtherLineIndex + 1] or 0
				DynamicProgrammingTable[BaseLineIndex][OtherLineIndex] = math.max(NextBaseScore, NextOtherScore)
			end
		end
	end

	local MatchList = {}
	local BaseLineIndex = 1
	local OtherLineIndex = 1

	while BaseLineIndex <= BaseLineCount and OtherLineIndex <= OtherLineCount do
		if BaseLineList[BaseLineIndex] == OtherLineList[OtherLineIndex] then
			table.insert(MatchList, {
				Base = BaseLineIndex,
				Other = OtherLineIndex
			})
			BaseLineIndex = BaseLineIndex + 1
			OtherLineIndex = OtherLineIndex + 1
		else
			local NextBaseScore = DynamicProgrammingTable[BaseLineIndex + 1] and DynamicProgrammingTable[BaseLineIndex + 1][OtherLineIndex] or 0
			local NextOtherScore = DynamicProgrammingTable[BaseLineIndex] and DynamicProgrammingTable[BaseLineIndex][OtherLineIndex + 1] or 0

			if NextBaseScore >= NextOtherScore then
				BaseLineIndex = BaseLineIndex + 1
			else
				OtherLineIndex = OtherLineIndex + 1
			end
		end
	end

	return MatchList
end

local function ExtractInsertedBlocks(BaseFileContent, LocalFileContent)
	local BaseLineList = SplitContentIntoLines(BaseFileContent)
	local LocalLineList = SplitContentIntoLines(LocalFileContent)
	local MatchList = BuildLCSMatches(BaseLineList, LocalLineList)

	if not MatchList then
		return nil
	end

	local InsertedBlocksByBaseIndex = {}
	local PreviousBaseLineIndex = 0
	local PreviousLocalLineIndex = 0

	for _, MatchData in ipairs(MatchList) do
		local BaseGapSize = MatchData.Base - PreviousBaseLineIndex - 1
		local LocalGapSize = MatchData.Other - PreviousLocalLineIndex - 1

		if LocalGapSize > 0 and BaseGapSize == 0 then
			InsertedBlocksByBaseIndex[PreviousBaseLineIndex] = InsertedBlocksByBaseIndex[PreviousBaseLineIndex] or {}
			for LocalLineIndex = PreviousLocalLineIndex + 1, MatchData.Other - 1 do
				table.insert(InsertedBlocksByBaseIndex[PreviousBaseLineIndex], LocalLineList[LocalLineIndex])
			end
		end

		PreviousBaseLineIndex = MatchData.Base
		PreviousLocalLineIndex = MatchData.Other
	end

	local RemainingBaseGapSize = #BaseLineList - PreviousBaseLineIndex
	local RemainingLocalGapSize = #LocalLineList - PreviousLocalLineIndex
	if RemainingLocalGapSize > 0 and RemainingBaseGapSize == 0 then
		InsertedBlocksByBaseIndex[PreviousBaseLineIndex] = InsertedBlocksByBaseIndex[PreviousBaseLineIndex] or {}
		for LocalLineIndex = PreviousLocalLineIndex + 1, #LocalLineList do
			table.insert(InsertedBlocksByBaseIndex[PreviousBaseLineIndex], LocalLineList[LocalLineIndex])
		end
	end

	return InsertedBlocksByBaseIndex
end

local function MergeLocalAdditions(BaseFileContent, LocalFileContent, RemoteFileContent)
	if not IsTextFileContent(BaseFileContent) or not IsTextFileContent(LocalFileContent) or not IsTextFileContent(RemoteFileContent) then
		return nil
	end

	local InsertedBlocksByBaseIndex = ExtractInsertedBlocks(BaseFileContent, LocalFileContent)
	if not InsertedBlocksByBaseIndex then
		return nil
	end

	local BaseLineList = SplitContentIntoLines(BaseFileContent)
	local RemoteLineList, RemoteNewLineSequence, RemoteHasTrailingNewLine = SplitContentIntoLines(RemoteFileContent)
	local RemoteMatchList = BuildLCSMatches(BaseLineList, RemoteLineList)
	if not RemoteMatchList then
		return nil
	end

	local RemoteIndexByBaseIndex = {}
	local BaseIndexByRemoteIndex = {}
	for _, MatchData in ipairs(RemoteMatchList) do
		RemoteIndexByBaseIndex[MatchData.Base] = MatchData.Other
		BaseIndexByRemoteIndex[MatchData.Other] = MatchData.Base
	end

	local MergedLineList = {}

	local function AppendInsertedLinesForBaseIndex(BaseLineIndex)
		local PendingInsertedLines = InsertedBlocksByBaseIndex[BaseLineIndex]
		if PendingInsertedLines then
			for _, PendingLine in ipairs(PendingInsertedLines) do
				table.insert(MergedLineList, PendingLine)
			end
		end
	end

	AppendInsertedLinesForBaseIndex(0)

	for RemoteLineIndex, RemoteLineText in ipairs(RemoteLineList) do
		local MatchedBaseLineIndex = BaseIndexByRemoteIndex[RemoteLineIndex]

		table.insert(MergedLineList, RemoteLineText)

		if MatchedBaseLineIndex then
			AppendInsertedLinesForBaseIndex(MatchedBaseLineIndex)
		end
	end

	if not RemoteIndexByBaseIndex[#BaseLineList] then
		AppendInsertedLinesForBaseIndex(#BaseLineList)
	end

	return JoinLinesIntoContent(MergedLineList, RemoteNewLineSequence, RemoteHasTrailingNewLine)
end

local function DownloadRepositoryFile(RelativeFilePath, ShouldForceUpdate, SyncReport)
	local RemoteFileUrl = RawRepositoryUrl .. RelativeFilePath
	local LocalWorkspaceFilePath = WorkspaceRootFolder .. "/" .. RelativeFilePath
	local LocalFileAlreadyExists = isfile(LocalWorkspaceFilePath)
	local ParentFolderPath = GetParentFolderPath(LocalWorkspaceFilePath)

	if ParentFolderPath then
		EnsureFolderExists(ParentFolderPath, SyncReport)
	end

	local HttpResponse = SendHttpRequest(RemoteFileUrl)

	if HttpResponse.StatusCode == 200 then
		local RemoteFileContent = HttpResponse.Body
		local RemoteFileHash = ComputeContentHash(RemoteFileContent)
		local ShouldWriteRemoteFile = true
		local PreservedLocalFile = false
		local MergedLocalFile = false

		if LocalFileAlreadyExists then
			local LocalFileContent = readfile(LocalWorkspaceFilePath)
			local LocalFileHash = ComputeContentHash(LocalFileContent)
			local LastSyncedRemoteHash = SyncState.FileHashes[RelativeFilePath]
			local BaseSnapshotContent = ReadBaseSnapshotContent(RelativeFilePath)

			if LocalFileHash == RemoteFileHash then
				ShouldWriteRemoteFile = false
				SyncState.FileHashes[RelativeFilePath] = RemoteFileHash
				WriteBaseSnapshotContent(RelativeFilePath, RemoteFileContent)
			elseif not ShouldForceUpdate and BaseSnapshotContent and LocalFileContent ~= BaseSnapshotContent then
				local MergedFileContent = MergeLocalAdditions(BaseSnapshotContent, LocalFileContent, RemoteFileContent)
				if MergedFileContent and MergedFileContent ~= LocalFileContent then
					writefile(LocalWorkspaceFilePath, MergedFileContent)
					WriteBaseSnapshotContent(RelativeFilePath, RemoteFileContent)
					SyncState.FileHashes[RelativeFilePath] = RemoteFileHash
					ShouldWriteRemoteFile = false
					MergedLocalFile = true
					if SyncReport then
						table.insert(SyncReport.MergedFiles, LocalWorkspaceFilePath)
					end
				else
					ShouldWriteRemoteFile = false
					PreservedLocalFile = true
					if SyncReport then
						table.insert(SyncReport.PreservedFiles, LocalWorkspaceFilePath)
					end
				end
			elseif not ShouldForceUpdate then
				if LastSyncedRemoteHash and LocalFileHash ~= LastSyncedRemoteHash then
					ShouldWriteRemoteFile = false
					PreservedLocalFile = true
					if SyncReport then
						table.insert(SyncReport.PreservedFiles, LocalWorkspaceFilePath)
					end
				elseif not LastSyncedRemoteHash then
					ShouldWriteRemoteFile = false
					PreservedLocalFile = true
					if SyncReport then
						table.insert(SyncReport.PreservedFiles, LocalWorkspaceFilePath)
					end
				end
			end
		end

		if ShouldWriteRemoteFile then
			writefile(LocalWorkspaceFilePath, RemoteFileContent)
			WriteBaseSnapshotContent(RelativeFilePath, RemoteFileContent)
			SyncState.FileHashes[RelativeFilePath] = RemoteFileHash
			if SyncReport then
				if LocalFileAlreadyExists then
					table.insert(SyncReport.UpdatedFiles, LocalWorkspaceFilePath)
				else
					table.insert(SyncReport.CreatedFiles, LocalWorkspaceFilePath)
				end
			end
		elseif LocalFileAlreadyExists and isfile(LocalWorkspaceFilePath) and not PreservedLocalFile and not MergedLocalFile then
			SyncState.FileHashes[RelativeFilePath] = ComputeContentHash(readfile(LocalWorkspaceFilePath))
		end

		return true
	end

	warn("Failed to download: " .. RemoteFileUrl)
	if SyncReport then
		table.insert(SyncReport.FailedFiles, LocalWorkspaceFilePath)
	end
	return false
end

local function CollectRepositoryFilesRecursively(RepositoryFolderPath, CollectedFilePaths)
	CollectedFilePaths = CollectedFilePaths or {}

	local ContentsApiUrl = RepositoryContentsApiUrl .. RepositoryFolderPath
	local HttpResponse = SendHttpRequest(ContentsApiUrl)

	if HttpResponse.StatusCode ~= 200 then
		warn("Failed to get directory listing for: " .. RepositoryFolderPath)
		return CollectedFilePaths
	end

	local DecodedItems = HttpService:JSONDecode(HttpResponse.Body)

	for _, RepositoryItem in ipairs(DecodedItems) do
		if RepositoryItem.type == "File" then
			table.insert(CollectedFilePaths, RepositoryItem.Path or (RepositoryFolderPath .. "/" .. RepositoryItem.name))
		elseif RepositoryItem.type == "dir" then
			CollectRepositoryFilesRecursively(RepositoryItem.Path or (RepositoryFolderPath .. "/" .. RepositoryItem.name), CollectedFilePaths)
		end
	end

	return CollectedFilePaths
end

local function SyncTaskiumFiles(ShouldForceUpdate)
	local SyncReport = CreateEmptySyncReport()
	local QueuedFileLookup = {}

	for _, RequiredFolderPath in ipairs(RequiredFolderPaths) do
		EnsureFolderExists(RequiredFolderPath, SyncReport)
	end

	local RepositoryFilePaths = CollectRepositoryFilesRecursively("")
	if #RepositoryFilePaths == 0 then
		warn("No Files found in repository.")
	end

	for _, RelativeFilePath in ipairs(RepositoryFilePaths) do
		QueuedFileLookup[RelativeFilePath] = true
	end

	for RelativeFilePath in pairs(QueuedFileLookup) do
		DownloadRepositoryFile(RelativeFilePath, ShouldForceUpdate, SyncReport)
	end

	SaveSyncState()

	Taskium.LastSyncReport = SyncReport
	return SyncReport
end

local function EnsureBootstrapFilesExist(SyncReport)
	for _, BootstrapRelativePath in ipairs(BootstrapFilePaths) do
		local BootstrapWorkspacePath = WorkspaceRootFolder .. "/" .. BootstrapRelativePath
		if not isfile(BootstrapWorkspacePath) then
			local DownloadedSuccessfully = DownloadRepositoryFile(BootstrapRelativePath, true, SyncReport)
			if not DownloadedSuccessfully then
				warn("Failed to bootstrap File: " .. BootstrapRelativePath)
			end
		end
	end

	SaveSyncState()
end

local function ExecuteWorkspaceFile(WorkspaceFilePath)
	local ReadSucceeded, FileContent = pcall(readfile, WorkspaceFilePath)
	if not ReadSucceeded then
		warn("Failed to read File: " .. WorkspaceFilePath)
		return nil
	end

	local LoadedFunction, LoadError = loadstring(FileContent, "@" .. WorkspaceFilePath)
	if not LoadedFunction then
		warn("Failed to load " .. WorkspaceFilePath .. ": " .. tostring(LoadError))
		return nil
	end

	return LoadedFunction()
end

local function GetQueueOnTeleportFunction()
	if syn and type(syn.queue_on_teleport) == "function" then
		return syn.queue_on_teleport
	end

	if type(queue_on_teleport) == "function" then
		return queue_on_teleport
	end

	if type(queueonteleport) == "function" then
		return queueonteleport
	end

	if fluxus and type(fluxus.queue_on_teleport) == "function" then
		return fluxus.queue_on_teleport
	end

	return nil
end

local function BuildTeleportBootstrapSource()
	return [[
local WorkspaceLoaderPath = "Taskium/Client/Loader.lua"
local LoaderSource

if isfile and isfile(WorkspaceLoaderPath) then
	local ReadSucceeded, FileContent = pcall(readfile, WorkspaceLoaderPath)
	if ReadSucceeded and type(FileContent) == "string" and FileContent ~= "" then
		LoaderSource = FileContent
	end
end

if not LoaderSource then
	LoaderSource = game:HttpGet("https://raw.githubusercontent.com/OliusSchool/Taskium/main/Client/Loader.lua", true)
end

local LoaderFunction, LoaderError = loadstring(LoaderSource, "@Client/Loader.lua")
if not LoaderFunction then
	error("Taskium teleport bootstrap failed to load Client/Loader.lua: " .. tostring(LoaderError))
end

return LoaderFunction()
]]
end

local function QueueTaskiumOnTeleport()
	local QueueFunction = GetQueueOnTeleportFunction()
	if not QueueFunction then
		return false
	end

	local QueueSucceeded = pcall(QueueFunction, BuildTeleportBootstrapSource())
	return QueueSucceeded
end

local function BootTaskium()
	EnsureBootstrapFilesExist(Taskium.LastSyncReport or CreateEmptySyncReport())
	QueueTaskiumOnTeleport()

	if Taskium.API and type(Taskium.API.Shutdown) == "function" then
		pcall(function()
			Taskium.API:Shutdown()
		end)
	end

	local TaskiumConfig = ExecuteWorkspaceFile("Taskium/Client/Config.lua")
	Taskium.Config = TaskiumConfig

	local TaskAPI = ExecuteWorkspaceFile("Taskium/GUI/TaskUI.lua")
	if not TaskAPI then
		warn("Taskium bootstrap could not find Taskium/GUI/TaskUI.lua")
		return nil
	end

	getgenv().TaskAPI = TaskAPI
	Taskium.API = TaskAPI
	TaskAPI.Config = TaskiumConfig

	ExecuteWorkspaceFile("Taskium/GUI/Categories.lua")
	ExecuteWorkspaceFile("Taskium/Games/Universal.lua")

	return TaskAPI
end

local function RestartTaskium()
	return BootTaskium()
end

Taskium.SyncTaskiumFiles = SyncTaskiumFiles
Taskium.ExecuteFile = ExecuteWorkspaceFile
Taskium.RestartTaskium = RestartTaskium
Taskium.QueueOnTeleport = QueueTaskiumOnTeleport
Taskium.LastSyncReport = nil

LoadSyncState()

local InitialSyncReport = SyncTaskiumFiles(false)
EnsureBootstrapFilesExist(InitialSyncReport)
Taskium.LastSyncReport = InitialSyncReport

local TaskAPI = BootTaskium()

if TaskAPI then
	local CreatedFolderCount = #InitialSyncReport.CreatedFolders
	local CreatedFileCount = #InitialSyncReport.CreatedFiles
	local UpdatedFileCount = #InitialSyncReport.UpdatedFiles

	if CreatedFolderCount > 0 then
		TaskAPI.Notification("Taskium", ("Created %d Folder(s)."):format(CreatedFolderCount), 3, "Info")
	end

	if CreatedFileCount > 0 or UpdatedFileCount > 0 then
		TaskAPI.Notification("Taskium", ("Files synced: %d new, %d updated."):format(CreatedFileCount, UpdatedFileCount), 3, "Success")
	end

	if Taskium and Taskium.API then
		TaskAPI.Notification("Taskium", "Taskium initialized successfully!", 3, "Success")
	else
		TaskAPI.Notification("Taskium", "Taskium failed to initialize properly", 5, "Error")
	end
end

return TaskAPI
