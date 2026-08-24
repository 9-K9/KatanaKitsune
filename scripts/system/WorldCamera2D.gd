extends Camera2D

@export var player: CharacterBody2D

func _ready():
	if is_instance_valid(player):
		self.position = player.position

## Follows in _physics_process: the player is moved by move_and_slide() during
## the physics step, so sampling its position in _process reads a stale value on
## frames where no physics tick ran, which shows up as camera jitter.
func _physics_process(_delta):
	if self.enabled and is_instance_valid(player):
		self.position = player.position



	
