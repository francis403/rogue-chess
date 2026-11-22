## ChessMatch

Rules engine: `scripts/core/match/` — `ChessMatch` (the match), `MatchPiece` (a piece on the board), `MatchBoard` (grid + holes), `MoveGenerator` (raw piece movement), `MatchSide` (one side's cards/energy/score). Pure logic (`RefCounted`, no nodes), deterministic for a given `setup["seed"]` (one `RandomNumberGenerator` drives deck shuffles and hole placement). Rules: SPEC "Match rules" + DECISIONS D1–D30.

### Setup

```gdscript
var game := ChessMatch.new({
  "seed": int,
  "player":   {"roster": [{"piece": PieceData, "square": Vector2i}], "deck": Array[CardData], "artifacts": Array[String]},
  "opponent": {"id": String, "roster": [...same...], "deck": Array[CardData], "artifacts": Array[String]},
  # optional, tests/debug only: fixed holes instead of the random Sinkholes placement
  "holes": Array[Vector2i],
})
```
- Constants `ChessMatch.PLAYER = 0`, `ChessMatch.OPPONENT = 1`. Squares are `Vector2i(file, rank)` (D1); player pawns move +y.
- Every `PieceData` and `CardData` is **copied**; the match never mutates what you pass in (a used shield is reported in `result()` instead, D20). Extra keys in `opponent` (name, search_depth, ...) are ignored.
- The constructor shuffles both decks (Book cards on top, D10), places holes (D28), and **starts the first turn** (`match.json: player_moves_first`, D2). Its events are in `initial_events()`. A side with no legal piece move at the start of its turn loses immediately (D14) — this can happen in the constructor.
- An invalid roster square (off-board or taken) fails an `assert` (D54); release builds skip that entry.

### Queries (never change state)

| call | returns |
|---|---|
| `initial_events()` | `Array[Dictionary]` from starting the first turn |
| `current_side()` | 0/1 — whose turn it is |
| `current_round()` | int, starts at 1; +1 when the first side starts a turn |
| `max_rounds()` | int (`match.json: max_rounds`, D15) |
| `opponent_id()` | String from setup |
| `artifacts(side)` | `Array[String]` |
| `energy(side)`, `max_energy(side)` | int (3, or 4 with `extra_energy`) |
| `hand(side)` | `Array[CardData]` (a new array; the cards themselves are read-only) |
| `draw_pile_size(side)`, `discard_size(side)`, `deck_size(side)` | int (`deck_size` = hand + draw + discard) |
| `score(side)`, `target_score()` | int |
| `board_size()` | int (6) |
| `pieces(side)` | `Array[MatchPiece]`, live objects — **read only** |
| `piece_at(square)` | `MatchPiece` or null (null off-board too) |
| `holes()`, `is_hole(square)` | `Array[Vector2i]`, bool |
| `is_over()`, `result()` | bool, Dictionary (`{}` until over) |
| `piece_moves(from)` | `Array[Vector2i]` raw movement of the piece on `from` (either side), ignoring cards/turn — AI lookahead and the D14 rule |
| `has_any_piece_move(side)` | bool |
| `legal_plays(side)` | `Array[Dictionary]` of `{"card_index", "from", "to"}` — **every** legal, affordable card play right now; empty if it isn't `side`'s turn or the match is over. Single source of truth for UI highlights, AI and bots. Two identical cards produce duplicate entries with different `card_index`. |
| `is_card_playable(card_index)` | bool — current side; affordable and moves at least one piece (D7) |
| `pieces_for_card(card_index)` | `Array[Vector2i]` squares of current-side pieces the card can move now (empty if unaffordable) |
| `targets(card_index, from)` | `Array[Vector2i]` destinations for that card on that piece (empty if not allowed/affordable) |
| `can_redraw()` | bool — not over, energy ≥ `redraw_cost`, and `legal_plays` is empty (D8) |

`MatchPiece` fields: `uid` (match-local, unique, stable for the match), `side`, `type` (current type — a promoted pawn is `"queen"`), `square`, `data` (`PieceData` copy: `data.uid` is the collection uid, `data.upgrade`, `data.piece_set`), `shield_active`, `burn_turns_left` (0 = not burning), `is_promoted`, `has_moved`; `is_burning()`, `value()` (current capture points), `burn_turns()`, `capture_bonus()`.

Card rules: a card moves one piece of its type; `"move"` moves any piece and is the only way to move a king. `CardData.cost()` (Cheaper included, min 0).

### Actions (current side only)

Each returns `Array[Dictionary]` of events. An illegal call changes nothing and returns exactly `[{"type": "error", "reason": String}]`; reasons: `match_over`, `bad_card_index`, `no_own_piece`, `wrong_card`, `not_enough_energy`, `illegal_move`, `redraw_not_allowed`. Nothing ever crashes on bad input.

- `play(card_index, from, to)` — spends the card's cost, discards the card, resolves the move (D13 order): shield block **or** capture → points → explosion → ignite → promotion → win check.
- `redraw()` — only when `can_redraw()`. Costs `redraw_cost`, discards the **whole** hand (Hold cards included, D8), draws a fresh hand. Repeatable while affordable.
- `end_turn()` — also the player's "skip". Burn ticks for this side's burning pieces (D24), discard non-Hold cards (D5), turn limit check (after the second side's turn of round `max_rounds`), then the other side's turn starts: energy refill, draw to 5 (reshuffle when needed, D6), no-move check (D14).
- `clone() -> ChessMatch` — deep copy (board, pieces, decks, RNG state) for AI search; the copy plays out exactly like the original. Cards and `PieceData` are shared (immutable here). Cost ≈ 0.15 ms per clone and ≈ 0.25 ms of move generation per side (debug build) — for depth 2, clone once per own play and evaluate replies with `piece_moves()` / `piece_at()` on that clone rather than cloning per reply.

### Result (`result()` once `is_over()`)

```
{"winner": 0|1, "reason": "king"|"score"|"no_moves"|"turn_limit",
 "scores": [player, opponent], "rounds": int, "opponent_id": String,
 "shields_consumed": [PieceData uids of player pieces whose shield was used (capture or explosion)],
 "player_pieces_used": [PieceData uids of every deployed player piece],
 "player_pieces_moved": [PieceData uids of player pieces that moved at least once],
 "captured": [{"uid": PieceData uid, "side": owner, "type": String (type at capture), "by_side": credited side,
			   "points": int, "cause": "capture"|"explosion"|"burn_out"}]}
```
Turn limit: higher score wins, tie → opponent (D15). Both kings lost at once → the side that acted loses; both sides at target at once → the side that acted wins (D13).

### Events

Every event has `"type"`; most have `"side"` (the side it concerns). `uid` is the `MatchPiece.uid`.

| type | keys | when |
|---|---|---|
| `turn_start` | side, round | a side's turn begins |
| `energy` | side, energy | energy refilled at turn start |
| `shuffle` | side, count | discard shuffled into the empty draw pile |
| `draw` | side, card_uid, card_type | one card drawn (the UI hides the opponent's) |
| `card_played` | side, card_index, card_uid, card_type, cost, energy (left) | first event of every legal `play` |
| `move` | side, uid, piece_type, from, to, is_capture | the piece moved (not emitted when a shield blocks) |
| `shield_block` | side (defender), uid, square, cause ("capture"\|"explosion"), attacker_uid (-1 for explosions), attacker_square | a shield absorbed a capture; the attacker stays on `attacker_square` |
| `capture` | side (victim owner), uid, piece_type, square, by_side, points, cause ("capture"\|"explosion") | a piece was removed by a capture or an explosion |
| `explosion` | side (exploder), square (centre), squares (in-board neighbours) | Powder Keg goes off, before its `capture`/`shield_block` events |
| `score` | side, points, total | points credited (only when points > 0) |
| `ignite` | side, uid, square, turns_left | a Fire piece moved for the first time |
| `burn_tick` | side, uid, square, turns_left | end of the owner's turn |
| `burn_out` | side (owner), uid, piece_type, square, by_side, points, cause "burn_out" | burned piece removed, credited to the opponent |
| `promotion` | side, uid, square, piece_type ("queen") | pawn reached the far rank |
| `redraw` | side, energy (left) | start of a `redraw()` |
| `discard` | side, card_uids | hand discarded (end of turn: Hold cards stay; redraw: whole hand) |
| `turn_end` | side, round | after the discard |
| `match_over` | winner, reason, scores, rounds | last event of the action that ended the match |
| `error` | reason | the only event of a rejected action |

### Rules resolved beyond DECISIONS.md

- A Fire piece whose attack is blocked by a Shield did not move, so it does **not** ignite.
- Fire's +2 applies only to the piece the Fire piece captures directly, not to pieces caught in its explosion.
- Burn-out is not a capture attempt: it ignores Shields and does not trigger Powder Keg. It does get the Trophy Case +1 from either side's Trophy Case (D27).
- Trophy Case: +1 per capture for each Trophy Case held by the capturer or the victim's owner (so +2 when both have it). Also applies to 0-value pieces (king, Fire pawn).
- Promoted pawns keep their piece set (a Fire pawn becomes a Fire queen worth 7) and their burn timer.
- Turn limit and round counting follow the side that moves first.

## RunSession

Run layer: `scripts/core/run/` (`RunSession`, `MapGraph`) and `scripts/core/meta/` (`MetaStore`, `RunLogger`). Pure logic (`RefCounted`, no nodes), deterministic for a given seed (one `RandomNumberGenerator` per run). Used the same way by the UI and the sim bot. It never plays a match: it builds a setup for `ChessMatch.new(setup)` and consumes the result.

### Lifecycle

```gdscript
var meta := MetaStore.new()                 # user://meta.json (tests/sim: MetaStore.new("user://sim/meta.json"))
var logger := RunLogger.new()               # user://logs/      (tests/sim: RunLogger.new("user://sim/logs/"))
var run := RunSession.new(seed, meta, logger)   # meta/logger default to the above when null
# ... drive the phases below until run.is_over() ...
var next_run := RunSession.new(new_seed, meta, logger)   # one RunSession per run; unlocks live in meta
```

### Phases (`RunSession.Phase`)

```
SET_SELECT -> ARTIFACT_SELECT (skipped when no artifact is unlocked, D40) -> MAP
MAP -> choose_node(): match/boss node -> MATCH_SETUP -> MATCH -> REWARD -> MAP
					  shop node       -> SHOP     -> MAP
					  coaching node   -> COACHING -> MAP
finish_match(): loss (any node)  -> RUN_END (+1 random artifact unlocked, D37)
				boss win         -> RUN_END (Fire unlocked)
```

`run.phase` (enum), `run.phase_name()` ("MAP", ...), `run.is_over()` (phase == RUN_END).

### Results

Every action returns `{"ok": bool, "error": String}` (`error` is "" on success, a player-readable reason otherwise). An action called in the wrong phase, with a bad index, or that the player can't afford is refused and changes nothing. Queries never fail (they return empty values outside their phase).

### State (read only — change it through the actions)

| var | type | |
|---|---|---|
| `run_seed` | int | |
| `phase` | `Phase` | |
| `piece_set` | String | "" until chosen |
| `artifacts` | `Array[String]` | chosen at run start |
| `collection` | `Array[PieceData]` | every piece owned, all in `piece_set`; upgrades live on the pieces |
| `deck` | `Array[CardData]` | the run deck |
| `points` | int | training points, never negative |
| `current_node` | String | "" before the first node |
| `visited` | `Array[String]` | node ids in order |
| `wins` | int | matches won |
| `map` | `MapGraph` | for drawing the map |
| `meta` | `MetaStore` | unlock store |
| `logger` | `RunLogger` | run log |

Starting collection = `economy.json: starting_collection` in the chosen set. Starting deck = one card per non-king piece type owned + one Move (6 cards). Points start at `starting_points`.

### Piece set and artifacts

| call | returns | phase |
|---|---|---|
| `available_piece_sets()` | `[{id, name, desc, locked: bool}]` (all sets, Fire locked until unlocked) | any |
| `choose_piece_set(id)` | result; builds collection + deck, starts the run log | SET_SELECT |
| `available_artifacts()` | `[{id, name, desc}]` unlocked ones | any |
| `max_starting_artifacts()` | int (2) | any |
| `choose_artifacts(ids: Array)` | result; 0..max distinct unlocked ids | ARTIFACT_SELECT |

### Map

| call | returns |
|---|---|
| `available_nodes()` | `Array[String]` node ids selectable now (start nodes first; [] outside MAP) |
| `choose_node(id)` | result; moves to MATCH_SETUP / SHOP / COACHING |
| `current_node_info()` | `{id, floor, lane, type, opponent, next}` or {} |

`MapGraph` (from `config/map.json`): `floors()`, `start_nodes()`, `node_ids()`, `has_node(id)`, `node(id) -> {id, floor, lane, type: "match"|"shop"|"coaching"|"boss", opponent: String ("" for shop/coaching), next: Array[String]}`, `available_nodes(current_id)` ("" → start nodes), `nodes_on_floor(n)`.

### Roster and match (MATCH_SETUP → MATCH)

A roster is `Array` of `{"piece": PieceData, "square": Vector2i}`.

- `deploy_budget() -> int` (12).
- `default_roster() -> Array[Dictionary]` — the "Auto" button: king + up to `economy.json: default_roster.pawns` pawns, then the highest `deploy_cost()` pieces that still fit (upgraded first on ties). Pawns go on the front rank (y = 1) centre-out, others on y = 0 centre-out, king at (2, 0). Always valid.
- `validate_roster(roster) -> {ok, error, cost}` — pieces must be in the collection (matched by uid), no duplicates, king present (free), squares unique with x 0..5 and y 0..1, total `deploy_cost()` ≤ budget (Deploy −1 and Fire −1 included). `cost` only on success.
- `build_match_setup(roster) -> Dictionary` (MATCH_SETUP only; moves to MATCH). On failure returns `{"ok": false, "error": ...}` and stays in MATCH_SETUP; on success (no `ok` key):

```
{"seed": int,
 "player":   {"roster": [{"piece": PieceData, "square": Vector2i}], "deck": Array[CardData], "artifacts": Array[String]},
 "opponent": {"id": "easy"|"medium"|"boss", "name": String, "difficulty": String, "search_depth": int, "random_chance": float,
			  "roster": [{"piece": PieceData (standard), "square": Vector2i}], "deck": Array[CardData], "artifacts": Array[String]}}
```
Player pieces and cards are **copies** (same uid) so the match can never change the run. Opponent squares come from `opponents.json` ([x, y], y = 4..5); opponent artifacts are `artifact_count` distinct random ids from the full artifact list (D30).

- `finish_match(result) -> result` (MATCH only). `result`:
```
{"winner": 0|1 (0 = player), "reason": String, "scores": [player, opponent],
 "shields_consumed": [player PieceData uids], "player_pieces_used": [player PieceData uids],
 "player_pieces_moved": [player PieceData uids]}
```
Only `winner` is required. Effects: pieces in `shields_consumed` that still have "shield" lose it (D20, win or loss); win → +`win_points` (2), `wins` + 1; the match is logged; then non-boss win → REWARD, boss win → unlock Fire → RUN_END, loss → unlock one random artifact → RUN_END.

### Reward (REWARD → MAP)

- `reward_offers() -> Array[CardData]` — `reward_choices` (3) distinct random card types from `reward_card_pool`, no upgrade.
- `take_reward(index)` — adds that card to the deck.
- `skip_reward()` — +`reward_skip_points` (1).

### Shop (SHOP → MAP)

- `shop_offers() -> {"cards": [{"card": CardData, "price": int, "sold": bool}], "pieces": [{"piece": PieceData, "price": int, "sold": bool}], "remove_price": int, "removes_left": int}` — generated once on entering the shop (3 distinct cards priced by rarity, 2 distinct pieces in the run's set priced from `piece_prices`).
- `buy_card(index)`, `buy_piece(index)` — each offer once; refused with "Not enough points ..." when short. A bought piece does not add a card (D34).
- `remove_card(card_uid)` — `removes_per_visit` (1) per shop, price `remove_price`, refused when the deck would drop below `min_deck_size` (4) or the card is the last Move card (D53).
- `leave_shop()`.

### Coaching (COACHING → MAP)

- `coaching_offers() -> [{"kind": "card"|"piece", "item": CardData|PieceData (the real deck card / collection piece), "upgrade": String, "upgrade_name": String, "price": int, "state": "open"|"accepted"|"declined"}]` — generated once on entering: up to 3 deck cards then up to 3 collection pieces that have no upgrade (fewer if fewer are eligible, D21), each with a uniformly random upgrade of its kind; price from `upgrades.json`.
- `accept_coaching(index)` — pays and applies the upgrade; refused if not open, not affordable, or the item already has an upgrade (max one per item).
- `decline_coaching(index)` — closes that offer.
- `leave_coaching()` — open offers may be left undecided.

### Run end (RUN_END)

- `unlock_result() -> {"kind": "artifact"|"piece_set", "id": String ("" if nothing new was left), "is_new": bool, "text": String}` ({} before the run ends).
- `summary() -> {"result": "won"|"lost", "boss_defeated": bool, "floors_cleared": int, "floors_total": int, "wins": int, "points": int, "piece_set": String, "artifacts": [..], "visited": [..], "deck": [CardData.to_dict()], "collection": [PieceData.to_dict()], "upgraded_pieces": [PieceData.to_dict()], "unlock": unlock_result()}`.

### MetaStore (`scripts/core/meta/meta_store.gd`)

`MetaStore.new(path = "user://meta.json")` loads immediately; missing/corrupt file or unknown ids → defaults (`piece_sets.json: default_unlocked`, no artifacts). Vars `unlocked_piece_sets`, `unlocked_artifacts` (`Array[String]`). `is_piece_set_unlocked(id)`, `is_artifact_unlocked(id)`, `unlock_piece_set(id) -> bool` (true if new), `unlock_random_artifact(rng) -> String` ("" if all unlocked), `load_from_disk()`, `save() -> bool`, `reset_to_defaults()` (memory only). Unlocks save immediately.

### RunLogger (`scripts/core/meta/run_logger.gd`)

`RunLogger.new(directory = "user://logs/")`. RunSession calls it; other code only reads. One file per run, `run_<yyyymmddThhmmss>_<seed>.json` (suffix `_2`, ... if taken), rewritten after every entry:
```
{"seed", "started_at", "finished_at", "piece_set", "artifacts",
 "matches": [{"node", "floor", "opponent", "result": "win"|"loss", "reason", "scores",
			  "deck": [card dicts at the win/loss], "roster": [piece dicts + "square": [x, y]],
			  "pieces_used": [roster piece dicts, pre-match upgrades], "pieces_moved": [roster piece dicts, pre-match upgrades],
			  "shields_consumed": [uids], "points_after"}],
 "events": [{"kind": "reward"|"reward_skip"|"purchase_card"|"purchase_piece"|"remove_card"|"upgrade", "node", "card"|"piece", "price"|"points"}],
 "summary": RunSession.summary()}
```
`stats.json` in the same folder: `{"runs", "boss_wins", "runs_per_piece_set", "boss_wins_per_piece_set", "match_wins_per_piece_set", "match_losses_per_piece_set", "match_wins_per_deck_size"}`. `run_file_path`, `run_data()`, `load_stats()`, `stats_path()` for reading.

## MatchAI

`scripts/core/ai/match_ai.gd` — plays one side of a `ChessMatch` (D41, D9, D42). Pure logic (`RefCounted`); never mutates the match it is given (it searches on `clone()`s). Deterministic for a given match and RNG seed. The sim bot (`tools/sim/`) uses it for both sides.

```gdscript
var ai := MatchAI.new(ChessMatch.OPPONENT, setup["opponent"]["search_depth"], setup["opponent"]["random_chance"], rng, setup["opponent"]["deck"])
while not game.is_over() and game.current_side() == ChessMatch.OPPONENT:
	var action := ai.choose_action(game)        # decide (a few ms)
	var events := MatchAI.apply_action(game, action)   # perform it; animate the events
```

| call | returns |
|---|---|
| `MatchAI.new(side, search_depth, random_chance, rng: RandomNumberGenerator, deck: Array = [])` | the RNG is used for random plays and tie-breaks (share one per match or per sim) |
| `choose_action(match)` | `{"kind": "play", "card_index", "from", "to"}`, `{"kind": "redraw"}` or `{"kind": "end_turn"}` — always legal right now: a play is an entry of `legal_plays(side)`, redraw only when `can_redraw()`, end_turn only when no card is playable. Call it only on this side's turn of a running match (otherwise it `push_error`s and returns end_turn). |
| `MatchAI.apply_action(match, action)` (static) | the events of `play` / `redraw` / `end_turn` |
| `evaluate(match)` | float, static score of the position from this side's view |
| `side`, `search_depth`, `random_chance` | read-only vars |

Behaviour:
- One card per call (the caller loops until the turn ends). Never ends the turn while a card is playable. When nothing is playable it redraws only if `can_redraw()` and the energy left after the redraw still pays for the cheapest card in its deck (a 0-cost card counts); otherwise it ends the turn. Pass the side's match deck as the optional 5th constructor argument `deck` (e.g. `setup["opponent"]["deck"]`); without it the AI judges by the cheapest card in its hand.
- With probability `random_chance`: a uniformly random entry of `legal_plays`.
- Otherwise every distinct (from, to) is simulated once with the cheapest card that can make it (a specific card before Move on ties), via `clone()` + `play()` — so Fire, shields, Powder Keg, holes, promotion and wins are exactly the engine's.
- Every depth: value = `evaluate` after its play − `energy_weight` × card cost − **king safety** (below). Ties within `tie_epsilon` are broken with the RNG.
- Depth 2 adds:
  - **Follow-up win**: if, still on its own turn, a card left in hand can then take the enemy king or a piece that reaches `target_score`, the play is worth `follow_up_win_factor` × `win_score` (a sure win: the enemy can't answer in between). This lets it play 2-card combos.
  - **Best single reply**: subtracts the opponent's best reply, where a reply is **any** raw piece move (`piece_moves`, the AI can't see the hand); only captures count, computed statically (shield, Fire/Trophy Case points, the opponent's Powder Keg blast, a pawn capture that promotes, D13 king/score wins).
- King safety (D4: the enemy plays several cards per turn, which one reply can't see), on a static board:
  - `king_threat_penalty` if some enemy piece can capture the king within min(`threat_horizon_moves`, enemy max energy ÷ cheapest card cost) raw moves (1: it already attacks; 2: one move onto a square attacking it — capturing a blocker included — then the capture; a pawn reaching the last rank attacks as a queen).
  - The same for its `threat_targets` pieces (queen, rook) at `piece_threat_factor` × (`score_weight` + `material_weight`) × value. Shielded pieces are ignored.
  - `king_exposure_weight` per square a queen standing on the king's square could reach (open lines around the king).
- `evaluate`: ±`win_score` once the match is over; else `score_weight` × score difference + per side (own − enemy): `material_weight` × `value()`, `shield_bonus` per active shield, `advance_weight` × ranks advanced (non-king pieces), and a burning piece costs `burn_pending_factor` × (`score_weight` + `material_weight`) × its value (it will burn out into enemy points).
- Weights: `config/ai.json` (`move_delay_seconds` is for the UI only).
- Speed (debug build, measured by the sim and `test_depth_two_decisions_are_fast`): depth 2 ≈ 2 ms average, ≈ 10–13 ms worst case per decision over 300 simulated runs.

### Sim bot

`/Applications/Godot.app/Contents/MacOS/Godot --headless -s tools/sim/run_sim.gd -- --runs=100 --seed=1` — plays full runs with random-but-valid run choices (piece set incl. Fire once unlocked, artifacts, map, rewards, shop buys/removes, coaching, default or random rosters) and `MatchAI` on both sides (the player bot cycles depth 2 / depth 2 + 10 % random / depth 1 + 20 % random). Writes only under `user://sim/cli/` (wiped at start; meta persists across the runs of one invocation). Checks every action (no error results, AI contract, match invariants incl. one king per side, no unpromoted pawn on the far rank and scores equal to the summed `score` events, termination, no engine/script errors), every run reaching RUN_END within a step cap, and the run logs. Prints a summary; exit code 0 only with zero failures. The driver is `tools/sim/sim_driver.gd` (also used by `tests/integration/test_sim_smoke.gd`).
