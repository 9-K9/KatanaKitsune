class_name WorldObjects
extends RefCounted

const SCENE_DIR := "res://scenes/props/world_objects/"
const FACINGS: PackedStringArray = [
	"southEast", "south", "southWest", "west",
	"northWest", "north", "northEast", "east",
]

static var _catalog: Dictionary = {}
static var _scenes: Dictionary = {}


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://resources/world_objects.json"))
		assert(parsed is Dictionary, "Invalid world-object catalog")
		_catalog = parsed
	return _catalog


static func direction_from_roll(group_roll: float, index: int, natural: bool) -> int:
	if natural:
		return posmod(index, 8) + 1
	return posmod(index, 4) * 2 + (1 if group_roll < 0.8 else 2)


static func scene(family: String, direction: int = 1) -> PackedScene:
	var path := "%s%s/%s_dir%d.tscn" % [SCENE_DIR, family, family, direction]
	if not _scenes.has(path):
		var packed := load(path) as PackedScene
		assert(packed != null, "Missing world object: " + path)
		_scenes[path] = packed
	return _scenes[path]


static func family_of(packed: PackedScene) -> String:
	if packed == null or not packed.resource_path.begins_with(SCENE_DIR):
		return ""
	return packed.resource_path.get_base_dir().get_file()


static func choose(packed: PackedScene, rng: RandomNumberGenerator,
		fixed_direction: int = 0) -> PackedScene:
	var family := family_of(packed)
	if family.is_empty():
		return packed
	if fixed_direction > 0:
		return scene(family, fixed_direction)
	var natural: bool = catalog()["natural"].has(family)
	var direction := direction_from_roll(rng.randf(), rng.randi(), natural)
	return scene(family, direction)


static func loot(packed: PackedScene) -> PackedScene:
	var family := family_of(packed)
	if family.is_empty():
		return packed
	if family == "health_potion" and randf() < 0.5:
		family = "health_charm"
	var direction := direction_from_roll(randf(), randi(), false)
	return scene(family, direction)
