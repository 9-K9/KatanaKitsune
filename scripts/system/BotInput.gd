class_name BotInput
extends PlayerInput

const THINK_INTERVAL: float = 0.25
const FOLLOW_REACH: float = 155.0
const LEASH: float = 650.0
const NOTICE_REACH: float = 400.0
const ATTACK_REACH: float = 210.0
const ATTACK_INTERVAL: float = 0.85
const TAP_TIME: float = 0.10
const READY_STATES: Array[StringName] = [&"katanaIdle"]
const THREAT_STATES: Array[StringName] = [
	&"Attack", &"Heavy", &"Charge", &"Stomp", &"Crit",
	&"attack", &"heavy", &"charge", &"stomp", &"crit",
]
const EVADE_STATES: Array[StringName] = [&"heavy", &"charge", &"stomp", &"crit"]
## Sneaking states a stealth strike (`flair`) can be thrown from.
const SNEAK_READY_STATES: Array[StringName] = [&"stealthIdle", &"stealthWalk"]
const DRAWN_STATES: Array[StringName] = [&"katanaIdle", &"katanaWalk", &"katanaRun"]

var navigation := BotNavigation.new()
var _body: WeakRef
var _anchor: WeakRef
var _target: WeakRef
## Until when the bot sees its current fight through; see BotTactics.ENGAGE_MS.
var _engaged_until_ms: int = 0
var _move := Vector2.ZERO
var _aim := Vector2.ZERO
var _think_left: float = 0.0
var _attack_left: float = 0.0
var _tap_left: float = 0.0
var _draw_left: float = 0.0
var _goal := Vector2.INF
var _repath_left: float = 0.0
var _navigation_left: float = 0.0


func _init() -> void:
	super(PlayerInput.BOT)


func bind_body(body: CharacterBody2D) -> void:
	_body = weakref(body)
	navigation.bind_body(body)
	reset()


func _sync() -> void:
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
	_anchor = null
	_target = null
	_think_left = 0.0
	_attack_left = 0.0
	_tap_left = 0.0
	_draw_left = 0.0
	_goal = Vector2.INF
	_repath_left = 0.0
	_navigation_left = 0.0
	navigation.reset()


