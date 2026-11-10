-- Executed with the actual server source injected by tools/check.py.
local passed = 0
local function eq(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			table.insert(callbacks, callback)
			return {Disconnect = function() table.remove(callbacks, table.find(callbacks, callback)) end}
		end,
		Fire = function(_, ...) for _, callback in ipairs(callbacks) do callback(...) end end,
	}
end
local function harness()
	local player = {UserId = 42}
	local players = {PlayerAdded = signal(), PlayerRemoving = signal()}
	player.Parent = players
	function players:GetPlayers() return {player} end
	local config = Schema.Clone(Example)
	local root = {Config = "Config", Request = {OnServerEvent = signal()}, Snapshot = {sent = {}}}
	function root:GetAttribute() return "revision-1" end
	function root.Snapshot:FireClient(who, state, message)
		table.insert(self.sent, {who = who, state = Schema.Clone(state), message = message})
	end
	local store = {records = {}, fail = false, failAfterCommit = false, updates = 0}
	function store:UpdateAsync(key, callback)
		self.updates += 1
		if self.fail then error("synthetic storage failure") end
		if self.replayCallback then callback(Schema.Clone(self.records[key])) end
		local record = callback(Schema.Clone(self.records[key]))
		if record == nil then return nil end
		self.records[key] = Schema.Clone(record)
		if self.failAfterCommit then self.failAfterCommit = false error("synthetic lost response") end
		return Schema.Clone(record)
	end
	local deferred, guid = {}, 0
	local fakeTask = {}
	function fakeTask.spawn(callback, ...)
		local thread = coroutine.create(callback)
		local ok, delay = coroutine.resume(thread, ...)
		assert(ok, delay)
		if coroutine.status(thread) ~= "dead" then table.insert(deferred, {thread = thread, delay = delay or 0}) end
	end
	function fakeTask.wait(delay) return coroutine.yield(delay or 0) end
	local function flush()
		for _ = 1, 10 do
			local remaining, ran = {}, false
			for _, entry in ipairs(deferred) do
				if entry.delay < 60 then
					ran = true
					local ok, delay = coroutine.resume(entry.thread)
					assert(ok, delay)
					if coroutine.status(entry.thread) ~= "dead" then table.insert(remaining, {thread = entry.thread, delay = delay or 0}) end
				else table.insert(remaining, entry) end
			end
			deferred = remaining
			if not ran then return end
		end
	end
	local collection = {}
	function collection:GetTagged() return {} end
	function collection:GetInstanceAddedSignal() return signal() end
	function collection:GetInstanceRemovedSignal() return signal() end
	local services = {
		Players = players, CollectionService = collection,
		RunService = {IsServer = function() return true end},
		HttpService = {GenerateGUID = function() guid += 1 return "guid-" .. guid end},
		DataStoreService = {GetDataStore = function() return store end},
		ReplicatedStorage = {WaitForChild = function() return root end},
	}
	local gameMock = {JobId = "test-server"}
	function gameMock:GetService(name) assert(services[name], name) return services[name] end
	function gameMock:BindToClose(callback) self.close = callback end
	local serviceChunk = assert(loadstring(SERVICE_SOURCE, "QuestService"))
	local environment = setmetatable({game = gameMock, task = fakeTask, script = {Parent = {Engine = "Engine", Schema = "Schema"}},
		Instance = {new = function() local event = signal() event.Event = event return event end},
		warn = function() end,
		require = function(module)
			if module == "Engine" then return Engine elseif module == "Schema" then return Schema elseif module == "Config" then return config end
			error("Unexpected require " .. tostring(module))
		end}, {__index = getfenv()})
	setfenv(serviceChunk, environment)
	local service = serviceChunk()
	return {service = service, player = player, root = root, store = store, players = players, flush = flush, game = gameMock, config = config}
end
local function test(name, callback) callback() passed += 1 print("PASS " .. name) end
local function request(h, action, id)
	h.root.Request.OnServerEvent:Fire(h.player, action, id)
end

