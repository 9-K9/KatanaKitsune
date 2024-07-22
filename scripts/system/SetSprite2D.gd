extends StaticBody2D

@onready var player_entered : bool = false
@onready var sprite = $Sprite2D
@export var sprite_texture: Texture2D
@export var enableModulate = false

func _ready():
	if sprite_texture:
		sprite.texture = sprite_texture

func _process(delta):
	if enableModulate:
		if player_entered:
			sprite.self_modulate = Color(1,1,1,0.5)
		else:
			sprite.self_modulate = Color(1,1,1,1)
		
func _on_area_2d_area_entered(area):
	if area.is_in_group("player"):
		player_entered = true
		print("player etered")

func _on_area_2d_area_exited(area):
	if area.is_in_group("player"):
		player_entered = false
		print("player exited")
