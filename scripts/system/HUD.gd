extends CanvasLayer

## The party's readouts: one cell per player, in a row across the top.
##
## Every cell is built the same way by the same code, including player one's.
## The scene still carries player one's original nodes, but they are hidden on
## start — having one player laid out by hand in the scene and the rest built in
## a loop meant two places to change whenever the design moved, and they drifted
## apart immediately (player two ended up with different bars and no eye).
##
## Bars are drawn by hand rather than with ProgressBar because the lacquer frame
## is pixel art with a fixed cavity, and the fill has to sit exactly inside it.

## One cell per player, laid left to right. 1536 wide viewport, radar on the
## right from about x=1376, so four 300px cells clear it.
const CELL_WIDTH: float = 300.0
const CELL_LEFT: float = 8.0
const CELL_TOP: float = 8.0

const PORTRAIT: float = 56.0
const BAR_LEFT: float = 68.0
const BAR_WIDTH: float = 168.0
## Inset from the bar frame's edge to the lacquer cavity the fill sits in.
const FILL_INSET: Vector2 = Vector2(9, 8)

## The sneak eye, one per player, at the right of their cell.
const EYE_SIZE: float = 34.0
const EYE_RING: float = 21.0
const EYE_RING_WIDTH: float = 3.0

## Blinking is a sign of life, and belongs only in the calm state: an eye that
## blinked while shut would be nonsense, and one that blinked while something
## was charging at its owner would undercut the alarm. Carried over from the
## standalone eye that used to sit beside the radar, which this row replaces.
const BLINK_EVERY := Vector2(2.4, 6.0)
const BLINK_LENGTH: float = 0.11

const EYE_CALM := preload("res://assets/sprites/ui/eye/eye_calm.png")
const EYE_ALERT := preload("res://assets/sprites/ui/eye/eye_alert.png")
const EYE_CLOSED := preload("res://assets/sprites/ui/eye/eye_closed.png")

## Hotter as the chain climbs, so a glance reads the grade without the letter.
const GRADE_COLOURS := {
	"D": Color(0.70, 0.70, 0.72), "C": Color(0.60, 0.82, 0.95),
	"B": Color(0.55, 0.92, 0.60), "A": Color(0.98, 0.85, 0.35),
	"S": Color(1.00, 0.60, 0.25), "SS": Color(1.00, 0.35, 0.30),
	"SSS": Color(1.00, 0.30, 0.65),
}

const FRAME_PORTRAIT := preload("res://assets/sprites/ui/frame_portrait.png")
const FRAME_BAR := preload("res://assets/sprites/ui/bar_frame.png")
const UI_THEME := preload("res://assets/sprites/ui/katanaKitsune.theme.tres")

@onready var depth_label: Label = $Depth
var _kill_count_label: Label = null

## One entry per player: the nodes that make up their cell.
var _cells: Array[Dictionary] = []
## Health eases towards the real value so chip damage reads as a drain rather
## than a jump. Kept per player, hence an array rather than a single float.
var _shown: Array[float] = []
## Where the party's rings are drawn. A single Control on top of the cells, so
## all four rings come from one _draw rather than four scripts.
var _rings: Control = null


func _ready() -> void:
	## Player one's hand-laid-out nodes step aside for the generated row.
	for name in ["Portrait", "PortraitFrame", "Bar", "Stamina", "Name"]:
		var node := get_node_or_null(name) as CanvasItem
		if node != null:
			node.visible = false

	_rings = Control.new()
	_rings.name = "SneakRings"
	_rings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rings.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rings.draw.connect(_draw_rings)
	add_child(_rings)

	_kill_count_label = Label.new()
	_kill_count_label.name = "KillCount"
	_kill_count_label.theme = UI_THEME
	_kill_count_label.position = Vector2(CELL_LEFT + 4.0, CELL_TOP + 98.0)
	_kill_count_label.size = Vector2(CELL_WIDTH - 8.0, 26.0)
	_kill_count_label.add_theme_font_size_override("font_size", 18)
	_kill_count_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.42))
	_kill_count_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.05, 0.95))
	_kill_count_label.add_theme_constant_override("outline_size", 3)
	_back_text(_kill_count_label)
	add_child(_kill_count_label)

	## Deferred a frame: the players are spawned by the maze during its own
	## _ready, so asking for them now finds nobody and the row comes out empty.
	await get_tree().process_frame
	for slot in maxi(Roster.count(), 1):
		_cells.append(_build_cell(slot))
		_shown.append(-1.0)

	var scroll_bar := ScrollHotbar.new()
	scroll_bar.name = "ScrollHotbar"
	scroll_bar.player_count = maxi(Roster.count(), 1)
	scroll_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(scroll_bar)

	if depth_label != null:
		depth_label.position = Vector2(CELL_LEFT + 4.0, CELL_TOP + 78.0)
		_back_text(depth_label)


func _back_text(label: Label) -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.04, 0.03, 0.05, 0.78)
	backing.content_margin_left = 3.0
	backing.content_margin_right = 3.0
	label.add_theme_stylebox_override("normal", backing)


