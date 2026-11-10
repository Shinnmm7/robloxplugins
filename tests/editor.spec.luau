-- Interaction smoke test for the real editor using lightweight Roblox GUI objects.
local function signal()
	local listeners = {}
	return {Connect = function(_, callback) table.insert(listeners, callback) end,
		Fire = function(_, ...) for _, callback in ipairs(listeners) do callback(...) end end}
end
local function harness()
	local function new(class)
		local object = {ClassName = class, children = {}, Activated = signal(), FocusLost = signal()}
		function object:IsA(name)
			return name == self.ClassName or (name == "GuiObject" and table.find({"Frame", "TextButton", "TextBox", "TextLabel", "ScrollingFrame"}, self.ClassName) ~= nil)
		end
		function object:GetChildren() return table.clone(self.children) end
		function object:GetPropertyChangedSignal() return signal() end
		function object:Destroy()
			if self.Parent then table.remove(self.Parent.children, table.find(self.Parent.children, self)) end
			self.Parent = nil
		end
		return setmetatable(object, {__newindex = function(self, key, value)
			rawset(self, key, value)
			if key == "Parent" and value then table.insert(value.children, self) end
		end})
	end
	local widget, settings, encoded, serial, generated, scenes = new("Frame"), {}, {}, 0, nil, 0
	local plugin = {SetSetting = function(_, key, value) settings[key] = value end, GetSetting = function(_, key) return settings[key] end}
	local http = {JSONEncode = function(_, value) serial += 1 local key = "json-" .. serial encoded[key] = Schema.Clone(value) return key end,
		JSONDecode = function(_, key) return Schema.Clone(assert(encoded[key], "Invalid synthetic JSON")) end}
	local generator = {Generate = function(config) generated = Schema.Clone(config) return "Generated" end,
		Demo = function() scenes += 1 return "Scene created" end, ReadPlace = function() return Schema.Clone(Example) end}
	local enum = setmetatable({}, {__index = function(_, name) return setmetatable({}, {__index = function(_, item) return name .. "." .. item end}) end})
	local types = {new = function(...) return {...} end, fromOffset = function(...) return {...} end, fromScale = function(...) return {...} end, fromRGB = function(...) return {...} end, zero = {}}
	local chunk = assert(loadstring(EDITOR_SOURCE, "Editor"))
	setfenv(chunk, setmetatable({game = {GetService = function() return http end}, script = {Parent = {Schema = "Schema", Example = "Example", Generator = "Generator"}},
		require = function(name) return ({Schema = Schema, Example = Example, Generator = generator})[name] end,
		Instance = {new = new}, Color3 = types, UDim2 = types, UDim = types, Vector2 = types, Enum = enum}, {__index = getfenv()}))
	local cleanup = chunk().Mount(plugin, widget)
	local function descendants(object, found)
		for _, child in ipairs(object.children) do table.insert(found, child) descendants(child, found) end
		return found
	end
	local function find(class, exact, prefix)
		for _, object in ipairs(descendants(widget, {})) do
			if object.ClassName == class and (object.Text == exact or (prefix and type(object.Text) == "string" and object.Text:sub(1, #exact) == exact)) then return object end
		end
		error("Missing UI control: " .. class .. " " .. tostring(exact))
	end
	local function click(label, prefix) find("TextButton", label, prefix).Activated:Fire() end
	local function editLabel(label, value)
		local heading = find("TextLabel", label)
		for _, input in ipairs(heading.Parent.children) do
			if input.ClassName == "TextBox" and input.LayoutOrder == heading.LayoutOrder + 1 then
				input.Text = value input.FocusLost:Fire() return
			end
		end
		error("Missing labeled input " .. label)
	end
	local function edit(current, value) local input = find("TextBox", current) input.Text = value input.FocusLost:Fire() end
	return {click = click, edit = edit, editLabel = editLabel, find = find, getGenerated = function() return generated end, getScenes = function() return scenes end, cleanup = cleanup}
end
local h = harness()
h.click("+ New quest")
h.edit("New quest", "Guild assignment")
h.edit("quest_1", "guild_assignment")
h.click("Objectives")
h.click("+ Add stage")
h.click("+ Add objective")
h.click("Move up")
h.click("○  Optional")
h.click("Rewards")
h.click("+ Add reward")
h.click("XP  ▸")
h.click("Requirements")
h.editLabel("Prerequisite quest IDs (comma separated)", "crystal_errand")
h.click("+ Add required item")
h.click("Preview")
h.click("Generate")
h.click("Save configuration to plugin settings")
h.click("Generate quest system into this place")
local generated = h.getGenerated()
assert(#generated.quests == 2)
local q = generated.quests[2]
assert(q.id == "guild_assignment" and q.name == "Guild assignment")
assert(#q.stages == 2 and #q.objectives == 2 and q.objectives[1].optional)
assert(#q.rewards == 2 and q.rewards[1].type == "Currency")
assert(q.prerequisites[1] == "crystal_errand" and #q.requirements.items == 1)
h.click("Load saved configuration")
h.click("Load configuration from this place")
h.click("Load working example configuration")
h.click("Create / replace example scene")
assert(h.getScenes() == 1)
h.click("Details")
h.click("Duplicate quest")
h.click("Delete this quest")
h.cleanup()
print("PASS editor interaction smoke: quest edits, stages, objectives, rewards, requirements, preview, persistence, generation, example, duplicate and delete")
