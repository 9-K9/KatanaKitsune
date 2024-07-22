extends PC_Class

@export var walkSpeed : float = 5000.00
@export var runSpeed : float = 10000.00

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
			playerControler(0,2,delta)

	
	
