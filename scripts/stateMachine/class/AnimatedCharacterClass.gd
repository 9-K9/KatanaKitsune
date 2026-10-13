class_name AnimatedCharacterClass
extends CharacterBody2D

##Movement Variables
@onready var direction: Vector2 = Vector2.ZERO
@onready var facing_dir: String = "southWest"
@export var ray_w : int
@export var ray_h : int
var speed : float = 0.0
## Speeds are in pixels/second. Previously these were ~60x larger because the
## movement code multiplied by delta before move_and_slide() applied it again;
## these values reproduce the old 60fps feel exactly (5000/60, 10000/60).
@export var walkSpeed : float = 83.333
@export var runSpeed : float = 183.333
## Damage one katana swing deals. Each swing now lands exactly once (see
## PlayerClass.playerAttack), where it used to fire on every rendered frame the
## clip sat on the hit frame — hence the old 0.25 "frame rate multiplies by 4".
@export var damage : float = 25.0
##Health Variables
@export var max_health: float = 100.0
var health: float = 100.0
var is_invincible: bool = false
## Latched on the killing blow. Without it every later hit on the corpse ran
## _on_death() again and restarted the death animation from the top.
var is_dead: bool = false
## What this body collided as before it fell, so reviving puts it back exactly
## rather than guessing at a layer.
var _layer_alive: int = -1

## Set by the states that own them, read by anything that cares.
## Stealth halves how far a monster notices her from; blocking cuts damage; the
## parry window opens the counter-slash.
var stealthed: bool = false
var crouched: bool = false
var blocking: bool = false
var katana_drawn: bool = false
var parry_ready: bool = false
var block_opened_at: int = 0
## Damage let through while guarding, when the blow's origin is unknown.
@export var block_soak: float = 0.25
## Blows arriving within this cone of her facing are stopped outright.
@export var guard_arc_degrees: float = 120.0
## Blows outside the guard but within this are caught on the flank.
@export var flank_arc_degrees: float = 240.0
## What a flanking blow still costs her.
@export var flank_soak: float = 0.5
## How much of a blow a low stance turns aside without a blade in the way.
## Below 1.0 on purpose: steel stops a hit, a stance only blunts it.
@export var stance_soak: float = 0.6
## A hit landing within this many ms of raising the guard is a parry.
@export var parry_window_ms: int = 350
@export var invincibility_duration: float = 0.8

##Sneak Variables
## Staying hidden is the strongest position in the game — monsters see a third
## as far, and she guards while doing it — so it has to run out. Empty, she is
## forced upright and has to earn it back by being seen.
@export var max_sneak: float = 100.0
var sneak: float = 100.0
## Per second while hidden, by what she is doing. Creeping is nearly free — the
## meter is there to stop her crossing a whole floor at speed, not to stop her
## creeping up on one guard, and at 14/sec a few steps emptied it before she
## could even pick a target.
@export var sneak_drain: float = 3.5
## Sprinting unseen is the fastest movement in the game, so it is where the
## meter should actually be spent.
@export var sneak_run_drain: float = 12.0
## A lump sum, taken when the stealth strike lands. It kills in one hit, so it
## has to cost most of a bar rather than a fraction of a second's creeping.
@export var flair_sneak_cost: float = 35.0
## Per second once she is upright again.
@export var sneak_regen: float = 11.0

var _sneak_used_this_frame: bool = false
## Lowered by Stealth upgrades. Applies to held sneaking, not the strike's cost.
var sneak_drain_factor: float = 1.0
## Unupgraded values, captured once so applying upgrades again cannot compound.
var _progress_base: Dictionary = {}

## Where katanaSeath hands off to. Set by whoever asked for the blade to go
## away, so guarding into a sneak sheathes first instead of cutting straight
## from a raised guard to a crouch.
var sheathe_into: String = ""

## Enough left to be worth hiding. A reserve rather than simply "above zero", so
## she cannot tap in and out at an empty meter and flicker between stances.
@export var sneak_entry_cost: float = 18.0


func can_sneak() -> bool:
	return sneak >= sneak_entry_cost


## Spends sneak. Called by the stealth states; anything not calling it lets the
## meter refill, so there is nothing to keep in sync.
func drain_sneak(per_second: float, delta: float) -> void:
	## Unseen by the scroll, hiding costs nothing.
	if is_invisible():
		return
	spend_sneak(per_second * delta * sneak_drain_factor)


