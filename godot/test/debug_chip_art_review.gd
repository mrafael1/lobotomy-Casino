extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_environment("ART_REVIEW_DIR")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(540, 960)
	var board := Control.new()
	root.add_child(board)
	var sheet: Texture2D = root.get_node("Assets").texture(ChipAugments.ICON_SHEET)
	var index := 0
	for entry in ChipAugments.LIST:
		var origin := Vector2(12 + (index % 2) * 76, 10 + (index / 2) * 76)
		var icon := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(index * 128, 0, 128, 128)
		icon.texture = atlas
		icon.position = origin
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.size = Vector2(60, 60)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		board.add_child(icon)
		icon.set_deferred("size", Vector2(60, 60))
		var label := Label.new()
		label.position = origin + Vector2(-4, 61)
		label.size = Vector2(68, 12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = " / ".join(entry["hints"])
		label.add_theme_font_override("font", root.get_node("Assets").font())
		label.add_theme_font_size_override("font_size", 5)
		board.add_child(label)
		index += 1
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("chip-emblems.png"))
	print("Chip artwork review: eight emblems captured")
	quit()
