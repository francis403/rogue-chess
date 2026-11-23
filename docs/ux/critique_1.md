# UX critique 1: independent review of the polish pass

**What I looked at:** I read all screenshots: 01–41, the nine 1080p shots, the nine 16x10 shots, and all 31 motion frames. I compared one before/after pair (old `05_match_start`). I read the `scripts/ui/**` code that matters (Sfx, Feel, Motion, MatchFx, the match screen, main, Settings, A11y, the settings panel, CardView, PieceToken, PipMeter, MapView, and the menu screens), plus `config/ux.json`, `feedback_map.md` and `UX_DECISIONS.md`. I ran `python3 -I tools/audio/check.py`, which reported "all checks passed". I also ran headless import and the full GUT suite: **343/343 passing**. The only error lines came from tests that check bad JSON on purpose.

**Scale:** 5 means excellent, at shipped-indie quality. 4 means good with clear small flaws. 3 means acceptable but noticeably rough. The bar for this pass was every line at 4.5 or higher and nothing below 4.

**Overall verdict:** This is a big step up from the old screenshots. The game now has one visual language, one timing vocabulary, a complete sound layer and real keyboard and reduced-motion support. It does **not** meet the bar yet. Most lines are 4: good, with small flaws you can see. Six lines sit at 3.5. These are mostly layout voids on the menu screens, the opponent-turn banner, the match-over 0–0 case, misplaced feedback in the shop, the coaching "declined" fade, and a run-end screen that undersells a win.

## 1. Score table

| Screen | Clarity | Visual polish | Feel | Sound | Accessibility |
|---|---|---|---|---|---|
| Title | 4.5 | 4.5 | 4 | 4 | 4.5 |
| Set select | 4.5 | **3.5** | 4 | 4 | 4 |
| Artifact select | 4 | **3.5** | 4 | 4 | 4 |
| Map | 4 | 4.5 | 4.5 | 4 | 4 |
| Roster | 4 | 4 | 4 | 4.5 | 4 |
| Match (normal) | 4 | 4 | 4 | 4 | 4 |
| Match (opponent turn) | 4.5 | **3.5** | 4 | 4 | 4 |
| Match (escape prompt) | 4 | 4.5 | 4 | 4 | 4.5 |
| Match over | **3.5** | 4 | 4 | 4.5 | 4.5 |
| Reward | 4 | **3.5** | 4 | 4.5 | 4 |
| Shop | 4 | **3.5** | **3.5** | 4.5 | 4.5 |
| Coaching | 4.5 | 4 | 4 | 4 | **3.5** |
| Deck & collection views | 4.5 | 4 | 4 | 4 | 4.5 |
| Run end | 4.5 | **3.5** | **3.5** | 4.5 | 4.5 |
| Settings | 4.5 | 4 | 4 | 4 | 4 |

| Whole game | Score |
|---|---|
| Cohesion (one product?) | 4.5 |
| Delight (would a playtester smile?) | **3.5** |

**Lines below 4:** Set select polish, Artifact select polish, Opponent turn polish, Match over clarity, Reward polish, Shop polish, Shop feel, Coaching accessibility, Run end polish, Run end feel, Delight. That is 11 lines at 3.5. Every other line is 4 or 4.5, and none is 5.

## 2. Evidence per score

### Title (01, 30, 37, 1080p/01, 16x10/01)
- **Clarity 4.5.** New Game is the only filled button and it has focus. The progress panel says "1 / 2 unlocked" in words and pip meters. The four "?" artifact chips are mysterious but harmless.
- **Polish 4.5.** This is the strongest screen. The 76 px Georgia lockup with a shadow, the brass-flanked eyebrow, the board backdrop under a vignette and the piece row with the ebony queen all hold together. At 16:10 the extra height is shared evenly top and bottom. The progress panel is slightly heavy for its content.
- **Feel 4.** The piece-row drop-in and the screen fade/settle (`main.gd` `_play_entrance`) are fine but modest. Buttons have only the hover state.
- **Sound 4.** Buttons get hover and click sounds automatically, New Game uses `ui_confirm`, and the menu loop starts. Nothing marks the title opening (map row "Title opens": sound "—"). The menu loop is only 32 s (`check.py`: `music_menu 32.00`), so it repeats very often.
- **Accessibility 4.5.** Focus starts on New Game with a 2 px brass ring. Contrast is fine. F1 opens settings.

