extends Node2D

class QuietInput extends PlayerInput:
	var move := Vector2.ZERO
	var attack := false

	func vector() -> Vector2:
		return move

	func pressed(_action: String) -> bool:
		return false

	func just_pressed(action: String) -> bool:
		return attack and action == "Attack"

	func just_released(_action: String) -> bool:
		return false


const EXTERIOR := "res://scenes/props/japanese/exterior/"
const PROTECTED := [
	"chair.tscn", "exitStairs.tscn", "pickupDrink.tscn", "pickupFood.tscn",
	"pickupHealth.tscn", "pickupPower.tscn", "pickupScroll.tscn", "projectile.tscn"]
const ARENA := Vector2(50000, 50000)

var _checks := 0
var _failed := 0
var _maze: Node2D
var _capture_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.trim_prefix("--capture-dir=")
	call_deferred("_run")


func _check(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failed += 1
		push_error(description)


func _near(actual: float, expected: float, description: String) -> void:
	_check(is_equal_approx(actual, expected), "%s: got %s, expected %s" % [
		description, actual, expected])


func _frames(count: int = 6) -> void:
	for frame in count:
		await get_tree().physics_frame


func _fresh(path: String, where: Vector2 = ARENA, health: float = -1.0) -> Node2D:
	var prop := load(path).instantiate() as Node2D
	prop.position = where
	if health >= 0.0:
		prop.max_health = health
	if _maze != null:
		_maze.add_child(prop)
	else:
		add_child(prop)
	return prop


func _coverage() -> void:
	for dir in ["res://scenes/props/", "res://scenes/props/japanese/",
			"res://scenes/props/torches/", EXTERIOR]:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".tscn"):
				continue
			var prop := _fresh(dir + file)
			if file in PROTECTED:
				_check(not prop.is_in_group("breakable"), "protected " + file)
				_check(not prop.has_method("take_damage"), "no prop damage on " + file)
			else:
				_check(prop.is_in_group("breakable"), "breakable group: " + file)
				_check(prop.has_method("take_damage"), "damage handler: " + file)
			if dir == EXTERIOR or file == "brazier.tscn":
				_near(prop.scroll_chance, 0.0, "no new scroll loot: " + file)
				var parent := prop.get_parent()
				var child_count := parent.get_child_count()
				var health: float = prop.health
				prop.take_damage(1.0)
				_near(prop.health, health - 1.0, "nonlethal damage: " + file)
				_check(prop.is_in_group("breakable"), "survives nonlethal: " + file)
				prop.take_damage(10000.0)
				_check(not prop.is_in_group("breakable"), "removed from attacks: " + file)
				for child in prop.get_children():
					if child is LightOccluder2D:
						_check(not child.visible, "no broken shadow: " + file)
				await _frames()
				_near(prop.collision_layer, 0, "no broken collision: " + file)
				if prop is ExteriorProp and not prop.blocks_movement:
					var hurt := prop.get_node("HurtBox") as Area2D
					_check(not hurt.monitorable and hurt.collision_layer == 0,
						"nonblocking hurt shape disabled: " + file)
				await get_tree().create_timer(0.4).timeout
				_check(not is_instance_valid(prop), "freed after fade: " + file)
				_check(parent.get_child_count() == child_count - 1, "no new loot: " + file)
			else:
				prop.queue_free()
				await get_tree().process_frame


func _stop_actors() -> void:
	_maze.set_physics_process(false)
	_maze._wave_live = false
	for player in _maze._players:
		player.set_physics_process(false)
		player.get_node("FiniteStateMachine").process_mode = Node.PROCESS_MODE_DISABLED
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is EnemyBase:
			enemy.set_physics_process(false)
			enemy.get_node("FiniteStateMachine").process_mode = Node.PROCESS_MODE_DISABLED


