extends OneShotAttackState

## A kick to the head. Quicker to recover from than the mid kick.

func _init() -> void:
	clip = "highKick"
	exit_state = "idle"