## One player's readout: portrait, tag, health, stamina, eye.
func _build_cell(slot: int) -> Dictionary:
	var x: float = CELL_LEFT + CELL_WIDTH * float(slot)
	var tint: Color = Roster.colour_of(slot)

	var portrait := TextureRect.new()
	portrait.position = Vector2(x + 4.0, CELL_TOP + 4.0)
	portrait.size = Vector2(PORTRAIT - 8.0, PORTRAIT - 8.0)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var art := load(PowerState.icon_path(Roster.scheme_of(slot)))
	if art != null:
		portrait.texture = art
	add_child(portrait)

	var frame := NinePatchRect.new()
	frame.position = Vector2(x, CELL_TOP)
	frame.size = Vector2(PORTRAIT, PORTRAIT)
	frame.texture = FRAME_PORTRAIT
	for side in ["left", "top", "right", "bottom"]:
		frame.set("patch_margin_%s" % side, 16)
	## Tinted to the slot colour, which is what tells the players apart — the
	## aspect is each player's own choice and two can look alike at a glance.
	frame.modulate = Color(tint.r, tint.g, tint.b, 1.0).lerp(Color.WHITE, 0.35)
	add_child(frame)

	var tag := Label.new()
	tag.position = Vector2(x + BAR_LEFT, CELL_TOP - 2.0)
	tag.text = "P%d" % (slot + 1)
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", tint)
	_back_text(tag)
	add_child(tag)

	var health := _build_bar(x, CELL_TOP + 18.0, Color(0.78, 0.17, 0.16))
	var stamina := _build_bar(x, CELL_TOP + 40.0, Color(0.45, 0.62, 0.36))

	## The eye reads as a face rather than a meter, which is the point — it says
	## "am I hidden" at a glance where a fourth bar would just be another bar.
	var eye := TextureRect.new()
	eye.position = Vector2(x + BAR_LEFT + BAR_WIDTH + 14.0, CELL_TOP + 8.0)
	eye.size = Vector2(EYE_SIZE, EYE_SIZE)
	eye.texture = EYE_CALM
	eye.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	eye.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	eye.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(eye)

	## The running score, beside the player number.
	var score := Label.new()
	score.position = Vector2(x + BAR_LEFT + 34.0, CELL_TOP - 2.0)
	score.text = "0"
	score.add_theme_font_size_override("font_size", 14)
	score.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	_back_text(score)
	add_child(score)

	return {"slot": slot, "portrait": portrait, "frame": frame, "score": score,
			"health": health, "stamina": stamina, "eye": eye,
			"eye_centre": eye.position + Vector2(EYE_SIZE, EYE_SIZE) * 0.5,
			## Staggered per player, or four eyes blink in unison and the row
			## reads as one animation rather than four characters.
			"blink_in": randf_range(BLINK_EVERY.x, BLINK_EVERY.y),
			"blink_left": 0.0}


## A lacquer-framed bar. The frame is a NinePatchRect so it can be any width
## without the art stretching — at a quarter of its original length a plain
## TextureRect squashes the corner detail into mush.
func _build_bar(x: float, y: float, colour: Color) -> ColorRect:
	var frame := NinePatchRect.new()
	frame.position = Vector2(x + BAR_LEFT, y)
	frame.size = Vector2(BAR_WIDTH, 20.0)
	frame.texture = FRAME_BAR
	frame.patch_margin_left = 12
	frame.patch_margin_right = 12
	frame.patch_margin_top = 8
	frame.patch_margin_bottom = 8
	add_child(frame)

	var fill := ColorRect.new()
	fill.position = frame.position + Vector2(FILL_INSET.x, 6.0)
	fill.size = Vector2(BAR_WIDTH - FILL_INSET.x * 2.0, 8.0)
	fill.color = colour
	add_child(fill)
	return fill


## Every player body, keyed by the slot it was spawned into.
func _body_for(slot: int) -> CharacterBody2D:
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D and node.get("slot") == slot:
			return node
	return null


func _process(delta: float) -> void:
	for i in _cells.size():
		_update_cell(i, delta)
	if _rings != null:
		_rings.queue_redraw()
	_show_depth()
	_show_kill_count()


