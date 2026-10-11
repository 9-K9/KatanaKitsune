extends CanvasLayer

## Arcade name entry, then the table.
##
## Shown when a run ends on a score good enough to place. Up to nine characters,
## driven by the device that earned the score rather than by whichever pad is
## nearest — in a party, the entry belongs to the player whose run it was.

signal finished

const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
const NAME_LENGTH: int = 9
const SPACE_INDEX: int = 36
## Held direction repeat, so a stick does not spin the wheel.
const REPEAT: float = 0.18

var _slot: int = 0
var _letters: Array[int] = []
var _at: int = 0
var _repeat_left: float = 0.0
var _input: PlayerInput = null
var _points: int = 0
var _wave: int = 1
var _done: bool = false

var _title: Label = null
var _entry: Label = null
var _table: Label = null
var _help: Label = null


## `slot` is the player whose score this is; their pad drives the wheel.
func open(slot: int, points: int, wave: int) -> void:
	_slot = slot
	_points = points
	_wave = wave
	_input = Roster.input_for(slot)
	## Primed, or the button that dismissed the previous screen enters a letter
	## the instant this one appears.
	_input.prime()
	_build()
	visible = true


func _build() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS

	var wash := ColorRect.new()
	wash.color = Color(0.03, 0.02, 0.04, 0.88)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)

	_title = _label(42.0, Color(0.95, 0.82, 0.45))
	_title.text = "P%d  —  %d  —  FLOOR %d" % [_slot + 1, _points, _wave]
	_title.offset_top = 120.0

	_entry = _label(58.0, Roster.colour_of(_slot))
	_entry.offset_top = 205.0

	_help = _label(18.0, Color(0.72, 0.68, 0.60))
	_help.offset_top = 300.0
	if _input.device == PlayerInput.KEYBOARD:
		_help.text = "TYPE YOUR NAME  •  BACKSPACE TO EDIT  •  ENTER TO SAVE"
	else:
		_help.text = "D-PAD: LETTER / SPACE  •  %s: NEXT  •  %s: BACK" % [
			_input.confirm_button_label(), "CANCEL"]

	_table = _label(20.0, Color(0.72, 0.68, 0.60))
	_table.offset_top = 370.0

	_letters.resize(NAME_LENGTH)
	_letters.fill(SPACE_INDEX)
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if _done or _input == null or _input.device != PlayerInput.KEYBOARD:
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_BACKSPACE:
		if _at > 0:
			_at -= 1
		_letters[_at] = SPACE_INDEX
		_refresh()
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_commit()
		get_viewport().set_input_as_handled()
		return
	if key.unicode <= 0:
		return
	var typed := String.chr(key.unicode).to_upper()
	var letter_index: int = LETTERS.find(typed)
	if letter_index < 0:
		return
	_letters[_at] = letter_index
	if _at < NAME_LENGTH - 1:
		_at += 1
	else:
		_commit()
		return
	_refresh()
	get_viewport().set_input_as_handled()


func _label(size: float, tint: Color) -> Label:
	var node := Label.new()
	node.set_anchors_preset(Control.PRESET_TOP_WIDE)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size", int(size))
	node.add_theme_color_override("font_color", tint)
	add_child(node)
	return node


func _process(delta: float) -> void:
	if _done or _input == null:
		return
	_repeat_left = maxf(_repeat_left - delta, 0.0)

	if _input.confirm_pressed():
		_at += 1
		if _at >= NAME_LENGTH:
			_commit()
		else:
			_refresh()
		return
	if _input.cancel_pressed():
		## Back a character, or clear the current one at the beginning.
		if _at > 0:
			_at -= 1
		_letters[_at] = SPACE_INDEX
		_refresh()
		return
	if _repeat_left > 0.0:
		return

	var step: int = 0
	if _input.pressed("Up") or _input.pressed("Right"):
		step = 1
	elif _input.pressed("Down") or _input.pressed("Left"):
		step = -1
	if step == 0:
		return
	_repeat_left = REPEAT
	_letters[_at] = wrapi(_letters[_at] + step, 0, LETTERS.length())
	_refresh()


func _refresh() -> void:
	var shown := ""
	for i in NAME_LENGTH:
		var ch: String = LETTERS[_letters[i]]
		## The one being edited is bracketed, so the caret reads without a cursor
		## that would have to blink in step with everything else.
		var visible_char: String = "_" if ch == " " else ch
		shown += ("[%s]" % visible_char) if i == _at else (" %s " % visible_char)
	_entry.text = shown

	var rows := "HIGH SCORES\n"
	for i in mini(Score.table.size(), 5):
		rows += "%d.  %-9s  %8d   wave %d\n" % [
			i + 1, Score.table[i]["name"], Score.table[i]["points"],
			Score.table[i]["wave"]]
	_table.text = rows


func _commit() -> void:
	_done = true
	var name := ""
	for i in NAME_LENGTH:
		name += LETTERS[_letters[i]]
	name = name.strip_edges()
	if name.is_empty():
		name = "PLAYER"
	Score.submit(name.strip_edges(), _points, _wave)
	_refresh()
	_entry.text = name
	await get_tree().create_timer(1.8, true).timeout
	finished.emit()
