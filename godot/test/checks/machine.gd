extends "res://test/checks/_base.gd"

## The machine itself: reels, presentation, the power bar and the spin controls.
##
## Cut from scene_smoke.gd unchanged. The suite's runner owns the order and the isolation;
## this file owns nothing but the assertions. See test/checks/_base.gd for why the check
## bodies can still call get_root(), create_timer() and `await process_frame` bare.


## Machine scene must expose the dedicated jackpot burst (issue #22).
func _check_jackpot_burst_hook(machine: Node, failures: Array) -> void:
	if not machine._bursts.has_method("spawn_jackpot"):
		failures.append("machine missing the jackpot burst")

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


## Issue #181: the TV's objective readout is two authored sheets — a goal frame per
## WEALTH_TARGETS entry, and a bar whose frames are the fill toward the current target.
func _check_target_readout_181(machine: Node, run_store: Node, failures: Array) -> void:
	var previous_phase := String(run_store.runPhase)
	var previous_score := int(run_store.scoreEarned)
	var previous_index := int(run_store.wealthTargetIndex)

	if machine._wealth.bar_sprite() == null or machine._wealth.goals_sprite() == null:
		failures.append("issue181: the TV is missing the TARGET bar/goal art")
		return
	if machine._wealth.bar_sprite().hframes != WealthReadout.BAR_FRAME_COUNT \
			or machine._wealth.goals_sprite().hframes != WealthReadout.GOALS_FRAME_COUNT:
		failures.append("issue181: the TARGET sheets were sliced into the wrong frame count")
	# The shimmer is re-authored from time to time; catch a sheet whose real frame count
	# has drifted from the constant rather than letting it play sliced-up frames.
	var shimmer: Sprite2D = machine._wealth.bar_anim_sprite()
	if shimmer == null:
		failures.append("issue181: the TARGET bar shimmer is missing")
	else:
		if shimmer.hframes != WealthReadout.BAR_ANIM_FRAME_COUNT:
			failures.append("issue181: the shimmer sheet was sliced into the wrong frame count")
		if shimmer.texture != null:
			var sheet_frames := int(round(
				float(shimmer.texture.get_width()) / float(machine.SRC_W)))
			if sheet_frames != WealthReadout.BAR_ANIM_FRAME_COUNT:
				failures.append("issue181: the shimmer sheet holds %d frames, the code expects %d"
					% [sheet_frames, int(WealthReadout.BAR_ANIM_FRAME_COUNT)])
		if shimmer.z_index >= machine._wealth.bar_sprite().z_index:
			failures.append("issue181: the shimmer should play under the fill bar")
		# It has to actually advance, and wrap rather than run off the sheet.
		var first_frame := shimmer.frame
		for _step in WealthReadout.BAR_ANIM_FRAME_COUNT:
			machine._wealth.step_bar_animation(WealthReadout.BAR_ANIM_FRAME_TIME)
		if shimmer.frame != first_frame:
			failures.append("issue181: the shimmer did not loop back around")
		machine._wealth.step_bar_animation(WealthReadout.BAR_ANIM_FRAME_TIME)
		if shimmer.frame == first_frame:
			failures.append("issue181: the shimmer is not advancing")
	if machine._wealth.goals_sprite().hframes != EconomyConst.WEALTH_TARGETS.size():
		failures.append("issue181: the goal sheet does not carry one frame per wealth target")

	run_store.runPhase = "running"
	# An empty run shows the first goal and an empty bar.
	run_store.wealthTargetIndex = 0
	run_store.scoreEarned = 0
	machine._refresh_target_readout()
	if machine._wealth.goals_sprite().frame != 0 or machine._wealth.bar_sprite().frame != 0:
		failures.append("issue181: a fresh run did not show goal 0 with an empty bar")
	# Meeting the current target fills the bar completely.
	run_store.scoreEarned = EconomyConst.WEALTH_TARGETS[0]
	machine._refresh_target_readout()
	if machine._wealth.bar_sprite().frame != WealthReadout.BAR_FRAME_COUNT - 1:
		failures.append("issue181: reaching the target did not fill the TARGET bar")
	# Paying it advances the goal frame and empties the bar again.
	run_store.wealthTargetIndex = 3
	run_store.scoreEarned = 0
	machine._refresh_target_readout()
	if machine._wealth.goals_sprite().frame != 3:
		failures.append("issue181: the goal frame does not follow the wealth target index")
	if machine._wealth.bar_sprite().frame != 0:
		failures.append("issue181: the TARGET bar did not refill from empty after a payout")
	# Half way to the last target reads as a partially filled bar, never a full one.
	run_store.wealthTargetIndex = EconomyConst.WEALTH_TARGETS.size() - 1
	run_store.scoreEarned = int(run_store.current_wealth_target() / 2)
	machine._refresh_target_readout()
	var half_frame: int = machine._wealth.bar_sprite().frame
	if half_frame <= 0 or half_frame >= WealthReadout.BAR_FRAME_COUNT - 1:
		failures.append("issue181: half progress did not land mid-bar (frame %d)" % half_frame)

	run_store.wealthTargetIndex = previous_index
	run_store.scoreEarned = previous_score
	run_store.runPhase = previous_phase
	machine._refresh_target_readout()

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
	machine._callouts.stop_win()
	machine._power_callout.stop()
	machine._tv_info_pop_sources.clear()
	machine._set_tv_progress_bars_visible(true)
	machine._update_hud()
	var free_spin := machine._free_spin_sprite as CanvasItem
	var dealer_bar := machine._dealer_bar.bar_sprite() as CanvasItem
	var dealer_icon := machine._dealer_icon as CanvasItem
	var target_bar := machine._wealth.bar_sprite() as CanvasItem
	var target_goals := machine._wealth.goals_sprite() as CanvasItem
	var target_bar_anim := machine._wealth.bar_anim_sprite() as CanvasItem
	var boost_slot: CanvasItem = null
	if not machine._boosts.slots().is_empty():
		boost_slot = (machine._boosts.slots()[0] as Dictionary)["slot"] as CanvasItem
	if free_spin != null and free_spin.visible:
		failures.append("TV callout priority: FREE SPIN banner showed without a credit")
	if dealer_bar == null or not dealer_bar.visible or dealer_icon == null or not dealer_icon.visible:
		failures.append("TV callout priority: dealer information did not establish its baseline")
	if target_bar == null or not target_bar.visible:
		failures.append("TV callout priority: objective readout did not establish its baseline")
	if boost_slot == null or not boost_slot.visible:
		failures.append("TV callout priority: boost icon did not establish its baseline")

	# A banked free spin lights the banner. Issue #185: it is a narrow owner now — it takes
	# only the goal NUMBER, whose band its own text runs into, and leaves the dealer
	# interface, the item icons and the fill bar (with its shimmer still stepping) lit
	# beside it. Progress toward the target is what the free spins are being spent on.
	run_store.freeSpinsRemaining = 1
	machine._update_hud()
	if free_spin == null or not free_spin.visible:
		failures.append("TV callout priority: FREE SPIN banner did not light")
	if target_goals != null and target_goals.visible:
		failures.append("issue185: FREE SPIN should hide the goal number")
	if target_bar == null or not target_bar.visible:
		failures.append("issue185: FREE SPIN should keep the target bar lit")
	if target_bar_anim == null or not target_bar_anim.visible:
		failures.append("issue185: FREE SPIN should keep the target bar animation running")
	if boost_slot == null or not boost_slot.visible:
		failures.append("issue185: FREE SPIN should keep the item icons lit beside it")
	# One authored placement: the banner text sits at y84..89, in the band the goal number
	# just vacated, so it clears the fill bar at y94..98 instead of being clipped by it.
	if machine.FREE_SPIN_FRAMES != 1:
		failures.append("issue185: the FREE SPIN banner should be a single authored frame")
	if (dealer_bar != null and not dealer_bar.visible) \
			or (dealer_icon != null and not dealer_icon.visible):
		failures.append("TV callout priority: FREE SPIN hid the dealer interface")

	machine._callouts.play_win("pair", 20)
	if machine._callouts.win_sprite() == null or not machine._callouts.win_sprite().visible:
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
	# Closing the callout hands the screen back to the banner and to everything that
	# shares it with: the dealer strip, the item icons and the fill bar. Only the goal
	# number keeps waiting the banner out.
	machine._callouts.stop_win()
	if free_spin != null and not free_spin.visible:
		failures.append("TV callout priority: FREE SPIN banner did not restore after PAIR")
	if target_goals != null and target_goals.visible:
		failures.append("issue185: PAIR restored the goal number under the banner")
	if target_bar != null and not target_bar.visible:
		failures.append("issue185: the target bar did not come back with the banner after PAIR")
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
		machine._power_callout.show_power(String(power_id))
		if machine._power_callout.sprite() == null \
				or int(machine._power_callout.sprite().frame) != int(expected_power_frames[power_id]):
			failures.append("TV callout priority: %s uses the wrong power animation frame" % power_id)
	machine._power_callout.show_power("reroll")
	if (free_spin != null and free_spin.visible) or (dealer_bar != null and dealer_bar.visible):
		failures.append("TV callout priority: power callout did not hide persistent TV information")
	machine._power_callout.stop()
	machine._callouts.play_win("triple", 50)
	machine._power_callout.show_power("shift")
	machine._callouts.stop_win()
	if free_spin != null and free_spin.visible:
		failures.append("TV callout priority: overlapping power callout released priority too early")
	machine._power_callout.stop()
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

