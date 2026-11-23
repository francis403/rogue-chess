class_name BoardLegend
extends Control
## A key to the board marks, drawn with the same shapes BoardView and PieceToken
## use: dot = move, ring = capture, brass corners = can move, oxblood frame =
## gives check, steel coin = shield, ember number = burn turns left, and (when the
## board has any) the dark pit of a hole.

const ROW := 24.0
const SWATCH := 18.0
const ENTRIES := [["dot", "Move here"], ["ring", "Capture"], ["corners", "Can move"],
	["check", "Gives check"], ["shield", "Shield"], ["burn", "Burn turns left"]]
const HOLE_ENTRY := ["hole", "Hole: no piece"]

## Set before it enters the tree: adds the hole entry (Sinkholes boards).
var show_holes: bool = false
var _entries: Array = ENTRIES


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if show_holes:
		_entries = ENTRIES + [HOLE_ENTRY]
	custom_minimum_size = Vector2(0, ROW * ceili(_entries.size() / 2.0))


func _draw() -> void:
	var column_width := size.x / 2.0
	for i in _entries.size():
		var at := Vector2((i % 2) * column_width, floori(i / 2.0) * ROW)
		var swatch := Rect2(at + Vector2(0, (ROW - SWATCH) / 2.0), Vector2.ONE * SWATCH)
		draw_rect(swatch, Palette.MAPLE)
		_draw_mark(_entries[i][0], swatch)
		draw_string(get_theme_default_font(), at + Vector2(SWATCH + Metrics.S, ROW / 2.0 + 5), _entries[i][1],
			HORIZONTAL_ALIGNMENT_LEFT, column_width - SWATCH - Metrics.S, UiTheme.CAPTION, Palette.IVORY_SOFT)


func _draw_mark(kind: String, rect: Rect2) -> void:
	var centre := rect.get_center()
	match kind:
		"dot":
			draw_circle(centre, 3.5, Palette.BRASS)
		"ring":
			draw_arc(centre, 7.0, 0, TAU, 24, Palette.OXBLOOD, 2.5, true)
			draw_arc(centre, 5.0, 0, TAU, 24, Color(Palette.MAPLE, 0.6), 1.0, true)
		"corners":
			_corners(rect.grow(-1), Palette.BRASS, 2.0)
		"check":
			draw_rect(rect.grow(-1), Palette.OXBLOOD, false, 1.0)
			_corners(rect.grow(-1), Palette.OXBLOOD, 3.0)
		"shield":
			draw_circle(centre, 7.0, Palette.STEEL)
			var w := 3.8
			draw_colored_polygon(PackedVector2Array([centre + Vector2(-w, -w), centre + Vector2(w, -w), centre + Vector2(w, 0.5),
				centre + Vector2(0, w * 1.2), centre + Vector2(-w, 0.5)]), Palette.WALNUT_DEEP)
		"hole":
			draw_circle(centre, 7.5, Palette.HOLE)
			draw_circle(centre + Vector2(0, 1.0), 5.5, Palette.HOLE.darkened(0.6))
		"burn":
			draw_circle(centre, 7.0, Palette.EMBER)
			draw_string(UiFonts.numbers(), centre + Vector2(-7, 4), "3", HORIZONTAL_ALIGNMENT_CENTER, 14, 11, Palette.WALNUT_DEEP)


func _corners(rect: Rect2, color: Color, width: float) -> void:
	var arm := rect.size.x * 0.35
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var inward := (rect.get_center() - corner).sign()
		draw_line(corner, corner + Vector2(inward.x * arm, 0), color, width)
		draw_line(corner, corner + Vector2(0, inward.y * arm), color, width)
