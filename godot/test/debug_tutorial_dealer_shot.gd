extends SceneTree
## Temporary debug helper for the tutorial's DEALER beats (issue #105), which the machine
## shot cannot reach: the between-runs shop, the target-break START, and the stand-down the
## odds table forces. Windowed only.
##
##   SHOT_DIR=... godot --path godot -s res://test/debug_tutorial_dealer_shot.gd
##
## Delete lobotomy-meta.json* / lobotomy-run.save* afterwards, as with the other shots.

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
	# The between-runs shop: no live run, so the dealer opens as the pre-run counter.
	run_store.runPhase = "idle"
	run_store.oddsPhaseCompleted = true # the odds table has its own shot below
	var scene := (load("res://scenes/dealer_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 10:
		await process_frame

	var dir := OS.get_environment("SHOT_DIR")
	if dir == "":
		dir = OS.get_user_data_dir()
	var shot := 0
	while bool(tutorial.active) and shot < TutorialScript.count() + 2:
		var beat: Dictionary = TutorialScript.beat(int(tutorial.beat_index))
		if String(beat.get("scene", "")) == "dealer":
			for i in 4:
				await process_frame
			get_root().get_texture().get_image().save_png("%s/dealer_%02d_%s.png" \
				% [dir, shot, String(beat.get("id", "beat"))])
		shot += 1
		tutorial._advance()

	# The odds table, with the beat that explains it shown OVER it.
	scene.queue_free()
	run_store.runPhase = "over"
	run_store.oddsPhaseCompleted = false
	run_store.oddsTokensRemaining = 4
	var odds_scene := (load("res://scenes/dealer_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(odds_scene)
	for i in 20:
		await process_frame
	tutorial.start()
	tutorial.attach(odds_scene, "dealer")
	while bool(tutorial.active) \
			and String(TutorialScript.beat(int(tutorial.beat_index)).get("id", "")) != "odds":
		tutorial._advance()
	tutorial._present_beat()
	for i in 6:
		await process_frame
	get_root().get_texture().get_image().save_png("%s/dealer_98_odds.png" % dir)
	odds_scene.queue_free()
	scene = (load("res://scenes/dealer_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 10:
		await process_frame

	# And the stand-down: a modal the tutorial does not own must be left entirely alone.
	tutorial.start()
	tutorial.attach(scene, "dealer")
	while bool(tutorial.active) \
			and String(TutorialScript.beat(int(tutorial.beat_index)).get("scene", "")) != "dealer":
		tutorial._advance()
	var modal := ColorRect.new()
	modal.color = Color(0.1, 0.0, 0.2, 0.9)
	modal.size = Vector2(120.0, 90.0)
	modal.position = Vector2(20.0, 110.0)
	scene.add_child(modal)
	scene.set("_augment_picker", modal)
	tutorial._present_beat()
	for i in 4:
		await process_frame
	get_root().get_texture().get_image().save_png("%s/dealer_99_stand_down.png" % dir)
	quit(0)
