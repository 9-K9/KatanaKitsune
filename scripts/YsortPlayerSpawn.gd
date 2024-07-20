extends Node2D

func _ready():
	var player = preload("res://scenes/characters/PC02.tscn").instantiate()
	player.name = "PC01"
	player.position = 	$SpawnPlayerMarker2D.position
	add_child(player)

