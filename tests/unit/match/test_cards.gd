extends GutTest
## Cards, costs, energy, hand and deck cycle, Hold, Book, redraw (D4-D11).

const H := preload("res://tests/unit/match/match_helper.gd")
const P := ChessMatch.PLAYER
const O := ChessMatch.OPPONENT
const PLAYER_KING := Vector2i(0, 0)
const OPPONENT_KING := Vector2i(5, 5)


func _game(player_deck: Array, player_extra: Array = [], options: Dictionary = {}, opponent_deck: Array = H.FIVE_MOVES) -> ChessMatch:
	var player_roster: Array = [H.piece("king", PLAYER_KING)] + player_extra
	return H.make(player_roster, [H.piece("king", OPPONENT_KING)], player_deck, opponent_deck, options)


func _from_squares(plays: Array[Dictionary]) -> Array:
	var squares := []
	for play in plays:
		if not squares.has(play["from"]):
			squares.append(play["from"])
	return H.sorted(squares)


func test_typed_card_moves_only_pieces_of_its_type() -> void:
	var game := _game(["knight", "knight", "knight", "knight", "knight"],
		[H.piece("knight", Vector2i(1, 0)), H.piece("bishop", Vector2i(2, 0)), H.piece("pawn", Vector2i(3, 1))])
	assert_eq(_from_squares(game.legal_plays(P)), [Vector2i(1, 0)])


func test_typed_card_moves_any_piece_of_its_type() -> void:
	var game := _game(["pawn", "pawn", "pawn", "pawn", "pawn"], [H.piece("pawn", Vector2i(3, 1)), H.piece("pawn", Vector2i(4, 1))])
	assert_eq(_from_squares(game.legal_plays(P)), [Vector2i(3, 1), Vector2i(4, 1)])


func test_move_card_moves_any_piece_including_the_king() -> void:
	var game := _game(H.FIVE_MOVES, [H.piece("knight", Vector2i(1, 0)), H.piece("pawn", Vector2i(3, 1))])
	assert_eq(_from_squares(game.legal_plays(P)), H.sorted([PLAYER_KING, Vector2i(1, 0), Vector2i(3, 1)]))


func test_king_can_only_move_with_a_move_card() -> void:
	var game := _game(["pawn", "knight", "bishop", "rook", "queen"],
		[H.piece("pawn", Vector2i(3, 1)), H.piece("knight", Vector2i(1, 0)), H.piece("bishop", Vector2i(2, 0)),
		H.piece("rook", Vector2i(5, 0)), H.piece("queen", Vector2i(4, 0))])
	assert_false(_from_squares(game.legal_plays(P)).has(PLAYER_KING))
	for card_index in game.hand(P).size():
		assert_eq(game.targets(card_index, PLAYER_KING), [] as Array[Vector2i])
	var events := H.play_type(game, "knight", PLAYER_KING, Vector2i(0, 1))
	assert_eq(events[0]["reason"], "wrong_card")


func test_card_costs_come_from_config() -> void:
	var expected := {"pawn": 1, "knight": 1, "bishop": 1, "rook": 2, "queen": 3, "move": 1}
	for type: String in expected:
		assert_eq(CardData.new(type).cost(), expected[type], type)


func test_playing_a_card_spends_energy_and_discards_it() -> void:
	var game := _game(["rook", "move", "move", "move", "move"], [H.piece("rook", Vector2i(5, 0))])
	assert_eq(game.energy(P), 3)
	var events := H.play_type(game, "rook", Vector2i(5, 0), Vector2i(5, 3))
	assert_eq(events[0]["type"], "card_played")
	assert_eq(events[0]["cost"], 2)
	assert_eq(game.energy(P), 1)
	assert_eq(game.hand(P).size(), 4)
	assert_eq(game.discard_size(P), 1)
	assert_eq(game.piece_at(Vector2i(5, 3)).type, "rook")


func test_several_cards_per_turn_while_energy_lasts() -> void:
	var game := _game(H.FIVE_MOVES)
	for y in [1, 2, 3]:
		assert_eq(game.play(0, Vector2i(0, y - 1), Vector2i(0, y))[0]["type"], "card_played")
	assert_eq(game.energy(P), 0)
	assert_eq(game.legal_plays(P), [] as Array[Dictionary])


