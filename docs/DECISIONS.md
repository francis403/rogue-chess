# Decisions

Every assumption made where the spec ([SPEC.md](SPEC.md)) is silent, vague or contradicts itself.
Rule of thumb: the simplest choice that keeps the game fun, with the number in `config/`.

## Board and coordinates
- D1. Squares are `Vector2i(x, y)`, x = file 0..5 left→right, y = rank 0..5. The player owns ranks 0–1 (bottom of the screen), the opponent ranks 4–5. Player pawns move +y, opponent pawns −y.
- D2. The player always takes the first turn of a match (`match.json: player_moves_first`).
- D3. Opponent rosters and squares are fixed in `opponents.json` (pieces never change between visits).

## Turns, cards, energy
- D4. A turn = refill energy, draw up to hand size, then play **any number of cards** while energy lasts (Slay the Spire style), then end the turn. Each card played = exactly one piece move.
- D5. End of turn: every card in hand without Hold is discarded. Hold cards stay and count toward the hand size of 5, so fewer cards are drawn next turn.
- D6. Drawing: if the draw pile is empty, the discard pile is shuffled into it. If both are empty (every card is in hand), drawing stops early.
- D7. A card is *playable* if its cost ≤ current energy and it has at least one legal move (a piece of its type, or any piece for Move, with a legal destination).
- D8. **Redraw** (cost `match.json: redraw_cost` = 1) is only available when no card in hand is playable. It discards the **whole hand, Hold cards included** (otherwise a hand of dead Hold cards could never be cleared — found in review) and draws a fresh 5. It can be used more than once per turn if energy allows.
- D9. **Skip turn** for the player = end the turn early (unplayed non-Hold cards are discarded). The AI never skips while it has a playable card; it redraws when nothing is playable and, after paying for the redraw, it would still have enough energy for the cheapest card in its deck; otherwise it ends the turn.
- D10. Every match starts with a fresh copy of the run deck, shuffled. The opening hand (first draw of the match) takes Book cards first (random subset if more Book cards than hand size), then fills from the shuffled pile.
- D11. Energy cost −1 cannot go below 0. A 0-cost card is still discarded when played.
- D12. Promoted pawns become queens for the rest of the match: they need a Queen (or Move) card and are worth queen points when captured. After the match they are pawns again (match state never changes the collection except D20).

## Winning and losing a match
- D13. Order after every move: resolve the capture (+ explosion), add points, then check (1) a king was captured, (2) a side reached the target score. If both kings die in one explosion, the side that made the move loses. If both sides reach the target on the same move, the side that made the move wins.
- D14. "A side that cannot move loses" = at the start of its turn the side has **no legal piece move on the board at all** (cards are ignored; a bad hand is solved by redraw/skip, not by losing).
- D15. Anti-softlock turn limit: `match.json: max_rounds` = 40 rounds (one round = player turn + opponent turn). When it runs out, the higher score wins; a tie goes to the opponent (the player must force the issue).

