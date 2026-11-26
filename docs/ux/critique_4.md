# UX critique 4: independent review after iteration 4 and the opponent-hand feature

**What I looked at**
- **Images.** Every image was read:
  - the 45 base shots `docs/screenshots/01–45` (42–45 are Deep Vision and the opponent hand);
  - the 18 shots each in `1080p/` and `16x10/`;
  - the 45 shots in `large_text/`;
  - all 82 motion frames: `player_capture`, `explosion`, `card_play_energy`, `turn_banner`, `scout_reveal`, `settings_open`, `map_travel`, `coaching_accept`, `deck_open`, `run_end_victory`.
- **Docs.** `docs/SPEC.md`, `docs/specs/opponent-card-visibility.md`, `docs/UX_DECISIONS.md`, `docs/ux/feedback_map.md`, `docs/ux/sound_hooks.md`, `config/ux.json`, `README.md`, and the events table in `docs/API.md`.
- **Code.** `opponent_hand.gd`, `match_fx.gd` (reveal, card play, opponent card), `card_view.gd` (minis, flip, coin), `run_end_screen.gd`, `sfx.gd` (stingers), and greps across `scripts/ui/**` for the review checklist.
- **Order.** I scored first, then read `critique_3.md` and re-checked each of its findings myself.

**Runs**
- `--headless --import`: clean.
- GUT: **444/444 pass**, 16 846 asserts. The only noise is 5 GUT notes about the inner class `TestTmp`, plus the expected warnings and JSON errors from negative tests (`test_corrupt_file_falls_back_to_defaults`, unknown sound ids).
- `run_sim.gd --runs=100 --seed=1`: **PASS**. No crashes, action errors, illegal states, softlocks or log errors. Average AI decision time is 1.1–1.8 ms, worst case 13.4 ms.
- `python3 -I tools/audio/check.py`: "all checks passed", 12.92 MB in total.
- **No core change.** `git diff --stat 49feac6 -- scripts/core config` is empty. **Met.**

**Accepted limitations** (noted, not scored down):
- the title Quit button and the screenshot tool use `get_tree().quit()`;
- nothing has been checked by ear;
- the opponent-escape toast covers the player's back rank for 2.4 s (large_text/35);
- the canvas UI scale was replaced by Large text.

**Overall verdict.** Critique 3's Large-text regressions are fixed. With Large text on:
- the board rect is identical in large_text/05, 09, 23, 35 and 36;
- the map fits;
- the roster shows whole rows;
- settings opens at the top.

The run-end unlock now opens together with its fanfare, and the coaching float sits on a plate.

The new opponent-hand feature is well integrated:
- shown cards are minis and hidden ones are oxblood backs, so the two differ by shape and pattern, not colour alone;
- a count caption and a line of names back them up in text;
- the Scout's reveal is a real card turn.

What keeps lines below 4.5 is new and small:
- the Scout reveal's caption and names line announce the result before the cards turn over;
- the Deep Vision penalty point is never attributed when it happens;
- the artifact screen with five artifacts leaves an orphan tile and a void;
- the run end sits on a sealed "?" for about 2.4 s after the figures finish.

## 1. Score table

| Screen | Clarity | Visual polish | Feel | Sound | Accessibility |
|---|---|---|---|---|---|
| Title | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Set select | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Artifact select | 4.5 | **4** | 4.5 | 4.5 | 4.5 |
| Map | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Roster | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Match (normal) | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Match (opponent turn, incl. hand row) | **4** | **4** | 4.5 | 4.5 | 4.5 |
| Match (escape prompt) | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Match over | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Reward | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Shop | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Coaching | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Deck & collection views | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |
| Run end | 4.5 | 4.5 | **4** | 4.5 | 4.5 |
| Settings | 4.5 | 4.5 | 4.5 | 4.5 | 4.5 |

| Whole game | Score |
|---|---|
| Cohesion | 4.5 |
| Delight | **4** |

There are 5 lines at 4 (in bold), against 11 in critique 3. None are below 4, and none are at 5. I hold back 5s for two reasons:
- placeholder-quality art in places: the card faces are glyph-on-circle;
- sound that nobody has heard yet.

## 2. Evidence per score

