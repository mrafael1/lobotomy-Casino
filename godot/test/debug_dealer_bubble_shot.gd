extends SceneTree
## Temporary debug helper: the in-run dealer's speech bubble on its own, once with a plain
## line and once with the two +/- hint lines, so the text's placement inside the drawn
## bubble can be judged against the art rather than against a rect.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	var scene := (load("res://scenes/in_run_dealer_offer.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 12:
		await process_frame
	scene._show_editor_preview()
	for i in 4:
		await process_frame
	scene._set_speech_text("I'VE GOT SOMETHING FOR YA")
	await _shot("SHOT_SPEECH")
	scene._set_speech_hints("item_cocktail")
	await _shot("SHOT_HINTS")
	quit(0)

func _shot(env_var: String) -> void:
	for i in 3:
		await process_frame
	var path := OS.get_environment(env_var)
	if path != "":
		get_root().get_texture().get_image().save_png(path)
