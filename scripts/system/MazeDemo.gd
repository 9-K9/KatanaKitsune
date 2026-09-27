extends Node2D

## Walkable demo: tiles room_A across the diamond lattice, knocks walls out to
## make a maze, and drops the player in with a camera that follows.
##
## Rooms sit on the isometric lattice, each neighbour half a room across and
## half a room down, so their diamonds interlock exactly — see
## _lattice_position. Openings are knocked through from both sides, which turns
## a run of rooms into one continuous space rather than a corridor.

@export var room_scene: PackedScene = null
@export var player_scene: PackedScene = null
@export var enemy_scenes: Array[PackedScene] = []
@export var prop_scenes: Array[PackedScene] = []
@export var exit_scene: PackedScene = null
## Stood at the ends of every opening and spaced across it, so a knocked-out
## wall reads as a deliberate colonnade instead of a severed run of stone.
@export var pillar_scene: PackedScene = null
@export var grid: Vector2i = Vector2i(4, 4)
## Roofs make the layout unreadable while testing; off by default here.
@export var show_roofs: bool = false
@export var maze_seed: int = 0
## Chance an interior wall is knocked through. Higher is more open.
@export_range(0.0, 1.0) var openness: float = 0.35

@export_group("Population")
@export var enemies_per_room: Vector2i = Vector2i(0, 2)
@export var props_per_room: Vector2i = Vector2i(1, 3)
## Columns spaced between the two that flank each opening.
@export var pillars_per_opening: int = 3

@export_group("Atmosphere")
## Near-black, so the player's lantern and the braziers do the lighting.
@export var gloom: Color = Color(0.18, 0.17, 0.26)
@export var lantern_radius: float = 2.6
@export var lantern_colour: Color = Color(1.0, 0.82, 0.55)

const SIDES: Array[String] = ["NE", "NW", "SE", "SW"]
## Which lattice step each side faces. This follows from the isometric transform
## rather than from looking at a render: +x moves right and down, which is SE,
## and +y moves left and down, which is SW.
const NEIGHBOUR := {
	"NE": Vector2i(0, -1),
	"SW": Vector2i(0, 1),
	"SE": Vector2i(1, 0),
	"NW": Vector2i(-1, 0),
}

var _rng := RandomNumberGenerator.new()
var _rooms: Dictionary = {}
## How deep the run has gone. HUD reads this; each floor adds monsters.
var depth: int = 1
var _player: Node2D = null


func _ready() -> void:
	if room_scene == null:
		push_warning("MazeDemo: no room_scene set.")
		return
	if maze_seed == 0:
		maze_seed = randi()
	_build()


## Next floor. Rebuilds around the player rather than reloading the scene, so
## she keeps her health, her buffs and her state machine across the descent —
## a reload would construct a fresh one and throw all of that away.
func descend() -> void:
	depth += 1
	maze_seed = _rng.randi()
	for child in get_children():
		## The player, the gloom and the HUD layers outlive a floor.
		if child == _player or child is CanvasLayer or child is CanvasModulate:
			continue
		child.queue_free()
	_rooms.clear()
	_build()


func _build() -> void:
	_rng.seed = maze_seed
	var step := _lattice_step()
	for iy in grid.y:
		for ix in grid.x:
			var cell := Vector2i(ix, iy)
			var room = room_scene.instantiate()
			room.name = "Room_%d_%d" % [ix, iy]
			add_child(room)
			room.position = _lattice_position(cell, step)
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
	_place_pillars()
	_spawn_player(step)
	_populate(step)
	_place_exit()
	_light()


## The stairs go in whichever room is furthest from the start, measured through
## the maze rather than across it, so the exit is a walk and not a room away.
func _place_exit() -> void:
	if exit_scene == null:
		return
	var start := Vector2i((grid.x - 1) / 2, (grid.y - 1) / 2)
	var far: Vector2i = start
	var best: int = -1
	var seen: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	while queue.size() > 0:
		var cell: Vector2i = queue.pop_front()
		if seen[cell] > best:
			best = seen[cell]
			far = cell
		var room = _rooms.get(cell)
		if room == null or not room.has_method("open_sides"):
			continue
		for side in room.open_sides():
			var next: Vector2i = cell + NEIGHBOUR[side]
			if _rooms.has(next) and not seen.has(next):
				seen[next] = seen[cell] + 1
				queue.append(next)

	var stairs = exit_scene.instantiate()
	add_child(stairs)
	var ground := (_rooms[far] as Node2D).get_node("TileMap/Ground") as TileMapLayer
	stairs.global_position = ground.to_global(ground.map_to_local(
		ground.get_used_rect().position + ground.get_used_rect().size / 2))
	## Deferred: descend() frees the whole floor and the signal fires from
	## inside body_entered, mid-physics.
	stairs.descended.connect(descend, CONNECT_DEFERRED)


