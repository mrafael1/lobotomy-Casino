extends SceneTree

## Real-window review: catches integer letterboxing and safe-area input drift.
var _output: String
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_output = OS.get_environment("ART_REVIEW_DIR")
	if _output.is_empty() or DisplayServer.get_name() == "headless":
		quit(1)
		return
	var meta := root.get_node("MetaStateStore")
	var run := root.get_node("RunStateStore")
	meta.sandboxed = true
	run.sandboxed = true
	meta.is_first_launch = false
	meta.pendingCardUnlocks = []
	run.reset_run_state()
	for window_size in [Vector2i(400, 800), Vector2i(540, 960), Vector2i(450, 1000), Vector2i(800, 1000)]:
		root.size = window_size
		for scene_name in ["start_menu_scene", "machine_scene", "pacte_scene", "settings_scene", "collection_scene", "scores_scene", "options_overlay", "dealer_choice_scene", "dealer_scene", "upgrades_scene"]:
			if scene_name == "machine_scene":
				run.reset_run_state()
				run.start_new_run([], {}, false, 12345)
				run.ownedPowerIds = ["reroll", "shift", "memory"]
			if scene_name == "pacte_scene":
				run.reset_run_state()
				run.start_new_run([], {}, false, 12345, true)
			if scene_name == "dealer_choice_scene":
				run.runPhase = "over"
				run.roundContinuationPending = true
				run.prepare_route_offer("wealth_target", 12345)
			if scene_name == "dealer_scene":
				run.reset_run_state()
			change_scene_to_file("res://scenes/%s.tscn" % scene_name)
			await scene_changed
			var scene := current_scene
			if scene.has_method("show_overlay"):
				scene.show_overlay()
			for frame in 8:
				await process_frame
			if scene_name == "machine_scene":
				scene._reel_symbols.set_symbol(0, "brain")
				scene._reel_symbols.set_symbol(1, "eye")
				scene._reel_symbols.set_symbol(2, "pill")
			if scene_name == "settings_scene":
				await _check_pointer(scene.get_node("Panel/Rows/MuteCheck") as CheckBox)
			if scene_name == "pacte_scene":
				await _check_card_drag(scene)
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			var filename := "%s-%dx%d.png" % [scene_name, window_size.x, window_size.y]
			shot.save_png(_output.path_join(filename))
			var safe := Rect2(root.canvas_transform.origin, Vector2(160, 320))
			if not root.get_visible_rect().encloses(safe):
				_failures.append("Safe area cropped: " + filename)
	for failure in _failures:
		push_error(failure)
	print("Display review: ", "PASS" if _failures.is_empty() else _failures)
	quit(0 if _failures.is_empty() else 1)

func _check_pointer(check: CheckBox) -> void:
	var before := check.button_pressed
	var point := check.get_global_transform_with_canvas() * (check.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	if check.button_pressed == before:
		_failures.append("Centered settings checkbox missed pointer at " + str(root.size))
	check.button_pressed = before

func _check_card_drag(scene: Control) -> void:
	await create_timer(0.4).timeout
	if scene._card_buttons.is_empty():
		_failures.append("Pacte has no draggable cards")
		return
	var card_id: String = scene._card_buttons.keys()[0]
	scene._set_face_up(card_id)
	scene._preview_card(card_id)
	var card: Button = scene._card_buttons[card_id]
	var grab := Vector2(15, 20)
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = grab
	scene._on_card_gui_input(press, card_id, 0, card)
	var drag := InputEventScreenDrag.new()
	drag.position = scene.get_global_transform_with_canvas() * Vector2(80, 235)
	root.push_input(drag, true)
	await process_frame
	var actual := card.get_global_transform_with_canvas() * grab
	if actual.distance_to(drag.position) > 0.1:
		_failures.append("Pacte card left the finger at " + str(root.size))
	var release := InputEventScreenTouch.new()
	release.position = drag.position
	release.pressed = false
	root.push_input(release, true)
	await process_frame
