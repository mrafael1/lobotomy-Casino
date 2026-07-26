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
	# No snapshot is passed: with no machine behind it the overlay lifts its own copy
	# of the wealth reels, which is what makes this helper runnable standalone.
	overlay.present(650, 500)
	# Frames are counted at 60fps against the phase constants in the overlay (issue
	# #181 stretched the beat from 1.4s to ~5.5s).
	for i in 60: # ~1.0s: blacked out, title in, the score lifting toward the TV
		await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_START"))
	for i in 130: # ~3.2s: the target is up and the score is draining beneath it
		await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_MID"))
	for i in 200: # ~6.5s: target shattered, loss line settled and CONTINUE visible
		await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_END"))
	quit(0)
