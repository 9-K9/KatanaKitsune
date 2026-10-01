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
@export var table_seat_gap: float = 150.0

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
## Set to roughly her own body radius, because that is the actual question being
## asked: is there room to stand at this chair. Measured on a floor, only one
## chair in eight was literally buried, but four were tucked against geometry;
## the rejection count is flat between 50 and 70 and climbs again past 90, where
## it starts throwing away chairs that merely sit near a wall.
@export var chair_clearance: float = 70.0
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
	for child in get_children():
		## The players, the gloom and the HUD layers outlive a floor.
		if child in keep or child is CanvasLayer or child is CanvasModulate:
			continue
		child.queue_free()
	## Dropped any that died and were freed, so the next floor spawns a fresh
	## body for their slot rather than counting a dangling reference.
	_players = []
	for body in keep:
		_players.append(body)
	_rooms.clear()
	_build()


func _build() -> void:
	_rng.seed = maze_seed
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


## A table with two or three chairs turned in towards it.
func _place_dining_set(room: Node2D) -> void:
	var ground := room.get_node_or_null("TileMap/Ground") as TileMapLayer
	if ground == null:
		return
	var cells := ground.get_used_cells()
	if cells.is_empty():
		return
	## Set out in open floor rather than on any tile at all. A table dropped
	## against a wall puts half its seats inside the stone, and the clearance
	## cull then removes them — six tables were keeping eight chairs between
	## them. Checked against the tilemap, not the physics world, because this
	## runs during _ready where the physics server is still empty.
	var floor_cells := {}
	for cell in cells:
		floor_cells[cell] = true
	var open_cells: Array[Vector2i] = []
	for cell in cells:
		var clear := true
		## Two cells, not one: the seats stand 96px out, which is two tiles across
		## the lattice, so a single ring of floor still let half of them land in
		## the wall and be culled.
		for dx in [-2, -1, 0, 1, 2]:
			for dy in [-2, -1, 0, 1, 2]:
				if not floor_cells.has(cell + Vector2i(dx, dy)):
					clear = false
					break
			if not clear:
				break
		if clear:
			open_cells.append(cell)
	var pick: Vector2i = (open_cells if not open_cells.is_empty() else cells)[
			_rng.randi_range(0, (open_cells.size() if not open_cells.is_empty() else cells.size()) - 1)]
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
		(chair as Node2D).global_position = centre + seat["offset"] * table_seat_gap


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
		probe.collision_mask = 1
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
