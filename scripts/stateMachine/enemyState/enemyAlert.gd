extends EnemyState

## Lost her. Presses on to wherever she was last seen, then stands and looks
## around, and gives up after enemy.memory_seconds — so breaking line of sight
## buys a few seconds rather than switching the monster off instantly.

## Seconds between glances while searching. Randomised so a row of monsters does
## not sweep in lockstep.
@export var scan_interval_min: float = 0.5
@export var scan_interval_max: float = 1.2
@export var arrive_within: float = 56.0

const DIRECTIONS: PackedStringArray = [
	"south", "southWest", "west", "northWest",
	"north", "northEast", "east", "southEast",
]

var _next_scan_at: float = 0.0


func on_enter() -> void:
	_schedule_scan()


func on_physics_process(delta: float) -> void:
	## Back in sight, so straight back to hunting.
	if enemy.sees_player():
		change_state("walk")
		return

	if enemy.seconds_since_seen() >= enemy.memory_seconds:
		change_state("idle")
		return

	## Still somewhere to go: walk to where she was last standing.
	if enemy.last_known != Vector2.ZERO \
			and enemy.ground_distance_to(enemy.last_known) > arrive_within:
		var step: Vector2 = (enemy.last_known - enemy.global_position).normalized()
		enemy.face(step)
		enemy.move_towards(step, enemy.chase_speed())
		enemy.play_chase()
		return

	## Arrived and she is not here. Stand and look about for the rest of the
	## memory, which is the window she has to get somewhere else.
	enemy.stop()
	enemy.play_loop("idle")
	_scan(delta)


func _scan(delta: float) -> void:
	_next_scan_at -= delta
	if _next_scan_at > 0.0:
		return
	_schedule_scan()
	## Never the direction already faced, or the turn visibly does nothing.
	var choices: Array = []
	for dir in DIRECTIONS:
		if dir != enemy.facing_dir:
			choices.append(dir)
	enemy.facing_dir = choices[randi() % choices.size()]


func _schedule_scan() -> void:
	_next_scan_at = randf_range(scan_interval_min, scan_interval_max)
