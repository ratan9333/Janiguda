# Janiguda

Open-world map of **Sunabeda / Koraput, Odisha**, in Godot 4.7.

World origin `(0,0,0)` is **18°43'28.36"N 82°49'35.57"E** — the centre of HAL
Stadium — at ground level. **1 Godot unit = 1 metre.**

## Run

Press **F5**. You spawn on the stadium field, standing on the world origin.

| Key | |
|---|---|
| `W A S D` | move (relative to the camera) |
| `Shift` | sprint — **20× walk speed (3 → 60 m/s)**, ×4 flying |
| `Space` | jump / fly up |
| `Ctrl` | fly down |
| `V` | third person ↔ first person |
| `F` | walk ↔ fly — the quick way to cross 4 km |
| `Esc` | release the mouse · click to recapture |

## What's in the map

4 × 4 km centred on the stadium, built in Blender (`../JanigudaBlender`) and
exported to `world/`.

| Layer | Source |
|---|---|
| Terrain | SRTM/NASADEM ~30 m, resampled to a 15.6 m grid — 137 m of relief |
| Ground texture | Esri World Imagery at 1.13 m/px, draped via UVs |
| Roads | OSM — 123 km of centreline, real lane counts, 2,917 lane-divider dashes |
| Medians | 90 paired-carriageway stretches (9.5 km) with 2,767 bushes |
| Street lights | 432 — twin-arm on medians, single-arm on undivided roads |
| Stadium | OSM footprint + photos — 13-row terraced stand, compound wall, 3 gates |
| Buildings | 83 real Overture ML footprints in the 250 m core |
| Vegetation | 31,135 trees + 103,222 grass clumps, placed by satellite canopy mask |

Building **outlines** are real; their heights, roofs, shopfronts, compound
walls, gates and footpaths are inferred — no open dataset maps those here (OSM
has zero buildings, barriers, shops or footways within 300 m of the stadium).

## Structure

- `scenes/Main.tscn` — environment, sun, world. Main scene.
- `scenes/Player.tscn` — rigged human character with spring-arm camera.
- `scripts/world.gd` — loads the map, builds collision and vegetation, spawns
  the player. Has `latlon_to_world()` — use it for any further GPS/OSM data so
  it lands in the same frame.
- `scripts/player.gd` — movement. Reads physical keys directly, so there is no
  InputMap to configure.
- `world/` — `map.glb` plus the vegetation instance buffers.

## Character

`assets/characters/soldier.glb` — Mixamo's "Vanguard", taken from the three.js
examples repo. 1.83 m tall, rigged, with `Idle` / `Walk` / `Run` clips that
`player.gd` drives from ground speed. Mixamo assets are royalty-free to use in
your own projects but not to redistribute standalone — grab your own from
mixamo.com (free Adobe account) before shipping anything.

Sprint is `WALK_SPEED × SPRINT_MULTIPLIER` in `player.gd`. It is set to **20**,
i.e. 60 m/s / 216 km/h, which is what was asked for but is far beyond human —
lower the multiplier there for something believable (3–4 is a realistic sprint).

## Notes

- **Vegetation has no collision** — you walk through trees and grass. Per-tree
  bodies would cost far more than they're worth; add trunk capsules if needed.
- Collision is trimesh generated at load (~250k triangles, about half a second).
  To make it instant, set `world/map.glb` to generate collision on import and
  drop the `_add_collision()` call.
- `GRASS_RANGE` (130 m) and `TREE_RANGE` (1400 m) in `world.gd` are the first
  knobs if the framerate suffers.
- Camera far plane is 8000 m — Godot's 4000 m default clips a 4 km tile.
- `world/map.glb` is 43 MB and **is** tracked by git. Consider Git LFS, or
  ignore it and re-export from Blender with `terrain/export_godot.py`.

## Re-exporting the map

Run `terrain/export_godot.py` inside Blender (`../JanigudaBlender`), then copy
`godot/*.glb` and `godot/*.bin` into `world/`.
