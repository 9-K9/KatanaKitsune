extends OneShotAttackState

## A spinning kick. Same timing as the high kick.

func _init() -> void:
	clip = "roundKick"
	fps = 12
	duration = 0.75
	exit_state = "idle"
