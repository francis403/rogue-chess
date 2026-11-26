# UX critique 5: independent review after iteration 5 (critique 4 fixes)

**What I looked at**
- **Screenshots.** I regenerated them from the current working tree first (`pgrep -f take_screenshots` showed nothing running; `--import`, then the base pass and `-- --large-text`; 163 shots written, exit 0). Then I read:
  - the 45 base shots `01–45`;
  - the 18 shots in `1080p/` and the 18 in `16x10/`;
  - the 45 shots in `large_text/`;
  - the motion frames `player_capture`, `explosion`, `card_play_energy`, `turn_banner`, `scout_reveal`, `settings_open`, `map_travel`, `coaching_accept`, `deck_open` and `run_end_victory`.
- **Docs.** `docs/SPEC.md`, `docs/specs/opponent-card-visibility.md`, `docs/UX_DECISIONS.md`, `docs/ux/feedback_map.md`, `docs/ux/sound_hooks.md`, `config/ux.json`, `README.md`, and the events in `docs/API.md`.
- **Code.** The uncommitted iteration-5 diff of `scripts/ui/**` (17 files) in full: `match_fx.gd`, `opponent_hand.gd`, `run_end_screen.gd`, `feel.gd`, `event_text.gd`, `card_view.gd`, `settings_panel.gd` / `item_overlay.gd` (modal open). I also read the engine's `_credit_capture` to check the new artifact attribution against it, and grepped all of `scripts/ui/**` for the review checklist.
- **Order.** I scored first. Only then did I read `critique_4.md`, and I re-checked each of its findings against the new shots and the code.

**Runs**
- `--headless --import`: clean.
- **GUT: 448/448 pass**, 16 896 asserts, **Scripts 37**. That count matches every `test_*.gd` under `tests/unit` and `tests/integration` (37). The 38th file with that prefix is the `tests/hooks/test_tmp.gd` helper, outside the configured directories. stderr has **no "SCRIPT ERROR" and no "Ignoring script"**, so no test file was silently skipped. The only noise is expected:
  - 5 GUT notes that the inner class `TestTmp` doesn't extend GutTest;
  - the deliberate bad-JSON and unknown-sound-id warnings from negative tests.
- **`run_sim.gd --runs=100 --seed=1`: PASS.** 0 crashes, action errors, illegal states, softlocks or log errors. The AI decides in 1.1–1.9 ms on average, 13.4 ms at worst.
- `python3 -I tools/audio/check.py`: "all checks passed", 12.92 MB.
- **No core change.** `git diff --stat 49feac6 -- scripts/core` is empty. The only config change is `config/ux.json` (+1 line: `motion.durations.unlock_hold` 0.9). **Met.**
- Screenshot runs end with the known "4 ObjectDB instances leaked / 2 resources still in use" (the accepted `get_tree().quit()` path).

**Accepted limitations** (noted, not scored down):
- `get_tree().quit()` on the title Quit button and in the screenshot tool;
- no sound has been checked by ear (`tools/audio/audition.tscn` exists for that);
- the opponent-escape toast covers the player's back rank for 2.4 s (35, large_text/35);
- Large text instead of a canvas UI scale;
- glyph-in-a-circle card art.

**Verdict.** All six of critique 4's blocking findings are fixed, and I can see each fix in the regenerated shots:
- **Scout text.** The reveal's text now waits for the flips: scout_reveal_01–07 read "3 shown · 2 hidden" / "Bishop · Knight · Rook" while the backs turn, and only frame 10 reads "all shown" with the log lines.
- **Deep Vision.** Its point is attributed: separate float, log note and chip flash, with an integration test.
- **Run end.** The unlock opens about 1 s after the figures, with a charging seal (run_end_victory_04 halo, 05 opening).
- **Five artifacts.** The odd fifth tile is centred and the list sits under the subtitle.
- **Opponent minis.** The mini coin sits inside the card.
- **Turn banner.** Its first frame no longer shows the header label beside the wipe (turn_banner_01).

