extends EnemyState

## A deliberately slow, readable heavy strike. Damage lands late enough in the
## clip for the player to evade or interrupt it.

@export var hit_frame: int = 6
@export var reach: float = 1.45
@export var damage_multiplier: float = 2.0
@export var maximum_seconds: float = 3.0

var _has_hit: bool = false
var _elapsed: float = 0.0


func on_enter() -> void:
	_has_hit = false
	_elapsed = 0.0
	enemy.stop()
	enemy.face(enemy.direction_to_player())
	enemy.play_once("charge")


func on_physics_process(delta: float) -> void:
	_elapsed += delta
	enemy.stop()
	if not _has_hit and enemy.animated_sprite.frame >= hit_frame:
		_has_hit = true
		enemy.strike(reach, damage_multiplier)
	if enemy.animation_finished() or _elapsed >= maximum_seconds:
		change_state("walk")


func on_exit() -> void:
	_has_hit = false
	_elapsed = 0.0
	enemy.start_attack_cooldown()
