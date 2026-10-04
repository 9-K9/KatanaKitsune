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
## Lay the drop out on top of the prop instead of hiding it inside. A meal on a
## table should be visible before you smash the table — you break it *because*
## you can see the food, rather than smashing furniture on spec.
@export var display_loot: bool = false
## How far above this prop's base its surface is. The drop is drawn there, but
## parked at the base, so it sorts with the furniture instead of behind it.
@export var loot_display_lift: float = 46.0
@export var loot_weight: float = 6.0
@export var spawn_scene: PackedScene = null
@export var spawn_weight: float = 2.0
## Chance of dropping nothing at all.
@export var empty_weight: float = 3.0

@export var max_health: float = 25.0
## Chests are meant to feel worth hitting, so they always drop.
@export var always_drops: bool = false
@export var break_texture: Texture2D
## The four isometric facings, in this order: southEast, southWest, northWest,
## northEast. Those are the directions that run along the tile grid rather than
## across it, so a prop turned to one of them sits square to the room. Leave
## empty for a prop with only one view, which still works exactly as before.
@export var facing_textures: Array[Texture2D] = []
## The same four, shattered. Falls back to break_texture when it is short, so a
## prop can have directional art before its debris does.
@export var facing_break_textures: Array[Texture2D] = []
@export_range(1, 8, 1) var break_frames: int = 4
@export_range(0.03, 0.3, 0.01) var break_frame_time: float = 0.09
## Frames in the intact sprite, cycled while the prop is whole. 0 leaves it
## static, which is every crate and urn. A torch sets this to the length of its
## flame loop, so the fire moves without needing an AnimatedSprite2D — which
## would mean a second prop class purely because one sprite animates, and would
## not survive _break swapping the texture out from under it.
@export_range(0, 16, 1) var lit_frames: int = 0
@export_range(2.0, 24.0, 1.0) var lit_fps: float = 9.0
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


## Which way this one faces, as an index into facing_textures.
var facing_index: int = 0



## Turns the prop to one of the floor axes. Called by the generator as it places
## each one, so a room is not full of identically-oriented furniture. Named to
## match Chair.face_randomly, which is what MazeDemo already looks for.
func face_randomly(rng: RandomNumberGenerator) -> void:
	if facing_textures.is_empty():
		return
	facing_index = rng.randi() % facing_textures.size()
	_apply_facing()


func _apply_facing() -> void:
	if facing_textures.is_empty():
		return
	var art: Texture2D = facing_textures[facing_index % facing_textures.size()]
	if art == null:
		return
	## The sprite may not be resolved yet when the generator turns the prop
	## before adding it to the tree, so this does not rely on @onready.
	var node := get_node_or_null("Sprite2D") as Sprite2D
	if node != null:
		node.texture = art


## The shattered art for the way this one faces.
func _broken_texture() -> Texture2D:
	if facing_index < facing_break_textures.size():
		var art: Texture2D = facing_break_textures[facing_index]
		if art != null:
			return art
	return break_texture


## The drop, chosen and instanced up front when it is displayed, so the item you
## can see on the table is the exact one that falls off it.
var _displayed: Node2D = null


func _ready() -> void:
	health = max_health
	add_to_group("breakable")
	_apply_facing()
	if display_loot:
		_lay_out_loot()
	## Nudge each prop off the exact tile centre so a room full of urns does not
	## read as a grid.
	sprite.rotation = 0.0
	var shader := Shader.new()
	shader.code = HIT_FLASH_SHADER
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = shader
	sprite.material = _flash_material
	if lit_frames > 1:
		sprite.hframes = lit_frames
		## Staggered, or every torch on the floor flickers in lockstep and the
		## room pulses as one light instead of several.
		_lit_at = randf() * float(lit_frames)
	else:
		set_process(false)


var _lit_at: float = 0.0


func _process(delta: float) -> void:
	if _broken or lit_frames <= 1:
		return
	_lit_at = fmod(_lit_at + delta * lit_fps, float(lit_frames))
	sprite.frame = int(_lit_at)


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
	_douse()

	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	_set_flash_amount(0.0)

	var shattered: Texture2D = _broken_texture()
	if shattered != null:
		sprite.texture = shattered
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


## Puts out any flame this prop was carrying.
##
## A lantern that keeps burning after it is shattered is the obvious tell, and
## for a prop with persist_broken the light would otherwise hang over the rubble
## for the rest of the run. Guttering it over a fifth of a second rather than
## cutting it reads as the flame dying rather than as the light being switched
## off, and it lands while the break frames are still playing.
##
## Written generically, in the base class, because any prop may carry a light
## and none of them should keep it: a brazier, a lantern, a candle on a table.
func _douse() -> void:
	for child in get_children():
		if child is PointLight2D:
			var light := child as PointLight2D
			var gutter := create_tween()
			gutter.tween_property(light, "energy", 0.0, 0.22)
			gutter.tween_callback(func() -> void:
				if is_instance_valid(light):
					light.enabled = false)


## Puts the chosen drop on top of the prop, dormant.
func _lay_out_loot() -> void:
	var picked: PackedScene = _roll()
	if picked == null:
		return
	var thing = picked.instantiate()
	if not ("armed" in thing):
		return
	thing.armed = false
	## Centred on the prop and left at its base — the lift moves the picture, not
	## the node, so Y-sort still treats the meal as standing where the table
	## stands rather than up in the air behind it.
	if "display_lift" in thing:
		thing.display_lift = loot_display_lift
	add_child(thing)
	(thing as Node2D).position = Vector2.ZERO
	_displayed = thing
	## Already decided, so _break must not roll a second time.
	_drop_spawned = true


func _drop_once() -> void:
	if _drop_spawned:
		## A displayed drop is already in the world; it just needs releasing.
		_release_displayed()
		return
	_drop_spawned = true
	_drop()


## Tips the displayed item onto the floor and makes it takeable.
func _release_displayed() -> void:
	if not is_instance_valid(_displayed):
		return
	var item := _displayed
	_displayed = null
	var landing: Vector2 = global_position
	## Reparented to the map, or it would be freed with the prop moments later.
	var keep := get_parent()
	item.reparent(keep)
	if item.has_method("arm"):
		item.arm(landing)


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
