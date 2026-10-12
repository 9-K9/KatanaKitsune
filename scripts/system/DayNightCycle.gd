class_name DayNightCycle
extends RefCounted

const PHASE_SECONDS: float = 300.0
const FADE_SECONDS: float = 20.0

var elapsed: float = 0.0


static func for_node(node: Node) -> DayNightCycle:
	var parent := node
	while parent != null:
		if "day_night" in parent:
			return parent.day_night as DayNightCycle
		parent = parent.get_parent()
	return null


func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		push_error("DayNightCycle: delta must be finite and nonnegative.")
		return
	elapsed += delta


func is_night() -> bool:
	return fposmod(elapsed, PHASE_SECONDS * 2.0) >= PHASE_SECONDS


func seconds_remaining() -> float:
	return PHASE_SECONDS - fposmod(elapsed, PHASE_SECONDS)


func night_weight() -> float:
	if elapsed < PHASE_SECONDS:
		return 0.0
	var fraction: float = clampf(fposmod(elapsed, PHASE_SECONDS) / FADE_SECONDS, 0.0, 1.0)
	var blend: float = fraction * fraction * (3.0 - 2.0 * fraction)
	return blend if is_night() else 1.0 - blend


func player_damage_factor(stealth_strike: bool, katana_strike: bool) -> float:
	if (is_night() and stealth_strike) or (not is_night() and katana_strike and not stealth_strike):
		return 1.25
	return 1.0


func sneak_cost_factor() -> float:
	return 0.75 if is_night() else 1.0


func stamina_cost_factor(katana_drawn: bool) -> float:
	return 0.75 if not is_night() and katana_drawn else 1.0


func run_factor(ninja: bool) -> float:
	return 1.2 if ninja == is_night() else 1.0


func sight_factor() -> float:
	return 0.75 if is_night() else 1.25


func hostile_damage_factor() -> float:
	return 2.0 if is_night() else 1.0
