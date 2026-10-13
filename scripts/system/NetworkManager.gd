extends Node

## WebSocket hosting/joining, remote input snapshots and peer<->Roster-slot
## bookkeeping for dedicated-server online play. Character authority and
## replicated game state are still staged separately; see NETWORKING.md.

signal hosting_started(port: int)
signal host_failed(reason: String)
signal joined_server()
signal join_failed(reason: String)
signal server_lost()
signal lobby_updated(player_count: int, is_leader: bool)
signal session_started()

const DEFAULT_PORT: int = 8910
const ACTOR_SNAPSHOT_INTERVAL: float = 0.05
const NETWORK_ACTIONS: PackedStringArray = [
	"Left", "Right", "Up", "Down", "Run", "Katana", "Attack", "Defend",
	"Dodge", "Action", "Jump", "Stealth", "Scroll1", "Scroll2", "Scroll3",
	"Scroll4", "Scroll5", "Scroll6", "ScrollUse", "ScrollPrevious", "ScrollNext",
]

var is_server: bool = false
var is_client: bool = false
var _client_input: PlayerInput
var _room_leader_peer: int = 0
var _session_started: bool = false
var _pending_seed: int = 0
var _pending_theme: int = 0
var _snapshot_left: float = 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_client_input = PlayerInput.new(PlayerInput.KEYBOARD)
	_maybe_launch_dedicated_server()


func _physics_process(_delta: float) -> void:
	if is_server and _session_started:
		_snapshot_left -= _delta
		if _snapshot_left <= 0.0:
			_snapshot_left = ACTOR_SNAPSHOT_INTERVAL
			_broadcast_actor_snapshot()
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
	var tls: TLSOptions = null
	var certificate_path := OS.get_environment("KK_TLS_CERT_FILE")
	var key_path := OS.get_environment("KK_TLS_KEY_FILE")
	if certificate_path.is_empty() != key_path.is_empty():
		push_error("NetworkManager: set both KK_TLS_CERT_FILE and KK_TLS_KEY_FILE")
		host_failed.emit("tls_configuration_incomplete")
		return ERR_INVALID_PARAMETER
	if not certificate_path.is_empty():
		var certificate := X509Certificate.new()
		var key := CryptoKey.new()
		var cert_error: Error = certificate.load(certificate_path)
		var key_error: Error = key.load(key_path)
		if cert_error != OK or key_error != OK:
			var reason := "TLS certificate/key load failed (%s, %s)" % [
				error_string(cert_error), error_string(key_error)]
			push_error("NetworkManager: " + reason)
			host_failed.emit(reason)
			return ERR_FILE_CANT_READ
		tls = TLSOptions.server(key, certificate)
	var err: Error = peer.create_server(port, "*", tls)
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
func join(address: String, port: int = DEFAULT_PORT, secure: bool = true) -> Error:
	var peer := WebSocketMultiplayerPeer.new()
	var url: String = "%s://%s:%d" % ["wss" if secure else "ws", address, port]
	var err: Error = peer.create_client(url, TLSOptions.client() if secure else null)
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
func join_room_code(code: String, secure: bool = true) -> Error:
	var parsed: Dictionary = parse_room_code(code)
	var address: String = parsed["address"]
	var loopback: bool = address == "localhost" or address == "127.0.0.1" \
			or address == "::1"
	return join(address, parsed["port"], secure and not loopback)


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
	if _session_started:
		push_warning("NetworkManager: refusing late join from peer %d" % peer_id)
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	var slot: int = Roster.join_network(peer_id)
	if slot == -1:
		push_warning("NetworkManager: peer %d refused, party is full" % peer_id)
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	if _room_leader_peer == 0:
		_room_leader_peer = peer_id
	print("NetworkManager: peer %d joined as slot %d" % [peer_id, slot])
	_send_lobby_state()


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_server:
		return
	var slot: int = Roster.slot_of_peer(peer_id)
	_reset_network_input(slot)
	Roster.drop_peer(peer_id)
	_send_lobby_state()
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
	rpc_id(1, "request_lobby_state")


func _on_connection_failed() -> void:
	is_client = false
	join_failed.emit("connection_failed")


func _on_server_disconnected() -> void:
	is_server = false
	is_client = false
	_session_started = false
	server_lost.emit()


func _roster_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for slot in Roster.players.size():
		if not Roster.is_network(slot) or Roster.players[slot].get("lost", false):
			continue
		snapshot.append({
			"peer_id": Roster.peer_id_of(slot),
			"scheme": Roster.scheme_of(slot),
			"hair": Roster.hair_of(slot),
			"skin": Roster.skin_of(slot),
		})
	return snapshot


func _send_lobby_state() -> void:
	if not is_server:
		return
	var snapshot := _roster_snapshot()
	for entry in snapshot:
		rpc_id(int(entry["peer_id"]), "receive_lobby_state",
				snapshot, _room_leader_peer)


func _apply_remote_roster(snapshot: Array) -> bool:
	if snapshot.is_empty() or snapshot.size() > Roster.MAX_PLAYERS:
		return false
	var own_peer: int = multiplayer.get_unique_id()
	var seen: Dictionary = {}
	var replacement: Array[Dictionary] = []
	var owns_slot: bool = false
	for entry in snapshot:
		if not (entry is Dictionary) or not entry.has("peer_id"):
			return false
		var peer_id: int = int(entry["peer_id"])
		if peer_id <= 1 or seen.has(peer_id):
			return false
		seen[peer_id] = true
		var device: int = PlayerInput.KEYBOARD if peer_id == own_peer \
				else PlayerInput.NETWORK
		owns_slot = owns_slot or peer_id == own_peer
		replacement.append({
			"device": device,
			"peer_id": peer_id,
			"scheme": int(entry.get("scheme", -1)),
			"hair": int(entry.get("hair", -1)),
			"skin": int(entry.get("skin", -1)),
			"lost": false,
			"bot": false,
		})
	if not owns_slot:
		return false
	Roster.players = replacement
	Roster.roster_changed.emit()
	return true


