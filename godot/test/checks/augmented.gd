extends "res://test/checks/_base.gd"

## The augmented run (issue #111): the suits, the menu selector and persistence.
##
## Cut from scene_smoke.gd unchanged. The suite's runner owns the order and the isolation;
## this file owns nothing but the assertions. See test/checks/_base.gd for why the check
## bodies can still call get_root(), create_timer() and `await process_frame` bare.


## The joker delivery played end to end (issue #111). The animation is the only path that
## resolves a joker visit — no button can — so a runtime error anywhere in it would strand
## the overlay with the sequence lock held and softlock the run. This drives the real
## sequence and waits for it to close itself.
func _check_joker_forced_visit_111(machine: Node, run_store: Node, failures: Array) -> void:
	var prev_phase := String(run_store.runPhase)
	var prev_tier := String(run_store.augmentedTier)
	var prev_offers: Variant = run_store.dealerOfferIds
	var prev_pending := bool(run_store.dealerPending)
	var prev_stash: Dictionary = (run_store.runConsumables as Dictionary).duplicate(true)
	run_store.runPhase = "running"
	run_store.isSpinning = false
	run_store.comboDefeatPending = false
	run_store.compulsiveSpinSkips = 0
	run_store.pendingCompulsiveSpinSkips = 0
	run_store.neurons = 100
	run_store.runConsumables = {}
	run_store.augmentedTier = "joker"
	run_store.dealerPending = true
	run_store.dealerOfferIds = ["item_water", "item_cocktail"]
	machine._set_sequence_lock(false)
	machine._show_dealer_offers()
	if machine._dealer_offer_popup == null:
		failures.append("issue111: the joker dealer popup did not open")
		run_store.runPhase = prev_phase
		return
	if String(machine._dealer_offer_popup._forced_item_id) == "":
		failures.append("issue111: the joker visit opened as a normal offer")
	# The whole delivery is a little over 3s; poll rather than sleeping a fixed time so a
	# faster sequence does not leave the suite waiting for nothing.
	var waited := 0.0
	while machine._dealer_offer_popup != null and waited < 8.0:
		await machine.get_tree().create_timer(0.2).timeout
		waited += 0.2
	if machine._dealer_offer_popup != null:
		failures.append("issue111: the joker delivery never closed the dealer (%.1fs)" % waited)
		machine._close_dealer()
	if bool(run_store.dealerPending):
		failures.append("issue111: the joker delivery left the visit pending")
	if Consumables.total_copies(run_store.runConsumables) != 0:
		failures.append("issue111: the delivered item was left in the stash: %s" \
			% str(run_store.runConsumables))
	run_store.cocktailMalusSpins = 0
	run_store.pendingPowerBarDrains = 0
	machine._set_sequence_lock(false)
	run_store.augmentedTier = prev_tier
	run_store.dealerOfferIds = prev_offers
	run_store.dealerPending = prev_pending
	run_store.runConsumables = prev_stash
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
	# Diamond: the threshold Pacte deals a power only, and completing it with no
	# augment is legitimate rather than refused.
	if not run_store.augmented_pacte_augment_suppressed():
		failures.append("issue111: diamond did not suppress the threshold augment offer")
	run_store.augmentedTier = ""
	if run_store.augmented_pacte_augment_suppressed():
		failures.append("issue111: a classic run suppressed the threshold augment offer")

	# Club: prices are marked up and a HOUSE ANGER row joins the target bill. The
	# effects it used to have — halved rewards, halved passive gain, doubled dealer
	# wait — are gone, so those must now read identically to a classic run.
	run_store.augmentedTier = ""
	var base_reset: int = run_store.dealer_countdown_reset_value()
	var base_scale: float = run_store._active_reward_scale()
	var base_passive: int = run_store._passive_lucidity_per_spin()
	var base_chip_price: int = run_store.chip_augment_price("aug_extra_spins")
	var base_item_price: int = run_store.consumable_price("cons_potion")
	var base_reroll: int = run_store.dealer_reroll_price()
	run_store.augmentedTier = "club"
	if int(run_store.dealer_countdown_reset_value()) != base_reset:
		failures.append("issue111: club still changes the dealer countdown reset")
	if not is_equal_approx(run_store._active_reward_scale(), base_scale):
		failures.append("issue111: club still scales the spin reward")
	if int(run_store._passive_lucidity_per_spin()) != base_passive:
		failures.append("issue111: club still scales the passive lucidity gain")
	if int(run_store.dealer_reroll_price()) != base_reroll:
		failures.append("issue111: club must leave the dealer reroll price alone")
	var want_chip := floori(float(base_chip_price) * 1.5 + 0.5)
	var want_item := floori(float(base_item_price) * 1.5 + 0.5)
	if int(run_store.chip_augment_price("aug_extra_spins")) != want_chip:
		failures.append("issue111: club chip price %d, expected %d" \
			% [int(run_store.chip_augment_price("aug_extra_spins")), want_chip])
	if int(run_store.consumable_price("cons_potion")) != want_item:
		failures.append("issue111: club item price %d, expected %d" \
			% [int(run_store.consumable_price("cons_potion")), want_item])
	if not is_equal_approx(run_store.augmented_anger_tax_rate(), EconomyConst.OVERFLOW_ANGER_RATE):
		failures.append("issue111: club did not arm the house anger tax")
	var club_bill: Dictionary = EconomyConst.overflow_bill(150, 500,
		run_store.augmented_anger_tax_rate())
	var club_rows: Array = club_bill["lines"] as Array
	if club_rows.size() != EconomyConst.OVERFLOW_TAX_LINES.size() + 1:
		failures.append("issue111: club bill has %d rows, expected one more than classic" \
			% club_rows.size())
	elif String((club_rows[club_rows.size() - 1] as Dictionary)["label"]) \
			!= String(EconomyConst.OVERFLOW_ANGER_LINE["label"]):
		failures.append("issue111: the club bill's last row is not HOUSE ANGER")
	if int(club_bill["net"]) >= int(EconomyConst.overflow_bill(150, 500)["net"]):
		failures.append("issue111: the house anger row took nothing off the overflow")
	# The angriest bill must still leave the player something: an overflow that banks
	# zero teaches them to stop overshooting, which flattens the whole target economy.
	if int(EconomyConst.overflow_bill(5000, 500, EconomyConst.OVERFLOW_ANGER_RATE)["net"]) <= 0:
		failures.append("issue111: the top club band confiscates the whole overflow")
	# The anger row is the last one on the receipt and carries its own key, which is what
	# the payout screen colours red. The rendered row itself is covered by the payout
	# screen's own check rather than by standing another live overlay up here.
	var anger_row: Dictionary = club_rows[club_rows.size() - 1] as Dictionary
	if String(anger_row.get("key", "")) != String(EconomyConst.OVERFLOW_ANGER_LINE["key"]):
		failures.append("issue111: the club bill's last row does not carry the anger key")
	run_store.augmentedTier = ""
	if not is_equal_approx(run_store.augmented_anger_tax_rate(), 0.0):
		failures.append("issue111: a classic run armed the house anger tax")
	if int(run_store.consumable_price("cons_potion")) != base_item_price:
		failures.append("issue111: the club markup outlived the club run")

	# Club also stocks one item fewer at BOTH counters (pre-run shop and in-run
	# visit), floored at one — an empty counter would read as a bug, not a modifier.
	var prev_augments: Dictionary = (meta_store.chipAugmentsPurchased as Dictionary).duplicate(true)
	var prev_prerun: Variant = run_store.prerunOfferIds
	var prev_rerolls: int = int(run_store.dealerRerollCount)
	meta_store.chipAugmentsPurchased = {}
	run_store.augmentedTier = ""
	var base_offers: int = run_store.dealer_offer_count()
	run_store.augmentedTier = "club"
	if int(run_store.dealer_offer_count()) != base_offers - 1:
		failures.append("issue111: club offer count %d, expected %d" \
			% [int(run_store.dealer_offer_count()), base_offers - 1])
	# Expanded Selection buys the classic pair back rather than being negated, so the
	# chip stays worth owning on a club run.
	meta_store.chipAugmentsPurchased = { "aug_offer_expand": 1 }
	if int(run_store.dealer_offer_count()) != base_offers:
		failures.append("issue111: Expanded Selection did not restore the club counter to %d" \
			% base_offers)
	meta_store.chipAugmentsPurchased = {}
	# The shortened offer is still a rolled offer: opening the pre-run shop twice must
	# not re-roll it, which would also reset the escalating reroll price.
	run_store.runPhase = "pre_run"
	run_store.prerunOfferIds = null
	var club_prerun: Array = run_store.ensure_prerun_offer(0x111c1)
	if club_prerun.size() != base_offers - 1:
		failures.append("issue111: club pre-run shop stocked %d items, expected %d" \
			% [club_prerun.size(), base_offers - 1])
	run_store.dealerRerollCount = 3
	if run_store.ensure_prerun_offer(0x111c2) != club_prerun:
		failures.append("issue111: reopening the club pre-run shop re-rolled its offer")
	if int(run_store.dealerRerollCount) != 3:
		failures.append("issue111: reopening the club pre-run shop reset the reroll price")
	run_store.augmentedTier = ""
	if int(run_store.dealer_offer_count()) != base_offers:
		failures.append("issue111: the club offer penalty outlived the club run")
	meta_store.chipAugmentsPurchased = prev_augments
	run_store.prerunOfferIds = prev_prerun
	run_store.dealerRerollCount = prev_rerolls
	run_store.runPhase = "running"

	# Spade: a spent charge takes two spins to come back, counted from the spend, and the
	# pips under the light track that wait — dark whenever a charge is banked.
	run_store.augmentedTier = "spade"
	run_store.powerRestoreCharges = EconomyConst.POWER_RESTORE_CHARGE_MAX
	run_store.powerRestoreProgress = 0
	run_store._recharge_restores()
	if int(run_store.restore_cycle_progress()) != 0:
		failures.append("issue111: spade counted down while a restore charge was banked")
	# Spending it starts the cycle from zero: the light goes out with both pips dark.
	run_store._spend_restore_budget(1)
	if int(run_store.restore_budget_left()) != 0 or int(run_store.restore_cycle_progress()) != 0:
		failures.append("issue111: spending a charge did not reset the spade cycle")
	run_store._recharge_restores()
	if int(run_store.restore_cycle_progress()) != 1:
		failures.append("issue111: the first spade wait spin did not light one pip")
	if int(run_store.restore_budget_left()) != 0:
		failures.append("issue111: spade handed the charge back after a single spin")
	run_store._recharge_restores()
	if int(run_store.restore_cycle_progress()) != EconomyConst.SPADE_RESTORE_CYCLE_SPINS:
		failures.append("issue111: the second spade wait spin did not light both pips")
	if int(run_store.restore_budget_left()) != EconomyConst.POWER_RESTORE_CHARGE_MAX:
		failures.append("issue111: spade never handed the restore charge back")
	# Banked again, so the countdown clears rather than sticking at full.
	run_store._recharge_restores()
	if int(run_store.restore_cycle_progress()) != 0:
		failures.append("issue111: the spade pips stayed lit under a banked charge")
	# A classic run refills every spin and never shows a countdown.
	run_store.augmentedTier = ""
	run_store.powerRestoreCharges = 0
	run_store._recharge_restores()
	if int(run_store.restore_budget_left()) != EconomyConst.POWER_RESTORE_CHARGE_MAX:
		failures.append("issue111: a classic spin did not refill the restore charge")
	if int(run_store.restore_cycle_progress()) != 0:
		failures.append("issue111: a classic run showed a restore countdown")
	run_store.augmentedTier = "spade"
	meta_store.ownedPermanents = []
	meta_store.lucidityWallet = 0
	meta_store.bank_run({ "lucidityCoins": 200, "scoreEarned": 0, "neurons": 1 }, "flatline")
	if int(meta_store.lucidityWallet) != 20:
		failures.append("issue111: spade banked %d of 200, expected the classic 10%% = 20" \
			% int(meta_store.lucidityWallet))
	if not is_equal_approx(machine._end_run_lucidity_kept_fraction(), 0.10):
		failures.append("issue111: the machine still shows spade a halved kept fraction")

	# Heart: a paid spin costs two health, the last chip costs one, and the spins the
	# run never charges for stay free. The brain jackpot is untouched again.
	run_store.augmentedTier = "heart"
	if int(run_store._augmented_health_cost_multiplier()) != 2:
		failures.append("issue111: heart did not double the health cost of a spin")
	run_store.augmentedTier = ""
	if int(run_store._augmented_health_cost_multiplier()) != 1:
		failures.append("issue111: a classic spin cost more than one health")
	run_store.augmentedTier = "heart"
	var heart_decay: int = Economy.compute_neuron_decay(run_store.ownedUpgrades) \
		* run_store._augmented_health_cost_multiplier()
	if mini(heart_decay, 4) != 2:
		failures.append("issue111: heart charged %d health with room to spare" % mini(heart_decay, 4))
	if mini(heart_decay, 1) != 1:
		failures.append("issue111: heart did not discount the run's last health chip")
	var spins_before := int(run_store.freeSpinsRemaining)
	machine._apply_symbol_triple("brain", 0, false)
	if int(run_store.freeSpinsRemaining) <= spins_before:
		failures.append("issue111: heart still suppresses the brain triple's free spin")
	machine._close_score_table()
	machine._show_score_table()
	if machine._score_table.overlay() == null:
		failures.append("issue111: score table failed to open for the heart check")
	else:
		var table_texts := _overlay_label_texts(machine._score_table.overlay())
		if not table_texts.has("+200"):
			failures.append("issue111: heart no longer pays the full jackpot in the score table")
	machine._close_score_table()
	run_store.augmentedTier = ""

	# Joker: the four in-run items are dealt turned against the player. Same ids, same
	# stash, same icons (rendered inverted) — only the effect and the copy change.
	var prev_items_phase := String(run_store.runPhase)
	var prev_items_stash: Dictionary = (run_store.runConsumables as Dictionary).duplicate(true)
	var prev_items_locked: Array = (run_store.lockedReels as Array).duplicate()
	var prev_items_mult := int(run_store.betMultiplier)
	if InRunItems.effect_for("item_water", false) == InRunItems.effect_for("item_water", true):
		failures.append("issue111: a joker run deals the same Water as a classic one")
	for id in InRunItems.JOKER_EFFECTS:
		if InRunItems.effect_for(String(id), false) == null:
			failures.append("issue111: joker table names an item the classic pool lacks: %s" % String(id))
	run_store.augmentedTier = "joker"
	run_store.runPhase = "running"
	run_store.isSpinning = false
	run_store.comboDefeatPending = false
	run_store.dealerIncoming = false
	run_store.dealerPending = false
	run_store.compulsiveSpinSkips = 0
	run_store.pendingCompulsiveSpinSkips = 0
	run_store.decaySkips = 0
	run_store.neurons = 100
	run_store.freeSpinsRemaining = 0

	# Joker Water drains the gauge instead of filling it, and takes nothing else: the
	# banked score and the Lucidity wallet are what the player keeps.
	var water_score := int(run_store.scoreEarned)
	var water_coins := int(run_store.lucidityCoins)
	run_store.pendingPowerBarDrains = 0
	run_store.runConsumables = { "item_water": 1 }
	if not run_store.use_consumable("item_water"):
		failures.append("issue111: the joker Water was refused in a clean running state")
	if int(run_store.pendingPowerBarDrains) != 1:
		failures.append("issue111: the joker Water did not queue the gauge drain")
	if int(run_store.scoreEarned) != water_score or int(run_store.lucidityCoins) != water_coins:
		failures.append("issue111: the joker Water still paid out its 40 score/Lucidity")
	machine._power_bar_score = 20
	machine._set_power_bar_frame(2)
	if not run_store.consume_power_bar_drain():
		failures.append("issue111: the queued gauge drain could not be claimed")
	machine._drain_power_bar()
	if int(machine._power_bar_score) != 0 or int(machine._power_bar_frame) != 0:
		failures.append("issue111: the joker Water left progress on the gauge")
	if int(machine._power_seen_lucidity) != int(machine._power_point_total()):
		failures.append("issue111: the drained points can be re-planned as a fresh gain")
	if run_store.consume_power_bar_drain():
		failures.append("issue111: a claimed gauge drain was handed out twice")

	# Joker Red Pill: one reel is dragged to flatline, and nothing is owed back.
	run_store.lockedReels = [false, false, false]
	run_store.lockedReelSpins = [0, 0, 0]
	run_store.runConsumables = { "item_pill": 1 }
	run_store.use_consumable("item_pill")
	if int(run_store.jokerFlatlineSpins) != 1 or int(run_store.forceFlatlineSpins) != 0 \
			or int(run_store.guaranteedTripleSpins) != 0:
		failures.append("issue111: the joker Red Pill set the classic pill's counters")
	var joker_pill_spin: Variant = run_store.spin()
	run_store.set_spinning(false)
	if joker_pill_spin == null:
		failures.append("issue111: the joker Red Pill spin did not resolve")
	elif not (joker_pill_spin["reels"] as Array).has("flatline"):
		failures.append("issue111: the joker Red Pill dragged no reel to flatline: %s" \
			% str(joker_pill_spin["reels"]))
	if int(run_store.jokerFlatlineSpins) != 0:
		failures.append("issue111: the joker Red Pill did not spend its spin")

	# Joker Cocktail: a WIN is charged the rarity points the classic one would have paid,
	# and a miss is charged nothing — there are no winnings to take.
	run_store.neurons = 100
	# The pill spin above may well have missed and opened a losing state; spin() resolves
	# a pending one by dropping the gauge, which would quietly rescale the malus below.
	run_store.comboDefeatPending = false
	run_store.pendingComboMultiplier = 1
	run_store.betMultiplier = 3
	run_store.freeSpinsRemaining = 0
	run_store.cocktailBoostSpins = 0
	run_store.runConsumables = { "item_cocktail": 1 }
	run_store.use_consumable("item_cocktail")
	if int(run_store.cocktailMalusSpins) != 2 or int(run_store.cocktailBoostSpins) != 0:
		failures.append("issue111: the joker Cocktail armed the paying boost")
	run_store.lastResult = { "reels": ["eye", "eye", "vial"] }
	run_store.lockedReels = [true, true, true]
	run_store.lockedReelSpins = [2, 2, 2]
	var malus_spin: Variant = run_store.spin()
	run_store.set_spinning(false)
	if malus_spin == null:
		failures.append("issue111: the joker Cocktail test spin did not resolve")
	else:
		# The same 36 the classic Cocktail pays for these reels at x3 (issue #185's case),
		# taken off a 30-point pair — floored at zero rather than going negative.
		if int(malus_spin.get("cocktailMalus", 0)) != 36:
			failures.append("issue111: the joker Cocktail charged %d, expected the 36 it would have paid" \
				% int(malus_spin.get("cocktailMalus", 0)))
		if int(malus_spin["scoreEarned"]) != 0 or int(malus_spin["coinsEarned"]) != 0:
			failures.append("issue111: the joker Cocktail win was not taken down to zero: %s" \
				% str(malus_spin))
	run_store.lastResult = { "reels": ["eye", "vial", "brain"] }
	run_store.lockedReels = [true, true, true]
	run_store.lockedReelSpins = [2, 2, 2]
	var malus_miss: Variant = run_store.spin()
	run_store.set_spinning(false)
	if malus_miss != null and malus_miss.has("cocktailMalus"):
		failures.append("issue111: the joker Cocktail charged a miss that won nothing")
	# The joker dealer does not offer, he delivers: one item of the visit is named up
	# front (the same one however often it is asked for), then bought and used at once.
	var prev_forced_pending := bool(run_store.dealerPending)
	var prev_forced_offers: Variant = run_store.dealerOfferIds
	run_store.comboDefeatPending = false
	run_store.compulsiveSpinSkips = 0
	run_store.pendingCompulsiveSpinSkips = 0
	run_store.cocktailMalusSpins = 0
	run_store.dealerPending = true
	run_store.dealerOfferIds = ["item_water", "item_pill"]
	var forced_id := String(run_store.joker_forced_offer_id())
	if not ["item_water", "item_pill"].has(forced_id):
		failures.append("issue111: the joker visit named no item from its own offer: '%s'" % forced_id)
	if String(run_store.joker_forced_offer_id()) != forced_id:
		failures.append("issue111: the joker visit named a different item when asked twice")
	# A full stash cannot swallow the delivery: it is taken over the cap and spent at once.
	run_store.runConsumables = { "item_cocktail": Consumables.MAX_CONSUMABLE_SLOTS }
	run_store.jokerFlatlineSpins = 0
	run_store.pendingPowerBarDrains = 0
	# The gauge is left part-full so a forced Water can be seen emptying it: the machine
	# claims its own drain inside the delivery, so the queue is back to zero afterwards.
	machine._power_bar_score = 20
	machine._set_power_bar_frame(2)
	machine._dealer_forced_take(forced_id)
	if bool(run_store.dealerPending) or run_store.dealerOfferIds != null:
		failures.append("issue111: the forced delivery did not resolve the dealer visit")
	if int((run_store.runConsumables as Dictionary).get(forced_id, 0)) != 0:
		failures.append("issue111: the forced item was left sitting in the stash")
	var forced_landed := int(run_store.jokerFlatlineSpins) > 0 \
		if forced_id == "item_pill" else int(machine._power_bar_score) == 0 \
			and int(machine._power_bar_frame) == 0
	if not forced_landed:
		failures.append("issue111: the forced item was taken but never used (%s)" % forced_id)
	if int(run_store.pendingPowerBarDrains) != 0:
		failures.append("issue111: the delivery left its gauge drain unclaimed")
	run_store.jokerFlatlineSpins = 0
	run_store.pendingPowerBarDrains = 0
	run_store.dealerPending = prev_forced_pending
	run_store.dealerOfferIds = prev_forced_offers
	run_store.augmentedTier = ""
	if String(run_store.joker_forced_offer_id()) != "":
		failures.append("issue111: a classic visit had its item chosen for it")
	run_store.augmentedTier = "joker"

	run_store.cocktailMalusSpins = 0
	run_store.lockedReels = prev_items_locked
	run_store.lockedReelSpins = [0, 0, 0]
	run_store.betMultiplier = prev_items_mult
	run_store.runConsumables = prev_items_stash
	run_store.runPhase = prev_items_phase
	run_store.augmentedTier = ""
	# Nothing of the joker items survives the joker run.
	if int(run_store.pendingPowerBarDrains) != 0 or int(run_store.jokerFlatlineSpins) != 0 \
			or int(run_store.cocktailMalusSpins) != 0:
		failures.append("issue111: a joker item effect outlived the joker run")

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
		if desc.text != String(menu.AUGMENTED_DESCRIPTIONS["heart"]):
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
