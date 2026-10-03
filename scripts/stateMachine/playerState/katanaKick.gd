extends OneShotAttackState

## A kick thrown with the blade already drawn, so it returns to katanaIdle.

func _init() -> void:
	clip = "katanaKick"
	fps = 8
	exit_state = "katanaIdle"
