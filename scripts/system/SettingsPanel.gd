class_name SettingsPanel
extends VBoxContainer

## Display settings list. Shared by the title screen and the pause menu; the
## owner shows or hides it and listens for back_pressed.

signal back_pressed

@export var font_size: int = 12

var _toggles := {}
var _display: Array[Control] = []
var controls: ControlsPanel


func _ready() -> void:
	var title := Label.new()
	title.text = tr("DISPLAY")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", font_size + 1)
	add_child(title)
	_display.append(title)

	for id in RetroFX.EFFECTS:
		var toggle := CheckButton.new()
		toggle.add_theme_font_size_override("font_size", font_size)
		toggle.toggled.connect(_on_toggled.bind(id))
		add_child(toggle)
		_toggles[id] = toggle
		_display.append(toggle)

	var controls_button := Button.new()
	controls_button.text = tr("CONTROLS")
	controls_button.add_theme_font_size_override("font_size", font_size + 1)
	controls_button.pressed.connect(_open_controls)
	add_child(controls_button)
	_display.append(controls_button)

	var back := Button.new()
	back.text = tr("BACK")
	back.add_theme_font_size_override("font_size", font_size + 1)
	back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back)
	_display.append(back)

	controls = ControlsPanel.new()
	controls.font_size = font_size
	controls.visible = false
	controls.back_pressed.connect(_close_controls)
	add_child(controls)

	visibility_changed.connect(_sync)
	_sync()


func _sync() -> void:
	if visible and controls.visible:
		_close_controls()
	for id in _toggles:
		var toggle: CheckButton = _toggles[id]
		toggle.set_pressed_no_signal(RetroFX.is_enabled(id))
		_update_label(id)


func _open_controls() -> void:
	for node in _display:
		node.visible = false
	controls.visible = true
	TitleScreen.focus_first_button(controls)


func _close_controls() -> void:
	controls.visible = false
	for node in _display:
		node.visible = true
	if visible:
		TitleScreen.focus_first_button(self)


func _on_toggled(enabled: bool, id: String) -> void:
	RetroFX.set_enabled(id, enabled)
	_update_label(id)


func _update_label(id: String) -> void:
	var toggle: CheckButton = _toggles[id]
	toggle.text = "%s: %s" % [tr(RetroFX.EFFECTS[id]["label"]), tr("ON") if toggle.button_pressed else tr("OFF")]