### Set select (02, 25)
- **Clarity 4.5.** "Locked · Beat the boss to unlock" is in `OXBLOOD_INK`, and the effect of each set is spelled out with worth tables.
- **Polish 3.5.** There is a dead band of about 90 px between the subtitle and the tiles (y 110–195) and about 110 px below them (540–650). The Standard tile's text block is half empty (y 390–475). "Back to title" sits alone in the bottom-right corner, far from everything else. The two tiles are not the same height: the focused one is about 4 px taller because of the ring.
- **Feel 4.** Pop, then a 0.22 s beat, then the next screen. Refusals shake.
- **Sound 4.** `ui_confirm`, and `ui_error` via `Feel.refuse`.
- **Accessibility 4.** Number keys pick a set and Enter works. The focus ring and the "selected" brass border look almost the same (02 and 25: Standard has focus but reads as chosen).

### Artifact select (31)
- **Clarity 4.** The "CHOSEN" chip is good. But Espresso, which has focus and is *not* chosen, has the same brass border as the chosen tiles. At a glance it looks like three are chosen while the counter says "2 / 2".
- **Polish 3.5.** The tiles are text only: no icon, no glyph. They are the only content tiles in the game without art. There is a large void above them (y 110–235) and below (500–650).
- **Feel 4** (toggle pop). **Sound 4** (`ui_toggle`, `ui_confirm`, `ui_error` at the limit).
- **Accessibility 4.** Keys 1–9 toggle and there are tooltips. The ambiguous focus ring is the same problem as on set select.

### Map (03, 13, 21, 38, 1080p/03, 16x10/03)
- **Clarity 4.** The node states read well: halo, number key caps, dashed path, "YOU" tab, the floor label in brass. At the start, though, the "Next stops" list shows **"FLOOR 1 · EASY / Rookie Rex" three times** with nothing to tell them apart, which is wasted space and confusing. The HUD says "Floor 0 of 7" before the first match.
- **Polish 4.5.** The map is clean and balanced, and the legend is in two columns. At 1280×720 the bottom captions ("EASY", y≈689) come within about 30 px of the edge, which is still fine.
- **Feel 4.5.** The halo breathes and the ivory marker walks the edge (0.42 s).
- **Sound 4.** `map_travel`, plus `ui_hover` on keyboard steps. Hovering a node with the mouse is silent.
- **Accessibility 4.** Arrows, Enter and 1–3 all work, the focus ring is outside the node, and tooltips come from `_get_tooltip`. In the legend, the "Ahead" and "Out of reach" swatches are about 10 px dotted circles that are almost the same, so you have to read the label to tell them apart.

### Roster (04, 22, 26, 1080p/04, 16x10/04)
- **Clarity 4.** The instructions are explicit and the budget pip meter reads 11 / 12. The king carries a small "★" badge (`piece_token.gd` `is_locked`) that nothing on the screen explains. The collection list is cut off mid-row at the bottom. A scroll bar is present, but the cut row makes the list feel cropped.
- **Polish 4.** The right column is half empty under "ARTIFACTS · None". "On the board" rows dim their **text** as well as the token (04: "Rook" in grey; 1080p/04 makes it obvious). This contradicts UX_DECISIONS "dim the token, not the text".
- **Feel 4.** The token pops when placed. **Sound 4.5.** The placement sound matches the piece's weight (`_land_sound`), Auto uses `card_shuffle`, and Bench all uses `ui_cancel`. That is a good touch.
- **Accessibility 4.** Enter on a row places or benches the piece and Esc drops the selection. There is no board cursor, so you cannot choose *which* square from the keyboard.

