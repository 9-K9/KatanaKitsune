extends Node2D

@onready var player = $"../NavigationRegion2D/Objects/Player"
@onready var world_camera = $WorldCamera
@onready var bgs = $AudioStreamPlayer2D

func _ready():
	if is_instance_valid(world_camera):
		world_camera.visible = true

func _on_audio_stream_player_2d_finished():
	bgs.play()
