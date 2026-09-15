extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_environment("ART_REVIEW_DIR")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		quit(1)
		return
	var meta := root.get_node("MetaStateStore")
	meta.sandboxed = true
	root.get_node("RunStateStore").sandboxed = true
	meta.history = {"bestScoreRun": 99999999, "runsPlayed": 123456,
		"wealthEndingPlaytimeMs": 360000000, "wealthEndingReachedAt": 1789459200000,
		"exitEndingPlaytimeMs": 3600000, "exitEndingReachedAt": 1789459200000}
	meta.endingsReached = ["wealth", "exit"]
	var before: Dictionary = meta.history.duplicate(true)
	root.size = Vector2i(540, 960)
	for locale in ["en", "fr"]:
		TranslationServer.set_locale(locale)
		change_scene_to_file("res://scenes/scores_scene.tscn")
		await scene_changed
		for frame in 5:
			await process_frame
		var scene := current_scene
		for key in ["SCORES_BESTValue", "SCORES_RUNSValue", "SCORES_WINSValue"]:
			var value: Label = scene.get_node(key)
			assert(value.position.x + value.size.x <= 131, "Stat value escaped its inset")
		for index in 6:
			assert(scene._tier_idx == index)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("scores-%s-%s.png" % [locale, scene.TIERS[index]]))
			var next: Button = scene.get_node("TierNextButton")
			var point := next.get_global_transform_with_canvas() * (next.size * 0.5)
			for pressed in [true, false]:
				var event := InputEventMouseButton.new()
				event.position = point
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = pressed
				root.push_input(event, true)
				await process_frame
			await create_timer(0.2).timeout
		assert(scene._tier_idx == 0, "Tier selection must wrap")
	assert(meta.history == before, "Scores view must not mutate saved history")
	print("Scores review: EN/FR, large values, ending dates and six-tier pointer cycling PASS")
	quit()
