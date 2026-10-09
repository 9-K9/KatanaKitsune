extends EnemyState

## A caster's ranged attack.
##
## Kappa, Jorogumo and Yuki Onna have no melee clip worth the name — their
## export carries a gesture, a spell cast and a stomp instead. Rather than give
## them a borrowed punch, they throw something that suits them: a turtle egg, a
## spirit bubble, a ball of snow.
##
## The clip is whatever the monster's scene calls "attack"; only the projectile
## differs. That keeps one state for three monsters and puts the character into
## the configuration rather than the code.

const PROJECTILE := preload("res://scenes/props/projectile.tscn")

## Frame of the cast clip the shot leaves on. Set per monster: Kappa's gesture
## releases early, Jorogumo's spell builds.
@export var release_frame: int = 7
## Art for this caster's shot.
@export var projectile_texture: Texture2D
## Pixels per second along the ground plane.
@export var projectile_speed: float = 260.0
## Multiplier on attack_damage. Ranged chip is worth less than a committed swing.
@export var damage_multiplier: float = 0.75
## Degrees per second of sprite spin — an egg tumbles, a bubble does not.
@export var projectile_spin: float = 0.0
## Vertical drift, for anything that floats rather than flies.
@export var projectile_bob_rate: float = 0.0
@export var projectile_bob_height: float = 0.0
## Where the shot leaves the body, relative to its feet.
@export var muzzle_offset: Vector2 = Vector2(0, -48)

var _fired: bool = false


func on_enter() -> void:
	_fired = false
	enemy.stop()
	enemy.face(enemy.direction_to_player())
	enemy.play_once("attack")


func on_physics_process(_delta: float) -> void:
	enemy.stop()
	## Keep tracking while winding up, so a player circling a slow caster is
	## still shot at rather than past.
	if not _fired:
		enemy.face(enemy.direction_to_player())
	if not _fired and enemy.animated_sprite.frame >= release_frame:
		_fired = true
		_fire()
	if enemy.animation_finished():
		change_state("walk")


func _fire() -> void:
	var shot: Projectile = PROJECTILE.instantiate()
	## Added to the level rather than the monster, so the shot keeps flying if
	## the caster dies or is freed mid-flight.
	enemy.get_parent().add_child(shot)
	shot.launch(
		enemy.global_position + muzzle_offset,
		enemy.direction_to_player(),
		enemy,
		{
			"texture": projectile_texture,
			"speed": projectile_speed,
			"damage": enemy.attack_damage * damage_multiplier,
			"spin": projectile_spin,
			"bob_rate": projectile_bob_rate,
			"bob_height": projectile_bob_height,
		})


func on_exit() -> void:
	enemy.start_attack_cooldown()
