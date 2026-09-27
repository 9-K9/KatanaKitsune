extends TileMapLayer

## Keeps the player visible when scenery is drawn on top of her.
##
## Replaces the hand-drawn trigger polygons, which only covered part of the map
## and fired for the whole layer at once. This works off the tilemap itself, so
## it needs nothing authored and works in a generated level too.
##
## FADE punches a soft hole around her — for walls, where hiding the whole layer
## would open the room up.
## HIDE drops the layer entirely — for roofs, where a porthole would look odd
## and you want to see the room anyway.

enum Mode { FADE, HIDE }

@export var mode: Mode = Mode.FADE
## How far around the player to look for covering tiles, in cells. The
## Crocotile wall planes are 8 cells wide and placed several cells apart, so a
## tight radius misses the very wall that is standing in front of her.
@export var search_radius: int = 8

## Rough extent of one wall plane, used to reject tiles too far off to be
## drawn over her whatever their sort order says.
const SPRITE_HALF_WIDTH: float = 130.0
const SPRITE_HEIGHT: float = 360.0

var _player: CharacterBody2D = null
var _shader: ShaderMaterial = null
var _covered: bool = false
## Ground-line gradient per tile source, worked out once.
var _slopes: Dictionary = {}


func _ready() -> void:
	if mode == Mode.FADE:
		_shader = material as ShaderMaterial
		if _shader == null:
			push_warning("WallFade: %s has no ShaderMaterial; it will not fade." % name)
			set_process(false)


func _process(_delta: float) -> void:
	var target := _find_player()
	if target == null:
		return

	var covered := _is_covering(target.global_position)
	match mode:
		Mode.FADE:
			_shader.set_shader_parameter("player_world", target.global_position)
			## Passed as a float because the shader multiplies by it.
			_shader.set_shader_parameter("behind", 1.0 if covered else 0.0)
		Mode.HIDE:
			if covered == visible:
				visible = not covered
	_covered = covered


## Does this layer draw anything on top of `world_pos`?
##
## For walls that means a tile the y-sort puts in front of her, which is any
## tile whose own position sorts later. Testing this per pixel in the shader
## cannot work: a wall's pixels run ~350px up from its base, so only the bottom
## strip ever matched, which read as a fade around her feet that also fired
## while she stood in front of the wall.
##
## For roofs it means a tile more or less overhead.
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
			## her however it sorts, and without this the scan kept finding
			## another wall further down the room and calling her covered while
			## she stood in the open.
			if absf(offset) > SPRITE_HALF_WIDTH:
				continue

			## Follow the plane instead of treating it as a rectangle. A wall
			## runs along a tile axis, so its ground line rises or falls as it
			## goes; comparing against the cell's single sort value made a wall
			## she was running alongside look like one she was standing behind.
			var line_y: float = _sort_y(cell) + offset * _slope(cell)
			if line_y - local.y > SPRITE_HEIGHT:
				continue
			## The stone at her x sorts in front of her, so it covers her.
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


## Where Godot sorts the tile in this cell, in layer-local space.
func _sort_y(cell: Vector2i) -> float:
	var base: float = map_to_local(cell).y
	var source := tile_set.get_source(get_cell_source_id(cell)) as TileSetAtlasSource
	if source == null:
		return base
	var data: TileData = source.get_tile_data(get_cell_atlas_coords(cell),
		get_cell_alternative_tile(cell))
	return base if data == null else base + data.y_sort_origin


func _find_player() -> CharacterBody2D:
	if is_instance_valid(_player):
		return _player
	## The player's hitbox Area2D is in the "player" group too, so take the
	## first body rather than the first node.
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D:
			_player = node
			return _player
	return null