### Title (01, 30, 1080p/01, 16x10/01, large_text/01, 30)
- **Clarity 4.5.** New Game is the one filled, focused action. The progress panel shows pips plus "N / M unlocked" and names Deep Vision once it is unlocked (30).
- **Polish 4.5.** The lamp vignette and the ghost board are balanced at 16:10, and Large text doesn't crowd the panel. The progress panel is still a little heavy for a title page.
- **Feel / Sound / Accessibility 4.5.** The drop-in and ambient loops are unchanged and good. There is one landing knock, and focus starts on New Game.

### Set select (02, 25, 16x10/10, large_text/02, 25)
- **All 4.5.** The tiles have equal height, worth tables, and three rule lines each. The locked state is given in words. Key caps and "Enter or a number key picks a set" are shown, and focus is a dashed ring, distinct from chosen. Fine at Large text.

### Artifact select (31, 42, 1080p/13, 15, 16x10/13, 15, large_text/31, 42)
- **Clarity 4.5.** Emblems, the "CHOSEN" chip and "1 / 2 chosen" next to Continue. Deep Vision states its cost plainly: "The opponent gets +1 point whenever one of your pieces is captured."
- **Polish 4.** Five artifacts expose two layout problems:
  - **The fifth tile sits alone in the left column** with an empty cell to its right (42, 1080p/15, 16x10/15). The grid reads as unfinished.
  - **There is a dead band between the subtitle and the list**: about 150 px at 1080p (y 165–320) and about 100 px at 16:10. The list is centred as a block, but the header stays pinned to the top, so the void sits between them.
  - The descriptions wrap well short of the tile's right edge (at 1080p, Powder Keg wraps at x≈1610 on a 1835 px tile).
- **Feel / Sound 4.5.** Toggle pop with `ui_toggle`. A third pick shakes and plays `ui_error`.
- **Accessibility 4.5.** Focus is a dashed ring outside the tile, and chosen is a tint, a border and the chip. The Deep Vision emblem is a distinct drawn glass ball.

### Map (03, 13, 21, 38, 1080p/03, 16x10/03, large_text/03, 13, 21, 38; map_travel_01–08)
- **Clarity 4.5.** Halo, key caps and a dashed path. "Then: …" lines. The legend covers node types and states.
- **Polish 4.5.** **Fixed since critique 3**: at Large text the first screen fits (large_text/03) and the legend is whole. The cost is that the "Next stops" list scrolls, so the third stop is hidden below a scroll bar until you scroll. The map itself still shows all three.
- **Feel 4.5.** The other choices drop their glow at once, the marker hops, and the screen changes after 0.6 s. Nit: the side panel keeps listing all three stops during travel (map_travel_02–07).
- **Sound / Accessibility 4.5.** Arrows, 1–3, and rich tooltips, and it now fits at Large text.

### Roster (04, 22, 26, 1080p/04, 14, 16x10/04, 14, large_text/04, 22, 26)
- **Clarity 4.5.** The ★ legend, budget pips, "8 pieces ready · 1 budget left", the cursor line, and "To win: …".
- **Polish 4.5.** **Fixed**: whole rows at Large text (large_text/04 ends on a full Bishop row). The opponent-deck minis drop the unreadable coin (`show_cost = false`).
- **Feel / Sound / Accessibility 4.5.** Weight-matched land sounds. The dashed cursor carries a ghost of the piece.

### Match, normal (05–08, 32–34, 40, 43, 44, 1080p/05, 16, 17, 16x10/05, 16, 17, large_text/05–08, 32–34, 40, 43, 44; player_capture, explosion, card_play_energy)
- **Clarity 4.5.** Legal marks are shapes first. The legend adds "Hole: no piece". The hint covers each step ("Choose a target", "Nothing to play"), and "Redraw · won't help" is written out. The Scout card has its own eye glyph (44).
- **Polish 4.5.**
  - Effects stay on the squares, and floats land on free squares ("+3 +1 +1" with "Boom!" in explosion_02–08).
  - The hand closes up at once.
  - **Nit**: the played card's ghost settles on the piece's *origin* square after the piece has left it. In card_play_energy_03–05 the ghost lands on a1 while the rook is already on a2. In player_capture_02–03 it lands on b3 while the knight is on c5. In card_play_energy_02 it crosses the e1 bishop and the board frame on its way.
- **Feel 4.5.**
  - A capture takes about 0.6 s and has an impact flash, a knock-away and a score-track flare.
  - An explosion is one beat.
  - Input responds in the same frame (selection lift in 06 and 40).
