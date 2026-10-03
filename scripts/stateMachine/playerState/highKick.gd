extends OneShotAttackState

## A kick to the head. Faster than the mid kick, and 0.08s of the lock runs past the end of the art.

func _init() -> void:
	clip = "highKick"
	fps = 12
	duration = 0.75
	exit_state = "idle"
