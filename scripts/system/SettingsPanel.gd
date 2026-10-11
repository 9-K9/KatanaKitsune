class_name SettingsPanel
extends VBoxContainer

## Display settings list. Shared by the title screen and the pause menu; the
## owner shows or hides it and listens for back_pressed.

signal back_pressed

@export var font_size: int = 12

var _toggles := {}


func _ready() -> void:
	var title := Label.new()
	title.text = "DISPLAY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", font_size + 1)
	add_child(title)

	for id in RetroFX.EFFECTS:
		var toggle := CheckButton.new()
		toggle.add_theme_font_size_override("font_size", font_size)
		toggle.toggled.connect(_on_toggled.bind(id))
		add_child(toggle)
		_toggles[id] = toggle

	var back := Button.new()
	back.text = "BACK"
	back.add_theme_font_size_override("font_size", font_size + 1)
	back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back)

	visibility_changed.connect(_sync)
	_sync()


func _sync() -> void:
	for id in _toggles:
		var toggle: CheckButton = _toggles[id]
		toggle.set_pressed_no_signal(RetroFX.is_enabled(id))
		_update_label(id)


func _on_toggled(enabled: bool, id: String) -> void:
	RetroFX.set_enabled(id, enabled)
	_update_label(id)


func _update_label(id: String) -> void:
	var toggle: CheckButton = _toggles[id]
	toggle.text = "%s: %s" % [RetroFX.EFFECTS[id]["label"], "ON" if toggle.button_pressed else "OFF"]
