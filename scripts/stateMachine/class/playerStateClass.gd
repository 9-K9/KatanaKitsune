class_name PlayerClass
extends StateMachineState

## Base class for all character states.
## Contains a reference to character variables and helper functions.

## Node path to the character.
@export_node_path("CharacterBody2D") var _CharacterBody2D: NodePath = "../.."
@export_node_path("AnimatedSprite2D") var _animatedsprite2D: NodePath = "../../AnimatedSprite2D"
@export_node_path("Timer") var _action_timer: NodePath = "../../ActionTimer"

## Reference to the character node.
@onready var pc: CharacterBody2D = get_node(_CharacterBody2D)
@onready var animated_sprite : AnimatedSprite2D = get_node(_animatedsprite2D)
@onready var action_timer : Timer = get_node(_action_timer)

## True once the current swing has already dealt its damage.
var _swing_connected: bool = false

##Handles Input and returns a state string
func stateAnimation(state_to_animate,fps):
	fps = null #fps can be set in code or in the editor
	var string_animation : String
	string_animation = "%s_%s"%[state_to_animate,pc.facing_dir]
	## Undoes any rate a one-shot state left behind. Looping states call this
	## every frame, so the rate is back to normal as soon as one is entered.
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(string_animation)

## How long a clip actually runs, in seconds, for the way she is facing.
##
## One-shot states used to carry hardcoded durations, and every one was shorter
## than its art: the roll ended after 0.55s of a 1.6s clip, so two thirds of the
## frames never showed. Ask the SpriteFrames instead of guessing.
func clip_length(clip: String) -> float:
	var frames: SpriteFrames = animated_sprite.sprite_frames
	var anim := "%s_%s" % [clip, pc.facing_dir]
	if frames == null or not frames.has_animation(anim):
		return 0.0
	var fps: float = frames.get_animation_speed(anim)
	if fps <= 0.0:
		return 0.0
	var total := 0.0
	for i in frames.get_frame_count(anim):
		total += frames.get_frame_duration(anim, i)
	return total / fps

## Plays a clip once and returns how long it will take, so the state can end when
## the art ends. `rate` speeds it up without editing the SpriteFrames — the roll
## and hop are drawn at a stately 5fps, far too slow to read as evasive.
func play_oneshot(clip: String, rate: float = 1.0) -> float:
	animated_sprite.speed_scale = rate
	animated_sprite.play("%s_%s" % [clip, pc.facing_dir])
	return clip_length(clip) / rate

## Too spent to run. Stamina lives on the character; this is just the shorthand.
func winded() -> bool:
	return pc.winded()

## A chair she is standing over, if any. Matched by group rather than collision
## so a chair is a sprite with a marker on it, not a physics body in her way.
## Reach was 30px, which her own collision diamond is more than twice as wide
## as — she could be standing squarely on a chair with her origin too far from
## its centre to count, so resting could effectively never be triggered.
## Measured along the ground, which doubles the vertical component to undo the
## 2:1 squash — so this is about 70px of tolerance up or down the screen and 140
## to the side. At 90 it was only 45px vertically, tight enough that she could
## look like she was standing on a chair and still not reach it.
const CHAIR_REACH: float = 140.0


func chair_underfoot() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = INF
	for chair in pc.get_tree().get_nodes_in_group("chair"):
		if not (chair is Node2D):
			continue
		## Overlap first where a chair offers one. A shape she stands inside has
		## no isometric squash to compensate for, which is what the distance
		## check kept getting wrong — 140 units of ground reach is only about 70
		## pixels up or down the screen, and a chair a little below her fell out
		## of it while still looking underfoot.
		var seat_position := _chair_position(chair as Node2D)
		## Ground distance, not screen distance. The map is drawn 2:1, so a chair
		## the same distance away up the screen would otherwise read as twice as
		## close as one to the side.
		var offset: Vector2 = seat_position - pc.global_position
		offset.y /= 0.5
		var distance: float = offset.length()

		var zone := (chair as Node2D).get_node_or_null("SitZone") as Area2D
		var in_reach: bool = zone.overlaps_body(pc) if zone != null else distance <= CHAIR_REACH
		if not in_reach:
			continue
		## Nearest, not first. Returning the first chair whose zone she was inside
		## meant that with two in range she could be snapped onto whichever the
		## group happened to list first — which is how she ended up sitting beside
		## the chair she was standing at rather than on it.
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = chair
	return nearest


func _chair_position(chair: Node2D) -> Vector2:
	if chair.has_method("get_sit_position"):
		return chair.get_sit_position()
	var anchor := chair.get_node_or_null("SitAnchor") as Node2D
	return anchor.global_position if anchor != null else chair.global_position

## Arms the next swing. Call from an attack state's on_enter.
func beginAttack():
	_swing_connected = false

##attack enemy body when the swing reaches its hit frame
func playerAttack(hit_frame: int = 3):
	## on_process runs many times per animation frame, so without this guard a
	## single swing landed once per rendered frame the clip sat on hit_frame.
	if _swing_connected or animated_sprite.frame < hit_frame:
		return
	_swing_connected = true
	## Targets come from the live blade overlap on the actual hit frame, so a
	## monster that has already backed off is not hit and every breakable in
	## range responds. Ordinary body contact is still harmless.
	##
	## Asked of the character rather than resolved here: a state should not know
	## where the player keeps its hitboxes, and this used to re-walk a hardcoded
	## node path on every swing.
	if not pc.has_method("blade_targets"):
		return
	for body in pc.blade_targets():
		body.take_damage(pc.damage)

##Math Functions
func round_to_dec(num, digit):
	return round(num * pow(10.0, digit)) / pow(10.0, digit)
	
