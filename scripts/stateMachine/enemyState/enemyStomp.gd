extends EnemyState

## Oni's ground stomp.
##
## His export carries Angry_Ground_Stomp, and it is the most readable wind-up
## any monster has: a long raise, one heavy landing, then nothing. That shape is
## the fight. He hits everything around him rather than in front, so backing off
## is not enough, but he is rooted long enough afterwards that the player who
## reads it gets a free swing or a clean escape.
##
## The opening is the point. Without the recovery he is just a bigger punch.

## Frame the foot lands on.
@export var impact_frame: int = 9
## Stomp reaches further than a swing — it is a shockwave, not an arm.
@export var reach: float = 2.4
@export var damage_multiplier: float = 1.6
## Seconds rooted after the clip ends. The window.
@export var recovery_seconds: float = 1.1

var _hit: bool = false
var _recovering: float = 0.0


func on_enter() -> void:
	_hit = false
	_recovering = 0.0
	enemy.stop()
	enemy.face(enemy.direction_to_player())
	enemy.play_once("stomp")


func on_physics_process(delta: float) -> void:
	enemy.stop()
	if not _hit and enemy.animated_sprite.frame >= impact_frame:
		_hit = true
		enemy.strike(reach, damage_multiplier, enemy.STRIKE_ARC_OMNI)
	if not enemy.animation_finished():
		return
	## Clip is done but he is not. Hold the last frame through the recovery so
	## the body reads as winded rather than snapping back to a ready idle.
	_recovering += delta
	if _recovering >= recovery_seconds:
		change_state("walk")


func on_exit() -> void:
	enemy.start_attack_cooldown()
