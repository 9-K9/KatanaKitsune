class_name WorldStreamer
extends Node

## Puts the floor to sleep away from the screen and wakes it ahead of the party.
##
## A floor is twenty-five rooms, hundreds of props, dozens of torches and
## monsters, and nearly all of it is off screen at any moment. Godot already
## skips drawing what is off screen, but it still runs every script, animates
## every sprite, sorts every node and feeds every wall occluder to every light.
## This switches that work off outside a buffer around the view.
##
## Two edges, so nothing flickers at the boundary: things wake inside
## view + buffer and only sleep again past view + buffer + hysteresis.
##
## Walls keep their collision while asleep — a room is hidden, not removed — so
## nothing can walk through a sleeping room.

const INTERVAL: float = 0.2
## Moving things are tested by position; this is the room they take up.
const BODY_REACH: float = 192.0
## Walls draw well above the floor cells they stand on.
const WALL_REACH: float = 320.0

var buffer: float = 512.0
var hysteresis: float = 256.0
## Anything this close to a player along the ground stays awake regardless of
## the camera, for bots and for the moment before the camera catches up.
var player_reach: float = 900.0

var _maze: Node2D
var _left: float = 0.0
## [node, bounds, asleep] for every room.
var _rooms: Array = []
## [node, bounds, asleep] for every static prop, torch and fixture.
var _props: Array = []
## [node, asleep] for wandering things that are not monsters.
var _movers: Array = []


func setup(maze: Node2D, rooms: Array) -> void:
	_maze = maze
	for room in rooms:
		if room is Node2D:
			var bounds := _room_bounds(room)
			if bounds.has_area():
				_rooms.append([room, bounds, false])
	for child in maze.get_children():
		if child in rooms or not (child is Node2D) or child == self:
			continue
		if child.is_in_group("player") or child is EnemyBase \
				or child is TileMapLayer or child is Camera2D:
			continue
		if child is CharacterBody2D or child.has_method("_nearest_threat"):
			_movers.append([child, false])
			continue
		var bounds := _prop_bounds(child)
		if bounds.has_area():
			_props.append([child, bounds, false])


func wake_all() -> void:
	for entry in _rooms:
		if entry[2] and is_instance_valid(entry[0]):
			_sleep_room(entry[0], false)
			entry[2] = false
	for entry in _props:
		if entry[2] and is_instance_valid(entry[0]):
			_sleep_node(entry[0], false)
			entry[2] = false
	for entry in _movers:
		if entry[1] and is_instance_valid(entry[0]):
			_sleep_node(entry[0], false)
			entry[1] = false
	if _maze != null:
		for node in _maze.get_tree().get_nodes_in_group("enemy"):
			if node is EnemyBase:
				node.set_dormant(false)


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	_left = INTERVAL
	if _maze == null or _maze.get("_building") == true:
		return
	var crew := Roster.bodies(get_tree())
	var camera := get_viewport().get_camera_2d()
	if camera == null and crew.is_empty():
		return
	var view := Rect2()
	if camera != null:
		var size: Vector2 = get_viewport().get_visible_rect().size / camera.zoom
		view = Rect2(camera.get_screen_center_position() - size * 0.5, size)
	else:
		view = Rect2(crew[0].global_position, Vector2.ZERO)
	## Every player counts as on screen even before the camera has caught up.
	for body in crew:
		view = view.expand(body.global_position)
	var wake := view.grow(buffer)
	var keep := view.grow(buffer + hysteresis)

	for i in range(_rooms.size() - 1, -1, -1):
		var entry: Array = _rooms[i]
		if not is_instance_valid(entry[0]):
			_rooms.remove_at(i)
			continue
		var bounds: Rect2 = entry[1]
		var asleep: bool = not bounds.intersects(keep if not entry[2] else wake)
		if asleep != entry[2]:
			entry[2] = asleep
			_sleep_room(entry[0], asleep)

	for i in range(_props.size() - 1, -1, -1):
		var entry: Array = _props[i]
		if not is_instance_valid(entry[0]) or entry[0].is_queued_for_deletion():
			_props.remove_at(i)
			continue
		var bounds: Rect2 = entry[1]
		var asleep: bool = not bounds.intersects(keep if not entry[2] else wake)
		if asleep != entry[2]:
			entry[2] = asleep
			_sleep_node(entry[0], asleep)

	for i in range(_movers.size() - 1, -1, -1):
		var entry: Array = _movers[i]
		if not is_instance_valid(entry[0]) or entry[0].is_queued_for_deletion():
			_movers.remove_at(i)
			continue
		var asleep: bool = not _near((entry[0] as Node2D).global_position,
				keep if not entry[1] else wake, crew, entry[1])
		if asleep != entry[1]:
			entry[1] = asleep
			_sleep_node(entry[0], asleep)

	## Looked up every pass rather than listed once: monsters are summoned and
	## killed all through a floor.
	for node in get_tree().get_nodes_in_group("enemy"):
		if not (node is EnemyBase) or node.is_queued_for_deletion():
			continue
		var monster := node as EnemyBase
		monster.set_dormant(not _near(monster.global_position,
				keep if not monster.dormant else wake, crew, monster.dormant))


