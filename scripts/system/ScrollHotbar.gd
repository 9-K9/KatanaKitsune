class_name ScrollHotbar
extends Control

## Every player's six scroll slots, along the bottom of the screen.
##
## Drawn by hand rather than built from nodes: it is six boxes, an icon and a
## number each, redrawn every frame anyway because the highlight and the effect
## timers move — a tree of TextureRects and Labels would just be more to keep in
## step. One bar per player, centred as a group, so a single player's bar sits
## in the middle and four sit side by side.
##
## Above each bar, the scrolls that are burning right now, with how long each
## has left.

const SLOT: float = 48.0
const GAP: float = 4.0
const PAD: float = 6.0
const BETWEEN_BARS: float = 28.0
const BOTTOM_MARGIN: float = 12.0
const EFFECT_ICON: float = 32.0
const UI_THEME := preload("res://assets/sprites/ui/katanaKitsune.theme.tres")

const BACK := Color(0.06, 0.04, 0.05, 0.78)
const EDGE := Color(0.52, 0.40, 0.22, 0.95)
const EMPTY_EDGE := Color(0.32, 0.26, 0.18, 0.7)

## How many players' bars to lay out. Set by the HUD.
var player_count: int = 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _bar_width() -> float:
	return PAD * 2.0 + SLOT * ScrollInventory.SLOTS + GAP * (ScrollInventory.SLOTS - 1)


func _draw() -> void:
	var view: Vector2 = get_viewport_rect().size
	var count: int = maxi(player_count, 1)
	var width: float = _bar_width()
	var total: float = width * count + BETWEEN_BARS * (count - 1)
	var left: float = (view.x - total) * 0.5
	var top: float = view.y - BOTTOM_MARGIN - SLOT - PAD * 2.0
	for slot in count:
		var body := _body_for(slot)
		if body == null or body.get("scrolls") == null:
			continue
		var x: float = left + (width + BETWEEN_BARS) * slot
		_draw_bar(body, Vector2(x, top), Roster.colour_of(slot))


func _body_for(slot: int) -> Node:
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D and node.get("slot") == slot:
			return node
	return null


func _draw_bar(body: Node, at: Vector2, tint: Color) -> void:
	var inventory: ScrollInventory = body.scrolls
	var dead: bool = body.get("is_dead") == true
	var font: Font = UI_THEME.default_font
	var keyboard: bool = body.get("input") != null \
			and body.input.device == PlayerInput.KEYBOARD
	var fade: float = 0.45 if dead else 1.0

	draw_rect(Rect2(at, Vector2(_bar_width(), SLOT + PAD * 2.0)),
			Color(BACK, BACK.a * fade))
	draw_rect(Rect2(at, Vector2(_bar_width(), SLOT + PAD * 2.0)),
			Color(tint, 0.55 * fade), false, 1.0)

	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 2.0)
	for i in ScrollInventory.SLOTS:
		var box := Rect2(at + Vector2(PAD + (SLOT + GAP) * i, PAD), Vector2(SLOT, SLOT))
		var kind: int = inventory.kind_at(i)
		draw_rect(box, Color(0.0, 0.0, 0.0, 0.35 * fade))
		if kind != -1:
			var icon: Texture2D = Scroll.icon(kind)
			draw_texture_rect(icon, box.grow(-2.0), false, Color(1, 1, 1, fade))
			var count: int = inventory.counts[i]
			if count > 1:
				_text(font, box.position + Vector2(box.size.x - 3.0, box.size.y - 3.0),
						"x%d" % count, 13, Color(1.0, 0.95, 0.8, fade), HORIZONTAL_ALIGNMENT_RIGHT)
		draw_rect(box, Color(EDGE if kind != -1 else EMPTY_EDGE, fade), false, 1.0)
		if i == inventory.selected and kind != -1 and not dead:
			var glow := tint.lightened(0.3)
			glow.a = 0.75 + 0.25 * pulse
			draw_rect(box.grow(1.0), glow, false, 2.0)
		if keyboard:
			_text(font, box.position + Vector2(3.0, 15.0), str(i + 1), 14,
					Color(0.95, 0.88, 0.7, 0.8 * fade))

	_draw_effects(body, at + Vector2(PAD, -EFFECT_ICON - 10.0), font)


## The scrolls currently in effect, as a row of small icons each with a bar
## that empties as its time runs out. The stone charge has no timer — it waits
## for a blow — so it shows full and pulses.
func _draw_effects(body: Node, at: Vector2, font: Font) -> void:
	if body.get("is_dead") == true:
		return
	var x: float = at.x
	for kind in Scroll.COUNT:
		var left: float = 0.0
		var share: float = 0.0
		if kind == Scroll.Kind.STONE:
			if body.get("stone_charged") != true:
				continue
			share = 1.0
		else:
			left = body.scroll_time_left(kind)
			if left <= 0.0:
				continue
			share = clampf(left / maxf(body.scroll_duration(kind), 0.01), 0.0, 1.0)
		var rect := Rect2(Vector2(x, at.y), Vector2(EFFECT_ICON, EFFECT_ICON))
		draw_rect(rect.grow(3.0), BACK)
		## Blinks in its last two seconds so running out is not a surprise.
		var alpha: float = 1.0
		if kind != Scroll.Kind.STONE and left < 2.0:
			alpha = 0.4 + 0.6 * absf(sin(Time.get_ticks_msec() / 1000.0 * TAU * 2.5))
		draw_texture_rect(Scroll.icon(kind), rect, false, Color(1, 1, 1, alpha))
		var bar := Rect2(rect.position + Vector2(0.0, EFFECT_ICON + 2.0),
				Vector2(EFFECT_ICON, 4.0))
		draw_rect(bar, Color(0.0, 0.0, 0.0, 0.6))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)),
				Scroll.INK[kind].lightened(0.25))
		if kind != Scroll.Kind.STONE:
			_text(font, rect.position + Vector2(EFFECT_ICON + 3.0, EFFECT_ICON * 0.5 + 5.0),
					"%d" % ceili(left), 16, Color(1.0, 0.95, 0.8, alpha))
		x += EFFECT_ICON + 20.0


func _text(font: Font, pos: Vector2, text: String, size: int, colour: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var width: float = -1.0
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		pos.x -= width
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var backing := Rect2(pos - Vector2(2.0, font.get_ascent(size) + 2.0),
			Vector2(text_size.x + 4.0, font.get_height(size) + 4.0))
	draw_rect(backing, Color(BACK, BACK.a * colour.a))
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4,
			Color(0.03, 0.02, 0.04, colour.a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