func spend_sneak(amount: float) -> void:
	var cycle := DayNightCycle.for_node(self)
	var factor: float = cycle.sneak_cost_factor() if cycle != null else 1.0
	sneak = maxf(sneak - amount * factor, 0.0)
	_sneak_used_this_frame = true


func phase_run_speed(ninja: bool) -> float:
	var cycle := DayNightCycle.for_node(self)
	return runSpeed * (cycle.run_factor(ninja) if cycle != null else 1.0)


func phase_attack_damage(stealth_strike: bool, katana_strike: bool) -> float:
	var cycle := DayNightCycle.for_node(self)
	return damage * (cycle.player_damage_factor(stealth_strike, katana_strike) if cycle != null else 1.0)


func recover_sneak(delta: float) -> void:
	if not _sneak_used_this_frame:
		sneak = minf(sneak + sneak_regen * delta, max_sneak)
	_sneak_used_this_frame = false


## Nothing left to hide with.
func sneak_spent() -> bool:
	return sneak <= 0.0


##Stamina Variables
## Running spends it, standing still returns it. Empty, she can only manage a
## jog — so a long chase costs her the speed to get out of the next one.
@export var max_stamina: float = 100.0
var stamina: float = 100.0
## Per second while moving. A sprint costs more than the jog it outpaces.
@export var run_drain: float = 16.0
@export var sprint_drain: float = 26.0
@export var stamina_regen: float = 22.0
## Nothing comes back for a moment after spending, so tapping Run cannot be used
## to dodge the cost of holding it.
@export var stamina_regen_delay: float = 0.8
## Below this there is not enough left to break into a run.
@export var stamina_floor: float = 4.0
## Health recovered per second while sitting.
@export var rest_regen: float = 7.0

var _stamina_rested_for: float = 0.0


## Spends at a rate, for states holding a cost open across frames.
func drain_stamina(per_second: float, delta: float) -> void:
	## Exertion holds the meter full rather than merely pausing it, so the scroll
	## also rescues her from an already winded state.
	if scroll_active(Scroll.Kind.EXERTION):
		stamina = max_stamina
		return
	var cycle := DayNightCycle.for_node(self)
	var factor: float = cycle.stamina_cost_factor(katana_drawn) if cycle != null else 1.0
	stamina = maxf(stamina - per_second * delta * factor, 0.0)
	_stamina_rested_for = 0.0




## Called every physics frame. Draining resets the rest timer, so a state that
## is spending suppresses regen without having to coordinate with this.
func recover_stamina(delta: float) -> void:
	_stamina_rested_for += delta
	if _stamina_rested_for >= stamina_regen_delay:
		stamina = minf(stamina + stamina_regen * delta, max_stamina)


## Too spent to run.
func winded() -> bool:
	return stamina <= stamina_floor


## Sitting mends her, slowly enough that stopping is a real choice.
func rest(delta: float) -> void:
	health = minf(health + rest_regen * delta, max_health)


## Timed power-ups picked up from breakables, keyed by Pickup.Kind.
## Each entry is {"multiplier": float, "until": float} in seconds of game time.
var buffs: Dictionary = {}
## Base values the multipliers are applied to, captured before any buff lands.
var _base_damage: float = 0.0
var _base_walk: float = 0.0
var _base_run: float = 0.0
##Ray Casting 
@export_node_path("AnimatedSprite2D") var _animatedSprite2D: NodePath = "../../AnimatedSprite2D"
@export_node_path("Timer") var _actionTimer: NodePath = "../../ActionTimer"
@export_node_path("RayCast2D") var _rayCast2D: NodePath = "RayCast2D"
@export_node_path("Line2D") var _debugRayCastCollision: NodePath = "RayCast2D/ActionArea/Line2D"
@export_node_path("Line2D") var _debugCircleCastCollision: NodePath = "RayCast2D/ActionArea/CollisionShape2D/Circle"
@export_node_path("CollisionShape2D") var _rayCastCollision: NodePath = "RayCast2D/ActionArea/CollisionShape2D"
@onready var rayCast2D : RayCast2D = get_node(_rayCast2D)
@onready var debugRayCastCollision : Line2D = get_node(_debugRayCastCollision)
@onready var debugCircleCastCollision : Line2D = get_node(_debugCircleCastCollision)
@onready var rayCastCollision : CollisionShape2D = get_node(_rayCastCollision)
@onready var myAnimatedSprite2D : AnimatedSprite2D = get_node(_animatedSprite2D)
@onready var myTimer : Timer = get_node(_actionTimer)
			
