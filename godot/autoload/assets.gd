@tool
extends Node

## Autoload "Assets" — process-wide cache for textures and fonts loaded by absolute
## res://assets. Caching
## across scene changes matters on Android: the 8x machine cabinet (1280x2560) is a
## ~13 MB texture, and reloading it every shop<->machine transition would hitch and
## churn VRAM. Loaded once here, reused everywhere.

var _tex := {}
var _fonts := {}

## Shared stash consumable icon size (virtual px). Single source of truth so the
## dealer scene, in-run dealer overlay, shop, and machine stash never drift apart
## (issues #24, #26). Every scene renders the stash as bare TextureRects this size so
## icons read identically; the row is anchored bottom-right via stash_slot_pos().
const STASH_ICON_SIZE := 16.0
const STASH_EDGE_MARGIN := 6.0  # px gap from the right and bottom screen edges
const STASH_SLOT_GAP := 4.0     # px between adjacent stash slots
const CANVAS_W := 160.0
const CANVAS_H := 320.0

## Top-left position of stash slot `index` (0 = leftmost) in a bottom-right anchored row
## of `total` slots, on the shared 160x320 canvas (issue #26). All scenes call this so
## the stash sits in the same corner at the same scale everywhere; pass the fixed slot
## count (Consumables.MAX_CONSUMABLE_SLOTS) so positions stay stable as copies change.
func stash_slot_pos(index: int, total: int) -> Vector2:
	var row_w := float(total) * STASH_ICON_SIZE + maxf(0.0, float(total - 1)) * STASH_SLOT_GAP
	var x0 := CANVAS_W - STASH_EDGE_MARGIN - row_w
	var y := CANVAS_H - STASH_EDGE_MARGIN - STASH_ICON_SIZE
	return Vector2(x0 + float(index) * (STASH_ICON_SIZE + STASH_SLOT_GAP), y)

func _ready() -> void:
	if OS.has_feature("android"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)

static func _res_image(rel: String) -> String:
	return "res://assets/images/" + rel

static func _res_asset(rel: String) -> String:
	return "res://assets/" + rel

# Texture under assets/images/<rel>. Cached by (rel, mipmaps). Returns null if missing.
func texture(rel: String, mipmaps := false) -> Texture2D:
	var key := rel + ("#m" if mipmaps else "")
	if _tex.has(key):
		return _tex[key]
	var res_path := _res_image(rel)
	if ResourceLoader.exists(res_path):
		var loaded := load(res_path)
		if loaded is Texture2D:
			_tex[key] = loaded
			return loaded
	push_warning("Assets: missing texture " + rel)
	_tex[key] = null
	return null

# Colour-inverted copy of a texture, cached by source path (issue #111). Joker Augmented
# runs deal the four in-run items in their inverted art rather than in new sprites, so the
# item is instantly recognisable and just as instantly wrong. Alpha is preserved — only
# RGB flips — so the silhouette the player learned stays exactly the same.
func inverted_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	# Generated textures have no resource path; key those by identity so the cache can
	# still hold them instead of collapsing every one of them onto the same empty key.
	var key := "#inv:" + (source.resource_path if source.resource_path != "" \
		else str(source.get_instance_id()))
	if _tex.has(key):
		return _tex[key]
	var image := source.get_image()
	if image == null:
		_tex[key] = source
		return source
	image = image.duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			image.set_pixel(x, y, Color(1.0 - c.r, 1.0 - c.g, 1.0 - c.b, c.a))
	var inverted := ImageTexture.create_from_image(image)
	_tex[key] = inverted
	return inverted

# Dynamic font under assets/<rel>. Cached. Returns null if missing.
func font(rel := "font/DTM-Sans.otf") -> FontFile:
	if _fonts.has(rel):
		return _fonts[rel]
	var res_path := _res_asset(rel)
	if ResourceLoader.exists(res_path):
		var loaded := load(res_path)
		if loaded is FontFile:
			_fonts[rel] = loaded
			return loaded
	push_warning("Assets: missing font " + rel)
	_fonts[rel] = null
	return null

