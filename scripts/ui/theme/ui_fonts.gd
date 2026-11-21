class_name UiFonts
extends RefCounted
## System fonts only (no downloads). Serif for headings, a symbol font for chess glyphs.

const GLYPHS := {"king": "♚", "queen": "♛", "rook": "♜", "bishop": "♝", "knight": "♞", "pawn": "♟"}

static var _serif: SystemFont
static var _serif_bold: SystemFont
static var _symbols: SystemFont
static var _numbers: SystemFont
static var _has_glyphs: int = -1


static func serif() -> SystemFont:
	if _serif == null:
		_serif = _system_font(["Georgia", "Times New Roman", "DejaVu Serif", "serif"], 400)
	return _serif


static func serif_bold() -> SystemFont:
	if _serif_bold == null:
		_serif_bold = _system_font(["Georgia", "Times New Roman", "DejaVu Serif", "serif"], 700)
	return _serif_bold


## Lining figures for every number (Georgia's old-style 0 reads like an "o").
static func numbers() -> SystemFont:
	if _numbers == null:
		_numbers = _system_font(["Avenir Next", "Helvetica Neue", "Arial", "DejaVu Sans", "sans-serif"], 700)
	return _numbers


static func symbols() -> SystemFont:
	if _symbols == null:
		_symbols = _system_font(["Apple Symbols", "DejaVu Sans", "Segoe UI Symbol", "Noto Sans Symbols 2", "FreeSerif"], 400)
	return _symbols


## The chess glyph for a piece type, or its letter if no installed font has the glyph.
static func glyph(piece_type: String) -> String:
	if _has_glyphs == -1:
		_has_glyphs = 1 if symbols().has_char(GLYPHS["knight"].unicode_at(0)) else 0
	if _has_glyphs == 1:
		return GLYPHS.get(piece_type, "?")
	return String(GameConfig.data("pieces").get(piece_type, {}).get("symbol", "?"))


static func _system_font(names: Array, weight: int) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(names)
	font.font_weight = weight
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return font
