class_name BoostIndicators
extends RefCounted

## The row of item badges along the bottom of the TV — one icon per running
## multi-spin boost with its spins-remaining count — and the description bubble a
## badge raises when you hold it (issue #185).
##
## Seam 4.4b. Two things that measured as separate clusters and are not: the
## badge you press and the bubble it opens have no other callers, and the press
## handler is the only thing that ever opens the bubble. Cutting one without the
## other would have left a two-function component reachable only through the one
## it was split from.
##
## The zero-linger comes too, and that is the judgement call in this seam. It is
## written on a spin and cleared on a spin, which looks like run flow — but its
## only purpose is to keep a badge showing "0" for one refresh after its last
## spin is spent, so the item is seen running out instead of vanishing. It is
## display state with a spin-shaped lifetime, and the machine drives it through
## two calls rather than owning a dictionary it never reads.
##
## DURATION_BOOSTS deliberately stays on the machine and is handed over at
## construction. It names store fields as DATA and the smoke suite reaches it as
## `machine.DURATION_BOOSTS` to check every one of those names still resolves
## (_check_dynamic_store_field_names). Moving the table would have moved that
## contract with it for no gain.

const ICON_SIZE := 8.0
const COUNT_WIDTH := 7.0

## The count is pinned to the badge's bottom-right CORNER, the same place on every item.
## It used to sit beside the icon at a fixed offset, which only looked consistent if the
## art did: the icons are aspect-centred in their 8px box and fill wildly different amounts
## of it (the cigarette is a wide horizontal object and runs the full width, the drink can
## is tall and narrow and uses half), so the number appeared to sit on top of one item and
## well clear of the next. Anchoring to the corner makes the number's position identical
## across the row and lets each icon differ underneath it.
##
## It sits ON the icon rather than beside it: the number belongs to that item, and a number
## floating in the gap between two icons reads as ambiguous about which one it counts. Its
## right edge overhangs the icon's by COUNT_OVERHANG px so the digit still has a clean
## edge to sit against, but the rest of it overlaps the art's bottom-right — the black
## outline on the label is what keeps it legible over the icon underneath.
const COUNT_OVERHANG := 1.0     # px the number's right edge clears the icon's
const COUNT_OFFSET := ICON_SIZE + COUNT_OVERHANG - COUNT_WIDTH  # 2
const SLOT_WIDTH := ICON_SIZE + COUNT_OVERHANG   # 9: icon + the overhang

## Per-item nudge for art that still reads badly under the shared anchor — the icons do not
## share a silhouette, so a few need a pixel either way. Keyed by item id, in badge px.
const COUNT_NUDGE := {}

## The row is bounded by the TV's own SCREEN, not by the cabinet around it: the near-black
## screen runs x37..114 across y99..106 before the bezel and the curved bottom corners take
## over (y107 already narrows to x39..112). Measuring "anything dark" instead caught the
## cabinet grey and pushed the row about 5px past the bezel, off the TV entirely.
## The row sits on the screen's last eight rows, y100..107. Its bottom row is where the
## screen curves in to x39..112, and that corner is what fixes the row's width: five
## SLOT_WIDTH slots at a 15px pitch from x39 land flush inside it. These positions
## are the layout — nothing derives them, so there is one place to change.
const SLOT_POSITIONS: Array[Vector2] = [
	Vector2(39.0, 100.0), Vector2(54.0, 100.0), Vector2(69.0, 100.0),
	Vector2(84.0, 100.0), Vector2(99.0, 100.0),
]
const BADGE_FONT_SIZE := 5      # the turn count, sized for the 8px badge

## Polarity is the count's colour (issue #185): the project's established positive/negative
## pair, the same green and red the potion popup and the on-use hints already speak in.
const COUNT_COLOR := Color(0.72, 1.0, 0.65)
const NEGATIVE_COUNT_COLOR := Color(0.94, 0.27, 0.27)

const POPUP_HOLD := 1.0     # seconds fully lit before it starts leaving
const POPUP_FADE := 0.18
const POPUP_MAX_WIDTH := 104.0 # wrap before the description leaves the TV
const POPUP_Z_INDEX := 42   # over the banner, the callouts and the dealer strip
const NEON_CYAN := Color(0.42, 1.0, 0.95)
const INFO_BUBBLE_GAP := 3.0 # px between the icon and its bubble

var _view: MachineView = null

## The boost table and the TV's screen rect: the machine's, static after load, so
## they are handed over rather than reached for or copied.
var _boosts: Array = []
var _tv_screen: Dictionary = {}

