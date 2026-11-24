extends GutTest
## CardView layout on small cards (critique 3): the upgrade ribbon never covers the
## cost coin, and the coin can be turned off on mini cards.

const DECK_CARD := Vector2(72, 101)  # the run end's deck row


func _card(upgrade: String, card_size: Vector2) -> CardView:
	var data := CardData.new("bishop")
	data.upgrade = upgrade
	var view := CardView.create(data, card_size)
	add_child_autofree(view)
	view.size = card_size
	return view


func _coin_rect(view: CardView) -> Rect2:
	var r := CardView.COIN_RADIUS * view.size.x / CardView.SIZE.x
	var at := Vector2.ONE * CardView.COIN_CENTRE * view.size.x / CardView.SIZE.x
	return Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0)


func test_ribbon_clears_the_coin_at_every_size() -> void:
	for card_size: Vector2 in [CardView.SIZE, DECK_CARD]:
		for upgrade in ["book", "hold", "cheaper"]:
			var view := _card(upgrade, card_size)
			var ribbon := view._ribbon_rect(Rect2(Vector2.ZERO, card_size))
			assert_true(ribbon.has_area())
			assert_false(ribbon.intersects(_coin_rect(view)), "%s ribbon clears the coin at %s" % [upgrade, card_size])
			assert_true(Rect2(Vector2.ZERO, card_size).encloses(ribbon), "and stays on the card")


func test_book_ribbon_sits_beside_the_coin_on_the_run_end_card() -> void:
	var view := _card("book", DECK_CARD)
	var ribbon := view._ribbon_rect(Rect2(Vector2.ZERO, DECK_CARD))
	assert_lt(ribbon.position.y, _coin_rect(view).end.y, "top row, as in the hand")


func test_cost_coin_can_be_hidden() -> void:
	var view := _card("", Vector2(56, 78))
	assert_true(view.show_cost, "shown by default")
	view.show_cost = false
	assert_false(view.show_cost)


func test_opponent_captures_use_their_own_sound_when_it_exists() -> void:
	assert_eq(MatchFx.capture_sound(ChessMatch.PLAYER), "capture")
	var expected := "capture_against" if Sfx.has_sound("capture_against") else "capture"
	assert_eq(MatchFx.capture_sound(ChessMatch.OPPONENT), expected)
