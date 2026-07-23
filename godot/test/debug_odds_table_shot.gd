extends SceneTree
## Temporary debug helper (issue #130): open the odds table overlay standalone
## and save a screenshot for visual inspection.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var root_view := get_root()
	root_view.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root_view.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root_view.content_scale_size = Vector2i(160, 320)
	root_view.size = Vector2i(640, 1280)
	var run_store: Node = root_view.get_node("RunStateStore")
	var meta_store: Node = root_view.get_node("MetaStateStore")
	meta_store.oddsTokensBanked = 3
	meta_store.oddsUpgrades = { "brain": 2, "eye": 5, "vial": 8 }
	run_store.reset_run_state()
	var overlay := (load("res://scenes/odds_table_overlay.tscn") as PackedScene).instantiate()
	root_view.add_child(overlay)
	overlay.open_overlay()
	for i in 10:
		await process_frame
	var img: Image = root_view.get_texture().get_image()
	img.save_png(OS.get_environment("SHOT_PATH"))
	quit(0)
