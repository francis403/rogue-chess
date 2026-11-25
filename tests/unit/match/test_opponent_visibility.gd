extends GutTest
## Opponent card visibility: hidden cards, Scout, foresight (D63-D70,
## docs/specs/opponent-card-visibility.md R1-R6).

const H := preload("res://tests/unit/match/match_helper.gd")
const P := ChessMatch.PLAYER
const O := ChessMatch.OPPONENT
const PLAYER_KING := Vector2i(0, 0)
const OPPONENT_KING := Vector2i(5, 5)
## Ten distinct-enough cards: each opponent hand is drawn from fresh cards for two turns.
const OPPONENT_DECK: Array = ["pawn", "knight", "bishop", "rook", "queen", "move", "pawn", "knight", "bishop", "move"]
const SCOUT_AND_MOVES: Array = ["scout", "move", "move", "move", "move"]


func _hand_size() -> int:
	return int(GameConfig.value("match", "hand_size"))


func _default_hidden() -> int:
	return int(GameConfig.value("match", "opponent_hidden_cards"))


func _foresight_config() -> Dictionary:
	return GameConfig.data("artifacts")["artifacts"]["foresight"]


func _game(hidden_cards: int, player_deck: Array = SCOUT_AND_MOVES, options: Dictionary = {},
		opponent_deck: Array = OPPONENT_DECK) -> ChessMatch:
	var setup := H.setup([H.piece("king", PLAYER_KING)], [H.piece("king", OPPONENT_KING)], player_deck, opponent_deck, options)
	setup["opponent"]["hidden_cards"] = hidden_cards
	return ChessMatch.new(setup)


func _uids(cards: Array[CardData]) -> Array:
	return cards.map(func(card: CardData) -> int: return card.uid)


func _hidden_uids(game: ChessMatch) -> Array:
	var visible := _uids(game.visible_opponent_hand())
	return _uids(game.hand(O)).filter(func(uid: int) -> bool: return not visible.has(uid))


## uids of the last `count` cards the opponent drew in `events`.
func _last_drawn(events: Array[Dictionary], count: int) -> Array:
	var draws := H.side_events(events, "draw", O)
	return draws.slice(draws.size() - count).map(func(event: Dictionary) -> int: return event["card_uid"])


## The visible cards are the first ones in hand order; the hidden ones are the last drawn.
func _assert_hidden(game: ChessMatch, draw_events: Array[Dictionary], expected: int, label: String = "") -> void:
	var hand := game.hand(O)
	assert_eq(game.hidden_card_count(), expected, label)
	assert_eq(_uids(game.visible_opponent_hand()), _uids(hand.slice(0, hand.size() - expected)), label)
	assert_eq(_hidden_uids(game), _last_drawn(draw_events, expected), label)


func test_default_hides_the_last_card_drawn() -> void:
	var game := H.make([H.piece("king", PLAYER_KING)], [H.piece("king", OPPONENT_KING)], H.FIVE_MOVES, OPPONENT_DECK)
	assert_eq(_default_hidden(), 1)
	assert_eq(game.current_side(), P)
	assert_eq(game.hand(O).size(), _hand_size())
	_assert_hidden(game, game.initial_events(), _default_hidden(), "no hidden_cards key: match.json default")
	assert_eq(game.visible_opponent_hand().size() + game.hidden_card_count(), game.hand(O).size())


func test_opponent_draw_events_never_name_the_card() -> void:
	var game := _game(0)
	var events := game.initial_events()
	assert_eq(H.side_events(events, "draw", O).size(), _hand_size())
	for event in H.side_events(events, "draw", O):
		assert_eq(event.keys(), ["type", "side", "card_uid"], "even with nothing hidden")
	assert_eq(H.side_events(events, "draw", P).map(func(event: Dictionary) -> String: return event["card_type"]),
		H.hand_types(game, P), "the player's draw events still name the card")
	game.end_turn()
	events = game.end_turn()
	assert_eq(H.side_events(events, "draw", O).size(), _hand_size())
	for event in H.side_events(events, "draw", O):
		assert_false(event.has("card_type"))


