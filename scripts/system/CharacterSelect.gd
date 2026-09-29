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
	_focus_icons()


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
	if not event.is_action_pressed("ui_cancel"):
		return
	_focus_icons()
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
		button.modulate = Color.WHITE if i == index else Color(0.45, 0.42, 0.45)


func _play_current() -> void:
	var clip: String = SHOWCASE[_clip % SHOWCASE.size()]
	var anim := "%s_%s" % [clip, DIRECTION]
	if preview.sprite_frames != null and preview.sprite_frames.has_animation(anim):
		preview.play(anim)
		clip_label.text = clip
	else:
		clip_label.text = ""


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= SECONDS_PER_CLIP:
		_elapsed = 0.0
		_clip += 1
		_play_current()


func _on_confirm_pressed() -> void:
	PowerState.select(_highlighted)
	get_tree().change_scene_to_file("res://scenes/world/mazeDemo.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
