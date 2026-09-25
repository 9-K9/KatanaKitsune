extends EnemyState

## One claw swing.


## Frame of the attack clip the claws connect on.
@export var hit_frame: int = 3
## How far past attack_range the follow-through still reaches.
@export var reach: float = 1.35

## Damage lands on a single frame, so one swing can only ever connect once
## however many physics frames that frame stays on screen for.
var _has_hit: bool = false


func on_enter() -> void:
	_has_hit = false
	enemy.stop()
	enemy.face(enemy.direction_to_player())
	enemy.play_once("attack")


func on_physics_process(_delta: float) -> void:
	enemy.stop()
	if not _has_hit and enemy.animated_sprite.frame >= hit_frame:
		_has_hit = true
		enemy.strike(reach)
	if enemy.animation_finished():
		change_state("walk")


func on_exit() -> void:
	enemy.start_attack_cooldown()
