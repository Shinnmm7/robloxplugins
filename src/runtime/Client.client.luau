local Players = game:GetService("Players")
local root = game:GetService("ReplicatedStorage"):WaitForChild("QuestForgePro")
local config = require(root:WaitForChild("Config"))
local request = root:WaitForChild("Request")
local snapshot = root:WaitForChild("Snapshot")
local gui = Instance.new("ScreenGui")
gui.Name = "QuestForgeProUI"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local function make(class, parent, properties)
	local object = Instance.new(class)
	for key, value in pairs(properties) do object[key] = value end
	object.Parent = parent
	return object
end
local colors = {bg = Color3.fromRGB(20, 23, 32), card = Color3.fromRGB(32, 37, 49), text = Color3.fromRGB(235, 239, 249), accent = Color3.fromRGB(105, 85, 235)}
local toggle = make("TextButton", gui, {Text = "Quests", Size = UDim2.fromOffset(100, 38), Position = UDim2.new(0, 16, 0.5, -19), BackgroundColor3 = colors.accent, TextColor3 = colors.text, Font = Enum.Font.GothamBold, TextSize = 15})
local panel = make("Frame", gui, {Size = UDim2.new(0.8, 0, 0.8, 0), Position = UDim2.new(0.1, 0, 0.1, 0), BackgroundColor3 = colors.bg, Visible = false})
make("UISizeConstraint", panel, {MaxSize = Vector2.new(650, 700)})
local title = make("TextLabel", panel, {Size = UDim2.new(1, -60, 0, 42), Position = UDim2.fromOffset(14, 0), Text = "QUEST JOURNAL", BackgroundTransparency = 1, TextColor3 = colors.text, Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left})
local close = make("TextButton", panel, {Size = UDim2.fromOffset(40, 34), Position = UDim2.new(1, -44, 0, 4), Text = "×", TextSize = 22, BackgroundColor3 = colors.card, TextColor3 = colors.text})
local message = make("TextLabel", panel, {Size = UDim2.new(1, -28, 0, 56), Position = UDim2.fromOffset(14, 42), Text = "Loading quest data…", TextWrapped = true, BackgroundTransparency = 1, TextColor3 = colors.text, TextSize = 13, Font = Enum.Font.Gotham})
local list = make("ScrollingFrame", panel, {Size = UDim2.new(1, -28, 1, -112), Position = UDim2.fromOffset(14, 104), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y})
make("UIListLayout", list, {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder})
local state
local function render()
	for _, child in ipairs(list:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
	if not state then return end
	title.Text = "QUESTS  •  " .. state.xp .. " XP  •  " .. state.currency .. " coins"
	for index, quest in ipairs(config.quests) do
		local entry = state.quests[quest.id]
		local active = entry and entry.status == "Active"
		local card = make("Frame", list, {Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = colors.card, LayoutOrder = index})
		make("UIPadding", card, {PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)})
		make("UIListLayout", card, {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})
		local function line(text, size)
			return make("TextLabel", card, {Text = text, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, BackgroundTransparency = 1, TextColor3 = colors.text, Font = Enum.Font.Gotham, TextSize = size or 14, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = #card:GetChildren()})
		end
		line(quest.name .. "  [" .. quest.difficulty .. " / " .. quest.category .. "]", 16)
		line(quest.description)
		line(if entry then entry.status else "Available to request")
		if active then
			line("Stage " .. entry.stage .. ": " .. quest.stages[entry.stage].name)
			for _, objective in ipairs(quest.objectives) do
				if objective.stage == entry.stage then line(objective.label .. ": " .. (entry.progress[objective.id] or 0) .. "/" .. objective.count .. (if objective.optional then " (optional)" else "")) end
			end
		end
		local rewards = {}
		for _, reward in ipairs(quest.rewards) do
			table.insert(rewards, if reward.type == "Metadata" then "Unlock: " .. reward.key else tostring(reward.amount) .. " " .. (reward.item or reward.type))
		end
		line("Rewards: " .. table.concat(rewards, ", "))
		local finished = entry and (entry.completions or 0) > 0 and not quest.repeatable
		if active or not finished then
			local button = make("TextButton", card, {Text = if active then "Abandon quest" else "Accept quest", Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = colors.accent, TextColor3 = colors.text, Font = Enum.Font.GothamBold, TextSize = 14, LayoutOrder = 999})
			button.Activated:Connect(function() request:FireServer(if active then "Abandon" else "Accept", quest.id) end)
		end
	end
end
snapshot.OnClientEvent:Connect(function(newState, text)
	if newState then state = newState end
	message.Text = if text == "" then "Choose a quest to begin." else text
	render()
end)
toggle.Activated:Connect(function() panel.Visible = not panel.Visible if panel.Visible then request:FireServer("Refresh") end end)
close.Activated:Connect(function() panel.Visible = false end)
-- Connect before requesting a snapshot; retry covers the asynchronous initial profile load.
task.spawn(function()
	while not state and gui.Parent do request:FireServer("Refresh") task.wait(3) end
end)
