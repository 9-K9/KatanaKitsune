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


## One whole footprint along each tile axis, in pixels.
func _footprint_step() -> Vector2:
	var probe := room_scene.instantiate()
	var ground := probe.get_node_or_null("TileMap/Ground") as TileMapLayer
	var step := Vector2.ZERO
	if ground != null:
		var size: Vector2i = ground.get_used_rect().size + spacing
		var origin: Vector2 = ground.map_to_local(Vector2i.ZERO)
		step = Vector2(
			ground.map_to_local(Vector2i(size.x, 0)).x - origin.x,
			ground.map_to_local(Vector2i(0, size.y)).y - origin.y)
	probe.free()
	return step
