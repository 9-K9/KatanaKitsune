extends Node

class ProbePlayer extends CharacterBody2D:
	var slot: int = 0
	var is_dead: bool = false
	var katana_drawn: bool = true
	var actionBlockInput: bool = false
	var input: PlayerInput

	func winded() -> bool:
		return false

	func _physics_process(delta: float) -> void:
		if input == null:
			return
		input.update(delta)
		var move := input.vector().round()
		velocity = Vector2(move.x, move.y * 0.5) * 183.0
		move_and_slide()


class DamageProbe extends CharacterBody2D:
	var is_dead: bool = false
	var hits: int = 0

	func take_damage(_amount: float, _from: Vector2) -> void:
		hits += 1


class TestWorld extends Node2D:
	var active: bool = true

	func bot_controls_active() -> bool:
		return active


class MenuProbe extends PlayerInput:
	var action: String = ""
	var confirm: bool = false

	func just_pressed(which: String) -> bool:
		return which == action

	func confirm_pressed() -> bool:
		return confirm

	func cancel_pressed() -> bool:
		return false


var _checks: int = 0
var _failed: int = 0
var _world: TestWorld
var _human: ProbePlayer
var _bot: ProbePlayer


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failed += 1
		push_error(description)


func _shape(body: CollisionObject2D, size: Vector2) -> void:
	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	collision.shape = rect
	body.add_child(collision)


func _probe(slot: int, point: Vector2) -> ProbePlayer:
	var body := ProbePlayer.new()
	body.slot = slot
	body.position = point
	body.add_to_group("player")
	_shape(body, Vector2(64, 32))
	_world.add_child(body)
	return body


