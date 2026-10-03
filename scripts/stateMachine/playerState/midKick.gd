extends OneShotAttackState

## A straight kick to the body, bare-handed.

func _init() -> void:
	clip = "midKick"
	fps = 8
	duration = 1.0
	exit_state = "idle"
