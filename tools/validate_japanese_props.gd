extends SceneTree

const PROP_NAMES: PackedStringArray = [
	"ceramic_jar_southEast",
	"ceramic_jar_southWest",
	"ceramic_jar_northWest",
	"ceramic_jar_northEast",
	"folding_screen_southEast",
	"folding_screen_southWest",
	"folding_screen_northWest",
	"folding_screen_northEast",
	"katana_rack_southEast",
	"katana_rack_southWest",
	"katana_rack_northWest",
	"katana_rack_northEast",
	"low_table_southEast",
	"low_table_southWest",
	"low_table_northWest",
	"low_table_northEast",
	"offering_box_southEast",
	"offering_box_southWest",
	"offering_box_northWest",
	"offering_box_northEast",
	"sake_barrel_southEast",
	"sake_barrel_southWest",
	"sake_barrel_northWest",
	"sake_barrel_northEast",
	"stone_lantern_southEast",
	"stone_lantern_southWest",
	"stone_lantern_northWest",
	"stone_lantern_northEast",
	"storage_chest_southEast",
	"storage_chest_southWest",
	"storage_chest_northWest",
	"storage_chest_northEast",
	"tea_set_southEast",
	"tea_set_southWest",
	"tea_set_northWest",
	"tea_set_northEast",
	"zabuton_stack_southEast",
	"zabuton_stack_southWest",
	"zabuton_stack_northWest",
	"zabuton_stack_northEast",
]


func _init() -> void:
	var failed := false
	for prop_name: String in PROP_NAMES:
		var path := "res://scenes/props/japanese/%s.tscn" % prop_name
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("Failed to load %s" % path)
			failed = true
			continue
		var prop := packed.instantiate() as StaticBody2D
		if prop == null or not prop.is_in_group("breakable"):
			push_error("%s is not a breakable StaticBody2D" % path)
			failed = true
		elif prop.break_texture == null or prop.break_frames != 1 or not prop.persist_broken:
			push_error("%s has invalid broken-state settings" % path)
			failed = true
		else:
			print("OK: %s" % path)
		if prop != null:
			prop.free()

	var chair_scene := load("res://scenes/props/chair.tscn") as PackedScene
	var chair := chair_scene.instantiate() if chair_scene != null else null
	if chair == null or not chair.has_method("get_sit_position") or not chair.has_method("get_sit_facing"):
		push_error("Chair scene is missing its sit anchor API")
		failed = true
	else:
		get_root().add_child(chair)
		print("OK: chair anchor %s, facing %s" % [chair.get_sit_position(), chair.get_sit_facing()])
		chair.queue_free()

	quit(1 if failed else 0)
