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

## The original art the player scene ships with, and the folder names it uses.
## Those predate this session's clip renames, so seven of them differ from the
## names the power-state folders now carry.
const BASE_SPRITES := "res://assets/sprites/characters/KatanaKitsune/sprites"
const FOLDER_ALIAS := {
	"IdleStanding": "idle", "Walking": "walk", "SneakWalk": "stealthWalk",
	"StealthToCrouch": "stealthCrouch", "Sitting": "sittingChair",
	"RuningJump": "runningJump", "SwitchDirectionIdle": "switchDirections",
}

## Vermilion Phoenix, the red one. Index 1, not 0 — the order here follows the
## elemental cycle the art was generated in, which starts on Wood.
var chosen: int = 1

## Textures are shared between many frames, so loading each one once turns
## ~2000 lookups into ~256 loads.
var _texture_cache: Dictionary = {}


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
## Every frame is an AtlasTexture carving a region out of a per-direction sheet,
## so only the sheet behind it has to change — the regions, timings and
## animation names are all left alone. The SpriteFrames is duplicated first
## because the resource is shared with every other instance of the scene.
func apply_to(sprite: AnimatedSprite2D, index: int = -1) -> void:
	var i := _clamp(index)
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null:
		return
	frames = frames.duplicate(true)
	var swapped := 0
	for anim in frames.get_animation_names():
		for f in frames.get_frame_count(anim):
			var tex: Texture2D = frames.get_frame_texture(anim, f)
			if not (tex is AtlasTexture):
				continue
			var atlas: AtlasTexture = tex
			if atlas.atlas == null:
				continue
			var repainted := _recolour(atlas.atlas.resource_path, i)
			if repainted != null:
				atlas.atlas = repainted
				swapped += 1
	sprite.sprite_frames = frames
	if swapped == 0:
		push_warning("PowerState: nothing repainted for %s" % STATES[i]["id"])


## Maps a sheet in the stock art onto the same sheet in a power state.
func _recolour(base_path: String, index: int) -> Texture2D:
	if not base_path.begins_with(BASE_SPRITES):
		return null
	## .../sprites/<Folder>/KatanaKitsume_<Folder>_dirN.png
	var parts := base_path.substr(BASE_SPRITES.length() + 1).split("/")
	if parts.size() < 2:
		return null
	var folder: String = parts[0]
	var clip: String = FOLDER_ALIAS.get(folder, folder.substr(0, 1).to_lower() + folder.substr(1))
	var dir := parts[1].get_basename().split("_")[-1]
	var path := "%s/%s/sprites/%s/katanaKitsune_%s_%s.png" % [
			SPRITES, STATES[index]["id"], clip, clip, dir]
	if _texture_cache.has(path):
		return _texture_cache[path]
	var loaded: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_texture_cache[path] = loaded
	return loaded


func _clamp(index: int) -> int:
	return clampi(index if index >= 0 else chosen, 0, STATES.size() - 1)
