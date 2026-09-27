extends Node2D
@export var npcScene : PackedScene
@onready var tileRoof = $TileMap/Roofs
@onready var tileFrontWalls = $TileMap/FrontWalls

##Spawn NPC from out of scene, e.g enemies
func _ready():
	if npcScene:
		var enemy = npcScene.instantiate()
		enemy.name = "NPC01"
		add_child(enemy)
		## global, not local: the marker lives under TileMap while the enemy is
		## parented here, so copying the raw position crossed coordinate spaces.
		enemy.global_position = nearest_floor($TileMap/SpawnNPCMarker2D.global_position)


## Nearest walkable tile to `world_pos`, searching outward in rings.
##
## The spawn marker sits on a cell with no ground tile under it, so the monster
## stood out in the void beside the room. Snapping means a marker only has to be
## roughly right, and anything else placing things on the floor can reuse this.
func nearest_floor(world_pos: Vector2) -> Vector2:
	var ground: TileMapLayer = $TileMap/Ground
	var start: Vector2i = ground.local_to_map(ground.to_local(world_pos))
	if ground.get_cell_source_id(start) != -1:
		return world_pos
	for radius in range(1, 48):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				## Ring only; the interior was covered by smaller radii.
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var cell: Vector2i = start + Vector2i(dx, dy)
				if ground.get_cell_source_id(cell) != -1:
					return ground.to_global(ground.map_to_local(cell))
	push_warning("YsortPlayerSpawn: no floor near %s" % world_pos)
	return world_pos

## Loop Music
func _on_audio_stream_player_2d_finished():
	$Ambience/AudioStreamPlayer2D.play()

## Control Visibility and Modulation when player group enter area2d
# Check Roof Area
## Superseded by WallFade.gd in HIDE mode on the Roofs layer, which asks the
## tilemap whether anything is actually overhead. This fired off a hand-drawn
## polygon that only covered part of the map, so the roof stayed solid
## everywhere else. Kept as no-ops because the scene still connects to them.
func _on_area_2d_area_entered(_area):
	pass
func _on_area_2d_area_exited(_area):
	pass
#Check Front Walls Area
## Superseded by wallFade.gdshader on the FrontWalls layer, which fades only the
## stretch of wall actually covering the player. These handlers dimmed every
## front wall at once and only fired inside one hand-drawn polygon, so standing
## anywhere else left the player hidden behind solid stone. Kept as no-ops
## because the scene still connects to them.
func _on_walls_check_player_area_entered(_area):
	pass
func _on_walls_check_player_area_exited(_area):
	pass