func test_unaffordable_card_is_not_playable() -> void:
	var game := _game(["rook", "queen", "move", "move", "move"], [H.piece("rook", Vector2i(5, 0)), H.piece("queen", Vector2i(4, 0))])
	H.play_type(game, "rook", Vector2i(5, 0), Vector2i(5, 3))
	var queen_index := H.card_index(game, "queen")
	assert_false(game.is_card_playable(queen_index))
	assert_eq(game.pieces_for_card(queen_index), [] as Array[Vector2i])
	for play in game.legal_plays(P):
		assert_ne(play["card_index"], queen_index)
	var before := H.snapshot(game)
	assert_eq(game.play(queen_index, Vector2i(4, 0), Vector2i(4, 1))[0]["reason"], "not_enough_energy")
	assert_eq(H.snapshot(game), before)


func test_cheaper_reduces_cost_but_not_below_zero() -> void:
	assert_eq(CardData.new("queen", "cheaper").cost(), 2)
	assert_eq(CardData.new("pawn", "cheaper").cost(), 0)
	var game := _game(["move", "move", "move", "move:cheaper", "knight"], [H.piece("knight", Vector2i(1, 0))])
	for y in [1, 2, 3]:
		H.play_type(game, "move", Vector2i(0, y - 1), Vector2i(0, y))
	var cheaper_index := H.card_index(game, "move", "cheaper")
	assert_eq(game.energy(P), 0)
	assert_true(game.is_card_playable(cheaper_index))
	assert_false(game.is_card_playable(H.card_index(game, "knight")))
	game.play(cheaper_index, Vector2i(0, 3), Vector2i(0, 4))
	assert_eq(game.energy(P), 0)
	assert_eq(game.discard_size(P), 4, "0-cost card is still discarded")


func test_hand_of_five_and_three_energy() -> void:
	var game := _game(["move", "move", "move", "move", "move", "move", "move", "move"])
	assert_eq(game.hand(P).size(), 5)
	assert_eq(game.draw_pile_size(P), 3)
	assert_eq(game.energy(P), 3)
	assert_eq(game.max_energy(P), 3)
	assert_eq(game.hand(O).size(), 0, "opponent draws at its own turn start")


func test_energy_resets_every_turn() -> void:
	var game := _game(H.FIVE_MOVES)
	game.play(0, PLAYER_KING, Vector2i(0, 1))
	game.play(0, Vector2i(0, 1), Vector2i(0, 2))
	assert_eq(game.energy(P), 1)
	game.end_turn()
	assert_eq(game.energy(O), 3)
	game.end_turn()
	assert_eq(game.energy(P), 3)


func test_end_turn_discards_unplayed_cards_and_passes_the_turn() -> void:
	var game := _game(H.FIVE_MOVES)
	var events := game.end_turn()
	assert_eq(game.hand(P).size(), 0)
	assert_eq(game.discard_size(P), 5)
	assert_eq(game.current_side(), O)
	assert_eq(H.events_of(events, "discard")[0]["card_uids"].size(), 5)
	assert_eq(H.events_of(events, "turn_end").size(), 1)
	assert_eq(H.events_of(events, "turn_start")[0]["side"], O)


func test_empty_draw_pile_reshuffles_the_discard() -> void:
	var game := _game(["move", "move", "move", "move", "move", "move", "move"])
	assert_eq(game.draw_pile_size(P), 2)
	game.end_turn()
	var events := game.end_turn()
	assert_eq(H.events_of(events, "shuffle").size(), 1)
	assert_eq(H.events_of(events, "shuffle")[0]["count"], 5)
	assert_eq(H.events_of(events, "draw").size(), 5)
	assert_eq(game.hand(P).size(), 5)
	assert_eq(game.draw_pile_size(P), 2)
	assert_eq(game.discard_size(P), 0)