# Whole-pixel correction for a VERTICAL_ALIGNMENT_CENTER label, per font size.
#
# Godot centres the font's ascent+descent box. The game's copy is upper case and sits
# between the cap line and the baseline — it never reaches into the descent — so the ink
# ends up above the middle of the box that was centred. On a 160x320 canvas that reads as
# "the text is not quite centred", which is exactly what it is.
#
# Measured from the rendered glyphs by test/debug_font_metrics.gd: this font's cap bias is
# about half a pixel at 5px and 6px — the two sizes the bubbles use — and lands on a whole
# pixel once it meets a real bubble's box, which is what the entries below correct. The
# other sizes measure flat, and nudging them would only move the text the other way.
# Re-run that script, and test/debug_bubble_ink.gd, if the font ever changes.
const CENTERED_TEXT_NUDGE := { 3: 0.0, 4: 0.0, 5: 1.0, 6: 1.0, 7: 0.0, 8: 0.0 }

## Px to push a vertically centred label down so its GLYPHS land in the middle.
func centered_text_nudge(font_size: int) -> float:
	return float(CENTERED_TEXT_NUDGE.get(font_size, 0.0))

# ── Augmented Run (issue #111) ───────────────────────────────────────────────────────
# Suit tier icons cropped from the authored symbols sheet (six full-canvas
# 160x320 frames: none, heart, diamond, spade, club, joker). Rects are in
# NATIVE CANVAS units (sheet at 960x320); augmented_sheet_scale() maps them
# onto whatever resolution the sheet was exported at, so a higher-res
# re-export needs no code change.
const AUGMENTED_SHEET_REL := "start_menu/start_menu_augmented symbols.png"
const AUGMENTED_SHEET_NATIVE_W := 960.0
const AUGMENTED_ICON_RECTS := {
	"heart": Rect2(229.0, 188.0, 23.0, 21.0),
	"diamond": Rect2(390.0, 187.0, 21.0, 21.0),
	"spade": Rect2(550.0, 187.0, 21.0, 22.0),
	"club": Rect2(709.0, 185.0, 23.0, 24.0),
	"joker": Rect2(868.0, 188.0, 24.0, 19.0),
}

## Export multiple of the states sheet (1.0 = native 320x1280).
func augmented_sheet_scale() -> float:
	var tex := texture(AUGMENTED_SHEET_REL, true)
	return 1.0 if tex == null else float(tex.get_width()) / AUGMENTED_SHEET_NATIVE_W

## AtlasTexture of one suit tier's icon, or null for "" / unknown tiers.
func augmented_suit_icon(tier: String) -> AtlasTexture:
	if not AUGMENTED_ICON_RECTS.has(tier):
		return null
	var tex := texture(AUGMENTED_SHEET_REL, true)
	if tex == null:
		return null
	var s := augmented_sheet_scale()
	var r: Rect2 = AUGMENTED_ICON_RECTS[tier]
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(r.position * s, r.size * s)
	return at

# ── Skinned buttons ─────────────────────────────────────────────────────────────────
# Button art lives in horizontal sprite sheets under ui/. Frame order by count:
#   2 -> [normal, pressed]   3 -> [normal, hover, pressed]   4 -> [+ disabled]
const _RED_BUTTON_REL := "ui/red_button.png"
const _CANCEL_BUTTON_REL := "ui/cancel_button.png"
const _PRESS_DROP := 2.0 # px the label/icon sinks on press, for a tactile feel
const _BUTTON_TEXT_BOTTOM_MARGIN := 2.0
const NEON_PANEL_FILL := Color(0.05, 0.04, 0.09, 0.97)
const START_MENU_BUTTON_CYAN := Color(0.42, 1.0, 0.95)
const START_MENU_BUTTON_PINK := Color(1.0, 0.5, 0.7)
const START_MENU_BUTTON_YELLOW := Color(1.0, 0.86, 0.36)
const _START_MENU_START_BUTTON_REL := "start_menu/start_menu_start_button.png"
const _START_MENU_SCORE_BUTTON_REL := "start_menu/start_menu_score_button.png"
const _START_MENU_OPTIONS_BUTTON_REL := "start_menu/start_menu_options_button.png"
const _START_MENU_START_BUTTON_REGION := Rect2(8.0, 142.0, 144.0, 28.0)
const _START_MENU_SCORE_BUTTON_REGION := Rect2(26.0, 176.0, 108.0, 30.0)
const _START_MENU_OPTIONS_BUTTON_REGION := Rect2(26.0, 211.0, 108.0, 30.0)
const _START_MENU_BUTTON_TEXTURE_MARGIN := 2.0
const _SMALL_NEON_BLUE_BUTTON_REL := "ui/neon_small_blue_button.png"
const _SMALL_NEON_PINK_BUTTON_REL := "ui/neon_small_pink_button.png"
const _SMALL_NEON_YELLOW_BUTTON_REL := "ui/neon_small_yellow_button.png"
const _SMALL_NEON_BUTTON_REGION := Rect2(0.0, 0.0, 45.0, 22.0)
const _SMALL_NEON_BUTTON_TEXTURE_MARGIN := 4.0
const SYMBOL_PICKER_FRAME_REL := "ui/symbol_chosing.png"
const SYMBOL_PICKER_TITLE_COLOR := Color(0.72, 1.0, 0.65)
const SYMBOL_PICKER_PANEL_COLOR := Color(0.05, 0.03, 0.1, 0.94)
const SYMBOL_PICKER_SLOT_COLOR := Color(0.18, 0.13, 0.26, 0.95)
const SYMBOL_PICKER_SLOT_BORDER := Color(0.45, 0.38, 0.62, 0.9)
const SYMBOL_PICKER_SLOT_HOVER := Color(0.28, 0.2, 0.42, 0.9)
const SYMBOL_PICKER_SLOT_PRESSED := Color(0.45, 0.38, 0.62, 0.95)
const SYMBOL_PICKER_ICON_SIZE := 16.0
const SYMBOL_PICKER_FIVE_SLOT_SOURCE_RECTS: Array[Rect2] = [
	Rect2(40.0, 56.0, 88.0, 96.0),
	Rect2(152.0, 56.0, 88.0, 96.0),
	Rect2(264.0, 56.0, 88.0, 96.0),
	Rect2(376.0, 56.0, 88.0, 96.0),
	Rect2(488.0, 56.0, 88.0, 96.0),
]

