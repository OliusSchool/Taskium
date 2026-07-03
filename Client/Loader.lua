local HttpService = game:GetService("HttpService")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local mainFolder = "Taskium"
local commitFile = mainFolder .. "/Client/Commit.txt"
local rawUrl = "https://raw.githubusercontent.com/OliusSchool/Taskium/"
local repoUrl = "https://github.com/OliusSchool/Taskium"
local commitApiUrl = "https://api.github.com/repos/OliusSchool/Taskium/commits/main"
local treeApiUrl = "https://api.github.com/repos/OliusSchool/Taskium/git/trees/"
local cacheMarker = "--Taskium cached file, remove this line to keep local edits after updates.\n"
local syncFolders = { "Client", "Games", "GUI", "Libraries" }

local Taskium = getgenv().Taskium or {}
getgenv().Taskium = Taskium
Taskium.Libraries = Taskium.Libraries or {}

local FileCache = {}
local TaskiumCommit = nil

-- Fast HTTP request function with strict timeout to prevent hanging
local function httpGet(url)
    if type(request) == "function" then
        local ok, res = pcall(request, {
            Url = url,
            Method = "GET",
            Timeout = 5000 
        })
        if ok and type(res) == "table" and (res.Success or (res.StatusCode >= 200 and res.StatusCode <= 299)) then
            return true, tostring(res.Body)
        end
        return false, (res and res.StatusCode or "Request failed")
    else
        local ok, body = pcall(game.HttpGet, game, url, true)
        return ok, body
    end
end

local function readCachedCommit()
    if not isfile(commitFile) then
        return ""
    end

    local value = readfile(commitFile)
    value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #value == 40 then return value end
    if value == "main" then return "main" end
    return ""
end