func _combat() -> void:
	var player = _maze._player
	player.global_position = ARENA
	player.facing_dir = "east"
	var fsm := player.get_node("FiniteStateMachine") as FiniteStateMachine
	var slash := fsm.get_node("katanaSlashStand") as PlayerClass
	var blade_shape := player.action_area.get_node("CollisionShape2D") as CollisionShape2D
	for name in ["komainu_statue", "torii_gate", "grass_tuft", "pond_reeds", "spikeTrap"]:
		var path: String = EXTERIOR + name + ".tscn" if name != "spikeTrap" else "res://scenes/props/spikeTrap.tscn"
		var prop := _fresh(path, ARENA, 1000.0)
		if prop is SpikeTrap:
			prop.set_physics_process(false)
		fsm.current_state = slash
		slash.weapon_tween.stop()
		prop.global_position = blade_shape.global_position
		if name == "torii_gate":
			prop.global_position -= Vector2(-42, -21)
		await _frames()
		_check(player.blade_targets().count(prop) == 1, "one live blade target: " + name)
		slash.animated_sprite.frame = 3
		slash.playerAttack(2)
		slash.playerAttack(2)
		_near(prop.health, 1000.0 - player.phase_attack_damage(false, true), "one swing: " + name)
		fsm.change_state("idle")
		prop.queue_free()
		await _frames()

	for name in ["komainu_statue", "grass_tuft", "pond_reeds", "spikeTrap"]:
		var path: String = EXTERIOR + name + ".tscn" if name != "spikeTrap" else "res://scenes/props/spikeTrap.tscn"
		for kind in ["slash", "hostile"]:
			var prop := _fresh(path, ARENA + Vector2(500, 0), 1000.0)
			if prop is SpikeTrap:
				prop.set_physics_process(false)
			var shot_path := "res://scenes/fx/slashProjectile.tscn" if kind == "slash" else "res://scenes/props/projectile.tscn"
			var shot := _fresh(shot_path, prop.global_position - Vector2(90, 0))
			if kind == "slash":
				shot.launch(shot.global_position, Vector2.RIGHT, 7.0)
			else:
				shot.launch(shot.global_position, Vector2.RIGHT, null, {"damage": 7.0})
			for frame in 40:
				await get_tree().physics_frame
				if prop.health < 1000.0:
					break
			_near(prop.health, 993.0, kind + " actual hit: " + name)
			await _frames()
			_near(prop.health, 993.0, kind + " no repeated hit: " + name)
			if is_instance_valid(shot):
				shot.queue_free()
			prop.queue_free()
			await _frames()

	var enemy := _fresh("res://scenes/monsters/kappa.tscn", ARENA + Vector2(1000, 0)) as EnemyBase
	enemy.set_physics_process(false)
	enemy.get_node("FiniteStateMachine").process_mode = Node.PROCESS_MODE_DISABLED
	enemy.facing_dir = "east"
	for name in ["torii_gate", "grass_tuft", "spikeTrap"]:
		var path: String = EXTERIOR + name + ".tscn" if name != "spikeTrap" else "res://scenes/props/spikeTrap.tscn"
		var prop := _fresh(path, enemy.global_position + Vector2(70, 0), 1000.0)
		if prop is SpikeTrap:
			prop.set_physics_process(false)
		await _frames()
		enemy._strike_breakables(3.0)
		_near(prop.health, 1000.0 - enemy.effective_attack_damage(), "one enemy melee hit: " + name)
		prop.queue_free()
		await _frames()
	enemy.queue_free()


