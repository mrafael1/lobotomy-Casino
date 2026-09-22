@tool
extends Node

## Autoload "Assets" — process-wide cache for textures and fonts loaded by absolute
## res://assets. Caching
## across scene changes matters on Android: the 8x machine cabinet (1280x2560) is a
## ~13 MB texture, and reloading it every shop<->machine transition would hitch and
## churn VRAM. Loaded once here, reused everywhere.

var _tex := {}
var _fonts := {}
const PAINTED_SYMBOLS := ["brain.png", "eye.png", "pill.png", "syringe.png", "vial.png", "flatline.png", "heart x1.png", "heart x2.png", "heart x3.png"]

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

static func _res_image(rel: String) -> String:
	return "res://assets/images/" + rel

static func _res_asset(rel: String) -> String:
	return "res://assets/" + rel

# Texture under assets/images/<rel>. Cached by (rel, mipmaps). Returns null if missing.
func texture(rel: String, mipmaps := false) -> Texture2D:
	# All reel, chooser, duration and odds-table views share the same symbol art.
	if rel.get_base_dir() == "symbols" and PAINTED_SYMBOLS.has(rel.get_file()):
		rel = "symbols/premium/" + rel.get_file()
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