- **Sound 4.5.**
  - Each event has its own cue, and every one is present (`check.py`).
  - The opponent's captures use the darker `capture_against`.
  - Variants, cooldowns and the voice limit guard against fatigue.
  - None of it has been heard yet; that is an accepted limitation.
- **Accessibility 4.5.** Remappable `rc_*` keys with live caps, colour-blind cues on rings, burn arcs and Cheaper coins, and a 12 px floor on hand cards.

### Match, opponent turn, including the hand row (09, 10, 35, 43–45, large_text/09, 10, 35, 43–45, 1080p/16–18, 16x10/16–18; turn_banner_01–11, scout_reveal_01–10)
- **Clarity 4.** What works:
  - The opponent's card is shown face up beside the rank numbers, with an oxblood wash on the source and a ring on the target (turn_banner_08).
  - The hand row works at a glance: "3 shown · 2 hidden", faces, then backs (44), and the names line spells the shown cards out.
  - A card the opponent plays leaves the row ("3 shown · 1 hidden" after it plays Move in turn_banner_08).

  Two problems:
  - **The Scout reveal announces its result before it happens.** From scout_reveal_01 (and in shot 45, 1080p/18, 16x10/18), the caption already reads "all shown" and the names line already ends "Move · Pawn" while two oxblood backs are still drawn. They only finish turning at about 0.4 s (scout_reveal_08). The text contradicts the cards on screen and gives away the moment. Root cause: `_animate_reveal` calls `view.sync_opponent_hand()`, and `OpponentHand._refresh()` sets `caption` and `names_line` at once, before the flips.
  - **Deep Vision's penalty is never attributed when it applies.** The +1 is folded into the capture's `points` (D68). When the opponent takes your pawn, the "+2" float and the log line "Pawn captured on … (+2)" give no reason for the extra point. The only explanation is the "Hand" tooltip. A player who forgot the trade-off will read it as a scoring bug.
- **Polish 4.** Two problems:
  - **Problems in the opponent-hand row.**
    - The mini's cost coin is 15.5 px across (`COIN_RADIUS × MINI_COIN`), with a 12 px figure crammed into it. It sits across the card's top-left corner and border (44, large_text/44).
    - At Large text the names line wraps with a dangling separator: "Bishop · Knight · Rook · Move ·" / "Pawn" (large_text/45).
    - Mid-flip, the narrowing back is drawn with a gap where its slot is (scout_reveal_03–06). That reads as a flip, but the row's spacing jumps when the reveal starts (scout_reveal_01 → 02).
  - **Turn-banner wipe.** At the start of the wipe, the header's already-updated label "…kie Rex's turn / 1 of 40" shows to the right of the half-open banner (turn_banner_01). This is a different sliver from critique 3's, on the other side, and it lasts one frame.
- **Feel 4.5.** Each opponent action takes about 1.3 s, and Shift or a board click hurries it. The Scout's flips are staggered by 0.12 s. Busy state is clear: "Scouting · Revealing Rookie Rex's hidden cards…" and End turn is disabled.
- **Sound 4.5.**
  - `turn_opponent` is a quiet tap, and opponent captures use `capture_against`.
  - The reveal plays `reward_reveal` with one `card_draw` per flip. Reusing the *reward* chime for a scouting action is a semantic stretch, but it is tonal and fits.
  - The opponent's new hand deals in silently, and that silence is documented.
- **Accessibility 4.5.**
  - Shown and hidden differ by shape and pattern, so they don't rely on colour.
  - The names line gives keyboard players a text version.
  - Reduced motion swaps the flip for a fade and keeps the sounds.
  - The minis are out of the focus order, which is a documented choice: the names line covers it.

### Match, escape prompt (36, 1080p/06, 16x10/06, large_text/36)
- **All 4.5.**
  - The CHECK box gives the energy cost and "next turn: 2/3".
  - The button reads "Stay in check".
  - The key line reads "Click a square to escape · N stay".
  - The tag and ring stay inside the square.
  - **Fixed since critique 3**: the board doesn't move at Large text (the frame's left edge is at x 461 in large_text/05 and in 36).
  - `check_stay` replaces `ui_cancel`.

### Match over (11, large_text/11)
- **All 4.5.** It leads with "King captured: you took their king", with the king on its side and the reward line above Continue. The stinger plays once.

