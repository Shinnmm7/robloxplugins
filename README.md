<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:c98985cf065d0150bfdbe3ab4f53623ba53cdaf9c3e1badafc46f1dc25a2767c -->

# Roblox Studio plugins

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:c1e666ab6a78874d89c2fd2b309ec827f53ca516e2417e6e31eb7a529fea361a -->

## CineForge Pro

CineForge Pro provides a visual cinematic timeline, camera and character tracks, preview and generated Luau playback. See the [installation and runtime guide](docs/CINEFORGE.md). Build with `python3 tools/build_cine.py`.

## DialogueCraft Pro

<!-- /coderabbit-ai-generated:v1 -->

DialogueCraft Pro adds a visual dialogue graph editor, conditional choices, actions, preview, validation, and generated secure server/client runtime. See [installation, architecture, API, and example instructions](docs/DIALOGUECRAFT.md). Build with `python3 tools/build_dialogue.py`. The plugin itself is Luau; Python only packages the XML.

The repository check now covers <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:b9077189ebc66fca8477024027ca747087c109181d2ed396dbbdd860fecd1c39 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:b1333680dc61a6f8d4e58e67cab8663f34a4037eb2bff4f58ef66586d3a56efb -->

**69 behavioral scenarios**

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 --> across both plugins, plus Luau compilation and package integrity. Native Studio checks remain outstanding. Regenerate QuestForge using the current source for dialogue quest integration.

# QuestForge Pro

<!-- /coderabbit-ai-generated:v1 -->

A Roblox Studio plugin written in Luau for authoring quests and generating a connected server and client quest system. Includes a dark DockWidget editor, persistent player profiles, a quest journal, reusable server modules, and a playable example.

## Install

1. Download **QuestForgePro.rbxmx** from this task's Outputs, or build it with `python3 tools/build.py` (Python 3.10+; no packages required).
2. Open Roblox Studio in **Edit** mode. Insert the `.rbxmx` using **Insert from File** in the Explorer context menu. Put the resulting **QuestForgePro** Script in **ServerStorage** temporarily. Keep all child modules and the Templates folder with it.
3. Select the **QuestForgePro** Script and choose **Save as Local Plugin** from Studio's **Plugins** menu. Save it under the name **QuestForge Pro**. It should start immediately; restart Studio if necessary.
4. Delete the temporary Script from ServerStorage after saving. Open the editor with the **QuestForge Pro** toolbar button.
5. If Studio asks for permission to create/edit scripts, allow that permission for this plugin so generation can write Script.Source.

Use a current version of Studio. The plugin uses `CreateDockWidgetPluginGuiAsync`, `TryBeginRecording`, and `FinishRecording`.

## Run the example

1. Start with a baseplate and a spawn point. Publish a dedicated test experience.
2. For persistent data testing in Studio, enable **Game Settings → Security → Enable Studio Access to API Services**. This connects to the experience's actual DataStores; use a separate test experience.
3. Open **Generate** in the editor. Click **Load working example configuration**, then **Validate all quests**.
4. Click **Generate quest system into this place**, then **Create / replace example scene**. Both place operations support Studio Undo/Redo. The example scene appears near `(0, 3, -12)` and `(0, 2, -24)`; move it closer to your spawn if needed.
5. Press Play. Open **Quests** on the left of the screen and accept **A Spark for Rowan**.
6. Use Rowan's purple Talk prompt, collect three crystals using the cyan prompts, then use Rowan's gold Deliver prompt.
7. The quest grants **100 XP, 25 currency, one village_token, and rowanFriend metadata**. Three crystals are consumed. After 30 seconds, the quest can be accepted again.

Each crystal prompt can be reused after a one-second cooldown. The example is an intentional reusable gathering station. For finite pickups, have your authoritative pickup script call the server API once when an item is actually acquired.

## Editor

- **Quest list:** live search by name, ID, or category; create, select, duplicate, and delete quests. There is no fixed quest-count limit; Roblox memory, DataStore, and serialized configuration limits still apply.
- **Details:** unique ID, display name, description, difficulty, category, repeatability, and cooldown.
- **Objectives:** add/remove stages; choose All or Any completion; add, remove, and reorder objectives; edit target, count, stage, optional status, and sequential behavior. Choice buttons cycle through their values.
- **Rewards:** add/remove/reorder XP, currency, item, and metadata rewards. Metadata accepts non-null JSON values, including objects and arrays.
- **Requirements:** comma-separated prerequisite quest IDs, minimum level, and a visual list of required inventory items.
- **Preview:** inspect stages, objectives, rewards, and validation results.
- **Generate:** validate, save/load drafts in plugin settings, load the configuration from the place, generate the complete system, or create the example.

