extends Node

## Runtime testing cheats. Kept in an autoload so settings survive scene changes.
var immortality_enabled: bool = false


func set_immortality(enabled: bool) -> void:
	immortality_enabled = enabled
