extends CanvasLayer

## Game Over screen. Shows itself when the map's GameManager enters the
## "game_over" state, which the player's death state sets once the collapse
## animation has played out.

## get_parent() rather than an absolute "/root/Main" path, matching PauseMenu,
## so this keeps working if the map root is renamed.
@onready var gameManager = get_parent()
@onready var fade: ColorRect = $Fade
@onready var panel: Control = $Center

const FADE_IN: float = 0.6


func _ready() -> void:
	visible = false
	## The tree is paused while this is up, so everything here has to keep
	## processing or the buttons would be dead.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if not is_instance_valid(gameManager) or not gameManager.has_method("getState"):
		return
	var should_show: bool = gameManager.getState() == "game_over"
	if should_show and not visible:
		_show()
	elif not should_show and visible:
		visible = false


func _show() -> void:
	visible = true
	fade.modulate.a = 0.0
	panel.modulate.a = 0.0
	var tween := create_tween()
	## The tree is paused by the time this runs, which stops an ordinary tween
	## dead and would leave the whole screen sitting at alpha 0.
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade, "modulate:a", 1.0, FADE_IN)
	tween.tween_property(panel, "modulate:a", 1.0, FADE_IN * 0.5)
	$Center/Panel/VBox/Buttons/Retry.grab_focus()


func _on_retry_pressed() -> void:
	## Unpause before reloading: the paused flag survives a scene change and
	## would leave the fresh map frozen.
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_title_pressed() -> void:
	get_tree().paused = false
	gameManager.setState("game_title")
