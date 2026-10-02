@tool
class_name RoomWalls
extends Node2D

## Turns one room prefab into any of sixteen by switching its four wall sides
## on and off.
##
## Sits on a room's root. Each side maps to a TileMapLayer named Walls_<side>
## under TileMap. Toggling in the Inspector updates the room live; the level
## generator sets the same four booleans when it places a room, so an authored
## variant and a generated one go through identical code.
##
## Uses `enabled` rather than `visible` deliberately. `visible` only stops a
## layer drawing — its collision stays, so hiding a wall that way leaves an
## invisible one the player walks into.

const SIDES: Array[String] = ["NE", "NW", "SE", "SW"]

@export var wall_ne: bool = true:
	set(value):
		wall_ne = value
		_apply("NE", value)

@export var wall_nw: bool = true:
	set(value):
		wall_nw = value
		_apply("NW", value)

@export var wall_se: bool = true:
	set(value):
		wall_se = value
		_apply("SE", value)

@export var wall_sw: bool = true:
	set(value):
		wall_sw = value
		_apply("SW", value)


func _ready() -> void:
	apply_all()


## Pushes all four booleans onto their layers. Call after setting them from
## code, since assigning the backing fields directly skips the setters.
func apply_all() -> void:
	_apply("NE", wall_ne)
	_apply("NW", wall_nw)
	_apply("SE", wall_se)
	_apply("SW", wall_sw)




## The reverse: sides a corridor or doorway can attach to.
func open_sides() -> Array[String]:
	var out: Array[String] = []
	for side in SIDES:
		if not get("wall_" + side.to_lower()):
			out.append(side)
	return out


func set_side(side: String, closed: bool) -> void:
	match side.to_upper():
		"NE": wall_ne = closed
		"NW": wall_nw = closed
		"SE": wall_se = closed
		"SW": wall_sw = closed


func _apply(side: String, closed: bool) -> void:
	if not is_inside_tree():
		return
	var layer := get_node_or_null("TileMap/Walls_" + side) as TileMapLayer
	if layer == null:
		push_warning("RoomWalls: %s has no TileMap/Walls_%s." % [name, side])
		return
	## Both, so the layer neither draws nor collides. `visible` is set too
	## because a layer left hidden by hand would otherwise stay invisible while
	## this reports it as walled.
	layer.enabled = closed
	layer.visible = closed