# Per-state -> frame index for a sheet of `frames` frames.
func _sheet_state_frames(frames: int) -> Dictionary:
	if frames <= 2:
		return {"normal": 0, "hover": 1, "pressed": 1, "disabled": 1, "focus": 0}
	if frames == 3:
		return {"normal": 0, "hover": 1, "pressed": 2, "disabled": 0, "focus": 0}
	return {"normal": 0, "hover": 1, "pressed": 2, "disabled": 3, "focus": 0}

# AtlasTexture for one frame of a horizontal sheet (for TextureButton/TextureRect).
func sheet_frame(rel: String, frame: int, frames: int) -> AtlasTexture:
	var tex := texture(rel)
	if tex == null:
		return null
	var fw := float(tex.get_width()) / float(frames)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(float(frame) * fw, 0.0, fw, float(tex.get_height()))
	return at

# Skin a TEXT Button with a sheet: one StyleBoxTexture region per state. The pressed
# state insets the top so the label visibly sinks a couple px. No-op if art missing.
func skin_sheet_button(b: Button, rel: String, frames: int) -> void:
	var tex := texture(rel)
	if tex == null:
		return
	var fw := float(tex.get_width()) / float(frames)
	var fh := float(tex.get_height())
	var sf := _sheet_state_frames(frames)
	for state in sf:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.region_rect = Rect2(float(sf[state]) * fw, 0.0, fw, fh)
		sb.content_margin_bottom = _BUTTON_TEXT_BOTTOM_MARGIN
		if state == "pressed":
			sb.content_margin_top = _PRESS_DROP # text sinks on press
		b.add_theme_stylebox_override(state, sb)
	# Upscaled pixel art: keep hard edges and a legible label over the fill.
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.5))

## Reuses the authored cyan, pink, or yellow start-menu plate as a scalable
## nine-slice skin. The nearest existing plate is selected for callers that pass
## a slightly adjusted label color, keeping every button on the same pixel grid.
func start_menu_button_style(button: Button, plate_color: Color, font_size: int = 6,
		texture_margin: float = _START_MENU_BUTTON_TEXTURE_MARGIN) -> void:
	if button == null:
		return
	var plate := _start_menu_button_plate(plate_color)
	_apply_authored_button_style(button, plate, font_size, texture_margin)
	button.set_meta(&"_start_menu_button_color", plate[&"color"])

