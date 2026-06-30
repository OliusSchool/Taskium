local Taskium = shared.Taskium or getgenv().Taskium
local TaskAPI = getgenv().TaskAPI or (Taskium and Taskium.API)

local players = game:GetService("Players")
local runService = game:GetService("RunService")
local workspace = game:GetService("Workspace")

local lplr = players.LocalPlayer
local gameCam = workspace.CurrentCamera

local runtime = rawget(getgenv(), "TaskiumUniversal")
if type(runtime) ~= "table" then
	runtime = {}
	getgenv().TaskiumUniversal = runtime
end

local function Run(func)
	return func()
end

local function characterState(plr)
	plr = plr or lplr
	local character = plr and plr.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = humanoid and humanoid.RootPart
		or character and (
			character:FindFirstChild("HumanoidRootPart")
			or character.PrimaryPart
			or character:FindFirstChild("Root")
			or character:FindFirstChild("Torso")
			or character:FindFirstChild("UpperTorso")
		)

	return character, humanoid, rootPart
end

runtime.TaskAPI = TaskAPI
runtime.Run = Run
runtime.players = players
runtime.runService = runService
runtime.workspace = workspace
runtime.lplr = lplr
runtime.gameCam = gameCam
runtime.characterState = characterState

return runtime