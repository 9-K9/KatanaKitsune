extends TileMapLayer

## Feeds the player's position to wallFade.gdshader so the walls in front of her
## fade locally, rather than the whole layer dimming off a trigger polygon.
##
## Lives on the FrontWalls layer. Works in hand-built and generated maps alike,
## since it needs nothing but the player.

var _player: CharacterBody2D = null
var _shader: ShaderMaterial = null


func _ready() -> void:
	_shader = material as ShaderMaterial
	if _shader == null:
		push_warning("WallFade: %s has no ShaderMaterial; walls will not fade." % name)
		set_process(false)


func _process(_delta: float) -> void:
	var target := _find_player()
	if target == null:
		return
	_shader.set_shader_parameter("player_world", target.global_position)


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
