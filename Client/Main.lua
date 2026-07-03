local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

while not Players.LocalPlayer do
	task.wait()
end

local TableUnpack = table.unpack or unpack
local Environment = type(getgenv) == "function" and getgenv() or _G

local Taskium = Environment.Taskium or {}
Environment.Taskium = Taskium

if type(shared) == "table" then
	shared.Taskium = Taskium
end

Taskium.RepositoryOwner = Taskium.RepositoryOwner or "OliusSchool"
Taskium.RepositoryName = Taskium.RepositoryName or "Taskium"
Taskium.RepositoryBranch = Taskium.RepositoryBranch or "main"
Taskium.RootFolder = Taskium.RootFolder or "Taskium"
Taskium.GuiFile = Taskium.GuiFile or "GUI/BetaUI.lua"
Taskium.AllowedFolders = {
	GUI = true,
	Client = true,
	Libraries = true,
	Games = true
}

Taskium.ModuleCache = {}
Taskium.LoadedAt = os.time()

local RootFolder = Taskium.RootFolder
local RawBase = ("https://raw.githubusercontent.com/%s/%s/%s/"):format(
	Taskium.RepositoryOwner,
	Taskium.RepositoryName,
	Taskium.RepositoryBranch
)
local TreeUrl = ("https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1"):format(
	Taskium.RepositoryOwner,
	Taskium.RepositoryName,
	Taskium.RepositoryBranch
)
local LoaderUrl = RawBase .. "Loader.lua"
local LoaderScript = ('loadstring(game:HttpGet("%s", true))()'):format(LoaderUrl)

