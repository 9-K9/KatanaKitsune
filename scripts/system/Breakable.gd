class_name Breakable
extends StaticBody2D

## A destructible dungeon prop: urns, crates, chests, statues.
##
## Takes katana hits like an enemy does (the player's attack code only needs a
## take_damage method), flashes, then shatters into whatever it was holding —
## a pickup, or something unpleasant that was nesting inside it.

## What comes out when it breaks. Weights are relative, not percentages.
@export var loot_scene: PackedScene = null
## Alternatives for the loot slot, chosen between at random when the prop
## breaks. A table holds a meal, and a meal is food or drink — without this a
## breakable could only ever drop one thing, and the second would have to be
## smuggled into spawn_scene, which means "something unpleasant was nesting in
## here" and would read as a bug to the next person.
@export var loot_scenes: Array[PackedScene] = []
@export var loot_weight: float = 6.0
@export var spawn_scene: PackedScene = null
@export var spawn_weight: float = 2.0
## Chance of dropping nothing at all.
@export var empty_weight: float = 3.0

@export var max_health: float = 25.0
## Chests are meant to feel worth hitting, so they always drop.
@export var always_drops: bool = false
@export var break_texture: Texture2D
@export_range(1, 8, 1) var break_frames: int = 4
@export_range(0.03, 0.3, 0.01) var break_frame_time: float = 0.09
## Keep the final broken sprite instead of fading and freeing the prop.
@export var persist_broken: bool = false

const HIT_FLASH_SHADER := """
shader_type canvas_item;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(source.rgb, vec3(1.0), flash_amount), source.a);
}
"""

@onready var sprite: Sprite2D = $Sprite2D

var health: float = 0.0
var _broken: bool = false
var _flash_tween: Tween = null
var _flash_material: ShaderMaterial
var _drop_spawned: bool = false


func _ready() -> void:
	health = max_health
	add_to_group("breakable")
	## Nudge each prop off the exact tile centre so a room full of urns does not
	## read as a grid.
	sprite.rotation = 0.0
	var shader := Shader.new()
	shader.code = HIT_FLASH_SHADER
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = shader
	sprite.material = _flash_material


## `from` is where the blow came from. Unused here — a crate has no facing to
## guard with and does not bleed — but it has to be accepted: everything a swing
## can hit is called through one path, and callers pass the source so characters
## can work out guard angles and throw blood the right way. Without it, every
## hit on a breakable threw "Expected 1 argument" and the crate never took the
## damage.
func take_damage(amount: float, _from: Vector2 = Vector2.INF,
		_guardable: bool = true) -> void:
	if _broken:
		return
	health -= amount
	_flash()
	if health <= 0.0:
		_break()


func _flash() -> void:
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	_flash_material.set_shader_parameter("flash_amount", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash_amount, 1.0, 0.0, 0.16)


func _set_flash_amount(amount: float) -> void:
	if is_instance_valid(_flash_material):
		_flash_material.set_shader_parameter("flash_amount", amount)


func _break() -> void:
	_broken = true
	## Drop out of collision immediately so the player is not left shoving an
	## invisible crate around while the shards fade.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	_set_flash_amount(0.0)

	if break_texture != null:
		sprite.texture = break_texture
		sprite.hframes = break_frames
		sprite.frame = 0
		for frame_index in break_frames:
			sprite.frame = frame_index
			if frame_index == mini(2, break_frames - 1):
				_drop_once()
			await get_tree().create_timer(break_frame_time, false).timeout
	else:
		_drop_once()

	_drop_once()
	if persist_broken:
		sprite.frame = break_frames - 1
		return
	var fade := create_tween()
	fade.set_parallel(true)
	fade.tween_property(sprite, "modulate:a", 0.0, 0.32)
	fade.tween_property(sprite, "position:y", sprite.position.y - 3.0, 0.32)
	await fade.finished
	queue_free()


func _drop_once() -> void:
	if _drop_spawned:
		return
	_drop_spawned = true
	_drop()


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
	var loot: PackedScene = loot_scene
	if not loot_scenes.is_empty():
		loot = loot_scenes[randi() % loot_scenes.size()]
	if loot != null:
		choices.append(loot)
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
