extends StaticBody2D

@onready var wall_sprite = $Sprite2D
@onready var player_entered : bool = false
@export var enableModulate = false

func _process(delta):
	if enableModulate:
		if player_entered:
			wall_sprite.self_modulate = Color(1,1,1,0.5)
		else:
			wall_sprite.self_modulate = Color(0.648, 0.402, 0.321)
		
func _on_area_2d_area_entered(area):
	if area.is_in_group("player"):
		player_entered = true

func _on_area_2d_area_exited(area):
	if area.is_in_group("player"):
		player_entered = false
