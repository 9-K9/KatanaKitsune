extends Node2D

class Recipient extends CharacterBody2D:
	var health: float = 10
	var max_health: float = 100
	var stamina: float = 0
	var max_stamina: float = 100
	var buff: int = -1
	var scrolls := ScrollInventory.new()

	func grant_buff(kind: int, _amount: float, _duration: float) -> void:
		buff = kind


var _checks := 0
var _failed := 0
var _used_sets: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _walker: CharacterBody2D


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failed += 1
		push_error(message)


func _ground(sprite: Sprite2D) -> float:
	var image := sprite.texture.get_image()
	var bounds := image.get_used_rect()
	return sprite.position.y + (sprite.offset.y + bounds.end.y - image.get_height() * 0.5) * sprite.scale.y


func _remember(texture: Texture2D) -> void:
	if texture != null:
		_used_sets[texture.resource_path.get_base_dir().get_file()] = true


func _directions() -> void:
	for index in range(8):
		_check(WorldObjects.direction_from_roll(0.0, index, true) == index + 1,
				"natural direction coverage")
	for index in range(4):
		_check(WorldObjects.direction_from_roll(0.799999, index, false) == index * 2 + 1,
				"isometric side of 80% boundary")
		_check(WorldObjects.direction_from_roll(0.8, index, false) == index * 2 + 2,
				"orthogonal side of 80% boundary")
	var counts := PackedInt32Array()
	counts.resize(8)
	var natural_counts := PackedInt32Array()
	natural_counts.resize(8)
	for i in 40000:
		counts[WorldObjects.direction_from_roll(_rng.randf(), _rng.randi(), false) - 1] += 1
		natural_counts[WorldObjects.direction_from_roll(_rng.randf(), _rng.randi(), true) - 1] += 1
	for i in 8:
		var expected := 8000 if i % 2 == 0 else 2000
		_check(abs(counts[i] - expected) < expected * 0.08, "80/20 distribution dir%d" % (i+1))
		_check(abs(natural_counts[i] - 5000) < 400, "uniform natural distribution dir%d" % (i+1))


func _library() -> void:
	var data := WorldObjects.catalog()
	_check(data["source_sets"].size() == 92, "all 92 source sets accounted for")
	for family: String in data["families"]:
		for direction in range(1, 9):
			var body := WorldObjects.scene(family, direction).instantiate() as Node2D
			body.position = Vector2(10000 + direction * 400, 10000)
			add_child(body)
			body.set_process(false)
			body.set_physics_process(false)
			var sprite := body.get_node("Sprite2D") as Sprite2D
			await get_tree().physics_frame
			_collision(body, family)
			_remember(sprite.texture)
			_check(body.get_meta("world_direction") == direction, family + " direction metadata")
			_check(sprite.hframes == 1, family + " directions are not animation frames")
			_check(absf(_ground(sprite)) < 0.01, family + " ground-contact pivot")
			_check(body.z_index == 0 and sprite.z_index == 0,
					family + " shares the actors' depth layer")
			_check(body.y_sort_enabled == (body is Chair),
					family + " sorts as one grounded object, or at the chair seat")
			if body is Pickup:
				_check(sprite.scale == Vector2(0.5, 0.5) and body.scale == Vector2.ONE,
						family + " exact half-size visual, full-size collection node")
				_check(body.use_world_art, family + " keeps supplied world art")
			elif family == "chair":
				_check(sprite.scale == Vector2(0.6, 0.6), "smaller seating visuals")
			elif data["trees"].has(family):
				var image := sprite.texture.get_image()
				var height := image.get_used_rect().size.y * sprite.scale.y
				_check(absf(height - float(data["player_height"]) * 2.0) < 0.2,
						family + " is twice the standing player's visible height")
				var bounds := image.get_used_rect()
				var top: int = bounds.end.y - maxi(1, roundi(bounds.size.y * 0.12))
				var left := image.get_width()
				var right := 0
				for y in range(top, bounds.end.y):
					for x in image.get_width():
						if image.get_pixel(x, y).a >= 128.0 / 255.0:
							left = mini(left, x)
							right = maxi(right, x + 1)
				var base_x: float = sprite.position.x + (
						(left + right) * 0.5 - image.get_width() * 0.5) * sprite.scale.x
				_check(absf(base_x) < 0.01, family + " collider aligns with roots, not canopy")
			else:
				_check(sprite.scale == Vector2.ONE, family + " retains native visual scale")
			if body is Chair:
				_check(body.find_children("*", "PhysicsBody2D", true, false).is_empty(),
						"chair has no physical blocker")
				_check(body.get_node("SitZone").collision_layer == 0,
						"chair detection area cannot block actors")
				_check(sprite.position.y < body.seat_offset.y,
						"seated actor sorts in front of chair")
				_check(body.get_sit_facing() == WorldObjects.FACINGS[direction-1],
						"chair uses selected authored facing")
				_check(body.get_sit_position().distance_to(body.position) < 25,
						"seated physics anchor remains by chair footprint")
			if body is Breakable:
				_remember(body.break_texture)
				if body.break_texture != null:
					var expected: Texture2D = body.break_texture
					body.take_damage(10000)
					_check(body.sprite.texture == expected, family + " matching broken state")
					_check(absf(_ground(sprite)) < 0.01, family + " broken-state pivot")
					_check(not body.is_in_group("breakable"), family + " leaves attack targets")
			if body is SpikeTrap:
				_remember(body.retracted_texture)
				_remember(body.extended_texture)
				body._set_phase(SpikeTrap.Phase.OUT)
				_check(sprite.texture == body.extended_texture and sprite.scale == Vector2.ONE,
						"trap extends using native art")
				body._set_phase(SpikeTrap.Phase.WARNING)
				_check(sprite.texture == body.retracted_texture and sprite.scale == Vector2.ONE,
						"trap telegraphs without distorting sprite")
				_check(absf(_ground(sprite)) < 0.01, "trap states share ground pivot")
			if family.ends_with("_unlit"):
				_check(not body.get_node("PointLight2D").enabled, "unlit prop has no active light")
			if family == "torii_gate":
				_check(body.has_node("Post0") and body.has_node("Post1"),
						"torii collides at posts, not across opening")
			body.queue_free()
		await get_tree().process_frame
	for name: String in data["source_sets"]:
		_check(_used_sets.has(name), "runtime scene/state coverage: " + name)