func test_hidden_cards_is_clamped_to_the_hand() -> void:
	for case in [[0, 0], [3, 3], [_hand_size(), _hand_size()], [9, _hand_size()], [-2, 0]]:
		var game := _game(case[0])
		var label := "hidden_cards %d" % case[0]
		_assert_hidden(game, game.initial_events(), case[1], label)
		assert_eq(H.events_of(game.initial_events(), "error"), [] as Array[Dictionary], label)


func test_small_opponent_deck_hides_at_most_its_hand() -> void:
	for case in [[2, 2], [9, 3]]:
		var game := _game(case[0], SCOUT_AND_MOVES, {}, ["pawn", "knight", "bishop"])
		assert_eq(game.hand(O).size(), 3)
		_assert_hidden(game, game.initial_events(), case[1], "hidden_cards %d" % case[0])


func test_opponent_draws_its_next_hand_at_the_end_of_its_turn() -> void:
	var game := _game(3)
	game.reveal(H.card_index(game, "scout"))
	assert_eq(game.hidden_card_count(), 1)
	var old_hand := _uids(game.hand(O))
	var events := game.end_turn()
	assert_eq(H.side_events(events, "draw", O), [] as Array[Dictionary], "its hand is already full at its turn start")
	assert_eq(game.hidden_card_count(), 1)
	events = game.end_turn()
	assert_eq(game.current_side(), P)
	var draws := H.side_events(events, "draw", O)
	assert_eq(draws.size(), _hand_size())
	assert_lt(events.find(draws[0]), events.find(H.events_of(events, "turn_start")[0]), "drawn before the player's turn starts")
	for uid in _uids(game.hand(O)):
		assert_false(old_hand.has(uid), "a new hand")
	_assert_hidden(game, events, 3, "earlier reveals are gone")


func test_opponent_does_not_draw_when_its_turn_ends_the_match() -> void:
	var game := _game(1)
	var events: Array[Dictionary] = []
	while not game.is_over():
		events = game.end_turn()
	assert_eq(game.result()["reason"], "turn_limit")
	assert_eq(H.side_events(events, "draw", O), [] as Array[Dictionary])
	assert_eq(game.hand(O).size(), 0)
	assert_eq(game.hidden_card_count(), 0)


func test_opponent_redraw_hides_cards_again() -> void:
	var game := _game(2, SCOUT_AND_MOVES, {}, ["pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn"])
	game.reveal(H.card_index(game, "scout"))
	assert_eq(game.hidden_card_count(), 0)
	game.end_turn()
	assert_true(game.can_redraw(), "no opponent pawn for its pawn cards")
	var events := game.redraw()
	_assert_hidden(game, events, 2)


func test_playing_an_opponent_card_never_hides_another() -> void:
	var game := _game(2, H.FIVE_MOVES, {}, H.FIVE_MOVES + H.FIVE_MOVES)
	game.end_turn()
	var visible := _uids(game.visible_opponent_hand())
	var hidden := _hidden_uids(game)
	game.play(0, OPPONENT_KING, Vector2i(5, 4))
	assert_eq(_uids(game.visible_opponent_hand()), visible.slice(1), "a visible card played")
	assert_eq(_hidden_uids(game), hidden)
	game.play(game.hand(O).size() - 1, Vector2i(5, 4), Vector2i(5, 3))
	assert_eq(_uids(game.visible_opponent_hand()), visible.slice(1), "a hidden card played")
	assert_eq(_hidden_uids(game), hidden.slice(0, 1))


