extends SceneTree
## Temporary debug helper: open the machine scene mid-run (items in the stash,
## partial wealth/health fills, dealer countdown low so the icon shows) and save
## a screenshot for bar-placement review. Never saves meta.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	run_store.start_new_run([], { "cons_cigarette": 1, "cons_tea": 2 }, false)
	run_store.scoreEarned = 850
	run_store.lucidityCoins = 120
	run_store.neurons = 9
	run_store.dealerCountdown = 4
	var scene := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 10:
		await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_PATH"))
	quit(0)
