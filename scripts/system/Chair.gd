class_name Chair
extends Node2D

## Grounded at the player's current physics origin, not the legacy sort lift.
@export var seat_offset := Vector2(0, -18)
@export var sit_nudge := Vector2.ZERO
@export var sort_bias: float = -24.0
@export_enum("southEast", "south", "southWest", "west", "northWest", "north", "northEast", "east")
var facing: String = "southEast":
	set(value):
		facing = value
		_apply_facing()

const FACINGS: PackedStringArray = ["southEast", "southWest", "northWest", "northEast"]


func _apply_facing() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	var index := WorldObjects.FACINGS.find(facing)
	if sprite == null or index < 0:
		return
	var texture := load("res://assets/sprites/world_objects/chair/chair_dir%d.png" % (index + 1)) as Texture2D
	sprite.texture = texture
	sprite.scale = Vector2(0.6, 0.6)
	var image := texture.get_image()
	var bounds := image.get_used_rect()
	# Sort at the seat, not the sprite centre or the front tips of its legs.
	y_sort_enabled = true
	sprite.position = Vector2(0, sort_bias)
	sprite.offset = Vector2(texture.get_width() * 0.5 - bounds.get_center().x,
			-(bounds.end.y - texture.get_height() * 0.5)) \
			- sprite.position / sprite.scale
	set_meta("world_direction", index + 1)


func face_randomly(rng: RandomNumberGenerator) -> void:
	var direction := WorldObjects.direction_from_roll(rng.randf(), rng.randi(), false)
	facing = WorldObjects.FACINGS[direction - 1]


func _ready() -> void:
	_apply_facing()


func get_sit_position() -> Vector2:
	return get_seat_position() + sit_nudge


func get_seat_position() -> Vector2:
	var anchor := get_node_or_null("SitAnchor") as Marker2D
	return anchor.global_position if anchor != null else global_position + seat_offset


func get_sit_facing() -> String:
	return facing
