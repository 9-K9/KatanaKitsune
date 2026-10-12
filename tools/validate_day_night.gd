extends Node

class MovingInput extends PlayerInput:
	func vector() -> Vector2:
		return Vector2.RIGHT

	func pressed(action: String) -> bool:
		return action == "Run"

	func just_pressed(_action: String) -> bool:
		return false

	func just_released(_action: String) -> bool:
		return false


class DamageProbe extends CharacterBody2D:
	var hits: Array[float] = []

	func take_damage(amount: float, _from: Vector2) -> void:
		hits.append(amount)


var _failed: int = 0
var _checks: int = 0
var _maze: Node2D
var _capture_dir: String = ""


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
	_check(is_equal_approx(actual, expected),
			"%s: got %s, expected %s" % [description, actual, expected])


func _clock_checks() -> void:
	var cycle := DayNightCycle.new()
	for row in [
		[0.0, false, 0.0], [299.999, false, 0.0], [300.0, true, 0.0],
		[310.0, true, 0.5], [320.0, true, 1.0], [599.999, true, 1.0],
		[600.0, false, 1.0], [610.0, false, 0.5], [620.0, false, 0.0],
		[900.0, true, 0.0], [920.0, true, 1.0], [1200.0, false, 1.0],
		[1220.0, false, 0.0],
	]:
		cycle.elapsed = row[0]
		_check(cycle.is_night() == row[1], "phase at %s" % row[0])
		_near(cycle.night_weight(), row[2], "light blend at %s" % row[0])
		var night: bool = row[1]
		_near(cycle.player_damage_factor(false, true), 1.0 if night else 1.25, "katana factor")
		_near(cycle.player_damage_factor(true, true), 1.25 if night else 1.0, "stealth only factor")
		_near(cycle.player_damage_factor(false, false), 1.0, "unarmed factor")
		_near(cycle.sneak_cost_factor(), 0.75 if night else 1.0, "sneak factor")
		_near(cycle.stamina_cost_factor(true), 1.0 if night else 0.75, "katana stamina factor")
		_near(cycle.stamina_cost_factor(false), 1.0, "sheathed stamina factor")
		_near(cycle.run_factor(true), 1.2 if night else 1.0, "ninja run factor")
		_near(cycle.run_factor(false), 1.0 if night else 1.2, "katana run factor")
		_near(cycle.sight_factor(), 0.75 if night else 1.25, "sight factor")
		_near(cycle.hostile_damage_factor(), 2.0 if night else 1.0, "hostile damage factor")
	cycle.elapsed = 0.0
	cycle.advance(1810.0)
	_check(not cycle.is_night(), "large delta crosses three cycles")
	_near(cycle.night_weight(), 0.5, "large delta retains dawn fade")
	_near(cycle.seconds_remaining(), 290.0, "countdown after large delta")


func _stop_actors() -> void:
	for body in _maze._players:
		body.set_physics_process(false)
		body.get_node("FiniteStateMachine").process_mode = Node.PROCESS_MODE_DISABLED
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is EnemyBase:
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
	_maze.set_physics_process(false)
	_maze._wave_live = false


