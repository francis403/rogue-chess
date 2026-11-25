# UX critique 3: independent review after iteration 3

**What I looked at**
- **Images.** I read every image:
  - the 41 base shots `docs/screenshots/01–41`;
  - the 14 shots each in `1080p/` and `16x10/`;
  - the 41 shots in `large_text/`;
  - all 72 motion frames: `player_capture`, `explosion`, `card_play_energy`, `turn_banner`, `settings_open`, `map_travel`, `coaching_accept`, `deck_open`, `run_end_victory`.
  - For a before/after check I compared one pre-pass original, `git show 6001818:docs/screenshots/05_match_start.png`.
- **Docs.** I read `docs/SPEC.md`, `docs/UX_DECISIONS.md`, `docs/ux/feedback_map.md`, `docs/ux/sound_hooks.md`, `config/ux.json` and `README.md`.
- **Code.** I read `sfx.gd` (play, stingers, hover hook), `match_fx.gd`, `match_screen.gd` (run and opponent loop), `match_view.gd`, `run_end_screen.gd`, `card_view.gd`, `score_race.gd` and `settings_panel.gd`. I grepped the rest of `scripts/ui/**`.
- **Order.** I formed my scores before I read `critique_1.md` and `critique_2.md`.

**Runs**
- `--headless --import`: clean.
- GUT: **385/385 pass**, 15 778 asserts. The only warnings are 5 GUT notes about the inner class `TestTmp`, plus expected warnings for unknown sound ids and bad JSON from the negative tests.
- `run_sim.gd --runs=100 --seed=1`: **PASS**. No crashes, illegal states, softlocks or log errors. Average AI decision time is 1.8 ms, worst case 20 ms.
- `python3 -I tools/audio/check.py`: "all checks passed", 12.81 MB in total.

**Core untouched.** `git diff --stat 6001818 -- scripts/core config` lists only `config/ux.json` (+171). **Met.**

**Overall verdict.** This is now a cohesive, intentional-looking game, and the jump from the pre-pass `05_match_start` is large. Every critique-2 item was addressed, and I confirmed almost all of them in pixels or code:
- the opaque wiping banner;
- live hand playability;
- clipped board effects;
- caption plates on the map;
- input remapping, Large text, a separate screen-shake toggle and a window mode;
- one stinger at a time;
- hover ticks everywhere;
- a way to hurry the opponent;
- a roster square cursor;
- the test suite is green.

What keeps lines below 4.5 falls into two groups:
- **The new Large text mode isn't finished.** The first map screen clips, the match board shifts sideways, settings scrolls its section headers out of view, and the roster shows a half row.
- **A handful of timing and placement issues in the menus:**
  - the coaching "−N pt" float lands on the card art;
  - the run-end unlock appears silently and its fanfare comes ~1.7 s later;
  - menu music comes back before the run stinger has finished.

## 1. Score table

| Screen | Clarity | Visual polish | Feel | Sound | Accessibility |
|---|---|---|---|---|---|
| Title | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Set select | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Artifact select | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Map | 4.5 | **4** | 4.5 | 4.5 | **4** |
| Roster | 4.5 | **4** | 4.5 | 4.5 | 4.5 |
| Match (normal) | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Match (opponent turn) | 4.5 | **4** | 4.5 | 4.5 | 4.5 |
| Match (escape prompt) | 4.5 | **4** | 4.5 | 4.5 | 4.5 |
| Match over | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Reward | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Shop | 4.5 | **4** | 4.5 | 4.5 | 4.5 |
| Coaching | 4.5 | 4.5 | **4** | 4.5 | 4.5 |
| Deck & collection views | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Run end | 4.5 | **4** | **4** | **4** | 4.5 |
| Settings | 4.5 | **4** | 4.5 | 4.5 | 4.5 |

| Whole game | Score |
|---|---|
| Cohesion | 4.5 |
| Delight | **4** |

There are 11 lines at 4 (in bold). None are below 4, and none are at 5. Critique 2 had 24 lines at 4.

## 2. Evidence per score

