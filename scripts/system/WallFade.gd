extends TileMapLayer

## Keeps characters visible when scenery is drawn on top of them.
##
## Replaces the hand-drawn trigger polygons, which only covered part of the map
## and fired for the whole layer at once. This works off the tilemap itself, so
## it needs nothing authored and works in a generated level too.
##
## FADE punches a soft hole around each covered character — for walls, where
## hiding the whole layer would open the room up.
## HIDE drops the layer entirely — for roofs, where a porthole would look odd
## and you want to see the room anyway.

enum Mode { FADE, HIDE }

## Matches MAX_SUBJECTS in wallFade.gdshader.
const MAX_SUBJECTS: int = 8
## Rough extent of one wall plane, used to reject tiles too far off to be drawn
## over a character whatever their sort order says.
const SPRITE_HALF_WIDTH: float = 130.0
const SPRITE_HEIGHT: float = 360.0

@export var mode: Mode = Mode.FADE
## How far around a character to look for covering tiles, in cells. The
## Crocotile wall planes are 8 cells wide and placed several cells apart, so a
## tight radius misses the very wall standing in front of them.
@export var search_radius: int = 8
## Monsters further than this from the player are off screen; skipping them
## keeps the per-cell scan off a whole floor's worth of enemies.
@export var subject_range: float = 1200.0

var _player: CharacterBody2D = null
var _shader: ShaderMaterial = null
## Ground-line gradient per tile source, worked out once.
var _slopes: Dictionary = {}


func _ready() -> void:
	if mode == Mode.FADE:
		var shared := material as ShaderMaterial
		if shared == null:
			push_warning("WallFade: %s has no ShaderMaterial; it will not fade." % name)
			set_process(false)
			return
		## Every instance of a room prefab shares the material stored in its
		## scene, so sixteen rooms would all write `subjects` to one resource and
		## only the last to run each frame would be seen. A copy per layer keeps
		## them independent.
		_shader = shared.duplicate() as ShaderMaterial
		material = _shader


func _process(_delta: float) -> void:
	## The nearest player to this wall, not the first one in the group. With a
	## party, keying on player one meant a wall never lifted for anybody else —
	## players two to four simply walked behind solid stone.
	var target := Roster.nearest_to(get_tree(), global_position)
	if target == null:
		return

	if mode == Mode.HIDE:
		## Keyed to players alone. Lifting a roof because a monster wandered
		## under it would just flicker the room.
		var hidden: bool = false
		for body in Roster.bodies(get_tree()):
			if _is_covering(body.global_position):
				hidden = true
				break
		if hidden == visible:
			visible = not hidden
		return

	var covered := PackedVector2Array()
	for subject in _subjects(target):
		if covered.size() >= MAX_SUBJECTS:
			break
		if _is_covering(subject.global_position):
			covered.append(subject.global_position)
	_shader.set_shader_parameter("subjects", covered)
	_shader.set_shader_parameter("subject_count", covered.size())


## Everyone worth cutting a hole for: every living player, plus any monster near
## enough to one of them to be on screen. Players go first so they keep their
## holes if a crowd ever overruns MAX_SUBJECTS. Only the nearest player used to
## be listed, so a second player behind the same wall stayed hidden.
func _subjects(_target: CharacterBody2D) -> Array[Node2D]:
	var crew := Roster.bodies(get_tree())
	var out: Array[Node2D] = []
	for body in crew:
		out.append(body)
	for node in get_tree().get_nodes_in_group("enemy"):
		if not (node is Node2D):
			continue
		for body in crew:
			if node.global_position.distance_to(body.global_position) <= subject_range:
				out.append(node)
				break
	return out


## Does this layer draw anything on top of `world_pos`?
func _is_covering(world_pos: Vector2) -> bool:
	var local: Vector2 = to_local(world_pos)
	var origin: Vector2i = local_to_map(local)
	for dy in range(-search_radius, search_radius + 1):
		for dx in range(-search_radius, search_radius + 1):
			var cell: Vector2i = origin + Vector2i(dx, dy)
			if get_cell_source_id(cell) == -1:
				continue
			if mode == Mode.HIDE:
				return true

			var tile: Vector2 = map_to_local(cell)
			var offset: float = local.x - tile.x
			## A wall plane is ~240px wide. Past that it cannot be drawn over
			## them however it sorts, and without this the scan kept finding
			## another wall further down the room and calling them covered while
			## they stood in the open.
			if absf(offset) > SPRITE_HALF_WIDTH:
				continue

			## Follow the plane instead of treating it as a rectangle. A wall
			## runs along a tile axis, so its ground line rises or falls as it
			## goes; comparing against the cell's single sort value made a wall
			## they were running alongside look like one they stood behind.
			var line_y: float = _sort_y(cell) + offset * _slope(cell)
			if line_y - local.y > SPRITE_HEIGHT:
				continue
			## The stone at their x sorts in front of them, so it covers them.
			if line_y > local.y:
				return true
	return false


## Gradient of a wall's ground line, read off its own collision polygon rather
## than assumed, so each of the eight directions gets its own answer.
func _slope(cell: Vector2i) -> float:
	var source_id: int = get_cell_source_id(cell)
	if _slopes.has(source_id):
		return _slopes[source_id]

	var slope: float = 0.0
	var source := tile_set.get_source(source_id) as TileSetAtlasSource
	if source != null:
		var data: TileData = source.get_tile_data(get_cell_atlas_coords(cell),
			get_cell_alternative_tile(cell))
		if data != null and data.get_collision_polygons_count(0) > 0:
			var points := data.get_collision_polygon_points(0, 0)
			## The footprint's longest edge runs along the wall.
			var best: float = 0.0
			for i in points.size():
				var edge: Vector2 = points[(i + 1) % points.size()] - points[i]
				if edge.length() > best and absf(edge.x) > 1.0:
					best = edge.length()
					slope = edge.y / edge.x
	_slopes[source_id] = slope
	return slope


## Where Godot sorts the tile in this cell, in layer-local space. These walls
## sit up to 132px below the cell they occupy, so the cell origin is not where
## Godot sorts them, and the two answers disagree exactly along a wall's bottom
## edge, which is where it matters.
func _sort_y(cell: Vector2i) -> float:
	var base: float = map_to_local(cell).y
	var source := tile_set.get_source(get_cell_source_id(cell)) as TileSetAtlasSource
	if source == null:
		return base
	var data: TileData = source.get_tile_data(get_cell_atlas_coords(cell),
		get_cell_alternative_tile(cell))
	return base if data == null else base + data.y_sort_origin


