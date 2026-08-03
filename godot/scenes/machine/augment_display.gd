class_name AugmentDisplay
extends RefCounted

## The Augmented-suit badge and the row of Pacte augment chips, with the popups
## both of them open on a hold.
##
## First seam cut out of machine_scene.gd. It was chosen by measurement rather
## than by the shape of the original plan: of everything this display touches,
## nine fields are read and written nowhere else in the machine, and the only
## state it needs from outside is the shared font and whether the TV already has
## a callout open. Six functions are called from the rest of the machine, and
## they are the six public methods below. The stash was originally grouped with
## this seam and is deliberately not here — its state is threaded through the
## spin lock, the launch flag and the dealer popup, so it is a different and
## much more entangled cut.
##
## Everything here is presentation. The augments themselves live in
## RunStateStore; this reads them and never writes one.

## --- the Augmented suit badge (issue #111) -------------------------------------
const AUGMENTED_BADGE_POS := Vector2(22.0, 254.0)
const AUGMENTED_BADGE_BORDER := Color(0.86, 0.84, 0.24)
const AUGMENTED_BADGE_SIZE := 14.0

## --- the Pacte augment chip row (issue #181) -----------------------------------
const AUGMENT_PLATE_FRAMES := 3 # frame N = N+1 sockets
const PACTE_AUGMENT_BADGE_POS := Vector2(64.0, 223.0)
const PACTE_AUGMENT_BADGE_SIZE := Vector2(12.0, 15.0)
const PACTE_AUGMENT_BADGE_PITCH := 14.0
const PACTE_AUGMENT_BADGE_MAX := 3
const PACTE_AUGMENT_ICON_SIZE := 10.0
const PACTE_AUGMENT_CONTOUR_COLOR := Color("#143464")

## Card names and their descriptions run long; wrapping keeps the bubble on the canvas.
const PACTE_AUGMENT_POPUP_MAX_WIDTH := 126.0

## The glitching chip: only the augment whose effect glitches the dealer gets one, keyed off
## the card's effect rather than its id so a renamed card keeps the treatment.
const AUGMENT_GLITCH_SLICES := 4
const AUGMENT_GLITCH_STEP_TIME := 0.09
const AUGMENT_GLITCH_COLORS: Array[Color] = [
	Color("#3ee0ff"), Color("#ff3ea5"), Color("#e8ff5a"), Color("#3ee0ff"),
]

const NEON_CYAN := Color(0.42, 1.0, 0.95)
const NEON_GOLD := Color(1.0, 0.86, 0.36)
const INFO_BUBBLE_GAP := 3.0 # px between the badge and its bubble
const SRC_W := 160.0
const SRC_H := 320.0

var _view: MachineView = null

## Every field below is owned here and read nowhere else in the machine — that is
## the measurement this seam was chosen on.
var _augmented_popup: Control = null # issue #111 hold-to-peek restrictions bubble
var _pacte_augment_badges: Array[Dictionary] = []
var _pacte_augment_badge: Button = null # first slot; anchors the popup
var _pacte_augment_badge_icon: TextureRect = null
var _pacte_augment_count: Label = null
var _pacte_augment_popup: Control = null
var _augment_plate_sprite: Sprite2D = null # authored augment sockets under the badges
var _augment_glitch_time := 0.0
var _augment_glitch_rng := RandomNumberGenerator.new()

func _init(view: MachineView) -> void:
	_view = view
	# Seeded, so the same frame count always looks the same.
	_augment_glitch_rng.seed = 181_0726

## --- what the rest of the machine calls ----------------------------------------

## The socket plate is built by the machine, which owns the full-canvas sheet
## helper and the layering the plate sits in; this display only shows and frames it.
func attach_plate(sprite: Sprite2D) -> void:
	_augment_plate_sprite = sprite

func badges() -> Array[Dictionary]:
	return _pacte_augment_badges

func plate_sprite() -> Sprite2D:
	return _augment_plate_sprite

func pacte_popup() -> Control:
	return _pacte_augment_popup

## The augment cards actually held, de-duplicated and filtered to ones the catalog
## still knows. What the row draws, and what the smoke checks count sockets against.
func active_ids() -> Array[String]:
	return _active_pacte_augment_ids()

