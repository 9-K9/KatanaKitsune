class_name SpikeTrap
extends Area2D

## Floor spikes on a cycle: retracted, a telegraph, then out and dangerous.
##
## Runs on a shared phase rather than a Timer so a corridor lined with traps
## fires in unison instead of drifting into a shimmer, and so the offset can be
## set per trap to make a wave.

enum Phase { HIDDEN, WARNING, OUT }

@export var damage: float = 15.0
## Seconds per full cycle.
@export var period: float = 2.6
## How long the spikes stay out within the cycle.
@export var out_time: float = 0.7
## Warning before they come out, so a death always feels readable.
@export var warn_time: float = 0.45
## Shifts this trap along the cycle. The generator staggers these so a row of
## traps rolls like a wave.
@export var phase_offset: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

var phase: Phase = Phase.HIDDEN
var _t: float = 0.0
## Everything standing on the trap right now. Damage is applied on the frame
## the spikes emerge, not on entry, so walking across between cycles is safe.
var _occupants: Array[Node2D] = []


func _ready() -> void:
	_t = phase_offset
	body_entered.connect(func(b): if b not in _occupants: _occupants.append(b))
	body_exited.connect(func(b): _occupants.erase(b))
	_set_phase(Phase.HIDDEN)


func _physics_process(delta: float) -> void:
	_t = fmod(_t + delta, period)
	var next: Phase = Phase.HIDDEN
	if _t >= period - out_time:
		next = Phase.OUT
	elif _t >= period - out_time - warn_time:
		next = Phase.WARNING
	if next != phase:
		_set_phase(next)


func _set_phase(next: Phase) -> void:
	phase = next
	match phase:
		Phase.HIDDEN:
			sprite.modulate = Color(0.55, 0.55, 0.6, 1.0)
			sprite.scale = Vector2(1.0, 0.35)
		Phase.WARNING:
			sprite.modulate = Color(1.0, 0.75, 0.4, 1.0)
			sprite.scale = Vector2(1.0, 0.55)
		Phase.OUT:
			sprite.modulate = Color.WHITE
			sprite.scale = Vector2(1.0, 1.0)
			_strike()


func _strike() -> void:
	for body in _occupants:
		if not is_instance_valid(body):
			continue
		## Hits monsters as readily as the player — a trap the player can bait
		## a mummy onto is more interesting than one only they can trip.
		if body.has_method("take_damage"):
			## Straight up through the floor: there is no facing that meets it,
			## so it ignores guards and stances alike.
			body.take_damage(damage, global_position, false)
