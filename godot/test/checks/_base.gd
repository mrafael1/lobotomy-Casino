extends RefCounted

## Everything a check needs that is not itself a check: a way to reach the SceneTree, the
## helpers several domains share, and the handful of checks that exist only to be called
## by another one.
##
## The checks were written as methods on a SceneTree, so they call get_root() and
## create_timer() bare and `await process_frame` directly — roughly 120 call sites. Moving
## them onto plain objects would normally mean rewriting every one of those to reach
## through a stored tree: churn across every check in the suite, changing the behaviour of
## none of them, and burying the actual move in the noise. So this base presents the same
## surface instead. The bodies moved out of scene_smoke.gd byte for byte, which is what
## makes the split reviewable as the cut-and-paste it is.

var tree: SceneTree

## Held as a value rather than forwarded through a method, because `await process_frame`
## has to resolve to a Signal, and a method call would hand back whatever it returned.
var process_frame: Signal

func _init(scene_tree: SceneTree) -> void:
	tree = scene_tree
	process_frame = scene_tree.process_frame

func get_root() -> Window:
	return tree.root

func create_timer(seconds: float) -> SceneTreeTimer:
	return tree.create_timer(seconds)

## ── checks that exist only to be called by other checks ──────────────────────────
##
## These are not registered in the runner's table and are not meant to be: they take a
## node the calling check has already built (a dealer, a settings screen, a button), so
## they have no isolation of their own to declare. They live here rather than in one
## domain file so that no domain has to reach into another.


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
		# A Button centres its label in the CONTENT box, so the gap between the top and
		# bottom margins IS the label's offset from the plate's middle. This used to demand
		# bottom > top — pushing every compact label upward on the theory that the font
		# leaves its slack below the glyphs. It leaves it above: measured against rendered
		# ink (test/debug_font_metrics.gd), upper-case copy in this font already sits high,
		# and lifting it again is what put DONE and TABLES above their own plate centres.
		# The box must now be balanced, offset only by that measured per-size correction.
		# The const, not the accessor: an autoload's CONSTANTS resolve statically here, but
		# a method call on it needs the singleton instance and will not compile in a `-s`
		# script (the same trap as naming a @tool class from this file).
		var nudge := float(Assets.CENTERED_TEXT_NUDGE.get(
			button.get_theme_font_size("font_size"), 0.0))
		var offset := style.content_margin_top - style.content_margin_bottom
		if not is_equal_approx(offset, nudge * 2.0):
			failures.append("%s: compact label sits %.1fpx off its plate's centre" % [
				label, offset * 0.5 - nudge])


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
	# MUTE is a TOGGLE and must not wear the button art: with a plate it read as a second
	# button stacked on BACK, one that mysteriously did not navigate. The box and its tick
	# carry the state instead, so every stylebox on it has to draw nothing.
	var mute := settings.get_node_or_null("Panel/Rows/MuteCheck") as CheckBox
	if mute == null:
		failures.append("settings: MUTE toggle is missing")
	else:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			if not (mute.get_theme_stylebox(String(state)) is StyleBoxEmpty):
				failures.append("settings: MUTE is wearing a %s button plate" % state)
				break
		# The tick is the only thing left that says on from off, so both icons must exist
		# and must not be the same image.
		var checked := mute.get_theme_icon(&"checked")
		var unchecked := mute.get_theme_icon(&"unchecked")
		if checked == null or unchecked == null or checked == unchecked:
			failures.append("settings: MUTE cannot show checked apart from unchecked")
		if mute.custom_minimum_size.y < 20.0:
			failures.append("settings: MUTE lost its tap target with its plate")
	var back := settings.get_node_or_null("Panel/Rows/BackButton") as Button
	_check_start_menu_button_style(back, ButtonKit.START_MENU_BUTTON_CYAN, "settings: BACK", failures)
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
			_check_start_menu_button_style(cancel_button, ButtonKit.START_MENU_BUTTON_PINK,
				"issue84: CANCEL", failures, true)
			_check_start_menu_button_style(enter_button, ButtonKit.START_MENU_BUTTON_CYAN,
				"issue84: ENTER", failures, true)
			_check_start_menu_press_feedback(cancel_button, "issue84: CANCEL", failures)
			_check_start_menu_press_feedback(enter_button, "issue84: ENTER", failures)
		# Cancelling dismisses the modal (and does not start the run).
		dealer._on_start_cancelled()
		if modal.visible:
			failures.append("issue84: CANCEL did not dismiss the start-confirm modal")


