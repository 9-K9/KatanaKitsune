extends Node2D

## F3 draws what the game is actually sensing with, rather than what it looks
## like it is sensing with. Off unless asked for.
##
## Worth keeping. Sitting on a chair went several rounds of "it looks wrong"
## against measurements saying it was right — the chair was rendering inside the
## player's own silhouette, and the sit target was a lifted origin floating
## above the furniture. None of that is visible in a build. Once the shapes were
## drawn, the answer stopped being a matter of nudging and turned out to be
## exactly the sort lift.

## Everything is drawn over the world, never mind y-sorting.
const OVERLAY_Z: int = 4096

## How far above a monster's origin its readout sits. Clear of the health bar,
## which the builder puts a little over 100 above the head at scale 1.
const LABEL_LIFT: float = 170.0
## Text size. 13 was unreadable at play distance once a few monsters bunched up.
const LABEL_SIZE: int = 20
const COLOUR_LABEL := Color(1.0, 1.0, 1.0, 0.95)
const COLOUR_LABEL_BACK := Color(0.0, 0.0, 0.0, 0.55)

const COLOUR_PLAYER := Color(0.30, 1.00, 0.45, 0.85)
const COLOUR_ZONE := Color(0.35, 0.80, 1.00, 0.75)
const COLOUR_SOLID := Color(1.00, 0.60, 0.20, 0.70)
const COLOUR_ENEMY := Color(1.00, 0.35, 0.35, 0.75)
## Her own hurtbox: what an enemy's attack actually has to land inside.
const COLOUR_HURTBOX := Color(0.55, 0.85, 1.00, 0.70)
## The blade's own hit area: what has to reach an enemy for a swing to land.
const COLOUR_WEAPON := Color(1.00, 0.20, 0.85, 0.70)
## Wall tiles, which collide as their drawn silhouette rather than a footprint.
const COLOUR_WALL := Color(0.75, 0.55, 1.00, 0.60)
## The chair she would sit on if she stood still long enough.
const COLOUR_PICKED := Color(1.00, 0.95, 0.40, 0.95)
const ORIGIN_ARM: float = 9.0
## Chair art is 96 tall with its stone ending at y 92, drawn from the sprite
## centre — so its base sits this far below the sprite node.
const CHAIR_BASE_BELOW_SPRITE: float = 44.0

var _on: bool = false
var _player: CharacterBody2D = null
## Label positions already used this frame, so two monsters standing together do
## not print over each other.
var _taken: Array[Vector2] = []


func _ready() -> void:
	z_index = OVERLAY_Z
	z_as_relative = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	## Off by default now the sitting is settled, but kept: drawing the shapes is
	## what turned a week of nudging offsets by eye into an exact answer, and the
	## next positioning problem will want it too.
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
	_taken.clear()
	var player := Roster.nearest_to(get_tree(), Vector2.ZERO)

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
		var target: Vector2 = anchor.global_position if anchor != null else node.global_position
		## Two points, because confusing them is exactly what went wrong. The
		## anchor is where her ORIGIN is sent, and her origin rides 100px above
		## her feet — so on screen it floats well above the chair and looks wrong
		## even when she lands right. The second cross is where her feet actually
		## come down, which is the one worth looking at.
		_cross(target, COLOUR_PICKED, "she sits here")
		## And where the chair's own stone meets the floor, to compare against.
		var art := node.get_node_or_null("Sprite2D") as Node2D
		if art != null:
			_cross(Vector2(node.global_position.x, node.global_position.y
					+ art.position.y + CHAIR_BASE_BELOW_SPRITE), COLOUR_SOLID, "chair base")
		if picked and player != null:
			draw_line(to_local(player.global_position), to_local(target), COLOUR_PICKED, 1.5)

	## Bodies. Her own shape first, then everything solid she can walk into.
	if player != null:
		_draw_body(player, COLOUR_PLAYER)
		_cross(player.global_position, COLOUR_PLAYER, "her origin")
		## Her own hurtbox and her blade's hitbox. Both sit a couple of levels
		## under CollisionChecker rather than directly on the body, so _draw_body
		## never reaches them — they were invisible under F3 even though the
		## body collision right next to them drew fine.
		var hurt_box := player.get_node_or_null("CollisionChecker/PlayerHitBox") as Area2D
		if hurt_box != null:
			_draw_area(hurt_box, COLOUR_HURTBOX)
		var action_area := player.get_node_or_null(
				"CollisionChecker/RayCast2D/ActionArea") as Area2D
		if action_area != null:
			_draw_area(action_area, COLOUR_WEAPON)
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is CollisionObject2D:
			_draw_body(node as CollisionObject2D, COLOUR_ENEMY)
		if node is Node2D:
			_label_enemy(node as Node2D)
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
		elif child is CollisionPolygon2D:
			## PlayerHitBox is built from one of these, not a CollisionShape2D —
			## without this branch her own hurtbox silently never drew.
			_outline((child as CollisionPolygon2D).polygon,
					(child as CollisionPolygon2D).global_transform, colour)


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




## What a monster is playing and which way it thinks it is facing.
##
## The two faults this is for are invisible in a screenshot and obvious in two
## lines of text. A clip bound to the wrong direction makes a monster travel one
## way while facing another, and raises no error because every name resolves.
## And a clip whose speed does not suit its frame count reads as a blur rather
## than a stride, which looks like bad art until the number is on screen.
func _label_enemy(node: Node2D) -> void:
	var sprite := node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	var clip: String = str(sprite.animation)
	var frames: int = 0
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(clip):
		frames = sprite.sprite_frames.get_frame_count(clip)
	var fps: float = 0.0
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(clip):
		fps = sprite.sprite_frames.get_animation_speed(clip)

	## The facing the monster believes it has, beside the direction it is
	## actually travelling. When those disagree, the sprite sheet is mis-wired.
	var facing: String = str(node.get("facing_dir")) if "facing_dir" in node else "?"
	var moving: String = ""
	if node is CharacterBody2D:
		var v: Vector2 = (node as CharacterBody2D).velocity
		if v.length() > 1.0:
			moving = IsoFacing.name_of(Vector2(signf(v.x), signf(v.y)))

	## Frame on screen, so a clip that is blurring can be read off directly.
	var line1 := "%s  %dfr @ %.0ffps  [%d]" % [clip, frames, fps, sprite.frame]
	var line2 := "facing %s%s" % [facing,
			("   moving %s   <-- MISMATCH" % moving) if (moving != "" and moving != facing) else ""]

	var font := ThemeDB.fallback_font
	var at: Vector2 = node.global_position - global_position + Vector2(0.0, -LABEL_LIFT)
	## Monsters bunch up and their readouts land on top of each other, which is
	## worse than no readout — two overlapping lines are unreadable and look like
	## one corrupted one. Nudge each label up until it clears the ones already
	## drawn this frame.
	var step: float = float(LABEL_SIZE) * 2.4
	while _taken.any(func(p: Vector2) -> bool:
			return absf(p.x - at.x) < 220.0 and absf(p.y - at.y) < step):
		at.y -= step
	_taken.append(at)

	for i in 2:
		var text: String = line1 if i == 0 else line2
		var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE)
		var where: Vector2 = at + Vector2(-size.x * 0.5, float(i) * (LABEL_SIZE + 4))
		draw_rect(Rect2(where + Vector2(-4.0, -float(LABEL_SIZE) + 2.0),
				size + Vector2(8.0, 5.0)), COLOUR_LABEL_BACK, true)
		draw_string(font, where, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, COLOUR_LABEL)