### Match: normal turn (05–08, 10, 27, 28, 32–34, 40, frames/*, 1080p/05, 16x10/05)
- **Clarity 4.** This is a real improvement over the old 05. The hint desk has an eyebrow title, the board legend matches the marks on the board, and there are key caps on the cards and buttons. Problems:
  1. **Hand key caps go stale for the whole play sequence.** After a card leaves, the remaining four still show "2 3 4 5" (08, 34, frames/player_capture_01–06, explosion_01–08), then renumber to 1–4 at the end (player_capture_07). The cause is that `_sync_hand()` runs only after `_run()` finishes (`match_screen.gd`).
  2. Hint 28 says a redraw won't help, yet the Redraw button is lit and enabled.
  3. The king's "★" badge again has no explanation.
- **Polish 4.**
  1. The hint desk has about 190 px of dead space between the hint and the pile counts (05, 1080p/05).
  2. Float texts land on pieces: "+3" sits on the opponent king's glyph (08, player_capture_06–08), and "+3" is drawn over the board frame at y≈141 (explosion_08).
  3. "Boom!" and the shockwave ring spill past the board's right edge (34, explosion_01–04).
  4. The hand keeps a gap where the played card was for the whole sequence (33, card_play_energy_02–06).
  5. Unplayable card names are faint, but they pass contrast.
- **Feel 4.** Durations are good (move 0.28 s, crouch 0.06 s, back-ease land) and so is the hit-stop discipline. The capture reads as cause and effect. The card flies from the hand to the piece (card_play_energy_02–04) and the pips drain one by one. Weak spots:
  1. **Explosion victims resolve one after another.** Each `capture` awaits `capture_beat` 0.16 s (`match_fx.gd` `_animate_capture`). In explosion_05–08, e5 dies, then e6 a beat later, so the blast reads as a ripple rather than one boom.
  2. The capture itself is soft: small shards, no board response.
  3. The hand re-centres late.
- **Sound 4.** Every match event calls `Sfx.play` (see section 5). Loudness is normalised, there is jitter and there are cooldowns. Risks:
  1. Impact centroids are very low: `explosion` 155 Hz, `check` 180 Hz, `capture` 380 Hz, `piece_land_heavy` 254 Hz (`check.py`). On laptop speakers, which roll off below about 200–300 Hz, the biggest moments will sound the thinnest.
  2. Each sound has a single file, varied only by ±5 % pitch. Hundreds of `piece_land_*` / `card_draw` plays per run will start to sound mechanical.
  3. The start of a turn stacks `turn_player` (1.1 s), `energy_refill` (0.7 s) and up to 5 × `card_draw` within about 0.5 s.
- **Accessibility 4.** Keyboard play is complete (1–5, E/Space, R, Esc, Y/N), reduced motion is thorough, and the CHECK tag means check is never shown by colour alone. However:
  1. The opponent's score figure is `OXBLOOD` #c0503f on the background at 20 px: **3.98:1**, which only passes as "large text" if the font is bold.
  2. The dashed burn arc is very faint on light squares (28, f4).
  3. Key remapping is not possible because shortcuts are hard-coded `KEY_*` constants.

### Match: opponent turn (09, frames/turn_banner_01–07)
- **Clarity 4.5.** The banner, the face-up revealed card ("Rookie Rex plays Move"), the oxblood source wash, the hollow target ring and the "thinking…" hint together make the opponent fully legible.
- **Polish 3.5.**
  1. The banner is an opaque bar across ranks 3–4 that covers pieces (the b3 knight in turn_banner_02–05).
  2. **It is still on screen when the first opponent card is revealed** (turn_banner_06: card and banner overlap; frame 07: the banner is still fading over the move marks).
  3. The revealed card sits over the rank labels "4" and "5" (turn_banner_07, x 352–455 against the labels at x≈449).
  4. The opponent's card backs are flat oxblood rectangles, crude next to everything else.
- **Feel 4.** Each AI action costs about `move_delay` 0.45 + reveal 0.18 + `reveal_hold` 0.35 + move 0.34 + land ≈ 1.3–1.5 s, so a three-card turn takes about 4 s at Normal. That is acceptable, but it is the slowest part of the loop. Fast speed helps.
- **Sound 4.** `turn_opponent`, `card_play`, move and land. The opponent's draw, energy refill and shuffle are silent by design.
- **Accessibility 4.** Same as the normal turn.