func _check_dealer_scene_revamp_55(dealer: Node, failures: Array) -> void:
	_check_dealer_shop_light_art(dealer, failures)
	if not dealer.has_method("_native_canvas_origin") \
			or dealer.call("_native_canvas_origin", Vector2(180.0, 320.0)) != Vector2(10.0, 0.0):
		failures.append("issue55: dealer native artwork canvas is not horizontally centred")
	var expected_offer_tops := [192.0, 192.2, 192.0, 192.2, 192.2]
	for index in expected_offer_tops.size():
		var slot := dealer.get_node_or_null("OfferSlot%d" % (index + 1)) as Control
		if slot == null or not is_equal_approx(slot.position.y, expected_offer_tops[index]):
			failures.append("issue55: OfferSlot%d is not resting on the updated counter line" \
				% (index + 1))
	if not is_equal_approx(float(dealer.COUNTER_DOT_CY), 208.0):
		failures.append("shop: counter contact row drifted from the authored dot line")
	var checked_offer_frames := 0
	for offer_id_variant in dealer._item_nodes:
		var offer_id := String(offer_id_variant)
		var item_node := dealer._item_nodes[offer_id] as Control
		if item_node == null:
			continue
		var kind := "augment" if ChipAugments.map().has(offer_id) else "offer"
		var parent := item_node.get_parent() as Control
		var parent_y: float = dealer.call("_counter_parent_origin_y", parent)
		var expected_top: float = dealer.call(
			"_counter_item_top", offer_id, kind, item_node.size.y)
		if not is_equal_approx(item_node.position.y + parent_y, expected_top):
			failures.append("shop: %s hitbox is not aligned to its counter contact point" % offer_id)
		if item_node.size != Vector2(16.0, 16.0):
			failures.append("shop: %s lost its authored 16px hitbox" % offer_id)
		checked_offer_frames += 1
	if checked_offer_frames == 0:
		failures.append("shop: no counter offer hitboxes were built")
	# Exported builds (APK) only ship res:// — the runtime asset tree
	# fallback does not exist on device, so shipped art MUST resolve as a resource.
	for rel in [
		"dealer_shop/bg.png",
		"dealer_shop/counter.png",
		"dealer_shop/machine.png",
		"dealer_shop/reroll.png",
	]:
		if not ResourceLoader.exists("res://assets/images/" + String(rel)):
			failures.append("issue55: %s not in godot/assets/images — missing from exported builds (APK)" % rel)
	var start_button := dealer.get_node_or_null("StartButton") as Button
	var machine_art := dealer.get_node_or_null("MachineButtonArt") as Sprite2D
	if start_button == null or machine_art == null:
		failures.append("issue55: dealer machine button/art pair is missing")
	else:
		if machine_art.hframes != 2:
			failures.append("issue55: machine button art is not a 2-frame sheet")
		if machine_art.position != Vector2(-20.0, -30.0):
			failures.append("issue55: machine art is not centred on the bleed-aware dealer canvas")
		if machine_art.scale != Vector2.ONE:
			failures.append("issue55: machine art is not kept at native source-pixel scale")
		if machine_art.texture == null \
				or not machine_art.texture.resource_path.ends_with("dealer_shop/machine.png"):
			failures.append("issue55: machine art is not using the native dealer-shop asset")
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
		"dealer_shop/bg.png": Vector2i(200, 380),
		"dealer_shop/counter.png": Vector2i(200, 380),
		"dealer_shop/machine.png": Vector2i(400, 380),
		"dealer_shop/reroll.png": Vector2i(400, 380),
	}
	for rel in expected_sizes:
		var path := "res://assets/images/" + String(rel)
		if not ResourceLoader.exists(path):
			failures.append("dealer shop: missing native art %s" % rel)
			continue
		var texture := load(path) as Texture2D
		var expected: Vector2i = expected_sizes[rel]
		if texture == null or Vector2i(texture.get_width(), texture.get_height()) != expected:
			failures.append("dealer shop: %s is not a native sheet at %s" % [rel, expected])
	var background := dealer.get_node_or_null("Background") as Sprite2D
	if background == null or background.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		failures.append("dealer shop: background is not nearest-neighbor filtered")
	elif background.texture == null \
			or not background.texture.resource_path.ends_with("dealer_shop/bg.png") \
			or background.position != Vector2(-20.0, -30.0) \
			or background.scale != Vector2.ONE:
		failures.append("dealer shop: background is not the centred native sheet")
	var counter := dealer.get_node_or_null("Counter") as Sprite2D
	if counter == null:
		failures.append("dealer shop: counter node is missing")
	elif counter.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST \
			or counter.hframes != 1 or counter.texture == null \
			or not counter.texture.resource_path.ends_with("dealer_shop/counter.png") \
			or counter.position != Vector2(-20.0, -30.0) \
			or counter.scale != Vector2.ONE:
		failures.append("dealer shop: counter is not the centred native sheet")
	for art_name in ["MachineButtonArt", "RerollButtonArt"]:
		var art := dealer.get_node_or_null(art_name) as Sprite2D
		if art == null or art.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST \
				or art.hframes != 2 or art.texture == null:
			failures.append("dealer shop: %s is not a nearest-neighbor 2-frame sheet" % art_name)
			continue
		if Vector2i(art.texture.get_width(), art.texture.get_height()) != Vector2i(400, 380) \
				or art.position != Vector2(-20.0, -30.0) \
				or art.scale != Vector2.ONE:
			failures.append("dealer shop: %s is not centred at native source-pixel scale" % art_name)
		var expected_asset := "dealer_shop/machine.png" if art_name == "MachineButtonArt" \
				else "dealer_shop/reroll.png"
		if not art.texture.resource_path.ends_with(expected_asset):
			failures.append("dealer shop: %s is using the wrong native asset" % art_name)

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

	var info_buttons: Array = machine._score_table.info_buttons()
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
	var popup: Control = machine._score_table.info_popup()
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
	if machine._score_table.info_popup() != null:
		failures.append("issue119: releasing the info button did not hide the effect popup")

	# Focus chain: CLOSE holds initial focus and links down into the rows.
	var close := overlay.get_node_or_null("CloseButton") as Button
	if close == null:
		failures.append("issue119: table has no CLOSE button")
	else:
		_check_start_menu_button_style(close, ButtonKit.START_MENU_BUTTON_YELLOW,
			"issue119: BACK", failures, true)
		if overlay.get_viewport() != null and overlay.get_viewport().gui_get_focus_owner() != close:
			failures.append("issue119: CLOSE did not take initial focus for keyboard/controller nav")
		# The chain interleaves each row's LVL pct-peek "i" before its effect
		# info button, so CLOSE links down into the first pct button (#153).
		var first_pct := machine._score_table.pct_buttons()[0] as Button
		if close.get_node_or_null(close.focus_neighbor_bottom) != first_pct:
			failures.append("issue119: CLOSE does not link down to the first pct button")
		if first_pct.get_node_or_null(first_pct.focus_neighbor_top) != close:
			failures.append("issue119: first pct button does not link back up to CLOSE")
		if first_pct.get_node_or_null(first_pct.focus_neighbor_bottom) != info_buttons[0]:
			failures.append("issue119: first pct button does not link down to its info button")
	# Issue #153: holding the "i" under a row's LVL value peeks at the symbol's
	# live draw chance (moved off the baked symbol box, matching the odds table).
	if machine._score_table.pct_buttons().size() != 6:
		failures.append("score-pct: every row should have a pct-peek button under LVL")
	else:
		var pct_button := machine._score_table.pct_buttons()[1] as Button
		pct_button.button_down.emit()
		var pct_popup: Control = machine._score_table.info_popup()
		if pct_popup == null or pct_popup.name != "PctPopup":
			failures.append("score-pct: holding the LVL info button did not show the pct bubble")
		else:
			var panel := pct_popup.get_child(0) as Panel
			var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
			var expected: Color = ScoreTable.PCT_COLORS["eye"]
			if style == null or not style.border_color.is_equal_approx(expected):
				failures.append("score-pct: bubble contour is not the symbol row color")
		pct_button.button_up.emit()
		if machine._score_table.info_popup() != null:
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

