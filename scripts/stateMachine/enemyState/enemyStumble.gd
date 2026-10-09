extends EnemyState

## Kappa falls over.
##
## His export has Angry_To_Tantrum_Sit — he throws himself down onto his shell —
## paired with Arise. Together they are the character: heavily armoured, badly
## coordinated, and periodically on his own back for reasons entirely his own.
##
## It is not a punish. It fires on a timer during a fight, unprompted, so the
## player gets a free opening at no cost. That is the trade for a monster who is
## otherwise hard to approach and shoots from range.
##
## While down he is wide open — the shell is useless with his legs in the air.

## Damage taken while down, as a multiple.
@export var exposed_multiplier: float = 2.0
## Seconds flat on his back after the fall clip, before Arise starts.
@export var down_seconds: float = 0.9

var _down: float = 0.0
var _fallen: bool = false


func on_enter() -> void:
	_down = 0.0
	_fallen = false
	enemy.stop()
	enemy.play_once("taunt")
	## The shell only protects a Kappa the right way up.
	enemy.set_meta("exposed", exposed_multiplier)


func on_physics_process(delta: float) -> void:
	enemy.stop()
	if not _fallen:
		if enemy.animation_finished():
			_fallen = true
		return
	_down += delta
	if _down >= down_seconds:
		change_state("arise")


func on_exit() -> void:
	enemy.remove_meta("exposed")