@rpc("any_peer", "call_remote", "reliable")
func request_lobby_state() -> void:
	if not is_server or _session_started:
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if Roster.slot_of_peer(peer_id) == -1:
		return
	rpc_id(peer_id, "receive_lobby_state", _roster_snapshot(), _room_leader_peer)


@rpc("authority", "call_remote", "reliable")
func receive_lobby_state(snapshot: Array, leader_peer: int) -> void:
	if not is_client or not _apply_remote_roster(snapshot):
		return
	_room_leader_peer = leader_peer
	lobby_updated.emit(Roster.count(), is_room_leader())


func is_room_leader() -> bool:
	return is_client and _room_leader_peer == multiplayer.get_unique_id()


func start_room() -> void:
	if is_client and is_room_leader():
		rpc_id(1, "request_start_session")


@rpc("any_peer", "call_remote", "reliable")
func request_start_session() -> void:
	if not is_server or _session_started \
			or multiplayer.get_remote_sender_id() != _room_leader_peer \
			or Roster.count() == 0:
		return
	_session_started = true
	_pending_seed = randi()
	_pending_theme = 0
	rpc("receive_session_start", _pending_seed, _pending_theme, _roster_snapshot())
	_start_session_scene()


@rpc("authority", "call_remote", "reliable")
func receive_session_start(seed: int, theme: int, snapshot: Array) -> void:
	if not is_client or not _apply_remote_roster(snapshot):
		return
	_session_started = true
	_pending_seed = seed
	_pending_theme = theme
	session_started.emit()


func consume_pending_floor() -> Dictionary:
	if not _session_started:
		return {}
	return {"seed": _pending_seed, "theme": _pending_theme}


func _start_session_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/world/mazeDemo.tscn")


func _broadcast_actor_snapshot() -> void:
	var players: Array[Dictionary] = []
	for body in get_tree().get_nodes_in_group("player"):
		if not (body is CharacterBody2D) or not ("slot" in body):
			continue
		var machine := body.get_node_or_null("FiniteStateMachine") as FiniteStateMachine
		var state: String = machine.current_state.name if machine != null \
				and machine.current_state != null else ""
		players.append({
			"slot": int(body.get("slot")),
			"position": body.global_position,
			"velocity": body.velocity,
			"facing": String(body.get("facing_dir")),
			"state": state,
			"health": float(body.get("health")),
			"max_health": float(body.get("max_health")),
			"is_dead": body.get("is_dead") == true,
			"katana_drawn": body.get("katana_drawn") == true,
			"stealthed": body.get("stealthed") == true,
			"crouched": body.get("crouched") == true,
		})
	var enemies: Array[Dictionary] = []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is CharacterBody2D) or not ("network_id" in enemy):
			continue
		var machine := enemy.get_node_or_null("FiniteStateMachine") as FiniteStateMachine
		var state: String = machine.current_state.name if machine != null \
				and machine.current_state != null else ""
		enemies.append({
			"id": int(enemy.get("network_id")),
			"position": enemy.global_position,
			"velocity": enemy.velocity,
			"facing": String(enemy.get("facing_dir")),
			"state": state,
			"health": float(enemy.get("health")),
			"is_dead": enemy.get("is_dead") == true,
		})
	rpc("receive_actor_snapshot", players, enemies)


@rpc("authority", "call_remote", "unreliable_ordered")
func receive_actor_snapshot(players: Array, enemies: Array) -> void:
	if not is_client:
		return
	for state in players:
		if not (state is Dictionary):
			continue
		var slot: int = int(state.get("slot", -1))
		if slot < 0:
			continue
		for body in get_tree().get_nodes_in_group("player"):
			if not (body is CharacterBody2D) or int(body.get("slot")) != slot:
				continue
			body.global_position = state.get("position", body.global_position)
			body.velocity = state.get("velocity", Vector2.ZERO)
			body.health = state.get("health", body.health)
			body.max_health = state.get("max_health", body.max_health)
			body.is_dead = state.get("is_dead", false)
			body.katana_drawn = state.get("katana_drawn", false)
			body.stealthed = state.get("stealthed", false)
			body.crouched = state.get("crouched", false)
			if "facing_dir" in body:
				body.facing_dir = state.get("facing", body.facing_dir)
			_apply_actor_state(body, String(state.get("state", "")))
			break
	for state in enemies:
		if not (state is Dictionary):
			continue
		var network_id: int = int(state.get("id", -1))
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if not ("network_id" in enemy) or int(enemy.get("network_id")) != network_id:
				continue
			enemy.global_position = state.get("position", enemy.global_position)
			enemy.velocity = state.get("velocity", Vector2.ZERO)
			enemy.health = state.get("health", enemy.health)
			enemy.is_dead = state.get("is_dead", false)
			if "facing_dir" in enemy:
				enemy.facing_dir = state.get("facing", enemy.facing_dir)
			_apply_actor_state(enemy, String(state.get("state", "")))
			break


func _apply_actor_state(body: Node, state_name: String) -> void:
	if state_name.is_empty():
		return
	var machine := body.get_node_or_null("FiniteStateMachine") as FiniteStateMachine
	if machine == null or (machine.current_state != null
			and machine.current_state.name == state_name):
		return
	if machine.has_node(state_name):
		machine.change_state(state_name)
