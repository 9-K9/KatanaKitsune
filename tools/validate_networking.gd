extends Node

## Headless check that the dedicated-server WebSocket transport and the
## Roster<->peer plumbing and input snapshot delivery (NetworkManager) work
## over a real loopback connection, not just that the code compiles.
##
## A server and a client can't share one process's MultiplayerAPI, so this
## runs as two separate headless processes:
##
##   godot --headless --path . res://tools/validate_networking.tscn --max-fps 120 -- --role=server
##   godot --headless --path . res://tools/validate_networking.tscn --max-fps 120 -- --role=client
##
## tools/validate_networking.sh starts both and reports combined PASS/FAIL.
## Exits nonzero on a failed check or a timed-out wait.

const TIMEOUT_SEC: float = 8.0

class NetworkProbe extends CharacterBody2D:
	var slot: int = -1
	var input: PlayerInput

var _failed: bool = false
var _probe: NetworkProbe


func _ready() -> void:
	var role: String = _arg_value("--role", "")
	var port: int = int(_arg_value("--port", str(NetworkManager.DEFAULT_PORT)))
	match role:
		"server":
			await _run_server(port)
		"client":
			await _run_client(port)
		_:
			push_error("validate_networking: pass --role=server or --role=client")
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
		print("FAIL: %s" % label)
		_failed = true


func _run_server(port: int) -> void:
	_check(NetworkManager.host(port) == OK, "server hosts on port %d" % port)
	await _wait_for(func() -> bool: return Roster.count() > 0,
			"a peer connects and takes a roster slot")
	_check(Roster.count() == 1, "roster has exactly one slot after one peer connects")
	_check(Roster.is_network(0), "slot 0 is a network slot")
	_check(Roster.peer_id_of(0) > 0, "slot 0 carries a real peer id")
	_probe = NetworkProbe.new()
	_probe.slot = 0
	_probe.input = Roster.input_for(0)
	_probe.add_to_group("player")
	add_child(_probe)
	await _wait_for(_snapshot_received,
			"client input reaches its server-side NetworkInput and is bounded")
	await _wait_for(func() -> bool: return Roster.any_lost(),
			"the peer disconnecting marks its slot lost, not removed")
	_check(Roster.count() == 1, "the slot is kept, not dropped, after disconnect")
	_check(not _probe.input.pressed("Attack")
			and _probe.input.vector() == Vector2.ZERO
			and _probe.input.aim_vector() == Vector2.ZERO,
			"disconnect clears held network input")


func _snapshot_received() -> bool:
	return _probe.input.pressed("Attack") \
			and _probe.input.vector().is_equal_approx(Vector2(0.6, 0.8)) \
			and _probe.input.aim_vector().is_equal_approx(Vector2.RIGHT)


func _run_client(port: int) -> void:
	_check(NetworkManager.join("127.0.0.1", port) == OK, "client starts connecting")
	await _wait_for(_client_connected, "client reaches CONNECTION_CONNECTED")
	## Give the server a moment to finish its own bookkeeping before this
	## process tears down the socket out from under it.
	NetworkManager.is_client = false
	NetworkManager.rpc_id(1, "receive_input_snapshot",
			{"Attack": true}, Vector2(0.6, 0.8), Vector2(2.0, 0.0))
	await get_tree().create_timer(0.5).timeout
	NetworkManager.stop()


func _client_connected() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## Polls `predicate` once a frame until it is true or TIMEOUT_SEC elapses,
## printing PASS/FAIL against `label` either way.
func _wait_for(predicate: Callable, label: String) -> void:
	var elapsed: float = 0.0
	while elapsed < TIMEOUT_SEC:
		if predicate.call():
			_check(true, label)
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_check(false, label)
