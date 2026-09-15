extends "res://test/checks/_base.gd"

## Payouts, multipliers, balance and the spin economy.
##
## Cut from scene_smoke.gd unchanged. The suite's runner owns the order and the isolation;
## this file owns nothing but the assertions. See test/checks/_base.gd for why the check
## bodies can still call get_root(), create_timer() and `await process_frame` bare.


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
	if bool(machine._locked_reels_during_spin[2]) or not machine._reel_blur.spin_visible(2):
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


## Issue #181: a jackpot is paced deliberately — the wealth reels roll slowly and the
## cash tray throws a coin spray — and the sequence lock has to outlast both.
func _check_jackpot_payout_181(machine: Node, run_store: Node, failures: Array) -> void:
	var previous_result: Variant = run_store.lastResult
	var previous_phase := String(run_store.runPhase)
	var previous_score := int(run_store.scoreEarned)
	var previous_spin := int(run_store.spinCount)
	var previous_burst_spin: int = machine._bursts.prev_spin()
	var previous_burst_score: int = machine._bursts.prev_score()
	var previous_display: int = machine._wealth.display_score()

	if not machine.has_method("_spawn_jackpot_coin_fountain"):
		failures.append("issue181: machine is missing the jackpot coin fountain")
	run_store.runPhase = "running"
	run_store.spinCount = 7
	run_store.scoreEarned = 400
	run_store.lastResult = {
		"scoreEarned": 200, "coinsEarned": 200, "winType": "jackpot", "isJackpot": true,
		"reels": ["brain", "brain", "brain"], "scoreMultiplier": 1.0,
	}
	machine._bursts.remember(6, 0)
	machine._set_display_lucidity(200, false)
	var reward_time: float = machine._emit_score_burst(null)
	var slow_roll: float = machine.JACKPOT_ODOMETER_ROLL_TIME + machine.JACKPOT_ROLL_TAIL
	if reward_time < slow_roll:
		failures.append("issue181: jackpot sequence unlocks before the slow score roll ends")
	if reward_time < machine.jackpot_coin_fountain_time():
		failures.append("issue181: jackpot sequence unlocks before the coin spray ends")
	if machine._coins.jackpot_coins().is_empty():
		failures.append("issue181: jackpot did not throw any coins from the cash tray")
	else:
		var first_coin := machine._coins.jackpot_coins()[0] as Sprite2D
		var tray: Vector2 = machine._cash_tray_pos()
		if first_coin == null or absf(first_coin.position.y - tray.y) > 1.0:
			failures.append("issue181: jackpot coins do not start at the cash tray mouth")
	if machine._wealth.odometer() != null and not machine._wealth.odometer().is_rolling():
		failures.append("issue181: jackpot did not roll the wealth odometer")
	# The coin layer sweep only hides children, so the spray needs its own free.
	machine._clear_jackpot_coins()
	if not machine._coins.jackpot_coins().is_empty():
		failures.append("issue181: jackpot coins survived the teardown")

	machine._set_display_lucidity(previous_display, false)
	machine._bursts.remember(previous_burst_spin, previous_burst_score)
	machine._callouts.hold_score(-1)
	run_store.lastResult = previous_result
	run_store.runPhase = previous_phase
	run_store.scoreEarned = previous_score
	run_store.spinCount = previous_spin


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
	machine._callouts.stop_win()
	machine._power_callout.stop()
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
				or dealer_bar.hframes != int(DealerBar.FRAME_COUNT) \
				or dealer_bar.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		failures.append("dealer bar: 13-frame countdown sheet is missing")
	for expected in [
		["DealerBarOverlay1", DealerBar.OVERLAY_1_FRAMES],
		["DealerBarOverlay2", DealerBar.OVERLAY_2_FRAMES],
		["DealerBarOverlay3", DealerBar.OVERLAY_3_FRAMES],
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
		var dealer_bar_during_loss := machine._dealer_bar.bar_sprite() as Sprite2D
		if dealer_bar_during_loss == null or not dealer_bar_during_loss.visible \
				or machine._dealer_bar.warning_light(0) == null \
				or not machine._dealer_bar.warning_light(0).visible \
				or machine._dealer_bar.warning_light(1) == null \
				or not machine._dealer_bar.warning_light(1).visible \
				or machine._dealer_bar.warning_light(2) == null \
				or not machine._dealer_bar.warning_light(2).visible:
			failures.append("combo pending: pending x2 loss did not show all dealer warning overlays")
		if not machine._callouts.loss_beeping():
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
		if machine._score_table.overlay() == null:
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
	if machine._stash.icons().size() > 0 \
			and machine._stash.icons()[0].modulate != Color.WHITE:
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
	if machine._pending_combo_overlay != null or machine._callouts.loss_beeping():
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

	# The Energy Drink is no longer a corrective item for an x3 defeat (issue #111): with
	# the forced x2 gone there is nothing to trade the frenzy for, so using one from the
	# stash leaves the losing state exactly where it was and the warning stays up.
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
	if not bool(run_store.comboDefeatPending) or int(run_store.betMultiplier) != 3:
		failures.append("combo pending: the Energy Drink still rescues an x3 losing state")
	run_store.comboDefeatPending = false
	machine._close_pending_combo_defeat()
	run_store.decaySkips = 0
	run_store.pendingCompulsiveSpinSkips = 0
	run_store.runConsumables = {}
	run_store.betMultiplier = 1
	machine._close_pending_combo_defeat()
	machine._callouts.stop_win()
	machine._power_callout.stop()
	machine._set_tv_progress_bars_visible(true)

	# The FREE SPIN banner is state-driven: it shows while the next spin is free
	# (banked credit or Energy Drink rush), holds until the credit is spent, and
	# never blocks input. The off-TV shelf counter stays visible alongside it. A grant
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
	var spins_tube := machine._spins_left_label as CanvasItem
	if spins_tube == null or not spins_tube.visible:
		failures.append("free spin banner: shelf counter should stay visible beside the banner")
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
		failures.append("free spin banner: shelf counter did not restore")
	machine._close_pending_combo_defeat()
	machine._callouts.stop_win()
	machine._power_callout.stop()
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
	var dealer_bar := machine._dealer_bar.bar_sprite() as Sprite2D
	var dealer_overlay_1 := machine._dealer_bar.warning_light(0) as Sprite2D
	var dealer_overlay_2 := machine._dealer_bar.warning_light(1) as Sprite2D
	var dealer_overlay_3 := machine._dealer_bar.warning_light(2) as Sprite2D
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
			machine._dealer_bar.step_progress(
				float(DealerBar.PROGRESS_FRAME_TIME) + 0.001)
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
		machine._dealer_bar.step_progress(
			float(DealerBar.PROGRESS_FRAME_TIME) + 0.001)
		if dealer_bar == null or dealer_bar.frame != int(intermediate_frame):
			failures.append("issue155: two-step dealer bar transition skipped frame %d" % int(intermediate_frame))
	# PR #169: the authored bar spans all 13 frames across the COMPLETE cycle, whatever
	# its length. Club used to be what made the cycle longer (issue #111 redesign moved
	# it onto prices), so the coverage now drives dealer_countdown_start directly — the
	# one knob that still changes the cycle the bar has to scale itself against.
	var previous_countdown_start := int(run_store.dealer_countdown_start)
	run_store.dealer_countdown_start = 24
	run_store.dealerCountdown = 24
	machine._refresh_dealer_countdown()
	if dealer_bar == null or dealer_bar.frame != 0:
		failures.append("pr169: dealer bar did not reset to frame 0 at a 24-step countdown")
	run_store.dealerCountdown = 12
	machine._refresh_dealer_countdown()
	if machine._dealer_bar.target_frame() != 6:
		failures.append("pr169: 24-step dealer bar midpoint was not frame 6")
	for _step in 6:
		machine._dealer_bar.step_progress(
			float(DealerBar.PROGRESS_FRAME_TIME) + 0.001)
	if dealer_bar == null or dealer_bar.frame != 6:
		failures.append("pr169: 24-step dealer bar did not reach frame 6 at countdown 12")
	run_store.dealerCountdown = 0
	machine._refresh_dealer_countdown()
	if machine._dealer_bar.target_frame() != 12:
		failures.append("pr169: 24-step dealer bar did not target frame 12 at countdown 0")
	for _step in 6:
		machine._dealer_bar.step_progress(
			float(DealerBar.PROGRESS_FRAME_TIME) + 0.001)
	if dealer_bar == null or dealer_bar.frame != 12:
		failures.append("pr169: 24-step dealer bar did not reach its final frame")
	run_store.dealer_countdown_start = previous_countdown_start
	run_store.dealerCountdown = 12
	machine._refresh_dealer_countdown()
	run_store.betMultiplier = 3
	machine._refresh_dealer_countdown()
	if machine._dealer_bar.warning_light(0) == null or not machine._dealer_bar.warning_light(0).visible \
			or (machine._dealer_bar.warning_light(1) != null and machine._dealer_bar.warning_light(1).visible) \
			or (machine._dealer_bar.warning_light(2) != null and machine._dealer_bar.warning_light(2).visible):
		failures.append("issue155: x3 should show only dealer bar overlay 1")
	run_store.betMultiplier = 2
	machine._refresh_dealer_countdown()
	if machine._dealer_bar.warning_light(1) == null or not machine._dealer_bar.warning_light(1).visible \
			or machine._dealer_bar.warning_light(0) == null or not machine._dealer_bar.warning_light(0).visible:
		failures.append("issue155: x2 should show dealer bar overlays 1 and 2")
	run_store.betMultiplier = 1
	machine._refresh_dealer_countdown()
	if machine._dealer_bar.warning_light(2) == null or not machine._dealer_bar.warning_light(2).visible \
			or machine._dealer_bar.warning_light(1) == null or not machine._dealer_bar.warning_light(1).visible \
			or machine._dealer_bar.warning_light(0) == null or not machine._dealer_bar.warning_light(0).visible:
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
		machine._dealer_bar.reset_beep()
		machine._dealer_bar.step_beep(float(DealerBar.OVERLAY_BEEP_TIME) * 0.25)
		if dealer_overlay_1.modulate.a >= 0.99:
			failures.append("issue155: dealer warning overlays did not beep")
		machine._dealer_bar.step_beep(float(DealerBar.OVERLAY_BEEP_TIME))
		if dealer_overlay_1.modulate.a < 0.99:
			failures.append("issue155: dealer warning overlay did not return to full alpha")
		# ...and a lone first light beeps too, just on the slower period: the cadence, not the
		# beep itself, is what tightens as the dealer closes in.
		run_store.betMultiplier = 3
		machine._refresh_dealer_countdown()
		dealer_overlay_1.modulate.a = 1.0
		machine._dealer_bar.reset_beep()
		machine._dealer_bar.step_beep(float(DealerBar.OVERLAY_BEEP_TIME) * 0.25)
		if dealer_overlay_1.modulate.a >= 0.99:
			failures.append("issue155: the x3 warning did not beep on its single light")
		if not is_equal_approx(float(machine._dealer_bar.beep_period()),
				float(DealerBar.OVERLAY_SLOW_BEEP_PERIOD)):
			failures.append("issue155: one light should beep on the slow period")
		run_store.betMultiplier = 2
		machine._refresh_dealer_countdown()
		if not is_equal_approx(float(machine._dealer_bar.beep_period()),
				float(DealerBar.OVERLAY_BEEP_PERIOD)):
			failures.append("issue155: the second light should tighten the beep cadence")
		if float(DealerBar.OVERLAY_SLOW_BEEP_PERIOD) \
				<= float(DealerBar.OVERLAY_BEEP_PERIOD):
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

	# The authored engaged x2-cap frame covers the whole compulsion window: from the
	# moment the forced spin is queued through the spin itself. The classic Energy Drink
	# no longer caps anything, so its protected spins do NOT raise the frame (issue #111).
	run_store.betMultiplier = 2
	run_store.decaySkips = 2
	run_store.pendingCompulsiveSpinSkips = 0
	run_store.compulsiveSpinSkips = 0
	machine._refresh_multiplier_controls()
	if machine._multiplier_sprite != null and machine._multiplier_sprite.frame != 1:
		failures.append("energy drink: the free-spin rush must not cap the gauge any more")
	run_store.pendingCompulsiveSpinSkips = 1
	machine._refresh_multiplier_controls()
	if machine._multiplier_sprite != null and machine._multiplier_sprite.frame != 5:
		failures.append("energy drink: a queued forced spin did not show the engaged x2-cap frame")
	# The cap's visual activation must win over a score-popup HUD hold; otherwise
	# the normal x2 frame remains on screen until an unrelated animation completes.
	machine._hud_delta_hold = true
	machine._refresh_multiplier_controls()
	if machine._multiplier_sprite != null and machine._multiplier_sprite.frame != 5:
		failures.append("energy drink: engaged x2-cap frame was deferred by HUD hold")
	machine._hud_delta_hold = false
	run_store.decaySkips = 0
	run_store.pendingCompulsiveSpinSkips = 0
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
	if int(blocked["score"]) != EconomyConst.LUCIDITY_COINS_PER_RESTORE:
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

## New-run balance: 15 starting spins, dealer countdown 12 under every suit — the
## issue #111 redesign took Club off the dealer axis and put it on prices.
func _check_new_run_balance_161(run_store: Node, failures: Array) -> void:
	if int(EconomyConst.STARTING_NEURONS) != 15:
		failures.append("pr161: fresh runs should start with 15 spins")
	if int(run_store.dealer_countdown_start) != 12:
		failures.append("pr161: dealer countdown should start at 12")
	var prev_tier := String(run_store.augmentedTier)
	for tier in ["", "club", "joker"]:
		run_store.augmentedTier = tier
		if int(run_store.dealer_countdown_reset_value()) != 12:
			failures.append("pr161: dealer countdown should reset to 12 on tier '%s'" % String(tier))
	run_store.augmentedTier = prev_tier
