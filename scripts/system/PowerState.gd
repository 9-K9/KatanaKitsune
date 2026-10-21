extends Node

## The twelve elemental colour schemes, and the one currently chosen -
## plus hair and skin tone, the other two bands shaders/powerState.gdshader
## can now recolour independently of clothing.
##
## Autoloaded, so the title screen, the character select and the player all read
## the same answer without passing it between scenes.

signal changed(index: int)
signal hair_changed(index: int)
signal skin_changed(index: int)

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

const SPRITES := "res://assets/sprites/characters/Kitsune/power_states"
## Title/pause/select cover per aspect: Kitsune with her hair and skirt in that
## aspect's colours, built by tools/build_kitsune_title_covers.py.
const COVERS := "res://assets/sprites/ui/title_covers_kitsune"
## Used when a state has no cover of its own.
const DEFAULT_COVER := "res://assets/sprites/ui/title_cover_kitsune.png"

## The previous heroine's art, shown instead while the Karmageisha cheat has
## her in play (CheatManager.karmageisha_active). Her cover set is one short
## (Fire), which the neutral cover stands in for.
const GOD_SPRITES := "res://assets/sprites/characters/KatanaKitsune/power_states"
const GOD_COVERS := "res://assets/sprites/ui/title_power_states"
const GOD_DEFAULT_COVER := "res://assets/sprites/ui/title_cover.png"

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

## Hair shadow -> highlight ramps. Index 0 is "natural" and matches the
## shader's own defaults exactly, so selecting it is indistinguishable from
## recolor_hair being off.
const HAIR_TONES: Array[Dictionary] = [
	{"name": "RAVEN BLACK",  "ramp": [Color8(0, 0, 0),       Color8(168, 168, 168)]},
	{"name": "CHESTNUT",     "ramp": [Color8(36, 16, 10),    Color8(168, 112, 78)]},
	{"name": "ASH BROWN",    "ramp": [Color8(28, 24, 22),    Color8(150, 134, 120)]},
	{"name": "CRIMSON",      "ramp": [Color8(40, 4, 6),      Color8(198, 48, 58)]},
	{"name": "SILVER",       "ramp": [Color8(60, 64, 70),    Color8(230, 235, 240)]},
	{"name": "SNOW WHITE",   "ramp": [Color8(90, 90, 96),    Color8(250, 250, 252)]},
	{"name": "OCEAN BLUE",   "ramp": [Color8(6, 10, 40),     Color8(70, 130, 220)]},
	{"name": "EMERALD",      "ramp": [Color8(4, 32, 16),     Color8(68, 196, 110)]},
]

## Skin shadow -> highlight ramps. Index 0 matches the painted ramp exactly
## (same values as the shader's own defaults), so it is the "no change" option.
const SKIN_TONES: Array[Dictionary] = [
	{"name": "NATURAL",   "ramp": [Color8(108, 64, 48),  Color8(238, 170, 142)]},
	{"name": "PORCELAIN", "ramp": [Color8(150, 104, 90), Color8(252, 224, 206)]},
	{"name": "IVORY",     "ramp": [Color8(132, 86, 68),  Color8(246, 202, 176)]},
	{"name": "TAWNY",     "ramp": [Color8(96, 56, 38),   Color8(214, 150, 110)]},
	{"name": "BRONZE",    "ramp": [Color8(70, 38, 24),   Color8(176, 110, 72)]},
	{"name": "UMBER",     "ramp": [Color8(46, 24, 16),   Color8(132, 78, 54)]},
	{"name": "DEEP EBONY","ramp": [Color8(30, 16, 12),   Color8(96, 56, 42)]},
]

## Clothing hue bands per monster scene, read by apply_to_enemy. Each band is
## (centre°, half-width°, min saturation, min value), measured from the Idle
## sheets so the band covers the cloth and stops short of hair and skin that
## carry a faint tint of the same hue: ninaNinja's navy hair, jorogumo's
## violet-shaded face, oni's red skin (only its loincloth is listed).
const ENEMY_CLOTHING := {
	"jorogumo":      [Vector4(258, 25, 0.40, 0.22)],
	"karasuShinobi": [Vector4(205, 25, 0.40, 0.20)],
	"kasha":         [Vector4(350, 25, 0.45, 0.08)],
	"ninaNinja":     [Vector4(215, 22, 0.60, 0.35)],
	"oni":           [Vector4(45, 25, 0.35, 0.08)],
	"tengu":         [Vector4(0, 25, 0.45, 0.08)],
	"yokailord":     [Vector4(220, 25, 0.50, 0.18), Vector4(38, 18, 0.35, 0.30)],
	"yukiOnna":      [Vector4(205, 25, 0.25, 0.50)],
}

## Vermilion Phoenix, the red one. Index 1, not 0 — the order here follows the
## elemental cycle the art was generated in, which starts on Wood.
var chosen: int = 1

## Natural black hair / natural skin, both index 0 — matches the shader's
## own hair/skin defaults, so a player who never opens that picker sees no
## change from before these two bands existed.
var chosen_hair: int = 0
var chosen_skin: int = 0

## Each player instance gets its own ShaderMaterial, so two characters on
## screen can wear different schemes.
var _materials: Dictionary = {}


func count() -> int:
	return STATES.size()