### Title (01, 30, 37, 1080p/01, 16x10/01, large_text/01, 30)
- **Clarity 4.5.** New Game is the one filled, focused action. The progress panel shows pips plus "1 / 2 unlocked", and later it names the artifacts.
- **Polish 4.5.** It is the strongest composition in the game: the lamp vignette, the barely-there board, the brass-flanked eyebrow. It is crisp at 1.5× and balanced at 16:10. The progress panel is still a little heavy for a title page.
- **Feel 4.5.** The row drops in and the light sweep and wave are ambient. The ambient loops are not scaled by the animation speed, which is correct: scaling them would make them flicker at Instant.
- **Sound 4.5.** A single knock as the row lands, under a 128 s lounge loop.
- **Accessibility 4.5.** Focus starts on New Game, F1 opens settings, reduced motion stops the loops, and nothing clips at Large text.

### Set select (02, 25, 16x10/10, large_text/02, 25)
- **Clarity 4.5.** Worth tables, three rule lines per set, "Locked · Beat the boss to unlock", key caps, and "Enter or a number key picks a set".
- **Polish 4.5.** The tiles are full and of equal height, and the action sits under them. The focus is a dashed ivory ring, so it can't read as "chosen".
- **Feel / Sound 4.5.** Pop, a 0.22 s beat, then the next screen. `ui_confirm` / `ui_error`.
- **Accessibility 4.5.** Fine at Large text. The locked tile keeps full-contrast text.

### Artifact select (31, 1080p/13, 16x10/13, large_text/31)
- **Clarity 4.5.** Wide rows, emblems, and a "CHOSEN" chip. "2 / 2 chosen" sits next to Continue.
- **Polish 4.5.** The chips and key caps are pinned to the same corners on every tile, so they line up. The critique-2 misalignment is gone.
- **Feel / Sound 4.5.** Toggle pop and `ui_toggle`. Going over the limit shakes and plays `ui_error`.
- **Accessibility 4.5.** Focus (dashed ivory, 5 px outside) and chosen (solid brass plus a tinted face plus the chip) now differ in shape, colour and words.

### Map (03, 13, 21, 38, 1080p/03, 16x10/03, large_text/03, 13, 21, 38; frames map_travel_01–08)
- **Clarity 4.5.** Next stops have a halo, key caps and a dashed path. The side list has "Then: …" lines. The legend covers both node types and node states.
- **Polish 4.** Two problems:
  - **At Large text the first map screen overflows the 720 px window** (large_text/03). The side panel, with three next stops, a longer intro and a bigger legend, runs past the bottom: the legend is cut after "Ahead". The map stretches with it, so the floor-1 nodes sit at y≈703 and their "EASY" captions are cut by the window edge. The same screen with one or two stops (large_text/13, 21) fits.
  - At normal size the floor-1 halos are cut flat by the caption plates (03, 16x10/03). This is a nit.
- **Feel 4.5.** Choosing a stop is clean: the other choices drop their glow at once, the marker hops along the path, and the screen changes 0.6 s later (frames 01–08). On the very first travel the marker starts from a "start" dot right under floor 1, so the trip is so short it reads as a jump.
- **Sound 4.5.** `map_travel`, plus a hover tick only on reachable nodes. The silence on other nodes is a documented choice.
- **Accessibility 4.** Arrows and 1–3 work and the tooltips are rich. But the screen every run passes through is clipped with Large text on, so the accessibility option breaks the screen it should help.

### Roster (04, 22, 26, 1080p/04, 14, 16x10/04, 14, large_text/04, 22, 26)
- **Clarity 4.5.** The ★ legend, "To win: …" pinned to the bottom, the budget pips and "8 pieces ready · 1 budget left". The keyboard cursor line says "Arrows choose a square · Enter places your queen · Esc puts it back".
- **Polish 4.** Two problems:
  - **At Large text the collection list shows a half row** ("Knight" cut at y≈660 in large_text/04, 22, 26). This contradicts the decision that the list window is "cut to whole rows".
  - The opponent-deck mini cards' cost coins render at about 8–9 px. The `MIN_FONT` 12 floor applies to card names, not to these coins.