## Drops monsters and breakables into the rooms. The room the player starts in
## is left clear so she is not swung at before taking a step.
func _populate(step: Vector2) -> void:
	var start := Vector2i((grid.x - 1) / 2, (grid.y - 1) / 2)
	for cell in _rooms:
		var here: Node2D = _rooms[cell]
		if not enemy_scenes.is_empty() and cell != start:
			var n: int = _rng.randi_range(enemies_per_room.x, enemies_per_room.y) + depth - 1
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
	if not has_node("Gloom"):
		var tint := CanvasModulate.new()
		tint.name = "Gloom"
		tint.color = gloom
		add_child(tint)

	var player := _player_body()
	if player == null or player.has_node("Lantern"):
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
	## Spawned once and carried down; later floors only move her.
	var player := _player
	if player == null:
		player = player_scene.instantiate()
		add_child(player)
		_player = player
	## Middle of the lattice, so there is maze in every direction.
	player.global_position = Vector2(
		step.x * 0.5 * (grid.x - 1) * 0.5,
		step.y * 0.5 * (grid.y - 1) * 0.5)

	if player.has_node("FollowCamera"):
		return
	var cam := Camera2D.new()
	cam.name = "FollowCamera"
	player.add_child(cam)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.zoom = Vector2(1.0, 1.0)
	cam.make_current()


## One whole room along each isometric axis, in pixels.
## Stands a pillar at each end of every opening, and spaces more across it.
##
## Knocking a wall out leaves the runs either side of it stopping in mid-air,
## showing their cut faces. Framing the gap with columns reads as architecture
## that was always meant to have an opening there, rather than a wall someone
## removed — and it costs a prop instead of a new tile set and door logic.
##
## The opening's own wall layer is disabled but still holds its tiles, so it
## describes exactly where the gap is; no geometry has to be inferred.
## Closest two columns may stand. Each footprint is 44 across and she is 66, so
## this leaves at least 106 of clear floor to walk through.
const MIN_GAP: float = 150.0


func _place_pillars() -> void:
	if pillar_scene == null:
		return
	## Both rooms either side of an opening describe the same gap, so each would
	## otherwise stand its own column there. Spacing is enforced by distance and
	## not by snapping to a grid: a grid still lets two columns land a few pixels
	## apart, and anything tighter than MIN_GAP is a doorway she cannot fit
	## through — her collision diamond is 66 across and a column's is 44.
	var placed: Array[Vector2] = []
	for cell in _rooms:
		var room: Node2D = _rooms[cell]
		if not room.has_method("open_sides"):
			continue
		for side in room.open_sides():
			var layer := room.get_node_or_null("TileMap/Walls_" + side) as TileMapLayer
			if layer == null:
				continue
			var cells: Array[Vector2i] = layer.get_used_cells()
			if cells.is_empty():
				continue
			## Along the gap, so "first" and "last" are its two ends.
			cells.sort_custom(func(a, b): return a.x + a.y < b.x + b.y)
			var wanted: Array[int] = [0, cells.size() - 1]
			var stride: int = maxi(int(cells.size() / float(pillars_per_opening + 1)), 1)
			for i in range(stride, cells.size() - 1, stride):
				wanted.append(i)
			for i in wanted:
				var world: Vector2 = layer.to_global(layer.map_to_local(cells[i]))
				var crowded := false
				for other in placed:
					if other.distance_to(world) < MIN_GAP:
						crowded = true
						break
				if crowded:
					continue
				placed.append(world)
				var pillar := pillar_scene.instantiate()
				pillar.name = "Pillar_%d_%d_%s_%d" % [cell.x, cell.y, side, i]
				add_child(pillar)
				(pillar as Node2D).global_position = world


## Where a grid cell sits on screen.
##
## The isometric lattice, not a grid of half-steps. A room's footprint is a
## diamond, and diamonds only interlock when each neighbour sits half a width
## across AND half a height down — moving in one axis alone slides a room
## halfway over its neighbour, which is what used to happen here.
##
## In tile terms this is exactly one room per step: +ix advances the room's own
## cell block by its width, +iy by its height, so floors abut with no seam and
## no shared cells. That also derives NEIGHBOUR rather than leaving it read off
## a render — +ix goes right and down (SE), +iy goes left and down (SW), and
## their negatives are NW and NE.
func _lattice_position(cell: Vector2i, step: Vector2) -> Vector2:
	return Vector2(
		float(cell.x - cell.y) * step.x * 0.5,
		float(cell.x + cell.y) * step.y * 0.5)


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
		## The diamond's full screen width and height: the span between the
		## outermost tile centres, plus the one whole tile hanging off each end.
		## This used to add a single tile rather than two, so every room was
		## measured one tile short and the lattice pulled itself inwards.
		step = Vector2(
			float(umax - umin + 2) * ground.tile_set.tile_size.x * 0.5,
			float(vmax - vmin + 2) * ground.tile_set.tile_size.y * 0.5)
	probe.free()
	return step
