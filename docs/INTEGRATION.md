<!-- coderabbit-ai-generated:v1 -->

# QuestForge Pro integration and configuration

## Quest contract

`src/shared/Example.luau` is a complete executable configuration. `src/shared/Schema.luau` defines validation; `Schema.NewQuest(id)` creates an editable starting point.

```luau
{
    version = 1,
    quests = {
        {
            id = "welcome", name = "Welcome", description = "Speak to the guide.",
            difficulty = "Easy", category = "Main", repeatable = false,
            cooldownSeconds = 0, prerequisites = {},
            requirements = {minLevel = 1, items = {}},
            stages = {{name = "Meet the guide", completion = "All"}},
            objectives = {{
                id = "greet", label = "Talk to the guide", type = "Talk",
                target = "guide", count = 1, stage = 1,
                optional = false, sequential = false,
            }},
            rewards = {{type = "XP", amount = 100}},
        },
    },
}
```

IDs use letters, numbers, underscores, periods, and hyphens (1–100 characters). Quest IDs are globally unique; objective IDs are unique within a quest. Difficulty is Easy, Normal, Hard, or Epic. Categories are free text. Counts, positive rewards, and levels are integers up to 1,000,000,000; cooldowns can be zero. Metadata must be JSON-compatible, non-null, and no deeper than 12 nested levels. Empty reward lists and projects are allowed. Generation rejects JSON configurations at or above 3 MB.

### Progression semantics

- Acceptance checks level, required item quantities, prerequisite completion, and repeat cooldown. Item requirements are checked, not consumed. Level starts at 1; XP does not automatically determine level.
- Each stage must contain a required objective. **All** requires every required objective; **Any** requires at least one required objective. Optional objectives never block or independently complete a stage.
- A sequential objective waits for earlier required objectives in its stage, in the objective list's order. A single event cannot also satisfy a sequential successor that becomes available during that event.
- An event advances matching eligible objectives in the current stage. An event cannot also advance a newly unlocked stage.
- Completing a stage advances to the next. Finishing the final stage grants every reward once in the same persistent transaction as quest completion.
- `CompleteQuest` uses historical completion of the referenced quest, including completion before acceptance; its count must be 1. It updates automatically, including across stage transitions and completion cascades. Self-references, missing references, and dependency cycles are rejected.
- A repeated quest resets progress, keeps completion history, and can be accepted again after its cooldown. Abandoning resets current progress and preserves previous completion history/cooldown.
- Collect adds to the built-in inventory once per event and also advances matching Collect objectives. Delivery only consumes owned items that match an eligible Deliver objective. Across simultaneous delivery quests, the configuration order decides which quest consumes available inventory first.
- Item rewards are virtual inventory quantities. Currency is a built-in single balance. Metadata rewards overwrite their configured key. Balances saturate at 1,000,000,000,000. Rewarding an item does not generate a Collect event.

Reward forms:

```luau
{type = "XP", amount = 100}
{type = "Currency", amount = 25}
{type = "Item", item = "village_token", amount = 1}
{type = "Metadata", key = "rowanFriend", value = {unlocked = true}}
```

## Server integration

Use the generated API from **server Scripts only**. Bootstrap starts it automatically. `Start()` is idempotent, so integrations may call it before reporting events.

```luau
local QuestService = require(game.ServerScriptService.QuestForgePro.QuestService)
QuestService.Start()

-- Call after your own server code has verified the corresponding action.
local queued, reason = QuestService.Report(player, "Kill", "forest_slime", 1)
if not queued then warn(reason) end

QuestService.Report(player, "Collect", "apple", 2)
QuestService.Report(player, "Talk", "rowan", 1)
QuestService.Report(player, "Reach", "north_gate", 1)
QuestService.Report(player, "Interact", "ancient_switch", 1)
QuestService.Report(player, "Deliver", "rowan", 3, "apple")
QuestService.SetLevel(player, 5)

local state = QuestService.GetState(player) -- Deep copy, or nil while loading
QuestService.Changed:Connect(function(changedPlayer, committedState)
    -- Called after a successful committed save. Read canonical balances here.
    print(changedPlayer.Name, committedState.xp, committedState.currency)
end)
```

`Report` and `SetLevel` return whether the operation was admitted to the player's queue, not whether the later DataStore save succeeded. Wait for Changed or read GetState after a committed snapshot when you need the result. Never use an admitted queue operation as authorization to award an external item. The built-in ledger is authoritative for the generated system. Connecting an existing economy or granting physical Tools requires an integration designed to derive from this ledger; external side effects are not transactionally committed by Roblox DataStores. The generator does not infer existing game inventory, combat, NPC dialogue, or economy conventions.

