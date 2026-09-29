extends Control

## The awareness eye: how hidden she is, and whether anything is looking back.
##
## This is the sneak meter, but drawn as an eye rather than a bar because what
## it measures is not a quantity — it is a relationship with the monsters. Three
## readings, and you should be able to take all of them at a glance:
##
##   calm     half-lidded, blinking now and then. Nothing has seen you.
##   alert    wide, and turned towards whatever just spotted you.
##   hidden   shut, ringed by how much sneaking you have left.
##
## Sits under the radar, and deliberately agrees with it: "something is hunting
## me" is read off the monster's own state machine here exactly as Radar does
## for its red blips, so the eye can never contradict the cones.

## Where the eye looks, in pixels, when something has spotted her. Small on
## purpose — the eye glances towards a threat, it does not swivel like a turret.
@export var glance: float = 3.0
## How quickly the glance settles on a new threat.
@export var glance_speed: float = 9.0

@export var ring_width: float = 3.0
@export var ring_radius: float = 26.0

const COLOUR_RING := Color(0.72, 0.55, 0.92, 0.95)
const COLOUR_RING_BACK := Color(0.10, 0.09, 0.14, 0.65)
const COLOUR_ALERT_HALO := Color(0.88, 0.22, 0.20, 0.55)

const EYE_CALM := preload("res://assets/sprites/ui/eye/eye_calm.png")
const EYE_ALERT := preload("res://assets/sprites/ui/eye/eye_alert.png")
const EYE_CLOSED := preload("res://assets/sprites/ui/eye/eye_closed.png")

## Blinking is a sign of life, and only belongs in the calm state: an eye that
## blinked while shut would be nonsense, and one that blinked while something
## was charging at her would undercut the alarm.
const BLINK_EVERY := Vector2(2.4, 6.0)
const BLINK_LENGTH: float = 0.11

@onready var _eye: TextureRect = $Eye

var _player: CharacterBody2D = null
var _look: Vector2 = Vector2.ZERO
var _look_target: Vector2 = Vector2.ZERO
var _blink_in: float = 3.0
var _blink_left: float = 0.0
## Which monster the eye is currently turned towards, so a glance only moves
## when something *new* spots her rather than jittering between two hunters.
var _watching: int = 0
var _threat: Node2D = null


func _ready() -> void:
	_eye.texture = EYE_CALM
	_eye.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_blink_in = randf_range(BLINK_EVERY.x, BLINK_EVERY.y)


func _process(delta: float) -> void:
	_player = _find_player()
	if _player == null:
		return

	## Resolved once and reused by _draw, which runs in the same frame — walking
	## the whole enemy group twice per frame to ask the same question would be
	## the most expensive thing on the HUD.
	var threat: Node2D = _nearest_hunter()
	_threat = threat
	var hidden: bool = _player.get("stealthed") or _player.get("crouched")

	if hidden:
		_show_hidden()
	elif threat != null:
		_show_alert(threat)
	else:
		_show_calm(delta)

	## Eased rather than snapped, so the eye turns towards a threat instead of
	## teleporting its pupil there.
	_look = _look.lerp(_look_target, clampf(delta * glance_speed, 0.0, 1.0))
	_eye.position = _eye_home() + _look
	queue_redraw()


## Shut, with the meter drawn around it. The ring is the whole point of the
## closed state: it is the only moment the number matters.
func _show_hidden() -> void:
	_eye.texture = EYE_CLOSED
	_look_target = Vector2.ZERO
	_watching = 0
	_blink_left = 0.0


## Wide, and turned towards whoever found her.
func _show_alert(threat: Node2D) -> void:
	_eye.texture = EYE_ALERT
	_blink_left = 0.0
	## Only re-aimed for a monster that was not already the one being watched,
	## so a single hunter circling her does not make the eye wobble.
	if threat.get_instance_id() != _watching:
		_watching = threat.get_instance_id()
		var to_threat: Vector2 = threat.global_position - _player.global_position
		## Unsquashed: the map is drawn 2:1, so a monster directly above her
		## would otherwise read as only half as far up as it is.
		to_threat.y /= 0.5
		if to_threat != Vector2.ZERO:
			_look_target = to_threat.normalized() * glance


## Half-lidded and watchful, blinking every few seconds.
func _show_calm(delta: float) -> void:
	_look_target = Vector2.ZERO
	_watching = 0
	if _blink_left > 0.0:
		_blink_left -= delta
		_eye.texture = EYE_CLOSED if _blink_left > 0.0 else EYE_CALM
		return
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink_in = randf_range(BLINK_EVERY.x, BLINK_EVERY.y)
		_blink_left = BLINK_LENGTH
		_eye.texture = EYE_CLOSED
	else:
		_eye.texture = EYE_CALM


func _draw() -> void:
	if _player == null:
		return
	var centre: Vector2 = size * 0.5
	var hidden: bool = _player.get("stealthed") or _player.get("crouched")

	if hidden:
		var maximum: float = maxf(_player.get("max_sneak"), 1.0)
		var left: float = clampf(_player.get("sneak") / maximum, 0.0, 1.0)
		draw_arc(centre, ring_radius, 0.0, TAU, 48, COLOUR_RING_BACK, ring_width, true)
		## Runs down from twelve o'clock, so an emptying ring unwinds the way a
		## clock does rather than filling up as her cover disappears.
		var start: float = -PI * 0.5
		var ring: Color = COLOUR_RING
		## Reddens as it runs out, so the last moments of cover are visible
		## without having to read the arc's length.
		if left < 0.3:
			ring = ring.lerp(COLOUR_ALERT_HALO, 1.0 - left / 0.3)
		draw_arc(centre, ring_radius, start, start + TAU * left, 48, ring, ring_width, true)
	elif _threat != null:
		## A soft halo instead of a ring: nothing is being counted down, this is
		## just alarm.
		draw_circle(centre, ring_radius + 2.0, COLOUR_ALERT_HALO * Color(1, 1, 1, 0.22))


## Where the eye sits before any glance is applied.
func _eye_home() -> Vector2:
	return (size - _eye.size) * 0.5


## The closest monster actively hunting her, or null.
##
## "Hunting" is taken from the monster's own state machine, the same way Radar
## picks its red blips — a monster in walk or attack has eyes on her. Recomputing
## the sight test here would let the eye and the radar disagree.
func _nearest_hunter() -> Node2D:
	var best: Node2D = null
	var best_distance: float = INF
	for node in get_tree().get_nodes_in_group("enemy"):
		if not (node is Node2D) or not is_instance_valid(node):
			continue
		var machine := node.get_node_or_null("FiniteStateMachine")
		if machine == null or machine.current_state == null:
			continue
		if not String(machine.current_state.name) in ["walk", "attack"]:
			continue
		var distance: float = _player.global_position.distance_squared_to(
				(node as Node2D).global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best


## Her PlayerHitBox is in the "player" group too, so the first node in the group
## is as likely to be that Area2D as the character — hence the search for the
## body rather than a cast on whatever comes back first.
func _find_player() -> CharacterBody2D:
	if is_instance_valid(_player):
		return _player
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D:
			return node
	return null
