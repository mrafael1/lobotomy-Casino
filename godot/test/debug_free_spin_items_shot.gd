extends SceneTree
## Temporary debug helper (issue #185): open the machine with the FREE SPIN banner lit
## AND active item icons on the TV, so the lowered-banner placement can be reviewed —
## the banner and the badge row must not overlap. Never saves meta.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	get_root().get_node("MetaStateStore").pendingCardUnlocks = []
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.scoreEarned = 300
	run_store.wealthTargetIndex = 2
	run_store.neurons = 9
	run_store.dealerCountdown = 6
	# The banner's credit, plus two live items so both badge slots are filled.
	run_store.freeSpinsRemaining = 1
	run_store.cocktailBoostSpins = 3
	run_store.forceFlatlineSpins = 1
	run_store.guaranteedTripleSpins = 1
	run_store.lastResult = {
		"reels": ["brain", "eye", "pill"], "winType": "miss",
		"scoreEarned": 0, "coinsEarned": 0, "freeSpinsGranted": 0, "isFreeSpin": false,
	}
	var scene := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 10:
		await process_frame
	print("banner active=", scene._free_spin_overlay_active,
		" frame=", scene._free_spin_sprite.frame,
		" badges=", scene._boost_indicators_showing(),
		" muted=", scene._tv_content_muted(), " callout=", scene._tv_callout_active())
	# The banner blinks, so pin it to the lit half of its duty cycle for the shot rather
	# than racing it: _process would otherwise flip a forced-visible sprite straight back.
	scene._free_spin_blink_time = 0.0
	scene._free_spin_sprite.visible = true
	# Render the forced state: get_texture() reads the frame already drawn, so without
	# this the shot captures the blink's dark half regardless of what was just set.
	await process_frame
	await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_PATH"))
	quit(0)
