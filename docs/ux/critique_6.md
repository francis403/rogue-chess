# UX critique 6: independent review after iteration 6 (critique 5 fixes)

**What I looked at**
- **Screenshots.** I regenerated them from the current working tree before scoring:
  - `pgrep -f take_screenshots` found nothing running;
  - `--headless --import`, then the base pass (169 shots) and `-- --large-text` (45 shots); both exited 0.

  Then I read every image:
  - the 45 base shots `01–45`;
  - the 18 shots in `1080p/` and the 18 in `16x10/`;
  - the 45 shots in `large_text/`;
  - all 88 motion frames: `player_capture`, `explosion`, `card_play_energy`, `turn_banner`, `scout_reveal`, `deep_vision_point` (new), `settings_open`, `map_travel`, `coaching_accept`, `deck_open` and `run_end_victory`.
- **Docs.** `docs/SPEC.md`, `docs/specs/opponent-card-visibility.md`, `docs/UX_DECISIONS.md`, `docs/ux/feedback_map.md`, `docs/ux/sound_hooks.md`, `config/ux.json`, `README.md`, and the event table in `docs/API.md`.
- **Code.**
  - The uncommitted diff of `scripts/ui/**` (18 files) in full.
  - The engine's `_credit_capture` and its three call sites, to check the artifact-point attribution.
  - A checklist grep over all of `scripts/ui/**` (changed since 6001818).
- **Order.** I scored first. Only then did I read `critique_5.md` and re-check each of its findings myself.

**Runs**
- **`--import`:** clean.
- **GUT: 448/448 pass**, Scripts **37**, 0 failures.
  - 38 files are named `test_*.gd`. The 38th is the helper `tests/hooks/test_tmp.gd`, which sits outside the configured `tests/unit` and `tests/integration` directories. Every real test file ran.
  - stderr has **0 "SCRIPT ERROR" and 0 "Ignoring script"**.
  - The only noise is expected: 5 GUT notes about the inner class `TestTmp`, and two "Parse JSON failed" lines from `test_settings.gd::test_corrupt_file_falls_back_to_defaults`, which is a deliberate negative test.
- **`run_sim.gd --runs=100 --seed=1`: PASS.**
  - 0 crashes, action errors, illegal states, softlocks or log errors.
  - The boss was beaten in 14/100 runs.
  - The AI takes 1.1–1.8 ms per decision on average, 13.5 ms at worst.
- **`python3 -I tools/audio/check.py`:** "all checks passed", 12.92 MB.
- **No core change.**
  - `git diff --stat 49feac6 -- scripts/core` is empty.
  - The only config change is `config/ux.json`, one line: `motion.durations.unlock_hold` 0.9.
  - **Met.**
- Both screenshot runs end with the known "4 ObjectDB instances leaked / 2 resources still in use" (the accepted `get_tree().quit()` path).

**Accepted limitations** (noted, not scored down):
- `get_tree().quit()` on the title's Quit button and in the screenshot tool;
- no sound has been checked by ear (`tools/audio/audition.tscn` exists for that);
- the opponent-escape toast covers the player's back rank for 2.4 s (35, large_text/35);
- Large text instead of a canvas UI scale;
- glyph-in-a-circle card art.

**Verdict.** Six of critique 5's seven open UX bugs are fixed or mostly fixed, and so are all of its code-review items. I verified each in the shots or the code:
- **Settings modal.** It now grows from its centre (settings_open_02: x 131–1148, symmetric about 640).
- **Unlock seal.** It shrinks away before the content deals in (run_end_victory_06: empty panel, small fading "?").
- **"(+0)".** It is gone from king-capture log lines (large_text/11: "King captured on c6").
- **Deep Vision attribution.** It now has its own frame sequence (`deep_vision_point_01–06`).
- **Docs.** `sound_hooks.md` and the orphan comment are fixed.

One fix went backwards. The "−N pt" plate is now held inside the offer's panel, and on coaching that makes it **cover the just-upgraded card's cost coin and new BOOK ribbon** (coaching_accept_01). Then it rises out through the panel border anyway (coaching_accept_03). Two nits remain open from before: the Large-text map stop list scrolls, and the card ghost passes over other pieces. Nothing is blocking.