func _run() -> void:
	_clock_checks()
	Roster.clear()
	for slot in 4:
		_check(Roster.join(slot - 1, slot) == slot, "join player %d" % slot)
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
	_check(_maze._players.size() == 4, "four real players")
	var cycle: DayNightCycle = _maze.day_night
	_check(not cycle.is_night(), "fresh run starts day")
	var rng_state: int = _maze._rng.state
	var before: float = cycle.elapsed
	_maze._physics_process(1.0)
	_near(cycle.elapsed, before + 1.0, "playable floor advances")
	_check(_maze._rng.state == rng_state, "clock does not consume maze RNG")
	_maze._building = true
	before = cycle.elapsed
	_maze._physics_process(30.0)
	_near(cycle.elapsed, before, "build freezes clock")
	_maze._building = false
	SceneLoader.begin()
	_maze._physics_process(30.0)
	_near(cycle.elapsed, before, "loading freezes clock")
	SceneLoader.finish()
	get_tree().paused = true
	for frame in 3:
		await get_tree().process_frame
	_maze._physics_process(30.0)
	_near(cycle.elapsed, before, "pause freezes clock")
	get_tree().paused = false

	for player in _maze._players:
		for phase in [0.0, 320.0]:
			cycle.elapsed = phase
			var night := cycle.is_night()
			player.katana_drawn = true
			player.stamina = 100.0
			player.drain_stamina(16.0, 1.0)
			_near(player.stamina, 84.0 if night else 88.0, "party drawn stamina")
			player.katana_drawn = false
			player.stamina = 100.0
			player.drain_stamina(16.0, 1.0)
			_near(player.stamina, 84.0, "party sheathed stamina")
			player.sneak = 100.0
			player.drain_sneak(12.0, 1.0)
			_near(player.sneak, 91.0 if night else 88.0, "party sneak movement")
			player.spend_sneak(35.0)
			_near(player.sneak, 64.75 if night else 53.0, "party strike cost")
			_near(player.phase_run_speed(true), player.runSpeed * (1.2 if night else 1.0), "party ninja run")
			_near(player.phase_run_speed(false), player.runSpeed * (1.0 if night else 1.2), "party katana run")
	var loose := Node.new()
	_check(DayNightCycle.for_node(loose) == null, "nonmaze scenes have no cycle")
	loose.free()

	var player = _maze._players[0]
	var player_base: float = player.damage
	player.use_scroll(Scroll.Kind.ATTACK)
	player.use_scroll(Scroll.Kind.SPEED)
	cycle.elapsed = 0.0
	_near(player.phase_attack_damage(false, true), player_base * 1.6 * 1.25, "attack scroll + day")
	_near(player.phase_run_speed(false), player._base_run * 1.4 * 1.2, "speed scroll + day")
	var probe := DamageProbe.new()
	probe.collision_layer = 2
	probe.collision_mask = 0
	probe.add_to_group("breakable")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 500.0
	shape.shape = circle
	probe.add_child(shape)
	_maze.add_child(probe)
	probe.global_position = player.action_area.global_position
	for i in 4:
		await get_tree().physics_frame
	_check(player.blade_targets().has(probe), "real blade overlaps damage probe")
	for phase in [0.0, 320.0]:
		cycle.elapsed = phase
		for state_name in ["katanaSlashStand", "katanaSlashCrouched", "katanaKick", "flair", "katanaCounterSlash", "katanaChargeAttack"]:
			var state: PlayerClass = player.get_node("FiniteStateMachine/" + state_name)
			probe.hits.clear()
			player.sneak = 100.0
			state.on_enter()
			if state_name == "katanaChargeAttack":
				state._charge = state.MAX_CHARGE
				state._release()
			state.animated_sprite.frame = 3
			state.playerAttack(2)
			state.playerAttack(2)
			var base_factor: float = 4.0 if state_name == "flair" else (
					2.0 if state_name == "katanaCounterSlash" else (
					3.0 if state_name == "katanaChargeAttack" else 1.0))
			var phase_factor: float = 1.25 if (
					(cycle.is_night() and state_name == "flair") or (
					not cycle.is_night() and state_name != "flair" and state_name != "katanaKick")) else 1.0
			_check(probe.hits.size() == 1, state_name + " hits once")
			if not probe.hits.is_empty():
				_near(probe.hits[0], player_base * 1.6 * base_factor * phase_factor, state_name + " composed damage")
			state.on_exit()
			_near(player.damage, player_base * 1.6, state_name + " leaves base intact")
	probe.queue_free()
	var counter: PlayerClass = player.get_node("FiniteStateMachine/katanaCounterSlash")
	counter.on_enter()
	player.buffs.erase(player.SCROLL_BUFF + Scroll.Kind.ATTACK)
	player._apply_buffs()
	_near(player.damage, player_base, "buff expiry during counter")
	counter.on_exit()
	_near(player.damage, player_base, "counter exit does not restore expired buff")
	player.input = MovingInput.new()
	for mode in ["katanaRun", "ninjaRun"]:
		var state: PlayerClass = player.get_node("FiniteStateMachine/" + mode)
		state.on_enter()
		for phase in [0.0, 320.0, 620.0]:
			cycle.elapsed = phase
			player.stamina = 100.0
			player.sneak = 100.0
			state.on_process(0.0)
			var ninja: bool = mode == "ninjaRun"
			_near(player.speed, player.phase_run_speed(ninja) * (1.55 if ninja else 1.0), "mid-run phase " + mode)
		state.on_exit()
	player.use_scroll(Scroll.Kind.EXERTION)
	player.stamina = 30.0
	player.drain_stamina(100.0, 1.0)
	_near(player.stamina, 100.0, "exertion preserved")
	player.use_scroll(Scroll.Kind.INVISIBLE)
	player.sneak = 100.0
	cycle.elapsed = 320.0
	player.drain_sneak(12.0, 1.0)
	_near(player.sneak, 100.0, "invisibility continuous free drain")
	player.spend_sneak(35.0)
	_near(player.sneak, 73.75, "invisibility retains one-shot cost")
	player.buffs.erase(player.SCROLL_BUFF + Scroll.Kind.INVISIBLE)
	player.buffs.erase(player.SCROLL_BUFF + Scroll.Kind.EXERTION)
	player.buffs.erase(player.SCROLL_BUFF + Scroll.Kind.SPEED)
	player._apply_buffs()
	var fallen = _maze._players[1]
	fallen.global_position = player.global_position
	fallen.is_dead = true
	player.stealthed = true
	player.sneak = 100.0
	player._try_revive(1.0)
	_near(player.sneak, 68.5, "night revival cost")
	fallen.is_dead = false
	player.stealthed = false

	await _enemy_checks(player)
	cycle.elapsed = 320.0
	_maze._update_daylight(true)
	var saved_cycle: DayNightCycle = cycle
	before = cycle.elapsed
	_maze.descend()
	_near(cycle.elapsed, before, "descent immediately freezes clock")
	while _maze._building:
		await get_tree().process_frame
	_stop_actors()
	_check(_maze.day_night == saved_cycle, "descent retains same clock")
	_near(cycle.elapsed, before, "rebuild preserves elapsed time")
	_near((_maze.get_node("Gloom") as CanvasModulate).color.r, _maze.gloom.r, "new floor applies current lighting")
	_check(not DayNightCycle.new().is_night(), "new run resets")
	if not _capture_dir.is_empty():
		await _captures()
	print("DAY/NIGHT CHECKS: %d checks, %d failures" % [_checks, _failed])
	_maze.queue_free()
	await get_tree().process_frame
	Roster.clear()
	get_tree().quit(1 if _failed > 0 else 0)


