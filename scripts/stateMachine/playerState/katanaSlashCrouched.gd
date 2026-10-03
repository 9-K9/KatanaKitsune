extends OneShotAttackState

## A low cut from a crouch.

func _init() -> void:
	clip = "katanaSlashCrouched"
	exit_state = "katanaIdle"
