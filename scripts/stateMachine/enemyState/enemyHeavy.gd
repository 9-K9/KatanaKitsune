extends EnemyState

## Oni's axe spin. The committed one.
##
## Punch_Combo is his jab; Axe_Spin_Attack is what he does when he has the room
## for it. Wider and harder than the jab, slower to start, and it does not
## track once begun — he commits to the arc he started.

@export var hit_frame: int = 6
@export var reach: float = 1.8
@export var damage_multiplier: float = 1.45

var _hit: bool = false


func on_enter() -> void:
	_hit = false
	enemy.stop()
	## Faces once, on entry. After this he is swinging and cannot correct.
	enemy.face(enemy.direction_to_player())
	enemy.play_once("heavy")


func on_physics_process(_delta: float) -> void:
	enemy.stop()
	if not _hit and enemy.animated_sprite.frame >= hit_frame:
		_hit = true
		## A spin has no front — it is the thing a forward-arc check would
		## otherwise wrongly take away from.
		enemy.strike(reach, damage_multiplier, enemy.STRIKE_ARC_OMNI)
	if enemy.animation_finished():
		change_state("walk")


func on_exit() -> void:
	enemy.start_attack_cooldown()
