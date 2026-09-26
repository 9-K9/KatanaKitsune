class_name LevelGenerator
extends RefCounted

## Builds a floor of rectangular rooms joined by L-shaped corridors, then paints
## it onto the map's existing TileMapLayers.
##
## The layout is produced in tile coordinates and handed back as a Layout, so
## the caller can place the player, the exit, enemies and props from the same
## room list the geometry came from.

## A room in tile coordinates. `rect` covers the walkable floor; the wall ring
## sits just outside it.
class Room:
	var rect: Rect2i
	var index: int
	func _init(r: Rect2i, i: int) -> void:
		rect = r
		index = i
	func centre() -> Vector2i:
		return rect.position + rect.size / 2
	## Somewhere inside the room with a one-tile margin, so nothing spawns
	## flush against a wall where the player cannot reach around it.
	func spot(rng: RandomNumberGenerator) -> Vector2i:
		return Vector2i(
			rng.randi_range(rect.position.x + 1, rect.end.x - 2),
			rng.randi_range(rect.position.y + 1, rect.end.y - 2))


class Layout:
	var rooms: Array[Room] = []
	var floor_cells: Dictionary = {}   ## Vector2i -> true
	var start_room: Room = null
	var exit_room: Room = null


## Rooms are placed one per cell of this grid, jittered inside it.
@export var grid: Vector2i = Vector2i(3, 3)
@export var room_min: Vector2i = Vector2i(16, 16)
@export var room_max: Vector2i = Vector2i(24, 24)
## Spacing between grid cells, in tiles. Must exceed room_max or rooms collide.
@export var cell_size: Vector2i = Vector2i(32, 32)
## Corridors are this many tiles wide. Three keeps Akane's collision box clear
## of both walls at once.
@export var corridor_width: int = 3


func generate(seed_value: int) -> Layout:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var layout := Layout.new()

	## One room per grid cell, skipping a few so the floor is not a lattice.
	var slots: Array[Vector2i] = []
	for y in grid.y:
		for x in grid.x:
			slots.append(Vector2i(x, y))
	var wanted: int = maxi(4, slots.size() - rng.randi_range(1, 3))

	var placed: Array[Vector2i] = []
	while placed.size() < wanted and slots.size() > 0:
		placed.append(slots.pop_at(rng.randi_range(0, slots.size() - 1)))
	placed.sort()

	for slot in placed:
		var size := Vector2i(
			_snap(rng.randi_range(room_min.x, room_max.x)),
			_snap(rng.randi_range(room_min.y, room_max.y)))
		var origin := Vector2i(slot.x * cell_size.x, slot.y * cell_size.y)
		## Jitter inside the cell, keeping the room clear of the next cell over.
		origin += Vector2i(
			rng.randi_range(0, maxi(0, cell_size.x - size.x - 1)),
			rng.randi_range(0, maxi(0, cell_size.y - size.y - 1)))
		var room := Room.new(Rect2i(origin, size), layout.rooms.size())
		layout.rooms.append(room)
		_carve_rect(layout, room.rect)

	## Chain the rooms so every one is reachable, then add one loop so the floor
	## is not a pure corridor-tree.
	for i in range(1, layout.rooms.size()):
		_carve_corridor(layout, layout.rooms[i - 1].centre(), layout.rooms[i].centre())
	if layout.rooms.size() > 3:
		_carve_corridor(layout, layout.rooms[0].centre(), layout.rooms[-1].centre())

	layout.start_room = layout.rooms[0]
	layout.exit_room = layout.rooms[-1]
	return layout


## Rounds up to the wall stride.
func _snap(n: int) -> int:
	return int(ceil(float(n) / WALL_SEGMENT_CELLS)) * WALL_SEGMENT_CELLS


