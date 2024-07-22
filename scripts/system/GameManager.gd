extends Node2D

@onready var player = get_node("../NavigationRegion2D/YSort Objects/PC01")
@onready var world_camera = get_node("WorldCamera")
@onready var bgs = get_node("AudioStreamPlayer2D")
var gameState : String = ""
var gameTime : float = 0.00

func _ready():
	if is_instance_valid(world_camera):
		world_camera.visible = true
		gameState = "game_play"

func _on_audio_stream_player_2d_finished():
	bgs.play()

func _process(delta):
	systemControls(gameState,delta)
		
func getState():
	return gameState
	
func setState(stateString):
	gameState = stateString
	
func systemControls(state,delta):
	if Input.is_action_just_pressed("Pause") and state == "game_play":
		state = "game_paused"
	if Input.is_action_just_pressed("Pause") and state == "game_paused":
		state = "game_play"
	if state == "game_title":
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
	gameTime = gameTime + delta
	return gameTime
	