func _wall(point: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = point
	_shape(wall, size)
	_world.add_child(wall)
	return wall


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _roster_checks() -> void:
	Roster.clear()
	_check(Roster.add_bot() == -1, "a party needs a human before adding bots")
	_check(Roster.join(PlayerInput.BOT) == -1, "bot sentinel cannot claim a human device")
	_check(Roster.join(PlayerInput.KEYBOARD, 0) == 0, "keyboard joins unchanged")
	for i in 3:
		_check(Roster.add_bot() == i + 1, "bots occupy stable successive slots")
	_check(Roster.count() == 4 and Roster.human_count() == 1, "combined four-body cap")
	_check(Roster.add_bot() == -1 and Roster.join(9) == -1, "neither humans nor bots exceed cap")
	_check(Roster.input_for(0).device == PlayerInput.KEYBOARD, "human input remains device-bound")
	_check(Roster.input_for(1) is BotInput, "bot gets ordinary player action interface")
	_check(not Roster.has_device(PlayerInput.BOT), "bots never reserve hardware")
	for i in range(1, 4):
		_check(not Roster.scheme_taken(Roster.scheme_of(i), i), "bot costumes are unique")
	Roster._on_joy_changed(PlayerInput.BOT, false)
	_check(not Roster.any_lost(), "bot slots never trigger reconnect pauses")
	Score.begin_run()
	Score.points = [50, 500, 200, 100]
	_check(Score.best_of_run()["slot"] == 0, "high-score name entry belongs to a human")
	Progression.begin_run()
	Progression.gain(1, 240)
	var screen := LevelUpScreen.new()
	screen._spend_bot_points(1)
	_check(Progression.points[1] == 0, "bots spend upgrade points without blocking the menu")
	_check(Progression.rank(1, Progression.Stat.HEALTH) > 0, "bot upgrades use normal progression")
	screen.free()
	Roster.clear()
	for i in 4:
		_check(Roster.join(i, i) == i, "four-human roster remains supported")
	_check(Roster.human_count() == 4 and not Roster.is_bot(3), "four humans have no bot slots")
	Roster._on_joy_changed(2, false)
	_check(Roster.any_lost() and Roster.players[2]["lost"], "human disconnect retains its slot")
	Roster._on_joy_changed(8, true)
	_check(not Roster.any_lost() and Roster.device_of(2) == 8, "replacement pad rescues human slot")


func _follow_checks() -> void:
	Roster.clear()
	Roster.join(PlayerInput.KEYBOARD)
	Roster.add_bot()
	_world = TestWorld.new()
	add_child(_world)
	_human = _probe(0, Vector2(500, 0))
	_bot = _probe(1, Vector2.ZERO)
	_bot.add_collision_exception_with(_human)
	_human.add_collision_exception_with(_bot)
	_bot.input = Roster.input_for(1)
	_bot.input.bind_body(_bot)
	await _frames(180)
	_check(BotNavigation.ground(_human.position - _bot.position).length() <= 160.0,
			"bot follows human and stops near them")
	_check(_bot.input.vector() == Vector2.ZERO, "bot does not crowd its human")
	_bot.position = Vector2.ZERO
	_bot.input.reset()
	var wall := _wall(Vector2(200, 0), Vector2(40, 220))
	await _frames(600)
	_check(BotNavigation.ground(_human.position - _bot.position).length() <= 165.0,
			"bounded pathfinding takes a route around a wall corner")
	_check((_bot.input as BotInput).navigation.expansions <= BotNavigation.MAX_EXPANSIONS,
			"navigation search stays bounded")
	wall.queue_free()
	await _frames(2)
	_bot.position = Vector2.ZERO
	_bot.input.reset()
	var trap := Area2D.new()
	trap.position = Vector2(240, 0)
	trap.add_to_group("bot_hazard")
	_shape(trap, Vector2(48, 24))
	_world.add_child(trap)
	var nearest: float = INF
	for _i in 450:
		await get_tree().physics_frame
		nearest = minf(nearest, BotNavigation.ground(_bot.position - trap.position).length())
	_check(nearest >= BotNavigation.HAZARD_MARGIN,
			"bot avoids trap footprints even while retracted")
	_check(BotNavigation.ground(_human.position - _bot.position).length() <= 165.0,
			"bot can follow around a trap")
	_check(not (_bot.input as BotInput).navigation.safe_segment(Vector2.ZERO, Vector2(500, 0)),
			"unsafe direct follow has no hazard-crossing fallback")
	trap.queue_free()
	await _frames(2)
	_world.active = false
	var before := _bot.position
	await _frames(20)
	_check(_bot.position == before and _bot.input.vector() == Vector2.ZERO,
			"loading/floor teardown freezes bot controls")
	_world.active = true
	_bot.position = Vector2.ZERO
	_bot.input.reset()
	get_tree().paused = true
	await get_tree().create_timer(0.1, true).timeout
	_check(_bot.position == Vector2.ZERO, "pause stops bot simulation")
	get_tree().paused = false
	await _frames(120)
	_check(_bot.position.x > 0, "unpause resumes following")
	_bot.is_dead = true
	before = _bot.position
	await _frames(10)
	_check(_bot.position == before, "fallen bot stays down")
	_bot.is_dead = false
	_human.position = Vector2(-500, 0)
	_bot.position = Vector2.ZERO
	_bot.input.reset()
	await _frames(180)
	_check(_bot.position.x < -300, "controller reset follows a rebuilt floor's new spawn")
	_human.is_dead = true
	await _frames(20)
	_check(_bot.input.vector() == Vector2.ZERO, "bots stop when no living human remains")
	var over = load("res://scenes/menuscreens/gameOver.tscn").instantiate()
	_world.add_child(over)
	over.set_process(false)
	_check(over._is_dead(), "all humans down ends the run even with a living bot")
	_human.is_dead = false
	_check(not over._is_dead(), "a living human keeps the run active")
	over.free()
	_world.queue_free()
	await _frames(2)


func _combat_checks() -> void:
	_world = TestWorld.new()
	add_child(_world)
	_human = _probe(0, Vector2(-200, 0))
	# Only one shared player SpriteFrames resource, in a tiny empty physics world.
	var player = load("res://scenes/characters/KatanaKitsune.tscn").instantiate()
	player.slot = 1
	_world.add_child(player)
	player.add_collision_exception_with(_human)
	_human.add_collision_exception_with(player)
	var enemy := DamageProbe.new()
	enemy.position = Vector2(95, 0)
	enemy.collision_layer = 3
	enemy.add_to_group("enemy")
	# Match kappa's actual ground body and torso hitbox without loading its art.
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 32.0 * 1.125
	collision.shape = circle
	enemy.add_child(collision)
	var hitbox := Area2D.new()
	hitbox.collision_layer = 2
	hitbox.collision_mask = 0
	var torso := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 31.0 * 1.125
	capsule.height = 164.0 * 1.125
	torso.position = Vector2(0, -48) * 1.125
	torso.shape = capsule
	hitbox.add_child(torso)
	enemy.add_child(hitbox)
	_world.add_child(enemy)
	await _frames(240)
	_check(player.input is BotInput, "real player scene binds bot input")
	_check(player.katana_drawn, "bot draws through normal player state machine")
	if enemy.hits == 0:
		print("Combat diagnostic: position=", player.position,
				" state=", player.get_node("FiniteStateMachine").current_state.name,
				" goal=", player.input._goal, " path=", player.input.navigation.path,
				" predicted=", player.can_slash_target(enemy, "east"),
				" live=", player.blade_targets())
	_check(enemy.hits > 0, "bot deals damage only through real slash hit frames")
	var target_aim := BotNavigation.ground(enemy.position - player.position).normalized().round()
	_check(player.facing_dir == IsoFacing.name_of(target_aim), "bot aims its attack at its target")
	_check(not player.input.pressed("ScrollUse"), "bot never requests scroll use")
	player.get_node("FiniteStateMachine").change_state("katanaIdle")
	player.position = Vector2.ZERO
	enemy.position = Vector2(0, 75)
	player.input.reset()
	var enemy_machine := FiniteStateMachine.new()
	enemy_machine.name = "FiniteStateMachine"
	var stomp := StateMachineState.new()
	stomp.name = "stomp"
	enemy_machine.add_child(stomp)
	enemy.add_child(enemy_machine)
	enemy_machine.current_state = stomp
	var previous_distance := BotNavigation.ground(enemy.position - player.position).length()
	await _frames(40)
	_check(BotNavigation.ground(enemy.position - player.position).length() > previous_distance + 20.0,
			"bot safely backs away from a heavy attack telegraph")
	enemy_machine.current_state = null
	enemy.is_dead = true
	await _frames(20)
	_check(not player.input.pressed("Attack"), "dead enemies are not targeted")
	enemy.is_dead = false
	for facing in IsoFacing.NAMES:
		player.get_node("FiniteStateMachine").change_state("katanaIdle")
		player.position = Vector2.ZERO
		player.input.reset()
		var direction := IsoFacing.vector_of(facing)
		enemy.position = Vector2(direction.x, direction.y * 0.5) * 180.0
		var before: int = enemy.hits
		var states: Dictionary = {}
		for _i in 300:
			await get_tree().physics_frame
			states[player.get_node("FiniteStateMachine").current_state.name] = true
		if enemy.hits == before:
			print("Facing diagnostic: ", facing, " position=", player.position,
					" states=", states.keys(), " goal=", player.input._goal,
					" path=", player.input.navigation.path,
					" predicted stand=", player.can_slash_target(enemy, facing))
		_check(enemy.hits > before, "real collision-aware slash connects approaching from " + facing)
		var aim := BotNavigation.ground(enemy.position - player.position).normalized().round()
		_check(player.facing_dir == IsoFacing.name_of(aim), "bot faces target approaching from " + facing)
	# Walls block sight and attacks, even while the target is still remembered.
	player.get_node("FiniteStateMachine").change_state("katanaIdle")
	player.position = Vector2.ZERO
	player.input.reset()
	enemy.position = Vector2(200, 0)
	var wall := _wall(Vector2(100, 0), Vector2(20, 400))
	await _frames(2)
	_check(not player.input._visible(player, enemy), "walls exclude hidden enemies")
	enemy.position = Vector2(1200, 0)
	await _frames(20)
	_check(player.input._living(player.input._target) == null, "bot abandons distant targets")
	wall.queue_free()
	player.is_dead = true
	_world.queue_free()
	await _frames(2)


func _menu_checks() -> void:
	var select = load("res://scenes/menuscreens/characterSelect.tscn").instantiate()
	add_child(select)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	select.set_process(false)
	var probe := MenuProbe.new()
	var probes: Array[PlayerInput] = [probe]
	select._menu_probes = probes
	_check(select._bot_count == 0, "AI teammates default to opt-out")
	probe.confirm = true
	select._drive_count()
	probe.confirm = false
	_check(select._phase == select.Phase.BOTS, "human count leads to AI count")
	probe.action = "MenuRight"
	for _i in 5:
		select._drive_bots()
	_check(select._bot_count == 3, "one human can select at most three bots")
	probe.action = ""
	select._go_back()
	select._wanted = 4
	probe.confirm = true
	select._drive_count()
	_check(select._phase == select.Phase.CLAIM and select._bot_count == 0,
			"four-human flow skips AI setup")
	select.queue_free()
	await _frames(2)
	Roster.clear()
	Roster.join(PlayerInput.KEYBOARD)
	for _i in 3:
		Roster.add_bot()
	Progression.begin_run()
	for slot in range(1, 4):
		Progression.gain(slot, 240)
	var screen := LevelUpScreen.new()
	screen.party = 4
	var completed: Array[bool] = [false]
	screen.finished.connect(func(): completed[0] = true)
	add_child(screen)
	for slot in range(1, 4):
		_check(screen._columns[slot]["ready"], "AI upgrade column is automatically ready")
		_check(Progression.points[slot] == 0, "AI points are spent when the real menu opens")
	await _frames(30)
	_check(completed[0], "real upgrade menu finishes without waiting for bot input")
	screen.queue_free()
	await _frames(2)


func _run() -> void:
	# Parse the changed integration surfaces without loading the actual maze.
	for path in ["res://scripts/system/MazeDemo.gd", "res://scripts/system/CharacterSelect.gd",
			"res://scripts/system/HUD.gd", "res://scripts/system/GameOver.gd"]:
		_check(load(path) != null, "script loads: " + path)
	_roster_checks()
	if "--combat-only" not in OS.get_cmdline_user_args():
		await _follow_checks()
	else:
		Roster.clear()
		Roster.join(PlayerInput.KEYBOARD)
		Roster.add_bot()
	await _combat_checks()
	await _menu_checks()
	Roster.clear()
	Progression.begin_run()
	Score.begin_run()
	print("AI companions: %d checks, %d failures" % [_checks, _failed])
	get_tree().quit(1 if _failed else 0)
