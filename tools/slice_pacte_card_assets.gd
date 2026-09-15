extends SceneTree

## Export painted cards and decks at four pixels per layout unit.
## Runtime controls keep their original card and deck footprints.

const CARD_SOURCE := "res://assets/images/pacte_polished/generated_set/cards_painted.png"
const DECK_SOURCE := "res://assets/images/pacte_polished/generated_set/decks_painted.png"
const OUTPUT_DIR := "res://assets/images/pacte_polished/generated_set"
const CARD_OUTPUT := "cards_detail.png"
const CARD_WIDTH := 156
const CARD_HEIGHT := 244
const DECK_WIDTH := 112
const DECK_HEIGHT := 128

func _initialize() -> void:
	var cards := Image.load_from_file(ProjectSettings.globalize_path(CARD_SOURCE))
	var decks := Image.load_from_file(ProjectSettings.globalize_path(DECK_SOURCE))
	assert(cards != null and decks != null, "Missing generated Pacte card/deck source")
	cards.convert(Image.FORMAT_RGBA8)
	decks.convert(Image.FORMAT_RGBA8)
	var cards_native := Image.create(CARD_WIDTH * 4, CARD_HEIGHT, false, Image.FORMAT_RGBA8)
	cards_native.fill(Color(0.0, 0.0, 0.0, 0.0))
	var card_cell_w := cards.get_width() / 4
	for index in 4:
		var cell := Rect2i(index * card_cell_w, 0, card_cell_w if index < 3 else cards.get_width() - index * card_cell_w, cards.get_height())
		var crop := _opaque_crop(cards.get_region(cell))
		var native := _resize_exact(crop, Vector2i(CARD_WIDTH, CARD_HEIGHT))
		cards_native.blit_rect(native, Rect2i(Vector2i.ZERO, native.get_size()),
			Vector2i(index * CARD_WIDTH, 0))
	assert(cards_native.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, CARD_OUTPUT])) == OK)

	var deck_cell_w := decks.get_width() / 2
	var deck_names := ["augment_deck_detail.png", "power_deck_detail.png"]
	for index in 2:
		var cell := Rect2i(index * deck_cell_w, 0, deck_cell_w if index == 0 else decks.get_width() - index * deck_cell_w, decks.get_height())
		var crop := _opaque_crop(decks.get_region(cell))
		var native := _resize_exact(crop, Vector2i(DECK_WIDTH, DECK_HEIGHT))
		assert(native.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, deck_names[index]])) == OK)
	print("Sliced generated Pacte cards and decks")
	quit()

func _opaque_crop(region: Image) -> Image:
	var min_x := region.get_width()
	var min_y := region.get_height()
	var max_x := -1
	var max_y := -1
	var column_counts := PackedInt32Array()
	column_counts.resize(region.get_width())
	var row_counts := PackedInt32Array()
	row_counts.resize(region.get_height())
	for y in region.get_height():
		for x in region.get_width():
			if region.get_pixel(x, y).a > 0.125:
				column_counts[x] += 1
				row_counts[y] += 1
	for x in region.get_width():
		if column_counts[x] > 10:
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
	for y in region.get_height():
		if row_counts[y] > 10:
			min_y = mini(min_y, y)
			max_y = maxi(max_y, y)
	assert(max_x >= min_x and max_y >= min_y, "Generated Pacte cell has no opaque art")
	return region.get_region(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))

func _resize_exact(source: Image, target_size: Vector2i) -> Image:
	source.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	return source
