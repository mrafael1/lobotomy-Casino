extends SceneTree
## Throwaway verification helper for seam 4.2b: open the machine, force the
## flatline ending, and screenshot the drain readout mid-fall.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	run_store.start_new_run([], {}, false)
	run_store.lucidityCoins = 100
	run_store.scoreEarned = 420
	var scene := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 10:
		await process_frame
	scene._show_ending("flatline", {
		"neurons": 0, "scoreEarned": 420, "lucidityCoins": 100,
	})
	for i in 60:
		await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_PATH"))
	quit(0)
