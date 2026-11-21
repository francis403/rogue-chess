# RogueChess — chess roguelike deckbuilder (MVP)

Godot 4.7 · GDScript · desktop · offline. Spec: [docs/SPEC.md](docs/SPEC.md) · Decisions: [docs/DECISIONS.md](docs/DECISIONS.md) · Plan: [docs/PLAN.md](docs/PLAN.md) · API: [docs/API.md](docs/API.md) · Screenshots: [docs/screenshots/](docs/screenshots/)

## Play
Open the folder in Godot 4.7 and press Play, or:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## Test
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --import
/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json
```
100 simulated full runs (bot plays both sides; exit code 0 = no crashes, illegal states or softlocks):
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless -s tools/sim/run_sim.gd -- --runs=100 --seed=1
```
Regenerate screenshots of every screen (opens a window):
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . res://tools/screenshots/take_screenshots.tscn
```

## Layout
- `config/*.json`: every number (values, prices, energy, AI, map, unlocks).
- `scripts/core/`: pure-logic rules engine (`match/`), AI (`ai/`), run state machine (`run/`), unlocks and logs (`meta/`). No nodes.
- `scripts/ui/`, `scenes/`: screens and widgets.
- `tests/`: GUT unit and UI-driven integration tests. `tools/sim/`: the headless bot.

Unlocks are saved to `user://meta.json` and run logs to `user://logs/` (macOS: `~/Library/Application Support/Godot/app_userdata/RogueChess/`). To reset progress, delete `meta.json`.
