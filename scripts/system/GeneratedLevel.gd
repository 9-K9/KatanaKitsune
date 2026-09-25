extends Node2D

## Builds a floor at load time and places everything that lives on it.
##
## Sits on the map root in place of a hand-built YSortMap. The tile work is in
## LevelGenerator; this is the part that knows about the game.

@export var level_seed: int = 0
## Leave at 0 to reroll every run.
@export var randomise_seed: bool = true

@export_group("Scenes")
@export var player_scene: PackedScene = null
@export var enemy_scenes: Array[PackedScene] = []
@export var prop_scenes: Array[PackedScene] = []

@export_group("Density")
## Enemies per room, excluding the room the player starts in.
@export var enemies_per_room: Vector2i = Vector2i(1, 3)
@export var props_per_room: Vector2i = Vector2i(2, 5)

@onready var ground: TileMapLayer = $TileMap/Ground
@onready var walls: TileMapLayer = $TileMap/Walls
@onready var contents: Node2D = $Contents

var layout: LevelGenerator.Layout = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if randomise_seed:
		level_seed = randi()
	_rng.seed = level_seed

	var gen := LevelGenerator.new()
	layout = gen.generate(level_seed)
	## Source 0 is the only source in dungeonKit.tres.
	gen.paint(layout, ground, walls, 0, level_seed)

	_populate()


## Centre of a tile in world space. The tilemap owns the isometric maths, so
## ask it rather than reimplementing the projection.
func tile_to_world(cell: Vector2i) -> Vector2:
	return ground.to_global(ground.map_to_local(cell))


func _populate() -> void:
	var player: Node2D = null
	if player_scene != null:
		player = player_scene.instantiate()
		contents.add_child(player)
		player.global_position = tile_to_world(layout.start_room.centre())

	for room in layout.rooms:
		## The start room is left clear so the player is not swung at before
		## they have taken a step.
		if room != layout.start_room:
			_fill(room, enemy_scenes, _rng.randi_range(enemies_per_room.x, enemies_per_room.y))
		_fill(room, prop_scenes, _rng.randi_range(props_per_room.x, props_per_room.y))


func _fill(room: LevelGenerator.Room, pool: Array[PackedScene], count: int) -> void:
	if pool.is_empty():
		return
	for i in count:
		var scene: PackedScene = pool[_rng.randi_range(0, pool.size() - 1)]
		if scene == null:
			continue
		var thing := scene.instantiate()
		contents.add_child(thing)
		thing.global_position = tile_to_world(room.spot(_rng))
