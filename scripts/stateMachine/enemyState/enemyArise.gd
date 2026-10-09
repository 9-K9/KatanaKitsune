extends EnemyState

## Getting up off the floor.
##
## Kappa after a tantrum, the kickers after a flip that did not land. Nothing
## happens here and that is the whole point — it is the window the player was
## given, and it has to be long enough to be worth taking.

@export var clip: String = "arise"


func on_enter() -> void:
	enemy.stop()
	enemy.play_once(clip)


func on_physics_process(_delta: float) -> void:
	## No facing, no tracking. He is on the ground.
	enemy.stop()
	if enemy.animation_finished():
		change_state("walk")
