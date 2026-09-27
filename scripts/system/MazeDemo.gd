extends Node2D

## Walkable demo: tiles room_A across the diamond lattice, knocks walls out to
## make a maze, and drops the player in with a camera that follows.
##
## Placement matches RoomStackTest — every half-step position on the lattice, so
## the rooms interlock rather than sitting on a checkerboard.

@export var room_scene: PackedScene = null
@export var player_scene: PackedScene = null
@export var enemy_scenes: Array[PackedScene] = []
@export var prop_scenes: Array[PackedScene] = []
@export var grid: Vector2i = Vector2i(4, 4)
## Roofs make the layout unreadable while testing; off by default here.
@export var show_roofs: bool = false
@export var maze_seed: int = 0
## Chance an interior wall is knocked through. Higher is more open.
@export_range(0.0, 1.0) var openness: float = 0.35

@export_group("Population")
@export var enemies_per_room: Vector2i = Vector2i(0, 2)
@export var props_per_room: Vector2i = Vector2i(1, 3)

@export_group("Atmosphere")
## Near-black, so the player's lantern and the braziers do the lighting.
@export var gloom: Color = Color(0.18, 0.17, 0.26)
@export var lantern_radius: float = 2.6
@export var lantern_colour: Color = Color(1.0, 0.82, 0.55)

const SIDES: Array[String] = ["NE", "NW", "SE", "SW"]
## Which lattice step each side faces. Derived by eye from the rendered lattice;
## if a passage ever lines up with solid stone, this is the table to correct.
const NEIGHBOUR := {
	"NE": Vector2i(0, -1),
	"SW": Vector2i(0, 1),
	"SE": Vector2i(1, 0),
	"NW": Vector2i(-1, 0),
}

var _rng := RandomNumberGenerator.new()
var _rooms: Dictionary = {}


func _ready() -> void:
	if room_scene == null:
		push_warning("MazeDemo: no room_scene set.")
		return
	_rng.seed = maze_seed if maze_seed != 0 else randi()

	var step := _lattice_step()
	for iy in grid.y:
		for ix in grid.x:
			var cell := Vector2i(ix, iy)
			var room = room_scene.instantiate()
			room.name = "Room_%d_%d" % [ix, iy]
			add_child(room)
			room.position = Vector2(step.x * ix * 0.5, step.y * iy * 0.5)
			## Every room carries a CanvasModulate; several stacked just fight.
			var light: Node = room.get_node_or_null("Lighting")
			if light:
				light.free()
			if not show_roofs:
				var roofs: Node = room.get_node_or_null("TileMap/Roofs")
				if roofs:
					roofs.queue_free()
			_rooms[cell] = room

	_carve()
	_spawn_player(step)
	_populate(step)
	_light()


## Drops monsters and breakables into the rooms. The room the player starts in
## is left clear so she is not swung at before taking a step.
func _populate(step: Vector2) -> void:
	var start := Vector2i((grid.x - 1) / 2, (grid.y - 1) / 2)
	for cell in _rooms:
		var here: Node2D = _rooms[cell]
		if not enemy_scenes.is_empty() and cell != start:
			var n: int = _rng.randi_range(enemies_per_room.x, enemies_per_room.y)
			for i in n:
				_place(here, enemy_scenes[_rng.randi_range(0, enemy_scenes.size() - 1)])
		if not prop_scenes.is_empty():
			var m: int = _rng.randi_range(props_per_room.x, props_per_room.y)
			for i in m:
				_place(here, prop_scenes[_rng.randi_range(0, prop_scenes.size() - 1)])


## Puts one thing on a random floor tile of `room`, so nothing lands in a wall
## or out in the void.
func _place(room: Node2D, scene: PackedScene) -> void:
	if scene == null:
		return
	var ground := room.get_node_or_null("TileMap/Ground") as TileMapLayer
	if ground == null:
		return
	var cells := ground.get_used_cells()
	if cells.is_empty():
		return
	var thing = scene.instantiate()
	add_child(thing)
	thing.global_position = ground.to_global(
		ground.map_to_local(cells[_rng.randi_range(0, cells.size() - 1)]))


