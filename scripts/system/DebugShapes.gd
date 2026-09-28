extends Node2D

## F3 draws what the game is actually sensing with, rather than what it looks
## like it is sensing with.
##
## Written because sitting on a chair went through several rounds of "it looks
## wrong" against measurements that said it was right — the chair turned out to
## be rendering inside the player's own silhouette. Shapes and origins are
## invisible in a build, so there was nothing to look at. Now there is.

## Everything is drawn over the world, never mind y-sorting.
const OVERLAY_Z: int = 4096

const COLOUR_PLAYER := Color(0.30, 1.00, 0.45, 0.85)
const COLOUR_ZONE := Color(0.35, 0.80, 1.00, 0.75)
const COLOUR_SOLID := Color(1.00, 0.60, 0.20, 0.70)
const COLOUR_ENEMY := Color(1.00, 0.35, 0.35, 0.75)
## Wall tiles, which collide as their drawn silhouette rather than a footprint.
const COLOUR_WALL := Color(0.75, 0.55, 1.00, 0.60)
## The chair she would sit on if she stood still long enough.
const COLOUR_PICKED := Color(1.00, 0.95, 0.40, 0.95)
const ORIGIN_ARM: float = 9.0

var _on: bool = true
var _player: CharacterBody2D = null


func _ready() -> void:
	z_index = OVERLAY_Z
	z_as_relative = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	## Still toggleable, but it starts on — this is for looking at a problem, and
	## having to remember a key first defeats that.
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_F3:
		_on = not _on
		queue_redraw()


func _process(_delta: float) -> void:
	if _on:
		queue_redraw()


func _draw() -> void:
	if not _on:
		return
	var player := _find_player()

	## Chairs: the zone she has to be inside, the origin, and the seat she is
	## actually sent to — which are three different points and were being
	## confused for each other.
	for chair in get_tree().get_nodes_in_group("chair"):
		if not (chair is Node2D):
			continue
		var node := chair as Node2D
		var picked: bool = player != null and _would_sit_on(node, player)
		var tint: Color = COLOUR_PICKED if picked else COLOUR_ZONE
		var zone := node.get_node_or_null("SitZone") as Area2D
		if zone != null:
			_draw_area(zone, tint)
		_cross(node.global_position, tint, "chair")
		var anchor := node.get_node_or_null("SitAnchor") as Node2D
		if anchor != null and anchor.global_position != node.global_position:
			_cross(anchor.global_position, COLOUR_PICKED, "seat")
			draw_line(to_local(node.global_position), to_local(anchor.global_position),
					COLOUR_PICKED, 1.0)
		if picked and player != null:
			## The line she is about to walk.
			var target: Vector2 = anchor.global_position if anchor != null else node.global_position
			draw_line(to_local(player.global_position), to_local(target), COLOUR_PICKED, 1.5)

	## Bodies. Her own shape first, then everything solid she can walk into.
	if player != null:
		_draw_body(player, COLOUR_PLAYER)
		_cross(player.global_position, COLOUR_PLAYER, "her origin")
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is CollisionObject2D:
			_draw_body(node as CollisionObject2D, COLOUR_ENEMY)
	for node in get_tree().get_nodes_in_group("breakable"):
		if node is CollisionObject2D:
			_draw_body(node as CollisionObject2D, COLOUR_SOLID)
	## Columns are not in a group; they are the scene's own static bodies.
	for node in get_parent().get_children():
		if node is StaticBody2D:
			_draw_body(node as StaticBody2D, COLOUR_SOLID)
	_draw_walls(get_parent())


