# RogueChess — chess roguelike deckbuilder (MVP)

Godot 4.7 · GDScript · desktop · offline. Spec: [docs/SPEC.md](docs/SPEC.md) · Decisions: [docs/DECISIONS.md](docs/DECISIONS.md) · Plan: [docs/PLAN.md](docs/PLAN.md) · API: [docs/API.md](docs/API.md) · Screenshots: generated locally into `docs/screenshots/` (see below; not tracked)

## Play
Open the folder in Godot 4.7 and press Play, or:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## Controls
Everything works with the mouse; every menu screen also works from the keyboard.

Game keys are **remappable** in Settings → Controls (click a key, press the new one; Esc cancels, a key already in use swaps with it, "Reset keys" restores the defaults). The defaults are below; key caps and tooltips always show the current key. Menu navigation (Tab, arrows, Enter, Esc) is fixed.

| Where | Keys |
|---|---|
| Anywhere | **F1** settings (toggle) · **Esc** opens settings when nothing else uses it (never in a match) |
| Run screens (HUD shown) | **D** deck · **C** collection |
| Menus | **Tab / arrows** move focus (brass ring; dashed ivory ring on tiles) · **Enter / Space** press · **Esc** closes an overlay (settings, deck, collection, the shop's card-removal chooser) |
| Set select · artifact select | **1–9** pick / toggle a tile |
| Map | **← →** (or ↑ ↓) choose a next stop · **Enter** travel · **1–3** travel directly (numbers are shown on the nodes) |
| Roster | **Enter** on a benched piece (or the king) picks it up: **arrows** move the square cursor over your deploy squares, **Enter** places, **Esc** puts it back · **Enter** on a placed piece benches it |
| Reward | **1–3** take a card · arrows + **Enter** on a card |
| Shop · coaching | **1–9** jump to an offer's button, **Enter** buys / accepts |
| Match | **1–5** select a card (a Scout plays at once) · **E / Space** end turn · **R** redraw · **Esc** / right-click cancel · **Y / Enter** escape check · **N** stay · hold **Shift** to hurry the opponent's turn |

Settings (master / music / effects / interface volume, mute, animation speed Normal / Fast / Instant, reduced motion, screen shake, window / fullscreen, large text, key bindings) apply at once and are saved to `user://settings.json` (same folder as `meta.json`, below; slider moves are written once the slider rests, on release and when the panel closes). Delete it to restore the defaults from `config/ux.json`. During a run the settings panel also offers **Leave run…** (asks first): the run is dropped and the title opens; unlocks already earned stay.

## Test
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --import
/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json
```
Tests never write your `user://settings.json` or `user://meta.json`. Every test process writes only to its own folder, `user://test_tmp/p<pid>/` (`tests/hooks/test_tmp.gd`), so several GUT runs, the sim and the screenshot tool can run at the same time without sharing settings, meta files or run logs. A GUT pre-run hook (`tests/hooks/gut_pre_run.gd`, registered in `.gutconfig.json`) points the `Settings` autoload at `settings.json` in that folder (defaults from `config/ux.json`) before any test runs, and the post-run hook deletes the folder. Unit tests that change settings use their own file in it; the UI driver (`tests/integration/ui_helpers/ui_driver.gd`) gives every integration test a fresh settings file in its temp folder and runs matches at animation speed **Fast** (every animation still plays) — `test_ui_check_escape.gd` runs at **Normal** to cover the real timings. (The autoload still reads the real file once at engine start, before any hook can run; it never saves it.)

`test_ui_full_run.gd` plays a whole first run through the UI. It is deterministic per seed (all game randomness comes from seeded RNGs, never from animation timing). Each seed attempt gets its own temp folder, and the test checks that it holds exactly one run log, for that seed. Run it alone with `-gselect=test_ui_full_run`; `UI_RUN_SEED=N` tries only seed N.

100 simulated full runs (bot plays both sides; exit code 0 = no crashes, illegal states or softlocks; meta, logs and settings go to `user://sim/cli_p<pid>/`, removed at the end):
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless -s tools/sim/run_sim.gd -- --runs=100 --seed=1
```

## Screenshots
Regenerate them (opens a window; takes a few minutes; uses temp meta, logs and settings at Normal animation speed in `user://screenshot_tmp/p<pid>/`):
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . res://tools/screenshots/take_screenshots.tscn
```
- `docs/screenshots/NN_*.png`: every screen and overlay at the 1280×720 base canvas, including settings (title and match), keyboard focus on the map and in the deck overlay, and a hovered card. Effects (capture, shield block, explosion, opponent escape) are caught on their own sound cue.
- `docs/screenshots/1080p/`: title, settings, map, roster, match, escape prompt, reward, shop, run end, set select, coaching, deck view, artifact select and the roster with its keyboard square cursor as a 1920×1080 window shows them (the 1280×720 canvas scaled 1.5×, as stretch mode `canvas_items` does).
- `docs/screenshots/16x10/`: the same subset in a 1280×800 window, where aspect `expand` makes the canvas 1280×800.
- `docs/screenshots/large_text/`: the base 1280×720 pass with the Large text setting on (a clipping check), made by adding `-- --large-text` to the command above (only that folder is rewritten).
- `docs/screenshots/frames/<name>_NN.png`: motion frame sequences — `player_capture`, `explosion`, `card_play_energy`, `turn_banner` (match), and `settings_open`, `map_travel`, `coaching_accept`, `deck_open`, `run_end_victory` (menus).

The tool is `tools/screenshots/take_screenshots.gd` (the runs), `shot_stage.gd` (viewport per window size, capture, waits) and `shot_moments.gd` (crafted match moments and frame sequences).

## Layout
- `config/*.json`: every number (values, prices, energy, AI, map, unlocks).
- `scripts/core/`: pure-logic rules engine (`match/`), AI (`ai/`), run state machine (`run/`), unlocks and logs (`meta/`). No nodes.
- `scripts/ui/`, `scenes/`: screens and widgets.
- `tests/`: GUT unit and UI-driven integration tests. `tools/sim/`: the headless bot.

Unlocks are saved to `user://meta.json` and run logs to `user://logs/` (macOS: `~/Library/Application Support/Godot/app_userdata/RogueChess/`). To reset progress, delete `meta.json`.
