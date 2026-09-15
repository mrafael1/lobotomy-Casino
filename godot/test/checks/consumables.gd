extends "res://test/checks/_base.gd"

## Consumables: the roster, and how the machine reacts to each item.
##
## Cut from scene_smoke.gd unchanged. The suite's runner owns the order and the isolation;
## this file owns nothing but the assertions. See test/checks/_base.gd for why the check
## bodies can still call get_root(), create_timer() and `await process_frame` bare.


## Generated item art is shared by the machine, shop, and both dealer offer views. Keep a
## small load/size gate here so a renamed or unimported slice cannot silently fall back to
## the placeholder in one of those scenes.
func _check_generated_item_icons(failures: Array) -> void:
	var expected := {
		"cons_cigarette": "items/generated/tobacco.png",
		"cons_focus": "items/generated/serum.png",
		"cons_white_powder": "items/generated/white_powder.png",
		"cons_potion": "items/generated/potion.png",
		"cons_tea": "items/generated/tea.png",
		"item_energy_drink": "items/generated/energy_drink.png",
		"item_cocktail": "items/generated/cocktail.png",
		"item_water": "items/generated/water.png",
		"item_pill": "items/generated/red_pill.png",
	}
	for item_id: String in expected:
		var texture := Assets.texture(String(expected[item_id]))
		if texture == null:
			failures.append("generated item art: missing texture for %s" % item_id)
			continue
		if texture.get_width() != 128 or texture.get_height() != 128:
			failures.append("generated item art: %s should be 128x128, got %dx%d"
				% [item_id, texture.get_width(), texture.get_height()])


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
	var previous_display: int = machine._wealth.display_score()
	var previous_coin_prev := int(machine._coin_prev_lucidity)
	var previous_burst_spin: int = machine._bursts.prev_spin()
	var previous_burst_score: int = machine._bursts.prev_score()

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
	machine._bursts.remember(0, 20)
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
	if machine._bursts.prev_score() != 60:
		failures.append("machine water: payout baseline did not advance past the direct score gain")
	await create_timer(0.1).timeout
	if machine._wealth.display_score() != 60:
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
	machine._bursts.remember(previous_burst_spin, previous_burst_score)

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
	machine._stash.set_tray_visible(true)
	run_store.reset_run_state()
	meta_store._apply(meta_before)
	meta_store.save_state()

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
	machine._consumable_fx.stop_ripple()
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
	# The Energy Drink is two free spins and NOTHING else now: no queued compulsion, no
	# gauge lock, no interaction with a pending defeat (issue #111).
	run_store.betMultiplier = 3
	run_store.comboDefeatPending = true
	run_store.pendingComboMultiplier = 3
	run_store.runConsumables = { "item_energy_drink": 1 }
	run_store.use_consumable("item_energy_drink")
	if int(run_store.decaySkips) != 2 or int(run_store.pendingCompulsiveSpinSkips) != 0:
		failures.append("energy drink: the rush should be the whole item now")
	if not bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 3:
		failures.append("energy drink: the drink still touches the gauge and the losing state")
	run_store.comboDefeatPending = false
	run_store.pendingComboMultiplier = 1
	run_store.betMultiplier = 1
	run_store.decaySkips = 0
	# The forced spin lives on the JOKER drink now (issue #111), and it lands on the spin
	# after the one that queued it — there are no protected spins in front of it to wait
	# for. The blocking checks below are what a queued compulsion does to the run.
	var prev_item_tier := String(run_store.augmentedTier)
	run_store.augmentedTier = "joker"
	run_store.runConsumables = { "item_energy_drink": 1 }
	run_store.use_consumable("item_energy_drink")
	if int(run_store.decaySkips) != 0 or int(run_store.pendingCompulsiveSpinSkips) != 1:
		failures.append("issue111: the joker Energy Drink should queue the forced spin alone")
	run_store.neurons = 100
	run_store.spin()
	run_store.set_spinning(false)
	if int(run_store.compulsiveSpinSkips) != 1 or int(run_store.pendingCompulsiveSpinSkips) != 0:
		failures.append("issue111: the joker drink's compulsion did not land on the next spin")
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

	# Issue #97, still true: stacking two drinks stacks the free-spin rush, and stacking
	# two JOKER drinks still caps the compulsion at a single forced spin.
	run_store.compulsiveSpinSkips = 0
	run_store.pendingCompulsiveSpinSkips = 0
	run_store.decaySkips = 0
	run_store.betMultiplier = 1
	run_store.runConsumables = { "item_energy_drink": 2 }
	run_store.use_consumable("item_energy_drink")
	run_store.use_consumable("item_energy_drink")
	if int(run_store.pendingCompulsiveSpinSkips) != 1:
		failures.append("issue97: stacked joker drinks stacked the compulsion")
	run_store.augmentedTier = prev_item_tier
	run_store.pendingCompulsiveSpinSkips = 0
	run_store.decaySkips = 0
	run_store.runConsumables = { "item_energy_drink": 2 }
	run_store.use_consumable("item_energy_drink")
	run_store.use_consumable("item_energy_drink")
	if int(run_store.decaySkips) != 4 or int(run_store.pendingCompulsiveSpinSkips) != 0:
		failures.append("issue97: stacked Energy Drinks did not stack the rush")
	run_store.decaySkips = 0
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