- **Feel 4.5.** Pickup and land sounds by weight, a pop on placement, and a dashed cursor that carries a ghost of the piece.
- **Sound 4.5.**
- **Accessibility 4.5.** The cursor works. The coins above are decorative duplicates of the deck list, so this keeps its 4.5.

### Match, normal (05–08, 32–34, 40, 1080p/05, 16x10/05, large_text/05–08, 32–34, 40; frames player_capture, explosion, card_play_energy)
- **Clarity 4.5.**
  - The desk hint has an eyebrow, and the KEYS list sits right under it.
  - Board marks are shape-first.
  - The legend has "Hole: no piece".
  - "End turn · nothing to play" and "Redraw · won't help" (28).
  - Playability updates live: the Hold Knight card is sunk during the opponent turn (turn_banner_01–11).
- **Polish 4.5.** Effects stay on the squares. Knocked-away victims are clipped at the frame (explosion_02–03). Floats land on free squares ("+3 +1 +1" in explosion_02). The ghost card shrinks onto the piece's square (card_play_energy_02–05). The hand closes up and renumbers in the frame right after the play.
- **Feel 4.5.**
  - A capture reads as cause and effect: impact flash, then the victim is knocked under and away, then "+3", then the score track flares (player_capture_04–08).
  - The explosion lands as one beat (explosion_01–02).
  - The total is about 0.6 s, so it never drags.
- **Sound 4.5.**
  - Coverage is complete (see §6).
  - The ten most frequent sounds have 3 variants each, with per-play jitter and cooldowns.
  - Impacts have a measured 1–4 kHz presence of −11 to −13 dB.
  - One nit: `piece_land_medium_2` has −19.2 dB presence against −11.7 / −10.8 for its siblings, so one bishop or rook landing in three is noticeably duller.
  - Your capture and the opponent's capture use the same `capture` and `score_tick` sounds. That is acceptable, but a missed chance.
- **Accessibility 4.5.** Remappable `rc_*` actions, live key caps, colour-blind cues (maple inner stroke on capture rings, a dashed burn arc, a Cheaper arrow tab), and 12 px floors on hand cards.

### Match, opponent turn (09, 10, 35, large_text/09, 10, 35; frames turn_banner_01–11)
- **Clarity 4.5.** The card is revealed face up beside the rank numbers, the source square gets an oxblood wash and the target a hollow ring (turn_banner_08). The hint says "Rookie Rex plays Move." and the hurry line follows.
- **Polish 4.** Two problems:
  - **At Large text the board moves sideways when the hint changes.** During the opponent turn the right column widens to fit "Hold Shift or click the board to hurry", so its left edge goes from x 992 to 987 and the board from x 461 to 458 (large_text/09, 35 vs 05). It springs back on your turn. The base 720p shots don't shift.
  - The banner's wipe leaves a sliver of the header's turn label visible at its left edge (turn_banner_02, x≈297).
- **Feel 4.5.** Hold Shift or click the board to hurry, and the opponent pauses while a modal is open. Each action takes about 1.3 s at Normal (delay 0.45, reveal hold 0.25, move, land), which is fine with hurry available.
- **Sound 4.5.** `turn_opponent` is a quiet 0.4 s tap. The opponent's actions use the same move, land and capture sounds as yours.
- **Accessibility 4.5.** The hurry key is remappable and shown in the hint.

### Match, escape prompt (36, 1080p/06, 16x10/06, large_text/36)
- **Clarity 4.5.** "CHECK!" box with the energy cost, "Stay (keep the king in check)", "Click a square to escape · N stay". CHECK tag and doubled ring stay inside the king's square.
- **Polish 4.** At base size the board doesn't move (461–818 in both 36 and 05). **At Large text the prompt widens the right column (x 973) and pushes the board left by 9 px** (452 vs 461), and the score race moves with it (large_text/36). The test that "the board's rect is unchanged when the prompt appears" evidently only runs at normal size.
- **Feel / Sound 4.5.** Hit-stop, three pulse rings, `check` (with the D6 ping layer), then `escape` / `ui_cancel`.
- **Accessibility 4.5.**

