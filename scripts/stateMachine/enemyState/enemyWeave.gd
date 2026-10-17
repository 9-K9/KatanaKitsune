extends EnemyState

## The bubble dance — a heal you are meant to interrupt.
##
## Jorogumo and Yuki Onna both carry Bubble_Dance, and it is far too long and
## far too pretty to be an attack. So it is a channel: she backs off, dances,
## and comes back up with health. Left alone it is a real swing in her favour.
##
## The cost is that she is rooted, not guarding, and not watching. Any hit
## breaks it and she keeps nothing — so it reads as an invitation rather than a
## punish, which is the point. A heal that could not be stopped would just be
## a longer fight.
##
## Entered on a timer when she is hurt and out of the player's reach, never
## while being hit; see the entry check in enemyWalk.
##
## Taking a hit sends her to "hurt", which leaves this state and ends the
## channel. Whatever ticked through before the interrupt she keeps — granting it
## all at the end would make a late interrupt worth exactly as much as an early
## one, and there would be no reason to rush.

## Fraction of max_health restored across a full channel.
@export var heal_fraction: float = 0.35
## Health is granted in steps rather than at the end, so an interrupt partway
## through is worth something to her and the player can see it ticking up.
@export var ticks: int = 6

var _granted: int = 0
var _start_health: float = 0.0


func on_enter() -> void:
	_granted = 0
	_start_health = enemy.health
	enemy.stop()
	## Facing the player while channelling: she is taunting, not hiding.
	enemy.face(enemy.direction_to_player())
	enemy.play_once("taunt", 0.5)


func on_physics_process(_delta: float) -> void:
	enemy.stop()
	var total: float = enemy.max_health * heal_fraction
	var per: float = total / float(maxi(ticks, 1))
	## Tie progress to the animation rather than a timer, so a redrawn clip
	## changes the channel length with it and the two cannot drift apart.
	var frames: int = maxi(enemy.animated_sprite.sprite_frames.get_frame_count(
			enemy.animated_sprite.animation), 1)
	var due: int = int(float(enemy.animated_sprite.frame) / float(frames) * float(ticks))
	while _granted < due and _granted < ticks:
		_granted += 1
		enemy.health = minf(enemy.health + per, enemy.max_health)
	enemy._refresh_health_bar()

	if enemy.animation_finished():
		change_state("walk")
