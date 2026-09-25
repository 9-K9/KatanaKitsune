extends Node2D

## Path to the player, relative to this map's root node.
## Exported so each map can wire its own player without editing this script.
@export var player_path: NodePath = "YSortMap/KatanaKitsune"

const TITLE_SCENE := "res://scenes/title_screen.tscn"

@onready var player: Node2D = get_node_or_null(player_path)
@onready var world_camera: Camera2D = get_node_or_null("WorldCamera")
@onready var bgs: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")

var gameState: String = ""
var gameTime: float = 0.00

## Guards the one-way transition to the title screen so it cannot re-fire
## every frame while the state is still "game_title".
var _changing_scene: bool = false

func _ready():
	if is_instance_valid(world_camera):
		world_camera.visible = true
	gameState = "game_play"

func _on_audio_stream_player_2d_finished():
	if is_instance_valid(bgs):
		bgs.play()

func _process(delta):
	gameState = systemControls(gameState, delta)

func getState():
	return gameState

func setState(stateString):
	if gameState == stateString:
		return
	gameState = stateString
	## Freeze the world behind the Game Over screen, or the monsters carry on
	## clawing at Akane's corpse while the player reads it. The screen itself
	## runs with PROCESS_MODE_ALWAYS so its buttons still work.
	get_tree().paused = (gameState == "game_over")

func getPlayerPosition() -> Vector2:
	if is_instance_valid(player):
		return player.position
	return Vector2.ZERO

func systemControls(state, delta):
	## Death is terminal: only the Game Over screen's own buttons get out of it,
	## so the pause key cannot be used to un-die.
	if state == "game_over":
		return state
	if Input.is_action_just_pressed("Pause"):
		if state == "game_play":
			state = "game_paused"
		elif state == "game_paused":
			state = "game_play"
	elif state == "game_title" and not _changing_scene:
		_changing_scene = true
		if ResourceLoader.exists(TITLE_SCENE):
			get_tree().change_scene_to_file(TITLE_SCENE)
		else:
			push_warning("GameManager: title scene missing (%s); staying in map." % TITLE_SCENE)
			state = "game_play"
			_changing_scene = false
	gameTime = gameTime + delta
	return state