func _pacte_power_result(reels: Array) -> Dictionary:
	return {
		"reels": reels, "scoreEarned": 0, "coinsEarned": 0,
		"freeSpinsGranted": 0, "freeSpinsAfter": 0, "isJackpot": false,
		"winType": "miss", "isFreeSpin": false, "scoreMultiplier": 1.0,
	}

func _restore_card_unlock_state(meta_store: Node, augments: Array, powers: Array, pending: Array,
		progress: Dictionary = {}) -> void:
	meta_store.unlockedAugmentCardIds = augments
	meta_store.unlockedPowerCardIds = powers
	meta_store.pendingCardUnlocks = pending
	meta_store.cardUnlockProgress = progress
	UnlockCardPopup.pending_highlight_card_id = ""

## Value equality that does not care whether a number arrived as an int or a float — the
## meta dict round-trips through JSON in the real save, so 3 and 3.0 are the same value.
func _deep_equal_variants(a: Variant, b: Variant) -> bool:
	var num_a := typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT
	var num_b := typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT
	if num_a and num_b:
		return is_equal_approx(float(a), float(b))
	return a == b

func _card_progress_result(reels: Array, win_type: String, score: int) -> Dictionary:
	return { "reels": reels, "winType": win_type, "scoreEarned": score }
