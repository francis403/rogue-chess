class_name Palette
extends RefCounted
## The club room at night: walnut surfaces, ivory type, one brass accent.
## Every colour in the UI comes from here.

# Surfaces: same warm hue, only lightness shifts.
const WALNUT_DEEP := Color("16110d")
const WALNUT := Color("1e1712")
const WALNUT_RAISED := Color("271e17")
const WALNUT_HIGH := Color("31261d")
const WALNUT_INSET := Color("120e0b")

# Ink: four text levels.
const IVORY := Color("efe6d4")
const IVORY_SOFT := Color("c2b6a0")
const IVORY_FAINT := Color("8d8172")
const IVORY_MUTED := Color("5f564b")

# Rules (borders): ivory at low alpha.
const RULE_SOFT := Color(0.94, 0.9, 0.83, 0.06)
const RULE := Color(0.94, 0.9, 0.83, 0.11)
const RULE_STRONG := Color(0.94, 0.9, 0.83, 0.2)

# The one accent and its meanings.
const BRASS := Color("d6a84e")
const BRASS_DIM := Color(0.84, 0.66, 0.31, 0.35)
const BRASS_INK := Color("2a1f12")
const OXBLOOD := Color("c0503f")
const FELT := Color("7fae67")
const EMBER := Color("e8823a")
const STEEL := Color("86b2d6")

# Board.
const MAPLE := Color("dcc7a3")
const BOARD_WALNUT := Color("8f6a4b")
const HOLE := Color("0d0a08")

# Pieces: the player plays ivory, the opponent plays ebony.
const PIECE_IVORY := Color("f1e6cc")
const PIECE_IVORY_INK := Color("3b2a1d")
const PIECE_EBONY := Color("231a14")
const PIECE_EBONY_INK := Color("eadcc0")

const SCRIM := Color(0.05, 0.035, 0.025, 0.78)


static func side_color(side: int) -> Color:
	return PIECE_IVORY if side == 0 else OXBLOOD