What I found this time is all nit-level:
- the settings modal grows from its top-left corner;
- the unlock seal overlaps the unlock content for one reveal beat;
- two stale lines in `sound_hooks.md`;
- an orphan doc comment.

## 1. Score table

| Screen | Clarity | Visual polish | Feel | Sound | Accessibility |
|---|---|---|---|---|---|
| Title | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Set select | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Artifact select | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Map | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Roster | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Match (normal) | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Match (opponent turn, incl. hand row and Scout reveal) | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Match (escape prompt) | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Match over | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Reward | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Shop | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Coaching | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Deck & collection views | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Run end | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Settings | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |

| Whole game | Score |
|---|---|
| Cohesion | 4.5 |
| Delight | 4.5 |

No line is below 4.5 and none is at 5. I hold back 5s for three reasons:
- the card faces are glyph-in-a-circle;
- no sound has been heard;
- each screen still has at least one nit.

Delight and Run end feel are the thinnest 4.5s.

## 2. Evidence per score

### Title (01, 30, 1080p/01, 16x10/01, large_text/01, 30)
- **Clarity 4.5.** New Game is the single filled, focused action. The progress panel gives pips plus "1 / 2 unlocked · 0 / 5 unlocked", and the names appear once unlocked (30).
- **Polish 4.5.** The ghost board and vignette are balanced at 720p, 1080p and 16:10, and Large text fits. The progress panel is still slightly heavy for a title page.
- **Feel / Sound / Accessibility 4.5.** The row drops in with one knock and the light sweep runs; ambient loops stop under reduced motion. Focus starts on New Game.

### Set select (02, 25, 16x10/10, large_text/02, 25)
- **All 4.5.**
  - Equal tiles with "worth N" tables and three rule lines.
  - "Locked · Beat the boss to unlock" in words.
  - Key caps, and the hint "Enter or a number key picks a set".
  - Focus is a dashed ivory ring, distinct from chosen.
  - The Fire tokens' ember rims read at Large text.

### Artifact select (31, 42, 1080p/13, 15, 16x10/13, 15, large_text/31, 42)
- **Clarity 4.5.** Emblem, chip and the "1 / 2 chosen" counter sit next to Continue. Deep Vision states its cost in its own description.
- **Polish 4.5.** **Fixed since critique 4.**
  - The fifth tile is centred under the pairs (1080p/15, 16x10/15).
  - The list starts right under the subtitle.
  - Descriptions run to the key cap.

  Nit: at 1080p the page now ends with about 250 px of empty background below Continue. That is acceptable for a top-aligned page.
- **Feel / Sound / Accessibility 4.5.** Pop with `ui_toggle`; a third pick shakes and plays `ui_error`. Focus (dashed) and chosen (tint, border and chip) differ by shape.

### Map (03, 13, 21, 38, 1080p/03, 16x10/03, large_text/03, 13, 21, 38; map_travel_01–08)
- **Clarity 4.5.** Halo, key caps, dashed path, "Then: …" lines, the "YOU" tab, and a two-column legend.
- **Polish 4.5.** The map fits at every size. Caption plates keep paths out of words, and the marker passes under them (map_travel_03).
- **Feel 4.5.** The other choices go quiet at once, the marker hops, and the screen changes at about 0.6 s (map_travel_08 shows the roster fading in).
- **Sound / Accessibility 4.5.** Arrows, 1–3, focus ring and rich tooltips. Nit, still open: at Large text the third next stop sits below a scroll bar (large_text/03).

### Roster (04, 22, 26, 1080p/04, 14, 16x10/04, 14, large_text/04, 22, 26)
- **Clarity 4.5.**
  - The ★ legend, budget pips and "8 pieces ready · 1 budget left".
  - The keyboard line "Arrows choose a square · Enter places your queen · Esc puts it back".
  - "To win: …" and the boss line "3 random artifacts, revealed when the match starts".
- **Polish 4.5.** Whole rows at Large text, and the opponent-deck minis have no cramped coin.
- **Feel / Sound / Accessibility 4.5.** Land sounds match the piece's weight. The dashed cursor carries a ghost of the piece (16x10/14).

