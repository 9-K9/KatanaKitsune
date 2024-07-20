extends StaticBody2D


@export var sideTexture : CompressedTexture2D
@export var topTexture : CompressedTexture2D
@export var faceTexture : CompressedTexture2D
@export var enableModulate = false

@onready var sidePolygon = $WallPolygonsCanvasMods/Polygon2D_Side
@onready var topPolygon = $WallPolygonsCanvasMods/Polygon2D_Top
@onready var facePolygon = $WallPolygonsCanvasMods/Polygon2D_Face
@onready var wall_sprite = $WallPolygonsCanvasMods
@onready var player_entered : bool = false

func _ready():
	if sideTexture:
		sidePolygon.texture = sideTexture
	if topTexture:
		topPolygon.texture = topTexture
	if faceTexture:
		facePolygon.texture = faceTexture
		

func _process(delta):
	if enableModulate:
		if player_entered:
			wall_sprite.modulate = Color(1,1,1,0.5)
		else:
			wall_sprite.modulate = Color(1,1,1,1)
		
func _on_area_2d_area_entered(area):
	if area.is_in_group("player"):
		player_entered = true

func _on_area_2d_area_exited(area):
	if area.is_in_group("player"):
		player_entered = false
