extends Node

## Fades a pillar when it is standing in front of a player.
##
## Columns are tall and the rooms are dense with them, so a player walking up
## the screen disappears entirely behind one — see the dungeon with forty of
## them to a floor. The walls already do this through an Area2D per room; a
## pillar is a single prop placed by the generator, so it carries its own check
## rather than needing a hand-authored trigger shape.
##
## Positional rather than collision-based on purpose: it has to answer for every
## player at once, and an Area2D would report "somebody is inside me" without
## saying whether that somebody is actually hidden.

## How far to either side of the column counts as behind it, in screen pixels.
## Its art is about 70 across, so this is a little wider than the stone.
@export var cover_width: float = 46.0
## How far up the screen the column reaches. Anything further up than this is
## past it and not occluded.
@export var cover_height: float = 150.0
## What it drops to while it is in the way.
@export var hidden_alpha: float = 0.35
@export var fade_speed: float = 8.0

var _sprite: Sprite2D = null
var _alpha: float = 1.0


func _ready() -> void:
	_sprite = get_parent().get_node_or_null("Sprite2D") as Sprite2D


func _process(delta: float) -> void:
	if _sprite == null:
		return
	var here: Vector2 = (get_parent() as Node2D).global_position
	var wanted: float = 1.0 if not _covering(here) else hidden_alpha
	_alpha = move_toward(_alpha, wanted, delta * fade_speed)
	## self_modulate, so this never tints anything the prop might parent later.
	_sprite.self_modulate = Color(1.0, 1.0, 1.0, _alpha)


## Is any living player hidden behind this column right now.
func _covering(here: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("player"):
		if not (node is CharacterBody2D) or node.get("is_dead") == true:
			continue
		var at: Vector2 = (node as Node2D).global_position
		## Up the screen from the column's base, and within its width. Those two
		## together are exactly the band the column draws over, because Y-sort
		## puts anything with a smaller y behind it.
		var up: float = here.y - at.y
		if up <= 0.0 or up > cover_height:
			continue
		if absf(at.x - here.x) <= cover_width:
			return true
	return false
