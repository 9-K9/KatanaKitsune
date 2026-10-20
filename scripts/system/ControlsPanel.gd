class_name ControlsPanel
extends VBoxContainer

## Settings > Controls. Pick a player, pick the device they play on, and press
## a row to rebind that action — then APPLY and confirm. Built in code like
## SettingsPanel, so the title screen and the pause menu share one copy.
##
## Edits live in ControlSettings' working copy until APPLY saves them; BACK with
## unsaved edits asks first, so a slip of the hand cannot silently change a key.

signal back_pressed

const CAPTURE_TIMEOUT: float = 5.0
## A stick has to be pushed well past the gameplay deadzone to count as a
## deliberate binding, or a resting stick binds itself to the first row.
const CAPTURE_AXIS: float = 0.6

@export var font_size: int = 12

## Optional gate on which device may drive this panel (the pause menu's owner).
## Called with the InputEvent; return false to ignore it.
var input_filter: Callable

var _slot: int = 0
## Which half of the bindings the rows show and capture: true = keyboard.
var _keyboard: bool = true
var _capturing: String = ""
var _capture_left: float = 0.0
var _leaving: bool = false

var _title: Label
var _player_button: Button
var _device_button: Button
var _kind_button: Button
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _row_buttons: Dictionary = {}
var _hint: Label
var _footer: VBoxContainer
var _confirm: VBoxContainer
var _confirm_text: Label


func _ready() -> void:
	_title = _label("CONTROLS", font_size + 1)
	add_child(_title)

	_player_button = _button("", _cycle_player)
	add_child(_player_button)
	_device_button = _button("", _cycle_device)
	add_child(_device_button)
	_kind_button = _button("", _cycle_kind)
	add_child(_kind_button)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 11 * (font_size + 10))
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)
	for action in ControlSettings.REBINDABLE:
		var row := HBoxContainer.new()
		var name := _label(ControlSettings.LABELS.get(action, action), font_size)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var bind := _button("", _begin_capture.bind(action))
		bind.custom_minimum_size = Vector2(7 * font_size, 0)
		row.add_child(bind)
		_rows.add_child(row)
		_row_buttons[action] = bind

	_hint = _label("", font_size - 1)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint)

	_footer = VBoxContainer.new()
	add_child(_footer)
	_footer.add_child(_button("RESET TO DEFAULT", _reset))
	_footer.add_child(_button("APPLY", _apply))
	_footer.add_child(_button("BACK", _back))

	_confirm = VBoxContainer.new()
	_confirm.visible = false
	add_child(_confirm)
	_confirm.add_child(_label("SAVE NEW CONTROLS?", font_size + 1))
	_confirm_text = _label("", font_size - 1)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm.add_child(_confirm_text)
	_confirm.add_child(_button("SAVE", _confirm_save))
	_confirm.add_child(_button("DISCARD", _confirm_discard))
	_confirm.add_child(_button("KEEP EDITING", _confirm_keep))

	visibility_changed.connect(_on_visibility_changed)
	set_process(false)
	_refresh()


## Resets to a sane view each time the owner shows this panel.
func _on_visibility_changed() -> void:
	if not visible:
		_end_capture()
		return
	_leaving = false
	_show_confirm(false)
	## Open on the half of the bindings the player will actually use.
	_keyboard = ControlSettings.assigned_device(_slot) < 0
	_refresh()


## ----------------------------------------------------------------- display

func _refresh() -> void:
	_player_button.text = "PLAYER: P%d" % (_slot + 1)
	_device_button.text = "DEVICE: %s" % ControlSettings.device_label(ControlSettings.assigned_device(_slot))
	_kind_button.text = "EDITING: %s" % ("KEYBOARD" if _keyboard else "GAMEPAD")
	for action in _row_buttons:
		var button: Button = _row_buttons[action]
		if action == _capturing:
			button.text = "..."
		elif _keyboard:
			button.text = ControlSettings.keyboard_label(_slot, action)
		else:
			button.text = ControlSettings.pad_label(_slot, action)
	if _capturing == "":
		_hint.text = "UNSAVED CHANGES" if ControlSettings.has_unsaved_changes() else ""


