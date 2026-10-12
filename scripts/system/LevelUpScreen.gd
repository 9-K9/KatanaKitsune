class_name LevelUpScreen
extends CanvasLayer

## Between-floor upgrades for every active player.
##
## Each column reads only its own player's device, so players spend at the same
## time. A player with nothing to spend starts ready.

signal finished

const UI_THEME := preload("res://assets/sprites/ui/katanaKitsune.theme.tres")
const FRAME_PORTRAIT := preload("res://assets/sprites/ui/frame_portrait.png")

const VIEW := Vector2(1536.0, 864.0)
const COLUMN_WIDTH: float = 330.0
const COLUMN_GAP: float = 24.0
const COLUMN_TOP: float = 150.0
const COLUMN_HEIGHT: float = 580.0
const ROW_TOP: float = 276.0
const ROW_HEIGHT: float = 52.0
const ROW_STEP: float = 58.0
const READY_ROW: int = 4
## Ignores the moment the screen appears, so a held attack does not spend.
const INPUT_GRACE: float = 0.35

var party: int = 1

var _columns: Array[Dictionary] = []
var _grace: float = INPUT_GRACE
var _done: bool = false


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("level_up_screen")
	party = clampi(party, 1, Progression.MAX_SLOTS)
	var root := Control.new()
	root.theme = UI_THEME
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.78)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var title := _label("LEVEL UP", 44, Color(1.0, 0.82, 0.38))
	title.position = Vector2(0.0, 58.0)
	title.size = Vector2(VIEW.x, 60.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var total: float = party * COLUMN_WIDTH + (party - 1) * COLUMN_GAP
	var left: float = (VIEW.x - total) * 0.5
	for slot in party:
		_columns.append(_build_column(root, slot, left + slot * (COLUMN_WIDTH + COLUMN_GAP)))
	var hint := _label("UP / DOWN CHOOSE    CONFIRM SPEND OR READY    BACK UNDO", 16,
			Color(0.82, 0.82, 0.82))
	hint.position = Vector2(0.0, COLUMN_TOP + COLUMN_HEIGHT + 30.0)
	hint.size = Vector2(VIEW.x, 28.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)
	for column in _columns:
		_refresh(column)


func _process(delta: float) -> void:
	if _done:
		return
	_grace = maxf(_grace - delta, 0.0)
	for column in _columns:
		var input: PlayerInput = column["input"]
		## Read every frame, including the grace period, so edges stay accurate.
		var up: bool = input.just_pressed("MenuUp")
		var down: bool = input.just_pressed("MenuDown")
		var confirm: bool = input.confirm_pressed()
		var cancel: bool = input.cancel_pressed()
		if _grace > 0.0:
			continue
		if up or down:
			_move(column, -1 if up else 1)
		elif confirm:
			_confirm(column)
		elif cancel:
			_cancel(column)
	if _grace <= 0.0 and _all_ready():
		_done = true
		finished.emit()


func _move(column: Dictionary, step: int) -> void:
	if column["ready"]:
		return
	column["cursor"] = wrapi(column["cursor"] + step, 0, READY_ROW + 1)
	_refresh(column)


func _confirm(column: Dictionary) -> void:
	if column["ready"]:
		return
	var slot: int = column["slot"]
	var cursor: int = column["cursor"]
	if cursor == READY_ROW:
		column["ready"] = true
	elif Progression.spend(slot, cursor):
		column["spent"].append(cursor)
		if Progression.points[slot] == 0:
			column["cursor"] = READY_ROW
	_refresh(column)


func _cancel(column: Dictionary) -> void:
	if column["ready"]:
		column["ready"] = false
	elif not column["spent"].is_empty():
		var stat: int = column["spent"].pop_back()
		Progression.refund(column["slot"], stat)
		column["cursor"] = stat
	_refresh(column)


## A slot whose pad is unplugged counts as ready, so the party is never held
## hostage by a missing controller. Unspent points stay banked for next floor.
func _all_ready() -> bool:
	for column in _columns:
		if not column["ready"] and not _is_lost(column["slot"]):
			return false
	return true


func _is_lost(slot: int) -> bool:
	return slot < Roster.count() and Roster.players[slot].get("lost", false)


func _build_column(root: Control, slot: int, x: float) -> Dictionary:
	var colour: Color = Roster.colour_of(slot) if Roster.count() > slot else Color(0.9, 0.25, 0.25)
	var panel := Panel.new()
	panel.position = Vector2(x, COLUMN_TOP)
	panel.size = Vector2(COLUMN_WIDTH, COLUMN_HEIGHT)
	panel.add_theme_stylebox_override("panel", _box(Color(0.04, 0.03, 0.04, 0.88), colour, 3))
	root.add_child(panel)

	var heading := _label("P%d" % (slot + 1), 26, colour)
	heading.position = Vector2(16.0, 12.0)
	heading.size = Vector2(COLUMN_WIDTH - 32.0, 34.0)
	panel.add_child(heading)
	var level := _label("", 26, Color.WHITE)
	level.position = heading.position
	level.size = heading.size
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(level)

	var frame := TextureRect.new()
	frame.texture = FRAME_PORTRAIT
	frame.position = Vector2((COLUMN_WIDTH - 124.0) * 0.5, 52.0)
	frame.size = Vector2(124.0, 124.0)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	panel.add_child(frame)
	var portrait := TextureRect.new()
	portrait.position = frame.position + Vector2(6.0, 6.0)
	portrait.size = frame.size - Vector2(12.0, 12.0)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var art = load(PowerState.icon_path(Roster.scheme_of(slot) if Roster.count() > slot else 0))
	if art is Texture2D:
		portrait.texture = art
	panel.add_child(portrait)
	panel.move_child(frame, panel.get_child_count() - 1)

	var bar := ProgressBar.new()
	bar.position = Vector2(20.0, 188.0)
	bar.size = Vector2(COLUMN_WIDTH - 40.0, 16.0)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _box(Color(0.12, 0.1, 0.1, 0.95), Color(0.0, 0.0, 0.0, 0.0), 0))
	bar.add_theme_stylebox_override("fill", _box(Color(1.0, 0.72, 0.25), Color(0.0, 0.0, 0.0, 0.0), 0))
	panel.add_child(bar)
	var xp := _label("", 16, Color(0.9, 0.9, 0.9))
	xp.position = Vector2(20.0, 207.0)
	xp.size = Vector2(COLUMN_WIDTH - 40.0, 22.0)
	xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(xp)
	var points := _label("", 22, Color(1.0, 0.82, 0.38))
	points.position = Vector2(20.0, 234.0)
	points.size = Vector2(COLUMN_WIDTH - 40.0, 30.0)
	points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(points)

	var rows: Array[Dictionary] = []
	for stat in READY_ROW + 1:
		rows.append(_build_row(panel, stat))
	var input: PlayerInput = Roster.input_for(slot) if Roster.count() > slot else PlayerInput.new()
	input.prime()
	return {"slot": slot, "colour": colour, "input": input, "cursor": 0,
			"ready": Progression.points[slot] == 0, "spent": [], "level": level,
			"bar": bar, "xp": xp, "points": points, "rows": rows}


