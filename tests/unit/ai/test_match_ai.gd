extends GutTest
## MatchAI: legal-action contract, tactics, depth-2 safety, determinism, strength and speed.

const H := preload("res://tests/unit/match/match_helper.gd")
const SimDriver := preload("res://tools/sim/sim_driver.gd")
const P := ChessMatch.PLAYER
const O := ChessMatch.OPPONENT
const FUZZ_MATCHES := 40
const MAX_ACTIONS_PER_MATCH := 5000
const TOURNAMENT_MATCHES := 30
const DECISION_BUDGET_MSEC := 30.0
const ARTIFACT_COMBOS: Array = [[], ["extra_energy"], ["capture_bonus"], ["holes"], ["exploding"], ["exploding", "capture_bonus"]]
const PIECE_UPGRADES: Array = ["", "range", "deploy", "shield"]
const CARD_TYPES: Array = ["pawn", "knight", "bishop", "rook", "queen", "move"]
const CARD_UPGRADES: Array = ["", "cheaper", "hold", "book"]
const AI_CONFIGS: Array = [[1, 0.0], [1, 0.3], [2, 0.0], [2, 0.15], [2, 1.0]]


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A random full position: either set, upgrades, shields, artifacts, random decks.
func _random_setup(seed_value: int) -> Dictionary:
	var rng := _rng(seed_value)
	var piece_set := "fire" if rng.randf() < 0.4 else "standard"
	var back_rank := ["rook", "knight", "bishop", "king", "queen", "bishop"]
	var player_roster := []
	var opponent_roster := [H.piece("king", Vector2i(2, 5)), H.piece("queen", Vector2i(3, 5)), H.piece("knight", Vector2i(1, 5))]
	for x in 6:
		player_roster.append(H.piece(back_rank[x], Vector2i(x, 0), piece_set, PIECE_UPGRADES[rng.randi_range(0, PIECE_UPGRADES.size() - 1)]))
		if rng.randf() < 0.7:
			player_roster.append(H.piece("pawn", Vector2i(x, 1), piece_set, PIECE_UPGRADES[rng.randi_range(0, PIECE_UPGRADES.size() - 1)]))
		if rng.randf() < 0.7:
			opponent_roster.append(H.piece("pawn", Vector2i(x, 4)))
	var player_deck := []
	for _i in rng.randi_range(4, 12):
		player_deck.append(CARD_TYPES[rng.randi_range(0, CARD_TYPES.size() - 1)] + ":" + CARD_UPGRADES[rng.randi_range(0, CARD_UPGRADES.size() - 1)])
	return H.setup(player_roster, opponent_roster, player_deck, ["pawn", "knight", "queen", "move", "move"], {
		"seed": seed_value,
		"player_artifacts": ARTIFACT_COMBOS[rng.randi_range(0, ARTIFACT_COMBOS.size() - 1)],
		"opponent_artifacts": ARTIFACT_COMBOS[rng.randi_range(0, ARTIFACT_COMBOS.size() - 1)],
	})


## The side that must act now: the checked side while an escape is pending (D57).
func _acting_side(game: ChessMatch) -> int:
	return game.pending_escape_side() if game.pending_escape_side() != -1 else game.current_side()


func _ai_pair(seed_value: int, player_config: Array, opponent_config: Array) -> Array[MatchAI]:
	var rng := _rng(seed_value)
	return [MatchAI.new(P, player_config[0], player_config[1], rng), MatchAI.new(O, opponent_config[0], opponent_config[1], rng)]


## Plays to the end; returns the action list. Fails the test on any contract break.
## Escape answers (escape / decline_escape) are part of the list.
func _play_out(game: ChessMatch, ais: Array[MatchAI], context: String) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	while not game.is_over() and actions.size() < MAX_ACTIONS_PER_MATCH:
		var action := ais[_acting_side(game)].choose_action(game)
		var contract_error := SimDriver.action_error(game, action)
		if contract_error != "":
			fail_test("%s: %s" % [context, contract_error])
			return actions
		var events := MatchAI.apply_action(game, action)
		if events[0]["type"] == "error":
			fail_test("%s: engine rejected %s" % [context, action])
			return actions
		actions.append(action)
	return actions