func update(delta: float) -> void:
	_was = _now
	_now = {}
	_move = Vector2.ZERO
	_aim = Vector2.ZERO
	var body := _body.get_ref() as CharacterBody2D if _body != null else null
	if not is_instance_valid(body) or body.get("is_dead") == true:
		reset()
		return
	var world := body.get_parent()
	if body.get_tree().paused or (world.has_method("bot_controls_active") \
			and not world.bot_controls_active()):
		reset()
		return
	_attack_left = maxf(_attack_left - delta, 0.0)
	_draw_left = maxf(_draw_left - delta, 0.0)
	_tap_left = maxf(_tap_left - delta, 0.0)
	_think_left -= delta
	_repath_left -= delta
	_navigation_left -= delta
	if _think_left <= 0.0:
		_think_left = THINK_INTERVAL
		_choose_anchor(body)
		_choose_target(body)
	var anchor := _living(_anchor)
	if anchor == null:
		return
	var target := _living(_target)
	if target != null and _distance(target, anchor) > LEASH:
		target = null
		_target = null
	if body.get("actionBlockInput") == true:
		return
	var state := _state(body)
	var mode := BotTactics.mode_for(body)
	var sneaking := BotTactics.sneaking_with(mode, body, anchor)
	if target != null:
		var offset := BotNavigation.ground(target.global_position - body.global_position)
		var distance: float = offset.length()
		var immediate_threat: bool = distance <= ATTACK_REACH and _state(target) in THREAT_STATES
		## A sneaking bot stalks with the blade sheathed and strikes from
		## cover; anything else fights with the katana out.
		var stalking: bool = sneaking and not immediate_threat
		if stalking and body.get("stealthed") != true:
			if body.get("katana_drawn") == true:
				if _draw_left <= 0.0 and state in DRAWN_STATES:
					_now["Katana"] = true
					_draw_left = 1.0
				return
			if _draw_left <= 0.0:
				_now["Stealth"] = true
				_draw_left = 0.5
			return
		if not stalking and body.get("katana_drawn") != true and _draw_left <= 0.0:
			_now["Katana"] = true
			_draw_left = 1.0
			return
		_aim = offset.normalized()
		if distance <= ATTACK_REACH and _state(target) in EVADE_STATES:
			var away := -_aim.round()
			var retreat := body.global_position + Vector2(away.x, away.y * 0.5) * 48.0
			if navigation.safe_segment(body.global_position, retreat):
				_move = -_aim
				_goal = Vector2.INF
				navigation.reset()
				return
		var facing := IsoFacing.name_of(_aim.round())
		var in_blade: bool = false
		if distance <= ATTACK_REACH and body.has_method("can_slash_target"):
			in_blade = body.can_slash_target(target, facing)
		if distance <= ATTACK_REACH and in_blade and _visible(body, target):
			navigation.reset()
			_goal = Vector2.INF
			if _state(target) in THREAT_STATES and state in [&"katanaIdle", &"katanaBlock"]:
				_now["Defend"] = true
				return
			var ready: bool = state in SNEAK_READY_STATES if stalking \
					else state in READY_STATES
			if ready and _attack_left <= 0.0:
				_tap_left = TAP_TIME
				_attack_left = ATTACK_INTERVAL
			_now["Attack"] = _tap_left > 0.0
			return
		# Stop at the actual collision surface, not an arbitrary centre distance.
		var travel := target.global_position - body.global_position
		var collision := KinematicCollision2D.new()
		if body.test_move(body.global_transform, travel, collision, 0.5):
			travel = collision.get_travel()
			travel = travel.limit_length(maxf(travel.length() - 2.0, 0.0))
		var approach := body.global_position + travel
		if body.has_method("can_slash_target") and not \
				body.can_slash_target(target, facing, approach):
			approach = _strike_position(body, target, approach)
		_follow(body, approach, false, 2.0)
		return
	## Nothing to fight: match the blade and the sneaking to the mode.
	var drawn: bool = body.get("katana_drawn") == true
	var wants_blade: bool = BotTactics.wants_blade(mode, body, anchor, false)
	if _draw_left <= 0.0:
		if wants_blade and not drawn:
			_now["Katana"] = true
			_draw_left = 1.0
			return
		if not wants_blade and drawn and state in DRAWN_STATES:
			_now["Katana"] = true
			_draw_left = 1.0
			return
		if not drawn and sneaking != (body.get("stealthed") == true):
			_now["Stealth"] = true
			_draw_left = 0.5
			return
	var anchor_distance: float = _distance(body, anchor)
	if anchor_distance <= BotTactics.follow_reach(mode, FOLLOW_REACH):
		navigation.reset()
		_goal = Vector2.INF
		return
	## Running out of stealth would give the party away.
	_follow(body, anchor.global_position, anchor_distance > 340.0 and not sneaking)


func _follow(body: CharacterBody2D, goal: Vector2, running: bool,
		stop_distance: float = 22.0) -> void:
	if _goal == Vector2.INF or (_repath_left <= 0.0 and \
			BotNavigation.ground(goal - _goal).length() > 96.0) \
			or (navigation.path.is_empty() and not navigation.searching and _repath_left <= 0.0):
		_goal = goal
		_repath_left = 0.75
		navigation.begin(body.global_position, goal)
	if _navigation_left <= 0.0:
		_navigation_left = 0.1
		navigation.advance()
	while not navigation.path.is_empty() and \
			BotNavigation.ground(navigation.path[0] - body.global_position).length() \
			< stop_distance:
		navigation.path.remove_at(0)
	if navigation.path.is_empty():
		return
	var offset := BotNavigation.ground(navigation.path[0] - body.global_position)
	var direction := offset.normalized()
	# The player moves in eight rounded directions; validate that exact step.
	var actual := direction.round()
	var ahead := body.global_position + Vector2(actual.x, actual.y * 0.5) \
			* minf(48.0, offset.length() / actual.length())
	if not navigation.safe_segment(body.global_position, ahead):
		var best := Vector2.ZERO
		var alignment: float = 0.05
		for step in BotNavigation.DIRECTIONS:
			var candidate := Vector2(step).normalized()
			var score: float = candidate.dot(direction)
			if score <= alignment:
				continue
			var probe := body.global_position + Vector2(step.x, step.y * 0.5) \
					* minf(24.0, offset.length() / Vector2(step).length())
			if navigation.safe_segment(body.global_position, probe):
				best = candidate
				alignment = score
		if best == Vector2.ZERO:
			navigation.reset()
			_repath_left = 0.0
			return
		direction = best
	_move = direction
	_now["Run"] = running and not body.winded()


