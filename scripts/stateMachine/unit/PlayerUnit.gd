extends PlayerClass

func _physics_process(delta: float) -> void:
	if gameManager.getState() == "game_play":
		playerMovement(delta)
		playerAnimation()


