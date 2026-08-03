extends SceneTree
## Temporary debug helper: apply the Memory (lock) power through the real UI path and
## shoot the machine BEFORE any spin follows, to see whether the padlock actually draws.
## Never saves meta.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	get_root().get_node("MetaStateStore").pendingCardUnlocks = []
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.scoreEarned = 120
	run_store.lucidityCoins = 40
	run_store.neurons = 9
	run_store.ownedPowerIds = ["reroll", "shift", "memory"]
	run_store.abilitiesUsed = []
	run_store.lastResult = {
		"reels": ["brain", "eye", "pill"], "winType": "miss",
		"scoreEarned": 0, "coinsEarned": 0, "freeSpinsGranted": 0, "isFreeSpin": false,
		"scoreMultiplier": 1.0,
	}
	var scene := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 10:
		await process_frame

	scene._set_sequence_lock(false)
	scene._refresh_reels_from_state()
	scene._update_hud()
	for i in 4:
		await process_frame

	# Arm the power and tap reel 1 (middle) exactly the way the player does.
	scene._on_power_pressed("memory")
	for i in 4:
		await process_frame
	var buttons: Array = []
	if scene._targeting_layer != null:
		for child in scene._targeting_layer.get_children():
			if child is Button:
				buttons.append(child)
	if buttons.size() > 1:
		(buttons[1] as Button).emit_signal("pressed")
	for i in 20:
		await process_frame
	print("BEFORE spin: spins=%s lock_vis=%s frame=%d targeting_layer=%s" % [
		str(run_store.lockedReelSpins), scene._lock_sprites[1].visible,
		int(scene._lock_sprites[1].frame), str(scene._targeting_layer)])
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_PATH"))

	# Now the spin the player takes next, which is when they say the padlock shows up.
	run_store.spin()
	scene._set_sequence_lock(false)
	scene._refresh_reels_from_state()
	scene._update_hud()
	for i in 20:
		await process_frame
	print("AFTER  spin: spins=%s lock_vis=%s frame=%d targeting_layer=%s" % [
		str(run_store.lockedReelSpins), scene._lock_sprites[1].visible,
		int(scene._lock_sprites[1].frame), str(scene._targeting_layer)])
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_PATH_B"))
	quit(0)
