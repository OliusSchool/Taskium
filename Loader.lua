local HttpService = game:GetService("HttpService")

local RawGitUrl = "https://raw.githubusercontent.com/OliusSchool/Taskium/main/"
local RepoApiUrl = "https://api.github.com/repos/OliusSchool/Taskium/contents/"

local RootFolder = "Taskium"
local Folders = {
	"Taskium",
	"Taskium/GUI",
	"Taskium/Games",
	"Taskium/Scripts",
	"Taskium/Assets",
	"Taskium/Assets/GUI",
	"Taskium/Assets/Icons"
}

local DownloadFolders = {
	"GUI",
	"Games",
	"Scripts",
	"Assets/GUI",
	"Assets/Icons"
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

for _, folder in ipairs(Folders) do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

local function DownloadFile(path)
	local url = RawGitUrl .. path
	local savePath = RootFolder .. "/" .. path
	if isfile(savePath) then
		return true
	end

	local response = HttpRequest(url)

	if response.StatusCode == 200 then
		writefile(savePath, response.Body)
		return true
	end

	warn("Failed to download: " .. url)
	return false
end

local function GetDirectoryContents(folder)
	local apiUrl = RepoApiUrl .. folder
	local response = HttpRequest(apiUrl)

	if response.StatusCode ~= 200 then
		warn("Failed to get directory listing for: " .. folder)
		return {}
	end

	local files = {}
	local data = HttpService:JSONDecode(response.Body)

	for _, item in ipairs(data) do
		if item.type == "file" then
			table.insert(files, folder .. "/" .. item.name)
		end
	end

	return files
end

for _, folder in ipairs(DownloadFolders) do
	local files = GetDirectoryContents(folder)

	if #files > 0 then
		for _, file in ipairs(files) do
			DownloadFile(file)
		end
	else
		warn("No files found in directory: " .. folder)
	end
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

local TaskAPI = ExecuteFile("Taskium/GUI/TaskUI.lua")

if TaskAPI then
	getgenv().TaskAPI = TaskAPI

	ExecuteFile("Taskium/GUI/Categories.lua")
	ExecuteFile("Taskium/Games/Universal.lua")

	if getgenv().TaskClient and getgenv().TaskClient.API then
		TaskAPI.Notification("Taskium", "Taskium initialized successfully!", 3, "Success")
	else
		TaskAPI.Notification("Taskium", "Taskium failed to initialize properly", 5, "Error")
	end
end

return TaskAPI