### Match: escape prompt (35, 36, 16x10/06, 1080p/06)
- **Clarity 4.** The framed oxblood prompt, the "Costs 1 energy · next turn: 2/3" line, the Stay button and the highlighted king squares are clear. However:
  1. The key line always says "Y escape (one square)", even when there are three squares (36). It should depend on the state.
  2. **Stale check marks after the opponent escapes.** In 35, the log already says "King c6 → d6", but the king at d6 still shows the CHECK tag and rings, and the rook on c2 still has "gives check" brackets, for the whole 2.4 s toast.
  3. The opponent-escape toast covers the player's back rank (35, a1/c1). This is a known lead call, but it still hides your own king.
- **Polish 4.5.** The prompt fits inside the desk and the board does not move (verified at 16:10 as well).
- **Feel 4. Sound 4.** `check` is a soft swell, which suits the tone, but at 180 Hz it is easy to miss on small speakers. **Accessibility 4.5** (words, tag, keys).

### Match over (11)
- **Clarity 3.5.** The panel reads **"Victory … The enemy king was captured … 0 – 0"**. When the win comes from a king capture, two big 0s contradict the headline: the scores make the result look like nothing happened. The hint behind the scrim also says "Match over." twice.
- **Polish 4.** The scrim and panel look good. The "–" separator sits about 10 px below the figures' optical centre.
- **Feel 4** (0.35 s beat, settle, count-up). **Sound 4.5** (victory/defeat stingers, no jitter). **Accessibility 4.5.**

### Reward (12, 1080p/07, 16x10/07)
- **Clarity 4.**
  1. Keys 1–3 take a card, but the reward cards **show no key caps**. The match draws them and the map draws them.
  2. The brass circles in the top-left are *cost coins* that happen to read 1, 2, 3 here, so a player will assume those are the keys, or that the numbers are positions.
  3. The focused card is only lifted. There is no ring.
- **Polish 3.5.** The three cards are small (about 150 px wide) in a large empty canvas. Lifting card 1 for focus breaks the row's alignment. "Skip · +1 point" is stranded in the bottom-right corner, about 400 px from the choice it belongs to.
- **Feel 4** (staggered deal-in, pop, 0.3 s beat). **Sound 4.5** (`reward_reveal`, `ui_confirm`). **Accessibility 4.**

### Shop (14–16, 1080p/08, 16x10/08)
- **Clarity 4.** The labels "Sold" and "2 pt · can't afford" are clear. But the purchase feedback appears **far from the click**: "Bought Bishop" in the bottom-left (16, y 625), while the button pressed is at (141, 451).
- **Polish 3.5.** The three section panels have different heights. The cards panel is about one third empty on the right. The bottom 40 % of the screen is empty, and "Leave the shop" is stranded in its corner.
- **Feel 3.5.** feedback_map says "−N pt floats up off it". In 16, **"−2 pt" floats at screen centre (≈616, 590)**, nowhere near the Sold button. The single most rewarding moment on this screen happens in the wrong place.
- **Sound 4.5** (`ui_purchase` is a clear cash-register-like chime; the button's own sound is suppressed so it doesn't double). **Accessibility 4.5** (affordability in words, 1–9 move focus, Enter buys).

### Coaching (17, 18)
- **Clarity 4.5.** Each offer says what it upgrades and what it costs, and there are Accepted / Declined chips.
- **Polish 4.** The mini cards are tiny. The BOOK ribbon squeezes the glyph on the accepted card (18). The bottom 35 % is empty.
- **Feel 4** (brass glow on accept). **Sound 4** (confirm / cancel / error).
- **Accessibility 3.5.** A declined offer is faded with `panel.modulate.a = 0.6` (`coaching_screen.gd:92`). This contradicts UX_DECISIONS ("sink instead of fading"). It drops the body text to **3.8:1** and the "Bishop card" caption to **2.8:1** on `WALNUT_RAISED`. The mini-card name text is also small (about 12 px serif on a 70 px card).