func _carve_rect(layout: Layout, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			layout.floor_cells[Vector2i(x, y)] = true


## L-shaped: run along x, then along y. Width is centred on the run.
func _carve_corridor(layout: Layout, from: Vector2i, to: Vector2i) -> void:
	var half: int = corridor_width / 2
	for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
		for w in range(-half, half + 1):
			layout.floor_cells[Vector2i(x, from.y + w)] = true
	for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
		for w in range(-half, half + 1):
			layout.floor_cells[Vector2i(to.x + w, y)] = true


## Crocotile floor sources, all interchangeable checkered flagstone.
const FLOOR_SOURCES := [0]

## Crocotile wall sources, by which edge of a room they close.
##
## These are not one-cell pieces: each is a single tile spanning 5x16 atlas
## cells, drawing a 4-cell-wide, ~350px-tall wall plane with its collision
## already authored. They come in the same dir1..dir8 rotation the character
## sprites use, and only the four that align with the tile axes are usable for
## room edges — dir2/dir6 render edge-on and dir4/dir8 face-on, which are the
## screen-aligned diagonals.
## A plane's collision spans x -96..+96, and one cell steps 24px horizontally,
## so each wall covers 8 cells along its axis and is CENTRED on the cell it is
## given rather than starting there. Placing them as if they started at the cell
## left them scattered half a plane off every edge.
const WALL_SEGMENT_CELLS := 8
const WALL_SOUTH_WEST := 1   ## closes the +Y edge
const WALL_NORTH_WEST := 3   ## closes the -X edge
const WALL_NORTH_EAST := 5   ## closes the -Y edge
const WALL_SOUTH_EAST := 7   ## closes the +X edge


## Paints `layout` onto the map. Floor goes on `ground`; walls are split across
## `back_walls` and `front_walls` so the near edges can be faded when the player
## walks behind them, exactly as the hand-built map does.
func paint(layout: Layout, ground: TileMapLayer, back_walls: TileMapLayer,
		front_walls: TileMapLayer, seed_value: int = 0) -> void:
	ground.clear()
	back_walls.clear()
	front_walls.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for cell in layout.floor_cells:
		var src: int = FLOOR_SOURCES[rng.randi_range(0, FLOOR_SOURCES.size() - 1)]
		ground.set_cell(cell, src, Vector2i(0, 0))

	for room in layout.rooms:
		_wall_edge(layout, room, Vector2i(0, -1), WALL_NORTH_EAST, back_walls)
		_wall_edge(layout, room, Vector2i(-1, 0), WALL_NORTH_WEST, back_walls)
		_wall_edge(layout, room, Vector2i(0, 1), WALL_SOUTH_WEST, front_walls)
		_wall_edge(layout, room, Vector2i(1, 0), WALL_SOUTH_EAST, front_walls)


## Runs along one edge of a room in 4-cell strides, dropping a wall plane on each
## stride whose outward neighbour is not floor. Strides that open onto floor are
## left bare, which is what turns a corridor junction into a doorway rather than
## a wall the player has to walk through.
func _wall_edge(layout: Layout, room: Room, outward: Vector2i, source: int,
		layer: TileMapLayer) -> void:
	var rect: Rect2i = room.rect
	## The row or column of floor cells that sits against this edge.
	var along := Vector2i(absi(outward.y), absi(outward.x))
	var start: Vector2i = rect.position
	if outward.x > 0:
		start.x = rect.end.x - 1
	if outward.y > 0:
		start.y = rect.end.y - 1

	var span: int = rect.size.y if outward.x != 0 else rect.size.x
	var half: int = WALL_SEGMENT_CELLS / 2
	var i: int = 0
	while i < span:
		## Anchor on the middle of this run, since the plane centres on its cell.
		var cell: Vector2i = start + along * (i + half)
		## Gate on the run's own cells: if any of them opens onto floor this is a
		## doorway, and walling it would seal the room off from its corridor.
		var open := false
		for k in range(i, mini(i + WALL_SEGMENT_CELLS, span)):
			if layout.floor_cells.has(start + along * k + outward):
				open = true
				break
		if not open:
			layer.set_cell(cell, source, Vector2i(0, 0))
		i += WALL_SEGMENT_CELLS
