-- Server-only API and durable state coordinator.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Engine = require(script.Parent.Engine)
local Schema = require(script.Parent.Schema)
local root = game:GetService("ReplicatedStorage"):WaitForChild("QuestForgePro")
local config = require(root.Config)
local request = root.Request
local snapshot = root.Snapshot
local store = DataStoreService:GetDataStore("QuestForgePro_v1")
local owner = game.JobId .. ":" .. HttpService:GenerateGUID(false)
local LEASE_SECONDS = 180
local profiles, loading, connections, bound, owners = {}, {}, {}, {}, {}
local Service = {}
local started, closing = false, false
local changed = Instance.new("BindableEvent")
Service.Changed = changed.Event

local function send(player, profile, message)
	if player.Parent == Players then snapshot:FireClient(player, profile.state, message or "") end
end
local function lockValid(record, token)
	return record and record.owner == token and record.expires > os.time()
end
local function persist(player, transform, release)
	local result, message
	local operationId = HttpService:GenerateGUID(false)
	local token = owners[player]
	for attempt = 1, 3 do
		local ok, value = pcall(function()
			return store:UpdateAsync("p_" .. player.UserId, function(record)
				if not lockValid(record, token) then return nil end
				local state = Schema.Clone(record.state)
				if record.lastOperation == operationId then
					message = record.lastMessage
				else
					message = transform(state)
				end
				return {version = 1, owner = if release then "" else token,
					expires = if release then 0 else os.time() + LEASE_SECONDS,
					configRevision = root:GetAttribute("Revision"), state = state,
					lastOperation = operationId, lastMessage = message}
			end)
		end)
		if ok then result = value break end
		if attempt < 3 then task.wait(attempt) end
	end
	if not result or (not release and result.owner ~= token) then return nil, "Data could not be saved; rejoin to reconnect" end
	return result.state, message
end
local function enqueue(player, operation)
	local profile = profiles[player]
	if closing or not profile or profile.leaving or profile.failed then return false, "Player data is not ready" end
	if #profile.queue >= 60 then return false, "Quest queue is busy" end
	table.insert(profile.queue, operation)
	if profile.busy then return true end
	profile.busy = true
	task.spawn(function()
		while #profile.queue > 0 and profiles[player] == profile and not profile.failed do
			local op = table.remove(profile.queue, 1)
			local state, message = persist(player, op, false)
			if not state then
				profile.failed = true
				profile.queue = {}
				send(player, profile, message)
				warn("QuestForge Pro: saving stopped for user " .. player.UserId)
				break
			end
			profile.state = state
			send(player, profile, message)
			changed:Fire(player, Schema.Clone(state))
		end
		profile.busy = false
	end)
	return true
end
local function load(player)
	if loading[player] or profiles[player] then return end
	loading[player] = true
	local token = owner .. ":" .. HttpService:GenerateGUID(false)
	owners[player] = token
	local ok, record
	for attempt = 1, 3 do
		ok, record = pcall(function()
			return store:UpdateAsync("p_" .. player.UserId, function(old)
				if old and old.owner ~= token and old.expires > os.time() then return nil end
				local state = if old then old.state else Engine.NewState()
				assert(type(state) == "table" and state.version == 1 and type(state.quests) == "table", "Unsupported player data")
				if old and old.configRevision ~= root:GetAttribute("Revision") then
					for _, entry in pairs(state.quests) do
						if entry.status == "Active" then entry.status = "Abandoned" entry.progress = {} entry.stage = 1 end
					end
				end
				return {version = 1, owner = token, expires = os.time() + LEASE_SECONDS,
					configRevision = root:GetAttribute("Revision"), state = state}
			end)
		end)
		if ok then break end
		if attempt < 3 then task.wait(attempt) end
	end
	loading[player] = nil
	if not ok or not record or record.owner ~= token then
		owners[player] = nil
		if player.Parent == Players then snapshot:FireClient(player, nil, "Quest data unavailable or in use. Rejoin to retry.") end
		warn("QuestForge Pro: profile load failed for user " .. player.UserId)
		return
	end
	local profile = {state = record.state, queue = {}, busy = false, failed = false, lastRequest = -100, lastRefresh = -100}
	profiles[player] = profile
	if player.Parent ~= Players or closing then
		profile.leaving = true
		persist(player, function() end, true)
		profiles[player] = nil
		owners[player] = nil
		return
	end
	send(player, profile)
end
local function unload(player)
	local profile = profiles[player]
	if not profile then return end
	profile.leaving = true
	local deadline = os.clock() + 20
	while profile.busy and os.clock() < deadline do task.wait(0.1) end
	-- A busy operation keeps its lease; never race release against a write.
	if not profile.busy then persist(player, function() end, true) end
	profiles[player] = nil
	owners[player] = nil
end

-- Authored dialogue can deliberately accept or complete quests on the server.
function Service.DialogueQuest(player, action, id)
 if type(id)~="string" or #id>100 or (action~="StartQuest" and action~="CompleteQuest") then return false,"Invalid quest action" end
 return enqueue(player,function(state)
  local _,message
  if action=="StartQuest" then _,message=Engine.Accept(state,config,id,os.time())
  else _,message=Engine.Complete(state,config,id,os.time()) end
  return message
 end)
