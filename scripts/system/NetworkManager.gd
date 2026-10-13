extends Node

## WebSocket hosting/joining, remote input snapshots and peer<->Roster-slot
## bookkeeping for dedicated-server online play. Character authority and
## replicated game state are still staged separately; see NETWORKING.md.

signal hosting_started(port: int)
signal host_failed(reason: String)
signal joined_server()
signal join_failed(reason: String)
signal server_lost()

const DEFAULT_PORT: int = 8910
const NETWORK_ACTIONS: PackedStringArray = [
	"Left", "Right", "Up", "Down", "Run", "Katana", "Attack", "Defend",
	"Dodge", "Action", "Jump", "Stealth", "Scroll1", "Scroll2", "Scroll3",
	"Scroll4", "Scroll5", "Scroll6", "ScrollUse", "ScrollPrevious", "ScrollNext",
]

var is_server: bool = false
var is_client: bool = false
var _client_input: PlayerInput


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_client_input = PlayerInput.new(PlayerInput.KEYBOARD)
	_maybe_launch_dedicated_server()


func _physics_process(_delta: float) -> void:
	if not is_client or multiplayer.multiplayer_peer == null \
			or multiplayer.multiplayer_peer.get_connection_status() \
			!= MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var actions: Dictionary = {}
	for action in NETWORK_ACTIONS:
		actions[action] = _client_input.pressed(action)
	rpc_id(1, "receive_input_snapshot", actions,
			_client_input.vector(), _client_input.aim_vector())


func is_networked() -> bool:
	return is_server or is_client


## Starts listening for players. All platforms, including the web export,
## speak WebSocket rather than raw ENet/UDP, so a browser client and a
## desktop client use the exact same transport and the server only has one
## listener to run.
func host(port: int = DEFAULT_PORT) -> Error:
	var peer := WebSocketMultiplayerPeer.new()
	var err: Error = peer.create_server(port)
	if err != OK:
		push_error("NetworkManager: failed to host on port %d (%s)" % [port, error_string(err)])
		host_failed.emit(error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	is_server = true
	is_client = false
	hosting_started.emit(port)
	print("NetworkManager: hosting on port %d" % port)
	return OK


## Connects to someone else's dedicated server as a client.
func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := WebSocketMultiplayerPeer.new()
	var url: String = "ws://%s:%d" % [address, port]
	var err: Error = peer.create_client(url)
	if err != OK:
		push_error("NetworkManager: failed to join %s (%s)" % [url, error_string(err)])
		join_failed.emit(error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	is_client = true
	is_server = false
	print("NetworkManager: joining %s" % url)
	return OK


## There is deliberately no account system or matchmaking site (per the
## chosen scope): a room code is just the host's own address, typed in by
## whoever is joining. "host" alone is shorthand for the default port.
func join_room_code(code: String) -> Error:
	var parsed: Dictionary = parse_room_code(code)
	return join(parsed["address"], parsed["port"])


func parse_room_code(code: String) -> Dictionary:
	var text: String = code.strip_edges()
	var port: int = DEFAULT_PORT
	var address: String = text
	var colon: int = text.rfind(":")
	if colon != -1:
		var tail: String = text.substr(colon + 1)
		if tail.is_valid_int():
			port = int(tail)
			address = text.substr(0, colon)
	if address.is_empty():
		address = "127.0.0.1"
	return {"address": address, "port": port}


func stop() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_server = false
	is_client = false


## `--server` (or `--server=PORT`) boots straight into a headless dedicated
## server instead of the title screen — the mode this is meant to run as on a
## small always-on VPS/PaaS instance, with nothing to render.
func _maybe_launch_dedicated_server() -> void:
	for arg in OS.get_cmdline_args():
		if arg == "--server" or arg.begins_with("--server="):
			var port: int = DEFAULT_PORT
			if arg.begins_with("--server="):
				var value: String = arg.substr("--server=".length())
				if value.is_valid_int():
					port = int(value)
			call_deferred("_start_dedicated_server", port)
			return


func _start_dedicated_server(port: int) -> void:
	host(port)


func _on_peer_connected(peer_id: int) -> void:
	if not is_server:
		return
	var slot: int = Roster.join_network(peer_id)
	if slot == -1:
		push_warning("NetworkManager: peer %d refused, party is full" % peer_id)
		return
	print("NetworkManager: peer %d joined as slot %d" % [peer_id, slot])


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_server:
		return
	var slot: int = Roster.slot_of_peer(peer_id)
	_reset_network_input(slot)
	Roster.drop_peer(peer_id)
	print("NetworkManager: peer %d disconnected" % peer_id)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func receive_input_snapshot(actions: Dictionary, move: Vector2, aim: Vector2) -> void:
	if not is_server:
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	var slot: int = Roster.slot_of_peer(peer_id)
	if peer_id <= 1 or slot == -1 or not Roster.is_network(slot):
		return
	if not move.is_finite() or not aim.is_finite():
		return
	for action in actions:
		if not NETWORK_ACTIONS.has(String(action)) \
				or typeof(actions[action]) != TYPE_BOOL:
			return
	var input := _network_input_for_peer(peer_id, slot)
	if input == null:
		return
	var safe_actions: Dictionary = {}
	for action in NETWORK_ACTIONS:
		safe_actions[action] = actions.get(action, false)
	input.apply_snapshot(safe_actions, move.limit_length(1.0), aim.limit_length(1.0))


func _network_input_for_peer(peer_id: int, slot: int) -> NetworkInput:
	for candidate in get_tree().get_nodes_in_group("player"):
		if not (candidate is CharacterBody2D) or not ("slot" in candidate):
			continue
		if int(candidate.get("slot")) != slot:
			continue
		var input: Variant = candidate.get("input")
		if input is NetworkInput:
			input.peer_id = peer_id
			return input
	return null


func _reset_network_input(slot: int) -> void:
	if slot == -1:
		return
	var input := _network_input_for_peer(Roster.peer_id_of(slot), slot)
	if input != null:
		input.reset()


func _on_connected_to_server() -> void:
	joined_server.emit()


func _on_connection_failed() -> void:
	is_client = false
	join_failed.emit("connection_failed")


func _on_server_disconnected() -> void:
	is_server = false
	is_client = false
	server_lost.emit()