func test_actions_are_always_legal_over_random_positions() -> void:
	var decisions := 0
	var escape_answers := 0
	for seed_value in range(1, FUZZ_MATCHES + 1):
		var game := ChessMatch.new(_random_setup(seed_value))
		var configs: Array = [AI_CONFIGS[seed_value % AI_CONFIGS.size()], AI_CONFIGS[(seed_value / AI_CONFIGS.size()) % AI_CONFIGS.size()]]
		var actions := _play_out(game, _ai_pair(seed_value, configs[0], configs[1]), "seed %d" % seed_value)
		decisions += actions.size()
		escape_answers += actions.filter(func(action: Dictionary) -> bool: return action["kind"] in ["escape", "decline_escape"]).size()
		assert_true(game.is_over(), "seed %d terminates" % seed_value)
	assert_gt(decisions, 300)
	assert_gt(escape_answers, 0, "the fuzz exercises check escapes")
	gut.p("legal fuzz: %d decisions, %d escape answers" % [decisions, escape_answers])


func test_random_chance_one_is_still_legal() -> void:
	for seed_value in range(100, 110):
		var game := ChessMatch.new(_random_setup(seed_value))
		_play_out(game, _ai_pair(seed_value, [2, 1.0], [1, 1.0]), "random seed %d" % seed_value)
		assert_true(game.is_over())


func test_choose_action_never_mutates_the_match() -> void:
	for seed_value in [5, 6]:
		var game := ChessMatch.new(_random_setup(seed_value))
		var ais := _ai_pair(seed_value, [2, 0.0], [2, 0.0])
		while not game.is_over():
			var before := H.snapshot(game)
			var action := ais[_acting_side(game)].choose_action(game)
			assert_eq(H.snapshot(game), before, "seed %d" % seed_value)
			MatchAI.apply_action(game, action)


func test_takes_a_free_king_capture() -> void:
	for depth in [1, 2]:
		var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(0, 0)), H.piece("queen", Vector2i(3, 0))],
			[H.piece("king", Vector2i(0, 5)), H.piece("rook", Vector2i(3, 4))])
		var action := MatchAI.new(P, depth, 0.0, _rng(1)).choose_action(game)
		assert_eq([action["from"], action["to"]], [Vector2i(0, 0), Vector2i(0, 5)], "depth %d" % depth)


func test_takes_the_capture_that_wins_the_score_race() -> void:
	for depth in [1, 2]:
		var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(0, 0)), H.piece("knight", Vector2i(1, 0))],
			[H.piece("king", Vector2i(5, 5)), H.piece("rook", Vector2i(0, 3)), H.piece("rook", Vector2i(2, 3)), H.piece("knight", Vector2i(2, 2)), H.piece("queen", Vector2i(2, 5))])
		H.play_type(game, "move", Vector2i(0, 0), Vector2i(0, 3))
		assert_eq(game.score(P), 5)
		var action := MatchAI.new(P, depth, 0.0, _rng(1)).choose_action(game)
		assert_eq([action["from"], action["to"]], [Vector2i(0, 3), Vector2i(2, 3)], "depth %d" % depth)
		MatchAI.apply_action(game, action)
		assert_eq(game.result()["reason"], "score")


func test_depth_two_does_not_hang_the_queen() -> void:
	var player := [H.piece("king", Vector2i(5, 0)), H.piece("queen", Vector2i(0, 0))]
	var opponent := [H.piece("king", Vector2i(4, 5)), H.piece("pawn", Vector2i(0, 4)), H.piece("rook", Vector2i(0, 5))]
	var game := H.make(player, opponent)
	var action := MatchAI.new(P, 2, 0.0, _rng(1)).choose_action(game)
	assert_ne(action["to"], Vector2i(0, 4))
	MatchAI.apply_action(game, action)
	assert_false(_enemy_can_capture(game, P, "queen"), "queen is safe after %s" % action)


