extends SceneTree

## Literal artwork extraction, not a redraw. Run with --path godot -s ../tools/extract_preview_shelf.gd.
const OUT := "res://assets/images/machine_polished/"
const CAP := Rect2i(64, 203, 31, 14)
const SHIFT := Vector2i(0, 11)
const LETTERS := ["01111100001000001110000010000111110", "11110100011000111110100001000010000", "11111001000010000100001000010011111", "10001110011100110101100111001110001"]

func _initialize() -> void:
	var source := Image.load_from_file("res://../tools/art_sources/control-shelf-preview.jpg")
	assert(source != null)
	# Preserve the source's hard pixel edges; averaging introduces a soft halo
	# that nearest filtering at runtime cannot undo.
	source.resize(160, 320, Image.INTERPOLATE_NEAREST)
	source.convert(Image.FORMAT_RGBA8)
	var shelf := Image.create(160, 320, false, Image.FORMAT_RGBA8)
	shelf.blit_rect(source, Rect2i(0, 199, 160, 39), Vector2i(0, 199) + SHIFT)
	# Clear only changing contents. Frame, bevel, wear and corner pixels stay intact.
	for area in [Rect2i(30, 205, 10, 9), Rect2i(42, 207, 12, 6), Rect2i(103, 204, 13, 12), Rect2i(121, 204, 13, 12)]:
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				shelf.set_pixel(x, y + SHIFT.y, source.get_pixel(area.position.x, 216))
	for y in range(CAP.position.y, CAP.end.y):
		for x in range(CAP.position.x, CAP.end.x):
			shelf.set_pixel(x, y + SHIFT.y, Color("#171c18"))
	assert(shelf.save_png(OUT + "preview_shelf.png") == OK)
	for state in ["normal", "pressed", "disabled", "hover", "focus"]:
		var button := Image.create(46, 28, false, Image.FORMAT_RGBA8)
		var depression := 2 if state == "pressed" else 0
		button.blit_rect(source, CAP, Vector2i(7, 1 + depression))
		# Replace only the reduced lettering; retain the painted face's row shading.
		for y in range(3, 12):
			for x in range(11, 36):
				button.set_pixel(x, y + depression, source.get_pixel(67, 202 + y))
		for letter in range(LETTERS.size()):
			for bit in range(35):
				if LETTERS[letter][bit] == "1":
					button.set_pixel(11 + letter * 6 + bit % 5, 4 + bit / 5 + depression, Color("#242820"))
		for y in range(28):
			for x in range(46):
				var pixel := button.get_pixel(x, y)
				if pixel.a == 0:
					continue
				if state == "disabled":
					var grey := pixel.get_luminance()
					pixel = Color(grey * 0.65, grey * 0.66, grey * 0.60, pixel.a)
				elif state in ["hover", "focus"]:
					pixel = pixel.lightened(0.10)
				button.set_pixel(x, y, pixel)
		if state == "focus":
			# Godot draws focus over the current state: never cover the depressed cap.
			button.fill(Color.TRANSPARENT)
			for point in [Vector2i(5, 0), Vector2i(39, 0), Vector2i(5, 18), Vector2i(39, 18)]:
				button.set_pixelv(point, Color("#d9dfaa"))
		assert(button.save_png(OUT + "preview_spin_%s.png" % state) == OK)
	# Original stationary hardware and cap corners remain copied, not redrawn.
	var idle := Image.load_from_file(OUT + "preview_spin_normal.png")
	assert(idle.get_pixel(7, 1) == source.get_pixelv(CAP.position))
	assert(idle.get_pixel(37, 14) == source.get_pixelv(CAP.end - Vector2i.ONE))
	for point in [Vector2i(23, 200), Vector2i(60, 217), Vector2i(99, 209), Vector2i(118, 210), Vector2i(137, 217), Vector2i(80, 230)]:
		assert(shelf.get_pixelv(point + SHIFT) == source.get_pixelv(point))
	print("Preview shelf extraction: source pixels preserved")
	quit()
