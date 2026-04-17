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

local function EnsureFolder(Path)
	if not isfolder(Path) then
		makefolder(Path)
	end
end

local function DeepCopy(Value)
	if type(Value) ~= "table" then
		return Value
	end

	local Copy = {}
	for Key, InnerValue in pairs(Value) do
		Copy[Key] = DeepCopy(InnerValue)
	end
	return Copy
end

function Config:Save()
	EnsureFolder(RootFolder)
	EnsureFolder(ClientFolder)
	writefile(self.Path, HttpService:JSONEncode(self.Data))
end

function Config:Load()
	EnsureFolder(RootFolder)
	EnsureFolder(ClientFolder)

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

function Config:BuildKey(Kind, ...)
	local Parts = { ... }
	for Index, Value in ipairs(Parts) do
		Parts[Index] = tostring(Value)
	end

	return tostring(Kind) .. "::" .. table.concat(Parts, "/")
end

function Config:Register(Kind, Key, DefaultValue)
	local Store = self.Data.Controls
	local FullKey = self:BuildKey(Kind, Key)

	if Store[FullKey] == nil then
		Store[FullKey] = DeepCopy(DefaultValue)
		self:Save()
	end

	return DeepCopy(Store[FullKey])
end

function Config:Get(Kind, Key, DefaultValue)
	local Store = self.Data.Controls
	local FullKey = self:BuildKey(Kind, Key)
	local StoredValue = Store[FullKey]

	if StoredValue == nil then
		return DeepCopy(DefaultValue)
	end

	return DeepCopy(StoredValue)
end

function Config:Set(Kind, Key, Value)
	local Store = self.Data.Controls
	local FullKey = self:BuildKey(Kind, Key)
	Store[FullKey] = DeepCopy(Value)
	self:Save()
	return DeepCopy(Value)
end

function Config:Remove(Kind, Key)
	local Store = self.Data.Controls
	local FullKey = self:BuildKey(Kind, Key)
	Store[FullKey] = nil
	self:Save()
end

Config:Load()

Taskium.Config = Config

return Config