## The machine's generic item-icon lookup, and its description copy. Both read
## things this component has no business in — the item catalogue, the joker run's
## reworded blurbs — so they are asked for, not reimplemented.
var _icon_for: Callable
var _popup_text_for: Callable

var _slots: Array[Dictionary] = []
## counter -> snapshot while the just-spent final spin shows "0"
var _zero_linger: Dictionary = {}
var _popup: Control = null
var _popup_time := 0.0
var _popup_held := false

func _init(view: MachineView, boosts: Array, tv_screen: Dictionary,
		icon_for: Callable, popup_text_for: Callable) -> void:
	_view = view
	_boosts = boosts
	_tv_screen = tv_screen
	_icon_for = icon_for
	_popup_text_for = popup_text_for

## --- construction ------------------------------------------------------------------

func build() -> void:
	_slots.clear()
	for i in _boosts.size():
		# A Button, not a bare Control (issue #185): HOLDING a badge is how you find out
		# what the icon means. Flat and untextured, so it stays the authored art with a
		# hit box on it. Its children keep MOUSE_FILTER_IGNORE so the whole 12px badge
		# is the target — there is nothing else to hit at that size.
		var slot := Button.new()
		slot.name = "BoostIndicator%d" % i
		slot.flat = true
		slot.text = ""
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.size = Vector2(ICON_SIZE, ICON_SIZE)
		slot.z_index = 12
		slot.visible = false
		# Hold to peek, release to dismiss — the same grip the Augmented suit badge and the
		# score table's info chips use, so every explain-this control on the machine
		# answers to one gesture instead of each having its own.
		slot.button_down.connect(on_pressed.bind(i))
		slot.button_up.connect(on_released)
		_view.add_layer(slot)
		# Icon at the slot origin; the whole slot is positioned per-row on refresh.
		var icon := TextureRect.new()
		icon.position = Vector2.ZERO
		icon.size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		# Count in the icon's bottom-right corner. The DTM font forces a ~23px min box
		# height, so a fixed box would push bottom-aligned text well below the icon; the
		# box is instead sized/placed from the label's real min height on refresh.
		var count := Label.new()
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		# Font 5 on the 8px badge, matching the augment chips' own count (issue #185
		# follow-up); the old 7 was sized for a 12px icon and would swallow this one.
		count.add_theme_font_size_override("font_size", BADGE_FONT_SIZE)
		var font := _view.font()
		if font != null:
			count.add_theme_font_override("font", font)
		count.add_theme_color_override("font_color", COUNT_COLOR)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_constant_override("outline_size", 1)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(count)
		_slots.append({
			"slot": slot, "icon": icon, "count": count,
			# Which boost this pooled slot is currently showing — the row is packed, so
			# slot index is not boost index and a tap has to look it up here.
			"boost": {},
		})

func slots() -> Array[Dictionary]:
	return _slots

## --- reading the boosts ---------------------------------------------------------------

## The phases an item runs through, in order. A single-phase item is described by its own
## `counter` and `negative` flag, so every entry can be read the same way.
func _phases(boost: Dictionary) -> Array:
	var phases: Array = boost.get("phases", [])
	if not phases.is_empty():
		return phases
	return [{ "counter": String(boost["counter"]),
		"negative": bool(boost.get("negative", false)) }]

## Spins left on a boost: the whole effect, summed across its phases, so a phased item
## counts down continuously instead of restarting at each hand-off (issue #185).
func remaining(boost: Dictionary) -> int:
	var total := 0
	for phase: Dictionary in _phases(boost):
		total += int(RunStateStore.get(String(phase["counter"])))
	return total

## Whether what the item is doing RIGHT NOW is a downside — the first phase with spins
## still on it. This is what colours the count, so an item that turns sour (or sweet)
## partway through says so as it happens rather than averaging the two.
func _phase_is_negative(boost: Dictionary) -> bool:
	var phases := _phases(boost)
	for phase: Dictionary in phases:
		if int(RunStateStore.get(String(phase["counter"]))) > 0:
			return bool(phase.get("negative", false))
	# Nothing left running (the badge is lingering on zero): keep the last phase's colour
	# rather than snapping back to the first one's as it goes out.
	return bool((phases[phases.size() - 1] as Dictionary).get("negative", false))

