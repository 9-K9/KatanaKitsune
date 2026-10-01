extends Node2D

## Walkable demo: tiles room_A across the diamond lattice, knocks walls out to
## make a maze, and drops the player in with a camera that follows.
##
## Rooms sit on the isometric lattice, each neighbour half a room across and
## half a room down, so their diamonds interlock exactly — see
## _lattice_position. Openings are knocked through from both sides, which turns
## a run of rooms into one continuous space rather than a corridor.

@export var room_scene: PackedScene = null
@export var player_scene: PackedScene = null
@export var enemy_scenes: Array[PackedScene] = []
@export var prop_scenes: Array[PackedScene] = []
@export var exit_scene: PackedScene = null
## Stood at the ends of every opening and spaced across it, so a knocked-out
## wall reads as a deliberate colonnade instead of a severed run of stone.
@export var pillar_scene: PackedScene = null
## One is always placed beside the spawn. Resting only happens at a chair, so
## leaving it to the random prop pool meant a floor could offer nowhere to rest.
@export var chair_scene: PackedScene = null
## A low table with chairs drawn up to it. Scattering furniture at random makes
## a storeroom; a table with seats around it makes a room somebody used.
@export var table_scene: PackedScene = null
## How often a room gets one.
@export_range(0.0, 1.0, 0.05) var table_chance: float = 0.45
## How far the chairs sit from the table, along the floor axes. Wider than it
## was: the table renders 202px across, so seats at 96 stood on the tabletop.
## Just outside the tabletop, not a stride away. At 150 the seats sat about
## three tiles out — past the two tiles of clear floor the table's own placement
## guarantees — so most of them landed on no floor at all and were skipped.
@export var table_seat_gap: float = 110.0

## How many floors share a look before it changes.
@export var floors_per_theme: int = 1
## Start deeper than floor one. For testing a themed floor without walking down
## to it — the generator is identical, only the starting depth differs.
@export var start_depth: int = 1