## Wall collision, read off the tiles themselves. This is the shape that stops
## her, and it is not the shape of the stone — it follows the drawn silhouette,
## sloped face and all, which is why she can end up held partway up a wall.
## Only switched-on layers: an opening keeps its tiles, and drawing those would
## put a wall across every doorway.
func _draw_walls(root: Node) -> void:
	for layer in _wall_layers(root):
		var tile_set: TileSet = layer.tile_set
		if tile_set == null:
			continue
		for cell in layer.get_used_cells():
			var source := tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			if source == null:
				continue
			var data: TileData = source.get_tile_data(layer.get_cell_atlas_coords(cell),
					layer.get_cell_alternative_tile(cell))
			if data == null:
				continue
			var at := Transform2D(0.0, layer.to_global(layer.map_to_local(cell)))
			for i in data.get_collision_polygons_count(0):
				_outline(data.get_collision_polygon_points(0, i), at, COLOUR_WALL)


func _wall_layers(node: Node) -> Array[TileMapLayer]:
	var found: Array[TileMapLayer] = []
	if node is TileMapLayer and String(node.name).begins_with("Walls_") \
			and (node as TileMapLayer).enabled:
		found.append(node as TileMapLayer)
	for child in node.get_children():
		found.append_array(_wall_layers(child))
	return found


## Would chair_underfoot pick this one? Same rule, so the overlay cannot
## disagree with the thing it is drawing.
func _would_sit_on(chair: Node2D, player: CharacterBody2D) -> bool:
	var zone := chair.get_node_or_null("SitZone") as Area2D
	if zone != null:
		return zone.overlaps_body(player)
	var offset: Vector2 = chair.global_position - player.global_position
	offset.y /= 0.5
	return offset.length() <= 140.0


func _draw_body(body: CollisionObject2D, colour: Color) -> void:
	for child in body.get_children():
		if child is CollisionShape2D:
			_draw_shape((child as CollisionShape2D).shape,
					(child as CollisionShape2D).global_transform, colour)
		elif child is CollisionPolygon2D:
			_outline((child as CollisionPolygon2D).polygon,
					(child as CollisionPolygon2D).global_transform, colour)


func _draw_area(area: Area2D, colour: Color) -> void:
	for child in area.get_children():
		if child is CollisionShape2D:
			_draw_shape((child as CollisionShape2D).shape,
					(child as CollisionShape2D).global_transform, colour)


func _draw_shape(shape: Shape2D, at: Transform2D, colour: Color) -> void:
	if shape is CircleShape2D:
		var radius: float = (shape as CircleShape2D).radius
		var ring := PackedVector2Array()
		for i in 32:
			var a: float = TAU * float(i) / 32.0
			ring.append(to_local(at * (Vector2(cos(a), sin(a)) * radius)))
		_fill(ring, colour)
	elif shape is ConvexPolygonShape2D:
		_outline((shape as ConvexPolygonShape2D).points, at, colour)
	elif shape is RectangleShape2D:
		var e: Vector2 = (shape as RectangleShape2D).size * 0.5
		_outline(PackedVector2Array([-e, Vector2(e.x, -e.y), e, Vector2(-e.x, e.y)]), at, colour)


func _outline(points: PackedVector2Array, at: Transform2D, colour: Color) -> void:
	if points.size() < 3:
		return
	var loop := PackedVector2Array()
	for p in points:
		loop.append(to_local(at * p))
	_fill(loop, colour)


## Filled, with a solid edge on top. A wash alone is hard to read where shapes
## overlap, and an outline alone disappears into the floor pattern.
func _fill(points: PackedVector2Array, colour: Color) -> void:
	var wash := colour
	wash.a = colour.a * 0.32
	draw_colored_polygon(points, wash)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, colour, 1.5)


## A small cross with a label, so the three points that matter can be told apart.
func _cross(where: Vector2, colour: Color, label: String) -> void:
	var p := to_local(where)
	draw_line(p - Vector2(ORIGIN_ARM, 0), p + Vector2(ORIGIN_ARM, 0), colour, 1.5)
	draw_line(p - Vector2(0, ORIGIN_ARM), p + Vector2(0, ORIGIN_ARM), colour, 1.5)
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, p + Vector2(11, -4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, colour)


func _find_player() -> CharacterBody2D:
	if is_instance_valid(_player):
		return _player
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D:
			_player = node
			return _player
	return null