local function executeFile(path)
    local repoP = tostring(path or ""):gsub("\\", "/")
    local marker = "/" .. mainFolder .. "/"
    local markerIndex = repoP:find(marker, 1, true)
    if markerIndex then
        repoP = repoP:sub(markerIndex + #marker)
    elseif repoP:sub(1, #mainFolder + 1) == mainFolder .. "/" then
        repoP = repoP:sub(#mainFolder + 2)
    end
    local localPath = mainFolder .. "/" .. repoP

    if FileCache[localPath] ~= nil then
        return FileCache[localPath] == false and nil or FileCache[localPath]
    end

    local source = ""
    if isfile(localPath) then
        source = readfile(localPath) or ""
    else
        local isSynced = false
        for _, folder in ipairs(syncFolders) do
            if repoP == folder or repoP:sub(1, #folder + 1) == folder .. "/" then
                isSynced = true
                break
            end
        end

        if not isSynced then
            warn("Blocked download outside synced folders: " .. repoP)
            FileCache[localPath] = false
            return nil
        else
            local parentFolder = repoP:match("^(.*)/[^/]+$")
            if parentFolder then
                local current = mainFolder
                for part in parentFolder:gmatch("[^/]+") do
                    current ..= "/" .. part
                    if not isfolder(current) then makefolder(current) end
                end
            end

            local commit = TaskiumCommit or readCachedCommit()
            if commit == "" then commit = "main" end

            local ok, body = httpGet(rawUrl .. commit .. "/" .. repoP)
            if not ok or body == "404: Not Found" then
                warn("Failed to download " .. repoP .. ": " .. tostring(body))
                FileCache[localPath] = false
                return nil
            else
                writefile(localPath, repoP:find("%.lua$") and (cacheMarker .. body) or body)
                source = body
            end
        end
    end

    if source == "" then
        FileCache[localPath] = false
        return nil
    end

    local finalSource = source:sub(1, #cacheMarker) == cacheMarker and source:sub(#cacheMarker + 1) or source
    local chunk, compileError = loadstring(finalSource, "@" .. localPath)
    if not chunk then
        FileCache[localPath] = false
        return warn("Failed to load " .. localPath .. ": " .. tostring(compileError))
    end

    local ok, result = pcall(chunk)
    if not ok then
        FileCache[localPath] = false
        return warn("Failed to run " .. localPath .. ": " .. tostring(result))
    end

    FileCache[localPath] = result or false
    return result
end

local function executeLuaFiles(path)
    if not isfolder(path) then return end
    
    local output = {}
    local stack = {path}
    
    -- 1. Recursively find all .lua files
    while #stack > 0 do
        local currPath = table.remove(stack)
        local files = listfiles(currPath)
        if type(files) == "table" then
            for _, child in ipairs(files) do
                if isfolder(child) then
                    table.insert(stack, child)
                elseif child:sub(-4) == ".lua" then
                    table.insert(output, child)
                end
            end
        end
    end
    table.sort(output)

    -- 2. Pre-download any missing files IN PARALLEL
    -- This stops the executor from hanging while loading categories/modules one by one
    local missingFiles = {}
    for _, file in ipairs(output) do
        if not isfile(file) then
            table.insert(missingFiles, file)
        end
    end

    if #missingFiles > 0 then
        local remaining = #missingFiles
        local fileIndex = 1
        local MAX_WORKERS = 10

        local function downloadWorker()
            while true do
                local idx = fileIndex
                fileIndex = fileIndex + 1
                if idx > #missingFiles then break end

                local file = missingFiles[idx]
                pcall(function()
                    local repoP = tostring(file or ""):gsub("\\", "/")
                    local marker = "/" .. mainFolder .. "/"
                    local markerIndex = repoP:find(marker, 1, true)
                    if markerIndex then
                        repoP = repoP:sub(markerIndex + #marker)
                    elseif repoP:sub(1, #mainFolder + 1) == mainFolder .. "/" then
                        repoP = repoP:sub(#mainFolder + 2)
                    end
                    local localPath = mainFolder .. "/" .. repoP

                    local parentFolder = repoP:match("^(.*)/[^/]+$")
                    if parentFolder then
                        local current = mainFolder
                        for part in parentFolder:gmatch("[^/]+") do
                            current ..= "/" .. part
                            if not isfolder(current) then makefolder(current) end
                        end
                    end

                    local commit = TaskiumCommit or readCachedCommit()
                    if commit == "" then commit = "main" end

                    local okDl, bodyDl = httpGet(rawUrl .. commit .. "/" .. repoP)
                    if okDl and bodyDl ~= "404: Not Found" then
                        writefile(localPath, repoP:find("%.lua$") and (cacheMarker .. bodyDl) or bodyDl)
                    end
                end)
                remaining = remaining - 1
            end
        end

        local workers = {}
        for i = 1, math.min(MAX_WORKERS, #missingFiles) do
            table.insert(workers, task.spawn(downloadWorker))
        end

        while remaining > 0 do
            task.wait(0.05)
        end
    end

    -- 3. Execute the files sequentially, but yield periodically
    -- This prevents the Roblox thread from freezing while compiling/running modules
    for i, file in ipairs(output) do
        executeFile(file)
        if i % 10 == 0 then
            task.wait() -- Yield every 10 files to let the UI breathe
        end
    end
end

function Taskium.Teleport()
    local queue = queue_on_teleport or queueonteleport
    if not queue then
        Taskium.TeleportQueued = false
        return false
    end

    local source = [[
if not game:IsLoaded() then
    game.Loaded:Wait()
end

task.spawn(function()
    local path = "Taskium/Client/Loader.lua"
    local source = isfile(path) and readfile(path)
    if source then
        loadstring(source, "@" .. path)()
    end
end)
]]

    Taskium.TeleportQueued = pcall(queue, source)
    return Taskium.TeleportQueued
end

function Taskium.ExecuteFile(path)
    return executeFile(path)
end

function Taskium.LoadLibrary(name)
    if Taskium.Libraries[name] then
        return Taskium.Libraries[name]
    end

    local library = executeFile(mainFolder .. "/Libraries/" .. name .. ".lua")
    Taskium.Libraries[name] = library
    return library
end

function Taskium.SyncTaskiumFiles()
    if not isfolder(mainFolder) then makefolder(mainFolder) end
    for _, folder in ipairs(syncFolders) do
        if not isfolder(mainFolder .. "/" .. folder) then makefolder(mainFolder .. "/" .. folder) end
    end

    local commit = ""
    if TaskiumCommit ~= nil then
        commit = TaskiumCommit
    else
        local ok, body = httpGet(commitApiUrl)
        if ok then
            local decodedOk, decoded = pcall(HttpService.JSONDecode, HttpService, body)
            local sha = decodedOk and type(decoded) == "table" and decoded.sha
            if type(sha) == "string" and #sha == 40 then
                TaskiumCommit = sha
                commit = sha
            end
        end

        if commit == "" then
            ok, body = httpGet(repoUrl)
            local index = ok and body and body:find("currentOid")
            local sha = index and body:sub(index + 13, index + 52) or ""
            if #sha == 40 then
                TaskiumCommit = sha
                commit = sha
            end
        end

        if commit == "" then
            commit = readCachedCommit()
            if commit == "" then
                commit = "main"
            end
            TaskiumCommit = commit
        end
    end

    if readCachedCommit() == commit then
        return { CreatedFolders = {}, CreatedFiles = {}, MergedFiles = {}, UpdatedFiles = {}, PreservedFiles = {}, FailedFiles = {} }
    end

    -- Skip bulk sync if API is rate-limited, executeFile will handle it on-demand
    if commit == "main" then
        warn("Taskium: GitHub API rate-limited or unavailable. Skipping bulk sync. Files will load on-demand.")
        return { CreatedFolders = {}, CreatedFiles = {}, MergedFiles = {}, UpdatedFiles = {}, PreservedFiles = {}, FailedFiles = {} }
    end

    local ok, body = httpGet(treeApiUrl .. commit .. "?recursive=1")
    if not ok then
        warn("Failed to list repository tree: " .. tostring(body))
        return { CreatedFolders = {}, CreatedFiles = {}, MergedFiles = {}, UpdatedFiles = {}, PreservedFiles = {}, FailedFiles = {} }
    end

    local decodedOk, decoded = pcall(HttpService.JSONDecode, HttpService, body)
    if not decodedOk or type(decoded) ~= "table" or type(decoded.tree) ~= "table" or decoded.message then
        warn("Failed to decode repository tree: " .. tostring(decoded and decoded.message or decoded))
        return { CreatedFolders = {}, CreatedFiles = {}, MergedFiles = {}, UpdatedFiles = {}, PreservedFiles = {}, FailedFiles = {} }
    end

    local directories = {}
    local files = {}
    for _, item in ipairs(decoded.tree) do
        if type(item.path) == "string" then
            local isSynced = false
            for _, folder in ipairs(syncFolders) do
                if item.path == folder or item.path:sub(1, #folder + 1) == folder .. "/" then
                    isSynced = true
                    break
                end
            end
            if isSynced then
                if item.type == "tree" then
                    table.insert(directories, item.path)
                elseif item.type == "blob" then
                    table.insert(files, item.path)
                end
            end
        end
    end

    table.sort(directories)
    table.sort(files)

    for _, folder in ipairs(syncFolders) do
        local stack = { mainFolder .. "/" .. folder }
        while #stack > 0 do
            local currPath = table.remove(stack)
            if isfolder(currPath) then
                local children = listfiles(currPath)
                if type(children) == "table" then
                    for _, child in ipairs(children) do
                        if isfolder(child) then
                            table.insert(stack, child)
                        elseif isfile(child) then
                            local content = readfile(child) or ""
                            if content:sub(1, #cacheMarker) == cacheMarker then
                                if delfile then delfile(child) else writefile(child, "") end
                            end
                        end
                    end
                end
            end
        end
    end

    for _, directory in ipairs(directories) do
        if not isfolder(mainFolder .. "/" .. directory) then makefolder(mainFolder .. "/" .. directory) end
    end

    local success = true
    local remaining = #files
    local fileIndex = 1
    local MAX_WORKERS = 10

    local function downloadWorker()
        while true do
            local idx = fileIndex
            fileIndex = fileIndex + 1
            if idx > #files then break end

            local file = files[idx]
            local okThread, err = pcall(function()
                local repoP = tostring(file or ""):gsub("\\", "/")
                local localPath = mainFolder .. "/" .. repoP

                local existing = isfile(localPath) and readfile(localPath) or nil
                if existing and existing ~= "" and existing:sub(1, #cacheMarker) ~= cacheMarker then
                    return 
                end

                local parentFolder = repoP:match("^(.*)/[^/]+$")
                if parentFolder then
                    local current = mainFolder
                    for part in parentFolder:gmatch("[^/]+") do
                        current ..= "/" .. part
                        if not isfolder(current) then makefolder(current) end
                    end
                end

                local okDl, bodyDl = httpGet(rawUrl .. commit .. "/" .. repoP)
                if not okDl or bodyDl == "404: Not Found" then
                    warn("Failed to download " .. repoP .. ": " .. tostring(bodyDl))
                    success = false
                else
                    writefile(localPath, repoP:find("%.lua$") and (cacheMarker .. bodyDl) or bodyDl)
                end
            end)

            if not okThread then
                warn("Taskium download thread failed: " .. tostring(err))
                success = false
            end
            remaining = remaining - 1
        end
    end

    local workers = {}
    for i = 1, math.min(MAX_WORKERS, #files) do
        table.insert(workers, task.spawn(downloadWorker))
    end

    while remaining > 0 do
        task.wait(0.1)
    end

    if success then
        writefile(commitFile, commit)
    else
        warn("Taskium files did not fully sync. The old commit marker was kept so this can retry next run.")
    end

    return { CreatedFolders = {}, CreatedFiles = {}, MergedFiles = {}, UpdatedFiles = {}, PreservedFiles = {}, FailedFiles = {} }
end

function Taskium.RestartTaskium()
    if Taskium.Config and type(Taskium.Config.Flush) == "function" then
        pcall(function()
            Taskium.Config:Flush()
        end)
    end
    if Taskium.API and type(Taskium.API.Shutdown) == "function" then
        pcall(function()
            Taskium.API:Shutdown()
        end)
    end

    FileCache = {}

    local config = executeFile(mainFolder .. "/Client/Config.lua")
    local api = executeFile(mainFolder .. "/GUI/BetaUI.lua") or executeFile(mainFolder .. "/GUI/TaskUI.lua")
    if not api then
        return warn("Taskium bootstrap could not find a Taskium GUI.")
    end

    getgenv().TaskAPI = api
    Taskium.API = api
    Taskium.Config = config
    api.Config = config

    executeFile(mainFolder .. "/GUI/Categories.lua")

    local games = executeFile(mainFolder .. "/Games/Games.lua")
    if type(games) ~= "table" then games = {} end

    local gameFile = Taskium.GameFile
        or (games.GameIds and games.GameIds[game.GameId])
        or (games.PlaceIds and games.PlaceIds[game.PlaceId])
        or games.Default
        or "Universal/Main.lua"

    Taskium.GameFile = gameFile

    executeFile(mainFolder .. "/Games/Universal/Main.lua")
    executeLuaFiles(mainFolder .. "/Games/Universal/Categories")
    
    if gameFile ~= "Universal/Main.lua" then
        executeFile(mainFolder .. "/Games/" .. gameFile)
        local gameRoot = type(gameFile) == "string" and gameFile:match("^(.+)/Main%.lua$")
        if gameRoot then
            executeLuaFiles(mainFolder .. "/Games/" .. gameRoot .. "/Categories")
        end
    end

    return api
end

Taskium.SyncTaskiumFiles()

local api = Taskium.RestartTaskium()
Taskium.Teleport()

if api then
    if type(api.Notification) == "function" then
        api.Notification("Taskium", "Taskium initialized successfully!", 3, "Success")
    else
        print("Taskium initialized successfully!")
    end
end

return api