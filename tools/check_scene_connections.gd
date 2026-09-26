extends SceneTree

## Catches signal connections that have gone stale.
##
## A .tscn wires signals with [connection] entries keyed by full node path:
##
##   [connection signal="pressed" from="UI/VBox/NewGame" to="." method="_on_new_game_pressed"]
##
## Reparent, rename or re-wrap that button and the path stops resolving.
## Godot does not error, warn or log — it silently drops the connection. The
## scene renders perfectly, the button still highlights on hover, and clicking
## it does nothing. It reads as a game-logic bug rather than a wiring one, so
## it costs real time to track down.
##
## Run after any change to a scene's node tree:
##
##   godot --headless --script res://tools/check_scene_connections.gd
##
## Optionally limit it to some scenes:
##
##   godot --headless --script res://tools/check_scene_connections.gd -- scenes/title_screen.tscn
##
## Exits non-zero if anything is broken, so it works as a pre-commit gate.

const SCAN_ROOT := "res://scenes"

var _problems: int = 0
var _scenes_checked: int = 0
var _connections_checked: int = 0


func _initialize() -> void:
	var targets: PackedStringArray = _targets()
	if targets.is_empty():
		print("No .tscn files found under ", SCAN_ROOT)
		quit(0)
		return

	for path in targets:
		_check_scene(path)

	print("")
	print("scenes: %d   connections: %d   problems: %d" % [
		_scenes_checked, _connections_checked, _problems])
	if _problems > 0:
		print("FAIL — see above. A stale connection is silent at runtime.")
	else:
		print("OK — every connection resolves.")
	quit(1 if _problems > 0 else 0)


## Scene list: whatever was passed after `--`, else everything under SCAN_ROOT.
func _targets() -> PackedStringArray:
	var out: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		var path: String = arg
		if not path.begins_with("res://"):
			path = "res://" + path.trim_prefix("./")
		out.append(path)
	if not out.is_empty():
		return out
	_collect(SCAN_ROOT, out)
	out.sort()
	return out


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect(full, out)
		elif entry.ends_with(".tscn"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _check_scene(scene_path: String) -> void:
	var text := FileAccess.get_file_as_string(scene_path)
	if text.is_empty():
		return
	_scenes_checked += 1

	## Rebuild the node paths the way Godot addresses them: the root is ".",
	## its children are bare names, and everything deeper is parent/name.
	var known: Dictionary = {".": true}
	var root_name: String = ""
	for line in text.split("\n"):
		if not line.begins_with("[node "):
			continue
		var node_name: String = _attr(line, "name")
		var parent: String = _attr(line, "parent")
		if node_name.is_empty():
			continue
		if parent.is_empty():
			root_name = node_name
			continue
		known[node_name if parent == "." else parent + "/" + node_name] = true

	var script_methods: Dictionary = _methods_of(text)

	for line in text.split("\n"):
		if not line.begins_with("[connection "):
			continue
		_connections_checked += 1
		var from: String = _attr(line, "from")
		var to: String = _attr(line, "to")
		var method: String = _attr(line, "method")
		var signal_name: String = _attr(line, "signal")

		if not known.has(from):
			_fail(scene_path, "signal '%s' comes from '%s', which is not a node in this scene" % [
				signal_name, from])
		if not known.has(to):
			_fail(scene_path, "signal '%s' targets '%s', which is not a node in this scene" % [
				signal_name, to])
		## Only meaningful when the handler is on the root's own script; a
		## connection to another node's script is not resolvable from here.
		elif to == "." and not script_methods.is_empty() and not script_methods.has(method):
			_fail(scene_path, "signal '%s' from '%s' calls %s(), which its script does not define" % [
				signal_name, from, method])

	_check_buttons_live(scene_path, root_name)


## Instancing catches anything the text scan cannot see — an inherited scene
## whose base moved a node, for instance. Scenes that need a particular parent
## to instance are skipped rather than reported as broken.
func _check_buttons_live(scene_path: String, _root_name: String) -> void:
	var packed: PackedScene = load(scene_path)
	if packed == null or not packed.can_instantiate():
		return
	var inst: Node = packed.instantiate()
	if inst == null:
		return
	root.add_child(inst)

	for node in _descendants(inst):
		if not (node is Button):
			continue
		var button := node as Button
		## A CheckButton or CheckBox reports through `toggled`, not `pressed`,
		## and is perfectly well wired without one. Any of these counts.
		var wired: bool = false
		for signal_name in ["pressed", "toggled", "button_up", "button_down"]:
			if _has_live_connection(button, signal_name):
				wired = true
				break
		if not wired:
			_fail(scene_path, "button '%s' has no live handler on pressed/toggled — it will look fine and do nothing" % [
				inst.get_path_to(button)])

	inst.queue_free()
	root.remove_child(inst)


func _has_live_connection(node: Node, signal_name: String) -> bool:
	if not node.has_signal(signal_name):
		return false
	for c in node.get_signal_connection_list(signal_name):
		var callable: Callable = c["callable"]
		if callable.is_valid() and is_instance_valid(callable.get_object()):
			return true
	return false


func _descendants(from: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [from]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


## The root's script, if it is a plain res:// path we can read.
func _methods_of(scene_text: String) -> Dictionary:
	var out: Dictionary = {}
	for line in scene_text.split("\n"):
		if not (line.begins_with("[ext_resource ") and line.find("type=\"Script\"") != -1):
			continue
		var path: String = _attr(line, "path")
		if path.is_empty() or not path.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string(path)
		for src_line in src.split("\n"):
			var trimmed: String = src_line.strip_edges()
			if not trimmed.begins_with("func "):
				continue
			var name_part: String = trimmed.substr(5).split("(")[0].strip_edges()
			out[name_part] = true
	return out


## Reads name="value" out of a .tscn header line.
func _attr(line: String, key: String) -> String:
	var needle: String = key + "=\""
	var at: int = line.find(needle)
	if at == -1:
		return ""
	var start: int = at + needle.length()
	var end: int = line.find("\"", start)
	if end == -1:
		return ""
	return line.substr(start, end - start)


func _fail(scene_path: String, message: String) -> void:
	_problems += 1
	print("BROKEN  ", scene_path)
	print("        ", message)
