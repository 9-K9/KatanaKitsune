class_name Chair
extends Node2D

## Exact position and facing used by the player's automatic rest state.
@export_enum("south", "southWest", "west", "northWest", "north", "northEast", "east", "southEast")
var sit_facing: String = "southWest"

## Her seated art hangs this far below her origin. The marker is placed on the
## seat — where you can see she should land — and this converts that into the
## origin the state actually moves her to. Marking the origin directly meant
## placing a marker a hundred pixels above the chair and hoping.
const FEET_BELOW_ORIGIN: float = 110.0


## Where the player's origin has to be put for her to come down on the seat.
func get_sit_position() -> Vector2:
	return get_seat_position() - Vector2(0.0, FEET_BELOW_ORIGIN)


## The seat itself, as marked in the editor. Drag SitAnchor onto the cushion and
## it is right; there is nothing to calculate.
func get_seat_position() -> Vector2:
	var sit_anchor := get_node_or_null("SitAnchor") as Marker2D
	return sit_anchor.global_position if sit_anchor != null else global_position


func get_sit_facing() -> String:
	return sit_facing