test("server ignores forged progress and reward requests", function()
	local h = harness() h.service.Start()
	for _, action in ipairs({"Collect", "Deliver", "GrantReward", "Complete", "SetLevel"}) do request(h, action, "crystal_errand") end
	local state = h.service.GetState(h.player)
	eq(state.xp, 0) eq(next(state.items), nil) eq(next(state.quests), nil)
end)
test("server persists the example and grants only canonical rewards", function()
	local h = harness() h.service.Start() request(h, "Accept", "crystal_errand")
	assert(h.service.Report(h.player, "Talk", "rowan", 1))
	assert(h.service.Report(h.player, "Collect", "crystal", 3))
	assert(h.service.Report(h.player, "Deliver", "rowan", 3, "crystal"))
	local state = h.store.records.p_42.state
	eq(state.xp, 100) eq(state.currency, 25) eq(state.items.crystal, 0) eq(state.items.village_token, 1)
	eq(state.quests.crystal_errand.completions, 1)
end)
test("a committed write with a lost response is not applied twice", function()
	local h = harness() h.service.Start()
	h.store.failAfterCommit = true
	assert(h.service.Report(h.player, "Collect", "crystal", 2))
	h.flush()
	eq(h.store.records.p_42.state.items.crystal, 2)
	eq(h.service.GetState(h.player).items.crystal, 2)
end)
test("failed writes never publish progress or grant a reward", function()
	local h = harness() h.service.Start() request(h, "Accept", "crystal_errand")
	h.store.fail = true
	assert(h.service.Report(h.player, "Collect", "crystal", 3)) h.flush()
	eq(h.service.GetState(h.player).items.crystal, nil)
	eq(h.store.records.p_42.state.items.crystal, nil)
	eq(h.service.Report(h.player, "Collect", "crystal", 1), false)
end)
test("an active foreign lease prevents profile acquisition", function()
	local h = harness()
	h.store.records.p_42 = {owner = "other-server", expires = os.time() + 100, state = Engine.NewState()}
	h.service.Start()
	eq(h.service.GetState(h.player), nil)
	eq(h.store.records.p_42.owner, "other-server")
end)
test("a stolen lease prevents all subsequent writes", function()
	local h = harness() h.service.Start()
	h.store.records.p_42.owner = "replacement"
	assert(h.service.Report(h.player, "Collect", "crystal", 1))
	eq(h.service.GetState(h.player).items.crystal, nil)
	eq(h.store.records.p_42.state.items.crystal, nil)
end)
test("regeneration cancels active quests and preserves balances and completion history", function()
	local h = harness()
	local state = Engine.NewState() state.xp = 99
	state.quests.crystal_errand = {status = "Active", stage = 3, progress = {gather = 3}, completions = 2, completedAt = 1}
	h.store.records.p_42 = {owner = "", expires = 0, state = state, configRevision = "old-revision"}
	h.service.Start()
	state = h.service.GetState(h.player)
	eq(state.xp, 99) eq(state.quests.crystal_errand.completions, 2) eq(state.quests.crystal_errand.status, "Abandoned")
end)
test("level changes and invalid trusted events respect boundaries", function()
	local h = harness() h.service.Start()
	eq(h.service.SetLevel(h.player, 0), false)
	eq(h.service.SetLevel(h.player, 0/0), false)
	assert(h.service.SetLevel(h.player, 5)) eq(h.service.GetState(h.player).level, 5)
	for _, amount in ipairs({0, -1, 0/0, math.huge, 1.5}) do eq(h.service.Report(h.player, "Collect", "x", amount), false) end
	eq(h.service.Report(h.player, "CompleteQuest", "x", 1), false)
	eq(h.service.Report(h.player, "Deliver", "x", 1, nil), false)
end)
test("snapshots are independent copies and leaving releases the lease", function()
	local h = harness() h.service.Start()
	local state = h.service.GetState(h.player) state.xp = 999
	eq(h.service.GetState(h.player).xp, 0)
	h.players.PlayerRemoving:Fire(h.player)
	eq(h.store.records.p_42.owner, "") eq(h.store.records.p_42.expires, 0)
	eq(h.service.GetState(h.player), nil)
end)
test("DataStore callback replay does not duplicate a reward", function()
	local h = harness() h.store.replayCallback = true h.service.Start() request(h, "Accept", "crystal_errand")
	h.service.Report(h.player, "Talk", "rowan", 1)
	h.service.Report(h.player, "Collect", "crystal", 3)
	h.service.Report(h.player, "Deliver", "rowan", 3, "crystal")
	eq(h.store.records.p_42.state.xp, 100) eq(h.store.records.p_42.state.items.village_token, 1)
end)
test("a lost acquisition response recovers with the same session token", function()
	local h = harness() h.store.failAfterCommit = true
	h.service.Start()
	h.flush()
	assert(h.service.GetState(h.player))
end)
print("Passed " .. passed .. " server integration scenarios")
