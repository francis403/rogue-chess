extends GutTest

const Helper := preload("res://tests/unit/run/run_test_helper.gd")

var dir: String
var session: RunSession


func before_each() -> void:
	dir = Helper.temp_dir("shop")
	session = Helper.started_session(dir)
	Helper.win_and_skip(session, "L1")
	session.choose_node("L2")


func after_each() -> void:
	Helper.remove_dir(dir)


func test_offers_match_the_config() -> void:
	var shop_cfg: Dictionary = GameConfig.data("economy")["shop"]
	var offers := session.shop_offers()
	assert_eq(offers["cards"].size(), 3)
	assert_eq(offers["pieces"].size(), 2)
	assert_eq(offers["remove_price"], 1)
	assert_eq(offers["removes_left"], 1)
	for offer in offers["cards"]:
		var expected := 3 if offer["card"].type in ["rook", "queen"] else 2
		assert_eq(offer["price"], expected, offer["card"].type)
		assert_false(offer["sold"])
	for offer in offers["pieces"]:
		assert_eq(offer["price"], int(shop_cfg["piece_prices"][offer["piece"].type]))
		assert_eq(offer["piece"].piece_set, "standard")
		assert_ne(offer["piece"].type, "king")


func test_offers_are_generated_once_per_visit() -> void:
	var first := session.shop_offers()
	var second := session.shop_offers()
	for i in 3:
		assert_eq(first["cards"][i]["card"], second["cards"][i]["card"])


func test_buy_card() -> void:
	session.points = 10
	var offer: Dictionary = session.shop_offers()["cards"][0]
	assert_true(session.buy_card(0)["ok"])
	assert_eq(session.points, 10 - offer["price"])
	assert_true(session.deck.has(offer["card"]))
	assert_true(session.shop_offers()["cards"][0]["sold"])
	var again := session.buy_card(0)
	assert_false(again["ok"], "each offer only once")
	assert_eq(session.points, 10 - offer["price"])


func test_buy_piece_joins_the_collection_without_a_card() -> void:
	session.points = 10
	var offer: Dictionary = session.shop_offers()["pieces"][1]
	var deck_size := session.deck.size()
	assert_true(session.buy_piece(1)["ok"])
	assert_eq(session.collection.size(), 17)
	assert_true(session.collection.has(offer["piece"]))
	assert_eq(session.deck.size(), deck_size, "D34")
	assert_eq(session.points, 10 - offer["price"])
	assert_false(session.buy_piece(1)["ok"])


func test_fire_run_buys_fire_pieces() -> void:
	var meta := MetaStore.new(dir + "meta.json")
	meta.unlock_piece_set("fire")
	var fire := RunSession.new(8, meta, RunLogger.new(dir + "logs/"))
	fire.choose_piece_set("fire")
	Helper.win_and_skip(fire, "L1")
	fire.choose_node("L2")
	for offer in fire.shop_offers()["pieces"]:
		assert_eq(offer["piece"].piece_set, "fire")


func test_not_enough_points_is_refused_with_a_reason() -> void:
	session.points = 0
	for result in [session.buy_card(0), session.buy_piece(0), session.remove_card(session.deck[0].uid)]:
		assert_false(result["ok"])
		assert_string_contains(result["error"], "Not enough points")
	assert_eq(session.points, 0)
	assert_eq(session.deck.size(), 6)


func test_bad_indexes_are_refused() -> void:
	session.points = 10
	assert_false(session.buy_card(3)["ok"])
	assert_false(session.buy_card(-1)["ok"])
	assert_false(session.buy_piece(2)["ok"])
	assert_eq(session.points, 10)


func test_remove_card() -> void:
	session.points = 5
	var card := session.deck[2]
	assert_false(session.remove_card(123456)["ok"], "unknown card")
	assert_true(session.remove_card(card.uid)["ok"])
	assert_false(session.deck.has(card))
	assert_eq(session.points, 4)
	assert_eq(session.shop_offers()["removes_left"], 0)
	var second := session.remove_card(session.deck[0].uid)
	assert_false(second["ok"], "one removal per visit")
	assert_eq(session.deck.size(), 5)


func test_remove_card_respects_min_deck_size() -> void:
	session.points = 5
	while session.deck.size() > 4:
		session.deck.pop_back()
	var result := session.remove_card(session.deck[0].uid)
	assert_false(result["ok"])
	assert_string_contains(result["error"], "fewer than 4")
	assert_eq(session.deck.size(), 4)


func test_leave_shop_returns_to_the_map() -> void:
	assert_true(session.leave_shop()["ok"])
	assert_eq(session.phase, RunSession.Phase.MAP)
	assert_false(session.buy_card(0)["ok"])
	assert_eq(session.shop_offers(), {})


func test_shop_actions_are_logged() -> void:
	session.points = 20
	session.buy_card(0)
	session.buy_piece(0)
	session.remove_card(session.deck[0].uid)
	var kinds: Array = session.logger.run_data()["events"].map(func(e: Dictionary) -> String: return e["kind"])
	assert_eq(kinds, ["reward_skip", "purchase_card", "purchase_piece", "remove_card"])


func test_last_move_card_cannot_be_removed() -> void:
	session.points = 5
	var move_card: CardData = session.deck.filter(func(c: CardData) -> bool: return c.type == "move")[0]
	var result := session.remove_card(move_card.uid)
	assert_false(result["ok"])
	assert_string_contains(result["error"], "last Move card")
	assert_true(session.deck.has(move_card))
	assert_eq(session.points, 5)
	assert_eq(session.shop_offers()["removes_left"], 1, "the removal is still available")


func test_a_spare_move_card_can_be_removed() -> void:
	session.points = 5
	var spare := CardData.new("move")
	session.deck.append(spare)
	assert_true(session.remove_card(spare.uid)["ok"])
	assert_eq(session.deck.filter(func(c: CardData) -> bool: return c.type == "move").size(), 1)
