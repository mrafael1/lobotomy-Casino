extends SceneTree
## Debug helper: open the machine mid-run with the TV's active-item badge row filled, and
## save a screenshot for reviewing that row's placement, sizing and colours (issue #185).
##
## Headless CANNOT render — run it windowed:
##
##   SHOT_PATH=<abs .png> godot --path godot -s res://test/debug_tv_items_shot.gd
##
## SHOT_MODE picks what the row is showing:
##   early    (default) five items, every one in its FIRST phase — all counts green
##   late     the phased items past their turn — Energy Drink and Red Pill counts red/green
##   overflow all seven possible boosts at once, so the "+N" on the last slot shows
##   empty    no items, for measuring the bare TV screen behind the row
##
## Never saves meta. NOTE: running this DOES write a user:// run/meta save, and the
## augments it leaves behind will fail scene_smoke on unrelated-looking checks — delete
## user://lobotomy-meta.json* and lobotomy-run.save* afterwards.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	# A pending card unlock would raise its blocking popup over the very row this shot
	# exists to review.
	get_root().get_node("MetaStateStore").pendingCardUnlocks = []
	# start_new_run no-ops while a saved run is still "running", so a resumed local save
	# would be drawn instead of the fixture below.
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	# Mid-way to the 1500 target, so the TARGET bar shows a partial fill under the row
	# instead of the run resolving straight into the target-reached screen.
	run_store.scoreEarned = 900
	run_store.wealthTargetIndex = 4
	run_store.neurons = 9
	run_store.dealerCountdown = 4
	match OS.get_environment("SHOT_MODE"):
		"empty":
			pass
		"late":
			# Both phased items past their hand-off: the Energy Drink is down to the
			# compulsory spin it queued, the Red Pill to the triple it owes.
			run_store.compulsiveSpinSkips = 1
			run_store.guaranteedTripleSpins = 1
			run_store.blurReelsSpins = 2
			run_store.cocktailBoostSpins = 3
			run_store.potionSpins = 5
		"overflow":
			# All seven, one more than the row has slots, so the last badge counts the rest.
			run_store.decaySkips = 2
			run_store.pendingCompulsiveSpinSkips = 1
			run_store.guaranteeSymbolSpins = 3
			run_store.guaranteeSymbolId = "eye"
			run_store.blurReelsSpins = 2
			run_store.cocktailBoostSpins = 3
			run_store.pairBoostSpins = 4
			run_store.potionSpins = 5
			run_store.forceFlatlineSpins = 1
			run_store.guaranteedTripleSpins = 1
		_:
			# Five distinct items, every slot filled, each in its opening phase.
			run_store.decaySkips = 2
			run_store.pendingCompulsiveSpinSkips = 1
			run_store.cocktailBoostSpins = 3
			run_store.pairBoostSpins = 4
			run_store.potionSpins = 5
			run_store.forceFlatlineSpins = 1
			run_store.guaranteedTripleSpins = 1
	run_store.lastResult = {
		"reels": ["brain", "eye", "pill"], "winType": "miss",
		"scoreEarned": 0, "coinsEarned": 0, "freeSpinsGranted": 0, "isFreeSpin": false,
	}
	var scene := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for _i in 10:
		await process_frame
	var path := OS.get_environment("SHOT_PATH")
	if path == "":
		path = OS.get_user_data_dir() + "/tv_items_shot.png"
	get_root().get_texture().get_image().save_png(path)
	print("saved ", path)
	quit(0)
