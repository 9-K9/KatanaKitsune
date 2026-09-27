class_name Chair
extends Node2D

## Exact position and facing used by the player's automatic rest state.
@export_enum("south", "southWest", "west", "northWest", "north", "northEast", "east", "southEast")
var sit_facing: String = "southWest"

func get_sit_position() -> Vector2:
	var sit_anchor := get_node_or_null("SitAnchor") as Marker2D
	return sit_anchor.global_position if sit_anchor != null else global_position


func get_sit_facing() -> String:
	return sit_facing
