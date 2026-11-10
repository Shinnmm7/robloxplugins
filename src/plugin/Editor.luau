local HttpService = game:GetService("HttpService")
local Schema = require(script.Parent.Schema)
local Example = require(script.Parent.Example)
local Generator = require(script.Parent.Generator)
local Editor = {}
local C = {bg = Color3.fromRGB(18, 21, 29), panel = Color3.fromRGB(26, 30, 41), field = Color3.fromRGB(38, 43, 57),
	text = Color3.fromRGB(233, 237, 247), muted = Color3.fromRGB(160, 172, 195), accent = Color3.fromRGB(113, 92, 235), good = Color3.fromRGB(112, 219, 164), bad = Color3.fromRGB(255, 156, 129)}
local SETTING = "QuestForgePro.Configuration.v1"
local function make(class, parent, properties)
	local object = Instance.new(class)
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end
local function round(object) make("UICorner", object, {CornerRadius = UDim.new(0, 6)}) end
local function text(parent, value, height)
	return make("TextLabel", parent, {Text = value, Size = UDim2.new(1, 0, 0, height or 24), BackgroundTransparency = 1,
		TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, LayoutOrder = #parent:GetChildren()})
end
local function button(parent, label, callback, accent)
	local object = make("TextButton", parent, {Text = label, Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = if accent then C.accent else C.field,
		TextColor3 = C.text, Font = Enum.Font.GothamMedium, TextSize = 13, BorderSizePixel = 0, LayoutOrder = #parent:GetChildren()})
	round(object)
	object.Activated:Connect(callback)
	return object
end
local function list(parent, padding)
	make("UIListLayout", parent, {Padding = UDim.new(0, padding or 8), SortOrder = Enum.SortOrder.LayoutOrder})
end
local function field(parent, label, value, callback, multiline)
	text(parent, label)
	local input = make("TextBox", parent, {Text = tostring(value), PlaceholderText = label, Size = UDim2.new(1, 0, 0, if multiline then 86 else 32),
		BackgroundColor3 = C.field, TextColor3 = C.text, PlaceholderColor3 = C.muted, Font = Enum.Font.Code, TextSize = 13,
		ClearTextOnFocus = false, MultiLine = multiline == true, TextWrapped = multiline == true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = if multiline then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center,
		BorderSizePixel = 0, LayoutOrder = #parent:GetChildren()})
	make("UIPadding", input, {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 5)})
	round(input)
	input.FocusLost:Connect(function() callback(input.Text) end)
	return input
end
local function selectField(parent, label, value, options, callback)
	text(parent, label)
	button(parent, tostring(value) .. "  ▸", function()
		local index = table.find(options, value) or 0
		callback(options[index % #options + 1])
	end)
end
local function toggle(parent, label, value, callback)
	button(parent, (if value then "✓  " else "○  ") .. label, function() callback(not value) end)
end
local function section(parent, title)
	local card = make("Frame", parent, {Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = #parent:GetChildren()})
	round(card)
	make("UIPadding", card, {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12)})
	list(card)
	local heading = text(card, title, 28)
	heading.Font = Enum.Font.GothamBold
	heading.TextSize = 15
	return card
end
local function scroll(parent, position, size)
	local frame = make("ScrollingFrame", parent, {Position = position, Size = size, BackgroundTransparency = 1, BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 5, ScrollBarImageColor3 = C.accent})
	list(frame)
	return frame
end
function Editor.Mount(pluginObject, widget)
	local config = Schema.Clone(Example)
	local selected, tab, query, dirty = 1, "Details", "", false
	local render, renderList, renderContent
	local root = make("Frame", widget, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BorderSizePixel = 0})
	local header = text(root, "QUESTFORGE PRO", 44)
	header.Position = UDim2.fromOffset(16, 0)
	header.Font = Enum.Font.GothamBold
	header.TextSize = 21
	local subtitle = text(root, "Visual quest systems • Server authority • Studio native", 26)
	subtitle.Position = UDim2.fromOffset(16, 38)
	subtitle.TextColor3 = C.muted
	local status = text(root, "Example loaded. Save your configuration before closing Studio.", 56)
	status.Position = UDim2.new(0, 12, 1, -60)
	status.Size = UDim2.new(1, -24, 0, 56)
	local sidebar = make("Frame", root, {Position = UDim2.fromOffset(12, 76), Size = UDim2.new(0.29, -18, 1, -144), BackgroundTransparency = 1})
	local search = field(sidebar, "Search quests", "", function(value) query = value renderList() end)
	search.Position = UDim2.fromOffset(0, 24)
	search:GetPropertyChangedSignal("Text"):Connect(function() query = search.Text renderList() end)
	local actions = make("Frame", sidebar, {Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 72), BackgroundTransparency = 1})
	list(actions, 4)
	local quests = scroll(sidebar, UDim2.fromOffset(0, 144), UDim2.new(1, 0, 1, -144))
	local contentArea = make("Frame", root, {Position = UDim2.new(0.29, 4, 0, 76), Size = UDim2.new(0.71, -16, 1, -144), BackgroundTransparency = 1})
	local tabs = make("Frame", contentArea, {Size = UDim2.new(1, 0, 0, 72), BackgroundTransparency = 1})
	make("UIGridLayout", tabs, {CellSize = UDim2.new(0.333, -5, 0, 32), CellPadding = UDim2.fromOffset(5, 5), SortOrder = Enum.SortOrder.LayoutOrder})
	local body = scroll(contentArea, UDim2.fromOffset(0, 80), UDim2.new(1, 0, 1, -80))
	local function notice(message, bad)
		status.Text = message
		status.TextColor3 = if bad then C.bad else C.good
	end
	local function protect(callback)
		local ok, value = pcall(callback)
		if ok then notice(type(value) == "string" and value or "Done.") else notice(tostring(value), true) end
	end
	local function changed() dirty = true header.Text = "QUESTFORGE PRO  •" end
	local function refresh() changed() render() end
	local function unique(prefix, entries)
		local used = {}
		for _, entry in ipairs(entries) do used[entry.id] = true end
		local i = 1
		while used[prefix .. i] do i += 1 end
		return prefix .. i
	end
	local function clear(frame)
		for _, child in ipairs(frame:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	end
	local function numeric(parent, label, value, callback)
		field(parent, label, value, function(raw)
			local number = tonumber(raw)
			if number and number == number and number >= 0 and number <= 1e9 and number % 1 == 0 then callback(number) changed()
			else notice(label .. " must be an integer from 0 to 1,000,000,000.", true) renderContent() end
		end)
	end
	local function edit(parent, label, object, key, multiline)
		field(parent, label, object[key] or "", function(value) object[key] = value changed() if key == "name" or key == "id" then renderList() end end, multiline)
	end
	renderList = function()
		clear(quests)
		local needle = query:lower()
		for index, quest in ipairs(config.quests) do
			if string.find((quest.name .. " " .. quest.id .. " " .. quest.category):lower(), needle, 1, true) then
				button(quests, quest.name .. "\n" .. quest.id, function() selected = index render() end, selected == index).Size = UDim2.new(1, -6, 0, 52)
			end
		end
	end
	local function moveButtons(parent, entries, index)
		if index > 1 then button(parent, "Move up", function() entries[index - 1], entries[index] = entries[index], entries[index - 1] refresh() end) end
		if index < #entries then button(parent, "Move down", function() entries[index + 1], entries[index] = entries[index], entries[index + 1] refresh() end) end
		button(parent, "Remove", function() table.remove(entries, index) refresh() end)
	end
	renderContent = function()
		clear(body)
		local quest = config.quests[selected]
		if tab == "Generate" then
			local card = section(body, "Configuration & generation")
			text(card, tostring(#config.quests) .. " quests in this project. Generation replaces the previous generated system.", 48)
			button(card, "Validate all quests", function()
				local errors = Schema.Validate(config)
				notice(if #errors == 0 then "All quests are valid." else table.concat(errors, " • "), #errors > 0)
			end)
			button(card, "Save configuration to plugin settings", function() protect(function()
				pluginObject:SetSetting(SETTING, HttpService:JSONEncode(config)) dirty = false header.Text = "QUESTFORGE PRO" return "Configuration saved locally."
			end) end)
			button(card, "Load saved configuration", function() protect(function()
				local saved = pluginObject:GetSetting(SETTING) assert(type(saved) == "string", "No configuration has been saved")
				local loaded = HttpService:JSONDecode(saved)
				-- Local drafts may be invalid; retain them for editing after load.
				assert(type(loaded) == "table" and loaded.version == 1 and type(loaded.quests) == "table", "Invalid saved configuration")
				config = loaded selected = 1 dirty = false header.Text = "QUESTFORGE PRO" render() return "Saved configuration loaded."
			end) end)
			button(card, "Load configuration from this place", function() protect(function() config = Generator.ReadPlace() selected = 1 refresh() return "Place configuration loaded." end) end)
			button(card, "Generate quest system into this place", function() protect(function() return Generator.Generate(config) end) end, true)
			button(card, "Load working example configuration", function() config = Schema.Clone(Example) selected = 1 refresh() notice("Example loaded. Generate the system, then create the example scene.") end)
			button(card, "Create / replace example scene", function() protect(Generator.Demo) end)
			text(card, "Play testing persistent data requires a published place and Studio API access. Test in a separate test experience. Generation cancels active quests on the next load; completion history and balances remain.", 100)
			return
		end
		if not quest then text(body, "Create a quest to begin.", 50) return end
		if tab == "Details" then
			local card = section(body, "Quest identity")
			edit(card, "Quest name", quest, "name")
			edit(card, "Unique quest ID", quest, "id")
			edit(card, "Description", quest, "description", true)
			selectField(card, "Difficulty (click to cycle)", quest.difficulty, Schema.Difficulties, function(value) quest.difficulty = value refresh() end)
			edit(card, "Category", quest, "category")
			toggle(card, "Repeatable quest", quest.repeatable, function(value) quest.repeatable = value refresh() end)
			numeric(card, "Repeat cooldown in seconds", quest.cooldownSeconds, function(value) quest.cooldownSeconds = value end)
			button(card, "Duplicate quest", function()
				local copy = Schema.Clone(quest) copy.id = unique("quest_", config.quests) copy.name ..= " (copy)"
				table.insert(config.quests, copy) selected = #config.quests refresh()
			end)
			button(card, "Delete this quest", function() table.remove(config.quests, selected) selected = math.min(selected, #config.quests) refresh() end)
		elseif tab == "Objectives" then
			local intro = section(body, "Stages & completion")
			text(intro, "All = every required objective. Any = one required objective. Optional objectives never block a stage. Sequential objectives wait for earlier required objectives in the same stage.", 86)
			for index, stage in ipairs(quest.stages) do
				local card = section(body, "Stage " .. index)
				edit(card, "Stage name", stage, "name")
				selectField(card, "Completion", stage.completion, {"All", "Any"}, function(value) stage.completion = value refresh() end)
				button(card, "Remove stage", function()
					if #quest.stages == 1 then notice("Keep at least one stage.", true) return end
					table.remove(quest.stages, index)
					for _, objective in ipairs(quest.objectives) do
						if objective.stage == index then objective.stage = math.min(index, #quest.stages)
						elseif objective.stage > index then objective.stage -= 1 end
					end
					refresh()
				end)
			end
			button(body, "+ Add stage", function() table.insert(quest.stages, {name = "New stage", completion = "All"}) refresh() end)
			for index, objective in ipairs(quest.objectives) do
				local card = section(body, "Objective " .. index .. " • " .. objective.type)
				edit(card, "Objective ID", objective, "id")
				edit(card, "Display label", objective, "label")
				selectField(card, "Type", objective.type, Schema.ObjectiveTypes, function(value) objective.type = value refresh() end)
				edit(card, "Target ID (quest ID for CompleteQuest)", objective, "target")
				if objective.type == "Deliver" then edit(card, "Item ID to consume", objective, "item") end
				numeric(card, "Required count", objective.count, function(value) objective.count = value end)
				numeric(card, "Stage number", objective.stage, function(value) objective.stage = value end)
				toggle(card, "Optional", objective.optional, function(value) objective.optional = value refresh() end)
				toggle(card, "Sequential", objective.sequential, function(value) objective.sequential = value refresh() end)
				moveButtons(card, quest.objectives, index)
			end
			button(body, "+ Add objective", function()
				local objective = Schema.NewQuest("template").objectives[1] objective.id = unique("objective_", quest.objectives)
				table.insert(quest.objectives, objective) refresh()
			end, true)
		elseif tab == "Rewards" then
			for index, reward in ipairs(quest.rewards) do
				local card = section(body, "Reward " .. index)
				selectField(card, "Reward type", reward.type, Schema.RewardTypes, function(value)
					reward.type = value reward.amount = reward.amount or 1 reward.key = reward.key or "unlock" reward.value = if reward.value == nil then true else reward.value reward.item = reward.item or "item_id" refresh()
				end)
				if reward.type == "Metadata" then
					edit(card, "Metadata key", reward, "key")
					field(card, "Metadata value (JSON)", HttpService:JSONEncode(reward.value), function(raw)
						local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
						if ok and decoded ~= nil then reward.value = decoded changed() else notice("Enter a valid, non-null JSON value.", true) end
					end, true)
				else
					numeric(card, "Amount", reward.amount, function(value) reward.amount = value end)
					if reward.type == "Item" then edit(card, "Item ID", reward, "item") end
				end
				moveButtons(card, quest.rewards, index)
			end
			button(body, "+ Add reward", function() table.insert(quest.rewards, {type = "XP", amount = 100}) refresh() end, true)
		elseif tab == "Requirements" then
			local card = section(body, "Prerequisites & requirements")
			field(card, "Prerequisite quest IDs (comma separated)", table.concat(quest.prerequisites, ", "), function(raw)
				quest.prerequisites = {}
				for id in raw:gmatch("[^,]+") do table.insert(quest.prerequisites, id:match("^%s*(.-)%s*$")) end changed()
			end)
			numeric(card, "Minimum player level", quest.requirements.minLevel, function(value) quest.requirements.minLevel = value end)
			text(card, "Required items are checked on acceptance and are not consumed.", 46)
			for index, item in ipairs(quest.requirements.items) do
				local itemCard = section(body, "Required item " .. index)
				edit(itemCard, "Item ID", item, "id")
				numeric(itemCard, "Amount", item.amount, function(value) item.amount = value end)
				button(itemCard, "Remove item requirement", function() table.remove(quest.requirements.items, index) refresh() end)
			end
			button(body, "+ Add required item", function() table.insert(quest.requirements.items, {id = "item_id", amount = 1}) refresh() end)
		elseif tab == "Preview" then
			local card = section(body, quest.name)
			text(card, quest.id .. " • " .. quest.difficulty .. " • " .. quest.category, 42)
			local description = text(card, quest.description, 0) description.AutomaticSize = Enum.AutomaticSize.Y
			text(card, if quest.repeatable then "Repeatable • cooldown " .. quest.cooldownSeconds .. "s" else "One-time quest", 32)
			text(card, "Prerequisites: " .. table.concat(quest.prerequisites, ", "), 48)
			for index, stage in ipairs(quest.stages) do
				local stageCard = section(body, "Stage " .. index .. ": " .. stage.name .. " (" .. stage.completion .. ")")
				for _, objective in ipairs(quest.objectives) do
					if objective.stage == index then text(stageCard, objective.label .. " • " .. objective.type .. " " .. objective.target .. " ×" .. objective.count .. (if objective.optional then " • Optional" else "") .. (if objective.sequential then " • Sequential" else ""), 62) end
				end
			end
			local rewards = section(body, "Rewards")
			for _, reward in ipairs(quest.rewards) do text(rewards, if reward.type == "Metadata" then reward.key .. " = " .. HttpService:JSONEncode(reward.value) else tostring(reward.amount) .. " " .. (reward.item or reward.type), 48) end
			local errors = Schema.Validate(config)
			local validation = section(body, "Project validation")
			for _, err in ipairs(errors) do text(validation, err, 60).TextColor3 = C.bad end
			if #errors == 0 then text(validation, "All quests are valid.") end
		end
	end
	render = function()
		clear(tabs)
		for _, name in ipairs({"Details", "Objectives", "Rewards", "Requirements", "Preview", "Generate"}) do
			button(tabs, name, function() tab = name body.CanvasPosition = Vector2.zero render() end, tab == name)
		end
		renderList() renderContent()
	end
	button(actions, "+ New quest", function() table.insert(config.quests, Schema.NewQuest(unique("quest_", config.quests))) selected = #config.quests tab = "Details" refresh() end, true)
	button(actions, "Save configuration", function() protect(function() pluginObject:SetSetting(SETTING, HttpService:JSONEncode(config)) dirty = false header.Text = "QUESTFORGE PRO" return "Saved locally. Load from the Generate tab." end) end)
	-- Restore the last draft without requiring a place or executing user scripts.
	local ok, saved = pcall(function() return pluginObject:GetSetting(SETTING) end)
	if ok and type(saved) == "string" then
		local decoded, value = pcall(HttpService.JSONDecode, HttpService, saved)
		if decoded and type(value) == "table" and value.version == 1 and type(value.quests) == "table" then config = value notice("Saved configuration restored.") end
	end
	render()
	return function()
		if dirty then pcall(function() pluginObject:SetSetting(SETTING, HttpService:JSONEncode(config)) end) end
		root:Destroy()
	end
end
return Editor