Text fields commit when focus leaves the field. Invalid numbers are rejected. Validation errors prevent generation. The editable draft may be incomplete and can still be saved. Plugin settings store one local draft shared across places on that machine; the generated place embeds its own JSON configuration in `ReplicatedStorage/QuestForgePro/ConfigurationData`. Load that place configuration when switching between projects. Drafts restore when the plugin starts and save on unload when changed.

**Generation replaces all instances owned by the plugin at its three output locations.** An instance with a matching name that lacks the plugin ownership attribute blocks generation. Edit the source templates for permanent runtime customizations; regeneration replaces edits made directly to generated scripts. Regeneration changes the configuration revision: on the next profile load, active quests become Abandoned and their current progress resets; balances, metadata, inventory, cooldowns, and completion history remain. Keep quest IDs stable to retain history. Removing or renaming a quest does not migrate its stored completion history.

## Generated architecture

```text
ReplicatedStorage
└─ QuestForgePro
   ├─ Config                 ModuleScript: authored quest definitions
   ├─ ConfigurationData      StringValue: editable JSON for plugin reload
   ├─ Request                RemoteEvent: Accept / Abandon / Refresh only
   └─ Snapshot               RemoteEvent: server → owning player's journal
ServerScriptService
└─ QuestForgePro
   ├─ Bootstrap              Script: starts the service
   ├─ QuestService           ModuleScript: persistence, requests, world adapters
   ├─ Engine                 ModuleScript: progression and reward transactions
   └─ Schema                 ModuleScript: configuration validation
StarterPlayer/StarterPlayerScripts
└─ QuestForgeProClient        LocalScript: interactive quest journal
Workspace
└─ QuestForgeExample          Optional example prompt targets
```

See [the integration and schema guide](docs/INTEGRATION.md) for server API usage, world target setup, persistence behavior, and the authoring contract.

## Source and build

```text
src/plugin/       Plugin entry point, visual editor, script generator
src/shared/       Configuration validator and complete example quest
src/runtime/      Generated server service, pure engine, client journal
tools/build.py    Reproducible XML plugin packager (standard library only)
tools/check.py    Luau compilation, behavioral tests, packaging integrity checks
tests/           Engine, persistence/security, generator, and editor harnesses
```

Build:

```bash
python3 tools/build.py
# Output: dist/QuestForgePro.rbxmx
```

Validate with upstream Luau CLI and compiler on PATH:

```bash
python3 tools/check.py
# Or specify binaries:
python3 tools/check.py --luau /path/to/luau --compiler /path/to/luau-compile
```

Automated verification used upstream **Luau 0.701**, Python **3.14.4**, and Ubuntu **26.04.1**. All Luau files compiled. **30 behavioral scenarios passed:** 13 engine/validation, 11 server persistence/security, five generator, and one editor interaction smoke scenario. XML checks also verify unique Roblox instance references, the module hierarchy, and byte-for-byte embedded source equality.

**Roblox Studio is unavailable in this Linux sandbox.** Native installation, rendered GUI layout, actual Undo/Redo, live DataStore semantics/limits, tagged physics/prompt behavior, and multiplayer must still be checked in Studio. The deterministic service and GUI harnesses are useful behavioral checks, not a replacement for a Studio play test.

## Studio acceptance check

- Install the local plugin and open/dock/resize its window. Exercise all six tabs, search, and a metadata reward.
- Save a draft, close/reopen Studio, and verify it restores; generate and reload from the place.
- Generate twice and verify only one copy of each generated container exists. Undo/Redo generation and example creation.
- Finish the example and verify the exact rewards and crystal consumption; rejoin to verify persistence.
- With two Studio test clients, verify each player's progress and inventory remain independent.
- Send forged progress/reward actions through Request and verify no progress or balances change.
- Disable API access and verify the journal reports unavailable data and grants no rewards.

## Official Roblox references

- [Creating and saving local plugins](https://create.roblox.com/docs/studio/plugins)
- [Plugin API](https://create.roblox.com/docs/reference/engine/classes/Plugin)
- [ChangeHistoryService](https://create.roblox.com/docs/reference/engine/classes/ChangeHistoryService)