### Match over (11, large_text/11)
- **Clarity 4.5.** Leads with the reason: "King captured: you took their king" with the toppled king. The score is hidden when the score didn't decide the match. The reward line sits above Continue.
- **Polish / Feel 4.5.** Scrim, then the panel settles. The over_delay beat on the final board lands well.
- **Sound 4.5.** `victory` / `defeat` play once, and a run stinger now replaces it instead of stacking.
- **Accessibility 4.5.**

### Reward (12, 1080p/07, 16x10/07, large_text/12)
- **Clarity 4.5.** "You earned +2 training points. Pick one card, or skip it for +1 more." Key caps under each card, the "Rare · costs 2 energy" caption, and "Deck: 6 cards" next to Skip.
- **Polish 4.5.** The 1.3× cards read well. Focus is a ring with no lift, so the row stays aligned.
- **Feel / Sound 4.5.** `reward_reveal` with a staggered deal-in, then `ui_confirm` plus a pop.
- **Accessibility 4.5.**

### Shop (14–16, 1080p/08, 16x10/08, large_text/14–16)
- **Clarity 4.5.** "Sold", "2 pt · can't afford" and the Services copy. Exactly one filled action ("Leave the shop").
- **Polish 4.** Two problems:
  - **The panels jump when a purchase changes the button labels.** At Large text, the cards panel goes from x 96–627 to x 84–631 and the pieces panel from x 652–907 to x 656–919 (large_text/14 vs 16), because "2 pt · can't afford" is wider than "Buy · 2 pt". The whole row reflows under the cursor.
  - The "Bought Bishop" plate sits over the bought card's glyph, which is acceptable but busy.
- **Feel 4.5.** The toast lands where you clicked, "−2 pt" floats up, and the HUD flashes.
- **Sound 4.5.** `ui_purchase` plus a HUD `energy_spend` tick, and Buy now ticks on hover.
- **Accessibility 4.5.** Affordability is said in words. 1–9 focus an offer.

### Coaching (17, 18, 1080p/11, 16x10/11, large_text/17, 18; frames coaching_accept_01–07)
- **Clarity 4.5.** Item, upgrade name, rule, price, "Accepted · upgraded" / "Declined" chips, and the status "Bishop learned Book".
- **Polish 4.5.** Full-size cards, one primary button, and a declined card sinks with its cost coin still readable.
- **Feel 4.** **The "−2 pt" float is drawn straight over the bishop glyph, with no plate, for its whole life** (coaching_accept_01–07): "–2pt" overlaps the glyph circle and reads as a smudge. The shop solved this with `Feel.toast`'s plate. The warm glow on the offer and the HUD flash are good.
- **Sound 4.5.** `ui_confirm` / `ui_cancel` / `ui_error`, and Accept / Decline now tick on hover.
- **Accessibility 4.5.**

### Deck & collection views (15, 19, 20, 39, 1080p/12, 16x10/12, large_text/15, 19, 20, 39; frames deck_open_01–07)
- **Clarity 4.5.** Copies are grouped as "×N", and the detail line follows focus and hover ("Queen · cost 3 · Move one queen").
- **Polish 4.5.** The modal hugs its content. The "×2 / ×3" badge overhangs the card's bottom edge by design.
- **Feel 4.5.** The panel is opaque from frame 1 and grows from 94 %, then the items deal in (deck_open_01–05), all in under 0.4 s.
- **Sound / Accessibility 4.5.** `ui_open` / `ui_close`, focus trap, ring, Esc / D / C.

### Run end (24, 29, 1080p/09, 16x10/09, large_text/24, 29; frames run_end_victory_01–08)
- **Clarity 4.5.** The headline, the run's back rank (with the king toppled on a loss), the figures, and the unlock with its rule.
- **Polish 4.** Two problems:
  - **For about 2.1 s, and at Instant for the stinger's full 3.8 s, the left third of the page is an empty hole.** The unlock panel is hidden but keeps its place (frames 02–07), so the composition is lopsided until it appears (08).
  - In the deck row, a card with a "BOOK" ribbon draws its glyph smaller and lower than its neighbours (Bishop in frames 03–08; Pawn in large_text/24).
