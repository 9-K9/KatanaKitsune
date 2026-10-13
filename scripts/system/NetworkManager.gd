extends Node

## WebSocket transport and peer<->Roster-slot bookkeeping for dedicated-server
## online play. See NETWORKING.md for the staged plan and what this does and
## does not do yet — this autoload covers bucket 1 (host/join a dedicated
## server with a simple room code) and the Roster side of bucket 3 (a
## connecting peer gets a slot, a dropped peer's slot waits to be reclaimed).
## It does not yet drive any gameplay: see NETWORKING.md for what remains.

signal hosting_started(port: int)
signal host_failed(reason: String)
signal joined_server()
signal join_failed(reason: String)
signal server_lost()

const DEFAULT_PORT: int = 8910

var is_server: bool = false
var is_client: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_maybe_launch_dedicated_server()


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
	Roster.drop_peer(peer_id)
	print("NetworkManager: peer %d disconnected" % peer_id)


func _on_connected_to_server() -> void:
	joined_server.emit()


func _on_connection_failed() -> void:
	is_client = false
	join_failed.emit("connection_failed")


func _on_server_disconnected() -> void:
	is_server = false
	is_client = false
	server_lost.emit()
