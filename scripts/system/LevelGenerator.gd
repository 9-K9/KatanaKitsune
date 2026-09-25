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
@export var room_min: Vector2i = Vector2i(9, 9)
@export var room_max: Vector2i = Vector2i(16, 14)
## Spacing between grid cells, in tiles. Must exceed room_max or rooms collide.
@export var cell_size: Vector2i = Vector2i(22, 20)
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
			rng.randi_range(room_min.x, room_max.x),
			rng.randi_range(room_min.y, room_max.y))
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


## Tile indices in the PixelLab building kit, by the role its placement rules
## give them. The kit is packed 8 to a row, so index -> atlas coords is
## Vector2i(i % 8, i / 8).
const KIT_FLOOR := 0
## Interchangeable flagstone variants, so a big room is not one repeated tile.
const KIT_FLOOR_VARIANTS := [0, 56, 57]
## Walls all round: a solid block with no open face. Used for every wall cell.
##
## The kit's single-face slabs (1-4) and L-corners (9-12) would give prettier
## edges, but they are thin, and any cell whose mapping is wrong leaves a gap
## the player can see through — or walk through. The first attempt fell back to
## the pillar piece for cells that only touch floor diagonally and the whole
## ring came out as a picket fence. A solid block reads as a proper dungeon
## wall and cannot gap.
const KIT_WALL := 53
const KIT_COLS := 8

static func kit_atlas(index: int) -> Vector2i:
	return Vector2i(index % KIT_COLS, index / KIT_COLS)


## Paints `layout` onto the map's layers. `ground` gets a floor tile per walkable
## cell; `walls` gets the wall piece whose open sides face the floor, which is
## also where the tileset's collision comes from.
func paint(layout: Layout, ground: TileMapLayer, walls: TileMapLayer, source_id: int,
		seed_value: int = 0) -> void:
	ground.clear()
	walls.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for cell in layout.floor_cells:
		var variant: int = KIT_FLOOR_VARIANTS[rng.randi_range(0, KIT_FLOOR_VARIANTS.size() - 1)]
		ground.set_cell(cell, source_id, kit_atlas(variant))

	## The wall ring: every neighbour of a floor cell that is not itself floor.
	## Diagonals are included so corners are sealed and nothing slips through.
	var ring: Dictionary = {}
	for cell in layout.floor_cells:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n: Vector2i = cell + Vector2i(dx, dy)
				if not layout.floor_cells.has(n):
					ring[n] = true

	for cell in ring:
		walls.set_cell(cell, source_id, kit_atlas(KIT_WALL))
