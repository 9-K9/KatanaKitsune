class_name JapaneseRoof
extends Node2D

const TILES := preload("res://assets/pixellab/japanese_environment/roofs/kawara_tiles.png")
const EAVE_HEIGHT: float = 240.0
const OVERHANG: float = 0.08
const FACE_LIGHT: Array[Color] = [
	Color(0.40, 0.43, 0.47), Color(0.56, 0.59, 0.64),
	Color(0.65, 0.67, 0.70), Color(0.48, 0.52, 0.57),
]


## Rectangular roof wings cover exactly the occupied cells, never an L-shaped
## building's empty courtyard. Connected wings meet at a valley.
static func wings(cells: Array) -> Array[Rect2i]:
	var remaining: Dictionary = {}
	for cell: Vector2i in cells:
		remaining[cell] = true
	var ordered: Array = cells.duplicate()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	var out: Array[Rect2i] = []
	for origin: Vector2i in ordered:
		if not remaining.has(origin):
			continue
		var width := 1
		while remaining.has(origin + Vector2i(width, 0)):
			width += 1
		var height := 1
		var extend := true
		while extend:
			for x in width:
				if not remaining.has(origin + Vector2i(x, height)):
					extend = false
					break
			if extend:
				height += 1
		for y in height:
			for x in width:
				remaining.erase(origin + Vector2i(x, y))
		out.append(Rect2i(origin, Vector2i(width, height)))
	return out


func build(cells: Array, half: Vector2, centre: Vector2) -> void:
	z_index = 1
	z_as_relative = false
	y_sort_enabled = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var surface := CanvasItemMaterial.new()
	surface.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = surface
	var rectangles := wings(cells)
	rectangles.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		return a.position.x + a.position.y < b.position.x + b.position.y)
	for rect in rectangles:
		_wing(rect, half, centre)
	for child in get_children():
		(child as CanvasItem).use_parent_material = true


func _project(at: Vector2, height: float, half: Vector2, centre: Vector2) -> Vector2:
	return centre + Vector2((at.x - at.y) * half.x, (at.x + at.y) * half.y - height)


func _wing(rect: Rect2i, half: Vector2, centre: Vector2) -> void:
	var lo := Vector2(rect.position) - Vector2.ONE * (0.5 + OVERHANG)
	var hi := Vector2(rect.end) - Vector2.ONE * (0.5 - OVERHANG)
	var middle := (lo + hi) * 0.5
	var radius: float = minf(hi.x - lo.x, hi.y - lo.y) * 0.5
	var rise: float = minf(420.0, radius * half.x * 0.9)
	var ridge_a := middle
	var ridge_b := middle
	if rect.size.x >= rect.size.y:
		ridge_a.x = lo.x + radius
		ridge_b.x = hi.x - radius
	else:
		ridge_a.y = lo.y + radius
		ridge_b.y = hi.y - radius
	var corners := [lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)]
	var tips := PackedVector2Array([ridge_a, ridge_b, ridge_b, ridge_a]) \
			if rect.size.x >= rect.size.y else PackedVector2Array([ridge_a, ridge_a, ridge_b, ridge_b])
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var tip_a: Vector2 = tips[side]
		var tip_b: Vector2 = tips[(side + 1) % 4]
		var eave := (a + b) * 0.5
		var points := PackedVector2Array([
			_project(a, EAVE_HEIGHT + 10.0, half, centre),
			_project(eave, EAVE_HEIGHT, half, centre),
			_project(b, EAVE_HEIGHT + 10.0, half, centre),
			_project(tip_b, EAVE_HEIGHT + rise, half, centre),
		])
		var length: float = a.distance_to(b) * half.x
		var depth: float = radius * half.x
		var uv := PackedVector2Array([
			Vector2.ZERO, Vector2(length * 0.5, 0), Vector2(length, 0),
			Vector2((tip_b - a).dot((b - a).normalized()) * half.x, depth),
		])
		if not tip_a.is_equal_approx(tip_b):
			points.append(_project(tip_a, EAVE_HEIGHT + rise, half, centre))
			uv.append(Vector2((tip_a - a).dot((b - a).normalized()) * half.x, depth))
		for i in uv.size():
			uv[i] *= 0.5
		var face := Polygon2D.new()
		face.polygon = points
		face.uv = uv
		face.texture = TILES
		face.color = FACE_LIGHT[side]
		add_child(face)
		var trim := Line2D.new()
		trim.points = PackedVector2Array([points[0], points[1], points[2]])
		trim.width = 8.0
		trim.default_color = Color("#40362d")
		add_child(trim)
		var hip := Line2D.new()
		hip.points = PackedVector2Array([points[0], _project(tip_a, EAVE_HEIGHT + rise, half, centre)])
		hip.width = 6.0
		hip.default_color = Color("#76818c")
		add_child(hip)
	var ridge := Line2D.new()
	ridge.points = PackedVector2Array([
		_project(ridge_a, EAVE_HEIGHT + rise + 4.0, half, centre),
		_project(ridge_b, EAVE_HEIGHT + rise + 4.0, half, centre),
	])
	ridge.width = 10.0
	ridge.default_color = Color("#697783")
	add_child(ridge)