## Issue #185: the Red Pill runs in two phases — a forced flatline, then the triple it
## promised — and had no TV badge at all, so the most dramatic item in the game ran
## invisibly. It gets ONE badge over both phases, counting the whole effect down.
func _check_red_pill_tv_badge_185(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	var slots: Array = machine._boosts.slots()
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
	if icon == null or not String(icon.resource_path).ends_with("items/generated/red_pill.png"):
		failures.append("issue185: the Red Pill badge did not use the pill icon")
	# Phase one is the forced flatline it makes you take, so the count is RED.
	var green: Color = BoostIndicators.COUNT_COLOR
	var red: Color = BoostIndicators.NEGATIVE_COUNT_COLOR
	if (slots[0]["count"] as Label).get_theme_color("font_color") != red:
		failures.append("issue185: the Red Pill's forced-flatline phase should count in red")

	# The flatline is spent; the promised triple is still owed. ONE badge, now at 1 —
	# not a second badge appearing as the first disappears — and it turns GREEN, because
	# what the item is doing has changed from costing to paying.
	run_store.forceFlatlineSpins = 0
	machine._refresh_boost_indicators()
	if not slot.visible:
		failures.append("issue185: the Red Pill badge vanished between its two phases")
	elif (slots[0]["count"] as Label).text != "1":
		failures.append("issue185: the Red Pill badge should read 1 after the flatline, got '%s'"
			% (slots[0]["count"] as Label).text)
	if (slots[0]["count"] as Label).get_theme_color("font_color") != green:
		failures.append("issue185: the Red Pill should turn green for its guaranteed triple")
	if slots.size() > 1 and (slots[1]["slot"] as Control).visible:
		failures.append("issue185: the Red Pill should occupy one badge, not one per phase")

	# Both phases spent: gone.
	run_store.guaranteedTripleSpins = 0
	machine._clear_boost_zero_linger()
	machine._refresh_boost_indicators()
	if slot.visible:
		failures.append("issue185: the Red Pill badge outlived both its phases")

	# The Energy Drink runs the other way round: protected spins first, then the
	# compulsory one it queued. 3 green, then red once only the bill is left.
	run_store.reset_run_state()
	run_store.decaySkips = 2
	run_store.pendingCompulsiveSpinSkips = 1
	machine._refresh_boost_indicators()
	if (slots[0]["count"] as Label).text != "3":
		failures.append("issue185: the Energy Drink should count its rush AND its forced spin, got '%s'"
			% (slots[0]["count"] as Label).text)
	if (slots[0]["count"] as Label).get_theme_color("font_color") != green:
		failures.append("issue185: the Energy Drink's protected spins should count in green")
	run_store.decaySkips = 0
	run_store.pendingCompulsiveSpinSkips = 0
	run_store.compulsiveSpinSkips = 1
	machine._refresh_boost_indicators()
	if (slots[0]["count"] as Label).text != "1":
		failures.append("issue185: the Energy Drink should read 1 for its forced spin, got '%s'"
			% (slots[0]["count"] as Label).text)
	if (slots[0]["count"] as Label).get_theme_color("font_color") != red:
		failures.append("issue185: the Energy Drink should turn red for its forced spin")
	run_store.reset_run_state()

## Issue #185: a 12px icon cannot say what an item DOES. Tapping one pops its name and
## effect over the TV and the popup ages out on its own, without ever blocking input or
## outliving a callout that needs the screen.
func _check_item_badge_popup_185(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	run_store.runPhase = "running"
	var slots: Array = machine._boosts.slots()
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
	# The badge answers to a hold, like every other explain-this control on the machine:
	# a plain press must pop nothing.
	(slot as Button).pressed.emit()
	if machine._boosts.popup() != null:
		failures.append("issue185: pressing an item badge popped a description instead of holding")

	machine._boosts.on_pressed(0)
	var popup := machine._boosts.popup() as Control
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
		# The bubble hugs its text, so its size is whatever the description needed.
		var popup_rect := Rect2(popup.position, popup.size)
		if popup_rect.size.x > BoostIndicators.POPUP_MAX_WIDTH:
			failures.append("issue185: the popup is wider than the TV allows: %s" % popup_rect)
		var badge_rect := Rect2(slot.position, slot.size)
		# "Next to the icon": the bubble sits within a few px of the badge that raised it,
		# never a plate floating elsewhere on the screen.
		if popup_rect.grow(machine.INFO_BUBBLE_GAP + 1.0).intersection(badge_rect).get_area() <= 0.0:
			failures.append("issue185: the description %s is not attached to its badge %s"
				% [popup_rect, badge_rect])
		if not tv_rect.encloses(popup_rect):
			failures.append("issue185: the popup %s spills outside the TV %s"
				% [popup_rect, tv_rect])

	# Hold to peek: while the badge is down the description stays, however long the player
	# takes to read it. It ages out only once the badge is released, and then it fades
	# rather than blinking off — no second tap needed, nothing to dismiss.
	machine._boosts.step_popup(BoostIndicators.POPUP_HOLD * 4.0)
	if machine._boosts.popup() == null:
		failures.append("issue185: the popup left while the badge was still held")
	machine._boosts.on_released()
	machine._boosts.step_popup(BoostIndicators.POPUP_FADE * 0.4)
	if machine._boosts.popup() == null:
		failures.append("issue185: the popup snapped off on release instead of fading")
	elif machine._boosts.popup().modulate.a >= 1.0:
		failures.append("issue185: the released popup is not fading out")
	machine._boosts.step_popup(BoostIndicators.POPUP_FADE)
	if machine._boosts.popup() != null:
		failures.append("issue185: the popup outstayed the release fade")

	# A callout needs the whole screen: the popup gets out of the way with the badges.
	machine._boosts.on_pressed(0)
	machine._callouts.play_win("pair", 20)
	if machine._boosts.popup() != null:
		failures.append("issue185: the popup survived a PAIR callout taking the TV")
	machine._callouts.stop_win()

	# A hidden badge describes nothing — a tap racing the boost running out must not pop
	# the item that just expired.
	run_store.cocktailBoostSpins = 0
	machine._clear_boost_zero_linger()
	machine._refresh_boost_indicators()
	machine._boosts.on_pressed(0)
	if machine._boosts.popup() != null:
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
	var sheet := "res://assets/images/%s" % ConsumableFx.WATER_SHEET
	if not ResourceLoader.exists(sheet):
		failures.append("issue185: the Water animation sheet is missing from godot/assets (%s)"
			% sheet)
		return
	var tex := load(sheet) as Texture2D
	if tex == null:
		failures.append("issue185: the Water sheet did not load as a texture")
		return
	# A full-canvas sheet: WATER_SHEET_FRAMES frames of the 160x320 virtual canvas.
	var frames: int = ConsumableFx.WATER_SHEET_FRAMES
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
	if not machine._stash.icons()[0].visible:
		failures.append("issue27: machine stash hidden during dealer popup")
	if machine._stash.icons()[0].texture == null:
		failures.append("issue27: machine stash icon texture missing during dealer popup")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	machine._on_stash_input(press, machine._stash.icons()[0], 0)
	if not machine._dealer_drag_active or machine._dealer_drag_kind != "stash":
		failures.append("issue27: machine stash did not start dealer drag")
		return
	machine._dealer_drag_moved = true
	machine._end_dealer_drag(popup._dealer_hit_rect().get_center())
	if Consumables.total_copies(run_store.runConsumables) != 0:
		failures.append("issue27: dropping machine stash on dealer did not discard it")
	machine._close_dealer()


## A queued compulsory spin owns the gauge at x2 until it resolves: a confirmed combo loss
## inside that window can not drop it below x2. Only the joker Energy Drink queues one
## since issue #111 — the classic drink no longer touches the gauge at all.
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
	run_store.betMultiplier = 1
	var prev_x2_tier := String(run_store.augmentedTier)
	run_store.augmentedTier = "joker"
	run_store.runConsumables = { "item_energy_drink": 1 }
	if not run_store.use_consumable("item_energy_drink"):
		failures.append("pr161: energy drink was refused in a clean running state")
	if int(run_store.decaySkips) != 0 or int(run_store.pendingCompulsiveSpinSkips) != 1:
		failures.append("pr161: joker drink counters wrong (decaySkips=%d pending=%d)" \
			% [int(run_store.decaySkips), int(run_store.pendingCompulsiveSpinSkips)])
	# The queued compulsion caps the gauge at x2 from the moment it is queued.
	run_store.betMultiplier = 2
	# A miss inside the window opens no losing state and keeps the capped x2. Locked
	# reels pin a deterministic non-paying result.
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
	# The spin is an ordinary paid one — the drink no longer protects it — so a miss may
	# well open a losing state. What must hold is the cap: it stays at x2.
	if int(run_store.betMultiplier) != 2:
		failures.append("pr161: a miss inside the compulsion window dropped the x2 (got %d)" \
			% int(run_store.betMultiplier))
	# A confirmed loss inside the window keeps the capped x2.
	run_store.comboDefeatPending = true
	run_store.pendingComboMultiplier = 2
	run_store.resolve_pending_combo_defeat(false)
	if int(run_store.betMultiplier) != 2:
		failures.append("pr161: combo loss must not break the compulsion's capped x2")
	# Once the forced spin is spent, losses drop the gauge again.
	run_store.decaySkips = 0
	run_store.pendingCompulsiveSpinSkips = 0
	run_store.compulsiveSpinSkips = 0
	run_store.comboDefeatPending = true
	run_store.pendingComboMultiplier = 2
	run_store.resolve_pending_combo_defeat(false)
	if int(run_store.betMultiplier) != 1:
		failures.append("pr161: a combo loss after the window should drop the gauge to x1")
	run_store.comboDefeatPending = false
	run_store.pendingComboMultiplier = 1
	run_store.augmentedTier = prev_x2_tier
	run_store.runConsumables = prev_consumables
	run_store.betMultiplier = prev_mult
	run_store.isSpinning = prev_spinning
	run_store.runPhase = prev_phase

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
