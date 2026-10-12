extends PlayerClass

## Hold Attack to wind up, release to swing. Damage scales with how long it was
## held, so the cost is standing still while something walks at her.
const MAX_CHARGE: float = 1.4
const MAX_BONUS: float = 3.0
const SWING_RATE: float = 1.25
## The blade is coming down by frame 2. It landed on 3 before, which is after
## the arc has passed through — the hit registered once the swing was already
## finishing rather than on the way down.
const HIT_FRAME: int = 2

var _charge: float = 0.0
var _released: bool = false

func on_enter():
	pc.speed = 0.0
	pc.actionBlockInput = true
	_charge = 0.0
	_released = false
	attack_damage_multiplier = 1.0

func on_process(delta):
	if not _released:
		_charge = minf(_charge + delta, MAX_CHARGE)
		## The wind-up loops, so it can be held without running out of frames.
		stateAnimation("katanaChargeAttack")
		## Brightens as it winds up, so the charge is readable without a meter.
		var glow: float = 1.0 + _charge / MAX_CHARGE
		animated_sprite.modulate = Color(glow, 1.0, 1.0)
		if not pc.input.pressed("Attack"):
			_release()
		return
	playerAttack(HIT_FRAME)

func on_physics_process(_delta):
	if _released and action_timer.is_stopped():
		## The swing has played out in full. The untouched-swing arc throw was
		## disabled — it did not read right in play and was not pulling its
		## weight — so this just returns to idle now.
		change_state("katanaIdle")

func _release() -> void:
	_released = true
	animated_sprite.modulate = Color.WHITE
	attack_damage_multiplier = 1.0 + (MAX_BONUS - 1.0) * (_charge / MAX_CHARGE)
	beginAttack()
	## The swing itself is a one-shot, and must outlast the clip it plays.
	action_timer.wait_time = play_oneshot("katanaSlashMid", SWING_RATE)
	action_timer.start()
	_sync_weapon_tween("katanaSlashMid", SWING_RATE)

func on_exit():
	animated_sprite.modulate = Color.WHITE
	animated_sprite.speed_scale = 1.0
	attack_damage_multiplier = 1.0
	pc.actionBlockInput = false
	action_timer.stop()
	_reset_weapon_tween()
