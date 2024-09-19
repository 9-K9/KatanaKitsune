extends Node2D
@export var npcScene : PackedScene

##Spawn NPC from out of scene, e.g enemies
func _ready():
	if npcScene:
		var enemy = npcScene.instantiate()
		enemy.name = "NPC01"
		enemy.position = $TileMap/SpawnNPCMarker2D.position
		add_child(enemy)

## Loop Music
func _on_audio_stream_player_2d_finished():
	$Ambience/AudioStreamPlayer2D.play()
