local mainFolder = "Taskium"
local loaderPath = mainFolder .. "/Client/Loader.lua"

-- Inlined ensureFolder
for _, folder in ipairs({ mainFolder, mainFolder .. "/Client", mainFolder .. "/Games", mainFolder .. "/GUI", mainFolder .. "/Libraries" }) do
    if not isfolder(folder) then makefolder(folder) end
end

local source = isfile(loaderPath) and readfile(loaderPath) or ""

-- Inlined downloadFile
if source == "" then
    local okHttp, res = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/OliusSchool/Taskium/main/Client/Loader.lua", true)
    end)
    
    if okHttp and res and res ~= "404: Not Found" and res ~= "" then
        writefile(loaderPath, res)
        source = res
    else
        error("Taskium failed to download Loader.lua: " .. tostring(res))
    end
end

local chunk, err = loadstring(source, "TaskiumLoader")
if not chunk then
    error("Taskium failed to compile Loader.lua: " .. tostring(err))
end

return chunk()