func _strike_position(body: CharacterBody2D, target: Node2D, fallback: Vector2) -> Vector2:
	var best := fallback
	var distance: float = INF
	for direction in BotNavigation.DIRECTIONS:
		var aim := Vector2(direction).normalized()
		var candidate := target.global_position - Vector2(aim.x, aim.y * 0.5) * 150.0
		var facing := IsoFacing.name_of(Vector2(direction))
		var reach: float = BotNavigation.ground(candidate - body.global_position).length()
		if reach >= distance or not navigation.safe_segment(candidate, candidate):
			continue
		if body.can_slash_target(target, facing, candidate):
			best = candidate
			distance = reach
	return best


func _choose_anchor(body: CharacterBody2D) -> void:
	var best: CharacterBody2D = null
	var distance: float = INF
	for candidate in Roster.bodies(body.get_tree()):
		if candidate == body or Roster.is_bot(int(candidate.get("slot"))):
			continue
		var reach: float = _distance(body, candidate)
		if reach < distance:
			best = candidate
			distance = reach
	var previous := _living(_anchor)
	if best != previous:
		navigation.reset()
		_goal = Vector2.INF
	_anchor = weakref(best) if best != null else null


func _choose_target(body: CharacterBody2D) -> void:
	var anchor := _living(_anchor)
	var best: Node2D = null
	var distance: float = NOTICE_REACH
	var mode := BotTactics.mode_for(body)
	var previous := _living(_target)
	var now := Time.get_ticks_msec()
	## A stalk is abandoned the moment the monster notices; any other fight is
	## seen through for a few seconds after the last provocation.
	var stick: bool = now < _engaged_until_ms \
			and not BotTactics.sneaking_with(mode, body, anchor)
	if anchor != null and _distance(body, anchor) <= LEASH:
		for candidate in body.get_tree().get_nodes_in_group("enemy"):
			if not (candidate is CharacterBody2D) or candidate.get("is_dead") == true \
					or candidate.is_queued_for_deletion():
				continue
			var reach: float = _distance(body, candidate)
			if reach < distance and _distance(candidate, anchor) <= LEASH \
					and _visible(body, candidate) \
					and ((stick and candidate == previous)
						or BotTactics.provokes(mode, body, anchor, candidate)):
				best = candidate
				distance = reach
	if best != null and BotTactics.provokes(mode, body, anchor, best):
		_engaged_until_ms = now + BotTactics.ENGAGE_MS
	_target = weakref(best) if best != null else null


func _visible(body: CharacterBody2D, target: Node2D) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(body.global_position,
			target.global_position, body.collision_mask)
	ray.exclude = [body.get_rid()]
	for other in Roster.bodies(body.get_tree()):
		if other != body:
			ray.exclude.append(other.get_rid())
	var hit := body.get_world_2d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit["collider"] == target


func _living(reference: WeakRef) -> Node2D:
	var node := reference.get_ref() as Node2D if reference != null else null
	return node if is_instance_valid(node) and not node.is_queued_for_deletion() \
			and node.get("is_dead") != true else null


func _state(body: Node2D) -> StringName:
	var machine := body.get_node_or_null("FiniteStateMachine") as FiniteStateMachine
	return machine.current_state.name if machine != null and machine.current_state != null else &""


func _distance(a: Node2D, b: Node2D) -> float:
	return BotNavigation.ground(a.global_position - b.global_position).length()
