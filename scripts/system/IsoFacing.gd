class_name IsoFacing
extends RefCounted

## The eight compass facings, and the one table that maps between them.
##
## The player and the monsters do not share a base class — AnimatedCharacterClass
## and AI_Class both extend CharacterBody2D directly — so each kept its own copy
## of this mapping. Two copies of a lookup table is two chances to edit one and
## not the other, and it had already drifted once: the name->vector halves
## disagreed on unknown input, one returning ZERO and the other falling off the
## end of a `match` to an uninitialised Vector2 that happened to equal ZERO.
## Callers test `== Vector2.ZERO` to mean "unknown facing", so correctness
## rested on that accident.
##
## Both classes keep thin directionState/stateDirection methods that call
## through to here. They are not redundant: Radar.gd finds anything that can
## report a facing with has_method("stateDirection"), so the methods have to
## exist on the instances.

## Screen-space unit vector for each facing. Not normalised — the diagonals are
## length sqrt(2) — because callers either round a direction into this table or
## normalise on the way out, and the unrounded values are what the `match` in
## the old copies compared against.
const VECTORS: Dictionary = {
	"south": Vector2(0, 1),
	"southWest": Vector2(-1, 1),
	"west": Vector2(-1, 0),
	"northWest": Vector2(-1, -1),
	"north": Vector2(0, -1),
	"northEast": Vector2(1, -1),
	"east": Vector2(1, 0),
	"southEast": Vector2(1, 1),
}

## The names, in the order the sprite sheets use them.
const NAMES: PackedStringArray = [
	"south", "southWest", "west", "northWest",
	"north", "northEast", "east", "southEast",
]

## Built once from VECTORS so the two directions can never disagree.
static var _names_by_vector: Dictionary = _build_reverse()


static func _build_reverse() -> Dictionary:
	var out: Dictionary = {}
	for name in VECTORS:
		out[VECTORS[name]] = name
	return out


## Facing name for a direction vector, or "" when it is not one of the eight.
##
## Expects an already-rounded vector: the components must be exactly -1, 0 or 1.
## Returning "" rather than a default facing is deliberate — callers guard on it
## to leave the current facing alone, and silently snapping to "south" would
## make a character flick round on a stray input.
static func name_of(direction: Vector2) -> String:
	return _names_by_vector.get(direction, "")


## Screen vector a facing points along, or ZERO when the name is not one of the
## eight. Callers test for ZERO to mean "unknown", so this must not guess.
static func vector_of(facing: String) -> Vector2:
	return VECTORS.get(facing, Vector2.ZERO)
