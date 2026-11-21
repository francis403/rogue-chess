# Plan — Chess Roguelike Deckbuilder MVP

Spec: [SPEC.md](SPEC.md) · Assumptions: [DECISIONS.md](DECISIONS.md) · Engine/run API: [API.md](API.md) (written by the engine and run owners)

## Architecture

```
config/*.json              all numbers (PM owns; owners may add keys, never hard-code numbers)
scripts/core/data/         GameConfig, CardData, PieceData           (PM, shared, pure)
scripts/core/match/        rules engine: board, moves, deck, match   (Engine, pure, no nodes)
scripts/core/ai/           MatchAI                                   (AI, pure)
scripts/core/run/          run session, map, shop, coaching, rewards (Run, pure)
scripts/core/meta/         unlocks persistence, run logger           (Run, pure, file I/O only)
scenes/, scripts/ui/       every screen + game feel                  (UI / UX)
tools/sim/                 headless 100-run bot                      (Test engineer)
tests/unit/<area>/         GUT tests per area                        (each owner)
tests/integration/         full-run and cross-module tests           (Test engineer)
```

Key seams (keep them stable; changes must be noted in API.md):
- `ChessMatch.new(setup: Dictionary)` → actions `play(card_index, from, to)`, `redraw()`, `end_turn()`; queries for UI/AI; `result()` when over. Every action returns a list of event dictionaries the UI animates.
- `RunSession` owns the run state machine. It *builds* a match setup (`build_match_setup(roster)`) and *consumes* a match result (`finish_match(result)`); it never runs a match itself, so the UI and the sim bot drive matches the same way.
- `MatchAI.new(side, depth, random_chance, rng).choose_action(match) -> Dictionary` (`{"kind": "play", card_index, from, to}` / `{"kind": "redraw"}` / `{"kind": "end_turn"}`).

## Milestones

| # | Milestone | Owner | Depends on | Status |
|---|-----------|-------|------------|--------|
| M0 | Repo, GUT, config files, data classes, docs | PM | – | done |
| M1a | Rules engine + tests (every match rule, artifacts, Fire, shields, explosions, holes) | Engine agent | M0 | done, reviewed, fixed |
| M1b | Run layer: map, economy, rewards, shop, coaching, roster/budget, unlocks, persistence, logs + tests | Run agent | M0 | done, reviewed, fixed |
| M2a | AI opponent + sim bot + tests | AI agent | M1a | done, reviewed, fixed (king safety D55) |
| M2b | UI: all screens, match screen, game feel | UI agent | M1a, M1b | done, reviewed, fixed |
| M3 | Sim bot (100 runs), UI-driven integration tests, independent review, screenshots of every screen | Test engineer, Reviewer, PM | M2 | done |
| M4 | Fix loop until "Done" passes | owners | M3 | done: 3 review rounds, 0 open findings |

## Verification gate (after each milestone)
1. `godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json` — all green.
2. `godot --headless -s tools/sim/run_sim.gd -- --runs=100` — 0 crashes, 0 illegal states, 0 softlocks.
3. Reviewer (did not write the code) audits against SPEC + DECISIONS.
4. Screenshots of every screen (`tools/screenshots/`) reviewed by the PM.

## Commands
```
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --headless --import                       # refresh class_name cache after adding classes
$GODOT --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/match -gexit
```