- **Feel 4.** The burst, row drop-in and sequential count-ups are a real payoff (02–07). But **the unlock, the single most rewarding thing on the screen, appears silently at ≈2.15 s, and its fanfare and glow fire about 1.65 s later.** They wait for `Sfx.stinger_time_left()`, about 3.8 s (`run_end_screen.gd:109`). The reveal and its sound are disconnected. At Fast or Instant the visual side shrinks but the stinger wait doesn't, so the gap grows to about 3.5 s.
- **Sound 4.** **`MUSIC_BACK_AFTER` is 3.5 s, but `run_victory` and `run_defeat` measure 3.80 s** (`check.py`). So `music_menu` starts its fade-in under the stinger's tail, and then `unlock_fanfare` plays over returning music (ducked). UX_DECISIONS justifies the constant as "the stinger's real length", which it isn't. Otherwise one-stinger-at-a-time works: `run_defeat` replaces `defeat`, and the fanfare queues.
- **Accessibility 4.5.**

### Settings (37, 41, 1080p/02, 16x10/02, large_text/37, 41; frames settings_open_01–07)
- **Clarity 4.5.** Two columns: Sound + Motion and Display + Controls. ON/OFF are given in words and knob position. "Saved automatically · F1 opens settings, Esc closes". Leave run… asks first.
- **Polish 4.** Two problems:
  - **At Large text, the body is already scrolled when the panel opens.** Focus on Master scrolls the body, so the "SOUND" and "DISPLAY" eyebrows are cut off above the visible area (large_text/37, 41). The panel opens mid-scroll.
  - At normal size a scroll track is drawn down the right column (settings_open_01–07, x≈1135), so the body overflows by a few pixels even at 1280×720.
- **Feel 4.5.** Opaque at once, grows from 94 % (frames 01–03), and settings apply live.
- **Sound 4.5.** A preview per bus once the slider rests, and `ui_open` / `ui_close`.
- **Accessibility 4.5.** Key remapping with swap-on-conflict, Large text, a screen-shake toggle, a window mode, and reduced motion.

### Cohesion 4.5
There is one palette, one type scale, one button and focus system, one timing table and one sound palette, and every hover ticks now. It isn't a 5 because Large text, the newest system, doesn't yet hold the layout guarantees the rest of the game does (map, board, roster, settings).

### Delight 4
The capture, the one-beat explosion, the map hop, the purchase toast and the run-end burst all land. Two things hold it back:
- the two most rewarding menu moments (an accepted coaching upgrade and a new unlock) are where the timing or placement fumbles: a smudged float, and a silent reveal followed by a late fanfare;
- every capture sounds the same whoever makes it.

## 3. Earlier critiques' findings: status (verified myself)