func test_drawing_stops_when_every_card_is_in_hand() -> void:
	var game := _game(["move", "move", "move"])
	assert_eq(game.hand(P).size(), 3)
	assert_eq(game.draw_pile_size(P), 0)
	game.end_turn()
	game.end_turn()
	assert_eq(game.hand(P).size(), 3)


func test_hold_card_stays_in_hand_and_counts_toward_hand_size() -> void:
	var deck := ["move:hold", "knight", "knight", "knight", "knight", "knight", "knight"]
	var game: ChessMatch = null
	for seed_value in range(1, 50):
		var candidate := _game(deck, [], {"seed": seed_value})
		if H.card_index(candidate, "move", "hold") >= 0:
			game = candidate
			break
	assert_not_null(game, "some seed puts the Hold card in the opening hand")
	if game == null:
		return
	game.end_turn()
	assert_eq(game.hand(P).size(), 1)
	assert_eq(game.hand(P)[0].upgrade, "hold")
	var events := game.end_turn()
	assert_eq(game.hand(P).size(), 5)
	assert_eq(H.events_of(events, "draw").size(), 4, "Hold card counts toward the hand size")
	assert_true(H.card_index(game, "move", "hold") >= 0)


func test_hold_card_always_kept_when_whole_deck_is_in_hand() -> void:
	var game := _game(["move:hold", "knight", "knight", "knight", "knight"])
	game.end_turn()
	assert_eq(game.hand(P).size(), 1)
	assert_eq(game.discard_size(P), 4)
	var events := game.end_turn()
	assert_eq(H.events_of(events, "draw").size(), 4)


func test_played_hold_card_is_discarded() -> void:
	var game := _game(["move:hold", "knight", "knight", "knight", "knight"])
	game.play(H.card_index(game, "move", "hold"), PLAYER_KING, Vector2i(0, 1))
	game.end_turn()
	assert_eq(game.hand(P).size(), 0)


func test_book_cards_are_always_in_the_opening_hand() -> void:
	var deck := ["knight:book", "bishop:book", "move", "move", "move", "move", "move", "move", "move", "move"]
	for seed_value in range(1, 30):
		var game := _game(deck, [], {"seed": seed_value})
		var types := H.hand_types(game, P)
		assert_true(types.has("knight") and types.has("bishop"), "seed %d" % seed_value)


func test_more_books_than_hand_size_fills_hand_with_a_random_subset() -> void:
	var deck := ["move:book", "move:book", "move:book", "move:book", "move:book", "move:book", "move:book", "knight", "knight", "knight"]
	var seen_subsets := {}
	for seed_value in range(1, 30):
		var setup := H.setup([H.piece("king", PLAYER_KING)], [H.piece("king", OPPONENT_KING)], deck, H.FIVE_MOVES, {"seed": seed_value})
		var deck_uids := (setup["player"]["deck"] as Array).map(func(card: CardData) -> int: return card.uid)
		var game := ChessMatch.new(setup)
		var positions := []
		for card in game.hand(P):
			assert_eq(card.upgrade, "book", "seed %d" % seed_value)
			positions.append(deck_uids.find(card.uid))
		positions.sort()
		seen_subsets[str(positions)] = true
	assert_gt(seen_subsets.size(), 1, "subset varies with the seed")


func test_opponent_book_cards_are_in_its_opening_hand() -> void:
	var opponent_deck := ["move:book", "move", "move", "move", "move", "move", "move", "move", "move", "move"]
	for seed_value in range(1, 10):
		var game := _game(H.FIVE_MOVES, [], {"seed": seed_value}, opponent_deck)
		game.end_turn()
		assert_true(H.card_index(game, "move", "book") >= 0, "seed %d" % seed_value)


func test_redraw_only_when_no_card_is_playable() -> void:
	var game := _game(H.FIVE_MOVES)
	assert_false(game.can_redraw())
	var before := H.snapshot(game)
	assert_eq(game.redraw()[0]["reason"], "redraw_not_allowed")
	assert_eq(H.snapshot(game), before)