func _near(at: Vector2, area: Rect2, crew: Array[CharacterBody2D], asleep: bool) -> bool:
	if area.grow(BODY_REACH).has_point(at):
		return true
	var reach: float = player_reach if asleep else player_reach + hysteresis
	reach *= reach
	for body in crew:
		var gap: Vector2 = body.global_position - at
		gap.y *= 2.0
		if gap.length_squared() <= reach:
			return true
	return false


## Hidden rather than removed: the tiles keep their collision, and hiding a
## room also takes its wall occluders out of every light's shadow pass.
func _sleep_room(room: Node2D, asleep: bool) -> void:
	room.visible = not asleep
	for layer in room.find_children("*", "TileMapLayer", true, false):
		if layer.has_method("set_dormant"):
			layer.set_dormant(asleep)


## Stops scripts, animation and physics under the node and hides it, keeping
## whatever process mode and visibility it had for when it wakes.
func _sleep_node(node: Node2D, asleep: bool) -> void:
	if asleep:
		node.set_meta(&"_stream_mode", node.process_mode)
		node.set_meta(&"_stream_visible", node.visible)
		node.process_mode = Node.PROCESS_MODE_DISABLED
		node.visible = false
	else:
		node.process_mode = node.get_meta(&"_stream_mode", Node.PROCESS_MODE_INHERIT)
		node.visible = node.get_meta(&"_stream_visible", true)


func _room_bounds(room: Node2D) -> Rect2:
	var out := Rect2()
	var first: bool = true
	for layer in room.find_children("*", "TileMapLayer", true, false):
		var tiles := layer as TileMapLayer
		var used := tiles.get_used_rect()
		if not used.has_area():
			continue
		for corner in [used.position, Vector2i(used.end.x, used.position.y),
				Vector2i(used.position.x, used.end.y), used.end]:
			var point: Vector2 = tiles.to_global(tiles.map_to_local(corner))
			if first:
				out = Rect2(point, Vector2.ZERO)
				first = false
			else:
				out = out.expand(point)
	return out.grow(WALL_REACH) if not first else Rect2()


## Everything the node draws or lights, worked out once: props do not move.
func _prop_bounds(node: Node2D) -> Rect2:
	var out := Rect2()
	var first: bool = true
	var parts: Array[Node] = [node]
	parts.append_array(node.find_children("*", "Node2D", true, false))
	for part in parts:
		var rect := Rect2()
		if part is Sprite2D and part.texture != null:
			rect = part.global_transform * (part as Sprite2D).get_rect()
		elif part is AnimatedSprite2D and part.sprite_frames != null \
				and part.sprite_frames.has_animation(part.animation) \
				and part.sprite_frames.get_frame_count(part.animation) > 0:
			var frame: Texture2D = part.sprite_frames.get_frame_texture(part.animation, 0)
			if frame != null:
				var size: Vector2 = frame.get_size()
				var origin: Vector2 = part.offset - (size * 0.5 if part.centered else Vector2.ZERO)
				rect = part.global_transform * Rect2(origin, size)
		elif part is PointLight2D and part.texture != null:
			var reach: Vector2 = part.texture.get_size() * part.texture_scale \
					* (part as Node2D).global_scale.abs() * 0.5
			rect = Rect2(part.global_position - reach, reach * 2.0)
		else:
			continue
		if first:
			out = rect
			first = false
		else:
			out = out.merge(rect)
	return out if not first else Rect2()
