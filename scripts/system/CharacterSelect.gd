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
	_highlighted = PowerState.chosen
	_show(_highlighted)


func _build_icons() -> void:
	for i in PowerState.count():
		var button := TextureButton.new()
		button.texture_normal = load(PowerState.icon_path(i))
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = Vector2(124, 124)
		button.tooltip_text = "%s — %s" % [PowerState.info(i)["element"], PowerState.info(i)["name"]]
		button.pressed.connect(_show.bind(i))
		icons.add_child(button)


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
