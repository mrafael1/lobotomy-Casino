extends SceneTree
## Temporary debug helper (issue #176): render the intermediate target payout
## overlay at three animation stages for visual inspection. Never saves meta.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.max_fps = 60
	DisplayServer.window_set_size(Vector2i(160, 320))
	get_root().content_scale_size = Vector2i(160, 320)
	var overlay := (load("res://scenes/target_reached_overlay.tscn") as PackedScene).instantiate()
	get_root().add_child(overlay)
	overlay.present(650, 500)
	for i in 2:
		await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_START"))
	# Mid-flight: the target has popped in and is flying onto the score (~0.75s).
	for i in 43:
		await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_MID"))
	# Settled: score paid down, red loss line and CONTINUE button visible (~1.7s).
	for i in 57:
		await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_END"))
	quit(0)
