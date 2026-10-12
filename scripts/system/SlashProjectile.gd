extends Area2D

## The arc thrown by a fully-charged swing at full health.
##
## Rewards fighting from the top of your health rather than scraping through on
## a sliver: the reach only exists while nothing has touched you.

@export var speed: float = 420.0
@export var damage: float = 40.0
@export var lifetime: float = 0.9
## Stone stops it, the same layer that blocks a monster's line of sight.
@export var wall_mask: int = 1

var _heading: Vector2 = Vector2.RIGHT
var _left: float = 0.0
var _hit: Dictionary = {}


## Aimed once, on the way out. `direction` is a screen vector.
func launch(from: Vector2, direction: Vector2, power: float) -> void:
	global_position = from
	damage = power
	_heading = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	## Aimed by the squashed vector, not the ground one: the sprite rotates on
	## screen, so using the unsquashed heading points it above or below the line
	## it actually travels.
	##
	## Turned half around because the art is a C opening right — its convex back
	## is on the left, and rotating straight to the heading led with the hollow
	## of the crescent, which reads as an arc flying backwards.
	var on_screen := Vector2(_heading.x, _heading.y * 0.5)
	rotation = on_screen.angle() + PI


func _ready() -> void:
	_left = lifetime
	monitoring = true
	body_entered.connect(_on_body_entered)
	area_entered.connect(func(area: Area2D) -> void:
		var target := Breakable.hit_target(area)
		if target != null:
			_on_body_entered(target))


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	## Squashed like every other ground movement, so it travels along the floor
	## rather than across the screen.
	var step: Vector2 = _heading * speed * delta
	step.y *= 0.5
	global_position += step

	## Stops on stone. Without this it sails through walls and hits things in
	## the next room, which reads as a bug rather than as reach.
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
			global_position - step, global_position, wall_mask)
	if not space.intersect_ray(query).is_empty():
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("take_damage"):
		return
	## Once each. An arc lingering inside a monster would otherwise bill it
	## every physics frame it overlapped.
	if _hit.has(body.get_instance_id()):
		return
	if not (body.is_in_group("enemy") or body.is_in_group("breakable")):
		return
	_hit[body.get_instance_id()] = true
	body.take_damage(damage, global_position)
