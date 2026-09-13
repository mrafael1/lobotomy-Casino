extends SceneTree

const SOURCE := "res://assets/images/ui/premium/icons_painted.png"
const OUTPUT := "res://assets/images/ui/premium/"
const NAMES := ["settings", "left", "right", "close", "confirm", "coin"]

func _initialize() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	assert(sheet != null)
	var cell := Vector2i(sheet.get_width() / 3, sheet.get_height() / 2)
	for index in range(NAMES.size()):
		var tile := sheet.get_region(Rect2i(Vector2i(index % 3, index / 3) * cell, cell))
		tile = tile.get_region(tile.get_used_rect())
		var factor := 16.0 / float(maxi(tile.get_width(), tile.get_height()))
		tile.resize(maxi(1, roundi(tile.get_width() * factor)), maxi(1, roundi(tile.get_height() * factor)), Image.INTERPOLATE_NEAREST)
		var icon := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		icon.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), (Vector2i(16, 16) - tile.get_size()) / 2)
		assert(icon.save_png(ProjectSettings.globalize_path(OUTPUT + NAMES[index] + ".png")) == OK)
	print("Prepared six native hardware icons")
	quit()
