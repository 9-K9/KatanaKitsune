extends EnemyState

## The backflip hook — a gamble.
##
## Karasu Shinobi and Tengu both carry Backflip_and_Hooks and
## Backflip_and_Rise. The first is a flip into a descending hook that hurts far
## more than their normal attack; the second is getting back up off the floor.
## Having both means the move can be allowed to fail.
##
## It whiffs on a roll. On a hit it is the hardest thing either of them does; on
## a miss they land badly and spend the recovery on the ground, which is a
## longer opening than any blocked attack would give. High ceiling, real floor.

@export var hit_frame: int = 8
@export var reach: float = 1.5
@export var damage_multiplier: float = 2.2
## Chance the flip lands badly. Rolled on entry so the whole move is already
## decided when it starts — a player reading the animation is reading something
## real, not a coin flipped at the moment of contact.
@export var whiff_chance: float = 0.3

var _hit: bool = false
var _whiffed: bool = false


func on_enter() -> void:
	_hit = false
	_whiffed = randf() < whiff_chance
	enemy.stop()
	enemy.face(enemy.direction_to_player())
	enemy.play_once("crit")


func on_physics_process(_delta: float) -> void:
	enemy.stop()
	if not _hit and enemy.animated_sprite.frame >= hit_frame:
		_hit = true
		if not _whiffed:
			enemy.strike(reach, damage_multiplier)
	if enemy.animation_finished():
		## A clean flip ends on its feet. A botched one has to get up first.
		change_state("arise" if _whiffed else "walk")


func on_exit() -> void:
	enemy.start_attack_cooldown()
