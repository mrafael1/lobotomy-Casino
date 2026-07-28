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
		"res://scenes/pacte_scene.tscn",
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
	await _check_pacte_flow(machine, run_store, meta_store, failures)
	_check_pacte_power_rules(machine, run_store, failures)
	_check_pacte_augment_effects(machine, run_store, failures)
	_check_base_scene_parity(failures)
	_check_first_launch_tutorial(meta_store, failures)
	_check_scene_nav(failures)
	_check_machine_ending_flow_source(failures)
	_check_flatline_action_text(machine, meta_store, failures)
	_check_global_options_layout(failures)
	_check_water_lucidity_gain(run_store, failures)
	_check_additive_power_payout_181(run_store, failures)
	_check_jackpot_payout_181(machine, run_store, failures)
	_check_target_readout_181(machine, run_store, failures)
	await _check_machine_water_feedback(machine, run_store, failures)
	_check_water_wealth_169(machine, run_store, meta_store, failures)
	_check_off_spin_target_proc(machine, run_store, meta_store, failures)
	_check_augment_level_readouts(machine, run_store, failures)
	_check_reserve_glow_132(machine, run_store, failures)
	_check_dealer_tip_steps_132(machine, failures)
	await _check_machine_consumable_feedback(machine, run_store, failures)
	await _check_upgrades_scene(failures)
	_check_smart_save_retention(failures)
	_check_issue27_overlay_layout(failures)
	_check_issue27_machine_stash_drag(machine, run_store, failures)
	await _check_issue28_machine_sequence_lock(machine, run_store, failures)
	_check_options_spin_lock_77(machine, run_store, failures)
	_check_dealer_compulsion_softlock_96(machine, run_store, failures)
	_check_dealer_refusal_countdown_161(run_store, failures)
	_check_dealer_gate_161(machine, run_store, failures)
	_check_energy_drink_x2_161(run_store, failures)
	await _check_forced_spin_persistence_161(machine, run_store, failures)
	_check_tap_duration_161(failures)
	_check_energy_drink_discard_161(machine, run_store, failures)
	_check_loss_visuals_161(machine, run_store, failures)
	_check_ending_cleanup_161(machine, run_store, failures)
	_check_new_run_balance_161(run_store, failures)
	_check_consumable_roster_32(run_store, failures)
	_check_machine_reactions_35(machine, run_store, failures)
	_check_campaign_rebalance_38(machine, failures)
	await _check_odds_table_36(run_store, failures)
	await _check_neuron_meter_on_menu(failures)
	_check_flatline_overlay_meter(machine, failures)
	_check_wealth_screen(machine, run_store, failures)
	_check_wealth_target_flow_176(machine, run_store, meta_store, failures)
	_check_wealth_score_feed(machine, run_store, failures)
	_check_wealth_zero_spins_62(machine, run_store, failures)
	_check_flatline_free_spins_75(machine, run_store, failures)
	_check_flatline_win_boost_76(run_store, failures)
	_check_deferred_negative_76(machine, failures)
	_check_dealer_pacing_76(run_store, failures)
	_check_frenzy_gauge_155(run_store, failures)
	await _check_pending_combo_and_free_spin_ui(machine, run_store, failures)
	_check_compulsion_multiplier_76(machine, run_store, failures)
	_check_tv_information_priority(machine, run_store, failures)
	_check_boost_duration_icons_76(machine, run_store, failures)
	_check_red_pill_tv_badge_185(machine, run_store, failures)
	_check_item_badge_popup_185(machine, run_store, failures)
	_check_water_animation_185(machine, run_store, failures)
	_check_dealer_item_usage_flow_185(machine, run_store, failures)
	_check_hallucination_machine_reaction_185(machine, run_store, failures)
	await _check_power_bar_76(machine, run_store, failures)
	_check_restore_cap_181(machine, run_store, failures)
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
	await _check_card_collection_52(meta_store, failures)
	_check_card_unlock_rules_52(machine, run_store, meta_store, failures)
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

	var multiplier := machine.get_node_or_null("Multiplier") as Sprite2D
	if multiplier == null:
		failures.append("machine art: native multiplier node is missing")
	elif multiplier.texture == null \
			or Vector2i(multiplier.texture.get_width(), multiplier.texture.get_height()) != Vector2i(960, 320) \
			or multiplier.hframes != 6 \
			or multiplier.scale != Vector2.ONE \
			or multiplier.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		failures.append("machine art: multiplier is not a 6-frame native nearest-neighbor sprite")

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

	var power_callout := machine.get_node_or_null("PowerCallout") as Sprite2D
	if power_callout == null:
		failures.append("machine art: power callout node is missing")
	elif power_callout.texture == null \
			or Vector2i(power_callout.texture.get_width(), power_callout.texture.get_height()) \
				!= Vector2i(1120, 320) \
			or power_callout.hframes != 7 \
			or power_callout.scale != Vector2.ONE \
			or power_callout.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		failures.append("machine art: power callout is not a 7-frame native sprite")

	var wealth_odometer := machine.get_node_or_null("WealthOdometer") as WealthOdometer
	if wealth_odometer == null:
		failures.append("machine art: wealth odometer is missing")
	else:
		var wealth_art := wealth_odometer.get_node_or_null("WealthBarArt") as Sprite2D
		if wealth_art == null or wealth_art.texture == null \
				or Vector2i(wealth_art.texture.get_width(), wealth_art.texture.get_height()) \
					!= Vector2i(160, 320) \
				or wealth_art.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
			failures.append("machine art: wealth odometer bar is not native 160x320 art")
		elif not String(wealth_art.texture.resource_path).ends_with("wealth_bar.png"):
			failures.append("machine art: wealth odometer still uses the misspelled bar asset")
		var wealth_cases := wealth_odometer.get_node_or_null("WealthCasesArt") as Sprite2D
		if wealth_cases == null or wealth_cases.texture == null \
				or Vector2i(wealth_cases.texture.get_width(), wealth_cases.texture.get_height()) \
					!= Vector2i(160, 320) \
				or wealth_cases.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
			failures.append("machine art: wealth odometer cases are missing or not native art")
		elif not String(wealth_cases.texture.resource_path).ends_with("wealth_cases.png"):
			failures.append("machine art: wealth odometer cases use the wrong asset")
		var wealth_numbers := wealth_odometer.get_node_or_null("Reel0") as Control
		if wealth_art != null and wealth_cases != null and wealth_numbers != null \
				and not (wealth_cases.z_index < wealth_numbers.z_index \
					and wealth_numbers.z_index < wealth_art.z_index):
			failures.append("machine art: wealth layers must be cases < numbers < wealth bar")
		for reel_index in 4:
			var reel := wealth_odometer.get_node_or_null("Reel%d" % reel_index) as Control
			var current := reel.get_node_or_null("Current") as Sprite2D if reel != null else null
			var next := reel.get_node_or_null("Next") as Sprite2D if reel != null else null
			if reel == null or not reel.clip_contents:
				failures.append("machine art: wealth odometer reel %d is not clipped" % reel_index)
			elif current == null or next == null or current.texture == null \
					or Vector2i(current.texture.get_width(), current.texture.get_height()) \
						!= Vector2i(1760, 320) \
					or current.hframes != 11 or next.hframes != 11 \
					or current.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST \
					or next.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
				failures.append("machine art: wealth odometer reel %d is not an 11-frame native sheet" % reel_index)

	for node_name in [
		"ReelBacking", "HealthBar", "HealthCoin",
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

	# Hallucination's cut travels in its OWN slot now (issue #185), not in reward_scale:
	# a promoted pair pays a triple discounted to 30%.
	var hallucination := Evaluate.score_reels(["eye", "eye", "brain"], 1.0, true,
		false, false, 1.0, 0, true, 1.0, {}, false, 1.0, 0.70)
	if String(hallucination["winType"]) != "triple" or int(hallucination["scoreEarned"]) != 35:
		failures.append("issue92: hallucination should score visible pair as 70%% triple: %s" % str(hallucination))

	# The tuned maluses, not just the mechanism: the checks above hand Evaluate a literal
	# scale, so without these a retune of the upgrade tables goes unnoticed. Hallucination
	# cuts its promoted triples to 30%, Learning pays for the Book joker with 70%.
	if not is_equal_approx(Economy.compute_hallucination_reward_scale(["pos_enlightenment"]), 0.30):
		failures.append("balance: Hallucination should cut rewards to 30%% (got %.2f)"
			% Economy.compute_hallucination_reward_scale(["pos_enlightenment"]))
	if not is_equal_approx(Economy.compute_book_reward_scale(["pos_learning"]), 0.70):
		failures.append("balance: Learning should cut book wins to 70%% (got %.2f)"
			% Economy.compute_book_reward_scale(["pos_learning"]))
	# Neither cut may ride the general scale (issue #185). Learning is charged to book
	# wins only; Hallucination is charged to the triples it promotes only. Owning either
	# can no longer tax a spin it had nothing to do with.
	var scale_owned: Array = run_store.ownedUpgrades.duplicate()
	run_store.ownedUpgrades = ["pos_enlightenment", "pos_learning"]
	if not is_equal_approx(run_store._active_reward_scale(), 1.0):
		failures.append("balance: a targeted malus leaked into the general reward scale (got %.3f)"
			% run_store._active_reward_scale())
	if not is_equal_approx(run_store._book_reward_scale(), 0.70):
		failures.append("balance: Learning's book-win cut went missing (got %.3f)"
			% run_store._book_reward_scale())
	if not is_equal_approx(run_store._hallucination_reward_scale(), 0.30):
		failures.append("issue185: Hallucination's promoted-triple cut went missing (got %.3f)"
			% run_store._hallucination_reward_scale())
	run_store.ownedUpgrades = scale_owned

	# The rule itself: with Learning owned, a win with no book on the reels pays in full,
	# and a win the book completed pays the 30% less. Same reels either way apart from the
	# book, so the discount is the only difference between the two payouts.
	var bookless := Evaluate.score_reels(["eye", "eye", "eye"], 1.0, true,
		false, true, 1.0, 0, false, 1.0, {}, false, 0.70)
	var full_triple := Evaluate.score_reels(["eye", "eye", "eye"], 1.0, true,
		false, false, 1.0, 0, false, 1.0)
	if int(bookless["scoreEarned"]) != int(full_triple["scoreEarned"]):
		failures.append("book malus: a bookless win was taxed by Learning (%d, expected %d)"
			% [int(bookless["scoreEarned"]), int(full_triple["scoreEarned"])])
	var book_win := Evaluate.score_reels(["eye", "eye", "book"], 1.0, true,
		false, true, 1.0, 0, false, 1.0, {}, false, 0.70)
	if not bool(book_win.get("bookJoker", false)):
		failures.append("book malus: the book should have completed the eye triple: %s" % str(book_win))
	var want_book := int(round(float(int(full_triple["scoreEarned"])) * 0.70))
	if int(book_win["scoreEarned"]) != want_book:
		failures.append("book malus: a book win should pay 70%% (%d, expected %d)"
			% [int(book_win["scoreEarned"]), want_book])

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
	run_store.runPhase = "running"
	run_store.ownedUpgrades = ["pos_enlightenment"]
	run_store.neurons = 10
	run_store.startingNeurons = 10
	run_store.lockedReels = [true, true, true]
	run_store.lastResult = { "reels": ["eye", "eye", "brain"] }
	run_store.cocktailBoostSpins = 1
	var cocktail_result: Variant = run_store.spin(false)
	if cocktail_result == null or int((cocktail_result as Dictionary).get("cocktailBonus", -1)) != 16:
		failures.append("issue174: hallucination cocktail bonus should include the visible third reel: %s" % str(cocktail_result))
	run_store.set_spinning(false)

	run_store.ownedUpgrades = ["pos_enlightenment"]
	run_store.lastResult = { "reels": ["vial", "vial", "brain"], "winType": "triple", "freeSpinsGranted": 0 }
	run_store.neurons = 10
	var before_vial := int(run_store.neurons)
	machine._last_reacted_reels = []
	machine._last_reacted_spin = -1
	machine._apply_machine_reactions(true)
	if int(run_store.neurons) <= before_vial:
		failures.append("issue92: hallucination power-made visible pair did not trigger vial triple effect")
	run_store.lastResult = { "reels": ["flatline", "flatline", "flatline"], "winType": "triple", "freeSpinsGranted": 0 }
	var before_flatline := int(run_store.flatlineResultCount)
	machine._last_reacted_reels = []
	machine._last_reacted_spin = -1
	machine._apply_machine_reactions(false)
	if int(run_store.flatlineResultCount) != before_flatline + 1:
		failures.append("issue92: hallucination flatline pair should trigger a close-call strike")

	if machine._derive_source_reel(["vial", "vial", "brain"]) != 1:
		failures.append("issue92: hallucination score burst should derive from second reel")
	if machine._derive_source_reel(["brain", "vial", "vial"]) != 2:
		failures.append("issue174: hallucination should derive a last-two pair from the third reel")
	run_store.lockedReels = [false, false, false]
	machine._start_reel_spin_animation([false, false, false])
	if bool(machine._locked_reels_during_spin[2]) or not bool(machine._spin_reel_sprites[2].visible):
		failures.append("issue174: hallucination should keep the third reel visible")
	machine._stop_sfx(&"reel_spin")

	run_store.pairBoostSpins = 0
	run_store.pairBoostHiddenReels = 0
	run_store.ownedUpgrades = ["pos_enlightenment"]
	machine._refresh_tobacco_fx()
	if bool(machine._tobacco_covers[2].visible):
		failures.append("issue174: hallucination should not cover the third reel")
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
		for phrase in ["The Objective", "Dealer Scene", "Upgrades Scene", "Machine Scene", "15 spins", "50 coins"]:
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
	_check_dealer_tip_132(failures)
	_check_emergency_reserve_132(failures)
	_check_symbol_level_picker_132(failures)
	_check_pair_triple_picker_bounds_132(failures)
	_check_augment_feedback_map_132(failures)
	_check_wealth_ending_augment_teardown_132(failures)

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
	var spin_number := machine.get_node_or_null("BottomHudLayer/spin_number") as Label
	var health_bar := machine.get_node_or_null("HealthBar") as Sprite2D
	var health_coin := machine.get_node_or_null("HealthCoin") as Sprite2D
	if bottom_hud == null:
		failures.append("machine: BottomHudLayer is missing")
	else:
		if bottom_hud.size != Vector2(160.0, 320.0):
			failures.append("machine: BottomHudLayer is not full-canvas")
		if bottom_hud.z_index <= 50 or bottom_hud.z_index >= 200:
			failures.append("machine: BottomHudLayer is not layered between cabinet art and options overlay")
	if spin_number == null:
		failures.append("machine: spin_number label is missing")
	else:
		if spin_number.anchor_left != 0.5 or spin_number.anchor_right != 0.5 \
				or spin_number.anchor_top != 1.0 or spin_number.anchor_bottom != 1.0:
			failures.append("machine: spin_number is not anchored Center Bottom")
		if spin_number.offset_top != -14.0 or spin_number.offset_bottom != -4.0:
			failures.append("machine: spin_number is not positioned at the bottom edge")
		if spin_number.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER:
			failures.append("machine: spin_number is not centered inside its label box")
		# Issue #38: the label is the anchor; the pixel-art meter is the readout.
		if spin_number.text != "":
			failures.append("machine: spin_number should render no text (tube readout replaces it)")
		_check_neuron_meter_absent("machine", bottom_hud, failures)
		# The -1 NEURON popup no longer fires during normal play (flatline overlay only).
		if machine.get_node_or_null("BottomHudLayer/NeuronSpendFeedback") != null:
			failures.append("machine: neuron spend feedback should not appear on the normal HUD")
	# The spins readout left the TV: it is now the native 20-frame tube sheet
	# (frame = spins remaining), plus a hidden 4-frame coin-drop sheet that only
	# plays while a spin launches.
	if machine.get_node_or_null("HealthLabel") != null:
		failures.append("machine: HealthLabel spins counter should be removed from the TV")
	if health_bar == null or health_bar.hframes != 20:
		failures.append("machine: HealthBar spins tube is not a 20-frame sheet")
	# The tube must be able to draw every spin the economy can hand out: one frame per
	# count from empty to the cap. A sheet that falls behind a raised cap silently
	# clamps the top of the tube instead of failing.
	if health_bar != null and health_bar.hframes != EconomyConst.MAX_NEURONS + 1:
		failures.append("machine: the tube's %d frames cannot draw a %d-spin cap"
			% [int(health_bar.hframes), EconomyConst.MAX_NEURONS])
	if health_coin == null or health_coin.hframes != 4 or health_coin.visible:
		failures.append("machine: HealthCoin drop sheet is missing or visible at rest")
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

## Issue #181: a power's combination pays on top of what the spin already won, and the
## score can never go down because a power reshaped the reels into something smaller.
func _check_additive_power_payout_181(run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.neurons = 10
	# The spin landed a pair worth 10; that is the baseline the powers build on.
	var spun := Evaluate.score_reels(["eye", "eye", "pill"], 1.0, false)
	var pair_score := int(spun["scoreEarned"])
	if pair_score <= 0:
		failures.append("issue181: the additive-payout fixture did not land a paying pair")
		return
	run_store.scoreEarned = pair_score
	run_store.lastPureWinScore = pair_score
	run_store.lastPureWinCoins = int(spun["coinsEarned"])
	run_store.lastResult = {
		"reels": ["eye", "eye", "pill"], "winType": "pair", "isJackpot": false,
		"scoreEarned": pair_score, "coinsEarned": pair_score,
		"freeSpinsGranted": 0, "freeSpinsAfter": 0, "isFreeSpin": false,
	}
	# A power turns it into a triple: the triple's own value is added on top.
	var triple := Evaluate.score_reels(["eye", "eye", "eye"], 1.0, false)
	var triple_score := int(triple["scoreEarned"])
	run_store._apply_outcome({
		"reels": ["eye", "eye", "eye"], "winType": "triple", "isJackpot": false,
		"scoreDelta": triple_score - pair_score, "coinsDelta": triple_score - pair_score,
		"freeSpinsGranted": 0,
	}, [], 1)
	if int(run_store.scoreEarned) != pair_score + triple_score:
		failures.append("issue181: a power's win did not pay on top of the spin's (%d, want %d)"
			% [int(run_store.scoreEarned), pair_score + triple_score])
	# A second power drops back to a smaller pair: it still pays its own value, and
	# nothing that was already won is taken away.
	var before_smaller := int(run_store.scoreEarned)
	var smaller := Evaluate.score_reels(["vial", "vial", "eye"], 1.0, false)
	var smaller_score := int(smaller["scoreEarned"])
	run_store._apply_outcome({
		"reels": ["vial", "vial", "eye"], "winType": "pair", "isJackpot": false,
		"scoreDelta": smaller_score - triple_score, "coinsDelta": smaller_score - triple_score,
		"freeSpinsGranted": 0,
	}, [], 2)
	if int(run_store.scoreEarned) < before_smaller:
		failures.append("issue181: a smaller power result took score away (%d -> %d)"
			% [before_smaller, int(run_store.scoreEarned)])
	if int(run_store.scoreEarned) != before_smaller + smaller_score:
		failures.append("issue181: the smaller power win did not pay its own value (%d, want %d)"
			% [int(run_store.scoreEarned), before_smaller + smaller_score])
	# A power that leaves no winning combination pays nothing and takes nothing.
	var before_miss := int(run_store.scoreEarned)
	run_store._apply_outcome({
		"reels": ["brain", "eye", "pill"], "winType": "miss", "isJackpot": false,
		"scoreDelta": -smaller_score, "coinsDelta": -smaller_score, "freeSpinsGranted": 0,
	}, [], 3)
	if int(run_store.scoreEarned) != before_miss:
		failures.append("issue181: a missed power result moved the score (%d -> %d)"
			% [before_miss, int(run_store.scoreEarned)])
	run_store.reset_run_state()

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
	var previous_score := int(run_store.scoreEarned)

	run_store.runPhase = "running"
	run_store.isSpinning = false
	run_store.dealerIncoming = false
	run_store.dealerPending = false
	run_store.lucidityCoins = 20
	run_store.runConsumables = { "item_water": 1 }
	run_store.abilitiesUsed = []
	run_store.pendingPowerRestores = []
	run_store.spinCount = 0
	run_store.scoreEarned = 20

	if not run_store.use_consumable("item_water"):
		failures.append("water: use_consumable returned false")
	elif int(run_store.lucidityCoins) != 60:
		failures.append("water: should grant 40 lucidity coins (20 -> 60), got %d" % int(run_store.lucidityCoins))
	elif int(run_store.scoreEarned) != 60:
		failures.append("water: should add its 40 points to the run score (20 -> 60), got %d" % int(run_store.scoreEarned))

	run_store.scoreEarned = previous_score
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
	var previous_score := int(run_store.scoreEarned)
	var previous_result: Variant = run_store.lastResult
	var previous_display := int(machine._display_lucidity)
	var previous_coin_prev := int(machine._coin_prev_lucidity)
	var previous_burst_spin := int(machine._burst_prev_spin)
	var previous_burst_score := int(machine._burst_prev_score)

	run_store.runPhase = "running"
	run_store.isSpinning = false
	run_store.dealerIncoming = false
	run_store.dealerPending = false
	run_store.lucidityCoins = 20
	run_store.runConsumables = { "item_water": 1 }
	run_store.abilitiesUsed = []
	run_store.pendingPowerRestores = []
	run_store.spinCount = 0
	run_store.scoreEarned = 20
	run_store.lastResult = {
		"scoreEarned": 20, "coinsEarned": 20, "winType": "pair",
		"reels": ["eye", "eye", "vial"], "scoreMultiplier": 1.0,
	}
	machine._burst_prev_spin = 0
	machine._burst_prev_score = 20
	machine._set_sequence_lock(false)
	machine._set_display_lucidity(20)
	machine._coin_prev_lucidity = 20

	machine._on_stash_pressed(0)
	if int(run_store.lucidityCoins) != 60:
		failures.append("machine water: should grant lucidity immediately on consume")
	if int(machine._coin_prev_lucidity) != 60:
		failures.append("machine water: immediate consume gain will replay on next spin")
	if int(run_store.scoreEarned) != 60:
		failures.append("machine water: should add its 40 points to the run score")
	if int((run_store.lastResult as Dictionary).get("scoreEarned", 0)) != 60:
		failures.append("machine water: current result score was not advanced with the direct gain")
	if int(machine._burst_prev_score) != 60:
		failures.append("machine water: payout baseline did not advance past the direct score gain")
	await create_timer(0.1).timeout
	if int(machine._display_lucidity) != 60:
		failures.append("machine water: score gain should roll the wealth odometer")

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
	run_store.scoreEarned = previous_score
	run_store.lastResult = previous_result
	machine._burst_prev_spin = previous_burst_spin
	machine._burst_prev_score = previous_burst_score

## Issue #181: the TV's objective readout is two authored sheets — a goal frame per
## WEALTH_TARGETS entry, and a bar whose frames are the fill toward the current target.
func _check_target_readout_181(machine: Node, run_store: Node, failures: Array) -> void:
	var previous_phase := String(run_store.runPhase)
	var previous_score := int(run_store.scoreEarned)
	var previous_index := int(run_store.wealthTargetIndex)

	if machine._target_bar_sprite == null or machine._target_goals_sprite == null:
		failures.append("issue181: the TV is missing the TARGET bar/goal art")
		return
	if machine._target_bar_sprite.hframes != machine.TARGET_BAR_FRAME_COUNT \
			or machine._target_goals_sprite.hframes != machine.TARGET_GOALS_FRAME_COUNT:
		failures.append("issue181: the TARGET sheets were sliced into the wrong frame count")
	# The shimmer is re-authored from time to time; catch a sheet whose real frame count
	# has drifted from the constant rather than letting it play sliced-up frames.
	var shimmer: Sprite2D = machine._target_bar_anim_sprite
	if shimmer == null:
		failures.append("issue181: the TARGET bar shimmer is missing")
	else:
		if shimmer.hframes != machine.TARGET_BAR_ANIM_FRAME_COUNT:
			failures.append("issue181: the shimmer sheet was sliced into the wrong frame count")
		if shimmer.texture != null:
			var sheet_frames := int(round(
				float(shimmer.texture.get_width()) / float(machine.SRC_W)))
			if sheet_frames != machine.TARGET_BAR_ANIM_FRAME_COUNT:
				failures.append("issue181: the shimmer sheet holds %d frames, the code expects %d"
					% [sheet_frames, int(machine.TARGET_BAR_ANIM_FRAME_COUNT)])
		if shimmer.z_index >= machine._target_bar_sprite.z_index:
			failures.append("issue181: the shimmer should play under the fill bar")
		# It has to actually advance, and wrap rather than run off the sheet.
		var first_frame := shimmer.frame
		for _step in machine.TARGET_BAR_ANIM_FRAME_COUNT:
			machine._advance_target_bar_animation(machine.TARGET_BAR_ANIM_FRAME_TIME)
		if shimmer.frame != first_frame:
			failures.append("issue181: the shimmer did not loop back around")
		machine._advance_target_bar_animation(machine.TARGET_BAR_ANIM_FRAME_TIME)
		if shimmer.frame == first_frame:
			failures.append("issue181: the shimmer is not advancing")
	if machine._target_goals_sprite.hframes != EconomyConst.WEALTH_TARGETS.size():
		failures.append("issue181: the goal sheet does not carry one frame per wealth target")

	run_store.runPhase = "running"
	# An empty run shows the first goal and an empty bar.
	run_store.wealthTargetIndex = 0
	run_store.scoreEarned = 0
	machine._refresh_target_readout()
	if machine._target_goals_sprite.frame != 0 or machine._target_bar_sprite.frame != 0:
		failures.append("issue181: a fresh run did not show goal 0 with an empty bar")
	# Meeting the current target fills the bar completely.
	run_store.scoreEarned = EconomyConst.WEALTH_TARGETS[0]
	machine._refresh_target_readout()
	if machine._target_bar_sprite.frame != machine.TARGET_BAR_FRAME_COUNT - 1:
		failures.append("issue181: reaching the target did not fill the TARGET bar")
	# Paying it advances the goal frame and empties the bar again.
	run_store.wealthTargetIndex = 3
	run_store.scoreEarned = 0
	machine._refresh_target_readout()
	if machine._target_goals_sprite.frame != 3:
		failures.append("issue181: the goal frame does not follow the wealth target index")
	if machine._target_bar_sprite.frame != 0:
		failures.append("issue181: the TARGET bar did not refill from empty after a payout")
	# Half way to the last target reads as a partially filled bar, never a full one.
	run_store.wealthTargetIndex = EconomyConst.WEALTH_TARGETS.size() - 1
	run_store.scoreEarned = int(run_store.current_wealth_target() / 2)
	machine._refresh_target_readout()
	var half_frame: int = machine._target_bar_sprite.frame
	if half_frame <= 0 or half_frame >= machine.TARGET_BAR_FRAME_COUNT - 1:
		failures.append("issue181: half progress did not land mid-bar (frame %d)" % half_frame)

	run_store.wealthTargetIndex = previous_index
	run_store.scoreEarned = previous_score
	run_store.runPhase = previous_phase
	machine._refresh_target_readout()

## Issue #181: a jackpot is paced deliberately — the wealth reels roll slowly and the
## cash tray throws a coin spray — and the sequence lock has to outlast both.
func _check_jackpot_payout_181(machine: Node, run_store: Node, failures: Array) -> void:
	var previous_result: Variant = run_store.lastResult
	var previous_phase := String(run_store.runPhase)
	var previous_score := int(run_store.scoreEarned)
	var previous_spin := int(run_store.spinCount)
	var previous_burst_spin := int(machine._burst_prev_spin)
	var previous_burst_score := int(machine._burst_prev_score)
	var previous_display := int(machine._display_lucidity)

	if not machine.has_method("_spawn_jackpot_coin_fountain"):
		failures.append("issue181: machine is missing the jackpot coin fountain")
	run_store.runPhase = "running"
	run_store.spinCount = 7
	run_store.scoreEarned = 400
	run_store.lastResult = {
		"scoreEarned": 200, "coinsEarned": 200, "winType": "jackpot", "isJackpot": true,
		"reels": ["brain", "brain", "brain"], "scoreMultiplier": 1.0,
	}
	machine._burst_prev_spin = 6
	machine._burst_prev_score = 0
	machine._set_display_lucidity(200, false)
	var reward_time: float = machine._emit_score_burst(null)
	var slow_roll: float = machine.JACKPOT_ODOMETER_ROLL_TIME + machine.JACKPOT_ROLL_TAIL
	if reward_time < slow_roll:
		failures.append("issue181: jackpot sequence unlocks before the slow score roll ends")
	if reward_time < machine.jackpot_coin_fountain_time():
		failures.append("issue181: jackpot sequence unlocks before the coin spray ends")
	if machine._jackpot_coins.is_empty():
		failures.append("issue181: jackpot did not throw any coins from the cash tray")
	else:
		var first_coin := machine._jackpot_coins[0] as Sprite2D
		var tray: Vector2 = machine._cash_tray_pos()
		if first_coin == null or absf(first_coin.position.y - tray.y) > 1.0:
			failures.append("issue181: jackpot coins do not start at the cash tray mouth")
	if machine._wealth_odometer != null and not machine._wealth_odometer.is_rolling():
		failures.append("issue181: jackpot did not roll the wealth odometer")
	# The coin layer sweep only hides children, so the spray needs its own free.
	machine._clear_jackpot_coins()
	if not machine._jackpot_coins.is_empty():
		failures.append("issue181: jackpot coins survived the teardown")

	machine._set_display_lucidity(previous_display, false)
	machine._burst_prev_spin = previous_burst_spin
	machine._burst_prev_score = previous_burst_score
	machine._combo_score_pending = -1
	run_store.lastResult = previous_result
	run_store.runPhase = previous_phase
	run_store.scoreEarned = previous_score
	run_store.spinCount = previous_spin

func _check_water_wealth_169(machine: Node, run_store: Node, meta_store: Node,
		failures: Array) -> void:
	var meta_before: Dictionary = meta_store._as_dict()
	meta_store.campaignNeuronsLeft = 5
	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.neurons = 0
	run_store.wealthTargetIndex = EconomyConst.WEALTH_TARGETS.size() - 1
	run_store.scoreEarned = 4960
	run_store.lucidityCoins = 20
	run_store.runConsumables = { "item_water": 1 }
	run_store.lastResult = {
		"scoreEarned": 4960, "coinsEarned": 4960, "winType": "pair",
		"reels": ["eye", "eye", "vial"], "scoreMultiplier": 1.0,
	}
	machine._set_sequence_lock(false)
	machine._set_display_lucidity(4960, false)
	machine._on_stash_pressed(0)
	if String(run_store.runPhase) != "over" or String(run_store.lastEnding) != "wealth":
		failures.append("pr169: Water crossing 5000 did not open the Wealth ending")
	if machine._overlay == null:
		failures.append("pr169: Water Wealth resolution left no ending overlay")
	if machine._overlay != null:
		machine._overlay.queue_free()
		machine._overlay = null
	machine._set_stash_tray_visible(true)
	run_store.reset_run_state()
	meta_store._apply(meta_before)
	meta_store.save_state()

## Reaching an intermediate target is a score fact, not a spin outcome: an item (or a
## power that rescores the reveal) that pushes the score over the line must pop the
## payout screen right there. A dealer queued for that same moment stands down — the
## round he belonged to is over, and the between-run dealer waits on the other side.
func _check_off_spin_target_proc(machine: Node, run_store: Node, meta_store: Node,
		failures: Array) -> void:
	var meta_before: Dictionary = meta_store._as_dict()
	meta_store.campaignNeuronsLeft = 5
	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.neurons = 6
	run_store.wealthTargetIndex = 0 # first ladder target
	var target: int = run_store.current_wealth_target()
	run_store.scoreEarned = target - 1
	run_store.lucidityCoins = 20
	run_store.runConsumables = { "item_water": 1 }
	run_store.lastResult = {
		"scoreEarned": target - 1, "coinsEarned": target - 1, "winType": "pair",
		"reels": ["eye", "eye", "vial"], "scoreMultiplier": 1.0,
	}
	machine._set_sequence_lock(false)
	machine._set_display_lucidity(target - 1, false)
	machine._on_stash_pressed(0)
	if not bool(machine._wealth_target_transition_active):
		failures.append("off-spin target: an item beating the target did not pop the payout screen")
	if machine._dealer_overlay != null or machine._dealer_offer_popup != null:
		failures.append("off-spin target: the dealer walked in over the beaten target")

	# A dealer queued for that same moment stands down rather than opening over (or
	# after) the payout screen — the round he belonged to is over.
	run_store.dealerIncoming = true
	run_store.dealerOfferIds = ["item_water"]
	machine._pending_dealer_offer = false
	machine._present_dealer_or_defer()
	if machine._dealer_overlay != null or machine._dealer_offer_popup != null:
		failures.append("off-spin target: a queued dealer opened during the payout")
	if bool(machine._pending_dealer_offer):
		failures.append("off-spin target: the dealer stayed queued behind the beaten target")
	machine._pending_dealer_offer = true
	machine._maybe_present_pending_dealer()
	if machine._dealer_overlay != null or machine._dealer_offer_popup != null:
		failures.append("off-spin target: a deferred dealer slipped in over the beaten target")
	machine._stop_wealth_target_transition()
	machine._wealth_target_transition_active = false

	# The stand-down is the target's doing, not a blanket block: with no target due the
	# same queued dealer opens normally.
	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.neurons = 6
	run_store.scoreEarned = 0
	run_store.dealerIncoming = true
	run_store.dealerOfferIds = ["item_water"]
	machine._pending_dealer_offer = false
	machine._present_dealer_or_defer()
	if machine._dealer_overlay == null and machine._dealer_offer_popup == null \
			and not bool(machine._pending_dealer_offer):
		failures.append("off-spin target: the dealer stopped coming without a target to pay")
	machine._close_dealer(false)
	machine._pending_dealer_offer = false

	# A power that rescores the reveal past the line pops it the same way — the player
	# never has to pull the lever again just to be told the target was already beaten.
	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.neurons = 6
	run_store.wealthTargetIndex = 0
	run_store.scoreEarned = run_store.current_wealth_target() + 25
	run_store.lastResult = {
		"scoreEarned": run_store.scoreEarned, "coinsEarned": 0, "winType": "pair",
		"reels": ["eye", "eye", "vial"], "scoreMultiplier": 1.0,
	}
	machine._set_sequence_lock(false)
	if not bool(machine._proc_wealth_target()):
		failures.append("off-spin target: a power-made score did not proc the target")
	machine._stop_wealth_target_transition()
	machine._wealth_target_transition_active = false
	machine._set_sequence_lock(false)

	# A queued dealer must not swallow the item. The stash reads enabled while he walks
	# in, so refusing the use there made the tap a silent no-op and the target went unpaid.
	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.neurons = 6
	run_store.wealthTargetIndex = 0
	target = run_store.current_wealth_target()
	run_store.scoreEarned = target - 1
	run_store.lucidityCoins = 20
	run_store.runConsumables = { "item_water": 1 }
	run_store.lastResult = {
		"scoreEarned": target - 1, "coinsEarned": target - 1, "winType": "pair",
		"reels": ["eye", "eye", "vial"], "scoreMultiplier": 1.0,
	}
	run_store.dealerPending = true
	machine._set_sequence_lock(false)
	machine._set_display_lucidity(target - 1, false)
	machine._on_stash_pressed(0)
	if int(run_store.runConsumables.get("item_water", 0)) != 0:
		failures.append("off-spin target: a queued dealer silently refused the item")
	if not bool(machine._wealth_target_transition_active):
		failures.append("off-spin target: an item used with a dealer queued did not pay the target")
	machine._stop_wealth_target_transition()
	machine._wealth_target_transition_active = false
	machine._set_sequence_lock(false)

	# A beaten target outranks a pending combo defeat: the payout ends the round, so the
	# loss resolves into it instead of holding the screen for a confirming spin.
	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.neurons = 6
	run_store.wealthTargetIndex = 0
	target = run_store.current_wealth_target()
	run_store.scoreEarned = target - 1
	run_store.lucidityCoins = 20
	run_store.runConsumables = { "item_water": 1 }
	run_store.lastResult = {
		"scoreEarned": target - 1, "coinsEarned": target - 1, "winType": "pair",
		"reels": ["eye", "eye", "vial"], "scoreMultiplier": 1.0,
	}
	run_store.comboDefeatPending = true
	run_store.pendingComboMultiplier = 3
	machine._set_display_lucidity(target - 1, false)
	machine._show_pending_combo_defeat()
	machine._on_stash_pressed(0)
	if not bool(machine._wealth_target_transition_active):
		failures.append("off-spin target: a beaten target stayed buried under the losing state")
	if bool(run_store.comboDefeatPending) or machine._pending_combo_overlay != null:
		failures.append("off-spin target: the losing state survived the target payout")
	machine._stop_wealth_target_transition()
	machine._wealth_target_transition_active = false
	machine._set_sequence_lock(false)

	run_store.reset_run_state()
	meta_store._apply(meta_before)
	meta_store.save_state()

## A Symbol Level augment is a live weight the moment it is bought, so every readout
## that quotes a level or a draw chance — the odds table meter, its "i" peek, the
## machine's score table — has to include it.
## Which frame of its sheet an odds-table region sprite is showing. One frame is the
## document width times whatever factor the sheet was exported at.
func _odds_sheet_frame(overlay: Node, sprite: Sprite2D) -> int:
	if sprite == null:
		return -1
	return int(sprite.region_rect.position.x / (float(overlay.ART_FRAME_SIZE.x) \
		* float(sprite.get_meta(&"art_scale", 1.0))))

func _check_augment_level_readouts(machine: Node, run_store: Node, failures: Array) -> void:
	# Symbol augment levels are campaign state (issue #132), so they are read off the
	# meta store here rather than the run store.
	var meta_store: Node = get_root().get_node("MetaStateStore")
	run_store.reset_run_state()
	var base_level: int = run_store.effective_symbol_level("eye")
	var base_percent: float = machine._symbol_draw_percent("eye")
	meta_store.symbolAugmentLevels = { "eye": 1 } # one per symbol is the cap
	if run_store.effective_symbol_level("eye") != base_level + 1:
		failures.append("augment readouts: the effective symbol level ignored the augment")
	if machine._symbol_draw_percent("eye") <= base_percent:
		failures.append("augment readouts: the score table quoted the pre-augment draw chance")

	# Kept untyped: naming OddsTableOverlay here would compile that script (and its
	# Assets autoload lookups) before the autoloads exist.
	var overlay: Node = (load("res://scenes/odds_table_overlay.tscn") as PackedScene).instantiate()
	get_root().add_child(overlay)
	overlay._rebuild()
	if overlay._symbol_percent("eye") <= base_percent:
		failures.append("augment readouts: the odds table quoted the pre-augment draw chance")
	# The Symbol Level picker stages like the odds phase: "+" marks a symbol and lights its
	# special segment, "-" takes it back, and only the action button commits — pressing "+"
	# must not close the table or charge anything on its own.
	var picker: Node = (load("res://scenes/odds_table_overlay.tscn") as PackedScene).instantiate()
	get_root().add_child(picker)
	picker.open_augment_picker()
	var picked := []
	picker.symbol_picked.connect(func(symbol_id: String) -> void: picked.append(symbol_id))
	picker._on_plus_pressed("pill")
	if not bool(picker.visible) or not picked.is_empty():
		failures.append("augment picker: + committed the pick instead of staging it")
	if String(picker._augment_pick) != "pill":
		failures.append("augment picker: + did not stage the symbol")
	var pill_augment := picker._augment_level_sprites.get("pill") as Sprite2D
	var pill_meter := picker._level_sprites.get("pill") as Sprite2D
	if _odds_sheet_frame(picker, pill_augment) != int(picker.AUGMENT_LEVEL_FRAME_ADDED):
		failures.append("augment picker: the staged pick did not light the special segment")
	# ...and the level bar itself never counts an augment level.
	if _odds_sheet_frame(picker, pill_meter) != int(run_store.odds_upgrade_level("pill")):
		failures.append("augment picker: the level bar moved for an augment level")
	picker._on_minus_pressed("pill")
	if String(picker._augment_pick) != "":
		failures.append("augment picker: - did not take the staged pick back")
	picker._on_plus_pressed("vial")
	picker._close()
	if picked.size() != 1 or String(picked[0]) != "vial":
		failures.append("augment picker: the action button did not commit the staged pick")
	picker.queue_free()

	# An augment level belongs to the special 9th segment, never to the level bar: with the
	# augment on, the bar sits exactly where it sits without it, and the segment is what
	# changes.
	var meter := overlay._level_sprites.get("eye") as Sprite2D
	var eye_segment := overlay._augment_level_sprites.get("eye") as Sprite2D
	var augmented_frame := _odds_sheet_frame(overlay, meter)
	var augmented_segment := _odds_sheet_frame(overlay, eye_segment)
	meta_store.symbolAugmentLevels = {}
	overlay.refresh_levels()
	var plain_frame := _odds_sheet_frame(overlay, meter)
	var plain_segment := _odds_sheet_frame(overlay, eye_segment)
	if meter == null or augmented_frame != plain_frame:
		failures.append("augment readouts: the level bar moved for an augment level")
	if eye_segment == null or augmented_segment != int(overlay.AUGMENT_LEVEL_FRAME_ADDED) \
			or plain_segment != int(overlay.AUGMENT_LEVEL_FRAME_NONE):
		failures.append("augment readouts: the augment level did not light the special segment")
	overlay.queue_free()
	run_store.reset_run_state()

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
	await create_timer(0.75).timeout
	if spawned == null or not is_instance_valid(spawned):
		failures.append("machine consumable feedback: hint disappeared during its growth phase")
	elif (spawned as HintLabel).modulate.a < 0.95:
		failures.append("machine consumable feedback: hint faded during its growth phase")
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
	# Assigning lastResult by hand skips the spin path, which is what normally rebases the
	# additive payout baseline (run_state_store.gd sets lastPureWinScore from each result).
	# Without this the boosted pair below is added to whatever the random spins above
	# happened to win, and the exact-30 assertion flips between 30 and 40 run to run.
	run_store.lastPureWinScore = 0
	run_store.lastPureWinCoins = 0
	run_store.copy_reel(0, 1)
	if int(run_store.lastResult["scoreEarned"]) != 30 or String(run_store.lastResult["winType"]) != "pair":
		failures.append("issue92: Tobacco pair boost did not apply to a power-made pair (got %d/%s)"
			% [int(run_store.lastResult["scoreEarned"]), String(run_store.lastResult["winType"])])
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
		# The Cocktail is pure upside now: a paying spin keeps the whole rarity bonus and
		# is never taxed for having won. The old 15% cut would have made this 61.
		if cocktail_spin.has("cocktailPenalty"):
			failures.append("issue92: Cocktail still charged a pair/triple tax: %s" % str(cocktail_spin))
		if int(cocktail_spin["scoreEarned"]) != 66 or int(cocktail_spin["coinsEarned"]) != 66:
			failures.append("issue92: Cocktail final score/coins wrong: %s" % str(cocktail_spin))
	run_store.cocktailBoostSpins = 0
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
		# The forced spin drives the gauge like a normal spin now; clear any losing
		# state it opened so the following blocks start clean.
		if bool(run_store.comboDefeatPending):
			run_store.resolve_pending_combo_defeat(false)

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

	# Energy Drink vs the losing state: during an x2 defeat the drink caps the gauge
	# at x2 but the defeat stays pending; during an x3 defeat it clears the defeat
	# outright (the x3 frenzy is traded for the capped x2 rush).
	run_store.betMultiplier = 2
	run_store.pendingComboMultiplier = 2
	run_store.comboDefeatPending = true
	run_store.runConsumables = { "item_energy_drink": 2 }
	run_store.use_consumable("item_energy_drink")
	if not bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 2 \
			or int(run_store.forcedRandomBetSpins) <= 0:
		failures.append("energy drink: x2 losing state should stay pending with the gauge capped at x2")
	run_store.betMultiplier = 3
	run_store.pendingComboMultiplier = 3
	run_store.comboDefeatPending = true
	run_store.use_consumable("item_energy_drink")
	if bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 2:
		failures.append("energy drink: x3 losing state should clear with the gauge capped at x2")
	run_store.comboDefeatPending = false
	run_store.pendingComboMultiplier = 1
	run_store.betMultiplier = 1
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

## Issue #84: the machine button is misclick-guarded by a YES/CANCEL confirm modal.
## The LAB button is retired: it must stay hidden on the dealer scene.
func _check_start_confirm_and_lab_glow_84(dealer: Node, failures: Array) -> void:
	# The lab is no longer reachable from the dealer scene.
	var lab_button := dealer.get_node_or_null("LabButton") as Button
	if lab_button != null and (lab_button.visible or not lab_button.disabled):
		failures.append("issue84: retired LAB button is still active on the dealer scene")
	if dealer.get_node_or_null("LabButtonArt") != null \
			or dealer.get_node_or_null("LabButtonGlowArt") != null:
		failures.append("issue84: retired LAB button art/glow is still built")

	# The machine button is wired to the confirm guard, not straight to _start_run.
	var start_button := dealer.get_node_or_null("StartButton") as Button
	if start_button == null:
		failures.append("issue84: machine (StartButton) missing for confirm wiring")
	else:
		if start_button.pressed.is_connected(Callable(dealer, "_start_run")):
			failures.append("issue84: machine button still starts the run without confirmation")
		if not start_button.pressed.is_connected(Callable(dealer, "_on_machine_button_pressed")):
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
	for rel in ["dealer_scene_machine_BUTTON.png"]:
		if not ResourceLoader.exists("res://assets/images/" + String(rel)):
			failures.append("issue55: %s not in godot/assets/images — missing from exported builds (APK)" % rel)
	var start_button := dealer.get_node_or_null("StartButton") as Button
	var machine_art := dealer.get_node_or_null("MachineButtonArt") as Sprite2D
	if start_button == null or machine_art == null:
		failures.append("issue55: dealer machine button/art pair is missing")
	else:
		if machine_art.hframes != 2:
			failures.append("issue55: machine button art is not a 2-frame sheet")
		if machine_art.position != Vector2.ZERO:
			failures.append("issue55: machine art lost its dealer-canvas-relative position")
		# The hit area is the button's own art rect, wherever the sheet puts it — the art
		# moved when it was re-exported unscaled, and the two must move together.
		if start_button.position != dealer.MACHINE_BUTTON_RECT.position \
				or start_button.size != dealer.MACHINE_BUTTON_RECT.size:
			failures.append("issue55: machine hit button is not on its art rect")
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
	for art_name in ["MachineButtonArt", "RerollButtonArt"]:
		var art := dealer.get_node_or_null(art_name) as Sprite2D
		if art == null or art.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST \
				or art.hframes != 2 or art.texture == null:
			failures.append("dealer shop: %s is not a nearest-neighbor 2-frame sheet" % art_name)
			continue
		# The sheets are exported at whatever scale suits the artist (the machine button is
		# native now, the reroll one is still x8), so what is asserted is the result: one
		# frame fitted across the whole canvas.
		var button_frame_w := float(art.texture.get_width()) * 0.5
		if not is_equal_approx(art.scale.x, 160.0 / button_frame_w) \
				or not is_equal_approx(art.scale.y, 320.0 / float(art.texture.get_height())):
			failures.append("dealer shop: %s frame is not fitted to the canvas" % art_name)

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
## Dealer's Tip (issue #132): the countdown starts part-way along instead of empty, and
## the BAR keeps its full 12-step scale so the head start is visible as 2/12.
func _check_dealer_tip_132(failures: Array) -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var prev_augs: Dictionary = (meta_store.chipAugmentsPurchased as Dictionary).duplicate(true)
	var prev_tier := String(run_store.augmentedTier)
	run_store.augmentedTier = ""

	meta_store.chipAugmentsPurchased = {}
	var plain_length := int(run_store.dealer_countdown_cycle_length())
	var plain_reset := int(run_store.dealer_countdown_reset_value())
	if plain_reset != plain_length or int(run_store.dealer_tip_head_start()) != 0:
		failures.append("issue132: without the Tip the countdown should reset to the full cycle (%d vs %d)"
			% [plain_reset, plain_length])

	meta_store.chipAugmentsPurchased = { "aug_dealer_tip": 1 }
	if int(run_store.dealer_tip_head_start()) != ChipAugments.DEALER_TIP_HEAD_START:
		failures.append("issue132: the Tip did not grant its head start")
	# The scale must NOT shrink with the reset value: 10 of 12, not 0 of 10. Measuring
	# progress against the reset value would hide the head start completely.
	if int(run_store.dealer_countdown_cycle_length()) != plain_length:
		failures.append("issue132: the Tip shortened the countdown scale, hiding its own head start")
	var tipped := int(run_store.dealer_countdown_reset_value())
	if tipped != plain_length - ChipAugments.DEALER_TIP_HEAD_START:
		failures.append("issue132: tipped reset should be %d, got %d"
			% [plain_length - ChipAugments.DEALER_TIP_HEAD_START, tipped])
	# A resolved visit is what applies it — the countdown already running is untouched.
	run_store.dealerCountdown = 7
	run_store.decline_dealer_offer()
	if int(run_store.dealerCountdown) != tipped:
		failures.append("issue132: a resolved visit did not reset onto the tipped value (%d)"
			% int(run_store.dealerCountdown))

	meta_store.chipAugmentsPurchased = prev_augs
	run_store.augmentedTier = prev_tier
	# decline_dealer_offer commits, which can leave a RESUMABLE run on disk for the next
	# launch of this suite. Reset back to a non-resumable state so the save is cleared.
	run_store.reset_run_state()

## Emergency Reserve (issue #132): one paid spin back when the run is out of them, once
## per campaign, and never for a losing state it does not own.
func _check_emergency_reserve_132(failures: Array) -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var prev_augs: Dictionary = (meta_store.chipAugmentsPurchased as Dictionary).duplicate(true)
	var prev_used := bool(meta_store.emergencyReserveUsed)
	var prev_extra_granted := int(meta_store.extraSpinsGranted)

	meta_store.chipAugmentsPurchased = {}
	meta_store.emergencyReserveUsed = false
	if run_store.emergency_reserve_armed():
		failures.append("issue132: the reserve armed without the chip being owned")
	meta_store.chipAugmentsPurchased = { "aug_emergency_reserve": 1 }
	if not run_store.emergency_reserve_armed():
		failures.append("issue132: owning the chip did not arm the reserve")

	# Nothing left to play: the reserve pays exactly one paid spin back.
	var decay := maxi(1, Economy.compute_neuron_decay(run_store.ownedUpgrades))
	run_store.neurons = 0
	run_store.freeSpinsRemaining = 0
	var serial_before := int(run_store.emergencyReserveSerial)
	if not run_store._try_emergency_reserve(true):
		failures.append("issue132: the reserve did not fire on an exhausted paid spin")
	if int(run_store.neurons) != ChipAugments.EMERGENCY_RESERVE_SPINS * decay:
		failures.append("issue132: the reserve restored %d neurons, expected one spin's worth (%d)"
			% [int(run_store.neurons), ChipAugments.EMERGENCY_RESERVE_SPINS * decay])
	if int(run_store.emergencyReserveSerial) == serial_before:
		failures.append("issue132: the reserve did not signal the machine to animate")
	if not bool(meta_store.emergencyReserveUsed):
		failures.append("issue132: the reserve was not marked spent")

	# Once per campaign: a second exhaustion gets nothing, even in a brand new run.
	run_store.neurons = 0
	if run_store._try_emergency_reserve(true):
		failures.append("issue132: the reserve fired twice in one campaign")
	# A fresh run must not re-arm it. Detached store on purpose: start_new_run leaves a
	# RESUMABLE run behind, and persisting that on the shared store would make the next
	# launch of this suite resume a run and fail checks that expect a menu.
	var fresh_run: Node = (load("res://autoload/run_state_store.gd") as GDScript).new()
	fresh_run.start_new_run([], {}, false)
	fresh_run.neurons = 0
	fresh_run.freeSpinsRemaining = 0
	if fresh_run._try_emergency_reserve(true):
		failures.append("issue132: a fresh run re-armed a reserve already spent this campaign")
	fresh_run.free()

	# Exclusions: a free spin is not a paid one, and spins still in hand are not
	# exhaustion — the reserve is the LAST resort, not a top-up.
	meta_store.emergencyReserveUsed = false
	run_store.neurons = 0
	run_store.freeSpinsRemaining = 0
	if run_store._try_emergency_reserve(false):
		failures.append("issue132: the reserve fired on a free spin")
	run_store.freeSpinsRemaining = 2
	if run_store._try_emergency_reserve(true):
		failures.append("issue132: the reserve fired with free spins still banked")
	run_store.freeSpinsRemaining = 0
	run_store.neurons = 5
	if run_store._try_emergency_reserve(true):
		failures.append("issue132: the reserve fired with spins still left")

	meta_store.chipAugmentsPurchased = prev_augs
	meta_store.emergencyReserveUsed = prev_used
	meta_store.extraSpinsGranted = prev_extra_granted
	# Firing the reserve persists the spent flag on purpose, so the restore has to reach
	# the disk too — otherwise the next run of this suite loads a save carrying a chip
	# this test invented, and unrelated augment checks fail on it.
	meta_store.save_state()
	# Same reason as the Tip check: leave no resumable run behind for the next launch.
	run_store.reset_run_state()

## Symbol Level picker (issue #132): staging a pick spends the golden token on the spot
## and closes every "+", leaving only the picked symbol's "-" to take it back.
func _check_symbol_level_picker_132(failures: Array) -> void:
	var overlay: Node = (load("res://scenes/odds_table_overlay.tscn") as PackedScene).instantiate()
	get_root().add_child(overlay)
	overlay.open_augment_picker()
	var token: Sprite2D = overlay._tokens_sprite
	if token == null or overlay._plus_buttons.is_empty():
		failures.append("issue132: the augment picker did not build its table")
		overlay.queue_free()
		return
	# Before any pick: the golden token is held and eligible "+" are live.
	if int(token.frame) != overlay.TOKEN_GOLDEN_FRAME:
		failures.append("issue132: the picker did not start holding the golden token")
	var eligible: Array[String] = []
	for symbol_id in overlay._plus_buttons:
		if not (overlay._plus_buttons[symbol_id] as Button).disabled:
			eligible.append(String(symbol_id))
	if eligible.size() < 2:
		failures.append("issue132: the picker needs at least two eligible symbols to test")
		overlay.queue_free()
		return
	var picked := eligible[0]
	var other := eligible[1]
	overlay._on_plus_pressed(picked)
	if int(token.frame) != overlay.TOKEN_SPENT_FRAME:
		failures.append("issue132: staging a pick did not spend the golden token (frame %d)"
			% int(token.frame))
	if not (overlay._plus_buttons[picked] as Button).disabled:
		failures.append("issue132: the picked symbol's + stayed live")
	if not (overlay._plus_buttons[other] as Button).disabled:
		failures.append("issue132: another symbol's + stayed live after the token was spent")
	if (overlay._minus_buttons[picked] as Button).disabled:
		failures.append("issue132: the picked symbol's - should cancel the pick")
	if not (overlay._minus_buttons[other] as Button).disabled:
		failures.append("issue132: an unpicked symbol's - should stay dead")
	# Cancelling hands the token back and reopens every eligible "+".
	overlay._on_minus_pressed(picked)
	if int(token.frame) != overlay.TOKEN_GOLDEN_FRAME:
		failures.append("issue132: cancelling did not hand the golden token back")
	for symbol_id in eligible:
		if (overlay._plus_buttons[symbol_id] as Button).disabled:
			failures.append("issue132: cancelling left %s's + disabled" % symbol_id)
			break
	if String(overlay._augment_pick) != "":
		failures.append("issue132: cancelling left the pick staged")
	overlay.queue_free()

## The Pair/Triple picker is modal and swallows input, so its buttons landing outside the
## canvas was a hard lock, not a cosmetic slip (issue #132). Centred anchors made Godot
## read `position` as an offset FROM the centre and threw the panel to (92, 285) with its
## buttons at y=327, below the 320px bottom edge.
func _check_pair_triple_picker_bounds_132(failures: Array) -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	var shop: Node = (load("res://scenes/dealer_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(shop)
	shop._open_pair_triple_picker("aug_pair_triple")
	var picker: Node = shop.get_node_or_null("AugmentPicker")
	var panel := picker.get_node_or_null("PairTriplePanel") as Control if picker != null else null
	if panel == null:
		failures.append("issue132: the pair/triple picker did not build its panel")
		shop.queue_free()
		return
	var canvas := Rect2(0.0, 0.0, shop.CANVAS_W, shop.CANVAS_H)
	if not canvas.encloses(Rect2(panel.position, panel.size)):
		failures.append("issue132: the picker panel %s escapes the %s canvas"
			% [str(Rect2(panel.position, panel.size)), str(canvas.size)])
	# The buttons are the part that must be reachable — check each one, not just the panel.
	var row := panel.get_node_or_null("Buttons") as Control
	if row == null:
		failures.append("issue132: the picker has no button row")
	else:
		for child in row.get_children():
			var button := child as Control
			if button == null:
				continue
			var rect := Rect2(button.global_position, button.size)
			if not canvas.encloses(rect):
				failures.append("issue132: picker button %s at %s is off-screen"
					% [button.name, str(rect)])
	run_store.dealerAugmentOfferId = ""
	shop.queue_free()

## An armed Emergency Reserve glows the health tube's bottom chip, and stops the moment it
## is spent (issue #132).
func _check_reserve_glow_132(machine: Node, run_store: Node, failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var prev_augs: Dictionary = (meta_store.chipAugmentsPurchased as Dictionary).duplicate(true)
	var prev_used := bool(meta_store.emergencyReserveUsed)
	var prev_phase := String(run_store.runPhase)
	var glow: Sprite2D = machine._reserve_glow_sprite
	if glow == null:
		failures.append("issue132: the machine built no reserve glow")
	else:
		run_store.runPhase = "running"
		meta_store.chipAugmentsPurchased = { "aug_emergency_reserve": 1 }
		meta_store.emergencyReserveUsed = false
		machine._refresh_reserve_glow()
		if not glow.visible:
			failures.append("issue132: an armed reserve did not light the bottom chip")
		# It must sit ON the chip, not near it: the region is borrowed from the sheet's
		# own "one spin left" frame so the two can never drift apart.
		if not glow.region_enabled \
				or not is_equal_approx(glow.position.x, machine.HEALTH_BOTTOM_CHIP_RECT.position.x) \
				or not is_equal_approx(glow.position.y, machine.HEALTH_BOTTOM_CHIP_RECT.position.y):
			failures.append("issue132: the reserve glow is not registered on the bottom chip (%s)"
				% str(glow.position))
		# The borrowed region has to be frame 1 of the sheet as it is authored TODAY. A
		# re-export that adds or drops a frame changes the frame width, which would slide
		# the glow onto a neighbouring frame while every position check still passed.
		var tube: Sprite2D = machine._health_bar_sprite
		if tube != null and tube.texture != null and int(tube.hframes) > 0:
			var frame_w := float(tube.texture.get_width()) / float(tube.hframes)
			if not is_equal_approx(frame_w, machine.HEALTH_BAR_FRAME_W):
				failures.append("issue132: the tube's real frame width is %.1f, not HEALTH_BAR_FRAME_W %.1f"
					% [frame_w, machine.HEALTH_BAR_FRAME_W])
			var want_x: float = frame_w + machine.HEALTH_BOTTOM_CHIP_RECT.position.x
			if not is_equal_approx(glow.region_rect.position.x, want_x):
				failures.append("issue132: the glow borrows x=%.1f, but frame 1's chip is at x=%.1f"
					% [glow.region_rect.position.x, want_x])
		meta_store.emergencyReserveUsed = true
		machine._refresh_reserve_glow()
		if glow.visible:
			failures.append("issue132: a spent reserve kept glowing")
	meta_store.chipAugmentsPurchased = prev_augs
	meta_store.emergencyReserveUsed = prev_used
	run_store.runPhase = prev_phase
	machine._refresh_reserve_glow()

## The Tip's head start is drawn on the bar's first steps while the augment is owned
## (issue #132). The marker is a CHILD of the bar so it can never outlive it on screen —
## the bar is hidden from four unrelated places, and a sibling would have to be
## remembered in all of them.
func _check_dealer_tip_steps_132(machine: Node, failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var prev_augs: Dictionary = (meta_store.chipAugmentsPurchased as Dictionary).duplicate(true)
	var marker: Sprite2D = machine._dealer_tip_steps
	var bar: Sprite2D = machine._dealer_bar_sprite
	if marker == null:
		failures.append("issue132: the machine built no Dealer's Tip step marker")
	elif bar == null or marker.get_parent() != bar:
		failures.append("issue132: the Tip marker is not parented to the dealer bar")
	else:
		var prev_bar_visible := bar.visible
		bar.visible = true

		meta_store.chipAugmentsPurchased = {}
		machine._refresh_dealer_tip_steps()
		if marker.visible:
			failures.append("issue132: the Tip marker showed without the augment")

		meta_store.chipAugmentsPurchased = { "aug_dealer_tip": 1 }
		machine._refresh_dealer_tip_steps()
		if not marker.visible:
			failures.append("issue132: owning the Tip did not mark its head start on the bar")

		# The whole point of the parenting: a hidden bar takes the marker with it, without
		# the marker's own flag being touched.
		bar.visible = false
		if marker.is_visible_in_tree():
			failures.append("issue132: the Tip marker still drew with the dealer bar hidden")
		if not marker.visible:
			failures.append("issue132: hiding the bar cleared the Tip marker's own state")
		bar.visible = prev_bar_visible

	meta_store.chipAugmentsPurchased = prev_augs
	machine._refresh_dealer_tip_steps()

## Every augment must name feedback that a scene can actually route (issue #132), and a
## missing visual target must be survivable — the data says WHERE, the scene decides IF.
func _check_augment_feedback_map_132(failures: Array) -> void:
	var routed := ["spins", "dealer_bar", "offer_prices", "augment_price",
		"odds_row", "offer_slot", "message"]
	for augment_id in ChipAugments.ids():
		var fb := ChipAugments.feedback_for(String(augment_id))
		if fb.is_empty():
			failures.append("issue132: %s has no purchase feedback authored" % augment_id)
			continue
		var scene := String(fb.get("scene", ""))
		if scene != "dealer" and scene != "machine":
			failures.append("issue132: %s routes feedback to an unknown scene '%s'"
				% [augment_id, scene])
		if not routed.has(String(fb.get("target", ""))):
			failures.append("issue132: %s points at an unhandled target '%s'"
				% [augment_id, String(fb.get("target", ""))])
	# An unknown augment yields nothing rather than exploding.
	if not ChipAugments.feedback_for("aug_does_not_exist").is_empty():
		failures.append("issue132: an unknown augment invented feedback")
	# The icon sheet may not hold every chip's frame yet: the frame must clamp to what
	# the art can draw instead of slicing past the end of the texture.
	var assets: Node = get_root().get_node("Assets")
	var sheet: Texture2D = assets.texture(ChipAugments.ICON_SHEET)
	var frames := ChipAugments.icon_frames(sheet)
	for augment_id in ChipAugments.ids():
		var frame := ChipAugments.icon_frame(String(augment_id), frames)
		if frame < 0 or frame >= frames:
			failures.append("issue132: %s asks for icon frame %d of %d"
				% [augment_id, frame, frames])

## A wealth ending is where the campaign is torn down, so every consumer that reports on
## the finished campaign has to read BEFORE the chips are taken away. The win is recorded
## against the tier the run was actually played at, and only then does the campaign state
## go — clearing first would leave a later consumer reading an already-emptied campaign.
func _check_wealth_ending_augment_teardown_132(failures: Array) -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	var prev_tier := String(run_store.augmentedTier)

	run_store.augmentedTier = "heart"
	meta_store.history = {}
	meta_store.endingsReached = []
	meta_store.wealthEndingReached = false
	meta_store.campaignActive = true
	meta_store.campaignFailed = false
	meta_store.chipAugmentsPurchased = { "aug_dealer_tip": 1, "aug_emergency_reserve": 1 }
	meta_store.symbolAugmentLevels = { "eye": 2 }
	meta_store.pairTripleAugmentChoice = "pair"
	meta_store.extraSpinsGranted = 3
	meta_store.emergencyReserveUsed = true

	meta_store.mark_ending_reached("wealth")

	# The win landed on the played tier, not on "classic" or a tier the teardown mangled.
	if int(meta_store.tier_wins("heart")) != 1:
		failures.append("issue132: a wealth ending did not record the win on the active tier (heart=%d)"
			% int(meta_store.tier_wins("heart")))
	if int(meta_store.tier_wins("classic")) != 0:
		failures.append("issue132: a wealth ending credited the win to classic")
	# ... and the campaign teardown still happened, after the accounting.
	if not (meta_store.chipAugmentsPurchased as Dictionary).is_empty() \
			or not (meta_store.symbolAugmentLevels as Dictionary).is_empty() \
			or String(meta_store.pairTripleAugmentChoice) != "" \
			or int(meta_store.extraSpinsGranted) != 0 \
			or bool(meta_store.emergencyReserveUsed):
		failures.append("issue132: a wealth ending left campaign augments standing")
	if bool(meta_store.campaignActive):
		failures.append("issue132: a wealth ending left the campaign active")

	run_store.augmentedTier = prev_tier
	meta_store._apply(meta_before)
	meta_store.save_state()

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
	var prev_augs: Dictionary = (meta_store.chipAugmentsPurchased as Dictionary).duplicate(true)
	var prev_aug_offer := String(run_store.dealerAugmentOfferId)
	var prev_sym: Dictionary = (meta_store.symbolAugmentLevels as Dictionary).duplicate(true)
	var prev_pt := String(meta_store.pairTripleAugmentChoice)
	# Campaign state since issue #132, so it PERSISTS: leaving it bumped would carry into
	# the next launch of this suite instead of dying with the run.
	var prev_extra_granted := int(meta_store.extraSpinsGranted)
	var prev_weights: Dictionary = (run_store.oddsWeightOverrides as Dictionary).duplicate(true)
	var prev_bonuses: Dictionary = (run_store.symbolRewardBonuses as Dictionary).duplicate(true)
	var prev_neurons := int(run_store.neurons)
	var prev_owned: Array = (run_store.ownedUpgrades as Array).duplicate()

	# Fresh pre-run cycle: exactly one pool offer rolls. Augments persist for the
	# whole campaign — only a fresh Pacte run or a full reset clears them.
	run_store.runPhase = "idle"
	run_store.dealerPending = false
	run_store.dealerOfferIds = null
	run_store.prerunOfferIds = null
	meta_store.chipAugmentsPurchased = { "aug_extra_spins": 1 } # must survive the roll
	meta_store.pairTripleAugmentChoice = "pair"
	meta_store.symbolAugmentLevels = { "eye": 1 }
	meta_store.lucidityWallet = 1000
	run_store.ensure_prerun_offer(7)
	if int((meta_store.chipAugmentsPurchased as Dictionary).get("aug_extra_spins", 0)) != 1 \
			or String(meta_store.pairTripleAugmentChoice) != "pair" \
			or int((meta_store.symbolAugmentLevels as Dictionary).get("eye", 0)) != 1:
		failures.append("augments: a new cycle must keep the campaign's augments")
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
	meta_store.chipAugmentsPurchased = {}
	if int(run_store.consumable_price("cons_cigarette")) != 20:
		failures.append("augments: undiscounted consumable price wrong")
	run_store.dealerAugmentOfferId = "aug_consumable_discount"
	if not run_store.purchase_chip_augment("aug_consumable_discount"):
		failures.append("augments: consumable discount purchase refused")
	run_store.dealerAugmentOfferId = "aug_consumable_discount"
	run_store.purchase_chip_augment("aug_consumable_discount")
	if int(run_store.consumable_price("cons_cigarette")) != 16:
		failures.append("augments: two consumable discounts should stack 20 -> 16")
	if int((meta_store.chipAugmentsPurchased as Dictionary).get("aug_consumable_discount", 0)) != 2:
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
	if ChipAugments.eligible_ids(meta_store.chipAugmentsPurchased).has("aug_chip_discount"):
		failures.append("augments: maxed augment still in the eligible pool")

	# Insufficient funds: nothing charged, no stock consumed.
	run_store.lucidityCoins = 1
	run_store.dealerAugmentOfferId = "aug_extra_spins"
	if run_store.purchase_chip_augment("aug_extra_spins"):
		failures.append("augments: purchase succeeded without funds")
	if int(run_store.lucidityCoins) != 1 \
			or int((meta_store.chipAugmentsPurchased as Dictionary).get("aug_extra_spins", 0)) != 0:
		failures.append("augments: failed purchase charged or consumed stock")

	# Extra Spins: its single copy pays +3 spins through the neuron decay model, subject
	# to the MAX_NEURONS run cap, and a second purchase has no stock to consume.
	run_store.lucidityCoins = 500
	run_store.ownedUpgrades = []
	var decay := maxi(1, Economy.compute_neuron_decay([]))
	var neurons_before := int(run_store.neurons)
	run_store.dealerAugmentOfferId = "aug_extra_spins"
	run_store.purchase_chip_augment("aug_extra_spins")
	var expected_extra_spins := mini(EconomyConst.MAX_NEURONS, neurons_before + 3 * decay)
	if int(run_store.neurons) != expected_extra_spins:
		failures.append("augments: Extra Spins should respect the %d-spin cap"
			% EconomyConst.MAX_NEURONS)
	run_store.dealerAugmentOfferId = "aug_extra_spins"
	if run_store.purchase_chip_augment("aug_extra_spins"):
		failures.append("augments: Extra Spins sold a second copy of a 1-stock augment")

	# Symbol Level: needs a selection, raises the weight, honours the level-9 cap.
	meta_store.symbolAugmentLevels = {}
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
	# One augment level per symbol: the copy just spent on "eye" locks eye out, even
	# though its effective level is nowhere near the hard cap.
	meta_store.chipAugmentsPurchased = (meta_store.chipAugmentsPurchased as Dictionary).duplicate(true)
	meta_store.chipAugmentsPurchased["aug_symbol_level"] = 0
	run_store.dealerAugmentOfferId = "aug_symbol_level"
	var coins_before_second := int(run_store.lucidityCoins)
	if run_store.purchase_chip_augment("aug_symbol_level", "eye"):
		failures.append("augments: a symbol took a second augment level")
	if int(run_store.lucidityCoins) != coins_before_second \
			or int(run_store.symbol_augment_levels("eye")) != 1:
		failures.append("augments: refused second augment level still charged or stacked")

	# Level-9 cap: the augment level that lands on a maxed-out symbol adds the max-level
	# reward bonus a second time, and a symbol already at 9 is refused without charging.
	# Pick a symbol with no augment level yet so a real save on this machine can't skew it.
	var cap_sym := ""
	for s in ["vial", "syringe", "pill", "brain"]:
		if int(run_store.symbol_augment_levels(s)) == 0:
			cap_sym = s
			break
	if cap_sym == "":
		failures.append("augments: no un-augmented symbol available for the cap test")
	else:
		# Base level 8 (the odds-phase maximum) + the symbol's one augment level = 9.
		meta_store.oddsUpgrades = (meta_store.oddsUpgrades as Dictionary).duplicate(true)
		meta_store.oddsUpgrades[cap_sym] = int(run_store.odds_max_level)
		run_store.symbolRewardBonuses = {}
		meta_store.chipAugmentsPurchased["aug_symbol_level"] = 0
		run_store.dealerAugmentOfferId = "aug_symbol_level"
		if not run_store.purchase_chip_augment("aug_symbol_level", cap_sym): # -> level 9
			failures.append("augments: a maxed symbol refused its one augment level")
		var cap_bonus := float((run_store.symbolRewardBonuses as Dictionary).get(cap_sym, 0.0))
		if not is_equal_approx(cap_bonus, float(run_store.odds_max_level_reward_bonus)):
			failures.append("augments: level 9 should add the max-level reward bonus")
		if int(run_store.effective_symbol_level(cap_sym)) != ChipAugments.SYMBOL_LEVEL_HARD_CAP:
			failures.append("augments: base 8 plus an augment level should reach the level-9 cap")
		meta_store.chipAugmentsPurchased["aug_symbol_level"] = 0
		run_store.dealerAugmentOfferId = "aug_symbol_level"
		var coins_at_cap := int(run_store.lucidityCoins)
		if run_store.purchase_chip_augment("aug_symbol_level", cap_sym):
			failures.append("augments: symbol pushed past level 9")
		if int(run_store.lucidityCoins) != coins_at_cap:
			failures.append("augments: refused level-10 purchase still charged")
		meta_store.oddsUpgrades = {}

	# Expanded Selection: visits generate three consumables; rerolls keep three.
	meta_store.chipAugmentsPurchased = {}
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
	if String(meta_store.pairTripleAugmentChoice) != "triple":
		failures.append("augments: specialist triple choice not stored")
	meta_store.pairTripleAugmentChoice = ""
	meta_store.chipAugmentsPurchased = {}
	run_store.dealerAugmentOfferId = "aug_pair_triple"
	run_store.purchase_chip_augment("aug_pair_triple", "pair")
	if String(meta_store.pairTripleAugmentChoice) != "pair":
		failures.append("augments: specialist pair choice not stored")
	if ChipAugments.specialist_bonus(100, "triple", "triple") != 25 \
			or ChipAugments.specialist_bonus(100, "pair", "triple") != 0 \
			or ChipAugments.specialist_bonus(10, "pair", "pair") != 3: # 2.5 rounds up
		failures.append("augments: specialist bonus arithmetic wrong")

	# Pool exhaustion: everything at stock limit => no offer rolls.
	var maxed := {}
	for a in ChipAugments.LIST:
		maxed[String(a["id"])] = int(a["stock"])
	meta_store.chipAugmentsPurchased = maxed
	if String(run_store._roll_augment_offer(5)) != "":
		failures.append("augments: exhausted pool still rolled an offer")
	# One eligible augment left => the roll must offer exactly that one.
	var one_left: Dictionary = maxed.duplicate(true)
	one_left["aug_pair_triple"] = 0
	meta_store.chipAugmentsPurchased = one_left
	if String(run_store._roll_augment_offer(5)) != "aug_pair_triple":
		failures.append("augments: sole eligible augment was not offered")

	# UI: the augment stands on the far-right counter slot like a consumable —
	# priced tag above, name/rarity/stock/effect on select, drag-on-dealer to buy;
	# selector cancel never charges.
	run_store.runPhase = "idle"
	run_store.dealerPending = false
	run_store.dealerOfferIds = null
	run_store.prerunOfferIds = null
	meta_store.chipAugmentsPurchased = {}
	meta_store.symbolAugmentLevels = {}
	meta_store.pairTripleAugmentChoice = ""
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
				or not (meta_store.chipAugmentsPurchased as Dictionary).is_empty():
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

	# Run start folds pre-run purchases in. Issue #132: the chips are CAMPAIGN state, so
	# neither a new run, a Pacte, nor a full run reset may confiscate them — only the
	# campaign ending does. Uses a detached store so the ambient smoke state survives.
	var fresh: Node = (load("res://autoload/run_state_store.gd") as GDScript).new()
	meta_store.chipAugmentsPurchased = { "aug_extra_spins": 1 }
	meta_store.symbolAugmentLevels = { "eye": 1 }
	meta_store.pairTripleAugmentChoice = "pair"
	meta_store.extraSpinsGranted = 0
	fresh.start_new_run([], {}, false)
	if int((meta_store.chipAugmentsPurchased as Dictionary).get("aug_extra_spins", 0)) != 1 \
			or String(meta_store.pairTripleAugmentChoice) != "pair":
		failures.append("augments: run start dropped pre-run purchases")
	if int(fresh.neurons) != int(fresh.startingNeurons) + 3 * maxi(1, Economy.compute_neuron_decay([])):
		failures.append("augments: run start did not fold in pre-run Extra Spins")
	var eye_base := int(meta_store.odds_upgrade_level("eye")) * int(fresh.probability_increase_per_upgrade)
	if float((fresh.oddsWeightOverrides as Dictionary).get("eye", 0.0)) \
			!= float(eye_base + int(fresh.probability_increase_per_upgrade)):
		failures.append("augments: run start did not fold in pre-run symbol levels")
	if String(fresh.dealerAugmentOfferId) != "":
		failures.append("augments: run start left the shop augment offer open")
	# A Pacte run used to wipe the chips mid-campaign — the bug issue #132 is about.
	fresh.runPhase = "over"
	fresh.start_new_run([], {}, false, -1, true)
	if int((meta_store.chipAugmentsPurchased as Dictionary).get("aug_extra_spins", 0)) != 1 \
			or String(meta_store.pairTripleAugmentChoice) != "pair" \
			or int((meta_store.symbolAugmentLevels as Dictionary).get("eye", 0)) != 1:
		failures.append("issue132: a Pacte run confiscated the campaign's chip augments")
	fresh.reset_run_state()
	if int((meta_store.chipAugmentsPurchased as Dictionary).get("aug_extra_spins", 0)) != 1 \
			or String(meta_store.pairTripleAugmentChoice) != "pair":
		failures.append("issue132: a run reset confiscated the campaign's chip augments")
	# Only the campaign ending takes them away. Ending the campaign rewrites shared meta
	# state, so this snapshots and restores it — otherwise every later check inherits a
	# failed campaign.
	var campaign_before: Dictionary = meta_store._as_dict()
	meta_store.emergencyReserveUsed = true
	meta_store.mark_campaign_failed(false)
	var cleared := (meta_store.chipAugmentsPurchased as Dictionary).is_empty() \
		and (meta_store.symbolAugmentLevels as Dictionary).is_empty() \
		and String(meta_store.pairTripleAugmentChoice) == "" \
		and int(meta_store.extraSpinsGranted) == 0 \
		and not bool(meta_store.emergencyReserveUsed)
	meta_store._apply(campaign_before)
	if not cleared:
		failures.append("issue132: the campaign ending did not clear the chip augments")
	fresh.free()

	run_store.runPhase = prev_phase
	run_store.dealerPending = prev_pending
	run_store.dealerOfferIds = prev_offers
	run_store.dealerRerollCount = prev_reroll_count
	run_store.prerunOfferIds = prev_prerun
	run_store.lucidityCoins = prev_coins
	meta_store.chipAugmentsPurchased = prev_augs
	run_store.dealerAugmentOfferId = prev_aug_offer
	meta_store.symbolAugmentLevels = prev_sym
	meta_store.pairTripleAugmentChoice = prev_pt
	meta_store.extraSpinsGranted = prev_extra_granted
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
			if meter.frame_count != 34 or sprite.frame < 0 or sprite.frame >= meter.frame_count:
				failures.append("menu: meter is not using the 34-frame idle neuron animation")
		var death_sprites: Array[Sprite2D] = [
			meter.get_node_or_null("Death") as Sprite2D,
			meter.get_node_or_null("Death2") as Sprite2D,
			meter.get_node_or_null("Death3") as Sprite2D,
		]
		for index: int in range(death_sprites.size()):
			var death_sprite := death_sprites[index]
			if death_sprite == null or death_sprite.hframes != 3 or death_sprite.visible:
				failures.append("menu: meter is missing its hidden three-frame death overlay %d" % (index + 1))
		# Each loss finishes on frame 3 and remains as a permanent overlay. Later
		# losses must not clear the earlier damage (issue #176 feedback).
		var health_before_animation := int(meta_store.campaignNeuronsLeft)
		for remaining: int in [2, 1, 0]:
			meta_store.campaignNeuronsLeft = remaining
			meter.play_loss_animation()
			await create_timer(NeuronMeter.LOSS_ANIM_DELAY + 0.65).timeout
			var lost_count := int(meta_store.campaignNeuronsMax) - remaining
			for index: int in range(death_sprites.size()):
				var death_sprite := death_sprites[index]
				var expected_visible := index < lost_count
				if death_sprite == null or death_sprite.visible != expected_visible:
					failures.append("menu: neuron death overlay %d did not persist" % (index + 1))
				elif expected_visible and death_sprite.frame != NeuronMeter.DEATH_FRAME_COUNT - 1:
					failures.append("menu: neuron death overlay %d did not stop on frame 3" % (index + 1))
		meta_store.campaignNeuronsLeft = health_before_animation
		meter.refresh()
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
	if int(meta_store.campaign_starting_neurons) != 3:
		failures.append("issue38: campaigns should start at 3 neurons")
	# Wealth ending fires at the final 5000 target; the @export override threads through.
	if Endings.check_ending({ "scoreEarned": 5000, "neurons": 5 }, {}) != "wealth":
		failures.append("issue38: 5000 score did not trigger the wealth ending")
	if Endings.check_ending({ "scoreEarned": 4999, "neurons": 5 }, {}) != null:
		failures.append("issue38: sub-goal score triggered an ending")
	if Endings.check_ending({ "scoreEarned": 2500, "neurons": 5 }, {}, 3000) != null:
		failures.append("issue38: raised campaign_goal_score was ignored")
	# Exact GDD fatal copy remains on the transparent game-over overlay.
	machine._show_campaign_failed()
	var overlay: Control = machine._overlay
	if overlay == null or int(overlay.z_index) != int(machine.ENDING_OVERLAY_Z_INDEX):
		failures.append("issue38: campaign-failed overlay does not draw above the machine HUD art")
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
		# The table is stretched to the full width and lifted, so DONE hangs off its bottom
		# frame (document y239). Compared against the last ROW (document y223) rather than
		# the frame itself: Godot snaps control positions to whole pixels, so the button can
		# sit a pixel above the frame's fractional edge — what must never happen is it
		# covering a row.
		var last_row_bottom: float = 223.0 * float(overlay.CANVAS_FIT) + float(overlay.TABLE_LIFT.y)
		if done_button.position.y < last_row_bottom:
			failures.append("issue130: DONE button overlaps the last odds row")
		if done_button.position.y + done_button.size.y > 320.0:
			failures.append("issue130: DONE button hangs off the bottom of the canvas")
		# Sized up to read as a real button (follow-up tweak), but still well
		# inside the modal frame.
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
	# Measured against the authored rest scale, not the live one: the brain press
	# above leaves a TRANS_BACK pop tween running, and its overshoot briefly pushes
	# that icon past the box.
	var box_icons := 0
	for child in overlay.get_children():
		# Geometry is authored in document px, so the box column lands at
		# SYMBOL_BOX_CENTER scaled by CANVAS_FIT — as does the size the icon must fit in.
		if child is Sprite2D and (child as Sprite2D).centered \
				and is_equal_approx((child as Sprite2D).position.x,
					float(overlay.SYMBOL_BOX_CENTER.x) * float(overlay.CANVAS_FIT)
						+ float(overlay.TABLE_LIFT.x)):
			var icon := child as Sprite2D
			var rest_scale: Vector2 = icon.get_meta("rest_scale", icon.scale)
			var icon_w: float = float(icon.texture.get_width()) * rest_scale.x
			if icon_w <= float(overlay.ODD_ICON_SIZE) * float(overlay.CANVAS_FIT) + 0.01:
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
	# The bought level advances the row's meter to the next sheet frame (one frame is the
	# document width times however the sheet was exported).
	var brain_meter := level_sprites["brain"] as Sprite2D
	var brain_frame_step: float = float(overlay.ART_FRAME_SIZE.x) \
		* float(brain_meter.get_meta(&"art_scale", 1.0))
	if brain_meter.region_rect.position.x != brain_level_x0 + brain_frame_step:
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

	# A card earned on the run's last spin is celebrated AFTER the odds table, not over it:
	# the machine holds it through the target-reached hand-off, and the dealer hosts the
	# queue so the first quiet moment is the one after the table closes. Instantiating these
	# scenes touches run state, so this runs last and resets afterwards.
	var post_run_dealer := (load("res://scenes/dealer_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(post_run_dealer)
	if post_run_dealer._unlock_popup == null:
		failures.append("issue52: the dealer does not host the unlock queue")
	if post_run_dealer._odds_overlay != null and is_instance_valid(post_run_dealer._odds_overlay):
		post_run_dealer._odds_overlay.visible = true
		if post_run_dealer._can_present_card_unlock():
			failures.append("issue52: an unlock could take the screen over the odds table")
		post_run_dealer._odds_overlay.visible = false
		if not post_run_dealer._can_present_card_unlock():
			failures.append("issue52: the dealer never lets the unlock queue drain")
	post_run_dealer.queue_free()
	var handoff_machine := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(handoff_machine)
	handoff_machine._target_round_handoff = true
	if handoff_machine._can_present_card_unlock():
		failures.append("issue52: an unlock could interrupt the target-round hand-off")
	handoff_machine.queue_free()
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
	if machine._overlay == null \
			or int(machine._overlay.z_index) != int(machine.ENDING_OVERLAY_Z_INDEX):
		failures.append("flatline: ending overlay does not draw above the machine HUD art")
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
	if machine._overlay == null \
			or int(machine._overlay.z_index) != int(machine.ENDING_OVERLAY_Z_INDEX):
		failures.append("game over: ending overlay does not draw above the machine HUD art")
	var game_over_screen := machine._overlay.get_node_or_null("GameOverEndingOverlay") as Control
	if game_over_screen == null:
		failures.append("game over: dedicated screen missing when neurons are exhausted")
	else:
		var game_over_meter := _find_neuron_meter(game_over_screen)
		if game_over_meter == null:
			failures.append("game over: final neuron-loss meter is missing")
		else:
			for death_name: String in ["Death", "Death2", "Death3"]:
				var death_overlay := game_over_meter.get_node_or_null(death_name) as Sprite2D
				if death_overlay == null or not death_overlay.visible or death_overlay.hframes != 3:
					failures.append("game over: %s death overlay is not retained" % death_name)
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
	var run := { "neurons": 5, "scoreEarned": 5000, "lucidityCoins": 300 }

	# The authored four-reel odometer replaces the old progress bar and x/goal label.
	machine._set_display_lucidity(300, false)
	if machine._wealth_odometer == null or machine._wealth_odometer.get_value() != 300:
		failures.append("wealth: odometer did not initialize to 0300")

	run_store.runPhase = "running"
	# The store must mirror a continuable run (issue #62): CONTINUE is disabled
	# when no next spin is possible, and the guard reads the store, not `run`.
	run_store.neurons = 5
	run_store.freeSpinsRemaining = 0
	run_store.spinCount = 10
	run_store.scoreEarned = 300
	run_store.lucidityCoins = 300
	machine._show_ending("wealth", run)
	if machine._overlay == null \
			or int(machine._overlay.z_index) != int(machine.ENDING_OVERLAY_Z_INDEX):
		failures.append("wealth: ending overlay does not draw above the machine HUD art")
	var wallet_before := int(meta_store.lucidityWallet)
	var wealth_screen := machine._overlay.get_node_or_null("WealthEndingOverlay") as Control
	var texts := _overlay_label_texts(wealth_screen)
	for required_copy in ["You've become rich", "is it enough ?", "5,000"]:
		if not texts.has(required_copy):
			failures.append("wealth: missing ending copy %s" % required_copy)
	if texts.has("FINAL SCORE"):
		failures.append("wealth: final score caption should be removed")
	if wealth_screen != null and wealth_screen.get_node_or_null("TVPanel") != null:
		failures.append("wealth: overlay created a replacement TV panel")
	for node_name: String in [
		"WealthOdometer", "HealthBar"]:
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
		"WealthOdometer", "HealthBar"]:
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
	if coin_field == null or coin_field.get_child_count() < EconomyConst.WEALTH_SCORE_THRESHOLD:
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
	# Issue #181: the money fills the bottom THIRD and stops — no coin is given a resting
	# place above the ceiling, and none is left flying off the top of the canvas.
	if wealth_screen != null:
		var highest_target: float = wealth_screen.COIN_FLOOD_HEIGHT
		for target: Vector2 in wealth_screen._coin_targets:
			highest_target = minf(highest_target, target.y)
		if highest_target < wealth_screen.COIN_PILE_TOP_Y - 0.01:
			failures.append("issue181: the coin pile builds past its ceiling (top y %.1f)"
				% highest_target)
		# ...and that ceiling really is the bottom third of the canvas, so the title and the
		# score above it stay clear of the money.
		if not is_equal_approx(float(wealth_screen.COIN_PILE_TOP_Y),
				float(wealth_screen.CANVAS_SIZE.y) * 2.0 / 3.0):
			failures.append("issue181: the coin pile ceiling is not the bottom third (y %.1f)"
				% float(wealth_screen.COIN_PILE_TOP_Y))
		var last_release := 0.0
		for delay: float in wealth_screen._coin_delays:
			last_release = maxf(last_release, delay)
		if last_release > 12.0:
			failures.append("issue181: the coin flood still releases for %.1fs" % last_release)
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
	if score == null or score.text != "5,000":
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
	# The odometer has no goal suffix to mask after a Wealth continuation; it keeps
	# rolling the current total through the normal HUD refresh and scene-reentry paths.
	machine._refresh_tv_indicators()
	if machine._wealth_odometer == null or machine._wealth_odometer.get_value() != 300:
		failures.append("issue131: continued-run odometer did not preserve 0300")
	else:
		machine._wealth_odometer._drive_roll(0.5, 1999, 2000)
		var from_digits: Array[int] = [1, 9, 9, 9]
		var to_digits: Array[int] = [2, 0, 0, 0]
		for reel_index in 4:
			var reel := machine._wealth_odometer.get_node("Reel%d" % reel_index) as Control
			var current := reel.get_node("Current") as Sprite2D
			var next := reel.get_node("Next") as Sprite2D
			if current.frame != machine._wealth_odometer.FRAME_FOR_DIGIT[from_digits[reel_index]] \
					or next.frame != machine._wealth_odometer.FRAME_FOR_DIGIT[to_digits[reel_index]] \
					or not next.visible or is_equal_approx(current.position.y, next.position.y):
				failures.append("wealth: 1999 -> 2000 carry did not roll reel %d" % reel_index)
		machine._set_display_lucidity(450, false)
		if machine._wealth_odometer.get_value() != 450:
			failures.append("issue131: continued-run odometer did not update to 0450")
	# A fresh standard run restores a zero-padded mechanical readout.
	run_store.reset_run_state()
	machine._set_display_lucidity(300, false)
	if machine._wealth_odometer == null or machine._wealth_odometer.get_value() != 300:
		failures.append("wealth: fresh-run odometer did not restore 0300")
	if machine._overlay != null:
		machine._overlay.queue_free()
		machine._overlay = null
	machine._set_stash_tray_visible(true)
	meta_store._apply(meta_before)
	meta_store.save_state()

## Passive gain is score like any other, so a losing spin can beat a Wealth target with it
## alone. That spin also arms the combo-defeat warning, and the lever press that confirms
## the loss is the moment the payout has to appear — it must NOT also start a fresh spin
## underneath the overlay, which is what a dropped sequence lock used to allow.
func _check_passive_gain_target_176(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.ownedUpgrades = ["pacte_passive_gain"] # +10 Lucidity every spin
	run_store.neurons = 20
	run_store.wealthTargetIndex = 0                  # first target = 100
	run_store.scoreEarned = 95                       # 95 + 10 passive clears it
	run_store.lastResult = { "reels": ["eye", "vial", "pill"] }
	run_store.lockedReels = [true, true, true]       # pinned miss: the reels pay nothing
	run_store.lockedReelSpins = [5, 5, 5]
	run_store.isSpinning = false
	run_store.comboDefeatPending = false
	var spun: Variant = run_store.spin()
	run_store.set_spinning(false)
	if spun == null or int((spun as Dictionary).get("scoreEarned", -1)) != 0:
		failures.append("issue176: the passive-gain fixture should be a scoreless miss: %s" % str(spun))
	if int(run_store.scoreEarned) != 105:
		failures.append("issue176: passive gain did not reach the run score (%d, expected 105)"
			% int(run_store.scoreEarned))
	if not machine._wealth_target_due_now():
		failures.append("issue176: a target beaten by passive gain alone was not due")
	if not run_store.comboDefeatPending:
		failures.append("issue176: the losing fixture spin should arm the combo warning")
	var spins_before := int(run_store.spinCount)
	machine._do_spin() # the lever press that confirms the loss
	if not machine._wealth_target_transition_active:
		failures.append("issue176: confirming the loss did not proc the target payout")
	if int(run_store.spinCount) != spins_before:
		failures.append("issue176: the target payout was buried under a fresh spin (%d -> %d)"
			% [spins_before, int(run_store.spinCount)])
	machine._stop_wealth_target_transition()
	machine._wealth_target_transition_active = false
	machine._set_sequence_lock(false)
	machine._post_spin_sequence_active = false
	run_store.wealthTargetPending = false
	run_store.wealthTargetPendingValue = 0
	run_store.lockedReels = [false, false, false]
	run_store.ownedUpgrades = []
	run_store.reset_run_state()

func _check_wealth_target_flow_176(machine: Node, run_store: Node, meta_store: Node,
		failures: Array) -> void:
	# The target payout is a run-local sequence. Exercise the 500 milestone, its
	# centered presentation, the score remainder, and the shared Pacte visit gate.
	var meta_before: Dictionary = meta_store._as_dict()
	_check_passive_gain_target_176(machine, run_store, failures)
	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.neurons = 10
	run_store.scoreEarned = 650
	run_store.wealthTargetIndex = 2
	run_store.pacteThresholdVisits = 0
	var target_info: Dictionary = run_store.begin_wealth_target()
	if int(target_info.get("target", 0)) != 500:
		failures.append("issue176: current target did not resolve to 500")
	if not machine._start_wealth_target_transition(target_info):
		failures.append("issue176: target transition did not start")
	else:
		var overlay: Node = machine._wealth_target_transition
		if overlay == null:
			failures.append("issue176: target reached overlay was not created")
		else:
			# Issue #181: the number is the machine's own wealth reels, lifted off the
			# cabinet as a detached snapshot rather than retyped as a Label.
			if overlay._snapshot == null or overlay._snapshot.get_value() != 650:
				failures.append("issue181: target overlay did not lift the running score")
			if overlay.target_text() != "500":
				failures.append("issue181: target overlay did not show the beaten target")
			if overlay.title_label == null or overlay.title_label.text != "TARGET REACHED":
				failures.append("issue176: target overlay is missing its TARGET REACHED title")
			# The TV shuts down behind the payout, and the live reels blank the moment
			# the snapshot says it has lifted them.
			if machine._tv_blackout_rect == null or not machine._tv_blackout_rect.visible:
				failures.append("issue181: the payout screen did not shut the TV down")
			# Issue #184: the 150 made over the target is billed before it banks. The
			# receipt shows one row per charge and the reels settle on what survives,
			# so the screen and the wallet cannot disagree.
			var bill: Dictionary = EconomyConst.overflow_bill(150, 500)
			var net_overflow := int(bill["net"])
			if net_overflow >= 150 or net_overflow <= 0:
				failures.append("issue184: the overflow bill did not take a share of 150 (%d)"
					% net_overflow)
			overlay._skip_to_end()
			# The receipt is the target paid plus one row per charge, in that order.
			var rows: Array[String] = overlay.bill_text()
			var want_rows := EconomyConst.OVERFLOW_TAX_LINES.size() + 1
			if rows.size() != want_rows:
				failures.append("issue184: the payout screen printed %d bill rows, want %d"
					% [rows.size(), want_rows])
			# Read off the instance, not the class: naming the class here would make this
			# suite compile-depend on the overlay script, which is loaded before the
			# autoloads it needs exist.
			elif rows[0] != "%s -500" % String(overlay.TARGET_PAID_LABEL):
				failures.append("issue184: the target is not the head of the receipt (%s)"
					% rows[0])
			if overlay.net_banked() != net_overflow:
				failures.append("issue184: the receipt's net (%d) is not what banks (%d)"
					% [overlay.net_banked(), net_overflow])
			if overlay.net_label.text.find(str(net_overflow)) < 0:
				failures.append("issue184: the banked line does not show the net (%s)"
					% overlay.net_label.text)
			if overlay._snapshot.get_value() != net_overflow:
				failures.append("issue181: skipping the payout did not settle on the remainder")
			if machine._wealth_odometer.get_node("Reel3").visible:
				failures.append("issue181: the machine kept drawing the digits it handed over")
		machine._stop_wealth_target_transition()
		if machine._tv_blackout_rect != null and machine._tv_blackout_rect.visible:
			failures.append("issue181: the TV stayed dark after the payout screen closed")
		if not machine._wealth_odometer.get_node("Reel3").visible:
			failures.append("issue181: the machine never got its wealth digits back")
		machine._wealth_target_transition_active = false
		machine._set_sequence_lock(false)
	var wallet_before_payout := int(meta_store.lucidityWallet)
	var payout: Dictionary = run_store.complete_wealth_target()
	# Issue #184: the 150 made over the 500 target reaches the wallet minus the casino's
	# bill, and the run's score returns to zero either way.
	var expected_net := EconomyConst.overflow_after_tax(150, 500)
	if int(payout.get("overflow", -1)) != 150 \
			or int(payout.get("banked", -1)) != expected_net \
			or int(meta_store.lucidityWallet) != wallet_before_payout + expected_net \
			or int(run_store.scoreEarned) != 0 \
			or int(run_store.wealthTargetIndex) != 3:
		failures.append("issue181: 500 target did not bank the 150 overflow")
	# The rows the player was shown must add up to exactly what changed hands.
	var settled_bill: Dictionary = payout.get("bill", {})
	var row_total := 0
	for line: Dictionary in settled_bill.get("lines", []) as Array:
		row_total += int(line["amount"])
	if row_total + expected_net != 150:
		failures.append("issue184: the bill rows (%d) plus the net (%d) are not the overflow"
			% [row_total, expected_net])
	if not run_store.arm_pacte_for_wealth_target(500):
		failures.append("issue176: first 500 target did not arm Pacte")
	# Once the first visit is consumed, the same 500 milestone cannot arm it again,
	# while the second 1500/health-one visit remains available.
	run_store.pacteThresholdVisits = 1
	run_store.pacteThresholdPending = false
	run_store.pacteThresholdOpened = false
	if run_store.arm_pacte_for_wealth_target(500):
		failures.append("issue176: second event incorrectly reopened the first Pacte visit")
	if not run_store.arm_pacte_for_wealth_target(1500):
		failures.append("issue176: second Pacte milestone was consumed with the first")
	run_store.pacteThresholdVisits = 2
	run_store.pacteThresholdPending = false
	if run_store.arm_pacte_for_wealth_target(1500):
		failures.append("issue176: exhausted Pacte visits still accepted a target")
	# The health crossings use the same visit counter: 3 -> 2 arms visit one,
	# then 2 -> 1 arms visit two after the first visit has been consumed.
	run_store.reset_run_state()
	meta_store.campaignActive = true
	meta_store.campaignFailed = false
	meta_store.campaignNeuronsLeft = 3
	run_store.runPhase = "running"
	run_store.campaignNeuronPending = true
	run_store.pacteThresholdVisits = 0
	run_store.end_run("flatline")
	if int(meta_store.campaignNeuronsLeft) != 2 or not run_store.pacteThresholdPending:
		failures.append("issue176: health 3 -> 2 did not arm the first Pacte visit")
	run_store.runPhase = "running"
	run_store.lastEnding = null
	run_store.campaignNeuronPending = true
	run_store.pacteThresholdPending = false
	run_store.pacteThresholdVisits = 1
	run_store.pacteAfterFlatlinePending = false
	run_store.end_run("flatline")
	if int(meta_store.campaignNeuronsLeft) != 1 or not run_store.pacteThresholdPending:
		failures.append("issue176: health 2 -> 1 did not arm the second Pacte visit")
	# Round break: paying a target sends the run to the PERSISTENT dealer shop and the
	# next START begins a fresh run. Augments/powers/consumables, campaign health, the
	# advanced target, and the money left after the payout all carry; the run-spin
	# budget resets; and no campaign neuron is spent along the way.
	run_store.reset_run_state()
	meta_store.campaignActive = true
	meta_store.campaignFailed = false
	meta_store.campaignNeuronsLeft = 3
	run_store.runPhase = "running"
	run_store.campaignNeuronPending = true
	run_store.neurons = 4
	run_store.scoreEarned = 150
	run_store.wealthTargetIndex = 3
	run_store.selectedAugmentCardIds = ["issue176_kept_augment"]
	run_store.runConsumables = {"cons_tea": 1}
	if not run_store.begin_target_round():
		failures.append("issue176: begin_target_round did not open the dealer break")
	# The between-run dealer is the shared post-run flow (odds table -> shop), so the
	# target break parks at runPhase "over" just like a flatline continuation does.
	if String(run_store.runPhase) != "over" or not run_store.roundContinuationPending:
		failures.append("issue176: target break did not enter the shared between-run dealer")
	if not run_store.has_resume_state():
		failures.append("issue176: target break dealer visit is not resumable")
	if int(meta_store.campaignNeuronsLeft) != 3:
		failures.append("issue176: target break wrongly spent a campaign neuron")
	if not run_store.start_new_run([], {}):
		failures.append("issue176: could not start the next target round")
	if int(run_store.scoreEarned) != 0:
		failures.append("issue181: next round did not start from zero")
	if int(run_store.wealthTargetIndex) != 3:
		failures.append("issue176: next round lost the advanced target")
	if run_store.roundContinuationPending:
		failures.append("issue176: round continuation flag was not consumed")
	if not run_store.runConsumables.has("cons_tea"):
		failures.append("issue176: next round dropped the carried consumables")
	if run_store.selectedAugmentCardIds.is_empty():
		failures.append("issue176: next round dropped the selected augments")
	if int(meta_store.campaignNeuronsLeft) != 3:
		failures.append("issue176: starting the next round wrongly spent a campaign neuron")
	if String(run_store.runPhase) != "running":
		failures.append("issue176: next round did not enter the machine")
	# Issue #181: a consumable that was used does not come back. The meta stash is a
	# purchase order and it was delivered when the run started, so the between-round
	# dealer must not re-deliver it; and spending the last charge drops the entry
	# instead of carrying an empty stack into the next round.
	run_store.reset_run_state()
	meta_store.campaignNeuronsLeft = 3
	meta_store.pendingConsumables = { "cons_tea": 1 }
	run_store.start_new_run([], meta_store.get_pending_consumables(), false)
	if int(run_store.runConsumables.get("cons_tea", 0)) != 1:
		failures.append("issue181: the purchased consumable was not delivered")
	if not meta_store.pendingConsumables.is_empty():
		failures.append("issue181: the meta stash was not cleared once delivered")
	run_store.runPhase = "running"
	run_store.lastResult = { "reels": ["eye", "pill", "vial"], "isFreeSpin": false }
	if not run_store.use_consumable("cons_tea"):
		failures.append("issue181: the delivered consumable could not be used")
	if run_store.runConsumables.has("cons_tea"):
		failures.append("issue181: a spent consumable left an empty stack behind")
	run_store.wealthTargetIndex = 3
	run_store.begin_target_round()
	run_store.start_new_run([], meta_store.get_pending_consumables(), false)
	if run_store.runConsumables.has("cons_tea"):
		failures.append("issue181: a used consumable came back after the target break")
	# Issue #181/#184: beating target 100 with 152 banks the 52 overflow to the wallet
	# minus the casino's bill, and the next run starts from zero.
	run_store.reset_run_state()
	meta_store.campaignNeuronsLeft = 3
	meta_store.lucidityWallet = 400
	run_store.runPhase = "running"
	run_store.wealthTargetIndex = 0
	run_store.scoreEarned = 152
	var net_52 := EconomyConst.overflow_after_tax(52, 100)
	run_store.begin_wealth_target()
	var overflow: Dictionary = run_store.complete_wealth_target()
	if int(overflow.get("banked", -1)) != net_52:
		failures.append("issue181: paying target 100 out of 152 did not bank 52")
	if int(meta_store.lucidityWallet) != 400 + net_52:
		failures.append("issue181: the overflow never reached the wallet (%d)"
			% int(meta_store.lucidityWallet))
	if int(run_store.scoreEarned) != 0:
		failures.append("issue181: the run kept its score after banking the overflow")
	# The break's dealer is a pre-run shop, so he spends the wallet the overflow just
	# landed in — banking has to happen at the payout, not at the next run's start.
	run_store.begin_target_round()
	if String(run_store.runPhase) == "running":
		failures.append("issue181: the target break did not leave the machine")
	run_store.start_new_run([], {}, false)
	if int(run_store.scoreEarned) != 0:
		failures.append("issue181: the next run did not start from zero (%d)"
			% int(run_store.scoreEarned))
	# A claim that never reached its CONTINUE (scene left, app closed) is settled by the
	# round rollover instead of being dropped — dropping it left the overflow unbanked
	# and the target unadvanced, so it could be beaten twice.
	run_store.reset_run_state()
	meta_store.campaignNeuronsLeft = 3
	meta_store.lucidityWallet = 400
	run_store.runPhase = "running"
	run_store.wealthTargetIndex = 0
	run_store.scoreEarned = 152
	run_store.begin_wealth_target()
	run_store.begin_target_round()
	run_store.start_new_run([], {}, false)
	if int(meta_store.lucidityWallet) != 400 + net_52:
		failures.append("issue181: an unpaid target claim lost the overflow (%d)"
			% int(meta_store.lucidityWallet))
	if int(run_store.scoreEarned) != 0:
		failures.append("issue181: an unpaid target claim carried a score into the next run")
	if int(run_store.wealthTargetIndex) != 1:
		failures.append("issue181: an unpaid target claim left the target unadvanced")
	if run_store.wealthTargetPending:
		failures.append("issue181: the settled claim is still pending")
	# A flatline with campaign health left resumes the campaign at the target it died
	# on: the money is gone, but the player does not replay targets already beaten.
	run_store.reset_run_state()
	meta_store.campaignNeuronsLeft = 3
	run_store.runPhase = "running"
	run_store.campaignNeuronPending = true
	run_store.scoreEarned = 900
	run_store.wealthTargetIndex = 2
	run_store.end_run("flatline")
	if not run_store.start_new_run([], {}):
		failures.append("issue176: could not resume the campaign after a flatline")
	if int(run_store.wealthTargetIndex) != 2:
		failures.append("issue176: a flatline continuation reset the wealth target")
	if int(run_store.scoreEarned) != 0:
		failures.append("issue176: a flatline continuation kept the run's money")
	run_store.reset_run_state()
	meta_store._apply(meta_before)
	meta_store.save_state()

func _check_wealth_score_feed(machine: Node, run_store: Node, failures: Array) -> void:
	var previous_result: Variant = run_store.lastResult
	var previous_phase := String(run_store.runPhase)
	var previous_score := int(run_store.scoreEarned)
	var previous_lucidity := int(run_store.lucidityCoins)
	var previous_spin := int(run_store.spinCount)
	var previous_bet := int(run_store.lastEffectiveBet)
	var previous_burst_spin := int(machine._burst_prev_spin)
	var previous_burst_score := int(machine._burst_prev_score)
	var previous_display := int(machine._display_lucidity)
	run_store.runPhase = "running"
	run_store.scoreEarned = 42
	run_store.lucidityCoins = 0
	run_store.spinCount = 1
	run_store.lastEffectiveBet = 1
	run_store.lastResult = {
		"scoreEarned": 42,
		"winType": "pair",
		"reels": ["eye", "eye", "vial"],
		"scoreMultiplier": 1.0,
	}
	machine._burst_prev_spin = -1
	machine._burst_prev_score = 0
	machine._set_display_lucidity(0, false)
	machine._emit_score_burst(null)
	if machine._wealth_odometer == null or machine._wealth_odometer.get_value() != 42:
		failures.append("wealth: score popup did not advance the odometer without Lucidity coins")
	run_store.lastResult = previous_result
	run_store.runPhase = previous_phase
	run_store.scoreEarned = previous_score
	run_store.lucidityCoins = previous_lucidity
	run_store.spinCount = previous_spin
	run_store.lastEffectiveBet = previous_bet
	machine._burst_prev_spin = previous_burst_spin
	machine._burst_prev_score = previous_burst_score
	machine._set_display_lucidity(previous_display, false)

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
	run_store.scoreEarned = 5000
	run_store.wealthTargetIndex = EconomyConst.WEALTH_TARGETS.size() - 1
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
	run_store.wealthTargetIndex = 1 # keep the target-transition flow out of this flatline gate test
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
	run_store.wealthTargetIndex = 1
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

	# The core fix: you never die just for the spin count. With neurons on the bar,
	# a high spin count does not end the run; only the remaining spin pool does.
	run_store.runPhase = "running"
	run_store.lastEnding = null
	run_store.neurons = 5
	run_store.freeSpinsRemaining = 0
	run_store.wealthContinued = false
	run_store.spinCount = 999
	if machine._check_ending():
		failures.append("issue75: run with HP left flatlined from spin count alone")

	machine._set_stash_tray_visible(true)
	run_store.reset_run_state()
	meta_store._apply(meta_before)
	meta_store.save_state()

# Pacte augment presentation and the three revised run effects.
func _check_pacte_augment_effects(machine: Node, run_store: Node, failures: Array) -> void:
	var glitch_card := PacteCards.card("augment_glitch_2")
	if glitch_card.has("icon_rect"):
		failures.append("pacte augment: GLITCH 2 should not define an icon")
	for augment in PacteCards.AUGMENTS:
		var description := String(augment.get("description", ""))
		if description != description.to_upper():
			failures.append("pacte augment: %s description is not uppercase" % String(augment.get("id", "")))
	var pacte_ps := load("res://scenes/pacte_scene.tscn") as PackedScene
	var pacte := pacte_ps.instantiate() as Control
	var glitch_view: Control = pacte._make_card_view("augment_glitch_2", "augment")
	if glitch_view.get_node_or_null("Icon") != null:
		failures.append("pacte augment: GLITCH 2 still renders an icon")
	if glitch_view.get_node_or_null("GlitchFx") == null:
		failures.append("pacte augment: GLITCH 2 card is missing its intermittent tear effect")
	pacte.free()

	var saved_state: Dictionary = {}
	for property_name in run_store._run_state_properties():
		var value: Variant = run_store.get(property_name)
		if value is Array:
			saved_state[property_name] = (value as Array).duplicate(true)
		elif value is Dictionary:
			saved_state[property_name] = (value as Dictionary).duplicate(true)
		else:
			saved_state[property_name] = value

	var combo_effect: Sprite2D = machine._combo_effect_sprite
	if combo_effect == null or int(combo_effect.hframes) < 1 \
			or int(combo_effect.hframes) > machine.COMBO_EFFECT_FRAMES:
		failures.append("pacte augment: COMBO effect sheet has an invalid frame count")
	else:
		run_store.winBoostEnabled = true
		var last_combo_frame := int(combo_effect.hframes) - 1
		machine._show_combo_effect(last_combo_frame, 45, 45)
		if not combo_effect.visible or int(combo_effect.frame) != last_combo_frame \
				or machine._combo_payout_label == null \
				or String(machine._combo_payout_label.text) != "+ 45 (45%)":
			failures.append("pacte augment: COMBO did not show its frame and bonus")
		machine._stop_combo_effect()

	# Win Boost uses the 5/10/15...45% steps on successive paying results and
	# exposes the stage/bonus separately for the machine's second TV beat.
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.runPhase = "running"
	run_store.neurons = 35
	run_store.winBoostEnabled = true
	run_store.winBoostCombo = 0
	for expected_step in range(1, 10):
		var expected_percent := expected_step * 5
		run_store.lastResult = { "reels": ["eye", "eye", "vial"] }
		run_store.lockedReels = [true, true, true]
		run_store.lockedReelSpins = [2, 2, 2]
		var boosted: Variant = run_store.spin()
		run_store.set_spinning(false)
		if boosted == null:
			failures.append("pacte augment: Win Boost did not resolve stage %d" % expected_step)
			continue
		if int(boosted.get("winBoostPercent", 0)) != expected_percent \
				or int(boosted.get("winBoostCombo", 0)) != expected_step \
				or not bool(boosted.get("winBoostApplied", false)):
			failures.append("pacte augment: Win Boost did not reach %d%% on its streak" % expected_percent)
		var base_payout := int(boosted.get("scoreEarned", 0)) - int(boosted.get("winBoostBonus", 0))
		var expected_bonus := floori(float(base_payout) * float(expected_percent) / 100.0 + 0.5)
		if int(boosted.get("winBoostBonus", -1)) != expected_bonus:
			failures.append("pacte augment: Win Boost bonus did not match %d%% of the base payout" % expected_percent)
	if int(run_store.winBoostCombo) != 9:
		failures.append("pacte augment: Win Boost streak did not cap at x9")
	# A miss leaves the current COMBO stage in the same rescue window as the
	# frenzy loss. Confirming that loss clears the streak; the machine presentation
	# beeps while the decision is pending.
	run_store.winBoostCombo = 4
	run_store.lastResult = { "reels": ["eye", "vial", "pill"] }
	run_store.lockedReels = [true, true, true]
	var combo_miss: Variant = run_store.spin()
	run_store.set_spinning(false)
	if combo_miss == null or String(combo_miss.get("winType", "")) != "miss" \
			or int(run_store.winBoostCombo) != 4 \
			or not bool(run_store.comboDefeatPending):
		failures.append("pacte augment: a COMBO miss did not enter a recoverable warning")
	run_store.comboDefeatPending = true
	run_store.pendingComboMultiplier = 2
	machine._refresh_combo_effect()
	machine._show_pending_combo_defeat()
	if not combo_effect.visible or machine._combo_loss_beep_tween == null:
		failures.append("pacte augment: COMBO did not beep during its recoverable loss")
	run_store.resolve_pending_combo_defeat(false)
	machine._close_pending_combo_defeat()
	if int(run_store.winBoostCombo) != 0:
		failures.append("pacte augment: confirming COMBO loss did not clear its streak")

	# Glitch 2 advances the dealer by three steps even at the x3 gauge.
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.runPhase = "running"
	run_store.neurons = 35
	run_store.betMultiplier = 3
	run_store.glitchDealerStepActive = true
	run_store.dealerCountdown = 12
	run_store.lastResult = { "reels": ["eye", "eye", "vial"] }
	run_store.lockedReels = [true, true, true]
	run_store.lockedReelSpins = [2, 2, 2]
	var glitch_result: Variant = run_store.spin()
	run_store.set_spinning(false)
	if glitch_result == null or int(run_store.dealerCountdown) != 9:
		failures.append("pacte augment: GLITCH 2 did not move the dealer by three steps at x3")

	# Joker activates on the first three-flatline strike and its assist is not a
	# player power use. Try a few seeds because the assist is intentionally occasional.
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.runPhase = "running"
	run_store.pacteJokerArmed = true
	run_store.register_flatline_result()
	if not run_store.pacteJokerActive:
		failures.append("pacte augment: Joker did not activate after a three-flatline strike")
	run_store.spinCount = 1
	run_store.neurons = 35
	run_store.lastResult = {
		"reels": ["eye", "vial", "pill"], "scoreMultiplier": 1.0,
		"isFreeSpin": false, "scoreEarned": 0, "coinsEarned": 0,
		"freeSpinsGranted": 0, "freeSpinsAfter": 0,
	}
	var dealer_help: Dictionary = {}
	for candidate_seed in range(1, 128):
		run_store.pacteSeed = candidate_seed
		run_store.dealerHelpSpinCount = -1
		dealer_help = run_store.maybe_dealer_help()
		if not dealer_help.is_empty():
			break
	if dealer_help.is_empty():
		failures.append("pacte augment: Joker never produced a dealer assist")
	elif not run_store.abilitiesUsed.is_empty() or int(run_store.powersUsedThisSpin) != 0:
		failures.append("pacte augment: dealer assist consumed a player power")

	for property_name in saved_state:
		run_store.set(property_name, saved_state[property_name])
	run_store._commit()

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

	# The same flatline charge must also apply to a paying power result. Copying
	# the first reel onto the second turns the current reveal into an eye pair.
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.runPhase = "running"
	run_store.neurons = 100
	run_store.lastResult = {
		"reels": ["eye", "vial", "pill"], "scoreEarned": 0,
		"coinsEarned": 0, "freeSpinsGranted": 0, "freeSpinsAfter": 0,
		"isJackpot": false, "winType": "miss", "isFreeSpin": false,
		"scoreMultiplier": 1.0,
	}
	run_store.abilitiesUsed = []
	run_store.pendingPowerRestores = []
	run_store.flatlineWinBoostArmed = true
	if not run_store.copy_reel(0, 1):
		failures.append("issue174: power pair could not be resolved")
	else:
		var power_win: Dictionary = run_store.lastResult
		if not bool(power_win.get("flatlineBoostApplied", false)):
			failures.append("issue174: flatline charge did not boost a power win")
		var power_boost := int(power_win.get("flatlineBoostBonus", 0))
		if power_boost <= 0 or int(power_win["scoreEarned"]) != power_boost * 2 \
				or int(power_win["coinsEarned"]) != int(power_win["scoreEarned"]):
			failures.append("issue174: power flatline boost did not double score and coins")
		if run_store.flatlineWinBoostArmed:
			failures.append("issue174: power flatline charge was not consumed")

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
		if flavor._pos_label.text != "+ +40 SCORE & LUCIDITY":
			failures.append("issue76: water upside copy wrong: '%s'" % flavor._pos_label.text)
		flavor.queue_free()
	machine._pending_deferred_neg.clear()

# Issue #155: dealer pacing is a fixed visible countdown — no randomness. It starts at
# dealer_countdown_start, every spin advances it by the inverse multiplier step,
# 0 triggers the visit, and resolving the offer resets it.
func _check_dealer_pacing_76(run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)

	# The old hard cap (3) is gone — the ceiling is a high sentinel now.
	if run_store.dealer_max_count <= Dealer.MAX_COUNT:
		failures.append("issue76: dealer still capped at the old per-run limit (%d)" % run_store.dealer_max_count)

	# A fresh run starts the countdown at 12.
	if int(run_store.dealerCountdown) != 12 or int(run_store.dealer_countdown_start) != 12:
		failures.append("issue155: fresh run countdown should start at 12, got %d" % int(run_store.dealerCountdown))

	# x1 advances 3 steps, x2 advances 2, and x3 advances 1.
	# Locked reels keep the outcome deterministic (an eye pair pays every spin).
	run_store.neurons = 100
	run_store.betMultiplier = 1
	run_store.lastResult = { "reels": ["eye", "eye", "vial"] }
	run_store.lockedReels = [true, true, true]
	run_store.lockedReelSpins = [3, 3, 3]
	run_store.spin()
	run_store.set_spinning(false)
	if int(run_store.dealerCountdown) != 9:
		failures.append("issue155: x1 spin should advance the countdown to 9, got %d" % int(run_store.dealerCountdown))
	if int(run_store.betMultiplier) != 2:
		failures.append("issue155: a paying win should step the gauge to x2, got %d" % int(run_store.betMultiplier))
	run_store.spin()
	run_store.set_spinning(false)
	if int(run_store.dealerCountdown) != 7:
		failures.append("issue155: x2 spin should advance the countdown to 7, got %d" % int(run_store.dealerCountdown))
	run_store.spin()
	run_store.set_spinning(false)
	if int(run_store.dealerCountdown) != 6:
		failures.append("issue155: x3 spin should advance the countdown to 6, got %d" % int(run_store.dealerCountdown))

	# 0 triggers the visit deterministically; resolving the offer resets to 12.
	run_store.dealerCountdown = 0
	run_store.dealerIncoming = false
	run_store.dealerPending = false
	var count_before := int(run_store.dealerCount)
	run_store.check_dealer_trigger()
	if not bool(run_store.dealerIncoming) or int(run_store.dealerCount) != count_before + 1:
		failures.append("issue155: countdown 0 did not trigger the dealer")
	run_store.reveal_dealer()
	run_store.decline_dealer_visit()
	if int(run_store.dealerCountdown) != 12:
		failures.append("issue155: resolving the visit should reset the countdown to 12, got %d" % int(run_store.dealerCountdown))

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
	# The decay no longer scales with the gauge: three spins consume three of the
	# capped MAX_NEURONS pool.
	if int(run_store.neurons) != EconomyConst.MAX_NEURONS - 3:
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
	machine._close_pending_combo_defeat()
	machine._stop_win_animation()
	machine._stop_power_animation()
	machine._set_free_spin_display(false)
	var dealer_icon := machine.get_node_or_null("DealerIcon") as TextureRect
	if dealer_icon == null or dealer_icon.texture == null:
		failures.append("dealer icon: dealer portrait is missing from the TV")
	else:
		# The compact portrait sits immediately beside the bar and stays inside the
		# authored pink TV border.
		var tv_bounds := Rect2(float(machine.TV_SCREEN["left"]),
			float(machine.TV_SCREEN["top"]), float(machine.TV_SCREEN["width"]),
			float(machine.TV_SCREEN["height"]))
		var icon_rect := Rect2(dealer_icon.position, dealer_icon.size)
		if dealer_icon.position != machine.DEALER_ICON_POS \
				or dealer_icon.size != machine.DEALER_ICON_SIZE \
				or not tv_bounds.encloses(icon_rect) \
				or dealer_icon.position.x - 101.0 > 5.0:
			failures.append("dealer icon: compact portrait is not beside the bar inside the TV border")
		if machine.get_node_or_null("DealerCountdownTitle") != null:
			failures.append("dealer icon: old DEALER title label was not removed")
		if machine.get_node_or_null("DealerCountdownNumber") != null \
				or dealer_icon.get_node_or_null("DealerCountdownNumber") != null:
			failures.append("dealer icon: numeric countdown badge was not removed")
	var dealer_bar := machine.get_node_or_null("DealerBar") as Sprite2D
	if dealer_bar == null or dealer_bar.texture == null \
				or dealer_bar.hframes != int(machine.DEALER_BAR_FRAME_COUNT) \
				or dealer_bar.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		failures.append("dealer bar: 13-frame countdown sheet is missing")
	for expected in [
		["DealerBarOverlay1", machine.DEALER_BAR_OVERLAY_1_FRAMES],
		["DealerBarOverlay2", machine.DEALER_BAR_OVERLAY_2_FRAMES],
		["DealerBarOverlay3", machine.DEALER_BAR_OVERLAY_3_FRAMES],
	]:
		var overlay := machine.get_node_or_null(String(expected[0])) as Sprite2D
		if overlay == null or overlay.texture == null or overlay.hframes != int(expected[1]) \
				or overlay.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
			failures.append("dealer bar: %s animation sheet is missing or has the wrong frame count" % String(expected[0]))

	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.runPhase = "running"
	# Reroll is no longer implicit; opt into it here to cover the rescue path.
	run_store.ownedPowerIds = ["reroll"]
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
		if prompt != null:
			failures.append("combo pending: text bubble was not removed")
		if machine._pending_combo_overlay.get_node_or_null("Panel") != null:
			failures.append("combo pending: text panel was not removed")
		var loss_2_sprite := machine.get_node_or_null("ComboLoss2") as Sprite2D
		var loss_3_sprite := machine.get_node_or_null("ComboLoss3") as Sprite2D
		if loss_2_sprite == null or not loss_2_sprite.visible:
			failures.append("combo pending: x2 losing animation was not shown")
		if loss_3_sprite != null and loss_3_sprite.visible:
			failures.append("combo pending: x3 losing animation was shown for x2")
		machine._refresh_dealer_countdown()
		var dealer_bar_during_loss := machine._dealer_bar_sprite as Sprite2D
		if dealer_bar_during_loss == null or not dealer_bar_during_loss.visible \
				or machine._dealer_bar_overlay_1 == null \
				or not machine._dealer_bar_overlay_1.visible \
				or machine._dealer_bar_overlay_2 == null \
				or not machine._dealer_bar_overlay_2.visible \
				or machine._dealer_bar_overlay_3 == null \
				or not machine._dealer_bar_overlay_3.visible:
			failures.append("combo pending: pending x2 loss did not show all dealer warning overlays")
		if machine._combo_loss_beep_tween == null:
			failures.append("combo pending: x2 losing animation did not start beeping")
		if machine._pending_combo_overlay.get_node_or_null("Title") != null:
			failures.append("combo pending: old COMBO AT RISK headline was not removed")
		var reroll_button := machine._power_buttons.get("reroll") as Button
		if reroll_button == null or reroll_button.disabled:
			failures.append("combo pending: reroll was not enabled as a rescue power")
		var spin_button := machine._spin_button as Button
		if spin_button == null or spin_button.disabled:
			failures.append("combo pending: spin was not enabled to confirm the loss")
		# TABLES stays reachable during the losing state: the sequence lock alone
		# must not gate the odds overlay while a rescue decision is pending.
		if machine._score_button == null or machine._score_button.disabled:
			failures.append("combo pending: TABLES button read disabled during the losing state")
		machine._show_score_table()
		if machine._score_overlay == null:
			failures.append("combo pending: TABLES overlay did not open during the losing state")
		else:
			machine._close_score_table()
	machine._on_pending_combo_declined()
	if bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 1:
		failures.append("combo pending: confirming x2 did not settle at x1")

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

	# A pending decision remains visible until the player confirms it; there is no
	# timeout or automatic loss while an available rescue power still exists.
	run_store.abilitiesUsed = []
	run_store.betMultiplier = 2
	run_store.pendingComboMultiplier = 2
	run_store.comboDefeatPending = true
	machine._show_pending_combo_defeat()
	if not bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 2 \
			or machine._pending_combo_overlay == null:
		failures.append("combo pending: rescue window settled before spin confirmation")
	machine._on_pending_combo_declined()
	if bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 1:
		failures.append("combo pending: spin confirmation did not settle the one-level loss")

	# A failed already-spent power attempt leaves the rescue window active and must
	# not create a second reward or settle the loss before the next spin.
	run_store.abilitiesUsed = ["reroll"]
	run_store.betMultiplier = 2
	run_store.pendingComboMultiplier = 2
	run_store.comboDefeatPending = true
	machine._show_pending_combo_defeat()
	machine._apply_reel_power("reroll", 0)
	if not bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 2 \
			or machine._pending_combo_overlay == null:
		failures.append("combo pending: failed power attempt settled the loss too early")
	machine._on_pending_combo_declined()
	if bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 1:
		failures.append("combo pending: failed power was not settled by spin confirmation")

	# Simplified losing state: consumables stay usable while the warning beeps, no
	# text bubble may appear while it is active, and a corrective power/consumable
	# cancels the warning immediately — beep stopped and loss art removed before
	# the reward presentation, without waiting for the confirming spin.
	run_store.abilitiesUsed = []
	run_store.lastComboMultiplier = 2
	run_store.betMultiplier = 2
	run_store.pendingComboMultiplier = 2
	run_store.comboDefeatPending = true
	run_store.lastResult = { "reels": ["eye", "vial", "eye"], "isJackpot": false,
		"winType": "miss", "scoreEarned": 0, "coinsEarned": 0,
		"freeSpinsGranted": 0, "freeSpinsAfter": 0, "isFreeSpin": false,
		"scoreMultiplier": 1.0 }
	machine._show_pending_combo_defeat()
	run_store.runConsumables = { "item_water": 1 }
	machine._refresh_controls()
	if machine._stash_icons.size() > 0 \
			and machine._stash_icons[0].modulate != Color.WHITE:
		failures.append("combo pending: stash icons read disabled during the losing state")
	if machine._spawn_hint("item_water", false, false) != null:
		failures.append("combo pending: consumable text bubble appeared during the losing state")
	if not run_store.use_consumable("item_water"):
		failures.append("combo pending: consumables were blocked during the losing state")
	elif not bool(run_store.comboDefeatPending):
		failures.append("combo pending: a non-corrective consumable settled the losing state")
	run_store.pendingPowerRestores = []
	# Sync the burst tracker so the water's +40 lucidity doesn't add a long coin
	# flight to the copy's reward presentation.
	machine._coin_prev_lucidity = int(run_store.lucidityCoins)
	machine._copy_source = 0
	machine._on_copy_pick(1) # copy the eye onto the vial reel -> a rescuing triple
	if bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 3:
		failures.append("combo pending: copy-made win did not rescue the combo (got x%d)" % int(run_store.betMultiplier))
	if machine._pending_combo_overlay != null or machine._combo_loss_beep_tween != null:
		failures.append("combo pending: rescue did not cancel the warning immediately")
	var loss_2_rescued := machine.get_node_or_null("ComboLoss2") as Sprite2D
	var loss_3_rescued := machine.get_node_or_null("ComboLoss3") as Sprite2D
	if (loss_2_rescued != null and loss_2_rescued.visible) \
			or (loss_3_rescued != null and loss_3_rescued.visible):
		failures.append("combo pending: loss art stayed visible after the rescue")
	# Let the copy's in-flight reward presentation settle before the next blocks
	# re-open the pending window, so its tail cannot race their assertions.
	await machine.get_tree().create_timer(1.6).timeout
	run_store.runConsumables = {}

	# No available rescue power still waits for the next spin to confirm the loss.
	run_store.lastResult = { "reels": ["eye", "vial", "pill"], "isJackpot": false,
		"winType": "miss", "scoreEarned": 0, "coinsEarned": 0,
		"freeSpinsGranted": 0, "freeSpinsAfter": 0, "isFreeSpin": false,
		"scoreMultiplier": 1.0 }
	run_store.abilitiesUsed = ["reroll", "shift"]
	run_store.betMultiplier = 2
	run_store.pendingComboMultiplier = 2
	run_store.comboDefeatPending = true
	machine._show_pending_combo_defeat()
	if not bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 2:
		failures.append("combo pending: unavailable powers settled before spin confirmation")
	machine._on_pending_combo_declined()
	if bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 1:
		failures.append("combo pending: unavailable powers were not settled by spin confirmation")

	# Energy Drink is a corrective item for an x3 defeat: used from the stash it
	# clears the losing state and drops the beeping overlay immediately, leaving
	# the gauge capped at x2.
	run_store.abilitiesUsed = []
	run_store.betMultiplier = 3
	run_store.pendingComboMultiplier = 3
	run_store.comboDefeatPending = true
	run_store.runConsumables = { "item_energy_drink": 1 }
	# The rescue tail re-checks endings once the defeat clears; keep the run alive
	# so this block cannot flatline it for the checks that follow.
	run_store.neurons = 100
	machine._show_pending_combo_defeat()
	machine._on_stash_pressed(0)
	if bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 2:
		failures.append("combo pending: Energy Drink did not clear the x3 losing state to a capped x2")
	if machine._pending_combo_overlay != null or machine._combo_loss_beep_tween != null:
		failures.append("combo pending: Energy Drink rescue did not cancel the warning immediately")
	run_store.decaySkips = 0
	run_store.forcedRandomBetSpins = 0
	run_store.pendingCompulsiveSpinSkips = 0
	run_store.runConsumables = {}
	run_store.betMultiplier = 1
	machine._close_pending_combo_defeat()
	machine._stop_win_animation()
	machine._stop_power_animation()
	machine._set_tv_progress_bars_visible(true)

	# The FREE SPIN banner is state-driven: it shows while the next spin is free
	# (banked credit or Energy Drink rush), holds until the credit is spent, and
	# never blocks input. The off-TV spins tube stays visible alongside it. A grant
	# that lands mid-spin stays hidden until the reels stop so the reveal is not
	# spoiled.
	run_store.abilitiesUsed = []
	run_store.freeSpinsRemaining = 0
	run_store.decaySkips = 0
	run_store.neurons = 100
	machine._hud_delta_hold = false
	machine._set_sequence_lock(false)
	machine._update_hud()
	if bool(machine._free_spin_overlay_active):
		failures.append("free spin banner: active with no free credit")
	var spins_before_credit := int(machine._display_spins_left())
	run_store.freeSpinsRemaining = 1
	machine._update_hud()
	if machine.get_node_or_null("FreeSpinOverlay") == null or not bool(machine._free_spin_overlay_active):
		failures.append("free spin banner: banked free spin did not show the banner")
	if int(machine._display_spins_left()) != spins_before_credit:
		failures.append("free spin banner: free credit changed the SPINS LEFT counter")
	var spins_tube := machine._health_bar_sprite as CanvasItem
	if spins_tube == null or not spins_tube.visible:
		failures.append("free spin banner: spins tube should stay visible beside the banner")
	# The banner is not a modal: spin stays available while it blinks.
	machine._refresh_controls()
	if machine._spin_button != null and machine._spin_button.disabled:
		failures.append("free spin banner: spin button was blocked by the banner")
	# Spending the credit clears the banner on the next state refresh.
	run_store.freeSpinsRemaining = 0
	machine._update_hud()
	if bool(machine._free_spin_overlay_active):
		failures.append("free spin banner: did not clear once the credit was spent")
	# Energy Drink rush: the banner stays up for the whole no-decay effect.
	run_store.decaySkips = 2
	machine._update_hud()
	if not bool(machine._free_spin_overlay_active):
		failures.append("free spin banner: Energy Drink rush did not show the banner")
	run_store.decaySkips = 0
	machine._update_hud()
	# A grant made by the spin in flight must not light the banner until the reels
	# stop and the reward hold releases.
	machine._spinning_anim = true
	run_store.freeSpinsRemaining = 1
	machine._update_hud()
	if bool(machine._free_spin_overlay_active):
		failures.append("free spin banner: mid-spin grant revealed the result early")
	machine._spinning_anim = false
	machine._update_hud()
	if not bool(machine._free_spin_overlay_active):
		failures.append("free spin banner: banner did not appear after the reels stopped")

	# Restore the normal TV state for the remaining smoke checks.
	run_store.freeSpinsRemaining = 0
	machine._set_tv_progress_bars_visible(true)
	machine._update_hud()
	if spins_tube != null and not spins_tube.visible:
		failures.append("free spin banner: spins tube did not restore")
	machine._close_pending_combo_defeat()
	machine._stop_win_animation()
	machine._stop_power_animation()
	run_store.reset_run_state()
	machine._set_tv_progress_bars_visible(true)
	machine._update_hud()

# A PAIR/TRIPLE or power callout owns the TV outright while it plays: every persistent
# readout on the screen steps aside — the dealer countdown and his icon, the objective
# plate, the item/boost icons. The lit FREE SPIN banner is a weaker owner (issue #181): it
# takes the objective plate and the item/boost icons but leaves the dealer interface lit
# beside it. A callout outranks the banner, so it hides that too, and when it closes it
# hands the screen back to the banner and to the dealer strip the banner shares it with.
func _check_tv_information_priority(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.runPhase = "running"
	run_store.neurons = 10
	run_store.freeSpinsRemaining = 0
	run_store.dealerCountdown = 5
	run_store.betMultiplier = 3
	run_store.cocktailBoostSpins = 3 # one active boost, so a TV item icon is up
	machine._hud_delta_hold = false
	machine._spinning_anim = false
	machine._spin_launch_pending = false
	machine._stop_win_animation()
	machine._stop_power_animation()
	machine._tv_info_pop_sources.clear()
	machine._set_tv_progress_bars_visible(true)
	machine._update_hud()
	var free_spin := machine._free_spin_sprite as CanvasItem
	var dealer_bar := machine._dealer_bar_sprite as CanvasItem
	var dealer_icon := machine._dealer_icon as CanvasItem
	var target_bar := machine._target_bar_sprite as CanvasItem
	var boost_slot: CanvasItem = null
	if not machine._boost_indicator_slots.is_empty():
		boost_slot = (machine._boost_indicator_slots[0] as Dictionary)["slot"] as CanvasItem
	if free_spin != null and free_spin.visible:
		failures.append("TV callout priority: FREE SPIN banner showed without a credit")
	if dealer_bar == null or not dealer_bar.visible or dealer_icon == null or not dealer_icon.visible:
		failures.append("TV callout priority: dealer information did not establish its baseline")
	if target_bar == null or not target_bar.visible:
		failures.append("TV callout priority: objective readout did not establish its baseline")
	if boost_slot == null or not boost_slot.visible:
		failures.append("TV callout priority: boost icon did not establish its baseline")

	# A banked free spin lights the banner. It takes the objective plate, and leaves the
	# dealer interface lit beside it. Issue #185: the item icons stay lit too — the
	# banner drops to its lowered frame to clear the badge row instead of blanking it,
	# so what is running is still readable while the free spins are spent.
	run_store.freeSpinsRemaining = 1
	machine._update_hud()
	if free_spin == null or not free_spin.visible:
		failures.append("TV callout priority: FREE SPIN banner did not light")
	if target_bar != null and target_bar.visible:
		failures.append("TV callout priority: FREE SPIN did not hide the objective readout")
	if boost_slot == null or not boost_slot.visible:
		failures.append("issue185: FREE SPIN should keep the item icons lit beside it")
	if free_spin != null and int((free_spin as Sprite2D).frame) != machine.FREE_SPIN_FRAME_LOWERED:
		failures.append("issue185: FREE SPIN should drop to its lowered frame for the item icons")
	if (dealer_bar != null and not dealer_bar.visible) \
			or (dealer_icon != null and not dealer_icon.visible):
		failures.append("TV callout priority: FREE SPIN hid the dealer interface")

	machine._play_win_animation("pair", 20)
	if machine._win_anim_sprite == null or not machine._win_anim_sprite.visible:
		failures.append("TV callout priority: PAIR callout did not show")
	if (free_spin != null and free_spin.visible) or (dealer_bar != null and dealer_bar.visible) \
			or (dealer_icon != null and dealer_icon.visible) \
			or (target_bar != null and target_bar.visible) \
			or (boost_slot != null and boost_slot.visible):
		failures.append("TV callout priority: PAIR did not hide persistent TV information")
	machine._refresh_tv_indicators()
	if (free_spin != null and free_spin.visible) or (dealer_bar != null and dealer_bar.visible) \
			or (dealer_icon != null and dealer_icon.visible) \
			or (target_bar != null and target_bar.visible) \
			or (boost_slot != null and boost_slot.visible):
		failures.append("TV callout priority: HUD refresh overrode the PAIR priority")
	# Closing the callout hands the screen back to the banner, to the dealer strip and to
	# the item icons it shares it with; the objective plate keeps waiting the banner out.
	machine._stop_win_animation()
	if free_spin != null and not free_spin.visible:
		failures.append("TV callout priority: FREE SPIN banner did not restore after PAIR")
	if target_bar != null and target_bar.visible:
		failures.append("TV callout priority: PAIR restored the objective readout under the banner")
	if boost_slot != null and not boost_slot.visible:
		failures.append("issue185: item icons did not come back with the banner after PAIR")
	if (dealer_bar != null and not dealer_bar.visible) \
			or (dealer_icon != null and not dealer_icon.visible):
		failures.append("TV callout priority: dealer interface lost after PAIR under the banner")

	# Power callouts share the same priority, and overlapping callouts keep it held
	# until the last owner closes.
	var expected_power_frames: Dictionary = {
		"reroll": 0, "shift": 1, "memory": 2, "rewind": 3,
		"heart": 4, "cheat": 5, "swap": 6,
	}
	for power_id in expected_power_frames:
		machine._show_power_animation(String(power_id))
		if machine._power_anim_sprite == null \
				or int(machine._power_anim_sprite.frame) != int(expected_power_frames[power_id]):
			failures.append("TV callout priority: %s uses the wrong power animation frame" % power_id)
	machine._show_power_animation("reroll")
	if (free_spin != null and free_spin.visible) or (dealer_bar != null and dealer_bar.visible):
		failures.append("TV callout priority: power callout did not hide persistent TV information")
	machine._stop_power_animation()
	machine._play_win_animation("triple", 50)
	machine._show_power_animation("shift")
	machine._stop_win_animation()
	if free_spin != null and free_spin.visible:
		failures.append("TV callout priority: overlapping power callout released priority too early")
	machine._stop_power_animation()
	if free_spin != null and not free_spin.visible:
		failures.append("TV callout priority: FREE SPIN banner did not restore after overlapping pops")
	if not machine._tv_info_pop_sources.is_empty():
		failures.append("TV callout priority: stale callout owner remained active")

	# Spending the last credit puts the banner out and every readout comes back.
	run_store.freeSpinsRemaining = 0
	machine._update_hud()
	if free_spin != null and free_spin.visible:
		failures.append("TV callout priority: banner outlived its credit")
	if dealer_bar == null or not dealer_bar.visible or dealer_icon == null or not dealer_icon.visible:
		failures.append("TV callout priority: dealer information did not restore after FREE SPIN")
	if target_bar == null or not target_bar.visible:
		failures.append("TV callout priority: objective readout did not restore after FREE SPIN")
	if boost_slot == null or not boost_slot.visible:
		failures.append("TV callout priority: boost icon did not restore after FREE SPIN")
	run_store.cocktailBoostSpins = 0
	run_store.reset_run_state()
	machine._set_tv_progress_bars_visible(true)
	machine._update_hud()

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

	# Issue #155: the authored dealer bar and all warning sheets share one progress
	# frame. The bar starts at frame 0 for 0/12 progress, then walks through frames
	# 1..3 at 3/12 and 4..8 at 8/12; shorter warning sheets clamp only at their
	# final frame.
	var dealer_bar := machine._dealer_bar_sprite as Sprite2D
	var dealer_overlay_1 := machine._dealer_bar_overlay_1 as Sprite2D
	var dealer_overlay_2 := machine._dealer_bar_overlay_2 as Sprite2D
	var dealer_overlay_3 := machine._dealer_bar_overlay_3 as Sprite2D
	run_store.betMultiplier = 1
	run_store.isSpinning = false
	machine._spinning_anim = false
	machine._spin_launch_pending = false
	machine._hud_delta_hold = false
	run_store.dealerCountdown = 12
	machine._refresh_dealer_countdown()
	if dealer_bar == null or dealer_bar.frame != 0:
		failures.append("issue155: dealer bar did not start at frame 0")
	var previous_progress := 0
	for expected_progress in [3, 8, 12]:
		run_store.dealerCountdown = 12 - int(expected_progress)
		machine._refresh_dealer_countdown()
		for intermediate_frame in range(previous_progress + 1, int(expected_progress) + 1):
			machine._step_dealer_bar_progress(
				float(machine.DEALER_BAR_PROGRESS_FRAME_TIME) + 0.001)
			if dealer_bar == null or dealer_bar.frame != intermediate_frame:
				failures.append("issue155: dealer bar skipped frame %d while advancing to %d/12" \
					% [intermediate_frame, int(expected_progress)])
			if dealer_overlay_1 == null or dealer_overlay_1.frame != mini(intermediate_frame, dealer_overlay_1.hframes - 1) \
					or dealer_overlay_2 == null or dealer_overlay_2.frame != mini(intermediate_frame, dealer_overlay_2.hframes - 1) \
					or dealer_overlay_3 == null or dealer_overlay_3.frame != mini(intermediate_frame, dealer_overlay_3.hframes - 1):
				failures.append("issue155: dealer overlays did not follow intermediate frame %d" % intermediate_frame)
		previous_progress = int(expected_progress)
	# A two-step spin follows the same path instead of jumping directly to frame 2.
	run_store.dealerCountdown = 12
	machine._refresh_dealer_countdown()
	run_store.dealerCountdown = 10
	machine._refresh_dealer_countdown()
	for intermediate_frame in [1, 2]:
		machine._step_dealer_bar_progress(
			float(machine.DEALER_BAR_PROGRESS_FRAME_TIME) + 0.001)
		if dealer_bar == null or dealer_bar.frame != int(intermediate_frame):
			failures.append("issue155: two-step dealer bar transition skipped frame %d" % int(intermediate_frame))
	# PR #169: Club/Joker doubles the countdown, but the authored bar still spans
	# all 13 frames across the complete 24-step cycle.
	var previous_augmented_tier := String(run_store.augmentedTier)
	run_store.augmentedTier = "club"
	run_store.dealerCountdown = 24
	machine._refresh_dealer_countdown()
	if dealer_bar == null or dealer_bar.frame != 0:
		failures.append("pr169: Club dealer bar did not reset to frame 0 at countdown 24")
	run_store.dealerCountdown = 12
	machine._refresh_dealer_countdown()
	if int(machine._dealer_bar_target_frame) != 6:
		failures.append("pr169: Club dealer bar midpoint was not frame 6")
	for _step in 6:
		machine._step_dealer_bar_progress(
			float(machine.DEALER_BAR_PROGRESS_FRAME_TIME) + 0.001)
	if dealer_bar == null or dealer_bar.frame != 6:
		failures.append("pr169: Club dealer bar did not reach frame 6 at countdown 12")
	run_store.dealerCountdown = 0
	machine._refresh_dealer_countdown()
	if int(machine._dealer_bar_target_frame) != 12:
		failures.append("pr169: Club dealer bar did not target frame 12 at countdown 0")
	for _step in 6:
		machine._step_dealer_bar_progress(
			float(machine.DEALER_BAR_PROGRESS_FRAME_TIME) + 0.001)
	if dealer_bar == null or dealer_bar.frame != 12:
		failures.append("pr169: Club dealer bar did not reach its final frame")
	run_store.augmentedTier = previous_augmented_tier
	run_store.dealerCountdown = 12
	machine._refresh_dealer_countdown()
	run_store.betMultiplier = 3
	machine._refresh_dealer_countdown()
	if machine._dealer_bar_overlay_1 == null or not machine._dealer_bar_overlay_1.visible \
			or (machine._dealer_bar_overlay_2 != null and machine._dealer_bar_overlay_2.visible) \
			or (machine._dealer_bar_overlay_3 != null and machine._dealer_bar_overlay_3.visible):
		failures.append("issue155: x3 should show only dealer bar overlay 1")
	run_store.betMultiplier = 2
	machine._refresh_dealer_countdown()
	if machine._dealer_bar_overlay_2 == null or not machine._dealer_bar_overlay_2.visible \
			or machine._dealer_bar_overlay_1 == null or not machine._dealer_bar_overlay_1.visible:
		failures.append("issue155: x2 should show dealer bar overlays 1 and 2")
	run_store.betMultiplier = 1
	machine._refresh_dealer_countdown()
	if machine._dealer_bar_overlay_3 == null or not machine._dealer_bar_overlay_3.visible \
			or machine._dealer_bar_overlay_2 == null or not machine._dealer_bar_overlay_2.visible \
			or machine._dealer_bar_overlay_1 == null or not machine._dealer_bar_overlay_1.visible:
		failures.append("issue155: x1 should show all three dealer bar overlays")
	# Glitch 2 keeps all three warning sheets visible even while the gauge is x3.
	run_store.glitchDealerStepActive = true
	run_store.betMultiplier = 3
	machine._refresh_dealer_countdown()
	if dealer_overlay_1 == null or not dealer_overlay_1.visible \
			or dealer_overlay_2 == null or not dealer_overlay_2.visible \
			or dealer_overlay_3 == null or not dealer_overlay_3.visible:
		failures.append("issue155: Glitch 2 did not show all three dealer warning overlays")
	run_store.glitchDealerStepActive = false
	run_store.betMultiplier = 1
	# The lit stack pulses without changing the frame selected by countdown progress, so the
	# warning beeps but never spoils a different state.
	if dealer_overlay_1 != null:
		machine._refresh_dealer_countdown()
		dealer_overlay_1.modulate.a = 1.0
		machine._dealer_bar_overlay_beep_time = 0.0
		machine._step_dealer_overlay_beep(float(machine.DEALER_BAR_OVERLAY_BEEP_TIME) * 0.25)
		if dealer_overlay_1.modulate.a >= 0.99:
			failures.append("issue155: dealer warning overlays did not beep")
		machine._step_dealer_overlay_beep(float(machine.DEALER_BAR_OVERLAY_BEEP_TIME))
		if dealer_overlay_1.modulate.a < 0.99:
			failures.append("issue155: dealer warning overlay did not return to full alpha")
		# ...and a lone first light beeps too, just on the slower period: the cadence, not the
		# beep itself, is what tightens as the dealer closes in.
		run_store.betMultiplier = 3
		machine._refresh_dealer_countdown()
		dealer_overlay_1.modulate.a = 1.0
		machine._dealer_bar_overlay_beep_time = 0.0
		machine._step_dealer_overlay_beep(float(machine.DEALER_BAR_OVERLAY_BEEP_TIME) * 0.25)
		if dealer_overlay_1.modulate.a >= 0.99:
			failures.append("issue155: the x3 warning did not beep on its single light")
		if not is_equal_approx(float(machine._dealer_overlay_beep_period()),
				float(machine.DEALER_BAR_OVERLAY_SLOW_BEEP_PERIOD)):
			failures.append("issue155: one light should beep on the slow period")
		run_store.betMultiplier = 2
		machine._refresh_dealer_countdown()
		if not is_equal_approx(float(machine._dealer_overlay_beep_period()),
				float(machine.DEALER_BAR_OVERLAY_BEEP_PERIOD)):
			failures.append("issue155: the second light should tighten the beep cadence")
		if float(machine.DEALER_BAR_OVERLAY_SLOW_BEEP_PERIOD) \
				<= float(machine.DEALER_BAR_OVERLAY_BEEP_PERIOD):
			failures.append("issue155: the slow warning period is not slower than the fast one")
		run_store.betMultiplier = 1
	# A pending x2 loss falls to the x1 warning state, so it keeps the full
	# cumulative stack. Pending x1 stays at x1 and must do the same.
	run_store.comboDefeatPending = true
	run_store.pendingComboMultiplier = 2
	machine._refresh_dealer_countdown()
	if dealer_overlay_1 == null or not dealer_overlay_1.visible \
			or dealer_overlay_2 == null or not dealer_overlay_2.visible \
			or dealer_overlay_3 == null or not dealer_overlay_3.visible:
		failures.append("issue155: pending x2 loss did not show all three dealer overlays")
	run_store.pendingComboMultiplier = 1
	machine._refresh_dealer_countdown()
	if dealer_overlay_1 == null or not dealer_overlay_1.visible \
			or dealer_overlay_2 == null or not dealer_overlay_2.visible \
			or dealer_overlay_3 == null or not dealer_overlay_3.visible:
		failures.append("issue155: pending x1 loss changed the full dealer warning stack")
	run_store.comboDefeatPending = false
	run_store.pendingComboMultiplier = 1

	# A new spin keeps the warning lights hidden until its result/aftereffect hold
	# releases; otherwise the countdown would reveal the current spin's outcome.
	run_store.isSpinning = true
	machine._hud_delta_hold = true
	machine._refresh_dealer_countdown()
	if (dealer_overlay_1 != null and dealer_overlay_1.visible) \
			or (dealer_overlay_2 != null and dealer_overlay_2.visible) \
			or (dealer_overlay_3 != null and dealer_overlay_3.visible):
		failures.append("issue155: dealer warning overlays spoiled an in-flight spin")
	run_store.isSpinning = false
	machine._hud_delta_hold = false
	machine._refresh_dealer_countdown()
	if dealer_overlay_1 == null or not dealer_overlay_1.visible \
			or dealer_overlay_2 == null or not dealer_overlay_2.visible \
			or dealer_overlay_3 == null or not dealer_overlay_3.visible:
		failures.append("issue155: dealer warning overlays did not return after the result hold")

	# Energy Drink keeps the authored engaged x2-cap frame through both protected
	# spins and the queued compulsory spin, not only while forcedRandomBetSpins is > 0.
	run_store.betMultiplier = 2
	run_store.decaySkips = 2
	run_store.forcedRandomBetSpins = 2
	run_store.pendingCompulsiveSpinSkips = 0
	run_store.compulsiveSpinSkips = 0
	machine._refresh_multiplier_controls()
	if machine._multiplier_sprite != null and machine._multiplier_sprite.frame != 5:
		failures.append("energy drink: protected spins did not show the engaged x2-cap frame")
	# The drink's visual activation must win over a score-popup HUD hold; otherwise
	# the normal x2 frame remains on screen until an unrelated animation completes.
	machine._hud_delta_hold = true
	machine._refresh_multiplier_controls()
	if machine._multiplier_sprite != null and machine._multiplier_sprite.frame != 5:
		failures.append("energy drink: engaged x2-cap frame was deferred by HUD hold")
	machine._hud_delta_hold = false
	run_store.decaySkips = 0
	run_store.forcedRandomBetSpins = 0
	run_store.compulsiveSpinSkips = 1
	machine._refresh_multiplier_controls()
	if machine._multiplier_sprite != null and machine._multiplier_sprite.frame != 5:
		failures.append("energy drink: compulsory spin lost the engaged x2-cap frame")
	run_store.compulsiveSpinSkips = 0
	machine._refresh_multiplier_controls()
	if machine._multiplier_sprite != null and machine._multiplier_sprite.frame != 1:
		failures.append("energy drink: x2-cap frame did not release after activation")
	run_store.betMultiplier = 1

	# The Energy-Drink forced spin no longer forces x1: the badge keeps showing the
	# real gauge value through the compulsive phase.
	run_store.compulsiveSpinSkips = 2
	machine._refresh_multiplier_controls()
	if machine._multiplier_sprite != null and machine._multiplier_sprite.frame == 4:
		failures.append("issue76: multiplier showed forced x1 during compulsion (frame %d)" % machine._multiplier_sprite.frame)

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
	# Issue #181: the slots fill right to left and every one of them has to stay clear
	# of the TV bounds, the dealer icon, and the authored TARGET art below.
	var p0: Vector2 = (slots[0]["slot"] as Control).position
	var p1: Vector2 = (slots[1]["slot"] as Control).position
	if not is_equal_approx(p0.y, p1.y) or not (p1.x < p0.x):
		failures.append("issue181: boost icons did not fill right to left (%s vs %s)" % [p0, p1])
	var tv_left := float(machine.TV_SCREEN["left"])
	var tv_top := float(machine.TV_SCREEN["top"])
	var tv_bottom := tv_top + float(machine.TV_SCREEN["height"])
	var icon_size: float = machine.BOOST_ICON_SIZE
	var dealer_rect := Rect2(machine.DEALER_ICON_POS, machine.DEALER_ICON_SIZE)
	# Measured art extents of the TV's other occupants (see the constants' comment).
	# The widest goal frame runs x66..83; the bar spans the TV at y94..98.
	var goal_rect := Rect2(66.0, 86.0, 18.0, 5.0)
	var fill_bar_rect := Rect2(41.0, 94.0, 70.0, 5.0)
	for slot_pos: Vector2 in machine.BOOST_SLOT_POSITIONS:
		var rect := Rect2(slot_pos, Vector2(icon_size, icon_size))
		if rect.position.x < tv_left or rect.end.x > machine.TV_STATUS_RIGHT \
				or rect.position.y < tv_top or rect.end.y > tv_bottom:
			failures.append("issue181: boost slot %s falls outside the TV" % rect)
		if rect.intersects(dealer_rect):
			failures.append("issue181: boost slot %s collides with the dealer icon" % rect)
		if rect.intersects(goal_rect) or rect.intersects(fill_bar_rect):
			failures.append("issue181: boost slot %s collides with the TARGET art" % rect)
	# Issue #113: polarity rides a sign glyph, not the count colour alone. Slots 0 and 1
	# are the Energy Drink no-decay rush and the Cocktail — both pure upside now that the
	# Cocktail's pair/triple tax is gone, so both show "+" only.
	if not (slots[0]["pos_mark"] as Label).visible or (slots[0]["neg_mark"] as Label).visible:
		failures.append("issue113: pure-positive boost should show only the + mark")
	if not (slots[1]["pos_mark"] as Label).visible or (slots[1]["neg_mark"] as Label).visible:
		failures.append("issue113: the Cocktail should be pure upside (+ mark only)")
	# Tobacco still carries a live cost (3x pairs bought with a hidden reel), so it is the
	# mixed case: both marks at once. Shown alone — there are only two slots, and a third
	# simultaneous boost folds into a "+N" instead of getting its own badge.
	run_store.cocktailBoostSpins = 0
	run_store.decaySkips = 0
	run_store.pairBoostSpins = 4
	machine._refresh_boost_indicators()
	if not (slots[0]["pos_mark"] as Label).visible or not (slots[0]["neg_mark"] as Label).visible:
		failures.append("issue113: mixed Tobacco boost should show both + and - marks")
	run_store.pairBoostSpins = 0
	run_store.cocktailBoostSpins = 2
	run_store.decaySkips = 3
	machine._refresh_boost_indicators()
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
	run_store.pairBoostHiddenReels = 0
	machine._refresh_consumable_fx()
	# Tunnel Vision takes the third reel out of the scoring for the whole run, so the reel is
	# covered even with no consumable running — silently, without Tobacco's smoke.
	var prev_upgrades: Array = (run_store.ownedUpgrades as Array).duplicate()
	run_store.ownedUpgrades = ["pacte_tunnel_vision"]
	machine._refresh_consumable_fx()
	if not (machine._tobacco_covers[2] as ColorRect).visible:
		failures.append("issue181: Tunnel Vision did not hide the third reel")
	if machine._tobacco_smoke.size() > 2 \
			and bool((machine._tobacco_smoke[2] as CPUParticles2D).emitting):
		failures.append("issue181: Tunnel Vision should blind the reel without smoking it")
	run_store.ownedUpgrades = prev_upgrades
	machine._refresh_consumable_fx()
	if (machine._tobacco_covers[2] as ColorRect).visible:
		failures.append("issue181: the third reel stayed covered without Tunnel Vision")
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

## Issue #185: the Red Pill runs in two phases — a forced flatline, then the triple it
## promised — and had no TV badge at all, so the most dramatic item in the game ran
## invisibly. It gets ONE badge over both phases, counting the whole effect down.
func _check_red_pill_tv_badge_185(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	var slots: Array = machine._boost_indicator_slots
	if slots.is_empty():
		failures.append("issue185: boost indicator slots were not built")
		return
	var pill_boost := {}
	for boost: Dictionary in machine.DURATION_BOOSTS:
		if String(boost.get("id", "")) == "item_pill":
			pill_boost = boost
	if pill_boost.is_empty():
		failures.append("issue185: the Red Pill has no TV duration badge")
		return

	# Fresh out of the bottle: both phases pending, so the badge reads 2.
	run_store.forceFlatlineSpins = 1
	run_store.guaranteedTripleSpins = 1
	machine._refresh_boost_indicators()
	var slot := slots[0]["slot"] as Control
	if not slot.visible:
		failures.append("issue185: the Red Pill badge did not show")
	elif (slots[0]["count"] as Label).text != "2":
		failures.append("issue185: the Red Pill badge should count both phases, got '%s'"
			% (slots[0]["count"] as Label).text)
	var icon := (slots[0]["icon"] as TextureRect).texture
	if icon == null or not String(icon.resource_path).ends_with("items/pill.png"):
		failures.append("issue185: the Red Pill badge did not use the pill icon")
	# Both an upside and a live cost, so both polarity glyphs.
	if not (slots[0]["pos_mark"] as Label).visible \
			or not (slots[0]["neg_mark"] as Label).visible:
		failures.append("issue185: the Red Pill is mixed and should show both +/- marks")

	# The flatline is spent; the promised triple is still owed. ONE badge, now at 1 —
	# not a second badge appearing as the first disappears.
	run_store.forceFlatlineSpins = 0
	machine._refresh_boost_indicators()
	if not slot.visible:
		failures.append("issue185: the Red Pill badge vanished between its two phases")
	elif (slots[0]["count"] as Label).text != "1":
		failures.append("issue185: the Red Pill badge should read 1 after the flatline, got '%s'"
			% (slots[0]["count"] as Label).text)
	if slots.size() > 1 and (slots[1]["slot"] as Control).visible:
		failures.append("issue185: the Red Pill should occupy one badge, not one per phase")

	# Both phases spent: gone.
	run_store.guaranteedTripleSpins = 0
	machine._clear_boost_zero_linger()
	machine._refresh_boost_indicators()
	if slot.visible:
		failures.append("issue185: the Red Pill badge outlived both its phases")
	run_store.reset_run_state()

## Issue #185: a 12px icon cannot say what an item DOES. Tapping one pops its name and
## effect over the TV and the popup ages out on its own, without ever blocking input or
## outliving a callout that needs the screen.
func _check_item_badge_popup_185(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.runPhase = "running"
	var slots: Array = machine._boost_indicator_slots
	if slots.is_empty():
		failures.append("issue185: boost indicator slots were not built")
		return
	# Every badge must be able to describe itself, or tapping it is a dead end.
	for boost: Dictionary in machine.DURATION_BOOSTS:
		if String(boost.get("title", "")) == "" or String(boost.get("desc", "")) == "":
			failures.append("issue185: boost badge %s has no name/description to pop"
				% String(boost.get("counter", "?")))

	run_store.cocktailBoostSpins = 2
	machine._refresh_boost_indicators()
	var slot := slots[0]["slot"] as Control
	if not (slot is Button):
		failures.append("issue185: the item badge is not a clickable control")
		return
	if slot.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		failures.append("issue185: the item badge cannot receive a tap")

	machine._on_boost_indicator_pressed(0)
	var popup := machine._item_info_popup as Control
	if popup == null:
		failures.append("issue185: tapping an item badge popped nothing")
	else:
		var text_label := popup.find_child("Text", true, false) as Label
		if text_label == null or not text_label.text.contains("COCKTAIL"):
			failures.append("issue185: the popup did not name the item: '%s'"
				% ("" if text_label == null else text_label.text))
		elif text_label.text.length() <= String("COCKTAIL").length():
			failures.append("issue185: the popup named the item but did not describe it")
		if popup.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			failures.append("issue185: the popup must not eat taps meant for the machine")
		# It sits over the banner, the callouts and the dealer strip, or it is unreadable.
		if int(popup.z_index) <= 12:
			failures.append("issue185: the popup draws under the TV indicators")
		var tv_rect := Rect2(
			Vector2(machine.TV_SCREEN["left"], machine.TV_SCREEN["top"]),
			Vector2(machine.TV_SCREEN["width"], machine.TV_SCREEN["height"]))
		var popup_rect := Rect2(popup.position, machine.ITEM_INFO_POPUP_SIZE)
		if not tv_rect.encloses(popup_rect):
			failures.append("issue185: the popup %s spills outside the TV %s"
				% [popup_rect, tv_rect])

	# It leaves by itself in about a second — no second tap needed, nothing to dismiss.
	machine._step_item_info_popup(machine.ITEM_INFO_POPUP_HOLD * 0.5)
	if machine._item_info_popup == null:
		failures.append("issue185: the popup vanished before it could be read")
	machine._step_item_info_popup(machine.ITEM_INFO_POPUP_HOLD + machine.ITEM_INFO_POPUP_FADE)
	if machine._item_info_popup != null:
		failures.append("issue185: the popup outstayed its ~1s welcome")

	# A callout needs the whole screen: the popup gets out of the way with the badges.
	machine._on_boost_indicator_pressed(0)
	machine._play_win_animation("pair", 20)
	if machine._item_info_popup != null:
		failures.append("issue185: the popup survived a PAIR callout taking the TV")
	machine._stop_win_animation()

	# A hidden badge describes nothing — a tap racing the boost running out must not pop
	# the item that just expired.
	run_store.cocktailBoostSpins = 0
	machine._clear_boost_zero_linger()
	machine._refresh_boost_indicators()
	machine._on_boost_indicator_pressed(0)
	if machine._item_info_popup != null:
		failures.append("issue185: an expired badge still popped a description")
	machine._hide_item_info_popup()
	run_store.reset_run_state()

## Issue #185: the same fix as the evaluator checks, but driven through the real store
## path a power takes, because that is where the leak was actually felt — every rescore
## in the run handed Hallucination's cut to Evaluate as the general reward scale.
## The syringe triple the issue names is the case: built for real, it pays in full.
func _check_hallucination_machine_reaction_185(machine: Node, run_store: Node,
		failures: Array) -> void:
	var syringe_triple := int(Payouts.TRIPLE_SCORE["syringe"])
	var eye_pair := int(Payouts.PAIR_SCORE["eye"])

	# A natural triple, completed by CHEAT, with Hallucination owned. The promoted pair
	# it replaced was discounted, so the delta is the full triple minus that discount —
	# and the triple itself must never be cut.
	for owned: Array in [["pos_enlightenment"], []] as Array[Array]:
		run_store.reset_run_state()
		run_store.runPhase = "running"
		run_store.isSpinning = false
		run_store.ownedPowerIds = ["cheat"]
		run_store.abilitiesUsed = []
		run_store.powersUsedThisSpin = 0
		run_store.augmentedTier = ""
		run_store.ownedUpgrades = owned
		run_store.winBoostEnabled = false
		run_store.flatlineWinBoostArmed = false
		var opening := int(Evaluate.score_reels(["syringe", "syringe", "vial"], 1.0, true,
			false, false, 1.0, 0, not owned.is_empty(), 1.0, {}, false, 1.0,
			run_store._hallucination_reward_scale())["scoreEarned"])
		run_store.scoreEarned = opening
		run_store.lastPureWinScore = opening
		run_store.lastPureWinCoins = opening
		run_store.lastResult = {
			"reels": ["syringe", "syringe", "vial"], "scoreEarned": opening,
			"coinsEarned": opening, "freeSpinsGranted": 0, "freeSpinsAfter": 0,
			"isJackpot": false, "winType": "triple" if not owned.is_empty() else "pair",
			"isFreeSpin": false, "scoreMultiplier": 1.0,
		}
		var label := "with Hallucination" if not owned.is_empty() else "without it"
		if not run_store.cheat_symbol(2, "syringe"):
			failures.append("issue185: Cheat was refused building the syringe triple %s" % label)
			continue
		var result: Dictionary = run_store.lastResult
		# A new combination pays its own full value on top of the score already banked
		# (issue #181), so the GAIN is the triple — and it is the same number whether or
		# not Hallucination is owned. Only the opening pair differs, because that one was
		# a promotion and did pay the cut.
		var gain := int(run_store.scoreEarned) - opening
		if gain != syringe_triple:
			failures.append("issue185: the natural syringe triple paid %d %s, expected the full %d"
				% [gain, label, syringe_triple])
		if String(result.get("winType", "")) != "triple":
			failures.append("issue185: the syringe triple did not register as a triple %s" % label)
		if bool(result.get("hallucinatedTriple", false)):
			failures.append("issue185: a natural syringe triple was marked as promoted %s" % label)

	# The promoted pair itself still pays the card's 70% cut — the fix narrows where the
	# malus lands, it does not remove it.
	run_store.reset_run_state()
	run_store.ownedUpgrades = ["pos_enlightenment"]
	var promoted := Evaluate.score_reels(["eye", "eye", "vial"], 1.0, true,
		false, false, 1.0, 0, true, run_store._active_reward_scale(), {}, false, 1.0,
		run_store._hallucination_reward_scale())
	var full_eye_triple := int(Payouts.TRIPLE_SCORE["eye"])
	if String(promoted["winType"]) != "triple":
		failures.append("issue185: Hallucination stopped promoting a visible pair")
	elif int(promoted["scoreEarned"]) >= full_eye_triple:
		failures.append("issue185: the promoted triple paid %d, the undiscounted %d"
			% [int(promoted["scoreEarned"]), full_eye_triple])
	elif int(promoted["scoreEarned"]) <= eye_pair:
		failures.append("issue185: the promoted triple paid %d, no better than the pair %d"
			% [int(promoted["scoreEarned"]), eye_pair])

	# The general scale is where the leak lived: nothing but Tunnel Vision and the club
	# modifier may ride it.
	if not is_equal_approx(run_store._active_reward_scale(), 1.0):
		failures.append("issue185: owning Hallucination still taxes the general reward scale (%.3f)"
			% run_store._active_reward_scale())
	run_store.ownedUpgrades = []
	run_store.ownedPowerIds = []
	run_store.abilitiesUsed = []
	run_store.reset_run_state()

## Issue #185: Water used to land as a bare number. It now plays the authored 3-frame
## pour, which must live in godot/assets and clear itself when the run tears down.
func _check_water_animation_185(machine: Node, run_store: Node, failures: Array) -> void:
	var sheet := "res://assets/images/%s" % machine.WATER_SHEET
	if not ResourceLoader.exists(sheet):
		failures.append("issue185: the Water animation sheet is missing from godot/assets (%s)"
			% sheet)
		return
	var tex := load(sheet) as Texture2D
	if tex == null:
		failures.append("issue185: the Water sheet did not load as a texture")
		return
	# A full-canvas sheet: WATER_SHEET_FRAMES frames of the 160x320 virtual canvas.
	var frames: int = machine.WATER_SHEET_FRAMES
	if frames != 3:
		failures.append("issue185: the Water animation should be 3 frames, declared %d" % frames)
	if tex.get_width() != int(machine.SRC_W) * frames or tex.get_height() != int(machine.SRC_H):
		failures.append("issue185: the Water sheet is %dx%d, expected %dx%d for %d full-canvas frames"
			% [tex.get_width(), tex.get_height(), int(machine.SRC_W) * frames,
				int(machine.SRC_H), frames])

	run_store.reset_run_state()
	run_store.runPhase = "running"
	machine._play_water_animation()
	var sprite := machine._water_fx_sprite as Sprite2D
	if sprite == null:
		failures.append("issue185: using Water built no animation")
	else:
		if not sprite.visible:
			failures.append("issue185: the Water animation did not start")
		if sprite.hframes != frames:
			failures.append("issue185: the Water sprite sliced %d frames, expected %d"
				% [sprite.hframes, frames])
		if sprite.frame != 0:
			failures.append("issue185: the Water animation did not start on its first frame")
		# It is a one-shot, not a duration: it must not become another thing left running.
		machine._hide_water_animation()
		if sprite.visible:
			failures.append("issue185: the Water animation would not clear")
	run_store.reset_run_state()

## Issue #185: the complete item journey — the dealer offers it, TAKE puts it in the run
## stash, and the machine's own stash is where it is spent. The two halves were never
## covered end to end, so nothing caught a break between them.
func _check_dealer_item_usage_flow_185(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.isSpinning = false
	run_store.neurons = 10
	run_store.lucidityCoins = 0
	run_store.runConsumables = {}
	run_store.dealerPending = true
	run_store.dealerIncoming = true
	run_store.dealerOfferIds = ["item_water", "item_cocktail"]
	machine._set_sequence_lock(false)
	machine._update_hud()
	machine._show_dealer_offers()

	var popup = machine._dealer_offer_popup
	if popup == null:
		failures.append("issue185: the dealer offer overlay did not open")
		return
	# 1) The offer is SELECTED in the overlay: tapping arms TAKE with that item and
	# nothing is taken yet.
	popup._on_look_pressed()   # reveal the items; TAKE starts disabled
	popup._select_offer("item_cocktail")
	if String(popup._selected_offer_id) != "item_cocktail":
		failures.append("issue185: tapping an offer did not select it")
	if not run_store.runConsumables.is_empty():
		failures.append("issue185: selecting an offer took it without confirming")

	# 2) TAKE is what actually takes it, into the run stash.
	machine._dealer_take("item_cocktail")
	if int(run_store.runConsumables.get("item_cocktail", 0)) != 1:
		failures.append("issue185: TAKE did not put the item in the run stash (%s)"
			% str(run_store.runConsumables))
	if run_store.dealerPending:
		failures.append("issue185: taking an offer left the dealer visit unresolved")
	machine._close_dealer()

	# 3) The machine's stash is where it now lives, and where it is spent.
	machine._update_hud()
	var slots: Array = machine._stash_slots()
	if not slots.has("item_cocktail"):
		failures.append("issue185: the taken item never reached the machine stash (%s)"
			% str(slots))
		run_store.reset_run_state()
		return
	var slot_index := slots.find("item_cocktail")
	var stash_icons: Array = machine._stash_icons
	if slot_index < stash_icons.size():
		var stash_icon := stash_icons[slot_index] as TextureRect
		if stash_icon == null or stash_icon.texture == null:
			failures.append("issue185: the stash slot holding the item drew nothing")

	# 4) Using it from the stash spends the copy and starts the effect.
	if int(run_store.cocktailBoostSpins) != 0:
		failures.append("issue185: the Cocktail was already running before it was used")
	machine._on_stash_pressed(slot_index)
	if int(run_store.cocktailBoostSpins) <= 0:
		failures.append("issue185: using the item from the stash did not start its effect")
	if int(run_store.runConsumables.get("item_cocktail", 0)) != 0:
		failures.append("issue185: using the item did not spend the stash copy (%s)"
			% str(run_store.runConsumables))
	if machine._stash_slots().has("item_cocktail"):
		failures.append("issue185: the spent item is still in the machine stash")
	# 5) ...and the running effect is what the TV badge is now showing.
	machine._refresh_boost_indicators()
	if not machine._boost_indicators_showing():
		failures.append("issue185: the item was used but no TV badge reported it running")

	run_store.reset_run_state()

# Issue #76: the power gauge banks power points (10 points = 1 coin/frame, 50 = 5). Sub-10
# gains bank without a coin (no infinite loop), the gauge caps at 4/5 when no restore is
# available (discarding the excess, no fake-fill), and a fill commits one pending restore.
func _check_power_bar_76(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.runPhase = "running"

	if machine._power_bar_step() != 10:
		failures.append("issue76: power-bar step should be 10, got %d" % machine._power_bar_step())
	var pop: Sprite2D = machine._make_power_coin_pop() as Sprite2D
	if pop == null:
		failures.append("issue76: wealth power-coin pop animation asset is missing")
	else:
		if pop.hframes != 4 or pop.vframes != 1:
			failures.append("issue76: power-coin pop animation should expose four horizontal frames")
		if not String(pop.texture.resource_path).ends_with("power coin animation.png"):
			failures.append("issue76: wrong power-coin pop animation texture")
		pop.queue_free()
	if machine.WEALTH_COIN_ORIGIN == machine._cash_tray_pos():
		failures.append("issue76: wealth power coins still start in the cash tray")
	# The flight must begin where the pop's last frame leaves the coin, or the coin jumps at
	# the hand-off. Measured off the sheet so a re-exported animation is caught here.
	var pop_sheet := Image.load_from_file(
		"res://assets/images/machine new view/power coin animation.png")
	if pop_sheet != null:
		var pop_frame_w: int = pop_sheet.get_width() / 4
		var lo := Vector2i(999999, 999999)
		var hi := Vector2i(-1, -1)
		for y in pop_sheet.get_height():
			for x in pop_frame_w:
				if pop_sheet.get_pixel(3 * pop_frame_w + x, y).a <= 0.02:
					continue
				lo.x = mini(lo.x, x); lo.y = mini(lo.y, y)
				hi.x = maxi(hi.x, x); hi.y = maxi(hi.y, y)
		var pop_end := Vector2(float(lo.x + hi.x + 1) * 0.5, float(lo.y + hi.y + 1) * 0.5)
		if hi.x >= 0 and machine.WEALTH_COIN_ORIGIN.distance_to(pop_end) > 1.01:
			failures.append("issue76: power coin flight starts at %s but the pop ends at %s"
				% [str(machine.WEALTH_COIN_ORIGIN), str(pop_end)])

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

	# Cocktail rarity points are part of the wealth score and must feed the same 10-point
	# threshold even if the Lucidity marker has not caught up yet.
	machine._power_bar_score = 0
	machine._power_seen_lucidity = 0
	run_store.pendingPowerRestores = []
	run_store.scoreEarned = 17
	run_store.lucidityCoins = 0
	var cocktail_points: Dictionary = machine._compute_power_plan()
	if (cocktail_points["steps"] as Array).size() != 1 \
			or int(cocktail_points["score"]) != 17 \
			or int(cocktail_points["seen"]) != 17:
		failures.append("issue76: Cocktail score points did not advance the 10-point power threshold")

	# A restore queued by the spin fires before that spin's point fill, and the
	# queued power is not counted a second time as a bar-driven restore.
	machine._power_bar_score = 20
	machine._power_seen_lucidity = 0
	run_store.scoreEarned = 10
	run_store.lucidityCoins = 0
	run_store.pendingPowerRestores = ["reroll"]
	run_store.abilitiesUsed = []
	var restore_first: Dictionary = machine._compute_power_plan()
	var restore_first_steps: Array = restore_first["steps"]
	if restore_first_steps.size() != 2 \
			or not bool(restore_first_steps[0]["restore"]) \
			or bool(restore_first_steps[1]["restore"]) \
			or int(restore_first["score"]) != 10:
		failures.append("issue174: queued restore did not precede the point fill")

	run_store.scoreEarned = 60
	var restore_no_double: Dictionary = machine._compute_power_plan()
	var restore_no_double_steps: Array = restore_no_double["steps"]
	var restore_step_count := 0
	for stepd in restore_no_double_steps:
		if bool(stepd["restore"]):
			restore_step_count += 1
	if restore_step_count != 1 or int(restore_no_double["score"]) != 40:
		failures.append("issue174: queued restore was counted again by the power bar")

	# Cocktail can award points on a miss, which opens the combo-loss warning. The warning
	# must not swallow the already-landed threshold coin sequence.
	machine._power_bar_score = 0
	machine._power_seen_lucidity = 0
	machine._set_power_bar_frame(0)
	machine._power_coins_in_flight = 0
	machine._power_batch_running = false
	run_store.runPhase = "running"
	run_store.neurons = 100
	run_store.scoreEarned = 12
	run_store.lucidityCoins = 12
	run_store.abilitiesUsed = []
	run_store.pendingPowerRestores = []
	run_store.spinCount = 1
	run_store.lastResult = {
		"scoreEarned": 12,
		"coinsEarned": 12,
		"winType": "miss",
		"reels": ["eye", "vial", "pill"],
		"scoreMultiplier": 1.0,
		"cocktailApplied": true,
		"cocktailBonus": 12,
	}
	machine._burst_prev_spin = -1
	machine._burst_prev_score = 0
	machine._set_display_lucidity(0, false)
	machine._emit_score_burst(null)
	run_store.comboDefeatPending = true
	run_store.pendingComboMultiplier = 2
	machine._show_pending_combo_defeat()
	machine._try_start_power_coin_flow()
	if not machine._power_sequence_active():
		failures.append("issue76: Cocktail threshold coin was blocked by the combo-loss warning")
	await create_timer(0.95).timeout
	if int(machine._power_bar_frame) != 1:
		failures.append("issue76: Cocktail threshold coin did not reach power bar frame 1")
	machine._close_pending_combo_defeat()
	run_store.comboDefeatPending = false
	run_store.pendingComboMultiplier = 1
	machine._set_sequence_lock(false)
	machine._power_coins_in_flight = 0
	machine._power_batch_running = false
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

	# A queued restore fires first, then the same gain starts filling the reset gauge.
	machine._power_bar_score = 40
	machine._power_seen_lucidity = 100
	run_store.pendingPowerRestores = ["reroll"]
	run_store.lucidityCoins = 110
	var atcap: Dictionary = machine._compute_power_plan()
	if (atcap["steps"] as Array).size() != 2 \
			or not bool((atcap["steps"] as Array)[0]["restore"]) \
			or bool((atcap["steps"] as Array)[1]["restore"]):
		failures.append("issue174: 4/5 + 10 should restore before the new point coin")
	if int(atcap["score"]) != 10:
		failures.append("issue174: point fill after restore should leave 10 banked, got %d" % int(atcap["score"]))

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

# Per-spin restore cap (issue #181): a spin may hand back at most
# EconomyConst.POWER_RESTORE_CHARGE_MAX charges, one spent per restored power and one
# given back per spin, so the sustained rate is one restore per spin.
func _check_restore_cap_181(machine: Node, run_store: Node, failures: Array) -> void:
	var cap: int = EconomyConst.POWER_RESTORE_CHARGE_MAX

	# The planner stops at the cap and leaves the surplus abilities spent. Three
	# thresholds crossed, three powers down, but only `cap` come back.
	var spent_three: Array = ["reroll", "shift", "memory"]
	var capped: Dictionary = Lucidity.plan_gain(0, 150, spent_three, 12345,
		EconomyConst.LUCIDITY_COINS_PER_RESTORE, cap)
	if (capped["restores"] as Array).size() != cap:
		failures.append("issue181: capped plan returned %d restores, expected %d"
			% [(capped["restores"] as Array).size(), cap])
	if (capped["abilitiesUsed"] as Array).size() != spent_three.size() - cap:
		failures.append("issue181: capped plan freed the wrong number of abilities (%s)"
			% str(capped["abilitiesUsed"]))
	# The uncapped default is what the parity vectors pin — it must be untouched.
	var uncapped: Dictionary = Lucidity.plan_gain(0, 150, spent_three, 12345)
	if (uncapped["restores"] as Array).size() != 3:
		failures.append("issue181: the default (uncapped) plan lost a restore (%d of 3)"
			% (uncapped["restores"] as Array).size())

	run_store.reset_run_state()
	run_store.runPhase = "running"
	if int(run_store.restore_budget_left()) != cap:
		failures.append("issue181: a fresh run should start with the full restore budget")

	# The scenario: with the charges spent, the gauge must not complete. A spent power is
	# available and the gain is enormous, and it still holds one frame short of full —
	# the same shape as having nothing restorable at all.
	run_store.powerRestoreCharges = 0
	run_store.abilitiesUsed = ["reroll", "shift"]
	run_store.pendingPowerRestores = []
	run_store.scoreEarned = 0
	run_store.lucidityCoins = 200
	machine._power_bar_score = 0
	machine._power_seen_lucidity = 0
	var blocked: Dictionary = machine._compute_power_plan()
	for stepd in (blocked["steps"] as Array):
		if bool(stepd["restore"]):
			failures.append("issue181: the gauge restored a power with no charge left")
			break
	if int(blocked["score"]) != EconomyConst.LUCIDITY_COINS_PER_RESTORE - machine._power_bar_step():
		failures.append("issue181: a capped gauge did not hold at 4/5 (score %d)"
			% int(blocked["score"]))

	# The bar-driven restore refuses too, and leaves the spent power spent.
	if String(run_store.bar_restore_power(99)) != "":
		failures.append("issue181: bar_restore_power handed a power back with no charge")
	if (run_store.abilitiesUsed as Array).size() != 2:
		failures.append("issue181: a refused bar restore still emptied abilitiesUsed")

	# The light reads the charges: one frame per charge still banked, dark when spent.
	if machine._restore_cap_sprite == null:
		failures.append("issue181: the restore cap art is missing")
	elif int(machine.RESTORE_CAP_FRAMES) != cap + 1:
		failures.append("issue181: the cap art has %d frames but the pool holds %d charges"
			% [int(machine.RESTORE_CAP_FRAMES), cap])
	else:
		for charges in range(cap + 1):
			run_store.powerRestoreCharges = charges
			machine._refresh_restore_cap()
			var want := cap - charges # 0 charges spent = frame 0, fully spent = last frame
			if int(machine._restore_cap_sprite.frame) != want:
				failures.append("issue181: %d charge(s) banked lit frame %d, expected %d"
					% [charges, int(machine._restore_cap_sprite.frame), want])

	# The light must stay lit for a restore that is owed but not yet delivered, or it goes
	# dark seconds before the power returns and the two stop reading as one event.
	# plan_gain already took the power out of abilitiesUsed when it charged the light, so a
	# pending restore is a power the store considers back but the machine has not shown yet.
	run_store.powerRestoreCharges = 0
	run_store.abilitiesUsed = ["shift"]
	run_store.pendingPowerRestores = ["reroll"]
	if int(machine._shown_restore_charges()) != 1:
		failures.append("issue181: the light went dark while a restore was still owed (%d)"
			% int(machine._shown_restore_charges()))
	# Delivering it takes the light out on the same beat, and the flash announces both.
	machine._power_seen_lucidity = 0
	machine._resolve_bar_restore()
	if int(machine._shown_restore_charges()) != 0:
		failures.append("issue181: delivering the restore did not take the light out")
	if not run_store.pendingPowerRestores.is_empty():
		failures.append("issue181: the restore did not actually commit (%s)"
			% str(run_store.pendingPowerRestores))
	machine._stop_restore_flash()
	var flashed_chip: Sprite2D = machine._power_sprites.get("reroll") as Sprite2D
	if flashed_chip != null and flashed_chip.modulate != Color.WHITE:
		failures.append("issue181: the restore flash left the chip overdriven (%s)"
			% str(flashed_chip.modulate))
	if machine._restore_cap_glow != null and machine._restore_cap_glow.visible:
		failures.append("issue181: the restore glow was left painted on the gauge")

	# A spin gives back exactly one charge — not the whole pool. Nothing is spent, so the
	# spin's own plan restores nothing and cannot muddy the count.
	run_store.abilitiesUsed = []
	run_store.pendingPowerRestores = []
	run_store.neurons = 10
	run_store.isSpinning = false
	run_store.comboDefeatPending = false
	run_store.powerRestoreCharges = 0
	run_store.spin()
	if int(run_store.restore_budget_left()) != EconomyConst.POWER_RESTORE_RECHARGE_PER_SPIN:
		failures.append("issue181: a spin from empty should bank exactly %d charge, got %d"
			% [EconomyConst.POWER_RESTORE_RECHARGE_PER_SPIN, int(run_store.restore_budget_left())])

	# Recharging never runs past the cap, however long the player goes without restoring.
	run_store.isSpinning = false
	run_store.comboDefeatPending = false
	run_store.powerRestoreCharges = cap
	run_store.spin()
	if int(run_store.restore_budget_left()) != cap:
		failures.append("issue181: recharge overflowed the charge cap (%d of %d)"
			% [int(run_store.restore_budget_left()), cap])

	run_store.reset_run_state()

# Issue #66: +3 spin grants (3x vial, Tea's fallback) fly a "+N" into the
# spins-left counter; the counter includes free spins and only ticks up when the
# fly-in lands (value in sync with the effect).
func _check_spin_gain_fx_66(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.neurons = 10
	run_store.startingNeurons = EconomyConst.STARTING_NEURONS
	run_store.freeSpinsRemaining = 0
	# The REAL base cap (1): the user-reported bug was +3 grants clamping to +1.
	run_store.maxFreeSpins = 1
	machine._pending_spin_gain = 0
	machine._set_sequence_lock(false)
	machine._update_hud()
	var tube := machine._health_bar_sprite as Sprite2D
	if tube == null:
		failures.append("issue66: spins tube missing")
		return
	var before_n := int(machine._display_spins_left())
	var before_frame := int(tube.frame)

	# 3x vial restores +3 normal spins, spawns the fly-in, and holds the counter.
	machine._apply_symbol_triple("vial", 0, false)
	if int(run_store.freeSpinsRemaining) != 0:
		failures.append("issue66: 3x vial created free-spin credits instead of restoring spins")
	if machine.get_node_or_null("SpinGainFx") == null:
		failures.append("issue66: vial grant did not spawn the +3 fly-in")
	if int(machine._display_spins_left()) != before_n:
		failures.append("issue66: counter ticked before the vial fly-in landed")
	if int(tube.frame) != before_frame:
		failures.append("issue66: spins tube filled before the vial fly-in landed")
	await create_timer(1.3).timeout
	if int(machine._pending_spin_gain) != 0:
		failures.append("issue66: pending spin gain never landed")
	var after_n := int(machine._display_spins_left())
	if after_n != before_n + 3:
		failures.append("issue66: counter did not gain +3 in sync (was %d, now %d)" % [before_n, after_n])
	if int(tube.frame) <= before_frame:
		failures.append("issue66: spins tube did not refill with the +3 vial grant")

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
	var tea_before := int(machine._display_spins_left())
	machine._on_stash_pressed(0)
	if int(run_store.freeSpinsRemaining) != 0:
		failures.append("issue66: tea fallback created free-spin credits instead of restoring spins")
	if machine.get_node_or_null("SpinGainFx") == null:
		failures.append("issue66: tea restore did not spawn the +3 fly-in")
	if int(machine._display_spins_left()) != tea_before:
		failures.append("issue66: counter ticked before the tea fly-in landed")
	await create_timer(1.3).timeout
	if int(machine._display_spins_left()) != tea_before + 3:
		failures.append("issue66: tea +3 did not land in the spins counter")

	machine._pending_spin_gain = 0
	machine._set_sequence_lock(false)
	run_store.reset_run_state()

# Issue #80: the SPINS LEFT counter must drop with the neuron cost the instant the
# lever is pulled — while the HUD reward-delta hold (issue #54) is still active. A
# free spin GRANTED by that spin never enters the counter: the FREE SPIN banner
# carries the reward (the next spin is free, not +1 on the meter).
func _check_spins_bar_lever_80(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.runPhase = "running"
	run_store.startingNeurons = 10
	run_store.neurons = 10
	run_store.freeSpinsRemaining = 0
	machine._pending_spin_gain = 0
	machine._hud_delta_hold = false
	machine._set_sequence_lock(false)
	machine._update_hud()

	var tube := machine._health_bar_sprite as Sprite2D
	if tube == null:
		failures.append("issue80: spins tube missing")
		run_store.reset_run_state()
		return
	var full_spins := int(machine._display_spins_left())
	var full_frame := int(tube.frame)

	# Lever pull: the reward-delta hold is on, and spin() has spent the neuron cost.
	machine._hud_delta_hold = true
	run_store.neurons = 2
	machine._update_hud()
	var during_hold := int(machine._display_spins_left())
	if during_hold >= full_spins:
		failures.append("issue80: SPINS LEFT did not drop on lever pull while the HUD was held")
	if int(tube.frame) >= full_frame:
		failures.append("issue80: spins tube did not drain on lever pull while the HUD was held")

	# A free spin granted by the same spin never enters the counter, held or not.
	run_store.freeSpinsRemaining = 1
	machine._update_hud()
	if int(machine._display_spins_left()) != during_hold:
		failures.append("issue80: granted free spin leaked into SPINS LEFT during the hold")

	# Releasing the hold (score popup landed) lights the FREE SPIN banner instead.
	machine._release_hud_delta_hold()
	if int(machine._display_spins_left()) != during_hold:
		failures.append("issue80: free spins must not inflate SPINS LEFT after release")
	if not bool(machine._free_spin_overlay_active):
		failures.append("issue80: released free-spin grant did not light the FREE SPIN banner")

	machine._hud_delta_hold = false
	machine._pending_spin_gain = 0
	run_store.freeSpinsRemaining = 0
	machine._update_hud()
	run_store.reset_run_state()

# Issue #85/#80/#75: with a single 1:1 spin currency SPINS LEFT is the capped neuron
# pool (plus banked free spins). The readout turns dark red at the MAX_NEURONS maximum.
func _check_spins_counter_accuracy_80(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	run_store.runPhase = "running"
	run_store.startingNeurons = EconomyConst.STARTING_NEURONS
	run_store.neurons = EconomyConst.MAX_NEURONS
	run_store.freeSpinsRemaining = 0
	run_store.spinCount = 0
	machine._pending_spin_gain = 0
	machine._hud_delta_hold = false
	machine._set_sequence_lock(false)
	machine._update_hud()

	var before := int(machine._display_spins_left())
	if before != EconomyConst.MAX_NEURONS:
		failures.append("issue85: SPINS LEFT should cap at %d, got %d"
			% [EconomyConst.MAX_NEURONS, before])
	# The tube and number both show their full state at the cap: the top frame of the
	# sheet is the cap itself, so a raised cap must reach real authored art.
	var tube := machine._health_bar_sprite as Sprite2D
	if tube != null and int(tube.frame) != EconomyConst.MAX_NEURONS:
		failures.append("issue85: spins tube showed frame %d at the %d-spin cap"
			% [int(tube.frame), EconomyConst.MAX_NEURONS])
	if machine._spins_left_label == null \
			or machine._spins_left_label.get_theme_color("font_color") != machine.SPINS_LEFT_MAX_COLOR:
		failures.append("issue85: max SPINS LEFT number did not turn dark red")

	# A +3 vial restore adds its three spins to a starting pool, never past the cap.
	run_store.neurons = EconomyConst.STARTING_NEURONS
	machine._update_hud()
	var restore_before := int(machine._display_spins_left())
	machine._apply_symbol_triple("vial", 0, false)
	await create_timer(1.3).timeout # let the +3 fly-in land
	var after := int(machine._display_spins_left())
	var restore_expected := mini(EconomyConst.MAX_NEURONS, restore_before + 3)
	if after != restore_expected:
		failures.append("issue80: +3 vial restore landed at %d, expected %d"
			% [after, restore_expected])

	# Directly oversized/legacy state is clamped visually and by the store's next
	# committed result; it can never display more than the cap.
	run_store.neurons = 100
	run_store.freeSpinsRemaining = 0
	run_store.spinCount = 500
	machine._pending_spin_gain = 0
	machine._update_hud()
	var capped := int(machine._display_spins_left())
	if capped != EconomyConst.MAX_NEURONS:
		failures.append("issue75: SPINS LEFT exceeded the %d-spin cap (read %d)"
			% [EconomyConst.MAX_NEURONS, capped])

	machine._pending_spin_gain = 0
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
	# Shift and Reroll are optional Pacte powers, and Random must never redraw the
	# symbol already sitting on its target reel.
func _check_starting_powers_and_random_118(run_store: Node, failures: Array) -> void:
	# Starting loadout: a fresh run with zero purchased permanents has neither
	# Shift nor Reroll. Permanent Memory remains available when it is owned.
	for owned_permanents in [[], ["perm_memory"]]:
		run_store.reset_run_state()
		run_store.start_new_run(owned_permanents, {}, false)
		if (run_store.ownedPowerIds as Array).has("shift") \
				or (run_store.ownedPowerIds as Array).has("reroll"):
			failures.append("issue118: new run injected Shift/Reroll into the default loadout")
		if owned_permanents.has("perm_memory") \
				and not (run_store.ownedPowerIds as Array).has("memory"):
			failures.append("issue118: owned Memory was dropped from the direct loadout")
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
	run_store.ownedPowerIds = ["reroll"]
	run_store.neurons = EconomyConst.MAX_NEURONS
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
		prefix: String, failures: Array, expects_header: bool = true) -> void:
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
	var title := panel.get_node_or_null("TitleLabel") as Label
	if expects_header:
		if cancel == null or cancel.size.x < 10.0 or cancel.size.y < 9.0:
			failures.append("%s picker cancel target is missing or too small" % prefix)
	else:
		if cancel != null or title != null:
			failures.append("%s picker should not draw title/cancel chrome" % prefix)
	var frame := panel.get_node_or_null("Frame") as TextureRect
	var background := panel.get_node_or_null("Background") as ColorRect
	if expects_frame:
		if frame == null or frame.texture == null or frame.texture.resource_path.get_file() != "symbol_chosing.png":
			failures.append("%s picker did not use the symbol choosing art" % prefix)
		if background == null or background.size != Vector2.ZERO:
			failures.append("%s picker should not draw a generated fill behind the symbol choosing art" % prefix)
		if expects_header and (title == null or frame == null \
				or title.position.y < frame.position.y - 6.0 \
				or title.position.y > frame.position.y + 1.0):
			failures.append("%s picker title should sit on the top band of the symbol choosing art" % prefix)
		if expects_header and (cancel == null or frame == null or cancel.position.y < frame.position.y):
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
	_check_symbol_picker_panel_63(reward_picker, 5, true, "issue63: Reward Amp", failures, false)
	if reward_picker != null:
		if reward_picker.find_child("SymbolButtonBrain", true, false) == null:
			failures.append("issue63: Reward Amp picker should include brain")
		if reward_picker.find_child("SymbolButtonFlatline", true, false) != null:
			failures.append("issue63: Reward Amp picker should not include flatline")
		if reward_picker.find_child("TitleLabel", true, false) != null \
			or reward_picker.find_child("CancelButton", true, false) != null:
			failures.append("issue63: Reward Amp picker still shows title/cross chrome")
	if reward_picker != null:
		var outside_reward_tap := InputEventMouseButton.new()
		outside_reward_tap.button_index = MOUSE_BUTTON_LEFT
		outside_reward_tap.pressed = true
		scene._on_reward_amp_picker_input(outside_reward_tap)
		await process_frame
		if scene._reward_amp_picker == null or String(scene._pending_reward_amp_upgrade_id) == "":
			failures.append("issue63: Reward Amp picker can be dismissed outside the mandatory choice")
		# Test cleanup is internal scene teardown, not a player-facing cancel path.
		scene._pending_reward_amp_upgrade_id = ""
		scene._close_reward_amp_picker()
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
	if int(banked["lucidityWallet"]) != 100:
		failures.append("upgrades: Smart Save did not retain 50% of run lucidity")

	# Smart Saving's OTHER door: the Pacte augment card grants pos_smart_save into the
	# run's ownedUpgrades, never into ownedPermanents. Endings only reads the permanents,
	# so the card used to bank at the plain 10% while promising 50% on its face.
	var run_store: Node = get_root().get_node("RunStateStore")
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	var prev_upgrades: Array = (run_store.ownedUpgrades as Array).duplicate()
	var prev_tier := String(run_store.augmentedTier)

	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.augmentedTier = ""
	run_store.ownedUpgrades = []
	meta_store.ownedPermanents = []
	meta_store.lucidityWallet = 0
	if not run_store._apply_pacte_augment("augment_smart_saving"):
		failures.append("pacte: the SMART SAVING augment card did not apply")
	if not is_equal_approx(meta_store.effective_lucidity_kept_fraction(),
			EconomyConst.SMART_SAVE_LUCIDITY_KEPT):
		failures.append("pacte: a card-granted Smart Saving did not raise the kept fraction")
	meta_store.bank_run({ "lucidityCoins": 200, "scoreEarned": 0, "neurons": 0 }, "flatline")
	if int(meta_store.lucidityWallet) != 100:
		failures.append("pacte: card-granted Smart Saving banked %d of 200, expected 100"
			% int(meta_store.lucidityWallet))

	# Without the card the same run banks the plain 10% — the fix must not hand the
	# raised fraction to every run.
	run_store.ownedUpgrades = []
	meta_store.lucidityWallet = 0
	meta_store.bank_run({ "lucidityCoins": 200, "scoreEarned": 0, "neurons": 0 }, "flatline")
	if int(meta_store.lucidityWallet) != 20:
		failures.append("pacte: a run without Smart Saving banked %d of 200, expected 20"
			% int(meta_store.lucidityWallet))

	run_store.ownedUpgrades = prev_upgrades
	run_store.augmentedTier = prev_tier
	run_store.reset_run_state()
	meta_store._apply(meta_before)
	meta_store.save_state()

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
	if coin_duration != 0.0:
		failures.append("issue28: removed cash-tray wealth coin flow still reports a duration")
	if machine._display_lucidity != 0:
		failures.append("issue28: removed Lucidity feedback changed the wealth display")

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
	var prev_target_index := int(run_store.wealthTargetIndex)
	var prev_target_pending := bool(run_store.wealthTargetPending)
	var prev_target_pending_value := int(run_store.wealthTargetPendingValue)
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
	run_store.wealthTargetIndex = 1
	run_store.wealthTargetPending = false
	run_store.wealthTargetPendingValue = 0
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
	run_store.wealthTargetIndex = prev_target_index
	run_store.wealthTargetPending = prev_target_pending
	run_store.wealthTargetPendingValue = prev_target_pending_value
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

	# Every route to a flatline triple registers a strike, not just a raw 3-of-a-kind:
	# Hallucination promoting a visible flatline pair on EITHER pair of reels, and a book
	# standing in for the flatlines it completes. Flatline pays 0, so the joker only resolves
	# to it when the board has nothing else to become — which is exactly these boards.
	machine.fatal_flatline_count = 99 # no instant death part way through the routes
	var flatline_routes: Array[Dictionary] = [
		{ "reels": ["flatline", "flatline", "flatline"], "why": "a raw flatline triple" },
		{ "reels": ["flatline", "flatline", "eye"], "why": "a hallucinated pair on reels 1+2" },
		{ "reels": ["eye", "flatline", "flatline"], "why": "a hallucinated pair on reels 2+3" },
		{ "reels": ["flatline", "book", "book"], "book": "flatline",
			"why": "books resolving to the only symbol on the board" },
		{ "reels": ["flatline", "flatline", "book"], "book": "flatline",
			"why": "two flatlines and a book" },
	]
	for i in flatline_routes.size():
		var route: Dictionary = flatline_routes[i]
		run_store.flatlineResultCount = 0
		run_store.spinCount = 30 + i
		var route_result := { "reels": route["reels"], "freeSpinsGranted": 0, "winType": "triple" }
		if route.has("book"):
			route_result["bookJoker"] = true
			route_result["resolvedSymbol"] = String(route["book"])
		run_store.lastResult = route_result
		machine._last_reacted_reels = []
		machine._last_reacted_spin = -1
		machine._apply_machine_reactions(false)
		if int(run_store.flatlineResultCount) != 1:
			failures.append("issue35: %s did not register a flatline strike" % String(route["why"]))
	# The same reaction runs for power-made reels, so a power that forms the flatline pair
	# strikes too...
	run_store.flatlineResultCount = 0
	run_store.spinCount = 38
	run_store.lastResult = { "reels": ["flatline", "flatline", "eye"], "freeSpinsGranted": 0,
		"winType": "triple" }
	machine._last_reacted_reels = []
	machine._last_reacted_spin = -1
	machine._apply_machine_reactions(true)
	if int(run_store.flatlineResultCount) != 1:
		failures.append("issue35: a power-made flatline pair did not register a strike")
	# ...but a power that only left an existing win standing must not strike again.
	run_store.flatlineResultCount = 0
	run_store.spinCount = 39
	run_store.lastResult = { "reels": ["flatline", "flatline", "eye"], "freeSpinsGranted": 0,
		"winType": "triple", "combinationReplayed": true }
	machine._last_reacted_reels = []
	machine._last_reacted_spin = -1
	machine._apply_machine_reactions(true)
	if int(run_store.flatlineResultCount) != 0:
		failures.append("issue35: a replayed combination struck the flatline counter again")

	# The scoring side of those boards: with Hallucination and Learning up, each really does
	# resolve to a flatline triple (which is what makes the reactions above fire in play).
	for reels: Array in [["flatline", "flatline", "eye"], ["eye", "flatline", "flatline"],
			["flatline", "book", "book"], ["flatline", "flatline", "book"]]:
		var scored: Dictionary = Evaluate.score_reels(reels, 1.0, false, false, true,
			1.0, 0, true, 1.0, {}, false)
		var scored_symbol := String(scored.get("resolvedSymbol", "")) \
			if bool(scored.get("bookJoker", false)) else "flatline"
		if String(scored["winType"]) != "triple" or scored_symbol != "flatline":
			failures.append("issue35: %s scored as %s/%s, not a flatline triple"
				% [str(reels), String(scored["winType"]), scored_symbol])

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
	# In play the ending waits for the FLATLINE reaction to finish (a real timer); this check
	# asserts the ending itself, so it takes the zero-delay path.
	if machine.fatal_flatline_reaction_delay <= 0.0:
		failures.append("issue35: the fatal flatline should hold for its reaction by default")
	machine.fatal_flatline_reaction_delay = 0.0
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

	_check_new_combination_payout(run_store, failures)

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

## A power pays for the combination it FORMS, never for one that was already paid: changing
## the odd reel out of a pair pays nothing, completing the triple pays the triple, and
## replaying a reel the pair itself sits on pays the pair again (that symbol was played
## again). Driven through Cheat because it picks the symbol outright, so each case is exact.
func _check_new_combination_payout(run_store: Node, failures: Array) -> void:
	var eye_pair := int(Payouts.PAIR_SCORE["eye"])
	var eye_triple := int(Payouts.TRIPLE_SCORE["eye"])
	var cases: Array[Dictionary] = [
		{ "reel": 2, "symbol": "vial", "gain": 0,
			"why": "changing the odd reel out of a pair paid the old pair again" },
		{ "reel": 2, "symbol": "eye", "gain": eye_triple,
			"why": "completing the triple did not pay it" },
		{ "reel": 0, "symbol": "eye", "gain": eye_pair,
			"why": "replaying a reel of the pair did not pay the pair again" },
	]
	for case: Dictionary in cases:
		run_store.runPhase = "running"
		run_store.isSpinning = false
		run_store.ownedPowerIds = ["cheat"]
		run_store.abilitiesUsed = []
		run_store.powersUsedThisSpin = 0
		run_store.augmentedTier = ""
		run_store.ownedUpgrades = []
		run_store.winBoostEnabled = false
		run_store.flatlineWinBoostArmed = false
		run_store.pairBoostSpins = 0
		run_store.scoreEarned = eye_pair
		run_store.lastPureWinScore = eye_pair
		run_store.lastPureWinCoins = eye_pair
		run_store.lastResult = {
			"reels": ["eye", "eye", "pill"], "scoreEarned": eye_pair, "coinsEarned": eye_pair,
			"freeSpinsGranted": 0, "freeSpinsAfter": 0, "isJackpot": false,
			"winType": "pair", "isFreeSpin": false, "scoreMultiplier": 1.0,
		}
		if not run_store.cheat_symbol(int(case["reel"]), String(case["symbol"])):
			failures.append("new combinations: Cheat was refused setting up %s" % String(case["why"]))
			continue
		var expected := eye_pair + int(case["gain"])
		if int(run_store.scoreEarned) != expected:
			failures.append("new combinations: %s (score %d, expected %d)"
				% [String(case["why"]), int(run_store.scoreEarned), expected])
		var replayed := bool((run_store.lastResult as Dictionary).get("combinationReplayed", false))
		if replayed != (int(case["gain"]) == 0):
			failures.append("new combinations: combinationReplayed was %s for %s"
				% [str(replayed), String(case["why"])])
	run_store.ownedPowerIds = []
	run_store.abilitiesUsed = []

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
	# countdown, "half the visits" means the reset value doubles (12 -> 24).
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
	_check_save_durability(run_store, meta_store, failures)

## Saves must survive a bad write. Both files are written atomically through SaveIO —
## a temp file that only replaces the real one once it is completely on disk — and the
## previous good copy is kept as a backup that a corrupt primary falls back to. A run
## snapshot from a newer schema, and a field whose type changed between builds, are
## rejected rather than half-applied over the live state.
func _check_save_durability(run_store: Node, meta_store: Node, failures: Array) -> void:
	var meta_before: Dictionary = meta_store._as_dict()

	# Atomic write: nothing is left behind, and the previous copy is kept as a backup.
	SaveIO.remove(run_store.RUN_SAVE_PATH)
	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.scoreEarned = 321
	run_store._commit()
	run_store.scoreEarned = 654
	run_store._commit()
	if FileAccess.file_exists(run_store.RUN_SAVE_PATH + SaveIO.TMP_SUFFIX):
		failures.append("save durability: a temp file survived a committed write")
	if not FileAccess.file_exists(run_store.RUN_SAVE_PATH + SaveIO.BACKUP_SUFFIX):
		failures.append("save durability: the previous run snapshot was not backed up")

	# A truncated primary falls back to the backup instead of losing the session.
	var truncated := FileAccess.open(run_store.RUN_SAVE_PATH, FileAccess.WRITE)
	if truncated != null:
		truncated.store_string("{ \"runPhase\": \"runn")
		truncated.close()
	run_store.runPhase = "idle"
	run_store.scoreEarned = 0
	run_store.load_run_state()
	if String(run_store.runPhase) != "running" or int(run_store.scoreEarned) != 321:
		failures.append("save durability: a truncated run snapshot did not fall back to its backup")

	# A snapshot from a newer schema is refused outright, and an unusable file is
	# dropped so it cannot fail every launch from here on.
	SaveIO.remove(run_store.RUN_SAVE_PATH)
	var future := FileAccess.open(run_store.RUN_SAVE_PATH, FileAccess.WRITE)
	if future != null:
		future.store_string(var_to_str({
			"schemaVersion": int(run_store.RUN_SAVE_SCHEMA_VERSION) + 1,
			"runPhase": "running", "scoreEarned": 999,
		}))
		future.close()
	run_store.runPhase = "idle"
	run_store.scoreEarned = 0
	run_store.load_run_state()
	if String(run_store.runPhase) == "running" or int(run_store.scoreEarned) == 999:
		failures.append("save durability: a newer-schema snapshot was applied anyway")
	if FileAccess.file_exists(run_store.RUN_SAVE_PATH):
		failures.append("save durability: an unusable run snapshot was left on disk")

	# A field whose type changed keeps its reset default rather than aborting the load.
	SaveIO.remove(run_store.RUN_SAVE_PATH)
	var mistyped := FileAccess.open(run_store.RUN_SAVE_PATH, FileAccess.WRITE)
	if mistyped != null:
		mistyped.store_string(var_to_str({
			"schemaVersion": int(run_store.RUN_SAVE_SCHEMA_VERSION),
			"runPhase": "running", "scoreEarned": "not a number", "neurons": 7,
		}))
		mistyped.close()
	run_store.runPhase = "idle"
	run_store.scoreEarned = 0
	run_store.neurons = 0
	run_store.load_run_state()
	if String(run_store.runPhase) != "running" or int(run_store.neurons) != 7:
		failures.append("save durability: one mistyped field aborted the whole restore")
	if int(run_store.scoreEarned) != 0:
		failures.append("save durability: a mistyped field was forced onto its property")

	# The meta save recovers from a truncated primary the same way.
	meta_store.lucidityWallet = 4242
	meta_store.save_state()
	meta_store.lucidityWallet = 7
	meta_store.save_state() # the 4242 copy becomes the backup
	var broken := FileAccess.open(meta_store.SAVE_PATH, FileAccess.WRITE)
	if broken != null:
		broken.store_string("{ \"lucidityWallet\":")
		broken.close()
	meta_store.lucidityWallet = 0
	meta_store.load_state()
	if int(meta_store.lucidityWallet) != 4242:
		failures.append("save durability: a truncated meta save did not fall back to its backup")

	run_store.reset_run_state()
	meta_store._apply(meta_before)
	meta_store.save_state()

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
	run_store.wealthTargetIndex = 1
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
	meta_store.bank_run({ "lucidityCoins": 0, "scoreEarned": 5000, "neurons": 1 }, "wealth")
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


# ── PR #161: post-spin sequencing, Energy Drink, dealer countdown ──────────────────

## Refusing the in-run dealer must restore the full countdown — not leave it at 0
## so he walks right back in on the next spin.
func _check_dealer_refusal_countdown_161(run_store: Node, failures: Array) -> void:
	var prev_phase := String(run_store.runPhase)
	var prev_pending := bool(run_store.dealerPending)
	var prev_offers: Variant = run_store.dealerOfferIds
	var prev_countdown := int(run_store.dealerCountdown)
	run_store.runPhase = "running"
	run_store.dealerPending = true
	run_store.dealerOfferIds = ["item_water"]
	run_store.dealerCountdown = 0
	run_store.decline_dealer_offer()
	if int(run_store.dealerCountdown) != int(run_store.dealer_countdown_reset_value()):
		failures.append("pr161: refusing the dealer must restore the initial countdown")
	if bool(run_store.dealerPending):
		failures.append("pr161: refusing the dealer must clear dealerPending")
	run_store.runPhase = prev_phase
	run_store.dealerPending = prev_pending
	run_store.dealerOfferIds = prev_offers
	run_store.dealerCountdown = prev_countdown

## The dealer visit stays queued behind the combo-loss warning and the Energy-Drink
## forced spin, and presents once every sequence has resolved.
func _check_dealer_gate_161(machine: Node, run_store: Node, failures: Array) -> void:
	var prev_phase := String(run_store.runPhase)
	var prev_incoming := bool(run_store.dealerIncoming)
	var prev_pending := bool(run_store.dealerPending)
	var prev_offers: Variant = run_store.dealerOfferIds
	var prev_combo := bool(run_store.comboDefeatPending)
	var prev_skips := int(run_store.compulsiveSpinSkips)
	run_store.runPhase = "running"
	run_store.isSpinning = false
	run_store.dealerPending = false
	run_store.dealerOfferIds = ["item_water"]
	machine._spinning_anim = false
	machine._spin_launch_pending = false
	machine._reroll_anim_active = false
	machine._compulsive_queued = false
	machine._pending_dealer_offer = false
	machine._power_bar_score = 0
	machine._power_seen_lucidity = machine._power_point_total()

	# A pending combo loss does not block the visit: the dealer opens above the
	# warning (z100 over the z97 loss art) and closing him returns to the still-
	# pending decision — no spin press required.
	run_store.comboDefeatPending = true
	run_store.pendingComboMultiplier = 2
	run_store.compulsiveSpinSkips = 0
	run_store.dealerIncoming = true
	machine._present_dealer_or_defer()
	if machine._dealer_offer_popup == null:
		failures.append("pr161: dealer should open above a pending combo-loss decision")
	else:
		if int(machine._dealer_offer_popup.z_index) != int(machine.DEALER_OVERLAY_Z_INDEX):
			failures.append("pr161: dealer overlay must draw at z %d" % int(machine.DEALER_OVERLAY_Z_INDEX))
		var tray := machine.get_node_or_null("stash") as Control
		if tray != null and int(tray.z_index) != int(machine.DEALER_STASH_Z_INDEX):
			failures.append("pr161: stash must ride above the dealer while his offer is up")
	machine._close_dealer()
	if not bool(run_store.comboDefeatPending):
		failures.append("pr161: closing the dealer must return to the pending loss decision")
	if not bool(machine._sequence_lock_active):
		failures.append("pr161: pending loss must keep the sequence lock after the dealer closes")
	var tray_after := machine.get_node_or_null("stash") as Control
	if tray_after != null and int(tray_after.z_index) != int(machine.STASH_TRAY_Z_INDEX):
		failures.append("pr161: closing the dealer must restore normal stash layering")

	# The Energy-Drink forced spin still outranks the visit: keep waiting.
	run_store.comboDefeatPending = false
	machine._set_sequence_lock(false)
	run_store.compulsiveSpinSkips = 1
	run_store.dealerIncoming = true
	machine._present_dealer_or_defer()
	if machine._dealer_offer_popup != null:
		failures.append("pr161: dealer must not open while a forced spin is pending")
	if not machine._pending_dealer_offer:
		failures.append("pr161: deferred dealer visit must stay queued")

	# All clear: the queued visit finally presents.
	run_store.compulsiveSpinSkips = 0
	machine._maybe_present_pending_dealer()
	if machine._dealer_offer_popup == null:
		failures.append("pr161: queued dealer visit should present once sequences resolve")
	machine._close_dealer()
	machine._set_sequence_lock(false)
	machine._pending_dealer_offer = false
	run_store.runPhase = prev_phase
	run_store.dealerIncoming = prev_incoming
	run_store.dealerPending = prev_pending
	run_store.dealerOfferIds = prev_offers
	run_store.comboDefeatPending = prev_combo
	run_store.compulsiveSpinSkips = prev_skips

## Energy Drink forces the gauge to x2 and owns it until the forced spin resolves:
## a confirmed combo loss inside the window can not drop it below x2.
func _check_energy_drink_x2_161(run_store: Node, failures: Array) -> void:
	var prev_phase := String(run_store.runPhase)
	var prev_spinning := bool(run_store.isSpinning)
	var prev_consumables: Dictionary = run_store.runConsumables
	var prev_mult := int(run_store.betMultiplier)
	run_store.runPhase = "running"
	run_store.isSpinning = false
	run_store.comboDefeatPending = false
	run_store.dealerIncoming = false
	run_store.dealerPending = false
	run_store.compulsiveSpinSkips = 0
	run_store.pendingCompulsiveSpinSkips = 0
	run_store.decaySkips = 0
	run_store.forcedRandomBetSpins = 0
	run_store.betMultiplier = 1
	run_store.runConsumables = { "item_energy_drink": 1 }
	if not run_store.use_consumable("item_energy_drink"):
		failures.append("pr161: energy drink was refused in a clean running state")
	if int(run_store.betMultiplier) != 2:
		failures.append("pr161: energy drink must force the gauge to x2 (got %d)" % int(run_store.betMultiplier))
	if int(run_store.decaySkips) != 2 or int(run_store.pendingCompulsiveSpinSkips) != 1:
		failures.append("pr161: energy drink counters wrong (decaySkips=%d pending=%d)" \
			% [int(run_store.decaySkips), int(run_store.pendingCompulsiveSpinSkips)])
	# A protected-spin miss opens no losing state and keeps the drink-owned x2.
	# Locked reels pin a deterministic non-paying result.
	run_store.neurons = 100
	run_store.freeSpinsRemaining = 0
	run_store.guaranteedWinSpins = 0
	run_store.potionSpins = 0
	run_store.forceFlatlineSpins = 0
	run_store.guaranteedTripleSpins = 0
	run_store.guaranteeSymbolSpins = 0
	run_store.banBrainSpins = 0
	run_store.pairBoostSpins = 0
	run_store.brainBoostSpins = 0
	run_store.lastResult = { "reels": ["eye", "vial", "brain"] }
	run_store.lockedReels = [true, true, true]
	run_store.lockedReelSpins = [2, 2, 2]
	run_store.spin()
	run_store.set_spinning(false)
	if bool(run_store.comboDefeatPending):
		failures.append("pr161: protected Energy Drink miss opened a losing state")
	if int(run_store.betMultiplier) != 2:
		failures.append("pr161: protected Energy Drink miss dropped the x2 (got %d)" \
			% int(run_store.betMultiplier))
	# A confirmed loss during the drink keeps the forced x2.
	run_store.comboDefeatPending = true
	run_store.pendingComboMultiplier = 2
	run_store.resolve_pending_combo_defeat(false)
	if int(run_store.betMultiplier) != 2:
		failures.append("pr161: combo loss must not break the drink's forced x2")
	# Once the whole effect (protected + forced spins) is over, losses drop again.
	run_store.decaySkips = 0
	run_store.forcedRandomBetSpins = 0
	run_store.pendingCompulsiveSpinSkips = 0
	run_store.compulsiveSpinSkips = 0
	run_store.comboDefeatPending = true
	run_store.pendingComboMultiplier = 2
	run_store.resolve_pending_combo_defeat(false)
	if int(run_store.betMultiplier) != 1:
		failures.append("pr161: post-drink combo loss should drop the gauge to x1")
	run_store.comboDefeatPending = false
	run_store.pendingComboMultiplier = 1
	run_store.runConsumables = prev_consumables
	run_store.betMultiplier = prev_mult
	run_store.isSpinning = prev_spinning
	run_store.runPhase = prev_phase

## The queued forced spin must survive a temporary lock (an animation still
## running) instead of being dropped — dropping it softlocks the run because the
## player can not act while compulsiveSpinSkips > 0.
func _check_forced_spin_persistence_161(machine: Node, run_store: Node, failures: Array) -> void:
	var prev_phase := String(run_store.runPhase)
	var prev_skips := int(run_store.compulsiveSpinSkips)
	run_store.runPhase = "running"
	run_store.compulsiveSpinSkips = 1
	machine._compulsive_queued = false
	machine._spinning_anim = true # a reveal animation is still active
	machine._queue_compulsive_spin()
	await machine.get_tree().create_timer(0.9).timeout
	if not machine._compulsive_queued:
		failures.append("pr161: forced-spin request was dropped while an animation was active")
	# Neutralize before the retry loop actually pulls the lever, then confirm it exits.
	run_store.compulsiveSpinSkips = 0
	machine._spinning_anim = false
	await machine.get_tree().create_timer(0.5).timeout
	if machine._compulsive_queued:
		failures.append("pr161: compulsion queue did not clear after the skips were consumed")
	machine._hide_compulsive_overlay()
	run_store.runPhase = prev_phase
	run_store.compulsiveSpinSkips = prev_skips

## The TAP TAP TAP warning must complete fast (under ~0.75s) while each tap stays
## on screen long enough to read.
func _check_tap_duration_161(failures: Array) -> void:
	var script := load("res://scenes/in_run_dealer_offer.gd") as GDScript
	var consts := script.get_script_constant_map()
	var taps := int(consts["TAP_COUNT"])
	var per_tap := float(consts["TAP_ENTRY_TIME"]) + float(consts["TAP_EXIT_TIME"])
	var total := taps * per_tap + (taps - 1) * float(consts["TAP_WAIT"]) \
		+ float(consts["TAP_FINAL_WAIT"])
	if total > 0.75:
		failures.append("pr161: TAP warning too slow (%.2fs > 0.75s)" % total)
	if per_tap < 0.08:
		failures.append("pr161: TAP flash too brief to read (%.2fs per tap)" % per_tap)

## Energy Drink: a loss warning from the final protected spin is moot once the
## compulsory spin is queued — it is discarded (closing the warning UI) without
## lowering the drink-owned x2, so _do_spin(true) can never be gated by it.
func _check_energy_drink_discard_161(machine: Node, run_store: Node, failures: Array) -> void:
	var prev_phase := String(run_store.runPhase)
	var prev_skips := int(run_store.compulsiveSpinSkips)
	var prev_mult := int(run_store.betMultiplier)
	run_store.runPhase = "running"
	run_store.isSpinning = false
	run_store.compulsiveSpinSkips = 1
	run_store.comboDefeatPending = true
	run_store.pendingComboMultiplier = 2
	run_store.betMultiplier = 2
	run_store.decaySkips = 0
	run_store.forcedRandomBetSpins = 0
	run_store.pendingCompulsiveSpinSkips = 0
	if not machine._discard_moot_combo_defeat():
		failures.append("pr161: queued compulsory spin must discard the pending loss warning")
	if bool(run_store.comboDefeatPending):
		failures.append("pr161: discarded loss warning left comboDefeatPending set")
	if int(run_store.betMultiplier) != 2:
		failures.append("pr161: discarding the moot loss lowered the drink-owned x2")
	if machine._pending_combo_overlay != null:
		failures.append("pr161: discarding the moot loss left the warning overlay up")
	# Without a queued compulsory spin (and with spins left) the warning is NOT
	# moot — nothing is discarded.
	var prev_neurons := int(run_store.neurons)
	var prev_free := int(run_store.freeSpinsRemaining)
	run_store.neurons = 100
	run_store.compulsiveSpinSkips = 0
	run_store.comboDefeatPending = true
	run_store.pendingComboMultiplier = 2
	if machine._discard_moot_combo_defeat():
		failures.append("pr161: loss warning discarded with no compulsory spin queued")
	# Out of spins: the confirming spin can never come — the dead rescue window
	# resolves itself so the flatline procs without touching the lever.
	run_store.neurons = 0
	run_store.freeSpinsRemaining = 0
	if not machine._discard_moot_combo_defeat():
		failures.append("pr161: out-of-spins loss warning must resolve itself")
	if bool(run_store.comboDefeatPending):
		failures.append("pr161: out-of-spins discard left the loss pending")
	run_store.neurons = prev_neurons
	run_store.freeSpinsRemaining = prev_free
	run_store.comboDefeatPending = false
	run_store.pendingComboMultiplier = 1
	run_store.compulsiveSpinSkips = prev_skips
	run_store.betMultiplier = prev_mult
	run_store.runPhase = prev_phase

## The losing state owns the gauge presentation: x2 shows only its authored
## overlay (no sparks), x3 shows only the 9-frame diminished-fire sheet (no
## glitch, no fire) stepped at the multiplier-effect cadence, and the regular
## effects return the moment the loss display closes.
func _check_loss_visuals_161(machine: Node, run_store: Node, failures: Array) -> void:
	if machine._combo_loss_3_sprite == null:
		failures.append("pr161: x3 loss sprite missing")
		return
	if int(machine._combo_loss_3_sprite.hframes) != int(machine.COMBO_LOSS_3_FRAMES):
		failures.append("pr161: x3 loss sheet should slice into %d frames (got %d)" \
			% [int(machine.COMBO_LOSS_3_FRAMES), int(machine._combo_loss_3_sprite.hframes)])
	# x2 loss: only the authored overlay, sparks suppressed.
	machine._refresh_multiplier_fx(2)
	machine._set_combo_loss_display(2)
	if machine._combo_loss_2_sprite == null or not machine._combo_loss_2_sprite.visible:
		failures.append("pr161: x2 loss overlay not shown")
	if machine._mult_fx_2 != null and machine._mult_fx_2.visible:
		failures.append("pr161: x2 loss must suppress the normal x2 sparks")
	machine._set_combo_loss_display(0)
	if machine._mult_fx_2 != null and not machine._mult_fx_2.visible:
		failures.append("pr161: closing the x2 loss must restore the sparks")
	# x3 loss: only the diminished-fire sheet, glitch + fire suppressed, animated.
	machine._refresh_multiplier_fx(3)
	machine._set_combo_loss_display(3)
	if not machine._combo_loss_3_sprite.visible or int(machine._combo_loss_3_sprite.frame) != 0:
		failures.append("pr161: x3 loss overlay should start visible on frame 0")
	if (machine._mult_fx_3 != null and machine._mult_fx_3.visible) \
			or (machine._mult_fx_fire != null and machine._mult_fx_fire.visible):
		failures.append("pr161: x3 loss must suppress the normal x3 glitch and fire sheets")
	machine._mult_fx_time = 0.0
	machine._step_multiplier_fx(float(machine.MULT_FX_FRAME_TIME) + 0.001)
	if int(machine._combo_loss_3_sprite.frame) != 1:
		failures.append("pr161: x3 loss sheet did not advance at the multiplier-effect cadence")
	machine._set_combo_loss_display(0)
	if machine._mult_fx_3 != null and not machine._mult_fx_3.visible:
		failures.append("pr161: closing the x3 loss must restore the glitch effect")
	# Only the x2 losing state beeps — x3 plays its sheet steady.
	run_store.pendingComboMultiplier = 3
	machine._start_combo_loss_beep()
	if machine._combo_loss_beep_tween != null:
		failures.append("pr161: x3 losing state must not beep")
	run_store.pendingComboMultiplier = 2
	machine._start_combo_loss_beep()
	if machine._combo_loss_beep_tween == null:
		failures.append("pr161: x2 losing state should beep")
	machine._stop_combo_loss_beep()
	run_store.pendingComboMultiplier = 1
	machine._refresh_multiplier_fx(1)
	machine._set_combo_loss_display(0)

## Every ending path funnels through the transient-presentation cleanup: dealer
## UI, loss warning/beep, gauge effects, and temporary stash layering are gone
## before flatline, game-over, or wealth presents.
func _check_ending_cleanup_161(machine: Node, run_store: Node, failures: Array) -> void:
	var prev_phase := String(run_store.runPhase)
	var prev_pending := bool(run_store.dealerPending)
	var prev_offers: Variant = run_store.dealerOfferIds
	run_store.runPhase = "running"
	run_store.dealerPending = true
	run_store.dealerOfferIds = ["item_water"]
	machine._show_dealer_offers()
	run_store.comboDefeatPending = true
	run_store.pendingComboMultiplier = 3
	machine._refresh_multiplier_fx(3)
	machine._show_pending_combo_defeat()
	machine._cleanup_transient_presentation()
	if machine._dealer_offer_popup != null or machine._dealer_overlay != null:
		failures.append("pr161: ending cleanup left the dealer UI up")
	if machine._pending_combo_overlay != null:
		failures.append("pr161: ending cleanup left the loss warning overlay up")
	if machine._combo_loss_beep_tween != null:
		failures.append("pr161: ending cleanup left the loss beep running")
	for fx in [machine._combo_loss_2_sprite, machine._combo_loss_3_sprite,
			machine._mult_fx_2, machine._mult_fx_3, machine._mult_fx_fire]:
		if fx != null and fx.visible:
			failures.append("pr161: ending cleanup left a gauge/loss effect visible")
			break
	var tray := machine.get_node_or_null("stash") as Control
	if tray != null and int(tray.z_index) != int(machine.STASH_TRAY_Z_INDEX):
		failures.append("pr161: ending cleanup did not reset stash layering")
	# The funnel itself must invoke the cleanup for every terminal screen.
	var src := FileAccess.get_file_as_string("res://scenes/machine_scene.gd")
	var show_ending_at := src.find("func _show_ending(")
	if show_ending_at < 0 \
			or src.find("_cleanup_transient_presentation()", show_ending_at) < 0 \
			or src.find("_cleanup_transient_presentation()", show_ending_at) > src.find("func ", show_ending_at + 10):
		failures.append("pr161: _show_ending must call _cleanup_transient_presentation first")
	run_store.comboDefeatPending = false
	run_store.pendingComboMultiplier = 1
	machine._refresh_multiplier_fx(1)
	machine._set_sequence_lock(false)
	run_store.runPhase = prev_phase
	run_store.dealerPending = prev_pending
	run_store.dealerOfferIds = prev_offers

## New-run balance: 15 starting spins, dealer countdown 12 (Club modifier 24).
func _check_new_run_balance_161(run_store: Node, failures: Array) -> void:
	if int(EconomyConst.STARTING_NEURONS) != 15:
		failures.append("pr161: fresh runs should start with 15 spins")
	if int(run_store.dealer_countdown_start) != 12:
		failures.append("pr161: dealer countdown should start at 12")
	var prev_tier := String(run_store.augmentedTier)
	run_store.augmentedTier = ""
	if int(run_store.dealer_countdown_reset_value()) != 12:
		failures.append("pr161: dealer countdown should reset to 12")
	run_store.augmentedTier = "club"
	if int(run_store.dealer_countdown_reset_value()) != 24:
		failures.append("pr161: Club modifier should reset the dealer countdown to 24")
	run_store.augmentedTier = prev_tier

## Pacte card ritual smoke coverage: native art, staged/saveable selections, the
## two campaign-neuron threshold visits, and the seven-button machine loadout.
func _check_pacte_flow(machine: Node, run_store: Node, meta_store: Node, failures: Array) -> void:
	var meta_before: Dictionary = meta_store._as_dict()
	run_store.reset_run_state()
	if not run_store.start_new_run([], {}, false, 0x115156, true):
		failures.append("pacte: initial run could not be reserved")
		return
	if String(run_store.runPhase) != "pacte_initial":
		failures.append("pacte: fresh run did not enter pacte_initial")
	var augment_offers := run_store.pacteOfferAugmentIds as Array
	var power_offers := run_store.pacteOfferPowerIds as Array
	if augment_offers.size() != 3 or power_offers.size() != 3:
		failures.append("pacte: expected three augment and three power offers")
	if PacteCards.power_ids().size() != 7 or PacteCards.power_draw_ids().size() != 7 \
			or not PacteCards.power_draw_ids().has("reroll") \
			or not PacteCards.power_draw_ids().has("shift"):
		failures.append("pacte: optional power deck is missing Shift or Reroll")
	if machine._power_buttons.size() != 7:
		failures.append("pacte: machine power bar does not expose all seven controls")

	var pacte := (load("res://scenes/pacte_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(pacte)
	await process_frame
	var pattern_view := pacte._make_card_view("augment_pattern_recognition", "augment") as Control
	var pattern_icon := pattern_view.get_node_or_null("Icon") as AnimatedSprite2D
	if pattern_icon == null or pattern_icon.sprite_frames == null \
			or pattern_icon.sprite_frames.get_frame_count(&"pattern") != 5 \
			or pattern_icon.animation != &"pattern":
		failures.append("pacte: Pattern Recognition is missing its five-frame animated icon")
	pattern_view.free()
	var cheat_view := pacte._make_card_view("augment_how_to_cheat", "augment") as Control
	var cheat_icon := cheat_view.get_node_or_null("Icon") as AnimatedSprite2D
	if cheat_icon == null or cheat_icon.sprite_frames == null \
			or cheat_icon.sprite_frames.get_frame_count(&"cheat") != 7 \
			or cheat_icon.animation != &"cheat":
		failures.append("pacte: How to Cheat is missing its seven-frame animated icon")
	cheat_view.free()
	for node_name in ["PacteBackground", "PacteTable", "SelectedCardEmplacement",
			"PowerCardEmplacement",
			"OddsTableDescriptionBubble", "DropHere", "AugmentDeck", "PowerDeck",
			"PacteDealer", "DealerBubble"]:
		if pacte.get_node_or_null(node_name) == null:
			failures.append("pacte: missing %s" % node_name)
	if pacte._background == null or pacte._dealer_sprite == null or pacte._table == null \
			or int(pacte._background.z_index) != pacte.BACKGROUND_Z_INDEX \
			or int(pacte._dealer_sprite.z_index) != pacte.DEALER_Z_INDEX \
			or int(pacte._table.z_index) != pacte.TABLE_Z_INDEX \
			or not (pacte.BACKGROUND_Z_INDEX < pacte.DEALER_Z_INDEX \
				and pacte.DEALER_Z_INDEX < pacte.TABLE_Z_INDEX):
		failures.append("pacte: background/dealer/table draw order is incorrect")
	if pacte._dealer_bubble == null or int(pacte._dealer_bubble.z_index) <= pacte.TABLE_Z_INDEX:
		failures.append("pacte: dealer text does not draw above the table")
	if pacte._dealer_bubble == null \
			or pacte._dealer_bubble.hframes != pacte.DEALER_TEXT_FRAME_COUNT \
			or pacte._dealer_bubble.frame != pacte.DEALER_AUGMENT_FRAME \
			or pacte._phase_label.visible:
		failures.append("pacte: authored augment dealer text frame is not active")
	if pacte._instruction == null \
			or pacte._instruction.position != pacte.INSTRUCTION_RECT.position \
			or pacte._instruction.position.y <= pacte.CARD_POSITIONS[1].y + pacte.CARD_SIZE.y:
		failures.append("pacte: drag instruction did not move below the card row")
	if augment_offers.size() >= 3:
		var expected_card_positions: Array[Vector2] = [
			Vector2(10.0, 174.0), Vector2(61.0, 174.0), Vector2(112.0, 174.0),
		]
		for index in expected_card_positions.size():
			var card_id := String(augment_offers[index])
			var card_button := pacte._card_buttons.get(card_id, null) as Button
			if card_button == null or card_button.position != expected_card_positions[index]:
				failures.append("pacte: card slot %d did not use its authored offset" % (index + 1))
	if pacte._augment_deck == null or pacte._power_deck == null \
			or pacte._augment_deck.hframes != pacte.DECK_FRAME_COUNT \
			or pacte._power_deck.hframes != pacte.DECK_FRAME_COUNT \
			or pacte._augment_deck.frame != pacte.DECK_FRAME \
			or pacte._power_deck.frame != pacte.DECK_FRAME \
			or not pacte._augment_deck.visible or not pacte._power_deck.visible:
		failures.append("pacte: fixed dual-deck state is not initialized")
	if PacteCards.POWER_FRONT_RECT != Rect2(39.0, 0.0, 39.0, 61.0):
		failures.append("pacte: power proposition does not use the full authored 39x61 front")
	# The arrow selector overlay and the CANCEL/EXIT text buttons were removed.
	for removed_name in ["SelectedCardOverlay", "CancelSelection", "ExitPacte"]:
		if pacte.get_node_or_null(removed_name) != null:
			failures.append("pacte: %s should have been removed" % removed_name)
	var augment_drop := pacte.get_node_or_null("DropHere") as Label
	var power_drop := pacte.get_node_or_null("PowerDropHere") as Label
	if augment_drop == null or augment_drop.position != Vector2(28.0, 256.0) \
			or augment_drop.size != Vector2(25.0, 36.0):
		failures.append("pacte: augment DROP HERE is not inside its emplacement")
	if power_drop == null or power_drop.position != Vector2(107.0, 256.0) \
			or power_drop.size != Vector2(25.0, 36.0):
		failures.append("pacte: power DROP HERE is not inside its emplacement")
	if augment_drop != null and augment_drop.visible or power_drop != null and power_drop.visible:
		failures.append("pacte: DROP HERE was not moved into the emplacement artwork")
	if pacte._emplacement == null or pacte._emplacement.hframes != pacte.EMPLACEMENT_FRAME_COUNT \
			or pacte._emplacement.frame != pacte.EMPLACEMENT_SELECTING_FRAME \
			or pacte._power_emplacement == null or pacte._power_emplacement.visible:
		failures.append("pacte: emplacement did not start on its centered selecting frame")
	var first_augment := String(augment_offers[0])
	pacte._set_face_up(first_augment)
	pacte._preview_card(first_augment)
	if not bool(pacte._description_bubble.visible):
		failures.append("pacte: card preview did not show the description bubble")
	if String(pacte._instruction.text) == "CHOOSE ONE CARD":
		failures.append("pacte: choose-one prompt remained after card tap")
	if pacte._description_bubble.size != pacte.DESCRIPTION_BUBBLE_RECT.size:
		failures.append("pacte: description bubble geometry does not match the authored card preview")
	if pacte._description_bubble.position != pacte._description_bubble_position_for_card(first_augment):
		failures.append("pacte: description bubble is not positioned above the inspected card")
	if pacte._phase_label.position != pacte.PHASE_LABEL_RECT.position \
			or pacte._phase_label.size != pacte.PHASE_LABEL_RECT.size \
			or pacte._phase_label.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER \
			or pacte._phase_label.vertical_alignment != VERTICAL_ALIGNMENT_CENTER \
			or pacte._phase_label.get_theme_font_size("font_size") != pacte.DEALER_PROMPT_FONT_SIZE \
			or pacte._phase_label.visible:
		failures.append("pacte: dynamic choose prompt label was not removed")
	var description_bubble_rect: Rect2 = pacte._description_bubble.get_global_rect()
	if not description_bubble_rect.encloses(pacte._description_title.get_global_rect()) \
			or not description_bubble_rect.encloses(pacte._description_text.get_global_rect()):
		failures.append("pacte: card preview text extends outside its description bubble")
	if augment_offers.size() >= 2:
		var alternate_augment := String(augment_offers[1])
		pacte._set_face_up(alternate_augment)
		pacte._preview_card(alternate_augment)
		if String(pacte._preview_id) != alternate_augment \
				or String(pacte._description_title.text) != String(PacteCards.card(alternate_augment).get("name", "")):
			failures.append("pacte: tapping another card did not replace the preview")
		if pacte._description_bubble.position == pacte._description_bubble_position_for_card(first_augment):
			failures.append("pacte: description bubble stayed on the first card after another card was inspected")
		pacte._preview_card(first_augment)
	var first_button := pacte._card_buttons.get(first_augment, null) as Button
	if first_button == null or first_button.scale.x <= 1.0:
		failures.append("pacte: preview card did not scale up")
	if pacte._drop_label.text != "DROP HERE":
		failures.append("pacte: drag target is missing DROP HERE")
	var screen_press := InputEventScreenTouch.new()
	screen_press.index = 0
	# gui_input delivers positions local to the card button, so feed the handler
	# exactly what the engine would. Deriving this point with the scene's own
	# conversion instead would make the check pass whatever that conversion does.
	var grabbed_card_point := Vector2(15.0, 20.0)
	screen_press.position = grabbed_card_point
	screen_press.pressed = true
	pacte._on_card_gui_input(screen_press, first_augment, 0, first_button)
	if not bool(pacte._description_bubble.visible):
		failures.append("pacte: card explanation disappeared before drag movement")
	var screen_drag := InputEventScreenDrag.new()
	screen_drag.index = 0
	# _input receives events the viewport has already mapped into canvas space.
	screen_drag.position = Vector2(40.0, 270.0)
	pacte._input(screen_drag)
	# The grabbed point of the card must end up exactly under the reported finger.
	var dragged_finger_position := first_button.get_global_transform() * grabbed_card_point
	if dragged_finger_position.distance_to(screen_drag.position) > 0.1:
		failures.append("pacte: mobile card drag did not stay under the finger")
	if not first_button.visible:
		failures.append("pacte: dragged card disappeared before drop")
	var drag_shadow := first_button.get_node_or_null("DragShadow") as Control
	if drag_shadow == null or drag_shadow.get_index() != 0 \
			or drag_shadow.position != Vector2(2.0, 3.0) or not drag_shadow.show_behind_parent:
		failures.append("pacte: dragged card is missing its drop shadow")
	if bool(pacte._description_bubble.visible) or String(pacte._instruction.text) != "" \
			or pacte._emplacement.frame != 1:
		failures.append("pacte: drag did not hide explanation and show authored DROP HERE frame")
	# A screen drag can report coordinates outside the scaled viewport on mobile;
	# the card itself must remain inside the native canvas while held.
	pacte._update_drag(Vector2(-100.0, -100.0))
	var card_visual_scale := Vector2(absf(first_button.scale.x), absf(first_button.scale.y))
	var card_visual_top_left := first_button.position \
		- first_button.pivot_offset * (card_visual_scale - Vector2.ONE)
	var card_visual_size := first_button.size * card_visual_scale
	if card_visual_top_left.x < 0.0 or card_visual_top_left.y < 0.0 \
			or card_visual_top_left.x + card_visual_size.x > 160.0 \
			or card_visual_top_left.y + card_visual_size.y > 320.0:
		failures.append("pacte: mobile card drag escaped the native canvas")
	pacte._update_drag(Vector2(40.0, 270.0))
	var screen_release := InputEventScreenTouch.new()
	screen_release.index = 0
	screen_release.position = Vector2(40.0, 270.0)
	screen_release.pressed = false
	pacte._input(screen_release)
	# The card button may be freed by the accepted drop; check the shadow removal
	# before yielding a frame (remove_drag_shadow queues the shadow for deletion).
	if is_instance_valid(first_button):
		var lingering_shadow := first_button.get_node_or_null("DragShadow")
		if lingering_shadow != null and not lingering_shadow.is_queued_for_deletion():
			failures.append("pacte: drop shadow survived the end of the drag")
	await process_frame
	if String(run_store.pacteSelectedAugmentId) != first_augment \
			or String(pacte._pool_kind) != "power":
		failures.append("pacte: augment selection did not stage before power selection")
	if bool(pacte._description_bubble.visible) \
			or pacte._emplacement.frame != pacte.EMPLACEMENT_SELECTING_FRAME:
		failures.append("pacte: dropped card left explanation or DROP HERE frame visible")
	if pacte._augment_emplacement == null \
			or pacte._augment_emplacement.frame != pacte.EMPLACEMENT_SELECTING_FRAME \
			or not pacte._augment_emplacement.visible \
			or pacte._power_emplacement == null \
			or pacte._power_emplacement.frame != pacte.EMPLACEMENT_SELECTING_FRAME \
			or not pacte._power_emplacement.visible:
		failures.append("pacte: augment and power emplacement frames are incorrect")
	var chosen_augment := pacte._chosen_card_views.get("augment", null) as Control
	if chosen_augment == null or chosen_augment.size != Vector2(21.0, 33.0) \
			or not Rect2(28.0, 256.0, 25.0, 36.0).encloses(
				Rect2(chosen_augment.position, chosen_augment.size)):
		failures.append("pacte: chosen augment card is not minimized inside its emplacement")
	if pacte._drop_label != power_drop:
		failures.append("pacte: power pool did not switch to the power emplacement hint")
	if pacte._dealer_bubble.frame != pacte.DEALER_POWER_FRAME or pacte._phase_label.visible:
		failures.append("pacte: authored power dealer text frame did not replace the choose label")
	if not pacte._augment_deck.visible or not pacte._power_deck.visible \
			or pacte._augment_deck.frame != pacte.DECK_FRAME \
			or pacte._power_deck.frame != pacte.DECK_FRAME:
		failures.append("pacte: both fixed-position decks are not visible during power drawing")
	var first_power := String(power_offers[0])
	pacte._set_face_up(first_power)
	var power_button := pacte._card_buttons.get(first_power, null) as Button
	if power_button == null:
		failures.append("pacte: first power offer has no draggable card")
	else:
		pacte._begin_drag(first_power, 0, power_button, Vector2(70.0, 190.0))
		pacte._update_drag(Vector2(100.0, 270.0))
		if pacte._emplacement.frame != 1:
			failures.append("pacte: power drag did not show authored DROP HERE frame")
		pacte._finish_drag(Vector2(0.0, 0.0))

	# A saved partial selection must restore the same Pacte phase and offers.
	var saved_power_offers := (run_store.pacteOfferPowerIds as Array).duplicate()
	run_store._commit()
	run_store.runPhase = "idle"
	run_store.pacteSelectedAugmentId = ""
	run_store.pacteOfferPowerIds = null
	run_store.load_run_state()
	if String(run_store.runPhase) != "pacte_initial" \
			or String(run_store.pacteSelectedAugmentId) != first_augment \
			or str(run_store.pacteOfferPowerIds) != str(saved_power_offers):
		failures.append("pacte: saved partial selection did not restore")
	var selected_power := String((run_store.pacteOfferPowerIds as Array)[0])
	if not run_store.stage_pacte_power_selection(selected_power):
		failures.append("pacte: initial power selection was rejected")
	if String(run_store.runPhase) != "running" or run_store.selectedPowerCardIds.size() != 1:
		failures.append("pacte: initial completion did not enter the machine with accumulated cards")
	var pacte_badge := machine.get_node_or_null("PacteAugmentBadge") as Button
	if pacte_badge == null or not pacte_badge.visible:
		failures.append("pacte: selected augment is missing from the machine TV badge")
	else:
		if pacte_badge.get_node_or_null("CardContour") != null:
			failures.append("pacte: augment badge should not draw a full card around the icon")
		var badge_style := pacte_badge.get_theme_stylebox("normal") as StyleBoxFlat
		if badge_style == null or badge_style.border_color != machine.PACTE_AUGMENT_CONTOUR_COLOR:
			failures.append("pacte: augment badge is missing its compact blue icon contour")
		if pacte_badge.position != machine.PACTE_AUGMENT_BADGE_POS \
				or pacte_badge.size != machine.PACTE_AUGMENT_BADGE_SIZE:
			failures.append("pacte: augment badge geometry changed unexpectedly")
		# Issue #181: the augments continue the power bar rather than sitting on the TV —
		# same baseline as the three emplacements, same pitch, starting after the third.
		if machine._pacte_augment_badges.size() != machine.PACTE_AUGMENT_BADGE_MAX:
			failures.append("issue181: the augment row was not built to its full width")
		# The sockets plate offers exactly one bed per badge on show: frame N = N+1 sockets,
		# and nothing at all with no augments held.
		var plate := machine._augment_plate_sprite as Sprite2D
		var held_augments: Array = machine._active_pacte_augment_ids()
		var expected_sockets: int = mini(held_augments.size(), machine.PACTE_AUGMENT_BADGE_MAX)
		if plate == null or plate.hframes != machine.AUGMENT_PLATE_FRAMES:
			failures.append("issue181: the augment sockets plate is not a %d-frame sheet"
				% int(machine.AUGMENT_PLATE_FRAMES))
		elif not plate.visible or plate.frame != expected_sockets - 1:
			failures.append("issue181: the sockets plate shows %d beds for %d augments"
				% [plate.frame + 1, expected_sockets])
		var kept_augments: Array = (run_store.selectedAugmentCardIds as Array).duplicate()
		run_store.selectedAugmentCardIds = []
		machine._refresh_pacte_augment_badge()
		if plate != null and plate.visible:
			failures.append("issue181: the sockets plate stayed up with no augments held")
		run_store.selectedAugmentCardIds = kept_augments
		machine._refresh_pacte_augment_badge()
		var third_slot: Dictionary = machine.POWER_HITS[machine.POWER_IDS[2]]
		if not is_equal_approx(machine.PACTE_AUGMENT_BADGE_POS.y, float(third_slot["top"])):
			failures.append("issue181: the augment row is not on the power bar baseline")
		if machine.PACTE_AUGMENT_BADGE_POS.x <= float(machine.POWER_ART_LEFT[machine.POWER_IDS[2]]):
			failures.append("issue181: the augment row does not start after the third power")
		var augment_row_end: float = machine.PACTE_AUGMENT_BADGE_POS.x \
			+ float(machine.PACTE_AUGMENT_BADGE_MAX - 1) * machine.PACTE_AUGMENT_BADGE_PITCH \
			+ machine.PACTE_AUGMENT_BADGE_SIZE.x
		if augment_row_end > 160.0:
			failures.append("issue181: the augment row runs off the canvas (ends %.1f)"
				% augment_row_end)
		if machine.PACTE_AUGMENT_ICON_SIZE < 8.0:
			failures.append("issue181: the augment icons were not enlarged")
		pacte_badge.pressed.emit()
		if machine.get_node_or_null("PacteAugmentPopup") == null:
			failures.append("pacte: augment badge did not open its description popup")
		pacte_badge.pressed.emit()
	pacte._show_reward_amp_picker()
	var reward_amp_picker := pacte.get_node_or_null("RewardAmpPicker") as Control
	if reward_amp_picker == null \
			or reward_amp_picker.find_child("SymbolButtonBrain", true, false) == null:
		failures.append("pacte: selecting Reward Amplification did not show the symbol picker")
	elif reward_amp_picker.find_child("TitleLabel", true, false) != null \
			or reward_amp_picker.find_child("CancelButton", true, false) != null:
		failures.append("pacte: Reward Amplification picker still shows title/cross chrome")
	if reward_amp_picker != null:
		var outside_reward_tap := InputEventMouseButton.new()
		outside_reward_tap.button_index = MOUSE_BUTTON_LEFT
		outside_reward_tap.pressed = true
		pacte._on_reward_amp_picker_input(outside_reward_tap)
		if pacte._reward_amp_picker == null:
			failures.append("pacte: Reward Amplification picker can be dismissed outside the choice")
	pacte._on_reward_amp_symbol_picked("eye")

	# A live machine spin must never interrupt into Pacte, even when its run-spin
	# budget reaches five. The first threshold visit is armed only by the later
	# flatline handoff when the campaign count crosses from three to two.
	run_store.neurons = 5
	run_store.comboDefeatPending = false
	var live_spin: Variant = run_store.spin()
	run_store.set_spinning(false)
	if live_spin == null or bool(run_store.pacteThresholdPending) \
			or String(run_store.runPhase) != "running":
		failures.append("pacte: live machine spin incorrectly opened the threshold visit")
	meta_store.campaignNeuronsLeft = 3
	run_store.campaignNeuronPending = true
	run_store.end_run("flatline")
	if int(meta_store.campaignNeuronsLeft) != 2 \
			or not bool(run_store.pacteThresholdPending) \
			or not bool(run_store.pacteAfterFlatlinePending) \
			or String(run_store.runPhase) != "over":
		failures.append("pacte: flatline did not arm the three-to-two campaign threshold")
	if not run_store.open_threshold_pacte():
		failures.append("pacte: first threshold crossing did not open the Pacte visit")
	var threshold_scene := (load("res://scenes/pacte_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(threshold_scene)
	await process_frame
	if String(run_store.runPhase) != "pacte_threshold" \
			or String(threshold_scene._pool_kind) != "augment":
		failures.append("pacte: threshold visit did not restore as augment draw")
	# The initial visit's chosen cards keep their run effects but are no longer
	# presented on the ritual table when Pacte reopens mid-run.
	if not (threshold_scene._chosen_card_views as Dictionary).is_empty() \
			or threshold_scene._chosen_cards_layer.get_node_or_null("ChosenAugmentCard") != null \
			or threshold_scene._chosen_cards_layer.get_node_or_null("ChosenPowerCard") != null:
		failures.append("pacte: threshold visit re-presented the initial visit's cards")
	if run_store.ownedPowerIds.is_empty() or run_store.selectedAugmentCardIds.is_empty():
		failures.append("pacte: clearing the threshold presentation dropped earlier effects")
	var threshold_augments := run_store.pacteOfferAugmentIds as Array
	var threshold_powers := run_store.pacteOfferPowerIds as Array
	if threshold_augments.is_empty() or threshold_powers.is_empty() \
			or threshold_augments.has(first_augment) or threshold_powers.has(selected_power):
		failures.append("pacte: threshold draw did not accumulate exclusions")
	if not run_store.complete_pacte_selection(String(threshold_augments[0]), String(threshold_powers[0])):
		failures.append("pacte: threshold selection was rejected")
	# A campaign-health-crossing Pacte rejoins the shared between-run flow (odds
	# table -> dealer shop), the same one a plain flatline uses, instead of the
	# mid-run dealer offer (issue #176).
	if not run_store.enter_between_run_dealer_after_flatline() \
			or String(run_store.runPhase) != "over" \
			or str(run_store.lastEnding) != "flatline":
		failures.append("pacte: health-crossing Pacte did not rejoin the between-run dealer")
	run_store.oddsPhaseCompleted = false
	var dealer_scene := (load("res://scenes/dealer_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(dealer_scene)
	await process_frame
	# The shared between-run dealer is the post-run shop: pre-run presentation with
	# the odds table overlay shown on top before the consumables.
	if not bool(dealer_scene._pre_run) or not bool(dealer_scene._post_run):
		failures.append("pacte: health-crossing dealer is not the shared between-run shop")
	if dealer_scene._odds_overlay == null:
		failures.append("pacte: health-crossing dealer did not show the odds table")
	dealer_scene.queue_free()

	# A flatline continuation (post-run dealer -> machine) keeps the campaign's
	# Pacte cards: powers rejoin the loadout, permanent augment effects re-apply.
	var kept_augments: Array = (run_store.selectedAugmentCardIds as Array).duplicate()
	var kept_powers: Array = (run_store.selectedPowerCardIds as Array).duplicate()
	run_store.runPhase = "over"
	run_store.lastEnding = "flatline"
	run_store.start_new_run([], {}, false)
	if str(run_store.selectedAugmentCardIds) != str(kept_augments) \
			or str(run_store.selectedPowerCardIds) != str(kept_powers):
		failures.append("pacte: flatline continuation dropped the selected cards")
	for card_id in kept_powers:
		if not (run_store.ownedPowerIds as Array).has(PacteCards.power_id(String(card_id))):
			failures.append("pacte: flatline continuation lost the %s power" % card_id)
	for card_id in kept_augments:
		var kept_effect := PacteCards.card(String(card_id)).get("effect", {}) as Dictionary
		if String(kept_effect.get("type", "")) == "owned_upgrade" \
				and not (run_store.ownedUpgrades as Array).has(String(kept_effect.get("upgrade_id", ""))):
			failures.append("pacte: flatline continuation lost the %s augment effect" % card_id)

	# A later flatline crossing from two to one arms the additional threshold
	# visit instead of treating the first Pacte encounter as the only one.
	meta_store.campaignNeuronsLeft = 2
	run_store.campaignNeuronPending = true
	run_store.end_run("flatline")
	if int(meta_store.campaignNeuronsLeft) != 1 \
			or not bool(run_store.pacteThresholdPending) \
			or not bool(run_store.pacteAfterFlatlinePending) \
			or String(run_store.runPhase) != "over":
		failures.append("pacte: flatline did not arm the two-to-one campaign threshold")
	if not run_store.open_threshold_pacte():
		failures.append("pacte: second threshold crossing did not open the extra Pacte visit")
	var second_threshold_scene := (load("res://scenes/pacte_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(second_threshold_scene)
	await process_frame
	if String(run_store.runPhase) != "pacte_threshold" \
			or String(second_threshold_scene._pool_kind) != "augment":
		failures.append("pacte: extra threshold visit did not restore as augment draw")

	pacte.queue_free()
	threshold_scene.queue_free()
	second_threshold_scene.queue_free()
	run_store.reset_run_state()
	meta_store._apply(meta_before)
	meta_store.save_state()

func _check_pacte_power_rules(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false, 0x168, false)
	run_store.runPhase = "running"
	run_store.lastResult = _pacte_power_result(["brain", "eye", "pill"])
	run_store.ownedPowerIds = ["swap", "heart", "reroll", "rewind"]
	run_store.abilitiesUsed = []
	machine._set_sequence_lock(false)
	machine._refresh_controls()
	for slot_index in 3:
		var ordered_id: String = ["swap", "heart", "reroll"][slot_index]
		var target_id: String = machine.POWER_IDS[slot_index]
		var source_hit: Dictionary = machine.POWER_HITS[ordered_id]
		var target_hit: Dictionary = machine.POWER_HITS[target_id]
		var ordered_button := machine._power_buttons.get(ordered_id) as Button
		var ordered_sprite := machine._power_sprites.get(ordered_id) as Sprite2D
		# The chip lands on the emplacement's art, not beside it: the offset is measured
		# art to art, so a re-slotted power sits exactly where the power that owns the
		# emplacement is drawn.
		var expected_position := Vector2(float(target_hit["left"]), float(target_hit["top"]))
		var expected_offset := Vector2(
			float(machine.POWER_ART_LEFT[target_id]) - float(machine.POWER_ART_LEFT[ordered_id]),
			float(target_hit["top"]) - float(source_hit["top"]))
		if ordered_button == null or not ordered_button.visible \
				or ordered_button.position != expected_position:
			failures.append("pacte powers: %s did not move into acquisition slot %d" % [ordered_id, slot_index + 1])
		if ordered_sprite == null or ordered_sprite.position != expected_offset:
			failures.append("pacte powers: %s art did not follow acquisition slot %d" % [ordered_id, slot_index + 1])
	var fourth_button := machine._power_buttons.get("rewind") as Button
	if fourth_button == null or fourth_button.visible:
		failures.append("pacte powers: fourth owned power should stay off the three-slot bar")

	# Rebuild the normal rewind fixture after the slot-order assertion.
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false, 0x168, false)
	run_store.ownedPowerIds = ["reroll", "rewind", "heart", "cheat", "swap"]
	run_store.pacteSeed = 0x115156
	run_store.neurons = 50
	var first_spin: Variant = run_store.spin()
	run_store.set_spinning(false)
	if first_spin == null:
		failures.append("pacte powers: rewind setup spin failed")
		run_store.reset_run_state()
		return
	run_store.comboDefeatPending = false
	var first_reels: Array = (run_store.lastResult["reels"] as Array).duplicate()
	var neurons_before_second := int(run_store.neurons)
	run_store.abilitiesUsed = ["reroll"]
	if not run_store.heart_power(1):
		failures.append("pacte powers: Heart could not be armed for the rewind fixture")
	var second_spin: Variant = run_store.spin()
	run_store.set_spinning(false)
	if second_spin == null:
		failures.append("pacte powers: second setup spin failed")
	else:
		# Reroll belongs to the older reveal. Heart was armed for the spin that will
		# be rewound, so only Heart may be recovered.
		run_store.scoreEarned = 777
		run_store.lucidityCoins = 88
		if not run_store.rewind():
			failures.append("pacte powers: Rewind rejected valid history")
		elif str(run_store.lastResult["reels"]) != str(first_reels) \
				or int(run_store.neurons) != neurons_before_second \
				or int(run_store.scoreEarned) != 777 or int(run_store.lucidityCoins) != 88 \
				or bool(run_store.rewindHistoryAvailable) \
				or not (run_store.abilitiesUsed as Array).has("rewind") \
				or not (run_store.abilitiesUsed as Array).has("reroll") \
				or (run_store.abilitiesUsed as Array).has("heart"):
			failures.append("pacte powers: Rewind did not restore state while preserving rewards")
		var heart_neurons_before_rewind_use := int(run_store.neurons)
		if not run_store.heart_power(1):
			failures.append("pacte powers: a power restored by Rewind could not be used")
		else:
			var heart_after_rewind: Variant = run_store.spin()
			run_store.set_spinning(false)
			if heart_after_rewind == null \
					or String(heart_after_rewind.get("winType", "")) != "heart" \
					or int(run_store.neurons) <= heart_neurons_before_rewind_use:
				failures.append("pacte powers: a restored Heart did not resolve its spin reward")
		if run_store.rewind():
			failures.append("pacte powers: Rewind remained available without history")
		# A fresh spin can make a new history available, but Rewind's spent chip must
		# be restored explicitly before the machine-side animation test.
		run_store.abilitiesUsed = []
		# Machine-side lock: the restore beat keeps the lever dead until the rewind
		# sequence finishes, then always releases it.
		run_store.comboDefeatPending = false
		var third_spin: Variant = run_store.spin()
		run_store.set_spinning(false)
		run_store.comboDefeatPending = false
		if third_spin == null:
			failures.append("pacte powers: rewind lock setup spin failed")
		else:
			machine._use_rewind_power()
			# Rewind rolls spinCount back with the snapshot; the locked baseline is
			# whatever the restore landed on.
			var spin_count_during_lock := int(run_store.spinCount)
			if not bool(machine._rewind_anim_active) or not bool(machine._sequence_lock_active):
				failures.append("pacte powers: rewind restore did not lock the sequence")
			if machine._spin_button != null and not bool(machine._spin_button.disabled):
				failures.append("pacte powers: SPIN stayed enabled during the rewind restore")
			# _do_spin must bail out synchronously — a spin that got through would
			# call RunStateStore.spin() (and bump spinCount) before its first await.
			# No frame yield here: this helper runs without await from _run().
			machine._do_spin()
			if int(run_store.spinCount) != spin_count_during_lock:
				failures.append("pacte powers: SPIN input worked during the rewind restore")
			machine._finish_rewind_restore()
			if bool(machine._rewind_anim_active) or bool(machine._sequence_lock_active):
				failures.append("pacte powers: rewind restore did not release the lock")

	run_store.reset_run_state()
	run_store.start_new_run([], {}, false, 0x157, false)
	run_store.ownedPowerIds = ["reroll", "heart", "cheat", "swap"]
	run_store.runPhase = "running"
	for heart_symbol in ["heart_x1", "heart_x2", "heart_x3"]:
		var heart_view := Sprite2D.new()
		machine._apply_symbol(heart_view, heart_symbol, 24.0)
		if heart_view.texture == null:
			failures.append("pacte powers: missing %s machine asset" % heart_symbol)
		heart_view.free()
	run_store.neurons = 5
	run_store.lastResult = _pacte_power_result(["brain", "eye", "pill"])
	run_store.betMultiplier = 1
	var heart_score_before := int(run_store.scoreEarned)
	var heart_neurons_before := int(run_store.neurons)
	var heart_spins_before := int(run_store.freeSpinsRemaining)
	var heart_spin_count_before := int(run_store.spinCount)
	var heart_tier := 0
	if not run_store.heart_power(1) \
			or int(run_store.neurons) != heart_neurons_before \
			or int(run_store.scoreEarned) != heart_score_before \
			or int(run_store.freeSpinsRemaining) != heart_spins_before \
			or not bool(run_store.heartPowerArmed) \
			or (run_store.abilitiesUsed as Array).count("heart") != 1:
		failures.append("pacte powers: Heart preparation failed")
	# Arming Heart immediately previews hearts on every strip symbol — centre AND
	# adjacent — but only three of each tier show: the strip cycles x1/x2/x3
	# (centre x1, top x3, bottom x2) until the next spin resolves the tier.
	machine._refresh_reels_from_state()
	var heart_x1_tex: Variant = machine._load_texture("symbols/heart x1.png", true)
	var heart_x2_tex: Variant = machine._load_texture("symbols/heart x2.png", true)
	var heart_x3_tex: Variant = machine._load_texture("symbols/heart x3.png", true)
	for reel_index in 3:
		if machine._reel_sprites[reel_index].texture != heart_x1_tex \
				or machine._reel_top_sprites[reel_index].texture != heart_x3_tex \
				or machine._reel_bottom_sprites[reel_index].texture != heart_x2_tex:
			failures.append("pacte powers: arming Heart did not preview the heart tier cycle on reel %d" % reel_index)
			break
	# A resolved heart triple shows the landed tier flanked by the OTHER tiers —
	# never nine copies of one heart symbol.
	var heart_neighbours: Dictionary = machine._reel_neighbours("heart_x2")
	if String(heart_neighbours["top"]) != "heart_x1" \
			or String(heart_neighbours["bottom"]) != "heart_x3":
		failures.append("pacte powers: heart reveal strip does not cycle the other tiers")
	var heart_follow_up: Variant = run_store.spin()
	if heart_follow_up == null:
		failures.append("pacte powers: Heart did not arm a follow-up spin")
	else:
		run_store.set_spinning(false)
		var heart_reels := heart_follow_up["reels"] as Array
		var heart_symbol := String(heart_reels[0]) if not heart_reels.is_empty() else ""
		heart_tier = int(heart_symbol.trim_prefix("heart_x"))
		var valid_heart_symbols := ["heart_x1", "heart_x2", "heart_x3"]
		var all_hearts_match := heart_reels.size() == 3
		for symbol in heart_reels:
			all_hearts_match = all_hearts_match and String(symbol) == heart_symbol
		if not valid_heart_symbols.has(heart_symbol) or not all_hearts_match \
				or int(run_store.neurons) != heart_neurons_before + heart_tier \
				or int(run_store.scoreEarned) != heart_score_before \
				or int(heart_follow_up.get("scoreEarned", -1)) != 0 \
				or int(heart_follow_up.get("coinsEarned", -1)) != 0 \
				or bool(heart_follow_up.get("isFreeSpin", false)) != true \
				or int(run_store.spinCount) != heart_spin_count_before + 1 \
				or int(run_store.betMultiplier) != 2 \
				or bool(run_store.heartPowerArmed):
			failures.append("pacte powers: Heart did not resolve a winning free score-less triple")
		if not (run_store.abilitiesUsed as Array).has("heart"):
			failures.append("pacte powers: Heart should stay spent until a 50-point restore")
		if bool(run_store.comboDefeatPending):
			failures.append("pacte powers: the heart spin opened a losing state")
		# The heart triple uses the normal TRIPLE callout/music and a spin-gain
		# fly-in plus the vial-style reaction flash even though its score payout remains zero.
		machine._pending_spin_gain = heart_tier
		machine._burst_prev_spin = -1
		machine._burst_prev_score = 0
		machine._refresh_reels_from_state()
		machine._emit_score_burst(null)
		if machine._win_anim_sprite == null or not bool(machine._win_anim_sprite.visible) \
				or int(machine._win_anim_sprite.frame) != int(machine.WIN_ANIM_FRAME["triple"]):
			failures.append("pacte powers: Heart did not use the TRIPLE callout animation")
		var heart_gain_fx := machine.get_node_or_null("SpinGainFx") as Label
		if heart_gain_fx == null or heart_gain_fx.text != "+%d" % heart_tier:
			failures.append("pacte powers: Heart did not show its +%d spin gain" % heart_tier)
		var heart_reaction_found := false
		var heart_reaction_text := "+%d SPINS" % heart_tier
		for transient: Node in machine.get_tree().get_nodes_in_group("wealth_transient_fx"):
			for child: Node in transient.get_children():
				var reaction_label := child as Label
				if reaction_label != null and String(reaction_label.text) == heart_reaction_text:
					heart_reaction_found = true
		if not heart_reaction_found:
			failures.append("pacte powers: Heart did not use the vial-style +%d reaction flash" % heart_tier)
		if machine.get_node_or_null("HeartHealthOverlay") != null:
			failures.append("pacte powers: Heart still builds the removed red health-bar overlay")
		machine._stop_win_animation()
		machine._pending_spin_gain = 0
	# Swap's UI is a drag gesture over every reel, including adjacent destinations.
	run_store.abilitiesUsed = []
	run_store.lastResult = _pacte_power_result(["brain", "eye", "pill"])
	machine._arm_swap_source()
	if machine._targeting_layer == null \
			or machine._targeting_layer.name != "SwapSymbolDragLayer":
		failures.append("pacte powers: Swap did not arm its drag layer")
	if machine._swap_shake_tween == null or not (machine._swap_shake_tween as Tween).is_valid():
		failures.append("pacte powers: Swap targeting did not start the reel shake")
	# The reel is the thing that moves: each one shakes its reel art, its three strip symbols
	# and its slot frame together on its own phase, so the reel reads as loose and the symbols
	# look stuck to it rather than jiggling inside a still reel.
	if machine._swap_shake_nodes.size() != 15:
		failures.append("pacte powers: Swap should shake three reels' art, symbols and frames, got %d nodes"
			% machine._swap_shake_nodes.size())
	elif machine._swap_shake_reel.size() != machine._swap_shake_nodes.size():
		failures.append("pacte powers: Swap shake lost track of which reel a node belongs to")
	else:
		machine._set_swap_shake_step(0)
		var reel_offsets := {}
		for i in machine._swap_shake_nodes.size():
			var node_offset: Vector2 = machine._swap_shake_nodes[i].position \
				- machine._swap_shake_base[i]
			var reel: int = machine._swap_shake_reel[i]
			if reel_offsets.has(reel) and reel_offsets[reel] != node_offset:
				failures.append("pacte powers: reel %d did not shake as one piece" % reel)
			reel_offsets[reel] = node_offset
		if reel_offsets.size() == 3 and reel_offsets[0] == reel_offsets[1] \
				and reel_offsets[1] == reel_offsets[2]:
			failures.append("pacte powers: the three reels shake in lockstep instead of staggered")
		machine._set_swap_shake_step(0)
	if machine._targeting_layer != null:
		for reel_index in 3:
			if machine._targeting_layer.get_node_or_null("SwapRubbleHint%d" % reel_index) == null \
					or machine._targeting_layer.get_node_or_null("SwapSymbol%d" % reel_index) == null:
				failures.append("pacte powers: Swap missing reel %d drag hint" % reel_index)
		if int(machine._swap_target_at(Vector2(75.5, 185.0))) != 1:
			failures.append("pacte powers: Swap rejected an adjacent reel destination")
		var source_button := machine._targeting_layer.get_node_or_null("SwapSymbol0") as Button
		if source_button == null:
			failures.append("pacte powers: Swap source button is missing")
		else:
			# Swap grabs the REEL: a press on the strip above the hole still picks up the
			# reel's own landed symbol, never the adjacent one under the finger.
			var top_press := source_button.get_global_transform_with_canvas() * Vector2(12.0, 4.0)
			machine._begin_swap_drag(0, source_button, top_press)
			if machine._swap_source_slot != machine.SWAP_CENTRE_SLOT \
					or machine._swap_source_symbol != "brain" \
					or machine._swap_drag_ghost == null \
					or not bool(machine._swap_drag_ghost.visible):
				failures.append("pacte powers: Swap did not pick up the whole reel")
			if machine._swap_invalid_target_overlay == null \
					or not bool(machine._swap_invalid_target_overlay.visible):
				failures.append("pacte powers: Swap did not mark the source reel as a disabled destination")
			# Issue #181: the rejection cue is silent until the player actually offends.
			if machine._swap_invalid_target_overlay != null \
					and machine._swap_invalid_target_overlay.modulate.a > 0.01:
				failures.append("issue181: Swap showed the red cross before an invalid hover")
			if machine._swap_invalid_target_overlay != null \
					and machine._swap_invalid_target_overlay.get_node_or_null("InvalidMarker") != null:
				failures.append("issue181: Swap still draws the font-glyph X marker")
			machine._update_swap_drag(Vector2(43.5, 185.0))
			if machine._swap_target_feedback_reel != 0 \
					or machine._swap_invalid_target_overlay == null \
					or machine._swap_invalid_target_overlay.modulate.a < 0.99:
				failures.append("pacte powers: Swap did not show the red invalid state over the source reel")
			if machine._swap_valid_target_overlay != null \
					and bool(machine._swap_valid_target_overlay.visible):
				failures.append("issue181: Swap showed the green target cue over the forbidden source reel")
			# Hovering a legal reel swaps the cues over: green on, red off.
			machine._update_swap_drag(Vector2(75.5, 185.0))
			if machine._swap_valid_target_overlay == null \
					or not bool(machine._swap_valid_target_overlay.visible):
				failures.append("issue181: Swap did not highlight the legal destination reel")
			if machine._swap_invalid_target_overlay != null \
					and machine._swap_invalid_target_overlay.modulate.a > 0.01:
				failures.append("issue181: Swap kept the red cross up over a legal destination")
			# The cues carry the whole message now — Swap has no instruction line.
			if machine._targeting_layer.get_node_or_null("SwapInstruction") != null:
				failures.append("issue181: Swap still draws an instruction line")
			# The green cue sits on the reel exactly like the red one, not off its bottom.
			if machine._swap_valid_target_overlay != null \
					and machine._swap_invalid_target_overlay != null \
					and not is_equal_approx(machine._swap_valid_target_overlay.position.y,
						machine._swap_invalid_target_overlay.position.y):
				failures.append("issue181: Swap's green and red cues sit at different heights")
			machine._update_swap_drag(Vector2(43.5, 185.0))
			var top_drag_start: Vector2 = machine._swap_drag_ghost.position \
					if machine._swap_drag_ghost != null else Vector2.ZERO
			machine._update_swap_drag(Vector2(75.5, 185.0))
			if machine._swap_drag_ghost == null or machine._swap_drag_ghost.position == top_drag_start:
				failures.append("pacte powers: Swap ghost did not follow the pointer during drag")
			machine._cancel_swap_drag_gesture()
			var swap_press := source_button.get_global_transform_with_canvas() * Vector2(12.0, 15.0)
			machine._begin_swap_drag(0, source_button, swap_press)
			machine._update_swap_drag(Vector2(75.5, 185.0))
			if machine._swap_drag_ghost == null or not bool(machine._swap_drag_ghost.visible):
				failures.append("pacte powers: Swap did not expose a draggable symbol ghost")
			elif machine._swap_drag_ghost.get_node_or_null("DragShadow") == null:
				failures.append("pacte powers: Swap drag ghost has no drop shadow")
		machine._clear_targeting()
		if machine._swap_shake_tween != null:
			failures.append("pacte powers: Swap symbol shake survived targeting clear")
	run_store.abilitiesUsed = []
	run_store.lastResult = _pacte_power_result(["brain", "eye", "pill"])
	machine._arm_cheat_targets()
	if machine.get_node_or_null("PowerRubbleAnimation") == null:
		failures.append("pacte powers: Cheat did not show the rubble overlay")
	machine._on_cheat_reel_pick(1)
	if machine._cheat_selection_sprite == null \
			or machine._cheat_selection_sprite.hframes != 9 \
			or not bool(machine._cheat_selection_sprite.visible) \
			or machine._cheat_selection_sprite.frame != 3:
		failures.append("pacte powers: Cheat did not show the second-reel selection frame")
	machine._set_cheat_selection_state(1)
	if machine._cheat_selection_sprite != null and machine._cheat_selection_sprite.frame != 4:
		failures.append("pacte powers: Cheat bottom-arrow frame was not selected")
	machine._set_cheat_selection_state(2)
	if machine._cheat_selection_sprite != null and machine._cheat_selection_sprite.frame != 5:
		failures.append("pacte powers: Cheat top-arrow frame was not selected")
	# The arrows are authored into cheat_selection.png; their pixels sit at y156..165 (up)
	# and y207..216 (down) around the picked reel's hole, x = hole centre ±8.5. The
	# invisible hit buttons have to cover that art completely — the bottom one used to stop
	# 5px short of the arrow's tip (issue #181) — and must stay off the confirm button that
	# owns the hole itself.
	var cheat_hole: Dictionary = machine.REEL_HOLES[1]
	var cheat_hole_rect := Rect2(float(cheat_hole["left"]), float(cheat_hole["top"]),
		float(cheat_hole["width"]), float(cheat_hole["height"]))
	var cheat_arrow_art := {
		"CheatArrowUp": Rect2(67.0, 156.0, 17.0, 9.0),
		"CheatArrowDown": Rect2(67.0, 207.0, 17.0, 9.0),
	}
	for arrow_name: String in cheat_arrow_art:
		var arrow := machine._targeting_layer.get_node_or_null(arrow_name) as Control
		if arrow == null:
			failures.append("pacte powers: Cheat %s hit target is missing" % arrow_name)
			continue
		var hit := Rect2(arrow.position, arrow.size)
		var art: Rect2 = cheat_arrow_art[arrow_name]
		if not hit.encloses(art):
			failures.append("pacte powers: Cheat %s hitbox %s misses its arrow art %s"
				% [arrow_name, str(hit), str(art)])
		if hit.intersects(cheat_hole_rect):
			failures.append("pacte powers: Cheat %s hitbox overlaps the confirm hole"
				% arrow_name)
	machine._clear_targeting()
	run_store.lastResult = _pacte_power_result(["brain", "eye", "pill"])
	if not run_store.cheat_symbol(1, "brain") \
			or String((run_store.lastResult["reels"] as Array)[1]) != "brain":
		failures.append("pacte powers: Cheat did not replace the selected reel")
	run_store.abilitiesUsed = []
	run_store.lastResult = _pacte_power_result(["brain", "eye", "pill"])
	if not run_store.swap_symbol(0, 1) \
			or str(run_store.lastResult["reels"]) != str(["eye", "brain", "pill"]):
		failures.append("pacte powers: Swap did not exchange adjacent symbols")
	run_store.abilitiesUsed = []
	run_store.powersUsedThisSpin = 2
	run_store.augmentedTier = "diamond"
	run_store.lastResult = _pacte_power_result(["brain", "eye", "pill"])
	if run_store.swap_symbol(0, 2):
		failures.append("pacte powers: augmented power-use limit was ignored")
	run_store.powersUsedThisSpin = 0
	run_store.augmentedTier = ""
	run_store.abilitiesUsed = []
	run_store.ownedPowerIds = ["memory", "heart", "reroll", "cheat", "swap"]
	run_store.lastResult = _pacte_power_result(["brain", "eye", "pill"])
	run_store.comboDefeatPending = true
	run_store.pendingComboMultiplier = 2
	run_store.betMultiplier = 2
	var pending_rescue_ids: Array[String] = run_store.pending_combo_power_ids()
	if not pending_rescue_ids.has("heart") or not pending_rescue_ids.has("memory"):
		failures.append("issue174: Heart and Lock were not offered during a combo loss")
	machine._set_sequence_lock(false)
	machine._show_pending_combo_defeat()
	machine._refresh_controls()
	var heart_button := machine._power_buttons.get("heart") as Button
	if heart_button == null or heart_button.disabled:
		failures.append("pacte powers: Heart stayed disabled during a combo loss")
	var memory_button := machine._power_buttons.get("memory") as Button
	if memory_button == null or memory_button.disabled:
		failures.append("issue174: Lock stayed disabled during a combo loss")
	machine._on_power_pressed("memory")
	machine._apply_reel_power("memory", 1)
	if not (run_store.lockedReels as Array)[1] \
			or not (run_store.abilitiesUsed as Array).has("memory") \
			or bool(run_store.comboDefeatPending) \
			or int(run_store.betMultiplier) != 1:
		failures.append("issue174: Lock did not resolve the combo-loss state")
	if machine._targeting_layer != null:
		failures.append("issue174: Lock targeting stayed open after combo-loss use")
	run_store.comboDefeatPending = true
	run_store.pendingComboMultiplier = 2
	run_store.betMultiplier = 2
	machine._set_sequence_lock(false)
	machine._show_pending_combo_defeat()
	machine._refresh_controls()
	machine._on_power_pressed("heart")
	if not bool(run_store.heartPowerArmed) or bool(run_store.comboDefeatPending) \
			or int(run_store.betMultiplier) != 2:
		failures.append("pacte powers: Heart did not rescue the combo loss without lowering its gauge")
	run_store.reset_run_state()

func _pacte_power_result(reels: Array) -> Dictionary:
	return {
		"reels": reels, "scoreEarned": 0, "coinsEarned": 0,
		"freeSpinsGranted": 0, "freeSpinsAfter": 0, "isJackpot": false,
		"winType": "miss", "isFreeSpin": false, "scoreMultiplier": 1.0,
	}

# ── issue #52: Collection card catalog and the unlock popup ──────────────────────

func _check_card_collection_52(meta_store: Node, failures: Array) -> void:
	var saved_augments: Array = meta_store.unlockedAugmentCardIds.duplicate()
	var saved_powers: Array = meta_store.unlockedPowerCardIds.duplicate()
	var saved_pending: Array = meta_store.pendingCardUnlocks.duplicate(true)
	var saved_progress: Dictionary = meta_store.cardUnlockProgress.duplicate(true)
	var locked_augment := "augment_hallucination"
	var locked_power := "heart"
	var unlocked_augment := "augment_book"

	var augments: Array = PacteCards.augment_ids()
	augments.erase(locked_augment)
	var powers: Array = PacteCards.power_ids()
	powers.erase(locked_power)
	meta_store.unlockedAugmentCardIds = augments
	meta_store.unlockedPowerCardIds = powers
	meta_store.pendingCardUnlocks = []

	var collection := (load("res://scenes/collection_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(collection)

	# The catalog is complete and ordered by PacteCards, locked cards included.
	var expected: Array[String] = []
	expected.append_array(PacteCards.augment_ids())
	expected.append_array(PacteCards.power_ids())
	if str(collection.catalog_card_ids()) != str(expected):
		failures.append("issue52: Collection catalog order/contents drifted from PacteCards")

	# An unlocked card shows its authored front, icon, and name.
	var unlocked_entry := collection.card_entry(unlocked_augment) as Button
	if unlocked_entry == null:
		failures.append("issue52: unlocked augment has no catalog entry")
	else:
		var art := unlocked_entry.get_node_or_null("CardArt") as TextureRect
		var atlas := art.texture as AtlasTexture if art != null else null
		if atlas == null or atlas.region != PacteCards.AUGMENT_FRONT_RECT:
			failures.append("issue52: unlocked augment did not render the card front")
		if unlocked_entry.get_node_or_null("CardIcon") == null:
			failures.append("issue52: unlocked augment did not render its icon")
		var name_label := unlocked_entry.get_node_or_null("NameLabel") as Label
		if name_label == null or name_label.text != String(PacteCards.card(unlocked_augment)["name"]).to_upper():
			failures.append("issue52: unlocked augment did not show its name")

	# A locked card keeps its slot but shows only the card back.
	for locked in [
		{ "id": locked_augment, "back": PacteCards.AUGMENT_BACK_RECT, "name": "HALLUCINATION" },
		{ "id": locked_power, "back": PacteCards.POWER_BACK_RECT, "name": "HEART" },
	]:
		var locked_id := String(locked["id"])
		var locked_entry := collection.card_entry(locked_id) as Button
		if locked_entry == null:
			failures.append("issue52: locked card %s lost its catalog slot" % locked_id)
			continue
		var locked_art := locked_entry.get_node_or_null("CardArt") as TextureRect
		var locked_atlas := locked_art.texture as AtlasTexture if locked_art != null else null
		if locked_atlas == null or locked_atlas.region != (locked["back"] as Rect2):
			failures.append("issue52: locked card %s did not render the card back" % locked_id)
		if locked_entry.get_node_or_null("CardIcon") != null:
			failures.append("issue52: locked card %s leaked its icon" % locked_id)
		var locked_label := locked_entry.get_node_or_null("NameLabel") as Label
		if locked_label == null or locked_label.text != "":
			failures.append("issue52: locked card %s leaked a readable name" % locked_id)
		if locked_entry.modulate == Color.WHITE:
			failures.append("issue52: locked card %s was not muted" % locked_id)

	# Selecting a card opens the matching modal state.
	var unlocked_button := collection.card_entry(unlocked_augment) as Button
	if unlocked_button != null:
		unlocked_button.pressed.emit()
	var unlocked_card := PacteCards.card(unlocked_augment)
	if collection.modal_state() != "unlocked" or collection.modal_card_id() != unlocked_augment:
		failures.append("issue52: selecting an unlocked card did not open the unlocked modal")
	if collection._modal_description.text != String(unlocked_card["description"]):
		failures.append("issue52: the unlocked modal did not show the authored description")
	if not collection._modal.visible:
		failures.append("issue52: the detail modal stayed hidden for an unlocked card")

	var locked_button := collection.card_entry(locked_augment) as Button
	if locked_button != null:
		locked_button.pressed.emit()
	if collection.modal_state() != "locked" or collection.modal_card_id() != locked_augment:
		failures.append("issue52: selecting a locked card did not open the LOCKED modal")
	var locked_meta := PacteCards.card(locked_augment)
	if collection._modal_name.text != collection.LOCKED_NAME \
			or collection._modal_description.text == String(locked_meta["description"]) \
			or collection._modal_description.text.contains(String(locked_meta["name"])):
		failures.append("issue52: the LOCKED modal revealed the card's metadata")
	if collection._modal_card_icon != null and collection._modal_card_icon.visible:
		failures.append("issue52: the LOCKED modal revealed the card icon")
	collection.queue_free()

	# ── unlock popup ─────────────────────────────────────────────────────────────
	var host := Control.new()
	get_root().add_child(host)
	var popup := UnlockCardPopup.attach_to(host)
	if popup == null:
		failures.append("issue52: the unlock popup did not attach to its host")
		host.queue_free()
		_restore_card_unlock_state(meta_store, saved_augments, saved_powers, saved_pending, saved_progress)
		return
	if popup.visible:
		failures.append("issue52: the unlock popup opened with an empty queue")

	# A new unlock queues exactly one entry and opens the popup on that card.
	if not meta_store.unlock_card(locked_augment, "augment", false):
		failures.append("issue52: unlock_card refused a locked card")
	if meta_store.pending_card_unlocks().size() != 1:
		failures.append("issue52: a new unlock did not create exactly one popup entry")
	if not popup.visible or popup._card_id != locked_augment:
		failures.append("issue52: the popup did not present the newly unlocked card")
	if popup._name_label.text != String(PacteCards.card(locked_augment)["name"]).to_upper() \
			or popup._description_label.text != String(PacteCards.card(locked_augment)["description"]):
		failures.append("issue52: the popup did not show the card's authored name/description")
	if popup._front.texture == null or (popup._front.texture as AtlasTexture).region != PacteCards.AUGMENT_FRONT_RECT:
		failures.append("issue52: the popup did not show the enlarged card front")
	if popup._front.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		failures.append("issue52: the popup card front is not nearest-filtered")
	if popup._heading.text != "CARD UNLOCKED":
		failures.append("issue52: the popup is missing its CARD UNLOCKED heading")
	if popup._dim == null or popup.mouse_filter != Control.MOUSE_FILTER_STOP:
		failures.append("issue52: the popup does not block the scene behind it")

	# A duplicate unlock attempt changes nothing.
	if meta_store.unlock_card(locked_augment, "augment", false):
		failures.append("issue52: an already-unlocked card unlocked twice")
	if meta_store.pending_card_unlocks().size() != 1:
		failures.append("issue52: a duplicate unlock added a second popup entry")

	# A second unlock waits its turn behind the card on screen.
	if not meta_store.unlock_card(locked_power, "power", false):
		failures.append("issue52: unlock_card refused a locked power card")
	if meta_store.pending_card_unlocks().size() != 2:
		failures.append("issue52: a second unlock was not queued")
	if popup._card_id != locked_augment:
		failures.append("issue52: a second unlock interrupted the card being presented")

	# CONTINUE acknowledges the presented card and advances to the next one.
	popup._on_continue_pressed()
	if meta_store.pending_card_unlocks().size() != 1:
		failures.append("issue52: CONTINUE did not acknowledge the presented card")
	if meta_store.pending_card_unlocks().size() == 1 \
			and String((meta_store.pending_card_unlocks()[0] as Dictionary)["cardId"]) != locked_power:
		failures.append("issue52: CONTINUE acknowledged the wrong card")
	if not popup.visible or popup._card_id != locked_power:
		failures.append("issue52: multiple pending unlocks did not present sequentially")

	# VIEW COLLECTION acknowledges the card and hands its ID to Collection. The
	# popup is detached first so the check exercises the acknowledgement/highlight
	# handoff without changing the harness's scene out from under the run.
	host.remove_child(popup)
	popup._on_view_collection_pressed()
	if not meta_store.pending_card_unlocks().is_empty():
		failures.append("issue52: VIEW COLLECTION did not acknowledge the presented card")
	if UnlockCardPopup.pending_highlight_card_id != locked_power:
		failures.append("issue52: VIEW COLLECTION did not hand the card to Collection")
	if popup.visible:
		failures.append("issue52: the popup stayed open after VIEW COLLECTION")
	if popup.COLLECTION_SCENE != "res://scenes/collection_scene.tscn":
		failures.append("issue52: VIEW COLLECTION does not route to the Collection scene")
	popup.queue_free()
	host.queue_free()

	var highlighted := (load("res://scenes/collection_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(highlighted)
	if highlighted.highlighted_card_id() != locked_power:
		failures.append("issue52: Collection did not highlight the newly unlocked card")
	if highlighted.card_entry(locked_power) == null \
			or not bool(highlighted.card_entry(locked_power).get_meta(&"unlocked")):
		failures.append("issue52: the unlocked card is still locked in Collection")
	if UnlockCardPopup.pending_highlight_card_id != "":
		failures.append("issue52: the Collection highlight handoff was not consumed")
	highlighted.queue_free()

	# Draw filtering keeps reading the unlocked lists.
	var draw_pool: Array = PacteCards.augment_ids()
	draw_pool.erase(locked_augment)
	for drawn_id in PacteCards.draw("augment", 991, draw_pool, [], 3):
		if String(drawn_id) == locked_augment:
			failures.append("issue52: Pacte draw offered a card outside the unlocked list")

	_restore_card_unlock_state(meta_store, saved_augments, saved_powers, saved_pending, saved_progress)
	await process_frame

func _restore_card_unlock_state(meta_store: Node, augments: Array, powers: Array, pending: Array,
		progress: Dictionary = {}) -> void:
	meta_store.unlockedAugmentCardIds = augments
	meta_store.unlockedPowerCardIds = powers
	meta_store.pendingCardUnlocks = pending
	meta_store.cardUnlockProgress = progress
	UnlockCardPopup.pending_highlight_card_id = ""

# ── issue #52: the deck is gated and the run feeds the unlock counters ───────────

func _check_card_unlock_rules_52(machine: Node, run_store: Node, meta_store: Node, failures: Array) -> void:
	var saved_augments: Array = meta_store.unlockedAugmentCardIds.duplicate()
	var saved_powers: Array = meta_store.unlockedPowerCardIds.duplicate()
	var saved_pending: Array = meta_store.pendingCardUnlocks.duplicate(true)
	var saved_progress: Dictionary = meta_store.cardUnlockProgress.duplicate(true)

	meta_store.unlockedAugmentCardIds = CardUnlocks.default_ids("augment")
	meta_store.unlockedPowerCardIds = CardUnlocks.default_ids("power")
	meta_store.pendingCardUnlocks = []
	meta_store.cardUnlockProgress = {}

	# The Pacte only ever draws from the gated roster.
	for pool in PacteCards.POOLS:
		var unlocked: Array = meta_store.unlocked_augment_cards() if pool == "augment" \
			else meta_store.unlocked_power_cards()
		for card_id in unlocked:
			if not CardUnlocks.default_ids(pool).has(String(card_id)):
				failures.append("issue52 rules: %s starts outside the default %s roster" % [card_id, pool])
		for drawn_id in PacteCards.draw(pool, 7331, unlocked, [], 3):
			if not unlocked.has(String(drawn_id)):
				failures.append("issue52 rules: a %s draw offered a locked card" % pool)

	# Collection shows the unlock condition on a locked card, never its effect.
	var collection := (load("res://scenes/collection_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(collection)
	collection.show_card_detail("augment_adrenaline", "augment")
	var adrenaline := PacteCards.card("augment_adrenaline")
	if collection.modal_state() != "locked":
		failures.append("issue52 rules: a gated card did not open the LOCKED modal")
	if collection._modal_description.text == String(adrenaline["description"]) \
			or collection._modal_description.text.contains(String(adrenaline["name"])):
		failures.append("issue52 rules: the LOCKED modal leaked a gated card's metadata")
	if not collection._modal_description.text.contains("30"):
		failures.append("issue52 rules: the LOCKED modal did not show the unlock condition")
	collection.queue_free()

	# The run feeds the counters. Spin results are fed through the tracker directly:
	# the counters are the unit under test, not the parity-pinned spin math.
	run_store.runPairCount = 0
	run_store.runTripleCounts = {}
	run_store.scoreEarned = 2100
	run_store._track_spin_card_progress(_card_progress_result(["brain", "brain", "eye"], "pair", 40))
	if meta_store.card_unlock_progress(CardUnlocks.METRIC_PAIRS_IN_RUN) != 1:
		failures.append("issue52 rules: a paying pair was not counted")
	if not meta_store.unlockedAugmentCardIds.has("augment_reward_2"):
		failures.append("issue52 rules: a 2100 run did not unlock REWARD + II")
	run_store._track_spin_card_progress(_card_progress_result(["eye", "eye", "eye"], "triple", 90))
	run_store._track_spin_card_progress(_card_progress_result(["eye", "eye", "eye"], "triple", 90))
	if meta_store.card_unlock_progress(CardUnlocks.METRIC_SAME_TRIPLE_IN_RUN) != 2:
		failures.append("issue52 rules: repeated same-symbol triples were not counted")
	run_store._track_spin_card_progress(_card_progress_result(["pill", "pill", "pill"], "triple", 90))
	if meta_store.card_unlock_progress(CardUnlocks.METRIC_SAME_TRIPLE_IN_RUN) != 2:
		failures.append("issue52 rules: a different triple advanced the same-triple metric")
	run_store._track_spin_card_progress(_card_progress_result(["eye", "eye", "eye"], "triple", 90))
	if meta_store.card_unlock_progress(CardUnlocks.METRIC_SAME_TRIPLE_IN_RUN) != 3 \
			or not meta_store.unlockedAugmentCardIds.has("augment_tunnel_vision"):
		failures.append("issue52 rules: the third same triple did not unlock Tunnel Vision")
	run_store._track_spin_card_progress(_card_progress_result(["brain", "eye", "pill"], "miss", 0))
	if meta_store.card_unlock_progress(CardUnlocks.METRIC_PAIRS_IN_RUN) != 1:
		failures.append("issue52 rules: a losing spin counted as a pair")

	# Per-run counters reset with the run; the meta record keeps the best.
	run_store.reset_run_state()
	if int(run_store.runPairCount) != 0 or not (run_store.runTripleCounts as Dictionary).is_empty():
		failures.append("issue52 rules: per-run card counters survived a run reset")
	if meta_store.card_unlock_progress(CardUnlocks.METRIC_SAME_TRIPLE_IN_RUN) != 3:
		failures.append("issue52 rules: a run reset cleared the banked best-run metric")

	# Endings settle the win/death metrics.
	meta_store.cardUnlockProgress = {}
	meta_store.unlockedPowerCardIds = CardUnlocks.default_ids("power")
	meta_store.unlockedAugmentCardIds = CardUnlocks.default_ids("augment")
	run_store.flatlineResultCount = 0
	run_store.augmentedTier = ""
	meta_store._record_ending_card_progress("wealth")
	if meta_store.card_unlock_progress(CardUnlocks.METRIC_WINS) != 1 \
			or not meta_store.unlockedPowerCardIds.has("cheat"):
		failures.append("issue52 rules: a win did not unlock the Cheat power")
	if meta_store.card_unlock_progress(CardUnlocks.METRIC_FLAWLESS_WINS) != 1 \
			or not meta_store.unlockedAugmentCardIds.has("augment_win_boost"):
		failures.append("issue52 rules: a flatline-free win did not unlock COMBO")
	run_store.flatlineResultCount = 2
	meta_store.cardUnlockProgress = {}
	meta_store.unlockedAugmentCardIds = CardUnlocks.default_ids("augment")
	meta_store._record_ending_card_progress("wealth")
	if meta_store.card_unlock_progress(CardUnlocks.METRIC_FLAWLESS_WINS) != 0:
		failures.append("issue52 rules: a win after a flatline counted as flawless")
	meta_store._record_ending_card_progress("flatline")
	if not meta_store.unlockedAugmentCardIds.has("augment_glitch_2"):
		failures.append("issue52 rules: dying of flatline did not unlock GLITCH")
	run_store.flatlineResultCount = 0

	# An unlock earned during the run raises the blocking popup over the machine, but
	# only once the spin it was earned on has finished playing out.
	meta_store.cardUnlockProgress = {}
	meta_store.unlockedAugmentCardIds = CardUnlocks.default_ids("augment")
	meta_store.pendingCardUnlocks = []
	var popup := machine.get_node_or_null("UnlockCardPopup") as UnlockCardPopup
	if popup == null:
		failures.append("issue52 rules: the machine scene has no unlock popup attached")
	else:
		# The Collection check earlier in the run drove this same attached popup (both
		# popups answer card_unlocked). Put it back down so this block starts from a
		# quiet machine rather than a card left on screen there.
		popup._dismiss()
		var previous_spinning: bool = run_store.isSpinning
		run_store.isSpinning = true
		meta_store.add_card_unlock_progress(CardUnlocks.METRIC_CONSUMABLES_USED, 10, false)
		if popup.visible:
			failures.append("issue52 rules: an unlock interrupted a spin in progress")
		run_store.isSpinning = previous_spinning
		machine._maybe_present_card_unlocks()
		if not popup.visible or popup._card_id != "augment_hallucination":
			failures.append("issue52 rules: a held unlock was not raised once the spin ended")
		popup._on_continue_pressed()
		# An ending screen owns the scene until the player leaves it, so the card a
		# wealth/flatline run just earned is celebrated afterwards (on the menu). The
		# ending host is claimed before the commits that earn the card, so a live
		# _overlay is enough to hold the queue.
		var previous_overlay: Control = machine._overlay
		machine._overlay = Control.new()
		if machine._can_present_card_unlock():
			failures.append("issue52 rules: an unlock could interrupt an ending screen")
		machine._overlay.queue_free()
		machine._overlay = previous_overlay

	_restore_card_unlock_state(meta_store, saved_augments, saved_powers, saved_pending, saved_progress)

func _card_progress_result(reels: Array, win_type: String, score: int) -> Dictionary:
	return { "reels": reels, "winType": win_type, "scoreEarned": score }
