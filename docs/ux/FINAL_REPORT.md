# UX polish pass: final report

Status: **stopped after iteration 4 of 8 (usage limit). The exit criteria are NOT fully met.** Critique 3 (the last critic pass, before the iteration-4 fixes) had 11 lines at 4.0, all others at 4.5, none below 4, and none at 5. Iteration 4 targeted all 11, but no fresh critic has re-scored the build, and the "two consecutive critic passes agree" criterion has not been run.

## Verification (final, after iteration 4)
| Check | Result |
|---|---|
| `--headless --import` | clean |
| GUT, run 1 / run 2 | 395/395, 395/395 (≈31 s each; baseline was 283) |
| Sim, 100 runs, seed 1 | PASS |
| `tools/audio/check.py` | all checks passed (12.9 MB audio) |
| Screenshot tool, default + `--large-text` | rc 0; 141 + 41 shots; no script errors. One exit warning ("2 ObjectDB leaked / 1 resource in use"), a known limitation by user decision (title Quit and the tool keep `get_tree().quit()`) |
| `git diff --stat 6001818 -- scripts/core config` | only `config/ux.json` (new UX tunables) |

## Critic scores across passes
| Pass | Lines < 4 | Lines at 4 | Cohesion | Delight |
|---|---|---|---|---|
| Critique 1 | 11 at 3.5 | many | 4.5 | 3.5 |
| Critique 2 | 0 | 24 | 4.5 | 4 |
| Critique 3 | 0 | 11 | 4.5 | 4 |
Full tables and evidence: `docs/ux/critique_1.md`, `critique_2.md`, `critique_3.md`.

## What changed
- **Look:** refined "club room at night" theme with a spacing and type scale (`theme/metrics.gd`), AA contrast fixes, shape-coded board marks (dot = move, ringed = capture, brackets = movable, frame = gives check), shield badge, dashed burn arc, a CHECK tag, sunk unplayable cards, a board legend, captured-piece trays, a title backdrop with light sweep, map node states with captions on plates, artifact emblems, centred menus, a run-end payoff, consistent focus rings. Before/after: `git show 6001818:docs/screenshots/<name>.png` vs `docs/screenshots/`.
- **Feel:** one timing vocabulary (`config/ux.json` → `motion`, read via `Motion.time()`), card hover/select/drag-to-play/fly/deal, piece pickup/hop/land by weight, hit-stop on captures/explosions/check, knock-away shards, score flare, shield bounce, one-beat explosions, fire embers/smoke, promotion swap, a turn banner wipe, opponent card reveal, hurry (Shift or click), match-over reason headline with count-up, screen transitions, map travel walk.
- **Sound:** 44+ procedurally synthesized sounds with variants (`tools/audio/generate.py`), ~2-minute sectioned music loops, the `Sfx` autoload (voice pools, cooldowns, jitter, no-repeat variants, steal fade, stinger exclusivity, music ducking), buses Master/Music/SFX/UI, auto button sounds.
- **Accessibility:** a settings panel (volumes, mute, animation speed Normal/Fast/Instant, reduced motion, screen shake, window mode, Large text, key remapping), InputMap actions `rc_*`, full keyboard play including the roster cursor and map, a colour-blind check (Machado CVD sim, recorded in UX_DECISIONS), ≥12 px text.
- **Code:** match_screen split into `match/match_fx.gd`, `match_view.gd`, `match_over_panel.gd`; `Feel`/`A11y`/`Motion` helpers; per-process temp folders for tests and tools; per-draw allocations removed.

## Where things live
- Settings: `user://settings.json` (macOS: `~/Library/Application Support/Godot/app_userdata/RogueChess/`). Defaults: `config/ux.json` → `settings_defaults`.
- Regenerate sounds: `python3 -I tools/audio/generate.py`, then `python3 -I tools/audio/check.py` and `Godot --headless --import`. Mix levels: `config/ux.json` → `audio` (no regeneration needed).
- Decisions: `docs/UX_DECISIONS.md`. Event map: `docs/ux/feedback_map.md`. Sound hooks: `docs/ux/sound_hooks.md`.

## Known limitations
- Sound is verified only by measurement, never by ear or on laptop speakers.
- Exit leak warning on the title Quit button and the screenshot tool (user's choice to keep `get_tree().quit()`).
- The opponent-escape toast covers the player's back rank for 2.4 s (lead call).
- Iteration-4 frames not reviewed: coaching_accept, run_end_victory, the 16x10 set. `24_run_end_victory.png` is captured mid-reveal (sealed "?"), and the "×4" group badge overlaps the bottom of the Bishop mini card there.
- No logic bugs found in core.

## Next steps to reach the exit criteria
1. Run a fresh critic (`docs/ux/critique_4.md`) using the same brief as critique 3; fix anything still below 4.5; then a second fresh critic must agree.
2. Review the unreviewed iteration-4 frames and the 16x10 / large_text sets; fix the ×4 badge overlap on run-end mini cards; let the screenshot tool wait for the run-end reveal.
3. Listen to every sound on laptop speakers and headphones; tune the `db` values in `config/ux.json`.
4. Playtest 30+ minutes at Normal and Fast speed, keyboard-only and with reduced motion on.
5. Optional: route the title Quit button through `Sfx.quit()` if the exit warning matters.
