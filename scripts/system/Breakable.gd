class_name Breakable
extends StaticBody2D

## A destructible dungeon prop: urns, crates, chests, statues.
##
## Takes katana hits like an enemy does (the player's attack code only needs a
## take_damage method), flashes, then shatters into whatever it was holding —
## a pickup, or something unpleasant that was nesting inside it.

## What comes out when it breaks. Weights are relative, not percentages.
@export var loot_scene: PackedScene = null
@export var loot_weight: float = 6.0
@export var spawn_scene: PackedScene = null
@export var spawn_weight: float = 2.0
## Chance of dropping nothing at all.
@export var empty_weight: float = 3.0

@export var max_health: float = 25.0
## Chests are meant to feel worth hitting, so they always drop.
@export var always_drops: bool = false

const HIT_FLASH: Color = Color(1.6, 1.3, 1.1, 1.0)

@onready var sprite: Sprite2D = $Sprite2D

var health: float = 0.0
var _broken: bool = false
var _flash_tween: Tween = null


func _ready() -> void:
	health = max_health
	## Nudge each prop off the exact tile centre so a room full of urns does not
	## read as a grid.
	sprite.rotation = 0.0


func take_damage(amount: float) -> void:
	if _broken:
		return
	health -= amount
	_flash()
	if health <= 0.0:
		_break()


func _flash() -> void:
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	sprite.modulate = HIT_FLASH
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _break() -> void:
	_broken = true
	## Drop out of collision immediately so the player is not left shoving an
	## invisible crate around while the shards fade.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	_drop()

	var shatter := create_tween()
	shatter.set_parallel(true)
	shatter.tween_property(sprite, "modulate:a", 0.0, 0.25)
	shatter.tween_property(sprite, "scale", sprite.scale * 1.25, 0.25)
	shatter.chain().tween_callback(queue_free)


func _drop() -> void:
	var picked: PackedScene = _roll()
	if picked == null:
		return
	var thing = picked.instantiate()
	## Parent to the map rather than to self, or it would be freed along with
	## the prop a quarter of a second later.
	get_parent().add_child(thing)
	thing.global_position = global_position


func _roll() -> PackedScene:
	var choices: Array[PackedScene] = []
	var weights: Array[float] = []
	if loot_scene != null:
		choices.append(loot_scene)
		weights.append(loot_weight)
	if spawn_scene != null:
		choices.append(spawn_scene)
		weights.append(spawn_weight)
	if not always_drops:
		choices.append(null)
		weights.append(empty_weight)
	if choices.is_empty():
		return null

	var total: float = 0.0
	for w in weights:
		total += w
	var roll: float = randf() * total
	for i in choices.size():
		roll -= weights[i]
		if roll <= 0.0:
			return choices[i]
	return choices[-1]
