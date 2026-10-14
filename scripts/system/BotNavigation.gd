class_name BotNavigation
extends RefCounted

const STEP := Vector2(12.0, 6.0)
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]
const SEARCH_RADIUS: int = 144
const MAX_EXPANSIONS: int = 131072
const TICK_EXPANSIONS: int = 128
const HAZARD_MARGIN: float = 64.0

var path: PackedVector2Array = []
var searching: bool = false
var exhausted: bool = false
var expansions: int = 0
var _body: WeakRef
var _origin := Vector2.ZERO
var _goal := Vector2.ZERO
var _open: Array[Vector2i] = []
var _scores: Array[float] = []
var _cost: Dictionary[Vector2i, float] = {}
var _parent: Dictionary[Vector2i, Vector2i] = {}
var _closed: Dictionary[Vector2i, bool] = {}
var _best := Vector2i.ZERO
var _hazard_frame: int = -1
var _hazards: Array[Vector3] = []
var _bounds := Rect2()
var _world: Node
var _arrival_reach: float = 0.0
var _doors: Array[RID] = []


func bind_body(body: CharacterBody2D) -> void:
	_body = weakref(body)
	_world = body.get_parent()
	reset()


func reset() -> void:
	path.clear()
	searching = false
	exhausted = false
	expansions = 0
	_open.clear()
	_scores.clear()
	_cost.clear()
	_parent.clear()
	_closed.clear()
	_hazard_frame = -1
	_hazards.clear()
	_doors.clear()


static func ground(offset: Vector2) -> Vector2:
	return Vector2(offset.x, offset.y * 2.0)


func safe_segment(from: Vector2, to: Vector2, planning: bool = false) -> bool:
	var body := _body.get_ref() as CharacterBody2D
	if not is_instance_valid(body):
		return false
	if is_instance_valid(_world) and _world.has_method("bot_navigation_contains"):
		var samples := maxi(1, ceili(ground(to - from).length() / STEP.x))
		for i in range(1, samples + 1):
			if not _world.bot_navigation_contains(from.lerp(to, float(i) / samples)):
				return false
	var pose := body.global_transform
	pose.origin = from
	var blocked: bool
	if planning and not _doors.is_empty():
		var motion := PhysicsTestMotionParameters2D.new()
		motion.from = pose
		motion.motion = to - from
		motion.margin = 0.5
		motion.recovery_as_collision = true
		motion.exclude_bodies = _doors
		blocked = PhysicsServer2D.body_test_motion(body.get_rid(), motion)
	else:
		blocked = body.test_move(pose, to - from, null, 0.5, true)
	if blocked:
		return false
	var a := ground(from)
	var b := ground(to)
	_refresh_hazards(body)
	for hazard in _hazards:
		var centre := Vector2(hazard.x, hazard.y)
		var closest := Geometry2D.get_closest_point_to_segment(centre, a, b)
		if closest.distance_to(centre) < hazard.z:
			# Allow escape if a trap was placed under the spawn/teleport point.
			if a.distance_to(centre) < hazard.z and b.distance_to(centre) > a.distance_to(centre):
				continue
			return false
	return true


func _refresh_hazards(body: CharacterBody2D) -> void:
	var frame: int = Engine.get_physics_frames()
	if frame == _hazard_frame:
		return
	_hazard_frame = frame
	_hazards.clear()
	for hazard in body.get_tree().get_nodes_in_group("bot_hazard"):
		if not (hazard is Area2D) or hazard.is_queued_for_deletion():
			continue
		var radius: float = HAZARD_MARGIN
		for child in hazard.get_children():
			if child is CollisionShape2D and not child.disabled and child.shape != null:
				var rect: Rect2 = child.shape.get_rect()
				radius += ground(rect.size * child.global_scale).length() * 0.5
				break
		var centre := ground(hazard.global_position)
		_hazards.append(Vector3(centre.x, centre.y, radius))


