extends EnemyState

## A hop backwards out of reach.
##
## Jorogumo steps and spins, the kickers backflip, Yuki Onna jumps. Different
## clips, same intent: break the distance an attacker just closed. Entered when
## something swings and the monster has the footwork to answer it.

@export var distance: float = 120.0
## Clip to play. Every monster calls it "dodge"; the art behind it differs.
@export var clip: String = "dodge"
## Roughly how long the clip runs. Turns `distance` into a speed, so tuning the
## hop means saying how far it goes rather than how fast.
@export var duration: float = 0.4

var _dir: Vector2 = Vector2.ZERO


func on_enter() -> void:
	## Away from the player, measured once — a dodge that re-aimed every frame
	## would curve around her instead of leaving.
	_dir = -enemy.direction_to_player()
	## Still facing her while retreating: a monster that turns its back reads as
	## fleeing, and these are not fleeing.
	enemy.face(enemy.direction_to_player())
	enemy.play_once(clip)


func on_physics_process(_delta: float) -> void:
	enemy.move_towards(_dir, distance / maxf(duration, 0.05))
	if enemy.animation_finished():
		change_state("walk")


func on_exit() -> void:
	enemy.stop()
