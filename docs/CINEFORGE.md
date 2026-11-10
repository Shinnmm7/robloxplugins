<!-- coderabbit-ai-generated:v1 -->

# CineForge Pro

CineForge Pro is a Roblox Studio plugin and client runtime written in Luau. It provides cutscene projects with multiple scenes, camera and character tracks, cinematic effects, Studio preview, validation, and runtime generation.

## Installation

1. Download **CineForgePro.rbxmx**. In Studio Edit mode, use Explorer **Insert from File** to insert it. Temporarily place the resulting CineForgePro Script in ServerStorage and keep its children together.
2. Select the Script and choose **Plugins → Save as Local Plugin**. Delete the temporary Script after saving. Restart Studio if its toolbar does not appear.
3. Click **CineForge Pro** in the plugin toolbar. Allow Studio's script editing permission if prompted during generation.

To build the plugin from source, run `python3 tools/build_cine.py`; the output is `dist/CineForgePro.rbxmx`. Python is only used to package the plugin and run the repository tests; Roblox runs the Luau code.

## Example cutscene

The editor opens with **Village introduction** (`village_intro`) unless a saved draft exists. Click **Example** to add a fresh copy with a unique ID. Select the project and click **Preview / reset**, then **Play**. The Studio viewport camera moves while the editor's preview monitor displays the fade, letterbox and subtitle. Click **Pause** or **Stop / restore** to restore the camera. You can scrub the timeline while preview is active.

To use it in an experience, click **Validate**, then **Generate** in Edit mode. Add this LocalScript to StarterPlayerScripts and Play; use the actual ID shown in the project inspector:

```luau
local root = game:GetService("ReplicatedStorage"):WaitForChild("CineForgePro")
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:8f27d7c6c00f03cac7b78f3d9ed0f7e84c720f82a03bbac0da3f9ed8a3e4e515 -->

-- Wait for CineForgeProClient to connect before firing the local event.
while not root:GetAttribute("ClientReady") do root:GetAttributeChangedSignal("ClientReady"):Wait() end

<!-- /coderabbit-ai-generated:v1 -->
root.Play:Fire("village_intro")
```

The starter script shows how to trigger a cutscene. Integrate the event into your own game flow for production; see the API below. The generated runtime does not auto-play cutscenes.

## Editor workflow

- **Projects and scenes:** use the left browser to add and select projects/scenes. The Project inspector renames, duplicates, deletes and reorders scenes, changes the project ID, and adjusts scene duration and letterbox. Keep one scene per project. Project IDs must be unique.
- **Timeline:** camera diamonds represent keyframes in the selected scene. Click a diamond to select it; drag it to change its timestamp. Click or drag the ruler to scrub. Zoom buttons adjust pixels per second; use the horizontal scrollbar for long scenes. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:bea91322aa6ca994d8c916f144340b5856e52df095ba875e0a2e4d646bc86951 -->

The current time and duration appear above the ruler. The SUB lane displays subtitle clips; the ACT lane shows animation clips and movement-key ticks.

<!-- /coderabbit-ai-generated:v1 -->
- **Camera:** add a keyframe at the playhead, capture the Studio camera position, orientation and FOV, edit numeric XYZ position and Euler XYZ rotation in degrees, choose a transition, set custom power, enter an optional look-at path, or delete a keyframe. Move the Studio camera to the desired location before capture. Changes are saved when a field loses focus.
- **Effects:** edit fade to black (0–1), blur (0–56), depth intensity (0–1), focus distance, and shake intensity at each selected camera keyframe. Values interpolate with the outgoing camera transition. FOV interpolates in the same way. Letterbox is a per-scene setting.
- **Subtitles:** add, edit, or remove text clips with start time and duration. Overlapping subtitle clips are rejected.
- **Characters:** add a character using a slash-separated Workspace model path, or select a model and capture its path. Add movement keys and animation clips at the playhead; enter XYZ transform values or capture the selected model's pivot. Animations use numeric Roblox animation asset IDs and clip start/duration. Animation clips for one character cannot overlap; movement timestamps for one character must be unique. Character movements are linearly interpolated between keys, independently of camera easing.
- **Preview:** Preview / reset creates a preview at the selected scene's playhead. Play, Pause and Stop / restore control it. The player advances through scenes in order. Scrubbing while a preview exists moves camera, effects, characters and animation positions. Stop, closing the widget, unloading the plugin, and playback errors release the preview resources and restore the original camera. Studio preview uses temporary cloned character models; it does not move the authored models. Rig clones must be archivable and contain a Humanoid or AnimationController to preview animations.
- **Save/load:** Save draft and Load draft use a single plugin setting shared across places. Unsaved changes are also saved when the plugin unloads. The generated place contains its own `ConfigurationData` StringValue. Export JSON creates a selected StringValue in ServerStorage; select an exported or generated configuration StringValue and use Import selection. Import and generation require valid configurations, while draft save can preserve unfinished work.
- **Validation:** Validate lists configuration errors in the monitor: invalid/missing keyframes, duplicate timestamps, invalid FOV/transforms/effects/easing, scene durations, missing or malformed animation IDs, and conflicting clips. **Check assets** queries Roblox for animation asset metadata and reports invalid IDs, wrong asset types, or assets that could not be verified. A successful metadata lookup does not guarantee that the experience has permission to play an animation; verify ownership and permissions in Studio.

A project has no fixed count limit, subject to Roblox memory and storage limits. Generation rejects serialized JSON of 3 MB or greater. Timeline keyframes may be entered out of order; sampling uses their timestamps. Exact duplicate camera/movement timestamps are invalid. A scene needs at least one camera keyframe. Shorten the scene only after moving or removing clips and keyframes outside its new duration.

### Camera interpolation