| # | Critique-2 finding | Status | Evidence |
|---|---|---|---|
| 1 | Translucent turn banner ghosts the header | **Fixed** (nit left) | turn_banner_02–07: opaque panel and a clean left wipe. Frame 02: sliver of the header label at x≈297 |
| 2 | Stale card playability | **Fixed** | turn_banner_01–11: Hold Knight sunk for the whole opponent turn. `MatchFx.refresh_playable()` |
| 3 | Refusals and check inaudible on laptops | **Fixed in data, unverified by ear** | `check.py` presence: `ui_error` −12.8, `ui_cancel` −13.4, `turn_player` −13.4, `check` −12.9 dB |
| 4 | Stinger stacking | **Fixed**, new issue | `sfx.gd:149–156` stinger exclusivity and queueing. New: music back at 3.5 s < stinger 3.8 s (§2 Run end) |
| 5 | Effects leave the board | **Fixed** | explosion_02–03: victims clipped at the frame. The CHECK tag is inside the square (36) |
| 6 | Map paths strike captions | **Fixed** | 03 and 16x10/03: captions on walnut plates |
| 7 | Shop/coaching hierarchy, toast placement | **Fixed (shop)**, **new (coaching)** | 14 and 16: one primary, toast on a plate. coaching_accept_01–07: "−2 pt" over the glyph |
| 8 | Artifact focus ≈ chosen; chips misaligned | **Fixed** | 31 and 16x10/13: dashed ivory focus, pinned chips |
| 9 | Remapping, UI scale, window, shake | **Fixed** | 37: Controls list, Large text, Window, Screen shake |
| 10 | Missing hover ticks on `sfx = "none"` buttons | **Fixed** | `sfx.gd:466–471` reads only `sfx_hover` |
| 11 | Opponent turn pacing; modal pause | **Fixed** | Hurry (Shift or click), `reveal_hold` 0.25, `A11y.is_modal_open` poll (`match_screen.gd:526`) |
| 12 | Roster keyboard square choice; cut row | **Fixed at base, regressed at Large text** | 1080p/14 and 16x10/14 cursor. large_text/04: half row |
| 13 | 12 px floor on mini cards | **Mostly** | Coaching now uses full-size cards. Card names are floored at `MIN_FONT` 12. The roster opponent-deck coin figures are still about 8–9 px |
| 14 | Modals hug content; run-end headers aligned | **Fixed** | 19, 20, 24 |
| 15 | Legend: holes, fire | **Fixed** | 32: "Hole: no piece". "Burn turns left" was already there |
| 16 | Copy: "King captured", king angle, End-turn cap collision, deck life, coaching frames | **Fixed** | 11, 28, deck_open frames, coaching_accept frames |
| 17 | Desk dead space | **Fixed** | 05: KEYS right under the hint |
| 18 | Red `test_ui_full_run` | **Fixed** | GUT 385/385 |
| CR | `card_view.gd` per-draw arrays | **Fixed** | `card_view.gd:46–47` member arrays |
| CR | `score_race.gd` literals | **Fixed** | Named constants at `score_race.gd:7–28` |
| CR | Hard-coded keys | **Fixed** | `rc_*` actions from `config/ux.json`, `A11y.is_action` |
| CR | Synchronous AI search | **Measured, fine** | sim: average 1.8 ms, max 20 ms per decision |

Critique-1 items 1–18 were already verified in critique 2. I rechecked the ones that could regress:
- the shop anchor (16);
- the match-over reason (11);
- the explosion single beat (explosion_01–02);
- the hand re-layout (card_play_energy_02);
- the stale check marks (35);
- the opponent score ink (`score_race.gd`, `OXBLOOD_INK`).

All of them still hold.

## 4. Prioritised fixes (every line below 4.5)

1. **Make the first map screen fit with Large text.** At Large text, cap the "Next stops" list, for example by dropping the "Then: …" line or using two-line cards, or let the side panel scroll its stop list. Never let it grow the map's height: the map's floor spacing must come from the window, not from the side column. [Map polish, Map accessibility] `scripts/ui/screens/map_screen.gd`, `scripts/ui/widgets/map_view.gd`.
2. **Give the match's right column a fixed width at every text size.** Make `Metrics.SIDE_COLUMN` a hard width: set `custom_minimum_size` *and* clip or wrap its labels, with autowrap on the hint, the hurry label and the escape box. The column must never grow from its content. Extend the existing "board rect unchanged when the prompt appears" test to run with `large_text = true`, and add an opponent-turn case. [Opponent-turn polish, Escape-prompt polish] `scripts/ui/match/match_view.gd`, `tests/integration/test_ui_check_escape.gd`.
3. **Tie the unlock's fanfare to its reveal.** Either:
   - delay the unlock *reveal* itself to `max(unlock_at, Sfx.stinger_time_left())` and keep the left panel's place filled meanwhile (a dim "Unlocked for your next run" eyebrow, or a sealed emblem); or
   - shorten the run stinger tail and let the fanfare cut in at the reveal.

   Also derive the music return from the stinger: `create_tween()…set_delay(maxf(MUSIC_BACK_AFTER, Sfx.stinger_time_left()))`, or after the fanfare when there is one. Fix the "3.5 s = stinger length" line in UX_DECISIONS. [Run-end feel, Run-end sound, Run-end polish, Delight] `scripts/ui/screens/run_end_screen.gd:73–112`, `docs/UX_DECISIONS.md`.
