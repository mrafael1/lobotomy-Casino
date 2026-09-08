extends SceneTree

## Render the real machine through idle, targeting, spent-power, spin and
## augment states. Uses sandboxed stores; pass an existing ART_REVIEW_DIR.
var _scene: Node = null
var _output: String = ""

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_output = OS.get_environment("ART_REVIEW_DIR")
	if _output.is_empty() or not DirAccess.dir_exists_absolute(_output):
		push_error("Set ART_REVIEW_DIR to an existing screenshot directory")
		quit(1)
		return
	var run: Node = root.get_node("RunStateStore")
	var meta: Node = root.get_node("MetaStateStore")
	run.sandboxed = true
	meta.sandboxed = true
	meta.pendingCardUnlocks = []
	meta.is_first_launch = false
	run.reset_run_state()
	run.sandboxed = true
	run.start_new_run([], {}, false)
	run.runPhase = "running"
	run.neurons = 15
	run.scoreEarned = 40
	run.wealthTargetIndex = 0
	run.dealerCountdown = 12
	run.ownedPowerIds = ["reroll", "shift", "memory"]
	run.abilitiesUsed = []
	run.lastResult = {"reels": ["brain", "eye", "pill"], "winType": "miss",
		"scoreEarned": 0, "coinsEarned": 0, "freeSpinsGranted": 0, "isFreeSpin": false}
	_scene = (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	await create_timer(0.5).timeout
	await _capture("01-idle")
	_scene._on_power_pressed("memory")
	await create_timer(0.3).timeout
	await _capture("02-lock-selected")
	_scene._apply_reel_power("memory", 0)
	await create_timer(0.5).timeout
	assert(run.abilitiesUsed.has("memory"), "Lock was not spent by the real power action")
	await _capture("03-lock-spent")
	_scene._do_spin()
	await create_timer(0.45).timeout
	await _capture("04-spinning")
	await create_timer(5.0).timeout
	assert(not _scene._spin_in_flight(), "Spin presentation failed to settle")
	await _capture("05-reveal")
	run.ownedUpgrades = ["pacte_tunnel_vision"]
	run.selectedAugmentCardIds = ["augment_tunnel_vision"]
	_scene._update_hud()
	await create_timer(0.5).timeout
	await _capture("06-tunnel-vision")
	var shutter := _scene._consumable_fx.layer().get_node("TunnelVisionShutter") as TextureRect
	assert(shutter.visible and is_equal_approx(shutter.scale.y, 1.0), "Shutter did not settle")
	run.ownedUpgrades = []
	_scene._refresh_consumable_fx()
	assert(not shutter.visible, "Removing Tunnel Vision left the shutter visible")
	print("Machine art review: live Lock, spin, reveal and Tunnel Vision passed")
	_scene.free()
	quit(0)

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(_output.path_join(label + ".png"))
	assert(error == OK, "Could not save machine review capture")
