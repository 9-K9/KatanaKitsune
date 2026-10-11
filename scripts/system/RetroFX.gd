extends Node

## Retro screen effects (CRT, scanlines, vignette). An autoload, so the overlay
## survives scene changes and the choices are saved to user://settings.cfg.

signal changed

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "retro_fx"

const EFFECTS := {
	"crt": {"label": "CRT SCREEN", "shader": "res://shaders/retro_crt.gdshader", "layer": 100},
	"scanlines": {"label": "SCANLINES", "shader": "res://shaders/retro_scanlines.gdshader", "layer": 101},
	"vignette": {"label": "VIGNETTE", "shader": "res://shaders/retro_vignette.gdshader", "layer": 102},
}

var _enabled := {"crt": true, "scanlines": true, "vignette": true}
var _rects := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	for id in EFFECTS:
		_build(id)
	_apply_all()


func is_enabled(id: String) -> bool:
	return _enabled.get(id, false)


func set_enabled(id: String, enabled: bool) -> void:
	if not _enabled.has(id) or _enabled[id] == enabled:
		return
	_enabled[id] = enabled
	_apply_all()
	_save()
	changed.emit()


func _build(id: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = EFFECTS[id]["layer"]
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load(EFFECTS[id]["shader"])
	rect.material = material
	layer.add_child(rect)
	_rects[id] = layer


func _apply_all() -> void:
	for id in _rects:
		_rects[id].visible = _enabled[id]


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for id in _enabled:
		_enabled[id] = bool(config.get_value(SECTION, id, _enabled[id]))


func _save() -> void:
	## Other settings may share the file later, so read-modify-write.
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	for id in _enabled:
		config.set_value(SECTION, id, _enabled[id])
	config.save(SETTINGS_PATH)
