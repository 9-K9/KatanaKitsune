extends Node2D

## Walkable demo: tiles room_A across the diamond lattice, knocks walls out to
## make a maze, and drops the player in with a camera that follows.
##
## Placement matches RoomStackTest — every half-step position on the lattice, so
## the rooms interlock rather than sitting on a checkerboard.

@export var room_scene: PackedScene = null
@export var player_scene: PackedScene = null
@export var grid: Vector2i = Vector2i(4, 4)
@export var maze_seed: int = 0
## Chance an interior wall is knocked through. Higher is more open.
@export_range(0.0, 1.0) var openness: float = 0.55

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
			_rooms[cell] = room

	_carve()
	_spawn_player(step)


## Knocks out walls between neighbours. A wall is only opened if the room on the
## other side opens its matching wall too, or one side stays solid and the
## passage is blocked from exactly one direction.
func _carve() -> void:
	for cell in _rooms:
		var room = _rooms[cell]
		if not room.has_method("set_side"):
			continue
		for side in SIDES:
			var other: Vector2i = cell + NEIGHBOUR[side]
			if not _rooms.has(other):
				## Outer edge: keep the maze sealed.
				room.set_side(side, true)
				continue
			## Deterministic per wall pair, so both rooms agree without one
			## having to look up what the other already decided.
			var pair := Vector2i(mini(cell.x, other.x), mini(cell.y, other.y))
			var h: int = hash([pair, cell + other, maze_seed])
			room.set_side(side, float(h % 1000) / 1000.0 > openness)


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