### Deck & collection views (15, 19, 20, 39)
- **Clarity 4.5.** The detail line under the grid ("Queen · cost 3 · Move one queen") works for both focus and hover, which is nice.
- **Polish 4.** About 40 % of the modal is empty when the deck is small. The deck is not sorted or grouped: three separate "Bishop" cards, not "Bishop ×3". On deck cards, focus is shown only by the lift, with no ring, while the collection rows do get a ring (20), so the two are inconsistent.
- **Feel 4. Sound 4** (`ui_open` / `ui_close`). **Accessibility 4.5** (focus trap, Esc, D/C keys).

### Run end (24, 29, 1080p/09, 16x10/09)
- **Clarity 4.5.** The headline ("The boss has fallen" / "Defeated on floor 1"), the unlock and the summary figures are all clear.
- **Polish 3.5.** The layout is flat and unbalanced. The unlock panel is about 50 % empty, the bottom third of the screen is void (y 510–630), and "New piece set unlocked: Fire" repeats the heading. The victory screen looks almost the same as the defeat screen, just in a different colour.
- **Feel 3.5.** A run victory is the biggest moment in a roguelike, and here it gets a staggered fade and a panel glow. There is no burst, no piece row, no count-up of the run, nothing for the eye to celebrate.
- **Sound 4.5.** The music stops, a stinger plays, then `unlock_fanfare`, and the lounge returns after 3.5 s. This is the best-designed audio beat in the game.
- **Accessibility 4.5.**

### Settings (37, 41, 1080p/02, 16x10/02)
- **Clarity 4.5.** It covers sound and motion only, in plain words, and saves automatically.
- **Polish 4.** The toggle switches are tiny (about 30 px) and their off state is a dark grey knob on a dark track. The screenshots never show the on state.
- **Feel 4. Sound 4.** The preview plays on `drag_ended` only, so **keyboard arrow changes are silent** (`settings_panel.gd`).
- **Accessibility 4.** It is keyboard reachable and focus is trapped. It has no UI or text scale, no fullscreen or window option, and no separate "screen shake" toggle: reduced motion is all or nothing. More importantly, **there is no way to abandon a run or return to the title mid-run.** No "quit" path exists outside the title and run-end screens (grep shows `quit` only in `title_screen.gd`).

### Cohesion 4.5
There is one palette (walnut, ivory, brass, oxblood), one type scale, one button system and one focus ring. Every duration is named in `config/ux.json`, and the sound palette is consistent (wood, paper, brass chimes, Rhodes). It reads as one product. It loses half a point for:
- the opponent's crude card backs;
- the text-only artifact tiles;
- the run-end screen, which feels like a different, flatter product than the match.

### Delight 3.5
It is tasteful and calm, but it rarely delights. The explosion (Boom!, shockwave, shake) and the escape prompt are the moments a playtester would notice. The capture is soft. The rewards and purchases put their feedback in the wrong place or show none. A run victory is a static page. The music loops are 32–40 s, so after 30 minutes the match loop will have played about 45 times.

## 3. Prioritised fixes

Each fix lists the score lines it would raise in brackets. The top ten are marked ★.