## Facing lookups live in IsoFacing so the player and the monsters share one
## table. Kept as methods rather than replaced at the call sites because Radar
## finds anything that can report a facing with has_method("stateDirection").

## The facing name for a rounded direction vector, or "" if it is not one of
## the eight. Callers guard on "" to leave the current facing alone.
func directionState(rnd_dir):
	return IsoFacing.name_of(rnd_dir)


## The screen vector for a facing name, or ZERO if the name is not one of the
## eight.
func stateDirection(str_dir) -> Vector2:
	return IsoFacing.vector_of(str_dir)
	
func updateRayCast2D(str_dir):
	setRayCast2D(stateDirection(str_dir)) 

##set raycast to direction of player to check interaction events
func setRayCast2D(rnd_dir):
		if directionState(rnd_dir) == "south" or directionState(rnd_dir) == "north":
			rayCast2D.target_position = rnd_dir * Vector2(ray_w,ray_w)
		else:
			rayCast2D.target_position = rnd_dir * Vector2(ray_w,ray_h)
		debugRayCastCollision.set_point_position(0, Vector2.ZERO)
		debugRayCastCollision.set_point_position(1, rayCast2D.target_position)
		rayCastCollision.position = rayCast2D.target_position
		facing_dir = directionState(rnd_dir)

## Grants (or refreshes) a timed power-up. `kind` is a Pickup.Kind.
func grant_buff(kind: int, multiplier: float, duration: float) -> void:
	_capture_base_stats()
	buffs[kind] = {
		"multiplier": multiplier,
		"until": Time.get_ticks_msec() / 1000.0 + duration,
	}
	_apply_buffs()


## Drops any power-up whose timer has run out. Cheap enough to poll, and it
## keeps expiry off a pile of one-shot timers that would need cancelling on
## death and on scene reload.
func update_buffs() -> void:
	if buffs.is_empty():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var expired: Array = []
	for kind in buffs:
		if now >= buffs[kind]["until"]:
			expired.append(kind)
	if expired.is_empty():
		return
	for kind in expired:
		buffs.erase(kind)
	_apply_buffs()


func has_buff(kind: int) -> bool:
	return buffs.has(kind)


func _capture_base_stats() -> void:
	if _base_damage > 0.0:
		return
	_base_damage = damage
	_base_walk = walkSpeed
	_base_run = runSpeed


## Recomputed from the base values every time rather than multiplied in place,
## so a buff picked up twice cannot stack its multiplier permanently.
func _apply_buffs() -> void:
	if _base_damage <= 0.0:
		return
	damage = _base_damage * _buff_multiplier(Pickup.Kind.DAMAGE) \
			* _buff_multiplier(SCROLL_BUFF + Scroll.Kind.ATTACK)
	_apply_speed()


func _apply_speed() -> void:
	var trained: float = Progression.speed_factor(_progress_slot())
	walkSpeed = _base_walk * _buff_multiplier(Pickup.Kind.SPEED) * trained
	## Swiftness is a running scroll: it lengthens her stride at speed and
	## leaves the careful walk alone.
	runSpeed = _base_run * _buff_multiplier(Pickup.Kind.SPEED) \
			* _buff_multiplier(SCROLL_BUFF + Scroll.Kind.SPEED) * trained


func _progress_slot() -> int:
	return int(get("slot")) if "slot" in self else -1


