extends "res://test/checks/_base.gd"

## The Pacte: offers, powers, augments and the chip/augment feedback.
##
## Cut from scene_smoke.gd unchanged. The suite's runner owns the order and the isolation;
## this file owns nothing but the assertions. See test/checks/_base.gd for why the check
## bodies can still call get_root(), create_timer() and `await process_frame` bare.


func _check_augment_level_readouts(machine: Node, run_store: Node, failures: Array) -> void:
	# Symbol augment levels are campaign state (issue #132), so they are read off the
	# meta store here rather than the run store.
	var meta_store: Node = get_root().get_node("MetaStateStore")
	run_store.reset_run_state()
	var base_level: int = run_store.effective_symbol_level("eye")
	var base_percent: float = machine._score_table.symbol_draw_percent("eye")
	meta_store.symbolAugmentLevels = { "eye": 1 } # one per symbol is the cap
	if run_store.effective_symbol_level("eye") != base_level + 1:
		failures.append("augment readouts: the effective symbol level ignored the augment")
	if machine._score_table.symbol_draw_percent("eye") <= base_percent:
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

	var combo_effect: Sprite2D = machine._callouts.combo_sprite()
	if combo_effect == null or int(combo_effect.hframes) < 1 \
			or int(combo_effect.hframes) > WinCallouts.COMBO_EFFECT_FRAMES:
		failures.append("pacte augment: COMBO effect sheet has an invalid frame count")
	else:
		run_store.winBoostEnabled = true
		var last_combo_frame := int(combo_effect.hframes) - 1
		machine._callouts.show_combo(last_combo_frame, 45, 45)
		if not combo_effect.visible or int(combo_effect.frame) != last_combo_frame \
				or machine._callouts.combo_payout_label() == null \
				or String(machine._callouts.combo_payout_label().text) != "+ 45 (45%)":
			failures.append("pacte augment: COMBO did not show its frame and bonus")
		machine._callouts.stop_combo()

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
	machine._callouts.refresh_combo()
	machine._show_pending_combo_defeat()
	if not combo_effect.visible or not machine._callouts.loss_beeping():
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
		# The cards do not simply appear at their offsets — _shuffle_face_down_cards
		# wiggles each one ±2px around its origin for ~0.22s when the scene opens. This
		# used to assert the position a single frame after instantiating the scene, which
		# agreed with the authored offset only because the suite always arrived here at a
		# moment the tween had not started yet. Under a shuffled order it arrives
		# mid-wiggle and reads 9.73 against an expected 10.0.
		#
		# So settle first. The deadline is wall-clock rather than a frame count because
		# headless frames are far shorter than real ones, and it exists so that a genuinely
		# mis-authored layout still FAILS here instead of hanging the suite.
		var settle_deadline := Time.get_ticks_msec() + 2000
		while Time.get_ticks_msec() < settle_deadline:
			var settled := true
			for index in expected_card_positions.size():
				var settling := pacte._card_buttons.get(String(augment_offers[index]), null) as Button
				if settling == null or settling.position != expected_card_positions[index]:
					settled = false
					break
			if settled:
				break
			await process_frame
		for index in expected_card_positions.size():
			var card_id := String(augment_offers[index])
			var card_button := pacte._card_buttons.get(card_id, null) as Button
			if card_button == null or card_button.position != expected_card_positions[index]:
				failures.append("pacte: card slot %d did not settle at its authored offset (%s)"
					% [index + 1,
					str(card_button.position) if card_button != null else "no button"])
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
		if badge_style == null or badge_style.border_color != AugmentDisplay.PACTE_AUGMENT_CONTOUR_COLOR:
			failures.append("pacte: augment badge is missing its compact blue icon contour")
		if pacte_badge.position != AugmentDisplay.PACTE_AUGMENT_BADGE_POS \
				or pacte_badge.size != AugmentDisplay.PACTE_AUGMENT_BADGE_SIZE:
			failures.append("pacte: augment badge geometry changed unexpectedly")
		# Issue #181: the augments continue the power bar rather than sitting on the TV —
		# same baseline as the three emplacements, same pitch, starting after the third.
		if machine._augments.badges().size() != AugmentDisplay.PACTE_AUGMENT_BADGE_MAX:
			failures.append("issue181: the augment row was not built to its full width")
		# The sockets plate offers exactly one bed per badge on show: frame N = N+1 sockets,
		# and nothing at all with no augments held.
		var plate := machine._augments.plate_sprite() as Sprite2D
		var held_augments: Array = machine._augments.active_ids()
		var expected_sockets: int = mini(held_augments.size(), AugmentDisplay.PACTE_AUGMENT_BADGE_MAX)
		if plate == null or plate.hframes != AugmentDisplay.AUGMENT_PLATE_FRAMES:
			failures.append("issue181: the augment sockets plate is not a %d-frame sheet"
				% int(AugmentDisplay.AUGMENT_PLATE_FRAMES))
		elif not plate.visible or plate.frame != expected_sockets - 1:
			failures.append("issue181: the sockets plate shows %d beds for %d augments"
				% [plate.frame + 1, expected_sockets])
		var kept_augments: Array = (run_store.selectedAugmentCardIds as Array).duplicate()
		run_store.selectedAugmentCardIds = []
		machine._augments.refresh_pacte_badges()
		if plate != null and plate.visible:
			failures.append("issue181: the sockets plate stayed up with no augments held")
		run_store.selectedAugmentCardIds = kept_augments
		machine._augments.refresh_pacte_badges()
		var third_slot: Dictionary = machine.POWER_HITS[machine.POWER_IDS[2]]
		if not is_equal_approx(AugmentDisplay.PACTE_AUGMENT_BADGE_POS.y, float(third_slot["top"])):
			failures.append("issue181: the augment row is not on the power bar baseline")
		if AugmentDisplay.PACTE_AUGMENT_BADGE_POS.x <= float(machine.POWER_ART_LEFT[machine.POWER_IDS[2]]):
			failures.append("issue181: the augment row does not start after the third power")
		var augment_row_end: float = AugmentDisplay.PACTE_AUGMENT_BADGE_POS.x \
			+ float(AugmentDisplay.PACTE_AUGMENT_BADGE_MAX - 1) * AugmentDisplay.PACTE_AUGMENT_BADGE_PITCH \
			+ AugmentDisplay.PACTE_AUGMENT_BADGE_SIZE.x
		if augment_row_end > 160.0:
			failures.append("issue181: the augment row runs off the canvas (ends %.1f)"
				% augment_row_end)
		if AugmentDisplay.PACTE_AUGMENT_ICON_SIZE < 8.0:
			failures.append("issue181: the augment icons were not enlarged")
		# Hold to peek, release to dismiss — the machine's one gesture for "explain this".
		pacte_badge.button_down.emit()
		if machine.get_node_or_null("PacteAugmentPopup") == null:
			failures.append("pacte: holding the augment badge did not open its description")
		# The popup is queue_free'd, so it lingers in the tree until the frame ends: the
		# handle is what says whether it is still up.
		pacte_badge.button_up.emit()
		if machine._augments.pacte_popup() != null:
			failures.append("pacte: the augment description outlived the hold")
		pacte_badge.pressed.emit()
		if machine._augments.pacte_popup() != null:
			failures.append("pacte: a plain press still toggles the augment description open")
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
		machine._reel_symbols.apply_symbol(heart_view, heart_symbol, 24.0)
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
		if machine._reel_symbols.center(reel_index).texture != heart_x1_tex \
				or machine._reel_symbols.top(reel_index).texture != heart_x3_tex \
				or machine._reel_symbols.bottom(reel_index).texture != heart_x2_tex:
			failures.append("pacte powers: arming Heart did not preview the heart tier cycle on reel %d" % reel_index)
			break
	# A resolved heart triple shows the landed tier flanked by the OTHER tiers —
	# never nine copies of one heart symbol.
	var heart_neighbours: Dictionary = machine._reel_symbols.neighbours_of("heart_x2")
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
		machine._bursts.remember(-1, 0)
		machine._refresh_reels_from_state()
		machine._emit_score_burst(null)
		if machine._callouts.win_sprite() == null or not bool(machine._callouts.win_sprite().visible) \
				or int(machine._callouts.win_sprite().frame) != int(WinCallouts.WIN_ANIM_FRAME["triple"]):
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
		machine._callouts.stop_win()
		machine._pending_spin_gain = 0
	# Swap's UI is a drag gesture over every reel, including adjacent destinations.
	run_store.abilitiesUsed = []
	run_store.lastResult = _pacte_power_result(["brain", "eye", "pill"])
	machine._arm_swap_source()
	if machine._targeting_layer == null \
			or machine._targeting_layer.name != "SwapSymbolDragLayer":
		failures.append("pacte powers: Swap did not arm its drag layer")
	if not machine._swap_shake.running():
		failures.append("pacte powers: Swap targeting did not start the reel shake")
	# The reel is the thing that moves: each one shakes its reel art, its three strip symbols
	# and its slot frame together on its own phase, so the reel reads as loose and the symbols
	# look stuck to it rather than jiggling inside a still reel.
	var shake_nodes: Array = machine._swap_shake.nodes()
	var shake_bases: Array = machine._swap_shake.bases()
	var shake_phases: Array = machine._swap_shake.phases()
	if shake_nodes.size() != 15:
		failures.append("pacte powers: Swap should shake three reels' art, symbols and frames, got %d nodes"
			% shake_nodes.size())
	elif shake_phases.size() != shake_nodes.size():
		failures.append("pacte powers: Swap shake lost track of which reel a node belongs to")
	else:
		machine._swap_shake.set_step(0)
		var reel_offsets := {}
		for i in shake_nodes.size():
			var node_offset: Vector2 = shake_nodes[i].position - shake_bases[i]
			var reel: int = shake_phases[i]
			if reel_offsets.has(reel) and reel_offsets[reel] != node_offset:
				failures.append("pacte powers: reel %d did not shake as one piece" % reel)
			reel_offsets[reel] = node_offset
		if reel_offsets.size() == 3 and reel_offsets[0] == reel_offsets[1] \
				and reel_offsets[1] == reel_offsets[2]:
			failures.append("pacte powers: the three reels shake in lockstep instead of staggered")
		machine._swap_shake.set_step(0)
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
			if machine._swap_overlay.invalid_overlay() == null \
					or not bool(machine._swap_overlay.invalid_overlay().visible):
				failures.append("pacte powers: Swap did not mark the source reel as a disabled destination")
			# Issue #181: the rejection cue is silent until the player actually offends.
			if machine._swap_overlay.invalid_overlay() != null \
					and machine._swap_overlay.invalid_overlay().modulate.a > 0.01:
				failures.append("issue181: Swap showed the red cross before an invalid hover")
			if machine._swap_overlay.invalid_overlay() != null \
					and machine._swap_overlay.invalid_overlay().get_node_or_null("InvalidMarker") != null:
				failures.append("issue181: Swap still draws the font-glyph X marker")
			machine._update_swap_drag(Vector2(43.5, 185.0))
			if machine._swap_overlay.feedback_reel() != 0 \
					or machine._swap_overlay.invalid_overlay() == null \
					or machine._swap_overlay.invalid_overlay().modulate.a < 0.99:
				failures.append("pacte powers: Swap did not show the red invalid state over the source reel")
			if machine._swap_overlay.valid_overlay() != null \
					and bool(machine._swap_overlay.valid_overlay().visible):
				failures.append("issue181: Swap showed the green target cue over the forbidden source reel")
			# Hovering a legal reel swaps the cues over: green on, red off.
			machine._update_swap_drag(Vector2(75.5, 185.0))
			if machine._swap_overlay.valid_overlay() == null \
					or not bool(machine._swap_overlay.valid_overlay().visible):
				failures.append("issue181: Swap did not highlight the legal destination reel")
			if machine._swap_overlay.invalid_overlay() != null \
					and machine._swap_overlay.invalid_overlay().modulate.a > 0.01:
				failures.append("issue181: Swap kept the red cross up over a legal destination")
			# The cues carry the whole message now — Swap has no instruction line.
			if machine._targeting_layer.get_node_or_null("SwapInstruction") != null:
				failures.append("issue181: Swap still draws an instruction line")
			# The green cue sits on the reel exactly like the red one, not off its bottom.
			if machine._swap_overlay.valid_overlay() != null \
					and machine._swap_overlay.invalid_overlay() != null \
					and not is_equal_approx(machine._swap_overlay.valid_overlay().position.y,
						machine._swap_overlay.invalid_overlay().position.y):
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
		if machine._swap_shake.running():
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

