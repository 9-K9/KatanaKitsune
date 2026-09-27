extends CanvasLayer
var game_paused : bool = false
## get_parent() rather than an absolute "/root/Main" path, so this keeps working
## if the map root is renamed or the scene is run on its own.
@onready var gameManager = get_parent()
@onready var main_menu: VBoxContainer = $Center/Panel/Margin/MainMenu
@onready var cheats_menu: VBoxContainer = $Center/Panel/Margin/CheatsMenu
@onready var immortality_toggle: CheckButton = $Center/Panel/Margin/CheatsMenu/Immortality

func _ready():
	## The tree is paused while this menu is up, so it has to keep processing
	## or its own buttons would be dead.
	process_mode = Node.PROCESS_MODE_ALWAYS
	## The same cover the title screen shows, so pausing frames the character
	## rather than a flat wash over the level.
	var art := get_node_or_null("Cover")
	if art != null:
		art.texture = load(PowerState.cover_path())
	_show_main_menu()
	_sync_immortality_label()

func _process(_delta):
	if not is_instance_valid(gameManager) or not gameManager.has_method("getState"):
		return
	var state: String = gameManager.getState()
	## Owns the pause toggle because this node keeps processing while the tree
	## is frozen; GameManager stops dead the instant the pause takes effect.
	## Death is excluded so the key cannot be used to un-die.
	if state != "game_over" and Input.is_action_just_pressed("Pause"):
		gameManager.setState("game_play" if state == "game_paused" else "game_paused")
		state = gameManager.getState()

	var should_show: bool = state == "game_paused"
	if should_show != visible:
		visible = should_show

func _on_resume_pressed():
	gameManager.setState("game_play")
	_show_main_menu()

func _on_cheats_pressed() -> void:
	main_menu.visible = false
	cheats_menu.visible = true
	immortality_toggle.button_pressed = CheatManager.immortality_enabled
	_sync_immortality_label()

func _on_immortality_toggled(enabled: bool) -> void:
	CheatManager.set_immortality(enabled)
	_sync_immortality_label()

func _on_cheats_back_pressed() -> void:
	_show_main_menu()

func _show_main_menu() -> void:
	main_menu.visible = true
	cheats_menu.visible = false

func _sync_immortality_label() -> void:
	immortality_toggle.text = "IMMORTALITY IS ON" if CheatManager.immortality_enabled else "IMMORTALITY IS OFF"

func _on_quit_pressed():
	## Leaving the map has to lift the pause too, or the title screen loads
	## into a frozen tree.
	get_tree().paused = false
	gameManager.setState("game_title")
