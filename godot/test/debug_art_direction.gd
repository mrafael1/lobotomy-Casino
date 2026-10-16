extends SceneTree

## Deterministic display-resolution art review. Both stores stay sandboxed.
## ART_REVIEW_DIR is required; ART_CABINET optionally overrides only the texture.
var _output: String
var _scene: Node2D
var _frame := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_output = OS.get_environment("ART_REVIEW_DIR")
	if _output.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Use a graphical renderer and set ART_REVIEW_DIR")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_output)
	var run := root.get_node("RunStateStore")
	var meta := root.get_node("MetaStateStore")
	run.sandboxed = true
	meta.sandboxed = true
	meta.is_first_launch = false
	meta.pendingCardUnlocks = []
	run.reset_run_state()
	run.start_new_run([], {}, false, 170316)
	run.runPhase = "running"
	run.neurons = 15
	run.scoreEarned = 40
	run.lucidityCoins = 0
	run.dealerCountdown = 10
	run.ownedPowerIds = ["reroll", "shift", "memory"]
	run.abilitiesUsed = []
	run.runConsumables = {"cons_cigarette": 1, "cons_focus": 1}
	run.lastResult = {"reels": ["brain", "eye", "pill"], "winType": "miss",
		"scoreEarned": 0, "coinsEarned": 0, "freeSpinsGranted": 0, "isFreeSpin": false}
	change_scene_to_file("res://scenes/machine_scene.tscn")
	await scene_changed
	_scene = current_scene as Node2D
	# Keep the real cabinet transform, filtering, draw order and animation layers.
	var variant := OS.get_environment("ART_CABINET")
	if not variant.is_empty():
		var cabinet := _scene.get_node("Cabinet") as Sprite2D
		var texture := load(variant) as Texture2D
		assert(texture != null, "Review cabinet could not load")
		cabinet.texture = texture
		cabinet.scale = Vector2(160.0, 320.0) / texture.get_size()
	# Particle/flicker randomness is presentation-only; fix it for comparisons.
	if _scene.get("_heat") != null:
		_scene._heat._rng.seed = 724
	if _scene.get("_cabinet_light") != null:
		_scene._cabinet_light._rng.seed = 724
		_scene._cabinet_light._flicker_in = 100.0
	for window_size: Vector2i in [Vector2i(400, 800), Vector2i(540, 960), Vector2i(450, 1000), Vector2i(800, 1000)]:
		root.size = window_size
		await create_timer(0.3).timeout
		await _capture("idle-%dx%d" % [window_size.x, window_size.y])
	root.size = Vector2i(400, 800)
	await create_timer(0.3).timeout
	await _record(12)
	# A real paid spin: inspect strip travel, staggered stops and cabinet recovery.
	_scene._do_spin()
	await _record(120)
	assert(not _scene._spin_in_flight(), "Spin did not settle in the review")
	await _capture("reveal")
	# Identical revealed symbols in every material/lighting state.
	for index in 3:
		_scene._reel_symbols.set_symbol(index, ["brain", "eye", "pill"][index])
	run.comboDefeatPending = false
	_scene._callouts.set_loss_display(0)
	for tier in [2, 3]:
		run.betMultiplier = tier
		_scene._refresh_multiplier_controls()
		await _record(36)
		await _capture("heat-x%d" % tier)
	_scene._callouts.set_loss_display(3)
	await _record(36)
	await _capture("loss-x3")
	_scene._callouts.set_loss_display(0)
	run.betMultiplier = 1
	_scene._refresh_multiplier_controls()
	await create_timer(1.5).timeout
	_scene._on_power_pressed("memory")
	await create_timer(0.25).timeout
	await _capture("targeting")
	print("Art direction review: PASS; ", _frame, " motion frames; four display sizes")
	quit()

func _record(count: int) -> void:
	for index in count:
		await _capture("motion-%04d" % _frame)
		_frame += 1

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	assert(shot.save_png(_output.path_join(label + ".png")) == OK)