## Applies this player's run upgrades. Health is applied with depth scaling in
## MazeDemo._scale_party, since both multiply the same maximum.
func apply_progression() -> void:
	var slot := _progress_slot()
	if slot < 0:
		return
	if _progress_base.is_empty():
		_progress_base = {
			"max_stamina": max_stamina,
			"stamina_regen": stamina_regen,
			"max_sneak": max_sneak,
			"sneak_regen": sneak_regen,
		}
	var was_stamina: float = max_stamina
	max_stamina = _progress_base["max_stamina"] * Progression.stamina_factor(slot)
	stamina = clampf(stamina + max_stamina - was_stamina, 0.0, max_stamina)
	stamina_regen = _progress_base["stamina_regen"] * Progression.stamina_regen_factor(slot)
	var was_sneak: float = max_sneak
	max_sneak = _progress_base["max_sneak"] * Progression.sneak_factor(slot)
	sneak = clampf(sneak + max_sneak - was_sneak, 0.0, max_sneak)
	sneak_regen = _progress_base["sneak_regen"] * Progression.sneak_regen_factor(slot)
	sneak_drain_factor = Progression.sneak_drain_factor(slot)
	_capture_base_stats()
	_apply_speed()


func _buff_multiplier(kind: int) -> float:
	return buffs[kind]["multiplier"] if buffs.has(kind) else 1.0


## Scroll effects share the buff table and its expiry, keyed above every
## Pickup.Kind so a scroll and a walk-over orb of the same sort are two separate
## timers rather than one refreshing the other.
const SCROLL_BUFF: int = 100

@export_group("Scrolls")
@export var scroll_invincible_time: float = 8.0
@export var scroll_exertion_time: float = 15.0
@export var scroll_invisible_time: float = 10.0
@export var scroll_speed_time: float = 12.0
@export var scroll_speed_multiplier: float = 1.4
@export var scroll_attack_time: float = 12.0
@export var scroll_attack_multiplier: float = 1.6
## How long a monster struck by the charged blade stays stone.
@export var scroll_stone_time: float = 6.0
## How see-through she is while invisible. Not zero: the player still has to
## be able to find her own character.
@export var invisible_alpha: float = 0.3
@export_group("")

## Set by the Stone scroll, spent by the next blow that lands on a monster.
var stone_charged: bool = false


func scroll_active(kind: int) -> bool:
	return buffs.has(SCROLL_BUFF + kind)


## Seconds left on a scroll's effect, or 0.
func scroll_time_left(kind: int) -> float:
	if not buffs.has(SCROLL_BUFF + kind):
		return 0.0
	return maxf(buffs[SCROLL_BUFF + kind]["until"] - Time.get_ticks_msec() / 1000.0, 0.0)


## The full length of a scroll's effect, for drawing how much is left.
func scroll_duration(kind: int) -> float:
	match kind:
		Scroll.Kind.INVINCIBLE: return scroll_invincible_time
		Scroll.Kind.EXERTION: return scroll_exertion_time
		Scroll.Kind.INVISIBLE: return scroll_invisible_time
		Scroll.Kind.SPEED: return scroll_speed_time
		Scroll.Kind.ATTACK: return scroll_attack_time
		Scroll.Kind.STONE: return scroll_stone_time
	return 0.0


func is_invisible() -> bool:
	return scroll_active(Scroll.Kind.INVISIBLE)


## Reads a scroll. False when it would do nothing — the blade is already
## charged with stone — so the caller can keep it rather than waste it.
## Reading one that is already burning starts its timer again.
func use_scroll(kind: int) -> bool:
	if is_dead:
		return false
	match kind:
		Scroll.Kind.STONE:
			if stone_charged:
				return false
			stone_charged = true
		Scroll.Kind.SPEED:
			grant_buff(SCROLL_BUFF + kind, scroll_speed_multiplier, scroll_speed_time)
		Scroll.Kind.ATTACK:
			grant_buff(SCROLL_BUFF + kind, scroll_attack_multiplier, scroll_attack_time)
		Scroll.Kind.EXERTION:
			grant_buff(SCROLL_BUFF + kind, 1.0, scroll_exertion_time)
			stamina = max_stamina
		Scroll.Kind.INVISIBLE:
			grant_buff(SCROLL_BUFF + kind, 1.0, scroll_invisible_time)
			## Anything already on her trail loses it outright, not just the
			## ones that would have looked again.
			for node in get_tree().get_nodes_in_group("enemy"):
				if node.has_method("forget_player"):
					node.forget_player(self)
		Scroll.Kind.INVINCIBLE:
			grant_buff(SCROLL_BUFF + kind, 1.0, scroll_invincible_time)
		_:
			return false
	return true


