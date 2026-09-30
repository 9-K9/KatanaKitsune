class_name Pickup
extends Area2D

## Something Akane can walk over: a health charm, or a timed power-up.
##
## One script covers both because the only difference is what apply() does to
## the player, and keeping it in one place means breakables can drop either
## without caring which.

## STAMINA is food and drink rather than a charm: it restores the meter she
## spends on running and fighting, which nothing else refilled on demand. Kept
## in the same enum so a breakable can drop one without knowing the difference.
enum Kind { HEALTH, DAMAGE, SPEED, WARD, STAMINA }

@export var kind: Kind = Kind.HEALTH
## Health restored, or the multiplier applied for a power-up.
@export var amount: float = 30.0
## Power-up lifetime in seconds. Ignored by HEALTH.
@export var duration: float = 12.0

@onready var sprite: Sprite2D = $Sprite2D

var _taken: bool = false
var _bob: float = 0.0
var _rest_y: float = 0.0


func _ready() -> void:
	_rest_y = sprite.position.y
	_bob = randf() * TAU
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	## Slow hover so dropped loot reads as pickable rather than as scenery.
	_bob += delta * 2.4
	sprite.position.y = _rest_y + sin(_bob) * 3.0


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	## The player's hitbox Area2D is in the "player" group too; only the body
	## carries the health and the buff state.
	if not (body is CharacterBody2D):
		return
	_taken = true
	_apply(body)
	_consume()


func _apply(player: CharacterBody2D) -> void:
	match kind:
		Kind.HEALTH:
			player.health = minf(player.health + amount, player.max_health)
		Kind.STAMINA:
			player.stamina = minf(player.stamina + amount, player.max_stamina)
			## winded() is simply "stamina <= stamina_floor", so topping the meter
			## up is all that is needed to let her run again — there is no
			## separate winded flag to clear.
		Kind.DAMAGE, Kind.SPEED, Kind.WARD:
			if player.has_method("grant_buff"):
				player.grant_buff(kind, amount, duration)


func _consume() -> void:
	set_deferred("monitoring", false)
	var take := create_tween()
	take.set_parallel(true)
	take.tween_property(sprite, "position:y", _rest_y - 18.0, 0.3)
	take.tween_property(sprite, "modulate:a", 0.0, 0.3)
	take.chain().tween_callback(queue_free)
