class_name HitEffects
extends Object

## Blood and slash arcs, spawned wherever a blow lands.
##
## Built in code rather than as scenes: every one of these is a handful of
## properties on a node that frees itself, and a scene file per effect would be
## four files to keep in step with four scripts for no gain.

const BLOOD := Color(0.62, 0.05, 0.07)
const TRAIL := preload("res://assets/sprites/fx/slash_trail.png")


## A short spray of blood, thrown away from whoever landed the blow.
##
## Particles rather than a sprite because a hit should never look the same
## twice — a fixed splash animation reads as a stamp after the third monster.
static func blood(parent: Node, at: Vector2, from: Vector2, amount: float) -> void:
	if not is_instance_valid(parent):
		return
	var burst := CPUParticles2D.new()
	parent.add_child(burst)
	burst.global_position = at
	burst.z_index = 60

	## Scales with the blow, so a backstab reads differently from a jab.
	burst.amount = clampi(int(amount * 0.6), 6, 40)
	burst.one_shot = true
	burst.explosiveness = 0.92
	burst.lifetime = 0.55
	burst.local_coords = false

	var away: Vector2 = at - from
	away.y *= 0.5
	if away.length_squared() < 1.0:
		away = Vector2.DOWN
	burst.direction = away.normalized()
	burst.spread = 42.0
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 190.0
	## Pulled down the screen, so the spray falls to the floor rather than
	## drifting off in whatever direction the hit came from.
	burst.gravity = Vector2(0.0, 420.0)
	burst.damping_min = 40.0
	burst.damping_max = 120.0

	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 2.6
	burst.color = BLOOD
	## Fades out rather than vanishing mid-air. CPUParticles2D takes the Gradient
	## itself here, unlike the GPU one, which wants it wrapped in a texture.
	var ramp := Gradient.new()
	ramp.set_color(0, BLOOD)
	ramp.set_color(1, Color(BLOOD.r * 0.5, 0.0, 0.0, 0.0))
	burst.color_ramp = ramp

	burst.emitting = true
	_free_after(burst, burst.lifetime + 0.2)


## The arc a blade leaves, pointed the way the blow travelled.
static func slash(parent: Node, at: Vector2, direction: Vector2, size: float = 1.0) -> void:
	if not is_instance_valid(parent):
		return
	var arc := Sprite2D.new()
	parent.add_child(arc)
	arc.texture = TRAIL
	arc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arc.global_position = at
	arc.z_index = 60
	var heading: Vector2 = direction
	heading.y *= 0.5
	arc.rotation = heading.angle() if heading != Vector2.ZERO else 0.0
	## Squashed across the short axis so it lies along the floor like everything
	## else, and scaled by the weight of the blow.
	arc.scale = Vector2(size, size * 0.62)
	arc.modulate = Color(1.6, 1.9, 2.0, 0.95)

	## Grows and fades as it passes, which reads as a blade moving through
	## rather than a decal appearing.
	var fade := arc.create_tween()
	fade.set_parallel(true)
	fade.tween_property(arc, "modulate:a", 0.0, 0.22)
	fade.tween_property(arc, "scale", arc.scale * 1.35, 0.22)
	_free_after(arc, 0.3)


static func _free_after(node: Node, seconds: float) -> void:
	var timer := node.get_tree().create_timer(seconds)
	timer.timeout.connect(func():
		if is_instance_valid(node):
			node.queue_free())
