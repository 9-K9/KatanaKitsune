extends CanvasLayer

## Player HUD: portrait and health. The bar is drawn by hand rather than with a
## ProgressBar because the lacquer frame is a fixed-size piece of pixel art and
## the fill has to sit exactly inside its inner cavity.

## Inset from the bar frame's edges to the lacquer cavity the fill sits in.
const FILL_INSET: Vector2 = Vector2(9, 8)

@onready var depth_label: Label = $Depth
@onready var fill: ColorRect = $Bar/Fill
@onready var bar: TextureRect = $Bar
@onready var portrait: TextureRect = $Portrait
@onready var stamina_fill: ColorRect = $Stamina/Fill
@onready var stamina_bar: TextureRect = $Stamina

var _player: CharacterBody2D = null
var _fill_width: float = 0.0
var _shown: float = -1.0
var _stamina_width: float = 0.0


func _ready() -> void:
	_fill_width = bar.size.x - FILL_INSET.x * 2.0
	fill.position = FILL_INSET
	fill.size = Vector2(_fill_width, bar.size.y - FILL_INSET.y * 2.0)
	_stamina_width = stamina_bar.size.x - FILL_INSET.x * 2.0
	stamina_fill.position = FILL_INSET
	stamina_fill.size = Vector2(_stamina_width, stamina_bar.size.y - FILL_INSET.y * 2.0)
	## Portrait wears the chosen aspect, like she does. Each power state ships
	## its own recoloured HUDicon.
	var icon := load(PowerState.icon_path())
	if icon != null:
		portrait.texture = icon


func player() -> CharacterBody2D:
	if is_instance_valid(_player):
		return _player
	## The player's hitbox Area2D is in the "player" group too, so take the
	## first body rather than the first node.
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D:
			_player = node
			return _player
	return null


func _process(delta: float) -> void:
	var target := player()
	if target == null:
		return
	var ratio: float = clampf(target.health / maxf(target.max_health, 1.0), 0.0, 1.0)
	## Chase the real value so chip damage reads as a drain rather than a jump.
	_shown = ratio if _shown < 0.0 else move_toward(_shown, ratio, delta * 1.2)
	fill.size.x = _fill_width * _shown
	fill.color = Color(0.78, 0.17, 0.16) if _shown > 0.3 else Color(0.9, 0.35, 0.12)
	## Stamina tracks the real value with no easing: she needs to see it empty the
	## moment the sprint stops, because that is when she loses the speed.
	var winded: bool = target.has_method("winded") and target.winded()
	var spare: float = clampf(target.stamina / maxf(target.max_stamina, 1.0), 0.0, 1.0)
	stamina_fill.size.x = _stamina_width * spare
	stamina_fill.color = Color(0.55, 0.34, 0.16) if winded else Color(0.45, 0.62, 0.36)
	_show_depth()


## Only the generated levels have a depth; the hand-built maps leave this blank.
func _show_depth() -> void:
	var level = get_tree().current_scene
	if level == null or not ("depth" in level):
		return
	var text: String = "FLOOR %d" % level.depth
	if depth_label.text != text:
		depth_label.text = text
