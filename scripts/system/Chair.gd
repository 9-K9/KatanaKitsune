class_name Chair
extends Node2D

## Exact position and facing used by the player's automatic rest state.
@export_enum("south", "southWest", "west", "northWest", "north", "northEast", "east", "southEast")
var sit_facing: String = "southWest"
## Nudges where she lands without moving the marker, for tuning a single chair
## in the Inspector. Added to the marker, in screen pixels.
@export var sit_nudge: Vector2 = Vector2.ZERO

## Where the seat sits relative to this node, worked out rather than eyeballed.
##
## Two things pull her up and to the left of the chair. The node's origin is
## lifted 100px above the chair's base so it sorts against characters, and the
## sprite is drawn back down at +52 — so the chair you see is centred a good way
## below the origin everything is measured from. Separately, her seated art is
## drawn about 15px left of her own origin, so placing her origin on the chair's
## centre still leaves her body left of it.
const SPRITE_CENTRE_BELOW_ORIGIN: float = 52.0
const HER_ART_LEANS_LEFT: float = 15.0

## The marker maps straight onto her position: drag it a pixel and she moves a
## pixel. It used to convert by the 110px from her origin down to her feet, on
## the reasoning that her feet should land on the cushion — but seated, her feet
## stick out in front of her and it is her hips that touch the seat. Converting
## by her feet lifted her whole body clear of the chair.
##
## Rather than guess where her hips are in each of eight drawn directions, the
## marker simply is the answer, and can be dragged until it looks right.
func get_sit_position() -> Vector2:
	return get_seat_position() + sit_nudge


## The seat itself, as marked in the editor. Drag SitAnchor onto the cushion and
## it is right; there is nothing to calculate.
func get_seat_position() -> Vector2:
	var sit_anchor := get_node_or_null("SitAnchor") as Marker2D
	return sit_anchor.global_position if sit_anchor != null else global_position


func get_sit_facing() -> String:
	return sit_facing
