extends AnimatedCharacterClass

## This player's controls, bound to their own device. Every state asks this
## rather than the global Input, because Input.is_action_pressed answers for any
## device — with four pads connected, one player's Attack would swing all four
## katanas.
var input: PlayerInput = null
## Which player this is. Slot 0 is player one; the maze sets this when it spawns
## her, and it decides the device, the colour scheme and the marker underfoot.
var slot: int = 0

## Reviving a fallen team-mate: stand over them and drop into a sneak.
##
## It costs the whole sneak meter and drains fast — a few seconds crouched over
## the body, not a chore, but it spends the thing that keeps you hidden, so
## picking someone up in front of a monster is a real decision.
@export var revive_drain: float = 42.0
## Ground reach to a fallen body, measured unsquashed like every other distance
## in an isometric room.
##
## Generous on purpose. "Standing over" someone never means sharing their exact
## position — she is about 66 across, so two characters pressed together already
## sit over a hundred units apart once the isometric squash is undone. At 110 a
## player who looked like they were on the body was measured at 132 and the
## revive silently never started.
@export var revive_reach: float = 190.0
## Share of their health a revived player comes back with.
@export var revive_health: float = 0.5

@onready var timerTimeOut : bool = false
@onready var actionBlockInput : bool = false
@export var contact_damage: float = 10.0

## What the blade is currently over. Resolved once — the attack code used to
## re-look this up by string path on every swing.
@onready var action_area: Area2D = $CollisionChecker/RayCast2D/ActionArea

## Every light she carries, hooded while she sneaks: one that stays at full
## brightness makes a nonsense of hiding, and it is the clearest read on the
## stance she is in that does not involve looking at the HUD.
##
## Gathered lazily rather than with @onready, because the bright one is not in
## her scene at all — MazeDemo adds a "Lantern" child at runtime, after her
## _ready has already run. Hooding only the scene's own PointLight2D dimmed a
## light contributing almost nothing next to it, so nothing appeared to happen.
var _lights: Array[PointLight2D] = []
var _light_base: Array[Vector3] = []
## What the lantern drops to while hidden. Dimmer and tighter, not out — going
## dark would just make the floor unreadable and sneaking unplayable.
@export var sneak_light_energy: float = 0.6
@export var sneak_light_size: float = 0.7
## Eased rather than switched, so it hoods and opens rather than popping.
@export var light_fade_speed: float = 6.0

## Things a katana swing is allowed to damage. Ordinary body contact is not a
## hit, so this is only ever consulted on an attack's hit frame.
const HITTABLE_GROUPS: PackedStringArray = ["enemy", "breakable"]

func _ready() -> void:
	health = max_health
	## Falls back to the keyboard when nothing has claimed a slot, so running the
	## maze scene directly still gives a playable character.
	if input == null:
		input = Roster.input_for(slot) if Roster.count() > slot else PlayerInput.new()
	## Repaint into this player's chosen aspect. Only the sheets behind each
	## frame change, so every animation, region and timing is untouched. The
	## index is per-player now: four players wear four different colours.
	var sprite := get_node_or_null("AnimationManager/AnimatedSprite2D")
	if sprite != null:
		PowerState.apply_to(sprite, Roster.scheme_of(slot) if Roster.count() > slot else -1)
	var hitbox = $CollisionChecker/PlayerHitBox
	hitbox.body_entered.connect(_on_player_hit_box_body_entered)


## Everything inside the blade right now that can take a hit.
##
## The single answer to "what am I aiming at". Targeting used to be resolved
## two different ways — a cached enemyBody kept in sync by Area2D signals, and
## a separate live overlap query inside playerAttack — which could disagree,
## and the cache only ever held one body.
func blade_targets() -> Array[Node2D]:
	var found: Array[Node2D] = []
	if not is_instance_valid(action_area):
		return found
	for body in action_area.get_overlapping_bodies():
		if not is_instance_valid(body) or not body.has_method("take_damage"):
			continue
		for group in HITTABLE_GROUPS:
			if body.is_in_group(group):
				found.append(body)
				break
	return found


## The monster a non-attack interaction applies to: the nearest one in the
## blade. Breakables are skipped — only monsters have anything to say.
func current_target() -> Node2D:
	var best: Node2D = null
	var best_distance: float = INF
	for body in blade_targets():
		if not body.is_in_group("enemy"):
			continue
		var distance: float = global_position.distance_squared_to(body.global_position)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best

