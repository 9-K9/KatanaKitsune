extends Node2D

@onready var player = $"../NavigationRegion2D/YSort Objects/PC01"
@onready var world_camera = $WorldCamera
@onready var bgs = $AudioStreamPlayer2D
var gameState : String = ""

func _ready():
	if is_instance_valid(world_camera):
		world_camera.visible = true
		gameState = "game_play"

func _on_audio_stream_player_2d_finished():
	bgs.play()

func _process(delta):
	if Input.is_action_just_pressed("Pause") and gameState == "game_play":
		gameState = "game_paused"
	if gameState == "game_title":
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func getState():
	return gameState
	
func setState(stateString):
	gameState = stateString