## 1. Score table

| Screen | Clarity | Visual polish | Feel | Sound | Accessibility |
|---|---|---|---|---|---|
| Title | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Set select | 5 | 5 | 4.5 | 4.5 | 5 |
| Artifact select | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Map | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Roster | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Match (normal) | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Match (opponent turn, incl. hand row and Scout reveal) | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Match (escape prompt) | 5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Match over | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Reward | 5 | 5 | 4.5 | 4.5 | 4.5 |
| Shop | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Coaching | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Deck & collection views | 5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Run end | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Settings | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |

| Whole game | Score |
|---|---|
| Cohesion | 4.5 |
| Delight | 4.5 |

**Lines below 4.5: none. Lines below 4: none. Exit bar met.**

How I gave the 5s:
- **Where 5s appear.** Only in cells where I found nothing to fault at any of the four sizes or the motion frames.
- **Sound.** Capped at 4.5 everywhere, because nothing has been heard.
- **Feel.** Stays at 4.5 on screens whose motion is good but ordinary.

## 2. Evidence per score

### Title (01, 30, 1080p/01, 16x10/01, large_text/01, 30)
- **Clarity 4.5.** New Game is the single filled, focused action. The progress panel shows pips plus "1 / 2 unlocked · 0 / 5 unlocked", and names replace the "?" chips once unlocked (30).
- **Polish 4.5.** The ghost board and vignette balance at every size, and Large text fits. The progress panel is still a little heavy for a title page.
- **Feel, Sound, Accessibility 4.5.**
  - The piece row drops in with one knock, then a light sweep.
  - The ambient loops stop under reduced motion.
  - Focus starts on New Game.

### Set select (02, 25, 1080p/10, 16x10/10, large_text/02, 25)
- **Clarity 5.** Two equal tiles, each with:
  - a "worth N" row under the tokens;
  - three rule lines read from config;
  - a key cap.

  Locked is said in words ("Locked · Beat the boss to unlock"), and the footer says "Enter or a number key picks a set". Readable in under 2 s.
- **Polish 5.** Nothing clips at 720p, 1080p, 16:10 or Large text. The Fire tokens' ember rims read at every size (25).
- **Feel 4.5.** A pop and a beat, then the next screen. Fine, but plain.
- **Sound 4.5.** `ui_confirm` / `ui_error`; not heard.
- **Accessibility 5.**
  - Focus is a dashed ivory ring outside the tile, so it differs from chosen by shape.
  - Number keys and Enter both pick.
  - Lock state is in text, not colour alone.

### Artifact select (31, 42, 1080p/13, 15, 16x10/13, 15, large_text/31, 42)
- **Clarity 4.5.** Each artifact has an emblem, a filled "CHOSEN" chip and a "1 / 2 chosen" counter next to Continue. Deep Vision states its cost in its own line.
- **Polish 4.5.**
  - The fifth tile is centred under the pairs.
  - The list starts under the subtitle.
  - The text runs to the key cap.

  Nit: at 1080p there is about 250 px of empty background under Continue.
- **Feel, Sound, Accessibility 4.5.**
  - A pop with `ui_toggle`; a third pick shakes and plays `ui_error`.
  - Focus (dashed) and chosen (tint, border and chip) differ by shape.

### Map (03, 13, 21, 38, 1080p/03, 16x10/03, large_text/03, 13, 21, 38; map_travel_01–08)
- **Clarity 4.5.**
  - Next stops have a breathing halo, a key cap and a dashed path.
  - "Then: …" lines, a "YOU" tab and a two-column legend.
  - The focused node gets a detail card with the opponent's pieces (large_text/38).
- **Polish 4.5.** The map fits at every size, and the caption plates keep paths out of words. Nit, still open: at Large text only two of the three next-stop cards are visible above a scroll bar (large_text/03).
- **Feel 4.5.** The other choices go quiet at once and the marker hops along the path. The roster fades in by about 0.6 s (map_travel_08).
- **Sound, Accessibility 4.5.**
  - `ui_hover` plays only on reachable nodes.
  - Arrows, 1–3 and Enter all work.

