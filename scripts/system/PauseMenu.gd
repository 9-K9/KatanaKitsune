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
	## Owns the pause toggle either way, because this node keeps processing while
	## the tree is frozen; GameManager stops dead the instant the pause takes
	## effect, so it could never un-pause the game itself.
	if _has_manager():
		_process_with_manager()
	else:
		_process_standalone()


## Maps built around GameManager route pause through its state machine, so
## game_over stays excluded and the key cannot be used to un-die.
func _process_with_manager() -> void:
	var state: String = gameManager.getState()
	if state != "game_over" and Input.is_action_just_pressed("Pause"):
		gameManager.setState("game_play" if state == "game_paused" else "game_paused")
		state = gameManager.getState()
	_set_shown(state == "game_paused")


## The maze's root is its generator, not a GameManager, so there is no state
## machine to ask — the menu pauses the tree itself. Without this the key did
## nothing at all on the level the game actually starts on.
func _process_standalone() -> void:
	## Death has its own screen, and it pauses the tree to show it. Without this
	## the pause menu reads that pause as its own, opens behind the Game Over
	## panel and takes the focus off CONTINUE — two menus up at once, neither
	## driveable.
	if _player_dead():
		_set_shown(false)
		return
	## A pad pulled out also pauses the tree, to say whose. Same trap as death:
	## without this the menu reads that pause as its own and opens behind the
	## reconnect notice, so two things are up at once and the player whose
	## controller is missing is the one being asked to drive the menu.
	if Roster.any_lost():
		_set_shown(false)
		return
	if Input.is_action_just_pressed("Pause"):
		get_tree().paused = not get_tree().paused
	_set_shown(get_tree().paused)


func _player_dead() -> bool:
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D and "is_dead" in node and node.is_dead:
			return true
	return false


func _has_manager() -> bool:
	return is_instance_valid(gameManager) and gameManager.has_method("getState")


func _set_shown(should_show: bool) -> void:
	if should_show == visible:
		return
	visible = should_show
	## Focus has to be taken when the menu appears, not when it is built. The
	## grab in _ready ran while this was still hidden, and a grab on a hidden
	## tree does not stick — so a pad opened onto nothing.
	if should_show:
		_show_main_menu()

func _on_resume_pressed():
	if _has_manager():
		gameManager.setState("game_play")
	else:
		get_tree().paused = false
	_show_main_menu()

func _on_cheats_pressed() -> void:
	main_menu.visible = false
	cheats_menu.visible = true
	TitleScreen.focus_first_button(cheats_menu)
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
	## Focus follows whichever list is showing, so a pad can drive both.
	TitleScreen.focus_first_button(main_menu)

func _sync_immortality_label() -> void:
	immortality_toggle.text = "IMMORTALITY IS ON" if CheatManager.immortality_enabled else "IMMORTALITY IS OFF"

func _on_quit_pressed():
	## Leaving the map has to lift the pause too, or the title screen loads
	## into a frozen tree.
	get_tree().paused = false
	if _has_manager():
		gameManager.setState("game_title")
	else:
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