## Uses the dedicated 45x22 button art for compact controls. Callers with
## sub-22px authored hit areas can lower the slice margin without changing size.
func small_neon_button_style(button: Button, plate_color: Color, font_size: int = 6,
		texture_margin: float = _SMALL_NEON_BUTTON_TEXTURE_MARGIN) -> void:
	if button == null:
		return
	var plate := _small_neon_button_plate(plate_color)
	_apply_authored_button_style(button, plate, font_size, texture_margin)
	# These used to push the label up by 2-3px on the theory that the font leaves its slack
	# below the glyphs. It leaves it ABOVE: measured against the rendered ink, upper-case
	# copy in this font already sits high, so lifting it again put DONE, CANCEL and TABLES
	# visibly above the middle of their own plates. The box is balanced now, and
	# centered_text_nudge carries the only correction the font actually needs.
	var nudge := centered_text_nudge(font_size)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := button.get_theme_stylebox(String(state))
		style.content_margin_top = 1.0 + nudge + (_PRESS_DROP if state == "pressed" else 0.0)
		style.content_margin_bottom = maxf(0.0, 1.0 - nudge)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.set_meta(&"_start_menu_button_color", plate[&"color"])
	button.set_meta(&"_small_neon_button_asset", plate[&"asset"])

func _apply_authored_button_style(button: Button, plate: Dictionary, font_size: int,
		texture_margin: float) -> void:
	var plate_texture := texture(String(plate[&"asset"]))
	if plate_texture == null:
		return
	var region: Rect2 = plate[&"region"]
	var resolved_color: Color = plate[&"color"]
	button.add_theme_font_size_override("font_size", font_size)
	if font() != null:
		button.add_theme_font_override("font", font())
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxTexture.new()
		style.texture = plate_texture
		style.region_rect = region
		var margin := maxf(texture_margin, 0.0)
		style.texture_margin_left = margin
		style.texture_margin_top = margin
		style.texture_margin_right = margin
		style.texture_margin_bottom = margin
		# A Button centres its label in the CONTENT box, so the difference between the top
		# and bottom margins is exactly how far off the plate's middle the label lands.
		# These used to differ by a hand-tuned pixel, which put every label slightly high —
		# on top of the font's own cap bias, which already sits the ink high. Balance the
		# box and let centered_text_nudge (measured, see its own comment) do the correcting.
		var nudge := centered_text_nudge(font_size)
		style.content_margin_left = 1.0
		style.content_margin_top = 1.0 + nudge
		style.content_margin_right = 1.0
		style.content_margin_bottom = maxf(0.0, 1.0 - nudge)
		if state == "pressed":
			style.content_margin_top = 1.0 + nudge + (0.0 if margin <= 1.0 else _PRESS_DROP)
		elif state == "disabled":
			style.modulate_color = Color(1.0, 1.0, 1.0, 0.45)
		button.add_theme_stylebox_override(String(state), style)
	button.add_theme_color_override("font_color", resolved_color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", resolved_color)
	button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.5))
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _start_menu_button_plate(requested_color: Color) -> Dictionary:
	var cyan_distance := _color_distance_squared(requested_color, START_MENU_BUTTON_CYAN)
	var pink_distance := _color_distance_squared(requested_color, START_MENU_BUTTON_PINK)
	var yellow_distance := _color_distance_squared(requested_color, START_MENU_BUTTON_YELLOW)
	if cyan_distance <= pink_distance and cyan_distance <= yellow_distance:
		return {
			&"asset": _START_MENU_START_BUTTON_REL,
			&"region": _START_MENU_START_BUTTON_REGION,
			&"color": START_MENU_BUTTON_CYAN,
		}
	if pink_distance <= yellow_distance:
		return {
			&"asset": _START_MENU_SCORE_BUTTON_REL,
			&"region": _START_MENU_SCORE_BUTTON_REGION,
			&"color": START_MENU_BUTTON_PINK,
		}
	return {
		&"asset": _START_MENU_OPTIONS_BUTTON_REL,
		&"region": _START_MENU_OPTIONS_BUTTON_REGION,
		&"color": START_MENU_BUTTON_YELLOW,
	}

func _small_neon_button_plate(requested_color: Color) -> Dictionary:
	var cyan_distance := _color_distance_squared(requested_color, START_MENU_BUTTON_CYAN)
	var pink_distance := _color_distance_squared(requested_color, START_MENU_BUTTON_PINK)
	var yellow_distance := _color_distance_squared(requested_color, START_MENU_BUTTON_YELLOW)
	if cyan_distance <= pink_distance and cyan_distance <= yellow_distance:
		return {
			&"asset": _SMALL_NEON_BLUE_BUTTON_REL,
			&"region": _SMALL_NEON_BUTTON_REGION,
			&"color": START_MENU_BUTTON_CYAN,
		}
	if pink_distance <= yellow_distance:
		return {
			&"asset": _SMALL_NEON_PINK_BUTTON_REL,
			&"region": _SMALL_NEON_BUTTON_REGION,
			&"color": START_MENU_BUTTON_PINK,
		}
	return {
		&"asset": _SMALL_NEON_YELLOW_BUTTON_REL,
		&"region": _SMALL_NEON_BUTTON_REGION,
		&"color": START_MENU_BUTTON_YELLOW,
	}

