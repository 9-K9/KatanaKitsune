extends Node2D

@onready var player = $"../NavigationRegion2D/Objects/Player"
@onready var world_camera = $WorldCamera

func _ready():
	if is_instance_valid(world_camera):
		world_camera.visible = true
		Dialogic.start("timeline")
		
		
	
		


	
		

	