func test_redraw_costs_energy_discards_and_draws_back_up() -> void:
	var game := _game(["rook", "rook", "rook", "rook", "rook", "rook", "rook"])
	assert_true(game.can_redraw(), "no rook on the board")
	var events := game.redraw()
	assert_eq(events[0]["type"], "redraw")
	assert_eq(game.energy(P), 2)
	assert_eq(H.events_of(events, "discard")[0]["card_uids"].size(), 5)
	assert_eq(H.events_of(events, "draw").size(), 5)
	assert_eq(game.hand(P).size(), 5)
	assert_eq(game.deck_size(P), 7)


func test_redraw_can_repeat_until_energy_runs_out() -> void:
	var game := _game(["rook", "rook", "rook", "rook", "rook"])
	for _i in 3:
		assert_true(game.can_redraw())
		game.redraw()
	assert_eq(game.energy(P), 0)
	assert_false(game.can_redraw())


func test_redraw_needs_enough_energy() -> void:
	var game := _game(["move", "move", "move", "rook", "rook"])
	for y in [1, 2, 3]:
		H.play_type(game, "move", Vector2i(0, y - 1), Vector2i(0, y))
	assert_eq(game.energy(P), 0)
	assert_false(game.can_redraw())


func test_redraw_discards_hold_cards_too() -> void:
	var game := _game(["rook:hold", "rook", "rook", "rook", "rook"])
	var hold_uid := game.hand(P)[H.card_index(game, "rook", "hold")].uid
	var events := game.redraw()
	var discarded: Array = H.events_of(events, "discard")[0]["card_uids"]
	assert_eq(discarded.size(), 5)
	assert_true(discarded.has(hold_uid), "D8: redraw discards the whole hand")
	assert_eq(game.hand(P).size(), 5)


func test_redraw_breaks_a_hand_of_dead_hold_cards() -> void:
	var deck := ["pawn:hold", "pawn:hold", "pawn:hold", "pawn:hold", "pawn:hold", "move", "move", "move", "move", "move"]
	var game := _game(deck)
	for _turn in 20:
		if H.hand_types(game, P).count("pawn") == 5:
			break
		game.end_turn()
		game.end_turn()
	assert_eq(H.hand_types(game, P).count("pawn"), 5, "Hold cards pile up into a dead hand")
	assert_eq(game.legal_plays(P), [] as Array[Dictionary], "no pawn on the board")
	assert_true(game.can_redraw())
	game.redraw()
	assert_gt(H.hand_types(game, P).count("move"), 0, "fresh hand has Move cards")
	assert_gt(game.legal_plays(P).size(), 0)
	assert_eq(game.deck_size(P), 10)


func test_redraw_when_affordable_cards_have_no_legal_move() -> void:
	var blocked := H.make([H.piece("pawn", Vector2i(0, 1)), H.piece("king", Vector2i(5, 0))],
		[H.piece("king", Vector2i(5, 5)), H.piece("pawn", Vector2i(0, 2))], ["pawn", "pawn", "pawn", "pawn", "pawn"])
	assert_true(blocked.can_redraw(), "pawn cards exist but the pawn is blocked")


func test_legal_plays_match_targets_and_pieces_for_card() -> void:
	var game := _game(["move", "knight", "pawn", "rook", "queen"],
		[H.piece("knight", Vector2i(1, 0)), H.piece("pawn", Vector2i(3, 1)), H.piece("rook", Vector2i(5, 0))])
	var plays := game.legal_plays(P)
	assert_gt(plays.size(), 0)
	var counted := 0
	for card_index in game.hand(P).size():
		for from in game.pieces_for_card(card_index):
			for to in game.targets(card_index, from):
				counted += 1
				assert_true(plays.has({"card_index": card_index, "from": from, "to": to}))
	assert_eq(counted, plays.size())
	assert_false(game.is_card_playable(H.card_index(game, "queen")), "no queen on board")


func test_legal_plays_empty_for_the_side_not_to_move() -> void:
	var game := _game(H.FIVE_MOVES)
	assert_eq(game.legal_plays(O), [] as Array[Dictionary])
	game.end_turn()
	assert_eq(game.legal_plays(P), [] as Array[Dictionary])
	assert_gt(game.legal_plays(O).size(), 0)
