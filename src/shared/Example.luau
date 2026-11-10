return {
	version = 1,
	quests = {{
		id = "crystal_errand", name = "A Spark for Rowan", difficulty = "Easy", category = "Village",
		description = "Speak to Rowan, gather three crystals, and bring them back. Start this quest using the Quests button when you play.",
		repeatable = true, cooldownSeconds = 30, prerequisites = {}, requirements = {minLevel = 1, items = {}},
		stages = {{name = "Meet Rowan", completion = "All"}, {name = "Gather crystals", completion = "All"}, {name = "Return to Rowan", completion = "All"}},
		objectives = {
			{id = "meet", type = "Talk", label = "Speak to Rowan", target = "rowan", count = 1, stage = 1, optional = false, sequential = false},
			{id = "gather", type = "Collect", label = "Gather crystals", target = "crystal", count = 3, stage = 2, optional = false, sequential = false},
			{id = "return", type = "Deliver", label = "Give Rowan three crystals", target = "rowan", item = "crystal", count = 3, stage = 3, optional = false, sequential = false},
		},
		rewards = {{type = "XP", amount = 100}, {type = "Currency", amount = 25}, {type = "Item", item = "village_token", amount = 1},
			{type = "Metadata", key = "rowanFriend", value = {unlocked = true}}},
	}},
}
