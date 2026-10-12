class_name BotNavigation
extends RefCounted

const STEP := Vector2(48.0, 24.0)
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]
const SEARCH_RADIUS: int = 36
const MAX_EXPANSIONS: int = 2048
const TICK_EXPANSIONS: int = 64
const HAZARD_MARGIN: float = 64.0

var path: PackedVector2Array = []
var searching: bool = false
var exhausted: bool = false
var expansions: int = 0
var _body: WeakRef
var _origin := Vector2.ZERO
var _goal := Vector2.ZERO
var _open: Array[Vector2i] = []
var _cost: Dictionary[Vector2i, float] = {}
var _parent: Dictionary[Vector2i, Vector2i] = {}
var _closed: Dictionary[Vector2i, bool] = {}
var _best := Vector2i.ZERO
var _hazard_frame: int = -1
var _hazards: Array[Vector3] = []


func bind_body(body: CharacterBody2D) -> void:
	_body = weakref(body)
	reset()


func reset() -> void:
	path.clear()
	searching = false
	exhausted = false
	expansions = 0
	_open.clear()
	_cost.clear()
	_parent.clear()
	_closed.clear()
	_hazard_frame = -1
	_hazards.clear()


static func ground(offset: Vector2) -> Vector2:
	return Vector2(offset.x, offset.y * 2.0)


func safe_segment(from: Vector2, to: Vector2) -> bool:
	var body := _body.get_ref() as CharacterBody2D
	if not is_instance_valid(body):
		return false
	var pose := body.global_transform
	pose.origin = from
	if body.test_move(pose, to - from, null, 0.5, true):
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


func begin(from: Vector2, goal: Vector2) -> void:
	reset()
	_origin = from
	_goal = goal
	if safe_segment(from, goal):
		path.append(goal)
		return
	searching = true
	_open.append(Vector2i.ZERO)
	_cost[Vector2i.ZERO] = 0.0


func advance() -> void:
	if not searching:
		return
	for _i in TICK_EXPANSIONS:
		if _open.is_empty() or expansions >= MAX_EXPANSIONS:
			_finish(_best)
			exhausted = true
			return
		var index: int = 0
		var score: float = INF
		for j in _open.size():
			var cell: Vector2i = _open[j]
			var value: float = _cost[cell] + _heuristic(cell) * 1.15
			if value < score:
				index = j
				score = value
		var current: Vector2i = _open[index]
		_open.remove_at(index)
		_closed[current] = true
		expansions += 1
		if _heuristic(current) < _heuristic(_best):
			_best = current
		var point := _point(current)
		if ground(point - _goal).length() <= STEP.x * 1.5 \
				and safe_segment(point, _goal):
			_finish(current)
			path.append(_goal)
			return
		for direction in DIRECTIONS:
			var next := current + direction
			if absi(next.x) > SEARCH_RADIUS or absi(next.y) > SEARCH_RADIUS \
					or _closed.has(next):
				continue
			var cost: float = _cost[current] + Vector2(direction).length()
			if cost >= _cost.get(next, INF):
				continue
			if not safe_segment(point, _point(next)):
				continue
			_parent[next] = current
			_cost[next] = cost
			if not _open.has(next):
				_open.append(next)


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
