extends SceneTree
## Temporary debug helper: open the machine scene mid-run and force the new
## TV callouts (win/power), the wealth objective box, and the spins-left number
## so a screenshot can verify their placement. Never saves meta.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	run_store.start_new_run(["perm_shift", "perm_memory"], {}, false)
	run_store.scoreEarned = 850
	run_store.neurons = 9
	var scene := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 10:
		await process_frame
	scene.call("_play_win_animation", "pair", 35)
	await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_PATH"))
	quit(0)
