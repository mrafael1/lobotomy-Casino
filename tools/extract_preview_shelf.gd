extends SceneTree

## Literal artwork extraction, not a redraw. Run with --path godot -s ../tools/extract_preview_shelf.gd.
const OUT := "res://assets/images/machine_polished/"
const CAP := Rect2i(64, 203, 31, 14)
const SHIFT := Vector2i(0, 8)

func _initialize() -> void:
	var source := Image.load_from_file("res://../tools/art_sources/control-shelf-preview.jpg")
	assert(source != null)
	source.resize(160, 320, Image.INTERPOLATE_LANCZOS)
	source.convert(Image.FORMAT_RGBA8)
	var shelf := Image.create(160, 320, false, Image.FORMAT_RGBA8)
	shelf.blit_rect(source, Rect2i(0, 199, 160, 39), Vector2i(0, 207))
	# Clear only changing contents. Frame, bevel, wear and corner pixels stay intact.
	for area in [Rect2i(30, 205, 10, 9), Rect2i(103, 204, 13, 12), Rect2i(121, 204, 13, 12)]:
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
	# Exact reconstruction of the original stationary hardware and idle button.
	var idle := Image.load_from_file(OUT + "preview_spin_normal.png")
	assert(idle.get_region(Rect2i(7, 1, 31, 14)).get_data() == source.get_region(CAP).get_data())
	for point in [Vector2i(23, 200), Vector2i(60, 217), Vector2i(99, 209), Vector2i(118, 210), Vector2i(137, 217), Vector2i(80, 230)]:
		assert(shelf.get_pixelv(point + SHIFT) == source.get_pixelv(point))
	print("Preview shelf extraction: source pixels preserved")
	quit()
