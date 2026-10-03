extends OneShotAttackState

## A spinning kick. Same timing as the high kick.

func _init() -> void:
	clip = "roundKick"
	exit_state = "idle"
