-- Pure server-side quest state machine. No client-supplied progress enters this module.
local Engine = {}
local MAX_BALANCE = 1000000000000
function Engine.NewState()
	return {version = 1, level = 1, xp = 0, currency = 0, items = {}, metadata = {}, quests = {}}
end
local function progress(entry, objective) return entry.progress[objective.id] or 0 end
local function boundedAdd(old, amount) return math.min(MAX_BALANCE, (old or 0) + amount) end
local function stageDone(quest, entry)
	local all, any = true, false
	for _, objective in ipairs(quest.objectives) do
		if objective.stage == entry.stage and not objective.optional then
			local done = progress(entry, objective) >= objective.count
			all = all and done
			any = any or done
		end
	end
	return if quest.stages[entry.stage].completion == "Any" then any else all
end
local function eligible(quest, entry, objective)
	if objective.stage ~= entry.stage or progress(entry, objective) >= objective.count then return false end
	if objective.sequential then
		for _, previous in ipairs(quest.objectives) do
			if previous == objective then break end
			if previous.stage == entry.stage and not previous.optional and progress(entry, previous) < previous.count then return false end
		end
	end
	return true
end
function Engine.CanAccept(state, quest, now)
	local existing = state.quests[quest.id]
	if existing and existing.status == "Active" then return false, "Quest is already active" end
	if existing and (existing.completions or 0) > 0 then
		if not quest.repeatable then return false, "Quest is already completed" end
		if now < (existing.completedAt or 0) + quest.cooldownSeconds then return false, "Repeat cooldown is active" end
	end
	if state.level < quest.requirements.minLevel then return false, "Level requirement not met" end
	for _, item in ipairs(quest.requirements.items) do
		if (state.items[item.id] or 0) < item.amount then return false, "Required item missing: " .. item.id end
	end
	for _, id in ipairs(quest.prerequisites) do
		if not state.quests[id] or (state.quests[id].completions or 0) == 0 then return false, "Prerequisite missing: " .. id end
	end
	return true
end
local function settle(state, config, now)
	-- Completion can unlock CompleteQuest objectives in other active quests.
	local completed = {}
	local limit = 1
	for _, quest in ipairs(config.quests) do limit += #quest.stages + 1 end
	for _ = 1, limit do
		local advanced = false
		for _, quest in ipairs(config.quests) do
			local entry = state.quests[quest.id]
			if not entry or entry.status ~= "Active" then continue end
			for _, objective in ipairs(quest.objectives) do
				if objective.type == "CompleteQuest" and eligible(quest, entry, objective) then
					local other = state.quests[objective.target]
					if other and (other.completions or 0) > 0 then entry.progress[objective.id] = 1 end
				end
			end
			while entry.stage <= #quest.stages and stageDone(quest, entry) do
				entry.stage += 1
				advanced = true
				if entry.stage > #quest.stages then
					entry.status = "Completed"
					entry.completions = (entry.completions or 0) + 1
					entry.completedAt = now
					for _, reward in ipairs(quest.rewards) do
						if reward.type == "XP" then state.xp = boundedAdd(state.xp, reward.amount)
						elseif reward.type == "Currency" then state.currency = boundedAdd(state.currency, reward.amount)
						elseif reward.type == "Item" then state.items[reward.item] = boundedAdd(state.items[reward.item], reward.amount)
						elseif reward.type == "Metadata" then state.metadata[reward.key] = reward.value end
					end
					table.insert(completed, quest.id)
					break
				end
			end
		end
		if not advanced then break end
	end
	return completed
end
function Engine.Accept(state, config, id, now)
	for _, quest in ipairs(config.quests) do
		if quest.id == id then
			local allowed, reason = Engine.CanAccept(state, quest, now)
			if not allowed then return false, reason end
			local previous = state.quests[id]
			state.quests[id] = {status = "Active", stage = 1, progress = {},
				completions = if previous then previous.completions else 0, completedAt = if previous then previous.completedAt else nil}
			settle(state, config, now)
			return true, "Quest accepted"
		end
	end
	return false, "Unknown quest"
end
function Engine.Abandon(state, id)
	local entry = state.quests[id]
	if not entry or entry.status ~= "Active" then return false, "Quest is not active" end
	entry.status = "Abandoned"
	entry.progress = {}
	return true, "Quest abandoned"
end
function Engine.Report(state, config, kind, target, amount, item, now)
	if kind == "Collect" then state.items[target] = boundedAdd(state.items[target], amount) end
	for _, quest in ipairs(config.quests) do
		local entry = state.quests[quest.id]
		if not entry or entry.status ~= "Active" then continue end
		-- Snapshot eligibility so one action cannot also satisfy its sequential successor.
		local candidates = {}
		for _, objective in ipairs(quest.objectives) do
			if objective.type == kind and objective.target == target and eligible(quest, entry, objective)
				and (kind ~= "Deliver" or objective.item == item) then table.insert(candidates, objective) end
		end
		for _, objective in ipairs(candidates) do
			local delta = math.min(amount, objective.count - progress(entry, objective))
			if kind == "Deliver" then
				delta = math.min(delta, state.items[item] or 0)
				state.items[item] = (state.items[item] or 0) - delta
			end
			entry.progress[objective.id] = progress(entry, objective) + delta
		end
	end
	return settle(state, config, now)
end
return Engine
