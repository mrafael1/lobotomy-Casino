extends "res://test/checks/_base.gd"

## The dealer -- offers, tips, gating, pacing and the odds table.
##
## Cut from scene_smoke.gd unchanged. The suite's runner owns the order and the isolation;
## this file owns nothing but the assertions. See test/checks/_base.gd for why the check
## bodies can still call get_root(), create_timer() and `await process_frame` bare.


## The dealer's pre-run vs in-run offer-pool branching (issue #21, the suite's original
## reason to exist).
func _check_dealer_offer_pools(run_store: Node, failures: Array) -> void:
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
	var glow: Control = machine._reserve_glow_sprite
	if glow == null:
		failures.append("issue132: the machine built no reserve glow")
	else:
		run_store.runPhase = "running"
		meta_store.chipAugmentsPurchased = { "aug_emergency_reserve": 1 }
		meta_store.emergencyReserveUsed = false
		machine._refresh_reserve_glow()
		if not glow.visible:
			failures.append("issue132: an armed reserve did not outline the shelf counter")
		if not glow.get_rect().encloses(machine.SPINS_LEFT_LABEL_RECT):
			failures.append("issue132: reserve contour does not surround the shelf counter")
		if glow.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			failures.append("issue132: reserve contour intercepts input")
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
	var bar: Sprite2D = machine._dealer_bar.bar_sprite()
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
		_check_start_menu_button_style(done_button, ButtonKit.START_MENU_BUTTON_CYAN,
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
	var stash_icons: Array = machine._stash.icons()
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
		if tray != null and int(tray.z_index) != int(StashTray.DEALER_Z_INDEX):
			failures.append("pr161: stash must ride above the dealer while his offer is up")
	machine._close_dealer()
	if not bool(run_store.comboDefeatPending):
		failures.append("pr161: closing the dealer must return to the pending loss decision")
	if not bool(machine._sequence_lock_active):
		failures.append("pr161: pending loss must keep the sequence lock after the dealer closes")
	var tray_after := machine.get_node_or_null("stash") as Control
	if tray_after != null and int(tray_after.z_index) != int(StashTray.TRAY_Z_INDEX):
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

## A Dealer visit is persisted gameplay state.  Repeated HUD/TV refreshes and a
## machine visual rebuild must recover the same overlay until the player dismisses it.
func _check_dealer_overlay_persistence(machine: Node, run_store: Node,
		failures: Array) -> void:
	var prev_phase := String(run_store.runPhase)
	var prev_pending := bool(run_store.dealerPending)
	var prev_offers: Variant = run_store.dealerOfferIds
	var prev_incoming := bool(run_store.dealerIncoming)
	var prev_neurons := int(run_store.neurons)
	run_store.runPhase = "running"
	run_store.neurons = 10
	run_store.dealerIncoming = false
	run_store.dealerPending = true
	run_store.dealerOfferIds = ["item_water", "item_cocktail"]
	machine._show_dealer_offers()
	for _i in 4:
		machine._refresh_tv_indicators()
		machine._refresh_controls()
		machine._refresh_consumable_fx()
		machine._update_hud()
	if machine._dealer_offer_popup == null or not machine._dealer_offer_popup.visible:
		failures.append("dealer: HUD refresh hid an active overlay")
	# A stale visual hide is recoverable from the authoritative offer state.
	if machine._dealer_offer_popup != null:
		machine._dealer_offer_popup.visible = false
	machine._update_hud()
	if machine._dealer_offer_popup == null or not machine._dealer_offer_popup.visible:
		failures.append("dealer: HUD refresh did not recover a hidden active overlay")
	# Simulate a scene teardown/resume: the Control is gone, but persisted state remains.
	machine._close_dealer(false)
	await machine.get_tree().process_frame
	machine._sync_visuals()
	if machine._dealer_offer_popup == null or not machine._dealer_offer_popup.visible \
			or not bool(run_store.dealerPending):
		failures.append("dealer: save/resume did not rebuild the active overlay")
	# The normal close is an intentional dismissal and clears the state first.
	machine._close_dealer()
	run_store.runPhase = prev_phase
	run_store.neurons = prev_neurons
	run_store.dealerPending = prev_pending
	run_store.dealerOfferIds = prev_offers
	run_store.dealerIncoming = prev_incoming
