extends SceneTree
## Temporary debug helper: the tutorial's dealer beat with the in-run offer actually up, so
## the coach box can be checked against the counter it is talking about (issue #105).
## Windowed only. Delete lobotomy-meta.json* / lobotomy-run.save* afterwards.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	var tutorial: Node = get_root().get_node("Tutorial")
	get_root().get_node("MetaStateStore").pendingCardUnlocks = []
	run_store.reset_run_state()
	if not tutorial.start():
		push_error("tutorial refused to start")
		quit(1)
		return
	var scene := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 10:
		await process_frame
	# Walk to the beat that hands the player to the dealer, then stand the offer up the way
	# a real visit does.
	while bool(tutorial.active) \
			and String(TutorialScript.beat(int(tutorial.beat_index)).get("id", "")) != "dealer_take":
		tutorial._advance()
	run_store.runConsumables = {}
	run_store.dealerPending = true
	run_store.dealerOfferIds = ["item_energy_drink", "cons_white_powder"]
	scene._show_dealer_offers()
	# The offer plays a tap warning and a slide-in before the items are on the counter.
	for i in 150:
		await process_frame
	# The items only appear once the counter is opened; the tutorial hands the tap through
	# so a real player would press this themselves.
	var popup: Control = scene._dealer_offer_popup as Control
	if popup != null:
		popup._on_look_pressed()
		for i in 60:
			await process_frame
	var dir := OS.get_environment("SHOT_DIR")
	if dir == "":
		dir = OS.get_user_data_dir()
	get_root().get_texture().get_image().save_png("%s/offer_dealer_take.png" % dir)
	quit(0)
