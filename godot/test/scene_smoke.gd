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
		"res://scenes/in_run_dealer_offer.tscn",
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
	_check_base_scene_parity(failures)
	_check_first_launch_tutorial(meta_store, failures)
	_check_scene_nav(failures)
	_check_machine_ending_flow_source(failures)
	_check_flatline_action_text(machine, meta_store, failures)
	_check_global_options_layout(failures)
	_check_water_lucidity_gain(run_store, failures)
	await _check_machine_water_feedback(machine, run_store, failures)
	await _check_machine_consumable_feedback(machine, run_store, failures)
	await _check_upgrades_scene(failures)
	_check_smart_save_retention(failures)
	_check_issue27_overlay_layout(failures)
	_check_issue27_machine_stash_drag(machine, run_store, failures)
	await _check_issue28_machine_sequence_lock(machine, run_store, failures)
	_check_consumable_roster_32(run_store, failures)
	_check_machine_reactions_35(machine, run_store, failures)
	_check_campaign_rebalance_38(machine, failures)
	_check_odds_table_36(run_store, failures)
	await _check_neuron_meter_on_menu(failures)
	_check_flatline_overlay_meter(machine, failures)
	_check_wealth_screen(machine, run_store, failures)
	await _check_eye_reveal(machine, failures)
	_check_score_table_51(machine, failures)
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

	# Offer pool branches on _pre_run (set in _ready from the mode above).
	dealer._pre_run = true
	if dealer._offer_ids() != ["cons_cigarette", "cons_focus", "cons_white_powder", "cons_potion", "cons_tea"]:
		failures.append("pre-run offers wrong: %s" % str(dealer._offer_ids()))
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
		for phrase in ["The Objective", "Dealer Scene", "Upgrades Scene", "Machine Scene", "35 spins", "50 coins"]:
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
	var start_button := start_menu.get_node("MenuColumn/StartButton") as Button
	if start_button.text != "CONTINUE":
		failures.append("menu: active run should show CONTINUE")
	run_store.runPhase = "idle"
	start_menu._refresh_start_button()
	if start_button.text != "START RUN":
		failures.append("menu: idle state should show START RUN")
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
	dealer.queue_free()

	var machine := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(machine)
	var machine_options := machine.get_node_or_null("options") as TextureButton
	if machine_options == null:
		failures.append("options: machine scene missing options button")
	elif machine_options.position.x > 20.0:
		failures.append("options: machine options button is not top-left")
	if machine.get_node_or_null("OptionsOverlay") == null:
		failures.append("options: machine scene missing shared OptionsOverlay")
	var bottom_hud := machine.get_node_or_null("BottomHudLayer") as Control
	var neuron_number := machine.get_node_or_null("BottomHudLayer/neuron_number") as Label
	var health_label := machine.get_node_or_null("HealthLabel") as Label
	if bottom_hud == null:
		failures.append("machine: BottomHudLayer is missing")
	else:
		if bottom_hud.size != Vector2(160.0, 320.0):
			failures.append("machine: BottomHudLayer is not full-canvas")
		if bottom_hud.z_index <= 50 or bottom_hud.z_index >= 200:
			failures.append("machine: BottomHudLayer is not layered between cabinet art and options overlay")
	if neuron_number == null:
		failures.append("machine: neuron_number label is missing")
	else:
		if neuron_number.anchor_left != 0.5 or neuron_number.anchor_right != 0.5 \
				or neuron_number.anchor_top != 1.0 or neuron_number.anchor_bottom != 1.0:
			failures.append("machine: neuron_number is not anchored Center Bottom")
		if neuron_number.offset_top != -14.0 or neuron_number.offset_bottom != -4.0:
			failures.append("machine: neuron_number is not positioned at the bottom edge")
		if neuron_number.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER:
			failures.append("machine: neuron_number is not centered inside its label box")
		# Issue #38: the label is the anchor; the pixel-art meter is the readout.
		if neuron_number.text != "":
			failures.append("machine: neuron_number should render no text (meter replaces it)")
		_check_neuron_meter_absent("machine", bottom_hud, failures)
		# The -1 NEURON popup no longer fires during normal play (flatline overlay only).
		if machine.get_node_or_null("BottomHudLayer/NeuronSpendFeedback") != null:
			failures.append("machine: neuron spend feedback should not appear on the normal HUD")
	if health_label == null:
		failures.append("machine: HealthLabel spins counter is missing")
	else:
		if health_label.position != Vector2(43.0, 85.0):
			failures.append("machine: spins counter is not above the red bar")
	machine.queue_free()

	var overlay := (load("res://scenes/options_overlay.tscn") as PackedScene).instantiate()
	get_root().add_child(overlay)
	for path in ["Panel/Menu/ScoresButton", "Panel/Menu/SettingsButton", "Panel/Menu/CollectionButton", "Panel/Menu/MenuButton"]:
		if overlay.get_node_or_null(path) == null:
			failures.append("options: overlay missing %s" % path)
	overlay.queue_free()

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

	run_store.runPhase = "running"
	run_store.isSpinning = false
	run_store.dealerIncoming = false
	run_store.dealerPending = false
	run_store.lucidityCoins = 20
	run_store.runConsumables = { "item_water": 1 }
	run_store.abilitiesUsed = []
	run_store.pendingPowerRestores = []
	run_store.spinCount = 0

	if not run_store.use_consumable("item_water"):
		failures.append("water: use_consumable returned false")
	elif int(run_store.lucidityCoins) != 60:
		failures.append("water: should grant 40 lucidity coins (20 -> 60), got %d" % int(run_store.lucidityCoins))

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
	var previous_display := int(machine._display_lucidity)
	var previous_coin_prev := int(machine._coin_prev_lucidity)

	run_store.runPhase = "running"
	run_store.isSpinning = false
	run_store.dealerIncoming = false
	run_store.dealerPending = false
	run_store.lucidityCoins = 20
	run_store.runConsumables = { "item_water": 1 }
	run_store.abilitiesUsed = []
	run_store.pendingPowerRestores = []
	run_store.spinCount = 0
	machine._set_sequence_lock(false)
	machine._set_display_lucidity(20)
	machine._coin_prev_lucidity = 20

	machine._on_stash_pressed(0)
	if int(run_store.lucidityCoins) != 60:
		failures.append("machine water: should grant lucidity immediately on consume")
	if int(machine._coin_prev_lucidity) != 60:
		failures.append("machine water: immediate consume gain will replay on next spin")
	await create_timer(2.0).timeout
	if int(machine._display_lucidity) != 60:
		failures.append("machine water: HUD did not count to Water lucidity before next spin")

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

