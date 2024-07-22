extends Camera2D

@onready var player : CharacterBody2D = $"../NavigationRegion2D/YSort Objects/PC01"



func _ready():
	if is_instance_valid(player):
		self.position = player.position 

func _process(delta):
	if self.enabled and is_instance_valid(player):
		self.position = player.position 



	
