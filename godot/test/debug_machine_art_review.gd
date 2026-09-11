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
	assert(_scene.get_node_or_null("HealthBar") == null, "Side tube must be removed")
	assert(_scene.tutorial_anchor("health").position + _scene.global_position == _scene.SPINS_LEFT_LABEL_RECT.position, "Tutorial must highlight the fixed shelf counter")
	assert(_scene.position == Vector2(4, 0), "Cabinet must be centered four pixels right")
	assert(_scene._spin_button.global_position == Vector2(57, 213), "Centered SPIN must not move with the cabinet")
	assert(_scene._spins_left_label.global_position == Vector2(28, 213), "Shelf count must stay fixed")
	_scene._nudge(2.0)
	await create_timer(0.2).timeout
	assert(_scene.position == _scene.CABINET_OFFSET, "Shake must return to the new cabinet center")
	assert(_scene._spin_button.global_position == Vector2(57, 213), "Shake must leave the shelf button fixed")
	await _capture("01-idle")
	for state in ["normal", "pressed", "disabled", "hover", "focus"]:
		var face := _scene._spin_button.get_theme_stylebox(state) as StyleBoxTexture
		assert(face.texture.resource_path.ends_with("preview_spin_%s.png" % state), "SPIN must use extracted preview art")
	var beacon := _scene.get_node("Jackpot") as Sprite2D
	assert(beacon.texture.resource_path.ends_with("jackpot_beacon.svg"), "Jackpot must use the cabinet beacon")
	_scene._bursts.refresh_jackpot_lamp(true, true)
	assert(beacon.frame == 0, "Held payout must not light the beacon early")
	_scene._bursts.refresh_jackpot_lamp(true, false)
	assert(beacon.frame == 1, "Jackpot must light the beacon")
	await _capture("01-jackpot-lit")
	_scene._bursts.flash_jackpot_lamp(_scene._refresh_jackpot_lamp.bind(false))
	await create_timer(0.1).timeout
	assert(beacon.frame in [1, 2], "Jackpot flash must use a lit beacon frame")
	await _capture("01-jackpot-flash")
	await create_timer(0.95).timeout
	assert(beacon.frame == 0, "Jackpot flash must return to its current result state")
	var spin_legend := _scene.get_node("SpinsLegend") as Label
	assert(spin_legend.get_rect().end.x <= 55, "SPINS legend must remain in the counter well")
	var screen := Rect2(33, 47, 90, 58)
	var title := _scene.get_node("CrtTargetTitle") as Label
	var target := _scene.get_node("CrtTargetNumber") as Label
	assert(screen.encloses(_scene._dealer_icon.get_rect()), "Dealer must fit inside the CRT glass")
	assert(_scene._dealer_icon.get_rect().end.y <= 95, "Dealer must leave room for his approach bar")
	for slot_pos: Vector2 in _scene._boosts.SLOT_POSITIONS:
		assert(slot_pos.y >= 100, "Active items must stay below the dealer path ending at y99")
	assert(title.position.y == target.position.y and title.get_theme_font_size("font_size") == target.get_theme_font_size("font_size"), "Target title and value must share a baseline and font size")
	assert(screen.encloses(title.get_rect()) and screen.encloses(target.get_rect()), "Target text must fit inside CRT glass")
	assert((_scene.get_node("stash") as TextureRect).texture == null, "Stash wells belong to cabinet material, not an overlay")
	for index in range(2):
		var item := _scene.get_node("stash/StashSlot%d/Icon" % (index + 1)) as TextureRect
		var aperture := Rect2(102 + index * 18, 214, 14, 14)
		assert(aperture.encloses(item.get_global_rect()), "Item art must fit its square cabinet aperture")
	run.wealthTargetIndex = 7
	_scene._refresh_target_readout()
	await process_frame
	assert(screen.encloses(target.get_rect()), "The 5000 target must fit inside the CRT")
	var active_fields := ["guaranteeSymbolSpins", "cocktailBoostSpins", "pairBoostSpins", "potionSpins", "forceFlatlineSpins"]
	for field: String in active_fields:
		run.set(field, 2)
	_scene._update_hud()
	await _capture("01-populated-crt")
	run.freeSpinsRemaining = 1
	_scene._refresh_free_spin_banner()
	assert(not target.visible and not title.visible, "FREE SPIN must replace the target text")
	assert(_scene._wealth.bar_sprite().visible and _scene._dealer_icon.visible,
		"FREE SPIN must retain progress and dealer information")
	await _capture("01-free-spin-items")
	run.freeSpinsRemaining = 0
	_scene._refresh_free_spin_banner()
	var shown_items := 0
	for entry: Dictionary in _scene._boosts.slots():
		var slot := entry["slot"] as Control
		if slot.visible:
			shown_items += 1
			assert(Rect2(33, 100, 90, 9).encloses(slot.get_rect()), "Item duration must stay in its CRT row")
	assert(shown_items == 5, "Review must show all five duration indicators")
	for field: String in active_fields:
		run.set(field, 0)
	run.wealthTargetIndex = 0
	_scene._update_hud()
	assert(_scene.get_node_or_null("PowerBar") == null, "Side power gauge must be removed")
	_scene._set_sequence_lock(true)
	run.scoreEarned = 0
	run.lucidityCoins = 0
	run.abilitiesUsed = ["shift"]
	run.powerRestoreCharges = 1
	_scene._power_seen_lucidity = 0
	_scene._power_bar_score = 0
	for coins in [10, 20, 30]:
		run.lucidityCoins = coins
		_scene._advance_power_bar()
		await create_timer(0.93).timeout
		await _capture("01-power-lamps-%02d" % coins)
		if coins < 30:
			assert(_scene._power_bar_frame == coins / 10, "Wrong lamp activated")
			assert(run.abilitiesUsed.has("shift"), "Power restored before the third lamp")
	assert(not run.abilitiesUsed.has("shift"), "Third lamp did not restore the spent power")
	await create_timer(0.8).timeout
	assert(_scene._power_bar_frame == 0, "Restore did not reset the lamps")
	await _capture("01-power-lamps-reset")
	run.lucidityCoins = 60
	_scene._advance_power_bar()
	await create_timer(1.2).timeout
	assert(_scene._power_bar_frame == 3, "Full lamps must wait when no restore is available")
	await _capture("01-power-lamps-waiting")
	run.powerRestoreCharges = 1
	run.abilitiesUsed = ["reroll"]
	_scene._advance_power_bar()
	await create_timer(1.2).timeout
	assert(not run.abilitiesUsed.has("reroll"), "Banked lamps required extra coins to restore")
	_scene._stop_restore_flash()
	run.powerRestoreCharges = 1
	run.lucidityCoins = 0
	run.scoreEarned = 40
	_scene._power_seen_lucidity = 40
	_scene._power_bar_score = 0
	_scene._set_power_bar_frame(0)
	_scene._set_sequence_lock(false)
	for count in [0, 1, 3, _scene.MAX_RUN_SPINS]:
		run.neurons = count
		_scene._update_hud()
		assert(int(_scene._spins_left_label.text) == count, "Shelf counter disagrees with remaining spins")
		await _capture("01-spin-counter-%02d" % count)
	run.neurons = 1
	_scene._update_hud()
	meta.chipAugmentsPurchased = {"aug_emergency_reserve": 1}
	meta.emergencyReserveUsed = false
	_scene._refresh_reserve_glow()
	assert(_scene._reserve_glow_sprite.visible, "Reserve must outline the counter")
	await create_timer(0.3).timeout
	await _capture("01-spin-counter-reserve")
	meta.emergencyReserveUsed = true
	_scene._refresh_reserve_glow()
	assert(not _scene._reserve_glow_sprite.visible, "Spent reserve still glows")
	meta.chipAugmentsPurchased = {}
	meta.emergencyReserveUsed = false
	run.neurons = 15
	_scene._update_hud()
	_scene._wealth.set_score(99, false)
	_scene._wealth.set_score(100, true)
	await create_timer(0.12).timeout
	await _capture("01-odometer-carry")
	_scene._wealth.set_score(40, false)
	assert(_scene.tutorial_anchor("wealth").encloses(Rect2(74, 61, 46, 14)),
		"Tutorial still points to the lower cabinet wealth display")
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
	var before_shift: String = str(run.lastResult["reels"][1])
	shift_press.button_index = MOUSE_BUTTON_LEFT
	shift_press.position = Vector2(75.5, 211.0)
	shift_press.pressed = true
	root.push_input(shift_press, true)
	shift_press = shift_press.duplicate() as InputEventMouseButton
	shift_press.pressed = false
	root.push_input(shift_press, true)
	await create_timer(1.0).timeout
	assert(_scene._targeting_power_id.is_empty() and str(run.lastResult["reels"][1]) != before_shift,
		"Lower Shift arrow must change the reel, even if the payout immediately restores Shift")
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
	run.ownedUpgrades = ["pos_learning", "pacte_tunnel_vision"]
	_scene._refresh_consumable_fx()
	var book := _scene._consumable_fx.layer().get_node("LearningAttachment") as TextureRect
	assert(book.visible and book.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Learning attachment must appear without blocking reel input")
	assert(_scene._consumable_fx.persistent_nodes().has(book), "Learning attachment must survive effect cleanup")
	await create_timer(0.4).timeout
	await _capture("06-learning-and-tunnel")
	run.ownedUpgrades = ["pos_learning"]
	_scene._refresh_consumable_fx()
	assert(book.visible and not shutter.visible, "Augment attachments must be independent")
	await _capture("06-learning")
	run.ownedUpgrades = []
	_scene._refresh_consumable_fx()
	assert(not book.visible, "Removed Learning left its attachment visible")
	_scene._callouts.play_win("pair", 20)
	assert(not _scene._wealth.odometer().visible, "Payout must own the CRT above the score")
	await create_timer(0.08).timeout
	await _capture("07-payout")
	_scene._callouts.stop_win()
	assert(_scene._wealth.odometer().visible, "Score did not return after the payout")
	_scene._react_dealer("miss")
	_scene._tv.begin_pop("reaction_review")
	await create_timer(3.1).timeout
	var reaction := _scene._dealer_icon.get_node("DealerReaction") as Label
	assert(reaction.get_global_rect().end.y <= 94.0,
		"Dealer caption must leave the approach row visible: %s minimum %s font %d" % [reaction.get_global_rect(), reaction.get_minimum_size(), reaction.get_theme_font_size("font_size")])
	assert(reaction.visible and reaction.visible_characters == 0,
		"Hidden dealer reaction consumed its reading time")
	_scene._tv.end_pop("reaction_review")
	await create_timer(0.4).timeout
	assert(reaction.visible and reaction.visible_characters == reaction.text.length(),
		"Dealer reaction did not type after the CRT returned")
	await _capture("07-dealer-reaction")
	# A synthetic paying COMBO must start outside the random spin's rescue warning.
	run.comboDefeatPending = false
	_scene._callouts.set_loss_display(0)
	run.winBoostEnabled = true
	_scene._callouts.show_combo(1, 5, 10)
	var wealth_frame := _scene._wealth.odometer().get_node("WealthBarArt") as Sprite2D
	assert(_scene._callouts.combo_sprite().z_index > _scene._wealth.odometer().z_index + wealth_frame.z_index,
		"Odometer dividers must not draw across the COMBO panel")
	assert(_scene._callouts.combo_sprite().scale == Vector2.ONE,
		"COMBO lettering must render at native resolution")
	assert(_scene._callouts.combo_sprite().hframes == 9, "COMBO must show all nine stages")
	await _capture("07-combo")
	_scene._callouts.stop_combo()
	_scene._callouts.show_combo(8, 90, 45)
	await _capture("07-combo-max")
	_scene._callouts.stop_combo()
	run.winBoostEnabled = false
	assert(_scene._wealth.odometer().visible and not _scene._callouts.combo_sprite().visible,
		"Closing COMBO must reveal the wealth display")
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
	var stickers: Array = _scene._augments.badges()
	for entry: Dictionary in stickers:
		var sticker := entry["badge"] as Button
		assert(Rect2(42, 250, 88, 36).encloses(sticker.get_rect()),
			"Augment sticker must stay on the lower cabinet clear of controls and cash outlet")
	_scene._callouts.play_win("triple", 50)
	assert((stickers[0]["badge"] as Button).visible,
		"CRT callouts must leave cabinet stickers visible")
	assert(not _scene._multiplier_sprite.visible, "TV payout must hide the multiplier")
	await _capture("07-crt-payout-priority")
	_scene._callouts.stop_win()
	# Touching the well margin must use an item even though its inset art is smaller.
	run.comboDefeatPending = false
	run.runConsumables = {"cons_cigarette": 1, "cons_focus": 1}
	_scene._refresh_controls()
	var well := _scene._stash.slot_node(0) as Control
	var item_icon := _scene._stash.icons()[0] as TextureRect
	assert(well.size == Vector2(16, 18) and item_icon.size == Vector2(12, 14), "Stash art must be inset within its larger touch well")
	var margin := well.global_position + Vector2(0.5, 0.5)
	assert(not item_icon.get_global_rect().has_point(margin), "Review tap must hit the well outside its icon")
	_scene._set_sequence_lock(true)
	var stash_tap := InputEventMouseButton.new()
	stash_tap.button_index = MOUSE_BUTTON_LEFT
	stash_tap.position = margin
	stash_tap.pressed = true
	root.push_input(stash_tap, true)
	assert(run.runConsumables.get("cons_cigarette", 0) == 1, "Locked stash accepted a margin tap")
	_scene._set_sequence_lock(false)
	root.push_input(stash_tap, true)
	assert(run.runConsumables.get("cons_cigarette", 0) == 0, "Well margin did not use its item")
	stash_tap = stash_tap.duplicate() as InputEventMouseButton
	stash_tap.pressed = false
	root.push_input(stash_tap, true)
	await _capture("07-stash-margin-used")
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
