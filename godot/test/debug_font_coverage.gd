extends SceneTree
## Temporary audit helper: does the UI font actually have the glyphs French needs?
## A missing glyph does not error — it renders as a blank or a box — so this asks the font
## directly, and then renders a sample to catch a glyph that exists but is empty.

const FRENCH := "ÉÈÊËÀÂÇÎÏÔÖÙÛÜŒ«»éèêëàâçîïôöùûüœ"
const ASCII_REF := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var assets: Node = get_root().get_node("Assets")
	for rel in ["font/DTM-Sans.otf", "font/DTM-Mono.otf"]:
		var font: FontFile = assets.call("font", rel) as FontFile
		if font == null:
			print("%s: MISSING" % rel)
			continue
		var missing := ""
		for i in FRENCH.length():
			var c := FRENCH[i]
			if not _has_glyph(font, c):
				missing += c
		print("\n%s" % rel)
		print("  ascii sample width @5: %.1f" % font.get_string_size(
			ASCII_REF, HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x)
		print("  french glyphs missing from the font table: %s" % (
			"(none)" if missing == "" else missing))
		# A glyph can be present but blank. Render each one and check that ink lands.
		var blank := ""
		for i in FRENCH.length():
			var c := FRENCH[i]
			if not await _renders_ink(font, c):
				blank += c
		print("  present but render EMPTY: %s" % ("(none)" if blank == "" else blank))
		# Accents need headroom: a capital E-acute is taller than a capital E.
		print("  height@5 %.1f  'E' %s  'É' %s" % [
			font.get_height(5),
			font.get_string_size("E", HORIZONTAL_ALIGNMENT_LEFT, -1, 5),
			font.get_string_size("É", HORIZONTAL_ALIGNMENT_LEFT, -1, 5)])
	quit(0)

func _has_glyph(font: FontFile, c: String) -> bool:
	var rid := font.find_variation({})
	return TextServerManager.get_primary_interface().font_has_char(rid, c.unicode_at(0))

## Draws one character large and reports whether any pixel was painted.
func _renders_ink(font: FontFile, c: String) -> bool:
	var vp := SubViewport.new()
	vp.size = Vector2i(48, 48)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	get_root().add_child(vp)
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color.WHITE)
	vp.add_child(l)
	l.text = c
	await process_frame
	await process_frame
	var img := vp.get_texture().get_image()
	var inked := false
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.2:
				inked = true
				break
		if inked:
			break
	get_root().remove_child(vp)
	vp.queue_free()
	return inked
