local Environment = type(getgenv) == "function" and getgenv() or _G
local Taskium = Environment.Taskium or {}
Environment.Taskium = Taskium

Taskium.RepositoryOwner = Taskium.RepositoryOwner or "OliusSchool"
Taskium.RepositoryName = Taskium.RepositoryName or "Taskium"
Taskium.RepositoryBranch = Taskium.RepositoryBranch or "main"

local MainUrl = ("https://raw.githubusercontent.com/%s/%s/%s/Client/Main.lua"):format(
	Taskium.RepositoryOwner,
	Taskium.RepositoryName,
	Taskium.RepositoryBranch
)

local Source = game:HttpGet(MainUrl, true)
local Chunk, LoadError = loadstring(Source, "@Taskium/Client/Main.lua")

if not Chunk then
	error(LoadError, 0)
end

return Chunk()
