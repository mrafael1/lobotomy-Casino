extends SceneTree

## Throwaway smoke check (issue #21): instantiate the new/changed scenes (catches
## GDScript parse/instantiate regressions) and assert the dealer's pre-run vs in-run
## offer-pool branching is correct. Not a parity gate.
##
##   godot --headless --path godot -s res://test/scene_smoke.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array = []
	var run_store: Node = get_root().get_node("RunStateStore")
	var meta_store: Node = get_root().get_node("MetaStateStore")
	meta_store.is_first_launch = false

	# Every touched scene loads + instantiates without parse/runtime errors.
	for path in [
		"res://scenes/start_menu_scene.tscn",
		"res://scenes/shop_scene.tscn",
		"res://scenes/upgrades_scene.tscn",
		"res://scenes/scores_scene.tscn",
		"res://scenes/settings_scene.tscn",
		"res://scenes/collection_scene.tscn",
		"res://scenes/options_overlay.tscn",
		"res://scenes/in_run_dealer_offer.tscn",
		"res://scenes/game_over_ending_overlay.tscn",
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
	_check_machine_art_mix(machine, failures)
	_check_base_scene_parity(failures)
	_check_first_launch_tutorial(meta_store, failures)
	_check_scene_nav(failures)
	_check_machine_ending_flow_source(failures)
	_check_flatline_action_text(machine, meta_store, failures)
	_check_global_options_layout(failures)
	_check_water_lucidity_gain(run_store, failures)
	await _check_machine_water_feedback(machine, run_store, failures)
	await _check_machine_consumable_feedback(machine, run_store, failures)
	await _check_upgrades_scene(failures)
	_check_smart_save_retention(failures)
	_check_issue27_overlay_layout(failures)
	_check_issue27_machine_stash_drag(machine, run_store, failures)
	await _check_issue28_machine_sequence_lock(machine, run_store, failures)
	_check_options_spin_lock_77(machine, run_store, failures)
	_check_dealer_compulsion_softlock_96(machine, run_store, failures)
	_check_consumable_roster_32(run_store, failures)
	_check_machine_reactions_35(machine, run_store, failures)
	_check_campaign_rebalance_38(machine, failures)
	await _check_odds_table_36(run_store, failures)
	await _check_neuron_meter_on_menu(failures)
	_check_flatline_overlay_meter(machine, failures)
	_check_wealth_screen(machine, run_store, failures)
	_check_wealth_zero_spins_62(machine, run_store, failures)
	_check_flatline_free_spins_75(machine, run_store, failures)
	_check_flatline_win_boost_76(run_store, failures)
	_check_deferred_negative_76(machine, failures)
	_check_dealer_pacing_76(run_store, failures)
	_check_frenzy_gauge_155(run_store, failures)
	_check_pending_combo_and_free_spin_ui(machine, run_store, failures)
	_check_compulsion_multiplier_76(machine, run_store, failures)
	_check_boost_duration_icons_76(machine, run_store, failures)
	_check_power_bar_76(machine, run_store, failures)
	await _check_eye_reveal(machine, failures)
	_check_score_table_51(machine, failures)
	await _check_spin_gain_fx_66(machine, run_store, failures)
	_check_spins_bar_lever_80(machine, run_store, failures)
	await _check_spins_counter_accuracy_80(machine, run_store, failures)
	_check_free_spin_multiplier_cost(run_store, failures)
	_check_issue92_rule_reworks(machine, run_store, meta_store, failures)
	_check_starting_powers_and_random_118(run_store, failures)
	_check_augmented_run_111(machine, run_store, meta_store, failures)
	await _check_augmented_menu_111(run_store, meta_store, failures)
	_check_run_persistence_111(run_store, failures)
	_check_save_resume_151(machine, run_store, failures)
	_check_tier_win_counter_142(run_store, meta_store, failures)
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

	# Offer pool branches on _pre_run (set in _ready from the mode above). The
	# pre-run shop rolls a persistent pair — max two consumables per visit.
	dealer._pre_run = true
	run_store.prerunOfferIds = null
	var shop_pool: Array = []
	for c in Consumables.LIST:
		shop_pool.append(String(c["id"]))
	var shop_offers: Array = dealer._offer_ids()
	if shop_offers.size() != 2 or shop_offers[0] == shop_offers[1] \
			or not shop_pool.has(shop_offers[0]) or not shop_pool.has(shop_offers[1]):
		failures.append("pre-run offers wrong: %s" % str(shop_offers))
	if dealer._offer_ids() != shop_offers:
		failures.append("pre-run offer pair is not stable across reads")
	run_store.prerunOfferIds = null
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

func _check_machine_art_mix(machine: Node, failures: Array) -> void:
	# The new neon cabinet/control sheets are native 160x320 art. The surrounding
	# reel/HUD sheets remain legacy 8x art, so both scale conventions must coexist.
	for rel in [
		"machine new view/machine_neon.png",
		"machine new view/neon_machine_lever.png",
		"machine new view/neon_machine_jackpot.png",
		"machine new view/neon_machine_power_bar.png",
	]:
		if not ResourceLoader.exists("res://assets/images/" + rel):
			failures.append("machine art: missing native asset %s" % rel)

	var cabinet := machine.get_node_or_null("Cabinet") as Sprite2D
	if cabinet == null:
		failures.append("machine art: native cabinet node is missing")
	elif cabinet.texture == null \
			or Vector2i(cabinet.texture.get_width(), cabinet.texture.get_height()) != Vector2i(160, 320) \
			or cabinet.scale != Vector2.ONE \
			or cabinet.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		failures.append("machine art: cabinet is not a 160x320 native sprite")

	var lever := machine.get_node_or_null("Lever") as Sprite2D
	if lever == null:
		failures.append("machine art: native lever node is missing")
	elif lever.texture == null \
			or Vector2i(lever.texture.get_width(), lever.texture.get_height()) != Vector2i(960, 320) \
			or lever.hframes != 6 \
			or lever.scale != Vector2.ONE \
			or lever.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		failures.append("machine art: lever is not a 6-frame native sprite")

	var jackpot := machine.get_node_or_null("Jackpot") as Sprite2D
	if jackpot == null:
		failures.append("machine art: native jackpot node is missing")
	elif jackpot.texture == null \
			or Vector2i(jackpot.texture.get_width(), jackpot.texture.get_height()) != Vector2i(480, 320) \
			or jackpot.hframes != 3 \
			or jackpot.scale != Vector2.ONE \
			or jackpot.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		failures.append("machine art: jackpot is not a 3-frame native sprite")

	var power_bar := machine.get_node_or_null("PowerBar") as Sprite2D
	if power_bar == null:
		failures.append("machine art: native power bar node is missing")
	elif power_bar.texture == null \
			or Vector2i(power_bar.texture.get_width(), power_bar.texture.get_height()) != Vector2i(960, 320) \
			or power_bar.hframes != 6 \
			or power_bar.vframes != 1 \
			or power_bar.scale != Vector2.ONE \
			or power_bar.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		failures.append("machine art: power bar is not a 6-frame native sprite")

	for node_name in [
		"ReelBacking", "WealthTrack", "WealthFill", "HealthTrack", "HealthFill",
		"Multiplier", "LockPower0", "LockPower1", "LockPower2", "RerollPower",
		"ShiftPower", "MemoryPower", "Reel0Top", "Reel0Bottom", "Reel0Center",
		"Reel1Top", "Reel1Bottom", "Reel1Center", "Reel2Top", "Reel2Bottom",
		"Reel2Center",
	]:
		var machine_art := machine.get_node_or_null(node_name) as Sprite2D
		if machine_art == null or machine_art.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
			failures.append("machine art: %s is not nearest-neighbor filtered" % node_name)
	if float(machine.POWER_BAR_CENTER.x) < 80.0:
		failures.append("machine art: power bar coin target is still on the left")

func _check_issue92_rule_reworks(machine: Node, run_store: Node, meta_store: Node, failures: Array) -> void:
	var triple_book := Evaluate.score_reels(["book", "book", "book"], 1.0, true,
		false, true)
	if String(triple_book["winType"]) != "triple" or int(triple_book["scoreEarned"]) != Payouts.TRIPLE_SCORE["eye"] \
			or not bool(triple_book.get("bookTripleChoice", false)):
		failures.append("issue92: triple book should score as eye and open choice: %s" % str(triple_book))

	var joker_eye := Evaluate.score_reels(["book", "eye", "eye"], 1.0, true,
		false, true)
	if String(joker_eye["winType"]) != "triple" or String(joker_eye.get("resolvedSymbol", "")) != "eye":
		failures.append("issue92: book should complete the highest near symbol triple: %s" % str(joker_eye))

	var hallucination := Evaluate.score_reels(["eye", "eye", "brain"], 1.0, true,
		false, false, 1.0, 1, true, 0.70)
	if String(hallucination["winType"]) != "triple" or int(hallucination["scoreEarned"]) != 35:
		failures.append("issue92: hallucination should score visible pair as 70%% triple: %s" % str(hallucination))

	var amped_pair := Evaluate.score_reels(["eye", "eye", "pill"], 1.0, true,
		false, false, 1.0, 0, false, 1.0, { "eye": 0.40 })
	if int(amped_pair["scoreEarned"]) != 14:
		failures.append("issue92: symbol reward amp should boost only the matched symbol: %s" % str(amped_pair))

	var previous_odds: Dictionary = meta_store.oddsUpgrades.duplicate(true)
	var previous_amp_symbol := String(meta_store.rewardAmpSymbol)
	meta_store.oddsUpgrades = { "eye": int(run_store.odds_max_level) }
	meta_store.rewardAmpSymbol = "pill"
	var bonuses: Dictionary = run_store._symbol_reward_bonuses_from_meta([
		"corr_reward_amp_1", "corr_reward_amp_2", "corr_reward_amp_3",
	])
	if not is_equal_approx(float(bonuses.get("eye", 0.0)), float(run_store.odds_max_level_reward_bonus)):
		failures.append("issue92: maxed odds level should add reward bonus: %s" % str(bonuses))
	if not is_equal_approx(float(bonuses.get("pill", 0.0)), 0.40):
		failures.append("issue92: reward amplification should target saved symbol: %s" % str(bonuses))
	meta_store.oddsUpgrades = previous_odds
	meta_store.rewardAmpSymbol = previous_amp_symbol

	var previous_run_phase := String(run_store.runPhase)
	var previous_owned: Array = run_store.ownedUpgrades.duplicate()
	var previous_last: Variant = run_store.lastResult
	var previous_locked: Array = run_store.lockedReels.duplicate()
	var previous_neurons := int(run_store.neurons)
	var previous_starting := int(run_store.startingNeurons)
	var previous_spin_count := int(run_store.spinCount)
	var previous_free_spins := int(run_store.freeSpinsRemaining)
	var previous_is_spinning := bool(run_store.isSpinning)
	var previous_pair_spins := int(run_store.pairBoostSpins)
	var previous_pair_hidden := int(run_store.pairBoostHiddenReels)
	var previous_cocktail := int(run_store.cocktailBoostSpins)
	var previous_penalty := float(run_store.cocktailPairTriplePenalty)
	run_store.runPhase = "running"
	run_store.ownedUpgrades = ["pos_enlightenment"]
	run_store.neurons = 10
	run_store.startingNeurons = 10
	run_store.lockedReels = [true, true, true]
	run_store.lastResult = { "reels": ["eye", "eye", "brain"] }
	run_store.cocktailBoostSpins = 1
	run_store.cocktailPairTriplePenalty = 0.0
	var cocktail_result: Variant = run_store.spin(false)
	if cocktail_result == null or int((cocktail_result as Dictionary).get("cocktailBonus", -1)) != 10:
		failures.append("issue92: hallucination cocktail bonus should ignore hidden third reel: %s" % str(cocktail_result))
	run_store.set_spinning(false)

	run_store.ownedUpgrades = ["pos_enlightenment"]
	run_store.lastResult = { "reels": ["vial", "vial", "brain"], "winType": "triple", "freeSpinsGranted": 0, "hiddenReelCount": 1 }
	run_store.neurons = 10
	var before_vial := int(run_store.neurons)
	machine._last_reacted_reels = []
	machine._last_reacted_spin = -1
	machine._apply_machine_reactions(true)
	if int(run_store.neurons) <= before_vial:
		failures.append("issue92: hallucination power-made visible pair did not trigger vial triple effect")
	run_store.lastResult = { "reels": ["flatline", "flatline", "flatline"], "winType": "triple", "freeSpinsGranted": 0, "hiddenReelCount": 1 }
	var before_flatline := int(run_store.flatlineResultCount)
	machine._last_reacted_reels = []
	machine._last_reacted_spin = -1
	machine._apply_machine_reactions(false)
	if int(run_store.flatlineResultCount) != before_flatline + 1:
		failures.append("issue92: hallucination flatline pair should trigger a close-call strike")

	if machine._derive_source_reel(["vial", "vial", "brain"]) != 1:
		failures.append("issue92: hallucination score burst should derive from second reel")
	machine._start_reel_spin_animation([false, false, false])
	if not bool(machine._locked_reels_during_spin[2]) or bool(machine._spin_reel_sprites[2].visible):
		failures.append("issue92: hallucination should not spin the hidden third reel")
	machine._stop_sfx(&"reel_spin")

	run_store.pairBoostSpins = 0
	run_store.pairBoostHiddenReels = 0
	run_store.ownedUpgrades = ["pos_enlightenment"]
	machine._refresh_tobacco_fx()
	if not bool(machine._tobacco_covers[2].visible):
		failures.append("issue92: hallucination should still cover the hidden third reel")
	if bool(machine._tobacco_smoke[2].emitting) or bool(machine._tobacco_smoke[2].visible):
		failures.append("issue92: hallucination hidden reel should not emit cigarette smoke")
	run_store.ownedUpgrades = []
	run_store.pairBoostSpins = 1
	run_store.pairBoostHiddenReels = 1
	machine._refresh_tobacco_fx()
	if not bool(machine._tobacco_smoke[2].emitting):
		failures.append("issue92: cigarette should still emit smoke on its hidden reel")

	run_store.runPhase = previous_run_phase
	run_store.ownedUpgrades = previous_owned
	run_store.lastResult = previous_last
	run_store.lockedReels = previous_locked
	run_store.neurons = previous_neurons
	run_store.startingNeurons = previous_starting
	run_store.spinCount = previous_spin_count
	run_store.freeSpinsRemaining = previous_free_spins
	run_store.isSpinning = previous_is_spinning
	run_store.pairBoostSpins = previous_pair_spins
	run_store.pairBoostHiddenReels = previous_pair_hidden
	run_store.cocktailBoostSpins = previous_cocktail
	run_store.cocktailPairTriplePenalty = previous_penalty

func _check_first_launch_tutorial(meta_store: Node, failures: Array) -> void:
	var previous_first_launch := bool(meta_store.is_first_launch)
	meta_store.is_first_launch = true
	var start_menu := (load("res://scenes/start_menu_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(start_menu)
	var tutorial := start_menu.get_node_or_null("TutorialModal") as Control
	var panel := start_menu.get_node_or_null("TutorialModal/Panel") as PanelContainer
	var body := start_menu.get_node_or_null("TutorialModal/Panel/Margin/Content/Body") as RichTextLabel
	var button := start_menu.get_node_or_null("TutorialModal/Panel/Margin/Content/OkButton") as Button
	if tutorial == null:
		failures.append("tutorial: TutorialModal is missing")
	else:
		if not tutorial.visible:
			failures.append("tutorial: first launch did not show the modal")
		if tutorial.process_mode != Node.PROCESS_MODE_ALWAYS:
			failures.append("tutorial: modal must process while the tree is paused")
	if panel == null:
		failures.append("tutorial: central panel is not a PanelContainer")
	if body == null:
		failures.append("tutorial: body is not a RichTextLabel")
	else:
		if not body.bbcode_enabled:
			failures.append("tutorial: RichTextLabel BBCode is not enabled")
		for phrase in ["The Objective", "Dealer Scene", "Upgrades Scene", "Machine Scene", "35 spins", "50 coins"]:
			if not body.text.contains(phrase):
				failures.append("tutorial: missing copy phrase '%s'" % phrase)
				break
	if button == null or button.text != "UNDERSTOOD":
		failures.append("tutorial: dismiss button is missing or mislabelled")
	if not get_root().get_tree().paused:
		failures.append("tutorial: first launch did not pause the tree")
	start_menu._dismiss_tutorial(false)
	if bool(meta_store.is_first_launch):
		failures.append("tutorial: dismiss did not clear is_first_launch")
	if get_root().get_tree().paused:
		failures.append("tutorial: dismiss did not unpause the tree")
	start_menu.queue_free()
	meta_store.is_first_launch = previous_first_launch

func _check_global_options_layout(failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var previous_campaign_failed := bool(meta_store.campaignFailed)
	var previous_wealth_reached := bool(meta_store.wealthEndingReached)
	var previous_campaign_active := bool(meta_store.campaignActive)
	var previous_campaign_left := int(meta_store.campaignNeuronsLeft)
	meta_store.campaignFailed = false
	meta_store.wealthEndingReached = false
	meta_store.campaignActive = true
	meta_store.campaignNeuronsLeft = maxi(1, previous_campaign_left)
	var start_menu := (load("res://scenes/start_menu_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(start_menu)
	if start_menu.get_node_or_null("MenuColumn/UpgradesButton") != null:
		failures.append("options: start menu still exposes old UpgradesButton")
	var run_store: Node = get_root().get_node("RunStateStore")
	var previous_phase := String(run_store.runPhase)
	run_store.runPhase = "running"
	start_menu._refresh_start_button()
	# Art mode reparents the button out of MenuColumn; reach it via the scene.
	var start_button := start_menu._start_button as Button
	if start_button == null:
		failures.append("menu: start button is missing")
	elif start_button.text != "CONTINUE":
		failures.append("menu: active run should show CONTINUE")
	run_store.runPhase = "idle"
	start_menu._refresh_start_button()
	if start_button != null and start_button.text != "CLASSIC RUN":
		failures.append("menu: idle state should show CLASSIC RUN")
	run_store.runPhase = previous_phase
	meta_store.campaignFailed = previous_campaign_failed
	meta_store.wealthEndingReached = previous_wealth_reached
	meta_store.campaignActive = previous_campaign_active
	meta_store.campaignNeuronsLeft = previous_campaign_left
	start_menu.queue_free()

	var dealer := (load("res://scenes/dealer_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(dealer)
	var dealer_options := dealer.get_node_or_null("options") as TextureButton
	if dealer_options == null:
		failures.append("options: dealer scene missing renamed options button")
	elif dealer_options.position.x > 20.0:
		failures.append("options: dealer options button is not top-left")
	_check_settings_icon(dealer_options, "dealer", failures)
	if dealer.get_node_or_null("BackButton") != null:
		failures.append("options: dealer scene still has BackButton node")
	_check_dealer_scene_revamp_55(dealer, failures)
	if dealer.get_node_or_null("OptionsOverlay") == null:
		failures.append("options: dealer scene missing shared OptionsOverlay")
	var credits_row := dealer.get_node_or_null("CreditsRow") as HBoxContainer
	var credits_label := dealer.get_node_or_null("CreditsRow/CreditsLabel") as Label
	var credits_coin := dealer.get_node_or_null("CreditsRow/Coin") as TextureRect
	if credits_row == null:
		failures.append("dealer: credits row is not an HBoxContainer")
	else:
		if credits_row.alignment != BoxContainer.ALIGNMENT_BEGIN:
			failures.append("dealer: credits row should align contents to Begin")
		if credits_row.anchor_left != 0.0 or credits_row.anchor_top != 1.0 or credits_row.anchor_bottom != 1.0:
			failures.append("dealer: credits row is not anchored bottom-left")
		if credits_row.position != Vector2(7.0, 300.0) or credits_row.size.y < 10.0:
			failures.append("dealer: credits row is not inside the full bottom-left coin-bank box: %s %s" % [credits_row.position, credits_row.size])
	if credits_label == null or credits_coin == null:
		failures.append("dealer: credits row must contain label and coin")
	elif credits_label.size_flags_vertical != Control.SIZE_SHRINK_CENTER or credits_coin.size_flags_vertical != Control.SIZE_SHRINK_CENTER:
		failures.append("dealer: credits label and coin are not vertically centered in their HBox")
	var dealer_bottom_hud := dealer.get_node_or_null("BottomHudLayer") as Control
	var dealer_neuron_number := dealer.get_node_or_null("BottomHudLayer/neuron_number") as Label
	if dealer_bottom_hud == null:
		failures.append("dealer: BottomHudLayer is missing")
	else:
		if dealer_bottom_hud.size != Vector2(160.0, 320.0):
			failures.append("dealer: BottomHudLayer is not full-canvas")
		if dealer_bottom_hud.z_index <= 50 or dealer_bottom_hud.z_index >= 200:
			failures.append("dealer: BottomHudLayer is not layered between scene art and options overlay")
	if dealer_neuron_number == null:
		failures.append("dealer: neuron_number label is missing")
	else:
		if dealer_neuron_number.anchor_left != 0.5 or dealer_neuron_number.anchor_right != 0.5 \
				or dealer_neuron_number.anchor_top != 1.0 or dealer_neuron_number.anchor_bottom != 1.0:
			failures.append("dealer: neuron_number is not anchored Center Bottom")
		if dealer_neuron_number.offset_top != -14.0 or dealer_neuron_number.offset_bottom != -4.0:
			failures.append("dealer: neuron_number is not positioned at the bottom edge")
		if dealer_neuron_number.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER:
			failures.append("dealer: neuron_number is not centered inside its label box")
		# Issue #38: the label is the anchor; the pixel-art meter is the readout.
		if dealer_neuron_number.text != "":
			failures.append("dealer: neuron_number should render no text (meter replaces it)")
	_check_neuron_meter_absent("dealer", dealer_bottom_hud, failures)
	_check_start_confirm_and_lab_glow_84(dealer, failures)
	dealer.queue_free()
	_check_painting_reroll_117(failures)
	_check_chip_augments(failures)

	var machine := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(machine)
	var machine_options := machine.get_node_or_null("options") as TextureButton
	if machine_options == null:
		failures.append("options: machine scene missing options button")
	elif machine_options.position.x > 20.0:
		failures.append("options: machine options button is not top-left")
	_check_settings_icon(machine_options, "machine", failures)
	if machine.get_node_or_null("OptionsOverlay") == null:
		failures.append("options: machine scene missing shared OptionsOverlay")
	var bottom_hud := machine.get_node_or_null("BottomHudLayer") as Control
	var neuron_number := machine.get_node_or_null("BottomHudLayer/neuron_number") as Label
	var health_label := machine.get_node_or_null("HealthLabel") as Label
	if bottom_hud == null:
		failures.append("machine: BottomHudLayer is missing")
	else:
		if bottom_hud.size != Vector2(160.0, 320.0):
			failures.append("machine: BottomHudLayer is not full-canvas")
		if bottom_hud.z_index <= 50 or bottom_hud.z_index >= 200:
			failures.append("machine: BottomHudLayer is not layered between cabinet art and options overlay")
	if neuron_number == null:
		failures.append("machine: neuron_number label is missing")
	else:
		if neuron_number.anchor_left != 0.5 or neuron_number.anchor_right != 0.5 \
				or neuron_number.anchor_top != 1.0 or neuron_number.anchor_bottom != 1.0:
			failures.append("machine: neuron_number is not anchored Center Bottom")
		if neuron_number.offset_top != -14.0 or neuron_number.offset_bottom != -4.0:
			failures.append("machine: neuron_number is not positioned at the bottom edge")
		if neuron_number.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER:
			failures.append("machine: neuron_number is not centered inside its label box")
		# Issue #38: the label is the anchor; the pixel-art meter is the readout.
		if neuron_number.text != "":
			failures.append("machine: neuron_number should render no text (meter replaces it)")
		_check_neuron_meter_absent("machine", bottom_hud, failures)
		# The -1 NEURON popup no longer fires during normal play (flatline overlay only).
		if machine.get_node_or_null("BottomHudLayer/NeuronSpendFeedback") != null:
			failures.append("machine: neuron spend feedback should not appear on the normal HUD")
	if health_label == null:
		failures.append("machine: HealthLabel spins counter is missing")
	else:
		if health_label.position != Vector2(43.0, 85.0):
			failures.append("machine: spins counter is not above the red bar")
	machine.queue_free()

	var overlay := (load("res://scenes/options_overlay.tscn") as PackedScene).instantiate()
	get_root().add_child(overlay)
	var options_panel := overlay.get_node_or_null("Panel") as PanelContainer
	var options_contour := overlay.get_node_or_null("Contour") as Panel
	if options_contour == null:
		failures.append("options: overlay missing neon contour")
	var panel_style := options_panel.get_theme_stylebox("panel") as StyleBoxFlat \
		if options_panel != null else null
	if panel_style == null or panel_style.border_width_left != 1 or panel_style.shadow_size < 1:
		failures.append("options: panel is missing the neon contour style")
	for path in ["Panel/Menu/ScoresButton", "Panel/Menu/SettingsButton", "Panel/Menu/CollectionButton", "Panel/Menu/MenuButton"]:
		var option_button := overlay.get_node_or_null(path) as Button
		if option_button == null:
			failures.append("options: overlay missing %s" % path)
		else:
			var button_style := option_button.get_theme_stylebox("normal") as StyleBoxTexture
			if button_style == null or button_style.texture == null:
				failures.append("options: %s is not using start-menu button art" % path)
	var close_button := overlay.get_node_or_null("CloseButton") as Button
	if close_button == null or close_button.text != "X":
		failures.append("options: overlay close button is not the pixel X control")
	elif options_panel != null and close_button.position.y >= options_panel.position.y + 16.0:
		failures.append("options: close button is not in the panel's top-right corner")
	overlay.queue_free()

	var settings := (load("res://scenes/settings_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(settings)
	_check_settings_neon(settings, failures)
	settings.queue_free()

func _check_settings_icon(button: TextureButton, scene_name: String, failures: Array) -> void:
	if button == null:
		return
	const asset_path := "res://assets/images/ui/setting_icon.png"
	if not ResourceLoader.exists(asset_path):
		failures.append("options: %s is missing the new setting icon" % scene_name)
		return
	var icon := button.texture_normal
	if icon == null or icon.get_width() != 69 or icon.get_height() != 66:
		failures.append("options: %s is not using the 69x66 setting icon" % scene_name)
	if button.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		failures.append("options: %s setting icon is not nearest-neighbor filtered" % scene_name)

func _check_water_lucidity_gain(run_store: Node, failures: Array) -> void:
	var previous_phase := String(run_store.runPhase)
	var previous_spinning := bool(run_store.isSpinning)
	var previous_dealer_incoming := bool(run_store.dealerIncoming)
	var previous_dealer_pending := bool(run_store.dealerPending)
	var previous_lucidity := int(run_store.lucidityCoins)
	var previous_consumables: Dictionary = run_store.runConsumables.duplicate(true)
	var previous_abilities: Array = run_store.abilitiesUsed.duplicate()
	var previous_restores: Array = run_store.pendingPowerRestores.duplicate()
	var previous_spin_count := int(run_store.spinCount)

	run_store.runPhase = "running"
	run_store.isSpinning = false
	run_store.dealerIncoming = false
	run_store.dealerPending = false
	run_store.lucidityCoins = 20
	run_store.runConsumables = { "item_water": 1 }
	run_store.abilitiesUsed = []
	run_store.pendingPowerRestores = []
	run_store.spinCount = 0

	if not run_store.use_consumable("item_water"):
		failures.append("water: use_consumable returned false")
	elif int(run_store.lucidityCoins) != 60:
		failures.append("water: should grant 40 lucidity coins (20 -> 60), got %d" % int(run_store.lucidityCoins))

	run_store.runPhase = previous_phase
	run_store.isSpinning = previous_spinning
	run_store.dealerIncoming = previous_dealer_incoming
	run_store.dealerPending = previous_dealer_pending
	run_store.lucidityCoins = previous_lucidity
	run_store.runConsumables = previous_consumables
	run_store.abilitiesUsed = previous_abilities
	run_store.pendingPowerRestores = previous_restores
	run_store.spinCount = previous_spin_count

func _check_machine_water_feedback(machine: Node, run_store: Node, failures: Array) -> void:
	var previous_phase := String(run_store.runPhase)
	var previous_spinning := bool(run_store.isSpinning)
	var previous_dealer_incoming := bool(run_store.dealerIncoming)
	var previous_dealer_pending := bool(run_store.dealerPending)
	var previous_lucidity := int(run_store.lucidityCoins)
	var previous_consumables: Dictionary = run_store.runConsumables.duplicate(true)
	var previous_abilities: Array = run_store.abilitiesUsed.duplicate()
	var previous_restores: Array = run_store.pendingPowerRestores.duplicate()
	var previous_spin_count := int(run_store.spinCount)
	var previous_display := int(machine._display_lucidity)
	var previous_coin_prev := int(machine._coin_prev_lucidity)

	run_store.runPhase = "running"
	run_store.isSpinning = false
	run_store.dealerIncoming = false
	run_store.dealerPending = false
	run_store.lucidityCoins = 20
	run_store.runConsumables = { "item_water": 1 }
	run_store.abilitiesUsed = []
	run_store.pendingPowerRestores = []
	run_store.spinCount = 0
	machine._set_sequence_lock(false)
	machine._set_display_lucidity(20)
	machine._coin_prev_lucidity = 20

	machine._on_stash_pressed(0)
	if int(run_store.lucidityCoins) != 60:
		failures.append("machine water: should grant lucidity immediately on consume")
	if int(machine._coin_prev_lucidity) != 60:
		failures.append("machine water: immediate consume gain will replay on next spin")
	await create_timer(2.0).timeout
	if int(machine._display_lucidity) != 60:
		failures.append("machine water: HUD did not count to Water lucidity before next spin")

	machine._set_sequence_lock(false)
	machine._set_display_lucidity(previous_display)
	machine._coin_prev_lucidity = previous_coin_prev
	run_store.runPhase = previous_phase
	run_store.isSpinning = previous_spinning
	run_store.dealerIncoming = previous_dealer_incoming
	run_store.dealerPending = previous_dealer_pending
	run_store.lucidityCoins = previous_lucidity
	run_store.runConsumables = previous_consumables
	run_store.abilitiesUsed = previous_abilities
	run_store.pendingPowerRestores = previous_restores
	run_store.spinCount = previous_spin_count

func _check_machine_consumable_feedback(machine: Node, run_store: Node, failures: Array) -> void:
	var expected := {
		"cons_tea": "RESTORE POWER",
		"item_pill": "WIN GUARANTEED",
		"item_cocktail": "RARITY BONUS",
		"item_energy_drink": "2 FREE SPINS",
	}
	for id in expected:
		var hint: Dictionary = machine.use_hints.get(String(id), {})
		if hint.is_empty() or String(hint.get("pos", "")) != String(expected[id]):
			failures.append("machine consumable feedback: wrong hint for %s" % String(id))

	var previous_phase := String(run_store.runPhase)
	var previous_spinning := bool(run_store.isSpinning)
	var previous_dealer_incoming := bool(run_store.dealerIncoming)
	var previous_dealer_pending := bool(run_store.dealerPending)
	var previous_consumables: Dictionary = run_store.runConsumables.duplicate(true)
	var previous_abilities: Array = run_store.abilitiesUsed.duplicate()
	var previous_restores: Array = run_store.pendingPowerRestores.duplicate()
	var previous_spin_count := int(run_store.spinCount)

	run_store.runPhase = "running"
	run_store.isSpinning = false
	run_store.dealerIncoming = false
	run_store.dealerPending = false
	run_store.runConsumables = { "cons_tea": 1 }
	run_store.abilitiesUsed = ["reroll"]
	run_store.pendingPowerRestores = []
	run_store.spinCount = 0
	run_store.lucidityCoins = 0 # keep the power flow deterministic: no bank steps, direct restore
	machine._set_sequence_lock(false)
	machine._power_coins_in_flight = 0
	machine._power_batch_running = false
	machine._power_bar_score = 0
	machine._power_seen_lucidity = 0

	machine._on_stash_pressed(0)
	var fx_layer := machine._fx_layer as Control
	var tea_petals := fx_layer.get_node_or_null("TeaSakuraPetals") if fx_layer != null else null
	if tea_petals == null:
		failures.append("issue34: Tea did not spawn sakura petals")
	var hint_layer := machine.get_node_or_null("BottomHudLayer/HintLayer") as Control
	var spawned: Node = null
	if hint_layer != null and hint_layer.get_child_count() > 0:
		spawned = hint_layer.get_child(hint_layer.get_child_count() - 1)
	if spawned == null or not (spawned is HintLabel):
		failures.append("machine consumable feedback: Tea did not spawn a hint")
	elif (spawned as HintLabel)._pos_label == null or (spawned as HintLabel)._pos_label.text != "+ RESTORE POWER":
		failures.append("machine consumable feedback: Tea hint missing '+ RESTORE POWER' line")
	# Tea restored the used ability (gameplay, deterministic) and engaged the restore
	# visual (a coin is in flight, or the restore already committed the pending entry).
	if run_store.abilitiesUsed.has("reroll"):
		failures.append("machine consumable feedback: Tea did not restore the used ability")
	if not machine._power_sequence_active() and not run_store.pendingPowerRestores.is_empty():
		failures.append("machine consumable feedback: Tea queued a restore but no coin flew")
	await create_timer(1.0).timeout
	if spawned == null or not is_instance_valid(spawned):
		failures.append("machine consumable feedback: hint disappeared before the 1.5s hold")
	elif (spawned as HintLabel).modulate.a < 0.95:
		failures.append("machine consumable feedback: hint faded before the 1.5s hold")
	if spawned != null and is_instance_valid(spawned):
		spawned.queue_free()
	await create_timer(float(machine.tea_petal_time) + 0.3).timeout

	machine._play_close_call_heartbeat()
	if machine._close_call_heartbeat_tween == null:
		failures.append("issue34: close call did not start heartbeat zoom")
	machine._clear_close_call_heartbeat()

	machine._play_white_powder_distortion()
	var distortion := fx_layer.get_node_or_null("WhitePowderDistortion") if fx_layer != null else null
	if distortion == null:
		failures.append("issue34: White Powder did not spawn distortion")
	if machine._white_powder_distortion_tween != null and machine._white_powder_distortion_tween.is_valid():
		machine._white_powder_distortion_tween.kill()
	machine._white_powder_distortion_tween = null
	if distortion != null and is_instance_valid(distortion):
		distortion.free()

	machine._set_sequence_lock(false)
	machine._power_coins_in_flight = 0
	machine._power_batch_running = false
	run_store.runPhase = previous_phase
	run_store.isSpinning = previous_spinning
	run_store.dealerIncoming = previous_dealer_incoming
	run_store.dealerPending = previous_dealer_pending
	run_store.runConsumables = previous_consumables
	run_store.abilitiesUsed = previous_abilities
	run_store.pendingPowerRestores = previous_restores
	run_store.spinCount = previous_spin_count

func _check_scene_nav(failures: Array) -> void:
	var nav: Node = get_root().get_node("SceneNav")
	nav.clear()
	nav.push_scene("res://scenes/dealer_scene.tscn", true)
	if nav.peek_back_scene() != "res://scenes/dealer_scene.tscn":
		failures.append("scene nav: did not retain dealer as return scene")
	if not nav.peek_back_restores_options():
		failures.append("scene nav: did not retain options restore flag")
	nav.clear()

func _check_machine_ending_flow_source(failures: Array) -> void:
	var file := FileAccess.open("res://scenes/machine_scene.gd", FileAccess.READ)
	if file == null:
		failures.append("machine ending flow: could not read machine_scene.gd")
		return
	var source := file.get_as_text()
	if not source.contains("_start_again_from_wealth"):
		failures.append("machine ending flow: wealth screen is missing Start Again handling")
	if not source.contains("continue_pressed.connect(_continue_from_wealth)"):
		failures.append("machine ending flow: wealth screen is missing CONTINUE handling")
	if not source.contains("_can_resume_after_wealth()"):
		failures.append("machine ending flow: wealth screen is missing continuation gating")
	if not source.contains("GAME_OVER_ENDING_SCENE"):
		failures.append("machine ending flow: dedicated game-over scene is missing")
	if source.contains("EXIT CASINO"):
		failures.append("machine ending flow: old EXIT CASINO wealth action still present")
	if source.contains("BANK & LAB"):
		failures.append("machine ending flow: old bank/lab wealth transition still present")

func _check_flatline_action_text(machine: Node, meta_store: Node, failures: Array) -> void:
	var previous_neurons := int(meta_store.campaignNeuronsLeft)
	meta_store.campaignNeuronsLeft = 5
	if machine._flatline_action_text() != "CONTINUE":
		failures.append("flatline action: campaign neurons > 0 should show CONTINUE")
	meta_store.campaignNeuronsLeft = 0
	if machine._flatline_action_text() != "TRY AGAIN":
		failures.append("flatline action: campaign neurons <= 0 should show TRY AGAIN")
	meta_store.campaignNeuronsLeft = previous_neurons

func _check_issue27_overlay_layout(failures: Array) -> void:
	var ps := load("res://scenes/in_run_dealer_offer.tscn") as PackedScene
	if ps == null:
		failures.append("issue27: in-run dealer overlay failed to load")
		return
	var overlay := ps.instantiate()
	get_root().add_child(overlay)

	var tap := overlay.get_node("TapLabel") as Label
	if tap.get_theme_font_size("font_size") < 12:
		failures.append("issue27: tap warning font is not punchy")
	var tap_color := tap.get_theme_color("font_color")
	if tap_color.r < 0.75 or tap_color.b < 0.9:
		failures.append("issue27: tap warning is not light purple")

	var bubble := overlay.get_node("SpeechBubble") as Control
	var speech := overlay.get_node("SpeechBubble/SpeechLabel") as Label
	var bubble_graphic := overlay.get_node("SpeechBubble/BubbleGraphic") as TextureRect
	if bubble_graphic.texture == null:
		failures.append("issue27: bubble graphic texture missing")
	if speech.position != Vector2.ZERO or speech.size.x > bubble.size.x or speech.size.y > bubble.size.y:
		failures.append("issue27: speech text not inside bubble")

	overlay._apply_side("left")
	var dealer_sprite := overlay.get_node("DealerRoot/DealerSprite") as Sprite2D
	var authored_dealer_scale := dealer_sprite.scale
	var authored_dealer_position := dealer_sprite.position
	if not is_equal_approx(dealer_sprite.rotation, PI / 2.0):
		failures.append("issue27: left dealer rotation wrong")
	if overlay._offscreen_x >= overlay._target_x:
		failures.append("issue27: left dealer does not pop in from off-screen")
	if bubble.position.x < 0.0 or bubble.position.x + bubble.size.x > 160.0:
		failures.append("issue27: left bubble is off-screen")

	overlay._apply_side("right")
	if dealer_sprite.scale != authored_dealer_scale:
		failures.append("issue27: dealer side placement overwrote authored scale")
	if dealer_sprite.position != authored_dealer_position:
		failures.append("issue27: dealer side placement overwrote authored position")
	if not is_equal_approx(dealer_sprite.rotation, -PI / 2.0):
		failures.append("issue27: right dealer rotation wrong")
	if overlay._target_x < 0.0 or overlay._target_x > 160.0:
		failures.append("issue27: right dealer target is off-canvas")
	if overlay._offscreen_x <= overlay._target_x:
		failures.append("issue27: right dealer does not pop in from off-screen")
	if bubble.position.x < 0.0 or bubble.position.x + bubble.size.x > 160.0:
		failures.append("issue27: right bubble is off-screen")

	overlay._position_prompt_buttons()
	var look := overlay.get_node("LookButton") as Button
	var ignore_button := overlay.get_node("IgnoreButton") as Button
	var row_left := look.position.x
	var row_right := ignore_button.position.x + ignore_button.size.x
	if absf(((row_left + row_right) * 0.5) - 80.0) > 0.5 or row_left <= 0.0 or row_right >= 160.0:
		failures.append("issue27: look/ignore buttons are not bottom-centered")
	if look.text != "look" or ignore_button.text != "ignore":
		failures.append("issue27: look/ignore button labels wrong")
	if look.position.y >= ignore_button.position.y:
		failures.append("issue27: look button is not above ignore button")
	var offer_slot_1 := overlay.get_node("ItemLayer/OfferSlot1") as Control
	var offer_slot_2 := overlay.get_node("ItemLayer/OfferSlot2") as Control
	if offer_slot_1.size != Vector2(32.0, 32.0) or offer_slot_2.size != Vector2(32.0, 32.0):
		failures.append("issue27: offer slots are not 32x32")
	var hands_rest := overlay.get_node("Hands") as Sprite2D
	if hands_rest.position.y != 0.0:
		failures.append("issue27: hands do not rest at top of screen")
	if offer_slot_1.position != Vector2(20.0, 7.0) or offer_slot_2.position != Vector2(89.0, 8.0):
		failures.append("issue27: offer slots did not preserve authored positions")

	overlay._on_look_pressed()
	var hands := overlay.get_node("Hands") as Sprite2D
	if not look.visible or look.text != "take":
		failures.append("issue27: look button did not become the take button")
	if not look.disabled:
		failures.append("issue27: take button should be disabled before selecting an item")
	if look.position.y >= ignore_button.position.y:
		failures.append("issue27: take button is not above the leave button")
	if not ignore_button.visible or ignore_button.text != "leave":
		failures.append("issue27: ignore button did not become leave")
	if absf((ignore_button.position.x + ignore_button.size.x * 0.5) - 80.0) > 0.5:
		failures.append("issue27: leave button is not centered")
	var speech_after_look := overlay.get_node("SpeechBubble/SpeechLabel") as Label
	if speech_after_look.text != "Interested in one?":
		failures.append("issue27: look trigger did not show normal offer prompt")
	overlay.show_full_pockets()
	if speech_after_look.text != "YOUR POCKETS ARE FULL,\nWANNA THROW SOMETHING ?":
		failures.append("issue27: full stash trigger did not replace offer prompt")
	if hands.position.y >= 0.0:
		failures.append("issue27: hands did not start overhead entry")
	if overlay.get_node("StashLayer").visible:
		failures.append("issue27: overlay stash layer is visible")
	overlay.set_stash_items(["cons_focus", "cons_white_powder"])
	if overlay.get_node("StashLayer").get_child_count() != 0:
		failures.append("issue27: overlay built a duplicate stash")
	_check_dealer_offer_take_flow(overlay, failures)

	overlay.queue_free()

func _check_consumable_roster_32(run_store: Node, failures: Array) -> void:
	# issue #32: using each roster item sets its effect state (mirrors the TS tests).
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.lastResult = { "reels": ["eye", "pill", "vial"], "isFreeSpin": false }

	# Serum (issue #53): the picked symbol is guaranteed; blur queues for after.
	run_store.runConsumables = { "cons_focus": 1 }
	if not run_store.use_consumable("cons_focus", "vial"):
		failures.append("issue32: Serum use rejected")
	if int(run_store.guaranteeSymbolSpins) != 3 or String(run_store.guaranteeSymbolId) != "vial" \
			or int(run_store.pendingBlurSpins) != 2 or int(run_store.banBrainSpins) != 0:
		failures.append("issue53: Serum did not set guarantee/blur state")
	# Issue #97: stacking a second Serum extends the guarantee window but the
	# negative blur duration stays capped at a single item.
	run_store.runConsumables = { "cons_focus": 1 }
	run_store.use_consumable("cons_focus", "vial")
	if int(run_store.guaranteeSymbolSpins) != 6 or int(run_store.pendingBlurSpins) != 2:
		failures.append("issue97: stacked Serums stacked the blur instead of the guarantee")
	run_store.guaranteeSymbolSpins = 3
	run_store.pendingBlurSpins = 2
	# The next 3 spins contain the picked symbol, then the next 2 spins are blurry.
	run_store.neurons = 100
	for i in 3:
		var serum_spin: Variant = run_store.spin()
		run_store.set_spinning(false)
		if serum_spin == null or not (serum_spin["reels"] as Array).has("vial"):
			failures.append("issue53: Serum guaranteed spin %d did not contain the picked symbol" % [i + 1])
	if int(run_store.blurReelsSpins) != 2 or int(run_store.pendingBlurSpins) != 0:
		failures.append("issue53: blur did not queue for 2 spins after the guarantee")
	for _i in 2:
		run_store.spin()
		run_store.set_spinning(false)
	if int(run_store.blurReelsSpins) != 0:
		failures.append("issue53: blur did not clear after 2 spins")
	if bool(run_store.comboDefeatPending):
		run_store.resolve_pending_combo_defeat(false)

	# Tobacco (issue #53): pair boost + hidden reel for 2 spins.
	run_store.runConsumables = { "cons_cigarette": 1 }
	run_store.use_consumable("cons_cigarette")
	if int(run_store.pairBoostSpins) != 2 or int(run_store.pairBoostMult) != 3 or int(run_store.pairBoostHiddenReels) != 1:
		failures.append("issue32: Tobacco did not set pair-boost counters")
	run_store.lastResult = {
		"reels": ["eye", "vial", "pill"], "scoreEarned": 0, "coinsEarned": 0,
		"freeSpinsGranted": 0, "freeSpinsAfter": 0, "isJackpot": false,
		"winType": "miss", "isFreeSpin": false, "scoreMultiplier": 1.0,
	}
	run_store.copy_reel(0, 1)
	if int(run_store.lastResult["scoreEarned"]) != 30 or String(run_store.lastResult["winType"]) != "pair":
		failures.append("issue92: Tobacco pair boost did not apply to a power-made pair")
	run_store.pairBoostSpins = 0 # cleared so later spins in this check score normally

	# Potion (renamed cons_potion, issue #53): restores all powers + potionSpins.
	run_store.abilitiesUsed = ["reroll", "shift"]
	run_store.runConsumables = { "cons_potion": 1 }
	run_store.use_consumable("cons_potion")
	if not run_store.abilitiesUsed.is_empty() or int(run_store.potionSpins) != 3:
		failures.append("issue32: Potion did not reset powers / set potionSpins")
	var potion_kinds := {}
	for effect in Consumables.POTION_RANDOM_POOL:
		potion_kinds[String(effect["kind"])] = true
	if potion_kinds.has("multNextSpin") or not potion_kinds.has("restoreSpin") \
			or not potion_kinds.has("restorePower") or not potion_kinds.has("adjacentSymbol"):
		failures.append("issue92: Potion pool did not remove multiplier and add new effects")
	run_store.potionSpins = 0
	run_store.lastPotionEffect = null

	# Tea with no used abilities restores normal spins.
	run_store.abilitiesUsed = []
	run_store.freeSpinsRemaining = 0
	run_store.maxFreeSpins = 10
	var tea_neurons_before := int(run_store.neurons)
	run_store.runConsumables = { "cons_tea": 1 }
	if not run_store.use_consumable("cons_tea"):
		failures.append("issue32: Tea use rejected with no abilities")
	if int(run_store.freeSpinsRemaining) != 0:
		failures.append("issue32: Tea created fallback free-spin credits")
	if int(run_store.neurons) != tea_neurons_before + 3 * int(Economy.compute_neuron_decay(run_store.ownedUpgrades)):
		failures.append("issue32: Tea did not restore normal spins")

	# Red Pill: force flatline then triple.
	run_store.runConsumables = { "item_pill": 1 }
	run_store.use_consumable("item_pill")
	if int(run_store.forceFlatlineSpins) != 1 or int(run_store.guaranteedTripleSpins) != 1:
		failures.append("issue32: Red Pill did not set flatline/triple counters")

	# Pill spin 1 forces all flatlines; spin 2 forces a non-flatline triple.
	run_store.neurons = 100
	var r1: Variant = run_store.spin()
	run_store.set_spinning(false)
	if r1 == null or String(r1["reels"][0]) != "flatline" or String(r1["reels"][1]) != "flatline":
		failures.append("issue32: Red Pill first spin was not an all-flatline result")
	var r2: Variant = run_store.spin()
	run_store.set_spinning(false)
	if r2 == null or String(r2["reels"][0]) != String(r2["reels"][1]) or String(r2["reels"][0]) == "flatline":
		failures.append("issue32: Red Pill second spin was not a non-flatline triple")

	# Cocktail boost no longer queues compulsion; Energy Drink owns the forced spin.
	run_store.runConsumables = { "item_cocktail": 1 }
	run_store.use_consumable("item_cocktail")
	if int(run_store.cocktailBoostSpins) != 2 or int(run_store.pendingCompulsiveSpinSkips) != 0:
		failures.append("consumables: Cocktail still queued compulsion")
	run_store.betMultiplier = 3
	run_store.neurons = 100
	run_store.freeSpinsRemaining = 0
	run_store.lastResult = { "reels": ["eye", "eye", "vial"] }
	run_store.lockedReels = [true, true, true]
	run_store.lockedReelSpins = [2, 2, 2]
	var cocktail_spin: Variant = run_store.spin()
	run_store.set_spinning(false)
	if cocktail_spin == null:
		failures.append("issue92: Cocktail test spin did not resolve")
	else:
		if int(cocktail_spin.get("cocktailBonus", 0)) != 36:
			failures.append("issue92: Cocktail bonus should use 1-6 rarity scaled by x3")
		if int(cocktail_spin.get("cocktailPenalty", 0)) != 5:
			failures.append("issue92: Cocktail pair/triple penalty should be 15%% rounded")
		if int(cocktail_spin["scoreEarned"]) != 61 or int(cocktail_spin["coinsEarned"]) != 61:
			failures.append("issue92: Cocktail final score/coins wrong: %s" % str(cocktail_spin))
	run_store.cocktailBoostSpins = 0
	run_store.cocktailPairTriplePenalty = 0.0
	run_store.lockedReels = [false, false, false]
	run_store.freeSpinsRemaining = 0
	run_store.compulsiveSpinSkips = 0
	run_store.pendingCompulsiveSpinSkips = 0
	run_store.decaySkips = 0
	run_store.forcedRandomBetSpins = 0
	run_store.runConsumables = { "item_energy_drink": 1 }
	run_store.use_consumable("item_energy_drink")
	if int(run_store.decaySkips) != 2 or int(run_store.pendingCompulsiveSpinSkips) != 1:
		failures.append("consumables: Energy Drink did not queue compulsion")
	run_store.neurons = 100
	run_store.spin()
	run_store.set_spinning(false)
	run_store.spin()
	run_store.set_spinning(false)
	if int(run_store.compulsiveSpinSkips) != 1 or int(run_store.pendingCompulsiveSpinSkips) != 0:
		failures.append("consumables: Energy Drink compulsion did not unlock after no-decay spins")
	var queued_spin_count := int(run_store.spinCount)
	var queued_neurons := int(run_store.neurons)
	run_store.runConsumables = { "item_water": 1 }
	if run_store.spin() != null:
		failures.append("issue61: manual spin was allowed while compulsion was queued")
	if int(run_store.spinCount) != queued_spin_count or int(run_store.neurons) != queued_neurons or bool(run_store.isSpinning):
		failures.append("issue61: blocked manual spin changed run state")
	# Issue #155: the multiplier is no longer a player toggle — nothing to poke here.
	if run_store.reroll_reel(0):
		failures.append("issue61: power was usable while compulsion was queued")
	if run_store.use_consumable("item_water") or int(run_store.runConsumables.get("item_water", 0)) != 1:
		failures.append("issue61: stash item was usable while compulsion was queued")
	var forced_spin: Variant = run_store.spin(true)
	if forced_spin == null:
		failures.append("issue61: forced compulsion spin did not start")
	else:
		run_store.set_spinning(false)

	# Issue #97: stacking two Energy Drinks at once stacks the free-spin rush
	# (decaySkips) but caps the negative compulsion at a single forced spin.
	run_store.compulsiveSpinSkips = 0
	run_store.pendingCompulsiveSpinSkips = 0
	run_store.decaySkips = 0
	run_store.forcedRandomBetSpins = 0
	run_store.betMultiplier = 1
	run_store.runConsumables = { "item_energy_drink": 2 }
	run_store.use_consumable("item_energy_drink")
	run_store.use_consumable("item_energy_drink")
	if int(run_store.decaySkips) != 4 or int(run_store.pendingCompulsiveSpinSkips) != 1:
		failures.append("issue97: stacked Energy Drinks stacked the compulsion instead of the rush")
	run_store.decaySkips = 0
	run_store.forcedRandomBetSpins = 0
	run_store.pendingCompulsiveSpinSkips = 0

	# White Powder copy keeps other consumables and neurons intact after the copy.
	run_store.runConsumables = { "cons_white_powder": 0, "item_water": 1 }
	run_store.neurons = 80
	run_store.lastResult = {
		"reels": ["brain", "eye", "vial"], "scoreEarned": 0, "coinsEarned": 0,
		"neuronsAfter": 80, "freeSpinsAfter": 0, "freeSpinsGranted": 0,
		"isJackpot": false, "winType": "loss", "isFreeSpin": false,
		"scoreMultiplier": 1.0,
	}
	run_store.copy_reel(0, 2)
	if int(run_store.neurons) != 80 or int(run_store.runConsumables.get("item_water", 0)) != 1:
		failures.append("consumables: White Powder copy still removed a penalty")

	run_store.reset_run_state()

func _check_start_menu_button_style(button: Button, expected_color: Color, label: String,
		failures: Array, expect_small: bool = false) -> void:
	if button == null:
		failures.append("%s: button is missing" % label)
		return
	var style := button.get_theme_stylebox("normal") as StyleBoxTexture
	if style == null:
		failures.append("%s: button is not using a start-menu StyleBoxTexture" % label)
		return
	if style.texture == null:
		failures.append("%s: start-menu plate texture is missing" % label)
	var resolved_color: Color = button.get_meta(&"_start_menu_button_color", Color.TRANSPARENT)
	if not resolved_color.is_equal_approx(expected_color):
		failures.append("%s: start-menu plate color is %s, expected %s" % [
			label, str(resolved_color), str(expected_color)])
	if style.texture_margin_left < 1.0 or style.texture_margin_top < 1.0:
		failures.append("%s: start-menu plate is not configured as a nine-slice" % label)
	if expect_small:
		var small_asset := String(button.get_meta(&"_small_neon_button_asset", ""))
		if not small_asset.begins_with("ui/neon_small_"):
			failures.append("%s: compact control is not using neon_small button art" % label)
		if style.content_margin_bottom <= style.content_margin_top:
			failures.append("%s: compact label is not visually centered in its plate" % label)

func _check_start_menu_press_feedback(button: Button, label: String, failures: Array) -> void:
	if button == null:
		failures.append("%s: button is missing for press feedback" % label)
		return
	if not button.has_meta(&"_start_menu_press_feedback"):
		failures.append("%s: start-menu button is missing press feedback" % label)
		return
	var resting_scale := button.scale
	button.button_down.emit()
	if button.scale == resting_scale:
		failures.append("%s: press feedback did not squash the button" % label)
	button.button_up.emit()

func _check_settings_neon(settings: Node, failures: Array) -> void:
	var panel := settings.get_node_or_null("Panel") as PanelContainer
	var panel_style := panel.get_theme_stylebox("panel") as StyleBoxFlat \
		if panel != null else null
	if panel_style == null or not panel_style.border_color.is_equal_approx(Color(0.42, 1.0, 0.95)) \
			or panel_style.shadow_size < 1:
		failures.append("settings: panel is missing the neon contour style")
	var slider := settings.get_node_or_null("Panel/Rows/VolumeRow/VolumeSlider") as HSlider
	var slider_style := slider.get_theme_stylebox("slider") as StyleBoxFlat \
		if slider != null else null
	if slider_style == null or not slider_style.border_color.is_equal_approx(Color(1.0, 0.5, 0.7)):
		failures.append("settings: volume slider is missing the neon track")
	var mute := settings.get_node_or_null("Panel/Rows/MuteCheck") as CheckBox
	_check_start_menu_button_style(mute, Assets.START_MENU_BUTTON_PINK, "settings: MUTE", failures)
	_check_start_menu_press_feedback(mute, "settings: MUTE", failures)
	var back := settings.get_node_or_null("Panel/Rows/BackButton") as Button
	_check_start_menu_button_style(back, Assets.START_MENU_BUTTON_CYAN, "settings: BACK", failures)
	_check_start_menu_press_feedback(back, "settings: BACK", failures)

## Issue #84: the machine button is misclick-guarded by a YES/CANCEL confirm modal,
## and the LAB button glows (looping self_modulate pulse) so it reads as a button.
func _check_start_confirm_and_lab_glow_84(dealer: Node, failures: Array) -> void:
	# Lab glow is armed and looping.
	if dealer._lab_glow_tween == null or not dealer._lab_glow_tween.is_valid():
		failures.append("issue84: LAB button glow tween is not running")
	elif not dealer._lab_glow_tween.is_running():
		failures.append("issue84: LAB button glow tween is not looping")
	var lab_glow := dealer.get_node_or_null("LabButtonGlowArt") as Sprite2D
	if lab_glow == null:
		failures.append("issue84: LAB sign-only glow layer is missing")
	elif dealer._lab_button_sprite.self_modulate != Color.WHITE:
		failures.append("issue84: LAB glow still modulates the label layer")
	var lab_button := dealer.get_node_or_null("LabButton") as Button
	if lab_button != null and lab_glow != null:
		lab_button.button_down.emit()
		if lab_glow.position != Vector2(62.0, 12.0):
			failures.append("issue84: LAB glow did not follow the pressed sign frame")
		lab_button.button_up.emit()
		if lab_glow.position != Vector2(59.0, 0.0):
			failures.append("issue84: LAB glow did not restore the normal sign frame")

	# The machine button is wired to the confirm guard, not straight to _start_run.
	var start_button := dealer.get_node_or_null("StartButton") as Button
	if start_button == null:
		failures.append("issue84: machine (StartButton) missing for confirm wiring")
	else:
		if start_button.pressed.is_connected(Callable(dealer, "_start_run")):
			failures.append("issue84: machine button still starts the run without confirmation")
		if not start_button.pressed.is_connected(Callable(dealer, "_confirm_start_run")):
			failures.append("issue84: machine button is not gated behind the confirm modal")

	# Pressing the machine button shows the modal instead of starting the run.
	dealer._confirm_start_run()
	var modal := dealer.get_node_or_null("StartConfirmModal") as Control
	if modal == null or not modal.visible:
		failures.append("issue84: machine button did not raise the start-confirm modal")
	else:
		var enter_button := modal.get_node_or_null("Panel/Buttons/EnterButton") as Button
		var cancel_button := modal.get_node_or_null("Panel/Buttons/CancelButton") as Button
		if enter_button == null or cancel_button == null:
			failures.append("issue84: confirm modal missing ENTER/CANCEL buttons")
		else:
			_check_start_menu_button_style(cancel_button, Assets.START_MENU_BUTTON_PINK,
				"issue84: CANCEL", failures, true)
			_check_start_menu_button_style(enter_button, Assets.START_MENU_BUTTON_CYAN,
				"issue84: ENTER", failures, true)
			_check_start_menu_press_feedback(cancel_button, "issue84: CANCEL", failures)
			_check_start_menu_press_feedback(enter_button, "issue84: ENTER", failures)
		# Cancelling dismisses the modal (and does not start the run).
		dealer._on_start_cancelled()
		if modal.visible:
			failures.append("issue84: CANCEL did not dismiss the start-confirm modal")

func _check_dealer_scene_revamp_55(dealer: Node, failures: Array) -> void:
	_check_dealer_shop_light_art(dealer, failures)
	# Exported builds (APK) only ship res:// — the runtime asset tree
	# fallback does not exist on device, so shipped art MUST resolve as a resource.
	for rel in ["dealer_scene_LAB_BUTTON.png", "dealer_scene_machine_BUTTON.png"]:
		if not ResourceLoader.exists("res://assets/images/" + String(rel)):
			failures.append("issue55: %s not in godot/assets/images — missing from exported builds (APK)" % rel)
	var lab_button := dealer.get_node_or_null("LabButton") as Button
	var lab_art := dealer.get_node_or_null("LabButtonArt") as Sprite2D
	if lab_button == null or lab_art == null:
		failures.append("issue55: dealer LAB button/art pair is missing")
	else:
		if lab_button.text != "":
			failures.append("issue55: lab hit button should render no text over the art")
		if lab_art.hframes != 2:
			failures.append("issue55: lab button art is not a 2-frame sheet")
		if lab_art.position != Vector2.ZERO:
			failures.append("issue55: lab art lost its dealer-canvas-relative position")
		lab_button.button_down.emit()
		if lab_art.frame != 1:
			failures.append("issue55: lab press did not switch to the pressed frame")
		lab_button.button_up.emit()
		if lab_art.frame != 0:
			failures.append("issue55: lab release did not restore the default frame")
	var start_button := dealer.get_node_or_null("StartButton") as Button
	var machine_art := dealer.get_node_or_null("MachineButtonArt") as Sprite2D
	if start_button == null or machine_art == null:
		failures.append("issue55: dealer machine button/art pair is missing")
	else:
		if machine_art.hframes != 2:
			failures.append("issue55: machine button art is not a 2-frame sheet")
		if machine_art.position != Vector2.ZERO:
			failures.append("issue55: machine art lost its dealer-canvas-relative position")
		if start_button.position.x < 100.0:
			failures.append("issue55: machine hit button is not over the top-right art")
		start_button.button_down.emit()
		if machine_art.frame != 1:
			failures.append("issue55: machine press did not switch to the pressed frame")
		start_button.button_up.emit()
		if machine_art.frame != 0:
			failures.append("issue55: machine release did not restore the default frame")
	if dealer.get_node_or_null("InstructionBubble") != null:
		failures.append("issue55: dealer text bubble should be removed")
	if _find_label_with_text(dealer, "DRAG TO BUY") != null:
		failures.append("issue55: 'DRAG TO BUY' text should be removed")
	var message := dealer.get_node_or_null("Message") as Label
	if message == null:
		failures.append("issue55: dealer Message label is missing")
	else:
		if message.get_theme_constant("outline_size") < 1:
			failures.append("issue55: dealer message has no black outline")
		if message.get_theme_color("font_outline_color") != Color.BLACK:
			failures.append("issue55: dealer message outline is not black")
		# Just above the dealer's head (y~131) and inside the canvas.
		if message.position.y < 100.0 or message.position.y + message.size.y > 131.0:
			failures.append("issue55: dealer message is not just above the dealer: %s" % message.position)
	if dealer.get_node_or_null("OfferSlot6") != null:
		failures.append("issue55: the 1-Lucidity placeholder offer slot should be gone")

func _check_dealer_shop_light_art(dealer: Node, failures: Array) -> void:
	var expected_sizes: Dictionary = {
		"dealer_shop/dealer_shop_bg_x8.png": Vector2i(1280, 2560),
		"dealer_shop/dealer_shop_counter_base_x8.png": Vector2i(2560, 2560),
		"dealer_shop/dealer_shop_LAB_BUTTON_x8.png": Vector2i(2560, 2560),
		"dealer_shop/dealer_shop_machine_BUTTON_x8.png": Vector2i(2560, 2560),
		"dealer_shop/dealer_shop_reroll_BUTTON_x8.png": Vector2i(2560, 2560),
	}
	for rel in expected_sizes:
		var path := "res://assets/images/" + String(rel)
		if not ResourceLoader.exists(path):
			failures.append("dealer shop: missing scaled art %s" % rel)
			continue
		var texture := load(path) as Texture2D
		var expected: Vector2i = expected_sizes[rel]
		if texture == null or Vector2i(texture.get_width(), texture.get_height()) != expected:
			failures.append("dealer shop: %s is not an NN 8x sheet at %s" % [rel, expected])
	var counter_base := load("res://assets/images/dealer_shop/dealer_shop_counter_base.png") as Texture2D
	var counter_image := counter_base.get_image() if counter_base != null else null
	if counter_image == null:
		failures.append("dealer shop: counter-only base art is missing")
	else:
		for button_filename in [
			"dealer_shop_LAB_BUTTON.png",
			"dealer_shop_machine_BUTTON.png",
			"dealer_shop_reroll_BUTTON.png",
		]:
			var button_texture := load("res://assets/images/dealer_shop/" + button_filename) as Texture2D
			var button_image := button_texture.get_image() if button_texture != null else null
			var overlaps := false
			if button_image != null:
				for y in counter_image.get_height():
					for x in counter_image.get_width():
						if counter_image.get_pixel(x, y).a > 0.0 \
								and button_image.get_pixel(x, y).a > 0.0:
							overlaps = true
							break
					if overlaps:
						break
			if overlaps:
				failures.append("dealer shop: counter base still contains %s" % button_filename)

	var background := dealer.get_node_or_null("Background") as Sprite2D
	if background == null or background.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		failures.append("dealer shop: background is not nearest-neighbor filtered")
	var counter := dealer.get_node_or_null("Counter") as Sprite2D
	if counter == null:
		failures.append("dealer shop: counter node is missing")
	elif counter.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST \
			or counter.hframes != 2 or counter.scale != Vector2(0.125, 0.125):
		failures.append("dealer shop: counter is not a nearest-neighbor 2-frame 8x sheet")
	for art_name in ["LabButtonArt", "MachineButtonArt", "RerollButtonArt"]:
		var art := dealer.get_node_or_null(art_name) as Sprite2D
		if art == null or art.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST \
				or art.hframes != 2 or art.scale != Vector2(0.125, 0.125):
			failures.append("dealer shop: %s is not a nearest-neighbor 2-frame 8x sheet" % art_name)

# Issue #117 (repriced): the dealer-scene painting rerolls the current offer for
# an escalating Lucidity price (5, 10, 15, …) in BOTH dealer phases. Covers the
# escalating cost, insufficient funds, pre-run availability (wallet-paid), the
# two-consumable offer maximum, the immediate price/affordability refresh, and the
# price reset at the start of a new dealer/run cycle.
func _check_painting_reroll_117(failures: Array) -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	var meta_store: Node = get_root().get_node("MetaStateStore")
	if not ResourceLoader.exists("res://assets/images/dealer_scene_reroll_BUTTON.png"):
		failures.append("issue117: reroll painting art not in godot/assets/images — missing from exported builds (APK)")

	var prev_phase := String(run_store.runPhase)
	var prev_pending := bool(run_store.dealerPending)
	var prev_offers: Variant = run_store.dealerOfferIds
	var prev_count := int(run_store.dealerRerollCount)
	var prev_prerun_offers: Variant = run_store.prerunOfferIds
	var prev_coins := int(run_store.lucidityCoins)
	var prev_wallet := int(meta_store.lucidityWallet)

	# Store rules: invalid outside a pending visit; 5L then 10L; funds gate.
	run_store.runPhase = "running"
	run_store.dealerPending = false
	run_store.dealerOfferIds = null
	run_store.dealerRerollCount = 0
	run_store.lucidityCoins = 100
	if run_store.reroll_dealer_offer():
		failures.append("issue117: reroll succeeded with no pending dealer visit")
	run_store.dealerPending = true
	run_store.dealerOfferIds = ["item_water", "item_pill"]
	if int(run_store.dealer_reroll_price()) != 5:
		failures.append("issue117: first reroll price is not 5L")
	if not run_store.reroll_dealer_offer():
		failures.append("issue117: reroll refused a funded pending visit")
	else:
		var offers := run_store.dealerOfferIds as Array
		if offers.size() != 2 or (offers.has("item_water") and offers.has("item_pill")):
			failures.append("issue117: reroll did not change the offer pair: %s" % str(offers))
		if int(run_store.lucidityCoins) != 95:
			failures.append("issue117: first reroll did not charge 5L (coins=%d)" % int(run_store.lucidityCoins))
		if int(run_store.dealer_reroll_price()) != 10:
			failures.append("issue117: price did not escalate to 10L after one reroll")
		if not run_store.reroll_dealer_offer():
			failures.append("issue117: second reroll refused despite sufficient funds")
		elif int(run_store.lucidityCoins) != 85:
			failures.append("issue117: second reroll did not charge 10L (coins=%d)" % int(run_store.lucidityCoins))
		run_store.lucidityCoins = int(run_store.dealer_reroll_price()) - 1
		if run_store.reroll_dealer_offer():
			failures.append("issue117: reroll succeeded without enough Lucidity")

	# In-run UI: affordable painting glows, shows the live price, and updates the
	# price + affordability immediately after a reroll.
	run_store.lucidityCoins = 100
	run_store.dealerRerollCount = 0
	var dealer := (load("res://scenes/dealer_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(dealer)
	var button := dealer.get_node_or_null("RerollButton") as Button
	var art := dealer.get_node_or_null("RerollButtonArt") as Sprite2D
	var price_label := dealer.get_node_or_null("RerollPriceTag/Price") as Label
	if button == null or art == null or price_label == null:
		failures.append("issue117: dealer painting button/art/price-tag is missing")
	else:
		if button.disabled:
			failures.append("issue117: live painting is disabled")
		if button.focus_mode != Control.FOCUS_ALL:
			failures.append("issue117: live painting is not keyboard/controller focusable")
		if dealer._reroll_glow_tween == null or not dealer._reroll_glow_tween.is_valid():
			failures.append("issue117: live painting glow tween is not running")
		if art.hframes != 2:
			failures.append("issue117: painting art is not a 2-frame sheet")
		if price_label.text != "5":
			failures.append("issue117: painting price tag does not read 5 (got %s)" % price_label.text)
		button.button_down.emit()
		if art.frame != 1:
			failures.append("issue117: painting press did not switch to the pressed frame")
		button.button_up.emit()
		# Activation through the scene: reroll fires, coins drop, price tag jumps.
		var before := (run_store.dealerOfferIds as Array).duplicate()
		dealer._on_painting_pressed()
		var after := run_store.dealerOfferIds as Array
		if after.has(before[0]) and after.has(before[1]):
			failures.append("issue117: painting press did not reroll the offer")
		if int(run_store.lucidityCoins) != 95:
			failures.append("issue117: painting press did not charge 5L")
		if price_label.text != "10":
			failures.append("issue117: price tag did not update to 10 right after the reroll")
		var message := dealer.get_node_or_null("Message") as Label
		if message == null or message.text == "":
			failures.append("issue117: painting reroll gave no feedback message")
		# Broke: glow off, price reads as warning, press refuses with feedback.
		run_store.lucidityCoins = 3
		dealer._refresh_painting_state()
		if dealer._reroll_glow_tween != null and dealer._reroll_glow_tween.is_valid():
			failures.append("issue117: unaffordable painting still glows")
		if price_label.get_theme_color("font_color") != dealer.PRICE_WARN_COLOR:
			failures.append("issue117: unaffordable price tag is not the warning colour")
		var held := (run_store.dealerOfferIds as Array).duplicate()
		dealer._on_painting_pressed()
		if run_store.dealerOfferIds != held:
			failures.append("issue117: broke reroll still changed the offer")
		if message != null and message.text != dealer.PAINTING_NO_CREDITS_MESSAGE:
			failures.append("issue117: broke reroll gave no NOT ENOUGH CREDITS feedback")
	dealer.queue_free()

	# Pre-run shop: the painting is live there too, priced from the wallet, and a
	# fresh cycle's offer (two consumables max) resets the escalated price.
	run_store.runPhase = "idle"
	run_store.dealerPending = false
	run_store.dealerOfferIds = null
	run_store.prerunOfferIds = null
	run_store.dealerRerollCount = 7 # stale escalation from a previous cycle
	meta_store.lucidityWallet = 50
	var shop := (load("res://scenes/dealer_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(shop)
	var shop_offers: Array = shop._offer_ids()
	if shop_offers.size() != 2:
		failures.append("issue117: pre-run offer must be exactly two consumables: %s" % str(shop_offers))
	if int(run_store.dealerRerollCount) != 0 or int(run_store.dealer_reroll_price()) != 5:
		failures.append("issue117: fresh pre-run offer did not reset the reroll price to 5L")
	# Slots beyond the two-item offer are empty (the far-right slot belongs to the
	# Chip Augment): their authored price tags must hide.
	for i in range(shop_offers.size() + 1, 5):
		var empty_slot := shop.get_node_or_null("OfferSlot%d" % i) as Control
		var empty_tag := empty_slot.get_node_or_null("PriceTag") as Control if empty_slot != null else null
		if empty_tag != null and empty_tag.visible:
			failures.append("issue117: empty OfferSlot%d still shows a price tag" % i)
	var shop_button := shop.get_node_or_null("RerollButton") as Button
	if shop_button == null or not shop_button.visible or shop_button.disabled:
		failures.append("issue117: pre-run painting is not a live control")
	elif shop._reroll_glow_tween == null or not shop._reroll_glow_tween.is_valid():
		failures.append("issue117: pre-run painting glow tween is not running")
	else:
		var shop_before := (run_store.prerunOfferIds as Array).duplicate()
		shop._on_painting_pressed()
		var shop_after := run_store.prerunOfferIds as Array
		if shop_after.has(shop_before[0]) and shop_after.has(shop_before[1]):
			failures.append("issue117: pre-run reroll did not change the shop pair")
		if int(meta_store.lucidityWallet) != 45:
			failures.append("issue117: pre-run reroll did not charge the wallet 5L (wallet=%d)" % int(meta_store.lucidityWallet))
		if int(run_store.dealer_reroll_price()) != 10:
			failures.append("issue117: pre-run price did not escalate to 10L")
		if shop._offer_ids().size() != 2:
			failures.append("issue117: pre-run offer grew past two consumables after reroll")
		# Insufficient wallet: refuse and leave the pair and wallet untouched.
		meta_store.lucidityWallet = 2
		shop._refresh_painting_state()
		var shop_held := (run_store.prerunOfferIds as Array).duplicate()
		shop._on_painting_pressed()
		if run_store.prerunOfferIds != shop_held or int(meta_store.lucidityWallet) != 2:
			failures.append("issue117: broke pre-run reroll changed state")
	shop.queue_free()

	# New run => new cycle: starting a run clears the shop offer and price ladder.
	# Exercised on a detached store instance so ambient smoke-test state survives.
	var fresh_store: Node = (load("res://autoload/run_state_store.gd") as GDScript).new()
	fresh_store.dealerRerollCount = 4
	fresh_store.prerunOfferIds = ["cons_tea", "cons_potion"]
	fresh_store.start_new_run([], {}, false)
	if int(fresh_store.dealerRerollCount) != 0 or fresh_store.prerunOfferIds != null:
		failures.append("issue117: starting a run did not reset the reroll cycle state")
	fresh_store.free()

	run_store.runPhase = prev_phase
	run_store.dealerPending = prev_pending
	run_store.dealerOfferIds = prev_offers
	run_store.dealerRerollCount = prev_count
	run_store.prerunOfferIds = prev_prerun_offers
	run_store.lucidityCoins = prev_coins
	meta_store.lucidityWallet = prev_wallet
	meta_store.save_state() # re-persist the restored wallet (rerolls saved to disk)

# Chip Augments (rules/chip_augments.gd): one dedicated dealer offer per visit,
# separate from the item/consumable offer. Covers offer rolling and eligibility,
# reroll isolation, stock limits + pool exhaustion, discount stacking + rounding,
# symbol levels (selection, cancellation, level-9 cap), Extra Spins, expanded
# three-item offers, pair/triple choices, run-start persistence and cycle reset.
func _check_chip_augments(failures: Array) -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var prev_phase := String(run_store.runPhase)
	var prev_pending := bool(run_store.dealerPending)
	var prev_offers: Variant = run_store.dealerOfferIds
	var prev_reroll_count := int(run_store.dealerRerollCount)
	var prev_prerun: Variant = run_store.prerunOfferIds
	var prev_coins := int(run_store.lucidityCoins)
	var prev_wallet := int(meta_store.lucidityWallet)
	var prev_augs: Dictionary = (run_store.chipAugmentsPurchased as Dictionary).duplicate(true)
	var prev_aug_offer := String(run_store.dealerAugmentOfferId)
	var prev_sym: Dictionary = (run_store.symbolAugmentLevels as Dictionary).duplicate(true)
	var prev_pt := String(run_store.pairTripleAugmentChoice)
	var prev_weights: Dictionary = (run_store.oddsWeightOverrides as Dictionary).duplicate(true)
	var prev_bonuses: Dictionary = (run_store.symbolRewardBonuses as Dictionary).duplicate(true)
	var prev_neurons := int(run_store.neurons)
	var prev_owned: Array = (run_store.ownedUpgrades as Array).duplicate()

	# Fresh pre-run cycle: stale augments expire, exactly one pool offer rolls.
	run_store.runPhase = "idle"
	run_store.dealerPending = false
	run_store.dealerOfferIds = null
	run_store.prerunOfferIds = null
	run_store.chipAugmentsPurchased = { "aug_extra_spins": 2 } # stale, must clear
	run_store.pairTripleAugmentChoice = "pair"
	run_store.symbolAugmentLevels = { "eye": 1 }
	meta_store.lucidityWallet = 1000
	run_store.ensure_prerun_offer(7)
	if not (run_store.chipAugmentsPurchased as Dictionary).is_empty() \
			or String(run_store.pairTripleAugmentChoice) != "" \
			or not (run_store.symbolAugmentLevels as Dictionary).is_empty():
		failures.append("augments: fresh cycle did not expire the previous cycle's augments")
	var offer_id := String(run_store.dealerAugmentOfferId)
	if offer_id == "" or not ChipAugments.ids().has(offer_id):
		failures.append("augments: fresh visit did not roll one augment offer from the pool")

	# Painting rerolls (both phases) never swap the augment offer.
	run_store.reroll_prerun_offer(1234)
	if String(run_store.dealerAugmentOfferId) != offer_id:
		failures.append("augments: pre-run reroll changed the augment offer")
	run_store.runPhase = "running"
	run_store.dealerPending = true
	run_store.dealerOfferIds = ["item_water", "item_pill"]
	run_store.lucidityCoins = 500
	run_store.reroll_dealer_offer()
	if String(run_store.dealerAugmentOfferId) != offer_id:
		failures.append("augments: in-run reroll changed the augment offer")

	# Discount stacking + project rounding (floor(x + 0.5)).
	run_store.chipAugmentsPurchased = {}
	if int(run_store.consumable_price("cons_cigarette")) != 20:
		failures.append("augments: undiscounted consumable price wrong")
	run_store.dealerAugmentOfferId = "aug_consumable_discount"
	if not run_store.purchase_chip_augment("aug_consumable_discount"):
		failures.append("augments: consumable discount purchase refused")
	run_store.dealerAugmentOfferId = "aug_consumable_discount"
	run_store.purchase_chip_augment("aug_consumable_discount")
	if int(run_store.consumable_price("cons_cigarette")) != 16:
		failures.append("augments: two consumable discounts should stack 20 -> 16")
	if int((run_store.chipAugmentsPurchased as Dictionary).get("aug_consumable_discount", 0)) != 2:
		failures.append("augments: consumable discount stock not tracked")
	run_store.dealerAugmentOfferId = "aug_chip_discount"
	run_store.purchase_chip_augment("aug_chip_discount")
	if int(run_store.chip_augment_price("aug_extra_spins")) != 32: # 35 * 0.9 = 31.5 -> 32
		failures.append("augments: one chip discount should price 35 -> 32 (round half up)")
	run_store.dealerAugmentOfferId = "aug_chip_discount"
	run_store.purchase_chip_augment("aug_chip_discount")
	if int(run_store.chip_augment_price("aug_extra_spins")) != 28:
		failures.append("augments: two chip discounts should price 35 -> 28")

	# Stock limit: a maxed augment can't be offered or bought again.
	run_store.dealerAugmentOfferId = "aug_chip_discount"
	var coins_hold := int(run_store.lucidityCoins)
	if run_store.purchase_chip_augment("aug_chip_discount"):
		failures.append("augments: purchase exceeded the stock limit")
	if int(run_store.lucidityCoins) != coins_hold:
		failures.append("augments: refused over-stock purchase still charged")
	if ChipAugments.eligible_ids(run_store.chipAugmentsPurchased).has("aug_chip_discount"):
		failures.append("augments: maxed augment still in the eligible pool")

	# Insufficient funds: nothing charged, no stock consumed.
	run_store.lucidityCoins = 1
	run_store.dealerAugmentOfferId = "aug_extra_spins"
	if run_store.purchase_chip_augment("aug_extra_spins"):
		failures.append("augments: purchase succeeded without funds")
	if int(run_store.lucidityCoins) != 1 \
			or int((run_store.chipAugmentsPurchased as Dictionary).get("aug_extra_spins", 0)) != 0:
		failures.append("augments: failed purchase charged or consumed stock")

	# Extra Spins: both copies, +3 spins each through the neuron decay model.
	run_store.lucidityCoins = 500
	run_store.ownedUpgrades = []
	var decay := maxi(1, Economy.compute_neuron_decay([]))
	var neurons_before := int(run_store.neurons)
	run_store.dealerAugmentOfferId = "aug_extra_spins"
	run_store.purchase_chip_augment("aug_extra_spins")
	run_store.dealerAugmentOfferId = "aug_extra_spins"
	run_store.purchase_chip_augment("aug_extra_spins")
	if int(run_store.neurons) != neurons_before + 6 * decay:
		failures.append("augments: two Extra Spins should add 6 spins' worth of neurons")

	# Symbol Level: needs a selection, raises the weight, honours the level-9 cap.
	run_store.symbolAugmentLevels = {}
	run_store.oddsWeightOverrides = {}
	run_store.symbolRewardBonuses = {}
	run_store.dealerAugmentOfferId = "aug_symbol_level"
	if run_store.purchase_chip_augment("aug_symbol_level"):
		failures.append("augments: symbol level purchase went through without a selection")
	run_store.dealerAugmentOfferId = "aug_symbol_level"
	if not run_store.purchase_chip_augment("aug_symbol_level", "eye"):
		failures.append("augments: symbol level purchase refused a valid symbol")
	if float((run_store.oddsWeightOverrides as Dictionary).get("eye", 0.0)) \
			!= float(run_store.probability_increase_per_upgrade):
		failures.append("augments: symbol augment did not raise the chosen symbol's weight")
	# Level-9 cap: crossing 8 and 9 each add the max-level reward bonus; a tenth
	# level is refused without charging. Pick a symbol whose persisted odds level
	# leaves room, so a real save on this machine can't skew the test.
	var cap_sym := ""
	for s in ["vial", "syringe", "pill", "eye", "brain"]:
		if int(meta_store.odds_upgrade_level(s)) <= 7:
			cap_sym = s
			break
	if cap_sym == "":
		failures.append("augments: no symbol below level 8 available for the cap test")
	else:
		var meta_level := int(meta_store.odds_upgrade_level(cap_sym))
		run_store.symbolAugmentLevels = { cap_sym: 7 - meta_level } # effective level 7
		run_store.symbolRewardBonuses = {}
		run_store.chipAugmentsPurchased = (run_store.chipAugmentsPurchased as Dictionary).duplicate(true)
		run_store.chipAugmentsPurchased["aug_symbol_level"] = 0
		run_store.dealerAugmentOfferId = "aug_symbol_level"
		run_store.purchase_chip_augment("aug_symbol_level", cap_sym) # -> level 8
		run_store.chipAugmentsPurchased["aug_symbol_level"] = 0
		run_store.dealerAugmentOfferId = "aug_symbol_level"
		run_store.purchase_chip_augment("aug_symbol_level", cap_sym) # -> level 9
		var cap_bonus := float((run_store.symbolRewardBonuses as Dictionary).get(cap_sym, 0.0))
		if not is_equal_approx(cap_bonus, 2.0 * float(run_store.odds_max_level_reward_bonus)):
			failures.append("augments: levels 8 and 9 should each add the max-level reward bonus")
		run_store.chipAugmentsPurchased["aug_symbol_level"] = 0
		run_store.dealerAugmentOfferId = "aug_symbol_level"
		var coins_at_cap := int(run_store.lucidityCoins)
		if run_store.purchase_chip_augment("aug_symbol_level", cap_sym):
			failures.append("augments: symbol pushed past level 9")
		if int(run_store.lucidityCoins) != coins_at_cap:
			failures.append("augments: refused level-10 purchase still charged")

	# Expanded Selection: visits generate three consumables; rerolls keep three.
	run_store.chipAugmentsPurchased = {}
	run_store.dealerAugmentOfferId = "aug_offer_expand"
	run_store.purchase_chip_augment("aug_offer_expand")
	if int(run_store.dealer_offer_count()) != 3:
		failures.append("augments: expanded selection did not raise the offer count")
	run_store.dealerOfferIds = ["item_water", "item_pill"]
	run_store.reroll_dealer_offer()
	if (run_store.dealerOfferIds as Array).size() != 3:
		failures.append("augments: in-run reroll did not generate three items")
	run_store.runPhase = "idle"
	run_store.reroll_prerun_offer(77)
	if (run_store.prerunOfferIds as Array).size() != 3:
		failures.append("augments: pre-run reroll did not generate three consumables")

	# Pair/Triple Specialist: choice validated, stored, and locked; bonus maths.
	run_store.runPhase = "running"
	run_store.dealerAugmentOfferId = "aug_pair_triple"
	if run_store.purchase_chip_augment("aug_pair_triple", "banana"):
		failures.append("augments: specialist accepted an invalid choice")
	run_store.dealerAugmentOfferId = "aug_pair_triple"
	run_store.purchase_chip_augment("aug_pair_triple", "triple")
	if String(run_store.pairTripleAugmentChoice) != "triple":
		failures.append("augments: specialist triple choice not stored")
	run_store.pairTripleAugmentChoice = ""
	run_store.chipAugmentsPurchased = {}
	run_store.dealerAugmentOfferId = "aug_pair_triple"
	run_store.purchase_chip_augment("aug_pair_triple", "pair")
	if String(run_store.pairTripleAugmentChoice) != "pair":
		failures.append("augments: specialist pair choice not stored")
	if ChipAugments.specialist_bonus(100, "triple", "triple") != 25 \
			or ChipAugments.specialist_bonus(100, "pair", "triple") != 0 \
			or ChipAugments.specialist_bonus(10, "pair", "pair") != 3: # 2.5 rounds up
		failures.append("augments: specialist bonus arithmetic wrong")

	# Pool exhaustion: everything at stock limit => no offer rolls.
	var maxed := {}
	for a in ChipAugments.LIST:
		maxed[String(a["id"])] = int(a["stock"])
	run_store.chipAugmentsPurchased = maxed
	if String(run_store._roll_augment_offer(5)) != "":
		failures.append("augments: exhausted pool still rolled an offer")
	# One eligible augment left => the roll must offer exactly that one.
	var one_left: Dictionary = maxed.duplicate(true)
	one_left["aug_pair_triple"] = 0
	run_store.chipAugmentsPurchased = one_left
	if String(run_store._roll_augment_offer(5)) != "aug_pair_triple":
		failures.append("augments: sole eligible augment was not offered")

	# UI: the augment stands on the far-right counter slot like a consumable —
	# priced tag above, name/rarity/stock/effect on select, drag-on-dealer to buy;
	# selector cancel never charges.
	run_store.runPhase = "idle"
	run_store.dealerPending = false
	run_store.dealerOfferIds = null
	run_store.prerunOfferIds = null
	run_store.chipAugmentsPurchased = {}
	run_store.symbolAugmentLevels = {}
	run_store.pairTripleAugmentChoice = ""
	meta_store.lucidityWallet = 100
	var shop := (load("res://scenes/dealer_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(shop)
	run_store.dealerAugmentOfferId = "aug_symbol_level"
	shop._build_offers()
	var aug_slot := shop.get_node_or_null("OfferSlot5") as Control
	if aug_slot == null:
		failures.append("augments: far-right offer slot missing")
	else:
		var has_icon := false
		var icon_sprite: Sprite2D = null
		for child in aug_slot.get_children():
			if child.has_meta("_dealer_dynamic") and child is Control and not (child is HBoxContainer):
				has_icon = true
				icon_sprite = (child as Control).get_child(0) as Sprite2D
		if not has_icon:
			failures.append("augments: no augment icon on the far-right counter slot")
		# The authored chip sheet: 6 frames, one unique chip per augment.
		if icon_sprite == null or icon_sprite.texture == null:
			failures.append("augments: augment icon has no chip art")
		elif icon_sprite.hframes != ChipAugments.ICON_HFRAMES \
				or icon_sprite.frame != int(ChipAugments.map()["aug_symbol_level"]["frame"]):
			failures.append("augments: augment icon is not the augment's unique chip frame")
		var aug_tag := aug_slot.get_node_or_null("PriceTag") as Control
		var aug_price_label := aug_slot.get_node_or_null("PriceTag/Price") as Label
		if aug_tag == null or not aug_tag.visible or aug_price_label == null \
				or aug_price_label.text != str(run_store.chip_augment_price("aug_symbol_level")):
			failures.append("augments: far-right slot must show the live augment price")
		# Selecting the augment surfaces the shared AUGMENT name (rarity-coloured)
		# and green-only TV hints — no explanatory message text.
		shop._select("aug_symbol_level")
		var sel_name := shop.get_node_or_null("NameLabel") as Label
		var sel_message := shop.get_node_or_null("Message") as Label
		if sel_name == null or not sel_name.visible or sel_name.text != "AUGMENT":
			failures.append("augments: selecting the augment did not show the AUGMENT name")
		if sel_message == null or sel_message.text != "":
			failures.append("augments: selecting the augment should show no explanatory text")
		if not shop._tv_pos.text.begins_with("+ ") \
				or (shop._tv_neg.text != "" and not shop._tv_neg.text.begins_with("+ ")):
			failures.append("augments: TV must show only beneficial (green) hints")
		# Double positives share the exact same x on the TV.
		if shop._tv_neg.position.x != shop._tv_pos.position.x:
			failures.append("augments: double-positive TV lines are misaligned")
		# A later normal-item selection restores the red negative line, nudged
		# +0.5px so the narrower "-" glyph keeps the words column-aligned.
		shop._select("cons_cigarette")
		if not shop._tv_neg.text.begins_with("- "):
			failures.append("augments: normal item selection lost its negative hint")
		if shop._tv_neg.position.x != shop._tv_pos.position.x + 0.5:
			failures.append("augments: negative TV line lost its half-pixel glyph nudge")
		shop._select("aug_symbol_level")
		# Selector cancellation: drop on the dealer opens the picker; cancel
		# consumes nothing.
		shop._drop_on_dealer("aug_symbol_level", "augment")
		if shop.get_node_or_null("AugmentPicker") == null:
			failures.append("augments: symbol selector did not open")
		shop._close_augment_picker()
		if int(meta_store.lucidityWallet) != 100 \
				or not (run_store.chipAugmentsPurchased as Dictionary).is_empty():
			failures.append("augments: cancelled selector charged or consumed stock")
		# Drag-to-dealer purchase: wallet pays, the offer and its icon are consumed.
		run_store.dealerAugmentOfferId = "aug_extra_spins"
		shop._build_offers()
		shop._drop_on_dealer("aug_extra_spins", "augment")
		if int(meta_store.lucidityWallet) != 100 - 35:
			failures.append("augments: drop purchase charged the wrong wallet price")
		if String(run_store.dealerAugmentOfferId) != "":
			failures.append("augments: purchased offer was not consumed")
		var leftover_tag := aug_slot.get_node_or_null("PriceTag") as Control
		if leftover_tag != null and leftover_tag.visible:
			failures.append("augments: consumed augment still shows a price tag")
		var leftover_icon := false
		for child in aug_slot.get_children():
			if child.has_meta("_dealer_dynamic") and child is Control and not (child is HBoxContainer):
				leftover_icon = true
		if leftover_icon:
			failures.append("augments: consumed augment icon still on the counter")
	shop.queue_free()

	# Run start folds pre-run purchases in; a full reset clears everything. Uses a
	# detached store so the ambient smoke-test state survives.
	var fresh: Node = (load("res://autoload/run_state_store.gd") as GDScript).new()
	fresh.chipAugmentsPurchased = { "aug_extra_spins": 1 }
	fresh.symbolAugmentLevels = { "eye": 1 }
	fresh.pairTripleAugmentChoice = "pair"
	fresh.start_new_run([], {}, false)
	if int((fresh.chipAugmentsPurchased as Dictionary).get("aug_extra_spins", 0)) != 1 \
			or String(fresh.pairTripleAugmentChoice) != "pair":
		failures.append("augments: run start dropped pre-run purchases")
	if int(fresh.neurons) != int(fresh.startingNeurons) + 3 * maxi(1, Economy.compute_neuron_decay([])):
		failures.append("augments: run start did not fold in pre-run Extra Spins")
	var eye_base := int(meta_store.odds_upgrade_level("eye")) * int(fresh.probability_increase_per_upgrade)
	if float((fresh.oddsWeightOverrides as Dictionary).get("eye", 0.0)) \
			!= float(eye_base + int(fresh.probability_increase_per_upgrade)):
		failures.append("augments: run start did not fold in pre-run symbol levels")
	if String(fresh.dealerAugmentOfferId) != "":
		failures.append("augments: run start left the shop augment offer open")
	fresh.reset_run_state()
	if not (fresh.chipAugmentsPurchased as Dictionary).is_empty() \
			or not (fresh.symbolAugmentLevels as Dictionary).is_empty() \
			or String(fresh.pairTripleAugmentChoice) != "":
		failures.append("augments: full reset did not clear augment state")
	fresh.free()

	run_store.runPhase = prev_phase
	run_store.dealerPending = prev_pending
	run_store.dealerOfferIds = prev_offers
	run_store.dealerRerollCount = prev_reroll_count
	run_store.prerunOfferIds = prev_prerun
	run_store.lucidityCoins = prev_coins
	run_store.chipAugmentsPurchased = prev_augs
	run_store.dealerAugmentOfferId = prev_aug_offer
	run_store.symbolAugmentLevels = prev_sym
	run_store.pairTripleAugmentChoice = prev_pt
	run_store.oddsWeightOverrides = prev_weights
	run_store.symbolRewardBonuses = prev_bonuses
	run_store.neurons = prev_neurons
	run_store.ownedUpgrades = prev_owned
	meta_store.lucidityWallet = prev_wallet
	meta_store.save_state() # re-persist the restored wallet

func _find_label_with_text(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text:
		return node
	for child in node.get_children():
		var found := _find_label_with_text(child, text)
		if found != null:
			return found
	return null

# The neuron meter no longer lives on the in-run HUDs — it belongs to the start
# menu and the flatline overlay only.
func _check_neuron_meter_absent(scene_name: String, hud: Control, failures: Array) -> void:
	if hud == null:
		return
	for child in hud.get_children():
		if child is NeuronMeter:
			failures.append("%s: neuron meter should not be on the in-run HUD" % scene_name)
			return

func _find_neuron_meter(node: Node) -> NeuronMeter:
	if node is NeuronMeter:
		return node
	for child in node.get_children():
		var found := _find_neuron_meter(child)
		if found != null:
			return found
	return null

# The neuron meter left the menu: CONTINUE opens the run-state modal, which
# carries it plus the resume/abandon choice (issue #111 follow-up).
func _check_neuron_meter_on_menu(failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var run_store: Node = get_root().get_node("RunStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	meta_store.is_first_launch = false
	var start_menu := (load("res://scenes/start_menu_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(start_menu)
	await process_frame
	if _find_neuron_meter(start_menu) != null:
		failures.append("menu: the neuron meter should not render on the start menu")

	var prev_phase := String(run_store.runPhase)
	run_store.runPhase = "pre_run"
	start_menu._refresh_start_button()
	if start_menu._start_button == null or (start_menu._start_button as Button).text != "CONTINUE":
		failures.append("menu: pre-run dealer return should show CONTINUE")
	run_store.runPhase = "running"
	run_store.campaignNeuronPending = true
	run_store.lucidityCoins = 200
	run_store.scoreEarned = 40
	meta_store.ownedPermanents = []
	meta_store.lucidityWallet = 0
	meta_store.campaignNeuronsLeft = int(meta_store.campaignNeuronsMax)
	start_menu._show_continue_modal()
	await process_frame
	var meter := _find_neuron_meter(start_menu)
	if meter == null:
		failures.append("menu: CONTINUE modal is missing the neuron meter")
	else:
		var sprite: Sprite2D = null
		for child in meter.get_children():
			if child is Sprite2D:
				sprite = child
				break
		if sprite == null:
			failures.append("menu: modal meter built no sprite (sheet missing?)")
		else:
			if sprite.hframes != meter.frame_count:
				failures.append("menu: meter hframes do not match frame_count")
			var lost := int(meta_store.campaignNeuronsMax) - int(meta_store.campaignNeuronsLeft)
			if sprite.frame != clampi(lost, 0, meter.frame_count - 1):
				failures.append("menu: meter frame is not wired to neurons lost")
		var count := meter.get_node_or_null("CountLabel") as Label
		if count == null:
			failures.append("menu: modal meter is missing the numeric neuron count")
		elif count.text != "%d/%d" % [int(meta_store.campaignNeuronsLeft), int(meta_store.campaignNeuronsMax)]:
			failures.append("menu: modal neuron count reads '%s'" % count.text)
	var stats := start_menu.get_node_or_null("ContinueModal/Panel/Stats") as Label
	if stats == null or stats.text != "CURRENT COINS : 200":
		failures.append("menu: CONTINUE modal should show current coins only")
	if stats != null and (stats.text.contains("SCORE") or stats.text.contains("LUCIDITY") \
			or stats.text.contains("L-COIN")):
		failures.append("menu: CONTINUE modal still shows the old score/coin label")
	# A dealer/pre-run session shows the same banked wallet that the dealer spends.
	var wallet_before_preview := int(meta_store.lucidityWallet)
	start_menu._hide_continue_modal()
	await process_frame
	run_store.runPhase = "pre_run"
	run_store.lucidityCoins = 222
	meta_store.lucidityWallet = 321
	start_menu._show_continue_modal()
	var pre_run_stats := start_menu.get_node_or_null("ContinueModal/Panel/Stats") as Label
	if pre_run_stats == null or pre_run_stats.text != "CURRENT COINS : 321":
		failures.append("menu: CONTINUE modal should show the dealer wallet")
	start_menu._hide_continue_modal()
	await process_frame
	run_store.runPhase = "running"
	meta_store.lucidityWallet = wallet_before_preview
	start_menu._show_continue_modal()
	await process_frame
	var panel := start_menu.get_node_or_null("ContinueModal/Panel") as Panel
	var close := start_menu.get_node_or_null("ContinueModal/Panel/CloseButton") as Button
	if close == null:
		failures.append("menu: CONTINUE modal has no close button")
	elif panel != null and (close.position.x + close.size.x > panel.size.x \
			or close.position.y >= 16.0):
		failures.append("menu: CONTINUE modal close button is not in the top-right corner")
	var resume := start_menu.get_node_or_null("ContinueModal/Panel/ContinueButton") as Button
	if stats != null and stats.position.y < 86.0:
		failures.append("menu: current-coins label is too high under the neuron number")
	if stats != null and resume != null \
			and stats.position.y + stats.size.y + 6.0 > resume.position.y:
		failures.append("menu: current-coins label is too close to CONTINUE")
	if close != null:
		close.pressed.emit()
		if start_menu._continue_modal != null or String(run_store.runPhase) != "running":
			failures.append("menu: modal close did not dismiss without losing the run")
	start_menu._show_continue_modal()
	var give_up := start_menu.get_node_or_null("ContinueModal/Panel/GiveUpButton") as Button
	resume = start_menu.get_node_or_null("ContinueModal/Panel/ContinueButton") as Button
	if resume == null:
		failures.append("menu: CONTINUE modal has no resume button")
	if give_up == null:
		failures.append("menu: CONTINUE modal has no GIVE UP button")
	else:
		# Abandoning resets the run outright: nothing banks, the menu frees up.
		give_up.pressed.emit()
		if String(run_store.runPhase) == "running":
			failures.append("menu: GIVE UP did not end the held run")
		if int(run_store.scoreEarned) != 0 or int(run_store.lucidityCoins) != 0:
			failures.append("menu: GIVE UP did not reset the run state")
		if int(meta_store.campaignNeuronsLeft) != int(meta_store.campaignNeuronsMax):
			failures.append("menu: GIVE UP did not restore the campaign neuron count")
		if int(meta_store.lucidityWallet) != 0:
			failures.append("menu: GIVE UP banked lucidity; abandoning should bank nothing")
		# queue_free is deferred; the scene's reference clears immediately.
		if start_menu._continue_modal != null:
			failures.append("menu: GIVE UP left the run-state modal open")
	run_store.runPhase = "over"
	start_menu._refresh_start_button()
	if start_menu._start_button != null and (start_menu._start_button as Button).text == "CONTINUE":
		failures.append("menu: finished flatline state incorrectly shows CONTINUE")
	run_store.reset_run_state()
	run_store.runPhase = prev_phase
	meta_store._apply(meta_before)
	meta_store.save_state()
	start_menu.queue_free()

# Issue #38: campaign rebalance — save reclamp, exact fatal text, goal threshold.
func _check_campaign_rebalance_38(machine: Node, failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	# Saves from the 12-neuron era reclamp to the current starting count.
	var migrated: Dictionary = meta_store._migrate({
		"schemaVersion": 3, "campaignNeuronsMax": 12, "campaignNeuronsLeft": 12,
	})
	if int(migrated["campaignNeuronsMax"]) != int(meta_store.campaign_starting_neurons) \
			or int(migrated["campaignNeuronsLeft"]) != int(migrated["campaignNeuronsMax"]):
		failures.append("issue38: 12-neuron save did not reclamp to the new starting count")
	if int(meta_store.campaign_starting_neurons) != 10:
		failures.append("issue38: campaigns should start at 10 neurons")
	# Wealth ending fires at the (default 2000) goal; the @export override threads through.
	if Endings.check_ending({ "scoreEarned": 2000, "neurons": 5 }, {}) != "wealth":
		failures.append("issue38: 2000 score did not trigger the wealth ending")
	if Endings.check_ending({ "scoreEarned": 1999, "neurons": 5 }, {}) != null:
		failures.append("issue38: sub-goal score triggered an ending")
	if Endings.check_ending({ "scoreEarned": 2500, "neurons": 5 }, {}, 3000) != null:
		failures.append("issue38: raised campaign_goal_score was ignored")
	# Exact GDD fatal copy remains on the transparent game-over overlay.
	machine._show_campaign_failed()
	var overlay: Control = machine._overlay
	var found_fatal := false
	if overlay != null:
		var game_over := overlay.get_node_or_null("GameOverEndingOverlay") as Control
		if game_over != null:
			for child in game_over.get_children():
				if child is Label and (child as Label).text == "this time, it's fatal. No coming back":
					found_fatal = true
					break
	if not found_fatal:
		failures.append("issue38: game-over overlay is missing the exact fatal text")
	if overlay != null:
		overlay.queue_free()
		machine._overlay = null

func _check_odds_table_36(run_store: Node, failures: Array) -> void:
	# issue #36 (permanent rework): post-run odds-buying — per-symbol costs, staged
	# purchases undoable while open, committed permanently on finalize, 8-level cap
	# (issue #50), and a screen lock until the next run.
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	meta_store.oddsUpgrades = {}
	meta_store.oddsTokensBanked = 0
	run_store.reset_run_state()

	run_store.begin_odds_phase()
	if int(run_store.oddsTokensRemaining) != int(run_store.odds_budget):
		failures.append("issue36: begin_odds_phase did not grant the token budget")
	if not run_store.buy_odds_upgrade("brain"):
		failures.append("issue36: brain (cost 4) rejected with a full budget")
	if int(run_store.oddsTokensRemaining) != 0 or run_store.odds_upgrade_level("brain") != 1:
		failures.append("issue36: brain buy did not spend 4 tokens for one level")
	if run_store.buy_odds_upgrade("eye"):
		failures.append("issue36: cap ignored — bought eye with 0 tokens")

	# Undo refunds staged purchases while the screen is still open.
	if not run_store.undo_odds_upgrade("brain"):
		failures.append("issue36: could not undo a staged purchase")
	if int(run_store.oddsTokensRemaining) != int(run_store.odds_budget) or run_store.odds_upgrade_level("brain") != 0:
		failures.append("issue36: undo did not refund the staged purchase")
	if run_store.undo_odds_upgrade("brain"):
		failures.append("issue36: undo went below zero staged purchases")

	if not run_store.buy_odds_upgrade("eye"):
		failures.append("issue36: eye (cost 3) rejected with a full budget")
	if run_store.buy_odds_upgrade("pill") or run_store.buy_odds_upgrade("vial"):
		failures.append("issue36: per-symbol cost ignored — 1 token bought pill/vial")
	if run_store.buy_odds_upgrade("book") or run_store.buy_odds_upgrade("nonsense"):
		failures.append("issue36: bought a symbol outside the reel cycle")

	# Finalize commits permanently and locks the phase until the next run.
	run_store.finalize_odds_phase()
	if int(meta_store.odds_upgrade_level("eye")) != 1:
		failures.append("issue36: finalize did not commit the eye level to meta")
	if not run_store.oddsPhaseCompleted:
		failures.append("issue36: finalize did not lock the odds phase")
	if run_store.undo_odds_upgrade("eye"):
		failures.append("issue36: undid a purchase after finalize")
	run_store.begin_odds_phase()
	if int(run_store.oddsTokensRemaining) != 0:
		failures.append("issue36: begin_odds_phase re-granted tokens after finalize")
	if run_store.buy_odds_upgrade("vial"):
		failures.append("issue36: bought odds after the phase was finalized")

	# Permanent levels survive into the run as weight overrides; buying stays locked.
	run_store.start_new_run([], {}, false)
	if int(run_store.oddsWeightOverrides.get("eye", 0)) != int(run_store.probability_increase_per_upgrade):
		failures.append("issue36: start_new_run did not derive overrides from meta levels")
	if int(run_store.oddsTokensRemaining) != 0:
		failures.append("issue36: start_new_run kept unspent tokens")
	if run_store.buy_odds_upgrade("vial"):
		failures.append("issue36: bought odds while a run was live")
	run_store.neurons = 100
	if run_store.spin() == null:
		failures.append("issue36: spin failed with overrides active")
	run_store.set_spinning(false)

	# Upgrades persist across runs: a reset keeps the meta levels for the next run.
	run_store.end_run("wealth")
	run_store.reset_run_state()
	if int(meta_store.odds_upgrade_level("eye")) != 1:
		failures.append("issue36: reset_run_state wiped the permanent odds levels")
	run_store.start_new_run([], {}, false)
	if int(run_store.oddsWeightOverrides.get("eye", 0)) < 1:
		failures.append("issue36: odds levels did not persist into the next run")
	run_store.reset_run_state()

	# The 8-level cap (issue #50) holds even with tokens to spare.
	if int(run_store.odds_max_level) != 8:
		failures.append("issue50: odds upgrades should cap at 8 levels")
	meta_store.oddsUpgrades = { "vial": 8 }
	run_store.begin_odds_phase()
	if run_store.buy_odds_upgrade("vial"):
		failures.append("issue36: bought past the 8-level cap")
	meta_store.oddsUpgrades = {}
	run_store.reset_run_state()

	# Issue #50: unspent tokens are banked on finalize and carry into the next
	# odds menu on top of the fresh budget (2 left of 4 => next menu opens at 6).
	meta_store.oddsTokensBanked = 0
	run_store.begin_odds_phase()
	if not run_store.buy_odds_upgrade("vial"):
		failures.append("issue50: vial (cost 2) rejected with a full budget")
	# Re-entering the phase before DONE (dealer scene reopen) keeps staged picks.
	run_store.begin_odds_phase()
	if int(run_store.oddsPendingUpgrades.get("vial", 0)) != 1 \
			or int(run_store.oddsTokensRemaining) != int(run_store.odds_budget) - 2:
		failures.append("issue50: reopening the odds phase dropped staged picks")
	run_store.finalize_odds_phase()
	if int(meta_store.oddsTokensBanked) != int(run_store.odds_budget) - 2:
		failures.append("issue50: leftover tokens were not banked on finalize (got %d)" % int(meta_store.oddsTokensBanked))
	run_store.reset_run_state()
	run_store.begin_odds_phase()
	if int(run_store.oddsTokensRemaining) != int(run_store.odds_budget) + int(run_store.odds_budget) - 2:
		failures.append("issue50: next odds menu did not open with banked + fresh tokens (got %d)" % int(run_store.oddsTokensRemaining))
	meta_store.oddsUpgrades = {}
	meta_store.oddsTokensBanked = 0
	run_store.reset_run_state()

	# Issue #130: the pool starts at the 4-token default and is hard-capped at 8
	# kept or used — a banked hoard past the cap is clamped when the menu opens.
	if int(run_store.odds_budget) != 4:
		failures.append("issue130: default token budget should be 4, got %d" % int(run_store.odds_budget))
	if int(run_store.odds_max_tokens) != 8:
		failures.append("issue130: token cap should be 8, got %d" % int(run_store.odds_max_tokens))
	meta_store.oddsTokensBanked = 20
	run_store.begin_odds_phase()
	if int(run_store.oddsTokensRemaining) != int(run_store.odds_max_tokens):
		failures.append("issue130: token pool exceeded the 8 cap (got %d)" % int(run_store.oddsTokensRemaining))
	run_store.finalize_odds_phase()
	if int(meta_store.oddsTokensBanked) > int(run_store.odds_max_tokens):
		failures.append("issue130: banked tokens exceeded the 8 cap (got %d)" % int(meta_store.oddsTokensBanked))
	# Costs match the numbers baked into the ODD-TABLE art (4/3/3/2/2/1).
	var baked_costs := { "brain": 4, "eye": 3, "pill": 3, "syringe": 2, "vial": 2, "flatline": 1 }
	for sym in baked_costs:
		if int(run_store.odds_token_cost(String(sym))) != int(baked_costs[sym]):
			failures.append("issue130: %s token cost %d does not match the baked art (%d)"
				% [String(sym), int(run_store.odds_token_cost(String(sym))), int(baked_costs[sym])])
	meta_store.oddsUpgrades = {}
	meta_store.oddsTokensBanked = 0
	run_store.reset_run_state()

	# The odds overlay scene: +/- controls, level meters, close finalizes.
	var overlay_ps := load("res://scenes/odds_table_overlay.tscn") as PackedScene
	var overlay: Node = overlay_ps.instantiate()
	get_root().add_child(overlay)
	overlay.open_overlay()
	if not bool(overlay.visible):
		failures.append("issue36: overlay not visible after open_overlay")
	if int(run_store.oddsTokensRemaining) != int(run_store.odds_budget):
		failures.append("issue36: open_overlay did not begin the odds phase")
	var plus_buttons: Dictionary = overlay._plus_buttons
	var level_sprites: Dictionary = overlay._level_sprites
	if plus_buttons.size() != 6 or level_sprites.size() != 6:
		failures.append("issue36: overlay should list all 6 reel-cycle symbols")
	elif (plus_buttons["vial"] as Button).disabled:
		failures.append("issue36: affordable + button is disabled")
	# Issue #130: the wallet renders on the ODD-TABLE_tokens sheet, one frame per
	# token count (fresh budget => frame 4). Percentages are revealed on symbol
	# press so the authored rows stay uncluttered.
	if overlay._tokens_sprite == null \
			or int((overlay._tokens_sprite as Sprite2D).frame) != int(run_store.odds_budget):
		failures.append("issue130: tokens sheet should sit on frame %d" % int(run_store.odds_budget))
	var symbol_buttons: Dictionary = overlay._symbol_buttons
	if symbol_buttons.size() != 6:
		failures.append("issue50: symbol boxes should be pressable for live draw chance")
	if overlay.get_node_or_null("NeonGlow") != null:
		failures.append("issue130: odds-table neon glow should be disabled")
	var done_button: Button = null
	for child in overlay.get_children():
		if child is Button and (child as Button).text == "DONE":
			done_button = child as Button
			break
	if done_button == null:
		failures.append("issue130: odds-table DONE button is missing")
	else:
		var modal_bottom: float = overlay.MODAL_FRAME_RECT.position.y \
			+ overlay.MODAL_FRAME_RECT.size.y + overlay.TABLE_Y_OFFSET - 10.0
		var done_center: float = done_button.position.y + done_button.size.y * 0.5
		if not is_equal_approx(done_center, modal_bottom):
			failures.append("issue130: DONE button is not centered on the modal edge")
		# Sized up to read as a real button (follow-up tweak), but still well
		# inside the 144px-wide modal frame.
		if done_button.size.x < 40.0 or done_button.size.y < 10.0:
			failures.append("issue130: DONE button too small to read as a button")
		if done_button.size.x > 64.0 or done_button.size.y > 16.0:
			failures.append("issue130: DONE button is oversized for the modal")
		if done_button.pivot_offset != done_button.size * 0.5:
			failures.append("issue130: DONE button press animation needs a centered pivot")
		_check_start_menu_button_style(done_button, Assets.START_MENU_BUTTON_CYAN,
			"issue130: DONE", failures, true)
	var brain_symbol_button := symbol_buttons.get("brain") as Button
	var brain_icon := overlay._symbol_icons.get("brain") as Sprite2D
	if brain_symbol_button == null or brain_icon == null:
		failures.append("issue50: brain symbol is missing its press target or icon")
	else:
		var icon_rest_scale := brain_icon.scale
		brain_symbol_button.button_down.emit()
		await process_frame
		if brain_icon.scale == icon_rest_scale:
			failures.append("issue50: symbol press did not start the pressed animation")
		brain_symbol_button.button_up.emit()
	# Issue #153: the draw-chance peek moved from the symbol box to a per-row
	# "i" button under the level meter.
	var info_buttons: Dictionary = overlay._info_buttons
	if info_buttons.size() != 6:
		failures.append("issue153: every row needs an info button under its level meter")
	var brain_info_button := info_buttons.get("brain") as Button
	if brain_info_button == null:
		failures.append("issue153: brain row is missing its info button")
	else:
		brain_info_button.button_down.emit()
		await process_frame
		if overlay._pct_popup == null:
			failures.append("issue153: pressing the info button did not open the percentage popup")
		else:
			var popup_label := overlay._pct_popup.get_node_or_null("PctBubble/PctLabel") as Label
			if popup_label == null or not popup_label.text.ends_with("%"):
				failures.append("issue153: percentage popup is missing its current chance")
			else:
				var popup_bubble := overlay._pct_popup.get_node("PctBubble") as Panel
				if not popup_bubble.get_global_rect().encloses(popup_label.get_global_rect()):
					failures.append("issue153: percentage text extends outside its popup bubble")
		brain_info_button.button_up.emit()
		if overlay._pct_popup != null:
			failures.append("issue153: releasing the info button did not hide the popup")
	# Every row's symbol sits inside the baked box, scaled down to fit (issue #130).
	var box_icons := 0
	for child in overlay.get_children():
		if child is Sprite2D and (child as Sprite2D).centered \
				and is_equal_approx((child as Sprite2D).position.x, float(overlay.SYMBOL_BOX_CENTER.x)):
			var icon := child as Sprite2D
			var icon_w: float = float(icon.texture.get_width()) * icon.scale.x
			if icon_w <= float(overlay.ODD_ICON_SIZE) + 0.01:
				box_icons += 1
	if box_icons != 6:
		failures.append("issue130: expected 6 boxed symbol icons scaled to fit, found %d" % box_icons)
	var brain_level_x0: float = (level_sprites["brain"] as Sprite2D).region_rect.position.x
	overlay._on_plus_pressed("brain")
	if run_store.odds_upgrade_level("brain") != 1:
		failures.append("issue36: overlay + did not reach the store")
	# Issue #153: a staged + pops a transient "+x.x%" bubble above the row.
	if overlay._delta_popup == null:
		failures.append("issue153: + press did not show a percentage-delta bubble")
	else:
		var delta_label := overlay._delta_popup.get_node_or_null("PctBubble/PctLabel") as Label
		if delta_label == null or not delta_label.text.begins_with("+") \
				or not delta_label.text.ends_with("%"):
			failures.append("issue153: + delta bubble should read as +x.x%")
	# The bought level advances the row's meter to the next sheet frame.
	if (level_sprites["brain"] as Sprite2D).region_rect.position.x \
			!= brain_level_x0 + float(overlay.ART_FRAME_W):
		failures.append("issue130: bought level did not advance the meter frame")
	if int((overlay._tokens_sprite as Sprite2D).frame) != int(run_store.odds_budget) - 4:
		failures.append("issue130: tokens sheet frame did not track the spend")
	if not (plus_buttons["vial"] as Button).disabled:
		failures.append("issue36: unaffordable + button stayed enabled")
	overlay._on_minus_pressed("brain")
	if run_store.odds_upgrade_level("brain") != 0:
		failures.append("issue36: overlay - did not undo the staged purchase")
	overlay._close()
	if bool(overlay.visible):
		failures.append("issue36: overlay still visible after close")
	if not run_store.oddsPhaseCompleted:
		failures.append("issue36: overlay close did not finalize the phase")
	overlay.queue_free()
	run_store.reset_run_state()
	meta_store._apply(meta_before)
	meta_store.save_state()

# Issue #140 flatline treatment: a focused message, retained-credit drain,
# animated trace, broken-neon continuation button, and existing continuation flow.
func _check_flatline_overlay_meter(machine: Node, failures: Array) -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	var run := { "neurons": 0, "scoreEarned": 10, "lucidityCoins": 100 }

	meta_store.campaignNeuronsLeft = 5
	meta_store.ownedPermanents = [] # base retention => "10% kept"
	run_store.runPhase = "running"
	machine._show_ending("flatline", run)
	var flatline_screen := machine._overlay.get_node_or_null("FlatlineEndingOverlay") as Control
	var texts := _overlay_label_texts(flatline_screen)
	if texts.has("this time, it's fatal. No coming back"):
		failures.append("flatline: fatal copy shown with campaign neurons remaining")
	for required_copy in [
		"FLATLINE.",
		"fortune isn't far",
	]:
		if not texts.has(required_copy):
			failures.append("flatline: issue #140 copy missing: %s" % required_copy)
	for t in texts:
		if String(t).begins_with("FINAL CREDITS"):
			failures.append("flatline: FINAL CREDITS line should be gone")
		if String(t).contains("LUCIDITY"):
			failures.append("flatline: 'lucidity' should not appear on the overlay")
	if not texts.has("10% kept"):
		failures.append("flatline: retained percent line missing ('10% kept')")
	if _overlay_label_texts(machine._overlay).has("-1 NEURON"):
		failures.append("flatline: extra neuron-loss popup should not appear")
	var action := machine._overlay.get_node_or_null(
		"FlatlineEndingOverlay/ButtonHost/ActionButton") as Button
	if action == null or action.text != "CONTINUE":
		failures.append("flatline: continuation button is missing")
	elif action.size.x < 120.0 or action.size.y < 34.0:
		failures.append("flatline: continuation button is not prominent enough")
	var broken_frame := flatline_screen.get_node_or_null("ButtonHost/BrokenFrame") \
		if flatline_screen != null else null
	if broken_frame == null or not broken_frame is BrokenNeonFrame:
		failures.append("flatline: broken-neon button frame is missing")
	var trace := flatline_screen.get_node_or_null("TraceRoot/TraceLine") as Line2D \
		if flatline_screen != null else null
	if trace == null or trace.points.size() < 2 \
			or trace.points[-1].x - trace.points[0].x < 128.0:
		failures.append("flatline: the enlarged flatline trace is missing or too short")
	if _find_neuron_meter(machine._overlay) != null:
		failures.append("flatline: extra neuron meter should not appear")
	if flatline_screen != null:
		flatline_screen.play_continue_animation()
		if action != null and not action.disabled:
			failures.append("flatline: CONTINUE remains enabled during its transition")
		if trace == null or trace.points.size() < 10:
			failures.append("flatline: CONTINUE does not reveal returning heartbeats")
	# The presentation changes, but the existing drain still lands on the exact
	# amount banked by the 10% end-of-run retention rule.
	machine._flatline_countdown_elapsed = machine.FLATLINE_HOLD_TIME + machine.FLATLINE_DRAIN_TIME
	machine._step_flatline_countdown(0.0)
	if machine._flatline_score_label == null or machine._flatline_score_label.text != "10":
		failures.append("flatline: score drain did not settle on the 10 credits kept")
	if machine._flatline_lost_label == null or machine._flatline_lost_label.text != "-90 lost":
		failures.append("flatline: score drain did not preserve the lost-credit feedback")
	var tray := machine.get_node_or_null("stash") as Control
	if tray != null and tray.visible:
		failures.append("flatline: stash tray still renders over the overlay")
	machine._overlay.queue_free()
	machine._overlay = null
	machine._stop_flatline_countdown()

	# Campaign exhaustion uses the transparent dedicated game-over treatment.
	# Exercise the last reserved neuron too: end_run() spends it while resolving
	# the terminal ending, so the game-over route must account for that pending cost.
	meta_store.campaignNeuronsLeft = 1
	run_store.campaignNeuronPending = true
	run_store.runPhase = "running"
	machine._show_ending("flatline", run)
	var game_over_screen := machine._overlay.get_node_or_null("GameOverEndingOverlay") as Control
	if game_over_screen == null:
		failures.append("game over: dedicated screen missing when neurons are exhausted")
	else:
		var game_over_texts := _overlay_label_texts(game_over_screen)
		if not game_over_texts.has("GAME OVER"):
			failures.append("game over: red GAME OVER title is missing")
		if not game_over_texts.has("this time, it's fatal. No coming back"):
			failures.append("game over: fatal copy missing when neurons are exhausted")
		var game_over_action := game_over_screen.get_node_or_null(
			"ButtonHost/ActionButton") as Button
		if game_over_action == null or game_over_action.text != "TRY AGAIN":
			failures.append("game over: action button is not TRY AGAIN")
		var title := game_over_screen.get_node_or_null("TitleLabel") as Label
		if title == null or not title.get_theme_color(&"font_color").is_equal_approx(
			Color("#ff334d")):
			failures.append("game over: title is not using the flatline red")
		if title != null and (title.position.y < 120.0 or title.position.y > 136.0):
			failures.append("game over: title is not centered in the middle group")
		var game_over_score := game_over_screen.get_node_or_null("MoneyLabel") as Label
		if game_over_score == null or title == null:
			failures.append("game over: score label is missing")
		elif game_over_score.position.y <= title.position.y \
				or game_over_score.position.y - title.position.y > 34.0:
			failures.append("game over: score is not directly below the title")
		elif game_over_score.text != "100":
			failures.append("game over: credit drain did not start at the run total")
		if game_over_screen.has_method("_set_displayed_credits"):
			game_over_screen.call("_set_displayed_credits", 0.0)
			if game_over_score != null and game_over_score.text != "0":
				failures.append("game over: credit drain did not settle at zero")
		if game_over_screen.get_node_or_null("Dim") != null \
				or game_over_screen.get_node_or_null("TVPanel") != null:
			failures.append("game over: opaque background/TV overlay should be absent")
		if game_over_screen.get_node_or_null("JokerIcon") != null:
			failures.append("game over: joker icon should be removed")
		var machine_game_over := game_over_screen.get_node_or_null(
			"MachineGameOver") as TextureRect
		if machine_game_over == null or machine_game_over.texture == null:
			failures.append("game over: machine_game_over asset is missing")
		else:
			if not String(machine_game_over.texture.resource_path).ends_with(
					"machine_game_over.png"):
				failures.append("game over: wrong machine_game_over texture is mounted")
			if machine_game_over.size != Vector2(160.0, 320.0):
				failures.append("game over: machine_game_over asset is not full-canvas")
		if FileAccess.get_file_as_string("res://scenes/game_over_ending_overlay.gd").contains(
				"func _draw"):
			failures.append("game over: procedural glitch/damage filter should be removed")
	if int(run_store.lucidityCoins) != 0:
		failures.append("game over: run credits did not reach zero")
	if int(meta_store.lucidityWallet) != 0:
		failures.append("game over: wallet did not reach zero")
	if str(run_store.lastEnding) != "game_over":
		failures.append("game over: run ending is %s, expected game_over" % str(run_store.lastEnding))
	if not bool(meta_store.campaignFailed):
		failures.append("game over: campaign was not marked failed")
	machine._overlay.queue_free()
	machine._overlay = null
	machine._stop_flatline_countdown()
	machine._set_stash_tray_visible(true)
	run_store.reset_run_state()
	meta_store._apply(meta_before)
	meta_store.save_state()

# Dedicated wealth-ending screen: title/subtitle copy, quiet joker reveal, score
# pop, procedural coin flood, and a single Start Again action.
func _check_wealth_screen(machine: Node, run_store: Node, failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	var run := { "neurons": 5, "scoreEarned": 2000, "lucidityCoins": 300 }

	# Wealth bar readout targets the campaign goal, not the old 1000 objective.
	machine._set_display_lucidity(300)
	if machine._bar_labels.has("goal"):
		var goal_text := String((machine._bar_labels["goal"] as Label).text)
		if not goal_text.ends_with("/2000"):
			failures.append("wealth: goal bar reads '%s', expected x/2000" % goal_text)

	run_store.runPhase = "running"
	# The store must mirror a continuable run (issue #62): CONTINUE is disabled
	# when no next spin is possible, and the guard reads the store, not `run`.
	run_store.neurons = 5
	run_store.freeSpinsRemaining = 0
	run_store.spinCount = 10
	run_store.lucidityCoins = 300
	machine._show_ending("wealth", run)
	var wallet_before := int(meta_store.lucidityWallet)
	var wealth_screen := machine._overlay.get_node_or_null("WealthEndingOverlay") as Control
	var texts := _overlay_label_texts(wealth_screen)
	for required_copy in ["You've become rich", "is it enough ?", "2,000"]:
		if not texts.has(required_copy):
			failures.append("wealth: missing ending copy %s" % required_copy)
	if texts.has("FINAL SCORE"):
		failures.append("wealth: final score caption should be removed")
	if wealth_screen != null and wealth_screen.get_node_or_null("TVPanel") != null:
		failures.append("wealth: overlay created a replacement TV panel")
	for node_name: String in [
		"WealthTrack", "WealthFill", "HealthTrack", "HealthFill", "GoalLabel", "HealthLabel"]:
		var tv_bar := machine.get_node_or_null(node_name) as CanvasItem
		if tv_bar == null or tv_bar.visible:
			failures.append("wealth: %s is still visible over the ending screen" % node_name)
	for boost_entry: Dictionary in machine._boost_indicator_slots:
		var boost_slot := boost_entry.get("slot") as Control
		if boost_slot != null and boost_slot.visible:
			failures.append("wealth: active boost icon was not cleared")
	if machine._energy_edges != null and machine._energy_edges.visible:
		failures.append("wealth: energy-drink edge animation is still visible")
	if machine._compulsive_overlay != null and machine._compulsive_overlay.visible:
		failures.append("wealth: compulsive power overlay is still visible")
	# A deferred store commit can refresh the HUD after the ending is built. The
	# wealth presentation must keep the machine bars hidden through that path too.
	machine._update_hud()
	for node_name: String in [
		"WealthTrack", "WealthFill", "HealthTrack", "HealthFill", "GoalLabel", "HealthLabel"]:
		var refreshed_tv_bar := machine.get_node_or_null(node_name) as CanvasItem
		if refreshed_tv_bar == null or refreshed_tv_bar.visible:
			failures.append("wealth: %s reappeared after an ending HUD refresh" % node_name)
	var continue_button: Button = null
	var start_again_button: Button = null
	for node: Node in machine._overlay.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == "Keep playing":
			continue_button = button
		elif button.text == "Start again ?":
			start_again_button = button
		elif button.text == "BANK & LAB":
			failures.append("wealth: bank/lab button still on the wealth screen")
		elif button.text == "IS IT ENOUGH ?" or button.text == "EXIT CASINO":
			failures.append("wealth: old wealth action button still present")
	if continue_button == null or continue_button.disabled:
		failures.append("wealth: Keep playing button missing or disabled on a continuable run")
	if start_again_button == null:
		failures.append("wealth: Start again button missing from the wealth screen")
	elif start_again_button.disabled or start_again_button.size.x < 70.0 \
			or start_again_button.size.y < 34.0:
		failures.append("wealth: Start again button is missing, disabled, or too small")
	if continue_button != null and (continue_button.size.x < 70.0 or continue_button.size.y < 34.0):
		failures.append("wealth: Keep playing button is too small")
	var wealth_button_host := wealth_screen.get_node_or_null("ButtonHost") as Control \
		if wealth_screen != null else null
	var wealth_button_asset := String(start_again_button.get_meta(&"_small_neon_button_asset", "")) \
		if start_again_button != null else ""
	if wealth_button_host == null or wealth_button_asset.is_empty():
		failures.append("wealth: wealth action does not use the shared classic neon button style")
	var coin_field := wealth_screen.get_node_or_null("CoinFloodClip/CoinField") \
		if wealth_screen != null else null
	if coin_field == null or coin_field.get_child_count() < 2000:
		failures.append("wealth: full-screen coin flood did not prepare enough coins")
	var coin_clip := wealth_screen.get_node_or_null("CoinFloodClip") as Control \
		if wealth_screen != null else null
	if coin_clip == null or coin_clip.position.y != 0.0 or coin_clip.size.y < 320.0:
		failures.append("wealth: coin flood does not cover the full screen")
	var first_coin := coin_field.get_child(0) as TextureRect \
		if coin_field != null and coin_field.get_child_count() > 0 else null
	if first_coin == null or first_coin.texture == null \
			or not String(first_coin.texture.resource_path).ends_with("coin_cumulable.png"):
		failures.append("wealth: coin flood is not using coin_cumulable.png")
	if wealth_screen != null and first_coin != null:
		wealth_screen._drive_coin_to_pile(1.0, first_coin, first_coin.position,
			first_coin.position, 0.0, 0.9)
		if first_coin.modulate.a < 0.89:
			failures.append("wealth: landed coin faded out instead of staying in the pile")
	if wealth_screen != null and wealth_screen.get("_cash_tray_pos") != machine._cash_tray_pos():
		failures.append("wealth: coin flood did not receive the machine cash-tray position")
	if first_coin != null and coin_clip != null:
		var tray_start: Vector2 = machine._cash_tray_pos() - coin_clip.position
		if first_coin.position.distance_to(tray_start) > 6.0:
			failures.append("wealth: first coin does not start at the machine cash tray")
	if wealth_screen != null \
			and wealth_screen.get_node_or_null("CoinFloodClip/FloodSurface") != null:
		failures.append("wealth: created flood surface is still present")
	var joker := wealth_screen.get_node_or_null("JokerIcon") as TextureRect \
		if wealth_screen != null else null
	if joker == null or joker.texture == null:
		failures.append("wealth: joker icon is missing from the TV")
	elif joker.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		failures.append("wealth: joker icon is not nearest-neighbor filtered")
	else:
		var tv_rect: Dictionary = machine.TV_SCREEN
		var joker_rect := Rect2(joker.position, joker.size)
		var tv_bounds := Rect2(float(tv_rect["left"]), float(tv_rect["top"]),
			float(tv_rect["width"]), float(tv_rect["height"]))
		if not tv_bounds.encloses(joker_rect):
			failures.append("wealth: joker icon is not inside the machine TV")
		var tv_center := tv_bounds.position + tv_bounds.size * 0.5
		if (joker.position + joker.size * 0.5).distance_to(tv_center) > 0.5:
			failures.append("wealth: joker icon is not centered in the machine TV")
	var subtitle := wealth_screen.get_node_or_null("SubtitleLabel") as Label \
		if wealth_screen != null else null
	if subtitle == null:
		failures.append("wealth: subtitle is missing")
	elif joker != null and (subtitle.position.y <= joker.position.y + joker.size.y \
			or subtitle.position.y >= float(machine.TV_SCREEN["top"]) + float(machine.TV_SCREEN["height"])):
		failures.append("wealth: subtitle is not just below the joker inside the machine TV")
	var score := wealth_screen.get_node_or_null("ScoreLabel") as Label \
		if wealth_screen != null else null
	if score == null or score.text != "2,000":
		failures.append("wealth: final score did not populate: %s" % (score.text if score != null else "missing"))
	if int(meta_store.lucidityWallet) != wallet_before:
		failures.append("wealth: run banked before the player chose to leave")
	# CONTINUE resumes the run under the existing wealth-continue rules.
	machine._continue_from_wealth()
	if String(run_store.runPhase) != "running" or not bool(run_store.wealthContinued):
		failures.append("wealth: CONTINUE did not resume the run (wealth-continue rules)")
	# Re-entering the machine after CONTINUE must not recreate the wealth ending or
	# end the still-playable run (issue #131).
	machine._enter_run()
	if String(run_store.runPhase) != "running" or machine._overlay != null:
		failures.append("issue131: re-entering the machine ended or overlaid the continued run")
	if machine._check_ending() or machine._overlay != null:
		failures.append("issue131: continued run still re-triggered the wealth ending")
	# Issue #110: after choosing to continue, the completed goal disappears from the
	# objective target — the label shows the score plus "???" and the bar pins full, and it stays
	# that way through every HUD refresh path for the rest of the continued run.
	machine._refresh_tv_indicators()
	if machine._bar_labels.has("goal"):
		if String((machine._bar_labels["goal"] as Label).text) != "300/???":
			failures.append("issue131: continued run goal label reads '%s', expected 300/???"
				% String((machine._bar_labels["goal"] as Label).text))
		# _set_display_lucidity is the rebuild/count-up path (scene re-entry after a
		# save load repopulates the HUD through it) — it must also keep the mask.
		machine._set_display_lucidity(450)
		if String((machine._bar_labels["goal"] as Label).text) != "450/???":
			failures.append("issue131: goal label lost the score while preserving the ??? target")
		if machine._goal_fill_sprite != null \
				and machine._goal_fill_sprite.region_rect.size.x \
					< float(machine.WEALTH_BAR["width"]) * machine.ASSET_SCALE:
			failures.append("issue110: continued-run wealth bar is not pinned full")
	else:
		failures.append("issue110: goal bar label missing from the HUD")
	# A fresh standard run restores the normal x/goal progression.
	run_store.reset_run_state()
	machine._set_display_lucidity(300)
	if machine._bar_labels.has("goal") \
			and String((machine._bar_labels["goal"] as Label).text) != "300/%d" % int(machine.campaign_goal_score):
		failures.append("issue110: new run goal label reads '%s', expected 300/%d"
			% [String((machine._bar_labels["goal"] as Label).text), int(machine.campaign_goal_score)])
	if machine._overlay != null:
		machine._overlay.queue_free()
		machine._overlay = null
	machine._set_stash_tray_visible(true)
	meta_store._apply(meta_before)
	meta_store.save_state()

# Issue #62: reaching the wealth goal with no spins left must still open the
# wealth flow with a usable Start Again action and a disabled Keep playing action;
# the retained defensive wealth-continue path must still flatline instead of softlocking.
func _check_wealth_zero_spins_62(machine: Node, run_store: Node, failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	# Wealth continuation still exercises the normal flatline presentation while
	# campaign neurons remain; campaign exhaustion belongs to issue #140 coverage.
	meta_store.campaignNeuronsLeft = 5

	# Goal reached on the very spin that exhausts neurons: the wealth ending wins
	# over the no-spins dead-end.
	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.scoreEarned = 2000
	run_store.neurons = 0
	run_store.freeSpinsRemaining = 0
	if not machine._check_ending():
		failures.append("issue62: wealth goal with 0 spins left did not end the run")
	elif str(run_store.lastEnding) != "wealth":
		failures.append("issue62: 0-spin goal ended as %s, expected wealth" % str(run_store.lastEnding))
	var start_again_button: Button = null
	var continue_button: Button = null
	if machine._overlay != null:
		for node: Node in machine._overlay.find_children("*", "Button", true, false):
			var button := node as Button
			if button.text == "Keep playing":
				continue_button = button
			elif button.text == "Start again ?":
				start_again_button = button
	if start_again_button == null or start_again_button.disabled:
		failures.append("issue62: Start Again missing/disabled on the 0-spin wealth screen")
	if continue_button == null or not continue_button.disabled:
		failures.append("issue62: Keep playing should be disabled with no possible spin")
	# Even a forced continue must not strand a dead machine: it falls through to
	# the flatline flow (which always offers an action).
	machine._continue_from_wealth()
	if str(run_store.runPhase) == "running":
		failures.append("issue62: forced continue left a running run with no possible spin")
	elif str(run_store.lastEnding) != "flatline":
		failures.append("issue62: forced continue ended as %s, expected flatline" % str(run_store.lastEnding))
	if machine._overlay == null:
		failures.append("issue62: forced continue left no ending overlay on screen")
	if machine._overlay != null:
		machine._overlay.queue_free()
		machine._overlay = null
	machine._stop_flatline_countdown()

	# Post-continue, running out of neurons must flatline even though the score
	# is past the goal (the wealth ending is suppressed by wealthContinued).
	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.scoreEarned = 2500
	run_store.neurons = 0
	run_store.freeSpinsRemaining = 0
	run_store.wealthContinued = true
	if not machine._check_ending():
		failures.append("issue62: wealth-continued dry run did not end")
	elif str(run_store.lastEnding) != "flatline":
		failures.append("issue62: wealth-continued dry run ended as %s, expected flatline" % str(run_store.lastEnding))
	if machine._overlay != null:
		machine._overlay.queue_free()
		machine._overlay = null
	machine._stop_flatline_countdown()

	# With neurons remaining, a wealth-continued run keeps playing (no ending) — a
	# high spin count no longer ends it, only the neuron economy does (issue #75).
	run_store.runPhase = "running"
	run_store.lastEnding = null
	run_store.neurons = 5
	run_store.spinCount = 500
	if machine._check_ending():
		failures.append("issue62: wealth-continued run with neurons left ended early")

	machine._set_stash_tray_visible(true)
	run_store.reset_run_state()
	meta_store._apply(meta_before)
	meta_store.save_state()

# Issue #75: neurons hitting 0 with banked free spins left must NOT flatline —
# the SPINS LEFT counter (which includes free spins) still shows spins the player
# can take; the flatline only resolves once both pools are empty.
func _check_flatline_free_spins_75(machine: Node, run_store: Node, failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	# This check is about free-spin gating, so leave enough campaign neurons for a
	# non-terminal flatline once the free-spin pool is empty.
	meta_store.campaignNeuronsLeft = 5

	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.scoreEarned = 100
	run_store.neurons = 0
	run_store.freeSpinsRemaining = 2
	run_store.maxFreeSpins = 10
	if machine._check_ending():
		failures.append("issue75: flatlined with banked free spins remaining")
	if str(run_store.runPhase) != "running":
		failures.append("issue75: free-spin hold ended the run phase")

	# The banked free spin is actually playable at 0 neurons.
	if run_store.spin() == null:
		failures.append("issue75: free spin at 0 neurons was rejected")
	else:
		run_store.set_spinning(false)
		if bool(run_store.comboDefeatPending):
			run_store.resolve_pending_combo_defeat(false)

	# Wealth-continued runs get the same carve-out (parallels _can_resume_after_wealth).
	run_store.neurons = 0
	run_store.scoreEarned = 2500
	run_store.freeSpinsRemaining = 1
	run_store.wealthContinued = true
	if machine._check_ending():
		failures.append("issue75: wealth-continued run flatlined with free spins left")

	# Both pools empty => the flatline resolves normally.
	run_store.freeSpinsRemaining = 0
	run_store.wealthContinued = false
	run_store.scoreEarned = 100
	if not machine._check_ending():
		failures.append("issue75: dry run with no free spins did not flatline")
	elif str(run_store.lastEnding) != "flatline":
		failures.append("issue75: dry run ended as %s, expected flatline" % str(run_store.lastEnding))
	if machine._overlay != null:
		machine._overlay.queue_free()
		machine._overlay = null
	machine._stop_flatline_countdown()

	# The core fix: you never die just for spinning a lot. With neurons on the bar,
	# no number of spins ends the run — there is no spin cap anymore (issue #75).
	run_store.runPhase = "running"
	run_store.lastEnding = null
	run_store.neurons = 20
	run_store.freeSpinsRemaining = 0
	run_store.wealthContinued = false
	run_store.spinCount = 999
	if machine._check_ending():
		failures.append("issue75: run with HP left flatlined from spin count alone")

	machine._set_stash_tray_visible(true)
	run_store.reset_run_state()
	meta_store._apply(meta_before)
	meta_store.save_state()

# Issue #76: a 3x-flatline strike charges the NEXT winning pair/triple. The charge is
# armed by register_flatline_result, survives non-scoring spins, doubles the next real
# win (points AND coins), then is spent. Deterministic wins/misses come from fully
# locked reels replaying a stubbed previousReels, so no RNG flakiness.
func _check_flatline_win_boost_76(run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.runPhase = "running"
	run_store.neurons = 100

	if run_store.flatlineWinBoostArmed:
		failures.append("issue76: next-win boost armed at run start")

	# A flatline strike arms the charge.
	run_store.register_flatline_result()
	if not run_store.flatlineWinBoostArmed:
		failures.append("issue76: flatline strike did not arm the next-win boost")

	# A miss must NOT spend the charge (three different symbols score nothing).
	run_store.lastResult = { "reels": ["eye", "vial", "pill"] }
	run_store.lockedReels = [true, true, true]
	var miss: Variant = run_store.spin()
	run_store.set_spinning(false)
	if miss != null and String(miss["winType"]) != "miss":
		failures.append("issue76: locked miss setup did not produce a miss")
	if bool(miss.get("flatlineBoostApplied", false)):
		failures.append("issue76: boost fired on a miss")
	if not run_store.flatlineWinBoostArmed:
		failures.append("issue76: a miss wrongly spent the charge")

	# The next real win (a locked eye pair) doubles and consumes the charge.
	run_store.lastResult = { "reels": ["eye", "eye", "vial"] }
	run_store.lockedReels = [true, true, true]
	var win: Variant = run_store.spin()
	run_store.set_spinning(false)
	if win == null:
		failures.append("issue76: charged win spin did not resolve")
	else:
		if String(win["winType"]) != "pair":
			failures.append("issue76: locked pair setup did not produce a pair")
		if not bool(win.get("flatlineBoostApplied", false)):
			failures.append("issue76: charged win did not apply the boost")
		var bonus := int(win.get("flatlineBoostBonus", 0))
		var total := int(win["scoreEarned"])
		var base := total - bonus
		if base <= 0 or total != base * EconomyConst.FLATLINE_WIN_BOOST_MULT:
			failures.append("issue76: boosted score %d != base %d x %d" % [total, base, EconomyConst.FLATLINE_WIN_BOOST_MULT])
		if int(win["coinsEarned"]) != total:
			failures.append("issue76: boosted coins should match boosted score")
		if run_store.flatlineWinBoostArmed:
			failures.append("issue76: charge not spent after a winning spin")

	# A later win with no charge scores normally (no lingering boost).
	run_store.lastResult = { "reels": ["eye", "eye", "vial"] }
	run_store.lockedReels = [true, true, true]
	var plain: Variant = run_store.spin()
	run_store.set_spinning(false)
	if plain != null and bool(plain.get("flatlineBoostApplied", false)):
		failures.append("issue76: boost fired again without a fresh strike")

	run_store.reset_run_state()

# Issue #76: deferred-negative items show only the precise upside on use; the downside
# pops separately when it activates. Flavor items (no real downside) show upside only.
func _check_deferred_negative_76(machine: Node, failures: Array) -> void:
	machine._pending_deferred_neg.clear()

	# Energy Drink on use: upside only, and the copy is precise.
	var use_hint: HintLabel = machine._show_consumable_feedback("item_energy_drink")
	if use_hint == null:
		failures.append("issue76: energy-drink use hint was not created")
	else:
		if not use_hint._pos_label.visible or use_hint._neg_label.visible:
			failures.append("issue76: energy-drink use popup was not upside-only")
		if use_hint._pos_label.text != "+ 2 FREE SPINS":
			failures.append("issue76: energy-drink upside copy wrong: '%s'" % use_hint._pos_label.text)
		use_hint.queue_free()
	# Using a hooked item arms its deferred negative.
	if not machine._pending_deferred_neg.get("item_energy_drink", false):
		failures.append("issue76: energy-drink use did not arm its deferred negative")

	# Popping on activation: downside only, precise, and it disarms (no double-fire).
	var neg_hint: HintLabel = machine._show_deferred_negative("item_energy_drink")
	if neg_hint != null:
		if not neg_hint._neg_label.visible or neg_hint._pos_label.visible:
			failures.append("issue76: deferred popup was not downside-only")
		if neg_hint._neg_label.text != "- FORCED SPIN":
			failures.append("issue76: deferred downside copy wrong: '%s'" % neg_hint._neg_label.text)
		neg_hint.queue_free()
	machine._pop_deferred_negative("item_energy_drink") # arms cleared -> no-op
	if machine._pending_deferred_neg.get("item_energy_drink", false):
		failures.append("issue76: deferred negative did not disarm after popping")

	# A newly-deferred item (Serum) also shows upside-only on use.
	var serum: HintLabel = machine._show_consumable_feedback("cons_focus")
	if serum != null:
		if not serum._pos_label.visible or serum._neg_label.visible:
			failures.append("issue76: serum use popup was not upside-only")
		serum.queue_free()
	machine._pending_deferred_neg["cons_focus"] = true
	var hint_layer: Control = machine._hint_layer
	var serum_hint_count := hint_layer.get_child_count() if hint_layer != null else 0
	machine._pop_deferred_negative("cons_focus")
	if machine._pending_deferred_neg.get("cons_focus", false):
		failures.append("issue92: serum deferred negative did not disarm after popping")
	if hint_layer == null or hint_layer.get_child_count() <= serum_hint_count:
		failures.append("issue92: serum negative popup was not created")
	else:
		var serum_neg := hint_layer.get_child(hint_layer.get_child_count() - 1) as HintLabel
		if serum_neg == null or not serum_neg._neg_label.visible or serum_neg._pos_label.visible:
			failures.append("issue92: serum negative popup should be downside-only")
		elif serum_neg._neg_label.text != "- ADJACENTS HIDDEN":
			failures.append("issue92: serum negative copy wrong: '%s'" % serum_neg._neg_label.text)
		if serum_neg != null:
			serum_neg.queue_free()

	# Red Pill is inverted: CLOSE CALL on use, then WIN GUARANTEED on the second spin.
	var pill: HintLabel = machine._show_consumable_feedback("item_pill")
	if pill != null:
		if not pill._neg_label.visible or pill._pos_label.visible:
			failures.append("issue92: red pill use popup should be close-call only")
		if pill._neg_label.text != "- CLOSE CALL":
			failures.append("issue92: red pill close-call copy wrong: '%s'" % pill._neg_label.text)
		pill.queue_free()
	var pill_win: HintLabel = machine._show_deferred_positive("item_pill")
	if pill_win != null:
		if not pill_win._pos_label.visible or pill_win._neg_label.visible:
			failures.append("issue92: red pill guaranteed-win popup should be upside-only")
		if pill_win._pos_label.text != "+ WIN GUARANTEED":
			failures.append("issue92: red pill guaranteed-win copy wrong: '%s'" % pill_win._pos_label.text)
		pill_win.queue_free()
	var run_store: Node = get_root().get_node("RunStateStore")
	var previous_force_flatline := int(run_store.forceFlatlineSpins)
	var previous_guaranteed_triple := int(run_store.guaranteedTripleSpins)
	run_store.forceFlatlineSpins = 1
	run_store.guaranteedTripleSpins = 1
	if machine._pill_guaranteed_spin_pending():
		failures.append("issue92: red pill should not show guaranteed-win popup on the close-call spin")
	run_store.forceFlatlineSpins = 0
	run_store.guaranteedTripleSpins = 1
	if not machine._pill_guaranteed_spin_pending():
		failures.append("issue92: red pill should show guaranteed-win popup on the second spin")
	run_store.forceFlatlineSpins = previous_force_flatline
	run_store.guaranteedTripleSpins = previous_guaranteed_triple

	# A flavor item (Water) shows upside only — no fabricated downside line.
	var flavor: HintLabel = machine._show_consumable_feedback("item_water")
	if flavor != null:
		if not flavor._pos_label.visible or flavor._neg_label.visible:
			failures.append("issue76: flavor item showed a negative line")
		if flavor._pos_label.text != "+ +40 LUCIDITY":
			failures.append("issue76: water upside copy wrong: '%s'" % flavor._pos_label.text)
		flavor.queue_free()
	machine._pending_deferred_neg.clear()

# Issue #155: dealer pacing is a fixed visible countdown — no randomness. It starts at
# dealer_countdown_start, every spin ticks it by the multiplier used at spin start,
# 0 triggers the visit, and resolving the offer resets it.
func _check_dealer_pacing_76(run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)

	# The old hard cap (3) is gone — the ceiling is a high sentinel now.
	if run_store.dealer_max_count <= Dealer.MAX_COUNT:
		failures.append("issue76: dealer still capped at the old per-run limit (%d)" % run_store.dealer_max_count)

	# A fresh run starts the countdown at 8.
	if int(run_store.dealerCountdown) != 8 or int(run_store.dealer_countdown_start) != 8:
		failures.append("issue155: fresh run countdown should start at 8, got %d" % int(run_store.dealerCountdown))

	# x1 spin ticks -1; a frenzy spin ticks by the multiplier used at spin start.
	# Locked reels keep the outcome deterministic (an eye pair pays every spin).
	run_store.neurons = 100
	run_store.betMultiplier = 1
	run_store.lastResult = { "reels": ["eye", "eye", "vial"] }
	run_store.lockedReels = [true, true, true]
	run_store.lockedReelSpins = [3, 3, 3]
	run_store.spin()
	run_store.set_spinning(false)
	if int(run_store.dealerCountdown) != 7:
		failures.append("issue155: x1 spin should tick the countdown to 7, got %d" % int(run_store.dealerCountdown))
	if int(run_store.betMultiplier) != 2:
		failures.append("issue155: a paying win should step the gauge to x2, got %d" % int(run_store.betMultiplier))
	run_store.spin()
	run_store.set_spinning(false)
	if int(run_store.dealerCountdown) != 5:
		failures.append("issue155: x2 spin should tick the countdown by 2, got %d" % int(run_store.dealerCountdown))

	# 0 triggers the visit deterministically; resolving the offer resets to 8.
	run_store.dealerCountdown = 0
	run_store.dealerIncoming = false
	run_store.dealerPending = false
	var count_before := int(run_store.dealerCount)
	run_store.check_dealer_trigger()
	if not bool(run_store.dealerIncoming) or int(run_store.dealerCount) != count_before + 1:
		failures.append("issue155: countdown 0 did not trigger the dealer")
	run_store.reveal_dealer()
	run_store.decline_dealer_visit()
	if int(run_store.dealerCountdown) != 8:
		failures.append("issue155: resolving the visit should reset the countdown to 8, got %d" % int(run_store.dealerCountdown))

	# Above 0 the dealer never procs — no randomness left in the flow.
	run_store.dealerCountdown = 1
	run_store.check_dealer_trigger()
	if bool(run_store.dealerIncoming):
		failures.append("issue155: dealer triggered with a positive countdown")

	run_store.reset_run_state()

# Issue #155: the frenzy gauge — consecutive paying wins climb x1 → x2 → x3, a losing
# spin opens a rescue window, and declining/ failing to rescue it drops one level.
func _check_frenzy_gauge_155(run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.neurons = 100

	# Three paying wins (locked eye pair) climb to the x3 cap and stay there.
	run_store.lastResult = { "reels": ["eye", "eye", "vial"] }
	run_store.lockedReels = [true, true, true]
	run_store.lockedReelSpins = [4, 4, 4]
	for expected in [2, 3, 3]:
		run_store.spin()
		run_store.set_spinning(false)
		if int(run_store.betMultiplier) != expected:
			failures.append("issue155: gauge expected x%d after a win, got x%d" % [expected, int(run_store.betMultiplier)])
	# The decay no longer scales with the gauge: 3 spins = 3 neurons.
	if int(run_store.neurons) != 97:
		failures.append("issue155: frenzy spins should decay 1 neuron each, got %d left" % int(run_store.neurons))

	# A forced flatline spin (a 0-score "triple") opens the pending defeat window and
	# holds the current x3 until the player resolves it.
	run_store.lockedReels = [false, false, false]
	run_store.lockedReelSpins = [0, 0, 0]
	run_store.forceFlatlineSpins = 1
	run_store.spin()
	run_store.set_spinning(false)
	if not bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 3:
		failures.append("issue155: a losing spin should open a pending x3 rescue, got pending=%s x%d" % [
			str(run_store.comboDefeatPending), int(run_store.betMultiplier)])
	if not run_store.resolve_pending_combo_defeat(false) or int(run_store.betMultiplier) != 2:
		failures.append("issue155: declining a pending x3 defeat should lose exactly one level, got x%d" % int(run_store.betMultiplier))

	# A failed rescue also loses exactly one level, without allowing a duplicate
	# resolution from a second input.
	run_store.betMultiplier = 3
	run_store.pendingComboMultiplier = 3
	run_store.comboDefeatPending = true
	if not run_store.resolve_pending_combo_defeat(false) or int(run_store.betMultiplier) != 2 \
			or bool(run_store.comboDefeatPending):
		failures.append("issue155: failed rescue did not settle x3 to x2 exactly once")
	if run_store.resolve_pending_combo_defeat(false):
		failures.append("issue155: duplicate pending-defeat resolution was accepted")

	# Powers protect the frenzy: a post-reveal outcome that pays re-derives the
	# gauge from the value the spin ran at and clears the pending state.
	run_store.lastComboMultiplier = 2
	run_store.betMultiplier = 2
	run_store.pendingComboMultiplier = 2
	run_store.comboDefeatPending = true
	run_store.lastResult = { "reels": ["eye", "vial", "eye"], "isJackpot": false, "winType": "miss",
		"scoreEarned": 0, "coinsEarned": 0, "freeSpinsGranted": 0, "freeSpinsAfter": 0,
		"isFreeSpin": false, "scoreMultiplier": 1.0 }
	run_store.isSpinning = false
	if not run_store.copy_reel(0, 1):
		failures.append("issue155: copy_reel rescue setup failed")
	elif bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 3:
		failures.append("issue155: a power-made win should rescue the combo (expected x3, got x%d)" % int(run_store.betMultiplier))

	run_store.reset_run_state()

# Pending combo rescue and TV presentation regression checks.
func _check_pending_combo_and_free_spin_ui(machine: Node, run_store: Node, failures: Array) -> void:
	# Earlier smoke cases may have left a presentation-only free-spin entrance
	# running; isolate the pending-defeat assertions from that modal animation.
	machine._free_spin_overlay_active = false
	machine._queued_free_spin_overlays = 0
	machine._set_free_spin_display(false)
	var dealer_icon := machine.get_node_or_null("DealerIcon") as TextureRect
	if dealer_icon == null or dealer_icon.texture == null:
		failures.append("dealer icon: mini dealer portrait is missing from the TV")
	else:
		if dealer_icon.position.x < 24.0 or dealer_icon.position.y < 42.0 \
				or dealer_icon.size.x > 10.0 or dealer_icon.size.y > 10.0:
			failures.append("dealer icon: portrait is not anchored inside the TV top-left")

	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.runPhase = "running"
	run_store.neurons = 10
	run_store.lastResult = { "reels": ["eye", "vial", "pill"], "isJackpot": false,
		"winType": "miss", "scoreEarned": 0, "coinsEarned": 0,
		"freeSpinsGranted": 0, "freeSpinsAfter": 0, "isFreeSpin": false,
		"scoreMultiplier": 1.0 }
	run_store.betMultiplier = 2
	run_store.pendingComboMultiplier = 2
	run_store.comboDefeatPending = true
	run_store.isSpinning = false
	machine._set_sequence_lock(false)
	machine._show_pending_combo_defeat()
	if machine._pending_combo_overlay == null:
		failures.append("combo pending: defeat prompt was not created")
	else:
		var prompt := machine._pending_combo_overlay.get_node_or_null("Prompt") as Label
		if prompt == null or not prompt.text.contains("LOSE 1"):
			failures.append("combo pending: prompt did not expose the loss choice")
		var loss_2_sprite := machine.get_node_or_null("ComboLoss2") as Sprite2D
		var loss_3_sprite := machine.get_node_or_null("ComboLoss3") as Sprite2D
		if loss_2_sprite == null or not loss_2_sprite.visible:
			failures.append("combo pending: x2 losing animation was not shown")
		if loss_3_sprite != null and loss_3_sprite.visible:
			failures.append("combo pending: x3 losing animation was shown for x2")
		if machine._pending_combo_overlay.get_node_or_null("Title") != null:
			failures.append("combo pending: old COMBO AT RISK headline was not removed")
		var reroll_button := machine._power_buttons.get("reroll") as Button
		if reroll_button == null or reroll_button.disabled:
			failures.append("combo pending: reroll was not enabled as a rescue power")
		var spin_count_before := int(run_store.spinCount)
		machine._do_spin()
		if int(run_store.spinCount) != spin_count_before:
			failures.append("combo pending: spin input was accepted before resolution")
	machine._on_pending_combo_declined()
	if bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 1:
		failures.append("combo pending: declining x2 did not settle at x1")

	# The x3 authored loss overlay is selected independently and a declined x3
	# result drops exactly one level to x2.
	run_store.abilitiesUsed = []
	run_store.betMultiplier = 3
	run_store.pendingComboMultiplier = 3
	run_store.comboDefeatPending = true
	machine._show_pending_combo_defeat()
	var loss_2_after_x3 := machine.get_node_or_null("ComboLoss2") as Sprite2D
	var loss_3_after_x3 := machine.get_node_or_null("ComboLoss3") as Sprite2D
	if loss_3_after_x3 == null or not loss_3_after_x3.visible:
		failures.append("combo pending: x3 losing animation was not shown")
	if loss_2_after_x3 != null and loss_2_after_x3.visible:
		failures.append("combo pending: x2 losing animation remained visible for x3")
	machine._on_pending_combo_declined()
	if bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 2:
		failures.append("combo pending: declining x3 did not settle at x2")

	# A pending decision with an available power also commits the one-level loss
	# when its event-driven timeout fires.
	run_store.abilitiesUsed = []
	run_store.betMultiplier = 2
	run_store.pendingComboMultiplier = 2
	run_store.comboDefeatPending = true
	machine._show_pending_combo_defeat()
	machine._on_pending_combo_timeout()
	if bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 1:
		failures.append("combo pending: timeout did not commit the one-level loss")

	# A failed already-spent power attempt also commits the same one-level loss and
	# must not create a second reward or leave the state half-pending.
	run_store.abilitiesUsed = ["reroll"]
	run_store.betMultiplier = 2
	run_store.pendingComboMultiplier = 2
	run_store.comboDefeatPending = true
	machine._show_pending_combo_defeat()
	machine._apply_reel_power("reroll", 0)
	if bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 1:
		failures.append("combo pending: failed power attempt did not commit the one-level loss")

	# No available rescue power resolves the pending state as a one-level loss.
	run_store.lastResult = { "reels": ["eye", "vial", "pill"], "isJackpot": false,
		"winType": "miss", "scoreEarned": 0, "coinsEarned": 0,
		"freeSpinsGranted": 0, "freeSpinsAfter": 0, "isFreeSpin": false,
		"scoreMultiplier": 1.0 }
	run_store.abilitiesUsed = ["reroll", "shift"]
	run_store.betMultiplier = 2
	run_store.pendingComboMultiplier = 2
	run_store.comboDefeatPending = true
	machine._show_pending_combo_defeat()
	machine._resolve_pending_combo_without_power()
	if bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 1:
		failures.append("combo pending: unavailable powers did not commit the one-level loss")

	# A newly granted free-spin batch starts the named overlay, queues repeated
	# triggers, and hides the complete health bar rather than only its fill.
	run_store.abilitiesUsed = []
	run_store.freeSpinsRemaining = 0
	machine._free_spin_observation_initialized = true
	machine._observed_free_spins = 0
	machine._free_spin_overlay_active = false
	machine._queued_free_spin_overlays = 0
	machine._set_sequence_lock(false)
	machine._update_hud()
	run_store.freeSpinsRemaining = 1
	machine._update_hud()
	if machine.get_node_or_null("FreeSpinOverlay") == null or not bool(machine._free_spin_overlay_active):
		failures.append("free spin overlay: grant did not start the animation")
	var queued_before_replacement := int(machine._queued_free_spin_overlays)
	run_store.freeSpinsRemaining = 0
	run_store.grant_free_spins(1)
	var queued_after_replacement := int(machine._queued_free_spin_overlays)
	if queued_after_replacement <= queued_before_replacement:
		failures.append("free spin overlay: net-zero replacement grant was not queued")
	var health_track := machine.get_node_or_null("HealthTrack") as CanvasItem
	var health_fill := machine._life_fill_sprite as CanvasItem
	var health_label := machine._bar_labels.get("life") as CanvasItem
	if health_track == null or health_track.visible or health_fill == null or health_fill.visible \
			or health_label == null or health_label.visible:
		failures.append("free spin overlay: health bar was not hidden during the animation")
	var spin_count_during_overlay := int(run_store.spinCount)
	machine._do_spin()
	if int(run_store.spinCount) != spin_count_during_overlay:
		failures.append("free spin overlay: spin input was accepted during the animation")
	machine._queue_free_spin_overlay()
	if int(machine._queued_free_spin_overlays) != queued_after_replacement + 1:
		failures.append("free spin overlay: repeated trigger was not queued")
	# Drain the queued entrance and verify the health bar returns after the final one.
	machine._queued_free_spin_overlays = 0
	machine._step_free_spin_blink(machine.FREE_SPIN_OVERLAY_TIME + 0.1)
	if bool(machine._free_spin_overlay_active) or (health_track != null and not health_track.visible):
		failures.append("free spin overlay: health bar did not restore after animation")

	# Restore the normal TV state for the remaining smoke checks.
	machine._queued_free_spin_overlays = 0
	run_store.freeSpinsRemaining = 0
	machine._set_tv_progress_bars_visible(true)
	machine._update_hud()
	if health_track != null and not health_track.visible:
		failures.append("free spin overlay: health track did not restore")
	run_store.reset_run_state()

# Issue #76: while Compulsion owns the spins the multiplier badge must read x1 (the
# locked-x1 frame 4), overriding the player's chosen bet, so the takeover is obvious.
# Once the compulsive spins are spent, the badge returns to the player's choice.
func _check_compulsion_multiplier_76(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.runPhase = "running"
	run_store.neurons = 100
	run_store.betMultiplier = 3
	machine._hud_delta_hold = false
	machine._set_sequence_lock(false)

	# Baseline: no compulsion, x3 frenzy → the badge shows the gauge's x3 (frame 2).
	run_store.compulsiveSpinSkips = 0
	machine._refresh_multiplier_controls()
	if machine._multiplier_sprite != null and machine._multiplier_sprite.frame == 4:
		failures.append("issue76: multiplier showed forced-x1 without compulsion")

	# Issue #155: the TV's DEALER countdown label tracks the store's number.
	run_store.dealerCountdown = 5
	machine._refresh_dealer_countdown()
	var countdown_label := machine._bar_labels.get("dealer_count") as Label
	if countdown_label == null or countdown_label.text != "5":
		failures.append("issue155: TV dealer countdown label does not track the store")

	# Compulsion takes control → forced-x1 frame regardless of the chosen x3.
	run_store.compulsiveSpinSkips = 2
	machine._refresh_multiplier_controls()
	if machine._multiplier_sprite != null and machine._multiplier_sprite.frame != 4:
		failures.append("issue76: multiplier did not show forced x1 during compulsion (frame %d)" % machine._multiplier_sprite.frame)

	# Spins spent → back to the player's multiplier.
	run_store.compulsiveSpinSkips = 0
	machine._refresh_multiplier_controls()
	if machine._multiplier_sprite != null and machine._multiplier_sprite.frame == 4:
		failures.append("issue76: multiplier stuck on forced-x1 after compulsion ended")
	run_store.reset_run_state()

# Issue #76: active multi-spin boosts show a little consumable icon + spins-remaining in
# the TV's top-right. Icons appear only while their counter is live, stack in order, show
# the right count, and clear when the boost ends.
func _check_boost_duration_icons_76(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	var slots: Array = machine._boost_indicator_slots
	if slots.size() < 2:
		failures.append("issue76: boost indicator slots were not built")
		return

	# No boosts active: every icon hidden.
	machine._refresh_boost_indicators()
	if (slots[0]["slot"] as Control).visible:
		failures.append("issue76: boost icon shown with no active boost")

	# Focus Serum shows the chosen symbol on the TV, not the serum bottle.
	run_store.guaranteeSymbolSpins = 3
	run_store.guaranteeSymbolId = "vial"
	machine._refresh_boost_indicators()
	if not (slots[0]["slot"] as Control).visible:
		failures.append("issue92: Serum chosen-symbol boost icon did not show")
	elif (slots[0]["count"] as Label).text != "3":
		failures.append("issue92: Serum boost icon count wrong: '%s'" % (slots[0]["count"] as Label).text)
	else:
		var serum_icon := (slots[0]["icon"] as TextureRect).texture
		if serum_icon == null or not String(serum_icon.resource_path).ends_with("symbols/vial.png"):
			failures.append("issue92: Serum boost icon did not use the chosen symbol")
	run_store.guaranteeSymbolSpins = 1
	run_store.guaranteeSymbolId = "vial"
	var serum_expiring: Array[Dictionary] = machine._capture_expiring_boost_counters()
	run_store.guaranteeSymbolSpins = 0
	run_store.guaranteeSymbolId = ""
	run_store.blurReelsSpins = 2
	machine._apply_expiring_boost_linger(serum_expiring)
	machine._refresh_boost_indicators()
	if not (slots[0]["slot"] as Control).visible:
		failures.append("issue92: Serum zero-count handoff icon did not show")
	elif (slots[0]["count"] as Label).text != "0":
		failures.append("issue92: Serum zero-count handoff icon count wrong: '%s'" % (slots[0]["count"] as Label).text)
	else:
		var serum_zero_icon := (slots[0]["icon"] as TextureRect).texture
		var serum_zero_color := (slots[0]["count"] as Label).get_theme_color("font_color")
		if serum_zero_icon == null or not String(serum_zero_icon.resource_path).ends_with("symbols/vial.png"):
			failures.append("issue92: Serum zero-count handoff icon should keep the chosen symbol")
		if serum_zero_color == Color(0.94, 0.27, 0.27):
			failures.append("issue92: Serum zero-count handoff should not be red yet")
	if (slots[1]["slot"] as Control).visible:
		failures.append("issue92: Serum negative icon should wait until after the zero-count spin")
	machine._clear_boost_zero_linger()
	if not (slots[0]["slot"] as Control).visible:
		failures.append("issue92: Serum negative boost icon did not show after zero handoff")
	elif (slots[0]["count"] as Label).text != "2":
		failures.append("issue92: Serum negative boost icon count wrong: '%s'" % (slots[0]["count"] as Label).text)
	else:
		var serum_neg_icon := (slots[0]["icon"] as TextureRect).texture
		var serum_neg_color := (slots[0]["count"] as Label).get_theme_color("font_color")
		if serum_neg_icon == null or not String(serum_neg_icon.resource_path).ends_with("items/focus_serum.png"):
			failures.append("issue92: Serum negative boost icon did not use the serum bottle")
		if serum_neg_color != Color(0.94, 0.27, 0.27):
			failures.append("issue92: Serum negative boost count should be red")
	run_store.blurReelsSpins = 0
	machine._refresh_boost_indicators()

	# One boost active: first slot shows its count.
	run_store.cocktailBoostSpins = 2
	machine._refresh_boost_indicators()
	if not (slots[0]["slot"] as Control).visible:
		failures.append("issue76: active boost did not show an icon")
	elif (slots[0]["count"] as Label).text != "2":
		failures.append("issue76: boost icon count wrong: '%s'" % (slots[0]["count"] as Label).text)

	# Two boosts: they stack in DURATION_BOOSTS order (energy no-decay first).
	run_store.decaySkips = 3
	machine._refresh_boost_indicators()
	if (slots[0]["count"] as Label).text != "3" or (slots[1]["count"] as Label).text != "2":
		failures.append("issue76: stacked boost icons out of order/count (%s,%s)" % [(slots[0]["count"] as Label).text, (slots[1]["count"] as Label).text])
	if not (slots[1]["slot"] as Control).visible:
		failures.append("issue76: second stacked boost icon not shown")
	# Stacking is horizontal: same row (y), second icon to the LEFT of the first.
	var p0: Vector2 = (slots[0]["slot"] as Control).position
	var p1: Vector2 = (slots[1]["slot"] as Control).position
	if not is_equal_approx(p0.y, p1.y) or not (p1.x < p0.x):
		failures.append("issue76: boost icons did not stack horizontally (%s vs %s)" % [p0, p1])
	# Issue #113: polarity rides a sign glyph, not the count colour alone. Slot 0 is
	# the Energy Drink no-decay rush (pure upside → "+" only); slot 1 is the Cocktail
	# (rarity bonus with a live pair/triple tax → mixed, both "+" and "-").
	if not (slots[0]["pos_mark"] as Label).visible or (slots[0]["neg_mark"] as Label).visible:
		failures.append("issue113: pure-positive boost should show only the + mark")
	if not (slots[1]["pos_mark"] as Label).visible or not (slots[1]["neg_mark"] as Label).visible:
		failures.append("issue113: mixed Cocktail boost should show both + and - marks")
	# A pure downside (Serum's blur tail) shows only the "-" mark.
	run_store.cocktailBoostSpins = 0
	run_store.decaySkips = 0
	run_store.blurReelsSpins = 2
	machine._refresh_boost_indicators()
	if (slots[0]["pos_mark"] as Label).visible or not (slots[0]["neg_mark"] as Label).visible:
		failures.append("issue113: pure-negative boost should show only the - mark")
	run_store.blurReelsSpins = 0
	run_store.cocktailBoostSpins = 2
	run_store.decaySkips = 3
	machine._refresh_boost_indicators()

	# Boosts end: icons clear.
	run_store.cocktailBoostSpins = 0
	run_store.decaySkips = 0
	machine._refresh_boost_indicators()
	if (slots[0]["slot"] as Control).visible or (slots[1]["slot"] as Control).visible:
		failures.append("issue76: boost icons lingered after the boosts ended")

	# A boost that just spent its final spin stays visible as "0"; the next lever press
	# clears that zero-state icon before the next spin begins.
	run_store.cocktailBoostSpins = 1
	machine._refresh_boost_indicators()
	var expiring: Array[Dictionary] = machine._capture_expiring_boost_counters()
	run_store.cocktailBoostSpins = 0
	machine._apply_expiring_boost_linger(expiring)
	machine._refresh_boost_indicators()
	if not (slots[0]["slot"] as Control).visible or (slots[0]["count"] as Label).text != "0":
		failures.append("issue76: final boost spin should linger as count 0")
	machine._clear_boost_zero_linger()
	if (slots[0]["slot"] as Control).visible:
		failures.append("issue76: boost count 0 icon did not clear on next lever press")

	run_store.pairBoostHiddenReels = 1
	run_store.pairBoostSpins = 1
	machine._refresh_consumable_fx()
	expiring = machine._capture_expiring_boost_counters()
	run_store.pairBoostSpins = 0
	machine._apply_expiring_boost_linger(expiring)
	machine._refresh_consumable_fx()
	if not (machine._tobacco_covers[2] as ColorRect).visible:
		failures.append("issue76: Cigarette hidden reel should stay visible at count 0")
	machine._clear_boost_zero_linger()
	if (machine._tobacco_covers[2] as ColorRect).visible:
		failures.append("issue76: Cigarette hidden reel did not clear on next lever press")
	run_store.pairBoostHiddenReels = 0

	# Serum negative now hides the above/below strip neighbours, leaving center symbols.
	machine._set_reel_symbol(0, "eye")
	machine._set_reel_visible(0, true)
	machine._set_adjacent_symbols_hidden_active(true)
	if not machine._reel_sprites[0].visible or machine._reel_top_sprites[0].visible or machine._reel_bottom_sprites[0].visible:
		failures.append("issue92: Serum negative did not hide adjacent reel symbols")
	machine._set_adjacent_symbols_hidden_active(false)
	if not machine._reel_top_sprites[0].visible or not machine._reel_bottom_sprites[0].visible:
		failures.append("issue92: adjacent reel symbols did not restore after Serum negative")

	machine._build_serum_picker()
	var serum_picker := machine._serum_picker as Control
	_check_symbol_picker_panel_63(serum_picker, 5, true, "issue63: Serum", failures)
	if serum_picker != null and serum_picker.find_child("SymbolButtonBrain", true, false) != null:
		failures.append("issue63: Serum picker should not offer brain")
	machine._close_serum_picker()

	# Potion popup uses normal popup text size and green/red by effect sign.
	if machine._potion_effect_color({ "kind": "lucidity", "amount": -5 }) != machine.potion_popup_negative_color:
		failures.append("issue92: negative Potion popup should use negative color")
	if machine._potion_effect_color({ "kind": "restorePower" }) != machine.potion_popup_color:
		failures.append("issue92: positive Potion popup should use positive color")
	var fx_count: int = machine._fx_layer.get_child_count()
	machine._show_potion_popup("POTION TEST", machine.potion_popup_negative_color)
	if machine._fx_layer.get_child_count() <= fx_count:
		failures.append("issue92: Potion popup did not spawn")
	else:
		var popup := machine._fx_layer.get_child(machine._fx_layer.get_child_count() - 1) as Label
		if popup == null or popup.get_theme_font_size("font_size") != 8:
			failures.append("issue92: Potion popup text should use popup font size 8")
		elif popup.get_theme_color("font_color") != machine.potion_popup_negative_color:
			failures.append("issue92: Potion popup did not use requested effect color")
		if popup != null:
			popup.queue_free()

	run_store.reset_run_state()

# Issue #76: the power gauge banks SCORE GAINED (10 score = 1 coin/frame, 50 = 5). Sub-10
# gains bank without a coin (no infinite loop), the gauge caps at 4/5 when no restore is
# available (discarding the excess, no fake-fill), and a fill commits one pending restore.
func _check_power_bar_76(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.runPhase = "running"

	if machine._power_bar_step() != 10:
		failures.append("issue76: power-bar step should be 10, got %d" % machine._power_bar_step())

	# Frame for a banked-score value.
	var expect := { 0: 0, 10: 1, 20: 2, 30: 3, 40: 4, 50: 5 }
	for score in expect:
		if machine._bar_frame_for_score(score) != expect[score]:
			failures.append("issue76: frame for score %d = %d, expected %d" % [score, machine._bar_frame_for_score(score), expect[score]])

	# Scoring 9 banks a partial (no coin) and does NOT loop — plan is empty, seen advances.
	machine._power_bar_score = 0
	machine._power_seen_lucidity = 0
	run_store.pendingPowerRestores = []
	run_store.lucidityCoins = 9
	var p9: Dictionary = machine._compute_power_plan()
	if not (p9["steps"] as Array).is_empty():
		failures.append("issue76: scoring 9 planned coins (should bank a partial, %d steps)" % (p9["steps"] as Array).size())
	if int(p9["score"]) != 9 or int(p9["seen"]) != 9:
		failures.append("issue76: scoring 9 mis-banked (score %d seen %d, expected 9/9)" % [int(p9["score"]), int(p9["seen"])])

	# 10 score => exactly 1 coin (frame 1). 50 => 5 coins.
	machine._power_bar_score = 0
	machine._power_seen_lucidity = 0
	run_store.lucidityCoins = 10
	if (machine._compute_power_plan()["steps"] as Array).size() != 1:
		failures.append("issue76: 10 score should be exactly 1 power coin")

	# No restorable power (no pending, no spent ability) + big gain: caps at 4/5 (score 40),
	# no restore step, no cycling.
	machine._power_bar_score = 0
	machine._power_seen_lucidity = 0
	run_store.pendingPowerRestores = []
	run_store.abilitiesUsed = []
	run_store.lucidityCoins = 200
	var cap: Dictionary = machine._compute_power_plan()
	var cap_restores := 0
	for s in (cap["steps"] as Array):
		if bool(s["restore"]):
			cap_restores += 1
	if cap_restores != 0:
		failures.append("issue76: gauge planned a restore with no restorable power")
	if int(cap["score"]) != 40:
		failures.append("issue76: no-restore gauge did not cap at 4/5 (score %d, expected 40)" % int(cap["score"]))

	# At 4/5, scoring 10 with a restore available => 1 coin, restore, reset to 0 (no refill).
	machine._power_bar_score = 40
	machine._power_seen_lucidity = 100
	run_store.pendingPowerRestores = ["reroll"]
	run_store.lucidityCoins = 110
	var atcap: Dictionary = machine._compute_power_plan()
	if (atcap["steps"] as Array).size() != 1 or not bool((atcap["steps"] as Array)[0]["restore"]):
		failures.append("issue76: 4/5 + 10 with a restore should be a single restore coin")
	if int(atcap["score"]) != 0:
		failures.append("issue76: after the restore the gauge should sit at 0, got %d" % int(atcap["score"]))

	# At 4/5 with NO pending but a SPENT ability, scoring 10 completes the fill and the
	# gauge restores the spent power itself (e.g. Water at 4/5 with a used power).
	machine._power_bar_score = 40
	machine._power_seen_lucidity = 100
	run_store.pendingPowerRestores = []
	run_store.abilitiesUsed = ["reroll"]
	run_store.lucidityCoins = 110
	var spent: Dictionary = machine._compute_power_plan()
	if (spent["steps"] as Array).size() != 1 or not bool((spent["steps"] as Array)[0]["restore"]):
		failures.append("issue76: 4/5 + 10 with a spent power should restore it (bar-driven)")

	# At 4/5, scoring 10 with NOTHING restorable => no coin, gauge stays 4/5, excess discarded.
	machine._power_bar_score = 40
	machine._power_seen_lucidity = 100
	run_store.pendingPowerRestores = []
	run_store.abilitiesUsed = []
	run_store.lucidityCoins = 110
	var stay: Dictionary = machine._compute_power_plan()
	if not (stay["steps"] as Array).is_empty() or int(stay["score"]) != 40:
		failures.append("issue76: 4/5 with nothing restorable should stay at 4/5 (score %d)" % int(stay["score"]))

	# A restore step consumes a pending restore first (front, once).
	run_store.abilitiesUsed = []
	run_store.pendingPowerRestores = ["reroll", "shift"]
	machine._apply_power_bank_step({ "frame": 5, "restore": true })
	if run_store.pendingPowerRestores != ["shift"]:
		failures.append("issue76: restore step did not commit exactly the front restore (%s)" % str(run_store.pendingPowerRestores))
	# With no pending but a spent ability, the restore step brings that ability back.
	run_store.pendingPowerRestores = []
	run_store.abilitiesUsed = ["shift"]
	machine._apply_power_bank_step({ "frame": 5, "restore": true })
	if run_store.abilitiesUsed.has("shift"):
		failures.append("issue76: bar-driven restore did not bring the spent ability back")
	machine._power_coins_in_flight = 0
	machine._power_batch_running = false

	run_store.reset_run_state()

# Issue #66: +3 spin grants (3x vial, Tea's fallback) fly a "+N" into the
# spins-left counter; the counter includes free spins and only ticks up when the
# fly-in lands (value in sync with the effect).
func _check_spin_gain_fx_66(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.neurons = 10
	run_store.startingNeurons = 105
	run_store.freeSpinsRemaining = 0
	# The REAL base cap (1): the user-reported bug was +3 grants clamping to +1.
	run_store.maxFreeSpins = 1
	machine._pending_spin_gain = 0
	machine._set_sequence_lock(false)
	machine._update_hud()
	var label := machine._bar_labels.get("life") as Label
	if label == null:
		failures.append("issue66: spins-left label missing")
		return
	var before_n := String(label.text).get_slice(":", 1).to_int()
	var life_fill := machine._life_fill_sprite as Sprite2D
	var before_bar_width := 0.0
	if life_fill != null:
		before_bar_width = life_fill.region_rect.size.x

	# 3x vial restores +3 normal spins, spawns the fly-in, and holds the counter.
	machine._apply_symbol_triple("vial", 0, false)
	if int(run_store.freeSpinsRemaining) != 0:
		failures.append("issue66: 3x vial created free-spin credits instead of restoring spins")
	if machine.get_node_or_null("SpinGainFx") == null:
		failures.append("issue66: vial grant did not spawn the +3 fly-in")
	if String(label.text).get_slice(":", 1).to_int() != before_n:
		failures.append("issue66: counter ticked before the vial fly-in landed")
	if life_fill != null and not is_equal_approx(life_fill.region_rect.size.x, before_bar_width):
		failures.append("issue66: spins bar filled before the vial fly-in landed")
	await create_timer(1.3).timeout
	if int(machine._pending_spin_gain) != 0:
		failures.append("issue66: pending spin gain never landed")
	var after_n := String(label.text).get_slice(":", 1).to_int()
	if after_n != before_n + 3:
		failures.append("issue66: counter did not gain +3 in sync (was %d, now %d)" % [before_n, after_n])
	if life_fill != null and life_fill.region_rect.size.x <= before_bar_width:
		failures.append("issue66: spins bar did not refill with the +3 vial grant")

	# Tea with no used powers restores +3 spins through the same fly-in.
	run_store.isSpinning = false
	run_store.dealerIncoming = false
	run_store.dealerPending = false
	run_store.freeSpinsRemaining = 0
	run_store.runConsumables = { "cons_tea": 1 }
	run_store.abilitiesUsed = []
	run_store.pendingPowerRestores = []
	machine._pending_spin_gain = 0
	machine._power_coins_in_flight = 0
	machine._power_batch_running = false
	machine._set_sequence_lock(false)
	machine._update_hud()
	var tea_before := String(label.text).get_slice(":", 1).to_int()
	machine._on_stash_pressed(0)
	if int(run_store.freeSpinsRemaining) != 0:
		failures.append("issue66: tea fallback created free-spin credits instead of restoring spins")
	if machine.get_node_or_null("SpinGainFx") == null:
		failures.append("issue66: tea restore did not spawn the +3 fly-in")
	if String(label.text).get_slice(":", 1).to_int() != tea_before:
		failures.append("issue66: counter ticked before the tea fly-in landed")
	await create_timer(1.3).timeout
	if String(label.text).get_slice(":", 1).to_int() != tea_before + 3:
		failures.append("issue66: tea +3 did not land in the spins counter")

	machine._pending_spin_gain = 0
	machine._set_sequence_lock(false)
	run_store.reset_run_state()

# Issue #80: the SPINS LEFT counter must drop with the neuron cost the instant the
# lever is pulled — while the HUD reward-delta hold (issue #54) is still active — and
# a free spin GRANTED by that spin stays hidden until the hold releases at the score.
func _check_spins_bar_lever_80(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.runPhase = "running"
	run_store.startingNeurons = 10
	run_store.neurons = 10
	run_store.freeSpinsRemaining = 0
	machine._pending_spin_gain = 0
	machine._held_spin_grant = 0
	machine._hud_delta_hold = false
	machine._set_sequence_lock(false)
	machine._update_hud()

	var label := machine._bar_labels.get("life") as Label
	if label == null:
		failures.append("issue80: spins-left label missing")
		run_store.reset_run_state()
		return
	var life_fill := machine._life_fill_sprite as Sprite2D
	var full_spins := String(label.text).get_slice(":", 1).to_int()
	var full_width := 0.0
	if life_fill != null:
		full_width = life_fill.region_rect.size.x

	# Lever pull: the reward-delta hold is on, and spin() has spent the neuron cost.
	machine._hud_delta_hold = true
	run_store.neurons = 2
	machine._update_hud()
	var during_hold := String(label.text).get_slice(":", 1).to_int()
	if during_hold >= full_spins:
		failures.append("issue80: SPINS LEFT did not drop on lever pull while the HUD was held")
	if life_fill != null and life_fill.region_rect.size.x >= full_width:
		failures.append("issue80: spins bar did not shrink on lever pull while the HUD was held")

	# A free spin granted by the same spin is held out of the counter until release.
	run_store.freeSpinsRemaining = 1
	machine._pending_spin_gain = 1
	machine._held_spin_grant = 1
	machine._update_hud()
	if String(label.text).get_slice(":", 1).to_int() != during_hold:
		failures.append("issue80: granted free spin appeared before the score popup landed")

	# Releasing the hold (score popup landed) pops the grant into the counter.
	machine._release_hud_delta_hold()
	if int(machine._held_spin_grant) != 0 or int(machine._pending_spin_gain) != 0:
		failures.append("issue80: hold release did not clear the held grant")
	if String(label.text).get_slice(":", 1).to_int() != during_hold + 1:
		failures.append("issue80: granted free spin did not pop into SPINS LEFT on release")

	machine._hud_delta_hold = false
	machine._pending_spin_gain = 0
	machine._held_spin_grant = 0
	run_store.reset_run_state()

# Issue #85/#80/#75: with a single 1:1 spin currency SPINS LEFT is just the neuron
# pool (plus banked free spins). The #80 drift (a +3 vial restore reading +4, a spin
# dropping the counter by 2) can't recur because neurons and spins no longer disagree,
# and there is no spin-count cap (issue #75): the counter reads straight off the neuron
# budget no matter how many spins have been taken.
func _check_spins_counter_accuracy_80(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.runPhase = "running"
	run_store.startingNeurons = EconomyConst.STARTING_NEURONS
	run_store.neurons = 20          # 1 neuron = 1 spin, well under the cap
	run_store.freeSpinsRemaining = 0
	run_store.spinCount = 0
	machine._pending_spin_gain = 0
	machine._held_spin_grant = 0
	machine._hud_delta_hold = false
	machine._set_sequence_lock(false)
	machine._update_hud()

	var label := machine._bar_labels.get("life") as Label
	if label == null:
		failures.append("issue80: spins-left label missing")
		run_store.reset_run_state()
		return
	var before := String(label.text).get_slice(":", 1).to_int()
	if before != 20:
		failures.append("issue85: SPINS LEFT should equal neurons=20, got %d" % before)

	# A +3 vial restore must move the counter by exactly +3 (read +4 under the rescale).
	machine._apply_symbol_triple("vial", 0, false)
	await create_timer(1.3).timeout # let the +3 fly-in land
	var after := String(label.text).get_slice(":", 1).to_int()
	if after != before + 3:
		failures.append("issue80: +3 vial restore moved SPINS LEFT by %d, expected 3" % (after - before))

	# No spin cap (issue #75): even after a huge number of spins, SPINS LEFT reads the
	# full neuron budget — 1:1, so neurons=100 => 100 spins — so spinning a lot never
	# strands the run.
	run_store.neurons = 100
	run_store.freeSpinsRemaining = 0
	run_store.spinCount = 500
	machine._pending_spin_gain = 0
	machine._held_spin_grant = 0
	machine._update_hud()
	var uncapped := String(label.text).get_slice(":", 1).to_int()
	if uncapped != 100:
		failures.append("issue75: SPINS LEFT should ignore spin count (read %d, expected 100)" % uncapped)

	machine._pending_spin_gain = 0
	machine._held_spin_grant = 0
	run_store.reset_run_state()

func _check_free_spin_multiplier_cost(run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.freeSpinsRemaining = 3
	run_store.maxFreeSpins = 3
	run_store.betMultiplier = 3
	var neurons_before := int(run_store.neurons)
	var result: Variant = run_store.spin()
	if result == null:
		failures.append("free-spin multiplier: x3 free spin did not spin")
		run_store.reset_run_state()
		return
	run_store.set_spinning(false)
	if not bool(result["isFreeSpin"]):
		failures.append("free-spin multiplier: spin was not marked free")
	if int(result["scoreMultiplier"]) != 3:
		failures.append("free-spin multiplier: x3 did not score as x3")
	# Issue #155: the auto frenzy gauge never drains banked free spins faster —
	# an x3 free spin still costs exactly one free spin.
	if int(run_store.freeSpinsRemaining) != 2:
		failures.append("free-spin multiplier: an x3 free spin should cost 1 free spin, left %d" % int(run_store.freeSpinsRemaining))
	if int(run_store.neurons) != neurons_before:
		failures.append("free-spin multiplier: free spin consumed neurons")
	run_store.reset_run_state()

# 3x eye: the player picks a reel; the pick arms the presentation-only reveal and
# the popup names the picked reel's rolled symbol.
# Issue #118: Shift joins Reroll ("Random") as an unconditional starting power,
# and Random must never redraw the symbol already sitting on its target reel.
func _check_starting_powers_and_random_118(run_store: Node, failures: Array) -> void:
	# Starting loadout: a fresh run with zero purchased permanents still has Shift
	# (perm_shift) and Reroll available, and this holds across restarts.
	for owned_permanents in [[], ["perm_memory"]]:
		run_store.reset_run_state()
		run_store.start_new_run(owned_permanents, {}, false)
		if not (run_store.ownedUpgrades as Array).has("perm_shift"):
			failures.append("issue118: new run did not start with Shift (perm_shift) owned=%s" % str(owned_permanents))
		run_store.reset_run_state()

	# Random candidate selection (pure): excludes the occupying symbol, and reports
	# no candidates when the pool degenerates to just that symbol.
	var full_weights: Array = Symbols.symbol_weights()
	var filtered: Array = Abilities.random_candidate_weights(full_weights, "brain")
	if filtered.size() != full_weights.size() - 1:
		failures.append("issue118: random_candidate_weights did not exclude the current symbol")
	for w in filtered:
		if String(w["value"]) == "brain":
			failures.append("issue118: random_candidate_weights left the current symbol in the pool")
	var degenerate := Abilities.random_candidate_weights([{ "weight": 5, "value": "brain" }], "brain")
	if not degenerate.is_empty():
		failures.append("issue118: random_candidate_weights should be empty when no alternative symbol exists")

	# Integration: Random never produces a no-op result, across many seeds/reels,
	# and repeats are deterministic for a given spin/reel pairing.
	run_store.start_new_run([], {}, false)
	run_store.neurons = 100
	for i in 12:
		var pre: Variant = run_store.spin()
		if pre == null:
			failures.append("issue118: setup spin failed at iteration %d" % i)
			break
		run_store.set_spinning(false)
		run_store.abilitiesUsed = [] # Random is once-per-spin, restored via lucidity coins in real play
		var reel_index := i % 3
		var before_symbol := String(pre["reels"][reel_index])
		var used: bool = run_store.reroll_reel(reel_index)
		if not used:
			failures.append("issue118: Random failed to fire on a normal spin (iteration %d)" % i)
			continue
		var after_symbol := String(run_store.lastResult["reels"][reel_index])
		if after_symbol == before_symbol:
			failures.append("issue118: Random produced a no-op result (%s -> %s)" % [before_symbol, after_symbol])
		if run_store.lastPowerFailureReason != "":
			failures.append("issue118: successful Random use left a stale failure reason")
	run_store.reset_run_state()

func _check_eye_reveal(machine: Node, failures: Array) -> void:
	# Issue #53: tapping a reel reveals its next-spin symbol INSTANTLY, and the
	# next spin honours the revealed promise.
	var run_store: Node = get_root().get_node("RunStateStore")
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.neurons = 100
	machine._reveal_reel_next_spin = -1
	machine._apply_symbol_triple("eye", 0, false)
	await process_frame # the picker arms deferred
	if machine._targeting_layer == null:
		failures.append("eye: 3x eye did not arm the reel-selection UI")
	var before := machine.get_child_count()
	machine._on_eye_reveal_pick(1)
	var revealed := String(run_store.eyeRevealSymbol)
	if revealed == "" or int(run_store.eyeRevealReel) != 1:
		failures.append("eye: tap did not roll/commit the next-spin symbol instantly")
	if int(machine._reveal_reel_next_spin) != 1:
		failures.append("eye: picking a reel did not store the early-stop target")
	if machine._targeting_layer != null:
		failures.append("eye: picking a reel did not clear the selection UI")
	if machine.get_child_count() <= before:
		failures.append("eye: reveal popup did not spawn at tap time")
	# The next spin's reel shows exactly the revealed symbol.
	var result: Variant = run_store.spin()
	run_store.set_spinning(false)
	if result == null or String(result["reels"][1]) != revealed:
		failures.append("eye: next spin did not honour the revealed symbol")
	if int(run_store.eyeRevealReel) != -1 or String(run_store.eyeRevealSymbol) != "":
		failures.append("eye: reveal commitment was not consumed by the spin")

	# Issue #65: Memory locking the revealed reel should keep the current symbol,
	# not the previously promised next-spin reveal.
	run_store.set_spinning(false)
	run_store.reset_run_state()
	run_store.start_new_run(["perm_memory"], {}, false)
	run_store.neurons = 100
	var setup_result: Variant = run_store.spin()
	run_store.set_spinning(false)
	if setup_result == null:
		failures.append("issue65: setup spin failed before reveal/lock check")
	else:
		var locked_symbol := String(setup_result["reels"][1])
		var promised_symbol := "brain" if locked_symbol != "brain" else "eye"
		run_store.eyeRevealReel = 1
		run_store.eyeRevealSymbol = promised_symbol
		run_store.lock_reel(1)
		if int(run_store.eyeRevealReel) != -1 or String(run_store.eyeRevealSymbol) != "":
			failures.append("issue65: locking the revealed reel did not clear the reveal promise")
		var locked_result: Variant = run_store.spin()
		run_store.set_spinning(false)
		if locked_result == null or String(locked_result["reels"][1]) != locked_symbol:
			failures.append("issue65: locked revealed reel changed from %s to %s" % [
				locked_symbol,
				("<null>" if locked_result == null else String(locked_result["reels"][1])),
			])
	machine._reveal_reel_next_spin = -1
	run_store.reset_run_state()

# Issue #51: TABLES overlay — no run stats, SYMBOL|LVL|PAIR|TRIPLE columns with
# bonus-effect blurbs, downscalable icons, no symbol names.
func _check_score_table_51(machine: Node, failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var run_store: Node = get_root().get_node("RunStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	var owned_before: Array = run_store.ownedUpgrades.duplicate()
	var bonuses_before: Dictionary = run_store.symbolRewardBonuses.duplicate(true)
	meta_store.oddsUpgrades = { "eye": 2, "vial": int(run_store.odds_max_level) }
	meta_store.rewardAmpSymbol = "eye"
	run_store.ownedUpgrades = ["corr_reward_amp_1"]
	run_store.symbolRewardBonuses = {
		"eye": 0.15,
		"vial": float(run_store.odds_max_level_reward_bonus),
	}
	machine._set_sequence_lock(false)
	machine._close_score_table()
	machine._show_score_table()
	var overlay: Control = machine._score_overlay
	if overlay == null:
		failures.append("issue51: score table did not open")
		run_store.ownedUpgrades = owned_before
		run_store.symbolRewardBonuses = bonuses_before
		meta_store._apply(meta_before)
		meta_store.save_state()
		return
	if machine._score_button != null and machine._score_button.text != "TABLES":
		failures.append("issue51: score button is not renamed TABLES")
	_check_start_menu_button_style(machine._score_button, Assets.START_MENU_BUTTON_CYAN,
		"issue51: TABLES", failures, true)
	_check_start_menu_press_feedback(machine._score_button, "issue51: TABLES", failures)
	var texts := _overlay_label_texts(overlay)
	for stat in ["BEST", "RUNS", "CREDITS"]:
		if texts.has(stat):
			failures.append("issue51: '%s' stat should be removed from the table" % stat)
	for symbol_name in ["BRAIN", "EYE", "PILL", "SYRINGE", "VIAL", "FLATLINE"]:
		if texts.has(symbol_name):
			failures.append("issue51: symbol names should be removed")
			break
	_check_points_table_119(machine, overlay, failures)
	if not texts.has("2"):
		failures.append("issue51: LVL column does not show the symbol's odds level")
	var found_amp_pair := false
	var found_amp_triple := false
	var found_max_level := false
	var found_max_level_bonus := false
	var found_max_line_bonus := false
	var expected_max_bonus := "+%d%%" % int(round(float(run_store.odds_max_level_reward_bonus) * 100.0))
	var eye_bonus := float(run_store.symbolRewardBonuses.get("eye", 0.0))
	var expected_amp_pair := "+%d" % floori(float(int(Payouts.PAIR_SCORE["eye"])) * (1.0 + eye_bonus) + 0.5)
	var expected_amp_triple := "+%d" % floori(float(int(Payouts.TRIPLE_SCORE["eye"])) * (1.0 + eye_bonus) + 0.5)
	var gain_debug: Array[String] = []
	for child in overlay.get_children():
		if child is Label:
			var label := child as Label
			var color := label.get_theme_color("font_color")
			if label.text.begins_with("+"):
				gain_debug.append("%s:%s" % [label.text, str(color)])
			if label.text == expected_amp_pair and color == Color(1.0, 0.86, 0.2):
				found_amp_pair = true
			if label.text == expected_amp_triple and color == Color(1.0, 0.86, 0.2):
				found_amp_triple = true
			if label.text == str(int(run_store.odds_max_level)) and color == Color(1.0, 0.24, 0.24):
				found_max_level = true
			if label.text == "(%s)" % expected_max_bonus and color == Color(1.0, 0.24, 0.24):
				found_max_level_bonus = true
			if label.text == expected_max_bonus and color == Color(1.0, 0.24, 0.24):
				found_max_line_bonus = true
		if child is TextureRect and (child as TextureRect).expand_mode != TextureRect.EXPAND_IGNORE_SIZE:
			failures.append("issue51: table icons cannot scale down (expand mode)")
			break
	if not found_amp_pair or not found_amp_triple:
		failures.append("issue51: reward amplification does not highlight pair/triple gains in yellow (%s)" % str(gain_debug))
	if not found_max_level or not found_max_level_bonus or not found_max_line_bonus:
		failures.append("issue51: maxed odds level bonus is not shown in red in the table")
	machine._close_score_table()
	run_store.ownedUpgrades = owned_before
	run_store.symbolRewardBonuses = bonuses_before
	meta_store._apply(meta_before)
	meta_store.save_state()

# Issue #119: authored points-table art, hold-to-peek triple-effect info buttons,
# and keyboard/controller focus navigation.
func _check_points_table_119(machine: Node, overlay: Control, failures: Array) -> void:
	var art := overlay.get_node_or_null("TableArt") as TextureRect
	if art == null or art.texture == null \
			or not art.texture.resource_path.ends_with("TABLES SCORE.png"):
		failures.append("issue119: table does not render the authored TABLES SCORE art")
	elif art.size != Vector2(160.0, 320.0):
		failures.append("issue119: table art is not full-canvas")
	elif art.expand_mode != TextureRect.EXPAND_IGNORE_SIZE:
		failures.append("issue119: table art cannot scale down to the canvas")

	var info_buttons: Array = machine._score_info_buttons
	if info_buttons.size() != Symbols.BASE_SYMBOL_CYCLE.size():
		failures.append("issue119: expected one info button per symbol row, got %d" % info_buttons.size())
		return
	for b in info_buttons:
		var button := b as Button
		if button.focus_mode != Control.FOCUS_ALL:
			failures.append("issue119: info button %s is not keyboard/controller focusable" % button.name)
		var icon := button.get_node_or_null("InfoIcon") as TextureRect
		if icon == null or not (icon.texture is AtlasTexture) \
				or not (icon.texture as AtlasTexture).atlas.resource_path.ends_with("TABLES SCORE_information.png"):
			failures.append("issue119: info button %s missing the authored 'i' art" % button.name)

	# Hold shows the triple effect; release hides it (plus a pressed squash).
	var eye_button := info_buttons[Symbols.BASE_SYMBOL_CYCLE.find("eye")] as Button
	eye_button.button_down.emit()
	var popup: Control = machine._score_info_popup
	if popup == null:
		failures.append("issue119: holding the info button did not open the effect popup")
	else:
		var popup_texts := _overlay_label_texts(popup)
		if not popup_texts.has("REVEALS A REEL"):
			failures.append("issue119: eye info popup missing its triple effect: %s" % str(popup_texts))
		var icon := eye_button.get_node("InfoIcon") as TextureRect
		if icon.scale == Vector2.ONE:
			failures.append("issue119: info button press did not start the pressed animation")
	eye_button.button_up.emit()
	if machine._score_info_popup != null:
		failures.append("issue119: releasing the info button did not hide the effect popup")

	# Focus chain: CLOSE holds initial focus and links down into the rows.
	var close := overlay.get_node_or_null("CloseButton") as Button
	if close == null:
		failures.append("issue119: table has no CLOSE button")
	else:
		_check_start_menu_button_style(close, Assets.START_MENU_BUTTON_YELLOW,
			"issue119: BACK", failures, true)
		if overlay.get_viewport() != null and overlay.get_viewport().gui_get_focus_owner() != close:
			failures.append("issue119: CLOSE did not take initial focus for keyboard/controller nav")
		# The chain interleaves each row's LVL pct-peek "i" before its effect
		# info button, so CLOSE links down into the first pct button (#153).
		var first_pct := machine._score_pct_buttons[0] as Button
		if close.get_node_or_null(close.focus_neighbor_bottom) != first_pct:
			failures.append("issue119: CLOSE does not link down to the first pct button")
		if first_pct.get_node_or_null(first_pct.focus_neighbor_top) != close:
			failures.append("issue119: first pct button does not link back up to CLOSE")
		if first_pct.get_node_or_null(first_pct.focus_neighbor_bottom) != info_buttons[0]:
			failures.append("issue119: first pct button does not link down to its info button")
	# Issue #153: holding the "i" under a row's LVL value peeks at the symbol's
	# live draw chance (moved off the baked symbol box, matching the odds table).
	if machine._score_pct_buttons.size() != 6:
		failures.append("score-pct: every row should have a pct-peek button under LVL")
	else:
		var pct_button := machine._score_pct_buttons[1] as Button
		pct_button.button_down.emit()
		var pct_popup: Control = machine._score_info_popup
		if pct_popup == null or pct_popup.name != "PctPopup":
			failures.append("score-pct: holding the LVL info button did not show the pct bubble")
		else:
			var panel := pct_popup.get_child(0) as Panel
			var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
			var expected: Color = machine.SCORE_TABLE_PCT_COLORS["eye"]
			if style == null or not style.border_color.is_equal_approx(expected):
				failures.append("score-pct: bubble contour is not the symbol row color")
		pct_button.button_up.emit()
		if machine._score_info_popup != null:
			failures.append("score-pct: releasing the LVL info button did not hide the pct bubble")

func _overlay_label_texts(overlay: Control) -> Array:
	var out: Array = []
	if overlay == null:
		return out
	for child in overlay.get_children():
		if child is Label:
			out.append((child as Label).text)
	return out

# Button-based taking: a tap selects (hints, no name, no purchase); TAKE buys the
# selected item. Drag-to-buy is gone.
func _check_dealer_offer_take_flow(overlay: Node, failures: Array) -> void:
	overlay._apply_side("left")
	var offers: Array[String] = ["item_water"]
	overlay._current_offer_ids = offers
	overlay._clear_offer_items()
	overlay._setup_items(offers)
	var selected: Array[String] = []
	overlay.item_selected.connect(func(item_id: String) -> void:
		selected.append(item_id)
	)
	overlay._select_offer("item_water")
	if not selected.is_empty():
		failures.append("take-flow: tapping an item bought it directly")
	var hint_layer := overlay.get_node("SpeechBubble/HintLayer") as Control
	var pos_hint := overlay.get_node("SpeechBubble/HintLayer/PositiveHint") as Label
	var name_hint := overlay.get_node("SpeechBubble/HintLayer/NameHint") as Label
	if not hint_layer.visible or pos_hint.text != "+ REFRESH":
		failures.append("take-flow: item tap did not reveal hint text")
	if name_hint.visible:
		failures.append("take-flow: item name should no longer show in the bubble")
	var neg_hint := overlay.get_node("SpeechBubble/HintLayer/NegativeHint") as Label
	overlay._select_offer("item_pill")
	if pos_hint.text != "+ WIN GUARANTEED" or neg_hint.text != "- CLOSE CALL":
		failures.append("take-flow: red pill hints are not using close-call/win-guaranteed copy")
	if neg_hint.position.y >= pos_hint.position.y:
		failures.append("take-flow: red pill negative hint should display above the positive hint")
	overlay._select_offer("item_water")
	var take := overlay.get_node("LookButton") as Button
	if take.disabled or take.text != "take":
		failures.append("take-flow: selecting an item did not arm the take button")
	overlay._on_look_pressed()
	if selected != ["item_water"]:
		failures.append("take-flow: take button did not buy the selected item")

func _check_base_scene_parity(failures: Array) -> void:
	for scene_path in [
		"res://scenes/shop_scene.tscn",
		"res://scenes/dealer_scene.tscn",
		"res://scenes/machine_scene.tscn",
	]:
		var ps := load(scene_path) as PackedScene
		if ps == null:
			failures.append("parity: %s failed to load" % scene_path)
			continue
		var scene := ps.instantiate()
		get_root().add_child(scene)
		var stash := scene.get_node_or_null("stash") as TextureRect
		if stash == null:
			failures.append("parity: %s missing authored stash tray" % scene_path)
		else:
			if stash.position != Vector2(106.0, 290.0) or stash.size != Vector2(48.0, 26.0):
				failures.append("parity: %s stash tray does not match authored shared layout: %s %s" % [scene_path, stash.position, stash.size])
			if stash.z_index < 50:
				failures.append("parity: %s stash tray can draw behind base art" % scene_path)
			for i in range(1, 3):
				var slot := stash.get_node_or_null("StashSlot%d" % i) as Control
				if slot == null:
					failures.append("parity: %s missing StashSlot%d" % [scene_path, i])
				elif slot.size != Vector2(16.0, 16.0):
					failures.append("parity: %s StashSlot%d is not 16x16: %s" % [scene_path, i, slot.size])
		scene.queue_free()

func _check_symbol_picker_panel_63(picker: Control, expected_symbols: int, expects_frame: bool,
		prefix: String, failures: Array) -> void:
	if picker == null:
		failures.append("%s picker was not built" % prefix)
		return
	var panel := picker.get_node_or_null("SymbolPickerPanel") as Control
	if panel == null:
		failures.append("%s picker is missing the shared panel" % prefix)
		return
	if panel.size.y < 54.0:
		failures.append("%s picker is too cramped: %s" % [prefix, panel.size])
	var cancel := panel.get_node_or_null("CancelButton") as Button
	if cancel == null or cancel.size.x < 10.0 or cancel.size.y < 9.0:
		failures.append("%s picker cancel target is missing or too small" % prefix)
	var title := panel.get_node_or_null("TitleLabel") as Label
	var frame := panel.get_node_or_null("Frame") as TextureRect
	var background := panel.get_node_or_null("Background") as ColorRect
	if expects_frame:
		if frame == null or frame.texture == null or frame.texture.resource_path.get_file() != "symbol_chosing.png":
			failures.append("%s picker did not use the symbol choosing art" % prefix)
		if background == null or background.size != Vector2.ZERO:
			failures.append("%s picker should not draw a generated fill behind the symbol choosing art" % prefix)
		if title == null or frame == null \
				or title.position.y < frame.position.y - 6.0 or title.position.y > frame.position.y + 1.0:
			failures.append("%s picker title should sit on the top band of the symbol choosing art" % prefix)
		if cancel == null or frame == null or cancel.position.y < frame.position.y:
			failures.append("%s picker cancel should sit on the symbol choosing art" % prefix)
	elif frame != null:
		failures.append("%s picker should use variable-count slots, not the five-slot art" % prefix)
	var buttons := panel.find_children("SymbolButton*", "Button", true, false)
	if buttons.size() != expected_symbols:
		failures.append("%s picker button count wrong: %d" % [prefix, buttons.size()])
	for node in buttons:
		var button := node as Button
		if button == null:
			continue
		if expects_frame:
			if button.size.x > 24.0 or button.size.y > 26.0:
				failures.append("%s picker framed hover target is too large: %s" % [prefix, button.size])
				break
		elif button.size.x < 20.0 or button.size.y < 40.0:
			failures.append("%s picker touch target too small: %s" % [prefix, button.size])
			break
		var icon := button.find_child("SymbolIcon*", true, false) as Sprite2D
		if icon == null or icon.texture == null:
			failures.append("%s picker button is missing an icon" % prefix)
			break
		var rendered_size := Vector2(float(icon.texture.get_width()) * icon.scale.x,
			float(icon.texture.get_height()) * icon.scale.y)
		if maxf(rendered_size.x, rendered_size.y) > 16.5:
			failures.append("%s picker icon did not scale down: %s" % [prefix, rendered_size])
			break
		if maxf(rendered_size.x, rendered_size.y) < 15.5:
			failures.append("%s picker icon is too small: %s" % [prefix, rendered_size])
			break
		if icon.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
			failures.append("%s picker icon should use reel-style mipmapped filtering" % prefix)
			break

func _check_upgrades_scene(failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	# This check mutates ownedPermanents (reward-amp tiers); snapshot the
	# current meta state so later checks see whatever they started with.
	var saved_permanents: Array = meta_store.ownedPermanents.duplicate()
	var ps := load("res://scenes/upgrades_scene.tscn") as PackedScene
	if ps == null:
		failures.append("upgrades: scene failed to load")
		return
	var scene := ps.instantiate()
	get_root().add_child(scene)
	await process_frame
	var expected := [
		"upgrades_scene_bg",
		"upgrades_scene_brain",
		"upgrades_scene_bubbles",
		"upgrades_scene_eye_brain_overlay",
		"upgrade_scene_memory_brain_overlay",
		"upgrades_scene_cables",
		"upgrades_scene_layer",
		"upgrades_scene_eye_upgrades",
		"upgrades_scene_memory_upgrades",
		"upgrades_scene_eye_buttons",
		"upgrades_scene_memory_buttons",
		"upgrades_scene_LAB_SIGN",
		"upgrades_scene_leak",
	]
	for i in expected.size():
		if scene.get_child(i).name != expected[i]:
			failures.append("upgrades: visual child %d should be %s, got %s" % [i, expected[i], scene.get_child(i).name])
			break
	var bg := scene.get_node("upgrades_scene_bg") as AnimatedSprite2D
	if bg.sprite_frames.get_frame_count(&"default") != 4 or bg.frame != 3:
		failures.append("upgrades: bg is not on static frame 4 by default")
	if bg.z_index != -100 or bg.top_level:
		failures.append("upgrades: bg z-index is not the back baseline")
	var brain := scene.get_node("upgrades_scene_brain") as AnimatedSprite2D
	if brain.z_index != -90:
		failures.append("upgrades: brain z-index is not above bg")
	if brain.sprite_frames.get_frame_count(&"default") != 15:
		failures.append("upgrades: brain layer does not expose 15 frames")
	if brain.sprite_frames.get_frame_texture(&"default", 0).get_width() > 1280:
		failures.append("upgrades: brain frames still use an oversized sheet texture")
	var bubbles := scene.get_node("upgrades_scene_bubbles") as AnimatedSprite2D
	if bubbles.sprite_frames.get_frame_texture(&"default", 0).get_width() > 1280:
		failures.append("upgrades: bubbles frames still use an oversized sheet texture")
	if bubbles.frame != 12:
		failures.append("upgrades: bubbles layer should rest on frame 13 by default")
	var eye_overlay := scene.get_node("upgrades_scene_eye_brain_overlay") as AnimatedSprite2D
	if eye_overlay.sprite_frames.get_frame_texture(&"default", 0).get_width() > 1280:
		failures.append("upgrades: eye brain overlay still uses an oversized sheet texture")
	var memory_overlay := scene.get_node("upgrade_scene_memory_brain_overlay") as AnimatedSprite2D
	if memory_overlay.sprite_frames.get_frame_texture(&"default", 0).get_width() > 1280:
		failures.append("upgrades: memory brain overlay still uses an oversized sheet texture")
	var eye_terminal := scene.get_node("upgrades_scene_eye_upgrades") as AnimatedSprite2D
	if eye_terminal.position != Vector2.ZERO:
		failures.append("upgrades: eye terminal node is not at native canvas origin")
	if eye_terminal.sprite_frames.get_frame_count(&"default") != 13:
		failures.append("upgrades: eye terminal should use the asset's 13 exact 1280px frames")
	var memory_terminal := scene.get_node("upgrades_scene_memory_upgrades") as AnimatedSprite2D
	if memory_terminal.sprite_frames.get_frame_count(&"default") != 11:
		failures.append("upgrades: memory terminal should use the asset's 11 exact 1280px frames")
	if scene.get_child(13).name != "CanvasLayer":
		failures.append("upgrades: CanvasLayer is not the foreground root after visual layers")
	var ui_container := scene.get_node("CanvasLayer/UI_Container") as Control
	if ui_container.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		failures.append("upgrades: UI_Container should ignore mouse outside child controls")
	var eye_hitbox := scene.get_node("CanvasLayer/UI_Container/EyeComputerHitbox") as Button
	var memory_hitbox := scene.get_node("CanvasLayer/UI_Container/MemoryComputerHitbox") as Button
	if eye_hitbox.position != Vector2(61.0, 6.0) or eye_hitbox.size != Vector2(61.0, 44.0):
		failures.append("upgrades: eye hitbox does not cover the eye terminal panel")
	if memory_hitbox.position != Vector2(1.0, 10.0) or memory_hitbox.size != Vector2(35.0, 45.0):
		failures.append("upgrades: memory hitbox does not cover the memory terminal panel")
	# Regression check: a later, stop-filtered sibling sitting on top of a
	# hitbox's center silently eats the click even though the hitbox itself
	# is wired up correctly (this is exactly how the empty MemoryUpgradePanel
	# used to swallow every click to MemoryComputerHitbox after its rows were
	# removed). Assert nothing else claims mouse input at either hitbox's center.
	for hitbox in [eye_hitbox, memory_hitbox]:
		var center: Vector2 = hitbox.position + hitbox.size / 2.0
		var seen_hitbox := false
		for sibling in ui_container.get_children():
			if sibling == hitbox:
				seen_hitbox = true
				continue
			if not seen_hitbox or not (sibling is Control):
				continue
			var sib := sibling as Control
			if sib.visible and sib.mouse_filter == Control.MOUSE_FILTER_STOP and sib.get_rect().has_point(center):
				failures.append("upgrades: %s sits on top of %s's center and would swallow its click" % [sib.name, hitbox.name])
	var coin_label := scene.get_node("CanvasLayer/UI_Container/LucidtyCoinDisplay/Label") as Label
	var coin_icon := scene.get_node("CanvasLayer/UI_Container/LucidtyCoinDisplay/Coin") as TextureRect
	if coin_label.text.contains("lucid") or coin_label.text.contains("coin"):
		failures.append("upgrades: wallet label still includes lucidity coin text")
	if coin_icon.texture == null:
		failures.append("upgrades: wallet display is missing lucidity coin icon")
	if coin_label.get_theme_color("font_color") != Color(0.92, 0.86, 0.56):
		failures.append("upgrades: wallet label is not using the shared lucidity yellow")
	if coin_label.horizontal_alignment != HORIZONTAL_ALIGNMENT_RIGHT:
		failures.append("upgrades: wallet label horizontal alignment should preserve the authored right setting")
	var eye_prev := scene.get_node("CanvasLayer/UI_Container/EyePrevButton") as Button
	var eye_next := scene.get_node("CanvasLayer/UI_Container/EyeNextButton") as Button
	var memory_prev := scene.get_node("CanvasLayer/UI_Container/MemoryPrevButton") as Button
	var memory_next := scene.get_node("CanvasLayer/UI_Container/MemoryNextButton") as Button
	if eye_prev.visible or eye_next.visible or memory_prev.visible or memory_next.visible:
		failures.append("upgrades: nav buttons should stay hidden before terminal activation")
	if not bool(scene.get("editor_preview_eye_active")) or not bool(scene.get("editor_preview_memory_active")):
		failures.append("upgrades: editor preview flags are not enabled for WYSIWYG layout")
	var description := scene.get_node("CanvasLayer/UI_Container/DescriptionBubble") as Control
	var description_label := scene.get_node("CanvasLayer/UI_Container/DescriptionBubble/DescriptionCenter/Text") as RichTextLabel
	var power_name_box := scene.get_node("CanvasLayer/UI_Container/PowerNameBox") as Control
	var power_name_label := scene.get_node("CanvasLayer/UI_Container/PowerNameBox/NamePriceRow/PowerNameLabel") as Label
	var context_buy := scene.get_node("CanvasLayer/UI_Container/ContextBuyButton") as Button
	var buy_stele := scene.get_node("CanvasLayer/UI_Container/BuyStele") as Sprite2D
	var context_price := scene.get_node("CanvasLayer/UI_Container/PowerNameBox/NamePriceRow/PriceGroup") as Control
	var price_label := scene.get_node("CanvasLayer/UI_Container/PowerNameBox/NamePriceRow/PriceGroup/PriceLabel") as Label
	var context_price_coin := scene.get_node("CanvasLayer/UI_Container/PowerNameBox/NamePriceRow/PriceGroup/Coin") as TextureRect
	if power_name_box.position.y >= description.position.y:
		failures.append("upgrades: power name box is not above the description bubble")
	if scene.get_node_or_null("CanvasLayer/UI_Container/ContextPriceDisplay") != null:
		failures.append("upgrades: contextual price should live inside PowerNameBox, not a separate panel")
	if context_price.get_node_or_null("PriceTitle") != null:
		failures.append("upgrades: contextual price should not include a PRICE title")
	if price_label.vertical_alignment != VERTICAL_ALIGNMENT_CENTER:
		failures.append("upgrades: price amount is not vertically centered")
	if power_name_label.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER or price_label.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER:
		failures.append("upgrades: power name and price amount are not horizontally centered")
	if context_buy.visible:
		failures.append("upgrades: contextual buy button should be hidden before selecting a power")
	if not buy_stele.visible:
		failures.append("upgrades: buy stele should be visible even before a terminal is open")
	_check_start_menu_button_style(context_buy, Assets.START_MENU_BUTTON_CYAN,
		"upgrades: BUY", failures, true)
	_check_start_menu_press_feedback(context_buy, "upgrades: BUY", failures)
	if context_buy.size != Vector2(22.0, 10.0):
		failures.append("upgrades: contextual buy button should keep its authored 22x10 stele-aligned size (got %s)" % str(context_buy.size))
	var context_buy_disabled_style := context_buy.get_theme_stylebox("disabled")
	if context_buy_disabled_style != null:
		if context_buy_disabled_style.content_margin_left != 0.0 or context_buy_disabled_style.content_margin_right != 0.0:
			failures.append("upgrades: contextual buy button disabled state has asymmetric text margins")
	if context_price.visible:
		failures.append("upgrades: contextual price should be hidden before selecting a power")
	if context_price_coin.texture == null:
		failures.append("upgrades: contextual price is missing lucidity coin icon")
	var back_button := scene.get_node("CanvasLayer/UI_Container/BackButton") as Button
	_check_start_menu_button_style(back_button, Assets.START_MENU_BUTTON_PINK,
		"upgrades: RETURN TO BAR", failures)
	_check_start_menu_press_feedback(back_button, "upgrades: RETURN TO BAR", failures)
	var power_style := power_name_box.get_theme_stylebox(&"panel") as StyleBoxFlat
	if power_style == null or not power_style.border_color.is_equal_approx(Color(0.42, 1.0, 0.95)):
		failures.append("upgrades: power name box is missing its cyan neon contour")
	var description_style := description.get_theme_stylebox(&"panel") as StyleBoxFlat
	if description_style == null or not description_style.border_color.is_equal_approx(Color(1.0, 0.5, 0.7)):
		failures.append("upgrades: description bubble is missing its pink neon contour")
	if back_button.z_index <= description.z_index:
		failures.append("upgrades: back button should render above description bubble")
	scene._activate_memory()
	if not scene.get_node("upgrade_scene_memory_brain_overlay").visible:
		failures.append("upgrades: memory activation did not reveal memory overlay")
	if scene.get_node("upgrades_scene_eye_brain_overlay").visible:
		failures.append("upgrades: memory activation revealed eye overlay")
	if not memory_prev.visible or not memory_next.visible:
		failures.append("upgrades: memory nav buttons did not appear after activating the memory terminal")
	if not context_buy.visible:
		failures.append("upgrades: contextual buy button did not appear for the memory terminal's first power")
	await process_frame
	if power_name_label.text != "Lock":
		failures.append("upgrades: memory carousel did not open on the Lock power")
	if context_buy.text != "BUY" and context_buy.text != "OWNED":
		failures.append("upgrades: contextual buy button includes price text")
	if context_buy.alignment != HORIZONTAL_ALIGNMENT_CENTER or context_buy.size.x < 22.0:
		failures.append("upgrades: contextual buy button text is not centered with enough width")
	if not context_price.visible:
		failures.append("upgrades: contextual price group did not appear for the memory carousel's first power")
	if context_price.position.x <= power_name_label.position.x:
		failures.append("upgrades: contextual price group is not aligned to the right of the power name")
	scene._memory_next()
	await process_frame
	if power_name_label.text != "Rewards+":
		failures.append("upgrades: reward amp did not show the shortened power name")
	if price_label.text != "30":
		failures.append("upgrades: reward amp tier I price is not shown in PowerNameBox")
	if not description_label.text.contains("[color=#183A8C]tier I[/color]"):
		failures.append("upgrades: reward amp tier I description is not blue BBCode")
	scene._build_reward_amp_picker("corr_reward_amp_1")
	var reward_picker := scene._reward_amp_picker as Control
	_check_symbol_picker_panel_63(reward_picker, 5, true, "issue63: Reward Amp", failures)
	if reward_picker != null:
		if reward_picker.find_child("SymbolButtonBrain", true, false) == null:
			failures.append("issue63: Reward Amp picker should include brain")
		if reward_picker.find_child("SymbolButtonFlatline", true, false) != null:
			failures.append("issue63: Reward Amp picker should not include flatline")
	if reward_picker != null:
		var cancel_button := reward_picker.get_node_or_null("SymbolPickerPanel/CancelButton") as Button
		if cancel_button != null:
			cancel_button.pressed.emit()
		await process_frame
		if scene._reward_amp_picker != null or String(scene._pending_reward_amp_upgrade_id) != "":
			failures.append("issue63: Reward Amp picker cancel did not close cleanly")
	# Simulate owning tier I/II so the "reward_amp" carousel slot resolves to the
	# next unpurchased tier, mirroring the old row's price/description swap.
	meta_store.ownedPermanents.append("corr_reward_amp_1")
	scene._refresh_all()
	if price_label.text != "55":
		failures.append("upgrades: reward amp tier II price should be 55")
	if not description_label.text.contains("[color=#FBBF24]tier II[/color]"):
		failures.append("upgrades: reward amp tier II description is not orange BBCode")
	meta_store.ownedPermanents.append("corr_reward_amp_2")
	scene._refresh_all()
	if price_label.text != "90":
		failures.append("upgrades: reward amp tier III price should be 90")
	if not description_label.text.contains("[color=#D62828]tier III[/color]"):
		failures.append("upgrades: reward amp tier III description is not red BBCode")
	meta_store.ownedPermanents.append("corr_reward_amp_3")
	scene._refresh_all()
	scene._memory_next()
	if power_name_label.text != "Saving":
		failures.append("upgrades: memory carousel did not advance to the Smart Save power")
	if price_label.text != "30":
		failures.append("upgrades: Smart Save price should be 30")
	scene._memory_next()
	if power_name_label.text != "???":
		failures.append("upgrades: memory carousel did not reach the locked/future slot")
	if context_buy.visible:
		failures.append("upgrades: contextual buy button should be hidden on the locked/future slot")
	if not buy_stele.visible:
		failures.append("upgrades: buy stele should stay visible on the memory locked/future slot")
	scene._memory_next()
	if power_name_label.text != "Lock":
		failures.append("upgrades: memory carousel did not wrap back to the first power")
	brain.frame = 7
	scene._sync_brain_overlay_frames()
	if memory_overlay.frame != 7:
		failures.append("upgrades: memory brain overlay is not synced to brain frame")
	scene._activate_eye()
	if memory_overlay.visible:
		failures.append("upgrades: eye activation did not hide memory overlay")
	if scene.get_node("upgrades_scene_memory_upgrades").frame != 0:
		failures.append("upgrades: eye activation did not reset memory terminal frame")
	if not eye_prev.visible or not eye_next.visible:
		failures.append("upgrades: eye nav buttons did not appear after activating the eye terminal")
	if not context_buy.visible:
		failures.append("upgrades: contextual buy button did not appear for the eye terminal's first power")
	if power_name_label.text != "Pattern Fabrication":
		failures.append("upgrades: eye carousel did not open on Pattern Fabrication")
	if price_label.text != "160":
		failures.append("upgrades: Pattern Fabrication price should be 160")
	scene._eye_next()
	if power_name_label.text != "Book Upgrade":
		failures.append("upgrades: eye carousel did not advance to the Book power")
	if price_label.text != "120":
		failures.append("upgrades: Learning price should be 120")
	scene._eye_next()
	await process_frame
	if power_name_label.text != "Hallucination":
		failures.append("upgrades: Hallucination did not show in the power name box")
	var hallucination_cost := int(Upgrades.upgrade_map()["pos_enlightenment"]["cost"])
	if price_label.text != str(hallucination_cost):
		failures.append("upgrades: Hallucination price should be %d" % hallucination_cost)
	if not description_label.text.contains("Visible pairs count as triples"):
		failures.append("upgrades: Hallucination description does not describe the rework")
	scene._eye_next()
	if power_name_label.text != "???":
		failures.append("upgrades: eye carousel did not reach the locked/future slot")
	if context_buy.visible:
		failures.append("upgrades: contextual buy button should be hidden on the eye locked/future slot")
	if not buy_stele.visible:
		failures.append("upgrades: buy stele should stay visible on the eye locked/future slot")
	scene._eye_prev()
	if power_name_label.text != "Hallucination":
		failures.append("upgrades: eye carousel prev did not step back from the locked slot")
	brain.frame = 11
	scene._sync_brain_overlay_frames()
	if eye_overlay.frame != 11:
		failures.append("upgrades: eye brain overlay is not synced to brain frame")
	scene._activate_memory()
	if eye_overlay.visible:
		failures.append("upgrades: memory activation did not hide eye overlay")
	if eye_terminal.frame != 0:
		failures.append("upgrades: memory activation did not reset eye terminal frame")
	await create_timer(0.2).timeout
	if brain.frame <= 0:
		failures.append("upgrades: brain layer did not animate while scene was ticking")
	# Issue #109: the closed computer terminals must read as buttons — the
	# contour light blinks on a short cycle, hover/focus holds it on, a press
	# dips it, and an open terminal (active UI, not a button) stays untinted.
	scene._reset_eye_terminal()
	scene._reset_memory_terminal()
	scene._refresh_all()
	for hitbox in [eye_hitbox, memory_hitbox]:
		if hitbox.mouse_entered.get_connections().is_empty() \
				or hitbox.focus_entered.get_connections().is_empty() \
				or hitbox.button_down.get_connections().is_empty():
			failures.append("issue109: %s has no hover/focus/press feedback wiring" % hitbox.name)
	scene._terminal_blink_time = float(scene.TERMINAL_BLINK_TIME) * 0.5
	scene._step_terminal_glow(0.0)
	if eye_terminal.self_modulate.r <= 1.0:
		failures.append("issue109: closed eye terminal contour does not light mid-blink")
	if memory_terminal.self_modulate != Color.WHITE:
		failures.append("issue109: memory terminal should blink on the opposite half-cycle")
	scene._terminal_blink_time = float(scene.TERMINAL_BLINK_MEMORY_OFFSET) \
		+ float(scene.TERMINAL_BLINK_TIME) * 0.5
	scene._step_terminal_glow(0.0)
	if memory_terminal.self_modulate.r <= 1.0:
		failures.append("issue109: closed memory terminal contour does not light mid-blink")
	scene._set_terminal_hot("eye", true)
	scene._step_terminal_glow(0.0)
	if eye_terminal.self_modulate.r <= 1.0:
		failures.append("issue109: hover/focus does not hold the eye terminal light on")
	scene._set_terminal_pressed("eye", true)
	scene._step_terminal_glow(0.0)
	if eye_terminal.self_modulate.r >= 1.0:
		failures.append("issue109: press does not dip the eye terminal light")
	scene._set_terminal_pressed("eye", false)
	scene._set_terminal_hot("eye", false)
	scene._activate_memory()
	scene._step_terminal_glow(0.0)
	if memory_terminal.self_modulate != Color.WHITE:
		failures.append("issue109: open memory terminal should render untinted")
	meta_store.ownedPermanents = saved_permanents
	scene.queue_free()

func _check_smart_save_retention(failures: Array) -> void:
	var run := { "neurons": 0, "lucidityCoins": 200, "scoreEarned": 0 }
	var meta := {
		"schemaVersion": 2,
		"lucidityWallet": 0,
		"ownedPermanents": [EconomyConst.SMART_SAVE_UPGRADE_ID],
		"corruptionEverUsed": false,
		"endingsReached": [],
		"pendingConsumables": {},
		"history": { "runsPlayed": 0, "bestScoreRun": 0 },
	}
	var banked := Endings.bank_run_to_meta(run, meta, "flatline", 1700000000000)
	if int(banked["lucidityWallet"]) != 40:
		failures.append("upgrades: Smart Save did not retain 20% of run lucidity")

func _check_issue27_machine_stash_drag(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.runPhase = "running"
	run_store.isSpinning = false
	run_store.neurons = 10
	run_store.spinCount = 0
	run_store.runConsumables = { "cons_focus": 1 }
	run_store.dealerOfferIds = ["item_water"]
	machine._update_hud()
	machine._show_dealer_offers()

	var popup = machine._dealer_offer_popup
	if popup == null:
		failures.append("issue27: machine did not create in-run dealer popup")
		return
	if machine._spin_button == null or not machine._spin_button.disabled:
		failures.append("issue27: spin button stayed enabled during dealer popup")
	var spin_count_before := int(run_store.spinCount)
	machine._do_spin()
	if int(run_store.spinCount) != spin_count_before or run_store.isSpinning:
		failures.append("issue27: machine accepted spin during dealer popup")
	if popup.get_node("StashLayer").get_child_count() != 0:
		failures.append("issue27: dealer popup contains duplicate stash")
	var stash_tray := machine.get_node_or_null("stash") as TextureRect
	if stash_tray == null:
		failures.append("issue27: machine stash tray missing")
	elif stash_tray.position.x < 0.0 or stash_tray.position.y < 0.0 \
			or stash_tray.position.x + stash_tray.size.x > 160.0 \
			or stash_tray.position.y + stash_tray.size.y > 320.0:
		failures.append("issue27: machine stash tray is outside canvas: %s %s" % [stash_tray.position, stash_tray.size])
	elif stash_tray.z_index < 1:
		failures.append("issue27: machine stash tray is not drawn above cabinet")
	if not machine._stash_icons[0].visible:
		failures.append("issue27: machine stash hidden during dealer popup")
	if machine._stash_icons[0].texture == null:
		failures.append("issue27: machine stash icon texture missing during dealer popup")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	machine._on_stash_input(press, machine._stash_icons[0], 0)
	if not machine._dealer_drag_active or machine._dealer_drag_kind != "stash":
		failures.append("issue27: machine stash did not start dealer drag")
		return
	machine._dealer_drag_moved = true
	machine._end_dealer_drag(popup._dealer_hit_rect().get_center())
	if Consumables.total_copies(run_store.runConsumables) != 0:
		failures.append("issue27: dropping machine stash on dealer did not discard it")
	machine._close_dealer()

func _check_issue28_machine_sequence_lock(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.runPhase = "running"
	run_store.isSpinning = false
	run_store.neurons = 10
	run_store.spinCount = 0
	run_store.runConsumables = {}
	run_store.dealerOfferIds = ["item_water"]
	machine._set_sequence_lock(true)
	if machine._spin_button == null or not machine._spin_button.disabled:
		failures.append("issue28: spin button stayed enabled during sequence lock")
	if machine._score_button == null or not machine._score_button.disabled:
		failures.append("issue28: score button stayed enabled during sequence lock")
	# Issue #155: the multiplier is a read-only frenzy gauge — there are no
	# multiplier buttons to lock anymore.
	var spin_count_before := int(run_store.spinCount)
	machine._do_spin()
	if int(run_store.spinCount) != spin_count_before or run_store.isSpinning:
		failures.append("issue28: sequence lock accepted spin input")
	machine._set_sequence_lock(false)

	machine._set_display_lucidity(0)
	var coin_duration: float = machine._spawn_lucidity_coins(3, 3)
	if coin_duration <= 0.0:
		failures.append("issue28: coin sequence did not report an animation duration")
	if machine._display_lucidity != 0:
		failures.append("issue28: wealth display updated before coins reached the bar")
	await create_timer(coin_duration + 0.05).timeout
	if machine._display_lucidity != 3:
		failures.append("issue28: wealth display did not update after coin contact")

# Issue #77: opening options and leaving the scene (Settings/Scores/Collection)
# mid-spin frees the animation that would call set_spinning(false), so the store's
# isSpinning stays true and the committed lastResult is never resolved. Re-entering
# the running machine (_sync_visuals) must run the same non-visual post-spin
# resolution: clear the spin lock for a live run, and resolve a terminal committed
# result into its ending instead of leaving a playable-but-dead machine.
func _check_options_spin_lock_77(machine: Node, run_store: Node, failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	# Keep this legacy re-entry assertion on a resumable campaign. Terminal campaign
	# exhaustion is covered by the dedicated game-over assertions above.
	meta_store.campaignNeuronsLeft = 5
	var prev_campaign_pending := bool(run_store.campaignNeuronPending)
	var prev_phase := String(run_store.runPhase)
	var prev_spinning := bool(run_store.isSpinning)
	var prev_compulsive := int(run_store.compulsiveSpinSkips)
	var prev_free := int(run_store.freeSpinsRemaining)
	var prev_neurons := int(run_store.neurons)
	var prev_starting := int(run_store.startingNeurons)
	var prev_score := int(run_store.scoreEarned)
	var prev_spin_count := int(run_store.spinCount)
	var prev_flat := int(run_store.flatlineResultCount)
	var prev_locked_spins: Array = run_store.lockedReelSpins.duplicate()
	var prev_locked: Array = run_store.lockedReels.duplicate()
	var prev_last: Variant = run_store.lastResult

	# startingNeurons = 0 keeps check_dealer_trigger a no-op so these cases stay
	# isolated from the dealer RNG; flatlineResultCount = 0 avoids a stray instant death.
	run_store.startingNeurons = 0
	run_store.flatlineResultCount = 0

	# Case 1 — live run: a non-terminal committed result interrupted mid-spin. Re-entry
	# clears the stale spin lock and re-enables the lever/powers.
	run_store.runPhase = "running"
	run_store.isSpinning = true
	run_store.compulsiveSpinSkips = 0
	run_store.freeSpinsRemaining = 0
	run_store.neurons = 8
	run_store.scoreEarned = 100
	run_store.spinCount = 1
	run_store.lockedReelSpins = [0, 0, 0]
	run_store.lockedReels = [false, false, false]
	run_store.lastResult = { "reels": ["brain", "eye", "vial"], "winType": "loss", "freeSpinsGranted": 0 }
	machine._spinning_anim = false
	machine._sequence_lock_active = false

	machine._sync_visuals()

	if bool(run_store.isSpinning):
		failures.append("issue77: returning to the machine left isSpinning stuck true")
	if not run_store._can_act():
		failures.append("issue77: machine stayed non-actionable after returning from options")
	machine._refresh_controls()
	if machine._spin_button == null or machine._spin_button.disabled:
		failures.append("issue77: lever stayed disabled after returning from options mid-spin")
	if machine._overlay != null:
		failures.append("issue77: live-run re-entry wrongly showed an ending overlay")

	# Case 2 — terminal committed result (neurons drained to 0, no free spins). The
	# interrupted spin banked a flatline result; re-entry must resolve the ending, NOT
	# leave a playable-but-dead machine (owner review on PR #82).
	run_store.runPhase = "running"
	run_store.isSpinning = true
	run_store.compulsiveSpinSkips = 0
	run_store.freeSpinsRemaining = 0
	run_store.neurons = 0
	run_store.scoreEarned = 100
	run_store.spinCount = 2
	run_store.lastResult = { "reels": ["brain", "eye", "vial"], "winType": "loss", "freeSpinsGranted": 0 }
	machine._spinning_anim = false
	machine._sequence_lock_active = false

	machine._sync_visuals()

	if bool(run_store.isSpinning):
		failures.append("issue77: terminal re-entry left isSpinning stuck true")
	if String(run_store.runPhase) == "running":
		failures.append("issue77: terminal committed result did not end the run on re-entry")
	if String(run_store.lastEnding) != "flatline":
		failures.append("issue77: terminal re-entry ended as %s, expected flatline" % str(run_store.lastEnding))
	if machine._overlay == null:
		failures.append("issue77: terminal re-entry showed no ending overlay")
	if machine._overlay != null:
		machine._overlay.queue_free()
		machine._overlay = null
	machine._stop_flatline_countdown()

	# Case 3 — a non-spinning re-entry must NOT spuriously decrement locked-reel counters.
	run_store.runPhase = "running"
	run_store.isSpinning = false
	run_store.lockedReelSpins = [2, 0, 0]
	run_store.lockedReels = [true, false, false]
	machine._sync_visuals()
	if int(run_store.lockedReelSpins[0]) != 2:
		failures.append("issue77: idle re-entry wrongly decremented a locked reel")

	machine._set_stash_tray_visible(true)
	run_store.runPhase = prev_phase
	run_store.campaignNeuronPending = prev_campaign_pending
	run_store.isSpinning = prev_spinning
	run_store.compulsiveSpinSkips = prev_compulsive
	run_store.freeSpinsRemaining = prev_free
	run_store.neurons = prev_neurons
	run_store.startingNeurons = prev_starting
	run_store.scoreEarned = prev_score
	run_store.spinCount = prev_spin_count
	run_store.flatlineResultCount = prev_flat
	run_store.lockedReelSpins = prev_locked_spins
	run_store.lockedReels = prev_locked
	run_store.lastResult = prev_last
	meta_store._apply(meta_before)
	meta_store.save_state()

## Issue #96: a pending compulsion must resolve before the dealer takes the scene.
## If the dealer pops (and later closes) while compulsiveSpinSkips>0, the player is
## locked out of acting and nothing re-queues the forced spin → softlock. Closing the
## dealer with a compulsion pending must hand the scene to the compulsive takeover.
func _check_dealer_compulsion_softlock_96(machine: Node, run_store: Node, failures: Array) -> void:
	var prev_phase := String(run_store.runPhase)
	var prev_spinning := bool(run_store.isSpinning)
	var prev_compulsive := int(run_store.compulsiveSpinSkips)
	var prev_offers: Variant = run_store.dealerOfferIds
	var prev_incoming := bool(run_store.dealerIncoming)
	var prev_pending := bool(run_store.dealerPending)

	run_store.runPhase = "running"
	run_store.isSpinning = false
	run_store.neurons = 100
	run_store.spinCount = 0
	run_store.runConsumables = {}
	machine._hud_delta_hold = false
	machine._compulsive_queued = false
	machine._set_sequence_lock(false)

	# A compulsion is pending while the dealer is mid-visit.
	run_store.compulsiveSpinSkips = 1
	run_store.dealerPending = true
	run_store.dealerOfferIds = ["item_water"]
	machine._show_dealer_offers()
	if machine._dealer_offer_popup == null:
		failures.append("issue96: dealer popup did not open for setup")

	# Dealer closes — the machine must take the forced spin, not sit idle while the
	# player is locked out.
	machine._close_dealer()
	if run_store._can_act():
		failures.append("issue96: player could act while a compulsion was still pending")
	if not machine._compulsive_queued:
		failures.append("issue96: closing the dealer with a pending compulsion softlocked (no compulsive spin queued)")

	# Neutralize the queued takeover before its timer auto-spins, then restore state.
	run_store.compulsiveSpinSkips = 0
	machine._compulsive_queued = false
	machine._hide_compulsive_overlay()
	machine._close_dealer()
	machine._set_sequence_lock(false)
	run_store.runPhase = prev_phase
	run_store.isSpinning = prev_spinning
	run_store.compulsiveSpinSkips = prev_compulsive
	run_store.dealerOfferIds = prev_offers
	run_store.dealerIncoming = prev_incoming
	run_store.dealerPending = prev_pending

func _check_machine_reactions_35(machine: Node, run_store: Node, failures: Array) -> void:
	# Save the state this check mutates.
	var prev_phase := String(run_store.runPhase)
	var prev_last: Variant = run_store.lastResult
	var prev_spin := int(run_store.spinCount)
	var prev_free := int(run_store.freeSpinsRemaining)
	var prev_maxfree := int(run_store.maxFreeSpins)
	var prev_flat := int(run_store.flatlineResultCount)
	var prev_abilities: Array = run_store.abilitiesUsed.duplicate()
	var prev_cons: Dictionary = run_store.runConsumables.duplicate(true)
	var prev_lastused := String(run_store.lastUsedConsumableId)

	run_store.runPhase = "running"
	run_store.maxFreeSpins = 10
	run_store.freeSpinsRemaining = 0
	run_store.abilitiesUsed = ["reroll"]

	# grant_free_spins adds in full — reaction rewards ignore maxFreeSpins, which
	# only caps the parity-pinned in-spin jackpot grant (issue #66).
	run_store.grant_free_spins(3)
	if int(run_store.freeSpinsRemaining) != 3:
		failures.append("issue35: grant_free_spins did not add spins")
	run_store.maxFreeSpins = 1
	run_store.grant_free_spins(3)
	if int(run_store.freeSpinsRemaining) != 6:
		failures.append("issue66: grant_free_spins clamped a reaction reward")
	run_store.maxFreeSpins = 10
	run_store.freeSpinsRemaining = 0

	# restore_all_powers clears the used-abilities list.
	run_store.restore_all_powers()
	if not run_store.abilitiesUsed.is_empty():
		failures.append("issue35: restore_all_powers did not clear abilities")

	# recover_last_consumable honours the last-used id and the slot cap.
	run_store.runConsumables = {}
	run_store.lastUsedConsumableId = "cons_tea"
	if not run_store.recover_last_consumable(2) or int(run_store.runConsumables.get("cons_tea", 0)) != 1:
		failures.append("issue35: recover_last_consumable did not restore a copy")
	run_store.runConsumables = { "cons_tea": 1, "cons_focus": 1 }
	if run_store.recover_last_consumable(2):
		failures.append("issue35: recover_last_consumable ignored the slot cap")

	# Brains triple grants a spin when power-triggered (pinned evaluate granted none)...
	run_store.freeSpinsRemaining = 0
	run_store.spinCount = 5
	run_store.lastResult = { "reels": ["brain", "brain", "brain"], "freeSpinsGranted": 0, "winType": "jackpot" }
	machine._last_reacted_reels = []
	machine._last_reacted_spin = -1
	machine._apply_machine_reactions(true)
	if int(run_store.freeSpinsRemaining) < 1:
		failures.append("issue35: brains triple did not grant a free spin when power-triggered")

	# ...but must NOT double-grant on a natural brains triple (evaluate already granted).
	run_store.freeSpinsRemaining = 0
	run_store.spinCount = 6
	run_store.lastResult = { "reels": ["brain", "brain", "brain"], "freeSpinsGranted": 2, "winType": "jackpot" }
	machine._last_reacted_reels = []
	machine._last_reacted_spin = -1
	machine._apply_machine_reactions(false)
	if int(run_store.freeSpinsRemaining) != 0:
		failures.append("issue35: brains triple double-granted on a natural spin")

	# Three flatline results accumulate and route to the instant-death fatal path.
	run_store.flatlineResultCount = 0
	machine.fatal_flatline_count = 3
	for i in 3:
		run_store.spinCount = 10 + i
		run_store.lastResult = { "reels": ["flatline", "flatline", "flatline"], "freeSpinsGranted": 0, "winType": "triple" }
		machine._last_reacted_reels = []
		machine._last_reacted_spin = -1
		machine._apply_machine_reactions(false)
	if int(run_store.flatlineResultCount) != 3:
		failures.append("issue35: flatline results did not accumulate")
	# Instant death routes through the normal flatline ending (banks the run), so
	# snapshot the meta store and restore it after the overlay assertions.
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	# The fatal title only shows when the campaign is truly out of neurons.
	meta_store.campaignNeuronsLeft = 0
	if not machine._check_flatline_instant_death():
		failures.append("issue35: fatal flatline count did not trigger instant death")
	if machine._overlay == null:
		failures.append("issue35: instant death did not show the flatline ending overlay")
	else:
		var fatal_found := false
		for child: Node in machine._overlay.find_children("*", "Label", true, false):
			if (child as Label).text == "this time, it's fatal. No coming back":
				fatal_found = true
		if not fatal_found:
			failures.append("issue38: flatline ending is missing the byte-exact fatal title")
	meta_store._apply(meta_before)
	meta_store.save_state()

	# Restore mutated state.
	run_store.lastResult = prev_last
	run_store.spinCount = prev_spin
	run_store.freeSpinsRemaining = prev_free
	run_store.maxFreeSpins = prev_maxfree
	run_store.flatlineResultCount = prev_flat
	run_store.abilitiesUsed = prev_abilities
	run_store.runConsumables = prev_cons
	run_store.lastUsedConsumableId = prev_lastused
	run_store.runPhase = prev_phase

# Augmented Run (issue #111): unlock persistence and the four suit modifiers.
func _check_augmented_run_111(machine: Node, run_store: Node, meta_store: Node, failures: Array) -> void:
	var meta_before: Dictionary = meta_store._as_dict()
	var prev_tier := String(run_store.augmentedTier)
	var prev_phase := String(run_store.runPhase)
	var prev_powers := int(run_store.powersUsedThisSpin)

	# Unlock: banking a wealth run sets the permanent flag, and it survives a
	# fresh campaign (unlike wealthEndingReached) plus a save round-trip.
	meta_store.augmentedRunUnlocked = false
	meta_store.bank_run({ "lucidityCoins": 0, "scoreEarned": 0, "neurons": 1 }, "wealth")
	if not bool(meta_store.augmentedRunUnlocked):
		failures.append("issue111: wealth bank did not unlock Augmented Run")
	meta_store.start_new_campaign(false)
	if not bool(meta_store.augmentedRunUnlocked):
		failures.append("issue111: a new campaign wiped the Augmented unlock")
	var round_trip: Dictionary = meta_store._as_dict()
	if not bool(round_trip.get("augmentedRunUnlocked", false)):
		failures.append("issue111: unlock flag missing from the save payload")

	# Tier mapping: each suit activates exactly its modifier; joker all four.
	run_store.augmentedTier = "heart"
	if not run_store.augmented_modifier_active(1) or run_store.augmented_modifier_active(2):
		failures.append("issue111: heart should map to modifier 1 only")
	run_store.augmentedTier = "joker"
	for m in [1, 2, 3, 4]:
		if not run_store.augmented_modifier_active(m):
			failures.append("issue111: joker should activate modifier %d" % m)
			break
	run_store.augmentedTier = ""
	if run_store.augmented_modifier_active(1):
		failures.append("issue111: classic runs must activate no modifier")

	# Diamond: the third power use of a spin is refused.
	run_store.augmentedTier = "diamond"
	run_store.runPhase = "running"
	run_store.isSpinning = false
	run_store.compulsiveSpinSkips = 0
	run_store.blockPowersSpins = 0
	run_store.powersUsedThisSpin = 2
	if run_store._can_use_ability():
		failures.append("issue111: diamond did not block the third power of a spin")
	run_store.powersUsedThisSpin = 1
	if run_store.lastResult != null and not run_store._can_use_ability():
		failures.append("issue111: diamond blocked the second power of a spin")

	# Club: dealer visits and spin rewards are halved. With the issue #155 fixed
	# countdown, "half the visits" means the reset value doubles (8 -> 16).
	run_store.augmentedTier = ""
	var base_reset: int = run_store.dealer_countdown_reset_value()
	var base_scale: float = run_store._active_reward_scale()
	run_store.augmentedTier = "club"
	if int(run_store.dealer_countdown_reset_value()) != base_reset * 2:
		failures.append("issue111: club did not double the dealer countdown reset")
	if not is_equal_approx(run_store._active_reward_scale(), base_scale * 0.5):
		failures.append("issue111: club did not halve the spin reward scale")

	# Spade: the banked end-of-run gain is halved (10% -> 5%).
	run_store.augmentedTier = "spade"
	meta_store.ownedPermanents = []
	meta_store.lucidityWallet = 0
	meta_store.bank_run({ "lucidityCoins": 200, "scoreEarned": 0, "neurons": 1 }, "flatline")
	if int(meta_store.lucidityWallet) != 10:
		failures.append("issue111: spade banked %d of 200, expected 5%% = 10" % int(meta_store.lucidityWallet))
	if not is_equal_approx(machine._end_run_lucidity_kept_fraction(), 0.05):
		failures.append("issue111: machine kept-fraction display does not match the spade bank")

	# Heart: the machine no longer tops up a brain-triple free spin.
	run_store.augmentedTier = "heart"
	var spins_before := int(run_store.freeSpinsRemaining)
	machine._apply_symbol_triple("brain", 0, false)
	if int(run_store.freeSpinsRemaining) != spins_before:
		failures.append("issue111: heart brain triple still granted a free spin")
	# Heart: the TABLES popup shows the halved jackpot value.
	machine._close_score_table()
	machine._show_score_table()
	if machine._score_overlay == null:
		failures.append("issue111: score table failed to open for the heart check")
	else:
		var table_texts := _overlay_label_texts(machine._score_overlay)
		if not table_texts.has("+100"):
			failures.append("issue111: score table does not show the heart jackpot (+100)")
		if table_texts.has("+200"):
			failures.append("issue111: score table still shows the classic jackpot (+200)")
	machine._close_score_table()
	# Heart: the jackpot's evaluated score is halved (200 -> 100), classic isn't.
	if int(run_store._augmented_jackpot_cut(200, "jackpot")) != 100:
		failures.append("issue111: heart did not cut the jackpot score to 100")
	if int(run_store._augmented_jackpot_cut(200, "triple")) != 0:
		failures.append("issue111: heart cut a non-jackpot win")
	# Heart applies after the Flatline boost: a 200-point jackpot doubled to 400
	# still pays 200, rather than subtracting only the original 100-point cut.
	var jackpot_base_score := 200
	var flatline_jackpot_boost := jackpot_base_score * (EconomyConst.FLATLINE_WIN_BOOST_MULT - 1)
	var adjusted_jackpot: Dictionary = run_store._apply_augmented_jackpot(
		jackpot_base_score + flatline_jackpot_boost, "jackpot")
	if int(adjusted_jackpot["score"]) != jackpot_base_score \
			or int(adjusted_jackpot["cut"]) != jackpot_base_score:
		failures.append("issue111: heart did not halve the boosted jackpot payout")
	run_store.augmentedTier = ""
	if int(run_store._augmented_jackpot_cut(200, "jackpot")) != 0:
		failures.append("issue111: classic runs must not cut the jackpot")

	# The tier survives start_new_run (menu -> pre-run shop -> run handoff).
	run_store.runPhase = "idle"
	run_store.augmentedTier = "heart"
	var prev_neurons_left := int(meta_store.campaignNeuronsLeft)
	meta_store.campaignNeuronsLeft = maxi(prev_neurons_left, 1)
	if run_store.start_new_run([], {}, false):
		if String(run_store.augmentedTier) != "heart":
			failures.append("issue111: start_new_run dropped the augmented tier")
	else:
		failures.append("issue111: start_new_run refused a plain fresh run")
	meta_store.campaignNeuronsLeft = prev_neurons_left

	# A full run reset clears the tier; starting a new run keeps it.
	run_store.augmentedTier = "club"
	run_store.reset_run_state()
	if String(run_store.augmentedTier) != "":
		failures.append("issue111: reset_run_state kept the augmented tier")

	meta_store._apply(meta_before)
	meta_store.save_state()
	run_store.reset_run_state()
	run_store.augmentedTier = prev_tier
	run_store.runPhase = prev_phase
	run_store.powersUsedThisSpin = prev_powers

# Run persistence (issue #111 follow-up): a live run survives an app restart so
# the menu can offer CONTINUE; ending the run deletes the snapshot.
func _check_run_persistence_111(run_store: Node, failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	meta_store.campaignActive = true
	meta_store.campaignFailed = false
	meta_store.wealthEndingReached = false
	meta_store.campaignNeuronsLeft = int(meta_store.campaignNeuronsMax)
	run_store.reset_run_state()
	var campaign_neurons_before := int(meta_store.campaignNeuronsLeft)
	if not run_store.start_new_run([], {}, true):
		failures.append("persistence: a fresh run could not be prepared")
	elif int(meta_store.campaignNeuronsLeft) != campaign_neurons_before \
			or not bool(run_store.campaignNeuronPending):
		failures.append("persistence: campaign neuron was consumed before machine end")
	run_store.end_run("flatline")
	if int(meta_store.campaignNeuronsLeft) != campaign_neurons_before - 1 \
			or bool(run_store.campaignNeuronPending):
		failures.append("persistence: campaign neuron was not consumed at machine end")
	run_store.reset_run_state()
	meta_store._apply(meta_before)
	meta_store.save_state()

	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.scoreEarned = 123
	run_store.augmentedTier = "heart"
	run_store.betMultiplier = 2
	run_store._commit() # snapshots the live run to disk
	if not FileAccess.file_exists(run_store.RUN_SAVE_PATH):
		failures.append("persistence: a live run did not write its snapshot")
	# Simulate a fresh launch: wipe the in-memory state WITHOUT committing, then
	# load the snapshot back like the autoload's _ready does.
	run_store.runPhase = "idle"
	run_store.scoreEarned = 0
	run_store.augmentedTier = ""
	run_store.betMultiplier = 1
	run_store.load_run_state()
	if String(run_store.runPhase) != "running" or int(run_store.scoreEarned) != 123 \
			or String(run_store.augmentedTier) != "heart" or int(run_store.betMultiplier) != 2:
		failures.append("persistence: restart did not restore the live run")
	# A dealer pre-run is also resumable, but it must return to the dealer rather
	# than skipping straight to the machine.
	run_store.reset_run_state()
	run_store.begin_pre_run()
	run_store.augmentedTier = "heart"
	run_store._commit()
	run_store.runPhase = "idle"
	run_store.augmentedTier = ""
	run_store.load_run_state()
	if String(run_store.runPhase) != "pre_run" or String(run_store.augmentedTier) != "heart":
		failures.append("persistence: dealer pre-run was not restored")
	# A post-flatline dealer visit remains resumable before and after its odds
	# phase; a new run or GIVE UP owns the explicit reset.
	run_store.reset_run_state()
	run_store.runPhase = "over"
	run_store.lastEnding = "flatline"
	run_store.scoreEarned = 210
	run_store.lucidityCoins = 210
	run_store.oddsPhaseCompleted = false
	meta_store.campaignNeuronsLeft = maxi(1, int(meta_store.campaignNeuronsLeft))
	meta_store.lucidityWallet = 10
	var dealer := (load("res://scenes/dealer_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(dealer)
	if not bool(dealer._post_run):
		failures.append("persistence: dealer did not identify the finished-run visit")
	dealer._on_options_return_to_menu()
	if String(run_store.runPhase) != "over" or not run_store.has_resume_state():
		failures.append("persistence: leaving pending odds dealer lost the resumable state")
	if not FileAccess.file_exists(run_store.RUN_SAVE_PATH):
		failures.append("persistence: post-run dealer did not retain its restart snapshot")
	dealer.queue_free()
	# Simulate a fresh launch while the post-run dealer visit is still held.
	run_store.runPhase = "idle"
	run_store.lastEnding = null
	run_store.scoreEarned = 0
	run_store.lucidityCoins = 0
	run_store.load_run_state()
	if String(run_store.runPhase) != "over" or String(run_store.lastEnding) != "flatline" \
			or int(run_store.scoreEarned) != 210 or int(run_store.lucidityCoins) != 210:
		failures.append("persistence: restart did not restore the post-run dealer session")
	var start_menu := (load("res://scenes/start_menu_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(start_menu)
	start_menu._refresh_start_button()
	var start_button := start_menu._start_button as Button
	if start_button == null or start_button.text != "CONTINUE":
		failures.append("persistence: pending odds dealer should show CONTINUE on the menu")
	start_menu._show_continue_modal()
	var post_run_stats := start_menu.get_node_or_null("ContinueModal/Panel/Stats") as Label
	if post_run_stats == null or post_run_stats.text != "CURRENT COINS : 10":
		failures.append("persistence: post-run CONTINUE modal lost the dealer wallet")
	run_store.oddsPhaseCompleted = true
	var finalized_dealer := (load("res://scenes/dealer_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(finalized_dealer)
	finalized_dealer._on_options_return_to_menu()
	if String(run_store.runPhase) != "over" or not run_store.has_resume_state():
		failures.append("persistence: finalized odds dealer lost the CONTINUE state")
	start_menu._refresh_start_button()
	if start_button == null or start_button.text != "CONTINUE":
		failures.append("persistence: returning after odds completion should still show CONTINUE")
	finalized_dealer.queue_free()
	start_menu.queue_free()
	# Ending the run removes the snapshot so a stale CONTINUE can't appear.
	run_store.reset_run_state()
	if FileAccess.file_exists(run_store.RUN_SAVE_PATH):
		failures.append("persistence: reset left a stale run snapshot behind")

# Issue #151: a save written after the final neuron drain but before the post-spin
# ending check must resolve to an ending when the machine scene is rebuilt.
func _check_save_resume_151(machine: Node, run_store: Node, failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	meta_store.campaignActive = true
	meta_store.campaignFailed = false
	meta_store.wealthEndingReached = false
	meta_store.campaignNeuronsLeft = maxi(1, int(meta_store.campaignNeuronsMax))
	# campaignNeuronsLeft >= 1 and campaignNeuronPending == false keep this as flatline.

	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.neurons = 0
	run_store.freeSpinsRemaining = 0
	run_store.isSpinning = false
	run_store.scoreEarned = 123
	run_store.lastResult = {
		"reels": ["brain", "eye", "vial"],
		"winType": "miss",
		"freeSpinsGranted": 0,
	}
	run_store._commit()
	if not FileAccess.file_exists(run_store.RUN_SAVE_PATH):
		failures.append("issue151: exhausted running save was not written")

	# Re-enter through the same autoload load path used after an app restart.
	run_store.runPhase = "idle"
	run_store.neurons = 10
	run_store.lastResult = null
	run_store.load_run_state()
	machine._sync_visuals()

	if String(run_store.runPhase) == "running":
		failures.append("issue151: exhausted save left a running zero-spin machine")
	if String(run_store.lastEnding) != "flatline":
		failures.append("issue151: exhausted save ended as %s, expected flatline"
			% str(run_store.lastEnding))
	if machine._overlay == null:
		failures.append("issue151: exhausted save showed no ending overlay")
	if machine._overlay != null:
		machine._overlay.queue_free()
		machine._overlay = null
	machine._stop_flatline_countdown()

	run_store.reset_run_state()
	meta_store._apply(meta_before)
	meta_store.save_state()

# Score-scene win counter (issue #142): a win registers under the active tier
# the moment the wealth goal is hit — surviving the deferred Start Again bank,
# the wealth-CONTINUE-then-flatline path — and the scores scene shows the
# number for the tier the arrows have selected.
func _check_tier_win_counter_142(run_store: Node, meta_store: Node, failures: Array) -> void:
	var meta_before: Dictionary = meta_store._as_dict()
	var prev_tier := String(run_store.augmentedTier)
	meta_store.history = { "runsPlayed": 0, "bestScoreRun": 0 }
	meta_store.endingsReached = []

	# Classic win: counted when the ending resolves, before any bank.
	run_store.augmentedTier = ""
	meta_store.mark_ending_reached("wealth")
	if int(meta_store.tier_wins("classic")) != 1:
		failures.append("issue142: classic wealth did not register a classic win")
	# The deferred Start Again bank must not count the same win twice.
	meta_store.bank_run({ "lucidityCoins": 0, "scoreEarned": 2000, "neurons": 1 }, "wealth")
	if int(meta_store.tier_wins("classic")) != 1:
		failures.append("issue142: the wealth bank double-counted the win")

	# Augmented win taken through CONTINUE: the run later banks as flatline,
	# but the heart win is already on the books.
	run_store.augmentedTier = "heart"
	meta_store.mark_ending_reached("wealth")
	meta_store.bank_run({ "lucidityCoins": 50, "scoreEarned": 2400, "neurons": 0 }, "flatline")
	if int(meta_store.tier_wins("heart")) != 1:
		failures.append("issue142: a wealth-continued heart run lost its win")
	if int(meta_store.tier_wins("classic")) != 1:
		failures.append("issue142: the heart win leaked into the classic counter")

	# The scene opens on classic and the arrows move the counter to the
	# selected tier's number.
	var scene: Control = (load("res://scenes/scores_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	var shown: Array = []
	for i in 3: # classic -> heart -> diamond
		shown.append(String(scene._win_counter_label.text))
		scene._cycle_tier(1)
	if shown != ["1", "1", "0"]:
		failures.append("issue142: win counter cycled %s, expected [1, 1, 0]" % str(shown))
	scene.queue_free()

	run_store.augmentedTier = prev_tier
	meta_store._apply(meta_before)
	meta_store.save_state()

# Augmented Run menu (issue #111): the selector is hidden before the unlock and
# appears under START RUN afterwards, communicating the tier before the start.
func _check_augmented_menu_111(run_store: Node, meta_store: Node, failures: Array) -> void:
	var meta_before: Dictionary = meta_store._as_dict()
	meta_store.is_first_launch = false

	meta_store.augmentedRunUnlocked = false
	var menu := (load("res://scenes/start_menu_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(menu)
	await process_frame
	var selector := menu.get_node_or_null("AugmentedSelector") as Control
	var bar := menu.get_node_or_null("AugmentedBar") as Sprite2D
	if selector == null:
		failures.append("issue111: menu has no augmented selector node")
	elif selector.visible:
		failures.append("issue111: selector visible before the wealth unlock")
	if menu.get_node_or_null("MenuArt") == null:
		failures.append("issue111: menu is not built on the start_menu art")
	if bar == null:
		failures.append("issue111: menu has no selector bar overlay")
	elif bar.visible:
		failures.append("issue111: selector bar visible before the wealth unlock")
	menu.queue_free()

	meta_store.augmentedRunUnlocked = true
	menu = (load("res://scenes/start_menu_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(menu)
	await process_frame
	selector = menu.get_node_or_null("AugmentedSelector") as Control
	bar = menu.get_node_or_null("AugmentedBar") as Sprite2D
	var symbols := menu.get_node_or_null("AugmentedSymbols") as Sprite2D
	var desc := menu.get_node_or_null("AugmentedDescription") as Label
	var start := menu._start_button as Button
	if selector == null or not selector.visible:
		failures.append("issue111: selector hidden after the wealth unlock")
	elif desc == null or start == null or symbols == null or bar == null:
		failures.append("issue111: unlocked menu is missing selector/bar/symbols nodes")
	else:
		if not bar.visible:
			failures.append("issue111: unlocked menu should show the selector bar overlay")
		if not symbols.visible or symbols.frame != 0:
			failures.append("issue111: empty selection should show symbols frame 0 (no augment)")
		if desc.text != "NO AUGMENT":
			failures.append("issue111: empty selection should read NO AUGMENT")
		menu._cycle_augmented_tier(1) # "" -> heart (art frame order)
		if String(menu._selected_augmented_tier) != "heart":
			failures.append("issue111: cycling right did not select heart")
		if symbols.frame != 1:
			failures.append("issue111: heart selection should show symbols frame 1")
		if desc.text != "JACKPOT 100, NO FREE SPIN":
			failures.append("issue111: heart description not communicated before start")
		if start.text != "AUGMENTED RUN":
			failures.append("issue111: start button did not switch to AUGMENTED RUN")
		menu._cycle_augmented_tier(-1) # heart -> ""
		if start.text == "AUGMENTED RUN":
			failures.append("issue111: clearing the selection kept AUGMENTED RUN")
		if start.pivot_offset != start.size * 0.5:
			failures.append("issue111: plate buttons need a centered pivot for the press squash")
		# Modifiers can't change mid-run: a held run keeps the selector visible
		# but LOCKED — arrows disabled, showing the active run's suit.
		var prev_phase := String(run_store.runPhase)
		run_store.runPhase = "running"
		run_store.augmentedTier = "club"
		menu._refresh_augmented_selector()
		if not selector.visible:
			failures.append("issue111: locked selector should stay visible during a held run")
		var left_arrow := selector.get_node_or_null("CycleLeft") as Button
		if left_arrow == null or not left_arrow.disabled:
			failures.append("issue111: selector arrows should lock during a held run")
		if symbols.frame != 4:
			failures.append("issue111: locked selector should show the run's suit (club = frame 4)")
		var pre_cycle := String(menu._selected_augmented_tier)
		menu._cycle_augmented_tier(1)
		if String(menu._selected_augmented_tier) != pre_cycle:
			failures.append("issue111: cycling changed the selection during a held run")
		run_store.augmentedTier = ""
		run_store.runPhase = prev_phase
	menu.queue_free()
	run_store.augmentedTier = ""
	meta_store._apply(meta_before)
	meta_store.save_state()

