extends Node

## Who is playing, on what device, wearing which colour.
##
## Autoloaded, so the character select fills it in and the maze reads it back
## without either knowing about the other — the same trick PowerState uses for
## the single-player choice.
##
## A "slot" is a player: slot 0 is player one. Slots are filled in order and
## never reordered, so player two stays player two even if player three's pad
## is pulled out.

signal roster_changed()
## A pad vanished mid-game. The maze listens and halts until it is back.
signal device_lost(slot: int)
signal device_regained(slot: int)

const MAX_PLAYERS: int = 4

## Bright, clearly distinct, and in slot order. Used for the ring under each
## character and their HUD tint — the colour scheme is their own choice and
## cannot be relied on to tell players apart at a glance in a dark dungeon.
const SLOT_COLOURS: Array[Color] = [
	Color(0.35, 0.75, 1.00),	## blue
	Color(1.00, 0.45, 0.35),	## red
	Color(0.55, 0.95, 0.45),	## green
	Color(1.00, 0.85, 0.35),	## gold
]

## One entry per joined player:
## {"device": int, "scheme": int, "hair": int, "skin": int, "lost": bool}
var players: Array[Dictionary] = []
var level_theme: int = -1


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_changed)


## Wipes the roster back to nobody. Called when the select screen opens, so
## backing out to the title and starting again does not stack players up.
func clear() -> void:
	players.clear()
	level_theme = -1
	roster_changed.emit()


func count() -> int:
	return players.size()


## Adds a player on a device. Returns the slot, or -1 if the roster is full or
## that device is already playing. hair/skin default to -1, meaning "follow
## whatever PowerState's own picker is set to" — unlike scheme, hair and skin
## are not locked unique per player, so leaving them unset is a sensible
## default rather than something every caller must think about.
func join(device: int, scheme: int = -1, hair: int = -1, skin: int = -1) -> int:
	if players.size() >= MAX_PLAYERS or has_device(device):
		return -1
	players.append({"device": device, "scheme": scheme, "hair": hair, "skin": skin, "lost": false})
	roster_changed.emit()
	return players.size() - 1


## Removes the last player. The select screen backs out this way, so going back
## always returns control to the player before.
func drop_last() -> void:
	if players.is_empty():
		return
	players.pop_back()
	roster_changed.emit()


func has_device(device: int) -> bool:
	for p in players:
		if p["device"] == device:
			return true
	return false


## Is this colour scheme already taken. The select screen locks a scheme once
## chosen so two players cannot wear the same one and become indistinguishable.
func scheme_taken(scheme: int, ignoring_slot: int = -1) -> bool:
	for i in players.size():
		if i != ignoring_slot and players[i]["scheme"] == scheme:
			return true
	return false


func set_scheme(slot: int, scheme: int) -> void:
	if slot < 0 or slot >= players.size():
		return
	players[slot]["scheme"] = scheme
	roster_changed.emit()


func scheme_of(slot: int) -> int:
	if slot < 0 or slot >= players.size():
		return PowerState.chosen
	var value: int = players[slot]["scheme"]
	return value if value >= 0 else PowerState.chosen


func set_hair(slot: int, hair: int) -> void:
	if slot < 0 or slot >= players.size():
		return
	players[slot]["hair"] = hair
	roster_changed.emit()


func hair_of(slot: int) -> int:
	if slot < 0 or slot >= players.size():
		return PowerState.chosen_hair
	var value: int = players[slot].get("hair", -1)
	return value if value >= 0 else PowerState.chosen_hair


func set_skin(slot: int, skin: int) -> void:
	if slot < 0 or slot >= players.size():
		return
	players[slot]["skin"] = skin
	roster_changed.emit()


func skin_of(slot: int) -> int:
	if slot < 0 or slot >= players.size():
		return PowerState.chosen_skin
	var value: int = players[slot].get("skin", -1)
	return value if value >= 0 else PowerState.chosen_skin


func device_of(slot: int) -> int:
	if slot < 0 or slot >= players.size():
		return PlayerInput.KEYBOARD
	return players[slot]["device"]


func colour_of(slot: int) -> Color:
	return SLOT_COLOURS[slot % SLOT_COLOURS.size()]


## A fresh input object for a slot, bound to that slot's device.
func input_for(slot: int) -> PlayerInput:
	return PlayerInput.new(device_of(slot))


## Every device with nobody on it yet: connected pads plus the keyboard. The
## select screen offers these to whoever presses next.
func free_devices() -> Array[int]:
	var free: Array[int] = []
	if not has_device(PlayerInput.KEYBOARD):
		free.append(PlayerInput.KEYBOARD)
	for id in Input.get_connected_joypads():
		if not has_device(id):
			free.append(id)
	return free


func any_lost() -> bool:
	for p in players:
		if p["lost"]:
			return true
	return false


## Every living player body in the scene.
##
## One place, because this lookup was copy-pasted into four files and three of
## them got it wrong the same way: they latched onto the first CharacterBody2D
## in the group and cached it forever, so the radar, the wall fade and the debug
## overlay all only ever followed player one. The monsters had the identical bug
## and were fixed; these were missed.
##
## Her PlayerHitBox is in the "player" group too, so the body test is not
## optional — the first node in the group is as likely to be that Area2D.
func bodies(tree: SceneTree) -> Array[CharacterBody2D]:
	var out: Array[CharacterBody2D] = []
	for node in tree.get_nodes_in_group("player"):
		if node is CharacterBody2D and not (node.get("is_dead") == true):
			out.append(node)
	return out


## The middle of the party, for anything that has to pick one point to speak
## for everybody — the radar's centre, for instance.
func centre_of_party(tree: SceneTree) -> Vector2:
	var all := bodies(tree)
	if all.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for body in all:
		sum += body.global_position
	return sum / float(all.size())


## The living player closest to a point, or null.
func nearest_to(tree: SceneTree, point: Vector2) -> CharacterBody2D:
	var best: CharacterBody2D = null
	var best_distance: float = INF
	for body in bodies(tree):
		var distance: float = point.distance_squared_to(body.global_position)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best


## A pad appeared or vanished. Mid-game a lost pad holds its slot rather than
## freeing it — a dropped cable should not cost a player their run — and the
## maze pauses until the same slot has a device again.
func _on_joy_changed(device: int, connected: bool) -> void:
	for i in players.size():
		if players[i]["device"] != device:
			continue
		players[i]["lost"] = not connected
		if connected:
			device_regained.emit(i)
		else:
			device_lost.emit(i)
		roster_changed.emit()
		return
	## Not one of ours. A pad plugged in while a slot is waiting for a
	## replacement adopts that slot, so any spare pad can rescue a player.
	if connected:
		for i in players.size():
			if players[i]["lost"]:
				players[i]["device"] = device
				players[i]["lost"] = false
				device_regained.emit(i)
				roster_changed.emit()
				return
	roster_changed.emit()