func _color_distance_squared(first: Color, second: Color) -> float:
	var red := first.r - second.r
	var green := first.g - second.g
	var blue := first.b - second.b
	return red * red + green * green + blue * blue

## Give a start-menu text button a small squash-and-release animation while held.
## The metadata guard keeps callers that refresh their styles from wiring it twice.
func start_menu_button_press_feedback(button: Button, pressed_scale: float = 0.9) -> void:
	if button == null or button.has_meta(&"_start_menu_press_feedback"):
		return
	button.set_meta(&"_start_menu_press_feedback", true)
	var visual_size := button.size
	if visual_size == Vector2.ZERO:
		visual_size = button.custom_minimum_size
	if visual_size != Vector2.ZERO:
		button.pivot_offset = visual_size * 0.5
	var clamped_scale := clampf(pressed_scale, 0.75, 0.98)
	button.button_down.connect(_start_menu_button_down.bind(button, clamped_scale))
	button.button_up.connect(_start_menu_button_up.bind(button))

func _start_menu_button_down(button: Button, pressed_scale: float) -> void:
	if not is_instance_valid(button):
		return
	button.scale = Vector2.ONE * pressed_scale
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * minf(1.0, pressed_scale + 0.03), 0.06) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _start_menu_button_up(button: Button) -> void:
	if not is_instance_valid(button):
		return
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, 0.1) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Shared dark panel with a small neon contour for overlays and modal surfaces.
func neon_panel_style(border_color: Color, content_margin: float = 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = NEON_PANEL_FILL
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.32)
	style.shadow_size = 2
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	return style

## Drop shadow under an item/card while it is being dragged. Builds a black
## silhouette from every visible TextureRect inside the item (nested one level or
## more), parents it to the dragged node so it follows every drag update, and
## draws it behind the item. remove_drag_shadow() clears it when the drag ends or
## is cancelled; adding twice replaces the previous shadow.
const DRAG_SHADOW_NAME := "DragShadow"
const DRAG_SHADOW_OFFSET := Vector2(2.0, 3.0)
const DRAG_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.5)

func add_drag_shadow(item: Control) -> void:
	if item == null or not is_instance_valid(item):
		return
	remove_drag_shadow(item)
	var shadow := Control.new()
	shadow.name = DRAG_SHADOW_NAME
	shadow.position = DRAG_SHADOW_OFFSET
	shadow.size = item.size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.modulate = DRAG_SHADOW_COLOR
	shadow.show_behind_parent = true
	_copy_shadow_textures(item, item, shadow)
	if item is TextureRect and (item as TextureRect).texture != null:
		shadow.add_child(_shadow_texture_copy(item as TextureRect, Vector2.ZERO))
	if shadow.get_child_count() == 0:
		shadow.free()
		return
	item.add_child(shadow)
	item.move_child(shadow, 0)

func remove_drag_shadow(item: Control) -> void:
	if item == null or not is_instance_valid(item):
		return
	var shadow := item.get_node_or_null(NodePath(DRAG_SHADOW_NAME))
	if shadow != null:
		shadow.queue_free()

func _copy_shadow_textures(node: Control, base: Control, shadow: Control) -> void:
	for child in node.get_children():
		if not (child is Control) or not (child as Control).visible:
			continue
		if child is TextureRect and (child as TextureRect).texture != null:
			var offset: Vector2 = (child as Control).global_position - base.global_position
			shadow.add_child(_shadow_texture_copy(child as TextureRect, offset))
		_copy_shadow_textures(child as Control, base, shadow)

func _shadow_texture_copy(source: TextureRect, offset: Vector2) -> TextureRect:
	var copy := TextureRect.new()
	copy.texture = source.texture
	copy.position = offset
	copy.size = source.size
	copy.expand_mode = source.expand_mode
	copy.stretch_mode = source.stretch_mode
	copy.texture_filter = source.texture_filter
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return copy