func _enemy_checks(player: CharacterBody2D) -> void:
	var enemy: EnemyBase = load("res://scenes/monsters/jorogumo.tscn").instantiate()
	_maze.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.get_node("FiniteStateMachine").process_mode = Node.PROCESS_MODE_DISABLED
	enemy.apply_tier(4, 3)
	enemy.attack_damage = 10.0
	enemy.global_position = Vector2(40000, 40000)
	player.global_position = enemy.global_position + Vector2(200, 0)
	for i in range(1, 4):
		_maze._players[i].global_position = Vector2(60000 + i * 1000, 60000)
	player.katana_drawn = false
	player.crouched = false
	player.stealthed = false
	enemy.facing_dir = "east"
	enemy.detection_range = 420.0
	enemy.attack_range = 500.0
	var base_damage := enemy.attack_damage
	for phase in [0.0, 320.0, 620.0, 920.0, 1220.0]:
		_maze.day_night.elapsed = phase
		var night: bool = _maze.day_night.is_night()
		_near(enemy.effective_detection(), 315.0 if night else 525.0, "enemy phase sight")
		player.crouched = true
		_near(enemy.effective_detection(), (315.0 if night else 525.0) * player.stealth_ratio(), "stealth + phase sight")
		player.crouched = false
		_near(enemy.effective_attack_damage(), base_damage * (2.0 if night else 1.0), "tier/depth damage")
		player.is_invincible = false
		player.health = player.max_health
		Score.broke(player.slot)
		enemy.strike(1.0, 1.75)
		_near(player.max_health - player.health, base_damage * (2.0 if night else 1.0) * 1.75, "actual special strike damage")
	enemy.remove_from_group("enemy")
	_maze.day_night.elapsed = 320.0
	_near(enemy.effective_attack_damage(), base_damage, "nonhostile actor not doubled")
	enemy.add_to_group("enemy")
	var cast: Node = enemy.get_node("FiniteStateMachine/attack")
	for phase in [0.0, 320.0]:
		_maze.day_night.elapsed = phase
		cast._fire()
		var shot: Projectile = get_tree().get_nodes_in_group("projectile").back()
		shot.set_physics_process(false)
		var launched: float = base_damage * cast.damage_multiplier * (2.0 if phase > 0.0 else 1.0)
		_near(shot.damage, launched, "actual ranged launch damage")
		_maze.day_night.elapsed = 620.0 if phase > 0.0 else 320.0
		_near(shot.damage, launched, "in-flight phase snapshot")
		shot.queue_free()
		await get_tree().process_frame
	player.global_position = enemy.global_position + Vector2(500, 0)
	await get_tree().physics_frame
	_maze.day_night.elapsed = 0.0
	_check(enemy.sees_player(), "day sees distant player")
	_maze.day_night.elapsed = 320.0
	_check(not enemy.sees_player(), "night boundary bypasses stale sight cache")
	player.global_position = enemy.global_position + Vector2(200, 0)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20, 200)
	shape.shape = rectangle
	wall.add_child(shape)
	_maze.add_child(wall)
	wall.global_position = enemy.global_position + Vector2(100, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for phase in [0.0, 320.0]:
		_maze.day_night.elapsed = phase
		_check(not enemy._look_for_player(), "walls occlude sight in both phases")
	wall.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(enemy._look_for_player(), "clear sight after removing wall")
	player.global_position = enemy.global_position - Vector2(200, 0)
	_check(not enemy._look_for_player(), "vision cone retained")
	enemy.queue_free()


func _captures() -> void:
	var exterior: MazeExterior = _maze._ext
	var outdoor := exterior.start_cell
	var indoor: Vector2i = exterior.building_of.keys()[0]
	var camera := get_viewport().get_camera_2d()
	camera.position_smoothing_enabled = false
	for location in ["outdoor", "indoor"]:
		var centre := exterior.cell_centre(outdoor if location == "outdoor" else indoor)
		for body in _maze._players:
			body.global_position = centre + Vector2((body.slot - 1.5) * 100, absf(body.slot - 1.5) * 35)
			body.health = body.max_health
			body.is_invincible = false
			for kind in Scroll.COUNT:
				body.scrolls.add(kind)
			body.scrolls.selected = body.slot
		camera.global_position = centre
		camera.reset_smoothing()
		exterior.update_roofs(10.0, Roster.bodies(get_tree()))
		for phase in [0.0, 320.0]:
			_maze.day_night.elapsed = phase
			_maze._update_daylight(true)
			for overlay_name in ["FloorLayer", "ClearLayer"]:
				var overlay := _maze.get_node_or_null(overlay_name) as CanvasLayer
				if overlay != null:
					overlay.visible = false
			for frame in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var phase_name := "day" if phase == 0.0 else "night"
			var path := _capture_dir.path_join("day-night-%s-%s.png" % [location, phase_name])
			_check(get_viewport().get_texture().get_image().save_png(path) == OK, "save " + path)
			print("CAPTURE ", path)
		for layers: Array in exterior._roofs:
			for roof: CanvasItem in layers:
				if roof is JapaneseRoof:
					_near(roof.modulate.a, exterior._roof_alpha[exterior._roofs.find(layers)], "roof tint preserves fade alpha")
