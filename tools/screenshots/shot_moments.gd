extends RefCounted
## Crafted match moments for the screenshot tool: hand-made ChessMatch setups shown on
## the real match screen, the shots taken in them, and the motion frame sequences.
## Effects are caught on their own sound (Sfx.played), so each shot lands on the beat.

const ShotStage := preload("res://tools/screenshots/shot_stage.gd")

var stage: ShotStage
var frames_dir: String


## Opponent stand-in for the escape-prompt shot: one scripted rook move, then end turn.
class ScriptedAI extends MatchAI:
	var rook_move: Array = []

	func choose_action(game: ChessMatch) -> Dictionary:
		if game.pending_escape_side() == side:
			return {"kind": "decline_escape"}
		var hand := game.hand(side)
		for i in hand.size():
			if hand[i].type == "rook" and not rook_move.is_empty():
				var move: Array = rook_move
				rook_move = []
				return {"kind": "play", "card_index": i, "from": move[0], "to": move[1]}
		return {"kind": "end_turn"}


func _init(on_stage: ShotStage, frames_folder: String) -> void:
	stage = on_stage
	frames_dir = frames_folder


func _screen() -> Control:
	return stage.screen()


# --- Shots --------------------------------------------------------------------

func capture_scene() -> void:
	await _show_capture_setup()
	var ear := stage.listen("capture")
	await press_play("knight", Vector2i(1, 2), Vector2i(2, 4))
	await stage.heard(ear)
	await stage.shot("match_capture", 0.06)
	await stage.wait_idle()
	await stage.key(KEY_E)
	await stage.shot("match_opponent_turn", 0.5)
	await stage.wait_idle()
	await stage.shot("match_after_opponent")


func match_over_scene() -> void:
	show_crafted(crafted([["king", 2, 0], ["queen", 2, 3]], [["king", 2, 5], ["pawn", 0, 4]],
		["queen", "queen", "queen", "move", "move"], ["pawn", "move", "move", "move", "move"]))
	await stage.wait_idle()
	await press_play("queen", Vector2i(2, 3), Vector2i(2, 5))
	await stage.wait_idle()
	await stage.shot("match_over")


func shield_and_explosion_scene() -> void:
	await _show_explosion_setup()
	var shield := stage.listen("shield_block")
	await press_play("rook", Vector2i(2, 2), Vector2i(2, 4))
	await stage.heard(shield)
	await stage.shot("match_shield_block", 0.08)
	await stage.wait_idle()
	var blast := stage.listen("explosion")
	await press_play("knight", Vector2i(4, 2), Vector2i(5, 4))
	await stage.heard(blast)
	await stage.shot("match_explosion", 0.1)
	await stage.wait_idle()


## The opponent answers the player's check, then the player's own escape prompt.
func check_scenes() -> void:
	show_crafted(crafted([["king", 0, 0], ["rook", 3, 1], ["pawn", 1, 1]], [["king", 2, 5], ["pawn", 4, 4], ["knight", 4, 5]],
		["rook", "move", "pawn", "move", "move"], ["move", "move", "move", "move", "move"]))
	await stage.wait_idle()
	var escaped := stage.listen("escape")
	await press_play("rook", Vector2i(3, 1), Vector2i(2, 1))
	await stage.heard(escaped)
	await stage.shot("match_opponent_escapes", 0.3)
	await stage.wait_idle()
	await escape_prompt_scene()
	await stage.shot("match_escape_prompt")


## Leaves the player in check with the escape prompt up.
func escape_prompt_scene() -> void:
	show_crafted(crafted([["king", 2, 0], ["pawn", 5, 1], ["pawn", 0, 1], ["knight", 1, 0]], [["king", 5, 5], ["rook", 3, 5], ["pawn", 4, 4]],
		["move", "move", "pawn", "knight", "move"], ["rook", "rook", "rook", "rook", "rook"]))
	await stage.wait_idle()
	var scripted := ScriptedAI.new(ChessMatch.OPPONENT, 1, 0.0, RandomNumberGenerator.new())
	scripted.rook_move = [Vector2i(3, 5), Vector2i(2, 5)]
	_screen()._ai = scripted
	await stage.key(KEY_E)
	await stage.wait_idle()


