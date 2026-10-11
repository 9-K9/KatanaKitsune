class_name LevelTheme
extends Resource

enum Id { SAKURA_GARDENS, BAMBOO_WOODLAND, ABANDONED_SHRINES }

@export var id: Id = Id.SAKURA_GARDENS
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_file("*.png") var icon_path: String = ""
@export var walls: Array[String] = []
@export var trees: Array[String] = []
@export var edge_trees: Array[String] = []
@export var small_props: Array[String] = ["garden_rocks"]
@export var weather: Array[int] = [ExteriorBiome.Weather.CALM, ExteriorBiome.Weather.RAIN]
@export var outdoor_animals: Array[String] = []
@export var indoor_animals: Array[String] = []
@export var pond_animals: Array[String] = ["frog", "turtle"]
@export var tree_density: float = 1.0
@export var grass_density: float = 1.0
@export var animal_density: float = 1.0
@export_range(0.0, 1.0) var road_earth_chance: float = 0.0
@export_range(0.0, 1.0) var road_weed_chance: float = 0.0
@export_range(0.0, 1.0) var courtyard_earth_chance: float = 0.0
@export_range(0.0, 1.0) var ornament_chance: float = 0.45
@export var moonlight := Color(0.55, 0.66, 0.95)


static func definition(which: int) -> LevelTheme:
	var names := ["sakura_gardens", "bamboo_woodland", "abandoned_shrines"]
	return load("res://resources/level_themes/%s.tres" %
			names[clampi(which, 0, names.size() - 1)]) as LevelTheme


func exterior_biome() -> ExteriorBiome:
	var result := ExteriorBiome.definition(ExteriorBiome.Id.SAKURA).duplicate() as ExteriorBiome
	result.trees = trees.duplicate()
	result.edge_trees = edge_trees.duplicate()
	result.compatible_weather = weather.duplicate()
	result.moonlight = moonlight
	return result
