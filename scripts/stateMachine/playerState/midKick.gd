extends OneShotAttackState

## A straight kick to the body, bare-handed.

func _init() -> void:
	clip = "midKick"
	fps = 8
	exit_state = "idle"
