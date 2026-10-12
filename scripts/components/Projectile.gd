class_name Projectile
extends Area2D

## A thing a caster throws.
##
## One scene for every caster, configured at spawn rather than subclassed: a
## turtle egg, a snowball and a spirit bubble differ in art, speed and what they
## do on impact, not in how they travel. Three scenes would be three copies of
## the same movement and the same despawn bug.
##
## Travel is in ground space, not screen space. The world is isometric, so a
## projectile moving "north" has to cover half as many pixels vertically as
## horizontally or it reads as flying off the floor plane.

## Matches EnemyStateClass.ISO_Y_SCALE. Kept as its own constant so a projectile
## can be tested without a monster in the scene.
const ISO_Y_SCALE: float = 0.5

## Despawn distance. Without it a shot fired at a player who then dies travels
## until the level ends.
const MAX_TRAVEL: float = 900.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 260.0
var damage: float = 10.0
## Who fired it, so a caster cannot shoot itself in the back on a tight corner.
var shooter: Node2D = null
## Degrees per second of sprite spin. Eggs tumble, bubbles drift.
var spin: float = 0.0
## Pixels of vertical bob per second, and how far. A bubble floats; an egg does not.
var bob_rate: float = 0.0
var bob_height: float = 0.0

var _travelled: float = 0.0
var _life: float = 0.0
var _start_offset: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	## Areas only, so a shot does not stop on the caster's own body collider.
	body_entered.connect(_on_body_entered)
	area_entered.connect(func(area: Area2D) -> void:
		var target := Breakable.hit_target(area)
		if target != null:
			_on_body_entered(target))
	_start_offset = _sprite.position.y
	## So F3's debug overlay can find and draw every shot in flight — a ranged
	## attack is as much an "attack hitbox" as the blade's, and was invisible.
	add_to_group("projectile")


func _physics_process(delta: float) -> void:
	var step: Vector2 = direction.normalized() * speed * delta
	step.y *= ISO_Y_SCALE
	global_position += step

	_travelled += step.length()
	_life += delta
	if spin != 0.0:
		_sprite.rotation_degrees += spin * delta
	if bob_height != 0.0:
		_sprite.position.y = _start_offset + sin(_life * bob_rate) * bob_height

	if _travelled >= MAX_TRAVEL:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if is_queued_for_deletion():
		return
	if body == shooter:
		return
	## Monsters share a collision layer with her, so without this a caster at the
	## back of a group spends the fight shooting the monster in front of it.
	if body.is_in_group("enemy"):
		return
	if body.is_in_group("wall"):
		queue_free()
		return
	if (body.is_in_group("player") or body.is_in_group("breakable")) \
			and body.has_method("take_damage"):
		## Pass our own position so her guard can tell which way the shot came
		## from — the same contract melee strikes use.
		body.take_damage(damage, global_position)
		queue_free()


## Called by the caster instead of setting fields one at a time, so a caster
## that forgets a field gets the default rather than a half-configured shot.
func launch(from: Vector2, dir: Vector2, by: Node2D, cfg: Dictionary) -> void:
	global_position = from
	direction = dir
	shooter = by
	speed = cfg.get("speed", speed)
	damage = cfg.get("damage", damage)
	spin = cfg.get("spin", 0.0)
	bob_rate = cfg.get("bob_rate", 0.0)
	bob_height = cfg.get("bob_height", 0.0)
	var tex = cfg.get("texture", null)
	if tex != null:
		($Sprite2D as Sprite2D).texture = tex
	## The shot travels and collides on the floor, where bodies are; only the
	## sprite is lifted to hand height. Flying the collider at hand height ran it
	## a parallel line above her feet circle and missed her side-on.
	if cfg.has("height"):
		_sprite.position.y = float(cfg["height"])
		_start_offset = _sprite.position.y