1. ★ **Anchor the shop purchase feedback at the button.** Start the float from `Feel.centre_in(button, self)`, not a fixed point. Show the "Bought …" status next to the offer (or as a toast over it) and pop the HUD points. [Shop feel, Shop clarity, Delight] `scripts/ui/screens/shop_screen.gd`, `scripts/ui/feel.gd`.
2. ★ **Fix the match-over panel for king-capture wins.** When `result.reason` is a king capture, lead with that (for example a large king glyph or "Checkmate-style win") and show the material score small, or hide it when it is 0–0. Also align the "–" separator to the figures' centre. [Match over clarity, Delight] `scripts/ui/match/match_over_panel.gd`.
3. ★ **Turn banner off the pieces and not over the reveal.** Either put the banner in the header gap above the board (y≈110–140, next to the turn label), or make `_opponent_turn()` wait for the banner before the first `move_delay`. Move the revealed opponent card clear of the rank labels (`rest.x - 24`). Replace the flat oxblood card backs with the real `CardView` back style. [Opponent-turn polish, Match polish] `scripts/ui/match/match_fx.gd` (`_show_turn_banner`, `_reveal_opponent_card`), `scripts/ui/screens/match_screen.gd` (`_opponent_turn`), `scripts/ui/match/match_view.gd` (opponent hand).
4. ★ **Resolve an explosion's victims together.** Knock away all `cause == "explosion"` captures in the same beat: collect them, then one `capture_beat`. Give the capture a bit more weight: a 1–2 px board nudge and slightly larger shards. [Match feel, Delight] `scripts/ui/match/match_fx.gd` (`apply`, `_animate_capture`).
5. ★ **Keep float texts readable and inside the board.** Clamp the y position too (Feel.float_text clamps only x). Offset score floats so they never sit on a piece glyph: use the side of the square away from neighbours, or stack successive floats. Clip the shockwave ring and "Boom!" to the board rect. [Match polish] `scripts/ui/feel.gd` (`float_text`), `scripts/ui/match/match_fx.gd` (`_float`, `_animate_explosion`).
6. ★ **Re-layout the hand as soon as a card is played.** When `_play_selected` starts, remove the played card from `hand_row` (or collapse it with a 0.12 s tween) and refresh the `key_hint`s. That way the gap closes immediately and the key caps never show "2–5" for four cards. [Match clarity, Match polish, Match feel] `scripts/ui/screens/match_screen.gd` (`_play_selected`, `_sync_hand`).
7. ★ **Rebuild the run-end screen as a payoff.** On victory: a brass burst, the back-rank piece row dropping in (reuse the title-screen code), the floors / wins / points counting up, and the unlock tile dealing in last together with the fanfare. Balance the layout: unlock and summary centred vertically (`Ui.centre_tall`), no void below. Drop the duplicated "New piece set unlocked" line. [Run end polish, Run end feel, Delight] `scripts/ui/screens/run_end_screen.gd`, `scripts/ui/widgets/title_backdrop.gd`.
8. ★ **Close the menu-screen voids.** Centre the content blocks vertically between the header and footer on set select, artifact select, reward and shop. Put Skip and Back next to the content they belong to. Make the reward cards larger (about 1.3×). Equalise the shop panel heights and size the cards panel to its content. [Set select, Artifact select, Reward and Shop polish] `scripts/ui/ui.gd`, `scripts/ui/screens/{set_select,artifact_select,reward,shop}_screen.gd`.
9. ★ **Make focus and selection distinguishable.** On tiles, focus is the 2 px ring *outside* the tile, and chosen should be a filled or tinted face plus the chip, not the same brass border. Show key caps 1–3 on reward cards, using `CardView.key_hint` the way the match does. Draw the focus ring on deck and reward cards, not only the lift. [Artifact and Set clarity/accessibility, Reward clarity, Deck polish] `scripts/ui/widgets/select_tile.gd`, `scripts/ui/widgets/card_view.gd`, `scripts/ui/screens/reward_screen.gd`, `scripts/ui/widgets/item_overlay.gd`.
10. ★ **Reduce sound fatigue.** Make the music loops longer or varied: an A/B section or 2–3 rendered variations, picked at random per loop, 2–3 minutes each. Render 3 variants each for `piece_land_*`, `card_draw` and `capture`, and pick one at random in `Sfx.play`. Play `turn_opponent` quieter or skip it after the first round, or play only the player's chime. Add a 1–3 kHz transient layer to `capture`, `explosion` and `check` so they survive laptop speakers, and check that by listening. [Sound on every screen, Delight] `tools/audio/generate.py`, `scripts/ui/audio/sfx.gd`, `config/ux.json`.
11. **Coaching "declined": sink, don't fade.** Replace `modulate.a = 0.6` with the sunk face and `IVORY_FAINT` text, matching the locked tiles. [Coaching accessibility] `scripts/ui/screens/coaching_screen.gd:92`.
12. **Clear stale check marks immediately and make the escape key line depend on the state.** On `escape` / `escape_declined`, clear `board.threats` and `is_in_check` before the toast. Show the line as "Y / Enter escape to d1" for one square and "click a highlighted square" for several. [Escape clarity] `scripts/ui/match/match_fx.gd` (`_on_escape`), `scripts/ui/screens/match_screen.gd` (`_show_escape_prompt`).
13. **Settings additions.** Play the preview on `value_changed` with a short debounce, so keyboard users hear it. Add a "Leave run" (back to title, with confirmation) entry when a run is active. Add a separate "Screen shake" toggle, plus window mode / UI scale. [Settings accessibility, Settings sound, whole-game clarity] `scripts/ui/widgets/settings_panel.gd`, `scripts/ui/settings.gd`, `config/ux.json`.
14. **Map "Next stops" list.** When the stops are identical, collapse them ("3 × Rookie Rex · Easy") or show what each path leads to (the floor-2 node type). The HUD should say "Floor 1 of 7 · start" instead of "Floor 0". [Map clarity] `scripts/ui/screens/map_screen.gd`, `scripts/ui/widgets/hud.gd`.
15. **Roster.** Explain the king's "★" badge (tooltip or legend: "Free, always plays"). Keep the text of "On the board" rows at full contrast and dim only the token. Give the empty right column something to do, for example the opponent's deck as mini cards. [Roster clarity, polish, accessibility] `scripts/ui/screens/roster_screen.gd`, `scripts/ui/widgets/roster_row.gd`, `scripts/ui/widgets/piece_token.gd`.
16. **Opponent score contrast.** Draw the number in `OXBLOOD_INK` (5.9:1) rather than `OXBLOOD` (3.98:1). [Match accessibility] `scripts/ui/widgets/score_race.gd:52`.
17. **Hint desk dead space.** Let the log or legend take the height, or move the pile counts directly under the hint. [Match polish] `scripts/ui/match/match_view.gd`.
18. **Redraw button state.** Disable Redraw, or show it as not useful, when `_stuck_hint()` says a redraw can't help. [Match clarity] `scripts/ui/screens/match_screen.gd`.