4. **Put the coaching "−N pt" on a plate, or above the card.** Reuse `Feel.toast`'s plate, or float it from just above the card's top edge, as the shop does. It must never overlap the glyph circle. [Coaching feel, Delight] `scripts/ui/screens/coaching_screen.gd` (the accept handler around l.150–170), `scripts/ui/feel.gd`.
5. **Open settings at the top, and remove the base-size overflow.** On open, set `_scroll.scroll_vertical = 0` after focusing Master (`follow_focus` moves it), or focus the first control with `ensure_control_visible` on the section header. Trim the right column by 4–8 px at base size, for example by tightening the Controls grid row spacing, so no scroll track appears at 1280×720 with normal text. [Settings polish] `scripts/ui/widgets/settings_panel.gd:95–120`.
6. **Keep the shop row from reflowing after a purchase.** Give the Buy buttons a fixed `custom_minimum_size.x` equal to the widest state ("2 pt · can't afford"), or shorten that state to "Can't afford". Check at Large text. [Shop polish] `scripts/ui/screens/shop_screen.gd`.
7. **Roster list: whole rows at Large text.** Recompute the list window height from the row height *after* the theme rebuild (`Settings.large_text` changes the row height). Draw the 54 px opponent-deck cards without the cost figure, or raise it to 12 px. [Roster polish] `scripts/ui/screens/roster_screen.gd:90–100`, `scripts/ui/widgets/card_view.gd`.
8. **Run-end deck row: same glyph size with a ribbon.** On small cards, put the BOOK / HOLD ribbon under the coin, as the hand does, rather than shrinking the glyph. [Run-end polish] `scripts/ui/widgets/card_view.gd`.
9. **Small polish.**
   - Start the banner's clip 4 px left of the header label (turn_banner_02 sliver) [Opponent-turn polish] `scripts/ui/match/match_fx.gd` (`_show_turn_banner`).
   - Re-render `piece_land_medium_2` to match its siblings' presence (−11 dB) [Match sound] `tools/audio/generate.py`.
   - Consider a lower or darker `score_tick` variant for the opponent's score [Delight].

## 5. Code-review findings (godot-code-review checklist, `scripts/ui` changed since 6001818)

### Critical
- None. No crashes, soft-locks or per-frame costs found. There is no `_process` anywhere in `scripts/ui`, no `free()`, and no fragile `$A/B/C` paths. The only `get_parent()` uses are bounded and local: `A11y` walking up to trap focus, `item_overlay.gd:97–99` reparenting itself to fade out, and two layout reads.

### Improvements
- **`run_end_screen.gd:13,75`**: `MUSIC_BACK_AFTER := 3.5` is a hand-copied audio length that is already wrong (the files are 3.80 s). **Suggested fix:** ask `Sfx` for the stream length, or use `Sfx.stinger_time_left()`, so regenerating the audio can't silently desync it.
- **`run_end_screen.gd:109`**: `maxf(Settings.time(unlock_at), Sfx.stinger_time_left())` mixes scaled animation time with unscaled audio time. That mix is why the gap between the silent reveal and the fanfare grows at Fast and Instant. **Suggested fix:** schedule the visual reveal and the fanfare from the same value.
- **`match_fx.gd:97–99`**: the opponent's `escape_declined` plays `ui_cancel`. That is an interface sound whose meaning everywhere else is "*you* cancelled". **Suggested fix:** use a neutral board sound for the opponent side (for example `piece_land_light`, or nothing, since the toast carries it).
- **`match_fx.gd:452–454`**: `_hit_stop()` only delays the sequence (`wait`); tweens already running (flash, ring, shards) keep moving. That is a pause, not a hit-stop. It is fine at 0.05 s, but the name oversells it. **Suggested fix:** document it, or freeze the impact tweens (`Tween.pause`) for the hold.
- **`match_view.gd:314–324` `_fit_keys`**: deferred lambdas re-measure layout on every refresh, and a height-dependent hide/show can oscillate when `needed` sits near `room`. The hysteresis is only `Metrics.M`. **Suggested fix:** compute it once per resize and per theme change.
- **`settings.gd:58,63`**: the only untyped `var`s in the diff (`parsed`, `saved_bindings` from `JSON.parse_string`). **Suggested fix:** type them as `Variant` explicitly and check `is Dictionary` before `.get`.
- **`main.gd:58`**: `load(SCREENS[...])` per screen change. This is cached by ResourceLoader, so it is harmless, but `preload` constants would catch a bad path at parse time.
- **Input**: `match_screen.gd:79` and `settings_panel.gd:356` use `_input`. Both are justified and documented: Esc is consumed by tooltips, and key capture during a rebind. Everything else uses `_unhandled_input` / `_gui_input` with InputMap actions. Good.

