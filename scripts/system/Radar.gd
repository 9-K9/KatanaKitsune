extends Control

## Radar: plots nearby monsters relative to the player, through walls.
##
## Groundwork for stealth. Blips already carry the one piece of state that
## system will need — whether the monster has noticed you — so hiding from a
## red blip and watching it go amber is the loop, not a later rewrite.

## World distance the outer ring represents.
@export var range_world: float = 1400.0
@export var radius: float = 66.0
@export var blip_size: float = 4.0

const COLOUR_RING := Color(0.85, 0.72, 0.42, 0.30)
const COLOUR_PLAYER := Color(0.95, 0.90, 0.75, 0.95)
## Amber while it is still wandering, red once it has seen you.
const COLOUR_IDLE := Color(0.90, 0.65, 0.20, 0.85)
const COLOUR_ALERT := Color(0.85, 0.20, 0.18, 0.95)

var _player: CharacterBody2D = null


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var centre := Vector2(radius, radius)
	draw_circle(centre, radius, Color(0.05, 0.05, 0.06, 0.55))
	draw_arc(centre, radius, 0.0, TAU, 48, COLOUR_RING, 1.5, true)
	draw_arc(centre, radius * 0.5, 0.0, TAU, 32, COLOUR_RING, 1.0, true)

	var target := _find_player()
	if target == null:
		return
	draw_circle(centre, blip_size * 0.8, COLOUR_PLAYER)

	for node in get_tree().get_nodes_in_group("enemy"):
		if not (node is Node2D):
			continue
		var delta: Vector2 = node.global_position - target.global_position
		## Undo the 2:1 squash so the radar reads as a map of the ground rather
		## than of the screen, where everything vertical looks twice as close.
		delta.y *= 2.0
		if delta.length() > range_world:
			continue
		var blip: Vector2 = centre + delta / range_world * radius
		var alert: bool = "is_dead" in node and not node.is_dead and _has_noticed(node)
		draw_circle(blip, blip_size, COLOUR_ALERT if alert else COLOUR_IDLE)


## Whether this monster is actively after the player, read off its state machine
## rather than recomputed, so the radar cannot disagree with what it is doing.
func _has_noticed(node: Node) -> bool:
	var machine := node.get_node_or_null("FiniteStateMachine")
	if machine == null or machine.current_state == null:
		return false
	return machine.current_state.name in ["walk", "attack", "taunt"]


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
