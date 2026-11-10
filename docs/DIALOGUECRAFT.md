<!-- coderabbit-ai-generated:v1 -->

# DialogueCraft Pro

A Luau Roblox Studio plugin for building NPC dialogue graphs. Installs beside QuestForge Pro using a separate toolbar and widget. Python is used only to package XML and run development checks; Studio runs Luau.

## Install and run

1. Download **DialogueCraftPro.rbxmx** from this task's Outputs. In Studio Edit mode, use Explorer **Insert from File**, then place the resulting DialogueCraftPro Script in ServerStorage temporarily.
2. Select that Script, retaining its children, and choose **Plugins → Save as Local Plugin**. Delete the temporary Script after saving. Restart Studio if the toolbar does not appear.
3. Open **DialogueCraft Pro**. The initial Rowan example is ready to validate and preview. If Studio asks for script-edit permission, allow it for generation.
4. In a published test experience, enable **Game Settings → Security → Enable Studio Access to API Services**. The runtime saves real data; use a separate test experience.
5. Click **Validate**, then **Generate**, then **Example NPC**. A purple NPC part appears near `(-8, 3, -12)`. Add a spawn/baseplate and move the NPC if necessary.
6. Press Play and use its Talk prompt. Choose the gift or goodbye branch. The gift grants one virtual `village_token`; Continue ends the conversation. This example is one-time per player.

Build locally with Python 3.10+ (standard library only):

```bash
python3 tools/build_dialogue.py
# dist/DialogueCraftPro.rbxmx
```

## Authoring

The left browser contains projects and search. There is no fixed project-count limit; platform storage/memory constraints apply. Each project has a unique stable ID, name, NPC name, starting Start node, repeatable flag, and independent graph. Different projects represent separate conversation sequences.

The center canvas shows nodes and their outgoing connections. The right inspector edits the project and selected node. Add Start, Text, Choice, Condition, Action, or End nodes with the inspector buttons.

- **Move:** drag a node title. Connections redraw on release.
- **Connect:** click an output button on a node, then click the destination node title. Alternatively, enter the target node ID in the inspector.
- **Disconnect:** use the corresponding inspector button. Deleting a node leaves broken references visible to validation so you can repair them.
- **Duplicate/delete:** use inspector controls. Node duplication assigns a new ID and keeps outgoing links. Renaming a node updates its incoming references and project start.
- **Pan:** use the canvas scrollbars or middle-mouse drag. **Zoom + / −** changes scale from 40% to 150%.
- **Arrange:** places reachable nodes by graph depth; disconnected nodes remain in the first column.
- **Project actions:** create, duplicate, delete, and search projects from the browser/inspector. Choice/type buttons cycle values.

Text fields commit on focus loss. Nodes keep positions when saved. Drafts, including temporarily broken connections, save in one local plugin setting and restore on startup. **Save/Load** store or restore all projects. **Export JSON** creates a selected StringValue in ServerStorage. To import, select an exported StringValue and click **Import selection**. Generation embeds another JSON StringValue under its ReplicatedStorage folder; select that to import configuration from the place. Export and generated-place changes use ChangeHistoryService recordings.

## Choices, conditions, and actions

Choice nodes have multiple editable responses, each with its own connection, condition, Hide/Disable visibility rule, and default flag. Exactly one response must be default and Always available. It acts as a fallback and is marked with `›` in the preview/client. It is still selected explicitly by the player. Hidden choices are omitted; disabled choices remain visible and cannot be selected. The server rechecks every chosen response.

Conditions: Always; Item quantity; Currency amount; Quest completed; Level minimum; Attribute value. The inspector provides the key and required amount/value. Attribute comparison uses `tostring` against the authored value, so `true`, `5`, and string values can be compared. Attributes come from the Player on the server. A Condition node has Yes/No outputs.

Actions: GiveItem, RemoveItem, GiveCurrency, StartQuest, CompleteQuest, and Event. Give/remove item actions operate on virtual inventory counts. Removal fails without sufficient inventory. Currency is a numeric ledger balance. Event uses a named BindableEvent in ServerStorage/DialogueCraftActions. The generator creates missing configured events; attach server listeners to implement your own game actions.

Without QuestForge generated, quest actions maintain Active/Completed quest flags in the standalone dialogue ledger. CompleteQuest requires an Active flag. With the updated QuestForge system generated in the same place, the service reads its level and quest completions and forwards start/complete actions to its trusted server API. Regenerate **both** systems using the updated packages to enable this integration. Currency and item ledgers remain separate; use server integrations when connecting an existing economy.

**Intentional QuestForge extension:** authored CompleteQuest actions may finish an active quest without objective events and grant its configured rewards. This is exposed only as a server API; quest clients retain Accept/Abandon/Refresh access. Non-active/completed quests cannot be rewarded again through this API.

## Preview and validation

**Preview** starts the selected project with a fresh simulated player. Select responses to traverse branches; the active node is highlighted. Preview actions only mutate simulation state. Simulated server events appear in the preview panel and never fire real BindableEvents. **Preview state** lets you edit the simulated items, currency, level, quests, attributes, and completion history as JSON, then restart the simulation on focus loss.

**Validate** opens a validation panel listing missing/duplicate project or node IDs, missing dialogue text, invalid conditions/actions/choices, missing targets, disconnected nodes, unreachable nodes, and graph cycles. Generation blocks on errors. Every project must start at a Start node, every required output must connect, and all nodes must be reachable. All cycles are rejected; conversations must terminate. Use multiple projects or repeatable conversations for repeat sequences. Traversal is additionally bounded by the project's node count.

Keep project/node IDs stable after release: one-time action receipts are keyed by those IDs. For a non-repeatable project, revisiting an action after closing/reopening cannot grant the same gift again. A repeatable project deliberately re-executes its actions on each new conversation.

