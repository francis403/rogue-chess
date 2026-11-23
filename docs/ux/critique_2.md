# UX critique 2: independent review after iteration 2

**What I looked at:** every image: `docs/screenshots/01–41`, all nine `1080p/` shots, all nine `16x10/` shots and all 35 motion frames (`player_capture`, `explosion`, `card_play_energy`, `turn_banner`). I compared before/after pairs for `05_match_start`, `09_match_opponent_turn`, `11_match_over` and `31_artifact_select` (`git show HEAD:`). I read `docs/SPEC.md`, `docs/UX_DECISIONS.md`, `docs/ux/feedback_map.md`, `docs/ux/sound_hooks.md`, `config/ux.json` and `README.md`. In code I read `sfx.gd`, `match_fx.gd`, `match_screen.gd`, `main.gd`, `a11y.gd`, `feel.gd`, `settings_panel.gd` and `run_end_screen.gd`, and I grepped the rest of `scripts/ui/**`. I read `tools/audio/generate.py` (the UI, stinger and turn-chime voices) and ran `python3 -I tools/audio/check.py`, which reports "all checks passed" (12.81 MB in total). I ran headless import and the full GUT suite. I formed the scores before reading `critique_1.md`.

**Test suite: not green.** 359/360 pass. `tests/integration/test_ui_full_run.gd` fails, and it fails the same way when re-run alone:
- Seed 8 now loses the boss ("BOSS: lost by score, [1, 12] in 2 rounds"), so the test falls back to the next seed.
- The fallback run then finds 2 run logs where it expects 1 (`[2] expected to equal [1]: one run log written to the temp log folder`, line 60).

So either the UI pass changed the seeded run's outcome, or the fallback path never worked. Either way, the suite is red.

**Core untouched:** `git diff --stat scripts/core config` prints nothing. `config/ux.json` is untracked. **Met.**

**Overall verdict:** This is a solid iteration. Almost every critique-1 finding was actually fixed, and I checked each one against pixels or code. The menu screens are now composed rather than stranded. The match-over screen and the run end lead with meaning. The opponent's turn is legible. Sound fatigue was taken seriously. It is **not** at 4.5 everywhere yet. Several lines sit at 4 because of small but visible flaws:
- the translucent turn banner ghosts the header text;
- hand cards keep their "playable" look while it isn't your turn;
- map path lines strike through the node captions;
- the shop toast collides with its panel;
- the very dark error and check sounds are unverified on laptops;
- stingers stack after a loss;
- some buttons have no hover sound;
- there is still no remapping or UI scale.

## 1. Score table

| Screen | Clarity | Visual polish | Feel | Sound | Accessibility |
|---|---|---|---|---|---|
| Title | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Set select | 4.5 | **4** | 4.5 | 4.5 | 4.5 |
| Artifact select | **4** | **4** | 4.5 | 4.5 | **4** |
| Map | 4.5 | **4** | 4.5 | 4.5 | 4.5 |
| Roster | 4.5 | **4** | **4** | 4.5 | **4** |
| Match (normal) | **4** | **4** | 4.5 | **4** | **4** |
| Match (opponent turn) | 4.5 | **4** | **4** | 4.5 | **4** |
| Match (escape prompt) | 4.5 | 4.5 | 4.5 | **4** | 4.5 |
| Match over | 4.5 | 4.5 | 4.5 | **4** | 4.5 |
| Reward | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Shop | 4.5 | **4** | 4.5 | 4.5 | 4.5 |
| Coaching | 4.5 | **4** | **4** | 4.5 | **4** |
| Deck & collection views | 4.5 | **4** | **4** | 4.5 | 4.5 |
| Run end | 4.5 | **4** | 4.5 | **4** | 4.5 |
| Settings | 4.5 | **4** | 4.5 | 4.5 | **4** |

| Whole game | Score |
|---|---|
| Cohesion | 4.5 |
| Delight | **4** |

No line is below 4. There are 24 lines at 4 (bold), and none at 5.

## 2. Evidence per score

### Title (01, 30, 37, 1080p/01, 16x10/01)
- **Clarity 4.5.** New Game is the only filled button and has focus. The progress panel shows "1 / 2 unlocked" plus pips, and later the artifact names (30).
- **Polish 4.5.** It is the strongest composition in the game. It holds at 1080p (crisp 1.5× scale) and at 16:10, where the extra height is shared evenly. The progress panel is still slightly heavy.
- **Feel 4.5.** The piece row drops in. Ambient motion (light sweep, 2 px wave) is unscaled by speed, which is the right call for flicker.
- **Sound 4.5.** One `piece_land_light` knock as the row lands. The lounge loop is now 128 s in sections.
- **Accessibility 4.5.** Focus is on New Game, F1 works, and reduced motion stops the ambient loops.