# Issue #76: active multi-spin boosts show a little consumable icon + spins-remaining in
# the TV's top-right. Icons appear only while their counter is live, stack in order, show
# the right count, and clear when the boost ends.
func _check_boost_duration_icons_76(machine: Node, run_store: Node, failures: Array) -> void:
	run_store.reset_run_state()
	var slots: Array = machine._boosts.slots()
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
	# Issue #185 follow-up: the row moved below the fill bar and fills LEFT to right, one
	# slot per possible item instead of two with an overflow. Every slot — icon plus the
	# count beside it — has to stay inside the strip that was measured clear (y99..107,
	# x30..121) and off the TV's other authored art.
	var p0: Vector2 = (slots[0]["slot"] as Control).position
	var p1: Vector2 = (slots[1]["slot"] as Control).position
	if not is_equal_approx(p0.y, p1.y) or not (p0.x < p1.x):
		failures.append("issue185: boost icons did not fill left to right (%s vs %s)" % [p0, p1])
	if BoostIndicators.SLOT_POSITIONS.size() < 5:
		failures.append("issue185: the badge row should hold more than the old two items (%d)"
			% BoostIndicators.SLOT_POSITIONS.size())
	var tv_left := float(machine.TV_SCREEN["left"])
	var tv_top := float(machine.TV_SCREEN["top"])
	var tv_bottom := tv_top + float(machine.TV_SCREEN["height"])
	var icon_size: float = BoostIndicators.ICON_SIZE
	# Source item art is 32x32, so the badge must divide 32 exactly or the nearest-
	# neighbour reduction drops source pixels unevenly and the icon reads as mush.
	if not is_equal_approx(fmod(32.0, icon_size), 0.0):
		failures.append("issue185: badge size %d is not an exact division of the 32px source art"
			% int(icon_size))
	var dealer_rect := Rect2(machine.DEALER_ICON_POS, machine.DEALER_ICON_SIZE)
	# Measured art extents of the TV's other occupants (see the constants' comment).
	# The widest goal frame runs x66..83; the bar spans the TV at y94..98.
	var goal_rect := Rect2(66.0, 86.0, 18.0, 5.0)
	var fill_bar_rect := Rect2(41.0, 94.0, 70.0, 5.0)
	# The TV's own SCREEN below the fill bar, measured off the rendered cabinet as the
	# near-black region rather than "anything dark" — the surrounding cabinet grey reads
	# dark too, and counting it as screen is what let the row run past the bezel and off
	# the TV. Measured: y99..104 hold x36..115, y105..106 x37..114, y107 x39..112. The row
	# occupies y100..107, so the corner row is the binding constraint: x39..112.
	var screen_strip := Rect2(39.0, 100.0, 74.0, 8.0)
	var slot_width: float = BoostIndicators.SLOT_WIDTH
	for slot_pos: Vector2 in BoostIndicators.SLOT_POSITIONS:
		var rect := Rect2(slot_pos, Vector2(slot_width, icon_size))
		if rect.position.x < tv_left or rect.position.y < tv_top or rect.end.y > tv_bottom:
			failures.append("issue185: boost slot %s falls outside the TV" % rect)
		if not screen_strip.encloses(rect):
			failures.append("issue185: boost slot %s leaves the TV screen %s"
				% [rect, screen_strip])
		if rect.intersects(dealer_rect):
			failures.append("issue185: boost slot %s collides with the dealer icon" % rect)
		if rect.intersects(goal_rect) or rect.intersects(fill_bar_rect):
			failures.append("issue185: boost slot %s collides with the TARGET art" % rect)
	# Issue #185: the count is a bare turn number and its COLOUR carries polarity — green
	# while the item is helping, red while it is costing. The badge is 8px and the sign
	# glyphs that used to carry this crowded the art at that size.
	var green: Color = BoostIndicators.COUNT_COLOR
	var red: Color = BoostIndicators.NEGATIVE_COUNT_COLOR
	for i in 2:
		var badge_text: String = (slots[i]["count"] as Label).text
		if not badge_text.is_valid_int():
			failures.append("issue185: the count should be a bare number, got '%s'" % badge_text)
	if (slots[1]["count"] as Label).get_theme_color("font_color") != green:
		failures.append("issue185: the Cocktail is pure upside and should count in green")
	# Tobacco buys 3x pairs with a hidden reel; the boost itself is what the player
	# spent on, so it counts green like the other upsides.
	run_store.cocktailBoostSpins = 0
	run_store.decaySkips = 0
	run_store.pairBoostSpins = 4
	machine._refresh_boost_indicators()
	if (slots[0]["count"] as Label).get_theme_color("font_color") != green:
		failures.append("issue185: Tobacco should count in green")
	run_store.pairBoostSpins = 0
	run_store.cocktailBoostSpins = 2
	run_store.decaySkips = 3
	machine._refresh_boost_indicators()
	# A pure downside (Serum's blur tail) counts in red.
	run_store.cocktailBoostSpins = 0
	run_store.decaySkips = 0
	run_store.blurReelsSpins = 2
	machine._refresh_boost_indicators()
	if (slots[0]["count"] as Label).get_theme_color("font_color") != red:
		failures.append("issue185: a pure-downside boost should count in red")
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
	machine._reel_symbols.set_symbol(0, "eye")
	machine._reel_symbols.set_visible(0, true)
	machine._reel_symbols.set_adjacent_hidden(true)
	if not machine._reel_symbols.center(0).visible or machine._reel_symbols.top(0).visible or machine._reel_symbols.bottom(0).visible:
		failures.append("issue92: Serum negative did not hide adjacent reel symbols")
	machine._reel_symbols.set_adjacent_hidden(false)
	if not machine._reel_symbols.top(0).visible or not machine._reel_symbols.bottom(0).visible:
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
	machine._bursts.remember(-1, 0)
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
	var overlay: Control = machine._score_table.overlay()
	if overlay == null:
		failures.append("issue51: score table did not open")
		run_store.ownedUpgrades = owned_before
		run_store.symbolRewardBonuses = bonuses_before
		meta_store._apply(meta_before)
		meta_store.save_state()
		return
	if machine._score_button != null and machine._score_button.text != "TABLES":
		failures.append("issue51: score button is not renamed TABLES")
	_check_start_menu_button_style(machine._score_button, ButtonKit.START_MENU_BUTTON_CYAN,
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
	if machine._wealth.display_score() != 0:
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

	machine._stash.set_tray_visible(true)
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

## The losing state owns the gauge presentation: x2 shows only its authored
## overlay (no sparks), x3 shows only the 9-frame diminished-fire sheet (no
## glitch, no fire) stepped at the multiplier-effect cadence, and the regular
## effects return the moment the loss display closes.
func _check_loss_visuals_161(machine: Node, run_store: Node, failures: Array) -> void:
	if machine._callouts.loss_sprite(3) == null:
		failures.append("pr161: x3 loss sprite missing")
		return
	if int(machine._callouts.loss_sprite(3).hframes) != int(WinCallouts.COMBO_LOSS_3_FRAMES):
		failures.append("pr161: x3 loss sheet should slice into %d frames (got %d)" \
			% [int(WinCallouts.COMBO_LOSS_3_FRAMES), int(machine._callouts.loss_sprite(3).hframes)])
	# x2 loss: only the authored overlay, sparks suppressed.
	machine._refresh_multiplier_fx(2)
	machine._callouts.set_loss_display(2)
	if machine._callouts.loss_sprite(2) == null or not machine._callouts.loss_sprite(2).visible:
		failures.append("pr161: x2 loss overlay not shown")
	if machine._mult_fx_2 != null and machine._mult_fx_2.visible:
		failures.append("pr161: x2 loss must suppress the normal x2 sparks")
	machine._callouts.set_loss_display(0)
	if machine._mult_fx_2 != null and not machine._mult_fx_2.visible:
		failures.append("pr161: closing the x2 loss must restore the sparks")
	# x3 loss: only the diminished-fire sheet, glitch + fire suppressed, animated.
	machine._refresh_multiplier_fx(3)
	machine._callouts.set_loss_display(3)
	if not machine._callouts.loss_sprite(3).visible or int(machine._callouts.loss_sprite(3).frame) != 0:
		failures.append("pr161: x3 loss overlay should start visible on frame 0")
	if (machine._mult_fx_3 != null and machine._mult_fx_3.visible) \
			or (machine._mult_fx_fire != null and machine._mult_fx_fire.visible):
		failures.append("pr161: x3 loss must suppress the normal x3 glitch and fire sheets")
	machine._mult_fx_time = 0.0
	machine._step_multiplier_fx(float(machine.MULT_FX_FRAME_TIME) + 0.001)
	if int(machine._callouts.loss_sprite(3).frame) != 1:
		failures.append("pr161: x3 loss sheet did not advance at the multiplier-effect cadence")
	machine._callouts.set_loss_display(0)
	if machine._mult_fx_3 != null and not machine._mult_fx_3.visible:
		failures.append("pr161: closing the x3 loss must restore the glitch effect")
	# Only the x2 losing state beeps — x3 plays its sheet steady.
	run_store.pendingComboMultiplier = 3
	machine._callouts.start_loss_beep()
	if machine._callouts.loss_beeping():
		failures.append("pr161: x3 losing state must not beep")
	run_store.pendingComboMultiplier = 2
	machine._callouts.start_loss_beep()
	if not machine._callouts.loss_beeping():
		failures.append("pr161: x2 losing state should beep")
	machine._callouts.stop_loss_beep()
	run_store.pendingComboMultiplier = 1
	machine._refresh_multiplier_fx(1)
	machine._callouts.set_loss_display(0)

## Art GEOMETRY, as opposed to art presence or visibility semantics, which the checks
## above already cover.
##
## Added after two seams in a row (#207, #208) shipped geometry mistakes that this suite
## could not have caught: a blur strip laid out vertically instead of horizontally, and
## two invented placement constants. Both render garbage and pass every other check,
## because nothing here ever asserted where a sprite actually IS.
##
## The numbers below are derived from the source constants rather than repeated as
## literals, so a deliberate art change updates them and only a MISTAKE fails. What is
## pinned is the relationship: the strip is centred on the reel window, its neighbours sit
## one OFFSET away on each side, and every symbol is downscaled by its own texture height.
##
## Comparing rendered frames was tried first and does not work: the shot scripts are not
## deterministic, so two runs of identical code differ.
func _check_reel_strip_geometry(machine: Node, failures: Array) -> void:
	var rs = machine._reel_symbols
	var cy: float = float(machine.REEL_WINDOW["top"]) + float(machine.REEL_WINDOW["height"]) * 0.5
	rs.set_symbol(0, "eye")
	rs.set_visible(0, true)

	var expected_y := {
		"center": cy,
		"top": cy - ReelSymbols.OFFSET,
		"bottom": cy + ReelSymbols.OFFSET,
	}
	var expected_alpha := {
		"center": 1.0, "top": ReelSymbols.STRIP_ADJ_ALPHA, "bottom": ReelSymbols.STRIP_ADJ_ALPHA,
	}
	var expected_h := {
		"center": ReelSymbols.CENTER_H, "top": ReelSymbols.ADJ_H, "bottom": ReelSymbols.ADJ_H,
	}
	var sprites := { "center": rs.center(0), "top": rs.top(0), "bottom": rs.bottom(0) }
	for slot in ["center", "top", "bottom"]:
		var s := sprites[slot] as Sprite2D
		if s == null:
			failures.append("reel geometry: %s sprite is missing" % slot)
			continue
		var cx: float = float(machine.REEL_CELL_CENTERS[0])
		if not is_equal_approx(s.position.x, cx):
			failures.append("reel geometry: %s x is %.2f, expected the reel centre %.2f"
				% [slot, s.position.x, cx])
		if not is_equal_approx(s.position.y, float(expected_y[slot])):
			failures.append("reel geometry: %s y is %.2f, expected %.2f"
				% [slot, s.position.y, float(expected_y[slot])])
		if not is_equal_approx(s.modulate.a, float(expected_alpha[slot])):
			failures.append("reel geometry: %s alpha is %.2f, expected %.2f"
				% [slot, s.modulate.a, float(expected_alpha[slot])])
		if s.texture == null:
			failures.append("reel geometry: %s has no texture" % slot)
			continue
		# Never scaled UP: the art is authored large and only ever shrinks to the slot.
		var want_scale: float = minf(1.0,
			float(expected_h[slot]) / float(s.texture.get_height()))
		if not is_equal_approx(s.scale.y, want_scale):
			failures.append("reel geometry: %s scale is %.4f, expected %.4f"
				% [slot, s.scale.y, want_scale])
		if not is_equal_approx(s.scale.x, s.scale.y):
			failures.append("reel geometry: %s is not uniformly scaled (%.4f x %.4f)"
				% [slot, s.scale.x, s.scale.y])

	# The two neighbour rules that are not a plain cycle step. A heart strip shows one of
	# each tier rather than nine of one, and book sits outside the cycle entirely.
	var heart: Dictionary = rs.neighbours_of("heart_x2")
	if String(heart.get("top", "")) != "heart_x1" or String(heart.get("bottom", "")) != "heart_x3":
		failures.append("reel geometry: heart_x2 neighbours are %s, expected x1/x3" % str(heart))
	var book: Dictionary = rs.neighbours_of("book")
	var cycle: Array = Symbols.BASE_SYMBOL_CYCLE
	if String(book.get("top", "")) != String(cycle[cycle.size() - 1]) \
			or String(book.get("bottom", "")) != String(cycle[1]):
		failures.append("reel geometry: book neighbours are %s, expected %s/%s"
			% [str(book), str(cycle[cycle.size() - 1]), str(cycle[1])])

## The spin blur's region rect. The sheet is ONE HORIZONTAL ROW of full-canvas frames, and
## a version of this that stepped down the sheet instead of across it was written and
## caught by hand during #207 — it renders a plausible-looking wrong thing.
func _check_spin_blur_region(machine: Node, failures: Array) -> void:
	var rb = machine._reel_blur
	var scale: float = float(machine.ASSET_SCALE)
	for reel in 3:
		var hole: Dictionary = machine.REEL_HOLES[reel]
		rb.set_spin_frame(reel, 0)
		var first: Rect2 = rb.spin_region(reel)
		if first == Rect2():
			failures.append("blur region: reel %d has no strip sprite" % reel)
			continue
		if not is_equal_approx(first.position.x, float(hole["left"]) * scale) \
				or not is_equal_approx(first.position.y, float(hole["top"]) * scale):
			failures.append("blur region: reel %d frame 0 starts at %s, expected the hole origin"
				% [reel, str(first.position)])
		if not is_equal_approx(first.size.x, float(hole["width"]) * scale) \
				or not is_equal_approx(first.size.y, float(hole["height"]) * scale):
			failures.append("blur region: reel %d window is %s, expected the hole size"
				% [reel, str(first.size)])
		# Frame 1 steps ACROSS the sheet, never down it.
		rb.set_spin_frame(reel, 1)
		var second: Rect2 = rb.spin_region(reel)
		if is_equal_approx(second.position.x, first.position.x):
			failures.append("blur region: reel %d frame 1 did not advance horizontally" % reel)
		if not is_equal_approx(second.position.y, first.position.y):
			failures.append("blur region: reel %d frame 1 moved vertically (%.1f -> %.1f); "
				% [reel, first.position.y, second.position.y]
				+ "the sheet is one horizontal row of frames")
		rb.set_spin_frame(reel, 0)
