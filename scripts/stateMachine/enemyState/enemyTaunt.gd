extends EnemyState

## Saying its line. The monster is rooted here, facing the player, until the
## player dismisses the dialogue — then it goes hunting.
##
## Entered only from EnemyBase.provoke(); nothing transitions into it on its
## own. Damage taken during the taunt still lands but does not knock the
## monster into `hurt`, so a swing cannot cut the line off mid-sentence.

## Failsafe. If the timeline never reports back — plugin disabled, timeline
## missing, dialogue node freed — the monster starts fighting anyway rather
## than standing there permanently.
const MAX_WAIT: float = 30.0

var _elapsed: float = 0.0
var _finished: bool = false


func on_enter() -> void:
	enemy.stop()
	_elapsed = 0.0
	_finished = false
	enemy.face(enemy.direction_to_player())

	var taunt := enemy.taunt
	if is_instance_valid(taunt):
		taunt.taunt_finished.connect(_on_taunt_finished, CONNECT_ONE_SHOT)
	else:
		## No component to wait on, so there is nothing to say.
		_finished = true


func on_physics_process(delta: float) -> void:
	enemy.stop()
	## Keep looking at the player even if they circle while talking.
	enemy.face(enemy.direction_to_player())
	enemy.play_loop("idle")

	_elapsed += delta
	if _finished or _elapsed >= MAX_WAIT:
		change_state("walk")


func on_exit() -> void:
	var taunt := enemy.taunt
	## The connection is ONE_SHOT, but leaving early (death mid-sentence)
	## means it never fired and would outlive this state.
	if is_instance_valid(taunt) and taunt.taunt_finished.is_connected(_on_taunt_finished):
		taunt.taunt_finished.disconnect(_on_taunt_finished)


func _on_taunt_finished() -> void:
	_finished = true
