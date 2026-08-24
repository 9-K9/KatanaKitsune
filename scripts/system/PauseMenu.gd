extends CanvasLayer
var game_paused : bool = false
## get_parent() rather than an absolute "/root/Main" path, so this keeps working
## if the map root is renamed or the scene is run on its own.
@onready var gameManager = get_parent()

func _process(_delta):
	if not is_instance_valid(gameManager) or not gameManager.has_method("getState"):
		return
	var should_show: bool = gameManager.getState() == "game_paused"
	if should_show != visible:
		visible = should_show

func _on_resume_pressed():
	gameManager.setState("game_play")

func _on_quit_pressed():
	gameManager.setState("game_title")
