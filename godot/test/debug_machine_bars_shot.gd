extends SceneTree
## Temporary debug helper: open the machine scene mid-run (items in the stash,
## partial wealth/health fills, dealer countdown low so the icon shows) and save
## a screenshot for bar-placement review. Never saves meta.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	# A card unlock left pending in the local save would raise its blocking popup over
	# the machine and hide the very layout this shot exists to review.
	get_root().get_node("MetaStateStore").pendingCardUnlocks = []
	# start_new_run no-ops while a saved run is still "running", so a resumed local save
	# would be drawn instead of the fixture below.
	run_store.reset_run_state()
	run_store.start_new_run([], { "cons_cigarette": 1, "cons_tea": 2 }, false)
	run_store.scoreEarned = 850
	# Mid-way to the 1500 target: the TARGET bar shows a partial fill instead of the
	# run immediately resolving into the target-reached screen.
	run_store.wealthTargetIndex = 4
	run_store.lucidityCoins = 120
	run_store.neurons = 9
	run_store.dealerCountdown = 4
	# Fill the TV's item column and augment row so their placement can be reviewed:
	# three live duration boosts and four held augments (one past the row's width, so
	# the overflow badge shows too).
	run_store.cocktailBoostSpins = 3
	run_store.potionSpins = 5
	run_store.blurReelsSpins = 4
	run_store.selectedAugmentCardIds = [
		"augment_reward_1", "augment_book", "augment_smart_saving", "augment_passive_gain",
	]
	# Powers that are NOT the ones owning emplacements 1-3, so the shot also shows
	# whether a re-slotted chip lands on its emplacement.
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
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_PATH"))
	quit(0)
