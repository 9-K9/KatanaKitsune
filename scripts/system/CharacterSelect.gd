extends Control

## Pick a colour scheme. The preview on the left cycles her animations in the
## highlighted scheme so it can be judged in motion rather than from a portrait.
##
## Purely cosmetic for now: the choice repaints her and the title art, and
## carries no stats.

## Clips worth showing off, in an order that reads as a short performance.
const SHOWCASE: Array[String] = [
	"idle", "katanaDraw", "katanaSlashMid", "katanaCounterSlash",
	"forwardRoll", "fastRun", "flair", "katanaIdle",
]
const SECONDS_PER_CLIP: float = 1.6
const DIRECTION := "southEast"

## The preview is a Node2D, so it sits in a plain Control rather than a
## container — containers do not lay out Node2D children, which left it pinned
## tiny in the corner.
@onready var preview: AnimatedSprite2D = $PreviewHolder/Preview
@onready var icons: GridContainer = $Right/Icons
@onready var scheme_name: Label = $Right/SchemeName
@onready var element: Label = $Right/Element
@onready var clip_label: Label = $PreviewHolder/ClipName
@onready var cover: TextureRect = $Cover

var _highlighted: int = 0
var _clip: int = 0
var _elapsed: float = 0.0
var _base_frames: SpriteFrames = null

## How many are playing, who is choosing right now, and on what.
##
## The screen runs as three phases rather than one. Godot's focus system is
## device-blind — it answers to every pad at once — so once players are picking
## in turn the highlight is driven by hand from the active player's own device
## and focus is left out of it entirely.
enum Phase { COUNT, CLAIM, COLOUR }

var _phase: int = Phase.COUNT
var _wanted: int = 1
var _active: int = 0
## One probe per unclaimed device, watched during CLAIM so whichever pad presses
## first takes the slot. Rebuilt whenever the roster changes.
var _probes: Array[PlayerInput] = []
## The device driving the highlight during COLOUR.
var _driver: PlayerInput = null
## Repeat throttle for stick navigation — an analogue stick held over is a level,
## not an edge, and without this one nudge runs the whole row.
var _repeat: float = 0.0
const REPEAT_DELAY: float = 0.18
## Kept alive between frames, and that matters: a PlayerInput works out a press
## by comparing against what it saw last frame, so rebuilding these every frame
## would make every held button look freshly pressed and one nudge would run the
## whole list. Rebuilt only when a pad is plugged in or out.
var _menu_probes: Array[PlayerInput] = []


func _ready() -> void:
	## Borrow the player's own SpriteFrames so the preview cannot drift from
	## what the game actually plays.
	var player: Node = load("res://scenes/characters/KatanaKitsune.tscn").instantiate()
	var sprite: AnimatedSprite2D = player.get_node("AnimationManager/AnimatedSprite2D")
	_base_frames = sprite.sprite_frames
	player.queue_free()

	_build_icons()
	_link_focus()
	_highlighted = PowerState.chosen
	_show(_highlighted)
	## Deferred: grabbing focus before the containers have laid out does not
	## stick, which is why the screen opened with nothing selected.
	## Two frames, not one: the first lays the containers out, and a grab before
	## that silently does nothing — which is why the screen opened on a button.
	await get_tree().process_frame
	await get_tree().process_frame
	## A fresh roster every time the screen opens, or backing out to the title
	## and coming back would stack yesterday's players on top of today's.
	Roster.clear()
	Input.joy_connection_changed.connect(_on_menu_joy_changed)
	_rebuild_menu_probes()
	_enter_count()


## A pad plugged in at the menu joins the probes immediately, so a player can
## pick up a controller and claim a slot without backing out and returning.
func _on_menu_joy_changed(_device: int, _connected: bool) -> void:
	_rebuild_menu_probes()
	if _phase == Phase.CLAIM:
		_enter_claim()


func _build_icons() -> void:
	for i in PowerState.count():
		var button := TextureButton.new()
		button.texture_normal = load(PowerState.icon_path(i))
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = Vector2(124, 124)
		## Reachable with a pad. Icons are built here rather than in the scene,
		## so nothing in the editor would have set this.
		button.focus_mode = Control.FOCUS_ALL
		button.tooltip_text = "%s — %s" % [PowerState.info(i)["element"], PowerState.info(i)["name"]]
		button.pressed.connect(_on_icon_pressed.bind(i))
		## Moving onto an icon previews it. Focus and selection were separate,
		## so a pad could walk the grid with nothing changing but a thin
		## outline — no name, no preview, no telling where you were.
		button.focus_entered.connect(_show.bind(i))
		icons.add_child(button)


