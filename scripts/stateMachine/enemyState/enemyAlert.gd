extends EnemyState

## Standing guard. The monster does not move — it turns on the spot, glancing
## in random directions, until it catches sight of the player.
##
## This is the resting state for anything that still has a line to say, and the
## state a monster falls back to when the player escapes. It replaces `idle` as
## the starting state; `idle` is kept for monsters that should just stand there.

## Seconds between glances. Randomised per turn so a row of monsters does not
## sweep in lockstep.
@export var scan_interval_min: float = 0.8
@export var scan_interval_max: float = 2.0

## Once the player is this close the monster locks on and stops glancing
## around. Left at 0 it falls back to the monster's own detection_range.
@export var notice_range: float = 0.0

const DIRECTIONS: PackedStringArray = [
	"south", "southWest", "west", "northWest",
	"north", "northEast", "east", "southEast",
]

var _next_scan_at: float = 0.0
var _locked_on: bool = false


func on_enter() -> void:
	enemy.stop()
	_locked_on = false
	_schedule_scan()


func on_physics_process(delta: float) -> void:
	enemy.stop()

	var range_to_notice: float = notice_range if notice_range > 0.0 else enemy.detection_range
	var distance: float = enemy.distance_to_player()

	if distance <= range_to_notice:
		## Seen. Turn to face the player and hold there — no more glancing.
		if not _locked_on:
			_locked_on = true
		enemy.face(enemy.direction_to_player())

		## A monster that has already said its piece has no reason to wait
		## around; it goes straight back to hunting. One that has not stays
		## put until the player provokes it.
		if enemy.taunt_done():
			change_state("walk")
			return
	else:
		_locked_on = false
		_scan(delta)

	enemy.play_loop("idle")


## Glances to a random direction on a timer. Only runs while the player is out
## of sight; once locked on the monster keeps facing them.
func _scan(delta: float) -> void:
	_next_scan_at -= delta
	if _next_scan_at > 0.0:
		return
	_schedule_scan()
	## Never pick the direction already being faced, or a turn visibly does
	## nothing and the monster looks frozen rather than watchful.
	var choices: Array = []
	for dir in DIRECTIONS:
		if dir != enemy.facing_dir:
			choices.append(dir)
	enemy.facing_dir = choices[randi() % choices.size()]


func _schedule_scan() -> void:
	_next_scan_at = randf_range(scan_interval_min, scan_interval_max)
