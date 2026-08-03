extends SceneTree
## Temporary debug helper (issue #111 redesign): render the restore light under the
## augmented SPADE modifier, which refills a restore charge only every other spin.
##
## Three states have to be told apart at a glance, which is the whole point of the
## tint and the cycle pips: a banked charge, a charge the player spent, and a charge
## the suit is withholding on this spin. Never saves meta.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	get_root().get_node("MetaStateStore").pendingCardUnlocks = []
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.augmentedTier = "spade"
	run_store.scoreEarned = 850
	run_store.wealthTargetIndex = 4
	run_store.lucidityCoins = 120
	run_store.neurons = 9
	run_store.dealerCountdown = 4
	run_store.ownedPowerIds = ["swap", "heart", "cheat"]
	run_store.abilitiesUsed = []
	run_store.lastResult = {
		"reels": ["brain", "eye", "pill"], "winType": "miss",
		"scoreEarned": 0, "coinsEarned": 0, "freeSpinsGranted": 0, "isFreeSpin": false,
	}
	var scene := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 10:
		await process_frame

	# Default: a charge is banked, so the light is on and BOTH pips are dark — a lit
	# light has nothing to count down to.
	run_store.powerRestoreCharges = 1
	run_store.powerRestoreProgress = 0
	scene._refresh_restore_cap()
	await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_LIT"))

	# The power just came back: the charge is spent, the light goes out, and the cycle
	# starts from zero — still both pips dark.
	run_store._spend_restore_budget(1)
	scene._refresh_restore_cap()
	await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_SPENT"))

	# One spin waited: first pip lit, light still out.
	run_store._recharge_restores()
	scene._refresh_restore_cap()
	await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_WAIT1"))

	# Two spins waited: second pip lit AND the light comes back on the same spin.
	run_store._recharge_restores()
	scene._refresh_restore_cap()
	await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_WAIT2"))
	quit(0)