## 4. Code-review findings (godot-code-review checklist, changed UI code)

### Critical / bugs
- **`match_fx.gd` `_animate_move`, lines 320–332: await on a tween bound to the token.**
  - `await crouch.finished` waits on `Motion.tween(token)`. If the token is freed during the crouch, the tween is killed and `finished` never fires. `apply()` then never returns, and `_is_busy` stays true for the rest of the match, which is a soft-lock.
  - After the await, `token` is also used without an `is_instance_valid` check.
  - **Fix:** use `await wait(Motion.time("anticipation"))` (a tween owned by MatchFx), then check `is_instance_valid(token)` before continuing. Do the same for `await tween.finished` from `board.move_token`.
- **`match_fx.gd` `_reveal_opponent_card`, lines 171–174:** after `await wait(...)` it tweens `card`, which may already have been freed by `clear_ghosts()` or by leaving the screen. **Fix:** `if not is_instance_valid(card): return`.
- **Stale key caps and stale check marks.** These are logic-level UX bugs described above: `_sync_hand` runs only at the end of `_run()`, and `threats` / `is_in_check` survive an escape until the next `_sync`.

### Improvements
- **`map_view.gd` `_process`, line 82:** `queue_redraw()` runs every frame for as long as the map is visible, because `available` is never empty. That redraws the whole custom map at 60 fps. **Fix:** redraw from a `_pulse` setter and the marker tween, and `set_process(false)` otherwise.
- **`map_view.gd`, line 40:** the halo pulse uses a hard-coded 0.9 s that bypasses `Motion` / `config/ux.json`, so animation speed doesn't scale it. This contradicts the "no scattered literals" decision.
- **`settings_panel.gd` `_volume_row`:** `Settings.set_value`, and therefore `save()`, a file write, runs on every `value_changed` tick while a slider is dragged. **Fix:** save on `drag_ended` or debounce. The preview is tied to `drag_ended` only, so keyboard users never hear it.
- **`piece_token.gd` `_shield_badge`, around line 178:** allocates a `PackedVector2Array` on every `_draw`. Tokens redraw every frame during lift, move and flash tweens, so this is a small per-frame allocation. **Fix:** reuse a member array, as `FxBurst._points` does.
- **`sfx.gd` `_voice`:** steals the oldest voice with a hard `stop()`, which can click when a voice is cut mid-sample. **Fix:** prefer stealing the quietest or lowest-priority voice, or ramp it down over about 10 ms.
- **`sfx.gd` button hooks:** only `mouse_entered` gives hover sounds. Keyboard focus moves between menu buttons are silent, which is inconsistent with the map's keyboard `ui_hover`.
- **Literals against UX_DECISIONS "no scattered literals":** font sizes 26 / 20 / 28 / 16 / 18 and `padding := 10` in `match_fx.gd`; sizes 13 / 20 / 16 in `score_race.gd`; `custom_minimum_size` 520 / 280 / 84 / 80 / 48 in `settings_panel.gd`.
- **Input:** match and global shortcuts use hard-coded `KEY_E`, `KEY_R`, `KEY_Y`, `KEY_N`, `KEY_D`, `KEY_C`, `KEY_F1` and 1–9 instead of InputMap actions, so they cannot be remapped (and AZERTY users get number keys only via `physical_keycode` in `A11y.number_key`, not in `match_screen._press_shortcut`, which reads `keycode`). **Fix:** InputMap actions. At minimum, also check `physical_keycode` for 1–5 in the match.
- **`match_fx.gd` `_floats: Array`** is untyped; the comment explains why, and that is acceptable.
- **`main.gd show_screen`:** `load()` runs on every screen change. ResourceLoader caches it, so this is fine; `preload` in `SCREENS` would be cleaner.

