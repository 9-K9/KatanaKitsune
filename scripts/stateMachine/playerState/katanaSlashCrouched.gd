extends OneShotAttackState

## A low cut from a crouch.

func _init() -> void:
	clip = "katanaSlashCrouched"
	fps = 8
	exit_state = "katanaIdle"