## Drops the whole floor into gloom and gives the player a lantern, so the maze
## is lit by what she carries rather than being evenly visible everywhere.
func _light() -> void:
	var tint := CanvasModulate.new()
	tint.name = "Gloom"
	tint.color = gloom
	add_child(tint)

	var player := _player_body()
	if player == null:
		return
	var lamp := PointLight2D.new()
	lamp.name = "Lantern"
	lamp.texture = _glow()
	lamp.color = lantern_colour
	lamp.energy = 1.5
	lamp.texture_scale = lantern_radius
	## Sits at her torso, not her feet, or the pool reads as lighting the floor
	## behind her rather than travelling with her.
	lamp.position = Vector2(0, -40)
	player.add_child(lamp)


## A soft round falloff, built rather than shipped as an asset.
func _glow() -> GradientTexture2D:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = ramp
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


func _player_body() -> Node2D:
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D:
			return node
	return null


## Carves the maze. A randomised depth-first spanning tree first, so every room
## is reachable from every other, then extra walls knocked through on top to add
## loops and open the place up.
##
## Purely random walls left rooms sealed off with no way in, which read as a
## maze that was simply too tight.
func _carve() -> void:
	var walls: Dictionary = {}          ## Vector2i cell -> {side: closed}
	for cell in _rooms:
		walls[cell] = {}
		for side in SIDES:
			walls[cell][side] = true

	## Spanning tree.
	var visited: Dictionary = {Vector2i.ZERO: true}
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	while stack.size() > 0:
		var cell: Vector2i = stack[-1]
		var options: Array[String] = []
		for side in SIDES:
			var other: Vector2i = cell + NEIGHBOUR[side]
			if _rooms.has(other) and not visited.has(other):
				options.append(side)
		if options.is_empty():
			stack.pop_back()
			continue
		var side: String = options[_rng.randi_range(0, options.size() - 1)]
		var next: Vector2i = cell + NEIGHBOUR[side]
		_open_pair(walls, cell, side)
		visited[next] = true
		stack.append(next)

	## Extra openings for loops, so it is not a pure tree with one route.
	for cell in _rooms:
		for side in SIDES:
			if not _rooms.has(cell + NEIGHBOUR[side]):
				continue
			if _rng.randf() < openness:
				_open_pair(walls, cell, side)

	for cell in _rooms:
		var room = _rooms[cell]
		if not room.has_method("set_side"):
			continue
		for side in SIDES:
			room.set_side(side, walls[cell][side])


## Opens a wall from both sides. A shared wall is two layers, one in each room,
## and leaving the other closed blocks the passage from one direction only.
func _open_pair(walls: Dictionary, cell: Vector2i, side: String) -> void:
	var other: Vector2i = cell + NEIGHBOUR[side]
	if not walls.has(other):
		return
	walls[cell][side] = false
	for back in SIDES:
		if other + NEIGHBOUR[back] == cell:
			walls[other][back] = false


func _spawn_player(step: Vector2) -> void:
	if player_scene == null:
		return
	var player = player_scene.instantiate()
	add_child(player)
	## Middle of the lattice, so there is maze in every direction.
	player.global_position = Vector2(
		step.x * 0.5 * (grid.x - 1) * 0.5,
		step.y * 0.5 * (grid.y - 1) * 0.5)

	var cam := Camera2D.new()
	cam.name = "FollowCamera"
	player.add_child(cam)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.zoom = Vector2(1.0, 1.0)
	cam.make_current()


## One whole room along each isometric axis, in pixels.
func _lattice_step() -> Vector2:
	var probe = room_scene.instantiate()
	var ground := probe.get_node_or_null("TileMap/Ground") as TileMapLayer
	var step := Vector2.ZERO
	if ground != null:
		var umin := 1 << 30
		var umax := -(1 << 30)
		var vmin := 1 << 30
		var vmax := -(1 << 30)
		for c in ground.get_used_cells():
			umin = mini(umin, c.x - c.y)
			umax = maxi(umax, c.x - c.y)
			vmin = mini(vmin, c.x + c.y)
			vmax = maxi(vmax, c.x + c.y)
		step = Vector2(
			float(umax - umin + 1) * ground.tile_set.tile_size.x * 0.5,
			float(vmax - vmin + 1) * ground.tile_set.tile_size.y * 0.5)
	probe.free()
	return step