## Every look a floor can wear, one per wall set the project ships.
##
## Each is a wall texture prefix, the floor layer to show, and the ground
## texture prefix. All sixty-four wall sets live in the same folder as eight
## directional PNGs on an identical 240x384 canvas with identical content
## bounds — they were rendered from one camera rig — so a theme is a string
## swap, not new geometry, collision or prefabs.
##
## The pairing is by name: anything reading as a Japanese or Chinese building
## gets the tatami layer, the open-air sets get grass, and the rest keep the
## checkered stone.
const THEMES: Array[Dictionary] = [
	{"wall": "aluminiumMetalicWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "apartmentWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "arcadeGameWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "bathroomWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "blackAsylumnWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "casinoWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "casinoWall2", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "cementBurntWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "cementWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "cementWall2", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "chainMetalWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "chainPrisonWall", "floor": "", "ground": "grassTile"},
	{"wall": "chinaTownWall", "floor": "Floor_JP_Indoor", "ground": "checkeredFloorIsometric"},
	{"wall": "chineseWall", "floor": "Floor_JP_Indoor", "ground": "checkeredFloorIsometric"},
	{"wall": "chineseWall2", "floor": "Floor_JP_Indoor", "ground": "checkeredFloorIsometric"},
	{"wall": "computerScreenWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "devilsWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "glassWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "greenMetalicWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "greenWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "greenWall2", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "japaneseWall", "floor": "Floor_JP_Indoor", "ground": "checkeredFloorIsometric"},
	{"wall": "japaneseWall2", "floor": "Floor_JP_Indoor", "ground": "checkeredFloorIsometric"},
	{"wall": "japaneseWall3", "floor": "Floor_JP_Indoor", "ground": "checkeredFloorIsometric"},
	{"wall": "metalicFenceWall", "floor": "", "ground": "grassTile"},
	{"wall": "metalicFenceWall2", "floor": "", "ground": "grassTile"},
	{"wall": "metalicGateWall", "floor": "", "ground": "grassTile"},
	{"wall": "metalicGateWall2", "floor": "", "ground": "grassTile"},
	{"wall": "metalicWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "porcelinWhiteWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "rubixGameWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "rustedMetalicWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "rusticBrickWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "rusticBrickWall2", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "rusticBrickWall3", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "rusticBrickWall4", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "rusticWoodenWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "schoolBrickWall", "floor": "", "ground": "grassTile"},
	{"wall": "scifiBlackBlueDirtWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "scifiBlackBlueWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "scifiBlackBlueWall2", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "scifiBlackWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "scifiBlackWall2", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "scifiBlackWall3", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "scifiBlackWall4", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "scifiBlackWall6", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "scifiBlackWall7", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "scifiBlueWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "scifiBlueWall2", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "scifiBlueWall3", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "scifiMetalWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "slumWall", "floor": "", "ground": "grassTile"},
	{"wall": "snakeEdgeWall", "floor": "", "ground": "grassTile"},
	{"wall": "stainedMetalicWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "supermarketWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "toiletWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "whiteAsylumnWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "whiteMarbleWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "whiteMetalicWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "whiteWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "wood&BlueWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "wood&BrickWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "woodenWall", "floor": "", "ground": "checkeredFloorIsometric"},
	{"wall": "woodenWall2", "floor": "", "ground": "checkeredFloorIsometric"},
]

## Floor spikes. Laid in short runs rather than scattered, because the trap
## carries a phase_offset for exactly that — a line of them stepping through the
## cycle rolls like a wave and can be timed, where one alone is just a tax.
@export var trap_scene: PackedScene = null
@export_range(0.0, 1.0, 0.05) var trap_chance: float = 0.35
@export var traps_per_run: Vector2i = Vector2i(3, 5)

## Extra monsters per room for each player past the first. Per *room*, so it
## multiplies by the sixteen of them — at 1.5 a four-player floor one came out
## at 92 monsters, which is a slog rather than a scaling.
@export var party_enemy_bonus: float = 0.7

## Breathing room kept around the party when the camera pulls back to hold them.
@export var party_margin: float = 320.0
## How far the view is allowed to pull back. Below this the dungeon stops being
## readable, and players are better stopped from spreading than shown as ants.
@export_range(0.3, 1.0, 0.05) var camera_zoom_min: float = 0.55

## Chairs dropped on open floor beyond the one beside the spawn.
@export var extra_chairs: int = 3
## Clear floor a chair needs around it. She walks the last steps to a seat, so
## one wedged against a column is worse than no chair at all — she sets off and
## grinds into the stone.
##
## The question being asked is whether she can reach the seat, and she is about
## 66 across. This only tests props and columns now — walls are excluded, so the
## generous figure that used to compensate for the oversized wall silhouette is
## no longer needed and was costing real chairs.
@export var chair_clearance: float = 50.0
@export var grid: Vector2i = Vector2i(4, 4)
## Roofs make the layout unreadable while testing; off by default here.
@export var show_roofs: bool = false
@export var maze_seed: int = 0
## Chance an interior wall is knocked through. Higher is more open.
@export_range(0.0, 1.0) var openness: float = 0.35

@export_group("Population")
@export var enemies_per_room: Vector2i = Vector2i(0, 2)
@export var props_per_room: Vector2i = Vector2i(1, 3)
## Columns spaced between the two that flank each opening.
@export var pillars_per_opening: int = 3
## Nudges the columns along the wall's own footprint offset. 1.0 puts them on
## the centre of the stone; higher settles them further onto the wall line.
## Scaling rather than adding keeps the sideways part flipping per side, which a
## fixed nudge would not — the walls lean opposite ways on opposite sides.
@export_range(0.5, 2.5, 0.05) var pillar_wall_bias: float = 1.35
## How far a column sorts after the wall it stands against. Measured at only 4px
## without it, which is a coin flip — some columns landed behind the stone they
## were framing. The art does not move: the node drops by this much and the
## sprite rises by the same, so only the sort position changes.
@export var pillar_sort_bias: float = 26.0

@export_group("Atmosphere")
## Near-black, so the player's lantern and the braziers do the lighting.
@export var gloom: Color = Color(0.18, 0.17, 0.26)
@export var lantern_radius: float = 2.6
@export var lantern_colour: Color = Color(1.0, 0.82, 0.55)

const SIDES: Array[String] = ["NE", "NW", "SE", "SW"]
## Which lattice step each side faces. This follows from the isometric transform
## rather than from looking at a render: +x moves right and down, which is SE,
## and +y moves left and down, which is SW.
const NEIGHBOUR := {
	"NE": Vector2i(0, -1),
	"SW": Vector2i(0, 1),
	"SE": Vector2i(1, 0),
	"NW": Vector2i(-1, 0),
}

var _rng := RandomNumberGenerator.new()
## Which look this floor drew. Rolled rather than derived from depth: keyed to
## the depth, floor one was always aluminium and floor two always apartment, the
## same order every run. The roll comes off _rng, which is seeded from
## maze_seed, so a floor is still reproducible from its seed — it just is not
## the same floor for everybody.
var _theme_index: int = -1
## Themes already used this run, so a short descent does not show the same
## walls twice before it has shown sixty-four other options.
var _themes_used: Array[int] = []
## Every player, in slot order. _player stays as player one for the HUD.
var _players: Array[Node2D] = []
var _rooms: Dictionary = {}
## How deep the run has gone. HUD reads this; each floor adds monsters.
var depth: int = 1
var _player: Node2D = null


func _ready() -> void:
	if room_scene == null:
		push_warning("MazeDemo: no room_scene set.")
		return
	## Zero means roll one. The scene used to carry maze_seed = 12345, so every
	## run of the game built the identical dungeon — same maze, same rooms, same
	## props, every launch. Set it to a fixed number again only to reproduce a
	## specific floor while debugging.
	if maze_seed == 0:
		maze_seed = randi()
	_build()


## Next floor. Rebuilds around the player rather than reloading the scene, so
## she keeps her health, her buffs and her state machine across the descent —
## a reload would construct a fresh one and throw all of that away.
func descend() -> void:
	depth += 1
	maze_seed = _rng.randi()
	## Everyone who is playing survives the descent, not just player one. This
	## used to spare `_player` alone, which with a party meant players two to
	## four were freed with the floor — and because queue_free is deferred,
	## _players still reported them as present, so _spawn_player did not replace
	## them either and the party simply vanished on the stairs.
	var keep: Array[Node] = []
	for body in _players:
		if is_instance_valid(body):
			keep.append(body)
	## The camera outlives a floor too. It is a plain Node2D child, so it used to
	## be freed with the level — and because queue_free is deferred, the rebuild
	## then found the doomed camera still in the tree, reused it, and lost it at
	## the end of the frame. The next floor had no camera at all and the view
	## stayed where the stairs had been.
	var lens := get_node_or_null("PartyCamera")
	for child in get_children():
		## The players, the camera, the gloom and the HUD layers outlive a floor.
		if child in keep or child == lens or child is CanvasLayer \
				or child is CanvasModulate:
			continue
		child.queue_free()
	## Dropped any that died and were freed, so the next floor spawns a fresh
	## body for their slot rather than counting a dangling reference.
	_players = []
	for body in keep:
		_players.append(body)
	_rooms.clear()
	_build()
	_announce_floor()


## Picks this floor's look at random, avoiding anything already seen this run.
##
## Falls back to a plain roll once every theme has been used, rather than
## refusing to pick — sixty-four floors is deeper than anyone will go, but a
## generator that can run out is a generator that will.
func _roll_theme() -> void:
	if THEMES.is_empty():
		return
	for _try in 24:
		var pick: int = _rng.randi() % THEMES.size()
		if not _themes_used.has(pick):
			_theme_index = pick
			_themes_used.append(pick)
			return
	_theme_index = _rng.randi() % THEMES.size()


## Dresses every room in this depth's theme: walls, ground and floor layer.
##
## The cells for a themed floor layer are copied from the room's own Ground
## layer rather than authored into a second prefab, so a themed floor is exactly
## the shape of the dungeon one and no room has to be drawn twice.
func _theme_floor() -> void:
	if THEMES.is_empty():
		return
	if _theme_index < 0:
		_roll_theme()
	var theme: Dictionary = THEMES[_theme_index]
	_theme_walls(theme["wall"])
	_theme_pillars(theme["wall"])

	var layer_name: String = theme["floor"]
	for cell in _rooms:
		var room: Node = _rooms[cell]
		var ground := room.get_node_or_null("TileMap/Ground") as TileMapLayer
		if ground == null:
			continue
		if ground.tile_set != null:
			_repoint(ground.tile_set, theme["ground"])
		## Every themed layer off first, so moving between themes does not leave
		## the last one showing underneath.
		for other_name in ["Floor_JP_Indoor", "Floor_JP_Exterior"]:
			var other := room.get_node_or_null("TileMap/" + other_name) as TileMapLayer
			if other != null:
				other.visible = false
				other.clear()
		ground.visible = layer_name == ""
		if layer_name == "":
			continue
		var layer := room.get_node_or_null("TileMap/" + layer_name) as TileMapLayer
		if layer == null or layer.tile_set == null:
			ground.visible = true
			continue
		## A handful of materials for the whole floor rather than a different
		## tile per cell — sixteen variants scattered at random reads as
		## confetti, not as a room somebody laid.
		var palette: Array[int] = []
		var sources: int = layer.tile_set.get_source_count()
		if sources == 0:
			ground.visible = true
			continue
		for _i in mini(3, sources):
			palette.append(layer.tile_set.get_source_id(_rng.randi() % sources))
		for at in ground.get_used_cells():
			layer.set_cell(at, palette[_rng.randi() % palette.size()], Vector2i.ZERO)
		layer.visible = true


## Candidate material names for a wall set, most specific first.
func _pillar_names(wall_prefix: String) -> Array[String]:
	var out: Array[String] = []
	var bare: String = wall_prefix
	while bare.length() > 0 and bare[bare.length() - 1].is_valid_int():
		bare = bare.substr(0, bare.length() - 1)
	for candidate in [wall_prefix, bare, wall_prefix.trim_suffix("Wall"),
			bare.trim_suffix("Wall")]:
		if candidate != "" and not out.has(candidate):
			out.append(candidate)
	## Then by dropping trailing words: scifiBlackBlueDirt has no column of its
	## own but scifiBlackBlue does, and it is the same material with grime on it.
	var trimmed: String = bare.trim_suffix("Wall")
	while trimmed.length() > 1:
		var cut: int = -1
		for i in range(trimmed.length() - 1, 0, -1):
			if trimmed[i] == trimmed[i].to_upper() and trimmed[i] != trimmed[i].to_lower():
				cut = i
				break
		if cut <= 0:
			break
		trimmed = trimmed.substr(0, cut)
		if not out.has(trimmed):
			out.append(trimmed)
	return out


## Dresses the columns in the same material as the walls.
##
## Looks for pillar_<material>.png beside the default and leaves the stone one
## in place when there is none, so this does nothing until that art exists and
## then starts working with no further change. The material name is the wall
## prefix with its trailing "Wall" removed, which is how the wall sets are named.
func _theme_pillars(wall_prefix: String) -> void:
	## Tried from most specific to least: the set's own name, then with any
	## trailing number dropped, then with "Wall" trimmed. Twenty-four of the
	## sixty-four sets are numbered variants — casinoWall2, rusticBrickWall3 —
	## and they share their base material's column rather than going bare.
	var texture: Texture2D = null
	for material in _pillar_names(wall_prefix):
		var art: String = "res://assets/sprites/props/pillars/pillar_%s.png" % material
		if ResourceLoader.exists(art):
			texture = load(art) as Texture2D
			break
	if texture == null:
		return
	for node in get_children():
		if not node.name.begins_with("Pillar"):
			continue
		var sprite := node.get_node_or_null("Sprite2D") as Sprite2D
		if sprite != null:
			sprite.texture = texture


## Repoints the wall tiles at a different set of textures.
##
## Each atlas source is asked what it is currently showing and given the same
## direction from the new set, so this does not depend on the sources being in
## any particular order — it reads dirN out of the existing path and keeps it.
func _theme_walls(prefix: String) -> void:
	if prefix == "":
		return
	var done: Dictionary = {}
	for cell in _rooms:
		var room: Node = _rooms[cell]
		for side in ["NE", "NW", "SE", "SW"]:
			var layer := room.get_node_or_null("TileMap/Walls_" + side) as TileMapLayer
			if layer == null or layer.tile_set == null:
				continue
			## All four sides share one TileSet, and scene sub-resources are
			## shared between room instances, so without this the same swap runs
			## sixty-four times a floor.
			var id: int = layer.tile_set.get_instance_id()
			if done.has(id):
				continue
			done[id] = true
			_repoint(layer.tile_set, prefix)


func _repoint(tiles: TileSet, prefix: String) -> void:
	for i in tiles.get_source_count():
		var source := tiles.get_source(tiles.get_source_id(i)) as TileSetAtlasSource
		if source == null or source.texture == null:
			continue
		var was: String = source.texture.resource_path
		var dir: String = was.get_file().get_basename().split("_dir")[-1]
		if not dir.is_valid_int():
			continue
		## Built in the texture's own folder, which is what keeps this safe on the
		## ground tileset: that one holds blocks, slopes and stairs alongside the
		## flat floor, and they live in sibling folders. Asking for
		## blocks/grassTile_dir1.png finds nothing, so only the floor swaps and
		## the geometry pieces are left as they are.
		var wanted: String = "%s/%s_dir%s.png" % [was.get_base_dir(), prefix, dir]
		## Left alone when the set has no art for a direction, so a half-finished
		## wall set degrades to the old look rather than to blank tiles.
		if wanted != was and ResourceLoader.exists(wanted):
			source.texture = load(wanted)


## Says which floor she has arrived on, briefly, in the middle of the screen.
##
## The stairs used to drop you to a new floor with no acknowledgement at all —
## the only sign was the small FLOOR counter in the corner, so walking onto them
## read as being teleported by a glitch rather than as descending.
func _announce_floor() -> void:
	var layer := get_node_or_null("FloorLayer") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "FloorLayer"
		layer.layer = 80
		add_child(layer)
		var note := Label.new()
		note.name = "Note"
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		note.set_anchors_preset(Control.PRESET_FULL_RECT)
		note.add_theme_font_size_override("font_size", 44)
		note.add_theme_color_override("font_color", Color(0.85, 0.72, 0.42))
		layer.add_child(note)
	var note := layer.get_node_or_null("Note") as Label
	if note == null:
		return
	note.text = "FLOOR %d" % depth
	note.modulate.a = 1.0
	## Holds, then fades. Long enough to read on arrival, short enough that it is
	## not in the way of the first room.
	var fade := create_tween()
	fade.tween_interval(1.4)
	fade.tween_property(note, "modulate:a", 0.0, 0.9)


func _build() -> void:
	depth = maxi(depth, start_depth)
	_rng.seed = maze_seed
	_roll_theme()
	var step := _lattice_step()
	for iy in grid.y:
		for ix in grid.x:
			var cell := Vector2i(ix, iy)
			var room = room_scene.instantiate()
			room.name = "Room_%d_%d" % [ix, iy]
			add_child(room)
			room.position = _lattice_position(cell, step)
			## Every room carries a CanvasModulate; several stacked just fight.
			var light: Node = room.get_node_or_null("Lighting")
			if light:
				light.free()
			if not show_roofs:
				var roofs: Node = room.get_node_or_null("TileMap/Roofs")
				if roofs:
					roofs.queue_free()
			_rooms[cell] = room

	_carve()
	_place_pillars()
	_spawn_player(step)
	_place_starting_chair()
	_populate(step)
	_clear_buried_chairs()
	_place_exit()
	_light()


## The stairs go in whichever room is furthest from the start, measured through
## the maze rather than across it, so the exit is a walk and not a room away.
func _place_exit() -> void:
	if exit_scene == null:
		return
	var start := Vector2i((grid.x - 1) / 2, (grid.y - 1) / 2)
	var far: Vector2i = start
	var best: int = -1
	var seen: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	while queue.size() > 0:
		var cell: Vector2i = queue.pop_front()
		if seen[cell] > best:
			best = seen[cell]
			far = cell
		var room = _rooms.get(cell)
		if room == null or not room.has_method("open_sides"):
			continue
		for side in room.open_sides():
			var next: Vector2i = cell + NEIGHBOUR[side]
			if _rooms.has(next) and not seen.has(next):
				seen[next] = seen[cell] + 1
				queue.append(next)

	var stairs = exit_scene.instantiate()
	## Lit, because an unlit prop on a dark floor is scenery. This is the one
	## thing in a room the player is actually looking for.
	var beacon := PointLight2D.new()
	beacon.name = "Beacon"
	beacon.texture = _glow()
	beacon.color = Color(0.65, 0.85, 1.0)
	beacon.energy = 1.5
	beacon.texture_scale = 0.9
	beacon.position = Vector2(0, -20)
	stairs.add_child(beacon)
	add_child(stairs)
	stairs.global_position = _room_centre(far)
	## Deferred: descend() frees the whole floor and the signal fires from
	## inside body_entered, mid-physics.
	stairs.descended.connect(descend, CONNECT_DEFERRED)


## Drops monsters and breakables into the rooms. The room the player starts in
## is left clear so she is not swung at before taking a step.
func _populate(step: Vector2) -> void:
	var start := Vector2i((grid.x - 1) / 2, (grid.y - 1) / 2)
	for cell in _rooms:
		var here: Node2D = _rooms[cell]
		if not enemy_scenes.is_empty() and cell != start:
			## Scaled by the party. A floor built for one is a walkover for four,
			## and the extra bodies also have to be worth the extra katanas.
			var party: int = maxi(Roster.count(), 1)
			var n: int = _rng.randi_range(enemies_per_room.x, enemies_per_room.y) \
					+ depth - 1 + int(round(float(party - 1) * party_enemy_bonus))
			for i in n:
				_place(here, enemy_scenes[_rng.randi_range(0, enemy_scenes.size() - 1)])
		if not prop_scenes.is_empty():
			var m: int = _rng.randi_range(props_per_room.x, props_per_room.y)
			for i in m:
				_place(here, prop_scenes[_rng.randi_range(0, prop_scenes.size() - 1)])
		if table_scene != null and _rng.randf() < table_chance:
			_place_dining_set(here)
		if trap_scene != null and cell != start and _rng.randf() < trap_chance:
			_place_trap_run(here)


## Puts one thing on a random floor tile of `room`, so nothing lands in a wall
## or out in the void.
func _place(room: Node2D, scene: PackedScene) -> void:
	if scene == null:
		return
	var ground := room.get_node_or_null("TileMap/Ground") as TileMapLayer
	if ground == null:
		return
	var cells := ground.get_used_cells()
	if cells.is_empty():
		return
	var thing = scene.instantiate()
	## Chairs also arrive through the prop pool, and want turning just the same.
	if thing.has_method("face_randomly"):
		thing.face_randomly(_rng)
	add_child(thing)
	thing.global_position = ground.to_global(
		ground.map_to_local(cells[_rng.randi_range(0, cells.size() - 1)]))


## Drops the whole floor into gloom and gives the player a lantern, so the maze
## is lit by what she carries rather than being evenly visible everywhere.
func _light() -> void:
	if not has_node("Gloom"):
		var tint := CanvasModulate.new()
		tint.name = "Gloom"
		tint.color = gloom
		add_child(tint)

	for carrier in _players:
		if not is_instance_valid(carrier) or carrier.has_node("Lantern"):
			continue
		var lamp := PointLight2D.new()
		lamp.name = "Lantern"
		lamp.texture = _glow()
		lamp.color = lantern_colour
		lamp.energy = 1.5
		lamp.texture_scale = lantern_radius
		## Sits at her torso. Her origin is now her feet, so this is measured up
		## from the ground rather than out from the middle of her.
		lamp.position = Vector2(0, -40)
		carrier.add_child(lamp)


## A soft round falloff, built rather than shipped as an asset.
func _glow() -> GradientTexture2D:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = ramp
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


func _player_body() -> Node2D:
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D:
			return node
	return null


## Carves the maze. A randomised depth-first spanning tree first, so every room
## is reachable from every other, then extra walls knocked through on top to add
## loops and open the place up.
##
## Purely random walls left rooms sealed off with no way in, which read as a
## maze that was simply too tight.
func _carve() -> void:
	var walls: Dictionary = {}          ## Vector2i cell -> {side: closed}
	for cell in _rooms:
		walls[cell] = {}
		for side in SIDES:
			walls[cell][side] = true

	## Spanning tree.
	var visited: Dictionary = {Vector2i.ZERO: true}
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	while stack.size() > 0:
		var cell: Vector2i = stack[-1]
		var options: Array[String] = []
		for side in SIDES:
			var other: Vector2i = cell + NEIGHBOUR[side]
			if _rooms.has(other) and not visited.has(other):
				options.append(side)
		if options.is_empty():
			stack.pop_back()
			continue
		var side: String = options[_rng.randi_range(0, options.size() - 1)]
		var next: Vector2i = cell + NEIGHBOUR[side]
		_open_pair(walls, cell, side)
		visited[next] = true
		stack.append(next)

	## Extra openings for loops, so it is not a pure tree with one route.
	for cell in _rooms:
		for side in SIDES:
			if not _rooms.has(cell + NEIGHBOUR[side]):
				continue
			if _rng.randf() < openness:
				_open_pair(walls, cell, side)

	for cell in _rooms:
		var room = _rooms[cell]
		if not room.has_method("set_side"):
			continue
		for side in SIDES:
			room.set_side(side, walls[cell][side])


## Opens a wall from both sides. A shared wall is two layers, one in each room,
## and leaving the other closed blocks the passage from one direction only.
func _open_pair(walls: Dictionary, cell: Vector2i, side: String) -> void:
	var other: Vector2i = cell + NEIGHBOUR[side]
	if not walls.has(other):
		return
	walls[cell][side] = false
	for back in SIDES:
		if other + NEIGHBOUR[back] == cell:
			walls[other][back] = false


## Chairs to rest at: one beside the spawn, and a few more out on open floor so
## resting is something you can plan a route around rather than stumble onto.
## They go at room centres, which is the one spot guaranteed clear of the walls.
func _place_starting_chair() -> void:
	if chair_scene == null or _player == null:
		return
	## Beside the spawn, off to one side so she does not begin standing on it.
	_add_chair(_player.global_position + Vector2(150.0, 75.0), "StartingChair")

	## And in a scattering of other rooms, skipping the one she starts in.
	var start := Vector2i((grid.x - 1) / 2, (grid.y - 1) / 2)
	var elsewhere: Array[Vector2i] = []
	for cell in _rooms:
		if cell != start:
			elsewhere.append(cell)
	elsewhere.shuffle()
	for i in mini(extra_chairs, elsewhere.size()):
		_add_chair(_room_centre(elsewhere[i]), "Chair_%d_%d" % [elsewhere[i].x, elsewhere[i].y])


## The four floor axes as screen vectors, and the facing that looks back along
## each. Built from the lattice step: +ix lands at (+24,+12) on screen, which is
## southEast, so a chair standing there faces northWest to see the table.
const SEATS := [
	{"offset": Vector2( 1.0,  0.5), "faces": "northWest"},
	{"offset": Vector2(-1.0,  0.5), "faces": "northEast"},
	{"offset": Vector2(-1.0, -0.5), "faces": "southEast"},
	{"offset": Vector2( 1.0, -0.5), "faces": "southWest"},
]


## A line of floor spikes stepping through the cycle.
##
## Never in the starting room: the first thing a new player meets should not be
## something that damages them before they have moved.
func _place_trap_run(room: Node2D) -> void:
	var ground := room.get_node_or_null("TileMap/Ground") as TileMapLayer
	if ground == null:
		return
	var cells := ground.get_used_cells()
	if cells.is_empty():
		return
	var floor_cells := {}
	for cell in cells:
		floor_cells[cell] = true

	## Along one of the two tile axes, so the run reads as a deliberate line in
	## the architecture rather than a diagonal scatter.
	var axis: Vector2i = [Vector2i(1, 0), Vector2i(0, 1)][_rng.randi() % 2]
	var wanted: int = _rng.randi_range(traps_per_run.x, traps_per_run.y)

	## A start cell with enough floor ahead of it to hold the whole run.
	var from: Vector2i = Vector2i.ZERO
	var found := false
	for _try in 20:
		var candidate: Vector2i = cells[_rng.randi_range(0, cells.size() - 1)]
		var fits := true
		for i in wanted:
			if not floor_cells.has(candidate + axis * i):
				fits = false
				break
		if fits:
			from = candidate
			found = true
			break
	if not found:
		return

	for i in wanted:
		var trap = trap_scene.instantiate()
		add_child(trap)
		(trap as Node2D).global_position = ground.to_global(
				ground.map_to_local(from + axis * i))
		## Spread evenly around the cycle so the run ripples instead of firing
		## as one slab, which would be a wall rather than a rhythm.
		if "phase_offset" in trap:
			trap.phase_offset = trap.period * float(i) / float(wanted)


## A table with two or three chairs turned in towards it.
func _place_dining_set(room: Node2D) -> void:
	var ground := room.get_node_or_null("TileMap/Ground") as TileMapLayer
	if ground == null:
		return
	var cells := ground.get_used_cells()
	if cells.is_empty():
		return
	## Placed where its own seats will actually fit, rather than merely on open
	## floor. The table is wide enough that its chairs sit three or four tiles
	## out, so a generic "two clear rings" test said yes in places where half the
	## seats still landed in stone — tables were coming out with one chair.
	## Scoring candidates by how many of their four seats are over floor asks the
	## question that matters directly. Checked against the tilemap, not physics,
	## because this runs during _ready where the physics server is still empty.
	var floor_cells := {}
	for cell in cells:
		floor_cells[cell] = true

	var pick: Vector2i = cells[_rng.randi_range(0, cells.size() - 1)]
	var best: int = -1
	## A sample rather than every tile: rooms have hundreds of cells and four
	## seat tests each would be thousands of lookups per table.
	for _try in 24:
		var candidate: Vector2i = cells[_rng.randi_range(0, cells.size() - 1)]
		var origin: Vector2 = ground.map_to_local(candidate)
		var fits: int = 0
		for seat in SEATS:
			var at: Vector2 = origin + seat["offset"] * table_seat_gap
			if floor_cells.has(ground.local_to_map(at)):
				fits += 1
		if fits > best:
			best = fits
			pick = candidate
		if fits == SEATS.size():
			break
	var centre: Vector2 = ground.to_global(ground.map_to_local(pick))

	var table := table_scene.instantiate()
	table.name = "DiningTable"
	## Turned like every other prop. The dining set builds its table by hand
	## rather than going through _place, so it missed the facing pass and every
	## table on every floor faced the same way.
	if table.has_method("face_randomly"):
		table.face_randomly(_rng)
	add_child(table)
	(table as Node2D).global_position = centre

	if chair_scene == null:
		return
	## A random subset of the four sides, so no two sets look alike and the
	## table is never boxed in on every side.
	var sides: Array = SEATS.duplicate()
	for i in range(sides.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap = sides[i]
		sides[i] = sides[j]
		sides[j] = swap
	for i in _rng.randi_range(2, 3):
		var seat: Dictionary = sides[i]
		var where: Vector2 = centre + seat["offset"] * table_seat_gap
		## Belt and braces: the table was chosen for seats that fit, but if the
		## room could not offer a perfect spot one or two may still be in stone.
		if not floor_cells.has(ground.local_to_map(ground.to_local(where))):
			continue
		var chair := chair_scene.instantiate()
		chair.name = "DiningChair%d" % i
		if "facing" in chair:
			chair.facing = seat["faces"]
		## Its own table is the one thing it is *supposed* to be pressed up
		## against. The clearance cull would otherwise throw away every chair it
		## just seated: the chairs stand 96px out and the probe reaches 70, which
		## bites into a table half as wide again as that gap.
		chair.set_meta("dining_table", table)
		add_child(chair)
		(chair as Node2D).global_position = where


func _add_chair(where: Vector2, named: String) -> void:
	var chair := chair_scene.instantiate()
	chair.name = named
	## Turned before it is added, so the setter has run by the time _ready picks
	## the art. Without this every chair on the floor faces the same way, which
	## reads as a waiting room rather than a ruin.
	if chair.has_method("face_randomly"):
		chair.face_randomly(_rng)
	add_child(chair)
	(chair as Node2D).global_position = where


## Throws away any chair standing inside something solid.
##
## The prop pool drops chairs on any floor cell, including ones a column is
## already standing on. A buried chair still counts as somewhere to rest, so she
## would walk into a column and sit on a chair nobody can see — which is exactly
## what a chair under a column looked like.
func _clear_buried_chairs() -> void:
	## One physics frame late, and that is the whole reason this works. Walls,
	## columns and props are all added during _ready, and the physics server does
	## not know about a body's shapes until the next step — so querying here
	## immediately returned "nothing is there" for every chair, whatever it was
	## standing on.
	await get_tree().physics_frame
	var space := get_world_2d().direct_space_state
	var removed := 0
	for chair in get_tree().get_nodes_in_group("chair"):
		if not (chair is Node2D):
			continue
		## A shape rather than a point. Testing the exact centre only caught a
		## chair standing *inside* something; one tucked against a column passed,
		## and she would walk into the stone trying to reach it.
		var probe := PhysicsShapeQueryParameters2D.new()
		var clearance := CircleShape2D.new()
		clearance.radius = chair_clearance
		probe.shape = clearance
		## Its own base, not its origin, which sits SORT_LIFT above the floor.
		probe.transform = Transform2D(0.0,
				(chair as Node2D).global_position + Vector2(0.0, SORT_LIFT))
		## Layer 2 only: props and columns, not walls. Props sit on layer 3, which
		## is bits 1 and 2; the walls are bit 1 alone. Probing bit 1 therefore hit
		## the walls too, and the wall collision is a deliberately oversized
		## silhouette, so chairs were being rejected from well across the room
		## from any stone — seventeen a floor. She can stand beside a wall
		## perfectly well; what she cannot do is stand inside a column.
		probe.collision_mask = 2
		## Everything except the table it was deliberately drawn up to. It is
		## still tested against walls, columns and every other prop.
		var table = chair.get_meta("dining_table", null)
		if is_instance_valid(table) and table is CollisionObject2D:
			probe.exclude = [table.get_rid()]
		if not space.intersect_shape(probe, 1).is_empty():
			chair.queue_free()
			removed += 1
	if removed > 0:
		print("MazeDemo: removed %d chair(s) without clear floor around them" % removed)


## The world position of the middle of a room's floor.
func _room_centre(cell: Vector2i) -> Vector2:
	var room := _rooms.get(cell) as Node2D
	if room == null:
		return Vector2.ZERO
	var ground := room.get_node_or_null("TileMap/Ground") as TileMapLayer
	if ground == null:
		return room.global_position
	var used := ground.get_used_rect()
	return ground.to_global(ground.map_to_local(used.position + used.size / 2))


func _spawn_player(step: Vector2) -> void:
	if player_scene == null:
		return
	var wanted: int = maxi(Roster.count(), 1)
	var centre: Vector2 = _room_centre(Vector2i((grid.x - 1) / 2, (grid.y - 1) / 2))

	## Spawned once and carried down; later floors only move them.
	while _players.size() < wanted:
		var body = player_scene.instantiate()
		## Set before add_child so _ready picks the right device and colour —
		## afterwards would be too late, the character would already have bound
		## itself to the keyboard and repainted in somebody else's aspect.
		body.slot = _players.size()
		add_child(body)
		_players.append(body)
		## Only when there is a party to tell apart. One player needs no label
		## saying which one they are.
		if wanted > 1:
			var mark := Node2D.new()
			mark.name = "SlotMarker"
			mark.set_script(load("res://scripts/system/SlotMarker.gd"))
			body.add_child(mark)
			mark.setup(body.slot, Roster.colour_of(body.slot))
	## Kept for everything that still wants "the player" — the HUD, the radar
	## and the eye all speak for player one.
	_player = _players[0] if not _players.is_empty() else null

	for i in _players.size():
		if not is_instance_valid(_players[i]):
			continue
		## Fanned out around the middle of the room rather than stacked on one
		## point, or four bodies would spawn inside each other and shove apart.
		var angle: float = TAU * float(i) / float(maxi(_players.size(), 1))
		var ring := Vector2(cos(angle), sin(angle) * 0.5) * (0.0 if _players.size() == 1 else 90.0)
		(_players[i] as Node2D).global_position = centre + ring

	_theme_floor()
	_fit_camera()
	if not Roster.device_lost.is_connected(_on_device_lost):
		Roster.device_lost.connect(_on_device_lost)
		Roster.device_regained.connect(_on_device_regained)


func _physics_process(delta: float) -> void:
	_track_party(delta)


## Halts the floor while anyone's pad is unplugged, and says whose.
##
## The slot is held rather than freed: a cable pulled out by a foot should not
## cost that player their run. Any spare pad plugged in adopts the waiting slot,
## so a replacement controller rescues them without a trip to a menu.
func _on_device_lost(slot: int) -> void:
	get_tree().paused = true
	_show_reconnect("PLAYER %d — RECONNECT CONTROLLER" % (slot + 1))


func _on_device_regained(_slot: int) -> void:
	if Roster.any_lost():
		return
	get_tree().paused = false
	_show_reconnect("")


func _show_reconnect(text: String) -> void:
	var layer := get_node_or_null("ReconnectLayer") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "ReconnectLayer"
		## Runs while the tree is paused, or the notice could never appear —
		## the thing it announces is the reason everything else stopped.
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		layer.layer = 90
		add_child(layer)
		var note := Label.new()
		note.name = "Note"
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		note.set_anchors_preset(Control.PRESET_FULL_RECT)
		note.add_theme_font_size_override("font_size", 28)
		note.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
		layer.add_child(note)
	var note := layer.get_node_or_null("Note") as Label
	if note != null:
		note.text = text
		note.visible = text != ""


## One camera for the table, framing every living player.
##
## Shared rather than split: the HUD, radar, gloom and every lantern are single
## CanvasLayer things, and four viewports would mean four of each. The cost is
## that players cannot wander into separate rooms — the camera pulls back as
## they spread and stops them drifting off the edge of the world.
func _fit_camera() -> void:
	var cam := get_node_or_null("PartyCamera") as Camera2D
	if cam == null:
		cam = Camera2D.new()
		cam.name = "PartyCamera"
		add_child(cam)
		cam.position_smoothing_enabled = true
		cam.position_smoothing_speed = 6.0
		cam.make_current()
	## Any camera the player scene ships with would fight this one for the view.
	for body in _players:
		if is_instance_valid(body):
			var own := (body as Node).get_node_or_null("FollowCamera") as Camera2D
			if own != null:
				own.enabled = false


## Keeps the shared camera on the middle of the party and pulled back far enough
## to hold everyone. Runs in physics because that is when bodies move; sampling
## in _process reads a stale position on frames with no physics tick and the
## view jitters.
func _track_party(_delta: float) -> void:
	var cam := get_node_or_null("PartyCamera") as Camera2D
	if cam == null:
		return
	var alive: Array[Node2D] = []
	for body in _players:
		if is_instance_valid(body) and not (body.get("is_dead") == true):
			alive.append(body)
	if alive.is_empty():
		return

	var box := Rect2(alive[0].global_position, Vector2.ZERO)
	for body in alive:
		box = box.expand(body.global_position)
	cam.global_position = box.get_center()

	## Zoom out only once the party is wider than the view, and never past the
	## limit — a dungeon read at half size stops being readable.
	var view: Vector2 = get_viewport_rect().size
	var needed: Vector2 = (box.size + Vector2(party_margin, party_margin)) / view
	var out: float = maxf(maxf(needed.x, needed.y), 1.0)
	var target: float = clampf(1.0 / out, camera_zoom_min, 1.0)
	cam.zoom = cam.zoom.lerp(Vector2(target, target), clampf(_delta * 4.0, 0.0, 1.0))


## One whole room along each isometric axis, in pixels.
## Stands a pillar at each end of every opening, and spaces more across it.
##
## Knocking a wall out leaves the runs either side of it stopping in mid-air,
## showing their cut faces. Framing the gap with columns reads as architecture
## that was always meant to have an opening there, rather than a wall someone
## removed — and it costs a prop instead of a new tile set and door logic.
##
## The opening's own wall layer is disabled but still holds its tiles, so it
## describes exactly where the gap is; no geometry has to be inferred.
## Closest two columns may stand. Each footprint is 44 across and she is 66, so
## this leaves at least 106 of clear floor to walk through.
const MIN_GAP: float = 150.0
## How far a character's node origin sits above their feet. Props have to match
## it or the two sort against each other by different rules.
const SORT_LIFT: float = 100.0


## Where a wall tile's stone actually stands, relative to the cell it occupies.
##
## These tiles span five cells by sixteen and carry a texture origin, so the
## cell position lands near the top of the sprite rather than at its base —
## columns placed there stood about 56px off the wall line. The collision
## polygon is the honest footprint, and its centre differs per side because the
## walls lean, so this is read from the tile rather than typed in as a constant.
func _wall_footprint(layer: TileMapLayer, cell: Vector2i) -> Vector2:
	var ts: TileSet = layer.tile_set
	if ts == null:
		return Vector2.ZERO
	var src := ts.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
	if src == null:
		return Vector2.ZERO
	var data: TileData = src.get_tile_data(layer.get_cell_atlas_coords(cell),
			layer.get_cell_alternative_tile(cell))
	if data == null or data.get_collision_polygons_count(0) == 0:
		return Vector2.ZERO
	var points: PackedVector2Array = data.get_collision_polygon_points(0, 0)
	if points.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / float(points.size())


func _place_pillars() -> void:
	if pillar_scene == null:
		return
	## Both rooms either side of an opening describe the same gap, so each would
	## otherwise stand its own column there. Spacing is enforced by distance and
	## not by snapping to a grid: a grid still lets two columns land a few pixels
	## apart, and anything tighter than MIN_GAP is a doorway she cannot fit
	## through — her collision diamond is 66 across and a column's is 44.
	var placed: Array[Vector2] = []
	for cell in _rooms:
		var room: Node2D = _rooms[cell]
		if not room.has_method("open_sides"):
			continue
		for side in room.open_sides():
			var layer := room.get_node_or_null("TileMap/Walls_" + side) as TileMapLayer
			if layer == null:
				continue
			var cells: Array[Vector2i] = layer.get_used_cells()
			if cells.is_empty():
				continue
			## Along the gap, so "first" and "last" are its two ends.
			cells.sort_custom(func(a, b): return a.x + a.y < b.x + b.y)
			var wanted: Array[int] = [0, cells.size() - 1]
			var stride: int = maxi(int(cells.size() / float(pillars_per_opening + 1)), 1)
			for i in range(stride, cells.size() - 1, stride):
				wanted.append(i)
			for i in wanted:
				var world: Vector2 = layer.to_global(layer.map_to_local(cells[i])
						+ _wall_footprint(layer, cells[i]) * pillar_wall_bias)
				## The column's origin sits SORT_LIFT above its base so it sorts
				## on the same footing as the characters, whose origins sit that
				## far above their feet. Placing it that much higher leaves the
				## stone itself exactly where it was.
				world.y -= SORT_LIFT
				var crowded := false
				for other in placed:
					if other.distance_to(world) < MIN_GAP:
						crowded = true
						break
				if crowded:
					continue
				placed.append(world)
				var pillar := pillar_scene.instantiate()
				pillar.name = "Pillar_%d_%d_%s_%d" % [cell.x, cell.y, side, i]
				## Its own occlusion check, so a player walking up the screen
				## behind a column does not simply vanish.
				var fade := Node.new()
				fade.name = "Fade"
				fade.set_script(load("res://scripts/system/PillarFade.gd"))
				pillar.add_child(fade)
				add_child(pillar)
				(pillar as Node2D).global_position = world + Vector2(0.0, pillar_sort_bias)
				## Sprite back up by the same amount, so the stone stays where it
				## was and only the sort position has changed.
				var art := pillar.get_node_or_null("Sprite2D") as Node2D
				if art != null:
					art.position.y -= pillar_sort_bias


## Where a grid cell sits on screen.
##
## The isometric lattice, not a grid of half-steps. A room's footprint is a
## diamond, and diamonds only interlock when each neighbour sits half a width
## across AND half a height down — moving in one axis alone slides a room
## halfway over its neighbour, which is what used to happen here.
##
## In tile terms this is exactly one room per step: +ix advances the room's own
## cell block by its width, +iy by its height, so floors abut with no seam and
## no shared cells. That also derives NEIGHBOUR rather than leaving it read off
## a render — +ix goes right and down (SE), +iy goes left and down (SW), and
## their negatives are NW and NE.
func _lattice_position(cell: Vector2i, step: Vector2) -> Vector2:
	return Vector2(
		float(cell.x - cell.y) * step.x * 0.5,
		float(cell.x + cell.y) * step.y * 0.5)


func _lattice_step() -> Vector2:
	var probe = room_scene.instantiate()
	var ground := probe.get_node_or_null("TileMap/Ground") as TileMapLayer
	var step := Vector2.ZERO
	if ground != null:
		var umin := 1 << 30
		var umax := -(1 << 30)
		var vmin := 1 << 30
		var vmax := -(1 << 30)
		for c in ground.get_used_cells():
			umin = mini(umin, c.x - c.y)
			umax = maxi(umax, c.x - c.y)
			vmin = mini(vmin, c.x + c.y)
			vmax = maxi(vmax, c.x + c.y)
		## The diamond's full screen width and height: the span between the
		## outermost tile centres, plus the one whole tile hanging off each end.
		## This used to add a single tile rather than two, so every room was
		## measured one tile short and the lattice pulled itself inwards.
		step = Vector2(
			float(umax - umin + 2) * ground.tile_set.tile_size.x * 0.5,
			float(vmax - vmin + 2) * ground.tile_set.tile_size.y * 0.5)
	probe.free()
	return step
