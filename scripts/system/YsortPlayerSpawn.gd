extends Node2D
@export var pcScene : PackedScene
@export var npcScene : PackedScene

func _ready():
	if pcScene:
		var player = pcScene.instantiate()
		player.name = "PC01"
		player.position = $SpawnPCMarker2D.position
		add_child(player)
	if npcScene:
		var enemy = npcScene.instantiate()
		enemy.name = "NPC01"
		enemy.position = $SpawnNPCMarker2D.position
		add_child(enemy)

