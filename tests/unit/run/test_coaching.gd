extends GutTest

const Helper := preload("res://tests/unit/run/run_test_helper.gd")

var dir: String
var session: RunSession


func before_each() -> void:
	dir = Helper.temp_dir("coaching")
	session = Helper.started_session(dir)
	Helper.win_and_skip(session, "R1")
	Helper.win_and_skip(session, "R2")


func after_each() -> void:
	Helper.remove_dir(dir)


func _enter() -> void:
	session.choose_node("R3")


func test_offers_three_cards_and_three_pieces_with_config_prices() -> void:
	_enter()
	var offers := session.coaching_offers()
	assert_eq(offers.size(), 6)
	var kinds := offers.map(func(o: Dictionary) -> String: return o["kind"])
	assert_eq(kinds, ["card", "card", "card", "piece", "piece", "piece"])
	var upgrades_cfg: Dictionary = GameConfig.data("upgrades")
	var items := []
	for offer in offers:
		var cfg: Dictionary = upgrades_cfg[offer["kind"]]
		assert_true(cfg.has(offer["upgrade"]), offer["upgrade"])
		assert_eq(offer["price"], int(cfg[offer["upgrade"]]["price"]))
		assert_eq(offer["upgrade_name"], cfg[offer["upgrade"]]["name"])
		assert_eq(offer["state"], "open")
		assert_eq(offer["item"].upgrade, "")
		assert_false(items.has(offer["item"]), "distinct items")
		items.append(offer["item"])
	for offer in offers.slice(0, 3):
		assert_true(session.deck.has(offer["item"]))
	for offer in offers.slice(3):
		assert_true(session.collection.has(offer["item"]))


func test_only_items_without_an_upgrade_are_offered() -> void:
	for card in session.deck:
		card.upgrade = "hold"
	session.deck[0].upgrade = ""
	for piece in session.collection:
		piece.upgrade = "range"
	session.collection[3].upgrade = ""
	session.collection[5].upgrade = ""
	_enter()
	var offers := session.coaching_offers()
	assert_eq(offers.size(), 3, "fewer offers when few items are eligible")
	assert_eq(offers[0]["item"], session.deck[0])
	for offer in offers.slice(1):
		assert_true(offer["item"] in [session.collection[3], session.collection[5]])


func test_accept_applies_the_upgrade_and_charges() -> void:
	_enter()
	session.points = 10
	var offer: Dictionary = session.coaching_offers()[4]
	assert_true(session.accept_coaching(4)["ok"])
	assert_eq(offer["item"].upgrade, offer["upgrade"])
	assert_eq(session.points, 10 - offer["price"])
	assert_eq(session.coaching_offers()[4]["state"], "accepted")
	assert_false(session.accept_coaching(4)["ok"], "only once")
	assert_eq(session.points, 10 - offer["price"])


func test_accept_card_upgrade() -> void:
	_enter()
	session.points = 10
	var offer: Dictionary = session.coaching_offers()[0]
	assert_true(session.accept_coaching(0)["ok"])
	assert_eq(offer["item"].upgrade, offer["upgrade"])
	assert_true(session.deck.has(offer["item"]))


func test_accept_without_enough_points_is_refused() -> void:
	_enter()
	session.points = 1
	var result := session.accept_coaching(0)
	assert_false(result["ok"])
	assert_string_contains(result["error"], "Not enough points")
	assert_eq(session.coaching_offers()[0]["item"].upgrade, "")
	assert_eq(session.coaching_offers()[0]["state"], "open")
	assert_eq(session.points, 1)


func test_decline() -> void:
	_enter()
	session.points = 10
	assert_true(session.decline_coaching(2)["ok"])
	assert_eq(session.coaching_offers()[2]["state"], "declined")
	assert_false(session.accept_coaching(2)["ok"], "declined offers are closed")
	assert_false(session.decline_coaching(2)["ok"])
	assert_eq(session.points, 10)
	assert_eq(session.coaching_offers()[2]["item"].upgrade, "")


func test_bad_indexes_are_refused() -> void:
	_enter()
	assert_false(session.accept_coaching(6)["ok"])
	assert_false(session.decline_coaching(-1)["ok"])


func test_item_that_gained_an_upgrade_cannot_get_a_second() -> void:
	_enter()
	session.points = 10
	session.coaching_offers()[3]["item"].upgrade = "shield"
	var result := session.accept_coaching(3)
	assert_false(result["ok"])
	assert_eq(session.coaching_offers()[3]["item"].upgrade, "shield")
	assert_eq(session.points, 10)


func test_upgrades_are_logged_and_leave_returns_to_map() -> void:
	_enter()
	session.points = 10
	session.accept_coaching(0)
	var events: Array = session.logger.run_data()["events"]
	assert_eq(events[-1]["kind"], "upgrade")
	assert_true(events[-1].has("card"))
	assert_true(session.leave_coaching()["ok"])
	assert_eq(session.phase, RunSession.Phase.MAP)
	assert_eq(session.coaching_offers(), [] as Array[Dictionary])
	assert_false(session.accept_coaching(1)["ok"])


func test_every_upgrade_type_shows_up_with_its_price() -> void:
	var seen := {}
	for seed_value in 40:
		var other := Helper.started_session(dir, seed_value)
		Helper.win_and_skip(other, "R1")
		Helper.win_and_skip(other, "R2")
		other.choose_node("R3")
		for offer in other.coaching_offers():
			seen[offer["upgrade"]] = offer["price"]
	assert_eq(seen, {"cheaper": 2, "hold": 2, "book": 2, "range": 2, "deploy": 2, "shield": 4})


func test_no_offers_when_everything_is_upgraded() -> void:
	for card in session.deck:
		card.upgrade = "book"
	for piece in session.collection:
		piece.upgrade = "shield"
	_enter()
	assert_eq(session.phase, RunSession.Phase.COACHING)
	assert_eq(session.coaching_offers(), [] as Array[Dictionary])
	assert_false(session.accept_coaching(0)["ok"])
	assert_true(session.leave_coaching()["ok"])
	assert_eq(session.phase, RunSession.Phase.MAP)