### Roster (04, 22, 26, 1080p/04, 14, 16x10/04, 14, large_text/04, 22, 26)
- **Clarity 4.5.**
  - The ★ king legend, budget pips and "8 pieces ready · 1 budget left".
  - "To win: …" on the opponent side.
  - The boss line "3 random artifacts, revealed when the match starts".
- **Polish 4.5.**
  - At Large text the list shows whole rows only.
  - The keyboard cursor is a dashed square with a ghost of the piece (1080p/14).
  - Nit: at 1280×800 the screen sits vertically centred with an empty band above the header (16x10/04). Acceptable.
- **Feel, Sound, Accessibility 4.5.**
  - Landing sounds follow the piece's weight.
  - The keyboard path is "Arrows choose a square · Enter places your queen · Esc puts it back".

### Match, normal (05–08, 27, 28, 32–34, 40, 43, 44; 1080p/05, 16, 17; 16x10/05, 16, 17; large_text/same; player_capture, explosion, card_play_energy, deep_vision_point)
- **Clarity 4.5.**
  - Board marks are shapes (dot, ring, brackets), and the legend grows "Hole: no piece" when there are holes.
  - The hint names each step: "Choose a target", "Moving this Fire piece ignites it: 3 turns left" (large_text/27).
  - Dead turns are spelled out: "Redraw · won't help" and "End turn · nothing to play" (large_text/28).
  - The Scout has its own eye glyph.

  The screen is dense: three side columns, a log, a legend and a key list. It reads well, but not at a glance for a newcomer.
- **Polish 4.5.**
  - The played card's ghost settles on the destination square.
  - Explosion floats stay inside the board.
  - Deep Vision's point now has its own float ("+1 Deep Vision" under the "+1"), a chip glow and a log note (deep_vision_point_02–06).

  Nits:
  - The ghost still flies over other tokens on its way (card_play_energy_02 passes over the e1 bishop).
  - "Boom!" sits flush against the board's right edge (explosion_02, large_text/34).
- **Feel 4.5.**
  - A capture has a flash, a knock-away, a hit-stop and a score-track flare in about 0.6 s.
  - An explosion is one beat.
  - Energy pips drain one at a time.
- **Sound 4.5.**
  - Every event has a cue, and every id has a rendered file (`check.py`).
  - Variants, cooldowns and voice stealing guard against fatigue.
  - The opponent's captures use the darker `capture_against`.
- **Accessibility 4.5.**
  - The `rc_*` keys are remappable and every key cap follows the binding.
  - Colour-blind cues: rings, burn arcs, the CHEAPER and HOLD ribbons.
  - Text is never under 12 px, and reduced-motion paths exist.

### Match, opponent turn, incl. hand row and Scout reveal (09, 10, 35, 43–45; 1080p/16–18; 16x10/16–18; large_text/same; turn_banner_01–11, scout_reveal_01–10)
- **Clarity 4.5.**
  - The hand row shows faces with cost coins, then oxblood backs with a brass lozenge.
  - The caption says "3 shown · 2 hidden" / "all shown", and the names line below repeats the faces in text.
  - The Scout's text waits for the flips (scout_reveal_04: still "3 shown · 2 hidden"). Then "all shown" pops and the log says "You scouted 2 cards · none hidden now" / "Revealed: Move · Pawn" (frame 10).
  - The opponent's played card shows beside the rank numbers.
- **Polish 4.5.**
  - The row keeps its slots through the flip, and the coin sits inside each mini.
  - The banner wipe never shows a doubled header.

  Nits:
  - The minis are 40×56; they are legible but small.
  - The still named "scouted" (45 and its 1080p, 16x10 and large_text copies) catches the row mid-flip every time, so no still shows the final state. Only scout_reveal_10 does.
- **Feel 4.5.** About 1.3 s per opponent action, with a hurry option (Shift or a board click). The flips are staggered and glow.
- **Sound 4.5.**
  - `turn_opponent` is a quiet tap.
  - The reveal plays `reward_reveal`, then `card_draw` on each flip.
  - The opponent's draw is a documented silence.
