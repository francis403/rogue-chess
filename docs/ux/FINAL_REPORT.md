# UX polish pass: final report

Status: **exit criteria met.** Two consecutive fresh, independent critics (critique 5 and critique 6) scored every rubric line ≥ 4.5, with none below 4, and the minor items critique 6 left open were fixed afterwards ("Final fixes" in UX_DECISIONS). The only remaining item is a by-design scroll (see "Open items").

Branch: `iteration-1-king-move-on-check-ux-improvements` (follow-up on top of PR #1 and the opponent-hand feature from PR #3). Nothing committed by the agents.

## Verification (final)
| Check | Result |
|---|---|
| `--headless --import` | clean |
| GUT, run 1 / run 2 | 451/451 both, 37 test scripts loaded, no SCRIPT ERROR (baseline before the pass: 283) |
| Sim, 100 runs, seed 1 | PASS (0 crashes, illegal states or softlocks) |
| `tools/audio/check.py` | all checks passed |
| Screenshot tool, default + `--large-text` | rc 0; 172 + 46 images; only the accepted exit-leak warning |
| `git diff --stat 49feac6 -- scripts/core` | empty. Config: only `config/ux.json` (UX tunables) |

## Critic scores across passes
| Pass | Lines < 4 | Lines at 4 | Lines ≥ 4.5 | Cohesion | Delight |
|---|---|---|---|---|---|
| 1 | 11 (3.5) | many | few | 4.5 | 3.5 |
| 2 | 0 | 24 | rest | 4.5 | 4 |
| 3 | 0 | 11 | rest | 4.5 | 4 |
| 4 | 0 | 5 | rest | 4.5 | 4 |
| 5 | 0 | 0 | all 75 (4.5) | 4.5 | 4.5 |
| 6 | 0 | 0 | all 75 (five at 5: set select clarity, polish, a11y; escape prompt clarity; reward clarity, polish; deck clarity) | 4.5 | 4.5 |
Full tables and evidence: `docs/ux/critique_1.md` … `critique_6.md`.

## What changed (whole pass)
- **Look:** refined "club room at night" theme (spacing and type scale in `theme/metrics.gd`, AA contrast), shape-coded board marks (dot = move, ringed = capture, brackets = movable, frame = gives check), shield badge, dashed burn arc, CHECK tag, sunk unplayable cards, a board legend, captured-piece trays, a title backdrop with light sweep, map node states and caption plates, artifact emblems, centred menus, grouped ×N decks, a run-end payoff with a charging unlock seal, and focus rings distinct from "chosen". Before/after: `git show 6001818:docs/screenshots/<name>.png` vs the regenerated `docs/screenshots/` (now untracked; regenerate with the screenshot tool).
- **Feel:** one timing vocabulary (`config/ux.json` → `motion`, via `Motion.time()`). Cards hover, select, drag-to-play, fly to the destination and deal in. Pieces get pickup, hop and weighted landings, hit-stop beats, knock-away shards, a score flare, a shield bounce, one-beat explosions, fire embers and smoke, a promotion swap, a turn banner wipe, the opponent card reveal, the Scout flip reveal (text waits for the flips), Deep Vision / Trophy Case point attribution, hurry (Shift or click), a match-over reason headline, screen transitions and a map travel walk.
- **Sound:** ~50 procedurally synthesized ids with variants (`tools/audio/generate.py`), sectioned ~2-minute music loops, and the `Sfx` autoload (voice pools, cooldowns, jitter, no-repeat variants, steal fade, stinger exclusivity, music ducking, separate sounds for opponent captures and staying in check). Buses: Master/Music/SFX/UI.
- **Accessibility:** the settings panel (four volumes, mute, animation speed Normal/Fast/Instant, reduced motion, screen shake, window mode, Large text, key remapping), InputMap `rc_*` actions, full keyboard play (incl. the roster cursor and map), a colour-blind check (Machado sim in UX_DECISIONS), ≥12 px text.
- **Code:** the match screen split into `match/match_fx.gd`, `match_view.gd`, `match_over_panel.gd`; `Feel` / `A11y` / `Motion` helpers; per-process temp folders for tests and tools; no per-draw allocations; preloaded screens.

## How to run and tune
- Play: `Godot --path .`. Settings: `user://settings.json` (macOS: `~/Library/Application Support/Godot/app_userdata/RogueChess/`); defaults in `config/ux.json` → `settings_defaults`.
- Regenerate sounds: `python3 -I tools/audio/generate.py`, then `python3 -I tools/audio/check.py` and `Godot --headless --import`.
- **Listen:** `Godot --path . res://tools/audio/audition.tscn` plays every id in order (Space replays, Right skips, Esc stops; `-- <ids>` limits the list). Uses a temp settings file.
- Mix levels: `config/ux.json` → `audio` → `sounds.<id>.db` (no regeneration needed).
- Decisions: `docs/UX_DECISIONS.md`. Event map: `docs/ux/feedback_map.md`. Sound hooks: `docs/ux/sound_hooks.md`.

## Listening checklist (not yet done by anyone)
On laptop speakers and on headphones, at default volumes:
1. Hover and click spam on a menu (`ui_hover`, `ui_click`): should stay unobtrusive.
2. `ui_error`, `ui_cancel`, `check`, `check_stay`, `turn_player`, `turn_opponent`: audible on laptop speakers, not harsh.
3. `capture` vs `capture_against`: clearly different (yours vs theirs).
4. `explosion`, `piece_land_heavy`: weight without boom or clipping.
5. Stingers `victory`, `defeat`, `run_victory`, `run_defeat`, `unlock_fanfare`: music dips under them; no two overlap.
6. Both music loops for 10+ minutes: no audible seam, not tiring.
Adjust `db` values in `config/ux.json` as needed.

## Open items
- With Large text, the map's third next stop sits under a scroll bar (by design: the list scrolls rather than pushing the map off screen).

Fixed after critique 6 (verified in the screenshots and by the tests): the "−N pt" plate now hangs under the HUD points figure and never covers cards, coins or headings; the deck overlay balances its rows (7 → 4+3, 8 → 4+4); the played card's ghost flies under the pieces; a settled Scout still (`46_match_deep_vision_scout_settled`); the turn label is restored when a banner is freed; named `resized` handlers; and drift tests that check `EventText.bonuses` against real ChessMatch scoring.

## Accepted limitations
- Sound verified by measurement only (see the listening checklist).
- The title Quit button and the screenshot tool keep `get_tree().quit()` (user decision): a possible one-off exit-leak warning.
- The opponent-escape toast covers the player's back rank for 2.4 s (lead call).
- Large text replaces canvas UI scale; cards keep glyph-in-a-circle art by design.

## Next steps
1. Do the listening checklist and tune `db` values.
2. Playtest 30+ minutes: Normal and Fast speed, keyboard-only, reduced motion on, Large text on.