## Wires the grid by hand. Godot works focus neighbours out geometrically, and
## it was not finding the icons from the buttons at all — navigation just cycled
## BACK and BEGIN. Stating them removes the guesswork.
func _link_focus() -> void:
	var count: int = icons.get_child_count()
	var columns: int = icons.columns
	var begin := get_node_or_null("Right/Buttons/Confirm") as Control
	var back := get_node_or_null("Right/Buttons/Back") as Control
	for i in count:
		var icon: Control = icons.get_child(i)
		var column: int = i % columns
		if column > 0:
			icon.focus_neighbor_left = icon.get_path_to(icons.get_child(i - 1))
		if column < columns - 1 and i + 1 < count:
			icon.focus_neighbor_right = icon.get_path_to(icons.get_child(i + 1))
		if i - columns >= 0:
			icon.focus_neighbor_top = icon.get_path_to(icons.get_child(i - columns))
		if i + columns < count:
			icon.focus_neighbor_bottom = icon.get_path_to(icons.get_child(i + columns))
		elif begin != null:
			## Bottom row drops onto BEGIN, so the screen reads downward.
			icon.focus_neighbor_bottom = icon.get_path_to(begin)
	## And back up from the buttons into the last row.
	if count > 0:
		var last_row_start: int = count - (count % columns if count % columns > 0 else columns)
		for button in [begin, back]:
			if button != null:
				button.focus_neighbor_top = button.get_path_to(icons.get_child(last_row_start))


## Confirming an icon moves on to BEGIN, so the pad walks the screen in the
## order the screen is read: pick an aspect, then commit to it.
func _on_icon_pressed(index: int) -> void:
	_show(index)
	var begin := get_node_or_null("Right/Buttons/Confirm") as Control
	if begin != null:
		begin.grab_focus()


## Back to the icons. Cancel is the pad's right-hand face button — B on an Xbox
## pad, Circle on a DualShock, A on a Switch controller.
func _unhandled_input(event: InputEvent) -> void:
	## Cancel belongs to the party flow now, which routes it to the right player
	## rather than to whichever device happened to press. Left in place only so
	## nothing else claims the event.
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()


func _focus_icons() -> void:
	if _highlighted < icons.get_child_count():
		(icons.get_child(_highlighted) as Control).grab_focus()


## Repaints the preview and the backdrop in one scheme.
func _show(index: int) -> void:
	_highlighted = index
	var data: Dictionary = PowerState.info(index)
	scheme_name.text = data["name"]
	element.text = "◆  %s  ◆" % data["element"]
	cover.texture = load(PowerState.cover_path(index))

	preview.sprite_frames = _base_frames
	PowerState.apply_to(preview, index)
	_clip = 0
	_elapsed = 0.0
	_play_current()

	## Dim every icon but the highlighted one, so the selection is unmistakable.
	for i in icons.get_child_count():
		var button: TextureButton = icons.get_child(i)
		## Three states, not two: the one being previewed is full brightness, the
		## rest are dimmed, and the focused one is brighter still so it stands
		## out against the preview when a pad is driving.
		if i == index:
			button.modulate = Color.WHITE
		else:
			button.modulate = Color(0.45, 0.42, 0.45)
		if button.has_focus():
			button.modulate = Color(1.35, 1.3, 1.1)


func _play_current() -> void:
	var clip: String = SHOWCASE[_clip % SHOWCASE.size()]
	var anim := "%s_%s" % [clip, DIRECTION]
	if preview.sprite_frames != null and preview.sprite_frames.has_animation(anim):
		preview.play(anim)
		clip_label.text = clip
	else:
		clip_label.text = ""


func _process(delta: float) -> void:
	_drive(delta)
	_elapsed += delta
	if _elapsed >= SECONDS_PER_CLIP:
		_elapsed = 0.0
		_clip += 1
		_play_current()


func _on_confirm_pressed() -> void:
	## The on-screen button belongs to whoever is choosing now.
	_take_colour()


func _on_back_pressed() -> void:
	_go_back()


## Runs the current phase off real devices. Everything here reads a specific
## device rather than the global Input, which is the whole point: during COLOUR
## only the player whose turn it is may move the highlight.
func _drive(delta: float) -> void:
	_repeat = maxf(_repeat - delta, 0.0)
	match _phase:
		Phase.COUNT:
			_drive_count()
		Phase.CLAIM:
			_drive_claim()
		Phase.COLOUR:
			_drive_colour()


## Before anyone has claimed anything, so any device may set the number.
func _drive_count() -> void:
	var step: int = 0
	for probe in _all_devices():
		if probe.just_pressed("Right") or probe.just_pressed("Down"):
			step = 1
		elif probe.just_pressed("Left") or probe.just_pressed("Up"):
			step = -1
		if probe.confirm_pressed():
			_active = 0
			_enter_claim()
			return
		if probe.cancel_pressed():
			_go_back()
			return
	if step != 0:
		_wanted = clampi(_wanted + step, 1, Roster.MAX_PLAYERS)
		_banner("HOW MANY PLAYERS?   %s" % _count_bar())


