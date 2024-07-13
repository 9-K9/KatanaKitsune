extends Camera2D

@export var speed : int = 250
@export var bounding = Vector2(128,64)
@onready var fearEffect = $displacementShader
@onready var player : CharacterBody2D = $"../NavigationRegion2D/Objects/PC02"
@onready var shift_toogle : bool = false

var screen_center = get_screen_center_position()
var mouse_pos = get_global_mouse_position()

func _ready():
	if is_instance_valid(player):
		self.position = player.position - Vector2(bounding.x/2,bounding.y/4)

func _process(delta):
	if self.enabled and is_instance_valid(player):
		screen_center = self.position
		mouse_pos = get_global_mouse_position()
		if Input.is_action_just_released("ShiftCamera") and !shift_toogle:
			shift_toogle = true
		elif Input.is_action_just_released("ShiftCamera") and shift_toogle:
			shift_toogle = false
			
		if shift_toogle:
			if mouse_pos.x > (screen_center.x + (bounding.x)):
				self.position.x = self.position.x + speed * delta
			if mouse_pos.x < (screen_center.x - (bounding.x)):
				self.position.x = self.position.x - speed * delta
			if mouse_pos.y > (screen_center.y + (bounding.y)):
				self.position.y = self.position.y + speed * delta
			if mouse_pos.y < (screen_center.y - (bounding.y)):
				self.position.y = self.position.y - speed * delta
				
		if !shift_toogle:
			self.position = player.position - Vector2(bounding.x/2,bounding.y/4)



	