## Whether a boost currently owns a slot: either it has spins left, or it just expired
## and is lingering on zero for one refresh.
func _is_active(boost: Dictionary) -> bool:
	var counter := String(boost["counter"])
	var suppress_when_zero_counter := String(boost.get("suppressWhenZeroCounter", ""))
	if suppress_when_zero_counter != "" and _zero_linger.has(suppress_when_zero_counter):
		return false
	return remaining(boost) > 0 or _zero_linger.has(counter)

func _icon_texture(boost: Dictionary) -> Texture2D:
	var counter := String(boost.get("counter", ""))
	if _zero_linger.has(counter):
		var snapshot := _zero_linger[counter] as Dictionary
		var linger_symbol_id := String(snapshot.get("symbolId", ""))
		if linger_symbol_id != "":
			var linger_symbol_tex := _view.texture("symbols/%s.png" % linger_symbol_id, true)
			if linger_symbol_tex != null:
				return linger_symbol_tex
	var symbol_field := String(boost.get("symbolField", ""))
	if symbol_field != "":
		var symbol_id := String(RunStateStore.get(symbol_field))
		if symbol_id != "":
			var symbol_tex := _view.texture("symbols/%s.png" % symbol_id, true)
			if symbol_tex != null:
				return symbol_tex
	return _icon_for.call(String(boost["id"]))

## --- the row ----------------------------------------------------------------------

## Shows one icon per active multi-spin boost, stacked along the TV's bottom edge, each
## with a spins-remaining badge. A boost whose icon is missing is skipped rather than
## shown as a bare number. Unused slots hide (issue #76). There are more boosts than
## slots, so the last visible one carries a "+N" overflow count (issue #181).
##
## `callout_active` is asked for rather than read: the item icons step aside for a
## full-screen callout, and only for that (issue #185). The FREE SPIN banner no longer
## blanks them — the row sits below the target bar now, well clear of the banner, so
## what is running stays readable through the free spins.
func refresh(callout_active: bool) -> void:
	if _slots.is_empty():
		return
	if callout_active:
		hide_all()
		return
	var column_capacity := mini(SLOT_POSITIONS.size(), _slots.size())
	var active_total := 0
	for boost in _boosts:
		if _is_active(boost):
			active_total += 1
	var col := 0
	for boost in _boosts:
		var counter := String(boost["counter"])
		var left := remaining(boost)
		var show_zero := left <= 0 and _zero_linger.has(counter)
		var suppress_when_zero_counter := String(boost.get("suppressWhenZeroCounter", ""))
		if suppress_when_zero_counter != "" and _zero_linger.has(suppress_when_zero_counter):
			continue
		if left > 0:
			_zero_linger.erase(counter)
		if (left <= 0 and not show_zero) or col >= column_capacity:
			continue
		var tex := _icon_texture(boost)
		if tex == null:
			continue
		var s: Dictionary = _slots[col]
		var slot: Control = s["slot"]
		s["boost"] = boost
		slot.position = SLOT_POSITIONS[col]
		(s["icon"] as TextureRect).texture = tex
		(s["icon"] as TextureRect).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS \
			if tex.resource_path.contains("/items/generated/") else CanvasItem.TEXTURE_FILTER_NEAREST
		var cn: Label = s["count"]
		# Just the number of turns left, coloured by what the item is doing right now:
		# green while it is helping, red while it is costing. The badge is 8px and the
		# sign glyphs that used to carry polarity crowded the art at that size, so the
		# count carries it instead — and because the colour tracks the live phase, a
		# phased item announces the turn as it happens.
		cn.text = str(maxi(0, left))
		cn.add_theme_color_override("font_color",
			NEGATIVE_COUNT_COLOR if _phase_is_negative(boost) else COUNT_COLOR)
		# Pinned over the icon's bottom-right corner — the same coordinates on every item,
		# so the row reads as one repeated shape rather than the number chasing each
		# icon's silhouette, and overlapping the art so the count is visibly attached to
		# the item it belongs to. Plus whatever per-item nudge the art needs.
		var mh := cn.get_minimum_size().y
		var nudge: Vector2 = COUNT_NUDGE.get(String(boost.get("id", "")), Vector2.ZERO)
		cn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cn.size = Vector2(COUNT_WIDTH, mh)
		cn.position = Vector2(COUNT_OFFSET, ICON_SIZE - mh) + nudge
		slot.visible = true
		col += 1
	# More boosts than slots: the last one carries how many are not shown, so the player
	# still knows something is running rather than silently losing it.
	if col > 0 and active_total > col:
		var overflow: Label = _slots[col - 1]["count"]
		overflow.text = "+%d" % (active_total - col + 1)
	hide_all(col)

