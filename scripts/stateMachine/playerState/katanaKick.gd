extends OneShotAttackState

## A kick thrown with the blade already drawn, so it returns to katanaIdle.

func _init() -> void:
	clip = "katanaKick"
	exit_state = "katanaIdle"
