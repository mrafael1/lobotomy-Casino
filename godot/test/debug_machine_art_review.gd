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
	run.runConsumables = {"cons_cigarette": 1, "cons_focus": 1}
	run.lastResult = {"reels": ["brain", "eye", "pill"], "winType": "miss",
		"scoreEarned": 0, "coinsEarned": 0, "freeSpinsGranted": 0, "isFreeSpin": false}
	_scene = (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	await create_timer(0.5).timeout
	await _capture("01-idle")
	var spin := _scene.get_node("SpinButton") as Button
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = spin.get_global_rect().get_center()
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	assert(spin.is_pressed(), "SPIN did not receive the shelf press")
	await _capture("01-spin-pressed")
	press = press.duplicate() as InputEventMouseButton
	press.pressed = false
	root.push_input(press, true)
	await process_frame
	assert(spin.disabled, "SPIN must lock after release")
	await _capture("01-spin-disabled")
	await create_timer(5.0).timeout
	_scene._on_power_pressed("memory")
	await create_timer(0.3).timeout
	assert(spin.mouse_filter == Control.MOUSE_FILTER_IGNORE, "SPIN intercepts power targeting")
	await _capture("02-lock-selected")
	_scene._apply_reel_power("memory", 0)
	await create_timer(0.5).timeout
	assert(run.abilitiesUsed.has("memory"), "Lock was not spent by the real power action")
	await _capture("03-lock-spent")
	_scene._on_power_pressed("shift")
	await create_timer(0.3).timeout
	await _capture("03-shift-targeting")
	var shift_press := InputEventMouseButton.new()
	shift_press.button_index = MOUSE_BUTTON_LEFT
	shift_press.position = Vector2(75.5, 211.0)
	shift_press.pressed = true
	root.push_input(shift_press, true)
	shift_press = shift_press.duplicate() as InputEventMouseButton
	shift_press.pressed = false
	root.push_input(shift_press, true)
	await create_timer(1.0).timeout
	assert(run.abilitiesUsed.has("shift"), "SPIN intercepted the lower Shift arrow")
	await create_timer(4.0).timeout
	assert(not spin.disabled, "SPIN remained locked after Shift resolved")
	spin.grab_focus()
	var accept := InputEventKey.new()
	accept.keycode = KEY_ENTER
	accept.pressed = true
	root.push_input(accept, true)
	await process_frame
	assert(spin.is_pressed(), "Focused SPIN did not accept keyboard/controller input")
	accept = accept.duplicate() as InputEventKey
	accept.pressed = false
	root.push_input(accept, true)
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
	_scene._callouts.play_win("pair", 20)
	await create_timer(0.08).timeout
	await _capture("07-payout")
	_scene._callouts.stop_win()
	# The CRT multiplier retains its warning/cap states independently of the powers.
	for multiplier in [2, 3]:
		run.betMultiplier = multiplier
		_scene._refresh_multiplier_controls()
		await _capture("07-multiplier-x%d" % multiplier)
		_scene._callouts.set_loss_display(multiplier)
		assert(not _scene._multiplier_sprite.visible, "Loss warning must replace the normal multiplier")
		await _capture("07-loss-x%d" % multiplier)
		_scene._callouts.set_loss_display(0)
		assert(_scene._multiplier_sprite.visible, "Multiplier did not return after the warning")
	run.selectedAugmentCardIds = ["augment_tunnel_vision", "augment_adrenaline", "augment_reward_1"]
	_scene._augments.refresh_pacte_badges()
	await _capture("07-three-augments")
	_scene._callouts.play_win("triple", 50)
	assert(not _scene._multiplier_sprite.visible, "TV payout must hide the multiplier")
	await _capture("07-crt-payout-priority")
	_scene._callouts.stop_win()
	run.force_dealer_visit()
	_scene._show_dealer_offers()
	await create_timer(1.5).timeout
	assert(_scene._dealer_offer_popup != null and _scene._dealer_offer_popup.visible, "Dealer offer did not open")
	assert(spin.disabled, "Dealer interruption left SPIN enabled")
	await _capture("08-dealer-interruption")
	print("Machine art review: mouse/focus SPIN, Shift targeting, locks, dealer, payout and Tunnel Vision passed")
	_scene.free()
	quit(0)

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(_output.path_join(label + ".png"))
	assert(error == OK, "Could not save machine review capture")
