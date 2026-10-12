extends Control

## Radar: the floor around her, with every monster's view drawn on it.
##
## The point is to make sneaking playable. Each monster's cone is what it can
## actually see — same arc, same range, same walls — so a gap between two cones
## on the radar is a gap you can walk through. Blips carry the monster's state,
## so a cone going from amber to red is the moment you were spotted.

## World distance the outer ring represents.
@export var range_world: float = 1400.0
@export var radius: float = 88.0
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
const CENTRE := Vector2(140.0, 140.0)
const FRAME_RECT := Rect2(24.0, 24.0, 232.0, 232.0)
const ORBIT_RADIUS: float = 128.0
const ICON_SIZE: float = 20.0
const FRAME_PATH := "res://assets/sprites/ui/radar/dragon_frame.png"
const UI_THEME := preload("res://assets/sprites/ui/katanaKitsune.theme.tres")

var _frame: Texture2D
var _progress: Label
var _walls: Array[PackedVector2Array] = []
var _walls_age: float = 999.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame = load(FRAME_PATH) as Texture2D
	if _frame == null:
		push_error("Radar: missing dragon frame: " + FRAME_PATH)
	_progress = Label.new()
	_progress.name = "FloorKills"
	_progress.theme = UI_THEME
	_progress.position = Vector2(68.0, 286.0)
	_progress.size = Vector2(144.0, 54.0)
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.add_theme_font_size_override("font_size", 20)
	_progress.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.0, 0.0, 0.0, 0.65)
	_progress.add_theme_stylebox_override("normal", backing)
	add_child(_progress)


func _process(delta: float) -> void:
	_walls_age += delta
	var level = get_parent().get_parent()
	_progress.visible = "enemies_killed" in level and "enemies_total" in level
	if _progress.visible:
		var killed: int = level.enemies_killed
		var total: int = level.enemies_total
		_progress.text = "%d/%d\n%d" % [killed, total, maxi(total - killed, 0)]
	queue_redraw()


func _draw() -> void:
	var centre := CENTRE
	draw_circle(centre, radius, Color(0.05, 0.05, 0.06, 0.82))

	## Centred on the party rather than on player one, so it agrees with the
	## shared camera instead of drifting away from what is on screen.
	var crew := Roster.bodies(get_tree())
	if crew.is_empty():
		_ring(centre)
		_draw_frame()
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

	for node in get_tree().get_nodes_in_group("enemy"):
		if not (node is Node2D) or ("is_dead" in node and node.is_dead):
			continue
		var blip := _to_radar(node.global_position, focus, centre)
		if blip == Vector2.INF:
			continue
		var colour := _colour_for(node)
		_draw_cone(node, blip, colour)
		draw_circle(blip, blip_size, colour)

	## Players last, so a monster standing on one never hides them.
	for body in crew:
		var at := _to_radar(body.global_position, focus, centre)
		if at != Vector2.INF:
			_draw_player(body, at)
	_draw_frame()


func _draw_frame() -> void:
	if _frame != null:
		draw_texture_rect(_frame, FRAME_RECT, false)
	draw_arc(CENTRE, ORBIT_RADIUS, PI, TAU, 64, Color(0.91, 0.69, 0.29, 0.75), 2.0, true)
	draw_arc(CENTRE, ORBIT_RADIUS, 0.0, PI, 64, Color(0.48, 0.61, 0.88, 0.75), 2.0, true)
	var cycle := DayNightCycle.for_node(self)
	if cycle == null:
		return
	var angle: float = cycle.orbit_angle()
	var at := CENTRE + Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS
	draw_circle(at, ICON_SIZE * 0.6, Color(0.02, 0.02, 0.04, 0.9))
	if cycle.is_night():
		_draw_moon(at)
	else:
		_draw_sun(at)


func _draw_sun(at: Vector2) -> void:
	for i in 8:
		var ray := Vector2.from_angle(TAU * float(i) / 8.0)
		draw_line(at + ray * 7.0, at + ray * 10.0, Color(1.0, 0.82, 0.3), 2.0)
	draw_circle(at, 6.0, Color(0.95, 0.56, 0.13))
	draw_circle(at + Vector2(-1.0, -1.0), 4.0, Color(1.0, 0.91, 0.52))


func _draw_moon(at: Vector2) -> void:
	draw_circle(at, 9.0, Color(0.77, 0.85, 1.0))
	draw_circle(at + Vector2(4.0, -3.0), 7.5, Color(0.02, 0.02, 0.04))
	draw_circle(at + Vector2(-4.0, 3.0), 1.5, Color(0.53, 0.65, 0.86))


## A triangle pointing where this player faces, in their slot colour, so each
## player in a party can find themselves on the radar.
func _draw_player(body: Node, at: Vector2) -> void:
	var facing: Vector2 = Vector2.ZERO
	if body.has_method("stateDirection") and "facing_dir" in body:
		facing = body.stateDirection(body.facing_dir)
	if facing == Vector2.ZERO:
		facing = Vector2.DOWN
	## Unsquashed like everything else on the radar.
	facing.y *= 2.0
	facing = facing.normalized()
	var side := facing.orthogonal()
	var size: float = blip_size * 1.6
	var tri := PackedVector2Array([
		at + facing * size * 1.3,
		at - facing * size * 0.8 + side * size * 0.8,
		at - facing * size * 0.8 - side * size * 0.8,
	])
	var colour: Color = COLOUR_PLAYER
	if "slot" in body:
		colour = Roster.colour_of(body.slot)
	draw_colored_polygon(tri, colour)
	tri.append(tri[0])
	draw_polyline(tri, Color(0.0, 0.0, 0.0, 0.8), 1.0, true)


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
	var boundary := PackedVector2Array()
	for i in 64:
		boundary.append(CENTRE + Vector2.from_angle(TAU * float(i) / 64.0) * radius)
	for clipped in Geometry2D.intersect_polygons(wedge, boundary):
		draw_colored_polygon(clipped, fill)


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