## Deep Vision with two of the opponent's five cards still hidden (hidden_cards 3
## − foresight 1): three faces and two backs; then a Scout from the hand turns
## the two backs face up, shot while they flip open; then a still once the reveal
## has settled ("all shown", the names line and the log).
func deep_vision_scout_scene() -> void:
	await _show_deep_vision_setup()
	await stage.shot("match_deep_vision_hidden")
	await _play_scout()
	await stage.shot("match_deep_vision_scouted", 0.2)
	await stage.wait_idle()
	await stage.shot("match_deep_vision_scout_settled")


func _show_deep_vision_setup() -> void:
	var setup := crafted(
		[["king", 2, 0], ["knight", 1, 2], ["pawn", 3, 1], ["rook", 0, 0], ["bishop", 4, 0]],
		[["king", 2, 5], ["bishop", 2, 4], ["pawn", 4, 4], ["knight", 1, 5]],
		["scout", "knight", "move", "rook", "pawn"], ["pawn", "knight", "move", "bishop", "rook"], ["foresight"])
	setup["opponent"]["hidden_cards"] = 3
	show_crafted(setup)
	await stage.wait_idle()


## Plays the Scout from the hand; returns once its reveal starts (reward_reveal).
func _play_scout() -> void:
	var screen := _screen()
	var hand: Array[CardData] = screen.game.hand(ChessMatch.PLAYER)
	for i in hand.size():
		if hand[i].type == "scout":
			var flip := stage.listen("reward_reveal")
			screen.press_card(i)
			await stage.heard(flip)
			return


# --- Motion frame sequences ----------------------------------------------------

## 6-11 frames each across a capture, an explosion, a card play (energy drain), a
## turn banner, a Scout reveal (Deep Vision) and Deep Vision's attributed point.
func motion_frames() -> void:
	await _show_capture_setup()
	await _select("knight", Vector2i(1, 2))
	_screen().press_square(Vector2i(2, 4))
	await stage.frames("player_capture", 8, 0.09, frames_dir)
	await stage.wait_idle()

	await _show_explosion_setup()
	await _select("knight", Vector2i(4, 2))
	var blast := stage.listen("explosion")
	_screen().press_square(Vector2i(5, 4))
	await stage.heard(blast)
	await stage.frames("explosion", 8, 0.07, frames_dir)
	await stage.wait_idle()

	await _show_capture_setup()
	await _select("rook", Vector2i(0, 0))
	_screen().press_square(Vector2i(0, 1))
	await stage.frames("card_play_energy", 8, 0.06, frames_dir)
	await stage.wait_idle()

	var banner := stage.listen("turn_opponent")
	await stage.key(KEY_E)
	await stage.heard(banner)
	await stage.frames("turn_banner", 11, 0.09, frames_dir)
	await stage.wait_idle()

	# Deep Vision + Scout: the two hidden backs turn over one after the other.
	await _show_deep_vision_setup()
	await _play_scout()
	await stage.frames("scout_reveal", 10, 0.06, frames_dir)
	await stage.wait_idle()

	# Deep Vision's cost: the opponent's rook takes a pawn, "+1" and "+1 Deep Vision"
	# float apart and the player's Deep Vision chip glows.
	show_crafted(crafted([["king", 2, 0], ["pawn", 3, 3]], [["king", 0, 5], ["rook", 3, 5]],
		["move", "move", "move", "move", "move"], ["rook", "rook", "rook", "rook", "rook"], ["foresight"]))
	await stage.wait_idle()
	var scripted := ScriptedAI.new(ChessMatch.OPPONENT, 1, 0.0, RandomNumberGenerator.new())
	scripted.rook_move = [Vector2i(3, 5), Vector2i(3, 3)]
	_screen()._ai = scripted
	var taken := stage.listen(MatchFx.capture_sound(ChessMatch.OPPONENT))
	await stage.key(KEY_E)
	await stage.heard(taken)
	await stage.frames("deep_vision_point", 6, 0.1, frames_dir)
	await stage.wait_idle()