end
function Service.GetState(player)
	local profile = profiles[player]
	return if profile then Schema.Clone(profile.state) else nil
end
function Service.SetLevel(player, level)
	if type(level) ~= "number" or level ~= level or level % 1 ~= 0 or level < 1 or level > 1e9 then return false, "Invalid level" end
	return enqueue(player, function(state) state.level = level return "Level updated" end)
end
function Service.Report(player, kind, target, amount, item)
	if not table.find({"Kill", "Collect", "Talk", "Reach", "Interact", "Deliver"}, kind)
		or type(target) ~= "string" or #target == 0 or #target > 100
		or type(amount) ~= "number" or amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > 1e9
		or (kind == "Deliver" and (type(item) ~= "string" or #item == 0 or #item > 100)) then return false, "Invalid server event" end
	return enqueue(player, function(state)
		local completed = Engine.Report(state, config, kind, target, amount, item, os.time())
		return if #completed > 0 then "Completed: " .. table.concat(completed, ", ") else "Progress saved"
	end)
end
local function nearby(player, part, distance)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid and humanoid.Health > 0 and hrp and (hrp.Position - part.Position).Magnitude <= distance
end
local function bindObject(object)
	if bound[object] then return end
	if object:IsA("Humanoid") then
		bound[object] = object.Died:Connect(function()
			local creator = object:FindFirstChild("creator")
			local player = creator and creator:IsA("ObjectValue") and creator.Value
			if player and player:IsA("Player") and player.Parent == Players then
				Service.Report(player, "Kill", object:GetAttribute("QuestTarget") or "enemy", 1)
			end
		end)
		return
	end
	if not object:IsA("BasePart") then return end
	local lastUse = {}
	if object:GetAttribute("QuestType") == "Reach" then
		bound[object] = object.Touched:Connect(function(hit)
			if not CollectionService:HasTag(object, "QuestForgeTarget") then return end
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			local radius = object:GetAttribute("QuestRadius") or 10
			if not player or type(radius) ~= "number" or not nearby(player, object, math.clamp(radius, 1, 100)) then return end
			local now = os.clock()
			if now - (lastUse[player.UserId] or -100) < 1 then return end
			lastUse[player.UserId] = now
			Service.Report(player, "Reach", object:GetAttribute("QuestTarget"), 1)
		end)
		return
	end
	local prompt = object:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end
	bound[object] = prompt.Triggered:Connect(function(player)
		if not CollectionService:HasTag(object, "QuestForgeTarget") then return end
		if not nearby(player, object, math.min(prompt.MaxActivationDistance + 3, 20)) then return end
		local now = os.clock()
		if now - (lastUse[player.UserId] or -100) < 1 then return end
		lastUse[player.UserId] = now
		local kind, target = object:GetAttribute("QuestType"), object:GetAttribute("QuestTarget")
		if kind == "Reach" then
			local radius = object:GetAttribute("QuestRadius") or 10
			if type(radius) ~= "number" or not nearby(player, object, math.clamp(radius, 1, 100)) then return end
		end
		Service.Report(player, kind, target, object:GetAttribute("QuestAmount") or 1, object:GetAttribute("QuestItem"))
	end)
end
function Service.Start()
	if started then return end
	assert(RunService:IsServer(), "QuestService is server only")
	local errors = Schema.Validate(config)
	assert(#errors == 0, table.concat(errors, "\n"))
	started = true
	table.insert(connections, request.OnServerEvent:Connect(function(player, action, id)
		local profile = profiles[player]
		if not profile or profile.failed or type(action) ~= "string" then return end
		local now = os.clock()
		if action == "Refresh" then
			if now - profile.lastRefresh >= 1 then profile.lastRefresh = now send(player, profile) end
			return
		end
		if now - profile.lastRequest < 0.5 then return end
		profile.lastRequest = now
		if type(id) ~= "string" or #id > 100 then return end
		if action == "Accept" then
			enqueue(player, function(state) local _, message = Engine.Accept(state, config, id, os.time()) return message end)
		elseif action == "Abandon" then
			enqueue(player, function(state) local _, message = Engine.Abandon(state, id) return message end)
		end
	end))
	table.insert(connections, Players.PlayerAdded:Connect(load))
	table.insert(connections, Players.PlayerRemoving:Connect(unload))
	table.insert(connections, CollectionService:GetInstanceAddedSignal("QuestForgeTarget"):Connect(bindObject))
	table.insert(connections, CollectionService:GetInstanceRemovedSignal("QuestForgeTarget"):Connect(function(object)
		if bound[object] then bound[object]:Disconnect() bound[object] = nil end
	end))
	for _, object in ipairs(CollectionService:GetTagged("QuestForgeTarget")) do bindObject(object) end
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(load, player) end
	task.spawn(function()
		while not closing do
			task.wait(60)
			for player, profile in pairs(profiles) do
				if not profile.failed then enqueue(player, function() end) end
			end
		end
	end)
	game:BindToClose(function()
		closing = true
		for player in pairs(profiles) do task.spawn(unload, player) end
		local deadline = os.clock() + 25
		while (next(profiles) or next(loading)) and os.clock() < deadline do task.wait(0.1) end
	end)
end
return Service