func test_depth_two_does_not_hang_the_king() -> void:
	var game := H.make([H.piece("king", Vector2i(2, 0)), H.piece("knight", Vector2i(5, 0))],
		[H.piece("king", Vector2i(5, 5)), H.piece("pawn", Vector2i(2, 1)), H.piece("rook", Vector2i(2, 5))])
	var action := MatchAI.new(P, 2, 0.0, _rng(1)).choose_action(game)
	assert_ne(action["to"], Vector2i(2, 1), "king must not take the defended pawn")
	MatchAI.apply_action(game, action)
	assert_false(_enemy_can_capture(game, P, "king"), "king is safe after %s" % action)


## Moving the bishop off file 0 would let the rook reach (0, 4) and take the king
## next turn (2 enemy moves); the pawn guards rank 0. Only the knight's (3, 1) is safe.
func test_depth_two_keeps_a_two_move_threat_off_the_king() -> void:
	var game := H.make([H.piece("king", Vector2i(0, 0)), H.piece("pawn", Vector2i(1, 0)), H.piece("bishop", Vector2i(0, 2)), H.piece("knight", Vector2i(5, 0))],
		[H.piece("king", Vector2i(2, 5)), H.piece("rook", Vector2i(4, 4))])
	var action := MatchAI.new(P, 2, 0.0, _rng(1)).choose_action(game)
	assert_eq([action["from"], action["to"]], [Vector2i(5, 0), Vector2i(3, 1)])


## The boxed-in king has no escape square (D57), so knight + knight takes it this turn.
func test_sets_up_a_king_capture_the_enemy_cannot_escape() -> void:
	var game := H.make([H.piece("king", Vector2i(0, 0)), H.piece("knight", Vector2i(2, 2))],
		[H.piece("king", Vector2i(5, 5)), H.piece("pawn", Vector2i(4, 5)), H.piece("pawn", Vector2i(4, 4)), H.piece("pawn", Vector2i(5, 4))])
	var ai := MatchAI.new(P, 2, 0.0, _rng(1))
	MatchAI.apply_action(game, ai.choose_action(game))
	assert_false(game.is_over())
	assert_eq(game.pending_escape_side(), -1, "no escape square for the boxed king")
	MatchAI.apply_action(game, ai.choose_action(game))
	assert_eq(game.result().get("reason", ""), "king", "two cards in one turn take the king")


## Giving check is not a won king any more: the enemy escapes first (D57).
func test_search_does_not_count_an_escapable_check_as_a_win() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(0, 0))],
		[H.piece("king", Vector2i(3, 5)), H.piece("pawn", Vector2i(5, 4))])
	var ai := MatchAI.new(P, 2, 0.0, _rng(1))
	var check_play := {"card_index": 0, "from": Vector2i(0, 0), "to": Vector2i(0, 5)}
	var probe := game.clone()
	probe.play(0, Vector2i(0, 0), Vector2i(0, 5))
	assert_eq(probe.pending_escape_side(), O, "the move gives an escapable check")
	assert_lt(ai._play_value(game, check_play), float(GameConfig.value("ai", "win_score")) * 0.1)


## P's rook checks the opponent's king along rank 5 (after `quiet_moves_first`
## Move cards spent on pawns); the AI under test plays O and must answer.
func _checked_opponent(king_upgrade: String, quiet_moves_first: int) -> ChessMatch:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(0, 0)), H.piece("pawn", Vector2i(5, 1)), H.piece("pawn", Vector2i(4, 1))],
		[H.piece("king", Vector2i(2, 5), "standard", king_upgrade), H.piece("pawn", Vector2i(4, 4))])
	var quiet: Array[Array] = [[Vector2i(5, 1), Vector2i(5, 2)], [Vector2i(4, 1), Vector2i(4, 2)]]
	for i in quiet_moves_first:
		game.play(0, quiet[i][0], quiet[i][1])
	game.play(0, Vector2i(0, 0), Vector2i(0, 5))
	assert_eq(game.pending_escape_side(), O, "rook on (0, 5) checks the king on (2, 5)")
	return game


func test_escapes_a_real_check() -> void:
	var game := _checked_opponent("", 0)
	var action := MatchAI.new(O, 2, 0.0, _rng(1)).choose_action(game)
	assert_eq(action["kind"], "escape")
	assert_true(game.escape_squares().has(action["to"]))
	assert_eq(SimDriver.action_error(game, action), "")
	var events := MatchAI.apply_action(game, action)
	assert_eq(events[0]["type"], "escape")
	assert_false(game.in_check(O))


