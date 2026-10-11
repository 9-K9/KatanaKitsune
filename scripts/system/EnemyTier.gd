class_name EnemyTier
extends RefCounted

## What a monster of a given rung can do, and how hard it hits.
##
## One table rather than six subclasses. Every tier reuses the same state
## machine; what changes is which behaviours are switched on and what the
## numbers are. A subclass per tier would mean six copies of the chase logic
## drifting apart the first time one of them needed a fix.
##
## Tier is set on the monster scene; the generator reads it to decide what to
## place at a given wave.

## chase: the multiple of move_speed used while hunting when the scene sets no
##        run_speed. Never below RUN_PACE: every hunter runs.
## guards: will raise a block and take reduced damage from the front.
## phases: sees and walks through walls, and never loses the scent. No tier
##         grants it; Yuki Onna sets it in her species_traits.
## duellist: the full katana kit — draws, blocks, charges.
## stealth_weak: takes extra from a strike it never saw coming.
const TABLE: Array[Dictionary] = [
	## 1 — the shambling dead. What the game already had.
	{"chase": 1.00, "guards": false, "phases": false, "duellist": false,
	 "stealth_weak": 1.0, "health": 1.00, "damage": 1.00, "name": "SHAMBLER"},
	## 2 — runs you down. The first thing that punishes standing still.
	{"chase": 1.95, "guards": false, "phases": false, "duellist": false,
	 "stealth_weak": 1.0, "health": 1.05, "damage": 1.10, "name": "RUNNER"},
	## 3 — runs and guards, so it has to be opened up rather than swung at.
	{"chase": 1.80, "guards": true, "phases": false, "duellist": false,
	 "stealth_weak": 1.0, "health": 1.30, "damage": 1.20, "name": "WARDEN"},
	## 4 — tough and hits hard, but no new tricks. Walking through walls used
	## to live here and could land on any monster; it is Yuki Onna's alone now
	## (her species_traits), since only a ghost should ignore stone.
	{"chase": 1.80, "guards": false, "phases": false, "duellist": false,
	 "stealth_weak": 1.0, "health": 1.60, "damage": 1.45, "name": "BRUTE"},
	## 5 — her equal. Draws, blocks, charges.
	{"chase": 1.70, "guards": true, "phases": false, "duellist": true,
	 "stealth_weak": 1.0, "health": 2.20, "damage": 1.70, "name": "SPIRIT"},
	## 6 — the boss. Faster and stronger than her, and only one way in: it
	## never learned to watch its own back.
	{"chase": 2.10, "guards": true, "phases": false, "duellist": true,
	 "stealth_weak": 3.0, "health": 4.00, "damage": 2.10, "name": "YOKAI LORD"},
]


static func of(tier: int) -> Dictionary:
	return TABLE[clampi(tier - 1, 0, TABLE.size() - 1)]


## Which tiers may appear on a given wave, and how likely each is.
##
## Weighted rather than stepped: wave one is pure tier 1, and higher rungs phase
## in as the count climbs while the lower ones stay present in numbers. Stepping
## one tier per wave would show the whole bestiary in six waves and make every
## wave read as one note.
static func weights_for(wave: int) -> Array[float]:
	var out: Array[float] = []
	for tier in range(1, TABLE.size() + 1):
		## Each tier starts appearing three waves after the one below it, then
		## climbs towards a share of the pool rather than taking it over.
		## Every two waves rather than three: at three, waves one to five were all
		## tier one and the bestiary did not start showing until wave six.
		var opens: int = (tier - 1) * 2
		var since: float = float(wave - opens)
		out.append(0.0 if since <= 0.0 else minf(since * 0.35, 1.0) / float(tier))
	return out


## Rolls a tier for one monster on this wave.
static func roll(wave: int, rng: RandomNumberGenerator) -> int:
	var weights := weights_for(wave)
	var total: float = 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return 1
	var pick: float = rng.randf() * total
	for i in weights.size():
		pick -= weights[i]
		if pick <= 0.0:
			return i + 1
	return 1


## Bosses on their own schedule rather than from the pool, so a boss wave is an
## event you can feel coming instead of a roll that happened to go badly.
static func is_boss_wave(wave: int, every: int = 5) -> bool:
	return wave > 0 and wave % every == 0
