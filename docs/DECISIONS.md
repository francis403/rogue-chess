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
- D16. Standard chess moves otherwise; pawns move 1 forward (no double step), capture 1 diagonally forward, promote to queen on the far rank. No castling, no en passant, no check.
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
- D27. "Captured pieces worth +1, own pieces too": every piece credited to the owner as a capture (normal, explosion or burn-out) gives the owner +1, and every owner's piece credited to the opponent (normal, explosion or burn-out) gives the opponent +1. If both sides have Trophy Case, each capture gets +2.
- D28. Holes: if either side has the artifact, 2–4 holes (uniform) are placed on empty squares of ranks 2–3 at match start.
- D29. Exploding: when the **owner** captures a piece, the 8 squares around the captured piece's square explode; every piece there (both sides, never the attacker who now stands on the centre square) is captured, no chain reactions. Each exploded piece scores for its owner's opponent. A shielded piece in the blast loses its shield instead.
- D30. Boss gets `artifact_count` = 2 distinct random artifacts from the full pool; Easy and Medium get none. (Tuned from 1 → 2 after the 100-run sim showed the boss easier than Medium: player beat it 80% vs Medium 53%; with 2 it is ~38%.)

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
- D45. A burn-out is not a capture attempt: it ignores Shields and does not trigger Powder Keg, but it does get the Trophy Case +1 (D27) for either side's Trophy Case.
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
