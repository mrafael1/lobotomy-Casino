@tool
extends Node

## Autoload "Assets" — process-wide cache for textures and fonts loaded by absolute
## path from ../assets (the Expo project stays the single source of art). Caching
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

static func _images_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../assets/images")

static func _assets_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../assets")

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
	var img := Image.new()
	if img.load(_images_dir().path_join(rel)) != OK:
		push_warning("Assets: missing texture " + rel)
		_tex[key] = null
		return null
	if mipmaps:
		img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t

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
	var f := FontFile.new()
	if f.load_dynamic_font(_assets_dir().path_join(rel)) != OK:
		push_warning("Assets: missing font " + rel)
		_fonts[rel] = null
		return null
	_fonts[rel] = f
	return f

# ── Skinned buttons ─────────────────────────────────────────────────────────────────
# Button art lives in horizontal sprite sheets under ui/. Frame order by count:
#   2 -> [normal, pressed]   3 -> [normal, hover, pressed]   4 -> [+ disabled]
const _RED_BUTTON_REL := "ui/red_button.png"
const _PRESS_DROP := 2.0 # px the label/icon sinks on press, for a tactile feel

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