State contains `version`, `level`, `xp`, `currency`, `items`, `metadata`, and `quests`. Each quest record includes `status`, `stage`, `progress`, `completions`, and `completedAt` after completion. `GetState` is nil until profile acquisition succeeds. Changed does not fire for the initial load; query GetState to obtain initial balances.

## World adapters with no custom scripts

Use Studio's tag editor to add **QuestForgeTarget** after configuring a target. Targets created by the example already have these settings. Targets are bound when the service starts or when the tag is added. Remove/re-add the tag after replacing a prompt or changing a target between Reach and another type while the server is running.

| Objective | Tagged instance | Attributes / setup |
| --- | --- | --- |
| Kill | Humanoid | `QuestTarget` string; server combat adds an ObjectValue named `creator` whose Value is the credited Player before death |
| Collect | BasePart with child ProximityPrompt | `QuestType = "Collect"`, `QuestTarget = itemId`, optional positive integer `QuestAmount` |
| Talk | BasePart with child ProximityPrompt | `QuestType = "Talk"`, `QuestTarget = npcId` |
| Reach | BasePart with CanTouch enabled | `QuestType = "Reach"`, `QuestTarget = locationId`, optional number `QuestRadius` (default 10, clamped 1–100 studs); touched by a character |
| Interact | BasePart with child ProximityPrompt | `QuestType = "Interact"`, `QuestTarget = objectId` |
| Deliver | BasePart with child ProximityPrompt | `QuestType = "Deliver"`, `QuestTarget = npcId`, `QuestItem = itemId`, `QuestAmount` positive integer |
| CompleteQuest | No instance | Objective target is the other quest's ID; automatically reconciled by the engine |

Prompt actions require a living player's character near the part on the server. Distance is capped at 20 studs, even if a prompt has a larger activation distance. Each target allows one interaction per player per second. Reach uses server contact and distance checks. Kill credit trusts the server's creator tag; use your server combat handler and Report directly for other attribution conventions. These adapters confirm generic target actions; a Talk prompt does not build your NPC dialogue system.

## Client protocol

The generated client builds an interactive quest journal and listens before requesting the initial snapshot. It retries Refresh during asynchronous profile loading. It supports viewing quests, accepting quests, abandoning active quests, stages/objective progress, and reward summaries.

Only these client requests are supported:

```luau
Request:FireServer("Accept", questId)
Request:FireServer("Abandon", questId)
Request:FireServer("Refresh")
```

The server checks action and ID types, enforces per-player request intervals, looks up server-owned definitions, and validates acceptance. Unknown actions cannot report objectives, edit balances, set levels, or grant rewards. Request intervals are 0.5 seconds for quest mutations and one second for Refresh. Clients only receive their own state. All quest definitions in ReplicatedStorage are public.

## Persistence and recovery

- DataStore: `QuestForgePro_v1`; key: `p_<UserId>`. Version 1 player records hold the entire canonical quest ledger.
- Each join acquires a unique session lease for 180 seconds. Heartbeats renew it every 60 seconds. A foreign active lease blocks loading. A crashed server's lease expires; wait up to three minutes before reconnecting if needed.
- Operations are serialized per player and saved with UpdateAsync before snapshots or Changed are published. An operation ID prevents duplication if a successful save's response is lost and retried. The UpdateAsync transform has no external reward side effects.
- Load and save errors retry up to three times. After an unrecoverable save error, new mutations stop and the journal asks the player to rejoin. No unsaved reward is published. Normal leave releases the lease after pending writes; shutdown allows a bounded drain. A busy timed-out save keeps its lease until expiry.
- The queue is bounded to 60 waiting operations per player. Roblox DataStore budgets and latency constrain throughput. Batch high-volume trusted events using Report's amount parameter, and check admission failures in custom integrations. This template is suited to ordinary quest interactions; load-test your game's expected event volume.
- Profiles fail closed when DataStores are unavailable. There is no pretend-success or volatile-storage fallback. Avoid running a local Studio session against production player records.

## Studio operations

Generation and example-scene creation require Edit mode. Each uses a ChangeHistoryService recording committed on success and cancelled on error. All destination collisions are checked before generated containers are replaced. Generation writes only plugin-owned instances in ReplicatedStorage, ServerScriptService, and StarterPlayerScripts. The optional scene replaces only the owned `Workspace/QuestForgeExample` folder.

The generator embeds JSON as a quoted Luau string passed to HttpService:JSONDecode. Quest names, descriptions, IDs, or metadata cannot inject executable Luau into generated configuration. The plugin never requires user-supplied ModuleScripts when loading configuration from a place.
