extends Node

## End-to-end online match check: a headless dedicated server and one client,
## each a separate Godot process, play through lobby → floor → next floor →
## match over. Run via tools/validate_online_match.sh, or by hand:
##
##   godot --headless --path . res://tools/validate_online_match.tscn --max-fps 120 -- --role=server --port=8960
##   godot --headless --path . res://tools/validate_online_match.tscn --max-fps 120 -- --role=client --port=8960
##
## The shell script also compares the SEED lines printed by both sides, which
## is the real proof that both processes built the same floor.
##
## Against a live dedicated server (no validator on the far side) pass
## `--remote=1`: the client skips the checks that need the validator-server to
## drive a descent and end the match, and hangs up itself instead. `--host=` and
## `--tls=1` (implied by port 443) point it at the Droplet; `--wait-for=N` makes
## the leader hold the lobby until N seats are taken so a second process with
## `--role=client2` can join before the floor opens:
##
##   godot --headless --path . res://tools/validate_online_match.tscn -- --role=client  --host=209-97-138-84.sslip.io --port=443 --remote=1 --wait-for=2
##   godot --headless --path . res://tools/validate_online_match.tscn -- --role=client2 --host=209-97-138-84.sslip.io --port=443

const TIMEOUT_SEC: float = 40.0
## Lobby seats fill at human speed when a second process is being started.
const WAIT_FOR_SEATS_SEC: float = 90.0

var _failed: bool = false
var _match_ended: bool = false
var _ended_reason: String = ""
var _remote: bool = false
var _host: String = "127.0.0.1"
var _tls: bool = false
var _wait_for_seats: int = 1


func _ready() -> void:
	## change_scene_to_file frees the current scene, so this node moves under
	## the root to outlive the lobby → floor → title hops it is testing.
	await get_tree().process_frame
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	var role: String = _arg_value("--role", "")
	var port: int = int(_arg_value("--port", str(NetworkManager.DEFAULT_PORT)))
	_host = _arg_value("--host", "127.0.0.1")
	_remote = _arg_value("--remote", "0") == "1"
	_tls = _arg_value("--tls", "1" if port == 443 else "0") == "1"
	_wait_for_seats = maxi(1, int(_arg_value("--wait-for", "1")))
	match role:
		"server":
			await _run_server(port)
		"client":
			await _run_client(port)
		"client2":
			await _run_second_client(port)
		_:
			push_error("validate_online_match: pass --role=server, --role=client or --role=client2")
			_failed = true
	get_tree().quit(1 if _failed else 0)