## Whichever free device presses first takes this slot.
func _drive_claim() -> void:
	for probe in _probes:
		if probe.cancel_pressed():
			_go_back()
			return
	for probe in _probes:
		if not probe.confirm_pressed():
			continue
		if Roster.join(probe.device) < 0:
			continue
		_enter_colour()
		return


## Only the active player's device moves the highlight.
func _drive_colour() -> void:
	if _driver == null:
		return
	if _driver.cancel_pressed():
		_go_back()
		return
	if _driver.confirm_pressed():
		_take_colour()
		return
	if _repeat > 0.0:
		return
	var across: int = icons.columns if icons.columns > 0 else 6
	var step: int = 0
	if _driver.pressed("Right"):
		step = 1
	elif _driver.pressed("Left"):
		step = -1
	elif _driver.pressed("Down"):
		step = across
	elif _driver.pressed("Up"):
		step = -across
	if step == 0:
		return
	_repeat = REPEAT_DELAY
	var total: int = PowerState.count()
	## Steps over schemes an earlier player already wears, so held navigation
	## never parks on a choice that cannot be confirmed.
	var next: int = _highlighted
	for _i in total:
		next = wrapi(next + step, 0, total)
		if not Roster.scheme_taken(next, _active):
			break
	_highlighted = next
	_show(_highlighted)


## Keyboard plus every connected pad, for the phases open to all comers.
func _all_devices() -> Array[PlayerInput]:
	if _menu_probes.is_empty():
		_rebuild_menu_probes()
	return _menu_probes


func _rebuild_menu_probes() -> void:
	_menu_probes = [PlayerInput.new(PlayerInput.KEYBOARD)]
	for id in Input.get_connected_joypads():
		_menu_probes.append(PlayerInput.new(id))


## ---------------------------------------------------------------- party flow

func _enter_count() -> void:
	_phase = Phase.COUNT
	_wanted = maxi(_wanted, 1)
	_banner("HOW MANY PLAYERS?   %s" % _count_bar())


func _enter_claim() -> void:
	_phase = Phase.CLAIM
	_probes.clear()
	for id in Roster.free_devices():
		var probe := PlayerInput.new(id)
		## Same reason: a button still held from the previous phase must not
		## instantly claim the next slot.
		probe.prime()
		_probes.append(probe)
	if _probes.is_empty():
		## Nothing left to claim with — more players were asked for than there
		## are devices, so settle for the ones already in.
		_start_game()
		return
	_banner("PLAYER %d — PRESS A BUTTON" % (_active + 1))


func _enter_colour() -> void:
	_phase = Phase.COLOUR
	_driver = Roster.input_for(_active)
	## The button that claimed this pad is very likely still held. Priming makes
	## it count as already-down, so the colour screen waits for a fresh press
	## instead of confirming the first scheme and skipping the choice entirely.
	_driver.prime()
	## Opens on a scheme nobody has taken, so the first thing shown is a legal
	## choice rather than one that silently refuses to confirm.
	_highlighted = _first_free_scheme()
	_show(_highlighted)
	_banner("PLAYER %d — %s" % [_active + 1, _driver.device_name()])


## Every scheme not already worn by an earlier player.
func _first_free_scheme() -> int:
	for i in PowerState.count():
		if not Roster.scheme_taken(i, _active):
			return i
	return 0


func _take_colour() -> void:
	if _phase != Phase.COLOUR or Roster.scheme_taken(_highlighted, _active):
		return
	Roster.set_scheme(_active, _highlighted)
	_active += 1
	if _active >= _wanted:
		_start_game()
		return
	_enter_claim()


## Back always hands control to the player before, so a wrong colour is one
## press away from being redone rather than a reason to restart the screen.
func _go_back() -> void:
	match _phase:
		Phase.COUNT:
			get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
		Phase.CLAIM:
			## Nobody has claimed this slot yet, so step back over the player
			## before and let them choose again.
			if _active == 0:
				Roster.clear()
				_enter_count()
			else:
				_active -= 1
				Roster.drop_last()
				_enter_claim()
		Phase.COLOUR:
			## Give up this device and re-claim, so a player who grabbed the
			## wrong pad can hand it back.
			Roster.drop_last()
			_enter_claim()


func _start_game() -> void:
	## Player one's scheme stays the global one, so the title art and anything
	## else still reading PowerState.chosen keeps working.
	if Roster.count() > 0:
		PowerState.select(Roster.scheme_of(0))
	get_tree().change_scene_to_file("res://scenes/world/mazeDemo.tscn")


func _count_bar() -> String:
	var bar := ""
	for i in Roster.MAX_PLAYERS:
		bar += ("[%d]" % (i + 1)) if (i + 1) == _wanted else (" %d " % (i + 1))
	return bar


func _banner(text: String) -> void:
	var label := get_node_or_null("Right/SchemeName") as Label
	if label != null and _phase != Phase.COLOUR:
		label.text = text
	var hint := get_node_or_null("Right/Element") as Label
	if hint != null:
		hint.text = text if _phase != Phase.COLOUR else hint.text
