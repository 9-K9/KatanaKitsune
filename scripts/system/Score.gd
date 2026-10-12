extends Node

## The run's score, the kill streak that drives it, and the high score table.
##
## Autoloaded beside Roster. Scored per slot, so a party competes on the same
## screen rather than sharing one number.
##
## The streak is the spine of the whole thing. A kill opens a short window of
## invulnerability; killing again inside that window extends it and climbs the
## grade. So the aggressive line is also the safe line, and standing back to
## pick enemies off one at a time scores least. Everything else — tier weight,
## wave bonus, stealth, speed — multiplies through the grade.

signal score_changed(slot: int)
signal grade_changed(slot: int, grade: String)

## How long a kill protects you, and how long you have to extend the streak.
## One number for both on purpose: the window you are safe in is exactly the
## window you must kill in, so the protection and the pressure are the same.
@export var streak_window: float = 2.2
## Capped so a long chain cannot run away with the score.
@export var max_multiplier: float = 8.0

## Grades by streak length, worst first. Thresholds rather than a curve, because
## a letter that changes at a legible moment is the point of showing one.
const GRADES: Array[Dictionary] = [
	{"at": 0,  "name": "-"},
	{"at": 2,  "name": "D"},
	{"at": 4,  "name": "C"},
	{"at": 7,  "name": "B"},
	{"at": 11, "name": "A"},
	{"at": 16, "name": "S"},
	{"at": 22, "name": "SS"},
	{"at": 30, "name": "SSS"},
]

## What a kill is worth before any multiplier, by the enemy's tier.
const TIER_VALUE: Array[int] = [100, 160, 240, 360, 600, 1500]
## A flat bonus per wave, scaling with how deep the run has gone.
const WAVE_BONUS: int = 250
## Extra for a kill made from stealth, so the sneak meter has a scoring reason.
const STEALTH_BONUS: int = 150
## Clearing a wave quickly pays this at best, tapering to nothing by SLOW_AT.
const SPEED_BONUS: int = 400
const FAST_AT: float = 20.0
const SLOW_AT: float = 90.0

const SAVE_PATH := "user://highscores.cfg"
const TABLE_SIZE: int = 10

## Per slot, for the run in progress.
var points: Array[int] = [0, 0, 0, 0]
var floor_kills: Array[int] = [0, 0, 0, 0]
var run_kills: Array[int] = [0, 0, 0, 0]
var streak: Array[int] = [0, 0, 0, 0]
var _streak_left: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _grade: Array[String] = ["-", "-", "-", "-"]

## [{"name": String, "points": int, "wave": int}], best first.
var table: Array[Dictionary] = []


func _ready() -> void:
	_load_table()


func _process(delta: float) -> void:
	for slot in 4:
		if _streak_left[slot] <= 0.0:
			continue
		_streak_left[slot] -= delta
		if _streak_left[slot] <= 0.0:
			## The chain lapsed. The grade falls away with it.
			streak[slot] = 0
			_set_grade(slot, "-")


## Starts a fresh run. Called when a game begins, not when a wave does.
func begin_run() -> void:
	points = [0, 0, 0, 0]
	run_kills = [0, 0, 0, 0]
	begin_floor()
	streak = [0, 0, 0, 0]
	_streak_left = [0.0, 0.0, 0.0, 0.0]
	_grade = ["-", "-", "-", "-"]
	for slot in 4:
		score_changed.emit(slot)
		grade_changed.emit(slot, "-")


func begin_floor() -> void:
	floor_kills = [0, 0, 0, 0]


## A monster died. `tier` is 1-6; `stealth` means it never saw it coming.
func killed(slot: int, tier: int, stealth: bool = false) -> void:
	if slot < 0 or slot > 3:
		return
	floor_kills[slot] += 1
	run_kills[slot] += 1
	streak[slot] += 1
	_streak_left[slot] = streak_window

	var base: int = TIER_VALUE[clampi(tier - 1, 0, TIER_VALUE.size() - 1)]
	if stealth:
		base += STEALTH_BONUS
	points[slot] += int(round(float(base) * multiplier(slot)))
	_set_grade(slot, _grade_for(streak[slot]))
	score_changed.emit(slot)


## Is this player inside their post-kill window. The character asks this before
## taking damage, which is what makes a chain protective as well as scoring.
func protected(slot: int) -> bool:
	return slot >= 0 and slot <= 3 and _streak_left[slot] > 0.0


## Breaks the chain. Taking a hit should cost the streak even though the window
## is called invulnerability — the protection is for the moment between kills,
## not a shield to stand behind.
func broke(slot: int) -> void:
	if slot < 0 or slot > 3:
		return
	streak[slot] = 0
	_streak_left[slot] = 0.0
	_set_grade(slot, "-")


## Scales with the chain, capped so a long run cannot run away with it.
func multiplier(slot: int) -> float:
	if slot < 0 or slot > 3:
		return 1.0
	return minf(1.0 + float(streak[slot]) * 0.25, max_multiplier)


func grade_of(slot: int) -> String:
	return _grade[slot] if slot >= 0 and slot <= 3 else "-"


## How much of the post-kill window is left, 0 to 1, for drawing it.
func window_left(slot: int) -> float:
	if slot < 0 or slot > 3 or streak_window <= 0.0:
		return 0.0
	return clampf(_streak_left[slot] / streak_window, 0.0, 1.0)


## Everyone banks a wave bonus, and a speed bonus that tapers with the clock.
func wave_cleared(wave: int, seconds: float) -> void:
	var speed: float = clampf(
			1.0 - (seconds - FAST_AT) / (SLOW_AT - FAST_AT), 0.0, 1.0)
	var bonus: int = WAVE_BONUS * wave + int(round(SPEED_BONUS * speed))
	for slot in maxi(Roster.count(), 1):
		points[slot] += bonus
		score_changed.emit(slot)


## ------------------------------------------------------------- high scores

## Where this run's best player would land in the table, or -1 for nowhere.
func would_place(value: int) -> int:
	for i in table.size():
		if value > table[i]["points"]:
			return i
	return table.size() if table.size() < TABLE_SIZE else -1


func submit(name: String, value: int, wave: int) -> void:
	table.append({"name": name.substr(0, 9).strip_edges().to_upper(),
			"points": value, "wave": wave})
	table.sort_custom(func(a, b): return a["points"] > b["points"])
	if table.size() > TABLE_SIZE:
		table.resize(TABLE_SIZE)
	_save_table()


## The best score in the run that just ended, and whose it was.
func best_of_run() -> Dictionary:
	var slot: int = 0
	for i in maxi(Roster.count(), 1):
		if Roster.is_bot(i):
			continue
		if points[i] > points[slot]:
			slot = i
	return {"slot": slot, "points": points[slot]}


func _grade_for(chain: int) -> String:
	var name: String = "-"
	for step in GRADES:
		if chain >= step["at"]:
			name = step["name"]
	return name


func _set_grade(slot: int, name: String) -> void:
	if _grade[slot] == name:
		return
	_grade[slot] = name
	grade_changed.emit(slot, name)


## Kept in user:// rather than the project, so a scoreboard is the player's and
## survives reinstalling the game.
func _load_table() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return
	table.clear()
	for i in TABLE_SIZE:
		if not file.has_section_key("scores", str(i)):
			continue
		var row = file.get_value("scores", str(i))
		if row is Dictionary and row.has("points"):
			table.append(row)


func _save_table() -> void:
	var file := ConfigFile.new()
	for i in table.size():
		file.set_value("scores", str(i), table[i])
	file.save(SAVE_PATH)
