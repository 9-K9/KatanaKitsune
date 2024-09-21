extends Node2D
@export var npcScene : PackedScene
@onready var tileRoof = $TileMap/Roofs
@onready var tileFrontWalls = $TileMap/FrontWalls

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

## Control Visibility and Modulation when player group enter area2d
# Check Roof Area
func _on_area_2d_area_entered(area):
	if area.is_in_group("playerRoofCheck"):
		tileRoof.visible = false
func _on_area_2d_area_exited(area):
	if area.is_in_group("playerRoofCheck"):
		tileRoof.visible = true
#Check Front Walls Area
func _on_walls_check_player_area_entered(area):
	if area.is_in_group("playerWallCheck"):
		tileFrontWalls.modulate = Color("black",0.5)
func _on_walls_check_player_area_exited(area):
	if area.is_in_group("playerWallCheck"):
		tileFrontWalls.modulate = Color("white",1.0)
