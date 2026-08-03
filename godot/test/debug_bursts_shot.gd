extends SceneTree
## Verification helper for the score-burst layer and the jackpot lamp: spawn a
## reel-anchored burst, a centred jackpot burst and a lamp flash, then shoot the
## frame while all three are up.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	run_store.start_new_run([], {}, false)
	run_store.scoreEarned = 640
	var scene := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 10:
		await process_frame
	scene._bursts.spawn_jackpot(500)
	scene._bursts.spawn("TRIPLE", 120, Color(0.42, 1.0, 0.95), 2)
	scene._bursts.flash_jackpot_lamp(scene._refresh_jackpot_lamp)
	for i in 18:
		await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_PATH"))
	quit(0)
