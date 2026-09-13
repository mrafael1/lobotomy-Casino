extends SceneTree

## Render the real UI and the complete replacement asset families without saving.
## Set ART_REVIEW_DIR to an existing directory and run with a graphical renderer.
var _viewport: SubViewport
var _output: String

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_output = OS.get_environment("ART_REVIEW_DIR")
	if _output.is_empty() or not DirAccess.dir_exists_absolute(_output):
		push_error("Set ART_REVIEW_DIR to an existing directory")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Visual review requires a graphical renderer")
		quit(1)
		return
	var run := root.get_node("RunStateStore")
	var meta := root.get_node("MetaStateStore")
	run.sandboxed = true
	meta.sandboxed = true
	meta.is_first_launch = false
	meta.pendingCardUnlocks = []
	meta.lucidityWallet = 500
	run.reset_run_state()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(160, 320)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	for locale in ["en", "fr"]:
		TranslationServer.set_locale(locale)
		for scene_name in ["start_menu_scene", "options_overlay", "settings_scene", "collection_scene", "shop_scene"]:
			var scene := (load("res://scenes/%s.tscn" % scene_name) as PackedScene).instantiate()
			_viewport.add_child(scene)
			if scene.has_method("show_overlay"):
				scene.show_overlay()
			await _capture(locale + "-" + scene_name)
			scene.queue_free()
			await process_frame
	TranslationServer.set_locale("en")
	await _controls()
	await _cards()
	_viewport.queue_free()
	await process_frame
	print("Premium UI review captured to ", _output)
	quit()

func _capture(file_name: String) -> void:
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	assert(image.save_png(_output.path_join(file_name + "-native.png")) == OK)
	image.resize(480, 960, Image.INTERPOLATE_NEAREST)
	assert(image.save_png(_output.path_join(file_name + ".png")) == OK)

func _label(host: Node, text_value: String, position: Vector2) -> void:
	var label := Label.new()
	label.position = position
	label.text = text_value
	UiKit.style_display_label(label)
	label.add_theme_color_override("font_color", Color(0.90, 0.83, 0.64))
	host.add_child(label)

func _controls() -> void:
	var board := Control.new()
	_viewport.add_child(board)
	_label(board, "BRASS / ENAMEL", Vector2(12, 8))
	var index := 0
	for state in ["normal", "hover", "pressed", "disabled"]:
		var button := Button.new()
		button.position = Vector2(12, 25 + index * 28)
		button.size = Vector2(136, 20)
		button.text = String(state).to_upper()
		board.add_child(button)
		ButtonKit.start_menu_button_style(button, ButtonKit.START_MENU_BUTTON_YELLOW, 8)
		button.add_theme_stylebox_override("normal", button.get_theme_stylebox(state))
		if state == "disabled":
			button.disabled = true
		index += 1
	_label(board, "RÉGLAGES À É Ù 012345", Vector2(12, 145))
	index = 0
	for icon_name in ["settings", "left", "right", "close", "confirm", "coin"]:
		var icon := TextureRect.new()
		icon.texture = UiKit.texture("ui/premium/%s.png" % icon_name)
		icon.position = Vector2(12 + index * 23, 167)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		board.add_child(icon)
		index += 1
	_label(board, "REEL SYMBOLS", Vector2(12, 199))
	index = 0
	for symbol in ["brain", "eye", "pill", "syringe", "vial", "flatline", "heart x1", "heart x2", "heart x3"]:
		var icon := TextureRect.new()
		icon.texture = UiKit.texture("symbols/%s.png" % symbol)
		icon.position = Vector2(28 + index % 3 * 44, 219 + index / 3 * 28)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		board.add_child(icon)
		index += 1
	await _capture("controls-and-symbols")
	board.queue_free()
	await process_frame

func _cards() -> void:
	var pacte := (load("res://scenes/pacte_scene.tscn") as PackedScene).instantiate()
	var ids: Array = PacteCards.PAINTED_ICON_IDS
	for page in 2:
		var board := Control.new()
		_viewport.add_child(board)
		_label(board, "PAINTED CARDS %d" % (page + 1), Vector2(12, 8))
		for index in range(page * 12, mini(ids.size(), (page + 1) * 12)):
			var card_id := String(ids[index])
			var card := pacte._make_card_view(card_id, PacteCards.pool_of(card_id), true) as Control
			board.add_child(card)
			card.set_anchors_preset(Control.PRESET_TOP_LEFT)
			card.size = Vector2(39, 61)
			card.position = Vector2(8 + index % 3 * 46, 30 + (index % 12) / 3 * 70)
		await _capture("painted-cards-%d" % (page + 1))
		board.queue_free()
		await process_frame
	pacte.free()
