local LoaderUrl = "https://raw.githubusercontent.com/OliusSchool/Taskium/main/Client/Loader.lua"

local function HttpGet(url)
	return game:HttpGet(url, true)
end

local loaderSource = HttpGet(LoaderUrl)
local loaderFn, loaderError = loadstring(loaderSource, "@Client/Loader.lua")

if not loaderFn then
	error("Taskium root loader failed to load Client/Loader.lua: " .. tostring(loaderError))
end

return loaderFn()