## Generated architecture

```text
ReplicatedStorage/DialogueCraftPro
  Config                  ModuleScript with JSON-decoded project definitions
  ConfigurationData       StringValue for editor import
  Request                 RemoteEvent: token, turn, response ID only
  Response                RemoteEvent: server-approved display state
ServerScriptService/DialogueCraftPro
  Bootstrap               Starts the service
  Service                 Server persistence, NPC binding, requests and actions
  Model                   Shared validation and traversal engine (server only)
StarterPlayer/StarterPlayerScripts/DialogueCraftProClient
                          Interactive conversation LocalScript
ServerStorage/DialogueCraftActions
                          BindableEvents for authored custom actions
Workspace/DialogueCraftNPC Optional generated example target
```

Generated gameplay scripts are the actual source files in `src/dialogue/Service.luau`, `Model.luau`, `Runtime.server.luau`, and `Client.client.luau`. They are embedded byte-for-byte into the plugin package. The plugin-only files are `Plugin.server.luau`, `Editor.luau`, `Generator.luau`, and `Example.luau`.

Generation replaces only owned output containers. Unowned name collisions block generation. Modify source templates for permanent runtime changes, then rebuild; generation replaces manual edits to generated runtime scripts. JSON is quoted into configuration source, so dialogue text does not become executable Luau.

## Server API and world setup

Add a ProximityPrompt to a BasePart, set its `DialogueId` attribute to a project ID, and add tag **DialogueCraftNPC** after configuring it. Prompt activation and every response require a living character within 18 studs on the server. Targets should be anchored. Re-add the tag after replacing a prompt during Play. Alternatively, call Open from your server NPC script:

```luau
local Dialogue = require(game.ServerScriptService.DialogueCraftPro.Service)
Dialogue.Start() -- idempotent
local opened, reason = Dialogue.Open(player, "rowan_welcome", npcPart)

-- Standalone ledger integration; transform must not yield or have external effects,
-- because UpdateAsync may replay it. Call when outside a conversation.
Dialogue.UpdateState(player, function(state)
    state.level = 5
    state.currency = 100
    state.items.key = 1
end)

Dialogue.Changed:Connect(function(player, committedState)
    print(player.Name, committedState.currency)
end)

local event = game.ServerStorage.DialogueCraftActions:WaitForChild("OpenGate")
event.Event:Connect(function(player, receiptId, committedState)
    -- Implement the configured server action here.
    -- Deduplicate receiptId in your external system if it has durable side effects.
end)
```

An Event node using OpenGate causes the generator to create that event. No custom action can select an arbitrary instance or execute client-provided source. API transforms are trusted server code. Built-in state fields are items, currency, level, quests, attributes, completed, and executed (one-time action receipts).

## Persistence and security limits

DataStore **DialogueCraftPro_v1**, keys `p_<UserId>`, contains the canonical dialogue ledger and active conversation. Choice tokens, expected turn numbers, server ownership, 180-second expiry, distance checks, and per-player serialization prevent arbitrary node jumps and repeated response actions. Begin is throttled to 0.5 seconds; responses to 0.3 seconds. Fast repeated clicks may be ignored; click again after that interval. Request payloads never contain authoritative action values.

UpdateAsync saves progress/actions together. Each operation has a receipt so a lost response followed by retry does not duplicate a ledger change. Save errors retry three times, then show an error without publishing unsaved changes. Conversations can resume by talking to the same NPC in the same running server. A different server opens a new session and rejects old-server responses; one-time action receipts persist.

**External effects:** BindableEvents and QuestForge bridge calls dispatch after the dialogue commit. They are not one atomic transaction with the dialogue DataStore. A server crash between commit and dispatch can lose an external effect, and a failed QuestForge admission is logged. For critical custom actions, use receipt-aware external reconciliation. The built-in item/currency/quest-flag mutations are part of the dialogue transaction. The generator does not promise durable exactly-once external events or a shared transaction between the two plugins.

State and configuration must fit Roblox DataStore/memory limits. Generation caps serialized configuration below 3 MB. Load-test DataStore throughput for your game's expected dialogue volume. Use a separate test experience for Studio API testing.

## Verification

The full check command is:

```bash
python3 tools/check.py --luau /path/to/luau --compiler /path/to/luau-compile
```

Current automated result: <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:46415eb9aea328636c39bf5596127c92598ea656a1c13687db1a06faa0ca962e -->

**46 passing scenarios**

<!-- /coderabbit-ai-generated:v1 --> (14 QuestForge engine, 11 QuestForge server, 5 QuestForge generator, 1 QuestForge editor, 9 dialogue model, <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:ac07ff46ba33a12264366f9390f8ec4b5a8cd45fc9b3429cfade92b4556b2514 -->

and 6 dialogue server

<!-- /coderabbit-ai-generated:v1 -->). All Luau files compile with upstream Luau 0.701. XML checks verify hierarchy, unique instance references, and runtime-template equality for both plugins.

**Native Studio is unavailable in the Linux sandbox.** Dialogue editor rendering/input, live Undo/Redo, actual DataStores, multiplayer, and the QuestForge bridge need Studio verification. The dialogue editor has compilation coverage; its native graphical interaction is unverified.

Studio acceptance: install both local plugins; validate/generate; test node drag/connect/disconnect/delete/duplicate, zoom/pan and arrange; test Save/Load and JSON roundtrip; preview both Rowan branches and conditional hidden/disabled choices; run Rowan in Play; verify item count and rejoin persistence; try a stale token from another client; verify independent players; exercise a custom Event and both quest actions; Undo/Redo generation and example creation.
