extends "res://test/checks/_base.gd"

## Flatline: the overlay, the free spins it grants and the ending teardown.
##
## Cut from scene_smoke.gd unchanged. The suite's runner owns the order and the isolation;
## this file owns nothing but the assertions. See test/checks/_base.gd for why the check
## bodies can still call get_root(), create_timer() and `await process_frame` bare.


func _check_flatline_action_text(machine: Node, meta_store: Node, failures: Array) -> void:
	var previous_neurons := int(meta_store.campaignNeuronsLeft)
	meta_store.campaignNeuronsLeft = 5
	if machine._flatline_action_text() != "CONTINUE":
		failures.append("flatline action: campaign neurons > 0 should show CONTINUE")
	meta_store.campaignNeuronsLeft = 0
	if machine._flatline_action_text() != "TRY AGAIN":
		failures.append("flatline action: campaign neurons <= 0 should show TRY AGAIN")
	meta_store.campaignNeuronsLeft = previous_neurons


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
	var run_store: Node = get_root().get_node("RunStateStore")
	machine._pending_deferred_neg.clear()

	# Energy Drink on use: upside only, and the copy is precise. Since issue #111 the
	# classic drink has no downside left at all, so nothing is armed behind it.
	var prev_hint_tier := String(run_store.augmentedTier)
	run_store.augmentedTier = ""
	var use_hint: HintLabel = machine._show_consumable_feedback("item_energy_drink")
	if use_hint == null:
		failures.append("issue76: energy-drink use hint was not created")
	else:
		if not use_hint._pos_label.visible or use_hint._neg_label.visible:
			failures.append("issue76: energy-drink use popup was not upside-only")
		if use_hint._pos_label.text != "+ 2 FREE SPINS":
			failures.append("issue76: energy-drink upside copy wrong: '%s'" % use_hint._pos_label.text)
		use_hint.queue_free()
	if machine._pending_deferred_neg.get("item_energy_drink", false):
		failures.append("issue111: the classic drink armed a downside it no longer has")

	# The forced spin lives on the joker drink now, and it is still deferred: nothing on
	# use, then the downside pops when the machine actually seizes the spin.
	run_store.augmentedTier = "joker"
	var joker_use: HintLabel = machine._show_consumable_feedback("item_energy_drink")
	if joker_use != null:
		if joker_use._pos_label.visible or joker_use._neg_label.visible:
			failures.append("issue111: the joker drink's use popup should say nothing yet")
		joker_use.queue_free()
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
	run_store.augmentedTier = prev_hint_tier

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
	if machine._callouts.loss_beeping():
		failures.append("pr161: ending cleanup left the loss beep running")
	for fx in [machine._callouts.loss_sprite(2), machine._callouts.loss_sprite(3),
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