- **Accessibility 4.5.**
  - Shown and hidden cards differ by shape and pattern, and the names line gives the text path.
  - Reduced motion swaps the flip for a fade.
  - The "Hand" tooltip explains what the backs mean and what Deep Vision does.

### Match, escape prompt (36, 1080p/06, 16x10/06, large_text/36)
- **Clarity 5.** The red "CHECK!" panel says exactly what to do and what it costs: "Costs 1 energy from your next turn · next turn: 2/3". The escape squares are dots, the CHECK tag sits on the king and the checker's square is bracketed in oxblood.
- **Polish 4.5.** Clean at every size. The tag stays inside the first-rank square. The panel text wraps to 3 lines at Large text, which is fine.
- **Feel, Sound 4.5.** Hit-stop, pulsing rings and `check`; `check_stay` plays for a decline.
- **Accessibility 4.5.** Y/Enter or N, with the bound key in the hint. End turn is disabled while the prompt is up.

### Match over (11, large_text/11)
- **All 4.5.**
  - It leads with "King captured: you took their king", with a toppled king token and the reward line above Continue.
  - The "(+0)" noise is gone from the log.
  - The `victory` stinger ducks the music.

### Reward (12, 1080p/07, 16x10/07, large_text/12)
- **Clarity 5.** Three large cards, each with a key cap, a "Moves one bishop" line and "Rare · costs 2 energy". "Deck: 6 cards" sits next to "Skip · +1 point".
- **Polish 5.** Spacious and aligned at every size; nothing clips.
- **Feel, Sound 4.5.** The cards deal in with `reward_reveal`, and taking one pops.
- **Accessibility 4.5.** 1–3 and arrows. Rarity is shown as a word plus a ♦ pip, not colour alone.

### Shop (14–16, 1080p/08, 16x10/08, large_text/14–16)
- **Clarity 4.5.** "Need 3 pt", "Sold" and "Bought Pawn"; one filled action ("Leave the shop").
- **Polish 4.5.** The "−2 pt" plate now starts inside the panel, but it sits on top of the "CARDS" eyebrow (large_text/16: "CARD[S]" is hidden behind the plate). It is short-lived and opaque.
- **Feel, Sound, Accessibility 4.5.**
  - The HUD points flash oxblood.
  - `ui_purchase` plays.
  - 1–9 focus an offer.

### Coaching (17, 18, 1080p/11, 16x10/11, large_text/17, 18; coaching_accept_01–07)
- **Clarity 4.5.** The chips read "Accepted · upgraded" and "Declined", the line "Bishop learned Book" appears, and the BOOK ribbon shows at once.
- **Polish 4.5, a regression to fix.** Critique 5 fixed the plate covering the upgraded art; the new `ceiling` clamp in `Feel.spend_float` / `_rise` undoes it:
  - In **coaching_accept_01** the "−2 pt" plate sits on the Bishop card's cost coin **and** its new BOOK ribbon.
  - By **coaching_accept_03** it has risen through the panel's top border anyway.

  So it does both things the two fixes tried to avoid. It lasts only a couple of frames, so the score stays at 4.5, but it is the most visible polish defect this round.
- **Feel, Sound, Accessibility 4.5.**
  - A warm glow and an oxblood flash on the HUD, with `ui_confirm`.
  - Declined offers sink but stay above 4.5:1 contrast.

### Deck & collection views (15, 19, 20, 39, 1080p/12, 16x10/12, large_text/15, 19, 20, 39; deck_open_01–07)
- **Clarity 5.**
  - "×N" tabs hang under the cards, in room kept free for them.
  - The detail line follows focus ("Queen · cost 3 · Move one queen").
  - The collection reads "deploy N" with ×N counts.
- **Polish 4.5.** Opaque from frame 1, and the cards deal in. Nit: at Large text 8 cards wrap 6 + 1 + 1 with an orphan on the second row (large_text/19).
- **Feel, Sound, Accessibility 4.5.** Grows from 94 % with `ui_open` / `ui_close`. Focus is trapped, and Esc, the scrim or Close dismiss it.

### Run end (24, 29, 1080p/09, 16x10/09, large_text/24, 29; run_end_victory_01–08)
- **Clarity 4.5.**
  - The headline names the result and the floor.
  - The figures count up.
  - The unlock shows its rule text, with "Pick the set when you start a run".
