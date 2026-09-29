class_name Chair
extends Node2D

## Where the player sits, and facing which way, for the automatic rest state.
##
## She sits at the chair's BASE — straight down from this node by exactly the
## sort lift, with no sideways component. That is not a tuned number: every prop
## that shares the floor with characters has its origin lifted 100px above its
## base so it sorts against them (see MazeDemo.SORT_LIFT), so undoing the lift
## lands on the one point the whole scene is measured from.
##
## It was arrived at the long way round. The offset was treated as an
## art-alignment problem and nudged by eye through eight values, drifting as far
## as (50, 78), when it had an exact answer the convention already stated.

## Straight down onto this chair's base, with no sideways component. 96 rather
## than the convention's 100 because that is where this art actually meets the
## floor — the number follows the sprite, not the other way round, so a chair
## drawn to a different height just changes this value.
@export var seat_offset: Vector2 = Vector2(0.0, 96.0)
## A further nudge for one awkward chair, kept separate so the default above
## stays readable as "undo the lift".
@export var sit_nudge: Vector2 = Vector2.ZERO
@export_enum("south", "southWest", "west", "northWest", "north", "northEast", "east", "southEast")
var sit_facing: String = "southWest"
## How much later this chair sorts than its raw position would put it.
##
## The same 96 as seat_offset, and for the same reason. This node's (0,0) is at
## the chair's TOP corner, not where it stands — so y-sorting, which compares
## raw node positions, treats the chair as though it were 96px further up the
## screen than it looks, and it loses to anything standing beside it.
##
## Biasing by the height of that offset makes it sort from its base, which is
## where it meets the floor and the only fair thing to compare against a
## character, whose own (0,0) is down at her feet. The art does not move: the
## node drops by this much and everything hanging off it rises by the same, so
## only the ordering changes.
@export var sort_bias: float = 96.0

## A note for whoever looks at SitZone and thinks it is in the wrong place: it
## is not. The zone tests against her collision shape, which rides 100px above
## her feet like every character's does, so it belongs on this node's origin and
## not on the seat below. Moving it down onto the visible chair would put it
## under her body where it can never touch her, and sitting would stop working.


func _ready() -> void:
	if is_zero_approx(sort_bias):
		return
	position.y += sort_bias
	## Put the visuals and the zone back, so this is invisible except in ordering.
	for child in [get_node_or_null("Sprite2D"), get_node_or_null("SitZone")]:
		if child is Node2D:
			(child as Node2D).position.y -= sort_bias


## Where the player's position is set when she sits. Maps one to one: move the
## marker or the offset a pixel and she moves a pixel.
func get_sit_position() -> Vector2:
	return get_seat_position() + sit_nudge


## The seat. A SitAnchor marker overrides the offset when one is present, so a
## chair can still be positioned by hand in the editor.
func get_seat_position() -> Vector2:
	var sit_anchor := get_node_or_null("SitAnchor") as Marker2D
	if sit_anchor != null:
		return sit_anchor.global_position
	## Undoes the sort bias, which moved the node without moving anything seen.
	return global_position + seat_offset - Vector2(0.0, sort_bias)


func get_sit_facing() -> String:
	return sit_facing
