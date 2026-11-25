# Opponent Card Visibility

Source: Miro board "MVP Match Rules — Opponent Card visibility" and its "Clarifications 2026-11-25" frame.

## Goal
During their turn the player sees most of the opponent's hand, so they can plan around what it can do. Some opponent cards stay hidden. Opponent settings, a shop card (Scout) and an artifact (foresight) change how many.

## Turn flow
1. Match start: both sides draw. The opponent's hand is shown except its hidden cards (default 1).
2. The player plays cards, seeing the visible opponent cards.
3. The player ends the turn; the opponent plays its cards (each card it plays is shown face up, as before).
4. At the end of its turn the opponent discards and **draws its next hand right away**, with the same hiding rule. The player's next turn shows that hand.

## Rules
- R1. `match.json: opponent_hidden_cards` = 1 is the default. Each opponent in `opponents.json` has `hidden_cards` (editable; missing → default; negative → 0).
- R2. When the opponent draws a new hand, the **last N cards drawn** are marked hidden, N = clamp(hidden_cards − foresight amount, 0, hand size). A card's hidden mark never moves to another card: playing a card never hides a visible one.
- R3. Scout card (`cards.json: scout`, cost 1, normal rarity, `reveal: 2`): played by the player on their turn without a piece or target. It reveals the next `min(2, hidden)` hidden cards (in hand order). It cannot be played when nothing is hidden (it would waste energy). It never counts as a legal move (`legal_plays`, redraw rule D8 and AI ignore it). It is added to the shop card pool only (not rewards, not opponent decks).
- R4. foresight artifact (`artifacts.json: foresight`, shown as "Deep Vision", `amount: 1`, `penalty: 1`): +1 visible card per opponent hand; while the player owns it, every player piece captured (capture, explosion or burn-out — all credited to the opponent) gives the opponent +1 point, added to that capture's points like Trophy Case. It is in the unlock pool (chosen at run start) and is excluded from the opponent artifact pool (`artifacts.json: opponent_pool`).
- R5. Reveals last for the current opponent hand only; a new hand (end of opponent turn, or an opponent redraw) starts again from R2.
- R6. Display safety: the UI shows the opponent's hand only through `visible_opponent_hand()` and `hidden_card_count()`. The opponent's `draw` events carry no `card_type`.

## Godot design
- Engine (`scripts/core/match/chess_match.gd`): tracks `_hidden_uids` (uids of hidden opponent cards). New queries `visible_opponent_hand()`, `hidden_card_count()`, `can_reveal(card_index)`; new action `reveal(card_index)` → `card_played` + `reveal` events. `is_card_playable()` is true for a Scout when `can_reveal()`. `clone()` copies the hidden set.
- `CardData.is_reveal()` (true when the card's config has `reveal`).
- `RunSession._opponent_setup()` passes `hidden_cards`; opponent artifacts come from `opponent_pool`.
- UI: the opponent panel's hand row shows visible cards face up (small, with glyph and cost) followed by hidden card backs, plus a caption "N shown · M hidden". Selecting a Scout (click, key or drag) plays it at once. Scout and foresight get their own glyph / emblem.

## Acceptance criteria
- AC1. New match with defaults: hidden count 1, visible = hand − 1; the UI never shows a hidden card's face.
- AC2. `hidden_cards` 0 → all visible; ≥ hand size → all hidden; no errors.
- AC3. After the opponent's turn its new hand follows the same rule, and earlier reveals are gone.
- AC4. Scout costs 1 energy, reveals 2 (never more than are hidden), is refused when none are hidden.
- AC5. foresight: +1 visible; opponent +1 per player piece captured; no effect without it.
- AC6. Scout + foresight stack (e.g. hidden_cards 4 → 3 hidden → Scout → 1 hidden).
- AC7. All existing tests pass; new tests cover R1–R6; hidden/visible cards are clearly distinct and the panel never overflows for 0–5 hidden.

## Key tests
- `tests/unit/match/test_opponent_visibility.gd`: R1–R6 at the engine level.
- `tests/unit/run/*`: `hidden_cards` passed from config; Scout in the shop pool; foresight never given to opponents.
- `tests/integration/test_ui_opponent_hand.gd`: hand row faces/backs match the engine for several hidden counts; Scout played from the UI flips cards.
