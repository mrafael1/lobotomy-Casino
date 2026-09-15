extends SceneTree

## Extract the four isolated, alpha-separated painted states, then sample once.
const SOURCE := "res://assets/images/ui/premium/buttons_painted.png"
const OUTPUT := "res://assets/images/ui/premium/"
const STATES := ["normal", "hover", "pressed", "disabled"]

func _initialize() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	assert(source != null)
	var bands: Array[Rect2i] = []
	var first := -1
	for y in range(source.get_height() + 1):
		var filled := 0
		if y < source.get_height():
			for x in range(source.get_width()):
				if source.get_pixel(x, y).a > 0.5:
					filled += 1
		var active := filled > source.get_width() / 2
		if active and first < 0:
			first = y
		elif not active and first >= 0:
			if y - first > 20:
				bands.append(Rect2i(0, first, source.get_width(), y - first))
			first = -1
	assert(bands.size() == 4, "Expected four isolated button states")
	for index in range(bands.size()):
		var tile := source.get_region(bands[index])
		tile = tile.get_region(tile.get_used_rect())
		tile.resize(96, 20, Image.INTERPOLATE_NEAREST)
		assert(tile.save_png(ProjectSettings.globalize_path(OUTPUT + STATES[index] + ".png")) == OK)
	print("Prepared four native button states")
	quit()
