class_name ScrollInventory
extends RefCounted

## One player's six scroll slots.
##
## A slot holds one kind of scroll and a count, so a second Swiftness stacks on
## the first rather than taking another slot. A new kind takes the first empty
## slot; with all six taken by other kinds, there is no room and the scroll
## stays on the floor.
##
## Slots keep their place when emptied rather than closing up, so the number
## key for a scroll does not change under the player's fingers mid-fight.

const SLOTS: int = 6

## Each entry is -1 for empty, or a Scroll.Kind.
var kinds: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1, -1, -1])
var counts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
## The slot a pad player has highlighted. Keyboard players pick by number and
## never need it, but it is kept pointing somewhere sensible either way.
var selected: int = 0


## Puts a scroll in its stack, or the first empty slot. False when full.
func add(kind: int) -> bool:
	var index: int = kinds.find(kind)
	if index < 0:
		index = kinds.find(-1)
		if index < 0:
			return false
		kinds[index] = kind
		if kinds[selected] == -1:
			selected = index
	counts[index] += 1
	return true


## Would add() succeed.
func has_room_for(kind: int) -> bool:
	return kinds.has(kind) or kinds.has(-1)


## The kind in a slot, or -1.
func kind_at(index: int) -> int:
	if index < 0 or index >= SLOTS:
		return -1
	return kinds[index]


## Spends one scroll from a slot. The slot empties when its stack runs out.
func take(index: int) -> void:
	if kind_at(index) == -1:
		return
	counts[index] -= 1
	if counts[index] <= 0:
		counts[index] = 0
		kinds[index] = -1
		## The highlight moves on, so the next tap uses something rather than
		## landing on a hole.
		if index == selected:
			cycle()


## Moves the highlight to the next slot that holds anything.
func cycle() -> void:
	for step in range(1, SLOTS + 1):
		var next: int = (selected + step) % SLOTS
		if kinds[next] != -1:
			selected = next
			return


func is_empty() -> bool:
	return kinds.count(-1) == SLOTS
