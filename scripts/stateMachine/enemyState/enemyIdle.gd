extends EnemyState

## Wandering. Picks a spot a little way off, walks to it, stands a moment, picks
## another. This is where a monster lives until it actually sees her.
##
## Wandering rather than standing still because a static monster gives the whole
## floor away: you learn where everything is on the first pass and never have to
## look again.

@export var roam_radius: float = 280.0
@export var pause_min: float = 0.7
@export var pause_max: float = 2.2
## Close enough to call the spot reached.
@export var arrive_within: float = 48.0

var _target: Vector2 = Vector2.ZERO
var _pause_left: float = 0.0
var _giveup_left: float = 0.0


func on_enter() -> void:
	enemy.stop()
	_target = Vector2.ZERO
	_pause_left = randf_range(pause_min, pause_max)


func on_physics_process(delta: float) -> void:
	if enemy.sees_player():
		change_state("walk")
		return

	if _pause_left > 0.0:
		_pause_left -= delta
		enemy.stop()
		enemy.play_loop("idle")
		return

	if _target == Vector2.ZERO or enemy.ground_distance_to(_target) <= arrive_within:
		_choose()
		return

	## Walls are not navigated around out here — a monster that wedges itself
	## gives up after a moment and picks somewhere else rather than pushing at
	## the stone forever.
	_giveup_left -= delta
	if _giveup_left <= 0.0:
		_choose()
		return

	var step: Vector2 = (_target - enemy.global_position).normalized()
	enemy.face(step)
	## Half pace: an ambling monster reads as unaware, which is the tell that
	## she has not been spotted yet.
	enemy.move_towards(step, enemy.move_speed * 0.5)
	enemy.play_loop("walk")


func _choose() -> void:
	var angle: float = randf() * TAU
	var reach: float = randf_range(roam_radius * 0.35, roam_radius)
	## Squashed 2:1, like every other ground offset, so the spot is a real
	## distance away on the floor rather than on the screen.
	_target = enemy.global_position + Vector2(cos(angle), sin(angle) * 0.5) * reach
	_pause_left = randf_range(pause_min, pause_max)
	_giveup_left = 4.0