func _show_capture_setup() -> void:
	show_crafted(crafted(
		[["king", 2, 0], ["knight", 1, 2], ["pawn", 3, 1], ["rook", 0, 0, "shield"], ["bishop", 4, 0, "range"]],
		[["king", 2, 5], ["bishop", 2, 4], ["pawn", 4, 4], ["knight", 1, 5]],
		["knight", "knight:hold", "move", "rook", "pawn:cheaper"], ["pawn", "knight", "move", "bishop", "pawn"]))
	await stage.wait_idle()


func _show_explosion_setup() -> void:
	show_crafted(crafted(
		[["king", 2, 0], ["rook", 2, 2], ["knight", 4, 2], ["pawn", 1, 1]],
		[["king", 0, 5], ["bishop", 2, 4, "shield"], ["pawn", 5, 4], ["pawn", 4, 4], ["knight", 4, 5]],
		["rook", "knight", "move", "pawn", "move"], ["pawn", "move", "move", "move", "move"], ["exploding"]))
	await stage.wait_idle()


# --- Crafted setups and plays ---------------------------------------------------

## A setup in ChessMatch format. Pieces: [type, x, y, upgrade?]; cards: "type:upgrade".
func crafted(player: Array, opponent: Array, player_deck: Array, opponent_deck: Array, player_artifacts: Array = []) -> Dictionary:
	return {
		"seed": 5,
		"holes": [] as Array[Vector2i],
		"player": {"roster": _roster(player, Game.run.piece_set), "deck": _cards(player_deck), "artifacts": player_artifacts},
		"opponent": {"id": "easy", "name": "Rookie Rex", "difficulty": "Easy", "search_depth": 1, "random_chance": 0.0,
			"roster": _roster(opponent, "standard"), "deck": _cards(opponent_deck), "artifacts": []},
	}


static func _roster(entries: Array, set_id: String) -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for entry: Array in entries:
		var upgrade: String = entry[3] if entry.size() > 3 else ""
		roster.append({"piece": PieceData.new(entry[0], set_id, upgrade), "square": Vector2i(entry[1], entry[2])})
	return roster


static func _cards(specs: Array) -> Array[CardData]:
	var cards: Array[CardData] = []
	for spec: String in specs:
		var parts := spec.split(":")
		cards.append(CardData.new(parts[0], parts[1] if parts.size() > 1 else ""))
	return cards


func show_crafted(setup: Dictionary) -> void:
	Game.match_setup = setup
	# The HUD shows the run's artifacts: make them the crafted player's, so the HUD
	# chips and the YOU panel agree (this throwaway run is the tool's own).
	Game.run.artifacts.assign(setup["player"]["artifacts"])
	stage.main.show_screen("MATCH")


## Selects the card of `card_type` that can move the piece on `from`, then that piece.
func _select(card_type: String, from: Vector2i) -> void:
	var screen := _screen()
	var hand: Array[CardData] = screen.game.hand(ChessMatch.PLAYER)
	for i in hand.size():
		if hand[i].type == card_type and not screen.game.targets(i, from).is_empty():
			screen.press_card(i)
			break
	await stage.wait(0.25)
	screen.press_square(from)
	await stage.wait(0.1)


## Card, piece, target: a card-first play like a player's clicks.
func press_play(card_type: String, from: Vector2i, to: Vector2i) -> void:
	await _select(card_type, from)
	_screen().press_square(to)


func select_first_card() -> void:
	var screen := _screen()
	var game: ChessMatch = screen.game
	for i in game.hand(ChessMatch.PLAYER).size():
		if game.is_card_playable(i) and game.hand(ChessMatch.PLAYER)[i].type != "move":
			screen.press_card(i)
			var pieces := game.pieces_for_card(i)
			screen.press_square(pieces[pieces.size() / 2])
			return


func select_first_piece() -> void:
	var squares := MatchUiLogic.movable_pieces(_screen().game)
	_screen().press_square(squares[squares.size() - 1])


func play_first_legal() -> void:
	var game: ChessMatch = _screen().game
	var plays := game.legal_plays(ChessMatch.PLAYER)
	if plays.is_empty():
		return
	var play: Dictionary = plays[plays.size() - 1]
	_screen().press_square(play["from"])
	_screen().press_square(play["to"])
	await stage.wait_idle()
