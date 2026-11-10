-- QuestForge Pro: shared configuration contract, independent of Roblox services.
local Schema = {}
Schema.ObjectiveTypes = {"Kill", "Collect", "Talk", "Reach", "Interact", "Deliver", "CompleteQuest"}
Schema.RewardTypes = {"XP", "Currency", "Item", "Metadata"}
Schema.Difficulties = {"Easy", "Normal", "Hard", "Epic"}

function Schema.Clone(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = Schema.Clone(child) end
	return result
end

local function contains(list, value)
	return table.find(list, value) ~= nil
end
local function integer(value, minimum, maximum)
	return type(value) == "number" and value == value and value >= minimum
		and value <= (maximum or 1000000000) and value % 1 == 0
end
local function identifier(value)
	return type(value) == "string" and #value > 0 and #value <= 100 and value:match("^[%w_%-%.]+$") ~= nil
end
local function array(value)
	if type(value) ~= "table" then return false end
	local count = 0
	for key in pairs(value) do
		if not integer(key, 1) then return false end
		count += 1
	end
	return count == #value
end
local function jsonSafe(value, depth, seen)
	local kind = type(value)
	if kind == "nil" or kind == "boolean" then return true end
	if kind == "number" then return value == value and math.abs(value) <= 1e15 end
	if kind == "string" then return #value <= 10000 end
	if kind ~= "table" or depth > 12 or seen[value] then return false end
	seen[value] = true
	local mode = nil
	for key, child in pairs(value) do
		local keyMode = type(key)
		if keyMode ~= "string" and not integer(key, 1) then return false end
		if mode and mode ~= keyMode then return false end
		mode = keyMode
		if not jsonSafe(child, depth + 1, seen) then return false end
	end
	seen[value] = nil
	return mode ~= "number" or array(value)
end

function Schema.Validate(config)
	local errors, ids, dependencies = {}, {}, {}
	local function check(ok, message) if not ok then table.insert(errors, message) end return ok end
	if not check(type(config) == "table", "Configuration must be a table") then return errors end
	check(config.version == 1, "Configuration version must be 1")
	if not check(array(config.quests), "quests must be an array") then return errors end
	for index, quest in ipairs(config.quests) do
		local prefix = "Quest " .. index .. ": "
		if not check(type(quest) == "table", prefix .. "must be a table") then continue end
		local validId = check(identifier(quest.id), prefix .. "invalid ID (use letters, numbers, _, -, .)")
		if validId then
			check(not ids[quest.id], prefix .. "duplicate ID " .. quest.id)
			ids[quest.id] = quest
			dependencies[quest.id] = {}
		end
		check(type(quest.name) == "string" and #quest.name > 0 and #quest.name <= 200, prefix .. "name is required (max 200 characters)")
		check(type(quest.description) == "string" and #quest.description <= 10000, prefix .. "invalid description")
		check(contains(Schema.Difficulties, quest.difficulty), prefix .. "invalid difficulty")
		check(type(quest.category) == "string" and #quest.category <= 100, prefix .. "invalid category")
		check(type(quest.repeatable) == "boolean", prefix .. "repeatable must be boolean")
		check(integer(quest.cooldownSeconds, 0), prefix .. "invalid repeat cooldown")
		if check(array(quest.prerequisites), prefix .. "prerequisites must be an array") then
			local seen = {}
			for _, id in ipairs(quest.prerequisites) do
				check(identifier(id), prefix .. "invalid prerequisite ID")
				check(not seen[id], prefix .. "duplicate prerequisite")
				seen[id] = true
			end
		end
		local req = quest.requirements
		if check(type(req) == "table", prefix .. "requirements must be a table") then
			check(integer(req.minLevel, 1), prefix .. "minimum level must be positive")
			if check(array(req.items), prefix .. "required items must be an array") then
				for _, item in ipairs(req.items) do
					check(type(item) == "table" and identifier(item.id) and integer(item.amount, 1), prefix .. "invalid required item")
				end
			end
		end
		local stagesValid = check(array(quest.stages) and #quest.stages > 0, prefix .. "at least one stage is required")
		if stagesValid then
			for _, stage in ipairs(quest.stages) do
				check(type(stage) == "table" and type(stage.name) == "string" and #stage.name > 0
					and contains({"All", "Any"}, stage.completion), prefix .. "invalid stage name or completion condition")
			end
		end
		if check(array(quest.objectives) and #quest.objectives > 0, prefix .. "at least one objective is required") then
			local objectiveIds, required = {}, {}
			for oi, objective in ipairs(quest.objectives) do
				local op = prefix .. "objective " .. oi .. ": "
				if not check(type(objective) == "table", op .. "must be a table") then continue end
				check(identifier(objective.id) and not objectiveIds[objective.id], op .. "invalid or duplicate objective ID")
				if identifier(objective.id) then objectiveIds[objective.id] = true end
				check(contains(Schema.ObjectiveTypes, objective.type), op .. "unknown type")
				check(identifier(objective.target), op .. "target ID is required")
				check(type(objective.label) == "string" and #objective.label > 0 and #objective.label <= 300, op .. "invalid label")
				check(integer(objective.count, 1), op .. "count must be a positive integer")
				local stageOk = stagesValid and integer(objective.stage, 1, #quest.stages)
				check(stageOk, op .. "stage does not exist")
				check(type(objective.optional) == "boolean" and type(objective.sequential) == "boolean", op .. "optional and sequential must be boolean")
				if stageOk and objective.optional == false then required[objective.stage] = true end
				if objective.type == "Deliver" then check(identifier(objective.item), op .. "delivery item ID is required") end
				if objective.type == "CompleteQuest" then check(objective.count == 1, op .. "CompleteQuest count must be 1") end
			end
			if stagesValid then
				for si in ipairs(quest.stages) do check(required[si], prefix .. "stage " .. si .. " needs a required objective") end
			end
		end
		if check(array(quest.rewards), prefix .. "rewards must be an array") then
			for _, reward in ipairs(quest.rewards) do
				if not check(type(reward) == "table", prefix .. "reward must be a table") then continue end
				check(contains(Schema.RewardTypes, reward.type), prefix .. "unknown reward type")
				if reward.type == "Metadata" then
					check(identifier(reward.key) and reward.value ~= nil and jsonSafe(reward.value, 0, {}), prefix .. "invalid metadata key or JSON value")
				else
					check(integer(reward.amount, 1), prefix .. "reward amount must be a positive integer")
					if reward.type == "Item" then check(identifier(reward.item), prefix .. "reward item ID is required") end
				end
			end
		end
	end
	-- Only inspect dependency graphs after structural validation.
	if #errors > 0 then return errors end
	for _, quest in ipairs(config.quests) do
		for _, id in ipairs(quest.prerequisites) do table.insert(dependencies[quest.id], id) end
		for _, objective in ipairs(quest.objectives) do
			if objective.type == "CompleteQuest" then table.insert(dependencies[quest.id], objective.target) end
		end
		for _, id in ipairs(dependencies[quest.id]) do check(ids[id] ~= nil, quest.id .. ": missing referenced quest " .. id) end
	end
	local visiting, visited = {}, {}
	local function visit(id)
		if visiting[id] then check(false, "Quest dependency cycle includes " .. id) return end
		if visited[id] then return end
		visiting[id] = true
		for _, dependency in ipairs(dependencies[id] or {}) do if ids[dependency] then visit(dependency) end end
		visiting[id] = nil
		visited[id] = true
	end
	for id in pairs(ids) do visit(id) end
	return errors
end

function Schema.NewQuest(id)
	return {id = id, name = "New quest", description = "Describe your adventure.", difficulty = "Normal", category = "Main",
		repeatable = false, cooldownSeconds = 0, prerequisites = {}, requirements = {minLevel = 1, items = {}},
		stages = {{name = "First steps", completion = "All"}},
		objectives = {{id = "objective_1", label = "Talk to the guide", type = "Talk", target = "guide", count = 1, stage = 1, optional = false, sequential = false}},
		rewards = {{type = "XP", amount = 100}}}
end
return Schema