## Spends the stone charge, if there is one. Called by the swing that lands.
func spend_stone_charge() -> bool:
	if not stone_charged:
		return false
	stone_charged = false
	return true


## What the active scrolls look like on her. self_modulate rather than
## modulate, so the hit-flash tween on modulate:a still plays over the top.
func update_scroll_look() -> void:
	if not is_instance_valid(myAnimatedSprite2D):
		return
	var look := Color.WHITE
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.5)
	if scroll_active(Scroll.Kind.INVINCIBLE):
		look = Color(1.0, 0.92, 0.6).lerp(Color(1.45, 1.25, 0.7), pulse)
	elif stone_charged:
		look = Color(1.0, 1.0, 1.0).lerp(Color(0.75, 0.78, 0.85), pulse)
	if is_invisible():
		look.a = invisible_alpha
	myAnimatedSprite2D.self_modulate = look


## `from` is where the blow came from, which decides what the guard is worth.
## Optional so anything that simply loses health — breakables, scripted damage —
## can still call this with one argument.
## `guardable` is false for damage there is no stance against — spikes coming up
## through the floor, say. Without it, the sneak-as-defence rule quietly made
## crouching a discount on trap damage, because a blow with no source falls
## through to the flat soak.
## The monster that last swung at her and when, so AI teammates can tell who
## is picking on whom. Recorded before any guard or ward, because a blocked
## blow is still an attack worth answering.
var last_hurt_by: WeakRef = null
var last_hurt_at_ms: int = -1


func hurt_recently_by(enemy: Node, window_ms: int = 4000) -> bool:
	return last_hurt_by != null and last_hurt_by.get_ref() == enemy \
			and Time.get_ticks_msec() - last_hurt_at_ms <= window_ms


func attacker_recent(window_ms: int = 4000) -> Node2D:
	if last_hurt_by == null or Time.get_ticks_msec() - last_hurt_at_ms > window_ms:
		return null
	var enemy := last_hurt_by.get_ref() as Node2D
	return enemy if is_instance_valid(enemy) and enemy.get("is_dead") != true else null


func _note_attacker(from: Vector2) -> void:
	if from == Vector2.INF or not is_inside_tree():
		return
	var best: Node2D = null
	var best_distance: float = 260.0 * 260.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Node2D) or enemy.get("is_dead") == true:
			continue
		var d: float = (enemy as Node2D).global_position.distance_squared_to(from)
		if d < best_distance:
			best = enemy
			best_distance = d
	if best != null:
		last_hurt_by = weakref(best)
		last_hurt_at_ms = Time.get_ticks_msec()


func take_damage(amount: float, from: Vector2 = Vector2.INF,
		guardable: bool = true) -> void:
	if NetworkManager.is_client:
		return
	_note_attacker(from)
	if CheatManager.immortality_enabled:
		return
	## The Invincibility scroll: nothing gets through while it burns, and it is
	## not spent by being hit the way a ward is.
	if scroll_active(Scroll.Kind.INVINCIBLE):
		return
	## A ward soaks the hit entirely rather than reducing it, so the player can
	## see it working.
	if has_buff(Pickup.Kind.WARD):
		buffs.erase(Pickup.Kind.WARD)
		_start_invincibility()
		return
	if is_invincible or is_dead:
		return
	## Inside a kill streak's window. Separate from is_invincible rather than
	## reusing it, so the two cannot stack into permanent protection — and so a
	## blow still breaks the chain even though it did no damage. The window is
	## for the moment between kills, not a shield to stand behind.
	if "slot" in self and Score.protected(get("slot")):
		Score.broke(get("slot"))
		_start_invincibility()
		return
	## Sneaking is a guard of its own: low, turned side-on, watching. She reads
	## a blow coming the same way a raised blade does, so the same arc applies
	## without needing the katana out. It is simply worth less.
	if guardable and (blocking or stealthed or crouched):
		amount = _guarded(amount, from)
		if amount <= 0.0:
			return
	if amount > 0.0 and from != Vector2.INF:
		HitEffects.blood(get_parent(), global_position + Vector2(0, -40), from, amount,
				global_position - from)
	health -= amount
	health = max(health, 0)
	if health <= 0:
		is_dead = true
		_on_death()
	else:
		_start_invincibility()

