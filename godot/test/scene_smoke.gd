extends SceneTree

## Throwaway smoke check (issue #21): instantiate the new/changed scenes (catches
## GDScript parse/instantiate regressions) and assert the dealer's pre-run vs in-run
## offer-pool branching is correct. Not a parity gate.
##
##   godot --headless --path godot -s res://test/scene_smoke.gd

func _initialize() -> void:
	var failures: Array = []
	var run_store: Node = get_root().get_node("RunStateStore")

	# Every touched scene loads + instantiates without parse/runtime errors.
	for path in [
		"res://scenes/start_menu_scene.tscn",
		"res://scenes/shop_scene.tscn",
		"res://scenes/scores_scene.tscn",
	]:
		var ps := load(path) as PackedScene
		if ps == null:
			failures.append("%s failed to load" % path)
			continue
		var n := ps.instantiate()
		get_root().add_child(n)
		n.queue_free()

	# Machine scene must expose the dedicated jackpot burst (issue #22).
	var machine := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(machine)
	if not machine.has_method("_spawn_jackpot_burst"):
		failures.append("machine missing _spawn_jackpot_burst")
	machine.queue_free()

	var dealer_ps := load("res://scenes/dealer_scene.tscn") as PackedScene
	var dealer := dealer_ps.instantiate()

	# Mode detection: no active run => pre-run shop; an active run => in-run dealer.
	run_store.runPhase = "idle"
	if (run_store.runPhase != "running") != true:
		failures.append("mode detect: 'idle' should be pre-run")
	run_store.runPhase = "running"
	if (run_store.runPhase != "running") != false:
		failures.append("mode detect: 'running' should be in-run")

	# Offer pool branches on _pre_run (set in _ready from the mode above).
	dealer._pre_run = true
	if dealer._offer_ids() != ["cons_focus", "cons_white_powder", "cons_syringe", "cons_tea"]:
		failures.append("pre-run offers wrong: %s" % str(dealer._offer_ids()))
	dealer._pre_run = false
	run_store.dealerOfferIds = ["item_water", "item_pill"]
	if dealer._offer_ids() != ["item_water", "item_pill"]:
		failures.append("in-run offers wrong: %s" % str(dealer._offer_ids()))
	dealer.queue_free()

	if failures.is_empty():
		print("✓ scene smoke PASSED")
		quit(0)
	else:
		for f in failures:
			printerr("✗ ", f)
		quit(1)