func _collision(body: Node2D, family: String) -> void:
	var target := body.global_position
	if family == "torii_gate":
		target = body.get_node("Post0").global_position
	var solid: bool = body is StaticBody2D and not (
			body is ExteriorProp and not body.blocks_movement)
	for mask in [1, 2]:
		_walker.collision_mask = mask
		for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP,
				Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(),
				Vector2(-1, -1).normalized(), Vector2(1, -1).normalized()]:
			var start := Transform2D(0, target + direction * 120)
			_check(_walker.test_move(start, -direction * 120) == solid,
					"%s blocks only intended movement, mask %d from %s" % [family, mask, direction])
	if family == "torii_gate":
		var a: Vector2 = body.get_node("Post0").position
		var b: Vector2 = body.get_node("Post1").position
		var across := (b - a).orthogonal().normalized()
		var middle := body.global_position + (a + b) * 0.5
		_check(not _walker.test_move(Transform2D(0, middle - across * 80), across * 160),
				"gate opening remains passable")


func _render_sorting() -> void:
	if not "--render-sorting" in OS.get_cmdline_user_args():
		return
	assert(DisplayServer.get_name() != "headless", "Sorting checks require a renderer")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.world_2d = World2D.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var stage := Node2D.new()
	stage.y_sort_enabled = true
	viewport.add_child(stage)
	var actor := Node2D.new()
	stage.add_child(actor)
	var marker := Polygon2D.new()
	marker.polygon = PackedVector2Array([
		Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)])
	marker.color = Color(0, 1, 0, 1)
	var material := CanvasItemMaterial.new()
	material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	marker.material = material
	actor.add_child(marker)
	for family: String in WorldObjects.catalog()["families"]:
		for direction in range(1, 9):
			var body := WorldObjects.scene(family, direction).instantiate() as Node2D
			body.position = Vector2(256, 400)
			stage.add_child(body)
			body.set_process(false)
			body.set_physics_process(false)
			var sprite := body.get_node("Sprite2D") as Sprite2D
			var image := sprite.texture.get_image()
			var bounds := image.get_used_rect()
			var pixel := Vector2i(-1, -1)
			for y in range(bounds.position.y + 2, bounds.end.y - 2):
				for x in range(bounds.position.x + 2, bounds.end.x - 2):
					var opaque := true
					for dy in range(-2, 3):
						for dx in range(-2, 3):
							if image.get_pixel(x + dx, y + dy).a < 0.99:
								opaque = false
					if opaque:
						pixel = Vector2i(x, y)
						break
				if pixel.x >= 0:
					break
			_check(pixel.x >= 0, family + " has opaque art for sorting check")
			var sample := sprite.to_global(Vector2(pixel) + Vector2(0.5, 0.5)
					- Vector2(image.get_size()) * 0.5 + sprite.offset)
			var sort_y: float = body.position.y + (body.sort_bias if body is Chair else 0.0)
			for front in [false, true]:
				actor.position = Vector2(256, sort_y + (1 if front else -1))
				marker.global_position = sample
				await RenderingServer.frame_post_draw
				var rendered := viewport.get_texture().get_image()
				var color := rendered.get_pixelv(Vector2i(sample.floor()))
				var green := color.g > 0.95 and color.r < 0.05 and color.b < 0.05
				_check(green == front, "%s dir%d renders actor %s" % [
					family, direction, "in front" if front else "behind"])
			body.queue_free()
			await get_tree().process_frame
	viewport.queue_free()