## Falls out of the world's collision so the living can walk over the body.
##
## Deferred because this is reached from inside a physics callback, and changing
## a body's layer mid-step is the classic way to crash Godot's space.
func collapse() -> void:
	if _layer_alive < 0:
		_layer_alive = collision_layer
	set_deferred("collision_layer", 0)


## Back on her feet with a share of her health. The caller decides what that
## costs; this only puts the body back together.
func revive(fraction: float = 0.5) -> void:
	if not is_dead:
		return
	is_dead = false
	health = maxf(max_health * fraction, 1.0)
	if _layer_alive >= 0:
		set_deferred("collision_layer", _layer_alive)
	is_invincible = false
	## Belt and braces: this is the function that promises to put the body back
	## together, so it should not depend on which state happened to be blocking.
	if "actionBlockInput" in self:
		set("actionBlockInput", false)
	var machine := get_node_or_null("FiniteStateMachine")
	if machine != null and machine.has_method("change_state"):
		machine.change_state("idle")


## What a raised guard does to a blow, by where it landed.
##
## A shield is a direction, not a discount. Meeting a blow head-on stops it
## outright; catching one on the flank only blunts it; nothing stops a blade in
## the back. Without this, holding Defend cut every hit from every angle by the
## same amount and facing did not matter.
func _guarded(amount: float, from: Vector2) -> float:
	## No source given, so fall back to the old flat soak rather than guessing.
	if from == Vector2.INF:
		if Time.get_ticks_msec() - block_opened_at <= parry_window_ms:
			parry_ready = true
			return 0.0
		return amount * block_soak

	## A raised blade stops a blow; a low stance only rides it. Without this,
	## crouching would be as good as guarding and the katana would be pointless
	## on defence.
	var unarmed: float = 1.0 if blocking else stance_soak
	var off: float = rad_to_deg(absf(_angle_off_facing(from)))
	if off <= guard_arc_degrees * 0.5:
		## Met square on. A blow arriving inside the parry window also opens the
		## riposte; later ones are simply stopped.
		if blocking and Time.get_ticks_msec() - block_opened_at <= parry_window_ms:
			parry_ready = true
		return amount * (1.0 - unarmed)
	if off <= flank_arc_degrees * 0.5:
		return amount * (flank_soak if blocking else 1.0 - stance_soak * 0.5)
	## From behind. The guard is not in the way at all.
	return amount


## Degrees between the way she is facing and the direction a blow came from.
func _angle_off_facing(from: Vector2) -> float:
	var facing: Vector2 = stateDirection(facing_dir)
	if facing == Vector2.ZERO:
		## Unknown facing fails safe, not open. Returning 0.0 here meant "dead
		## ahead", so a facing_dir that was not one of the eight names made every
		## blow from every direction read as a perfect frontal block and she took
		## no damage at all. PI is behind her, which is the unguarded case.
		return PI
	var toward: Vector2 = from - global_position
	if toward.length_squared() < 1.0:
		return 0.0
	## Both unsquashed, or the arc would be far wider up and down the screen
	## than across it — the same correction the monsters' vision uses.
	toward.y /= 0.5
	facing.y /= 0.5
	return toward.normalized().angle_to(facing.normalized())


func _start_invincibility() -> void:
	is_invincible = true
	# Visual feedback - flash the sprite
	var tween = create_tween()
	tween.tween_property(myAnimatedSprite2D, "modulate:a", 0.5, 0.1)
	tween.tween_property(myAnimatedSprite2D, "modulate:a", 1.0, 0.1)
	tween.set_loops(4)  # Flash 4 times over ~0.8s
	## Bound to this body so a body freed mid-flash never resumes a dead await.
	create_tween().tween_callback(_end_invincibility).set_delay(invincibility_duration)


func _end_invincibility() -> void:
	is_invincible = false

func _on_death() -> void:
	pass  # Override in subclass


## Multiplier monsters apply to their detection range when looking for her.
## Crouched is quieter than merely sneaking, which is quieter than walking.
func stealth_ratio() -> float:
	## Drawn steel catches what light there is, so she is seen from furthest away
	## with the katana out and from closest flat against the floor. That makes
	## sheathing a real decision rather than a formality.
	if is_invisible():
		return 0.0
	if crouched:
		return 0.3
	if stealthed:
		return 0.5
	return 1.5 if katana_drawn else 1.0
