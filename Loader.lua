local LoaderUrl = "https://raw.githubusercontent.com/OliusSchool/Taskium/main/Client/Loader.lua"
local LoaderPath = "Taskium/Client/Loader.lua"

local function GetLoaderSource()
	if isfile and isfile(LoaderPath) then
		return readfile(LoaderPath)
	end

	local Succeeded, Body = pcall(function()
		return game:HttpGet(LoaderUrl, true)
	end)

	if not Succeeded then
		error("Taskium root loader failed to download Client/Loader.lua: " .. tostring(Body))
	end

	return Body
end

local LoaderSource = GetLoaderSource()
local LoaderFunction, LoaderError = loadstring(LoaderSource, "@Client/Loader.lua")

if not LoaderFunction then
	error("Taskium root loader failed to load Client/Loader.lua: " .. tostring(LoaderError))
end

return LoaderFunction()
