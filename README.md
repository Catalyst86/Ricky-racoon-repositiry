# Ricky's Rants - 3D Studio

A Godot 4.6 recreation of the "Ricky's Rants" podcast studio set. Room, stage, mezzanine, neon sign, and lighting are authored procedurally in GDScript; all props (desk, chairs, busts, skyline miniatures, workbench, bookshelves, etc.) and **Ricky himself** are generated on demand via the Meshy text-to-3D + rigging API.

Ricky the raccoon stands behind the news desk and can be programmed to walk around — see `scripts/director.gd` for the patrol demo, or call `ricky.walk_to(Vector3(x,y,z))` from your own code.

## Quick start

1. **Generate props** (takes 15-40 min total, ~25 parallel tasks):
   ```bash
   python meshy/generate_assets.py
   ```
   GLBs land in `assets/models/`. Re-run anytime — already-downloaded files are skipped. To regenerate a single asset, delete its GLB and re-run with that name: `python meshy/generate_assets.py curved_desk`.

2. **Generate Ricky** (the raccoon host, ~5-10 min):
   ```bash
   python meshy/generate_character.py
   ```
   This does text-to-3D → refine (with PBR textures) → rigging, producing `ricky.glb`. If Meshy's rigging endpoint rejects the request on your tier, it leaves `ricky_unrigged.glb` that you can rig externally (Mixamo, Blender) and save as `ricky.glb`.

3. **Open in Godot 4.6+**. The scene is **fully editable** — everything in the room is either already a real node or one click away:
   - Select `StudioBuilder` in the scene tree → Inspector → click **"Rebuild Studio"**. The room, stage, mezzanine, neon sign, trusses, and lighting all populate as real editable nodes.
   - Select `Props` → click **"Rebuild Props"**. Every Meshy prop instantiates as a child node with its GLB mesh inside — drag/rotate/scale freely from the 3D viewport.
   - Select `Ricky` → click **"Spawn Editor Preview"** to see his T-pose in the viewport so you can position him.
   - **Ctrl+S to save** — all generated nodes are now permanent scene nodes.
   - After baking, press **F5** to play.

4. **Further editing** is pure Godot: click any node in the 3D viewport, use the standard Move/Rotate/Scale gizmos (W/E/R). The procedural scripts only populate the tree — they don't fight your edits once baked.

## Controls

### Flat-screen
- **WASD** - walk
- **Mouse** - look
- **Space** - jump (onto stage, etc.)
- **Shift** - sprint
- **Esc** - release mouse (click to re-capture)

### VR (OpenXR — Quest, Index, Vive, WMR, Pico, etc.)
- **Left thumbstick** - smooth move (relative to head direction)
- **Right thumbstick (left/right)** - snap turn 30°
- **Either grip** - sprint
- Headset / room-scale movement works as expected (you walk physically)

#### VR setup
1. Make sure your headset's OpenXR runtime is **active**:
   - **SteamVR**: Settings → OpenXR → "Set as active OpenXR runtime"
   - **Meta (Link / AirLink)**: Oculus PC app → Settings → General → "Set as active OpenXR runtime"
   - **WMR**: Mixed Reality Portal does this automatically
2. Plug in your headset and put it on
3. Press **F5** in Godot — the autoload (`scripts/xr_init.gd`) detects OpenXR and switches to VR. If no headset is found, it falls back to flat-screen.
4. The VR rig (`VRPlayer` in the scene) spawns at the audience side (z=6.5). Walk physically or thumbstick toward the stage.

If VR doesn't kick in, check the **Output** panel for `[xr]` lines — they'll tell you whether OpenXR initialized and why not.

The player is a `CharacterBody3D` capsule (0.32m radius, 1.75m tall) with gravity. Everything solid in the scene has collision:
- Floor, walls, stage, mezzanine underside, back-wall panels (procedural geometry)
- Every Meshy-loaded prop (AABB box collider per GLB)
- Mic bases/stands on the desk

## Layout

```
scenes/
  main.tscn          - root; WorldEnvironment + StudioBuilder + Props + Player
  default_env.tres   - warm volumetric tone, SSAO, glow, orange fog
scripts/
  studio_builder.gd  - builds room, wood panels, stage, mezzanine, brass railings,
                       neon sign, trusses, spot/omni lights, desk mics; post-pass
                       wraps every solid mesh with a StaticBody3D collider
  prop_loader.gd     - reads assets/models/*.glb; auto-scales each to target size,
                       adds AABB box collider (unless no_collide: true); drops
                       placeholder boxes + colliders for missing GLBs
  player.gd          - first-person walker (CharacterBody3D + capsule)
  ricky.gd           - Ricky the raccoon character. Loads ricky.glb (rigged) or
                       ricky_unrigged.glb at runtime. Exposes walk_to(Vector3)
                       and stop(). Drives AnimationPlayer clips named "walk"/
                       "idle" when available; procedural bob otherwise.
  director.gd        - demo script that patrols Ricky behind the desk. Edit the
                       WAYPOINTS array or replace to script different scenes.
meshy/
  generate_assets.py - parallel Meshy client; resumes from tasks.json
  tasks.json         - persistent state (task IDs, download status)
assets/
  models/            - downloaded GLBs (Meshy output)
  textures/          - reserved for future texture overrides
```