func _show_confirm(show_confirm: bool) -> void:
	_confirm.visible = show_confirm
	for node in [_title, _player_button, _device_button, _kind_button, _scroll, _hint, _footer]:
		(node as Control).visible = not show_confirm
	if show_confirm:
		var lines := ControlSettings.pending_changes()
		_confirm_text.text = "\n".join(lines) if not lines.is_empty() else "NO CHANGES"
		TitleScreen.focus_first_button(_confirm)
	elif visible:
		_player_button.grab_focus()


## ---------------------------------------------------------------- selectors

func _cycle_player() -> void:
	_slot = (_slot + 1) % Roster.MAX_PLAYERS
	_refresh()


func _cycle_device() -> void:
	var options: Array[int] = [ControlSettings.UNASSIGNED, PlayerInput.KEYBOARD]
	for id in Input.get_connected_joypads():
		options.append(id)
	var current: int = ControlSettings.assigned_device(_slot)
	if current not in options:
		options.append(current)
	var next: int = options[(options.find(current) + 1) % options.size()]
	ControlSettings.assign_device(_slot, next)
	if next != ControlSettings.UNASSIGNED:
		_keyboard = next == PlayerInput.KEYBOARD
	_refresh()


func _cycle_kind() -> void:
	_keyboard = not _keyboard
	_refresh()


## ------------------------------------------------------------------ capture

func _begin_capture(action: String) -> void:
	_capturing = action
	_capture_left = CAPTURE_TIMEOUT
	set_process(true)
	_hint.text = "PRESS A %s FOR %s — ESC CANCELS" % [
			"KEY" if _keyboard else "BUTTON", ControlSettings.LABELS.get(action, action)]
	_refresh()


func _end_capture() -> void:
	var was := _capturing
	_capturing = ""
	set_process(false)
	_refresh()
	if was != "" and _row_buttons.has(was) and visible:
		(_row_buttons[was] as Button).grab_focus()


func _process(delta: float) -> void:
	if _capturing == "":
		return
	_capture_left -= delta
	if _capture_left <= 0.0:
		_end_capture()


func _input(event: InputEvent) -> void:
	if _capturing == "" or not visible:
		return
	if input_filter.is_valid() and not input_filter.call(event):
		return
	## Nothing leaks to the buttons underneath while a key is being chosen.
	var accepted: InputEvent = null
	if event is InputEventKey:
		var key := event as InputEventKey
		get_viewport().set_input_as_handled()
		if not key.pressed or key.echo:
			return
		if key.physical_keycode == KEY_ESCAPE or key.keycode == KEY_ESCAPE:
			_end_capture()
			return
		if _keyboard:
			accepted = key
	elif event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
		if not (event as InputEventJoypadButton).pressed:
			return
		if not _keyboard:
			accepted = event
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) < CAPTURE_AXIS:
			return
		get_viewport().set_input_as_handled()
		if not _keyboard:
			accepted = motion
	elif event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
	if accepted == null:
		if event is InputEventKey or event is InputEventJoypadButton:
			_hint.text = "THAT IS A %s — EDITING %s" % [
					"KEY" if event is InputEventKey else "PAD BUTTON",
					"KEYBOARD" if _keyboard else "GAMEPAD"]
		return
	var problem := ControlSettings.set_binding(_slot, _capturing, accepted)
	_end_capture()
	if problem != "":
		_hint.text = problem


## ------------------------------------------------------------------ footer

func _reset() -> void:
	ControlSettings.reset(_slot)
	_refresh()


func _apply() -> void:
	_leaving = false
	_show_confirm(true)


func _back() -> void:
	if ControlSettings.has_unsaved_changes():
		_leaving = true
		_show_confirm(true)
		return
	back_pressed.emit()


func _confirm_save() -> void:
	ControlSettings.save()
	_show_confirm(false)
	_refresh()
	if _leaving:
		back_pressed.emit()


func _confirm_discard() -> void:
	ControlSettings.revert()
	_show_confirm(false)
	_refresh()
	if _leaving:
		back_pressed.emit()


func _confirm_keep() -> void:
	_leaving = false
	_show_confirm(false)


## ----------------------------------------------------------------- helpers

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	return label


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(on_pressed)
	return button
