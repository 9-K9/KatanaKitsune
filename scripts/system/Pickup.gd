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

## Laid out on a table rather than lying loose. It is visible but cannot be
## taken — the meal is on the furniture, and she has to break the furniture to
## get at it. Armed by Breakable when the prop shatters.
@export var armed: bool = true
## How far above this node's own origin the art is drawn while it is laid out
## on something. The node itself stays down at the furniture's base so Y-sort
## places it with the furniture; only the picture climbs onto the tabletop.
##
## Same reasoning as Chair.sort_bias, inverted: sorting compares raw node
## positions, so an item parked at tabletop height sorts as though it stood
## 110px further up the screen and drew behind the table it is sitting on.
var display_lift: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

var _taken: bool = false
var _bob: float = 0.0
var _rest_y: float = 0.0


func _ready() -> void:
	if display_lift != 0.0:
		sprite.position.y -= display_lift
		## Over the furniture, never behind it. Relative so the whole prop still
		## sorts against the room as one thing.
		sprite.z_index = 1
	_rest_y = sprite.position.y
	_bob = randf() * TAU
	body_entered.connect(_on_body_entered)
	if not armed:
		monitoring = false


func _process(delta: float) -> void:
	## Sits still while it is still somebody's table setting; only loose loot
	## bobs, which is what marks it as pickable.
	if not armed:
		return
	_hover(delta)


## Made takeable, and tipped onto the floor. Called when the prop holding it
## breaks: until then it is scenery you can see but not use.
##
## Moves the whole node rather than the sprite — the sprite's local y is the
## hover offset, so animating that would leave the item hanging in mid-air at
## the height of a table that no longer exists.
func arm(falls_to: Vector2) -> void:
	armed = true
	set_deferred("monitoring", true)
	## Back down to the floor as the furniture goes: the lift was the tabletop,
	## and there is no tabletop any more.
	if display_lift != 0.0:
		sprite.position.y += display_lift
		sprite.z_index = 0
		_rest_y = sprite.position.y
		display_lift = 0.0
	var fall := create_tween()
	fall.tween_property(self, "global_position", falls_to, 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _hover(delta: float) -> void:
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
