local mainFolder = "Taskium"
local loaderPath = mainFolder .. "/Client/Loader.lua"

-- Fallbacks to prevent "attempt to call a nil value"
local isfolder = isfolder or function(p) return false end
local makefolder = makefolder or function(p) end
local isfile = isfile or function(p) return false end
local readfile = readfile or function(p) return "" end
local writefile = writefile or function(p, c) end
local loadstring = loadstring or function(s, n) return function() end, nil end

-- Inlined ensureFolder
for _, folder in ipairs({ mainFolder, mainFolder .. "/Client", mainFolder .. "/Games", mainFolder .. "/GUI", mainFolder .. "/Libraries" }) do
    if not isfolder(folder) then makefolder(folder) end
end

-- Safely read the file to prevent "file not found" crashes
local okRead, source = pcall(readfile, loaderPath)
source = (okRead and source) or ""

-- Inlined downloadFile
if source == "" then
    local okHttp, res = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/OliusSchool/Taskium/main/Client/Loader.lua", true)
    end)
    
    if okHttp and res ~= "404: Not Found" and res ~= "" then
        pcall(writefile, loaderPath, res)
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