func _lifecycle() -> void:
	var prop := _maze._ext._put("komainu_statue", ARENA + Vector2(1500, 0), 45, true) as ExteriorProp
	_check(prop.get_node("Sprite2D").flip_h, "mirrored lion retained")
	_check(prop.max_health == 80, "stone statue durability")
	var chair := _fresh("res://scenes/props/chair.tscn", prop.global_position)
	var chair_pos := chair.global_position
	prop.take_damage(1)
	_near(prop.health, 79, "mirrored lion receives damage")
	prop.take_damage(10000)
	prop.take_damage(10000)
	await _frames()
	get_tree().paused = true
	var alpha: float = prop.sprite.modulate.a
	for frame in 8:
		await get_tree().process_frame
	_near(prop.sprite.modulate.a, alpha, "destruction pauses")
	_check(is_instance_valid(prop), "paused fade does not free prop")
	get_tree().paused = false
	await get_tree().create_timer(0.4).timeout
	_check(not is_instance_valid(prop), "destruction resumes")
	_check(is_instance_valid(chair) and chair.global_position == chair_pos,
		"chair survives nearby destruction")
	chair.queue_free()

	var tree := _fresh(EXTERIOR + "sakura_tree_a.tscn") as ExteriorProp
	var player = _maze._player
	player.global_position = tree.global_position + tree.fade_rect.get_center()
	tree._process(1.0)
	_near(tree.sprite.modulate.a, tree.faded_alpha, "canopy still fades behind player")
	tree.take_damage(10000)
	await _frames()
	var broken_alpha: float = tree.sprite.modulate.a
	tree._process(1.0)
	_near(tree.sprite.modulate.a, broken_alpha, "canopy cannot undo destruction fade")
	await get_tree().create_timer(0.4).timeout

	var walker := CharacterBody2D.new()
	walker.collision_layer = 1
	walker.collision_mask = 1
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6
	collision.shape = circle
	walker.add_child(collision)
	walker.position = ARENA - Vector2(60, 0)
	_maze.add_child(walker)
	for name in ["grass_tuft", "pond_reeds"]:
		var soft := _maze._ext._put(name, ARENA, 0) as ExteriorProp
		await _frames()
		_near(soft.collision_layer, 0, "generator preserves nonblocking: " + name)
		_check(not walker.test_move(walker.global_transform, Vector2(120, 0)),
			"can walk through intact " + name)
		soft.queue_free()
		await _frames()
	var statue := _fresh(EXTERIOR + "komainu_statue.tscn")
	await _frames()
	_check(walker.test_move(walker.global_transform, Vector2(120, 0)), "intact statue blocks walking")
	statue.take_damage(10000)
	await _frames()
	_check(not walker.test_move(walker.global_transform, Vector2(120, 0)), "broken statue clears walking")
	walker.queue_free()

	var lantern := _fresh("res://scenes/props/torches/stoneLantern.tscn") as Breakable
	lantern.scroll_chance = 0.0
	lantern.take_damage(10000)
	await get_tree().create_timer(0.4).timeout
	_check(is_instance_valid(lantern) and lantern._broken, "existing lantern retains broken art")
	_check(not lantern.is_in_group("breakable"), "persistent debris cannot be attacked again")
	_near(lantern.collision_layer, 0, "persistent debris does not block")
	for child in lantern.get_children():
		if child is PointLight2D:
			_check(not child.enabled, "broken lantern light disabled")
			_near(child.energy, 0, "broken lantern energy extinguished")
	lantern.queue_free()

	var trap := _fresh("res://scenes/props/spikeTrap.tscn")
	var hp: float = player.health
	trap._occupants.append(player)
	trap.take_damage(10000)
	trap._strike()
	trap._physics_process(10)
	await _frames()
	_near(player.health, hp, "broken trap no longer strikes")
	_check(not trap.monitoring and not trap.monitorable, "broken trap sensors disabled")
	_check(not trap.is_physics_processing(), "broken trap cycle disabled")
	await get_tree().create_timer(0.4).timeout
	_check(not is_instance_valid(trap), "broken trap freed")


func _chair_timer() -> void:
	var player = _maze._player
	var input := QuietInput.new()
	player.input = input
	player.global_position = ARENA + Vector2(2000, 0)
	var chair := _fresh("res://scenes/props/chair.tscn", player.global_position - Vector2(0, 10))
	await _frames()
	var fsm := player.get_node("FiniteStateMachine") as FiniteStateMachine
	var idle := fsm.get_node("idle") as PlayerClass
	fsm.current_state = idle
	_check(idle.chair_underfoot() == chair, "real chair overlaps player")
	_near(idle.REST_AFTER, 3, "three-second sitting threshold")
	idle.on_process(2.99)
	_check(fsm.current_state == idle, "does not sit before three seconds")
	idle.on_process(0.01)
	var sitting := fsm.get_node("sittingChair") as PlayerClass
	_check(fsm.current_state == sitting, "sits at three seconds")
	sitting._walk_in(2.0)
	player.health = player.max_health - 10
	sitting.on_physics_process(1.0)
	_near(player.health, player.max_health - 10 + player.rest_regen, "chair healing unchanged")
	input.attack = true
	sitting.on_process(0)
	_check(fsm.current_state == idle, "attack interrupts sitting")
	input.attack = false
	idle.on_process(3.0)
	input.move = Vector2.RIGHT
	sitting.on_process(0)
	_check(fsm.current_state == idle, "movement interrupts sitting")
	input.move = Vector2.ZERO
	idle.on_process(2.5)
	fsm.change_state("walk")
	fsm.current_state = idle
	idle.on_process(0.5)
	_check(fsm.current_state == idle, "leaving idle resets sitting timer")
	chair.queue_free()
	await _frames()
	idle.on_enter()
	idle.on_process(4.0)
	_check(fsm.current_state == idle, "no sitting without chair")


func _capture(name: String) -> void:
	if _capture_dir.is_empty():
		return
	for overlay_name in ["FloorLayer", "ClearLayer"]:
		var layer := _maze.get_node_or_null(overlay_name) as CanvasLayer
		if layer != null:
			layer.visible = false
	for frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := _capture_dir.path_join(name + ".png")
	_check(get_viewport().get_texture().get_image().save_png(path) == OK, "capture " + name)
	print("CAPTURE ", path)


