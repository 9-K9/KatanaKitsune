extends StaticBody2D

## Outdoor scenery — trees, statues, the torii. The origin is the spot where it
## meets the ground, so y-sorting puts a player behind it once they walk past
## the trunk. A tall canopy then hides them, so the sprite fades while any
## player stands behind it inside `fade_rect`.

## Area that can hide a player, relative to the origin. Zero size disables it.
@export var fade_rect: Rect2 = Rect2()
@export var faded_alpha: float = 0.4
@export var fade_speed: float = 6.0

@onready var _sprite: CanvasItem = get_node_or_null("Sprite2D")


func _ready() -> void:
	if fade_rect.size == Vector2.ZERO or _sprite == null:
		set_process(false)


func _process(delta: float) -> void:
	var target: float = 1.0
	for body in Roster.bodies(get_tree()):
		var local: Vector2 = to_local(body.global_position)
		if local.y < 0.0 and fade_rect.has_point(local):
			target = faded_alpha
			break
	_sprite.modulate.a = move_toward(_sprite.modulate.a, target, fade_speed * delta)
