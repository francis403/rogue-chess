# Sound hooks

Where each sound should be triggered. API: `Sfx.play(id)`, `Sfx.play_music(id)`, `Sfx.stop_music()` (autoload, `scripts/ui/audio/sfx.gd`). Mix (dB, pitch range, cooldown) is in `config/ux.json` → `audio`; files come from `tools/audio/generate.py`.

**Already automatic:** every `BaseButton` plays `ui_hover` on mouse-enter (not when disabled) and `ui_click` on press (`ui_toggle` for toggle buttons / check boxes). Override per button, no edit to `sfx.gd` needed:

```gdscript
button.set_meta("sfx", "none")         # no press sound: the screen plays its own result sound (hover still ticks)
button.set_meta("sfx", "ui_confirm")   # different press sound
button.set_meta("sfx_hover", "none")   # no hover tick
```

**Also automatic (iteration 2), nothing to call:**
- **Variants**: `Sfx.play(id)` picks one of the id's files at random and never the same one twice in a row. Ids with 3 variants: `ui_hover`, `ui_click`, `card_draw`, `card_hover`, `piece_pickup`, `piece_move`, `piece_land_light/medium/heavy`, `capture` (`config/ux.json` → `audio.sounds[id].variants`). Call sites don't change; `played` still emits the plain id. `Sfx.variant_count(id)` / `Sfx.last_variant(id)` are for tests and tools.
- **Ducking**: `victory`, `defeat`, `run_victory`, `run_defeat` and `unlock_fanfare` dip the music 5 dB (0.12 s in, held for the stinger's length, 0.9 s back; `audio.duck`). It is an Amplify effect on the Music bus, so the bus volume always equals the player's slider. `Sfx.duck_music(seconds)` does it by hand if a screen ever needs it.
- **One stinger at a time** (iteration 3, `audio.stingers`): the same five ids are exclusive. A new stinger fades out the one still sounding over 0.3 s, and the music dip follows the new one (it is re-timed to the new stinger's end, even when that is shorter). So `run_defeat` / `run_victory` on the run-end screen replaces a `defeat` / `victory` still ringing from the match-over panel; call sites don't change. `unlock_fanfare` (`stingers.wait`) never cuts in: if a stinger is playing, `play()` queues it (and returns true) and it starts when that stinger ends. `Sfx.stinger_time_left()` gives the seconds until the playing and queued stingers have ended (0 when none), so the run-end screen can line its unlock reveal up with the fanfare. `Sfx.stop_stinger()` fades the stinger out and drops a queued one.
- **Voice stealing**: when 8 SFX (4 UI) voices are already sounding, the oldest fades out over 15 ms on a spare player instead of being cut, so bursts (explosion + captures) don't click.
- **Turn chimes**: `turn_opponent` is now a short (0.4 s), dark, quiet tap at -14 dB, so playing it every round is fine; `turn_player` stays a clear, gentle fifth (-7 dB). No call-site change needed.

Rules of thumb:
- Play the sound where the **animation** happens (match_fx.gd `_animate_*`), not where the rule resolves, so sound and picture line up and the opponent's actions get sound too.
- One sound per event; let the cooldown absorb bursts (e.g. a several-piece explosion yields one `explosion` plus a few `capture`s, which the 40 ms cooldown thins out).
- A button whose action can fail (buy, take reward) should be `sfx = "none"` and play the success (`ui_purchase`, `ui_confirm`) or `ui_error` from the result handler.
- Tonal cues (`turn_*`, stingers, `promotion`, chimes) have no pitch variation so they stay in tune with the music.

## Music

| id | when | call site |
|---|---|---|
| `music_menu` | title, set/artifact select, map, roster, shop, coaching, reward, run end (128 s loop in sections: theme, variation, bridge, breakdown, turnaround) | `main.gd` `show_screen()`: `Sfx.play_music("music_match" if screen_name == "match" else "music_menu")` (no-op when the loop is already playing, so calling it on every screen change is fine) |
| `music_match` | during a match (120 s loop: vamp, variation with fills, bridge, breakdown) | same place, `screen_name == "match"` |
| `Sfx.stop_music()` | optional: before a run-end stinger, then resume `music_menu` | `run_end_screen.gd` `_ready()` |

## UI

| id | trigger | suggested call site |
|---|---|---|
| `ui_hover` | pointer enters an enabled button | automatic (Sfx) |
| `ui_click` | button pressed | automatic (Sfx) |
| `ui_toggle` | toggle button / check box flipped | automatic (Sfx); also `artifact_select_screen.gd` `_toggle()` for tiles that aren't BaseButtons |
| `ui_confirm` | a choice that commits: Start run, Continue, Start match, accept coaching, choose set | `meta "sfx" = "ui_confirm"` on PrimaryButtons (`ui.gd` `button()` when `variant == "PrimaryButton"`), `set_select_screen.gd` `_choose()`, `roster_screen.gd` `_start_match()`, `coaching_screen.gd` `_apply()` on success |
| `ui_cancel` | Esc / right-click clears a selection, back/close | `match_screen.gd` `_cancel()` (only when something was selected), roster `_bench()` |
| `ui_error` | refused action: unplayable card, illegal square, can't afford, refused result | `match_screen.gd` `press_card()` (unplayable branch), `_refuse()`, `press_square()` escape-prompt miss; shop/coaching/reward `_apply()` / `_accepted()` when `ok` is false; `_finish_match()` refusal |
| `ui_purchase` | shop buy / card removal succeeded | `shop_screen.gd` `_apply()` on success (buy buttons: `set_meta("sfx", "none")` in `_buy_button()`) |
| `ui_open` | an overlay/modal opens (deck view, collection, removal picker, match-over panel) | `main.gd` `_show_deck()`, `_show_collection()`; `shop_screen.gd` `_open_removal()` |
| `ui_close` | that overlay closes | close handler of the overlay (`ui.gd` overlay helper / `Ui.clear(_overlay_host)`) |

## Cards

| id | trigger | suggested call site |
|---|---|---|
| `card_hover` | pointer over an interactive card | `card_view.gd` `_set_hover(true)` (only when `is_interactive`) |
| `card_select` | card selected in hand | `match_screen.gd` `press_card()` after `_selected_card = card_index` |
| `card_play` | `card_played` event | `match_fx.gd` `apply()` → `"card_played"` branch (both sides) |
| `card_draw` | `draw` events (once per batch, player side) | `match_fx.gd` `apply()` after the loop, where `draws[PLAYER] > 0` |
| `card_shuffle` | `shuffle` event | `match_fx.gd` `apply()` → `"shuffle"` |
| `card_discard` | `discard` event / redraw | `match_fx.gd` `apply()` → add a `"discard"` branch (player side) |
| `reward_reveal` | reward cards appear | `reward_screen.gd` `_ready()` |
| `ui_confirm` | reward card taken | `reward_screen.gd` `_take()` on success (CardView isn't a BaseButton, so nothing is automatic) |

## Pieces and board

| id | trigger | suggested call site |
|---|---|---|
| `piece_pickup` | player selects a piece | `match_screen.gd` `press_square()` before `_show_selection()` when `_selected_from` changes; roster drag start |
| `piece_move` | piece slides (`move` event) | `match_fx.gd` `_animate_move()` at tween start |
| `piece_land_light` / `_medium` / `_heavy` | slide ends | `_animate_move()` after `await tween.finished`: pawn/knight → light, bishop/rook → medium, queen/king → heavy (`event["piece_type"]`); skip when `event["is_capture"]` (the capture sound covers it). Roster `_place()` → `piece_land_light` |
| `capture` | `capture` event | `match_fx.gd` `_animate_capture()` |
| `shield_block` | `shield_block` event | `_animate_block()` |
| `explosion` | `explosion` event | `_animate_explosion()` (next to `Feel.shake`) |
| `fire_ignite` | `ignite` event | `_animate_burn()` when `event["type"] == "ignite"` |
| `fire_burn` | `burn_tick` event | `_animate_burn()` otherwise |
| `fire_burnout` | `burn_out` event | `_animate_burn_out()` |
| `promotion` | `promotion` event | `_animate_promotion()` |
| `check` | `check` event | `_animate_check()` |
| `escape` | `escape` event | `match_fx.gd` `apply()` → `"escape"` / `_on_escape()` |
| `ui_cancel` | `escape_declined` (player stays in check) | `_apply()` → `"escape_declined"` |

## Score, energy, turns

| id | trigger | suggested call site |
|---|---|---|
| `score_tick` | `score` event | `_apply()` → `"score"` (or per tick if the score race animates counting) |
| `energy_spend` | player's `card_played` / `redraw` (energy drops) | `_on_side_change()` player branches |
| `energy_refill` | `energy` event, player side | `_apply()` → `"energy"` when `event["side"] == PLAYER` |
| `turn_player` | `turn_start`, player | `_on_side_change()` `turn_start` branch |
| `turn_opponent` | `turn_start`, opponent (soft and short on purpose: it plays every round) | same |

## Stingers and screens

| id | trigger | suggested call site |
|---|---|---|
| `victory` / `defeat` | match over overlay | `match_over_panel.gd` `_ready()` (`player_won`) |
| `run_victory` / `run_defeat` | run end screen | `run_end_screen.gd` `_ready()` |
| `unlock_fanfare` | an unlock is shown | `run_end_screen.gd` `_unlock_panel()`; title unlock panel if it animates in |
| `map_travel` | a map node is chosen | `map_screen.gd` `_choose()` |
| `screen_transition` | screen swap | `main.gd` `show_screen()` / `_play_entrance()` (skip for the first title screen) |