func test_declines_when_the_shield_would_hold() -> void:
	var game := _checked_opponent("shield", 0)
	var action := MatchAI.new(O, 2, 0.0, _rng(1)).choose_action(game)
	assert_eq(action, {"kind": "decline_escape"})
	assert_eq(MatchAI.apply_action(game, action)[0]["type"], "escape_declined")


## Review repro: a checker with 0 energy left can still hold a 0-cost Cheaper Move.
func test_escapes_even_when_the_checker_has_no_energy_left() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(0, 0)), H.piece("pawn", Vector2i(4, 1))],
		[H.piece("king", Vector2i(2, 5)), H.piece("pawn", Vector2i(4, 4))],
		["rook", "pawn", "move:cheaper", "move:cheaper", "move:cheaper"])
	H.play_type(game, "pawn", Vector2i(4, 1), Vector2i(4, 2))
	H.play_type(game, "rook", Vector2i(0, 0), Vector2i(0, 5))
	assert_eq(game.energy(P), 0)
	assert_eq(game.pending_escape_side(), O)
	var declined := game.clone()
	declined.decline_escape()
	H.play_type(declined, "move", Vector2i(0, 5), Vector2i(2, 5))
	assert_eq(declined.result().get("reason", ""), "king", "declining loses to the 0-cost Move")
	var action := MatchAI.new(O, 1, 0.0, _rng(1)).choose_action(game)
	assert_eq(action["kind"], "escape")
	assert_eq(SimDriver.action_error(game, action), "")


func test_escape_answers_ignore_random_chance_and_whose_turn_it_is() -> void:
	var game := _checked_opponent("", 0)
	assert_eq(game.current_side(), P)
	var action := MatchAI.new(O, 1, 1.0, _rng(3)).choose_action(game)
	assert_true(action["kind"] in ["escape", "decline_escape"])
	assert_eq(SimDriver.action_error(game, action), "")


## A pawn capture onto its last rank also makes a queen: that reply costs more.
func test_reply_loss_counts_a_promoting_capture() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 1)), H.piece("knight", Vector2i(1, 0)), H.piece("knight", Vector2i(4, 2))],
		[H.piece("king", Vector2i(0, 5)), H.piece("pawn", Vector2i(2, 1)), H.piece("pawn", Vector2i(5, 3))])
	var ai := MatchAI.new(P, 2, 0.0, _rng(1))
	var promoting: float = ai._reply_loss(game, game.piece_at(Vector2i(2, 1)), game.piece_at(Vector2i(1, 0)))
	var plain: float = ai._reply_loss(game, game.piece_at(Vector2i(5, 3)), game.piece_at(Vector2i(4, 2)))
	var queen_gain := float(GameConfig.piece_value("queen") - GameConfig.piece_value("pawn")) * float(GameConfig.value("ai", "material_weight"))
	assert_almost_eq(promoting - plain, queen_gain, 0.001)


## foresight (D68): a player pawn is worth 1 + penalty to the opponent. At
## target - 2 that capture wins, so both shortcut scorers must count the penalty.
func test_foresight_penalty_counts_in_shortcut_scoring() -> void:
	var win_score := float(GameConfig.value("ai", "win_score"))
	var take_pawn := [Vector2i(0, 2), Vector2i(0, 1)]
	for has_ball in [false, true]:
		var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(0, 2)), H.piece("pawn", Vector2i(0, 1)),
			H.piece("pawn", Vector2i(1, 2)), H.piece("bishop", Vector2i(3, 2))],
			[H.piece("king", Vector2i(5, 5)), H.piece("rook", Vector2i(0, 5)), H.piece("knight", Vector2i(2, 4))],
			H.FIVE_MOVES, H.FIVE_MOVES, {"player_artifacts": ["foresight"] if has_ball else []})
		game.end_turn()
		game.play(0, Vector2i(0, 5), Vector2i(0, 2))
		game.play(0, Vector2i(2, 4), Vector2i(1, 2) if has_ball else Vector2i(3, 2))
		game.end_turn()
		game.end_turn()
		assert_eq(game.score(O), game.target_score() - 2, "rook + pawn with penalties, or rook + bishop")
		var opponent_ai := MatchAI.new(O, 2, 0.0, _rng(1))
		assert_eq(opponent_ai._has_winning_follow_up(game, opponent_ai._board_copy(game)), has_ball, "ball %s" % has_ball)
		var player_ai := MatchAI.new(P, 2, 0.0, _rng(1))
		var loss: float = player_ai._reply_loss(game, game.piece_at(take_pawn[0]), game.piece_at(take_pawn[1]))
		if has_ball:
			assert_eq(loss, win_score, "the reply loses the match")
			var action := opponent_ai.choose_action(game)
			assert_eq([action["from"], action["to"]], take_pawn)
			MatchAI.apply_action(game, action)
			assert_eq(game.result()["reason"], "score")
		else:
			assert_lt(loss, win_score)