### Positive
- `MatchFx` awaits only its own `wait()` tweens, and as a child node it dies with the screen, so a Leave run in mid-sequence just drops the coroutine. `Motion.hurry` is reset in `_exit_tree`.
- `Sfx`:
  - exclusive stingers with a queue for `wait` ids;
  - a fade-steal voice pool on spare players;
  - variants that never repeat back to back;
  - ducking through an Amplify effect, so the slider value is never touched;
  - hover and press metas that are now independent.
- Every tunable is in `config/ux.json`, and input actions are registered from config with physical keycodes (AZERTY-safe).
- `CardView` and `PieceToken` reuse their point arrays, and other style boxes come from `UiTheme.shared_box()`.
- Settings writes are debounced and flushed on release, close and quit.

## 6. Feedback-map gaps

**Event coverage (`docs/API.md` events against `match_fx.gd` and screens):**
- `turn_start`: `turn_player` / `turn_opponent`.
- `energy`: `energy_refill` (player); per-pip `energy_spend` in `match_view.gd:235`.
- `draw`: `card_draw` (`card_view.gd:94`).
- `shuffle`: player only.
- `card_played`: `card_play`.
- `discard`: `card_discard`.
- `redraw`: shuffle, spend, discard and draw.
- `move`: `piece_move` / `piece_land_*`.
- `capture`, `shield_block`, `explosion`, `score` (`score_tick`).
- `ignite` / `burn_tick`: `fire_ignite` / `fire_burn`.
- `burn_out`: `fire_burnout`.
- `promotion`, `check`, `escape`.
- `escape_declined`: `ui_cancel`.
- `match_over`: `victory` / `defeat`.

All of these have both a visual and a sound. `turn_end` and `error` have no row, which is fine: `turn_start` covers the handoff, and the UI never sends illegal actions.

**Screens and meta.** Every row in feedback_map has a sound, or is in the "Deliberately silent" list with a reason: opponent draw, refill and shuffle; ambient loops; unreachable map nodes and locked tiles; the match-over count-up; settings saving. The holes row is static, which is fine. **No undocumented silences found.**

**Mismatches between the map and the build:**
1. *Run end opens*: the map says "a new one glows with its fanfare once the run stinger has finished", but the unlock *panel* appears at ≈2.15 s, so the reveal itself is silent. It also says "music back after 3.5 s", which is before the 3.8 s stinger ends.
2. *Accept a coaching offer*: "'−N pt' floats up from the item" is accurate, but it floats over the item's art (§2 Coaching).
3. *Stay in check (opponent)*: `ui_cancel` is documented, but it is the player's cancel sound (§5).

**Known open UX bugs**
1. Large text: the first map screen clips (legend and floor-1 captions) at 720p (large_text/03).
2. Large text: the board shifts 3–9 px sideways for the opponent turn and the escape prompt (large_text/09, 35, 36).
3. Large text: settings opens scrolled, with the section headers hidden (large_text/37, 41).
4. Large text: the roster collection list shows a half row (large_text/04, 22, 26).
5. Large text: the shop row reflows after a purchase (large_text/14 vs 16).
6. The coaching "−N pt" float sits over the card glyph (coaching_accept_01–07).
7. Run end: silent unlock reveal, late fanfare, music back before the stinger ends, and an empty left third for about 2 s.
8. Settings: a scroll track at 1280×720 with normal text.
9. Turn banner: a sliver of the header label is visible at the wipe's left edge.
10. Roster opponent-deck coin figures are about 8–9 px.
11. Accepted lead call: the opponent-escape toast covers the player's back rank for 2.4 s.
12. Sound has not been verified by ear on laptop speakers. The numbers pass, and `piece_land_medium_2` is a presence outlier.
13. Accepted limitation: the title Quit button and the screenshot tool use `get_tree().quit()` and can print an exit leak warning.