func _on_death() -> void:
	$FiniteStateMachine.change_state("death")
		
func InputHandler():
	##movement based on this player's own device, not on any device at all
	direction = input.vector()
	return round(direction)

func _physics_process(_delta):
	update_buffs()
	## Unconditional: the running states call drain_stamina, which resets the rest
	## timer, so spending and recovering cannot both apply in the same frame.
	recover_stamina(_delta)
	recover_sneak(_delta)
	_try_revive(_delta)
	_hood_lantern(_delta)
	## Sampled once per frame: InputHandler() was previously called three times
	## per physics tick, and the state scripts call it twice more per frame.
	var input_dir: Vector2 = InputHandler()
	if input_dir != Vector2.ZERO and not actionBlockInput:
		facing_dir = directionState(input_dir)
		updateRayCast2D(facing_dir)
		## No delta here: move_and_slide() already integrates velocity over the
		## physics step. Multiplying by delta as well made displacement scale
		## with delta squared, so the character moved twice as fast at 30fps.
		velocity = input_dir * speed
		velocity.y = velocity.y / 2
	else:
		velocity = Vector2.ZERO
	move_and_slide()

## Brings her lights towards where the current stance wants them.
func _hood_lantern(delta: float) -> void:
	_gather_lights()
	var hidden: bool = stealthed or crouched
	var t: float = clampf(delta * light_fade_speed, 0.0, 1.0)
	for i in _lights.size():
		var light: PointLight2D = _lights[i]
		if not is_instance_valid(light):
			continue
		## Each light keeps its own starting energy and scale, so the hooded
		## values stay relative to however bright it was set to be.
		var base: Vector3 = _light_base[i]
		var factor_energy: float = sneak_light_energy if hidden else 1.0
		var factor_size: float = sneak_light_size if hidden else 1.0
		light.energy = lerpf(light.energy, base.x * factor_energy, t)
		light.scale = light.scale.lerp(
				Vector2(base.y, base.z) * factor_size, t)


## Picks up any light she is carrying, including ones added after _ready. Cheap
## enough to re-check: the loop stops at the first frame where the count matches.
func _gather_lights() -> void:
	var found: Array[PointLight2D] = []
	for node in find_children("*", "PointLight2D", true, false):
		found.append(node)
	if found.size() == _lights.size():
		return
	for light in found:
		if light in _lights:
			continue
		_lights.append(light)
		## Captured the first time it is seen, before anything has dimmed it.
		_light_base.append(Vector3(light.energy, light.scale.x, light.scale.y))


## Spends the sneak meter to bring a fallen team-mate back.
##
## Draining rather than a button press, so the cost is visible on the eye's ring
## as it happens and can be abandoned by standing up.
func _try_revive(delta: float) -> void:
	if is_dead or not (stealthed or crouched):
		return
	var fallen := _fallen_underfoot()
	if fallen == null:
		return
	drain_sneak(revive_drain, delta)
	if sneak <= 0.0:
		fallen.revive(revive_health)


## The nearest downed player within reach, or null.
func _fallen_underfoot() -> Node:
	var best: Node = null
	var best_distance: float = INF
	for node in get_tree().get_nodes_in_group("player"):
		if node == self or not (node is CharacterBody2D):
			continue
		if not (node.get("is_dead") == true):
			continue
		## Unsquashed: the map is drawn 2:1, so a body the same distance away up
		## the screen would otherwise read as twice as close as one to the side.
		var offset: Vector2 = (node as Node2D).global_position - global_position
		offset.y /= 0.5
		var distance: float = offset.length()
		if distance <= revive_reach and distance < best_distance:
			best_distance = distance
			best = node
	return best


func _on_action_timer_timeout():
	timerTimeOut = true

func _on_player_hit_box_body_entered(body):
	## Deliberately does nothing now. Monsters damage Akane from the hit frame of
	## their attack animation (EnemyBase.strike), which is telegraphed and can be
	## read and dodged. Contact damage predates that AI and meant simply brushing
	## past a monster — or walking into one still taunting — cost 10 health with
	## no wind-up to react to.
	pass
