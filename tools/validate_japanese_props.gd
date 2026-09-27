extends SceneTree

const PROP_NAMES: PackedStringArray = [
	"ceramic_jar",
	"folding_screen",
	"katana_rack",
	"low_table",
	"offering_box",
	"sake_barrel",
	"stone_lantern",
	"storage_chest",
	"tea_set",
	"zabuton_stack",
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
