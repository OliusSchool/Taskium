local Taskium = (shared and shared.Taskium) or getgenv().Taskium
local Main = Taskium.ExecuteFile("Taskium/Games/Bedwars/Main.lua")

local TaskAPI = Main.TaskAPI
local runService = Main.runService
local lplr = Main.lplr
local bedwars = Main.bedwars
local remotes = Main.remotes

local Run = Main.Run or function(func)
	return func()
end

local AntiAFK

Run(function()
	AntiAFK = TaskAPI.Categories.Player:CreateModule({
		Name = "Anti-AFK",
		Function = function(enabled)
			if not enabled then
				return
			end

			if getconnections then
				for _, connection in ipairs(getconnections(lplr.Idled)) do
					pcall(function()
						connection:Disconnect()
					end)
				end

				if debug and debug.getconstants then
					for _, connection in ipairs(getconnections(runService.Heartbeat)) do
						local func = connection.Function
						if type(func) == "function" then
							local ok, constants = pcall(debug.getconstants, func)
							if ok and table.find(constants, remotes.AfkStatus) then
								pcall(function()
									connection:Disconnect()
								end)
							end
						end
					end
				end
			end

			if bedwars.Client and remotes.AfkStatus then
				local ok, remote = pcall(function()
					return bedwars.Client:Get(remotes.AfkStatus)
				end)
				if ok and remote and type(remote.SendToServer) == "function" then
					pcall(function()
						remote:SendToServer({ afk = false })
					end)
				end
			end
		end,
		ToolTip = "Lets you stay in game without getting kicked."
	})
end)

return AntiAFK
