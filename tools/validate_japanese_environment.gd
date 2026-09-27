extends SceneTree

const EXPECTED_COUNTS := {
	"res://assets/pixellab/japanese_environment/tilesets/japanese_ground_tileset.tres": 32,
	"res://assets/pixellab/japanese_environment/tilesets/japanese_raised_terrain_tileset.tres": 16,
	"res://assets/pixellab/japanese_environment/tilesets/japanese_building_tileset.tres": 58,
}

func _init() -> void:
	var failed := false
	for path: String in EXPECTED_COUNTS:
		var tile_set := load(path) as TileSet
		if tile_set == null:
			push_error("Failed to load TileSet: %s" % path)
			failed = true
			continue
		var expected: int = EXPECTED_COUNTS[path]
		var actual := tile_set.get_source_count()
		if actual != expected:
			push_error("%s has %d sources; expected %d" % [path, actual, expected])
			failed = true
		else:
			print("OK: %s (%d sources, grid %s)" % [path, actual, tile_set.tile_size])
	quit(1 if failed else 0)
