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
enum Kind { HEALTH, DAMAGE, SPEED, WARD, STAMINA, SCROLL }

@export var kind: Kind = Kind.HEALTH
## Which scroll, for a SCROLL pickup. -1 picks one at random when it spawns, so
## one scene covers all six.
@export var scroll_kind: int = -1
## Health restored, or the multiplier applied for a power-up.
@export var amount: float = 30.0
## Power-up lifetime in seconds. Ignored by HEALTH.
@export var duration: float = 12.0
@export var use_world_art: bool = false

## Laid out on a table rather than lying loose. It is visible but cannot be
## taken — the meal is on the furniture, and she has to break the furniture to
## get at it. Armed by Breakable when the prop shatters.
@export var armed: bool = true
## How far above this node's own origin the art is drawn while it is laid out
## on something.
##
## Same reasoning as Chair.sort_bias and MazeDemo's pillar_sort_bias: Y-sort
## compares raw node positions, so an item parked at tabletop height sorts as
## though it stood further up the screen than the table it is sitting on, and
## loses to it. The fix is the same one used there — push this node's own
## position down by the lift so its sort key reads as "in front of the
## table", then pull every visible/functional child back up by the same
## amount so nothing actually moves on screen. z_index must never be used for
## this: a non-zero z_index is compared globally across the whole canvas, not
## just against the table, which is exactly what let a lifted item draw over
## pillars and anything else elsewhere in the room.
var display_lift: float = 0.0

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _light: PointLight2D = get_node_or_null("PointLight2D") as PointLight2D

@onready var sprite: Sprite2D = $Sprite2D

var _taken: bool = false
var _bob: float = 0.0
var _rest_y: float = 0.0


func _ready() -> void:
	add_to_group("pickup")
	if kind == Kind.SCROLL:
		_dress_scroll()
	if display_lift != 0.0:
		_raise(display_lift)
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
	## body_entered fires once, on the way in. A scroll she was standing on when
	## her slots were full is looked at again, so freeing a slot is enough to
	## take it without stepping off and back on.
	if kind == Kind.SCROLL and not _taken and monitoring:
		_retry_in -= delta
		if _retry_in <= 0.0:
			_retry_in = 0.3
			for body in get_overlapping_bodies():
				_on_body_entered(body)
				if _taken:
					break


var _retry_in: float = 0.3


## Picks the scroll, if the spawner left it to chance, and paints the pickup to
## match: its icon, a floor-sized scale, and a glow in the kanji's ink.
func _dress_scroll() -> void:
	if scroll_kind < 0 or scroll_kind >= Scroll.COUNT:
		scroll_kind = Scroll.random_kind()
	if not use_world_art:
		sprite.texture = Scroll.icon(scroll_kind)
	if _light != null:
		_light.color = Scroll.INK[scroll_kind].lightened(0.35)


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
		_lower(display_lift)
		_rest_y = sprite.position.y
		display_lift = 0.0
	var fall := create_tween()
	fall.tween_property(self, "global_position", falls_to, 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Pushes this node's own position down by `amount` (so its Y-sort key reads
## as standing in front of the table) and pulls every child that actually
## draws or collides back up by the same amount, so nothing visibly moves.
func _raise(amount: float) -> void:
	position.y += amount
	sprite.position.y -= amount
	if _collision != null:
		_collision.position.y -= amount
	if _light != null:
		_light.position.y -= amount


## Undoes _raise: used once the item falls and no longer needs to sort
## against the furniture it was sitting on.
func _lower(amount: float) -> void:
	position.y -= amount
	sprite.position.y += amount
	if _collision != null:
		_collision.position.y += amount
	if _light != null:
		_light.position.y += amount


func _hover(delta: float) -> void:
	## Slow hover so dropped loot reads as pickable rather than as scenery.
	_bob += delta * 2.4
	sprite.position.y = _rest_y + sin(_bob) * 3.0


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	## Online the server decides who picked what up; the client's copy only
	## vanishes when told to (see network_taken), and the effect arrives in the
	## next snapshot.
	if NetworkManager.is_client:
		return
	## The player's hitbox Area2D is in the "player" group too; only the body
	## carries the health and the buff state.
	if not (body is CharacterBody2D):
		return
	## A scroll goes into her slots rather than straight into effect, and with
	## all six taken by other kinds it stays on the floor for later.
	if kind == Kind.SCROLL:
		var slots = body.get("scrolls")
		if slots == null or not slots.add(scroll_kind):
			return
		_taken = true
		_consume()
		return
	_taken = true
	_apply(body)
	_consume()


## A client's copy of a pickup the server has just handed out.
func network_taken() -> void:
	if _taken:
		return
	_taken = true
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
	AudioManager.play_for("sfx_pickup_scroll" if kind == Kind.SCROLL else "sfx_pickup_health", self)
	NetworkManager.announce_world_event("pickup_taken", self)
	set_deferred("monitoring", false)
	var take := create_tween()
	take.set_parallel(true)
	take.tween_property(sprite, "position:y", _rest_y - 18.0, 0.3)
	take.tween_property(sprite, "modulate:a", 0.0, 0.3)
	take.chain().tween_callback(queue_free)
