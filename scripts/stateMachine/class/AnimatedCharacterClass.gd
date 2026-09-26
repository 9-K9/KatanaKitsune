class_name AnimatedCharacterClass
extends CharacterBody2D

##Movement Variables
@onready var direction: Vector2 = Vector2.ZERO
@onready var facing_dir: String = "southWest"
@export var ray_w : int
@export var ray_h : int
var speed : float = 0.0
## Speeds are in pixels/second. Previously these were ~60x larger because the
## movement code multiplied by delta before move_and_slide() applied it again;
## these values reproduce the old 60fps feel exactly (5000/60, 10000/60).
@export var walkSpeed : float = 83.333
@export var runSpeed : float = 166.667
## Damage one katana swing deals. Each swing now lands exactly once (see
## PlayerClass.playerAttack), where it used to fire on every rendered frame the
## clip sat on the hit frame — hence the old 0.25 "frame rate multiplies by 4".
@export var damage : float = 25.0
##Health Variables
@export var max_health: float = 100.0
var health: float = 100.0
var is_invincible: bool = false
## Latched on the killing blow. Without it every later hit on the corpse ran
## _on_death() again and restarted the death animation from the top.
var is_dead: bool = false
@export var invincibility_duration: float = 0.8

## Timed power-ups picked up from breakables, keyed by Pickup.Kind.
## Each entry is {"multiplier": float, "until": float} in seconds of game time.
var buffs: Dictionary = {}
## Base values the multipliers are applied to, captured before any buff lands.
var _base_damage: float = 0.0
var _base_walk: float = 0.0
var _base_run: float = 0.0
##Ray Casting 
@export_node_path("AnimatedSprite2D") var _animatedSprite2D: NodePath = "../../AnimatedSprite2D"
@export_node_path("Timer") var _actionTimer: NodePath = "../../ActionTimer"
@export_node_path("RayCast2D") var _rayCast2D: NodePath = "RayCast2D"
@export_node_path("Line2D") var _debugRayCastCollision: NodePath = "RayCast2D/ActionArea/Line2D"
@export_node_path("Line2D") var _debugCircleCastCollision: NodePath = "RayCast2D/ActionArea/CollisionShape2D/Circle"
@export_node_path("CollisionShape2D") var _rayCastCollision: NodePath = "RayCast2D/ActionArea/CollisionShape2D"
@onready var rayCast2D : RayCast2D = get_node(_rayCast2D)
@onready var debugRayCastCollision : Line2D = get_node(_debugRayCastCollision)
@onready var debugCircleCastCollision : Line2D = get_node(_debugCircleCastCollision)
@onready var rayCastCollision : CollisionShape2D = get_node(_rayCastCollision)
@onready var myAnimatedSprite2D : AnimatedSprite2D = get_node(_animatedSprite2D)
@onready var myTimer : Timer = get_node(_actionTimer)
			
func directionState(rnd_dir):
	var string_dir : String
	match rnd_dir:
		Vector2(0,1):
			string_dir = "south"
		Vector2(-1,1):
			string_dir = "southWest"
		Vector2(-1,0):
			string_dir = "west"
		Vector2(-1,-1):
			string_dir = "northWest"
		Vector2(0,-1):
			string_dir = "north"
		Vector2(1,-1):
			string_dir = "northEast"
		Vector2(1,0):
			string_dir = "east"
		Vector2(1,1):
			string_dir = "southEast"
	return string_dir	
	
func stateDirection(str_dir):
	var vector_dir : Vector2
	match str_dir:
		"south":
			vector_dir = Vector2(0,1)
		"southWest":
			vector_dir = Vector2(-1,1)
		"west":
			vector_dir = Vector2(-1,0)
		"northWest":
			vector_dir = Vector2(-1,-1)
		"north":
			vector_dir = Vector2(0,-1)
		"northEast":
			vector_dir = Vector2(1,-1)
		"east":
			vector_dir = Vector2(1,0)
		"southEast":
			vector_dir = Vector2(1,1)
	return vector_dir
	
func updateRayCast2D(str_dir):
	setRayCast2D(stateDirection(str_dir)) 

##set raycast to direction of player to check interaction events
func setRayCast2D(rnd_dir):
		if directionState(rnd_dir) == "south" or directionState(rnd_dir) == "north":
			rayCast2D.target_position = rnd_dir * Vector2(ray_w,ray_w)
		else:
			rayCast2D.target_position = rnd_dir * Vector2(ray_w,ray_h)
		debugRayCastCollision.set_point_position(0, Vector2.ZERO)
		debugRayCastCollision.set_point_position(1, rayCast2D.target_position)
		rayCastCollision.position = rayCast2D.target_position
		facing_dir = directionState(rnd_dir)

## Grants (or refreshes) a timed power-up. `kind` is a Pickup.Kind.
func grant_buff(kind: int, multiplier: float, duration: float) -> void:
	_capture_base_stats()
	buffs[kind] = {
		"multiplier": multiplier,
		"until": Time.get_ticks_msec() / 1000.0 + duration,
	}
	_apply_buffs()


## Drops any power-up whose timer has run out. Cheap enough to poll, and it
## keeps expiry off a pile of one-shot timers that would need cancelling on
## death and on scene reload.
func update_buffs() -> void:
	if buffs.is_empty():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var expired: Array = []
	for kind in buffs:
		if now >= buffs[kind]["until"]:
			expired.append(kind)
	if expired.is_empty():
		return
	for kind in expired:
		buffs.erase(kind)
	_apply_buffs()


func has_buff(kind: int) -> bool:
	return buffs.has(kind)


func _capture_base_stats() -> void:
	if _base_damage > 0.0:
		return
	_base_damage = damage
	_base_walk = walkSpeed
	_base_run = runSpeed


## Recomputed from the base values every time rather than multiplied in place,
## so a buff picked up twice cannot stack its multiplier permanently.
func _apply_buffs() -> void:
	if _base_damage <= 0.0:
		return
	damage = _base_damage * _buff_multiplier(Pickup.Kind.DAMAGE)
	walkSpeed = _base_walk * _buff_multiplier(Pickup.Kind.SPEED)
	runSpeed = _base_run * _buff_multiplier(Pickup.Kind.SPEED)


func _buff_multiplier(kind: int) -> float:
	return buffs[kind]["multiplier"] if buffs.has(kind) else 1.0


func take_damage(amount: float) -> void:
	## A ward soaks the hit entirely rather than reducing it, so the player can
	## see it working.
	if has_buff(Pickup.Kind.WARD):
		buffs.erase(Pickup.Kind.WARD)
		_start_invincibility()
		return
	if is_invincible or is_dead:
		return
	health -= amount
	health = max(health, 0)
	if health <= 0:
		is_dead = true
		_on_death()
	else:
		_start_invincibility()

func _start_invincibility() -> void:
	is_invincible = true
	# Visual feedback - flash the sprite
	var tween = create_tween()
	tween.tween_property(myAnimatedSprite2D, "modulate:a", 0.5, 0.1)
	tween.tween_property(myAnimatedSprite2D, "modulate:a", 1.0, 0.1)
	tween.set_loops(4)  # Flash 4 times over ~0.8s
	await get_tree().create_timer(invincibility_duration).timeout
	is_invincible = false

func _on_death() -> void:
	pass  # Override in subclass
