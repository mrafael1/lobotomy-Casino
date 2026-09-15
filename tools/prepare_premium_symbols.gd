extends SceneTree

const SOURCE := "res://assets/images/symbols/premium/symbols_painted.png"
const OUTPUT := "res://assets/images/symbols/premium/"
const EXPORT_SIZE := 128
const NAMES := ["brain", "eye", "pill", "syringe", "vial", "flatline", "heart x1", "heart x2", "heart x3"]

func _initialize() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	assert(sheet != null)
	# Find the actual transparent gutters rather than cutting an icon at a grid line.
	var bands: Array[Vector2i] = []
	var first := -1
	for y in range(sheet.get_height() + 1):
		var pixels := 0
		if y < sheet.get_height():
			for x in range(sheet.get_width()):
				if sheet.get_pixel(x, y).a > 0.5:
					pixels += 1
		if pixels > 3 and first < 0:
			first = y
		elif pixels <= 3 and first >= 0:
			if y - first > 50:
				bands.append(Vector2i(first, y - first))
			first = -1
	assert(bands.size() == 3, "Expected three separated rows")
	var width := sheet.get_width() / 3
	for index in range(NAMES.size()):
		var band: Vector2i = bands[index / 3]
		var tile := sheet.get_region(Rect2i(index % 3 * width, band.x, width, band.y))
		tile = tile.get_region(tile.get_used_rect())
		var factor := float(EXPORT_SIZE) / float(maxi(tile.get_width(), tile.get_height()))
		tile.resize(maxi(1, roundi(tile.get_width() * factor)), maxi(1, roundi(tile.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
		var icon := Image.create(EXPORT_SIZE, EXPORT_SIZE, false, Image.FORMAT_RGBA8)
		icon.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), (Vector2i(EXPORT_SIZE, EXPORT_SIZE) - tile.get_size()) / 2)
		assert(icon.save_png(ProjectSettings.globalize_path(OUTPUT + NAMES[index] + ".png")) == OK)
	print("Prepared nine detailed 128px reel symbols")
	quit()