## Programming Ricky

Call the character's API from any script. Example:

```gdscript
var ricky = get_node("/root/Main/Ricky")
ricky.walk_to(Vector3(-1.2, 0.35, -2.0))    # send him behind the desk
await get_tree().create_timer(3.0).timeout
ricky.walk_to(Vector3( 2.0, 0.0,  3.0))     # over to the guest chair
if ricky.is_walking(): print("Ricky is moving")
ricky.stop()
```

Properties on `Ricky` (all `@export`):
- `target_height` — scales the GLB so the raccoon is this tall in meters (default 1.4)
- `walk_speed` — m/s (default 1.8)
- `turn_speed` — rad/s yaw slerp (default 6.0)
- `arrival_tolerance` — distance in m that counts as "arrived" (default 0.25)
- `initial_position` — spawn spot (default behind desk at `(0, 0.35, -2.1)`)
- `initial_yaw_deg` — facing direction on spawn (default 180° = facing camera)

If `ricky.glb` has an `AnimationPlayer` with clips named `walk` / `idle` (or any clip containing those substrings), the controller drives it automatically. Without animations, it uses a procedural head bob.

## Adjusting props

Edit the `PLACEMENTS` dict in `scripts/prop_loader.gd`. Each entry:
```gdscript
"key": { "file": "glb_filename_without_ext",  # optional, defaults to key
         "pos": Vector3(x,y,z),
         "rot_deg": Vector3(pitch,yaw,roll),  # degrees
         "size": 1.5,                          # longest-axis meters
         "no_collide": true }                  # optional: skip adding a collider
```

The loader measures the GLB's AABB and scales so its longest axis equals `size`.
Props on the mezzanine (and other out-of-reach decoration) are set `no_collide: true` so they don't generate unnecessary physics shapes.

## Lighting rig

Studio-style adjustable lights live under the `LightingRig` node in the scene. Two fixture types:

- **`scenes/lights/spotlight_truss.tscn`** — horizontal truss bar with 4 spotlights mounted underneath, all driven by one set of Inspector knobs. Includes a collision shape so it acts solid in physics.
- **`scenes/lights/floor_light.tscn`** — tripod stand with a single steerable head.

### Adjusting in the editor

1. Click any light fixture in the scene tree (e.g. `LightingRig/TrussCenter`).
2. In the Inspector you'll see properties from `light_fixture.gd`:
   - **Light Color** — gel/temperature
   - **Energy** — brightness (0–50)
   - **Cone Angle Deg** — spot cone width (5–90°)
   - **Light Range** — falloff distance (1–50m)
   - **Cast Shadows** — on/off
   - **Enabled** — kill switch (also dims the housing glow)
3. Move the whole fixture with the W/E/R gizmos in the viewport. The lens, shadows, and spill update live.
4. **Duplicate** any fixture (Ctrl+D) to add more — they're scene instances so all 4 spots in a truss inherit edits to the master scene.

### Aiming individual spots inside a truss

Each truss instance has 4 child `Light1`–`Light4` nodes. Click any of them and rotate to aim that one spot independently of the bar. The fixture script still drives the SpotLight3D's color/energy/etc.

### Adding more racks

Right-click `LightingRig` in the scene tree → **Instantiate Child Scene** → pick `spotlight_truss.tscn` or `floor_light.tscn`. Position it. Done.

## Adjusting the room

Two ways to edit:

**Direct viewport editing (recommended)** — after clicking "Rebuild Studio" once and saving, every piece of the room (floor slab, wall panels, stage, mezzanine slabs, brass rails, neon sign, track lights, etc.) is a selectable node. Click it in the scene tree or viewport, drag it with the Move gizmo, scale it, change materials in the Inspector. Normal Godot editing.

**Regenerate from code** — if you want to tweak the procedural parameters (room dimensions, palette, stage radius, number of spot lights, etc.), edit constants at the top of `scripts/studio_builder.gd`, click "Clear Studio", then "Rebuild Studio". Note this wipes any manual edits you made to the generated nodes.

## Re-prompting an asset

Edit the prompt in `ASSETS` in `meshy/generate_assets.py`, delete the corresponding `.glb` from `assets/models/`, remove its entry from `meshy/tasks.json`, then re-run the generator.
