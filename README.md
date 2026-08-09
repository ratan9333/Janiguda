# Semiliguda

An original open-world game set in the real Sunabeda / Koraput area of Odisha,
India. Built in Godot 4.7. Inspired by the build-a-business gameplay loop of
Schedule I, told with a local village setting.

Fresh start centred on **HAL Stadium, Sunabeda** — world origin `(0,0,0)` is
`18.724522, 82.826247`.

## Scenes

Run a scene with **F6** (or F5 for the project's main scene, HalMain).

- `scenes/HalMain.tscn` — the real-world base: OSM roads + building footprints,
  SRTM terrain, the real HAL Stadium footprint (225 × 221 m). Free-fly survey
  camera to inspect it.
- `scenes/CharacterTest.tscn` — character turntable + pose viewer.
- `scenes/Playground.tscn` — greybox course to test movement feel.

## World data

- `data/hal_stadium_osm.json` — real geometry from OpenStreetMap
  (© OpenStreetMap contributors, ODbL).
- `data/hal_stadium_elevation.json` — SRTM 90 m elevation samples via
  OpenTopoData.

Landmarks are hand-built to real scale using the mapped footprints and photos
as reference. 1 Godot unit = 1 metre.

## Structure

- `scripts/hal_world.gd` — generates terrain, roads, footprints from the data.
- `scripts/hal_main.gd` — scene bootstrap (environment, sun, camera, HUD).
- `scripts/character_*.gd` — character rig (auto-loads a model, box fallback),
  controller (movement feel), preview.
- `scripts/post_fx.gd` — post-processing upgrade applied in place.
- `assets/` — Blender/Mixamo exports go here (see the character pipeline).

Reusable interaction patterns kept for later wiring: `bicycle.gd`, `shop.gd`,
`cigarette_pickup.gd`.
