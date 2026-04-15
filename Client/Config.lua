local HttpService = game:GetService("HttpService")

local RootFolder = "Taskium"
local ClientFolder = RootFolder .. "/Client"
local ConfigDataPath = ClientFolder .. "/ConfigData.json"

local Taskium = getgenv().Taskium or {}
getgenv().Taskium = Taskium

local Config = {
	Path = ConfigDataPath,
	Data = {
		Controls = {}
	}
}

local function ensureFolder(path)
	if not isfolder(path) then
		makefolder(path)
	end
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, innerValue in pairs(value) do
		copy[key] = deepCopy(innerValue)
	end
	return copy
end

function Config:Save()
	ensureFolder(RootFolder)
	ensureFolder(ClientFolder)
	writefile(self.Path, HttpService:JSONEncode(self.Data))
end

function Config:Load()
	ensureFolder(RootFolder)
	ensureFolder(ClientFolder)

	if isfile(self.Path) then
		local success, decoded = pcall(function()
			return HttpService:JSONDecode(readfile(self.Path))
		end)

		if success and type(decoded) == "table" then
			self.Data = decoded
		else
			self.Data = {
				Controls = {}
			}
		end
	else
		self.Data = {
			Controls = {}
		}
		self:Save()
	end

	self.Data.Controls = self.Data.Controls or {}
	return self.Data
end

function Config:BuildKey(kind, ...)
	local parts = { ... }
	for index, value in ipairs(parts) do
		parts[index] = tostring(value)
	end

	return tostring(kind) .. "::" .. table.concat(parts, "/")
end

function Config:Register(kind, key, defaultValue)
	local store = self.Data.Controls
	local fullKey = self:BuildKey(kind, key)

	if store[fullKey] == nil then
		store[fullKey] = deepCopy(defaultValue)
		self:Save()
	end

	return deepCopy(store[fullKey])
end

function Config:Get(kind, key, defaultValue)
	local store = self.Data.Controls
	local fullKey = self:BuildKey(kind, key)
	local storedValue = store[fullKey]

	if storedValue == nil then
		return deepCopy(defaultValue)
	end

	return deepCopy(storedValue)
end

function Config:Set(kind, key, value)
	local store = self.Data.Controls
	local fullKey = self:BuildKey(kind, key)
	store[fullKey] = deepCopy(value)
	self:Save()
	return deepCopy(value)
end

function Config:Remove(kind, key)
	local store = self.Data.Controls
	local fullKey = self:BuildKey(kind, key)
	store[fullKey] = nil
	self:Save()
end

Config:Load()

Taskium.Config = Config

return Config
