local TaskAPI = getgenv().TaskAPI or (getgenv().TaskClient and getgenv().TaskClient.API)
local TaskClient = getgenv().TaskClient

if not TaskAPI or not TaskAPI.Categories or not TaskAPI.Categories.Combat or not TaskAPI.Categories.Other then
	error("Required categories were not loaded before Games/Universal.lua")
end

local TestModule
TestModule = TaskAPI.Categories.Combat:CreateModule({
	Name = "TestModule",
	Function = function(enabled)
		print(enabled, "module state")

		if enabled then
			TestModule:Clean(Instance.new("Part"))

			repeat
				print("repeat loop!")
				task.wait(1)
			until (not TestModule.Enabled)
		end
	end,
	ExtraText = function()
		return "What"
	end,
	Tooltip = "This is a test module."
})

local Update
Update = TaskAPI.Categories.Other:CreateModule({
	Name = "Update",
	Function = function(enabled)
		if not enabled then
			return
		end

		if not TaskClient or type(TaskClient.SyncTaskiumFiles) ~= "function" then
			error("Taskium updater is not available")
		end

		local report = TaskClient.SyncTaskiumFiles(true)
		local createdFolders = #report.CreatedFolders
		local createdFiles = #report.CreatedFiles
		local updatedFiles = #report.UpdatedFiles

		if createdFolders > 0 then
			TaskAPI.Notification("Taskium", ("Created %d folder(s)."):format(createdFolders), 3, "Info")
		end

		if createdFiles > 0 or updatedFiles > 0 then
			TaskAPI.Notification("Taskium", ("Updated %d file(s), added %d file(s)."):format(updatedFiles, createdFiles), 4, "Success")
		else
			TaskAPI.Notification("Taskium", "No file updates found.", 3, "Info")
		end

		task.defer(function()
			if Update and Update.Enabled then
				Update:SetEnabled(false)
			end
		end)
	end,
	ExtraText = function()
		return "Sync"
	end,
	Tooltip = "Downloads updated Taskium files from GitHub."
})

return TaskAPI