func begin(from: Vector2, goal: Vector2, arrival_reach: float = 0.0) -> void:
	reset()
	_origin = from
	_goal = goal
	_arrival_reach = arrival_reach
	var body := _body.get_ref() as CharacterBody2D
	for door in body.get_tree().get_nodes_in_group("bot_door"):
		if door is SlidingDoor and not door.is_queued_for_deletion():
			_doors.append(door.get_rid())
	# Authored worlds without floor metadata still get a finite search which
	# covers both endpoints plus room for a detour, not just the bot's spawn.
	_bounds = Rect2(from, Vector2.ZERO).expand(goal).grow(SEARCH_RADIUS * STEP.x)
	if is_instance_valid(_world) and _world.has_method("bot_navigation_bounds"):
		_bounds = _world.bot_navigation_bounds()
	if _arrived(from):
		return
	# Sliding panels open on approach. Plan through them, but keep testing their
	# real collision while walking; jambs and closed walls are never excluded.
	if safe_segment(from, goal, true):
		path.append(goal)
		return
	searching = true
	_cost[Vector2i.ZERO] = 0.0
	_enqueue(Vector2i.ZERO, _heuristic(Vector2i.ZERO))


func advance() -> void:
	if not searching:
		return
	for _i in TICK_EXPANSIONS:
		if _open.is_empty() or expansions >= MAX_EXPANSIONS:
			_finish(_best)
			exhausted = true
			return
		var current := _dequeue()
		if _closed.has(current):
			continue
		_closed[current] = true
		expansions += 1
		if _heuristic(current) < _heuristic(_best):
			_best = current
		var point := _point(current)
		if _arrived(point):
			_finish(current)
			return
		if ground(point - _goal).length() <= STEP.x * 1.5 and safe_segment(point, _goal, true):
			_finish(current)
			path.append(_goal)
			return
		for direction in DIRECTIONS:
			var next := current + direction
			if not _bounds.has_point(_point(next)) or _closed.has(next):
				continue
			var cost: float = _cost[current] + Vector2(direction).length()
			if cost >= _cost.get(next, INF):
				continue
			if not safe_segment(point, _point(next), true):
				continue
			_parent[next] = current
			_cost[next] = cost
			_enqueue(next, cost + _heuristic(next) * 1.15)


func _arrived(point: Vector2) -> bool:
	if _arrival_reach <= 0.0 or ground(point - _goal).length() > _arrival_reach:
		return false
	var body := _body.get_ref() as CharacterBody2D
	var ray := PhysicsRayQueryParameters2D.create(point, _goal, body.collision_mask)
	ray.exclude = [body.get_rid()]
	for player in body.get_tree().get_nodes_in_group("player"):
		if player is CollisionObject2D:
			ray.exclude.append(player.get_rid())
	return body.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


## A heap keeps a floor-wide search incremental without scanning thousands of
## frontier cells every time a single cell is expanded.
func _enqueue(cell: Vector2i, score: float) -> void:
	var index := _open.size()
	_open.append(cell)
	_scores.append(score)
	while index > 0:
		var parent: int = (index - 1) >> 1
		if _scores[parent] <= score:
			break
		_open[index] = _open[parent]
		_scores[index] = _scores[parent]
		index = parent
	_open[index] = cell
	_scores[index] = score


func _dequeue() -> Vector2i:
	var first := _open[0]
	var last: Vector2i = _open.pop_back()
	var score: float = _scores.pop_back()
	if _open.is_empty():
		return first
	var index := 0
	while index * 2 + 1 < _open.size():
		var child := index * 2 + 1
		if child + 1 < _open.size() and _scores[child + 1] < _scores[child]:
			child += 1
		if score <= _scores[child]:
			break
		_open[index] = _open[child]
		_scores[index] = _scores[child]
		index = child
	_open[index] = last
	_scores[index] = score
	return first


func _point(cell: Vector2i) -> Vector2:
	return _origin + Vector2(cell) * STEP


func _heuristic(cell: Vector2i) -> float:
	return ground(_point(cell) - _goal).length() / STEP.x


func _finish(cell: Vector2i) -> void:
	searching = false
	var reversed: PackedVector2Array = []
	while cell != Vector2i.ZERO:
		reversed.append(_point(cell))
		cell = _parent[cell]
	reversed.reverse()
	path = reversed
