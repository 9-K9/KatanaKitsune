extends SceneTree


func _init() -> void:
	var failed := false
	var checked := 0
	for family in ["ceramic_jar", "folding_screen", "katana_rack", "low_table",
			"offering_box", "sake_barrel", "stone_lantern_japanese", "storage_chest",
			"tea_set", "zabuton_stack", "tansu_chest", "armour_stand", "taiko_drum",
			"rice_bales", "supply_crates", "butsudan_shrine"]:
		for direction in range(1, 9):
			var prop := WorldObjects.scene(family, direction).instantiate() as Breakable
			if prop == null or prop.break_texture == null or prop.break_frames != 1 \
					or not prop.persist_broken:
				push_error("Invalid replacement prop/state: %s dir%d" % [family, direction])
				failed = true
			checked += 1
			if prop != null:
				prop.free()
	var chair := WorldObjects.scene("chair").instantiate() as Chair
	if chair == null or not chair.has_method("get_sit_position") \
			or not chair.has_method("get_sit_facing"):
		push_error("Chair missing sit anchor API")
		failed = true
	if chair != null:
		chair.free()
	print("Japanese props: %d directional scenes, %s" % [checked, "FAILED" if failed else "OK"])
	quit(1 if failed else 0)