func _build_row(panel: Panel, stat: int) -> Dictionary:
	var row := Panel.new()
	row.position = Vector2(14.0, ROW_TOP + stat * ROW_STEP)
	row.size = Vector2(COLUMN_WIDTH - 28.0, ROW_HEIGHT if stat < READY_ROW else 46.0)
	panel.add_child(row)
	var caption := _label("READY" if stat == READY_ROW else Progression.STAT_NAMES[stat], 20, Color.WHITE)
	caption.position = Vector2(12.0, 4.0 if stat < READY_ROW else 8.0)
	caption.size = Vector2(row.size.x - 24.0, 28.0)
	if stat == READY_ROW:
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(caption)
	var out := {"row": row, "name": caption, "pips": [], "bonus": null}
	if stat == READY_ROW:
		return out
	var bonus := _label("", 14, Color(0.78, 0.78, 0.78))
	bonus.position = Vector2(12.0, 29.0)
	bonus.size = Vector2(row.size.x - 24.0, 20.0)
	row.add_child(bonus)
	out["bonus"] = bonus
	for i in Progression.MAX_RANK:
		var pip := ColorRect.new()
		pip.position = Vector2(row.size.x - 112.0 + i * 20.0, 13.0)
		pip.size = Vector2(14.0, 14.0)
		row.add_child(pip)
		out["pips"].append(pip)
	return out


func _refresh(column: Dictionary) -> void:
	var slot: int = column["slot"]
	var level: int = Progression.level[slot]
	var needed: int = Progression.xp_to_next(level)
	(column["level"] as Label).text = "LEVEL %d" % level
	var bar: ProgressBar = column["bar"]
	bar.max_value = needed
	bar.value = Progression.xp[slot]
	(column["xp"] as Label).text = "%d / %d XP" % [Progression.xp[slot], needed]
	var points: int = Progression.points[slot]
	(column["points"] as Label).text = ("%d POINT%s" % [points, "" if points == 1 else "S"]) \
			if points > 0 else "NO POINTS"
	var colour: Color = column["colour"]
	for i in column["rows"].size():
		var row: Dictionary = column["rows"][i]
		var selected: bool = i == column["cursor"] and not column["ready"]
		var fill := Color(colour.r, colour.g, colour.b, 0.35) if selected else Color(0.0, 0.0, 0.0, 0.45)
		if i == READY_ROW and column["ready"]:
			fill = Color(0.2, 0.55, 0.28, 0.75)
		(row["row"] as Panel).add_theme_stylebox_override("panel",
				_box(fill, colour if selected else Color(0.3, 0.3, 0.3, 0.8), 2 if selected else 1))
		if i == READY_ROW:
			(row["name"] as Label).text = "READY!" if column["ready"] else "READY"
			continue
		var rank: int = Progression.rank(slot, i)
		for p in row["pips"].size():
			(row["pips"][p] as ColorRect).color = Color(1.0, 0.72, 0.25) if p < rank \
					else Color(0.22, 0.2, 0.2)
		var now := Progression.bonus_text(i, rank) if rank > 0 else "BASE"
		(row["bonus"] as Label).text = (now + "  MAX") if rank >= Progression.MAX_RANK \
				else "%s  >  %s" % [now, Progression.bonus_text(i, rank + 1)]


func _label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label


func _box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	return box
