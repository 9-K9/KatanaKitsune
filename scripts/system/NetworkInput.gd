class_name NetworkInput
extends PlayerInput

## Input for a slot filled by a remote player, not local hardware or AI.
##
## Shaped exactly like BotInput: nothing here ever reads Input.* locally.
## `_sync()` is overridden to a no-op so the per-frame state is never
## clobbered by a hardware read, and `apply_snapshot()` is the only thing
## that ever changes what `pressed()`/`vector()`/`aim_vector()` report —
## called by NetworkManager when a fresh snapshot arrives for this peer.
##
## NetworkManager applies each validated client input snapshot here. Character
## authority and state replication remain separate unfinished phases.

var peer_id: int = 0
var _move := Vector2.ZERO
var _aim := Vector2.ZERO


func _init(for_peer: int = 0) -> void:
	super(PlayerInput.NETWORK)
	peer_id = for_peer


func bind_body(_body: CharacterBody2D) -> void:
	pass


func _sync() -> void:
	pass


func update(_delta: float) -> void:
	pass


func vector() -> Vector2:
	return _move


func aim_vector() -> Vector2:
	return _aim


func reset() -> void:
	_now.clear()
	_was.clear()
	_move = Vector2.ZERO
	_aim = Vector2.ZERO


## Called by NetworkManager when a fresh input snapshot arrives from this
## peer. `actions` is action-name -> bool, matching what `pressed()` already
## expects; `move`/`aim` mirror PlayerInput.vector()/aim_vector().
func apply_snapshot(actions: Dictionary, move: Vector2, aim: Vector2) -> void:
	_was = _now
	_now = actions.duplicate()
	_move = move
	_aim = aim