- **Polish 4.5.** **Fixed:** the seal no longer overlaps the content (frame 06 shows an empty panel while the seal fades; the content deals in next). Nit: that frame's panel is empty apart from the eyebrow for a beat.
- **Feel 4.5.**
  - The seal charges, and opens at most `unlock_hold` 0.9 s after the last figure.
  - Rays and a burst play on a win, and the king topples on a loss.
- **Sound 4.5.**
  - The stinger plays over silence; the fanfare cuts the stinger's tail.
  - Leaving early fades the stinger out (`_exit_tree`).
- **Accessibility 4.5.** Reduced motion drops the burst, drop, topple and charge, but keeps the counting figures.

### Settings (37, 41, 1080p/02, 16x10/02, large_text/37, 41; settings_open_01–07)
- **Clarity 4.5.**
  - Two columns, segmented choices, and toggles that say "ON" / "OFF".
  - The footer reads "Saved automatically · F1 opens settings, Esc closes".
  - "Leave run…" appears during a run.
- **Polish 4.5.** **Fixed:** the panel grows from its centre (settings_open_02). Nit (accepted): at Large text the Controls column scrolls and its hint line falls below the fold.
- **Feel, Sound, Accessibility 4.5.**
  - Volume previews play once a slider rests.
  - Rebinding swaps on conflict, and "Reset keys" restores the defaults.
  - Focus is trapped.

### Cohesion 4.5
- **What holds it together.** One palette, one type scale, one focus language (a brass ring, or a dashed ivory ring on tiles), one timing table and one sound palette.
- **The new work reuses it.** The flip is drawn in `CardView`, the artifact attribution reuses the chip glow, and the badge layout is shared through `ItemOverlay.badged`.
- **Why not 5.** The "−N pt" plate still doesn't sit well inside its container on either screen: on the shop it covers an eyebrow, on coaching it covers the item and then crosses the border.

### Delight 4.5
- **The pleasures.** The capture knock-away, the one-beat explosion, the Scout flip with its delayed payoff, the "+1 Deep Vision" attribution with its chip glow, the map hop, and the run-end seal charging into the fanfare.
- **Why not 5.** The glyph art (accepted) caps the "wow", and no sound has been heard.

## 3. Critique 5's findings: status (each checked myself)

| # | Critique-5 finding | Status | Evidence |
|---|---|---|---|
| 1 | Settings modal grows from its top-left | **Fixed** | settings_open_02 is symmetric about the centre; `settings_panel.gd:90` / `item_overlay.gd:74` keep the pivot centred on `resized` |
| 2 | Unlock seal drawn over the unlock title | **Fixed** | run_end_victory_06; `Seal.open` shrinks to 0.6 over `FADE` × reveal, and `Feel.reveal(items, …, Seal.FADE * reveal)` waits for it |
| 3 | "−N pt" plates cross the panel border | **Changed, partly regressed** | Shop: inside the panel now, but over the "CARDS" eyebrow (large_text/16). Coaching: starts over the cost coin and BOOK ribbon (coaching_accept_01), then still crosses the border (03) |
| 4 | Large text: map's third next stop under a scroll bar | **Open** (trade-off) | large_text/03 |
| 5 | "(+0)" in king-capture log lines | **Fixed** | large_text/11; `event_text.gd` returns no "(+N)" when `points == 0` |
| 6 | Card ghost passes over other tokens | **Open** | card_play_energy_02 (over e1) |
| 7 | Two stale lines in `sound_hooks.md` | **Fixed** | line 55 says `card_draw` plays per card; line 78 says the fallback is `turn_opponent` |
| 5.5 | No screenshot of the Deep Vision float | **Fixed** | `frames/deep_vision_point_01–06` |
| CR | Pivot set in a tween callback | **Fixed** | see #1 |
| CR | Orphan doc comment in `run_end_screen.gd` | **Fixed** | the line is gone |
| CR | `_relayout()` uses `get_child_count()` | **Fixed** | `var count := _cards().size()` |
| CR | `_score_floats()` has a side effect | **Fixed** | split into `_score_floats` (pure) and `_flash_bonuses` |
| CR | Comment on `artifacts` being captured once | **Open** (trivial) | `match_fx.gd:36` still doesn't say it assumes artifacts are fixed for the match |

