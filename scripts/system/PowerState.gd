extends Node

## The twelve elemental colour schemes, and the one currently chosen.
##
## Autoloaded, so the title screen, the character select and the player all read
## the same answer without passing it between scenes.

signal changed(index: int)

const STATES: Array[Dictionary] = [
	{"id": "01_Wood_JadeDragon",         "element": "WOOD",      "name": "JADE DRAGON"},
	{"id": "02_Fire_VermilionPhoenix",   "element": "FIRE",      "name": "VERMILION PHOENIX"},
	{"id": "03_Earth_GoldenQilin",       "element": "EARTH",     "name": "GOLDEN QILIN"},
	{"id": "04_Metal_WhiteTiger",        "element": "METAL",     "name": "WHITE TIGER"},
	{"id": "05_Water_BlackTortoise",     "element": "WATER",     "name": "BLACK TORTOISE"},
	{"id": "06_Lightning_ThunderDragon", "element": "LIGHTNING", "name": "THUNDER DRAGON"},
	{"id": "07_Ice_MoonFrost",           "element": "ICE",       "name": "MOON FROST"},
	{"id": "08_Darkness_Eclipse",        "element": "DARKNESS",  "name": "ECLIPSE"},
	{"id": "09_Light_SolarYang",         "element": "LIGHT",     "name": "SOLAR YANG"},
	{"id": "10_Wind_AzureGale",          "element": "WIND",      "name": "AZURE GALE"},
	{"id": "11_Poison_JadeSerpent",      "element": "POISON",    "name": "JADE SERPENT"},
	{"id": "12_Spirit_CelestialQi",      "element": "SPIRIT",    "name": "CELESTIAL QI"},
]

const SPRITES := "res://assets/sprites/characters/KatanaKitsune/power_states"
const COVERS := "res://assets/sprites/ui/title_power_states"
## Used when a state has no cover of its own — Fire currently has none.
const DEFAULT_COVER := "res://assets/sprites/ui/title_cover.png"

## Shadow -> highlight ramp per state, matching tools/generate_kitsune_power_palettes.py.
##
## These used to be baked into a recoloured copy of every sheet. At the old
## 480px frame size that was 1.9 GB of texture per state; at the current 768px
## it would be 9.9 GB per state, on top of the 9.9 GB the base sprites already
## cost. So the recolour moved to shaders/powerState.gdshader, which does the
## same arithmetic per fragment and costs two colours.
const RAMPS := {
	"01_Wood_JadeDragon":         [Color8(4, 38, 23),   Color8(48, 196, 105)],
	"02_Fire_VermilionPhoenix":   [Color8(72, 4, 1),    Color8(242, 58, 20)],
	"03_Earth_GoldenQilin":       [Color8(65, 34, 4),   Color8(218, 154, 31)],
	"04_Metal_WhiteTiger":        [Color8(42, 48, 60),  Color8(224, 234, 240)],
	"05_Water_BlackTortoise":     [Color8(3, 18, 58),   Color8(29, 116, 226)],
	"06_Lightning_ThunderDragon": [Color8(34, 13, 78),  Color8(177, 91, 255)],
	"07_Ice_MoonFrost":           [Color8(16, 61, 88),  Color8(158, 237, 255)],
	"08_Darkness_Eclipse":        [Color8(12, 5, 21),   Color8(91, 34, 118)],
	"09_Light_SolarYang":         [Color8(93, 61, 18),  Color8(255, 239, 159)],
	"10_Wind_AzureGale":          [Color8(0, 56, 61),   Color8(70, 224, 203)],
	"11_Poison_JadeSerpent":      [Color8(31, 52, 5),   Color8(159, 219, 34)],
	"12_Spirit_CelestialQi":      [Color8(70, 17, 63),  Color8(245, 99, 207)],
}

## Vermilion Phoenix, the red one. Index 1, not 0 — the order here follows the
## elemental cycle the art was generated in, which starts on Wood.
var chosen: int = 1

## Each player instance gets its own ShaderMaterial, so two characters on
## screen can wear different schemes.
var _materials: Dictionary = {}


func count() -> int:
	return STATES.size()


func info(index: int = -1) -> Dictionary:
	return STATES[_clamp(index)]


func select(index: int) -> void:
	var i := _clamp(index)
	if i == chosen:
		return
	chosen = i
	changed.emit(i)


func icon_path(index: int = -1) -> String:
	return "%s/%s/HUDicon.png" % [SPRITES, STATES[_clamp(index)]["id"]]


## The title art for a state, falling back to the stock cover when that state
## has none rather than leaving the screen blank.
func cover_path(index: int = -1) -> String:
	var path := "%s/%s/titleCover_1677x938.png" % [COVERS, STATES[_clamp(index)]["id"]]
	return path if ResourceLoader.exists(path) else DEFAULT_COVER


## Repaints an AnimatedSprite2D in the chosen scheme.
##
## The clothing is painted in pure red, with the red value carrying the shading
## ramp, so a fragment shader can map it onto any two-colour ramp without
## touching hair or skin. Sheets, regions, timings and animation names are all
## left alone — only two shader parameters change, which makes switching
## instant and free of load hitches.
##
## One caveat against the old baked sheets: the offline script also excluded a
## detected face box, which a shader cannot reproduce. About 0.13% of character
## pixels — dark red shade near the face — now recolour where they previously
## did not.
func apply_to(sprite: AnimatedSprite2D, index: int = -1) -> void:
	var i := _clamp(index)
	var mat: ShaderMaterial = _material_for(sprite)
	if mat == null:
		push_warning("PowerState: %s has no powerState ShaderMaterial" % sprite.name)
		return
	var ramp: Array = RAMPS.get(STATES[i]["id"], [])
	if ramp.is_empty():
		push_warning("PowerState: no ramp for %s" % STATES[i]["id"])
		return
	## Raw sRGB components, matching the 8-bit arithmetic in the shader.
	mat.set_shader_parameter("shadow_color", Vector3(ramp[0].r, ramp[0].g, ramp[0].b))
	mat.set_shader_parameter("highlight_color", Vector3(ramp[1].r, ramp[1].g, ramp[1].b))
	mat.set_shader_parameter("enabled", true)


## The scene's material is shared between instances, so each sprite gets its
## own copy the first time it is repainted.
func _material_for(sprite: AnimatedSprite2D) -> ShaderMaterial:
	var id := sprite.get_instance_id()
	if _materials.has(id) and is_instance_valid(sprite):
		return _materials[id]
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return null
	mat = mat.duplicate() as ShaderMaterial
	sprite.material = mat
	_materials[id] = mat
	return mat


func _clamp(index: int) -> int:
	return clampi(index if index >= 0 else chosen, 0, STATES.size() - 1)
