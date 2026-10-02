extends Control

## Radar: the floor around her, with every monster's view drawn on it.
##
## The point is to make sneaking playable. Each monster's cone is what it can
## actually see — same arc, same range, same walls — so a gap between two cones
## on the radar is a gap you can walk through. Blips carry the monster's state,
## so a cone going from amber to red is the moment you were spotted.

## World distance the outer ring represents.
@export var range_world: float = 1400.0
@export var radius: float = 66.0
@export var blip_size: float = 4.0
## Wall lines are cached; this is how often the cache is thrown away, so a new
## floor shows up without rebuilding it every frame.
@export var wall_refresh_seconds: float = 2.0

const COLOUR_RING := Color(0.85, 0.72, 0.42, 0.30)
const COLOUR_PLAYER := Color(0.95, 0.90, 0.75, 0.95)
const COLOUR_WALL := Color(0.62, 0.58, 0.48, 0.55)
## Amber wandering, orange hunting for her, red with eyes on her.
const COLOUR_IDLE := Color(0.90, 0.65, 0.20, 0.85)
const COLOUR_SEARCH := Color(0.95, 0.45, 0.12, 0.90)
const COLOUR_ALERT := Color(0.85, 0.20, 0.18, 0.95)
const CONE_ALPHA: float = 0.16

var _player: CharacterBody2D = null
var _walls: Array[PackedVector2Array] = []
var _walls_age: float = 999.0


func _process(delta: float) -> void:
	_walls_age += delta
	queue_redraw()


func _draw() -> void:
	var centre := Vector2(radius, radius)
	draw_circle(centre, radius, Color(0.05, 0.05, 0.06, 0.55))

	## Centred on the party rather than on player one, so it agrees with the
	## shared camera instead of drifting away from what is on screen.
	var crew := Roster.bodies(get_tree())
	if crew.is_empty():
		_ring(centre)
		return
	var focus: Vector2 = Roster.centre_of_party(get_tree())

	## Walls first, so cones and blips sit on top of them.
	if _walls_age >= wall_refresh_seconds:
		_rebuild_walls()
	for run in _walls:
		var points := PackedVector2Array()
		for world in run:
			var local := _to_radar(world, focus, centre)
			if local != Vector2.INF:
				points.append(local)
		if points.size() >= 2:
			draw_polyline(points, COLOUR_WALL, 1.0, true)

	_ring(centre)
	draw_circle(centre, blip_size * 0.8, COLOUR_PLAYER)

	for node in get_tree().get_nodes_in_group("enemy"):
		if not (node is Node2D) or ("is_dead" in node and node.is_dead):
			continue
		var blip := _to_radar(node.global_position, focus, centre)
		if blip == Vector2.INF:
			continue
		var colour := _colour_for(node)
		_draw_cone(node, blip, colour)
		draw_circle(blip, blip_size, colour)


func _ring(centre: Vector2) -> void:
	draw_arc(centre, radius, 0.0, TAU, 48, COLOUR_RING, 1.5, true)
	draw_arc(centre, radius * 0.5, 0.0, TAU, 32, COLOUR_RING, 1.0, true)


## A world point in radar space, or INF when it falls outside the ring.
func _to_radar(world: Vector2, origin: Vector2, centre: Vector2) -> Vector2:
	var delta: Vector2 = world - origin
	## Undo the 2:1 squash so the radar reads as a map of the ground rather than
	## of the screen, where everything vertical looks twice as close.
	delta.y *= 2.0
	if delta.length() > range_world:
		return Vector2.INF
	return centre + delta / range_world * radius


## The wedge a monster can actually see, at the scale the radar is drawn.
func _draw_cone(node: Node, blip: Vector2, colour: Color) -> void:
	if not ("vision_arc_degrees" in node and "detection_range" in node):
		return
	var reach: float = node.effective_detection() if node.has_method("effective_detection") \
			else node.detection_range
	var on_radar: float = reach / range_world * radius
	if on_radar <= 1.0:
		return

	var facing: Vector2 = Vector2.ZERO
	if node.has_method("stateDirection") and "facing_dir" in node:
		facing = node.stateDirection(node.facing_dir)
	if facing == Vector2.ZERO:
		return
	## Same unsquashing the radar itself uses, so the cone points where the
	## monster is actually looking on the ground.
	facing.y *= 2.0
	var heading: float = facing.angle()
	var half: float = deg_to_rad(node.vision_arc_degrees) * 0.5

	var wedge := PackedVector2Array([blip])
	var steps := 12
	for i in steps + 1:
		var a: float = heading - half + (half * 2.0) * float(i) / float(steps)
		wedge.append(blip + Vector2(cos(a), sin(a)) * on_radar)
	var fill := colour
	fill.a = CONE_ALPHA
	draw_colored_polygon(wedge, fill)


## Read off the state machine rather than recomputed, so the radar cannot
## disagree with what the monster is actually doing.
func _colour_for(node: Node) -> Color:
	var machine := node.get_node_or_null("FiniteStateMachine")
	if machine == null or machine.current_state == null:
		return COLOUR_IDLE
	match String(machine.current_state.name):
		"walk", "attack":
			return COLOUR_ALERT
		"alert", "hurt":
			return COLOUR_SEARCH
		_:
			return COLOUR_IDLE


## Wall runs in world space, gathered from the rooms' own wall layers. Only the
## layers that are switched on: an opening's layer keeps its tiles, and drawing
## those would put a wall across every doorway on the map.
func _rebuild_walls() -> void:
	_walls_age = 0.0
	_walls.clear()
	for layer in _find_wall_layers(get_tree().current_scene):
		var cells: Array[Vector2i] = layer.get_used_cells()
		if cells.size() < 2:
			continue
		cells.sort_custom(func(a, b): return a.x + a.y < b.x + b.y)
		var run := PackedVector2Array()
		for c in cells:
			run.append(layer.to_global(layer.map_to_local(c)))
		_walls.append(run)


func _find_wall_layers(node: Node) -> Array[TileMapLayer]:
	var found: Array[TileMapLayer] = []
	if node == null:
		return found
	if node is TileMapLayer and String(node.name).begins_with("Walls_") and node.enabled:
		found.append(node)
	for c in node.get_children():
		found.append_array(_find_wall_layers(c))
	return found


