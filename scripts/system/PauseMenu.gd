extends CanvasLayer
var game_paused : bool = false
@onready var gameManager = get_node("/root/Main")

func _process(delta):
	if gameManager.getState() == "game_paused":
		self.visible = true
	else:
		self.visible = false

func _on_resume_pressed():
	gameManager.setState("game_play")

func _on_quit_pressed():
	gameManager.setState("game_title")