## Piece movement
- D16. Standard chess moves otherwise; pawns move 1 forward (no double step), capture 1 diagonally forward, promote to queen on the far rank. No castling, no en passant, no checkmate (but see the check escape, D56).
- D17. Range +1: king moves up to 2 squares in any straight/diagonal line (path must be clear); pawn may move up to 2 forward (path clear, no capture forward), captures stay 1 diagonal; knight additionally gets the (±3,±1)/(±1,±3) leaps. Rook, bishop and queen: no effect (allowed, as the spec says).
- D18. Holes: no piece may stop on a hole; sliding pieces, pawns and kings are blocked by them; knights jump over them (they can't land on one either).

## Upgrades, shields
- D19. Upgrades are stored on the card/piece in the run and apply in every match.
- D20. Shield: the attacked piece survives, the attacker stays where it was, the card is still spent and the move ends. The shield is **consumed for the rest of the run** ("gone for good"): the upgrade slot becomes empty, so coaching can offer that piece a new upgrade. An explosion also counts as a capture attempt and eats a shield.
- D21. Coaching only offers cards/pieces that have no upgrade yet (max one per item). Upgrade picked uniformly at random. If fewer than 3 eligible items exist, fewer are offered.

## Piece sets
- D22. The chosen piece set applies to the whole collection for the run, including pieces bought in the shop. Opponents always use Standard.
- D23. Fire: the **king is not a Fire piece** (`piece_sets.json: king_is_fire = false`), otherwise moving the king would be suicide. Fire pawns are worth 0 (pick cost 0, capture points 0).
- D24. Fire burn: the first time a Fire piece moves it ignites with 3 turns (`burn_turns`). At the end of each of its owner's turns (the ignition turn included) every burning piece loses 1; at 0 it is removed and its value goes to the opponent as a capture. Moving again does not reset the timer.
- D25. Fire capture bonus (+2) applies to any capture made by a Fire piece (burning or not yet burning — it ignites on that same move anyway).

## Artifacts
- D26. Artifact list and unlock pool live in `artifacts.json`. Player picks **up to 2** (`max_starting_artifacts`) of the unlocked ones at run start, or none.
- D27. "Captured pieces worth +1 (only for the owner)": every piece credited to the owner as a capture (normal, explosion or burn-out) gives the owner +1. The opponent gets no bonus for capturing the owner's pieces.
- D28. Holes: if either side has the artifact, 2–4 holes (uniform) are placed on empty squares of ranks 2–3 at match start.
- D29. Exploding: when the **owner** captures a piece, the 8 squares around the captured piece's square explode; every piece there (both sides, never the attacker who now stands on the centre square) is captured, no chain reactions. Each exploded piece scores for its owner's opponent. A shielded piece in the blast loses its shield instead.
- D30. Boss gets `artifact_count` = 3 distinct random artifacts from the full pool (opponent_pool since D69); Easy and Medium get none. Tuned with the 100-run sim so the boss stays the hardest fight: 1 artifact made it easier than Medium (80% player wins); 2 fixed that until the check escape (D56) made it ~62% again, the same as Medium; with 3 it is ~46% vs Medium ~65%. The sim bot never picks foresight and never buys Scouts (it can't use hidden-card information), so these numbers stay comparable after D63–D70.

## Economy and run
- D31. Starting points 0. Win = +2; reward = pick 1 of 3 random distinct card types (no upgrade) or skip for +1.
- D32. Rarity: Rook and Queen cards are rare (3 in the shop), all others normal (2).
- D33. Shop stock per visit: 3 random cards, 2 random pieces (prices in `economy.json`: pawn 1, knight 2, bishop 2, rook 3, queen 5; the spec gives no piece prices), 1 card removal (price 1). Each offer can be bought once. The deck can't go below 4 cards (`min_deck_size`).
- D34. Buying a piece does not add a card to the deck (the starting-deck rule only applies at run start).
- D35. Map: 7 floors, 3 lanes, hand-built in `map.json`. Every path from a start node to the boss has exactly 4 matches, 1 shop, 1 coaching and the boss (enforced by a unit test). "~8 floors" → 7 including the boss. Floors 1–2 are Easy, 3–6 Medium.
- D36. Pre-match roster: the king is always included and free; budget 12 counts `deploy_cost()`. The player places pieces on their 2 back ranks; an "Auto" button fills a sensible default. Pawns may be placed on either back rank.
- D37. Losing a match: unlock one random artifact from the pool that is not unlocked yet (none if all are unlocked). Beating the boss: unlock Fire (nothing new if already unlocked). Either way the run ends on the unlock/summary screen.
- D38. Persistence: unlocks in `user://meta.json`. Mid-run state is not saved (out of scope).
- D39. Run logs: one JSON file per run in `user://logs/run_<timestamp>_<seed>.json`, plus `user://logs/stats.json` aggregating wins per piece set and per deck size across runs. "Wins per deck" = wins in that run tagged with the piece set and the deck list at each win.
- D40. The piece-set step is always shown (Fire visible but locked until unlocked). The artifact step is skipped when nothing is unlocked.

## AI
- D41. The AI plans one card play at a time: it lists every affordable (card, piece, destination), and searches `search_depth` plies where opponent replies are *any legal piece move* (it can't see the player's hand, so it doesn't cheat). Depth 1 = evaluate the position right after its move. With `random_chance` it plays a random playable move instead. Evaluation weights in `ai.json`.
- D42. The same AI class plays the player side in the 100-run simulation bot.

## Resolved during implementation (M1)
- D43. A Fire piece whose attack is blocked by a Shield did not move, so it does not ignite.
- D44. Fire's +2 applies only to the piece a Fire piece captures directly, not to explosion victims.
- D45. A burn-out is not a capture attempt: it ignores Shields and does not trigger Powder Keg, but it does give the opponent's Trophy Case +1.
- D46. Trophy Case +1 also applies to 0-value captures (king, Fire pawns).
- D47. A promoted pawn keeps its set and burn timer (a Fire pawn becomes a Fire queen worth 7).
- D48. Match result lists every deployed player piece (`player_pieces_used`) and, separately, the ones that moved (`player_pieces_moved`); logs record both.
- D49. Shields used are removed from the collection after the match whether it was won or lost.
- D50. Default roster (the "Auto" button): king at (2,0), a full wall of 6 pawns on rank 1, then the most valuable non-pawn pieces that fit (upgraded first) on rank 0 (`economy.json: default_roster.pawns`). Originally 4 pawns, but the UI integration test showed Medium's rook sniping the king down an open corner file in round 1.
- D51. Shop and reward offers within one visit are distinct types. Shop pieces use the run's set at the configured prices (Fire pieces cost the same as standard ones).
- D52. Coaching may offer the king any upgrade, including Deploy −1 (useless on a free king, but "any upgrade on any piece"). Leaving coaching with offers still open is allowed.
- D53. The shop can't remove your last Move card: the king can only move with it, so removing it could leave a side unable to act (found in review).
- D54. Bad roster squares passed straight to ChessMatch (bypassing RunSession validation) are a programming error and assert; RunSession always validates first.
- D55. AI king safety (extends D41): besides the single-reply search, the evaluation penalises positions where an enemy piece can capture the AI's king (or queen/rook, scaled) within 2 raw moves on a static board, adds a small king-exposure term, and at depth 2 treats "a card still in hand can take the king / reach the target score" as a sure win (no reply happens mid-turn). Weights in `ai.json`. Result: depth-2 vs depth-2 matches with default rosters last ~6–8 rounds (was ~3).

## Check escape (added after the MVP, from the Miro rule clarification)
- D56. **Check**: after a card play, if any piece of the side that moved could capture the enemy king with its normal movement, the enemy king is in check. Checks are only looked for after card plays (not after burn-outs or turn starts). A shield on the king does not prevent check.
- D57. **Escape**: the checked side may immediately move its king once, out of turn, using the king's normal movement (Range +1 included). It needs no card. The destination must not be attacked by the enemy (capturing the checking piece is allowed if that square is safe). If no safe square exists, there is no escape. The move resolves like any move (captures, points, explosions, win checks). Then the checking side continues its turn.
- D58. **Optional**: the escape can be declined (the player gets a prompt; the AI decides). Declining leaves the king in check.
- D59. **Cost**: `match.json: check_escape_cost` = 1 energy, taken off the escaping side's **next** turn (3 becomes 2). "Must have at least 1 energy remaining" = the escaping side's next-turn budget after earlier escape costs this round must still cover the cost, so with 3 energy a side can escape at most 3 times per enemy turn and its next turn can drop to 0.
- D60. Several checks in one turn each offer an escape, each costing 1, while the budget allows.
- D61. A square holding a shielded enemy piece is never an escape square (the shield would block the capture and the king would not move).
- D62. "Safe" escape square = no enemy piece could capture the king there with normal movement, checked on a board copy after the move. Powder Keg blasts are not considered.

## Opponent card visibility (from the Miro clarifications 2026-11-25)
Spec: [specs/opponent-card-visibility.md](specs/opponent-card-visibility.md).
- D63. **Draw timing**: the opponent draws at match start and again at the end of its own turn (after its discard), so during the player's turn it already holds the hand it will play next. It does not draw when its turn ended the match. Its turn start draws nothing (the hand is full). The player still draws at its own turn start (D4).
- D64. **Hidden cards**: every time the opponent draws a new hand (match start, end of its turn, or its own redraw), the **last N cards of its hand right after the draw** are hidden — the last N drawn, since its hand is empty before drawing (opponent cards never have Hold) — N = clamp(`hidden_cards` − the player's foresight `amount`, 0, hand size); every earlier mark is cleared. A mark never moves: when the opponent plays a card (shown face up, as before), the remaining cards keep their own state. The opponent's `draw` events carry no `card_type`, and the UI reads only `visible_opponent_hand()` / `hidden_card_count()`.
- D65. `match.json: opponent_hidden_cards` = 1 is the default; each opponent in `opponents.json` has `hidden_cards` (all 1 for now). Missing → the default; negative → 0; more than the hand → the whole hand.
- D66. **Scout** card (`cards.json: scout`, cost 1, normal, `reveal: 2`): the player plays it with `reveal()`, without a piece. It reveals the next `min(2, hidden)` hidden cards in hand order and is refused (`nothing_hidden`, no energy spent) when nothing is hidden. It moves nothing, so it never appears in `legal_plays`, does not stop a redraw (D8: a hand of only Scouts can be redrawn), and the AI / sim bot never play it. The opponent can't play one (`player_only`).
- D67. Reveals last for the current opponent hand only: its next hand starts again from D64.
- D68. **foresight** (`artifacts.json: foresight`, shown as "Deep Vision", `amount` 1, `penalty` 1): +1 visible card per opponent hand. While the player owns it, every player piece credited to the opponent gives the opponent +`penalty` on top of that capture's points — normal capture, check-escape capture, explosion (the player's own Powder Keg included) and burn-out — also for 0-value pieces (king, Fire pawn), like D46. Only the player's foresight counts: on the opponent it would do nothing.
- D69. foresight is in `unlock_pool` (chosen at run start like any artifact) but not in the new `artifacts.json: opponent_pool`, which replaces "the full pool" of D30 for opponent artifacts (the boss still gets 3 distinct ones).
- D70. Scout is only in the shop's `card_pool` (normal price): never a reward card and never in an opponent deck.
