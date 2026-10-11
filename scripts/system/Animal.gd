class_name Animal
extends CharacterBody2D
## Harmless wildlife. Idles, wanders about the spot it was placed on and bolts
## from anyone who comes close. Birds take off instead and are gone for good.
##
## Only two facings are drawn, south-east and north-east; the western two are
## the same frames mirrored. Movement is snapped to the four isometric
## diagonals so the sprite always matches the way the animal is going.

enum State { IDLE, WANDER, FLEE, FLY }

const DIAGONALS: Array[Vector2] = [
	Vector2(2, 1), Vector2(-2, 1), Vector2(-2, -1), Vector2(2, -1)]

@export var walk_speed: float = 40.0
@export var flee_speed: float = 150.0
@export var flee_radius: float = 170.0
## How far from a threat the animal stops running and settles down again.
@export var calm_radius: float = 320.0
@export var idle_time: Vector2 = Vector2(1.5, 4.5)
@export var wander_time: Vector2 = Vector2(0.6, 1.8)
@export var wander_radius: float = 140.0
## Birds fly off the floor when startled instead of running.
@export var can_fly: bool = false
@export var fly_speed: float = 220.0
@export var fly_rise: float = 160.0
@export var fly_time: float = 1.6

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var state: State = State.IDLE
var _home: Vector2
var _timer: float = 0.0
var _dir: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _fly_t: float = 0.0
var _sprite_base: Vector2


func _ready() -> void:
	_rng.randomize()
	## Spawners usually position a node after adding it, so home is taken on
	## the first physics frame rather than here.
	_home = Vector2.INF
	_sprite_base = sprite.position
	_dir = _diagonal(_rng.randi_range(0, 3))
	_idle()
	## Desynchronise the herd so a room of rats does not breathe in unison.
	sprite.frame = _rng.randi_range(0, maxi(sprite.sprite_frames.get_frame_count(sprite.animation) - 1, 0))


func _physics_process(delta: float) -> void:
	if _home == Vector2.INF:
		_home = global_position
	if state == State.FLY:
		_fly(delta)
		return
	var threat := _nearest_threat()
	var dist: float = INF if threat == null else global_position.distance_to(threat.global_position)
	if dist < flee_radius and state != State.FLEE:
		if can_fly:
			_take_off(threat)
			return
		state = State.FLEE
	if state == State.FLEE:
		if threat == null or dist > calm_radius:
			_idle()
		else:
			_dir = _away_from(threat.global_position)
			velocity = _dir * flee_speed
			_play("move")
			_slide()
		return
	_timer -= delta
	if state == State.WANDER:
		## Drift back home rather than wander off across the whole maze.
		if global_position.distance_to(_home) > wander_radius:
			_dir = _toward(_home)
		velocity = _dir * walk_speed
		_play("move")
		_slide()
		if _timer <= 0.0:
			_idle()
	elif _timer <= 0.0:
		state = State.WANDER
		_timer = _rng.randf_range(wander_time.x, wander_time.y)
		_dir = _diagonal(_rng.randi_range(0, 3))


func _idle() -> void:
	state = State.IDLE
	velocity = Vector2.ZERO
	_timer = _rng.randf_range(idle_time.x, idle_time.y)
	_play("idle")


func _slide() -> void:
	move_and_slide()
	## Ran into a wall: turn to the diagonal that runs along it.
	if get_slide_collision_count() > 0:
		var normal := get_slide_collision(0).get_normal()
		if _dir.dot(normal) < -0.2:
			_dir = _best_diagonal(_dir.slide(normal) + normal * 0.3)


func _nearest_threat() -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for group in ["player", "enemy"]:
		for node in get_tree().get_nodes_in_group(group):
			if not node is Node2D or not (node as Node2D).is_visible_in_tree():
				continue
			var d: float = global_position.distance_squared_to(node.global_position)
			if d < best_d:
				best_d = d
				best = node
	return best


func _take_off(threat: Node2D) -> void:
	state = State.FLY
	_dir = _away_from(threat.global_position)
	collision_mask = 0
	_fly_t = 0.0
	_play("fly" if sprite.sprite_frames.has_animation("fly_southEast") else "move")


func _fly(delta: float) -> void:
	_fly_t += delta
	var k: float = _fly_t / fly_time
	global_position += _dir * fly_speed * delta
	sprite.position = _sprite_base + Vector2(0, -fly_rise * k)
	modulate.a = clampf(1.5 - k * 1.5, 0.0, 1.0)
	if k >= 1.0:
		queue_free()


func _play(base: String) -> void:
	var back: bool = _dir.y < 0.0
	sprite.flip_h = _dir.x < 0.0
	var anim := "%s_%s" % [base, "northEast" if back else "southEast"]
	if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


func _diagonal(i: int) -> Vector2:
	return DIAGONALS[i].normalized()


func _best_diagonal(v: Vector2) -> Vector2:
	var best := _diagonal(0)
	for i in 4:
		if _diagonal(i).dot(v) > best.dot(v):
			best = _diagonal(i)
	return best


func _away_from(point: Vector2) -> Vector2:
	return _best_diagonal(global_position - point)


func _toward(point: Vector2) -> Vector2:
	return _best_diagonal(point - global_position)