### Set select (02, 25)
- **Clarity 4.5.** Worth tables, "Locked · Beat the boss to unlock", key caps and the hint "Enter or a number key picks a set".
- **Polish 4.** The tiles are equal height and Back sits under them, which is fixed. Still:
  - the Standard tile's body is half empty (y 380–455);
  - there is a ~90 px dead band between the subtitle and the tiles (110–200).
- **Feel 4.5.** Pop, a 0.22 s beat, then the next screen.
- **Sound 4.5.** `ui_confirm` / `ui_error`, plus a tile hover tick.
- **Accessibility 4.5.** Keys and ring. There is no persistent "chosen" state here, so the ring can't be mistaken for one.

### Artifact select (31)
- **Clarity 4.** Emblems were added, and chosen tiles get a tinted face and a "CHOSEN" chip. But the focused, unchosen Espresso tile still wears a solid brass outline that reads like the chosen tiles' 2 px brass border. At a glance you see three brass-bordered tiles under a "2 / 2 chosen" counter. The ring sits 3 px outside, but at 1280×720 that difference is about 2 px.
- **Polish 4.**
  - The "CHOSEN" chips are not aligned between tiles: Sinkholes y≈400, Powder Keg y≈389, because the title row moves with the description length.
  - The top-row tiles have a lot of empty interior.
  - There is still a ~120 px void above the tiles.
- **Feel 4.5.** Toggle pop.
- **Sound 4.5.** `ui_toggle`, `ui_confirm`, and `ui_error` at the limit.
- **Accessibility 4.** Same as Clarity: focus and chosen share the same colour and shape.