func _effects() -> void:
	var character = load("res://scenes/characters/Kitsune.tscn").instantiate()
	var animation := character.get_node("AnimationManager/AnimatedSprite2D") as AnimatedSprite2D
	var idle := animation.sprite_frames.get_frame_texture("idle_southWest", 0)
	_check(idle.get_image().get_used_rect().size.y == int(WorldObjects.catalog()["player_height"]),
			"tree sizing uses actual default standing sprite, not padded frame canvas")
	character.free()
	var recipient := Recipient.new()
	add_child(recipient)
	for family in ["onigiri", "sake_flask", "health_potion", "health_charm", "power_orb"]:
		var item := WorldObjects.scene(family).instantiate() as Pickup
		add_child(item)
		var before := recipient.health
		var stamina := recipient.stamina
		item._apply(recipient)
		if family in ["onigiri", "sake_flask"]:
			_check(recipient.stamina > stamina and recipient.health == before,
					family + " is a stamina food/drink pickup")
		elif family.begins_with("health"):
			_check(recipient.health > before, family + " restores health")
		else:
			_check(recipient.buff == Pickup.Kind.DAMAGE, "power orb preserves buff")
		item.queue_free()
	for kind in Scroll.COUNT:
		var item := WorldObjects.scene("scroll", kind + 1).instantiate() as Pickup
		item.scroll_kind = kind
		add_child(item)
		_check(item.sprite.texture.resource_path.contains("world_objects/scroll/"),
				"scroll retains world texture for type %d" % kind)
		_check(item.get_node("PointLight2D").color == Scroll.INK[kind].lightened(0.35),
				"scroll kind keeps identifying glow")
		_check(Scroll.icon(kind) != null, "existing scroll HUD icon preserved")
		item.queue_free()
	recipient.queue_free()


func _pools() -> void:
	var maze = load("res://scenes/world/mazeDemo.tscn").instantiate()
	var reachable: Dictionary = {}
	for group: Array in maze._prop_pool():
		for packed: PackedScene in group:
			reachable[WorldObjects.family_of(packed)] = true
	for packed: PackedScene in maze.torch_scenes + maze.table_scenes:
		reachable[WorldObjects.family_of(packed)] = true
	for name in ["chair", "pillar", "exit_stairs", "spike_trap_extended",
			"onigiri", "sake_flask", "health_potion", "health_charm", "power_orb", "scroll",
			"komainu_statue", "komainu_statue_b", "dragon_statue", "torii_gate", "pond_reeds", "grass_tuft"]:
		reachable[name] = true
	for i in LevelTheme.NAMES.size():
		var theme := LevelTheme.definition(i)
		var biome := theme.exterior_biome()
		_check(biome.unavailable_reason().is_empty(), "biome loads replacement library")
		for name in biome.trees + biome.edge_trees + biome.small_props + theme.small_props:
			reachable[name] = true
			_check(name != "sakura_tree_a", "no unreplaced Sakura placeholder")
	for family: String in WorldObjects.catalog()["families"]:
		_check(reachable.has(family), "spawn/drop pool reaches " + family)
	maze.free()


func _run() -> void:
	_rng.seed = 77241
	_walker = CharacterBody2D.new()
	_walker.collision_layer = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6
	shape.shape = circle
	_walker.add_child(shape)
	add_child(_walker)
	_directions()
	await _library()
	await _render_sorting()
	_effects()
	_pools()
	await get_tree().process_frame
	print("World objects: %d checks, %d failures" % [_checks, _failed])
	get_tree().quit(1 if _failed else 0)