func _update_cell(index: int, delta: float) -> void:
	var cell: Dictionary = _cells[index]
	var body := _body_for(cell["slot"])
	if body == null:
		return
	var dead: bool = body.get("is_dead") == true
	var full_width: float = BAR_WIDTH - FILL_INSET.x * 2.0

	var ratio: float = 0.0 if dead else clampf(
			body.health / maxf(body.max_health, 1.0), 0.0, 1.0)
	_shown[index] = ratio if _shown[index] < 0.0 else move_toward(
			_shown[index], ratio, delta * 1.2)
	var health: ColorRect = cell["health"]
	health.size.x = full_width * _shown[index]
	health.color = Color(0.78, 0.17, 0.16) if _shown[index] > 0.3 \
			else Color(0.9, 0.35, 0.12)

	## Stamina has no easing: it needs to read as empty the moment the sprint
	## stops, because that is the moment the speed is lost.
	var stamina: ColorRect = cell["stamina"]
	stamina.size.x = full_width * clampf(
			body.stamina / maxf(body.max_stamina, 1.0), 0.0, 1.0)
	var spent: bool = body.has_method("winded") and body.winded()
	stamina.color = Color(0.55, 0.34, 0.16) if spent else Color(0.45, 0.62, 0.36)

	## A downed player greys out rather than vanishing, so you can still see who
	## is missing and go back for them.
	var portrait: TextureRect = cell["portrait"]
	portrait.modulate = Color(0.35, 0.3, 0.32) if dead else Color.WHITE

	var score: Label = cell["score"]
	var want: String = "%d" % Score.points[cell["slot"]]
	if score.text != want:
		score.text = want

	var eye: TextureRect = cell["eye"]
	var hidden: bool = body.get("stealthed") == true or body.get("crouched") == true
	if hidden:
		eye.texture = EYE_CLOSED
		cell["blink_left"] = 0.0
	elif _hunted(body):
		eye.texture = EYE_ALERT
		cell["blink_left"] = 0.0
	else:
		eye.texture = _blink(cell, delta)


## The calm eye, blinking every few seconds.
func _blink(cell: Dictionary, delta: float) -> Texture2D:
	if cell["blink_left"] > 0.0:
		cell["blink_left"] = cell["blink_left"] - delta
		return EYE_CLOSED if cell["blink_left"] > 0.0 else EYE_CALM
	cell["blink_in"] = cell["blink_in"] - delta
	if cell["blink_in"] <= 0.0:
		cell["blink_in"] = randf_range(BLINK_EVERY.x, BLINK_EVERY.y)
		cell["blink_left"] = BLINK_LENGTH
		return EYE_CLOSED
	return EYE_CALM


## Is anything actively hunting this player. Read off the monster's own state
## machine, exactly as Radar picks its red blips, so the eye and the radar
## cannot disagree about who has been seen.
func _hunted(body: Node2D) -> bool:
	for node in get_tree().get_nodes_in_group("enemy"):
		if not (node is Node2D) or not is_instance_valid(node):
			continue
		var machine := node.get_node_or_null("FiniteStateMachine")
		if machine == null or machine.current_state == null:
			continue
		if not String(machine.current_state.name) in ["walk", "attack"]:
			continue
		## Only counts as hunting *this* player if they are the nearest one,
		## which is the rule the monster itself uses to pick a target.
		if node.has_method("player") and node.player() == body:
			return true
	return false


## The sneak meters, drawn as a ring around each player's eye.
func _draw_rings() -> void:
	for cell in _cells:
		var body := _body_for(cell["slot"])
		if body == null:
			continue
		var centre: Vector2 = cell["eye_centre"]
		var tint: Color = Roster.colour_of(cell["slot"])
		var hidden: bool = body.get("stealthed") == true \
				or body.get("crouched") == true
		## The empty track first, so a nearly spent meter still reads as a ring
		## rather than as a stray arc floating beside the face.
		_rings.draw_arc(centre, EYE_RING, 0.0, TAU, 40,
				Color(0.10, 0.09, 0.14, 0.70), EYE_RING_WIDTH, true)
		var left: float = clampf(
				body.get("sneak") / maxf(body.get("max_sneak"), 1.0), 0.0, 1.0)
		var ink: Color = tint
		## Reddens as it runs out, so the last of their cover is visible without
		## having to read the arc's length.
		if left < 0.3:
			ink = ink.lerp(Color(0.88, 0.22, 0.20), 1.0 - left / 0.3)
		## Dimmed while they are upright, where it is a reserve rather than a
		## countdown, and should not compete with the eye itself.
		ink.a = 0.95 if hidden else 0.40
		## Unwinds from twelve o'clock, the way a clock does.
		_rings.draw_arc(centre, EYE_RING, -PI * 0.5, -PI * 0.5 + TAU * left, 40,
				ink, EYE_RING_WIDTH, true)


## Only the generated levels have a depth; the hand-built maps leave this blank.
func _show_depth() -> void:
	var level = get_tree().current_scene
	if level == null or not ("depth" in level):
		return
	var text: String = "FLOOR %d" % level.depth
	if depth_label.text != text:
		depth_label.text = text


## Shows floor kills over the number of enemies actually spawned.
func _show_kill_count() -> void:
	if _kill_count_label == null:
		return
	var level = get_tree().current_scene
	if level == null or not ("enemies_killed" in level) \
			or not ("enemies_total" in level):
		_kill_count_label.visible = false
		return
	_kill_count_label.visible = true
	var killed: int = level.enemies_killed
	var total: int = level.enemies_total
	var remaining: int = maxi(total - killed, 0)
	var text: String = "KILLS %d / %d   LEFT %d" % [killed, total, remaining]
	if _kill_count_label.text != text:
		_kill_count_label.text = text
