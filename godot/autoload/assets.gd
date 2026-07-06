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

# ── Skinned buttons ─────────────────────────────────────────────────────────────────
# Button art lives in horizontal sprite sheets under ui/. Frame order by count:
#   2 -> [normal, pressed]   3 -> [normal, hover, pressed]   4 -> [+ disabled]
const _RED_BUTTON_REL := "ui/red_button.png"
const _CANCEL_BUTTON_REL := "ui/cancel_button.png"
const _PRESS_DROP := 2.0 # px the label/icon sinks on press, for a tactile feel
const _BUTTON_TEXT_BOTTOM_MARGIN := 2.0
const SYMBOL_PICKER_FRAME_REL := "ui/symbol_chosing.png"
const SYMBOL_PICKER_TITLE_COLOR := Color(0.72, 1.0, 0.65)
const SYMBOL_PICKER_PANEL_COLOR := Color(0.05, 0.03, 0.1, 0.94)
const SYMBOL_PICKER_SLOT_COLOR := Color(0.18, 0.13, 0.26, 0.95)
const SYMBOL_PICKER_SLOT_BORDER := Color(0.45, 0.38, 0.62, 0.9)
const SYMBOL_PICKER_SLOT_HOVER := Color(0.28, 0.2, 0.42, 0.9)
const SYMBOL_PICKER_SLOT_PRESSED := Color(0.45, 0.38, 0.62, 0.95)
const SYMBOL_PICKER_ICON_SIZE := 14.0
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

# Shared "negative" skin (ignore / leave / back / close / decline) — the red sheet.
func skin_negative_button(b: Button) -> void:
	skin_sheet_button(b, _RED_BUTTON_REL, 4)

func skin_cancel_button(b: Button) -> void:
	skin_sheet_button(b, _CANCEL_BUTTON_REL, 2)

# Skin an ICON TextureButton from a sheet (no text). Adds a 1-2px sink on press.
func skin_icon_button(b: TextureButton, rel: String, frames: int) -> void:
	if texture(rel) == null:
		return
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
		picked: Callable, cancelled: Callable, use_five_slot_art := false) -> Control:
	var frame_texture := texture(SYMBOL_PICKER_FRAME_REL)
	var uses_frame := use_five_slot_art and symbols.size() == 5 and frame_texture != null

	var panel := Control.new()
	panel.name = "SymbolPickerPanel"
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = SYMBOL_PICKER_PANEL_COLOR
	background.position = Vector2.ZERO
	background.size = Vector2(rect.size.x, 12.0) if uses_frame else rect.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(background)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = title_text
	title.position = Vector2(0.0, 1.0)
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

	var cancel := Button.new()
	cancel.name = "CancelButton"
	cancel.text = ""
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.position = Vector2(rect.size.x - 12.0, 1.0)
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

	var content := Rect2(0.0, 12.0, rect.size.x, rect.size.y - 12.0)
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

	var cell_w := content.size.x / float(maxi(1, symbols.size()))
	for i in symbols.size():
		var symbol_id := symbols[i]
		var button := Button.new()
		button.name = "SymbolButton%s" % symbol_id.capitalize()
		button.focus_mode = Control.FOCUS_NONE
		var button_rect := _symbol_picker_button_rect(i, cell_w, content)
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
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			button.add_child(icon)

	return panel

func _symbol_picker_button_rect(index: int, cell_w: float, content: Rect2) -> Rect2:
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
