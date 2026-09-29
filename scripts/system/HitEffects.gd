class_name HitEffects
extends Object

## Blood and slash arcs, spawned wherever a blow lands.
##
## Built in code rather than as scenes: every one of these is a handful of
## properties on a node that frees itself, and a scene file per effect would be
## four files to keep in step with four scripts for no gain.

const BLOOD := Color(0.62, 0.05, 0.07)
## The arc, drawn as six frames: a faint anticipation streak, the bright sweep
## at its peak, then breaking up into sparks. A single still could not read as a
## blade passing through — it just appeared and vanished.
##
## The seventh frame PixelLab produced is fully transparent, so it is left out
## rather than held as a blank beat.
const SLASH_FRAMES := [
	preload("res://assets/sprites/fx/slash/slash_0.png"),
	preload("res://assets/sprites/fx/slash/slash_1.png"),
	preload("res://assets/sprites/fx/slash/slash_2.png"),
	preload("res://assets/sprites/fx/slash/slash_3.png"),
	preload("res://assets/sprites/fx/slash/slash_4.png"),
	preload("res://assets/sprites/fx/slash/slash_5.png"),
]
## Fast enough to be a blow rather than a flourish.
const SLASH_FPS: float = 22.0


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
	var arc := AnimatedSprite2D.new()
	arc.sprite_frames = _slash_frames()
	parent.add_child(arc)
	arc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arc.global_position = at
	arc.z_index = 60

	## Squashed before taking the angle, so the arc lies along the floor rather
	## than pointing above or below the line the blow actually travelled.
	var heading := Vector2(direction.x, direction.y * 0.5)
	arc.rotation = heading.angle() if heading != Vector2.ZERO else 0.0
	arc.scale = Vector2(size, size * 0.62)
	arc.modulate = Color(1.5, 1.8, 2.0, 1.0)

	arc.play("slash")
	## Frees itself when the sweep has finished rather than on a guessed timer.
	arc.animation_finished.connect(func():
		if is_instance_valid(arc):
			arc.queue_free())


## Built once and shared. Every hit making its own SpriteFrames would rebuild
## the same six-frame resource on every swing.
static var _frames_cache: SpriteFrames = null


static func _slash_frames() -> SpriteFrames:
	if _frames_cache != null:
		return _frames_cache
	var frames := SpriteFrames.new()
	frames.add_animation("slash")
	frames.set_animation_loop("slash", false)
	frames.set_animation_speed("slash", SLASH_FPS)
	for texture in SLASH_FRAMES:
		frames.add_frame("slash", texture)
	frames.remove_animation("default")
	_frames_cache = frames
	return _frames_cache


static func _free_after(node: Node, seconds: float) -> void:
	var timer := node.get_tree().create_timer(seconds)
	timer.timeout.connect(func():
		if is_instance_valid(node):
			node.queue_free())
