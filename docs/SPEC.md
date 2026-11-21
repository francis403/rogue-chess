# MVP Spec (verbatim from the brief)

Goal of the MVP: prove that upgrading pieces and cards works and is fun. Not in scope: save/continue mid-run, tutorial, final art polish (clean placeholder art is fine, but it must look intentional).

**Run flow:** New Game → pick starting piece set → pick starting artifacts from those unlocked (only at run start; on the first run none are unlocked, so this step is skipped) → Slay the Spire–style branching map going upward (fixed, hand-built, ~8 floors: 3–4 matches, 1 shop, 1 coaching, 1 boss) → pick a node → repeat until the boss. Losing any match ends the run with a small random artifact unlock from a fixed list. Beating the boss unlocks the Fire piece set. Unlock screen shows the new unlock and a run summary, with a "Start new run" button. Unlocks persist between runs.

**Economy:** one currency, training points. +2 per win; after each win the player picks 1 of 3 random cards to add to the deck, or skips for +1 point.

**Shop:** buy a card (normal 2, rare 3), remove a card, buy a piece.

**Coaching:** offers 3 cards and 3 pieces, each with one random upgrade; the player accepts (pays the price) or declines each.

**Starting collection:** the default chess set (king, queen, 2 rooks, 2 bishops, 2 knights, 8 pawns). Pieces bought in the shop are added to it.

**Before each match:** pick pieces from your collection with a budget of 12 points; the King is free and always included. Place them in your 2 back rows. The roster can change between matches; upgrades stay with their piece. Captured pieces are fully restored after the match.

**Match rules:**
* 6x6 board. Piece values = pick cost = capture points: pawn 1, knight/bishop 3, rook 5, queen 8, king 0.
* Win by capturing the enemy king OR being first to 10 points (both sides race to the same target of 10 points, the same for every opponent, kept in config). The king can be captured; no check or checkmate. A side that cannot move loses.
* No castling, no en passant, no double pawn step. Pawns promote to queen only.
* Every move needs a card. A card is a piece type and moves any one piece of that type (the player picks which). Card costs: pawn 1, minor 1, rook 2, queen 3.
* Hand of 5, 3 energy per turn, resets each turn. Deck cycle like Slay the Spire: draw, discard the rest, reshuffle when empty. If no card is playable, redraw for 1 energy. The player may skip a turn (hand is discarded); the opponent always acts.
* There is no King card. Instead there is a "Move" card (cost 1): move any 1 piece (king included), following that piece's normal chess movement. The king can only move with this card.
* Starting deck: one card per non-king piece type owned, plus one Move card.

**Card upgrades** (2 points, max one per card, any upgrade on any card): energy cost −1; Hold (stays in hand if unplayed; held cards count toward hand size); Book (starts in the opening hand; if several, pick randomly until the hand is full).

**Piece upgrades** (max one per piece, any upgrade on any piece): Range +1 (2 points; no effect on rook/bishop but still allowed); Deploy cost −1 (2 points; capture value unchanged); Shield (4 points; blocks the first capture attempt, the attacker stays where it was, then the shield is gone for good).

**Opponents:** 3 fixed: Easy (king, 4 pawns, bishop, knight; search depth 1, 30% random), Medium (king, 4 pawns, rook, knight; depth 2, 15% random), Boss (king, 4 pawns, queen; depth 2, 5% random). They use a deck and energy like the player, play their best affordable move, and their hand is hidden. Stronger opponents may get random artifacts.

**Piece sets:** Standard (normal chess pieces). Fire (unlocked by beating the boss): once a Fire piece moves it is set on fire and lasts 3 turns; each Fire piece is worth 1 less than its standard value (pick cost and capture points), and any piece it captures gives +2 points; a burned-out piece is removed and counts as captured by the opponent. Water is not in the MVP.

**Artifacts** (passive, chosen at run start): +1 energy every turn (4 instead of 3); captured pieces worth +1 (only for the owner); 2–4 holes placed randomly at match start, never in either side's first 2 rows, only knights can jump over them; exploding pieces (a captured piece also captures adjacent pieces, own pieces included, no chain reactions; if an explosion captures a king, that king's side loses the match).

**Logs** (per run, to a file): wins per deck, cards in the deck at each win and loss, which pieces were used, which pieces were upgraded.

**Tech:** Godot 4.x, GDScript, desktop, single player, offline. Rules engine is pure logic with no nodes, fully unit-testable (GUT). All numbers (point values, prices, energy, AI settings, unlock lists) live in config files, not code. KISS.

**Done:**
* One full run works end to end: new game → pick piece set and artifacts → map → matches, shop, coaching → boss → unlock screen → new run.
* Every rule above is implemented and covered by tests.
* A scripted bot can complete 100 simulated runs with no crashes, illegal states or softlocks.
* The UI is clear, readable and responsive: legal moves highlighted, card costs, energy, score race, and opponent info always visible; every action has feedback.
* Run logs are written.