### Reward (12, 1080p/07, 16x10/07, large_text/12)
- **All 4.5.** 1.3× cards, key caps under them, "Rare · costs 2 energy", "Deck: 6 cards" next to Skip, and the deal-in with `reward_reveal`.

### Shop (14–16, 1080p/08, 16x10/08, large_text/14–16)
- **Clarity 4.5.** "Need 3 pt" says why an offer is unavailable, and there is one filled action.
- **Polish 4.5.** **Fixed**: the row no longer reflows after a purchase (the cards panel is at x 96–627 in both large_text/14 and 16). Nit: the "−2 pt" plate sits over the bought card's cost coin and the "Bought Pawn" plate over its glyph (large_text/16). Both are plated and short-lived, but the coin is the one thing that says what you paid.
- **Feel / Sound / Accessibility 4.5.** The toast appears where you clicked, the HUD flashes, and `ui_purchase` plays. 1–9 focus an offer.

### Coaching (17, 18, 1080p/11, 16x10/11, large_text/17, 18; coaching_accept_01–07)
- **Clarity 4.5.** The chips read "Accepted · upgraded" / "Declined", the status line reads "Bishop learned Book", and the BOOK ribbon appears on the card at once.
- **Polish 4.5.** **Fixed**: "−2 pt" is on a plate. Nit: the plate now sits squarely over the bishop glyph for about 0.9 s, so the card you just upgraded is hidden under its price (coaching_accept_01–06).
- **Feel / Sound / Accessibility 4.5.** The offer glows warm, the HUD flashes in oxblood, and `ui_confirm` plays.

### Deck & collection views (15, 19, 20, 39, 1080p/12, 16x10/12, large_text/15, 19, 20, 39; deck_open_01–07)
- **All 4.5.**
  - The "×N" tabs hang under the card and no longer cover it.
  - The detail line follows focus.
  - The panel is opaque from frame 1 and the items deal in within about 0.4 s.
  - There is a focus trap.
  - At Large text, 8 cards wrap to two rows with one orphan (large_text/19). That is acceptable.

### Run end (24, 29, 1080p/09, 16x10/09, large_text/24, 29; run_end_victory_01–08)
- **Clarity 4.5.** The headline, the back rank, the figures, and the unlock with its rule. Book and plain Bishop are separate kinds.
- **Polish 4.5.** **Fixed**: the panel keeps its place with a sealed "?" (no empty hole), and a ribboned card keeps the same glyph size as the others.
- **Feel 4.** **Fixed**: the reveal, fanfare and glow happen together. But by frame 04 (about 1.8 s) the figures are done, and the page then sits still with a sealed "?" until about 4.2 s (frames 04–07 are identical). That is about 2.4 s of nothing at the peak moment, and it is longer at Fast or Instant, because the stinger wait doesn't scale. The seal doesn't move to signal that something is coming.
- **Sound 4.5.** **Fixed**: the music returns at `Sfx.stinger_time_left()`, after the fanfare (`run_end_screen.gd:85`), and the fanfare no longer plays over returning music.
- **Accessibility 4.5.**

### Settings (37, 41, 1080p/02, 16x10/02, large_text/37, 41; settings_open_01–07)
- **All 4.5.**
  - **Fixed**: at normal size there is no scroll track (settings_open_01–07). At Large text the panel opens at the top, with SOUND and DISPLAY visible.
  - At Large text only the Controls column scrolls, and the "Click a key, then press the new one" hint is below the fold. That is acceptable.
  - Opaque from frame 1, Leave run… asks first, and keys can be remapped with swap-on-conflict.

### Cohesion 4.5
There is one palette, one type scale, one focus language, one timing table and one sound palette. The new feature uses the existing card language (mini faces, backs with oxblood field and brass lozenge), the existing glow and the existing paper sound. It isn't a 5: the hand row's mini coin and the five-tile artifact grid are the first places in a while where a new piece of content didn't get the same layout care.

### Delight 4
What lands well:
- the capture knock-away;
- the one-beat explosion;
- the map hop;
- the darker `capture_against`;
- the Scout flip, a genuinely nice small moment.

What holds Delight at 4:
- the Scout's payoff is pre-empted by its own caption;
- the run-end unlock, the biggest reward, sits behind about 2.4 s of a motionless "?";
- the card art is still glyph-in-a-circle everywhere, which reads as intentional placeholder rather than charming.

## 3. Critique 3's findings: status (checked myself)

