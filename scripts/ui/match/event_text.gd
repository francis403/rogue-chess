class_name EventText
extends RefCounted
## Turns ChessMatch events into short log lines. "" means "don't log this one".

const FILES := "abcdef"


static func square_name(square: Vector2i) -> String:
	return "%s%d" % [FILES[square.x], square.y + 1]


static func reason_text(reason: String, player_won: bool) -> String:
	match reason:
		"king":
			return "The enemy king was captured." if player_won else "Your king was captured."
		"score":
			return "First to the target score." if player_won else "The opponent reached the target score first."
		"no_moves":
			return "The opponent had no legal move." if player_won else "You had no legal move."
		"turn_limit":
			return "Turn limit reached with the higher score." if player_won else "Turn limit reached; ties go to the opponent."
	return reason


## names: [player name, opponent name].
static func describe(event: Dictionary, names: Array) -> String:
	var who: String = names[int(event.get("side", 0))] if event.has("side") else ""
	match event["type"]:
		"turn_start":
			return "— Round %d · %s —" % [event["round"], "Your turn" if event["side"] == 0 else "%s's turn" % who]
		"card_played":
			return "%s played %s (%d)" % [who, Ui.piece_name(event["card_type"]), event["cost"]]
		"move":
			return "%s %s → %s" % [Ui.piece_name(event["piece_type"]), square_name(event["from"]), square_name(event["to"])]
		"capture":
			var verb := "exploded" if event["cause"] == "explosion" else "captured"
			return "%s %s on %s (+%d)" % [Ui.piece_name(event["piece_type"]), verb, square_name(event["square"]), event["points"]]
		"shield_block":
			return "Shield on %s blocked the %s" % [square_name(event["square"]), "blast" if event["cause"] == "explosion" else "capture"]
		"explosion":
			return "Powder Keg explodes at %s" % square_name(event["square"])
		"ignite":
			return "Piece on %s ignites (%d turns)" % [square_name(event["square"]), event["turns_left"]]
		"burn_out":
			return "%s on %s burned out (+%d to %s)" % [Ui.piece_name(event["piece_type"]), square_name(event["square"]), event["points"], names[int(event["by_side"])]]
		"promotion":
			return "Pawn promoted to Queen on %s" % square_name(event["square"])
		"redraw":
			return "%s redrew the hand" % who
		"reveal":
			var count: int = event["count"]
			var left := "none hidden now" if int(event["hidden"]) == 0 else "%d still hidden" % event["hidden"]
			return "%s scouted %d card%s · %s" % [who, count, "" if count == 1 else "s", left]
		"shuffle":
			return "%s shuffled %d cards into the draw pile" % [who, event["count"]]
		"check":
			var line := "Check! %s king on %s is attacked" % ["Your" if event["side"] == 0 else "%s's" % who, square_name(event["king_square"])]
			return line if event["can_escape"] else line + " (no escape)"
		"escape":
			return "%s escaped %s → %s (−%d energy next turn)" % [who, square_name(event["from"]), square_name(event["to"]), event["cost"]]
		"escape_declined":
			return "%s stayed in check" % who
		"energy":
			if int(event.get("escape_penalty", 0)) > 0:
				return "%s starts with %d energy (−%d from escapes)" % [who, event["energy"], event["escape_penalty"]]
			return ""
		"match_over":
			return "Match over — you win" if int(event["winner"]) == 0 else "Match over — %s wins" % names[1]
	return ""