func test_scout_reveals_two_hidden_cards_in_hand_order() -> void:
	var game := _game(3)
	var scout_index := H.card_index(game, "scout")
	var scout: CardData = game.hand(P)[scout_index]
	var opponent_hand := _uids(game.hand(O))
	var cost := int(GameConfig.data("cards")["scout"]["cost"])
	var events := game.reveal(scout_index)
	assert_eq(events, [
		{"type": "card_played", "side": P, "card_index": scout_index, "card_uid": scout.uid, "card_type": "scout",
			"cost": cost, "energy": game.max_energy(P) - cost},
		{"type": "reveal", "side": P, "count": 2, "hidden": 1},
	] as Array[Dictionary])
	assert_eq(game.energy(P), game.max_energy(P) - cost)
	assert_eq(_uids(game.visible_opponent_hand()), opponent_hand.slice(0, 4))
	assert_eq(_uids(game.hand(O)), opponent_hand, "the opponent's hand is unchanged")
	assert_eq(H.card_index(game, "scout"), -1)
	assert_eq(game.discard_size(P), 1)


func test_scout_reveals_only_what_is_hidden() -> void:
	var game := _game(1)
	var events := game.reveal(H.card_index(game, "scout"))
	assert_eq(H.events_of(events, "reveal"), [{"type": "reveal", "side": P, "count": 1, "hidden": 0}] as Array[Dictionary])
	assert_eq(_uids(game.visible_opponent_hand()), _uids(game.hand(O)))


func test_two_scouts_reveal_four_hidden_cards() -> void:
	var game := _game(4, ["scout", "scout", "move", "move", "move"])
	game.reveal(H.card_index(game, "scout"))
	assert_eq(game.hidden_card_count(), 2)
	game.reveal(H.card_index(game, "scout"))
	assert_eq(game.hidden_card_count(), 0)
	assert_eq(_uids(game.visible_opponent_hand()), _uids(game.hand(O)))


func test_scout_is_refused_when_nothing_is_hidden() -> void:
	var game := _game(0)
	var scout_index := H.card_index(game, "scout")
	assert_false(game.can_reveal(scout_index))
	assert_false(game.is_card_playable(scout_index))
	var before := H.snapshot(game)
	assert_eq(game.reveal(scout_index), [{"type": "error", "reason": "nothing_hidden"}] as Array[Dictionary])
	assert_eq(H.snapshot(game), before)


func test_scout_needs_energy() -> void:
	var game := _game(1)
	for y in [1, 2, 3]:
		H.play_type(game, "move", Vector2i(0, y - 1), Vector2i(0, y))
	assert_eq(game.energy(P), 0)
	var scout_index := H.card_index(game, "scout")
	assert_false(game.can_reveal(scout_index))
	var before := H.snapshot(game)
	assert_eq(game.reveal(scout_index)[0]["reason"], "not_enough_energy")
	assert_eq(H.snapshot(game), before)
	assert_eq(game.hidden_card_count(), 1)


func test_cheaper_scout_costs_nothing() -> void:
	var game := _game(1, ["scout:cheaper", "move", "move", "move", "move"])
	var events := game.reveal(H.card_index(game, "scout"))
	assert_eq(events[0]["cost"], 0)
	assert_eq(game.energy(P), game.max_energy(P))
	assert_eq(game.hidden_card_count(), 0)


func test_scout_refuses_bad_cards_and_never_moves_a_piece() -> void:
	var game := _game(1)
	var scout_index := H.card_index(game, "scout")
	var before := H.snapshot(game)
	assert_eq(game.reveal(H.card_index(game, "move"))[0]["reason"], "wrong_card")
	assert_eq(game.reveal(-1)[0]["reason"], "bad_card_index")
	assert_eq(game.reveal(game.hand(P).size())[0]["reason"], "bad_card_index")
	assert_eq(game.play(scout_index, PLAYER_KING, Vector2i(0, 1))[0]["reason"], "wrong_card")
	assert_eq(game.targets(scout_index, PLAYER_KING), [] as Array[Vector2i])
	assert_eq(H.snapshot(game), before)
	assert_eq(game.hidden_card_count(), 1)


func test_scout_is_player_only() -> void:
	var game := _game(1, H.FIVE_MOVES, {}, SCOUT_AND_MOVES)
	game.end_turn()
	var scout_index := H.card_index(game, "scout")
	assert_false(game.can_reveal(scout_index))
	assert_false(game.is_card_playable(scout_index))
	var before := H.snapshot(game)
	assert_eq(game.reveal(scout_index)[0]["reason"], "player_only")
	assert_eq(H.snapshot(game), before)


