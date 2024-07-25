extends Node2D
@export var playerScene : PackedScene
@export var enemyScene : PackedScene

func _ready():
	var player = playerScene.instantiate()
	player.name = "PC01"
	player.position = $SpawnPlayerMarker2D.position
	add_child(player)
	var enemy = enemyScene.instantiate()
	enemy.name = "EC01"
	enemy.position = $SpawnEnemyMarker2D.position
	add_child(enemy)