func hair_count() -> int:
	return HAIR_TONES.size()


func skin_count() -> int:
	return SKIN_TONES.size()


func hair_info(index: int = -1) -> Dictionary:
	return HAIR_TONES[_clamp_hair(index)]


func skin_info(index: int = -1) -> Dictionary:
	return SKIN_TONES[_clamp_skin(index)]


func select_hair(index: int) -> void:
	var i := _clamp_hair(index)
	if i == chosen_hair:
		return
	chosen_hair = i
	hair_changed.emit(i)


func select_skin(index: int) -> void:
	var i := _clamp_skin(index)
	if i == chosen_skin:
		return
	chosen_skin = i
	skin_changed.emit(i)


func info(index: int = -1) -> Dictionary:
	return STATES[_clamp(index)]


func select(index: int) -> void:
	var i := _clamp(index)
	if i == chosen:
		return
	chosen = i
	changed.emit(i)


func icon_path(index: int = -1) -> String:
	var root: String = GOD_SPRITES if CheatManager.karmageisha_active else SPRITES
	return "%s/%s/HUDicon.png" % [root, STATES[_clamp(index)]["id"]]


## The title art for a state, falling back to the neutral cover when that
## state has none rather than leaving the screen blank.
func cover_path(index: int = -1) -> String:
	var id: String = STATES[_clamp(index)]["id"]
	if CheatManager.karmageisha_active:
		var god := "%s/%s/titleCover_768x432.png" % [GOD_COVERS, id]
		return god if ResourceLoader.exists(god) else GOD_DEFAULT_COVER
	var path := "%s/%s.png" % [COVERS, id]
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
##
## hair/skin are independent of the clothing scheme and of each other: pass -1
## for either (the default) to use whatever is currently chosen, or pass a
## specific index — e.g. for a monster instance that should keep its own fixed
## variety choice rather than following the player's picker. recolor_hair /
## recolor_skin are left enabled whenever this is called, since index 0 in
## each ramp list already matches the shader's natural/no-change defaults.
## A material that sets the shader's `hair_skin_passes` uniform false
## (Kitsune.tscn: her paint does not fit those keys) ignores both.
func apply_to(sprite: AnimatedSprite2D, index: int = -1, hair: int = -1, skin: int = -1) -> void:
	var i := _clamp(index)
	var mat: ShaderMaterial = _material_for(sprite)
	if mat == null:
		if not OS.has_feature("dedicated_server"):
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
	_apply_hair_skin(mat, hair, skin)


## Monster cosmetic variety: clothing only. Hair and skin are left exactly as
## painted, so a monster's face and fur stay recognisable; the clothing bands
## listed in ENEMY_CLOTHING are hue-rotated by `hue_shift` degrees instead.
## Monsters are not colour-keyed like Katana Kitsune's pure-red clothing, so
## the player's elemental ramps (`enabled`) are never used here.
##
## A species missing from ENEMY_CLOTHING (kappa: its only colour is its skin)
## keeps its painted look.
func apply_to_enemy(sprite: AnimatedSprite2D, monster: String, hue_shift: float) -> void:
	var bands: Array = ENEMY_CLOTHING.get(monster, [])
	if bands.is_empty():
		return
	var mat: ShaderMaterial = _material_for(sprite)
	if mat == null:
		if not OS.has_feature("dedicated_server"):
			push_warning("PowerState: %s has no powerState ShaderMaterial" % sprite.name)
		return
	mat.set_shader_parameter("recolor_hair", false)
	mat.set_shader_parameter("recolor_skin", false)
	mat.set_shader_parameter("clothing_band_a", bands[0])
	mat.set_shader_parameter("clothing_band_b", bands[1] if bands.size() > 1 else Vector4.ZERO)
	mat.set_shader_parameter("clothing_hue_shift", hue_shift)
	mat.set_shader_parameter("recolor_clothing_hue", true)


func _apply_hair_skin(mat: ShaderMaterial, hair: int, skin: int) -> void:
	var hi := _clamp_hair(hair)
	var hair_ramp: Array = HAIR_TONES[hi]["ramp"]
	mat.set_shader_parameter("hair_shadow_color", Vector3(hair_ramp[0].r, hair_ramp[0].g, hair_ramp[0].b))
	mat.set_shader_parameter("hair_highlight_color", Vector3(hair_ramp[1].r, hair_ramp[1].g, hair_ramp[1].b))
	mat.set_shader_parameter("recolor_hair", true)

	var si := _clamp_skin(skin)
	var skin_ramp: Array = SKIN_TONES[si]["ramp"]
	mat.set_shader_parameter("skin_shadow_color", Vector3(skin_ramp[0].r, skin_ramp[0].g, skin_ramp[0].b))
	mat.set_shader_parameter("skin_highlight_color", Vector3(skin_ramp[1].r, skin_ramp[1].g, skin_ramp[1].b))
	mat.set_shader_parameter("recolor_skin", true)


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


func _clamp_hair(index: int) -> int:
	return clampi(index if index >= 0 else chosen_hair, 0, HAIR_TONES.size() - 1)


func _clamp_skin(index: int) -> int:
	return clampi(index if index >= 0 else chosen_skin, 0, SKIN_TONES.size() - 1)
