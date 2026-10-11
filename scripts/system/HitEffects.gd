class_name HitEffects
extends Object

## Blood and slash arcs, spawned wherever a blow lands.
##
## Built in code rather than as scenes: every one of these is a handful of
## properties on a node that frees itself, and a scene file per effect would be
## four files to keep in step with four scripts for no gain.

const BLOOD_DIRECTIONS: Array[String] = [
	"east", "south-east", "south", "south-west",
	"west", "north-west", "north", "north-east",
]
const BLOOD_SHEETS: Array[Texture2D] = [
	preload("res://assets/pixellab/vfx/blood-8-directions/east/whole.png"),
	preload("res://assets/pixellab/vfx/blood-8-directions/south-east/whole.png"),
	preload("res://assets/pixellab/vfx/blood-8-directions/south/whole.png"),
	preload("res://assets/pixellab/vfx/blood-8-directions/south-west/whole.png"),
	preload("res://assets/pixellab/vfx/blood-8-directions/west/whole.png"),
	preload("res://assets/pixellab/vfx/blood-8-directions/north-west/whole.png"),
	preload("res://assets/pixellab/vfx/blood-8-directions/north/whole.png"),
	preload("res://assets/pixellab/vfx/blood-8-directions/north-east/whole.png"),
]
const BLOOD_OFFSETS: Array[Vector2] = [
	Vector2(-28, -23), Vector2(-28, -25), Vector2(-26, -27), Vector2(-23, -26),
	Vector2(-20, -23), Vector2(-19, -20), Vector2(-20, -20), Vector2(-25, -20),
]
const BLOOD_FPS: float = 19.0
const BLOOD_SCALE: int = 2
static var _blood_frames_cache: SpriteFrames = null
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
## The sheets already encode eight screen-space directions and their projection.
static func blood(parent: Node, at: Vector2, from: Vector2, amount: float,
		direction: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(parent) or amount <= 0.0:
		return
	var away := direction if direction != Vector2.ZERO else at - from
	if not away.is_finite() or away.length_squared() < 0.0001:
		away = Vector2.DOWN
	var index := posmod(roundi(away.angle() / (TAU / 8.0)), 8)
	var burst := AnimatedSprite2D.new()
	burst.name = "BloodBurst"
	burst.sprite_frames = _blood_frames()
	burst.centered = false
	burst.offset = BLOOD_OFFSETS[index]
	burst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	burst.process_mode = Node.PROCESS_MODE_PAUSABLE
	parent.add_child(burst)
	burst.global_position = at
	burst.global_scale = Vector2.ONE * BLOOD_SCALE
	burst.z_index = 60
	burst.z_as_relative = false
	burst.animation_finished.connect(burst.queue_free)
	burst.play(BLOOD_DIRECTIONS[index])


static func _blood_frames() -> SpriteFrames:
	if _blood_frames_cache != null:
		return _blood_frames_cache
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for i in BLOOD_DIRECTIONS.size():
		var animation: String = BLOOD_DIRECTIONS[i]
		var sheet: Texture2D = BLOOD_SHEETS[i]
		var size := sheet.get_size() / 3.0
		frames.add_animation(animation)
		frames.set_animation_loop(animation, false)
		frames.set_animation_speed(animation, BLOOD_FPS)
		for frame in 9:
			var texture := AtlasTexture.new()
			texture.atlas = sheet
			texture.region = Rect2(Vector2(frame % 3, frame / 3) * size, size)
			frames.add_frame(animation, texture)
	_blood_frames_cache = frames
	return frames


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
