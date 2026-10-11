class_name Scroll
extends RefCounted

## The six power-up scrolls: what each one is called, the kanji painted on it,
## and its icon. One table, so the pickup, the inventory bar and the player's
## effects all agree on what a kind means.
##
## The effects themselves live on the player (AnimatedCharacterClass.use_scroll)
## because every one of them is a change to her — her health, her meters, her
## speed, her blade. Durations and strengths are exports there.

enum Kind { INVINCIBLE, EXERTION, INVISIBLE, SPEED, ATTACK, STONE }

const COUNT: int = 6

const NAMES: PackedStringArray = [
	"Invincibility", "Exertion", "Invisibility", "Swiftness", "Might", "Stone",
]
const KANJI: PackedStringArray = ["無", "気", "隠", "速", "剛", "石"]

## Matches the ink each kanji is painted in, so lights and HUD timers read as
## the same scroll at a glance.
const INK: Array[Color] = [
	Color(0.77, 0.55, 0.08), Color(0.16, 0.51, 0.24), Color(0.43, 0.24, 0.63),
	Color(0.12, 0.43, 0.67), Color(0.71, 0.12, 0.12), Color(0.45, 0.45, 0.50),
]

const ICONS: Array[Texture2D] = [
	preload("res://assets/sprites/ui/scrolls/scroll_invincible.png"),
	preload("res://assets/sprites/ui/scrolls/scroll_exertion.png"),
	preload("res://assets/sprites/ui/scrolls/scroll_invisible.png"),
	preload("res://assets/sprites/ui/scrolls/scroll_speed.png"),
	preload("res://assets/sprites/ui/scrolls/scroll_attack.png"),
	preload("res://assets/sprites/ui/scrolls/scroll_stone.png"),
]


static func icon(kind: int) -> Texture2D:
	return ICONS[kind] if kind >= 0 and kind < COUNT else null


static func random_kind() -> int:
	return randi() % COUNT
