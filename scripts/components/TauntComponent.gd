class_name TauntComponent
extends Node

## Gives an entity one line to say before it will fight.
##
## Drop this under any entity and point `timeline` at a .dtl. The entity asks
## `provoke()` when the player interacts with it; the component runs the
## timeline and reports back through `taunt_finished` when the player has
## dismissed it.
##
## Deliberately knows nothing about EnemyBase — it only talks to Dialogic and
## its own exports, so the same node works on an NPC or a boss without edits.

## Emitted once the timeline has been dismissed. The host entity listens for
## this to leave its frozen state and start fighting.
signal taunt_finished

## The line this entity says. Left empty the component is inert and provoke()
## always returns false, so an entity without a line just fights immediately.
@export_file("*.dtl") var timeline: String = ""

## Once said, never said again. Cleared only by reset().
var has_spoken: bool = false

## True from provoke() until the timeline ends. The host freezes while this is
## set so a taunt cannot be walked out of halfway through.
var is_speaking: bool = false

## Guards against two entities taunting over each other. Dialogic has a single
## global timeline, so a second provoke() while one is running would cut the
## first off mid-sentence.
static var _speaker: TauntComponent = null


## Runs the line if this entity still has one to say.
## Returns true when a timeline actually started, so the caller can decide
## whether to freeze itself or carry on as normal.
func provoke() -> bool:
	if has_spoken or is_speaking or timeline.is_empty():
		return false
	if _speaker != null:
		return false
	if not _dialogic_available():
		## No Dialogic in the build: mark it said and let the fight start rather
		## than leaving the entity stuck waiting for a signal that never comes.
		has_spoken = true
		return false

	has_spoken = true
	is_speaking = true
	_speaker = self
	Dialogic.timeline_ended.connect(_on_timeline_ended, CONNECT_ONE_SHOT)
	Dialogic.start(timeline)
	return true


## Lets a respawned or re-used entity say its line again.
func reset() -> void:
	has_spoken = false


func _on_timeline_ended() -> void:
	is_speaking = false
	if _speaker == self:
		_speaker = null
	taunt_finished.emit()


## The autoload is registered in project.godot, but a scene run in isolation or
## with the plugin disabled will not have it.
func _dialogic_available() -> bool:
	if not Engine.has_singleton("Dialogic") and not is_instance_valid(get_node_or_null("/root/Dialogic")):
		return false
	return true


## Releasing the global latch matters when an entity dies mid-sentence —
## otherwise no other entity could ever taunt again.
func _exit_tree() -> void:
	if _speaker == self:
		_speaker = null
