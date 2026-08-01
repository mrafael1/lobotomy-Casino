extends SceneTree
## Temporary debug helper: proves the LANGUAGE row's flag placement BEFORE the real art
## exists. Builds a 12x8 stand-in in memory (no file is written — the pixel art is authored
## separately) and drops it straight onto the row's TextureRect, so the size and the right
## edge inset can be checked against the row now rather than after the art is drawn.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	TranslationServer.set_locale(OS.get_environment("SHOT_LOCALE"))
	var overlay := (load("res://scenes/options_overlay.tscn") as PackedScene).instantiate()
	get_root().add_child(overlay)
	for i in 8:
		await process_frame
	overlay.show_overlay()
	await process_frame
	var button := overlay.get_node("Panel/Menu/LanguageButton") as Button
	# Stand-in with a visible edge so the rect's bounds read clearly against the row.
	var size := Language.FLAG_SIZE
	var img := Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	img.fill(Color(0.15, 0.2, 0.75))
	for x in int(size.x):
		img.set_pixel(x, 0, Color.WHITE)
		img.set_pixel(x, int(size.y) - 1, Color.WHITE)
	var icon := TextureRect.new()
	icon.name = "Flag"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture = ImageTexture.create_from_image(img)
	button.add_child(icon)
	icon.size = size
	icon.position = Vector2(
		button.custom_minimum_size.x - size.x - overlay.LANGUAGE_FLAG_INSET,
		roundf((button.custom_minimum_size.y - size.y) * 0.5))
	button.text = overlay.tr("LANGUAGE")
	for i in 4:
		await process_frame
	print("row %s at %s   flag %s at %s (row-local)" % [
		button.size, button.position, icon.size, icon.position])
	var path := OS.get_environment("SHOT_PATH")
	if path != "":
		get_root().get_texture().get_image().save_png(path)
	quit(0)
