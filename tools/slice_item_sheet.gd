extends SceneTree

## Prepare the generated Pacte item sheet for runtime use.
## Each source cell is cropped to its opaque silhouette, padded, and placed on a
## 128x128 transparent canvas. Linear mipmaps retain painted detail when the
## icons are shown inside their existing 16-unit layout footprints.

const SOURCE := "res://assets/images/pacte_polished/generated_set/items_painted.png"
const OUTPUT_DIR := "res://assets/images/items/generated"
const NAMES := [
	["tobacco", 0, 0], ["serum", 1, 0], ["white_powder", 2, 0],
	["potion", 0, 1], ["tea", 1, 1], ["energy_drink", 2, 1],
	["cocktail", 0, 2], ["water", 1, 2], ["red_pill", 2, 2],
]

func _initialize() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	assert(source != null, "Missing generated item sheet: %s" % SOURCE)
	source.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var cell_w := source.get_width() / 3
	var cell_h := source.get_height() / 3
	for entry: Array in NAMES:
		var name := String(entry[0])
		var cell := Rect2i(int(entry[1]) * cell_w, int(entry[2]) * cell_h, cell_w, cell_h)
		var region := source.get_region(cell)
		var used := region.get_used_rect()
		assert(used.size.x > 0 and used.size.y > 0, "Empty generated item cell: %s" % name)
		var margin := 8
		var crop_pos := Vector2i(maxi(0, used.position.x - margin), maxi(0, used.position.y - margin))
		var crop_end := Vector2i(mini(region.get_width(), used.end.x + margin), mini(region.get_height(), used.end.y + margin))
		var crop := region.get_region(Rect2i(crop_pos, crop_end - crop_pos))
		var scale := minf(120.0 / float(crop.get_width()), 120.0 / float(crop.get_height()))
		var resized_w := maxi(1, roundi(float(crop.get_width()) * scale))
		var resized_h := maxi(1, roundi(float(crop.get_height()) * scale))
		crop.resize(resized_w, resized_h, Image.INTERPOLATE_LANCZOS)
		var icon := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		icon.fill(Color(0.0, 0.0, 0.0, 0.0))
		icon.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()),
			Vector2i((128 - resized_w) / 2, (128 - resized_h) / 2))
		var path := ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, name])
		assert(icon.save_png(path) == OK, "Could not save generated item: %s" % path)
	print("Sliced generated item icons into 128x128 transparent PNGs")
	quit()
