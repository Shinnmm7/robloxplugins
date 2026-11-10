local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Schema = require(script.Parent.Schema)
local templates = script.Parent.Templates
local Generator = {}
local function create(class, name, parent)
	local object = Instance.new(class)
	object.Name = name
	object.Parent = parent
	return object
end
local function source(class, name, text, parent)
	local object = create(class, name, parent)
	object.Source = text
	return object
end
local function template(name) return templates:FindFirstChild(name).Value end
local function recording(label, callback)
	assert(not RunService:IsRunning(), "Stop the play test before editing generated systems")
	local id = ChangeHistoryService:TryBeginRecording("QuestForgePro." .. HttpService:GenerateGUID(false), label)
	assert(id, "Studio is busy recording another edit. Try again.")
	local ok, result = pcall(callback)
	ChangeHistoryService:FinishRecording(id, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	if not ok then error(result, 0) end
	return result
end
local function replace(parent, object)
	local old = parent:FindFirstChild(object.Name)
	assert(not old or old:GetAttribute("QuestForgeGenerated") == true, parent.Name .. "/" .. object.Name .. " already exists and is not owned by QuestForge Pro")
	if old then old:Destroy() end
	object.Parent = parent
end
function Generator.Generate(config)
	local errors = Schema.Validate(config)
	assert(#errors == 0, table.concat(errors, "\n"))
	local json = HttpService:JSONEncode(config)
	assert(#json < 3000000, "Configuration exceeds the safe serialized size for a single Roblox container")
	-- JSON is quoted, so user-authored strings never become executable Luau.
	local configSource = 'return game:GetService("HttpService"):JSONDecode(' .. string.format("%q", json) .. ')'
	local replicated = create("Folder", "QuestForgePro")
	replicated:SetAttribute("QuestForgeGenerated", true)
	replicated:SetAttribute("Revision", HttpService:GenerateGUID(false))
	source("ModuleScript", "Config", configSource, replicated)
	local data = create("StringValue", "ConfigurationData", replicated)
	data.Value = json
	create("RemoteEvent", "Request", replicated)
	create("RemoteEvent", "Snapshot", replicated)
	local server = create("Folder", "QuestForgePro")
	server:SetAttribute("QuestForgeGenerated", true)
	source("ModuleScript", "Engine", template("Engine"), server)
	source("ModuleScript", "Schema", template("Schema"), server)
	source("ModuleScript", "QuestService", template("QuestService"), server)
	source("Script", "Bootstrap", template("Bootstrap"), server)
	local client = source("LocalScript", "QuestForgeProClient", template("Client"))
	client:SetAttribute("QuestForgeGenerated", true)
	local destinations = {
		{game:GetService("ReplicatedStorage"), replicated},
		{game:GetService("ServerScriptService"), server},
		{game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"), client},
	}
	-- Preflight all collisions before touching the place.
	for _, pair in ipairs(destinations) do
		local old = pair[1]:FindFirstChild(pair[2].Name)
		if old and old:GetAttribute("QuestForgeGenerated") ~= true then
			replicated:Destroy() server:Destroy() client:Destroy()
			error("An unowned " .. pair[1].Name .. "/" .. pair[2].Name .. " exists", 0)
		end
	end
	return recording("Generate QuestForge Pro system", function()
		for _, pair in ipairs(destinations) do replace(pair[1], pair[2]) end
		return "Generated configuration, server modules, remotes, and client journal. Use Undo to revert."
	end)
end
function Generator.ReadPlace()
	local root = game:GetService("ReplicatedStorage"):FindFirstChild("QuestForgePro")
	local data = root and root:FindFirstChild("ConfigurationData")
	assert(data and data:IsA("StringValue"), "No generated configuration exists in this place")
	local config = HttpService:JSONDecode(data.Value)
	local errors = Schema.Validate(config)
	assert(#errors == 0, table.concat(errors, "\n"))
	return config
end
function Generator.Demo()
	return recording("Create QuestForge Pro example scene", function()
		local folder = create("Folder", "QuestForgeExample")
		folder:SetAttribute("QuestForgeGenerated", true)
		local function target(name, position, color, kind, targetId, item)
			local part = create("Part", name, folder)
			part.Anchored = true
			part.Size = Vector3.new(3, 3, 3)
			part.Position = position
			part.Color = color
			part:SetAttribute("QuestType", kind)
			part:SetAttribute("QuestTarget", targetId)
			part:SetAttribute("QuestAmount", if kind == "Deliver" then 3 else 1)
			if item then part:SetAttribute("QuestItem", item) end
			local prompt = create("ProximityPrompt", "QuestPrompt", part)
			prompt.ActionText = kind
			prompt.ObjectText = name
			prompt.HoldDuration = 0.25
			prompt.MaxActivationDistance = 10
			CollectionService:AddTag(part, "QuestForgeTarget")
		end
		-- Placed in front of the origin; safely move the whole folder in Studio.
		target("Rowan • Talk", Vector3.new(0, 3, -12), Color3.fromRGB(120, 95, 230), "Talk", "rowan")
		target("Rowan • Deliver crystals", Vector3.new(5, 3, -12), Color3.fromRGB(230, 175, 65), "Deliver", "rowan", "crystal")
		for i = 1, 3 do target("Crystal " .. i, Vector3.new(i * 5, 2, -24), Color3.fromRGB(60, 210, 220), "Collect", "crystal") end
		replace(workspace, folder)
		return "Example scene created near the origin. Generate the example configuration, then Play and accept A Spark for Rowan."
	end)
end
return Generator
