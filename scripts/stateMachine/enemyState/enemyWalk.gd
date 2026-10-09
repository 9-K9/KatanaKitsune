extends EnemyState

## Hunting her. Holds this state only while she is actually in sight; the moment
## she is not, it hands over to `alert`, which keeps looking for a few seconds
## before giving up.
##
## Also the one place a monster decides what kind of monster it is. Every
## special move is chosen from here, and every choice is guarded by
## `has_state()` — a scene without the node never attempts the move, which is
## the same contract `_drop_skills_without_states` relies on. That way one walk
## state serves a kicker, a caster and a brute without any of them knowing about
## the others.

## Rolled once per decision rather than per frame, so a monster commits to an
## approach instead of flickering between them while the dice are re-thrown.

## How hurt a caster has to be before the bubble dance is worth the risk.
const WEAVE_HEALTH: float = 0.55
## And how long before she will try it again, win or lose.
const WEAVE_COOLDOWN_MS: int = 9000
## Kappa falls over on his own schedule, not hers.
const STUMBLE_MIN_MS: int = 7000
const STUMBLE_CHANCE: float = 0.012
## Hopping back out of reach while the claws reset.
const DODGE_COOLDOWN_MS: int = 3500
const DODGE_CHANCE: float = 0.06

var _weave_ready_at: int = 0
var _stumble_ready_at: int = 0
var _dodge_ready_at: int = 0


## Whether this monster was given the node for a move. Scenes differ by design:
## Tengu has no block, Kappa has no melee, only two of them can heal.
func has_state(name: String) -> bool:
	## state_machine is only assigned once this state has been entered. It always
	## has been by the time anything here runs, but a null check costs nothing
	## and a crash in the hunt loop would cost the run.
	return is_instance_valid(state_machine) and state_machine.has_node(name)


func on_physics_process(_delta: float) -> void:
	if enemy.traits.get("duellist", false) and not enemy.blade_drawn:
		change_state("draw")
		return
	if not enemy.sees_player():
		change_state("alert")
		return

	var now: int = Time.get_ticks_msec()
	var distance: float = enemy.distance_to_player()

	## Kappa's tantrum. Unprompted, on his own timer, and never because he was
	## hit — it is a gift to the player, not a reaction. He is hard to approach
	## and shoots from range; this is what he gives back.
	if has_state("stumble") and now >= _stumble_ready_at and randf() < STUMBLE_CHANCE:
		_stumble_ready_at = now + STUMBLE_MIN_MS
		change_state("stumble")
		return

	## The bubble dance. Only when hurt, only at a distance she thinks is safe,
	## and never in melee — channelling a heal under the blade would just be
	## free damage for the player rather than a decision.
	if has_state("weave") and now >= _weave_ready_at \
			and enemy.health < enemy.max_health * WEAVE_HEALTH \
			and distance > enemy.attack_range * 2.2:
		_weave_ready_at = now + WEAVE_COOLDOWN_MS
		change_state("weave")
		return

	## Guards rather than trades, but only sometimes — a duellist that blocked
	## every approach would be impassable, and one that never blocked would be
	## no different from a runner.
	if enemy.traits.get("duellist", false) and enemy.in_attack_range() \
			and enemy.attack_off_cooldown():
		var duel_move: float = randf()
		if duel_move < 0.35:
			change_state("block")
			return
		if duel_move < 0.6:
			change_state("charge")
			return

	## Face where she actually is, but walk where the path says: staring at a
	## corner while rounding it reads as the monster losing interest.
	var to_player: Vector2 = enemy.direction_to_player()
	enemy.face(to_player)

	if distance <= enemy.attack_range:
		if enemy.attack_off_cooldown():
			change_state(_pick_attack())
		else:
			## In range but still recovering. A monster with the footwork uses the
			## gap to leave rather than standing in her reach doing nothing — the
			## others hold position as before.
			if has_state("dodge") and now >= _dodge_ready_at and randf() < DODGE_CHANCE:
				_dodge_ready_at = now + DODGE_COOLDOWN_MS
				change_state("dodge")
				return
			enemy.stop()
			enemy.play_loop("idle")
		return

	var step: Vector2 = enemy.chase_direction()
	## Scaled by the rung: a runner closes, a revenant creeps and never stops.
	var pace: float = enemy.move_speed * enemy.traits.get("chase", 1.0)
	enemy.move_towards(step if step != Vector2.ZERO else to_player, pace)
	enemy.play_loop("walk")


## Which attack to open with, given what this monster can actually do.
##
## Weighted rather than uniform: the plain attack stays the common case, so the
## special move keeps its weight when it does come. A monster that stomped a
## third of the time would be read as a stomping monster rather than a brute
## that sometimes stomps.
func _pick_attack() -> String:
	var roll: float = randf()
	## Oni. The stomp is the readable one, so it is rarer than the axe.
	if has_state("stomp") and roll < 0.18:
		return "stomp"
	if has_state("heavy") and roll < 0.42:
		return "heavy"
	## The kickers. A gamble they take about a quarter of the time; the whiff is
	## rolled inside the state itself.
	if has_state("crit") and roll < 0.26:
		return "crit"
	return "attack"
