-- Uses the actual generator with a minimal deterministic Studio data model.
local function eq(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local function harness()
	local instance = {}
	local function new(class)
		local object = {_children = {}, _attributes = {}, ClassName = class}
		function object:FindFirstChild(name)
			for _, child in ipairs(self._children) do if child.Name == name then return child end end
		end
		function object:WaitForChild(name) return assert(self:FindFirstChild(name), name) end
		function object:SetAttribute(key, value) self._attributes[key] = value end
		function object:GetAttribute(key) return self._attributes[key] end
		function object:Destroy() self.Parent = nil self.destroyed = true end
		return setmetatable(object, {
			__newindex = function(self, key, value)
				if key == "Parent" then
					local previous = rawget(self, "_parent")
					if previous then table.remove(previous._children, table.find(previous._children, self)) end
					rawset(self, "_parent", value)
					if value then table.insert(value._children, self) end
				else rawset(self, key, value) end
			end,
			__index = function(self, key) return if key == "Parent" then rawget(self, "_parent") else self:FindFirstChild(key) end,
		})
	end
	instance.new = new
	local replicated, server, starter, world = new("Folder"), new("Folder"), new("Folder"), new("Folder")
	replicated.Name = "ReplicatedStorage" server.Name = "ServerScriptService" starter.Name = "StarterPlayer" world.Name = "Workspace"
	local scripts = new("Folder") scripts.Name = "StarterPlayerScripts" scripts.Parent = starter
	local history = {begun = 0, finished = {}}
	function history:TryBeginRecording() self.begun += 1 return "recording" end
	function history:FinishRecording(_, operation) table.insert(self.finished, operation) end
	local guid = 0
	local services = {HttpService = {JSONEncode = function() return '{"quests":[],"hostile":"\\\"\\nreturn 12"}' end,
		GenerateGUID = function() guid += 1 return "id" .. guid end},
		ChangeHistoryService = history, RunService = {IsRunning = function() return false end},
		ReplicatedStorage = replicated, ServerScriptService = server, StarterPlayer = starter,
		CollectionService = {AddTag = function() end}}
	local templates = {}
	function templates:FindFirstChild(name) return {Value = "-- source for " .. name} end
	local chunk = assert(loadstring(GENERATOR_SOURCE, "Generator"))
	setfenv(chunk, setmetatable({game = {GetService = function(_, name) return assert(services[name], name) end},
		script = {Parent = {Schema = "Schema", Templates = templates}}, require = function() return Schema end,
		Instance = instance, Enum = {FinishRecordingOperation = {Commit = "Commit", Cancel = "Cancel"}},
		workspace = world, Vector3 = {new = function(...) return {...} end}, Color3 = {fromRGB = function(...) return {...} end}}, {__index = getfenv()}))
	return {generator = chunk(), replicated = replicated, server = server, scripts = scripts, history = history, new = new, world = world}
end
local count = 0
local function test(name, callback) callback() count += 1 print("PASS " .. name) end

test("generator connects config, remotes, server modules and client entry point", function()
	local h = harness()
	h.generator.Generate(Example)
	local root, server = h.replicated:FindFirstChild("QuestForgePro"), h.server:FindFirstChild("QuestForgePro")
	assert(root.Config.Source:find("JSONDecode", 1, true))
	assert(loadstring(root.Config.Source), "Generated configuration must be valid Luau")
	eq(root.Request.ClassName, "RemoteEvent") eq(root.Snapshot.ClassName, "RemoteEvent")
	for _, name in ipairs({"Schema", "Engine", "QuestService"}) do eq(server[name].ClassName, "ModuleScript") end
	eq(server.Bootstrap.ClassName, "Script") eq(h.scripts.QuestForgeProClient.ClassName, "LocalScript")
	eq(h.history.begun, 1) eq(h.history.finished[1], "Commit")
end)
test("regeneration replaces owned instances and changes the revision", function()
	local h = harness() h.generator.Generate(Example)
	local old = h.replicated.QuestForgePro local revision = old:GetAttribute("Revision")
	h.generator.Generate(Example)
	assert(old.destroyed) assert(h.replicated.QuestForgePro:GetAttribute("Revision") ~= revision)
	eq(#h.replicated._children, 1) eq(#h.server._children, 1) eq(#h.scripts._children, 1)
end)
test("an unowned collision leaves all existing place containers untouched", function()
	local h = harness()
	local unowned = h.new("Folder") unowned.Name = "QuestForgePro" unowned.Parent = h.server
	eq(pcall(h.generator.Generate, Example), false)
	eq(h.server.QuestForgePro, unowned) eq(#h.replicated._children, 0) eq(#h.scripts._children, 0) eq(h.history.begun, 0)
end)
test("invalid configurations cannot alter the place", function()
	local h = harness() local config = Schema.Clone(Example) config.quests[1].rewards[1].amount = -1
	eq(pcall(h.generator.Generate, config), false) eq(h.history.begun, 0) eq(#h.replicated._children, 0)
end)
test("example scene creates five anchored tagged prompt targets", function()
	local h = harness() h.generator.Demo()
	local scene = h.world.QuestForgeExample eq(#scene._children, 5)
	for _, part in ipairs(scene._children) do eq(part.ClassName, "Part") eq(part.Anchored, true) eq(part.QuestPrompt.ClassName, "ProximityPrompt") assert(part:GetAttribute("QuestTarget")) end
	eq(h.history.finished[1], "Commit")
end)
print("Passed " .. count .. " Studio generator harness scenarios")