func _floor(theme: int) -> void:
	_check(not _maze._ext.buildings.is_empty(), "buildings retained on theme %d" % theme)
	var lion: ExteriorProp = null
	for node in get_tree().get_nodes_in_group("exterior_prop"):
		_check(node.is_in_group("breakable"), "generated prop breakable: " + node.name)
		if node.scene_file_path.ends_with("komainu_statue.tscn"):
			lion = node
	_check(lion != null, "generated entrance lions on theme %d" % theme)
	for group in ["chair", "wall"]:
		for node in get_tree().get_nodes_in_group(group):
			_check(not node.is_in_group("breakable"), "protected generated " + group)
	for layer in _maze.find_children("*", "TileMapLayer", true, false):
		_check(not layer.is_in_group("breakable") and not layer.has_method("take_damage"),
			"wall/ground tile layer stays protected")
	for layers: Array in _maze._ext._roofs:
		for roof: Node in layers:
			_check(not roof.is_in_group("breakable") and not roof.has_method("take_damage"),
				"roof stays protected")
	for pond in _maze.find_children("Pond_*", "Node2D", true, false):
		_check(not pond.is_in_group("breakable"), "water stays protected")
		for child in pond.get_children():
			if child is StaticBody2D:
				_check(not child.has_method("take_damage") and child.collision_layer == 3,
					"water retains impassable collision")
	var doors := _maze.find_children("*", "SlidingDoor", true, false)
	_check(not doors.is_empty(), "generated doors still present")
	if not doors.is_empty():
		var door: SlidingDoor = doors[0]
		door.take_damage(10000)
		await _frames()
		_check(door._broken and door.collision_layer == 0 and not door._occluder.visible,
			"broken door remains permanently passable without shadow")
	var windows := _maze.find_children("*", "WindowPane", true, false)
	if not windows.is_empty():
		var window: WindowPane = windows[0]
		var window_layer := window.layer
		var cell := window.cell
		var source := window.broken_source
		window.take_damage(10000)
		await _frames()
		_check(not is_instance_valid(window) and window_layer.get_cell_source_id(cell) == source,
			"window retains existing broken-tile behavior")
	var exits := _maze.find_children("*", "Exit", true, false)
	for exit in exits:
		_check(not exit.is_in_group("breakable"), "exit not destructible")
	if lion != null:
		var hostile_count := get_tree().get_nodes_in_group("enemy").size()
		var camera := get_viewport().get_camera_2d()
		camera.position_smoothing_enabled = false
		camera.global_position = lion.global_position
		camera.reset_smoothing()
		_maze._player.global_position = lion.global_position + Vector2(100, 0)
		_maze._ext.update_roofs(10.0, Roster.bodies(get_tree()))
		camera.force_update_scroll()
		await _capture("props-theme-%d-intact" % theme)
		var broken := 0
		for node in get_tree().get_nodes_in_group("exterior_prop"):
			if node.global_position.distance_to(lion.global_position) < 900:
				node.take_damage(10000)
				broken += 1
		_check(broken > 0, "generated scenery destroyed")
		await get_tree().create_timer(0.6).timeout
		_check(get_tree().get_nodes_in_group("enemy").size() == hostile_count,
			"prop destruction leaves enemy wave count unchanged")
		_maze._wave_live = true
		_maze._check_wave_cleared()
		_check(not _maze._clearing, "prop destruction cannot advance floor")
		_maze._wave_live = false
		await _capture("props-theme-%d-broken" % theme)


func _run() -> void:
	await _coverage()
	Roster.clear()
	Roster.join(-1, 0)
	Score.begin_run()
	_maze = load("res://scenes/world/mazeDemo.tscn").instantiate()
	_maze.maze_seed = 101
	_maze.outdoor_weather = 0
	_maze.level_theme = 0
	get_tree().root.add_child(_maze)
	get_tree().current_scene = _maze
	while _maze._building or _maze._player == null:
		await get_tree().process_frame
	_stop_actors()
	await _combat()
	await _lifecycle()
	await _chair_timer()
	for theme in [0, 3, 4]:
		if theme != 0:
			_maze._level_theme = LevelTheme.definition(theme)
			_maze.descend()
			while _maze._building:
				await get_tree().process_frame
			_stop_actors()
		await _floor(theme)
	var doomed := _fresh(EXTERIOR + "komainu_statue.tscn")
	doomed.take_damage(10000)
	_maze.descend()
	while _maze._building:
		await get_tree().process_frame
	_stop_actors()
	_check(not is_instance_valid(doomed), "floor rebuild during destruction frees old prop")
	_check(is_instance_valid(_maze._player), "player survives rebuild")
	print("BREAKABLE ENVIRONMENT: %d checks, %d failures" % [_checks, _failed])
	_maze.queue_free()
	await get_tree().process_frame
	Roster.clear()
	get_tree().call_deferred("quit", 1 if _failed > 0 else 0)