### Positive
- `MatchFx` is a child node, so its tweens and awaits die with the screen.
- Ghosts are tracked and freed.
- `Feel.shake` restores its rest position across overlapping shakes.
- `PipMeter.value` kills the running step tween.
- `UiTheme.shared_box` and reused StyleBoxes keep `_draw` free of allocations in CardView and BoardView.
- `A11y.trap_focus` holds the previous focus owner through a WeakRef.
- Reward and set-select deferred transitions are guarded (`_is_done`, `_has_chosen`).
- Headless runs skip playback.
- Every Sfx id is data-driven.
- The `_input` Esc workaround is justified in a comment.

## 5. Feedback-map gaps (exit criterion 3) and core diff (exit criterion 5)

Every match event in `docs/API.md` (`turn_start`, `energy`, `shuffle`, `draw`, `card_played`, `move`, `shield_block`, `capture`, `explosion`, `score`, `ignite`, `burn_tick`, `burn_out`, `promotion`, `check`, `escape`, `escape_declined`, `redraw`, `discard`, `match_over`) has both a visual and a `Sfx.play` call. I verified this by grepping `match_fx.gd`, `match_view.gd`, `match_over_panel.gd` and `card_view.gd`. `turn_end` has no row of its own; `turn_start` covers it.

Rows or cases with **no sound** (criterion 3 asks for both):
1. **Title opens:** visual (piece drop) but sound "—".
2. **HUD points change:** pop but sound "—". It is mostly masked by `ui_purchase` / `ui_confirm`, but the reward screen's skip pop has no sound of its own.
3. **Next stops halo:** ambient, sound "—". Acceptable.
4. **Map node mouse hover:** visual highlight and side panel, but sound only on keyboard steps.
5. **Opponent energy refill, draw and shuffle:** visual only. This is deliberate ("player only"), but it is not stated as a gap.
6. **Volume slider via keyboard:** the label updates, but there is no preview sound (`drag_ended` only).
7. **Keyboard focus moving between menu buttons:** ring only, no sound.
8. **Match-over score count-up:** no tick. This is covered by the stinger, so it is acceptable.

Criterion 3 is therefore **not strictly met**. The real gaps are 1, 2, 4 and 6. The rest are defensible design choices that should be written into feedback_map.md as "intentionally silent".

**Criterion 5:** `git diff --stat scripts/core config` is **empty**. `git status --short scripts/core config` shows only `?? config/ux.json`. **Met.**
