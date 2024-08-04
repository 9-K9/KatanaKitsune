extends StaticBody2D


@export var sideTexture : CompressedTexture2D
@export var sideColor : Color = "ffffff"
@export var sideRotation : float = 0.0
@export var sideScale : Vector2 = Vector2(1,1)
@export var sideOffset : Vector2 = Vector2.ZERO 
@export var topTexture : CompressedTexture2D
@export var topColor : Color = "ffffff"
@export var topRotation : float = 0.0
@export var topScale : Vector2 = Vector2(1,1)
@export var topOffset : Vector2 = Vector2.ZERO 
@export var faceTexture : CompressedTexture2D
@export var faceColor : Color = "ffffff"
@export var faceRotation : float = 0.0
@export var faceScale : Vector2 = Vector2(1,1)
@export var faceOffset : Vector2 = Vector2.ZERO 
@export var enableModulate = false

@onready var sidePolygon = $WallPolygonsCanvasMods/Polygon2D_Side
@onready var topPolygon = $WallPolygonsCanvasMods/Polygon2D_Top
@onready var facePolygon = $WallPolygonsCanvasMods/Polygon2D_Face
@onready var wall_sprite = $WallPolygonsCanvasMods
@onready var player_entered : bool = false

func _ready():
	if sideTexture:
		sidePolygon.texture = sideTexture
		sidePolygon.self_modulate = sideColor
		sidePolygon["texture_rotation"] = sideRotation
		sidePolygon["texture_scale"] = sideScale
		sidePolygon["texture_offset"] = sideOffset
	if topTexture:
		topPolygon.texture = topTexture
		topPolygon.self_modulate = topColor
		topPolygon["texture_rotation"] = topRotation
		topPolygon["texture_scale"] = topScale
		topPolygon["texture_offset"] = topOffset
	if faceTexture:
		facePolygon.texture = faceTexture
		facePolygon.self_modulate = faceColor
		facePolygon["texture_rotation"] = faceRotation
		facePolygon["texture_scale"] = faceScale
		facePolygon["texture_offset"] = faceOffset	

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