| # | Critique-3 finding | Status | Evidence |
|---|---|---|---|
| 1 | Map overflows at Large text | **Fixed** (trade-off) | large_text/03 fits. The stop list scrolls, so stop 3 is hidden until you scroll |
| 2 | Right column widens, board shifts at Large text | **Fixed** | large_text/05, 09, 35, 36: board frame left edge at x 461 in all four |
| 3 | Unlock silent, fanfare late; music back before stinger ends | **Fixed** (new feel issue) | `run_end_screen.gd:120–127`: reveal, fanfare and glow at one time. Music at `stinger_time_left()`. About 2.4 s of a static "?" (§2) |
| 4 | Coaching "−N pt" smudge | **Fixed** (nit) | coaching_accept_01–06: plated. Now hides the glyph |
| 5 | Settings opens mid-scroll; base scroll track | **Fixed** | large_text/37, 41 headers visible. settings_open_01–07 have no track |
| 6 | Shop row reflows after purchase | **Fixed** | "Need N pt" in both states. large_text/14 vs 16 identical x |
| 7 | Roster half row; mini coin 8–9 px | **Fixed** | large_text/04 whole rows. Roster minis drop the coin. The *opponent hand* minis now carry a cramped coin (new, §2) |
| 8 | Run-end ribbon shrinks glyph | **Fixed** | run_end_victory_02–08: the BOOK Bishop's glyph matches its neighbours |
| 9a | Banner sliver | **Fixed** (new one-frame sliver on the right, turn_banner_01) | the label pop is removed |
| 9b | `piece_land_medium_2` presence | **Fixed** | UX_DECISIONS iteration 4. `check.py` passes |
| 9c | Opponent score / capture sounds the same | **Fixed** via `capture_against` | `match_fx.gd:651` |
| CR | `MUSIC_BACK_AFTER` hand-copied | **Fixed** | removed; `stinger_time_left()` |
| CR | Scaled vs unscaled time mix at run end | **Kept deliberately** | `maxf(figures_done, stinger_time_left())`, both real seconds. This is what produces the dead wait at Fast and Instant |
| CR | Opponent `escape_declined` plays `ui_cancel` | **Fixed** | `match_fx.gd:105` plays `check_stay` |
| CR | `_hit_stop` is a pause | **Documented** | UX_DECISIONS "Hit-stop stays a beat" |
| CR | `_fit_keys` oscillation | **Fixed** | `KEYS_SLACK` 24 px hysteresis |
| CR | Untyped `parsed` / `saved_bindings` in settings.gd | **Open** | `settings.gd:58,63` unchanged |
| CR | `load()` per screen in main.gd | **Open** (harmless) | `main.gd:58` |

## 4. Prioritised fixes (every line below 4.5)

1. **Make the Scout reveal's text follow the flips.** [Opponent turn: clarity, polish; Delight]
   - Keep the old caption and names until each card has turned. One way: have `OpponentHand.show_hand` return the fresh faces without calling `_refresh()` when the caller is animating. Then call `opponent_hand.refresh_text()` from `_flip_up`'s final callback, or once after `await wait(...)` in `_animate_reveal`.
   - Move `Feel.pop(caption)` to that point, so the pop lands with the last flip.
   - Add a test: right after `reveal`, the caption still counts the backs.
   - Files: `scripts/ui/widgets/opponent_hand.gd` (`_refresh`), `scripts/ui/match/match_fx.gd:338–363`, `tests/integration/test_ui_opponent_hand.gd`.
2. **Attribute Deep Vision's point when it applies.** [Opponent turn: clarity]
   - When a player piece is captured and the player owns `foresight`, split the float into "+1" and a small "+1 Deep Vision" (or "+2 (Deep Vision +1)").
   - Add "(incl. +1 Deep Vision)" to the log line, and flash the "Deep Vision" chip in the YOU panel once.
   - The engine's `capture.points` already includes the penalty. The UI knows the owner (`game.artifacts(PLAYER).has("foresight")`) and the piece value, so this needs no core change. Do the same for Trophy Case on your captures, for consistency.
   - Files: `scripts/ui/match/match_fx.gd` (capture float), `scripts/ui/match/event_text.gd` (capture line), `scripts/ui/match/match_view.gd` (chip flash).