### Map (03, 13, 21, 38, 1080p/03, 16x10/03)
- **Clarity 4.5.** The "Then: Shop or Easy match" line tells identical first stops apart. The HUD says "Floor 1 of 7 · start". The tooltips are rich.
- **Polish 4.**
  - **Path lines run straight through the node captions** ("MEDIUM", "COACHING", "SHOP", "EASY" are struck through at x≈337/527/717 in 03; it is obvious at 1080p/03).
  - The map block is left-heavy, with a ~190 px empty column between it and the side panel at 720p and 16:10.
  - The bottom captions sit 18–27 px from the window edge (38: the selected node's caption at y 689), while the boss has ~80 px above it.
- **Feel 4.5.** The hop-travel and burst ring are described in code (not visible in stills). The halo now lives on its own layer.
- **Sound 4.5.** `map_travel`, plus a hover tick on reachable nodes only.
- **Accessibility 4.5.** Arrows, Enter, 1–3, an outer focus ring, and legend swatches drawn as mini nodes.

### Roster (04, 22, 26, 1080p/04, 16x10/04)
- **Clarity 4.5.** The ★ legend and the opponent's deck as mini cards. "8 pieces ready · 1 budget left".
- **Polish 4.**
  - The collection list is cut mid-row at the bottom (04 y≈670, 1080p/04 y≈1005).
  - The opponent column is empty from y≈580 down.
  - The opponent mini cards' cost coins are ~9 px.
- **Feel 4.** Place pop and weight-matched land sound. Placement needs a click per piece, and there is no drag preview evidence in the stills.
- **Sound 4.5.** Land sound by weight, `card_shuffle` on Auto.
- **Accessibility 4.** Enter places a piece only on the *first free* square. There is still no keyboard way to choose the square.

### Match, normal turn (05–08, 10, 27, 28, 32–34, 40, frames, 1080p/05, 16x10/05)
- **Clarity 4.** Fixed since critique 1:
  - the hand closes up and key caps renumber at once (card_play_energy_02);
  - "Redraw · won't help" (28);
  - the Fire ignite warning (27).

  New and remaining problems:
  1. **Hand cards keep their playable look whenever they're not playable.** `CardView.is_playable` is set only in `_sync_hand()` (`match_screen.gd:214`), which runs only after `_run()` ends. Two examples:
     - In 34, energy is 0/3 but Move/Move/Pawn still have raised faces, solid brass coins and ivory names.
     - In turn_banner_01–11 the held Knight looks playable for the whole opponent turn.
  2. Sinkholes holes (32) are not in the "Reading the board" legend.
  3. The "Took" tray and the score update only after the capture resolves (08), which is acceptable.
- **Polish 4.**
  1. **Effects still leave the board.**
     - Knocked-away explosion victims fly over the top frame (explosion_03/04: the knight token at y≈143, on the frame border).
     - The shockwave ring is clipped to `grid_rect().grow(Metrics.S)`, so it still paints 8 px of the frame (34, right edge).
     - The CHECK tag crosses the frame's bottom edge (36, 1080p/06, 16x10/06).
     - The check pulse ring spills below the board (16x10/06).
  2. The played card's ghost starts on top of its new neighbour (card_play_energy_01: "Kni…" hidden under the Rook ghost) and ends half outside the board over the rank label "2" (card_play_energy_04).
  3. The desk still has ~90 px of dead space between the hint and KEYS (05).
  4. "End turn (nothing playable)" runs into its "E" key cap (28: label ends at x≈1232, cap at 1246).
- **Feel 4.5.** The frames show a crisp sequence:
  - the card leaves the hand on the click frame;
  - the pips drain;
  - the capture plays crouch → hop → impact flash → knock-away with shards and "+3" in ≈0.6 s (8 frames at 0.09 s);
  - an explosion now resolves in one beat (both victims fly in explosion_02);
  - the board shake is visible (explosion_02: the board is offset 3 px);
  - control returns the moment the sequence ends (player_capture_08: End turn re-enabled).
- **Sound 4.** It is rich and well organised: 3 variants for repeated sounds, jitter, cooldowns, a 15 ms steal fade, and presence layers on capture, explosion, check and heavy land (`check.py` presence −11 to −13 dB). But:
  - **`ui_error` is a 170–207 Hz double knock** (centroid 203 Hz, presence −33.7 dB) and **`ui_cancel` has a centroid of 346 Hz** (presence −26.5 dB). On laptop speakers the refusal sound, which is half of the refusal feedback, will be close to inaudible.
  - The team itself writes "Not verified by ear on real laptop speakers yet".
  - The music centroid is 188 Hz (match) and 226 Hz (menu), so on laptops it will be thin.
- **Accessibility 4.** Fixed since critique 1: keyboard complete, physical-key letters, colour-blind cues (inner maple stroke on the capture ring, dashed burn arc, Cheaper arrow tab), a 12 px floor, and reduced motion. Still missing:
  - **no remapping** (hard-coded `KEY_E/R/Y/N/SPACE` in `match_screen.gd:_press_shortcut`, no InputMap actions);
  - no text or UI scale.

### Match, opponent turn (09, turn_banner_01–11)
- **Clarity 4.5.** The revealed card sits left of the rank labels (turn_banner_08). There is an oxblood source frame, a hollow target ring, "Rookie Rex plays Move" in the header caption and the hint, and real card backs.
- **Polish 4.** The banner moved off the board, which is fixed. But **its panel is 94 % opaque (`match_fx.gd:326`, `Color(WALNUT_DEEP, 0.94)`)** and it fades in and out over the live header. So the header's own "Rookie Rex's turn / Round 1 of 40 / You 0 / Rookie Rex 0 / 10" ghosts through it:
  - faintly while the banner is held (09, turn_banner_02–06);
  - as fully doubled text while it fades (turn_banner_01 and 07: "Rookie Rex's turn" twice, overlapping).

  The banner also only repeats what the header label beneath it already says.
- **Feel 4.** Each AI action is ≈ `move_delay` 0.45 + reveal 0.12–0.18 + `reveal_hold` 0.35 + crouch/move 0.34 ≈ 1.2–1.4 s. The first one also waits out the 0.58 s banner. A three-card opponent turn is still ~4 s at Normal: the slowest beat in the loop. It is legible but not snappy, and it can't be skipped or hurried (no "click to speed up").
- **Sound 4.5.** `turn_opponent` is now a 0.4 s tap at −14 dB. Opponent draws and refills are silent by design.
- **Accessibility 4.** Same as the normal turn. There is no way to pause the opponent while a settings or deck overlay is open (the opponent loop keeps animating behind the modal).

### Match, escape prompt (35, 36, 1080p/06, 16x10/06)
- **Clarity 4.5.**
  - The key line follows the state ("Click a square to escape · N stay" with several squares).
  - Check marks clear on escape (35: the d6 king carries no tag).
  - The cost line reads "Costs 1 energy from your next turn · next turn: 2/3".
  - The opponent-escape toast still covers your own back rank and king for 2.4 s (35). This is documented as a lead call, but it hides a1–c1.
- **Polish 4.5.** The prompt fits the desk and the board doesn't move.
- **Feel 4.5.** Hit-stop, pulse rings, prompt.
- **Sound 4.** `check` is a dark minor-second swell (centroid 188 Hz) with a D6 ping added for presence. It is tense and soft, but untested on small speakers.
- **Accessibility 4.5.** Words, the CHECK tag, keys, and a framed prompt.

### Match over (11)
- **Clarity 4.5.** It leads with the reason: a toppled ebony king and "Checkmate: you captured the king". The score is hidden when it didn't decide the match. Nitpick: "Checkmate" is the wrong word in a ruleset where the king is simply captured and check can be escaped or declined. "King captured" says it straight.
- **Polish 4.5.** Clean modal. The king is tilted about 29° (`rotation = -0.5`), so it reads as "tipped", not "toppled".
- **Feel 4.5.** A 0.35 s beat on the final board, then the panel settles and the king tips.
- **Sound 4.** The `victory` / `defeat` stingers are good. But **a lost match ends the run, so `defeat` (3.4 s) is followed by `run_defeat` (3.8 s) as soon as Continue is pressed, and then `unlock_fanfare` at ≈2.1 s into the run end.** That is three stingers in about 6 s, and the first two overlap if you click quickly (different ids, so no cooldown applies). The boss win does the same with `victory` followed by `run_victory`.
- **Accessibility 4.5.**

### Reward (12, 1080p/07, 16x10/07)
- **Clarity 4.5.** There are key caps under the cards, and the caption reads "Rare · costs 2 energy". The cost coins happen to read 1/2/3 right above key caps 1/2/3, but the caption disambiguates them.
- **Polish 4.5.** The cards are 1.3× size and Skip sits under them. The bottom 25 % of the screen is empty, which is acceptable.
- **Feel 4.5.** Deal-in, pop, beat.
- **Sound 4.5.** `reward_reveal`, `ui_confirm`, and the HUD `score_tick` on skip. Skip has no hover tick (`sfx = "none"`); see Sound overall.
- **Accessibility 4.5.**

### Shop (14–16, 1080p/08, 16x10/08)
- **Clarity 4.5.** "Sold", "2 pt · can't afford", and "Bought Bishop" right under the offer.
- **Polish 4.**
  - The anchored feedback now **collides with its surroundings**. In 16, "−2 pt" is drawn over the "Normal" caption, and the "Bought Bishop" toast straddles the Cards panel's bottom border (toast y≈544, panel edge y≈542).
  - Six full-brass "Buy" buttons plus a brass "Leave the shop" give every action the same weight, so the primary action isn't clear.
  - The Services panel is half empty.
- **Feel 4.5.** The float rises from the pressed button, and the HUD bumps and flashes.
- **Sound 4.5.** `ui_purchase` and HUD `energy_spend`. Buy buttons have no hover tick.
- **Accessibility 4.5.** Affordability in words; 1–9 focus, then Enter.

### Coaching (17, 18)
- **Clarity 4.5.** Item, upgrade, rule, price, and Accepted / Declined chips.
- **Polish 4.**
  - The mini cards are still tiny, and the "BOOK" ribbon crowds the coin (18).
  - Six brass Accept buttons plus a brass Leave button flatten the hierarchy.
  - The bottom ~20 % of the screen is empty.
- **Feel 4.** The accept glow can't be seen in the stills, and no frames were provided. Decline is instant.
- **Sound 4.5.** `ui_confirm` / `ui_cancel` / `ui_error`. Accept and Decline have no hover tick.
- **Accessibility 4.** The declined state now sinks instead of fading, which is fixed. But the mini-card names ("Pawn", "Bishop", "Rook" in 17) render at about 11 px serif, under the 12 px floor the team set. The declined card's art at 40 % alpha hides its cost coin (18: Bishop).

### Deck & collection views (15, 19, 20, 39)
- **Clarity 4.5.** The detail line follows focus and hover. Cards are sorted by cost.
- **Polish 4.** With small decks, about 45 % of the modal is empty (19: y 520–560; 39: y 360–560; collection 20: y 440–570). The modal doesn't hug its content.
- **Feel 4.** Fade in and out only. Focus moves are instant. Fine, but plain.
- **Sound 4.5.** `ui_open` / `ui_close`, and a focus tick.
- **Accessibility 4.5.** Focus trap, a ring on cards and rows, Esc, D and C.

### Run end (24, 29, 1080p/09, 16x10/09)
- **Clarity 4.5.** The headline, the run's back rank in its set (the defeated king is tipped over in 29), the unlock with its emblem and rule, and the figures.
- **Polish 4.**
  - The two panels' headers don't line up: "UNLOCKED FOR YOUR NEXT RUN" is vertically centred (y≈466 at 1080p) while "THE RUN" is top-aligned (y≈426).
  - The deck mini cards have ~9 px coins and ~11 px names.
  - The deck row fills only the left half of the panel.
- **Feel 4.5.** Burst, ring, shards, drop-in, sequential count-ups and the unlock deal (`run_end_screen.gd:_play`). This is a real payoff now. I judged it from code because no frame sequence was captured.
- **Sound 4.** It is designed well on its own terms (stop music, stinger, fanfare, music back after 3.5 s). But it inherits the stacking from match over: on a loss, `defeat` → `run_defeat` → `unlock_fanfare` (a bright C-major arpeggio) lands while `run_defeat` (A-minor descent) is still sounding at 2.1 s.
- **Accessibility 4.5.**

### Settings (37, 41, 1080p/02, 16x10/02)
- **Clarity 4.5.** Plain words and "Saved automatically". The Leave run row has a confirm step (41).
- **Polish 4.** The Mute and Reduced-motion switches are about 30 px with a grey knob on a near-black track, and the on state was never captured. The slider focus ring encloses the whole slider row (fine). The footer copy wraps awkwardly ("F1 opens this panel / anywhere; Esc closes it.").
- **Feel 4.5.** The settings apply live, and the preview plays after the slider rests for 0.25 s, so arrow keys work.
- **Sound 4.5.** A preview per bus, and `ui_open` / `ui_close`.
- **Accessibility 4.** Still missing: key remapping, a text or UI scale, a window or fullscreen option, and a separate "screen shake" toggle (reduced motion is all or nothing).

### Cohesion 4.5
There is one palette, one type scale, one button and focus system, one timing table, one sound palette (wood, paper, brass, Rhodes), and the artifact emblems now match the piece tokens. It loses half a point for:
- inconsistent hover sounds (buttons with `sfx = "none"` also lose their hover tick: `sfx.gd:375`);
- the banner's translucent double text.

### Delight 4
The capture, the one-beat explosion, the map hop and the new run-end payoff would all make a playtester smile. Purchases land where you click. What holds it back:
- opponent turns are a little long;
- the turn banner flickers double text every turn;
- refusals are near-silent on laptop speakers;
- a loss ends in a pile of stingers.

## 3. Critique 1 findings, verified

| # | Finding | Status | Evidence |
|---|---|---|---|
| 1 | Shop feedback far from click | **Fixed** (new collision) | 16: "−2 pt" rises from the Bishop offer, "Bought Bishop" under it; HUD 0. But the float and toast now overlap the caption and the panel border |
| 2 | Match over 0–0 on king capture | **Fixed** | 11: toppled ebony king + reason, no score (`match_over_panel.gd:49,84`) |
| 3 | Banner over pieces / over reveal / card on rank labels / crude card backs | **Fixed** | turn_banner_02–07 banner in header strip; frame 08 card at x 323–427, clear of labels at x≈449; walnut/oxblood card backs in 09/36. New: translucent ghosting |
| 4 | Explosion victims ripple; soft capture | **Fixed** | explosion_02 both victims fly in the same frame; player_capture_05–06 impact flash + shards; `HEAVY_CAPTURE_POINTS` nudge |
| 5 | Floats on pieces / outside board; Boom/ring spill | **Partly** | "+3" now on free d6 (08, player_capture_06); "Boom!" inside (34). Victim tokens still fly over the frame (explosion_03/04); ring clip grows 8 px past the grid |
| 6 | Hand gap and stale key caps | **Fixed** | card_play_energy_02: four cards numbered 1–4 the frame after the play (`_take_from_hand`) |
| 7 | Run end flat | **Fixed** | 24/29: centred column, piece row, count-up figures, emblem unlock; burst in code |
| 8 | Menu voids | **Mostly fixed** | Set select, reward and shop centred with actions under them; equal shop panel heights. Residual voids on artifact select (above) and in the deck modal |
| 9 | Focus vs chosen; reward key caps; deck focus ring | **Partly** | Reward key caps (12) and deck ring (39) fixed; artifact tiles still read focused ≈ chosen (31) |
| 10 | Sound fatigue / laptop presence | **Fixed in data, unverified by ear** | `check.py`: music 128 s / 120 s; 3 variants for 10 ids; presence −11..−13 dB on the four impacts; `turn_opponent` −14 dB, 0.4 s |
| 11 | Coaching declined fades | **Fixed** | 18: sunk face + chip; `coaching_screen.gd` only dims the art (`art.modulate.a = 0.4`) |
| 12 | Stale check marks; static escape key line | **Fixed** | 35: no CHECK tag on d6 after escape (`_on_escape`); 36: "Click a square to escape · N stay" |
| 13 | Settings: keyboard preview, Leave run, shake toggle, window/UI scale | **Partly** | Preview timer + Leave run fixed (41); no shake toggle, window mode or UI scale |
| 14 | Map identical next stops; "Floor 0" | **Fixed** | 03: "Then: …"; "Floor 1 of 7 · start" |
| 15 | Roster ★, row text dimming, empty right column | **Fixed** | 04: legend line, full-contrast "Rook / On the board", opponent deck mini cards |
| 16 | Opponent score OXBLOOD 3.98:1 | **Fixed** | `score_race.gd:78` uses `OXBLOOD_INK` for the figure |
| 17 | Hint desk dead space | **Partly** | KEYS list added; ~90 px gap remains (05) |
| 18 | Redraw lit when useless | **Fixed** | 28: "Redraw · won't help" in faint ink |
| CR | `_animate_move` awaits a token tween (soft-lock) | **Fixed** | `match_fx.gd:478` awaits `wait()`, then `is_instance_valid` |
| CR | `_reveal_opponent_card` freed card | **Fixed** | `match_fx.gd:290` |
| CR | Map redraws every frame | **Fixed** | No `_process` in `scripts/ui`; halo on its own layer, `Feel.ambient("map_pulse")` |
| CR | Settings write per slider tick | **Fixed** | `Settings.set_value(…, false)` + `SAVE_DELAY`, flush on close/release |
| CR | Shield badge per-draw allocation | **Fixed** | `piece_token.gd:39` member `_shield_points` |
| CR | Hard `stop()` voice steal clicks | **Fixed** | `sfx.gd:_release` 15 ms fade on a spare player |
| CR | Keyboard focus silent | **Fixed** | `main.gd:_on_focus_changed` |
| CR | Literals in match_fx / score_race / settings | **Mostly fixed** | match_fx and settings use `UiTheme` / `Metrics`; `score_race.gd` still has `Vector2(360, 52)`, `+13/+15/−30/34/48` offsets |
| CR | Hard-coded keys, no InputMap | **Partly** | `physical_keycode` + `A11y.number_key` (AZERTY ok); still no InputMap, so no remapping |
| Gaps | Title, HUD points, map hover, slider keyboard silent | **Fixed** | `title_screen.gd:58`, `hud.gd:82`, `map_view.gd:161/189`, `settings_panel.gd:48`; deliberate silences now listed in feedback_map |

## 4. Prioritised fixes (every line below 4.5)

1. **Turn banner: make it solid, or hide what it covers.** Set the panel to `WALNUT_DEEP` at alpha 1.0, *or* fade the header's contents (`view.header.modulate.a`) out while the banner is up, so there is never doubled text. Better still, don't repeat the header: pulse the turn label itself plus a brass or oxblood underline sweep. [Opponent-turn polish, Cohesion, Delight] `scripts/ui/match/match_fx.gd:321–351`.
2. **Refresh card playability at every state change, not only at `_sync`.** After `card_played` / `energy` / `turn_start` / `redraw`, set `is_playable` on the existing views (`is_my_turn and game.is_card_playable(i)`). Make every card unplayable as soon as the player's turn ends. [Match clarity, Opponent-turn clarity] `scripts/ui/screens/match_screen.gd:203–223`, `scripts/ui/match/match_fx.gd:_on_turn_start/_on_card_played/_on_energy`.
3. **Audibility of refusals and check on small speakers.** Add a 700–1500 Hz layer to `ui_error` (for example a muted wood tick an octave up, or a short dull "tock") and to `ui_cancel`, aiming for presence ≥ −14.5 dB like the impacts. Extend `check.py`'s presence rule to `ui_error`, `ui_cancel` and `turn_player`. Then **actually listen on a laptop** and write the result in UX_DECISIONS. [Match sound, Escape sound, Delight] `tools/audio/generate.py:431–444`, `tools/audio/check.py`, `config/ux.json`.
4. **Don't stack stingers at the end of a run.** When the match result ends the run (a loss, or the boss), play only a short "result" cue in the match-over panel, or none, and let the run end's stinger carry it. Alternatively, have `run_end_screen.gd` stop any still-sounding stinger (add `Sfx.stop(id)` or fade the SFX voice). Delay `unlock_fanfare` until the run stinger has finished (≥ 3.8 s), or duck the stinger under it. [Match-over sound, Run-end sound] `scripts/ui/match/match_over_panel.gd:72`, `scripts/ui/screens/run_end_screen.gd:71,98`, `scripts/ui/audio/sfx.gd`.
5. **Keep every board effect inside the frame.** Clip knocked-away victims too: reparent them into `_fx_clip` before knocking them away, or clamp the knock vector. Use `grid_rect()` (no `.grow(Metrics.S)`) for the clip. Move the CHECK tag up inside the square (or onto the token's top edge on rank 1), and clip the check pulse rings. Make the ghost card fly to the piece's *centre* without overhanging the board edge. [Match polish] `scripts/ui/match/match_fx.gd:209–222, 557–566, 695–711`, `scripts/ui/widgets/piece_token.gd` (CHECK tag).
6. **Map: captions on top of the paths.** Draw the edge segments with a gap at each node's caption, or give the captions a walnut backing chip. Centre the map block horizontally in its area and balance the top and bottom margins. [Map polish] `scripts/ui/widgets/map_view.gd`.
7. **Shop and coaching hierarchy and toast placement.** Make Buy and Accept the standard `Button` (brass outline), and keep `PrimaryButton` for the single "Leave" or the focused offer. Place the "Bought …" toast inside the panel padding, or over the card (never on the panel border), and start "−N pt" above the button's top edge so it clears the "Normal" caption. [Shop polish, Coaching polish] `scripts/ui/screens/shop_screen.gd:130–186`, `scripts/ui/screens/coaching_screen.gd:100–120`, `scripts/ui/feel.gd` (`toast`).
8. **Artifact tiles: distinguish focus from chosen by shape, not only by a 3 px offset.** For example, focus = a dashed or 1 px ivory ring, or a key-cap highlight, and keep brass for chosen only. Pin the CHOSEN chip to the tile's top-right corner so it lines up across tiles. [Artifact clarity, polish, accessibility] `scripts/ui/widgets/select_tile.gd`, `scripts/ui/screens/artifact_select_screen.gd`.
9. **Input remapping and UI scale.** Move E / R / Y / N / Space / D / C / F1 / 1–5 into InputMap actions (with defaults in `project.godot`). Add a "Controls" list to settings, a UI scale (0.9–1.25 via `content_scale_factor`), a window or fullscreen option and a "Screen shake" toggle split out of reduced motion. [Accessibility: match normal, opponent turn, settings, roster] `scripts/ui/screens/match_screen.gd`, `scripts/ui/main.gd`, `scripts/ui/settings.gd`, `scripts/ui/widgets/settings_panel.gd`, `config/ux.json`.
10. **Hover ticks on every enabled button.** Read `sfx_hover` independently of `sfx`, so `sfx = "none"` silences only the press. Buy, Accept, Decline, Skip, Start match, Continue and Close then tick like every other button. [Cohesion, Shop/Coaching/Reward sound consistency] `scripts/ui/audio/sfx.gd:374–379`.
11. **Opponent turn pacing.** Let a click or Space during the opponent's turn switch the rest of that turn to Fast. Shorten `reveal_hold` to 0.25 and overlap the reveal fade with the crouch. Pause the opponent loop while a modal is open (`A11y.is_modal_open`). [Opponent-turn feel, accessibility] `scripts/ui/screens/match_screen.gd:470–486`, `config/ux.json` `motion`.
12. **Roster keyboard square choice.** After Enter on a benched row, let the arrows walk the free deploy squares (a brass cursor on the board) and Enter place the piece. Show the next collection row partially, so the cut row reads as scrollable. [Roster accessibility, feel, polish] `scripts/ui/screens/roster_screen.gd`, `scripts/ui/widgets/board_view.gd`.
13. **12 px floor on mini cards.** Coaching mini cards, the run-end deck cards and the roster's opponent deck cards render names at about 11 px and coins at about 9 px. Drop the name below 72 px card width (keep glyph + coin), or raise the minimum to 12 px. [Coaching accessibility, Run-end polish, Roster polish] `scripts/ui/widgets/card_view.gd` (name and coin size floors).
14. **Modals and panels hug their content.** The deck and collection modals should size to their grid (a min height for 1 row, a max with scroll). Top-align the run end's unlock panel content with "THE RUN". [Deck polish, Run-end polish] `scripts/ui/widgets/item_overlay.gd`, `scripts/ui/screens/run_end_screen.gd`.
15. **Board legend completeness.** Add a "Hole" entry when Sinkholes is active, and a "Fire / burning" entry for the Fire set. [Match clarity] `scripts/ui/widgets/board_legend.gd`.
16. **Small copy and polish.**
    - Say "King captured" instead of "Checkmate" (`match_over_panel.gd:84`).
    - Rotate the toppled king nearer to 80–90°.
    - Remove the label/key-cap collision on long End turn labels: shorten to "End turn · nothing to play" or reserve cap space (`match_view.gd`).
    - Add a little life to the deck and collection overlays (stagger cards in on open, as the reward does) [Deck feel].
    - Show an accept frame sequence for coaching to prove its feel [Coaching feel].

    [Match-over clarity, Match polish, Deck feel, Coaching feel]
17. **Desk dead space** (still ~90 px): move KEYS directly under the hint, or let the hint area shrink. [Match polish] `scripts/ui/match/match_view.gd`.
18. **Fix the red test.** `test_ui_full_run.gd` fails deterministically because seed 8 now loses the boss and the fallback attempt counts 2 run logs. Either pick seeds that win under the current timings, or count logs per attempt (clear the log dir after a lost seed). Also check whether UI timing changes should affect a seeded run's outcome at all. `tests/integration/test_ui_full_run.gd:29–60`.

## 5. Code-review findings (godot-code-review checklist on the changed `scripts/ui` code)

### Critical
- **Test suite red** (see above): `test_ui_full_run.gd:60` fails deterministically. This is not a UX bug in itself, but the team's "all green" claim doesn't hold.
- **Stale `CardView.is_playable` during every animated sequence and the whole opponent turn** (`match_screen.gd:214`, only in `_sync_hand`). Input is guarded by `_can_act()`, so this is not a correctness bug, but it is a persistent wrong *display* of state on the most important widget.

### Improvements
- **`sfx.gd:375` hover suppression is coupled to the press override.** `get_meta("sfx") == "none"` returns before the hover is considered, so every result-driven button loses its hover tick. Read `sfx_hover` only.
- **No stinger management in `Sfx`.** Different stinger ids overlap freely, because cooldowns are per id. Add a `stop(id)` / "exclusive" flag for stingers (victory, defeat, run_*, unlock_fanfare), or route them through a single stinger voice.
- **`match_fx.gd:326` banner alpha 0.94** over live text creates the double-text artefact. Use an opaque fill or fade the header.
- **`match_fx.gd:209–222` `_fx_clip` grows by `Metrics.S`.** Bursts paint over the frame. Knocked-away victims (`_knock_away`) and the fly-card ghost live outside the clip, so they leave the board.
- **The opponent loop is not paused under modals** (`match_screen.gd:470–486`). The settings and deck overlays block input but the AI keeps moving. With "Leave run…" this is safe: MatchFx is a child of the screen, so its `wait()` tweens die with it and the coroutines are dropped. Still, the player misses opponent moves while reading settings.
- **`card_view.gd:233, 271, 313` build a `PackedVector2Array` literal on every `_draw`** (Cheaper arrow, ribbon, lozenge). Hand cards redraw throughout hover, lift and deal tweens. These are small per-frame allocations. Reuse member arrays, as `piece_token.gd` now does.
- **`score_race.gd`** still holds pixel literals (`Vector2(360, 52)`, text offsets 13 / 15 / 30 / 34 / 48), against the "no scattered literals" decision.
- **Input:** shortcuts are still hard-coded `KEY_*` constants (`match_screen.gd:100–110`, `main.gd`), with no InputMap actions, so they can't be remapped.
- **`main.gd:53` `load()` per screen change.** It is cached by ResourceLoader, which is fine; `preload` would be cleaner.
- **`_opponent_turn` runs `_ai.choose_action()` synchronously.** At depth 2 (Medium and Boss) a slow search would freeze running tweens for that frame. I did not measure it. Watch for hitching on the boss.

### Positive
- No `_process` anywhere in `scripts/ui`. The map halo is on its own layer, and the ambient loops are deliberately unscaled.
- MatchFx awaits only its own `wait()` tweens and re-checks `is_instance_valid` after each one (`_animate_move`, `_reveal_opponent_card`, `_animate_block`). The critique-1 soft-lock is gone.
- `Feel.shake` keeps its origin across overlapping shakes. The `A11y.trap_focus` weakref restore and the `tree_exiting` release are robust.
- In `Sfx`:
  - the voice pool with a fade-steal on spare players is correct (I traced it: `_fades` is non-empty whenever `free == null`, so `keys()[0]` is safe);
  - variants never repeat back to back;
  - ducking uses an Amplify effect, so the slider value is never touched;
  - quit releases playbacks.
- Settings writes are debounced and flushed on close, release and quit.
- The `_input` Esc workaround for tooltips is documented and correct.

## 6. Feedback-map gaps

**Every API event has visual and sound feedback.** I grepped `match_fx.gd` and `match_over_panel.gd`. `turn_start`, `energy` (player), `shuffle` (player), `draw` (`card_view.gd:91`), `card_played`, `move`, `shield_block`, `capture`, `explosion`, `score`, `ignite`, `burn_tick`, `burn_out`, `promotion`, `check`, `escape`, `escape_declined` (`ui_cancel`), `redraw`, `discard` and `match_over` all have both. `turn_end` and `error` have no row, which is fine: `turn_start` covers the handoff, and the UI never sends illegal actions.

**Documented deliberate silences, with reasons (acceptable):** opponent draw, refill and reshuffle; ambient loops; hovering unreachable map nodes or locked tiles; the match-over count-up; settings saving.

**Gaps (both channels required, not documented):**
1. **Hover ticks are missing on every button with `sfx = "none"`.** That covers Buy (shop), Accept and Decline (coaching), Skip (reward), Start match (roster), Continue to the map (artifact select), and Close (settings, deck overlays). feedback_map and sound_hooks say every enabled button hovers with `ui_hover`.
2. **Stinger stacking** after a run-ending match: `defeat` → `run_defeat` → `unlock_fanfare` (and `victory` → `run_victory`). Each is in the map, but their combination isn't considered.
3. **Hand playability change** (a card becoming unplayable after energy is spent or the turn ends) has no visual until the sequence ends (see the code review). The map's "Unplayable card" row assumes the look is always current.
4. **Holes (Sinkholes)**: they are drawn, but have no legend entry and no row in feedback_map (static, so no sound is needed).

**Known open UX issues:**
- The opponent-escape toast covers the player's back rank for 2.4 s (a lead call in UX_DECISIONS).
- The laptop presence of the sounds is "not verified by ear".
- The red `test_ui_full_run`.
