extends Node

## Headless check for WorldStreamer: a real floor is built, then the streamer is
## stepped by hand while the party is moved about.
##
##   godot --headless --path . res://tools/validate_world_streaming.tscn

var _failed: int = 0
var _checks: int = 0
var _maze: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _check(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failed += 1
		push_error(description)


func _tick(times: int = 1) -> void:
	for i in times:
		_maze._streamer._left = 0.0
		_maze._streamer._physics_process(0.0)


func _asleep_rooms() -> Array:
	return _maze._streamer._rooms.filter(func(e): return e[2])


func _run() -> void:
	_maze = load("res://scenes/world/mazeDemo.tscn").instantiate()
	_maze.maze_seed = 101
	_maze.outdoor_weather = 0
	_maze.level_theme = 0
	get_tree().root.add_child(_maze)
	get_tree().current_scene = _maze
	while _maze._building or _maze._player == null:
		await get_tree().process_frame
	## The maze's own loop would move the camera and the clock under the test.
	_maze.set_physics_process(false)
	var streamer: WorldStreamer = _maze._streamer
	_check(streamer != null, "streamer built with the floor")
	if streamer == null:
		get_tree().quit(1)
		return
	streamer.set_physics_process(false)
	_check(streamer._rooms.size() == _maze._rooms.size(), "every room is streamed")
	_check(streamer._props.size() > 20, "props streamed (%d)" % streamer._props.size())

	## Everyone at the start: the far side of a 5x5 floor must sleep.
	_tick()
	var asleep := _asleep_rooms()
	_check(asleep.size() > 0, "far rooms sleep (%d)" % asleep.size())
	_check(asleep.size() < streamer._rooms.size(), "near rooms stay awake")
	for entry in streamer._rooms:
		_check(entry[0].visible == not entry[2], "room visibility follows sleep")
		for layer in entry[0].find_children("*", "TileMapLayer", true, false):
			if "dormant" in layer:
				_check(layer.dormant == entry[2], "wall fade sleeps with its room")
			_check((layer as TileMapLayer).collision_enabled,
					"walls keep collision while asleep")
	var crew := Roster.bodies(get_tree())
	for entry in streamer._rooms:
		var bounds: Rect2 = entry[1]
		for body in crew:
			if bounds.has_point(body.global_position):
				_check(not entry[2], "a player's own room is awake")

	var sleeping_props: int = 0
	for entry in streamer._props:
		if entry[2]:
			sleeping_props += 1
			_check(entry[0].process_mode == Node.PROCESS_MODE_DISABLED,
					"sleeping prop does not process")
			_check(not entry[0].visible, "sleeping prop hidden")
	_check(sleeping_props > 0, "far props sleep (%d)" % sleeping_props)

	var monsters := get_tree().get_nodes_in_group("enemy")
	var dormant: int = 0
	for node in monsters:
		if node is EnemyBase and node.dormant:
			dormant += 1
			_check(node.state_machine.process_mode == Node.PROCESS_MODE_DISABLED,
					"dormant monster's brain is off")
			for body in crew:
				var gap: Vector2 = body.global_position - node.global_position
				gap.y *= 2.0
				_check(gap.length() > streamer.player_reach,
						"no monster sleeps near a player")
	_check(dormant > 0, "far monsters sleep (%d of %d)" % [dormant, monsters.size()])

	## Hysteresis: a second pass with nothing moved changes nothing.
	var before: Array = streamer._rooms.map(func(e): return e[2])
	_tick()
	_check(streamer._rooms.map(func(e): return e[2]) == before, "steady state is stable")

	## Walk the party to the far room: it wakes, and the start sleeps.
	var target: Array = asleep[0]
	var start: Array = []
	for entry in streamer._rooms:
		if (entry[1] as Rect2).has_point(crew[0].global_position):
			start = entry
	var centre: Vector2 = (target[1] as Rect2).get_center()
	for body in crew:
		body.global_position = centre
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		camera.global_position = centre
		camera.reset_smoothing()
		camera.force_update_scroll()
	_tick()
	_check(not target[2] and target[0].visible, "destination room wakes")
	if not start.is_empty():
		var far: bool = not (start[1] as Rect2).intersects(
				(target[1] as Rect2).grow(streamer.buffer + streamer.hysteresis + 2000.0))
		if far:
			_check(start[2], "start room sleeps once left behind")
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is EnemyBase:
			var gap: Vector2 = centre - node.global_position
			gap.y *= 2.0
			if gap.length() < streamer.player_reach * 0.5:
				_check(not node.dormant and node.visible, "monsters there wake")

	## A sleeping monster wakes the moment it is hit.
	var sleeper: EnemyBase = null
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is EnemyBase and node.dormant:
			sleeper = node
			break
	if sleeper != null:
		sleeper.take_damage(0.0)
		_check(not sleeper.dormant and sleeper.visible, "a blow wakes a sleeper")

	## Switching it off restores everything exactly.
	streamer.wake_all()
	for entry in streamer._props:
		_check(entry[0].process_mode != Node.PROCESS_MODE_DISABLED, "prop restored")
	for entry in streamer._rooms:
		_check(entry[0].visible, "room restored")

	## A new floor gets a new streamer and the old one goes with the old floor.
	var old := streamer
	_maze.descend()
	while _maze._building:
		await get_tree().process_frame
	_check(not is_instance_valid(old), "old streamer freed on descent")
	_check(_maze._streamer != null and _maze._streamer != old, "new floor streamed")

	print("world streaming: %d checks, %d failures" % [_checks, _failed])
	_maze.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if _failed > 0 else 0)