3. **Give the run-end wait some life, or shorten it.** [Run end: feel; Delight]
   - Make the sealed "?" breathe: a slow brass pulse or a small shimmer once the figures are done, stopped by reduced motion.
   - Or trim the run stinger's tail so the fanfare can start at `max(figures_done, ~2.5 s)`, letting `stingers.fade` cut the tail.
   - Either way the reveal should land no later than about 1 s after the last figure.
   - Files: `scripts/ui/screens/run_end_screen.gd:115–127`, the seal widget in the same file, `config/ux.json` (`audio.stingers`), `tools/audio/generate.py` (`run_victory` / `run_defeat` tail).
4. **Five-artifact layout.** [Artifact select: polish]
   - Past `ARTIFACT_LIST_MAX`, centre the last row's odd tile (or span it across both columns).
   - Pull the list block up under the subtitle (top-aligned with `Metrics.XXL`) instead of centring it in the remaining height.
   - Let descriptions use the tile's full text width.
   - Files: `scripts/ui/screens/artifact_select_screen.gd`, `scripts/ui/ui.gd` (`centre_block`), `scripts/ui/theme/metrics.gd`.
5. **Opponent-hand row details.** [Opponent turn: polish]
   - Give the mini coin a proper inset, so it sits fully inside the card: radius at least 8.5 px with an 11–12 px figure, centred at (10, 10). Or drop the coin on minis and show the cost as a small figure under the glyph.
   - Build the names line from tokens joined with a non-breaking separator (" · "), so a wrap never leaves a trailing "·".
   - Keep the row's separation fixed through a reveal.
   - Files: `scripts/ui/widgets/card_view.gd` (`MINI_COIN`, `_draw_cost` for minis), `scripts/ui/widgets/opponent_hand.gd` (`_refresh`).
6. **Banner first frame.** Hide the header's turn label until the banner's wipe has covered it, or start the clip at full width with the panel sliding in. [Opponent turn: polish] `scripts/ui/match/match_fx.gd` (`_show_turn_banner`).
7. **Small items, not blocking a score.**
   - Make the played card's ghost land on the piece's destination square (or follow the moving token), not its origin (card_play_energy_03–05). `match_fx.gd`, card fly.
   - Move the coaching "−N pt" plate above the card's top edge, or off to its right, so the upgraded card stays visible. `coaching_screen.gd`.
   - Keep the shop's "−N pt" plate clear of the card's cost coin. `shop_screen.gd`.
   - Call `Sfx.stop_stinger()` when the run end is left early (Start new run or Title during the stinger), so the run stinger doesn't trail over set select. `run_end_screen.gd`.
   - Screenshot tool: in the `player_capture`, `explosion`, `card_play_energy` and `turn_banner` frames, the HUD shows a "Deep Vision" chip, but the YOU panel says "No artifacts" and the opponent row shows "4 shown · 1 hidden". The crafted match doesn't carry the run's artifacts. This isn't a game bug, but it is misleading evidence. `tools/screenshots/shot_stage.gd`.

## 5. Code-review findings (godot-code-review checklist, `scripts/ui/**` changed since 6001818)

### Critical
- None. There is still no `_process` in `scripts/ui`, no `free()`, and no fragile `$A/B/C` paths. The `get_parent()` uses are bounded and local:
  - `A11y`'s focus trap;
  - `item_overlay.gd:101–103` reparenting to fade out;
  - three layout reads.

  The remaining `_input` uses (`match_screen.gd:80`, `settings_panel.gd:363`, `main.gd:90`) are justified in UX_DECISIONS: Esc vs tooltips, rebind capture, and global F1.

### Improvements
- **`opponent_hand.gd` `_refresh()` updates the display text in the same call as the layout.** That coupling is the root of the premature "all shown" (fix 1). **Suggested fix:** split it into `_relayout()` and `refresh_text()`, and let `MatchFx` call the text update when the reveal finishes.
- **`opponent_hand.gd` `faces()` uses `for view: CardView in get_children()`.** A typed loop variable errors at runtime the moment any non-CardView child is added (a spacer, a highlight). `_refresh` also calls `faces()` three times per refresh. **Suggested fix:** collect with `if child is CardView`, and compute faces once in `_refresh`.
- **`run_end_screen.gd:85,121`: tweens on the screen own the music return and the fanfare,** so leaving early drops them, which is correct. But nothing stops the run stinger itself (`Sfx.stop_stinger()` has no caller in `scripts/ui`). **Suggested fix:** call it from the screen's `_exit_tree`.
- **`card_view.gd:18` `MINI_COIN := 0.62` puts a `MIN_FONT` 12 px figure in a 15.5 px coin.** The comment says it is "big enough", but the pixels in 44 disagree. **Suggested fix:** derive the coin radius from the font (`MIN_FONT * 0.7`), not from a share of the full card.
- **`settings.gd:58,63`** still use untyped `var parsed =` / `var saved_bindings =`. **Suggested fix:** `var parsed: Variant = …`, and check `parsed is Dictionary` before `.get` (carried over from critique 3).
- **`main.gd:58`** still calls `load(SCREENS[...])` per screen change. It is harmless because of the ResourceLoader cache, but `preload` constants would catch a bad path at parse time (carried over).