### Match, normal (05–08, 32–34, 40, 43, 44; 1080p/05, 16, 17; 16x10/05, 16, 17; large_text/05–08, 32–34, 40, 43, 44; player_capture, explosion, card_play_energy)
- **Clarity 4.5.**
  - Marks are shapes first: dot, ring, brackets.
  - The legend includes "Hole: no piece".
  - The hint names each step ("Choose a target", "Nothing to play · … End your turn").
  - "Redraw · won't help" and "End turn · nothing to play" (large_text/28).
  - The Scout has its own eye glyph.
- **Polish 4.5.**
  - **Fixed**: the played card's ghost now settles on the *destination* square (card_play_energy_04 on a2; player_capture_03 on c5).
  - Explosion floats land on free squares inside the board.

  Nits:
  - The ghost still crosses other pieces on its way (card_play_energy_02 passes over the e1 bishop).
  - "Boom!" is clamped flush against the board's right edge (explosion_02–08).
- **Feel 4.5.** A capture takes about 0.6 s with flash, knock-away and score-track flare. The explosion is one beat. Selection lifts in the same frame (06, 40).
- **Sound 4.5.**
  - Every event has a cue, and every id is rendered (`check.py`).
  - Variants, cooldowns and the voice limit guard against fatigue.
  - The opponent's captures use `capture_against`.
- **Accessibility 4.5.**
  - Remappable `rc_*` keys, and the key caps follow bindings.
  - Colour-blind cues on rings, burn arcs and Cheaper coins.
  - 12 px floor; reduced-motion paths.

### Match, opponent turn, incl. hand row and Scout reveal (09, 10, 35, 43–45; 1080p/16–18; 16x10/16–18; large_text/09, 10, 35, 43–45; turn_banner_01–11, scout_reveal_01–10)
- **Clarity 4.5.** **Fixed since critique 4.**
  - **Scout reveal.** Text no longer pre-empts the flip: scout_reveal_01–07 keep "3 shown · 2 hidden" and "Bishop · Knight · Rook". Frame 10 then pops "all shown" and logs "You scouted 2 cards · none hidden now" and "Revealed: Move · Pawn".
  - **Deep Vision.** Its point is attributed. `MatchFx._score_floats` splits "+N" from "+1 Deep Vision", the log gets "(+2, incl. +1 Deep Vision)", and the chip flashes. This is tested (`test_deep_vision_point_is_attributed_when_it_scores`).
  - I checked `EventText.bonuses` against the engine's `_credit_capture`. Both apply Trophy Case to the credited side and the Deep Vision penalty to player victims, for capture, explosion and burn-out, so the split is exact.

  No screenshot shows the attribution float. That is a gap in the evidence, not in the game.
- **Polish 4.5.** **Fixed.**
  - The mini coin sits inside the card, with a 2 px inset (44, 1080p/17).
  - The row keeps its slots through the flip (scout_reveal_01 → 03: the backs stay at the same x).
  - turn_banner_01 shows the opening wipe with the header label hidden: no stale text beside it.
  - The names line is built with NBSP-glued tokens, so it can't end on "·".

  Nit: in scout_reveal_01 the shot catches a closing match-start banner as an empty outlined box over "You / Rookie Rex". That is the normal wipe (the text is already clipped out), but it looks odd frozen.
- **Feel 4.5.** The card shown beside the rank numbers, the source wash and the target ring (turn_banner_09) give about 1.3 s per action. Shift or a board click hurries it. The flips are 0.12 s apart.
- **Sound 4.5.** `turn_opponent` is a quiet tap, and captures against you are darker. The reveal plays `reward_reveal` with one `card_draw` per flip. The silent opponent draw is documented.
- **Accessibility 4.5.** Shown and hidden differ by shape and pattern. The names line is the text and keyboard path, and reduced motion swaps the flip for a fade.

