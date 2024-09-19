extends Camera2D

@export var player: CharacterBody2D

func _ready():
	print(player)
	if is_instance_valid(player):
		self.position = player.position 

func _process(delta):
	if self.enabled and is_instance_valid(player):
		self.position = player.position 



	