# Shared "negative" skin (ignore / leave / back / close / decline) — the red sheet.
func skin_negative_button(b: Button) -> void:
	skin_sheet_button(b, _RED_BUTTON_REL, 4)

func skin_cancel_button(b: Button) -> void:
	skin_sheet_button(b, _CANCEL_BUTTON_REL, 2)

# Skin an ICON TextureButton (no text). `frames <= 1` uses a single icon; larger
# values use the normal/hover/pressed horizontal sheet convention. Adds a 1-2px
# sink on press.
func skin_icon_button(b: TextureButton, rel: String, frames: int) -> void:
	var tex := texture(rel)
	if tex == null:
		return
	if frames <= 1:
		b.texture_normal = tex
		b.texture_hover = tex
		b.texture_pressed = tex
		b.texture_disabled = tex
	else:
		var sf := _sheet_state_frames(frames)
		b.texture_normal = sheet_frame(rel, sf["normal"], frames)
		b.texture_hover = sheet_frame(rel, sf["hover"], frames)
		b.texture_pressed = sheet_frame(rel, sf["pressed"], frames)
		if frames >= 4:
			b.texture_disabled = sheet_frame(rel, sf["disabled"], frames)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	add_press_feel(b)

# Tactile press for nodes with no inner label (icon buttons): sink position.y a
# couple px while held, restore on release. Robust to a missing button_up.
func add_press_feel(b: BaseButton) -> void:
	b.button_down.connect(_press_sink.bind(b))
	b.button_up.connect(_press_restore.bind(b))

func _press_sink(b: BaseButton) -> void:
	b.set_meta("_rest_y", b.position.y)
	b.position.y += _PRESS_DROP

func _press_restore(b: BaseButton) -> void:
	if b.has_meta("_rest_y"):
		b.position.y = b.get_meta("_rest_y")

func build_symbol_picker_panel(parent: Control, symbols: Array[String], title_text: String, rect: Rect2,
		picked: Callable, cancelled: Callable, use_five_slot_art: bool = false,
		show_title: bool = true, show_cancel: bool = true) -> Control:
	var frame_texture := texture(SYMBOL_PICKER_FRAME_REL)
	var uses_frame := use_five_slot_art and symbols.size() == 5 and frame_texture != null

	var panel := Control.new()
	panel.name = "SymbolPickerPanel"
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)

	var content := Rect2(0.0, 12.0, rect.size.x, rect.size.y - 12.0)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = SYMBOL_PICKER_PANEL_COLOR
	background.position = Vector2.ZERO
	background.size = Vector2.ZERO if uses_frame else rect.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(background)

	if uses_frame:
		var frame := TextureRect.new()
		frame.name = "Frame"
		frame.texture = frame_texture
		frame.position = content.position
		frame.size = Vector2(float(frame_texture.get_width()), float(frame_texture.get_height()))
		frame.scale = Vector2(content.size.x / frame.size.x, content.size.y / frame.size.y)
		frame.stretch_mode = TextureRect.STRETCH_KEEP
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(frame)
	else:
		_build_symbol_picker_slots(panel, symbols.size(), content)

	if show_title:
		var title := Label.new()
		title.name = "TitleLabel"
		title.text = title_text
		title.position = Vector2(0.0, content.position.y - 5.0) if uses_frame else Vector2(0.0, 1.0)
		title.size = Vector2(rect.size.x, 11.0)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_theme_font_size_override("font_size", 7)
		title.add_theme_color_override("font_color", SYMBOL_PICKER_TITLE_COLOR)
		title.add_theme_color_override("font_outline_color", Color.BLACK)
		title.add_theme_constant_override("outline_size", 1)
		if font() != null:
			title.add_theme_font_override("font", font())
		panel.add_child(title)

	if show_cancel:
		var cancel := Button.new()
		cancel.name = "CancelButton"
		cancel.text = ""
		cancel.focus_mode = Control.FOCUS_NONE
		cancel.position = Vector2(rect.size.x - 12.0, content.position.y + 1.0) if uses_frame else Vector2(rect.size.x - 12.0, 1.0)
		cancel.size = Vector2(10.0, 10.0)
		cancel.add_theme_font_size_override("font_size", 6)
		if font() != null:
			cancel.add_theme_font_override("font", font())
		skin_cancel_button(cancel)
		cancel.pressed.connect(func() -> void:
			if cancelled.is_valid():
				cancelled.call()
		)
		panel.add_child(cancel)

	var cell_w := content.size.x / float(maxi(1, symbols.size()))
	for i in symbols.size():
		var symbol_id := symbols[i]
		var button := Button.new()
		button.name = "SymbolButton%s" % symbol_id.capitalize()
		button.focus_mode = Control.FOCUS_NONE
		var button_rect := _symbol_picker_button_rect(i, cell_w, content, frame_texture, uses_frame)
		button.position = button_rect.position
		button.size = button_rect.size
		_apply_symbol_picker_button_style(button)
		button.pressed.connect(picked.bind(symbol_id))
		panel.add_child(button)

		var symbol_texture := texture("symbols/%s.png" % symbol_id, true)
		if symbol_texture != null:
			var icon_size: float = SYMBOL_PICKER_ICON_SIZE if uses_frame else minf(SYMBOL_PICKER_ICON_SIZE, content.size.y - 8.0)
			var icon := Sprite2D.new()
			icon.name = "SymbolIcon%s" % symbol_id.capitalize()
			icon.texture = symbol_texture
			var icon_center := _symbol_picker_icon_center(i, cell_w, content, frame_texture, uses_frame)
			icon.position = icon_center - button.position
			icon.centered = true
			var texture_max_side := float(maxi(symbol_texture.get_width(), symbol_texture.get_height()))
			var icon_scale := icon_size / texture_max_side
			icon.scale = Vector2(icon_scale, icon_scale)
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			button.add_child(icon)

	return panel

