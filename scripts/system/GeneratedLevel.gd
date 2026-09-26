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
@export var trap_scene: PackedScene = null
@export var exit_scene: PackedScene = null

@export_group("Density")
## Enemies per room, excluding the room the player starts in.
@export var enemies_per_room: Vector2i = Vector2i(1, 3)
@export var props_per_room: Vector2i = Vector2i(2, 5)
## Fraction of corridor tiles that become spike traps.
@export var trap_density: float = 0.06

@onready var ground: TileMapLayer = $TileMap/Ground
@onready var walls: TileMapLayer = $TileMap/Walls
@onready var contents: Node2D = $Contents

## How deep the run has gone. Drives difficulty and is shown on the HUD.
var depth: int = 1
var layout: LevelGenerator.Layout = null
var _rng := RandomNumberGenerator.new()
var _player: Node2D = null


func _ready() -> void:
	if randomise_seed:
		level_seed = randi()
	_build()


## Regenerates the floor in place rather than reloading the scene. Akane keeps
## her health, her buffs and her state machine across the descent, which a
## scene reload would throw away.
func descend() -> void:
	depth += 1
	level_seed = _rng.randi()
	for child in contents.get_children():
		if child != _player:
			child.queue_free()
	_build()


func _build() -> void:
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
	## Spawned once and carried down; on later floors it is only moved.
	if _player == null and player_scene != null:
		_player = player_scene.instantiate()
		contents.add_child(_player)
	if is_instance_valid(_player):
		_player.global_position = tile_to_world(layout.start_room.centre())

	## Each floor down adds roughly one more monster per room.
	var extra: int = depth - 1
	for room in layout.rooms:
		## The start room is left clear so the player is not swung at before
		## they have taken a step.
		if room != layout.start_room:
			_fill(room, enemy_scenes,
				_rng.randi_range(enemies_per_room.x, enemies_per_room.y) + extra)
		_fill(room, prop_scenes, _rng.randi_range(props_per_room.x, props_per_room.y))

	_place_traps()
	_place_exit()


func _place_exit() -> void:
	if exit_scene == null:
		return
	var stairs = exit_scene.instantiate()
	contents.add_child(stairs)
	stairs.global_position = tile_to_world(layout.exit_room.centre())
	## Deferred: descend() frees the whole floor and repaints the tilemaps, and
	## the signal fires from inside body_entered, mid-physics.
	stairs.descended.connect(descend, CONNECT_DEFERRED)


## Traps go in corridors, never in rooms: a corridor is the one place the player
## cannot simply walk around them, which is what makes them a decision rather
## than scenery. Neighbours are staggered along the cycle so a run of traps
## rolls as a wave instead of firing as one slab.
func _place_traps() -> void:
	if trap_scene == null:
		return
	var in_room: Dictionary = {}
	for room in layout.rooms:
		for y in range(room.rect.position.y, room.rect.end.y):
			for x in range(room.rect.position.x, room.rect.end.x):
				in_room[Vector2i(x, y)] = true

	var corridor: Array[Vector2i] = []
	for cell in layout.floor_cells:
		if not in_room.has(cell):
			corridor.append(cell)
	corridor.sort()

	var wanted: int = int(corridor.size() * trap_density)
	for i in wanted:
		var cell: Vector2i = corridor[_rng.randi_range(0, corridor.size() - 1)]
		var trap = trap_scene.instantiate()
		trap.phase_offset = _rng.randf() * trap.period
		contents.add_child(trap)
		trap.global_position = tile_to_world(cell)


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