func test_scout_is_refused_during_an_escape_and_after_the_match() -> void:
	var setup := H.setup([H.piece("king", PLAYER_KING), H.piece("rook", Vector2i(1, 0))], [H.piece("king", OPPONENT_KING)],
		SCOUT_AND_MOVES)
	var game := ChessMatch.new(setup)
	H.play_type(game, "move", Vector2i(1, 0), Vector2i(1, 5))
	assert_eq(game.pending_escape_side(), O)
	var scout_index := H.card_index(game, "scout")
	assert_false(game.can_reveal(scout_index))
	var before := H.snapshot(game)
	assert_eq(game.reveal(scout_index)[0]["reason"], "escape_pending")
	assert_eq(H.snapshot(game), before)
	game.decline_escape()
	H.play_type(game, "move", Vector2i(1, 5), OPPONENT_KING)
	assert_true(game.is_over())
	assert_eq(game.reveal(H.card_index(game, "scout"))[0]["reason"], "match_over")


func test_scout_is_never_a_legal_play_and_allows_redraw() -> void:
	for hidden in [0, 1]:
		var game := _game(hidden, ["scout", "scout", "scout", "scout", "scout"])
		assert_eq(game.legal_plays(P), [] as Array[Dictionary])
		assert_true(game.can_redraw(), "D8: a Scout is not a playable card")
		for card_index in game.hand(P).size():
			assert_eq(game.can_reveal(card_index), hidden > 0)
			assert_eq(game.is_card_playable(card_index), game.can_reveal(card_index))
			assert_eq(game.pieces_for_card(card_index), [] as Array[Vector2i])


func test_foresight_shows_one_more_card_per_hand() -> void:
	var amount := int(_foresight_config()["amount"])
	assert_eq(amount, 1)
	for hidden in [1, 3]:
		var game := _game(hidden, SCOUT_AND_MOVES, {"player_artifacts": ["foresight"]})
		_assert_hidden(game, game.initial_events(), hidden - amount, "hidden_cards %d" % hidden)
		game.end_turn()
		var events := game.end_turn()
		_assert_hidden(game, events, hidden - amount, "next hand, hidden_cards %d" % hidden)


func test_foresight_counts_only_for_the_player() -> void:
	var game := _game(1, SCOUT_AND_MOVES, {"opponent_artifacts": ["foresight"]})
	assert_eq(game.hidden_card_count(), 1)


func test_foresight_scout_stacking() -> void:
	var game := _game(4, ["scout", "scout", "scout", "move", "move"], {"player_artifacts": ["foresight"]})
	assert_eq(game.hidden_card_count(), 3)
	game.reveal(H.card_index(game, "scout"))
	assert_eq(game.hidden_card_count(), 1)
	assert_eq(H.events_of(game.reveal(H.card_index(game, "scout")), "reveal")[0]["count"], 1)
	assert_eq(game.hidden_card_count(), 0)
	assert_eq(game.reveal(H.card_index(game, "scout"))[0]["reason"], "nothing_hidden")


## [artifacts option, penalty the opponent gets per player piece].
func _penalty_cases() -> Array:
	var penalty := int(_foresight_config()["penalty"])
	assert_eq(penalty, 1)
	return [[{}, 0], [{"player_artifacts": ["foresight"]}, penalty], [{"opponent_artifacts": ["foresight"]}, 0]]


func test_foresight_penalty_on_a_capture() -> void:
	for case in _penalty_cases():
		var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(0, 0)), H.piece("pawn", Vector2i(3, 1))],
			[H.piece("king", OPPONENT_KING), H.piece("pawn", Vector2i(0, 4)), H.piece("bishop", Vector2i(1, 3))], H.FIVE_MOVES, H.FIVE_MOVES, case[0])
		game.play(0, Vector2i(0, 0), Vector2i(0, 4))
		assert_eq(game.score(P), 1, "the player's captures are unchanged: %s" % case[0])
		game.end_turn()
		var events := game.play(0, Vector2i(1, 3), Vector2i(3, 1))
		assert_eq(H.events_of(events, "capture")[0]["points"], 1 + case[1], str(case[0]))
		assert_eq(game.score(O), 1 + case[1], str(case[0]))


