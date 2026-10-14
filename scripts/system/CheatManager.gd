extends Node

## Cheats. Kept in an autoload so they survive scene changes, and saved to
## user:// so they survive a relaunch.
##
## Two of them:
##
## - Immortality, a development aid from the pause menu's Cheats submenu. Only
##   shown in debug builds, unless Karmageisha is on.
##
## - KARMAGEISHA, hidden in the high-score name entry. Enter that as your name
##   and the score is saved under it, then the previous heroine (Katana
##   Kitsune) takes over every player slot as a god: triple damage, faster,
##   twice the sneak meter at half the drain, immortal by default, and every
##   scroll stocked and never spent. The trade is the scoreboard: while she is
##   active a run scores nothing and the name entry still opens on game over,
##   showing 0, so entering any other name is how you turn her off again.

signal karmageisha_changed(active: bool)

const SAVE_PATH := "user://cheats.cfg"
const CODE_NAME := "KARMAGEISHA"

const GOD_DAMAGE: float = 3.0
const GOD_SPEED: float = 1.6
const GOD_SNEAK: float = 2.0
const GOD_SNEAK_DRAIN: float = 0.5
## How many of each scroll she carries. Cosmetic: read_scroll never spends one.
const GOD_SCROLL_STACK: int = 9

const GOD_SCENE := "res://scenes/characters/KatanaKitsune.tscn"
const PLAYER_SCENE := "res://scenes/characters/Kitsune.tscn"

var immortality_enabled: bool = false
var karmageisha_active: bool = false


func _ready() -> void:
	_load()


func set_immortality(enabled: bool) -> void:
	if immortality_enabled == enabled:
		return
	immortality_enabled = enabled
	_save()


func set_karmageisha(active: bool) -> void:
	if karmageisha_active == active:
		return
	karmageisha_active = active
	## She comes with immortality on; turning her off takes it with her so a
	## release build is not left immortal with no menu to switch it off.
	immortality_enabled = active
	_save()
	karmageisha_changed.emit(active)


## Whether the pause menu should offer the Cheats submenu at all.
func cheats_visible() -> bool:
	return OS.is_debug_build() or karmageisha_active


## The name typed at the end of a run. Decides between saving the score and
## toggling Karmageisha, since the two are mutually exclusive by design.
##
## - Not active, any other name: an ordinary high score.
## - Not active, the code: the real score is saved under it, then she wakes.
## - Active, the code: stays on. Nothing is saved (the run scored nothing).
## - Active, any other name: she goes back to sleep. Nothing is saved either;
##   the trade was agreed when she was switched on.
func on_highscore_name(name: String, points: int, wave: int) -> void:
	var code: bool = name.strip_edges().to_upper() == CODE_NAME
	if karmageisha_active:
		if not code:
			set_karmageisha(false)
		return
	Score.submit(name, points, wave)
	if code:
		set_karmageisha(true)


## Which character every player slot (human or bot) is spawned from.
func player_scene_path() -> String:
	return GOD_SCENE if karmageisha_active else PLAYER_SCENE


func damage_factor() -> float:
	return GOD_DAMAGE if karmageisha_active else 1.0


func speed_factor() -> float:
	return GOD_SPEED if karmageisha_active else 1.0


func sneak_factor() -> float:
	return GOD_SNEAK if karmageisha_active else 1.0


func sneak_drain_factor() -> float:
	return GOD_SNEAK_DRAIN if karmageisha_active else 1.0


## Fills a player's ScrollInventory with every kind. Called on spawn.
func stock_scrolls(inventory) -> void:
	if inventory == null or not karmageisha_active:
		return
	for kind in Scroll.COUNT:
		inventory.kinds[kind] = kind
		inventory.counts[kind] = GOD_SCROLL_STACK
	inventory.selected = 0


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	karmageisha_active = bool(cfg.get_value("cheats", "karmageisha", false))
	immortality_enabled = bool(cfg.get_value("cheats", "immortality", false))
	## Immortality outside a debug build only makes sense as part of her.
	if not OS.is_debug_build() and not karmageisha_active:
		immortality_enabled = false


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("cheats", "karmageisha", karmageisha_active)
	cfg.set_value("cheats", "immortality", immortality_enabled)
	cfg.save(SAVE_PATH)