func _check_machine_consumable_feedback(machine: Node, run_store: Node, failures: Array) -> void:
	var expected := {
		"cons_tea": "RESTORE",
		"item_pill": "WIN GUARANTEED",
		"item_cocktail": "EASY",
		"item_energy_drink": "FREE",
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
	machine._set_sequence_lock(false)
	machine._power_coin_active = false

	machine._on_stash_pressed(0)
	var hint_layer := machine.get_node_or_null("BottomHudLayer/HintLayer") as Control
	var spawned: Node = null
	if hint_layer != null and hint_layer.get_child_count() > 0:
		spawned = hint_layer.get_child(hint_layer.get_child_count() - 1)
	if spawned == null or not (spawned is HintLabel):
		failures.append("machine consumable feedback: Tea did not spawn a hint")
	elif (spawned as HintLabel)._pos_label == null or (spawned as HintLabel)._pos_label.text != "+ RESTORE":
		failures.append("machine consumable feedback: Tea hint missing '+ RESTORE' line")
	if not machine._power_coin_active and run_store.pendingPowerRestores.is_empty():
		failures.append("machine consumable feedback: Tea did not start/queue power coin restore")
	await create_timer(1.0).timeout
	if spawned == null or not is_instance_valid(spawned):
		failures.append("machine consumable feedback: hint disappeared before the 1.5s hold")
	elif (spawned as HintLabel).modulate.a < 0.95:
		failures.append("machine consumable feedback: hint faded before the 1.5s hold")
	if spawned != null and is_instance_valid(spawned):
		spawned.queue_free()

	machine._set_sequence_lock(false)
	machine._power_coin_active = false
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
	if not source.contains("EXIT CASINO"):
		failures.append("machine ending flow: wealth screen should offer EXIT CASINO")
	if source.contains("BANK & LAB"):
		failures.append("machine ending flow: old bank/lab wealth transition still present")

func _check_flatline_action_text(machine: Node, meta_store: Node, failures: Array) -> void:
	var previous_neurons := int(meta_store.campaignNeuronsLeft)
	meta_store.campaignNeuronsLeft = 5
	if machine._flatline_action_text() != "CONTINUE":
		failures.append("flatline action: campaign neurons > 0 should show CONTINUE")
	meta_store.campaignNeuronsLeft = 0
	if machine._flatline_action_text() != "MENU":
		failures.append("flatline action: campaign neurons <= 0 should show MENU")
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
	if int(run_store.guaranteeSymbolSpins) != 1 or String(run_store.guaranteeSymbolId) != "vial" \
			or int(run_store.pendingBlurSpins) != 1 or int(run_store.banBrainSpins) != 0:
		failures.append("issue53: Serum did not set guarantee/blur state")
	# The guaranteed spin contains the picked symbol, then the next spin is blurry.
	run_store.neurons = 100
	var serum_spin: Variant = run_store.spin()
	run_store.set_spinning(false)
	if serum_spin == null or not (serum_spin["reels"] as Array).has("vial"):
		failures.append("issue53: Serum guaranteed spin did not contain the picked symbol")
	if int(run_store.blurReelsSpins) != 1 or int(run_store.pendingBlurSpins) != 0:
		failures.append("issue53: blur did not queue for the spin after the guarantee")
	run_store.spin()
	run_store.set_spinning(false)
	if int(run_store.blurReelsSpins) != 0:
		failures.append("issue53: blur did not clear after its spin")

	# Tobacco (issue #53): pair boost + hidden reel for 2 spins.
	run_store.runConsumables = { "cons_cigarette": 1 }
	run_store.use_consumable("cons_cigarette")
	if int(run_store.pairBoostSpins) != 2 or int(run_store.pairBoostMult) != 3 or int(run_store.pairBoostHiddenReels) != 1:
		failures.append("issue32: Tobacco did not set pair-boost counters")
	run_store.pairBoostSpins = 0 # cleared so later spins in this check score normally

	# Potion (renamed cons_potion, issue #53): restores all powers + potionSpins.
	run_store.abilitiesUsed = ["reroll", "shift"]
	run_store.runConsumables = { "cons_potion": 1 }
	run_store.use_consumable("cons_potion")
	if not run_store.abilitiesUsed.is_empty() or int(run_store.potionSpins) != 3:
		failures.append("issue32: Potion did not reset powers / set potionSpins")

	# Tea with no used abilities grants fallback free spins.
	run_store.abilitiesUsed = []
	run_store.freeSpinsRemaining = 0
	run_store.maxFreeSpins = 10
	run_store.runConsumables = { "cons_tea": 1 }
	if not run_store.use_consumable("cons_tea"):
		failures.append("issue32: Tea use rejected with no abilities")
	if int(run_store.freeSpinsRemaining) != 3:
		failures.append("issue32: Tea did not grant fallback free spins")

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

	run_store.reset_run_state()

# Issue #55: dealer scene revamp — authored 2-frame lab/machine button art, no
# text bubble, outlined feedback messages above the dealer, no 1-Lucidity
# placeholder slot.
func _check_dealer_scene_revamp_55(dealer: Node, failures: Array) -> void:
	var lab_button := dealer.get_node_or_null("LabButton") as Button
	var lab_art := dealer.get_node_or_null("LabButtonArt") as Sprite2D
	if lab_button == null or lab_art == null:
		failures.append("issue55: dealer LAB button/art pair is missing")
	else:
		if lab_button.text != "":
			failures.append("issue55: lab hit button should render no text over the art")
		if lab_art.hframes != 2:
			failures.append("issue55: lab button art is not a 2-frame sheet")
		if lab_art.position != Vector2.ZERO:
			failures.append("issue55: lab art lost its dealer-canvas-relative position")
		lab_button.button_down.emit()
		if lab_art.frame != 1:
			failures.append("issue55: lab press did not switch to the pressed frame")
		lab_button.button_up.emit()
		if lab_art.frame != 0:
			failures.append("issue55: lab release did not restore the default frame")
	var start_button := dealer.get_node_or_null("StartButton") as Button
	var machine_art := dealer.get_node_or_null("MachineButtonArt") as Sprite2D
	if start_button == null or machine_art == null:
		failures.append("issue55: dealer machine button/art pair is missing")
	else:
		if machine_art.hframes != 2:
			failures.append("issue55: machine button art is not a 2-frame sheet")
		if machine_art.position != Vector2.ZERO:
			failures.append("issue55: machine art lost its dealer-canvas-relative position")
		if start_button.position.x < 100.0:
			failures.append("issue55: machine hit button is not over the top-right art")
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

# Start menu keeps the meter, now with a numeric "left/max" count under the art.
func _check_neuron_meter_on_menu(failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var start_menu := (load("res://scenes/start_menu_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(start_menu)
	var meter := _find_neuron_meter(start_menu)
	if meter == null:
		failures.append("menu: neuron meter is missing from the start menu")
		start_menu.queue_free()
		return
	var sprite: Sprite2D = null
	for child in meter.get_children():
		if child is Sprite2D:
			sprite = child
			break
	if sprite == null:
		failures.append("menu: neuron meter built no sprite (sheet missing?)")
	else:
		if sprite.hframes != meter.frame_count:
			failures.append("menu: meter hframes do not match frame_count")
		var lost := int(meta_store.campaignNeuronsMax) - int(meta_store.campaignNeuronsLeft)
		if sprite.frame != clampi(lost, 0, meter.frame_count - 1):
			failures.append("menu: meter frame is not wired to neurons lost")
	var count := meter.get_node_or_null("CountLabel") as Label
	if count == null:
		failures.append("menu: meter is missing the numeric neuron count")
	else:
		var expected := "%d/%d" % [int(meta_store.campaignNeuronsLeft), int(meta_store.campaignNeuronsMax)]
		if count.text != expected:
			failures.append("menu: neuron count reads '%s', expected '%s'" % [count.text, expected])
		# Count updates when neurons change.
		if int(meta_store.campaignNeuronsLeft) > 0:
			meta_store.campaignNeuronsLeft -= 1
			meta_store.meta_changed.emit()
			if count.text != "%d/%d" % [int(meta_store.campaignNeuronsLeft), int(meta_store.campaignNeuronsMax)]:
				failures.append("menu: neuron count did not update on meta change")
			meta_store.campaignNeuronsLeft += 1
			meta_store.meta_changed.emit()
	# The whole menu column fits the 160x320 virtual canvas.
	var col := start_menu.get_node_or_null("MenuColumn") as VBoxContainer
	if col != null:
		await process_frame
		if col.position.y < 0.0 or col.position.y + col.size.y > 320.0:
			failures.append("menu: menu column clips the 160x320 canvas: y %s h %s" % [col.position.y, col.size.y])
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
	if int(meta_store.campaign_starting_neurons) != 10:
		failures.append("issue38: campaigns should start at 10 neurons")
	# Wealth ending fires at the (default 2000) goal; the @export override threads through.
	if Endings.check_ending({ "scoreEarned": 2000, "neurons": 5 }, {}) != "wealth":
		failures.append("issue38: 2000 score did not trigger the wealth ending")
	if Endings.check_ending({ "scoreEarned": 1999, "neurons": 5 }, {}) != null:
		failures.append("issue38: sub-goal score triggered an ending")
	if Endings.check_ending({ "scoreEarned": 2500, "neurons": 5 }, {}, 3000) != null:
		failures.append("issue38: raised campaign_goal_score was ignored")
	# Exact GDD fatal copy on the campaign-failed overlay, byte-for-byte.
	machine._show_campaign_failed()
	var overlay: Control = machine._overlay
	var found_fatal := false
	if overlay != null:
		for child in overlay.get_children():
			if child is Label and (child as Label).text == "this time, it's fatal. No coming back":
				found_fatal = true
				break
	if not found_fatal:
		failures.append("issue38: campaign-failed overlay is missing the exact fatal text")
	if overlay != null:
		overlay.queue_free()
		machine._overlay = null

func _check_odds_table_36(run_store: Node, failures: Array) -> void:
	# issue #36 (permanent rework): post-run odds-buying — per-symbol costs, staged
	# purchases undoable while open, committed permanently on finalize, 5-level cap,
	# and a screen lock until the next run.
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	meta_store.oddsUpgrades = {}
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

	# The 5-level cap holds even with tokens to spare.
	meta_store.oddsUpgrades = { "vial": 5 }
	run_store.begin_odds_phase()
	if run_store.buy_odds_upgrade("vial"):
		failures.append("issue36: bought past the 5-level cap")
	meta_store.oddsUpgrades = {}
	run_store.reset_run_state()

	# The odds overlay scene: +/- controls, level bars, close finalizes.
	var overlay_ps := load("res://scenes/odds_table_overlay.tscn") as PackedScene
	var overlay: Node = overlay_ps.instantiate()
	get_root().add_child(overlay)
	overlay.open_overlay()
	if not bool(overlay.visible):
		failures.append("issue36: overlay not visible after open_overlay")
	if int(run_store.oddsTokensRemaining) != int(run_store.odds_budget):
		failures.append("issue36: open_overlay did not begin the odds phase")
	var plus_buttons: Dictionary = overlay._plus_buttons
	var level_bars: Dictionary = overlay._level_bars
	if plus_buttons.size() != 6 or level_bars.size() != 6:
		failures.append("issue36: overlay should list all 6 reel-cycle symbols")
	elif (level_bars["vial"] as Array).size() != int(run_store.odds_max_level):
		failures.append("issue36: overlay rows should show 5 level bars")
	elif (plus_buttons["vial"] as Button).disabled:
		failures.append("issue36: affordable + button is disabled")
	overlay._on_plus_pressed("brain")
	if run_store.odds_upgrade_level("brain") != 1:
		failures.append("issue36: overlay + did not reach the store")
	var brain_bars: Array = level_bars["brain"]
	if (brain_bars[0] as ColorRect).color != overlay.bar_fill_color:
		failures.append("issue36: bought level did not fill a bar yellow")
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
	meta_store._apply(meta_before)
	meta_store.save_state()

# Flatline overlay polish: retained-percent copy only, no FINAL CREDITS line, the
# neuron meter above the continue button, and fatal copy ONLY when the campaign
# is actually out of neurons.
func _check_flatline_overlay_meter(machine: Node, failures: Array) -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	var run := { "neurons": 0, "scoreEarned": 10, "lucidityCoins": 100 }

	meta_store.campaignNeuronsLeft = 5
	meta_store.ownedPermanents = [] # base retention => "10% kept"
	run_store.runPhase = "running"
	machine._show_ending("flatline", run)
	var texts := _overlay_label_texts(machine._overlay)
	if texts.has("this time, it's fatal. No coming back"):
		failures.append("flatline: fatal copy shown with campaign neurons remaining")
	if not texts.has("FLATLINE"):
		failures.append("flatline: non-fatal overlay is missing the FLATLINE title")
	for t in texts:
		if String(t).begins_with("FINAL CREDITS"):
			failures.append("flatline: FINAL CREDITS line should be gone")
		if String(t).contains("LUCIDITY"):
			failures.append("flatline: 'lucidity' should not appear on the overlay")
	if not texts.has("10% kept"):
		failures.append("flatline: retained percent line missing ('10% kept')")
	if not texts.has("-1 NEURON"):
		failures.append("flatline: -1 NEURON popup missing from the neuron-loss screen")
	var flat_meter := _find_neuron_meter(machine._overlay)
	if flat_meter == null:
		failures.append("flatline: overlay is missing the neuron meter")
	elif flat_meter.position.y + flat_meter.size.y > 238.0:
		failures.append("flatline: neuron meter is not above the continue button")
	var tray := machine.get_node_or_null("stash") as Control
	if tray != null and tray.visible:
		failures.append("flatline: stash tray still renders over the overlay")
	machine._overlay.queue_free()
	machine._overlay = null
	machine._stop_flatline_countdown()

	# Fatal copy shows when the campaign is actually exhausted.
	meta_store.campaignNeuronsLeft = 0
	run_store.runPhase = "running"
	machine._show_ending("flatline", run)
	if not _overlay_label_texts(machine._overlay).has("this time, it's fatal. No coming back"):
		failures.append("flatline: fatal copy missing when neurons are exhausted")
	machine._overlay.queue_free()
	machine._overlay = null
	machine._stop_flatline_countdown()
	machine._set_stash_tray_visible(true)
	run_store.reset_run_state()
	meta_store._apply(meta_before)
	meta_store.save_state()

# Dedicated wealth-ending screen: CONTINUE + EXIT CASINO, no bank/lab button, and
# the wealth bar targets the 2000 campaign goal.
func _check_wealth_screen(machine: Node, run_store: Node, failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	var run := { "neurons": 5, "scoreEarned": 2000, "lucidityCoins": 300 }

	# Wealth bar readout targets the campaign goal, not the old 1000 objective.
	machine._set_display_lucidity(300)
	if machine._bar_labels.has("goal"):
		var goal_text := String((machine._bar_labels["goal"] as Label).text)
		if not goal_text.ends_with("/2000"):
			failures.append("wealth: goal bar reads '%s', expected x/2000" % goal_text)

	run_store.runPhase = "running"
	machine._show_ending("wealth", run)
	var wallet_before := int(meta_store.lucidityWallet)
	var continue_button: Button = null
	var exit_button: Button = null
	for child in machine._overlay.get_children():
		if child is Button:
			var b := child as Button
			if b.text == "CONTINUE":
				continue_button = b
			elif b.text == "EXIT CASINO":
				exit_button = b
			elif b.text == "BANK & LAB":
				failures.append("wealth: bank/lab button still on the wealth screen")
	if continue_button == null:
		failures.append("wealth: CONTINUE button missing from the wealth screen")
	if exit_button == null:
		failures.append("wealth: EXIT CASINO button missing from the wealth screen")
	if int(meta_store.lucidityWallet) != wallet_before:
		failures.append("wealth: run banked before the player chose to leave")
	# CONTINUE resumes the run under the existing wealth-continue rules.
	machine._continue_from_wealth()
	if String(run_store.runPhase) != "running" or not bool(run_store.wealthContinued):
		failures.append("wealth: CONTINUE did not resume the run (wealth-continue rules)")
	run_store.reset_run_state()
	if machine._overlay != null:
		machine._overlay.queue_free()
		machine._overlay = null
	machine._set_stash_tray_visible(true)
	meta_store._apply(meta_before)
	meta_store.save_state()

# 3x eye: the player picks a reel; the pick arms the presentation-only reveal and
# the popup names the picked reel's rolled symbol.
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
	machine._reveal_reel_next_spin = -1
	run_store.reset_run_state()

# Issue #51: TABLES overlay — no run stats, SYMBOL|LVL|PAIR|TRIPLE columns with
# bonus-effect blurbs, downscalable icons, no symbol names.
func _check_score_table_51(machine: Node, failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	meta_store.oddsUpgrades = { "eye": 2 }
	machine._set_sequence_lock(false)
	machine._close_score_table()
	machine._show_score_table()
	var overlay: Control = machine._score_overlay
	if overlay == null:
		failures.append("issue51: score table did not open")
		meta_store._apply(meta_before)
		meta_store.save_state()
		return
	if machine._score_button != null and machine._score_button.text != "TABLES":
		failures.append("issue51: score button is not renamed TABLES")
	var texts := _overlay_label_texts(overlay)
	if not texts.has("TABLES"):
		failures.append("issue51: overlay title is not TABLES")
	for stat in ["BEST", "RUNS", "CREDITS"]:
		if texts.has(stat):
			failures.append("issue51: '%s' stat should be removed from the table" % stat)
	if not texts.has("LVL"):
		failures.append("issue51: LVL column header missing")
	for symbol_name in ["BRAIN", "EYE", "PILL", "SYRINGE", "VIAL", "FLATLINE"]:
		if texts.has(symbol_name):
			failures.append("issue51: symbol names should be removed")
			break
	if not texts.has("REVEALS A REEL"):
		failures.append("issue51: triple bonus-effect blurbs missing")
	if not texts.has("2"):
		failures.append("issue51: LVL column does not show the symbol's odds level")
	for child in overlay.get_children():
		if child is TextureRect and (child as TextureRect).expand_mode != TextureRect.EXPAND_IGNORE_SIZE:
			failures.append("issue51: table icons cannot scale down (expand mode)")
			break
	machine._close_score_table()
	meta_store._apply(meta_before)
	meta_store.save_state()

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
	if not hint_layer.visible or pos_hint.text != "+ refreshing":
		failures.append("take-flow: item tap did not reveal hint text")
	if name_hint.visible:
		failures.append("take-flow: item name should no longer show in the bubble")
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

func _check_upgrades_scene(failures: Array) -> void:
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
	if eye_terminal.sprite_frames.get_frame_count(&"default") != 12:
		failures.append("upgrades: eye terminal should use the asset's 12 exact 1280px frames")
	if scene.get_child(11).name != "CanvasLayer":
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
	var eye_panel := scene.get_node("CanvasLayer/UI_Container/EyeUpgradePanel") as Control
	var memory_panel := scene.get_node("CanvasLayer/UI_Container/MemoryUpgradePanel") as Control
	for path in [
		"CanvasLayer/UI_Container/EyeUpgradePanel/perm_shift",
		"CanvasLayer/UI_Container/EyeUpgradePanel/corr_pattern_23",
		"CanvasLayer/UI_Container/EyeUpgradePanel/pos_learning",
		"CanvasLayer/UI_Container/EyeUpgradePanel/pos_enlightenment",
		"CanvasLayer/UI_Container/MemoryUpgradePanel/perm_memory",
		"CanvasLayer/UI_Container/MemoryUpgradePanel/reward_amp",
		"CanvasLayer/UI_Container/MemoryUpgradePanel/pos_smart_save",
	]:
		var row := scene.get_node(path) as Control
		var row_label := row.get_node_or_null("NameLabel") as Label
		if row_label == null:
			failures.append("upgrades: row %s is missing its on-computer name label" % path)
			break
		if row_label.visible:
			failures.append("upgrades: row %s still renders its name on the computer" % path)
			break
		if row.find_child("Icon", true, false) != null:
			failures.append("upgrades: row %s still has an artificial icon node" % path)
			break
		if row.get_node_or_null("BuyButton") != null:
			failures.append("upgrades: row %s still has a per-row buy button" % path)
			break
	if scene.get_node_or_null("CanvasLayer/UI_Container/EyeUpgradePanel/pos_enlightenment/HallucinationIcon") != null:
		failures.append("upgrades: Hallucination row still has a duplicate lucidity icon")
	var pattern_row := scene.get_node("CanvasLayer/UI_Container/EyeUpgradePanel/corr_pattern_23") as Control
	var learning_row := scene.get_node("CanvasLayer/UI_Container/EyeUpgradePanel/pos_learning") as Control
	if pattern_row.position != Vector2(0.0, 14.0) or pattern_row.size != Vector2(18.0, 9.0):
		failures.append("upgrades: Pattern Fabrication hitbox does not cover the left middle icon")
	if learning_row.position != Vector2(0.0, 23.0) or learning_row.size != Vector2(18.0, 16.0):
		failures.append("upgrades: Learning hitbox does not cover the left lower book icon")
	var memory_lock_row := scene.get_node("CanvasLayer/UI_Container/MemoryUpgradePanel/perm_memory") as Control
	var reward_amp_row := scene.get_node("CanvasLayer/UI_Container/MemoryUpgradePanel/reward_amp") as Control
	var smart_save_row := scene.get_node("CanvasLayer/UI_Container/MemoryUpgradePanel/pos_smart_save") as Control
	if memory_panel.position != Vector2(1.0, 10.0) or memory_panel.size != Vector2(35.0, 45.0):
		failures.append("upgrades: memory upgrade panel does not align to the memory terminal")
	if memory_lock_row.position != Vector2(12.0, 2.0) or memory_lock_row.size != Vector2(13.0, 13.0):
		failures.append("upgrades: Memory hitbox does not cover the top lock icon")
	if reward_amp_row.position != Vector2(12.0, 16.0) or reward_amp_row.size != Vector2(13.0, 10.0):
		failures.append("upgrades: Reward Amplification hitbox does not cover the middle reward icon")
	if smart_save_row.position != Vector2(12.0, 28.0) or smart_save_row.size != Vector2(13.0, 12.0):
		failures.append("upgrades: Smart Save hitbox does not cover the lower save icon")
	if eye_panel.visible or memory_panel.visible:
		failures.append("upgrades: purchase panels should stay hidden at runtime before terminal activation")
	if not bool(scene.get("editor_preview_eye_active")) or not bool(scene.get("editor_preview_memory_active")):
		failures.append("upgrades: editor preview flags are not enabled for WYSIWYG layout")
	var description := scene.get_node("CanvasLayer/UI_Container/DescriptionBubble") as Control
	var description_label := scene.get_node("CanvasLayer/UI_Container/DescriptionBubble/DescriptionCenter/Text") as RichTextLabel
	var power_name_box := scene.get_node("CanvasLayer/UI_Container/PowerNameBox") as Control
	var power_name_label := scene.get_node("CanvasLayer/UI_Container/PowerNameBox/NamePriceRow/PowerNameLabel") as Label
	var context_buy := scene.get_node("CanvasLayer/UI_Container/ContextBuyButton") as Button
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
	if context_buy.size != Vector2(28.0, 13.0):
		failures.append("upgrades: contextual buy button should keep its authored 28x13 size")
	var context_buy_disabled_style := context_buy.get_theme_stylebox("disabled")
	if context_buy_disabled_style != null:
		if context_buy_disabled_style.content_margin_left != 0.0 or context_buy_disabled_style.content_margin_right != 0.0:
			failures.append("upgrades: contextual buy button disabled state has asymmetric text margins")
	if context_price.visible:
		failures.append("upgrades: contextual price should be hidden before selecting a power")
	if context_price_coin.texture == null:
		failures.append("upgrades: contextual price is missing lucidity coin icon")
	var back_button := scene.get_node("CanvasLayer/UI_Container/BackButton") as Button
	var back_style := back_button.get_theme_stylebox("normal") as StyleBoxTexture
	if back_style == null or back_style.texture == null or back_style.texture.resource_path.get_file() != "red_button.png":
		failures.append("upgrades: back button is not using the red button skin")
	if back_button.z_index <= description.z_index:
		failures.append("upgrades: back button should render above description bubble")
	scene._activate_memory()
	if not scene.get_node("upgrade_scene_memory_brain_overlay").visible:
		failures.append("upgrades: memory activation did not reveal memory overlay")
	if scene.get_node("upgrades_scene_eye_brain_overlay").visible:
		failures.append("upgrades: memory activation revealed eye overlay")
	if context_buy.visible:
		failures.append("upgrades: contextual buy button appeared before selecting a memory power")
	var reward_row := scene.get_node("CanvasLayer/UI_Container/MemoryUpgradePanel/reward_amp") as Control
	var description_before_hover := description_label.text
	reward_row.mouse_entered.emit()
	if description_label.text != description_before_hover:
		failures.append("upgrades: hover changed the contextual description")
	var memory_row := scene.get_node("CanvasLayer/UI_Container/MemoryUpgradePanel/perm_memory") as Control
	scene._select_row(memory_row)
	await process_frame
	if not context_buy.visible:
		failures.append("upgrades: contextual buy button did not appear after selecting a memory power")
	if power_name_label.text != "Lock":
		failures.append("upgrades: selected power name did not move to the name box")
	if context_buy.text != "BUY" and context_buy.text != "OWNED":
		failures.append("upgrades: contextual buy button includes price text")
	if context_buy.alignment != HORIZONTAL_ALIGNMENT_CENTER or context_buy.size.x < 28.0:
		failures.append("upgrades: contextual buy button text is not centered with enough width")
	if not context_price.visible:
		failures.append("upgrades: contextual price group did not appear after selecting a memory power")
	if context_price.position.x <= power_name_label.position.x:
		failures.append("upgrades: contextual price group is not aligned to the right of the power name")
	reward_row.set_meta("upgrade_id", "corr_reward_amp_1")
	scene._select_row(reward_row)
	await process_frame
	if power_name_label.text != "Rewards+":
		failures.append("upgrades: reward amp did not show the shortened power name")
	if price_label.text != "15":
		failures.append("upgrades: reward amp tier I price is not shown in PowerNameBox")
	if not description_label.text.contains("[color=#183A8C]tier I[/color]"):
		failures.append("upgrades: reward amp tier I description is not blue BBCode")
	await scene._animate_money_to_brain()
	reward_row.set_meta("upgrade_id", "corr_reward_amp_2")
	scene._select_row(reward_row)
	if price_label.text != "25":
		failures.append("upgrades: reward amp tier II price should be 25")
	if not description_label.text.contains("[color=#FBBF24]tier II[/color]"):
		failures.append("upgrades: reward amp tier II description is not orange BBCode")
	reward_row.set_meta("upgrade_id", "corr_reward_amp_3")
	scene._select_row(reward_row)
	if price_label.text != "50":
		failures.append("upgrades: reward amp tier III price should be 50")
	if not description_label.text.contains("[color=#D62828]tier III[/color]"):
		failures.append("upgrades: reward amp tier III description is not red BBCode")
	if (scene.get_node("CanvasLayer/UI_Container/MemoryUpgradePanel/perm_memory/NameLabel") as Label).text != "Lock":
		failures.append("upgrades: memory lock label was not shortened to Lock")
	if (scene.get_node("CanvasLayer/UI_Container/MemoryUpgradePanel/reward_amp/NameLabel") as Label).text != "Rewards+":
		failures.append("upgrades: reward amplification label was not shortened to Rewards+")
	if (scene.get_node("CanvasLayer/UI_Container/MemoryUpgradePanel/pos_smart_save/NameLabel") as Label).text != "Saving":
		failures.append("upgrades: smart save label was not shortened to Saving")
	scene._select_row(smart_save_row)
	if power_name_label.text != "Saving":
		failures.append("upgrades: Smart Save did not select the save upgrade")
	if price_label.text != "30":
		failures.append("upgrades: Smart Save price should be 30")
	brain.frame = 7
	scene._sync_brain_overlay_frames()
	if memory_overlay.frame != 7:
		failures.append("upgrades: memory brain overlay is not synced to brain frame")
	scene._activate_eye()
	if memory_overlay.visible:
		failures.append("upgrades: eye activation did not hide memory overlay")
	if scene.get_node("upgrades_scene_memory_upgrades").frame != 0:
		failures.append("upgrades: eye activation did not reset memory terminal frame")
	if context_buy.visible:
		failures.append("upgrades: contextual buy button stayed visible after switching terminals")
	var eye_row := scene.get_node("CanvasLayer/UI_Container/EyeUpgradePanel/perm_shift") as Control
	scene._select_row(eye_row)
	if not context_buy.visible:
		failures.append("upgrades: contextual buy button did not appear after selecting an eye power")
	scene._select_row(pattern_row)
	if power_name_label.text != "Pattern Fabrication":
		failures.append("upgrades: Pattern Fabrication did not select the pattern upgrade")
	if price_label.text != "100":
		failures.append("upgrades: Pattern Fabrication price should be 100")
	scene._select_row(learning_row)
	if power_name_label.text != "Book Upgrade":
		failures.append("upgrades: Learning did not select the book upgrade")
	if price_label.text != "70":
		failures.append("upgrades: Learning price should be 70")
	var hallucination_row := scene.get_node("CanvasLayer/UI_Container/EyeUpgradePanel/pos_enlightenment") as Control
	scene._select_row(hallucination_row)
	await process_frame
	if power_name_label.text != "Hallucination":
		failures.append("upgrades: Hallucination did not show in the power name box")
	if price_label.text != "50":
		failures.append("upgrades: Hallucination price should be 50")
	if not description_label.text.contains("25% more Lucidity"):
		failures.append("upgrades: Hallucination description does not describe the 25% gain")
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
	if int(banked["lucidityWallet"]) != 40:
		failures.append("upgrades: Smart Save did not retain 20% of run lucidity")

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
	for button in machine._multiplier_buttons:
		if not button.disabled:
			failures.append("issue28: multiplier stayed enabled during sequence lock")
			break
	var spin_count_before := int(run_store.spinCount)
	machine._do_spin()
	if int(run_store.spinCount) != spin_count_before or run_store.isSpinning:
		failures.append("issue28: sequence lock accepted spin input")
	machine._set_sequence_lock(false)

	machine._set_display_lucidity(0)
	var coin_duration: float = machine._spawn_lucidity_coins(3, 3)
	if coin_duration <= 0.0:
		failures.append("issue28: coin sequence did not report an animation duration")
	if machine._display_lucidity != 0:
		failures.append("issue28: wealth display updated before coins reached the bar")
	await create_timer(coin_duration + 0.05).timeout
	if machine._display_lucidity != 3:
		failures.append("issue28: wealth display did not update after coin contact")

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

	# grant_free_spins adds then clamps to maxFreeSpins.
	run_store.grant_free_spins(3)
	if int(run_store.freeSpinsRemaining) != 3:
		failures.append("issue35: grant_free_spins did not add spins")
	run_store.grant_free_spins(100)
	if int(run_store.freeSpinsRemaining) != 10:
		failures.append("issue35: grant_free_spins did not clamp to maxFreeSpins")

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
	if not machine._check_flatline_instant_death():
		failures.append("issue35: fatal flatline count did not trigger instant death")
	if machine._overlay == null:
		failures.append("issue35: instant death did not show the flatline ending overlay")
	else:
		var fatal_found := false
		for child in machine._overlay.get_children():
			if child is Label and (child as Label).text == "this time, it's fatal. No coming back":
				fatal_found = true
		if not fatal_found:
			failures.append("issue38: flatline ending is missing the byte-exact fatal title")
	meta_store._apply(meta_before)
	meta_store.save_state()

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
