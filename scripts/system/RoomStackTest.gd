@tool
extends Node2D

## Dev scene: tiles copies of a room prefab to check they abut cleanly.
##
## Runs in the editor, so changing the room and pressing Rebuild shows the
## result without playing. The copies are added without an owner, so they are
## never saved into this scene — it stays a handful of lines on disk.
##
## Offsets come from the room's own Ground layer, so a prefab that is resized
## keeps tiling correctly with no numbers to update here.

@export var room_scene: PackedScene = null:
	set(value):
		room_scene = value
		_rebuild()

@export var grid: Vector2i = Vector2i(2, 2):
	set(value):
		grid = Vector2i(maxi(1, value.x), maxi(1, value.y))
		_rebuild()

## Gap between rooms, in tiles. Zero butts them straight up against each other;
## raise it to leave room for a corridor.
@export var spacing: Vector2i = Vector2i.ZERO:
	set(value):
		spacing = value
		_rebuild()

## Every copy carries its own CanvasModulate, and several stacked just fight
## each other. Off by default so the tint matches the real game.
@export var keep_lighting: bool = false:
	set(value):
		keep_lighting = value
		_rebuild()

@export var rebuild: bool = false:
	set(_value):
		rebuild = false
		_rebuild()

const HOLDER := "Stacked"


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var holder := get_node_or_null(HOLDER)
	if holder:
		holder.free()
	holder = Node2D.new()
	holder.name = HOLDER
	holder.y_sort_enabled = true
	add_child(holder)

	if room_scene == null:
		return

	var step := _footprint_step()
	if step == Vector2.ZERO:
		push_warning("RoomStackTest: %s has no TileMap/Ground to measure." % room_scene.resource_path)
		return

	for iy in grid.y:
		for ix in grid.x:
			var room := room_scene.instantiate()
			room.name = "Room_%d_%d" % [ix, iy]
			holder.add_child(room)
			room.position = Vector2(step.x * ix, step.y * iy)
			if not keep_lighting:
				var light: Node = room.get_node_or_null("Lighting")
				if light:
					light.free()


## One whole footprint along each ISOMETRIC axis, in pixels.
##
## Measured on u = x-y and v = x+y, the screen's own axes, rather than on the
## tile rect. An isometric room is a diamond in tile coordinates, so stepping by
## its tile bounding box lands neighbours corner-to-corner and leaves diagonal
## gaps. Stepping along u and v moves a whole room screen-right or screen-down,
## which is how these rooms actually abut.
func _footprint_step() -> Vector2:
	var probe := room_scene.instantiate()
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
		## Half a tile wide and half a tile tall per unit of u and v.
		step = Vector2(
			float(umax - umin + 1 + spacing.x) * ground.tile_set.tile_size.x * 0.5,
			float(vmax - vmin + 1 + spacing.y) * ground.tile_set.tile_size.y * 0.5)
	probe.free()
	return step
