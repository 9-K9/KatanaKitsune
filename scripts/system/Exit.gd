class_name Exit
extends Area2D

## The stairway down. Walking onto it sends the run to the next floor.

signal descended

var _used: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	## The player's hitbox Area2D is in the "player" group too; only the body
	## should trip the stairs.
	if _used or not (body is CharacterBody2D) or not body.is_in_group("player"):
		return
	_used = true
	AudioManager.play_for("sfx_floor_descend", self)
	descended.emit()
