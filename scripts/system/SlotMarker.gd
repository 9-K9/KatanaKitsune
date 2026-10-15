extends Node2D

## The coloured ring under a player's feet, and their number.
##
## Four Akanes in one dark dungeon look identical from above — the colour
## schemes are each player's own choice and two of them can be a near match at
## a glance, so the thing that says "that one is you" cannot be the costume.
## Slot markers identify each body; player 1's marker follows temporary control.

## Drawn flat on the floor, so it is an ellipse rather than a circle: the map is
## 2:1, and a true circle reads as a ball hovering under her.
const RADIUS: float = 26.0
const SQUASH: float = 0.5
const WIDTH: float = 2.5

var slot: int = 0
var colour: Color = Color.WHITE

func setup(for_slot: int, tint: Color) -> void:
	slot = for_slot
	colour = tint
	queue_redraw()


func _ready() -> void:
	Roster.party_control_changed.connect(_on_party_control_changed)
	## Under her feet, not at her origin, which rides SORT_LIFT above the ground.
	position = Vector2(0, 0)
	## Behind her, so the ring reads as being on the floor she stands on rather
	## than painted across her boots.
	z_index = -1


func _on_party_control_changed(_previous: int, _controlled: int) -> void:
	queue_redraw()


func _draw() -> void:
	var tint := Roster.colour_of(0) if slot == Roster.controlled_bot_slot else colour
	var points := PackedVector2Array()
	for i in 33:
		var a: float = TAU * float(i) / 32.0
		points.append(Vector2(cos(a) * RADIUS, sin(a) * RADIUS * SQUASH))
	## A soft fill under the outline so the ring reads on a dark floor without
	## the outline having to be thick enough to look like paint.
	draw_colored_polygon(points, Color(tint.r, tint.g, tint.b, 0.13))
	draw_polyline(points, Color(tint.r, tint.g, tint.b, 0.85), WIDTH, true)

	## Built in code rather than as a Label child, so the marker is one script
	## with no scene file to keep in step with it.
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var text := Roster.gameplay_label_of(slot)
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(font, Vector2(-size.x * 0.5, -RADIUS * SQUASH - 6.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tint)