func showing() -> bool:
	for entry: Dictionary in _slots:
		if (entry["slot"] as Control).visible:
			return true
	return false

## Blanks the boost slots from `first` onwards. Dropping the texture matters: a slot
## re-shown before its icon is resolved would otherwise flash the previous boost's art.
func hide_all(first := 0) -> void:
	for i in range(first, _slots.size()):
		var hidden: Dictionary = _slots[i]
		(hidden["slot"] as Control).visible = false
		(hidden["icon"] as TextureRect).texture = null
		# Forget what the slot was showing along with the art: a tap that raced a
		# hide must not describe a boost that has already run out.
		hidden["boost"] = {}

## --- the zero linger ------------------------------------------------------------------

func capture_expiring() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for boost in _boosts:
		var counter := String(boost["counter"])
		if remaining(boost) == 1:
			var snapshot: Dictionary = { "counter": counter }
			var symbol_field := String(boost.get("symbolField", ""))
			if symbol_field != "":
				var symbol_id := String(RunStateStore.get(symbol_field))
				if symbol_id != "":
					snapshot["symbolId"] = symbol_id
			out.append(snapshot)
	return out

func apply_linger(counters: Array[Dictionary]) -> void:
	for snapshot in counters:
		var counter := String(snapshot.get("counter", ""))
		if int(RunStateStore.get(counter)) <= 0:
			_zero_linger[counter] = snapshot

func has_linger() -> bool:
	return not _zero_linger.is_empty()

## Whether one named counter is still lingering on zero. Tobacco's reel smoke asks:
## the covers have to stay up for the linger frame too, or the badge would still be
## showing the item while the effect it describes had visibly stopped.
func lingering(counter: String) -> bool:
	return _zero_linger.has(counter)

func clear_linger() -> void:
	_zero_linger.clear()

## --- the description bubble -------------------------------------------------------------

func on_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slots.size():
		return
	var entry: Dictionary = _slots[slot_index]
	if not (entry["slot"] as Control).visible:
		return
	show_popup(entry["boost"] as Dictionary, (entry["slot"] as Control).position)

## Released: the description starts leaving. It is not cut off — the hold timer is wound
## forward to the end of its dwell so the existing fade plays out from here, which is why
## letting go looks the same as a popup that timed out on its own.
func on_released() -> void:
	if _popup == null or not is_instance_valid(_popup):
		return
	_popup_held = false
	_popup_time = maxf(_popup_time, POPUP_HOLD)

func show_popup(boost: Dictionary, anchor: Vector2) -> void:
	hide_popup()
	if boost.is_empty():
		return
	var text: String = _popup_text_for.call(boost)
	if text == "":
		return
	var popup := _view.info_bubble("ItemInfoPopup", text, NEON_CYAN,
		Color(0.88, 0.98, 1.0), POPUP_MAX_WIDTH)
	popup.z_index = POPUP_Z_INDEX
	# Sitting on the badge being held: centred over it and a hair above, so the words are
	# next to the icon they belong to. Then clamped into the TV, because a badge near
	# either bezel would otherwise push half the description off the screen.
	var pos := anchor + Vector2(
		(ICON_SIZE - popup.size.x) * 0.5, -popup.size.y - INFO_BUBBLE_GAP + 1.0)
	pos.x = clampf(pos.x, float(_tv_screen["left"]) + 1.0,
		float(_tv_screen["left"] + _tv_screen["width"]) - popup.size.x - 1.0)
	pos.y = clampf(pos.y, float(_tv_screen["top"]) + 1.0,
		float(_tv_screen["top"] + _tv_screen["height"]) - popup.size.y - 1.0)
	popup.position = pos.round()
	_popup = popup
	_popup_time = 0.0
	_popup_held = true
	_view.add_layer(popup)

## Ages the popup out once the badge is let go. Fades over the last moments rather than
## vanishing, so a description leaving does not read as a glitch on a screen full of
## blinking things. A held badge never ages: the popup stays up for as long as the player
## keeps reading it, which is the whole point of holding.
func step_popup(delta: float) -> void:
	if _popup == null or not is_instance_valid(_popup):
		return
	if _popup_held:
		return
	_popup_time += delta
	var fading := _popup_time - POPUP_HOLD
	if fading >= POPUP_FADE:
		hide_popup()
		return
	if fading > 0.0:
		_popup.modulate.a = clampf(1.0 - fading / POPUP_FADE, 0.0, 1.0)

func hide_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null
	_popup_time = 0.0
	_popup_held = false

func popup() -> Control:
	return _popup