## 4. Fixes

No line is below 4.5, so none of these is required for the exit bar. They are the nits that hold back the remaining half points, most important first.

1. **Coaching and shop "−N pt" plate (regression).**
   - **Problem.** `_rise` clamps the start to `ceiling` (the panel's top + `XS`). On coaching the card sits right under the panel top, so the plate is pushed down onto the coin and ribbon. Then the "no room above" branch lets it rise past the border.
   - **Fix.** When there is no room between the panel top and the item, start the plate outside the panel, above its top border, with a `Metrics.XS` gap, and rise from there. Or anchor it to the side of the art (right of the card, level with its top) instead of above it.
   - **Shop.** Avoid the eyebrow by starting below the eyebrow's bottom edge (pass that as `ceiling`), or offset the plate horizontally.
   - **Files.** `scripts/ui/feel.gd` (`spend_float`, `_rise`), `coaching_screen.gd`, `shop_screen.gd`.
2. **Large-text map stops.** At Large text, use a compact stop card: key cap, type and name on one line, with "Then: …" in the tooltip. Then all three fit without a scroll bar. File: `scripts/ui/screens/map_screen.gd`.
3. **Card ghost over tokens.** Draw the ghost under the pieces' layer once it is over the board, or give it an arc that rises above the board before it descends. File: `scripts/ui/match/match_fx.gd` `fly_card`.
4. **Screenshot "scouted" still.** Wait for `reveal` + stagger × N before the capture, so the still shows "all shown". File: `tools/screenshots/shot_moments.gd`.
5. **Smaller items.**
   - Deck overlay at Large text: balance the rows (4 + 4) instead of 6 + 1 + 1.
   - "Boom!": inset it a few px from the board edge.
   - `match_fx.gd:36`: add "fixed for the match" to the `artifacts` comment.

## 5. Code-review findings (godot-code-review checklist; `scripts/ui/**` changed since 6001818, focused on the uncommitted iteration-6 diff)

### Critical
- **None.** Across `scripts/ui/**` there is:
  - no `_process` / `_physics_process`;
  - no `free()`;
  - no deep `$A/B/C` paths;
  - no untyped `var x =`.

  The only runtime `load()` is `Sfx._load`, for config-driven sound ids. Screens are now `preload` constants in `main.gd`.

### Improvements
- **`feel.gd` `_rise()`: the ceiling logic causes the coaching regression** (§4.1).
  - The plate's start is clamped *down* to `ceiling`.
  - Its end is clamped only when the start was already below `ceiling`.

  So a too-tight panel yields "start on the item, end above the border". **Fix:** decide up front whether there is room, then place the whole path either inside or outside the panel.
- **`match_fx.gd` `_show_turn_banner()`: label visibility depends on a tween callback.**
  - `_show_turn_label(false)` runs immediately. `true` runs only from the banner's tween, which dies with `_banner` when a new banner `queue_free()`s it mid-wipe.
  - Today the next banner re-shows the label, so it recovers.
  - **Edge case:** if the match screen ends or is replaced during the first 0.12 s wipe and the view is reused, the header label stays invisible.
  - **Fix:** restore the label in the same place the banner is freed, or tie it to `tree_exiting` of `_banner`.
- **`settings_panel.gd:90`, `item_overlay.gd:74`: an anonymous lambda is connected to `_panel.resized` on each open.**
  - Fine today, because each overlay instance opens once.
  - If an instance is ever reopened, connections accumulate. Duplicate lambda connections don't error, so the leak would be silent.
  - **Fix:** connect a named method once in `_ready`.
- **`event_text.gd` `bonuses()` mirrors the engine's scoring rule in the UI.**
  - I checked it against `_credit_capture` and its call sites: capture → mover, explosion → `1 − victim.side`, burn-out → `1 − side`. Trophy Case goes to the credited side; the foresight penalty applies when the victim is a player piece. They match.
  - It is still a second copy of a rule. If the engine changes, the float and log split would silently drift (a negative or wrong base).
  - **Fix:** a cheap guard, `assert(base >= 0)` in `_score_floats`, or a unit test that diffs `bonuses()` against the engine for all three causes with both artifacts.
- **`opponent_hand.gd` `show_hand(..., hold_text)`: the caption depends on the caller later calling `refresh_text()`.** Only `_animate_reveal` uses it, and it does. Document that the caller owns the refresh, or assert it on the next `show_hand`.

### Positive
- `OpponentHand` uses only `visible_opponent_hand()` / `hidden_card_count()`, so R6 holds and a hidden face is never built.
- The flip is a drawn property (`CardView.flip`), so container sorting can't reset it, and reduced motion becomes a fade.
- `_score_floats` is pure now; `_flash_bonuses` is separate.
- `ItemOverlay.badged()` replaced two copies of the badge holder code (overlay and run end).
- `Ui.need_points()` gives shop and coaching one wording.
- The map's `_fit_stops` measures minimum sizes, not stale rects.
- The only new tunable, `unlock_hold`, is in `config/ux.json`.

## 6. Feedback-map gaps and open UX bugs

I checked every event in the `docs/API.md` table against `match_fx.gd`, and every `Sfx.play` id against `config/ux.json` → `audio.sounds`. That includes the dynamic ids: `capture_sound()`, `_land_sound()`, `card_draw` via `bind`, `victory` / `defeat`, `run_victory` / `run_defeat`, `fire_ignite` / `fire_burn`, and `check_stay` / `turn_opponent`.

**Result:**
- All 44 configured sounds have a call site, and every call site resolves to a configured sound.
- `check.py` confirms that every file is rendered within its loudness and spectrum limits.

| Event | Visual | Sound | Note |
|---|---|---|---|
| `turn_start` / `turn_end` | banner wipe / discard sweep | `turn_player` / `turn_opponent` | OK |
| `energy` | pips | `energy_refill` (player) | the opponent's is a documented silence |
| `draw` / `shuffle` / `discard` / `redraw` | deal, pile pop, sweep | `card_draw`, `card_shuffle`, `card_discard` | the opponent's are documented silences |
| `card_played` | ghost to the destination; opponent's card beside the ranks | `card_play`, `energy_spend` | ghost over tokens (open nit) |
| `reveal` (Scout) | flips, glow, then caption pop and log | `reward_reveal` + `card_draw` per flip | OK |
| `move` | crouch, hop, land | `piece_move`, `piece_land_*` | OK |
| `capture` / `explosion` / `burn_out` | knock-away, "+N" and "+1 <artifact>", chip glow | `capture` / `capture_against`, `explosion`, `fire_burnout` | OK; now shown in deep_vision_point |
| `score` | track fill and flare | `score_tick` | OK |
| `shield_block`, `ignite`, `burn_tick`, `promotion` | ring and "Blocked!", arc, badge pop, glyph swap | `shield_block`, `fire_ignite`, `fire_burn`, `promotion` | OK |
| `check` / `escape` / `escape_declined` | rings, tag, toast | `check` / `escape` / `check_stay` | OK |
| `match_over` | panel | `victory` / `defeat` | the count-up is a documented silence |
| `error` | shake + hint | `ui_error` | OK |

No undocumented silent events remain. The feedback map's rows match what the shots show, with one exception: the shop and coaching "Buy" / "Accept" rows say the plate rises "clear of its glyph and cost coin", and on coaching that is not true in the first frames (§4.1).

### Open UX bugs (all minor)
1. **Regression.** The coaching "−N pt" plate covers the upgraded card's cost coin and BOOK ribbon, then crosses the panel border (coaching_accept_01 → 03).
2. The shop "−N pt" plate covers the "CARDS" eyebrow (large_text/16).
3. At Large text, the map's third next stop is under a scroll bar (large_text/03).
4. The played card's ghost passes over other tokens (card_play_energy_02).
5. At Large text the deck overlay wraps 6 + 1 + 1 with an orphan card (large_text/19).
6. **Tooling.** The "scouted" still is caught mid-flip at every size (45, 1080p/18, 16x10/18, large_text/45).
