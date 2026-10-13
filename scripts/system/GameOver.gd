extends CanvasLayer

## Death, then a choice. A countdown from ten with CONTINUE under it; taking it
## goes back to the aspect select, letting it run out goes to GAME OVER.
##
## Watches the player directly rather than asking a GameManager for a state.
## The maze's root is its generator, so on the level the game actually starts on
## there is no manager to ask — the same thing that left pause doing nothing.

@export var countdown_from: int = 10
## How long GAME OVER sits there before returning to the title on its own.
@export var game_over_seconds: float = 4.0

const SELECT := "res://scenes/menuscreens/characterSelect.tscn"
const TITLE := "res://scenes/title_screen.tscn"
const FADE_IN: float = 0.6

@onready var fade: ColorRect = $Fade
@onready var panel: Control = $Center

var _player: CharacterBody2D = null
var _counting: bool = false
var _begin_started: bool = false
var _left: float = 0.0
var _expired: bool = false
var _expired_for: float = 0.0
var _countdown_label: Label = null
var _over_layer: ColorRect = null
var _over_label: Label = null


func _ready() -> void:
	visible = false
	## The tree is paused while this is up, so everything here has to keep
	## processing or the buttons and the clock would be dead.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_countdown()
	_build_game_over()


func _process(delta: float) -> void:
	if _expired:
		_tick_game_over(delta)
		return
	if not _counting:
		if _is_dead():
			_begin()
		return

	_left -= delta
	var shown: int = maxi(int(ceil(_left)), 0)
	if _countdown_label != null:
		_countdown_label.text = str(shown)
	if _left <= 0.0:
		_to_game_over()


func _take_focus() -> void:
	TitleScreen.focus_first_button(panel)


## The run is over when every player (human or AI) is down.
##
## In a party, one death should not end everyone's run — reviving requires living
## allies (including AI teammates) to reach the body.
func _is_dead() -> bool:
	var any := false
	for node in get_tree().get_nodes_in_group("player"):
		if not (node is CharacterBody2D) or not ("is_dead" in node):
			continue
		any = true
		if not node.is_dead:
			return false
	return any


func _begin() -> void:
	if _begin_started:
		return
	_begin_started = true
	## A score worth recording gets its name entered before the menu appears.
	## The run ends either way; this is only whether the board remembers it.
	var best: Dictionary = Score.best_of_run()
	if Score.would_place(best["points"]) >= 0 and best["points"] > 0:
		var wave: int = 1
		var level = get_tree().current_scene
		if level != null and "depth" in level:
			wave = level.depth
		## Untyped: load() returns a Variant, so := cannot infer a class here.
		var entry = load("res://scripts/system/NameEntry.gd").new()
		entry.name = "NameEntry"
		get_parent().add_child(entry)
		entry.finished.connect(func():
			entry.queue_free()
			_begin_menu())
		get_tree().paused = true
		entry.open(best["slot"], best["points"], wave)
		return
	_begin_menu()


func _begin_menu() -> void:
	_counting = true
	_left = float(countdown_from)
	visible = true
	get_tree().paused = true
	fade.modulate.a = 0.0
	panel.modulate.a = 0.0
	var tween := create_tween()
	## The tree is paused by the time this runs, which stops an ordinary tween
	## dead and would leave the whole screen sitting at alpha 0.
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(fade, "modulate:a", 1.0, FADE_IN)
	tween.tween_property(panel, "modulate:a", 1.0, FADE_IN)
	## CONTINUE focused, so the countdown can be answered without reaching for a
	## mouse — the one moment you are least likely to want to. Deferred, so it
	## lands after any other menu has finished deciding whether to show itself.
	_take_focus.call_deferred()


## Taking the continue. Back to the aspect select rather than straight into a
## fresh floor, so a death is a chance to change your mind about who you are.
## Named for the button the scene already wires to it.
func _on_retry_pressed() -> void:
	_on_continue_pressed()


func _on_title_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE)


func _on_continue_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SELECT)


func _to_game_over() -> void:
	_counting = false
	_expired = true
	_expired_for = 0.0
	panel.visible = false
	fade.visible = false
	if _over_layer != null:
		_over_layer.visible = true


## Black with white text. Any key moves on; so does waiting.
func _tick_game_over(delta: float) -> void:
	_expired_for += delta
	if _expired_for >= game_over_seconds or _any_key():
		_expired = false
		get_tree().paused = false
		get_tree().change_scene_to_file(TITLE)


func _any_key() -> bool:
	## Ignores the first moment, or the keypress that ran the clock out would
	## skip straight past the screen it just opened.
	if _expired_for < 0.35:
		return false
	return Input.is_anything_pressed()


## Built in code so the existing scene file keeps working untouched.
func _build_countdown() -> void:
	var box := get_node_or_null("Center/Panel/VBox")
	if box == null:
		return
	_countdown_label = Label.new()
	_countdown_label.text = str(countdown_from)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 64)
	_countdown_label.add_theme_color_override("font_color", Color(1, 0.87, 0.57))
	_countdown_label.add_theme_color_override("font_outline_color", Color(0.22, 0.045, 0.045))
	_countdown_label.add_theme_constant_override("outline_size", 6)
	## Above the buttons, so the clock and the way out read as one thing.
	var buttons := get_node_or_null("Center/Panel/VBox/Buttons")
	box.add_child(_countdown_label)
	if buttons != null:
		box.move_child(_countdown_label, buttons.get_index())


func _build_game_over() -> void:
	_over_layer = ColorRect.new()
	_over_layer.name = "GameOverBlack"
	_over_layer.color = Color.BLACK
	_over_layer.anchor_right = 1.0
	_over_layer.anchor_bottom = 1.0
	_over_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over_layer.visible = false
	add_child(_over_layer)

	_over_label = Label.new()
	_over_label.text = "GAME OVER"
	_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_over_label.anchor_right = 1.0
	_over_label.anchor_bottom = 1.0
	_over_label.add_theme_font_size_override("font_size", 72)
	_over_label.add_theme_color_override("font_color", Color.WHITE)
	_over_layer.add_child(_over_label)
