extends SceneTree

const ROOT := "res://assets/images/cards/painted/"
const AUGMENTS := ["augment_smart_saving", "augment_hallucination", "augment_reward_1", "augment_reward_2", "augment_reward_3", "augment_joker", "augment_win_boost", "augment_tunnel_vision", "augment_adrenaline", "augment_passive_gain", "augment_pattern_recognition", "augment_how_to_cheat"]
const POWERS := ["reroll", "shift", "memory", "rewind", "heart", "cheat", "swap", "book_variant", "power_coin"]

func _initialize() -> void:
	_slice("augments_painted.png", AUGMENTS, 4)
	_slice("powers_painted.png", POWERS, 3)
	print("Prepared painted card emblems")
	quit()

func _slice(source: String, names: Array, rows: int) -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(ROOT + source))
	assert(sheet != null)
	var cell := Vector2i(sheet.get_width() / 3, sheet.get_height() / rows)
	for index in range(names.size()):
		# Animated card emblems retain their authored sequences; Book already has a master.
		if names[index] in ["augment_pattern_recognition", "augment_how_to_cheat", "book_variant"]:
			continue
		var tile := sheet.get_region(Rect2i(Vector2i(index % 3, index / 3) * cell, cell))
		tile = tile.get_region(tile.get_used_rect())
		var factor := 24.0 / float(maxi(tile.get_width(), tile.get_height()))
		tile.resize(maxi(1, roundi(tile.get_width() * factor)), maxi(1, roundi(tile.get_height() * factor)), Image.INTERPOLATE_NEAREST)
		var icon := Image.create(24, 24, false, Image.FORMAT_RGBA8)
		icon.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), (Vector2i(24, 24) - tile.get_size()) / 2)
		assert(icon.save_png(ProjectSettings.globalize_path(ROOT + String(names[index]) + ".png")) == OK)