func build_augmented_badge() -> void:
	if RunStateStore.augmentedTier == "":
		return
	var icon_tex := Assets.augmented_suit_icon(RunStateStore.augmentedTier)
	if icon_tex == null:
		return
	var b := Button.new()
	b.name = "AugmentedBadge"
	b.position = AUGMENTED_BADGE_POS
	b.size = Vector2.ONE * AUGMENTED_BADGE_SIZE
	b.z_index = 40
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.02, 0.05, 0.85)
	style.border_color = AUGMENTED_BADGE_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, style)
	var icon := TextureRect.new()
	icon.texture = icon_tex
	# expand_mode BEFORE size: with the default EXPAND_KEEP_SIZE the texture's
	# native size becomes the minimum and the size assignment gets clamped up.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2.ONE * 2.0
	icon.size = Vector2.ONE * (AUGMENTED_BADGE_SIZE - 4.0)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	b.button_down.connect(_show_augmented_popup.bind(b))
	b.button_up.connect(hide_augmented_popup)
	_view.add_layer(b)

func hide_augmented_popup() -> void:
	if _augmented_popup != null:
		_augmented_popup.queue_free()
		_augmented_popup = null

## A row of augment icons along the TV's bottom-left, one badge per held card up to
## PACTE_AUGMENT_BADGE_MAX (issue #181). The row stops short of the TARGET goal number
## in the middle of the screen; a fourth augment turns the last badge into a "+N".
## Every badge opens the same description popup.
func build_pacte_badges() -> void:
	if _pacte_augment_badge != null:
		refresh_pacte_badges()
		return
	for i in PACTE_AUGMENT_BADGE_MAX:
		var badge := Button.new()
		# The first badge keeps the historical node name; the scene smoke and the popup
		# anchoring both look it up by it.
		badge.name = "PacteAugmentBadge" if i == 0 else "PacteAugmentBadge%d" % (i + 1)
		badge.position = PACTE_AUGMENT_BADGE_POS + Vector2(float(i) * PACTE_AUGMENT_BADGE_PITCH, 0.0)
		badge.size = PACTE_AUGMENT_BADGE_SIZE
		badge.z_index = 40
		badge.text = ""
		badge.flat = true
		badge.visible = false
		badge.focus_mode = Control.FOCUS_NONE
		badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(0.03, 0.02, 0.05, 0.9)
		badge_style.border_color = PACTE_AUGMENT_CONTOUR_COLOR
		badge_style.set_border_width_all(1)
		badge_style.set_corner_radius_all(1)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			badge.add_theme_stylebox_override(state, badge_style)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.position = (PACTE_AUGMENT_BADGE_SIZE
			- Vector2(PACTE_AUGMENT_ICON_SIZE, PACTE_AUGMENT_ICON_SIZE)) * 0.5
		icon.size = Vector2(PACTE_AUGMENT_ICON_SIZE, PACTE_AUGMENT_ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(icon)
		# The overflow count replaces the last icon rather than sitting on top of one,
		# so it can never obscure the art it is counting.
		var count := Label.new()
		count.name = "Count"
		count.position = Vector2.ZERO
		count.size = PACTE_AUGMENT_BADGE_SIZE
		count.visible = false
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.add_theme_font_size_override("font_size", 5)
		var font := _view.font()
		if font != null:
			count.add_theme_font_override("font", font)
		count.add_theme_color_override("font_color", NEON_GOLD)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_constant_override("outline_size", 1)
		badge.add_child(count)
		# GLITCH has no authored chip art, so its badge carries the effect itself: a few
		# neon slices that jump and flicker inside the chip (clipped to it), stepped by
		# step_glitch. It draws over the icon, so authored art can arrive later
		# and keep the effect.
		var glitch := Control.new()
		glitch.name = "Glitch"
		glitch.position = icon.position
		glitch.size = icon.size
		glitch.clip_contents = true
		glitch.visible = false
		glitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for _slice_index in AUGMENT_GLITCH_SLICES:
			var slice := ColorRect.new()
			slice.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glitch.add_child(slice)
		badge.add_child(glitch)
		# Held, not toggled: the same grip as the Augmented suit badge and the TV item
		# badges. A toggle also left the description parked on screen if the second tap
		# ever went astray, which a hold cannot do.
		badge.button_down.connect(_show_pacte_augment_popup)
		badge.button_up.connect(hide_pacte_popup)
		_view.add_layer(badge)
		_pacte_augment_badges.append({
			"badge": badge, "icon": icon, "count": count, "glitch": glitch,
		})
	if not _pacte_augment_badges.is_empty():
		_pacte_augment_badge = _pacte_augment_badges[0]["badge"]
		_pacte_augment_badge_icon = _pacte_augment_badges[0]["icon"]
		_pacte_augment_count = _pacte_augment_badges[0]["count"]
	refresh_pacte_badges()

func refresh_pacte_badges() -> void:
	if _pacte_augment_badges.is_empty():
		return
	var ids := _active_pacte_augment_ids()
	# The row lives on the power bar now, not on the TV, so a TV callout no longer
	# hides it — only the description popup steps aside for one.
	if _view.tv_callout_open():
		hide_pacte_popup()
	if ids.is_empty():
		for entry: Dictionary in _pacte_augment_badges:
			(entry["badge"] as Button).visible = false
		if _augment_plate_sprite != null:
			_augment_plate_sprite.visible = false # no augments, no sockets
		hide_pacte_popup()
		return
	var shown := mini(ids.size(), _pacte_augment_badges.size())
	# One socket per badge on show, so the plate never offers an empty bed.
	if _augment_plate_sprite != null:
		_augment_plate_sprite.visible = true
		_view.set_sheet_frame(_augment_plate_sprite, clampi(shown - 1, 0, AUGMENT_PLATE_FRAMES - 1))
	for i in _pacte_augment_badges.size():
		var entry: Dictionary = _pacte_augment_badges[i]
		var badge: Button = entry["badge"]
		var icon: TextureRect = entry["icon"]
		var count: Label = entry["count"]
		badge.visible = i < shown
		if not badge.visible:
			icon.texture = null
			continue
		# The last slot counts the remainder instead of showing one more icon.
		var overflow := i == shown - 1 and ids.size() > shown
		count.visible = overflow
		icon.visible = not overflow
		var glitch := entry.get("glitch") as Control
		if overflow:
			count.text = "+%d" % (ids.size() - shown + 1)
			icon.texture = null
			if glitch != null:
				glitch.visible = false
		else:
			icon.texture = _pacte_augment_icon(ids[i])
			if glitch != null:
				glitch.visible = _augment_glitches(String(ids[i]))

func hide_pacte_popup() -> void:
	if _pacte_augment_popup != null:
		_pacte_augment_popup.queue_free()
		_pacte_augment_popup = null

func step_glitch(delta: float) -> void:
	if _pacte_augment_badges.is_empty():
		return
	_augment_glitch_time += delta
	if _augment_glitch_time < AUGMENT_GLITCH_STEP_TIME:
		return
	_augment_glitch_time = 0.0
	for entry: Dictionary in _pacte_augment_badges:
		var glitch := entry.get("glitch") as Control
		if glitch == null or not glitch.visible:
			continue
		if not (entry["badge"] as Button).visible:
			continue
		_scramble_augment_glitch(glitch)

## --- internal ------------------------------------------------------------------

func _augmented_restrictions_text() -> String:
	var lines: Array[String] = []
	# Every line is tr()'d BEFORE its numbers go in: the popup's own auto-translation only
	# sees the finished sentence, and "PRICES +50%" is not a key any table can hold. The
	# plural is two whole keys rather than an appended "S" for the same reason — French
	# does not pluralise by bolting a letter onto the end of the noun.
	if RunStateStore.augmented_modifier_active(1):
		lines.append(tr("SPINS COST 2 HEALTH"))
	if RunStateStore.augmented_modifier_active(2):
		lines.append(tr("POWER RESTORES EVERY 2 SPINS"))
	if RunStateStore.augmented_modifier_active(3):
		lines.append(tr("MAX 2 POWERS PER SPIN"))
		lines.append(tr("NO AUGMENT AT THE 2ND PACTE"))
	if RunStateStore.augmented_modifier_active(4):
		lines.append(tr("PRICES +%d%%") % roundi(
			(RunStateStore.AUGMENTED_CLUB_PRICE_MULTIPLIER - 1.0) * 100.0))
		var penalty := int(RunStateStore.AUGMENTED_CLUB_OFFER_PENALTY)
		lines.append(tr("DEALER OFFERS %d ITEM FEWER" if penalty == 1
			else "DEALER OFFERS %d ITEMS FEWER") % penalty)
		lines.append(tr("HOUSE ANGER TAX +%d%%") % roundi(
			EconomyConst.OVERFLOW_ANGER_RATE * 100.0))
	return "\n".join(lines)

func _show_augmented_popup(button: Button) -> void:
	hide_augmented_popup()
	var text := _augmented_restrictions_text()
	if text == "":
		return
	_augmented_popup = _view.info_bubble("AugmentedPopup", text,
		AUGMENTED_BADGE_BORDER, Color(0.95, 0.92, 0.7))
	_augmented_popup.z_index = 41
	# Above the badge and centred on it, like the augment row and the TV badges. It used to
	# open sideways, which worked while the badge lived in the top strip; from its new home
	# beside the wealth plate that would lay the restrictions straight across the score.
	var pos := button.position + Vector2(
		(button.size.x - _augmented_popup.size.x) * 0.5,
		-_augmented_popup.size.y - INFO_BUBBLE_GAP)
	pos.x = clampf(pos.x, 2.0, SRC_W - _augmented_popup.size.x - 2.0)
	pos.y = clampf(pos.y, 2.0, SRC_H - _augmented_popup.size.y - 2.0)
	_augmented_popup.position = pos.round()
	_view.add_layer(_augmented_popup)

func _active_pacte_augment_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in RunStateStore.selectedAugmentCardIds:
		var id := String(raw_id)
		if not ids.has(id) and PacteCards.augment_map().has(id):
			ids.append(id)
	return ids

func _augment_glitches(card_id: String) -> bool:
	var entry := PacteCards.card(card_id)
	var effect: Dictionary = entry.get("effect", {})
	return String(effect.get("type", "")) == "glitch_dealer"

## One frame of the effect: each slice jumps to a new row, overhangs the chip sideways so the
## clip cuts it, and takes a fresh alpha. Seeded, so the same frame count always looks the same.
func _scramble_augment_glitch(host: Control) -> void:
	for i in host.get_child_count():
		var slice := host.get_child(i) as ColorRect
		if slice == null:
			continue
		var height := floorf(_augment_glitch_rng.randf_range(1.0, 3.0))
		slice.position = Vector2(
			floorf(_augment_glitch_rng.randf_range(-2.0, 2.0)),
			floorf(_augment_glitch_rng.randf_range(0.0, maxf(1.0, host.size.y - height))))
		slice.size = Vector2(host.size.x + 4.0, height)
		var color: Color = AUGMENT_GLITCH_COLORS[i % AUGMENT_GLITCH_COLORS.size()]
		color.a = _augment_glitch_rng.randf_range(0.4, 1.0)
		slice.color = color

func _pacte_augment_icon(card_id: String) -> Texture2D:
	var entry := PacteCards.card(card_id)
	var sheet := _view.texture(String(entry.get("sheet", "")), true)
	var icon_rect := entry.get("icon_rect", Rect2()) as Rect2
	if sheet == null or icon_rect.size == Vector2.ZERO:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = icon_rect
	return atlas

func _pacte_augment_popup_text() -> String:
	var lines: Array[String] = []
	for card_id in _active_pacte_augment_ids():
		var entry := PacteCards.card(card_id)
		lines.append("%s\n%s" % [
			String(entry.get("name", card_id)), String(entry.get("description", ""))])
	return "\n".join(lines)

func _show_pacte_augment_popup() -> void:
	hide_pacte_popup()
	if _pacte_augment_badge == null or _active_pacte_augment_ids().is_empty():
		return
	var text := _pacte_augment_popup_text()
	if text == "":
		return
	var popup := _view.info_bubble("PacteAugmentPopup", text, NEON_CYAN,
		Color(0.88, 0.98, 1.0), PACTE_AUGMENT_POPUP_MAX_WIDTH)
	popup.z_index = 41
	# Directly above the badge being held rather than a whole badge-height clear of it,
	# which is what used to leave the words floating away from the row.
	var pos := _pacte_augment_badge.position + Vector2(
		(_pacte_augment_badge.size.x - popup.size.x) * 0.5,
		-popup.size.y - INFO_BUBBLE_GAP)
	pos.x = clampf(pos.x, 2.0, SRC_W - popup.size.x - 2.0)
	pos.y = clampf(pos.y, 2.0, SRC_H - popup.size.y - 2.0)
	popup.position = pos.round()
	_pacte_augment_popup = popup
	_view.add_layer(popup)
