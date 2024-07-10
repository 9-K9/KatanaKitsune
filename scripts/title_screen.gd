extends Node2D

func _on_new_game_pressed():
	print("start")
	get_tree().change_scene_to_file("res://scenes/world/stage_01.tscn")