func _arg_value(key: String, default: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(key + "="):
			return arg.substr(key.length() + 1)
	return default


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		_failed = true
		print("FAIL: %s" % label)


func _world() -> Node:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == NetworkManager.MATCH_SCENE:
		return scene
	return null


func _bodies() -> Array:
	var found: Array = []
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D and "slot" in node:
			found.append(node)
	return found


func _live_enemies() -> int:
	var total := 0
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is CharacterBody2D and node.get("is_dead") != true:
			total += 1
	return total


func _memory_mb() -> float:
	return OS.get_static_memory_usage() / 1048576.0


func _run_server(port: int) -> void:
	_check(NetworkManager.host(port) == OK, "server hosts on port %d" % port)
	await _wait_for(func() -> bool: return Roster.count() > 0,
			"a client takes a lobby seat")
	await _wait_for(func() -> bool: return Roster.players[0].get("scheme", -1) == 3,
			"the client's aspect choice lands in the roster")
	await _wait_for(func() -> bool: return NetworkManager.lobby_theme() == 2,
			"the leader's area choice lands in the lobby")
	await _wait_for(func() -> bool: return _world() != null,
			"start opens the match floor on the server")
	var world := _world()
	await _wait_for(func() -> bool: return _bodies().size() == 1 and _live_enemies() > 0,
			"the floor spawns the party and a wave")
	print("SEED: %d theme=%d depth=%d" % [world.maze_seed, world.level_theme, world.depth])
	_check(world.level_theme == 2, "the floor uses the lobby's area")
	print("MEMORY: server on floor %.0f MB" % _memory_mb())
	_check(_memory_mb() < 700.0, "server stays under 700 MB on a floor")
	## Let the enemies take a few steps so the client has snapshots to show.
	await get_tree().create_timer(1.5).timeout
	var start_depth: int = world.depth
	world.descend()
	await _wait_for(_descended.bind(world, start_depth),
			"the server descends and keeps the party")
	print("SEED: %d theme=%d depth=%d" % [world.maze_seed, world.level_theme, world.depth])
	await get_tree().create_timer(1.0).timeout
	## A wipe: every body dead ends the match once the game-over clock runs out.
	## Done directly here so the test does not wait on that clock.
	NetworkManager.end_session("validator")
	await _wait_for(_on_scene.bind(NetworkManager.IDLE_SCENE),
			"ending the match returns the server to its idle scene")
	_check(Roster.count() == 0, "the room is empty again")
	_check(NetworkManager.is_server, "the server keeps listening")
	print("MEMORY: server idle again %.0f MB" % _memory_mb())


func _run_client(port: int) -> void:
	NetworkManager.match_ended.connect(func(reason: String):
			_match_ended = true
			_ended_reason = reason)
	_check(NetworkManager.join(_host, port, _tls) == OK, "client starts connecting to %s:%d%s"
			% [_host, port, " (wss)" if _tls else ""])
	await _wait_for(func() -> bool: return NetworkManager.own_slot() == 0,
			"client is seated in slot 0")
	_check(NetworkManager.is_room_leader(), "first in is the room leader")
	NetworkManager.choose_scheme(3)
	await _wait_for(func() -> bool: return Roster.players[0].get("scheme", -1) == 3,
			"aspect choice round-trips through the server")
	NetworkManager.choose_theme(2)
	await _wait_for(func() -> bool: return NetworkManager.lobby_theme() == 2,
			"area choice round-trips through the server")
	var party: int = _wait_for_seats
	if party > 1:
		await _wait_for(func() -> bool: return Roster.count() >= party,
				"%d seats are taken before the leader starts" % party, WAIT_FOR_SEATS_SEC)
		party = Roster.count()
	NetworkManager.start_room()
	await _wait_for(func() -> bool: return _world() != null,
			"start opens the match floor on the client")
	var world := _world()
	await _wait_for(func() -> bool: return _bodies().size() == party and _live_enemies() > 0,
			"the client's floor has the party of %d and the wave" % party)
	print("SEED: %d theme=%d depth=%d" % [world.maze_seed, world.level_theme, world.depth])
	_check(world.level_theme == 2, "the client's floor uses the lobby's area")
	var body: CharacterBody2D = _own_body()
	_check(body != null, "the client finds its own body")
	_check(Roster.players[0].get("scheme", -1) == 3, "the client's body wears the chosen aspect")
	await _wait_for(_enemies_moved.bind(_enemy_positions()), "enemy positions arrive from the server")
	print("MEMORY: client on floor %.0f MB" % _memory_mb())
	if party > 1:
		## Hold "Right" so the second peer can see this body move via snapshots.
		var before: Vector2 = body.global_position if body else Vector2.ZERO
		_hold_key(KEY_D, true)
		await _wait_for(func() -> bool:
				return body != null and body.global_position != before,
				"the leader's own body moves on held input")
		await get_tree().create_timer(1.5).timeout
		_hold_key(KEY_D, false)
	if _remote:
		await _leave_remote_floor()
		return
	var start_depth: int = world.depth
	await _wait_for(_descended.bind(world, start_depth),
			"the client follows the server down a floor")
	print("SEED: %d theme=%d depth=%d" % [world.maze_seed, world.level_theme, world.depth])
	_check(_bodies().size() == 1 and _bodies()[0] == body,
			"the client's body survives the descent")
	await _wait_for(func() -> bool: return _match_ended, "the client hears the match end")
	_check(_ended_reason == "validator", "with the server's reason")
	await _wait_for(_on_scene.bind("res://scenes/title_screen.tscn"),
			"the client leaves the floor for the title screen")
	_check(not NetworkManager.is_client, "the client has hung up")
	_check(Roster.count() == 0, "the client's roster is cleared for local play")


## A non-leader joining a lobby that `--role=client --wait-for=2` is holding
## open. It verifies the floor from the second seat and then hangs up.
func _run_second_client(port: int) -> void:
	_check(NetworkManager.join(_host, port, _tls) == OK, "client2 starts connecting to %s:%d%s"
			% [_host, port, " (wss)" if _tls else ""])
	await _wait_for(func() -> bool: return NetworkManager.own_slot() > 0,
			"client2 is seated in a later slot", WAIT_FOR_SEATS_SEC)
	var slot: int = NetworkManager.own_slot()
	_check(not NetworkManager.is_room_leader(), "client2 is not the room leader")
	NetworkManager.choose_scheme(1)
	await _wait_for(func() -> bool: return Roster.players[slot].get("scheme", -1) == 1,
			"client2's aspect choice round-trips through the server")
	await _wait_for(func() -> bool: return _world() != null,
			"the leader's start opens the floor on client2", WAIT_FOR_SEATS_SEC)
	var world := _world()
	await _wait_for(func() -> bool: return _bodies().size() >= 2 and _live_enemies() > 0,
			"client2's floor has both bodies and the wave")
	print("SEED: %d theme=%d depth=%d" % [world.maze_seed, world.level_theme, world.depth])
	_check(_own_body() != null, "client2 finds its own body in slot %d" % slot)
	await _wait_for(_enemies_moved.bind(_enemy_positions()), "enemy positions arrive on client2")
	await _wait_for(_leader_moved.bind(_bodies_positions()),
			"the leader's body is seen moving on client2")
	print("MEMORY: client2 on floor %.0f MB" % _memory_mb())
	await _leave_remote_floor()


func _leave_remote_floor() -> void:
	## There is no validator on the far side to end the match, so hang up the
	## way OnlineLobby's back button does and confirm local play is clean.
	await get_tree().create_timer(2.0).timeout
	NetworkManager.stop()
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
	await _wait_for(_on_scene.bind("res://scenes/title_screen.tscn"),
			"hanging up returns to the title screen")
	_check(not NetworkManager.is_client, "the client has hung up")
	_check(Roster.count() == 0, "the roster is cleared for local play")


func _hold_key(physical: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.pressed = down
	Input.parse_input_event(event)


func _own_body() -> CharacterBody2D:
	var slot: int = NetworkManager.own_slot()
	for body in _bodies():
		if body.slot == slot:
			return body
	return null


func _enemy_positions() -> Dictionary:
	var positions: Dictionary = {}
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if "network_id" in enemy:
			positions[enemy.network_id] = enemy.global_position
	return positions


func _bodies_positions() -> Dictionary:
	var positions: Dictionary = {}
	for body in _bodies():
		positions[body.slot] = body.global_position
	return positions


## Slot 0's body is driven by the leader process; any movement means player
## snapshots are flowing to this peer.
func _leader_moved(before: Dictionary) -> bool:
	for body in _bodies():
		if body.slot == 0 and before.has(0) and body.global_position != before[0]:
			return true
	return false


func _descended(world: Node, start_depth: int) -> bool:
	return is_instance_valid(world) and world.depth == start_depth + 1 \
			and _live_enemies() > 0 and _bodies().size() == 1


func _on_scene(path: String) -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == path


func _enemies_moved(before: Dictionary) -> bool:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if "network_id" in enemy and before.has(enemy.network_id) \
				and enemy.global_position != before[enemy.network_id]:
			return true
	return false


## Polls `predicate` once a frame until it is true or TIMEOUT_SEC elapses,
## printing PASS/FAIL against `label` either way.
func _wait_for(predicate: Callable, label: String, timeout_sec: float = TIMEOUT_SEC) -> void:
	var elapsed: float = 0.0
	while elapsed < timeout_sec:
		if predicate.call():
			_check(true, label)
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_check(false, label)
