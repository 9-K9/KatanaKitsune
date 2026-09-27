extends TileMapLayer

## Keeps the player visible when scenery is drawn on top of her.
##
## Replaces the hand-drawn trigger polygons, which only covered part of the map
## and fired for the whole layer at once. This works off the tilemap itself, so
## it needs nothing authored and works in a generated level too.
##
## FADE punches a soft hole around her — for walls, where hiding the whole layer
## would open the room up.
## HIDE drops the layer entirely — for roofs, where a porthole would look odd
## and you want to see the room anyway.

enum Mode { FADE, HIDE }

@export var mode: Mode = Mode.FADE
## How far around the player to look for covering tiles, in cells. The
## Crocotile wall planes are 8 cells wide and placed several cells apart, so a
## tight radius misses the very wall that is standing in front of her.
@export var search_radius: int = 8

var _player: CharacterBody2D = null
var _shader: ShaderMaterial = null
var _covered: bool = false


func _ready() -> void:
	if mode == Mode.FADE:
		_shader = material as ShaderMaterial
		if _shader == null:
			push_warning("WallFade: %s has no ShaderMaterial; it will not fade." % name)
			set_process(false)


func _process(_delta: float) -> void:
	var target := _find_player()
	if target == null:
		return

	var covered := _is_covering(target.global_position)
	match mode:
		Mode.FADE:
			_shader.set_shader_parameter("player_world", target.global_position)
			## Passed as a float because the shader multiplies by it.
			_shader.set_shader_parameter("behind", 1.0 if covered else 0.0)
		Mode.HIDE:
			if covered == visible:
				visible = not covered
	_covered = covered


## Does this layer draw anything on top of `world_pos`?
##
## For walls that means a tile the y-sort puts in front of her, which is any
## tile whose own position sorts later. Testing this per pixel in the shader
## cannot work: a wall's pixels run ~350px up from its base, so only the bottom
## strip ever matched, which read as a fade around her feet that also fired
## while she stood in front of the wall.
##
## For roofs it means a tile more or less overhead.
func _is_covering(world_pos: Vector2) -> bool:
	var local: Vector2 = to_local(world_pos)
	var origin: Vector2i = local_to_map(local)
	for dy in range(-search_radius, search_radius + 1):
		for dx in range(-search_radius, search_radius + 1):
			var cell: Vector2i = origin + Vector2i(dx, dy)
			if get_cell_source_id(cell) == -1:
				continue
			if mode == Mode.HIDE:
				return true
			## Sorts in front of her, so it is drawn over her.
			if map_to_local(cell).y > local.y:
				return true
	return false


func _find_player() -> CharacterBody2D:
	if is_instance_valid(_player):
		return _player
	## The player's hitbox Area2D is in the "player" group too, so take the
	## first body rather than the first node.
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D:
			_player = node
			return _player
	return null
