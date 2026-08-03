extends SceneTree
## Temporary audit helper: the UI font's box metrics next to where its ink actually lands,
## per size. Centred labels centre the ascent+descent box, but the game's copy is upper
## case and never uses the descent — which is why centred text reads high. This prints the
## nudge that would put the INK in the middle instead.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var font: FontFile = get_root().get_node("Assets").call("font") as FontFile
	print("\n=== FONT BOX vs INK ===")
	print("size ascent descent height | box-centred ink T/B in a 20px label | nudge")
	for fs in [3, 4, 5, 6, 7, 8, 9, 10, 12]:
		var box := "%4d %6.2f %7.2f %6.2f" % [
			fs, font.get_ascent(fs), font.get_descent(fs), font.get_height(fs)]
		var probe := await _probe(font, fs, "ABC 123 XYZ")
		var lower := await _probe(font, fs, "agpy quill")
		print("%s | UPPER T%.0f B%.0f nudge %+.1f | mixed T%.0f B%.0f nudge %+.1f" % [
			box, probe.x, probe.y, (probe.y - probe.x) * 0.5,
			lower.x, lower.y, (lower.y - lower.x) * 0.5])
	quit(0)

## Renders `text` centred in a 60x20 label and returns the top and bottom ink gaps.
func _probe(font: FontFile, fs: int, text: String) -> Vector2:
	# Box height chosen so (box - font height) is EVEN: an odd remainder makes Godot's own
	# centring land on a half pixel and shows up as a fake half-pixel bias in the result.
	var h := int(font.get_height(fs)) + 20
	var vp := SubViewport.new()
	vp.size = Vector2i(60, h)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	get_root().add_child(vp)
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vp.add_child(l)
	l.text = text
	l.size = Vector2(60, h)
	await process_frame
	await process_frame
	var img := vp.get_texture().get_image()
	var top := -1
	var bottom := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.2:
				if top < 0:
					top = y
				bottom = y
				break
	get_root().remove_child(vp)
	vp.queue_free()
	if top < 0:
		return Vector2(-1, -1)
	return Vector2(top, h - 1 - bottom)
