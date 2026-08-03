extends "res://test/checks/_base.gd"

## Wealth: the screen, the target flow and the score feed.
##
## Cut from scene_smoke.gd unchanged. The suite's runner owns the order and the isolation;
## this file owns nothing but the assertions. See test/checks/_base.gd for why the check
## bodies can still call get_root(), create_timer() and `await process_frame` bare.


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

# Dedicated wealth-ending screen: title/subtitle copy, quiet joker reveal, score
# pop, procedural coin flood, and a single Start Again action.
func _check_wealth_screen(machine: Node, run_store: Node, failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	var run := { "neurons": 5, "scoreEarned": 5000, "lucidityCoins": 300 }

	# The authored four-reel odometer replaces the old progress bar and x/goal label.
	machine._set_display_lucidity(300, false)
	if machine._wealth.odometer() == null or machine._wealth.odometer().get_value() != 300:
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
	if machine._wealth.odometer() == null or machine._wealth.odometer().get_value() != 300:
		failures.append("issue131: continued-run odometer did not preserve 0300")
	else:
		machine._wealth.odometer()._drive_roll(0.5, 1999, 2000)
		var from_digits: Array[int] = [1, 9, 9, 9]
		var to_digits: Array[int] = [2, 0, 0, 0]
		for reel_index in 4:
			var reel := machine._wealth.odometer().get_node("Reel%d" % reel_index) as Control
			var current := reel.get_node("Current") as Sprite2D
			var next := reel.get_node("Next") as Sprite2D
			if current.frame != machine._wealth.odometer().FRAME_FOR_DIGIT[from_digits[reel_index]] \
					or next.frame != machine._wealth.odometer().FRAME_FOR_DIGIT[to_digits[reel_index]] \
					or not next.visible or is_equal_approx(current.position.y, next.position.y):
				failures.append("wealth: 1999 -> 2000 carry did not roll reel %d" % reel_index)
		machine._set_display_lucidity(450, false)
		if machine._wealth.odometer().get_value() != 450:
			failures.append("issue131: continued-run odometer did not update to 0450")
	# A fresh standard run restores a zero-padded mechanical readout.
	run_store.reset_run_state()
	machine._set_display_lucidity(300, false)
	if machine._wealth.odometer() == null or machine._wealth.odometer().get_value() != 300:
		failures.append("wealth: fresh-run odometer did not restore 0300")
	if machine._overlay != null:
		machine._overlay.queue_free()
		machine._overlay = null
	machine._set_stash_tray_visible(true)
	meta_store._apply(meta_before)
	meta_store.save_state()

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
			if machine._wealth.odometer().get_node("Reel3").visible:
				failures.append("issue181: the machine kept drawing the digits it handed over")
		machine._stop_wealth_target_transition()
		if machine._tv_blackout_rect != null and machine._tv_blackout_rect.visible:
			failures.append("issue181: the TV stayed dark after the payout screen closed")
		if not machine._wealth.odometer().get_node("Reel3").visible:
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
	var previous_burst_spin: int = machine._bursts.prev_spin()
	var previous_burst_score: int = machine._bursts.prev_score()
	var previous_display: int = machine._wealth.display_score()
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
	machine._bursts.remember(-1, 0)
	machine._set_display_lucidity(0, false)
	machine._emit_score_burst(null)
	if machine._wealth.odometer() == null or machine._wealth.odometer().get_value() != 42:
		failures.append("wealth: score popup did not advance the odometer without Lucidity coins")
	run_store.lastResult = previous_result
	run_store.runPhase = previous_phase
	run_store.scoreEarned = previous_score
	run_store.lucidityCoins = previous_lucidity
	run_store.spinCount = previous_spin
	run_store.lastEffectiveBet = previous_bet
	machine._bursts.remember(previous_burst_spin, previous_burst_score)
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
