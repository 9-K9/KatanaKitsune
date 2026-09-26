extends Node2D

## Title screen. GameManager sends the player here on "game_title".

## The playable map. Used to point at map01.tscn, which does not exist — the
## only map in the project is the template one the game boots into.
const FIRST_MAP := "res://scenes/world/maps/mapTemplate.tscn"


func _on_new_game_pressed():
	## A Game Over leaves the tree paused if the player quits to title from it.
	get_tree().paused = false
	get_tree().change_scene_to_file(FIRST_MAP)


func _on_quit_pressed():
	get_tree().quit()


func _on_audio_stream_player_2d_finished():
	var music := get_node_or_null("AudioStreamPlayer2D")
	if is_instance_valid(music):
		music.play()
