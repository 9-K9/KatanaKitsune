extends Node

## Per-player experience and upgrades for the run in progress.
##
## Stored by player slot rather than on the body: a player who dies is freed and
## recreated for the next floor, and must come back with the upgrades earned.

signal changed(slot: int)

enum Stat { HEALTH, STAMINA, SPEED, STEALTH }

const STAT_NAMES: Array[String] = ["HEALTH", "STAMINA", "SPEED", "STEALTH"]
const MAX_RANK: int = 5
const MAX_SLOTS: int = 4

## Fixed reward by species, so a kasha is always worth more than a kappa.
## Keys are the monster scene's file name.
const SPECIES_XP: Dictionary = {
	"kappa": 10,
	"karasuShinobi": 12,
	"ninaNinja": 15,
	"jorogumo": 25,
	"oni": 30,
	"tengu": 35,
	"kasha": 40,
	"yukiOnna": 60,
	"yokailord": 200,
}
## Added for each rung the spawner rolled above the species' own scene tier.
const TIER_BONUS: float = 0.15
const FIRST_LEVEL_XP: int = 80
const LEVEL_XP_STEP: int = 40

const HEALTH_PER_RANK: float = 0.10
const STAMINA_PER_RANK: float = 0.10
const STAMINA_REGEN_PER_RANK: float = 0.08
const SPEED_PER_RANK: float = 0.04
const SNEAK_PER_RANK: float = 0.10
const SNEAK_DRAIN_PER_RANK: float = 0.08
const SNEAK_REGEN_PER_RANK: float = 0.08

var level: Array[int] = [1, 1, 1, 1]
## Experience towards the next level, not lifetime experience.
var xp: Array[int] = [0, 0, 0, 0]
var total_xp: Array[int] = [0, 0, 0, 0]
var points: Array[int] = [0, 0, 0, 0]
## Levels gained since the last floor began; decides whether the screen shows.
var floor_levels: Array[int] = [0, 0, 0, 0]
var ranks: Array = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]


func begin_run() -> void:
	level = [1, 1, 1, 1]
	xp = [0, 0, 0, 0]
	total_xp = [0, 0, 0, 0]
	points = [0, 0, 0, 0]
	floor_levels = [0, 0, 0, 0]
	ranks = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
	for slot in MAX_SLOTS:
		changed.emit(slot)


func begin_floor() -> void:
	floor_levels = [0, 0, 0, 0]


static func xp_for(species: String, base_tier: int, rolled_tier: int) -> int:
	var base: int = SPECIES_XP.get(species, maxi(base_tier, 1) * 10)
	var above: int = maxi(rolled_tier - base_tier, 0)
	return int(round(float(base) * (1.0 + TIER_BONUS * float(above))))


static func xp_to_next(at_level: int) -> int:
	return FIRST_LEVEL_XP + LEVEL_XP_STEP * maxi(at_level - 1, 0)


func killed(slot: int, species: String, base_tier: int, rolled_tier: int) -> void:
	gain(slot, xp_for(species, base_tier, rolled_tier))


func gain(slot: int, amount: int) -> void:
	if not _valid(slot) or amount <= 0:
		return
	xp[slot] += amount
	total_xp[slot] += amount
	while xp[slot] >= xp_to_next(level[slot]):
		xp[slot] -= xp_to_next(level[slot])
		level[slot] += 1
		points[slot] += 1
		floor_levels[slot] += 1
	changed.emit(slot)


func levelled_this_floor(players: int) -> bool:
	for slot in clampi(players, 0, MAX_SLOTS):
		if floor_levels[slot] > 0:
			return true
	return false


func rank(slot: int, stat: int) -> int:
	return ranks[slot][stat] if _valid(slot) and stat >= 0 and stat < STAT_NAMES.size() else 0


func can_spend(slot: int, stat: int) -> bool:
	return _valid(slot) and points[slot] > 0 and rank(slot, stat) < MAX_RANK


func spend(slot: int, stat: int) -> bool:
	if not can_spend(slot, stat):
		return false
	ranks[slot][stat] += 1
	points[slot] -= 1
	changed.emit(slot)
	return true


## Undoes a point spent on the open upgrade screen.
func refund(slot: int, stat: int) -> bool:
	if rank(slot, stat) <= 0:
		return false
	ranks[slot][stat] -= 1
	points[slot] += 1
	changed.emit(slot)
	return true


func health_factor(slot: int) -> float:
	return 1.0 + HEALTH_PER_RANK * rank(slot, Stat.HEALTH)


func stamina_factor(slot: int) -> float:
	return 1.0 + STAMINA_PER_RANK * rank(slot, Stat.STAMINA)


func stamina_regen_factor(slot: int) -> float:
	return 1.0 + STAMINA_REGEN_PER_RANK * rank(slot, Stat.STAMINA)


func speed_factor(slot: int) -> float:
	return 1.0 + SPEED_PER_RANK * rank(slot, Stat.SPEED)


func sneak_factor(slot: int) -> float:
	return 1.0 + SNEAK_PER_RANK * rank(slot, Stat.STEALTH)


func sneak_drain_factor(slot: int) -> float:
	return 1.0 - SNEAK_DRAIN_PER_RANK * rank(slot, Stat.STEALTH)


func sneak_regen_factor(slot: int) -> float:
	return 1.0 + SNEAK_REGEN_PER_RANK * rank(slot, Stat.STEALTH)


## Percentage shown for a stat at the given rank.
static func bonus_text(stat: int, at_rank: int) -> String:
	match stat:
		Stat.HEALTH:
			return "+%d%% HP" % int(round(HEALTH_PER_RANK * at_rank * 100.0))
		Stat.STAMINA:
			return "+%d%% MAX" % int(round(STAMINA_PER_RANK * at_rank * 100.0))
		Stat.SPEED:
			return "+%d%% MOVE" % int(round(SPEED_PER_RANK * at_rank * 100.0))
		Stat.STEALTH:
			return "+%d%% SNEAK" % int(round(SNEAK_PER_RANK * at_rank * 100.0))
	return ""


func _valid(slot: int) -> bool:
	return slot >= 0 and slot < MAX_SLOTS
