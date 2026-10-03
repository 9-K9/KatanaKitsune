extends OneShotAttackState

## A low cut from a crouch.

func _init() -> void:
	clip = "katanaSlashCrouched"
	fps = 8
	duration = 1.0
	exit_state = "katanaIdle"