Each key's transition controls the segment from that key to the next. Linear uses constant progress. Smooth uses smoothstep; EaseIn uses quadratic acceleration; EaseOut uses quadratic deceleration; EaseInOut uses quadratic acceleration/deceleration; Custom uses `t ^ power` with power 0.1–10. CFrame interpolation blends position and rotation; FOV and numeric effects follow the same eased fraction. Values before the first and after the last key hold the nearest key. A look-at target remains selected until the next key; the runtime aims at a BasePart, Attachment, or Model at the configured slash-separated Workspace path. Missing or coincident targets leave the keyframed orientation in use.

Fade is black opacity. Shake adds a deterministic small positional and rotational oscillation; it is a visual effect and does not change the underlying keyframes. Depth uses near/far intensity, focus distance, and a 20-stud in-focus radius. Fade, subtitle, and letterbox are shown in the editor monitor; blur and depth apply to Studio's viewport via temporary Lighting effects. The runtime shows all effects on the player's screen.

## Generated architecture

```text
ReplicatedStorage/CineForgePro
  Config                ModuleScript; JSON-decoded projects/scenes
  ConfigurationData     StringValue; import back into editor
  Model                 ModuleScript; validation and timeline sampling
  Player                ModuleScript; camera/effects/character playback
  Play                  BindableEvent; local client starts a project by ID
  Stop                  BindableEvent; local client cancels playback
  Completed             BindableEvent; local client receives completed project ID
  PlayForClient         RemoteEvent; server can request client playback
StarterPlayer/StarterPlayerScripts/CineForgeProClient
                        LocalScript; wires events to the Player module
```

Generation uses ChangeHistoryService and replaces only CineForge-owned output containers. Unowned names block generation. Manual changes inside generated containers are replaced when generating again; edit the source templates and rebuild the plugin to make persistent runtime customizations. Configuration is JSON encoded and quoted inside the generated ModuleScript, so names and subtitles are not evaluated as code.

## Runtime API

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:7e6522d7685cd0fa137dc5c4014328bdd464f2168a458aad0cfd1fd85c051a1c -->

In a **LocalScript** after the generated client script is ready. Wait for its `ClientReady` attribute as shown in the example above before firing Play:

<!-- /coderabbit-ai-generated:v1 -->

```luau
local root = game:GetService("ReplicatedStorage"):WaitForChild("CineForgePro")
root.Completed.Event:Connect(function(projectId)
    print("Cutscene finished:", projectId)
end)
root.Play:Fire("village_intro")
-- Later, if needed: root.Stop:Fire()
```

A server Script may request a cutscene for one player:

```luau
local root = game:GetService("ReplicatedStorage"):WaitForChild("CineForgePro")
root.PlayForClient:FireClient(player, "village_intro")
```

Send the remote only after that player's generated client script is running; Roblox does not queue RemoteEvents for listeners that do not yet exist. Completion is deliberately local: do not trust it for rewards or other server authority. An existing game can use the reusable `Player` ModuleScript directly if it needs explicit start/seek/pause/cleanup control:

```luau
local root = game.ReplicatedStorage.CineForgePro
local config = require(root.Config)
local Player = require(root.Player)
local player = Player.New(config.projects[1], playerGuiScreenGui, false)
player.Completed:Connect(function(id) print(id) end)
player:Render(1.5)  -- seek in project time
player:Play()
player:Pause()
player:Destroy()     -- restore camera and dispose effects
```

Play pauses automatically at the end and fires Completed once. The generated LocalScript destroys the player on completion or Stop, restoring the saved camera and removing effects. Starting another project first stops the current one. `Render` accepts time in seconds over the entire project. `Player.New` clones the configuration for stable playback. Multiple independently created Player instances should not drive the same camera at once.

**Character movement is client-side presentation.** It moves the local copy of a workspace model and restores its saved pivot on scene exit/stop. It does not authoritatively move server characters, may compete with gameplay movement or physics, and is visible to the current client only. Anchor or otherwise manage cinematic actors in your game and coordinate any server-owned movement separately. Animation clips require a rig with a Humanoid/AnimationController and a playable animation asset. Character paths are resolved when a scene begins; unavailable models or animations warn and are skipped. Network streaming and asset permissions can affect availability.

## Validation and limitations

Run the repository checks with Luau CLI and compiler installed:

```bash
python3 tools/check.py --luau /path/to/luau --compiler /path/to/luau-compile
```

The automated run passes <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:f2c98f1a34e1b743b455377d4f760c1ab11c56278aad41e7090f4e348d54fb01 -->

**69 scenarios**

<!-- /coderabbit-ai-generated:v1 --> across the three plugins, including 12 CineForge model, 5 player, <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:c960c190ea8972784f8efdc722bad40c7013faa9f2832e39d204a913db5b373c -->

4 generator, 1 editor interaction and 1 client scenario

<!-- /coderabbit-ai-generated:v1 -->. All Luau compiles; XML package source and hierarchy checks pass. The mocked player checks camera restoration, scene sampling, preview clones, runtime actor restoration and completion.

**Roblox Studio is unavailable in the Linux sandbox.** Actual editor layout and drag behavior, Studio camera restoration, animation loading and permissions, live effects, generated gameplay, asset metadata queries, Undo/Redo and multiplayer have not been verified in Studio. The test harnesses simulate Roblox APIs and cannot establish those native behaviors.

Suggested Studio checks: install locally, preview the example and verify the original camera is restored; capture a rotated camera and compare the preview; scrub and drag keyframes; test each easing and FOV/effect transition; add a rig and permitted animation, scrub and play; validate broken timestamps and missing asset IDs; export/import and Undo/Redo generation; run the generated example for two clients; confirm local completion and server-triggered playback.
