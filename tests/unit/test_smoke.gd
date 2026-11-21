extends GutTest


func test_config_loads() -> void:
	assert_eq(GameConfig.value("match", "target_score"), 10.0)
	assert_eq(GameConfig.piece_value("queen"), 8)


func test_card_cost_with_cheaper() -> void:
	assert_eq(CardData.new("queen").cost(), 3)
	assert_eq(CardData.new("queen", "cheaper").cost(), 2)
	assert_eq(CardData.new("move", "cheaper").cost(), 0)


func test_fire_piece_value_and_deploy() -> void:
	assert_eq(PieceData.new("rook", "fire").value(), 4)
	assert_eq(PieceData.new("pawn", "fire").value(), 0)
	assert_eq(PieceData.new("king", "fire").is_set_piece(), false)
	assert_eq(PieceData.new("knight", "standard", "deploy").deploy_cost(), 2)
	assert_eq(PieceData.new("knight", "standard", "deploy").value(), 3)