### Positive
- `OpponentHand` is fed only `visible_opponent_hand()` and `hidden_card_count()`, so a hidden face is never built (R6). The hidden-card tooltip says so.
- `CardView.flip` is drawn in `_draw`, which layout never touches. This avoids the container-resets-scale trap that had broken the first version, and the reason is documented.
- `_flip_up` binds its tween to the face, so a row rebuilt mid-flip just drops the tween, and `sweep_out` sets `_is_swept` so a same-cards reshuffle still re-deals (tested).
- `_animate_reveal` and `_reveal_opponent_card` await only MatchFx's own `wait()` and re-check `is_instance_valid` after the await.
- All new tunables are in `config/ux.json` or `Metrics`. The core is untouched.

## 6. Feedback-map gaps

I checked each event in `docs/API.md` against `match_fx.gd`, the screens, and the `Sfx.play` calls (grep). Every id named in `feedback_map.md` exists in `config/ux.json`, and `check.py` renders it.

| Event | Visual | Sound | Note |
|---|---|---|---|
| `turn_start` | banner | `turn_player` / `turn_opponent` | OK |
| `energy` | pips | `energy_refill` (player) | the opponent's is a documented silence |
| `draw` | deal-in | `card_draw` | the opponent's is a documented silence (its row deals in) |
| `shuffle` | pile pop | `card_shuffle` (player) | the opponent's is documented |
| `card_played` | ghost and pips; opponent card reveal | `card_play`, `energy_spend` | OK |
| `reveal` (Scout) | flip and glow | `reward_reveal` + `card_draw` ×N | **gap: the caption and names line update before the visual (§2)**. Reusing the reward chime is acceptable |
| Scout refused | shake and hint | `ui_error` | OK |
| `move` / land | crouch, hop, land | `piece_move`, `piece_land_*` | OK |
| `capture` | impact, knock-away, "+N" | `capture` / `capture_against` | **gap: the Deep Vision (and Trophy Case) bonus inside `points` has no visual or text attribution** |
| `score` | track fill and flare | `score_tick` | OK |
| `shield_block` | steel ring, "Blocked!" | `shield_block` | OK |
| `explosion` | wash, ring, shake, "Boom!" | `explosion` | OK |
| `ignite` / `burn_tick` / `burn_out` | arc, badge, smoke | `fire_ignite` / `fire_burn` / `fire_burnout` | OK |
| `promotion` | ring and swap | `promotion` | OK |
| `check` / `escape` / `escape_declined` | rings, tag, toast | `check` / `escape` / `check_stay` | OK |
| `discard` / `redraw` | sweep / deal | `card_discard` / `card_shuffle` | OK |
| `match_over` | panel | `victory` / `defeat` | the count-up is a documented silence |
| Opponent hand dealt | fade-in | — | documented silence |
| Run end unlock | seal opens | `unlock_fanfare` | OK. The wait before it is a feel issue, not a gap |

The documented silences are reasonable: opponent draw, refill and shuffle; ambient loops; non-reachable map hovers; the match-over count-up; settings saves.

### Known open UX bugs
1. The Scout reveal's caption and names show the result before the cards flip (45, scout_reveal_01–07).
2. The Deep Vision penalty point is unexplained at the moment it scores.
3. The played card's ghost settles on the vacated origin square (card_play_energy_03–05, player_capture_02–03).
4. At Large text the names line wraps with a trailing "·" (large_text/45).
5. One frame of the header label shows beside the opening turn banner (turn_banner_01).
6. At Large text the map's third next stop is hidden under a scroll bar (large_text/03).
7. The run stinger keeps playing over the next screen if the run end is left early.
8. Screenshot-tool inconsistency: HUD "Deep Vision" vs "No artifacts" in the motion frames.