## Knight takes the rook on (3, 4) and the pawn recaptures: a good trade, unless
## the enemy's Powder Keg recapture also blows up the king next to (3, 4).
func test_depth_two_sees_an_enemy_explosion() -> void:
	var take_rook := [Vector2i(1, 3), Vector2i(3, 4)]
	for has_keg in [false, true]:
		var game := H.make([H.piece("king", Vector2i(4, 3)), H.piece("knight", Vector2i(1, 3))],
			[H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(3, 4)), H.piece("pawn", Vector2i(2, 5))],
			H.FIVE_MOVES, H.FIVE_MOVES, {"opponent_artifacts": ["exploding"] if has_keg else []})
		var action := MatchAI.new(P, 2, 0.0, _rng(1)).choose_action(game)
		if has_keg:
			assert_ne([action["from"], action["to"]], take_rook, "keg: the recapture would kill the king")
		else:
			assert_eq([action["from"], action["to"]], take_rook, "no keg: winning trade")


func test_prefers_the_cheaper_card_for_the_same_move() -> void:
	var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(0, 0))],
		[H.piece("king", Vector2i(0, 5)), H.piece("pawn", Vector2i(5, 5))], ["rook", "rook:cheaper", "pawn", "pawn", "pawn"])
	var action := MatchAI.new(P, 1, 0.0, _rng(1)).choose_action(game)
	assert_eq(game.hand(P)[action["card_index"]].upgrade, "cheaper")


## Only a king on the board, so no card in hand is playable.
func _turn_kinds(deck_specs: Array, ai_deck: Array) -> Array[String]:
	var game := H.make([H.piece("king", Vector2i(5, 0))], [H.piece("king", Vector2i(0, 5))], deck_specs)
	var ai := MatchAI.new(P, 2, 0.0, _rng(1), ai_deck)
	var kinds: Array[String] = []
	while game.current_side() == P:
		var action := ai.choose_action(game)
		kinds.append(action["kind"])
		MatchAI.apply_action(game, action)
	return kinds


func test_redraws_only_while_the_cheapest_deck_card_stays_affordable() -> void:
	var rooks := ["rook", "rook", "rook", "rook", "rook", "rook"]
	assert_eq(_turn_kinds(rooks, H.cards(rooks)), ["redraw", "end_turn"] as Array[String], "3 -> 2 energy still pays a rook, 1 does not")
	var with_free_card := rooks + ["pawn:cheaper"]
	assert_eq(_turn_kinds(with_free_card, H.cards(with_free_card)), ["redraw", "redraw", "redraw", "end_turn"] as Array[String], "a 0-cost card keeps redraws worthwhile")
	var queens := ["queen", "queen", "queen", "queen", "queen", "queen"]
	assert_eq(_turn_kinds(queens, H.cards(queens)), ["end_turn"] as Array[String], "after a redraw a queen is unaffordable")


func test_without_a_deck_the_redraw_rule_uses_the_hand() -> void:
	var rooks := ["rook", "rook", "rook", "rook", "rook", "rook"]
	assert_eq(_turn_kinds(rooks, []), ["redraw", "end_turn"] as Array[String])


