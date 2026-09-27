extends PlayerClass

## Hold Attack to wind up, release to swing. Damage scales with how long it was
## held, so the cost is standing still while something walks at her.
const MAX_CHARGE: float = 1.4
const MAX_BONUS: float = 3.0
const SWING_RATE: float = 1.25

var _charge: float = 0.0
var _base_damage: float = 0.0
var _released: bool = false

func on_enter():
	pc.speed = 0.0
	pc.actionBlockInput = true
	_charge = 0.0
	_released = false
	_base_damage = pc.damage

func on_process(delta):
	if not _released:
		_charge = minf(_charge + delta, MAX_CHARGE)
		## The wind-up loops, so it can be held without running out of frames.
		stateAnimation("katanaChargeAttack", 6)
		## Brightens as it winds up, so the charge is readable without a meter.
		var glow: float = 1.0 + _charge / MAX_CHARGE
		animated_sprite.modulate = Color(glow, 1.0, 1.0)
		if not Input.is_action_pressed("Attack"):
			_release()
		return
	playerAttack()

func on_physics_process(_delta):
	if _released and action_timer.is_stopped():
		change_state("katanaIdle")

func _release() -> void:
	_released = true
	animated_sprite.modulate = Color.WHITE
	pc.damage = _base_damage * (1.0 + (MAX_BONUS - 1.0) * (_charge / MAX_CHARGE))
	beginAttack()
	## The swing itself is a one-shot, and must outlast the clip it plays.
	action_timer.wait_time = play_oneshot("katanaSlashMid", SWING_RATE)
	action_timer.start()

func on_exit():
	animated_sprite.modulate = Color.WHITE
	animated_sprite.speed_scale = 1.0
	pc.damage = _base_damage
	pc.actionBlockInput = false
	action_timer.stop()