### Match, escape prompt (36, 1080p/06, 16x10/06, large_text/36)
- **All 4.5.**
  - "Costs 1 energy from your next turn · next turn: 2/3".
  - "Stay in check", and "Click a square to escape · N stay".
  - The CHECK tag sits inside the square.
  - The board doesn't move at Large text.
  - `check_stay` plays for a decline.

### Match over (11, large_text/11)
- **All 4.5.** It leads with "King captured: you took their king", the king lies toppled, and the reward line sits above Continue. The stinger plays once. Nit: the log line reads "King captured on c6 (+0)"; the "+0" is noise.

### Reward (12, 1080p/07, 16x10/07, large_text/12)
- **All 4.5.** 1.3× cards, key caps under them, "Rare · costs 2 energy", and "Deck: 6 cards" next to "Skip · +1 point". It deals in with `reward_reveal`.

### Shop (14–16, 1080p/08, 16x10/08, large_text/14–16)
- **Clarity 4.5.** "Need 3 pt" and "Sold", with one filled action.
- **Polish 4.5.** **Fixed**: "−2 pt" now starts above the card, clear of its cost coin (large_text/16). Nits:
  - the plate crosses the CARDS panel's top border;
  - "Bought Pawn" still sits over the bought card's glyph (opaque and short-lived).
- **Feel / Sound / Accessibility 4.5.** The toast appears where you acted, the HUD flashes, and `ui_purchase` plays. 1–9 focus an offer.

### Coaching (17, 18, 1080p/11, 16x10/11, large_text/17, 18; coaching_accept_01–07)
- **Clarity 4.5.** The chips read "Accepted · upgraded" and "Declined", the status line reads "Bishop learned Book", and the BOOK ribbon appears at once.
- **Polish 4.5.** **Fixed**: the plate rises from above the card, so the upgraded glyph and ribbon stay visible (coaching_accept_01–06). Nit: during frames 01–02 the plate straddles the offer panel's top border. This is a documented trade-off.
- **Feel / Sound / Accessibility 4.5.** A warm glow, an oxblood flash on the HUD, and `ui_confirm`.

### Deck & collection views (15, 19, 20, 39, 1080p/12, 16x10/12, large_text/15, 19, 20, 39; deck_open_01–07)
- **All 4.5.**
  - "×N" tabs under the cards, and the detail line follows focus.
  - The panel is opaque from frame 1 and the items deal in within about 0.4 s.
  - Focus is trapped in the overlay.

  Nit: at Large text 8 cards wrap with one orphan (large_text/19).

### Run end (24, 29, 1080p/09, 16x10/09, large_text/24, 29; run_end_victory_01–08)
- **Clarity 4.5.** Headline, back rank, counted figures, the unlock with its rule, and "Pick the set when you start a run".
- **Polish 4.5.** The panels are top-aligned, the deck row has "×N" tabs, and the seal keeps the panel from looking empty. Nit (new): at the reveal, the seal grows to 125 % and fades **in the same place** the content deals in. run_end_victory_06 shows the "?" ring drawn over the "Fire pieces" title.
- **Feel 4.5.** **Fixed since critique 4.**
  - From the last figure the seal charges: halo and thicker rim (frame 04).
  - It opens at clamp(stinger end, figures, figures + `unlock_hold` 0.9 s), about 1 s after the figures (frames 04 → 05), instead of 2.4 s of a still "?".
  - The fanfare cuts the stinger's tail (`Sfx.stop_stinger()` then `unlock_fanfare`).
- **Sound 4.5.** The run stinger plays over silence and the lounge loop returns after `stinger_time_left()`. Leaving early fades the stinger (`_exit_tree`).
- **Accessibility 4.5.** Reduced motion drops the burst, drop, topple and seal charge; the figures still count.

### Settings (37, 41, 1080p/02, 16x10/02, large_text/37, 41; settings_open_01–07)
- **Clarity 4.5.** Two columns: Sound and Motion, Display and Controls. Choices are segmented buttons, toggles say ON/OFF, and the footer reads "Saved automatically · F1 opens settings, Esc closes".
- **Polish 4.5.** Nits:
  - **New**: the panel opens growing from its **top-left corner**, not its centre. Its left and top edges stay at x 124 / y 33 while the right edge goes 1097 → 1141 → 1155 (settings_open_01–03). Cause: `pivot_offset = _panel.size / 2.0` is set in a tween callback, so the size it reads is still unset when the scale starts. It lasts 0.15 s.
  - At Large text the Controls column scrolls and its hint is below the fold (accepted).
