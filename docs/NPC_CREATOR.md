<!-- coderabbit-ai-generated:v1 -->

# NPC Creator Pro

A native Roblox Studio plugin written in **Luau**, with a dark dockable editor, custom R6/R15 rigs, username-based avatar NPCs, a WorldModel preview, NPC management, local saved presets, and optional server AI. It does not install an in-game editor or use external HTTP services.

## Install

1. Download `NPCCreatorPro.rbxmx`, or run `python3 tools/build_npc.py` from the source repository to build `dist/NPCCreatorPro.rbxmx`. Python is only the XML packaging tool; Studio runs the Luau source and does not need Python.
2. Open a current version of Roblox Studio in Edit mode. Insert the `.rbxmx` with **Insert from File** in Explorer. Move its root **NPCCreatorPro** Script to ServerStorage temporarily. Keep its five child modules and Templates folder together.
3. Select that Script and use **Save as Local Plugin** (the Script context menu or Studio's Plugins tools). Save it as **NPC Creator Pro**. Restart Studio if it does not appear immediately.
4. Delete the temporary imported Script after saving. Click **NPC Creator Pro** on the plugin toolbar to open the DockWidget. Dock, float, or resize it as needed; the minimum floating size is 860 × 660.
5. If Studio requests permission to create/edit scripts, allow it when enabling the optional server AI template. Script.Source writes only occur when installing or updating that template.

World edits require Edit mode. A play test blocks spawn, property updates, rebuild, duplication, and deletion. Reading configurations and detached previews does not require a running game or a player to join.

## Quick start: custom NPC

1. Choose **Custom NPC**. Set **NPC model name** to `Village Guide`, **Display name** to `Rowan`, health to `150`, walking speed to `12`, and jump power to `40`. Add a description if desired.
2. **Rig** cycles between R15 and R6. **Show name and health** controls Humanoid name/health visibility.
3. **Panel: Identity** cycles to **Appearance**, then **Behavior**, then back to Identity.
4. In Appearance, edit individual body-part asset IDs, classic face/shirt/pants/T-shirt IDs, six body RGB colors, and R15 body scales. Use `0` for a default body part or no clothing asset. RGB fields accept `163, 162, 165` format. Body dimensions accept 0.1–2; BodyTypeScale and ProportionScale accept 0–1. Roblox may clamp or adapt proportions for a particular body.
5. Click **Build preview**. A detached rig appears in the preview card. Drag horizontally or use the rotation buttons; use the mouse wheel or Zoom buttons to zoom. **Reset view** restores the front view and default zoom.
6. In **Settings**, choose Camera or Selection spawning. For Selection, select a Workspace part/model. **Save settings** persists these choices locally.
7. Click **Spawn NPC**. The generated Model is selected in Explorer and placed in the managed Workspace folder. A ready preview can spawn multiple separate copies.
8. Use **Preset name → Save new preset** to keep this configuration for future use.

All text fields commit on focus loss. Configuration edits mark the preview out of date; **Build preview** refreshes it before another spawn or replacement. Invalid inputs report errors in the status area and block rig creation.

## Quick start: player avatar NPC

1. Choose **Player Avatar NPC**. Enter an account username such as `Roblox`, without `@`. Display names are not account usernames.
2. Click **Search username & load avatar**. Loading is shown in the preview card and Build button. On success the card and form display the entered username and resolved UserId.
3. Set **NPC model name** and **Display name** independently of that account. For example use `Town Merchant` and `Merchant`; the account username remains recorded as source metadata.
4. Choose R6 or R15 and refresh the preview after making changes. R6 cannot reproduce all R15 body packages or layered clothing; Roblox can adapt or reject an incompatible appearance. Errors leave existing Workspace NPCs intact.
5. Click **Spawn NPC** as often as needed. Each copy receives its own plugin ID. The account does not have to join the game.

The loader uses these Roblox APIs, in order:

- [Players:GetUserIdFromNameAsync](https://create.roblox.com/docs/reference/engine/classes/Players#GetUserIdFromNameAsync)
- [Players:GetHumanoidDescriptionFromUserIdAsync](https://create.roblox.com/docs/reference/engine/classes/Players#GetHumanoidDescriptionFromUserIdAsync)
- [Players:CreateHumanoidModelFromDescriptionAsync](https://create.roblox.com/docs/reference/engine/classes/Players#CreateHumanoidModelFromDescriptionAsync)

The final API both builds the selected rig and applies the description. Every yielding call is protected. Changing creation mode, editing configuration, starting another valid load, or unloading the plugin invalidates earlier requests. Obsolete results are destroyed and cannot overwrite the current preview. Lookup failures, unavailable appearance data, rig/asset errors, and invalid input show status errors. A stalled Roblox request cannot be forcibly interrupted; its result is discarded when it eventually returns.

After a successful load, the appearance is stored as a snapshot: body/clothing asset IDs, body colors and scales, accessory descriptors including layered clothing, animation IDs, and dynamic-head mood/static-face settings. **Build preview** reuses that snapshot. **Search username & load avatar** deliberately fetches the account's current appearance again. Saved snapshots still depend on Roblox serving those assets and honoring the experience's asset permissions.

Custom and Avatar configurations are separate in memory. Editing a username or encountering an avatar API failure does not affect the custom NPC creator.

## Preview

The preview uses a [ViewportFrame](https://create.roblox.com/docs/reference/engine/classes/ViewportFrame), a WorldModel, and its own Camera. It fits the rig to the viewport on resize, has ambient/directional lighting, and supports drag rotation, bounded zoom, reset, and optional automatic rotation. The card identifies the rig and, for loaded avatars, username/UserId.

Preview parts are anchored and imported executable scripts are removed. NPCs are only parented to Workspace when spawned or when an explicit replacement is committed. The preview never writes to `Workspace.CurrentCamera`; closing/unloading destroys the preview world and camera. It is a static appearance preview; server AI and animations are exercised in a Studio play test.

## NPC Manager

The manager discovers Workspace Models carrying the `NPCCreatorPro` ownership attribute, including models saved with the place or restored by Studio Undo. Search matches model names. Use Refresh after external renames; the list also refreshes when managed models enter/leave Workspace and on Undo/Redo.

Select an NPC row, then use:

| Control | Result |
| --- | --- |
| Select in Explorer | Selects the Model with Studio's Selection service. |
| Edit properties / appearance / behavior | Loads its configuration into the appropriate creation mode and builds a detached preview. |
| Preview selected NPC | Clones the actual existing rig, including manual visual edits, into the preview card. |
| Duplicate selected NPC | Clones the Model, assigns a new plugin ID, and offsets it five studs along world X. |
| Save selected NPC preset | Saves its stored appearance/settings plus current name and Humanoid properties. |
| Delete selected NPC | Removes the Model with Studio Undo support. |

To rename, load the NPC for editing, change **NPC model name**, and click **Apply properties + behavior to NPC**. That button updates name, description, Humanoid values, visibility, and optional server AI on the same Model. It preserves the existing appearance and stored rig/source identity; changing an appearance field alone does not claim to have applied an unbuilt body.

To change appearance or rig type, load/edit the NPC, **Build preview**, then click **Replace NPC rig with preview**. Replacement retains its parent, pivot, plugin ID, and root attributes. **It replaces the Model and every descendant**, including manually added scripts/attachments or behavior edits; external ObjectValue references to the old Model are not migrated. Use the properties operation for edits that should retain manual rig work. Undo can restore a replacement.

**Detach / create another NPC** ends editing of that existing target. **Spawn NPC** always creates another Model; it does not overwrite the editing target.

Saving a preset captures authored appearance data, not arbitrary manually attached descendants. To preserve a manually modified rig as a whole, save the Model with your place or as a Roblox model. A managed NPC with missing/corrupt preset data or unowned children using reserved plugin names reports an error.

## Saved NPCs

- **Save new preset** creates a new local preset from the current configuration. Avatar configurations must have a loaded appearance.
- **Saved NPCs** lists stored presets. Select one to **Load saved NPC**, rename, overwrite it with the current editor configuration, or delete it.
- Loading builds a preview; it does not spawn automatically.
- Preset names contain 1–80 characters. Presets are stored with `plugin:SetSetting` as JSON under `NPCCreatorPro.Presets.v1`. They survive Studio restarts on that plugin installation and are shared across places on that machine.
- Presets/settings are local plugin storage, separate from place files and Studio's world Undo stack. Save errors are reported and preset mutations are rolled back in memory. The serialized preset collection is limited to 3 MB; a single generated NPC configuration is limited to 250 KB.

## Optional server AI

In the **Behavior** panel, enable **Generate server AI template** and choose a movement mode and disposition. With the template disabled, the NPC is a normal unanchored Humanoid rig and the plugin adds no AI Script.

| Movement | Behavior |
| --- | --- |
| Idle | Stays in place with normal Humanoid physics; optional idle animation. |
| Walking | Walks once to a point ahead of its initial facing, using Walking distance from spawn. |
| Patrol | Loops through at least two configured world-space waypoints. |
| Follow | Follows the nearest living player within Detection range and stops at the configured distance. |
| Stationary | Anchors the HumanoidRootPart and never moves. |

**Friendly** never attacks. **Enemy** seeks the nearest living player in range, temporarily chases it unless Stationary, and deals configured server-side damage when within Stopping / attack distance plus one stud. A server raycast must have line of sight. Attack interval limits repeated hits; it is configurable from 0.25–60 seconds. An Enemy without a target returns to its underlying walking/patrol behavior, or remains idle for Idle/Follow/Stationary.

For patrol, select a Workspace part or model and click **Add selected location as patrol point**. Edit individual `X, Y, Z` fields or remove points. Coordinates are absolute world positions: moving or duplicating the NPC does not move its authored patrol route.

Movement uses PathfindingService with periodic repathing, jumps at path jump waypoints, and falls back to Humanoid:MoveTo if no path is available. NPC network ownership is requested for the server. Geometry, crowds, physics, rig size, and streaming can prevent movement; there is no navigation guarantee or unstuck teleport. Each enabled NPC runs a throttled server task; profile large populations for your game's map and workload.

Idle/Walk animation asset IDs are optional; `0` disables the corresponding track. Use animations compatible with the selected rig and permitted for your experience. The template runs an Animator on the server and reports load errors to Output. It does not install Roblox's player Animate script or automatically run every animation from an avatar's description. Without configured animation assets, the Humanoid still moves physically but the limbs are not animated by this template.

NPC AI has no client RemoteEvent interface. Targets are real server-observed player characters. Damage amount, range, target selection and cooldown come from the server's generated configuration. These are basic reusable templates; they do not implement quest logic, dialogue, faction teams, inventory rewards, or persistent NPC health.

## Settings and placement

| Setting | Default | Purpose |
| --- | --- | --- |
| Spawn location | Camera | Cycles Camera/Selection. |
| Camera forward distance | 12 | Rig pivot is at camera position plus forward vector × distance. Set 0 for the exact camera position; no ground snap is performed in Camera mode. |
| Managed Workspace folder | NPCCreatorNPCs | Creates/reuses an owned Folder. A same-named unowned object blocks spawning. |
| Automatically rotate preview | Off | Slowly rotates the preview while the DockWidget is visible. |

Selection mode aligns the bottom of the rig's bounding box with the top of the selected part/model's bounding box plus 0.05 studs. NPCs initially face world −Z; rotate them with Studio's tools. Settings are saved only when **Save settings** is clicked, under `NPCCreatorPro.Settings.v1`.

## Source and generated architecture

```text
src/npc/
  Plugin.server.luau    Toolbar, DockWidget, unloading lifecycle
  Editor.luau           Five navigation pages, forms, async load orchestration
  Model.luau            Defaults, clone, validation and appearance whitelist
  Rig.luau              Username/description lookup, codec, rig creation
  Preview.luau          ViewportFrame camera, WorldModel, rotation/zoom/cleanup
  Manager.luau          Selection, placement, CRUD, recording and ownership
  Behavior.server.luau  Optional real server AI source template

tools/build_npc.py      XML packager; uses tools/build.py's XML helper
tools/check_npc.py      NPC-only compiler, harness and package verification
tests/npc*.luau         Pure schema and simulated Roblox-boundary tests
```

Installed plugin:

```text
NPCCreatorPro                   Script, saved as a local plugin
  Model / Rig / Preview        ModuleScripts
  Manager / Editor             ModuleScripts
  Templates
    Behavior                   StringValue containing the server AI source
```

Spawned place output:

```text
Workspace
  NPCCreatorNPCs                Owned Folder (configurable)
    Village Guide              Model with Humanoid, body parts and accessories
      NPCCreatorConfig         Owned StringValue: versioned JSON preset
      NPCCreatorBehavior       Owned server Script, only when AI is enabled
```

Root Model attributes include `NPCCreatorPro=true`, unique `NPCCreatorId`, `NPCDescription`, `NPCSourceUsername`, and `NPCSourceUserId`. These are metadata for the authoring workflow, not a security credential.

World mutations use [ChangeHistoryService recording](https://create.roblox.com/docs/reference/engine/classes/ChangeHistoryService), with Commit on success and Cancel on failure. Yielding network/asset work happens before a world recording. Detached clones are explicitly destroyed if a later operation fails. The plugin refuses to replace unowned reserved children/folders. It removes executable content from avatar assets; only the bundled AI template is installed by the manager.

## Build and checks

Python 3.10+ with only the standard library is sufficient to package. No Python is shipped into a place. Upstream Luau CLI/compiler are required for automated tests:

```bash
python3 tools/build_npc.py
python3 tools/check_npc.py --luau /path/to/luau --compiler /path/to/luau-compile
# All four plugins:
python3 tools/check.py --luau /path/to/luau --compiler /path/to/luau-compile
```

The NPC checks compile its Luau and exercise six harness groups: configuration validation; actual rig-loader API ordering/errors/cancellation; manager ownership/placement/CRUD/recording; isolated preview operations; editor controls/presets/asynchronous request handling; and actual server AI dispatch/damage/line-of-sight. XML checks verify every embedded source, the native instance hierarchy and unique references. Harness services and instances are synthetic; they do not run a Roblox engine or prove real rendering, physics, or network behavior.

### Verification status

Automated NPC checks passed using upstream Luau 0.701, Python 3.14.4 and Ubuntu 26.04.1. The existing QuestForge/DialogueCraft/CineForge checks were reused from their previously validated unchanged source and fixtures.

**Roblox Studio cannot run in this Linux sandbox.** Installation, rendered UI, actual avatar delivery and R6/R15 compatibility, asset permissions, real Undo/Redo, physics/pathfinding and animation playback remain unverified. The source implements those Studio calls, but an engine acceptance test is still needed before calling the plugin verified in Studio.

## Studio acceptance test

1. Install the plugin, open/close its toolbar window, dock/resize it, and exercise all five navigation pages.
2. Build a Custom R6 and R15 NPC without making an avatar search. Change colors/part IDs, name visibility, health, speed and jump power. Confirm the preview and spawned rigs match.
3. Load a real account username; confirm the source UserId, compatible avatar appearance and custom model/display name. Spawn two independent copies.
4. Test an invalid username and unavailable/incompatible asset. Start a search and change modes; close/unload while a load is pending. Confirm no stale result or unfinished Workspace NPC appears.
5. Rotate/zoom/resize the preview and enable automatic rotation. Confirm Studio's own camera remains unchanged. Stop a play test before making world edits.
6. Spawn using camera distance 0 and 12; select a part/model and verify Selection placement. Verify an unowned destination folder blocks generation.
7. In Manager, select, rename/apply, duplicate, delete, and replace an appearance. Undo/Redo each world operation. Confirm unrelated models remain untouched and replacement retains the pivot/ID.
8. Save/load/rename/overwrite/delete presets. Restart Studio and confirm saved presets/settings persist. Reopen the place and verify NPC discovery.
9. Configure a two-point patrol; play test Walking/Patrol/Follow and Idle/Stationary. Use a rig-compatible permitted idle/walk animation if needed. Test Enemy damage and a wall obstructing line of sight; Friendly should never damage players.
10. Run a server with two test clients and verify AI decisions/damage are server-owned, generated NPCs replicate, and there is no client damage/reward remote to invoke.
