# Small World Prototype

An asset-free Godot 4 prototype centred on `18.690209, 82.834109` near Jharaput,
Koraput, Odisha. It generates a stylized 2 × 2 km world covering a 1 km radius,
using mapped road geometry, sampled terrain elevation, mapped villages and
landmarks. It also includes an NPC, inventory, money, cigarette purchasing, and
a simple smoke particle interaction.

Roads and mapped places are derived from OpenStreetMap data under ODbL:
© OpenStreetMap contributors. Elevation samples are from the SRTM90m dataset
via OpenTopoData. Village buildings are intentionally approximate because no
building footprints are currently mapped in this area.

## Run

1. Install Godot 4.3 or newer.
2. Import `project.godot` from this folder.
3. Press **F6** or **F5** to run.

## Controls

- **WASD** — move
- **Shift** — run on foot / boost bicycle
- **Space** — jump
- **Mouse** — look
- **E** — interact with the shop or neighbour
- **F** — smoke one cigarette
- **I** — open or close inventory

## Bicycle

A rideable bicycle is parked beside the exact coordinate spawn. Press **E** to
mount or dismount, **W/S** to pedal, brake, or reverse, and **A/D** to steer.
- **Esc** — release the mouse

All visuals are generated at runtime, so there are no external assets to import.
