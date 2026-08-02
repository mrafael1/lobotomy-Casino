class_name ButtonKit
extends RefCounted

## Every skinned button in the game, and the plate art behind it.
##
## This was the largest of three unrelated neighbourhoods living inside the Assets
## autoload. Assets is a cache — it holds textures and fonts and hands them out — and none
## of the theming below needed to be there; it was there because Assets was already
## loaded everywhere. Splitting it out leaves the cache a cache and gives button styling
## a name of its own, so "how does a button get its look" has an answer that is not
## "somewhere in a 665-line autoload".
##
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

# Per-state -> frame index for a sheet of `frames` frames.
static func _sheet_state_frames(frames: int) -> Dictionary:
	if frames <= 2:
		return {"normal": 0, "hover": 1, "pressed": 1, "disabled": 1, "focus": 0}
	if frames == 3:
		return {"normal": 0, "hover": 1, "pressed": 2, "disabled": 0, "focus": 0}
	return {"normal": 0, "hover": 1, "pressed": 2, "disabled": 3, "focus": 0}

# AtlasTexture for one frame of a horizontal sheet (for TextureButton/TextureRect).
static func sheet_frame(rel: String, frame: int, frames: int) -> AtlasTexture:
	var tex := UiKit.texture(rel)
	if tex == null:
		return null
	var fw := float(tex.get_width()) / float(frames)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(float(frame) * fw, 0.0, fw, float(tex.get_height()))
	return at

# Skin a TEXT Button with a sheet: one StyleBoxTexture region per state. The pressed
# state insets the top so the label visibly sinks a couple px. No-op if art missing.
static func skin_sheet_button(b: Button, rel: String, frames: int) -> void:
	var tex := UiKit.texture(rel)
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
static func start_menu_button_style(button: Button, plate_color: Color, font_size: int = 6,
		texture_margin: float = _START_MENU_BUTTON_TEXTURE_MARGIN) -> void:
	if button == null:
		return
	var plate := _start_menu_button_plate(plate_color)
	_apply_authored_button_style(button, plate, font_size, texture_margin)
	button.set_meta(&"_start_menu_button_color", plate[&"color"])

## Uses the dedicated 45x22 button art for compact controls. Callers with
## sub-22px authored hit areas can lower the slice margin without changing size.
static func small_neon_button_style(button: Button, plate_color: Color, font_size: int = 6,
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
	var nudge := UiKit.centered_text_nudge(font_size)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := button.get_theme_stylebox(String(state))
		style.content_margin_top = 1.0 + nudge + (_PRESS_DROP if state == "pressed" else 0.0)
		style.content_margin_bottom = maxf(0.0, 1.0 - nudge)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.set_meta(&"_start_menu_button_color", plate[&"color"])
	button.set_meta(&"_small_neon_button_asset", plate[&"asset"])

static func _apply_authored_button_style(button: Button, plate: Dictionary, font_size: int,
		texture_margin: float) -> void:
	var plate_texture := UiKit.texture(String(plate[&"asset"]))
	if plate_texture == null:
		return
	var region: Rect2 = plate[&"region"]
	var resolved_color: Color = plate[&"color"]
	button.add_theme_font_size_override("font_size", font_size)
	if UiKit.font() != null:
		button.add_theme_font_override("font", UiKit.font())
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
		var nudge := UiKit.centered_text_nudge(font_size)
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

static func _start_menu_button_plate(requested_color: Color) -> Dictionary:
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

static func _small_neon_button_plate(requested_color: Color) -> Dictionary:
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

static func _color_distance_squared(first: Color, second: Color) -> float:
	var red := first.r - second.r
	var green := first.g - second.g
	var blue := first.b - second.b
	return red * red + green * green + blue * blue

## Give a start-menu text button a small squash-and-release animation while held.
## The metadata guard keeps callers that refresh their styles from wiring it twice.
static func start_menu_button_press_feedback(button: Button, pressed_scale: float = 0.9) -> void:
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

static func _start_menu_button_down(button: Button, pressed_scale: float) -> void:
	if not is_instance_valid(button):
		return
	button.scale = Vector2.ONE * pressed_scale
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * minf(1.0, pressed_scale + 0.03), 0.06) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

static func _start_menu_button_up(button: Button) -> void:
	if not is_instance_valid(button):
		return
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, 0.1) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Shared dark panel with a small neon contour for overlays and modal surfaces.
static func neon_panel_style(border_color: Color, content_margin: float = 0.0) -> StyleBoxFlat:
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

# Shared "negative" skin (ignore / leave / back / close / decline) — the red sheet.
static func skin_negative_button(b: Button) -> void:
	skin_sheet_button(b, _RED_BUTTON_REL, 4)

static func skin_cancel_button(b: Button) -> void:
	skin_sheet_button(b, _CANCEL_BUTTON_REL, 2)

# Skin an ICON TextureButton (no text). `frames <= 1` uses a single icon; larger
# values use the normal/hover/pressed horizontal sheet convention. Adds a 1-2px
# sink on press.
static func skin_icon_button(b: TextureButton, rel: String, frames: int) -> void:
	var tex := UiKit.texture(rel)
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
static func add_press_feel(b: BaseButton) -> void:
	b.button_down.connect(_press_sink.bind(b))
	b.button_up.connect(_press_restore.bind(b))

static func _press_sink(b: BaseButton) -> void:
	b.set_meta("_rest_y", b.position.y)
	b.position.y += _PRESS_DROP

static func _press_restore(b: BaseButton) -> void:
	if b.has_meta("_rest_y"):
		b.position.y = b.get_meta("_rest_y")
