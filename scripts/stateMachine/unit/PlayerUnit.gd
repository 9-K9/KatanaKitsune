extends PC_Class

func _physics_process(delta: float) -> void:
	#control the player
	match player_state:
		"run":
			playerControler(runSpeed,3,delta)
		"walk":
			playerControler(walkSpeed,2,delta)
		"idle":
			playerControler(0,1,delta)
		"attack":
			playerControler(0,3,delta)


			


func _on_action_timer_timeout():
	action_timer.stop()
			
func _on_action_area_body_entered(body):
	if body.is_in_group("enemy"):
		enemyBody = body