local function StartsWith(Value, Prefix)
	return Value:sub(1, #Prefix) == Prefix
end

local function Pack(...)
	return {
		n = select("#", ...),
		...
	}
end

local function NormalizePath(Path)
	Path = tostring(Path or ""):gsub("\\", "/"):gsub("^/+", "")

	local RootPrefix = RootFolder .. "/"
	if Path == RootFolder then
		return ""
	end
	if StartsWith(Path, RootPrefix) then
		Path = Path:sub(#RootPrefix + 1)
	end

	return Path
end

local function EncodePath(Path)
	local Parts = {}
	for Segment in NormalizePath(Path):gmatch("[^/]+") do
		table.insert(Parts, HttpService:UrlEncode(Segment))
	end
	return table.concat(Parts, "/")
end

local function EnsureFolder(Path)
	Path = NormalizePath(Path)
	local Current = ""

	for Segment in Path:gmatch("[^/]+") do
		Current = Current == "" and Segment or (Current .. "/" .. Segment)
		local FolderPath = RootFolder .. "/" .. Current
		if not isfolder(FolderPath) then
			makefolder(FolderPath)
		end
	end
end

local function EnsureParentFolder(Path)
	local Folder = NormalizePath(Path):match("^(.*)/[^/]+$")
	if Folder and Folder ~= "" then
		EnsureFolder(Folder)
	end
end

local function AssertFileSystem()
	local Missing = {}
	local Required = { "isfile", "isfolder", "makefolder", "readfile", "writefile" }

	for _, Name in ipairs(Required) do
		if type(Environment[Name]) ~= "function" then
			table.insert(Missing, Name)
		end
	end

	if #Missing > 0 then
		error("Taskium needs filesystem support: " .. table.concat(Missing, ", "), 0)
	end

	if not isfolder(RootFolder) then
		makefolder(RootFolder)
	end
end

local function GetRequestFunction()
	return Environment.request
		or Environment.http_request
		or Environment.httpRequest
		or (Environment.syn and Environment.syn.request)
		or (Environment.http and Environment.http.request)
		or (Environment.fluxus and Environment.fluxus.request)
end

local function HttpGet(Url)
	local Request = GetRequestFunction()
	if type(Request) == "function" then
		local Success, Response = pcall(Request, {
			Url = Url,
			Method = "GET",
			Headers = {
				["User-Agent"] = "Taskium"
			}
		})

		if Success and type(Response) == "table" then
			local StatusCode = Response.StatusCode or Response.Status or Response.status_code
			local Body = Response.Body or Response.body
			if type(StatusCode) == "number" and (StatusCode < 200 or StatusCode >= 300) then
				error(("HTTP %s while fetching %s"):format(tostring(StatusCode), Url), 0)
			end
			if type(Body) == "string" then
				return Body
			end
		end
	end

	local Success, Body = pcall(function()
		return game:HttpGet(Url, true)
	end)

	if not Success then
		error(("HTTP request failed for %s: %s"):format(Url, tostring(Body)), 0)
	end

	return Body
end

local function DecodeJson(Source, Url)
	local Success, Decoded = pcall(function()
		return HttpService:JSONDecode(Source)
	end)

	if not Success then
		error(("Taskium could not decode JSON from %s: %s"):format(tostring(Url), tostring(Decoded)), 0)
	end

	return Decoded
end

local function IsAllowedPath(Path)
	Path = NormalizePath(Path)
	local Folder = Path:match("^([^/]+)/")
	return Folder ~= nil and Taskium.AllowedFolders[Folder] == true
end

local function FetchTree()
	local Tree = DecodeJson(HttpGet(TreeUrl), TreeUrl)
	local Files = {}

	if type(Tree.tree) ~= "table" then
		error("Taskium GitHub tree API did not return a file tree: " .. tostring(Tree.message), 0)
	end

	for _, Item in ipairs(Tree.tree or {}) do
		if Item.type == "blob" and type(Item.path) == "string" and IsAllowedPath(Item.path) then
			table.insert(Files, NormalizePath(Item.path))
		end
	end

	table.sort(Files)

	if Tree.truncated then
		warn("Taskium GitHub tree response was truncated; some files may not be available.")
	end

	return Files
end

local function WriteSourceFile(RelativePath, Source)
	local LocalPath = RootFolder .. "/" .. RelativePath
	EnsureParentFolder(RelativePath)

	if isfile(LocalPath) then
		local Success, Existing = pcall(readfile, LocalPath)
		if Success and Existing == Source then
			return false
		end
	end

	writefile(LocalPath, Source)
	return true
end

local function DownloadFiles(Files)
	local Summary = {
		Downloaded = 0,
		Unchanged = 0,
		Cached = 0,
		Failed = {}
	}

	for Index, RelativePath in ipairs(Files) do
		local Url = RawBase .. EncodePath(RelativePath)
		local Success, Source = pcall(HttpGet, Url)

		if Success and type(Source) == "string" then
			if WriteSourceFile(RelativePath, Source) then
				Summary.Downloaded += 1
			else
				Summary.Unchanged += 1
			end
		else
			local LocalPath = RootFolder .. "/" .. RelativePath
			if isfile(LocalPath) then
				Summary.Cached += 1
				warn(("Taskium using cached file after download failed: %s (%s)"):format(RelativePath, tostring(Source)))
			else
				table.insert(Summary.Failed, RelativePath)
			end
		end

		if Index % 20 == 0 then
			task.wait()
		end
	end

	if #Summary.Failed > 0 then
		error("Taskium could not download required files: " .. table.concat(Summary.Failed, ", "), 0)
	end

	return Summary
end

function Taskium.LocalPath(Path)
	local RelativePath = NormalizePath(Path)
	return RootFolder .. "/" .. RelativePath, RelativePath
end

function Taskium.GetFiles(Prefix)
	Prefix = NormalizePath(Prefix)
	local Results = {}

	for _, Path in ipairs(Taskium.FileList or {}) do
		if StartsWith(Path, Prefix) then
			table.insert(Results, Path)
		end
	end

	table.sort(Results)
	return Results
end

function Taskium.ExecuteFile(Path, Options, ...)
	local NoCache = Options == true or (type(Options) == "table" and Options.NoCache == true)
	local LocalPath, RelativePath = Taskium.LocalPath(Path)

	if not NoCache and Taskium.ModuleCache[RelativePath] then
		local Cached = Taskium.ModuleCache[RelativePath]
		return TableUnpack(Cached, 1, Cached.n)
	end

	if not isfile(LocalPath) then
		error("Taskium missing file: " .. LocalPath, 2)
	end

	local Source = readfile(LocalPath)
	local Chunk, LoadError = loadstring(Source, "@" .. LocalPath)
	if not Chunk then
		error(LoadError, 2)
	end

	local Results = Pack(pcall(Chunk, ...))
	if not Results[1] then
		error(("Taskium file '%s' failed: %s"):format(RelativePath, tostring(Results[2])), 2)
	end

	local Packed = {
		n = math.max(Results.n - 1, 0)
	}

	for Index = 2, Results.n do
		Packed[Index - 1] = Results[Index]
	end

	if not NoCache then
		Taskium.ModuleCache[RelativePath] = Packed
	end

	return TableUnpack(Packed, 1, Packed.n)
end

function Taskium.LoadLibrary(Name)
	local LibraryPath = tostring(Name or "")
	if not LibraryPath:find("/", 1, true) then
		LibraryPath = "Libraries/" .. LibraryPath
	end
	if not LibraryPath:match("%.lua$") then
		LibraryPath ..= ".lua"
	end

	return Taskium.ExecuteFile(LibraryPath)
end

local function GetQueueFunction()
	return Environment.queue_on_teleport
		or Environment.queueonteleport
		or (Environment.syn and Environment.syn.queue_on_teleport)
		or (Environment.fluxus and Environment.fluxus.queue_on_teleport)
end

function Taskium.QueueOnTeleport()
	if Taskium.QueueTeleport == false or Environment.TaskiumQueueOnTeleport == false then
		return false
	end

	local QueueFunction = GetQueueFunction()
	if type(QueueFunction) ~= "function" then
		return false
	end

	local Success, QueueError = pcall(QueueFunction, Taskium.QueueScript or LoaderScript)
	if Success then
		Taskium.TeleportQueued = true
		return true
	end

	warn("Taskium queue_on_teleport failed: " .. tostring(QueueError))
	return false
end

local function Notify(Title, Message, Duration, NotificationType)
	local Api = Environment.TaskAPI or Taskium.API
	if Api and type(Api.Notification) == "function" then
		pcall(Api.Notification, Title, Message, Duration or 4, NotificationType or "Info")
	end
end

local function ExecuteRequired(Path)
	return Taskium.ExecuteFile(Path)
end

local ModuleFailures = {}

local function ExecuteOptional(Path)
	local Success, Result = pcall(Taskium.ExecuteFile, Path)
	if Success then
		return Result
	end

	warn(("Taskium failed to load %s: %s"):format(tostring(Path), tostring(Result)))
	table.insert(ModuleFailures, {
		Path = tostring(Path),
		Error = tostring(Result)
	})
	return nil
end

local function NormalizeGameEntry(Path)
	Path = NormalizePath(Path)
	if Path == "" then
		return nil
	end
	if not StartsWith(Path, "Games/") then
		Path = "Games/" .. Path
	end
	return Path
end

local function SelectGame(Registry)
	if type(Registry) ~= "table" then
		return nil
	end

	local PlaceIds = type(Registry.PlaceIds) == "table" and Registry.PlaceIds or {}
	local GameIds = type(Registry.GameIds) == "table" and Registry.GameIds or {}

	return PlaceIds[game.PlaceId]
		or PlaceIds[tostring(game.PlaceId)]
		or GameIds[game.GameId]
		or GameIds[tostring(game.GameId)]
		or Registry.Default
end

local function LoadCategoryFolder(Folder)
	local Count = 0
	local Remaining = 0

	for _, Path in ipairs(Taskium.GetFiles(Folder)) do
		if Path:match("%.lua$") then
			Count += 1
			Remaining += 1

			task.spawn(function()
				ExecuteOptional(Path)
				Remaining -= 1
			end)
		end
	end

	while Remaining > 0 do
		task.wait()
	end

	return Count
end

local function LoadGameEntry(MainPath)
	MainPath = NormalizeGameEntry(MainPath)
	if not MainPath then
		return nil
	end

	local Main = ExecuteRequired(MainPath)
	local GameFolder = MainPath:match("^Games/([^/]+)/")
	local CategoryCount = 0

	if GameFolder then
		CategoryCount = LoadCategoryFolder("Games/" .. GameFolder .. "/Categories/")
	end

	table.insert(Taskium.Game.Loaded, {
		Main = MainPath,
		Categories = CategoryCount
	})

	return Main
end

local function LoadRuntime()
	Taskium.QueueOnTeleport()

	ExecuteRequired("Client/Config.lua")
	ExecuteRequired(Taskium.GuiFile)
	ExecuteRequired("GUI/Categories.lua")

	local Registry = ExecuteRequired("Games/Games.lua")
	local DefaultEntry = NormalizeGameEntry(Registry and Registry.Default)
	local SelectedEntry = NormalizeGameEntry(SelectGame(Registry))

	Taskium.Game = {
		GameId = game.GameId,
		PlaceId = game.PlaceId,
		Default = DefaultEntry,
		Selected = SelectedEntry,
		Loaded = {}
	}

	if DefaultEntry then
		LoadGameEntry(DefaultEntry)
	end

	if SelectedEntry and SelectedEntry ~= DefaultEntry then
		LoadGameEntry(SelectedEntry)
	end

	Taskium.Failures = ModuleFailures

	if #ModuleFailures > 0 then
		Notify("Taskium", ("Loaded with %d module error(s). Check console."):format(#ModuleFailures), 5, "Warning")
	else
		Notify("Taskium", "Loaded successfully.", 4, "Success")
	end
end

AssertFileSystem()

Taskium.FileList = FetchTree()
Taskium.DownloadSummary = DownloadFiles(Taskium.FileList)

LoadRuntime()

return Taskium