func test_never_ends_the_turn_with_a_playable_card() -> void:
	for seed_value in range(200, 215):
		var game := ChessMatch.new(_random_setup(seed_value))
		var ais := _ai_pair(seed_value, [2, 0.0], [1, 0.3])
		while not game.is_over():
			var action := ais[_acting_side(game)].choose_action(game)
			if action["kind"] == "end_turn":
				assert_true(game.legal_plays(game.current_side()).is_empty(), "seed %d" % seed_value)
			MatchAI.apply_action(game, action)


func test_same_seed_gives_the_same_decisions() -> void:
	for seed_value in [7, 8, 9]:
		var first := _play_out(ChessMatch.new(_random_setup(seed_value)), _ai_pair(seed_value, [2, 0.15], [1, 0.3]), "first")
		var second := _play_out(ChessMatch.new(_random_setup(seed_value)), _ai_pair(seed_value, [2, 0.15], [1, 0.3]), "second")
		assert_eq(second, first, "seed %d" % seed_value)


## The same fixed player bot plays the Easy and the Boss AI config on one mirror position.
func test_easy_config_loses_more_than_boss_config() -> void:
	var easy: Dictionary = GameConfig.data("opponents")["easy"]
	var boss: Dictionary = GameConfig.data("opponents")["boss"]
	var easy_losses := _tournament_losses([int(easy["search_depth"]), float(easy["random_chance"])])
	var boss_losses := _tournament_losses([int(boss["search_depth"]), float(boss["random_chance"])])
	gut.p("tournament: easy config lost %d/%d, boss config lost %d/%d" % [easy_losses, TOURNAMENT_MATCHES, boss_losses, TOURNAMENT_MATCHES])
	assert_gt(easy_losses, boss_losses)


func _tournament_losses(opponent_config: Array) -> int:
	var losses := 0
	for seed_value in range(1, TOURNAMENT_MATCHES + 1):
		var game := ChessMatch.new(_mirror_setup(seed_value))
		_play_out(game, _ai_pair(seed_value, [1, 0.2], opponent_config), "tournament seed %d" % seed_value)
		if game.result().get("winner", P) == P:
			losses += 1
	return losses


## Closed mirror position: a full pawn rank in front of king, knight and bishop.
func _mirror_setup(seed_value: int) -> Dictionary:
	var player := [H.piece("king", Vector2i(2, 0)), H.piece("knight", Vector2i(1, 0)), H.piece("bishop", Vector2i(3, 0))]
	var opponent := [H.piece("king", Vector2i(2, 5)), H.piece("knight", Vector2i(1, 5)), H.piece("bishop", Vector2i(3, 5))]
	for x in 6:
		player.append(H.piece("pawn", Vector2i(x, 1)))
		opponent.append(H.piece("pawn", Vector2i(x, 4)))
	var deck := ["pawn", "knight", "bishop", "move"]
	return H.setup(player, opponent, deck, deck, {"seed": seed_value})


func test_depth_two_decisions_are_fast() -> void:
	var total_usec := 0
	var max_usec := 0
	var decisions := 0
	for seed_value in range(300, 310):
		var game := ChessMatch.new(_random_setup(seed_value))
		var ais := _ai_pair(seed_value, [2, 0.0], [2, 0.0])
		while not game.is_over():
			var started := Time.get_ticks_usec()
			var action := ais[_acting_side(game)].choose_action(game)
			var elapsed := Time.get_ticks_usec() - started
			total_usec += elapsed
			max_usec = maxi(max_usec, elapsed)
			decisions += 1
			MatchAI.apply_action(game, action)
	var average_msec := total_usec / 1000.0 / decisions
	gut.p("depth 2 timing: %d decisions, avg %.2f ms, max %.2f ms" % [decisions, average_msec, max_usec / 1000.0])
	assert_lt(average_msec, DECISION_BUDGET_MSEC / 5.0)
	assert_lt(max_usec / 1000.0, DECISION_BUDGET_MSEC)


func _enemy_can_capture(game: ChessMatch, victim_side: int, piece_type: String) -> bool:
	for attacker in game.pieces(1 - victim_side):
		for to in game.piece_moves(attacker.square):
			var victim := game.piece_at(to)
			if victim != null and victim.type == piece_type:
				return true
	return false
