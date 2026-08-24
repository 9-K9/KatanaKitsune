extends CanvasLayer

@onready var printLabel = $Label
var inputString : String = ""

func _ready() -> void:
	printLabel.text = ""

func _input(_event: InputEvent) -> void:
	var previous := inputString
	if Input.is_action_pressed("Action"):
		inputString = "Action"
	elif Input.is_action_pressed("Attack"):
		inputString = "Attack"
	elif Input.is_action_pressed("Defend"):
		inputString = "Defend"
	elif Input.is_action_pressed("Dodge"):
		inputString = "Dodge"
	elif Input.is_action_pressed("Jump"):
		inputString = "Jump"
	elif Input.is_action_pressed("Katana"):
		inputString = "Katana"
	elif Input.is_action_pressed("Run"):
		inputString = "Run"
	elif Input.is_action_pressed("Stealth"):
		inputString = "Stealth"
	elif Input.is_action_pressed("Left"):
		inputString = "Left"
	elif Input.is_action_pressed("Right"):
		inputString = "Right"	
	elif Input.is_action_pressed("Up"):
		inputString = "Up"
	elif Input.is_action_pressed("Down"):
		inputString = "Down"
	else:
		inputString = ""

	## Only touch the label when the value actually changed; this used to be
	## rewritten every frame from _process, and never cleared on release.
	if inputString != previous:
		printLabel.text = "" if inputString.is_empty() else inputString + " Button Is Pressed"