func test_foresight_penalty_on_a_king_capture() -> void:
	for case in _penalty_cases():
		var game := H.make([H.piece("king", Vector2i(5, 0))], [H.piece("king", OPPONENT_KING), H.piece("bishop", Vector2i(3, 2))],
			H.FIVE_MOVES, H.FIVE_MOVES, case[0])
		game.end_turn()
		game.play(0, Vector2i(3, 2), Vector2i(5, 0))
		assert_eq(game.result()["winner"], O)
		assert_eq(game.score(O), case[1], "a 0-value king: %s" % case[0])


func test_foresight_penalty_on_a_check_escape_capture() -> void:
	for case in _penalty_cases():
		var game := H.make([H.piece("king", PLAYER_KING), H.piece("rook", Vector2i(4, 0))], [H.piece("king", OPPONENT_KING)],
			H.FIVE_MOVES, H.FIVE_MOVES, case[0])
		game.play(0, Vector2i(4, 0), Vector2i(4, 5))
		var events := game.escape(Vector2i(4, 5))
		assert_eq(H.events_of(events, "capture")[0]["points"], 5 + case[1], str(case[0]))
		assert_eq(game.score(O), 5 + case[1], str(case[0]))


func test_foresight_penalty_on_an_explosion() -> void:
	for case in _penalty_cases():
		var options: Dictionary = case[0].duplicate()
		options["player_artifacts"] = options.get("player_artifacts", []) + ["exploding"]
		var game := H.make([H.piece("king", Vector2i(5, 0)), H.piece("rook", Vector2i(2, 0)), H.piece("knight", Vector2i(1, 3))],
			[H.piece("king", OPPONENT_KING), H.piece("pawn", Vector2i(2, 3)), H.piece("pawn", Vector2i(3, 4))], H.FIVE_MOVES, H.FIVE_MOVES, options)
		game.play(0, Vector2i(2, 0), Vector2i(2, 3))
		assert_null(game.piece_at(Vector2i(1, 3)), "own knight exploded")
		assert_eq(game.score(P), 1 + 1, "the player's explosion credits are unchanged: %s" % options)
		assert_eq(game.score(O), 3 + case[1], str(options))


func test_foresight_penalty_on_a_burn_out() -> void:
	var burn_turns := int(GameConfig.data("piece_sets")["sets"]["fire"]["burn_turns"])
	for case in _penalty_cases():
		var game := H.make([H.piece("king", Vector2i(5, 0), "fire"), H.piece("pawn", Vector2i(0, 1), "fire")],
			[H.piece("king", OPPONENT_KING)], H.FIVE_MOVES, H.FIVE_MOVES, case[0])
		game.play(0, Vector2i(0, 1), Vector2i(0, 2))
		var events: Array[Dictionary] = []
		for _i in burn_turns * 2 - 1:
			events = game.end_turn()
		assert_eq(H.events_of(events, "burn_out")[0]["points"], case[1], "a 0-value Fire pawn: %s" % case[0])
		assert_eq(game.score(O), case[1], str(case[0]))


func test_clone_keeps_the_hidden_cards() -> void:
	var game := _game(3, ["scout", "scout", "move", "move", "move"])
	game.reveal(H.card_index(game, "scout"))
	var copy := game.clone()
	assert_eq(_uids(copy.visible_opponent_hand()), _uids(game.visible_opponent_hand()))
	assert_eq(copy.hidden_card_count(), 1)
	copy.reveal(H.card_index(copy, "scout"))
	assert_eq(copy.hidden_card_count(), 0)
	assert_eq(game.hidden_card_count(), 1, "the original is independent")
