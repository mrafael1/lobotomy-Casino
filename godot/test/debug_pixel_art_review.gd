extends SceneTree

## Bilingual scene/contact-sheet capture and a runtime audit of image sources.
## Exercises every major scene; source paintings must never reach a live node.
var _output: String
var _failures: Array[String] = []
var _images := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("Pixel art review timed out")
		quit(1))
	_output = OS.get_environment("ART_REVIEW_DIR")
	if _output.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Set ART_REVIEW_DIR and use a graphical renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_output)
	root.size = Vector2i(400, 800)
	var run := root.get_node("RunStateStore")
	var meta := root.get_node("MetaStateStore")
	meta.sandboxed = true
	run.sandboxed = true
	meta.is_first_launch = false
	meta.pendingCardUnlocks = []
	for locale: String in ["en", "fr"]:
		root.get_node("Language").apply(locale)
		for scene_name: String in ["start_menu_scene", "machine_scene", "pacte_scene", "dealer_scene",
				"dealer_choice_scene", "route_build_scene", "route_bonus_scene", "sacrifice_scene",
				"settings_scene", "options_overlay", "collection_scene", "scores_scene", "upgrades_scene"]:
			run.reset_run_state()
			run.start_new_run([], {}, false, 170316, scene_name == "pacte_scene")
			if scene_name.begins_with("route_") or scene_name in ["sacrifice_scene", "dealer_choice_scene"]:
				run.runPhase = "over"
				run.roundContinuationPending = true
				run.routeContext = "wealth_target"
				run.routeDestination = "bonus" if scene_name == "route_bonus_scene" else "sacrifice" if scene_name == "sacrifice_scene" else "augment"
				run.routeBuildKind = "augment"
				run.lucidityCoins = 240
				run.ownedPowerIds = ["reroll"]
				run.selectedAugmentCardIds = ["augment_book"]
				if scene_name == "dealer_choice_scene":
					run.routeDestination = ""
					run.prepare_route_offer("wealth_target", 170316)
			change_scene_to_file("res://scenes/%s.tscn" % scene_name)
			await scene_changed
			if current_scene.has_method("show_overlay"):
				current_scene.show_overlay()
			await create_timer(0.25).timeout
			_audit(current_scene)
			await _capture(locale + "-" + scene_name)
			if scene_name == "route_bonus_scene":
				# Resolve after autoload startup; typing this as the wheel script forces
				# its Assets dependency to compile before a -s entry point has autoloads.
				var wheel: Node = current_scene.get_node("FortuneWheel")
				wheel.spin_to_reward(FortuneWheelRules.REWARD_COINS_50)
				await create_timer(0.6).timeout
				await _capture(locale + "-wheel-spinning")
				await create_timer(2.1).timeout
				await _capture(locale + "-wheel-result")
	for texture: Variant in root.get_node("Assets")._tex.values():
		if texture is Texture2D:
			_texture(texture, "Assets cache")
	for failure in _failures:
		push_error(failure)
	print("Pixel art review: ", "PASS" if _failures.is_empty() else "FAIL", "; ", _images, " texture bindings; 13 scenes in EN/FR")
	quit(0 if _failures.is_empty() else 1)

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(_output.path_join(label + ".png")) == OK)

func _texture(texture: Texture2D, owner_path: String) -> void:
	if texture == null:
		return
	if texture is AtlasTexture:
		_texture((texture as AtlasTexture).atlas, owner_path)
		return
	var path := texture.resource_path
	if path.begins_with("res://assets/images/"):
		_images += 1
		if not path.begins_with("res://assets/images/pixel/"):
			_failures.append("Legacy image reached %s: %s" % [owner_path, path])

func _audit(node: Node) -> void:
	if node is Sprite2D:
		_texture((node as Sprite2D).texture, str(node.get_path()))
	elif node is TextureRect:
		_texture((node as TextureRect).texture, str(node.get_path()))
	elif node is AnimatedSprite2D:
		var frames := (node as AnimatedSprite2D).sprite_frames
		if frames != null:
			for animation in frames.get_animation_names():
				for index in frames.get_frame_count(animation):
					_texture(frames.get_frame_texture(animation, index), str(node.get_path()))
	if node is Button:
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style := (node as Button).get_theme_stylebox(state)
			if style is StyleBoxTexture:
				_texture((style as StyleBoxTexture).texture, str(node.get_path()))
	for child in node.get_children():
		_audit(child)
