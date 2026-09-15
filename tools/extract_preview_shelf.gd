extends SceneTree

## Preserve four source pixels per layout unit, including the painted SPIN lettering.
const OUT := "res://assets/images/machine_polished/"
const SCALE := 4
const CAP := Rect2i(64, 203, 31, 14)
const SHIFT := Vector2i(0, 11)

func _initialize() -> void:
	var source := Image.load_from_file("res://../tools/art_sources/control-shelf-preview.jpg")
	assert(source != null)
	source.resize(160 * SCALE, 320 * SCALE, Image.INTERPOLATE_LANCZOS)
	source.convert(Image.FORMAT_RGBA8)
	var shelf := Image.create(160 * SCALE, 320 * SCALE, false, Image.FORMAT_RGBA8)
	shelf.blit_rect(source, _rect(Rect2i(0, 199, 160, 39)), (Vector2i(0, 199) + SHIFT) * SCALE)
	# Only the changing contents are removed; hardware remains copied from the master.
	for area in [Rect2i(30, 205, 10, 9), Rect2i(42, 207, 12, 6), Rect2i(103, 204, 13, 12), Rect2i(121, 204, 13, 12)]:
		var target := Rect2i((area.position + SHIFT) * SCALE, area.size * SCALE)
		shelf.fill_rect(target, source.get_pixel(area.position.x * SCALE, 216 * SCALE))
	shelf.fill_rect(Rect2i((CAP.position + SHIFT) * SCALE, CAP.size * SCALE), Color("#171c18"))
	assert(shelf.save_png(OUT + "preview_shelf.png") == OK)
	for state in ["normal", "pressed", "disabled", "hover", "focus"]:
		var button := Image.create(46 * SCALE, 28 * SCALE, false, Image.FORMAT_RGBA8)
		var depression := 2 if state == "pressed" else 0
		button.blit_rect(source, _rect(CAP), Vector2i(7, 1 + depression) * SCALE)
		for y in button.get_height():
			for x in button.get_width():
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
			button.fill(Color.TRANSPARENT)
			for point in [Vector2i(5, 0), Vector2i(39, 0), Vector2i(5, 18), Vector2i(39, 18)]:
				button.fill_rect(Rect2i(point * SCALE, Vector2i.ONE * SCALE), Color("#d9dfaa"))
		assert(button.save_png(OUT + "preview_spin_%s.png" % state) == OK)
	var idle := Image.load_from_file(OUT + "preview_spin_normal.png")
	assert(idle.get_pixel(7 * SCALE, SCALE) == source.get_pixelv(CAP.position * SCALE))
	for point in [Vector2i(23, 200), Vector2i(60, 217), Vector2i(99, 209), Vector2i(118, 210), Vector2i(137, 217), Vector2i(80, 230)]:
		assert(shelf.get_pixelv((point + SHIFT) * SCALE) == source.get_pixelv(point * SCALE))
	print("Detailed preview shelf: source hardware and SPIN lettering preserved")
	quit()

func _rect(rect: Rect2i) -> Rect2i:
	return Rect2i(rect.position * SCALE, rect.size * SCALE)
