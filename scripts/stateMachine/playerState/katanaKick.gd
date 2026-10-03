extends OneShotAttackState

## A kick thrown with the blade already drawn, so it returns to katanaIdle.

func _init() -> void:
	clip = "katanaKick"
	fps = 8
	duration = 0.75
	exit_state = "katanaIdle"
