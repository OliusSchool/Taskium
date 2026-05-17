local LoaderUrl = "https://raw.githubusercontent.com/OliusSchool/Taskium/main/Client/Loader.lua"

local function HttpGet(Url)
	local Succeeded, Body = pcall(function()
		return game:HttpGet(Url, true)
	end)

	if not Succeeded then
		error("Taskium root loader failed to download Client/Loader.lua: " .. tostring(Body))
	end

	return Body
end

local LoaderSource = HttpGet(LoaderUrl)
local LoaderFunction, LoaderError = loadstring(LoaderSource, "@Client/Loader.lua")

if not LoaderFunction then
	error("Taskium root loader failed to load Client/Loader.lua: " .. tostring(LoaderError))
end

return LoaderFunction()
