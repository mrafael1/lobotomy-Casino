extends SceneTree
## Temporary debug helper: mounts the tutorial's coach overlay on the machine and saves one
## shot per machine beat, so the box placement and the ring can be reviewed at 160x320.
## Headless cannot render, so this must be run windowed:
##
##   SHOT_DIR=... godot --path godot -s res://test/debug_tutorial_shot.gd
##
## The tutorial sandbox keeps this off the real save, but the machine scene itself still
## commits run state on the way in — delete lobotomy-meta.json* / lobotomy-run.save*
## afterwards like the other debug shots.

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
	# The scene attaches itself in _ready; attaching again here would replace the live
	# overlay with a second one.

	var dir := OS.get_environment("SHOT_DIR")
	if dir == "":
		dir = OS.get_user_data_dir()

	var shot := 0
	var skip_shot_taken := false
	while bool(tutorial.active) and shot < TutorialScript.count() + 2:
		var beat: Dictionary = TutorialScript.beat(int(tutorial.beat_index))
		# Only the machine's own beats have anything to look at here; the rest belong to
		# scenes this shot does not stand up.
		if String(beat.get("scene", "")) == "machine":
			for i in 4:
				await process_frame
			get_root().get_texture().get_image().save_png("%s/tutorial_%02d_%s.png" \
				% [dir, shot, String(beat.get("id", "beat"))])
			# The way out is a modal of its own; catch it once, over a live beat. The
			# overlay is taken from the director rather than by node name — a scene that
			# attached twice would hand back the freed one.
			if not skip_shot_taken:
				skip_shot_taken = true
				var overlay: Control = tutorial._overlay as Control
				(overlay.get_node("SkipButton") as Button).pressed.emit()
				for i in 3:
					await process_frame
				get_root().get_texture().get_image().save_png(
					"%s/tutorial_00_skip_confirm.png" % dir)
				overlay._dismiss_skip_confirm()
				for i in 2:
					await process_frame
		shot += 1
		tutorial._advance()
	quit(0)