func _symbol_picker_button_rect(index: int, cell_w: float, content: Rect2, frame_texture: Texture2D,
		uses_frame: bool) -> Rect2:
	if uses_frame and frame_texture != null and index < SYMBOL_PICKER_FIVE_SLOT_SOURCE_RECTS.size():
		var slot_rect := _symbol_picker_slot_rect(index, content, frame_texture)
		var pad := Vector2(1.0, 1.0)
		return Rect2(slot_rect.position - pad, slot_rect.size + pad * 2.0)
	return Rect2(Vector2(content.position.x + float(index) * cell_w, content.position.y),
		Vector2(cell_w, content.size.y))

func _symbol_picker_icon_center(index: int, cell_w: float, content: Rect2, frame_texture: Texture2D,
		uses_frame: bool) -> Vector2:
	if uses_frame and frame_texture != null and index < SYMBOL_PICKER_FIVE_SLOT_SOURCE_RECTS.size():
		return _symbol_picker_slot_rect(index, content, frame_texture).get_center()
	return Vector2(content.position.x + (float(index) + 0.5) * cell_w, content.position.y + content.size.y * 0.5)

func _symbol_picker_slot_rect(index: int, content: Rect2, frame_texture: Texture2D) -> Rect2:
	var source_rect := SYMBOL_PICKER_FIVE_SLOT_SOURCE_RECTS[index]
	var scale := Vector2(content.size.x / float(frame_texture.get_width()),
		content.size.y / float(frame_texture.get_height()))
	return Rect2(content.position + source_rect.position * scale, source_rect.size * scale)

func _build_symbol_picker_slots(parent: Control, count: int, content: Rect2) -> void:
	var cell_w := content.size.x / float(maxi(1, count))
	for i in count:
		var slot := ColorRect.new()
		slot.name = "Slot%d" % i
		slot.color = SYMBOL_PICKER_SLOT_COLOR
		slot.position = Vector2(content.position.x + float(i) * cell_w + 2.0, content.position.y + 5.0)
		slot.size = Vector2(maxf(1.0, cell_w - 4.0), maxf(1.0, content.size.y - 10.0))
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(slot)

func _apply_symbol_picker_button_style(button: Button) -> void:
	var states := {
		"normal": _symbol_picker_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0)),
		"hover": _symbol_picker_style(SYMBOL_PICKER_SLOT_HOVER, SYMBOL_PICKER_SLOT_BORDER),
		"pressed": _symbol_picker_style(SYMBOL_PICKER_SLOT_PRESSED, Color(0.72, 1.0, 0.65, 1.0)),
		"focus": _symbol_picker_style(Color(0.0, 0.0, 0.0, 0.0), SYMBOL_PICKER_SLOT_BORDER),
		"disabled": _symbol_picker_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0)),
	}
	for state in states:
		button.add_theme_stylebox_override(String(state), states[state])
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _symbol_picker_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	return style
