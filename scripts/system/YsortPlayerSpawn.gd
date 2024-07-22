extends Node2D
@export var playerScene : PackedScene

func _ready():
	var player = playerScene.instantiate()
	player.name = "PC01"
	player.position = 	$SpawnPlayerMarker2D.position
	add_child(player)

