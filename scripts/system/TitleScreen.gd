extends Node2D

## Title screen. GameManager sends the player here on "game_title".

## The playable level. mapTemplate is the hand-built single room kept for
## testing; the maze is the actual first level.
const FIRST_MAP := "res://scenes/world/mazeDemo.tscn"


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