- **Feel / Sound / Accessibility 4.5.**
  - The scrim is fast and the panel opaque from frame 1, with `ui_open` / `ui_close`.
  - Volume previews play once a slider rests.
  - Rebinding swaps on conflict, and Reset keys is there.
  - Focus is trapped in the panel.

### Cohesion 4.5
One palette, type scale, focus language, timing table (`config/ux.json`) and sound palette. Iteration 5's new pieces reuse existing language: the plated float (`Feel.spend_float`), the chip glow (`flash_artifact`), and the card flip drawn in `CardView`. Not a 5, because the "−N pt" plate crossing panel borders and the seal / content overlap show that a few transitions still don't respect their containers.

### Delight 4.5
**Raised from 4.** Both of critique 4's Delight blockers are gone:
- the Scout payoff now lands with its own flip and caption pop;
- the run-end seal builds anticipation and opens in time with the fanfare.

The capture knock-away, the one-beat explosion, the map hop, the darker capture against you and the Scout flip are each a small, well-timed pleasure. It isn't a 5: glyph-in-a-circle art (an accepted direction) caps the "wow", and no sound has been heard.

## 3. Critique 4's findings: status (each checked myself)

| # | Critique-4 finding | Status | Evidence |
|---|---|---|---|
| 1 | Scout caption and names announce the result before the flip | **Fixed** | scout_reveal_01–07 "3 shown · 2 hidden"; 10 "all shown" + log. `show_hand(..., hold_text)`, `refresh_text()` after the last flip; `test_the_scout_reveal_text_waits_for_the_flips` |
| 2 | Deep Vision point never attributed | **Fixed** (no screenshot of it) | `EventText.bonuses` / `bonus_note`, `MatchFx._score_floats`, `MatchView.flash_artifact`; matches the engine's `_credit_capture`; test at `test_ui_opponent_hand.gd:407` |
| 3 | Run end sits on a still "?" for about 2.4 s | **Fixed** (new overlap nit) | run_end_victory_04 charge halo, 05 opens; `clampf(..., figures_done + unlock_hold)` |
| 4 | Five-artifact orphan tile, void, short wrap | **Fixed** | 42, 1080p/15, 16x10/15: centred fifth tile, list under the subtitle, text to the key cap |
| 5a | Mini coin cramped across the corner | **Fixed** | `MINI_COIN := MIN_FONT * 0.72 / COIN_RADIUS`, 2 px inset; 44, 1080p/17 |
| 5b | Names line ends with "·" at Large text | **Fixed** (code and test; the final Large-text state isn't in a shot) | `OpponentHand.names_text` with NBSP, re-broken on `theme_changed` |
| 5c | Row spacing jumps at the reveal | **Fixed** | scout_reveal_01 vs 03: same x; `_relayout()` depends on the count only |
| 6 | Banner first-frame sliver | **Fixed** | turn_banner_01: no header label beside the wipe; `_show_turn_label` |
| 7a | Ghost settles on the origin square | **Fixed** | card_play_energy_04 (a2), player_capture_03 (c5) |
| 7b | Coaching plate hides the upgraded glyph | **Fixed** (crosses the panel border) | coaching_accept_01–06 |
| 7c | Shop plate over the cost coin | **Fixed** | large_text/16 |
| 7d | Run stinger trails over the next screen | **Fixed** | `run_end_screen.gd` `_exit_tree` → `Sfx.stop_stinger()` |
| 7e | Screenshot-tool HUD vs YOU artifact mismatch | **Fixed** | player_capture: both "No artifacts"; explosion: both "Powder Keg" |
| 8 | Large text: map's third next stop under a scroll bar | **Open** (trade-off) | large_text/03 |
| CR | `_refresh` couples layout and text | **Fixed** | `_relayout()` + `refresh_text()` |
| CR | `faces()` typed loop over `get_children()` | **Fixed** | `_cards()` filters `is CardView`. Leftover: `_relayout()` still counts `get_child_count()` |
| CR | `MINI_COIN` not derived from the font | **Fixed** | see 5a |
| CR | Untyped `parsed` / `saved_bindings` | **Fixed** | `settings.gd:58` `var parsed: Variant` + `is Dictionary` |
| CR | `load()` per screen in `main.gd` | **Fixed** | `SCREENS` preload constants |

## 4. Fixes (no line is below 4.5; these are the nits behind the remaining half point)

1. **Settings modal grows from its top-left corner.** (settings_open_01–03)
   - Set `_panel.pivot_offset` after the panel has a size: `await get_tree().process_frame`, or connect `resized` once. Or compute it from the panel's minimum size before setting `scale`.
   - Apply the same check to `ItemOverlay`, which uses the identical callback pattern.
   - Files: `scripts/ui/widgets/settings_panel.gd:86–90`, `scripts/ui/widgets/item_overlay.gd:70–75`.
2. **Unlock seal and content overlap at the reveal.** (run_end_victory_06)
   - Let the seal finish fading before `Feel.reveal(items)` starts (start the reveal with a delay of about 0.5 × `reveal`). Or shrink it into the emblem's slot instead of growing to 125 %.
   - File: `scripts/ui/screens/run_end_screen.gd` (`Seal.open`, `_play`).
3. **Plates crossing panel borders.** (coaching_accept_01–02, large_text/16) Start "−N pt" inside the offer panel (clamped to its top padding) and rise within it. Or draw it above the panel's border on a z-index with a small gap. Files: `scripts/ui/feel.gd` `spend_float`, `coaching_screen.gd`, `shop_screen.gd`.
4. **Large-text map next stops.** Compact the stop cards at Large text (one line: key cap, type and name; the "Then:" line moves to the tooltip), so all three fit without a scroll bar. Files: `scripts/ui/screens/map_screen.gd` (`_fit_stops`).
5. **Smaller items.**
   - Drop "(+0)" from king-capture log lines (`event_text.gd`).
   - Give the played-card ghost an arc that avoids passing over other tokens, or fade it under the pieces' layer.
   - Add a screenshot of the Deep Vision attribution float, so the evidence covers it (`tools/screenshots/shot_moments.gd`).

## 5. Code-review findings (godot-code-review checklist; `scripts/ui/**` changed since 6001818, focused on the iteration-5 diff)

### Critical
- None. Across `scripts/ui/**` there is:
  - no `_process` / `_physics_process`;
  - no `free()`;
  - no `$A/B/C` paths;
  - no untyped `var x =`.

  The only runtime `load()` is in `Sfx._load`, for config-driven ids. The `get_parent()` uses are bounded and local: the focus trap, overlay reparenting and three layout reads.

### Improvements
- **`settings_panel.gd:89`, `item_overlay.gd:74`: pivot set in a tween callback before the panel has a size** → the scale grows from the top-left (§4.1). **Fix:** set the pivot once the size is known (after layout, or on `resized`).
- **`run_end_screen.gd:21`: orphan doc comment.** "## Longest the sealed unlock waits after the last figure (seconds at speed 1.0)." has no constant under it, so GDScript attaches it to `var _stats` (the value moved to `config/ux.json` → `unlock_hold`). **Fix:** delete the line.
- **`opponent_hand.gd` `_relayout()` uses `get_child_count()`**, while `faces()` / `back_count()` were moved to `_cards()` precisely so that non-card children can't skew them. **Fix:** `var count := _cards().size()`.
- **`match_fx.gd` `_score_floats()` both builds the float list and flashes the artifact chips** (`view.flash_artifact` inside the loop). A builder with a side effect is easy to call twice: for example, an explosion's queued `_blast_floats` and a future re-layout would double-flash. **Fix:** return the parts and flash at the call site in `_animate_capture` / `_animate_burn_out`.
- **`match_fx.gd` `_init`: `artifacts` is captured once.** That is fine under today's rules, where artifacts are fixed for the match. Note it in the comment so a future mid-match artifact doesn't silently mis-attribute points.
- **Docs drift in `docs/ux/sound_hooks.md`:**
  - line 195 says `check_stay` falls back to `ui_cancel`; the code (`match_fx.gd:109`) and `feedback_map.md` use `turn_opponent`;
  - line 172 says `card_draw` plays "once per batch"; it plays per card (`match_fx.gd:365`, `card_view.gd:131`).

### Positive
- `OpponentHand` takes only `visible_opponent_hand()` / `hidden_card_count()`, so R6 holds: a hidden face is never built.
- The text/layout split (`hold_text`, `refresh_text()`) is small and tested, and the reveal awaits only MatchFx's own `wait()`.
- `EventText.bonuses` reconstructs artifact points from config and side artifacts without touching the core, and it agrees with `_credit_capture` for all three causes.
- `Feel.spend_float` / `top_centre_in` put the "−N pt" placement in one helper shared by the shop and coaching.
- The seal charge is one tween on a redraw-driven property, skipped under reduced motion. `_exit_tree` → `Sfx.stop_stinger()` closes the trailing-stinger bug.
- All new tunables are in `config/ux.json` (`unlock_hold`) or `Metrics`.

## 6. Feedback-map gaps and open UX bugs

I checked every API event against `match_fx.gd` and the screens, and every `Sfx.play` id (including the dynamic `capture_sound`, `piece_land_*`, `card_draw` via bind, `victory`/`defeat` and `run_victory`/`run_defeat`) against `config/ux.json` and `assets/audio/sfx`. Every configured sound has a call site and every call site has a sound.

| Event | Visual | Sound | Note |
|---|---|---|---|
| `turn_start` / `turn_end` | banner / discard sweep | `turn_player` / `turn_opponent` | OK |
| `energy` | pips | `energy_refill` (player) | the opponent's is a documented silence |
| `draw` / `shuffle` / `discard` / `redraw` | deal, pile pop, sweep | `card_draw`, `card_shuffle`, `card_discard` | the opponent's are documented silences |
| `card_played` | ghost to the destination; opponent card reveal | `card_play`, `energy_spend` | OK |
| `reveal` (Scout) | flips, glow, then caption pop and log | `reward_reveal` + `card_draw` ×N | **gap closed** |
| `move` / land | crouch, hop, land | `piece_move`, `piece_land_*` | OK |
| `capture` / `explosion` / `burn_out` | knock-away, "+N" and "+1 <artifact>", chip flash | `capture` / `capture_against`, `explosion`, `fire_burnout` | **gap closed** (artifact attribution) |
| `score` | track fill and flare | `score_tick` | OK |
| `shield_block`, `ignite`, `burn_tick`, `promotion` | ring, arc, badge, swap | own cues | OK |
| `check` / `escape` / `escape_declined` | rings, tag, toast | `check` / `escape` / `check_stay` | OK. `sound_hooks.md` names the wrong fallback (§5) |
| `match_over` | panel | `victory` / `defeat` | the count-up is a documented silence |
| Run-end unlock | seal charge, then open | `unlock_fanfare` (stinger tail cut) | OK |

No undocumented silent events remain.

### Open UX bugs (all minor)
1. The settings modal (and possibly the deck/collection overlay) grows from its top-left, not its centre (settings_open_01–03).
2. The unlock seal is drawn over the unlock's title during the reveal beat (run_end_victory_06).
3. "−N pt" plates cross the offer panel's top border for their first frames (coaching_accept_01–02, large_text/16).
4. At Large text the map's third next stop is under a scroll bar (large_text/03).
5. "(+0)" in king-capture log lines (11, large_text/11).
6. The played card's ghost passes over other tokens on its way (card_play_energy_02).
7. Docs: two stale lines in `sound_hooks.md` (§5).
