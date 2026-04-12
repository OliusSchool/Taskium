local BASE_URL = "https://raw.githubusercontent.com/OliusSchool/Taskium/main/"

local function loadRemote(path)
	local source = game:HttpGet(BASE_URL .. path, true)
	local chunk, err = loadstring(source)

	if not chunk then
		error(("Failed to compile %s: %s"):format(path, tostring(err)))
	end

	return chunk()
end

local TaskAPI = loadRemote("GUI/TaskUI.lua")
loadRemote("GUI/Categories.lua")

return TaskAPI
