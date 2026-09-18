extends "res://test/checks/_base.gd"

## Scene shells, navigation and the shared options/overlay layout.
##
## Cut from scene_smoke.gd unchanged. The suite's runner owns the order and the isolation;
## this file owns nothing but the assertions. See test/checks/_base.gd for why the check
## bodies can still call get_root(), create_timer() and `await process_frame` bare.

var _scene_transition_swap_count := 0
var _scene_transition_swap_at_midpoint := false


func _on_scene_transition_swap(transition: Control) -> void:
	_scene_transition_swap_count += 1
	_scene_transition_swap_at_midpoint = transition.get("_phase") == &"transition" \
			and is_equal_approx(float(transition.get("_progress")), 0.5)
	transition.call("complete_scene_swap")


## ── checks that used to be inline in _run() ───────────────────────────────────────

## Every touched scene loads + instantiates without parse/runtime errors.
func _check_scene_instantiation(failures: Array) -> void:
	for path in [
		"res://scenes/start_menu_scene.tscn",
		"res://scenes/shop_scene.tscn",
		"res://scenes/upgrades_scene.tscn",
		"res://scenes/scores_scene.tscn",
		"res://scenes/settings_scene.tscn",
		"res://scenes/collection_scene.tscn",
		"res://scenes/options_overlay.tscn",
		"res://scenes/pacte_scene.tscn",
		"res://scenes/dealer_choice_scene.tscn",
		"res://scenes/route_scene.tscn",
		"res://scenes/route_shop_scene.tscn",
		"res://scenes/route_dealer_scene.tscn",
		"res://scenes/route_build_scene.tscn",
		"res://scenes/route_bonus_scene.tscn",
		"res://scenes/sacrifice_scene.tscn",
		"res://scenes/in_run_dealer_offer.tscn",
		"res://scenes/game_over_ending_overlay.tscn",
	]:
		var ps := load(path) as PackedScene
		if ps == null:
			failures.append("%s failed to load" % path)
			continue
		var n := ps.instantiate()
		get_root().add_child(n)
		n.queue_free()

## The Sacrifice scene is a native-canvas interaction, not a collection of
## generic rows. Exercise its preview/commit/reveal seam with two accepted
## trades and prove that the third is unavailable for this visit.
func _check_sacrifice_ritual_scene(run_store: Node, meta_store: Node,
		failures: Array) -> void:
	var run_snapshot: Dictionary = {}
	for property_name in run_store._run_state_properties():
		run_snapshot[property_name] = run_store.get(property_name)
	var meta_snapshot: Dictionary = meta_store._as_dict()
	run_store.runPhase = "over"
	run_store.routeDestination = RouteCards.ROUTE_SACRIFICE
	run_store.routeContext = "wealth_target"
	run_store.routeOfferPending = false
	run_store.sacrificeCount = 0
	run_store.sacrificesUsedThisVisit = 0
	run_store.sacrificeClaimed = false
	run_store.sacrificeSelectedId = ""
	run_store.sacrificeRewardId = ""
	run_store.nextRoundSpinBonus = 0
	run_store.lucidityCoins = 240
	run_store.selectedAugmentCardIds = ["augment_book"]
	run_store.selectedPowerCardIds = ["reroll"]
	run_store.ownedPowerIds = ["reroll"]
	meta_store.campaignNeuronsLeft = 3
	var scene := (load("res://scenes/sacrifice_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	await process_frame
	var backdrop := scene.get_node_or_null("SacrificeBackdrop") as Sprite2D
	if backdrop == null or backdrop.texture == null \
			or backdrop.texture.resource_path != "res://assets/images/sacrifice_ritual.png":
		failures.append("sacrifice: scene is not using the authored ritual backdrop")
	if backdrop != null and backdrop.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		failures.append("sacrifice: ritual backdrop is not nearest-neighbor filtered")
	if scene.get_node_or_null("SacrificeOptionsScroll") != null:
		failures.append("sacrifice: old button-list presentation is still present")
	var offerings := scene.get_node_or_null("RitualOfferings") as Control
	if offerings == null or offerings.get_child_count() != 4:
		failures.append("sacrifice: four separated offering touch targets are not rendered")
	elif (offerings.get_child(0) as Control).get_global_rect().intersects(
			(offerings.get_child(1) as Control).get_global_rect()):
		failures.append("sacrifice: offering touch targets overlap")
	var confirm := scene.get_node_or_null("ConfirmSacrificeButton") as Button
	var leave := scene.get_node_or_null("LeaveSacrificeButton") as Button
	if confirm == null or leave == null:
		failures.append("sacrifice: ritual actions are missing")
	else:
		if not confirm.disabled:
			failures.append("sacrifice: confirm action is live before an offering is selected")
		if leave.text != "LEAVE":
			failures.append("sacrifice: initial leave action has the wrong label")

	# Exercise the real signal path: RitualToken emits while its input callback is
	# still active, which previously made _refresh() free that locked token.
	offerings.get_child(0).emit_signal("chosen", SacrificeRules.OPTION_COINS)
	await process_frame
	if String(scene.get("_selected_option_id")) != SacrificeRules.OPTION_COINS \
			or confirm == null or confirm.disabled \
			or scene.get_node_or_null("BalanceOffering") == null:
		failures.append("sacrifice: selecting an offering does not create a confirmable scale preview")
	var count_before_commit := int(run_store.sacrificeCount)
	scene.call("_on_confirm_pressed")
	if int(run_store.sacrificeCount) != count_before_commit + 1 \
			or not bool(scene.get("_resolving")) \
			or not run_store.sacrificeClaimed:
		failures.append("sacrifice: confirm did not lock the committed transaction")
	scene.call("_on_confirm_pressed")
	if int(run_store.sacrificeCount) != count_before_commit + 1:
		failures.append("sacrifice: duplicate confirm changed the accepted count")
	await create_timer(1.9).timeout
	if bool(scene.get("_resolving")) or run_store.sacrificeClaimed \
			or int(run_store.sacrificesUsedThisVisit) != 1 \
			or not String(scene.get("_last_reward_label")).contains("+5"):
		failures.append("sacrifice: deterministic reward reveal did not settle after its first trade")

	var second_id := SacrificeRules.option_id_for_augment("augment_book")
	scene.call("_on_option_pressed", second_id)
	scene.call("_on_confirm_pressed")
	await create_timer(1.9).timeout
	if int(run_store.sacrificesUsedThisVisit) != SacrificeRules.MAX_USES_PER_VISIT \
			or not run_store.sacrifice_options().is_empty() \
			or confirm == null or not confirm.disabled \
			or leave == null or leave.text != "RETURN":
		failures.append("sacrifice: second trade did not close the two-offering visit")
	if is_instance_valid(scene):
		scene.free()
	for property_name in run_snapshot:
		run_store.set(String(property_name), run_snapshot[property_name])
	meta_store._apply(meta_snapshot)

func _route_seed_for_card(context: String, card_id: String, seed_start: int) -> int:
	for offset in 64:
		for card in RouteCards.offer(seed_start + offset, context):
			if String(card.get("id", "")) == card_id:
				return seed_start + offset
	return -1

func _authored_door_normal_frame(route_type: String) -> int:
	if route_type == RouteCards.ROUTE_SHOP:
		return 0
	if route_type == RouteCards.ROUTE_AUGMENT:
		return 2
	if route_type == RouteCards.ROUTE_POWER:
		return 4
	if route_type == RouteCards.ROUTE_BONUS:
		return 6
	if route_type == RouteCards.ROUTE_SACRIFICE:
		return 8
	return -1

func _check_authored_door_sprite(button: Button, route_type: String,
		expected_frame: int, failures: Array) -> void:
	var sprite := button.get_node_or_null("DoorSprite") as Sprite2D
	if sprite == null:
		failures.append("route: %s door is missing its authored hover sprite" % route_type)
		return
	if sprite.texture == null or sprite.texture.resource_path != \
			"res://assets/images/dealer_choice/doors.png":
		failures.append("route: %s door is not using the authored hover sheet" % route_type)
	if sprite.hframes != 2 or sprite.vframes != 5:
		failures.append("route: %s door has the wrong hover-sheet grid" % route_type)
	if sprite.frame != expected_frame:
		failures.append("route: %s door does not start on its normal frame" % route_type)

func _check_power_door_hover(run_store: Node, failures: Array) -> void:
	var route := (load("res://scenes/dealer_choice_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(route)
	await process_frame
	var door_colors: Dictionary = route.DOOR_COLORS
	if not (door_colors[RouteCards.ROUTE_POWER] as Color).is_equal_approx(
		route.CYAN as Color):
		failures.append("route: power door suction particles are not blue")
	if not (door_colors[RouteCards.ROUTE_AUGMENT] as Color).is_equal_approx(
		route.ROSE as Color):
		failures.append("route: augment door suction particles are not rose")
	var route_cards: Array = run_store.current_route_offer()
	var power_index := -1
	for index in mini(route_cards.size(), RouteCards.OFFER_COUNT):
		if String(route_cards[index].get("routeType", "")) == RouteCards.ROUTE_POWER:
			power_index = index
			break
	if power_index < 0:
		failures.append("route: power offer did not include its power door")
	else:
		var path := "DoorChoices/DoorLeft" if power_index == 0 else "DoorChoices/DoorRight"
		var button := route.get_node_or_null(path) as Button
		if button == null:
			failures.append("route: power door button is missing")
		else:
			_check_authored_door_sprite(button, RouteCards.ROUTE_POWER, 4, failures)
			var sprite := button.get_node_or_null("DoorSprite") as Sprite2D
			button.mouse_entered.emit()
			await process_frame
			if sprite == null or sprite.frame != 5:
				failures.append("route: power door does not switch to its hover frame")
			button.mouse_exited.emit()
			await process_frame
			if sprite == null or sprite.frame != 4:
				failures.append("route: power door does not restore its normal frame")
	route.free()

## One native scene-smoke pass through the new machine -> route -> machine seam. The
## rules-level route checks cover payment invariants; this check proves the actual route
## panels and destination scenes can be entered with a live prepared offer.
func _check_route_loop(run_store: Node, meta_store: Node, failures: Array) -> void:
	run_store.runPhase = "over"
	run_store.lastEnding = null
	run_store.roundContinuationPending = true
	run_store.routeOfferPending = false
	run_store.routeOfferCards = null
	run_store.routeDestination = ""
	run_store.routeContext = ""
	run_store.routeSelectedCardId = ""
	run_store.routeBuildKind = ""
	run_store.routeBuildOfferIds = null
	run_store.routeBuildFreeTier = false
	run_store.routeBuildSelectedId = ""
	run_store.routeBonusClaimed = false
	run_store.lucidityCoins = 100
	run_store.neurons = 11
	run_store.selectedAugmentCardIds = []
	run_store.selectedPowerCardIds = []
	run_store.runConsumables = {}
	var shop_seed := _route_seed_for_card("wealth_target", RouteCards.CARD_SHOP_ID, 0x515253)
	if shop_seed < 0 or not run_store.prepare_route_offer("wealth_target", shop_seed):
		failures.append("route: target offer did not prepare")
		return
	var route := (load("res://scenes/dealer_choice_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(route)
	await process_frame
	var route_master := route.get_node_or_null("DealerSprite") as Sprite2D
	if route_master == null or route_master.texture == null \
			or not route_master.texture.resource_path.ends_with(
				"dealer_choice_polished/choice_scene_painted.png") \
			or route_master.position != Vector2.ZERO \
			or route_master.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS \
			or not (route_master.scale * route_master.texture.get_size()).is_equal_approx(Vector2(160, 320)):
		failures.append("route: painted choice master is not the active crisp base layer")
	var route_cards: Array = run_store.current_route_offer()
	if route.get_node_or_null("ContinueButton") != null:
		failures.append("route: dealer offer still exposes the removed continue action")
	if route.get_node_or_null("RerollButton") == null:
		failures.append("route: dealer offer is missing its door reroll action")
	if route.get_node_or_null("CreditsRow") == null:
		failures.append("route: dealer offer is missing its run-gold display")
	if route.get_node_or_null("PathPrompt") != null:
		failures.append("route: path prompt still sits outside the dealer bubble")
	if route.get_node_or_null("DealerSpeechBubble") != null:
		failures.append("route: dealer offer still includes the removed speech bubble")
	var default_bubble := route.get_node_or_null("BubbleText") as Sprite2D
	var default_bubble_label := route.get_node_or_null("BubbleTextLabel") as Label
	if default_bubble == null:
		failures.append("route: dealer offer is missing the authored hover bubble")
	if default_bubble_label == null:
		failures.append("route: dealer offer is missing the hover explanation label")
	elif not default_bubble.visible or not default_bubble_label.visible \
			or default_bubble_label.text != "CHOOSE\nYOUR PATH" \
			or default_bubble_label.position != Vector2(103.0, 173.0) \
			or default_bubble_label.size != Vector2(39.0, 21.0):
		failures.append("route: dealer bubble is missing the default path prompt")
	var cards_layer := route.get_node_or_null("DoorChoices") as Control
	if cards_layer == null or cards_layer.get_child_count() != RouteCards.OFFER_COUNT:
		failures.append("route: dealer selection scene does not render exactly two doors")
	var left_door_sprite := route.get_node_or_null("DoorChoices/DoorLeft/DoorSprite") as Sprite2D
	if left_door_sprite == null or left_door_sprite.position != Vector2(1.0, 1.0) \
			or left_door_sprite.visible:
		failures.append("route: left legacy door plate is still drawing over the master")
	var right_door_sprite := route.get_node_or_null("DoorChoices/DoorRight/DoorSprite") as Sprite2D
	if right_door_sprite == null or right_door_sprite.position != Vector2(1.0, 1.0) \
			or right_door_sprite.visible:
		failures.append("route: right legacy door plate is still drawing over the master")
	var authored_hover_index := -1
	for index in mini(route_cards.size(), RouteCards.OFFER_COUNT):
		var route_type := String(route_cards[index].get("routeType", ""))
		var normal_frame := _authored_door_normal_frame(route_type)
		if normal_frame < 0:
			continue
		if authored_hover_index < 0:
			authored_hover_index = index
		var authored_button := route.get_node_or_null(
			"DoorChoices/" + ("DoorLeft" if index == 0 else "DoorRight")) as Button
		if authored_button != null:
			_check_authored_door_sprite(authored_button, route_type, normal_frame, failures)
	for door in ["DoorLeft", "DoorRight"]:
		var door_button := route.get_node_or_null("DoorChoices/" + door) as Button
		if door_button != null and not door_button.tooltip_text.is_empty():
			failures.append("route: %s still exposes a hover description" % door)
		if door_button != null and door_button.get_node_or_null("DoorCost") != null:
			failures.append("route: %s still shows a cost under the door" % door)
		var door_title: Label = null
		if door_button != null:
			door_title = door_button.get_node_or_null("DoorTitle") as Label
		var door_emblem: Control = null
		if door_button != null:
			door_emblem = door_button.get_node_or_null("RouteEmblem") as Control
		if door_emblem == null or door_emblem.position != Vector2(18.0, -1.0) \
				or door_emblem.size != Vector2(28.0, 32.0):
			failures.append("route: %s emblem is not seated in its painted door inset" % door)
		if door_title == null or door_title.position != Vector2(14.0, 34.0) \
				or door_title.size != Vector2(36.0, 10.0) \
				or door_title.get_theme_font_size("font_size") < 4:
			failures.append("route: %s title is not inside its painted name plate" % door)
		if door_title != null and door_button != null:
			var title_route_type := String(route_cards[0 if door == "DoorLeft" else 1].get(
				"routeType", ""))
			var expected_title_color := route.DOOR_COLORS.get(title_route_type,
				route.CYAN) as Color
			if door_button.disabled:
				expected_title_color = expected_title_color.darkened(0.45)
			if not door_title.get_theme_color("font_color").is_equal_approx(
					expected_title_color):
				failures.append("route: %s title does not use its door color" % door)
	var lucidity_before_free_door_check := int(run_store.lucidityCoins)
	run_store.lucidityCoins = 0
	route.call("_refresh")
	for index in RouteCards.OFFER_COUNT:
		var free_door_path := "DoorChoices/" + ("DoorLeft" if index == 0 else "DoorRight")
		var free_door := route.get_node_or_null(free_door_path) as Button
		if free_door == null or free_door.disabled:
			failures.append("route: door %d is blocked when run Lucidity is zero" % index)
	run_store.lucidityCoins = lucidity_before_free_door_check
	route.call("_refresh")
	for index in RouteCards.OFFER_COUNT:
		if route.get_node_or_null("DoorGapGlow%d" % index) != null:
			failures.append("route: door %d still has a runtime gap overlay" % index)
	if default_bubble_label != null \
			and default_bubble_label.get_theme_font_size("font_size") < 4:
		failures.append("route: dealer bubble text is still too small")
	var reroll_row := route.get_node_or_null("RerollPriceRow") as HBoxContainer
	if reroll_row == null or reroll_row.position != Vector2(7.0, 216.0) \
			or reroll_row.size != Vector2(38.0, 12.0):
		failures.append("route: reroll price row is not centered under the art")
	var reroll_price := route.get_node_or_null("RerollPriceRow/RerollPrice") as Label
	if reroll_price == null or reroll_price.text != "10":
		failures.append("route: reroll price is not shown as a bare 10")
	var reroll_coin := route.get_node_or_null("RerollPriceRow/RerollCoin") as TextureRect
	if reroll_coin == null:
		failures.append("route: reroll price is missing its Lucidity coin icon")
	elif reroll_price != null:
		var price_center_y := reroll_price.position.y + reroll_price.size.y * 0.5
		var coin_center_y := reroll_coin.position.y + reroll_coin.size.y * 0.5
		if absf(price_center_y - coin_center_y) > 0.5:
			failures.append("route: reroll number and Lucidity coin are not vertically aligned")
	if reroll_price != null and reroll_price.get_theme_font_size("font_size") < 7:
		failures.append("route: reroll number is still too small")
	var confirmation_door: Button = null
	var confirmation_index := -1
	for index in 2:
		var door_path := "DoorChoices/DoorLeft" if index == 0 else "DoorChoices/DoorRight"
		var door_button := route.get_node_or_null(door_path) as Button
		var route_type := String(route_cards[index].get("routeType", "")) \
			if index < route_cards.size() else ""
		if door_button != null and not door_button.disabled \
				and route_type == RouteCards.ROUTE_SHOP:
			confirmation_door = door_button
			confirmation_index = index
			break
	if confirmation_door == null:
		for index in 2:
			var door_path := "DoorChoices/DoorLeft" if index == 0 else "DoorChoices/DoorRight"
			var door_button := route.get_node_or_null(door_path) as Button
			if door_button != null and not door_button.disabled:
				confirmation_door = door_button
				confirmation_index = index
				break
	if confirmation_door != null:
		var hover_index := authored_hover_index if authored_hover_index >= 0 else confirmation_index
		var hover_door := confirmation_door
		if hover_index >= 0:
			hover_door = route.get_node_or_null(
				"DoorChoices/" + ("DoorLeft" if hover_index == 0 else "DoorRight")) as Button
		var hover_sprite := hover_door.get_node_or_null("DoorSprite") as Sprite2D
		var hover_position := hover_sprite.position if hover_sprite != null else Vector2.ZERO
		var hover_route_type := String(route_cards[hover_index].get("routeType", "")) \
			if hover_index >= 0 and hover_index < route_cards.size() else ""
		var hover_normal_frame := _authored_door_normal_frame(hover_route_type)
		hover_door.mouse_entered.emit()
		await process_frame
		var bubble := route.get_node_or_null("BubbleText") as Sprite2D
		var bubble_label := route.get_node_or_null("BubbleTextLabel") as Label
		if bubble == null or not bubble.visible or bubble_label == null \
				or bubble_label.text.is_empty() or not bubble_label.visible \
				or bubble_label.text == "CHOOSE\nYOUR PATH":
			failures.append("route: hovering a door does not show its dealer explanation")
		if hover_sprite == null or not is_equal_approx(hover_sprite.scale.x, 1.0) \
				or hover_sprite.position != hover_position:
			failures.append("route: hovering a door changes its art size or position")
		if hover_normal_frame >= 0 and (hover_sprite == null \
				or hover_sprite.frame != hover_normal_frame + 1):
			failures.append("route: %s door does not switch to its hover frame" % hover_route_type)
		hover_door.mouse_exited.emit()
		await process_frame
		if bubble == null or not bubble.visible or bubble_label == null \
				or not bubble_label.visible or bubble_label.text != "CHOOSE\nYOUR PATH":
			failures.append("route: leaving a door does not restore the dealer path prompt")
		if hover_sprite != null and (not is_equal_approx(hover_sprite.scale.x, 1.0) \
				or hover_sprite.position != hover_position):
			failures.append("route: leaving a door does not restore its art size or position")
		if hover_normal_frame >= 0 and (hover_sprite == null or hover_sprite.frame != hover_normal_frame):
			failures.append("route: %s door does not restore its normal frame" % hover_route_type)
		var confirmation_card: Dictionary = route_cards[confirmation_index]
		var confirmation_route_type := String(confirmation_card.get("routeType", ""))
		var confirmation_normal_frame := _authored_door_normal_frame(confirmation_route_type)
		var confirmation_sprite := confirmation_door.get_node_or_null("DoorSprite") as Sprite2D
		var confirmation_position := confirmation_sprite.position \
			if confirmation_sprite != null else Vector2.ZERO
		confirmation_door.pressed.emit()
		await process_frame
		if route.get_node_or_null("DoorConfirmation") != null:
			failures.append("route: old door confirmation modal is still present")
		if not run_store.routeOfferPending or run_store.routeDestination != "":
			failures.append("route: first door click committed the route")
		var confirmation_label := route.get_node_or_null("BubbleTextLabel") as Label
		var expected_confirmation := "TAKING THE\n%s DOOR?" % String(
			confirmation_card.get("displayName", "ROUTE"))
		if confirmation_label == null or confirmation_label.text != expected_confirmation:
			failures.append("route: opened door did not ask for confirmation")
		var suction := route.get_node_or_null("DoorSuctionParticles") as Control
		if suction == null:
			failures.append("route: opening a door did not play the gap suction effect")
		else:
			var initial_particle_count := suction.get_child_count()
			var suction_line_start: Vector2 = suction.get_meta(
				&"suction_line_start", Vector2.ZERO)
			var suction_line_end: Vector2 = suction.get_meta(
				&"suction_line_end", Vector2.ZERO)
			if absf(suction_line_end.y - suction_line_start.y) < 80.0:
				failures.append("route: door suction effect does not cover the full open-door line")
			await create_timer(0.35).timeout
			if not is_instance_valid(suction) \
					or suction.get_child_count() <= initial_particle_count:
				failures.append("route: door suction effect is not emitting continuously")
		if confirmation_door.disabled:
			failures.append("route: opened door is disabled before the confirmation click")
		if confirmation_sprite == null or confirmation_sprite.position != confirmation_position:
			failures.append("route: opening a door changed its authored position")
		if confirmation_normal_frame >= 0 and (confirmation_sprite == null \
				or confirmation_sprite.frame != confirmation_normal_frame + 1):
			failures.append("route: opened door did not keep its open frame")
		var outside_click := InputEventMouseButton.new()
		outside_click.button_index = MOUSE_BUTTON_LEFT
		outside_click.pressed = true
		outside_click.position = Vector2(80.0, 230.0)
		route.call("_input", outside_click)
		await process_frame
		if confirmation_normal_frame >= 0 and (confirmation_sprite == null \
				or confirmation_sprite.frame != confirmation_normal_frame):
			failures.append("route: outside click did not close the semi-open door")
		var outside_bubble_label := route.get_node_or_null("BubbleTextLabel") as Label
		if outside_bubble_label == null or outside_bubble_label.text != "CHOOSE\nYOUR PATH":
			failures.append("route: outside click did not restore the dealer path prompt")
		if route.get_node_or_null("DoorSuctionParticles") != null:
			failures.append("route: outside click did not clear the door suction effect")
		confirmation_door.pressed.emit()
		await process_frame
		var other_index := 1 - confirmation_index
		var other_door := route.get_node_or_null(
			"DoorChoices/" + ("DoorLeft" if other_index == 0 else "DoorRight")) as Button
		var other_card: Dictionary = route_cards[other_index] \
			if other_index < route_cards.size() else {}
		var other_route_type := String(other_card.get("routeType", ""))
		var other_normal_frame := _authored_door_normal_frame(other_route_type)
		if other_door != null and not other_door.disabled and other_normal_frame >= 0:
			var other_sprite := other_door.get_node_or_null("DoorSprite") as Sprite2D
			other_door.pressed.emit()
			await process_frame
			if confirmation_normal_frame >= 0 and (confirmation_sprite == null \
					or confirmation_sprite.frame != confirmation_normal_frame):
				failures.append("route: switching doors did not close the previous door")
			if other_sprite == null or other_sprite.frame != other_normal_frame + 1:
				failures.append("route: clicking the other door did not open it")
			confirmation_door.pressed.emit()
			await process_frame
		confirmation_door.pressed.emit()
		await process_frame
		if run_store.routeOfferPending or run_store.routeDestination != RouteCards.ROUTE_SHOP:
			failures.append("route: second door click did not enter the Shop route")
		elif not run_store.finish_route_destination() or run_store.runPhase != "running":
			failures.append("route: confirmed Shop door did not return to a live machine segment")
	if route.get_node_or_null("DealerBackground") != null:
		failures.append("route: dealer offer still includes the shop background")
	if route.get_node_or_null("DealerCounter") != null:
		failures.append("route: dealer offer still includes the shop counter")
	if route.get_node_or_null("DealerSprite") == null:
		failures.append("route: dealer offer is missing DealerSprite art")
	var destination_scene: Node = tree.current_scene
	if destination_scene != null and destination_scene != route:
		destination_scene.queue_free()
	if is_instance_valid(route):
		route.queue_free()
	await process_frame

	run_store.runPhase = "over"
	run_store.roundContinuationPending = true
	run_store.routeOfferPending = false
	run_store.routeOfferCards = null
	run_store.routeDestination = ""
	run_store.routeContext = ""
	run_store.lucidityCoins = 100
	var augment_seed := _route_seed_for_card("wealth_target", RouteCards.CARD_AUGMENT_ID, 0x535455)
	if augment_seed < 0 or not run_store.prepare_route_offer("wealth_target", augment_seed):
		failures.append("route: augment offer setup failed")
	else:
		if not run_store.select_route(RouteCards.CARD_AUGMENT_ID):
			failures.append("route: Augment card could not be selected")
		else:
			var build := (load("res://scenes/route_build_scene.tscn") as PackedScene).instantiate()
			get_root().add_child(build)
			await process_frame
			if build.get_node_or_null("RouteBuildCards") == null:
				failures.append("route: augment destination has no build-card list")
			if build.get_node_or_null("BackToRoutesButton") != null:
				failures.append("route: build destination still exposes a return to door selection")
			_check_route_build_artwork(build, "augment", failures)
			var build_ids: Array = run_store.routeBuildOfferIds as Array
			if build_ids.is_empty():
				failures.append("route: augment destination has no cards")
			else:
				var build_id := String(build_ids[0])
				var reward_symbol := "brain" if run_store.route_build_card_requires_symbol(build_id) else ""
				if not run_store.complete_route_build_selection(build_id, reward_symbol):
					failures.append("route: augment card could not be selected")
				if not run_store.finish_route_destination() or run_store.runPhase != "running":
					failures.append("route: Augment did not return to a live machine segment")
			build.free()

	# The Power route reuses the same Pacte artwork, but must swap the visible deck
	# and emplacement so the augment side never leaks into a power-only choice.
	run_store.runPhase = "over"
	run_store.roundContinuationPending = true
	run_store.routeOfferPending = false
	run_store.routeOfferCards = null
	run_store.routeDestination = ""
	run_store.routeContext = ""
	run_store.lucidityCoins = 100
	var power_seed := _route_seed_for_card("wealth_target", RouteCards.CARD_POWER_ID, 0x565758)
	if power_seed < 0 or not run_store.prepare_route_offer("wealth_target", power_seed):
		failures.append("route: power artwork offer setup failed")
	else:
		await _check_power_door_hover(run_store, failures)
		if not run_store.select_route(RouteCards.CARD_POWER_ID):
			failures.append("route: power artwork card could not be selected")
		else:
			var power_build := (load("res://scenes/route_build_scene.tscn") as PackedScene).instantiate()
			get_root().add_child(power_build)
			await process_frame
			_check_route_build_artwork(power_build, "power", failures)
			var power_ids: Array = run_store.routeBuildOfferIds as Array
			if power_ids.is_empty():
				failures.append("route: power destination has no cards")
			else:
				var power_id := String(power_ids[0])
				if not run_store.complete_route_build_selection(power_id):
					failures.append("route: power artwork card could not be selected")
				if not run_store.finish_route_destination() or run_store.runPhase != "running":
					failures.append("route: Power did not return to a live machine segment")
			power_build.free()

	# The machine segment is the destination of the refusal path. A final live state is
	# enough here; the existing machine checks cover the machine's complete HUD/interaction
	# surface and the route checks pin that refusal is free.
	if run_store.runPhase != "running":
		failures.append("route: machine segment was not live after route loop")

## The run Shop keeps its long catalog inside one native scroll region. This check
## protects the authored panel geometry and prevents future rows from spilling over
## the footer or silently losing their state styling.
func _check_route_shop_layout(run_store: Node, failures: Array) -> void:
	var prev_phase := String(run_store.runPhase)
	var prev_destination := String(run_store.routeDestination)
	var prev_gold := int(run_store.lucidityCoins)
	var prev_upgrades: Array = (run_store.runShopUpgrades as Array).duplicate()
	run_store.runPhase = "running"
	run_store.routeDestination = RouteCards.ROUTE_SHOP
	run_store.lucidityCoins = 999
	run_store.runShopUpgrades = []
	var shop := (load("res://scenes/route_shop_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(shop)
	await process_frame
	var scroll := shop.get_node_or_null("ShopScroll") as ScrollContainer
	var list := shop.get_node_or_null("ShopScroll/RunShopItems") as VBoxContainer
	if scroll == null or scroll.position != Vector2(7.0, 45.0) \
			or scroll.size != Vector2(146.0, 188.0):
		failures.append("route shop: catalog is not inside the authored scroll frame")
	if list == null:
		failures.append("route shop: catalog list is missing from its scroll frame")
	else:
		var expected_count := ShopItems.ids().size()
		if list.get_child_count() != expected_count:
			failures.append("route shop: catalog row count changed (%d/%d)" % [
				list.get_child_count(), expected_count])
		for child in list.get_children():
			var row := child as Button
			if row == null:
				continue
			if not is_equal_approx(row.custom_minimum_size.y, 32.0):
				failures.append("route shop: %s lost its compact row height" % row.name)
			if row.get_theme_stylebox("normal") == null \
					or row.get_theme_stylebox("disabled") == null:
				failures.append("route shop: %s lost its state-specific plate" % row.name)
	var return_button := shop.get_node_or_null("ReturnButton") as Button
	if return_button == null or return_button.get_theme_stylebox("normal") == null:
		failures.append("route shop: return control is missing its painted button style")
	shop.queue_free()
	run_store.runPhase = prev_phase
	run_store.routeDestination = prev_destination
	run_store.lucidityCoins = prev_gold
	run_store.runShopUpgrades = prev_upgrades

## The bonus header has a translucent plate behind it. Keep the live title and
## balance above that plate so the route never opens with unreadable dark text.
func _check_route_bonus_layout(run_store: Node, failures: Array) -> void:
	var prev_phase := String(run_store.runPhase)
	var prev_destination := String(run_store.routeDestination)
	var prev_claimed := bool(run_store.routeBonusClaimed)
	var prev_reward := String(run_store.routeBonusRewardId)
	run_store.runPhase = "running"
	run_store.routeDestination = RouteCards.ROUTE_BONUS
	run_store.routeBonusClaimed = false
	run_store.routeBonusRewardId = ""
	var bonus := (load("res://scenes/route_bonus_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(bonus)
	await process_frame
	var header := bonus.get_node_or_null("BonusHeader") as Panel
	var title := bonus.get_node_or_null("BonusTitle") as Label
	var balance := bonus.get_node_or_null("BonusBalance") as Label
	if header == null or title == null or balance == null:
		failures.append("route bonus: header labels or plate are missing")
	else:
		if title.z_index <= header.z_index or balance.z_index <= header.z_index:
			failures.append("route bonus: header plate is covering its live text")
		if not title.visible or not balance.visible:
			failures.append("route bonus: header text is hidden at idle")
	bonus.queue_free()
	run_store.runPhase = prev_phase
	run_store.routeDestination = prev_destination
	run_store.routeBonusClaimed = prev_claimed
	run_store.routeBonusRewardId = prev_reward

## The persistent Lab uses a compact native UI instead of the dealer's stocked
## counter art. Keep the catalog opaque, single-axis scrollable and separated from
## the footer so upgrades remain readable at the 160x320 target resolution.
func _check_meta_shop_layout(failures: Array) -> void:
	var shop := (load("res://scenes/shop_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(shop)
	await process_frame
	for old_name in ["Background", "Portrait", "Counter", "Readability", "stash"]:
		var old_art := shop.get_node_or_null(old_name) as CanvasItem
		if old_art != null and old_art.visible:
			failures.append("meta shop: obsolete %s art is still visible" % old_name)
	for panel_name in ["LabBackdrop", "LabHeaderPanel", "LabCatalogPanel"]:
		if shop.get_node_or_null(panel_name) == null:
			failures.append("meta shop: %s panel is missing" % panel_name)
	var scroll := shop.get_node_or_null("Root/Scroll") as ScrollContainer
	var list := shop.get_node_or_null("Root/Scroll/List") as VBoxContainer
	if scroll == null or scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		failures.append("meta shop: horizontal catalog scrolling is still enabled")
	if list == null:
		failures.append("meta shop: upgrade catalog is missing")
	else:
		for child in list.get_children():
			var row := child as Button
			if row == null:
				continue
			if not is_equal_approx(row.custom_minimum_size.y, 22.0):
				failures.append("meta shop: %s lost its compact row height" % row.name)
			if row.get_theme_stylebox("normal") == null \
					or row.get_theme_stylebox("disabled") == null:
				failures.append("meta shop: %s lost its state-specific plate" % row.name)
	var meter := shop.get_node_or_null("Root/Header/NeuronMeter") as Control
	if meter != null and meter.scale.x > 0.6:
		failures.append("meta shop: campaign meter is crowding the header")
	shop.queue_free()

## The retained Dealer route shell still needs to be legible for older saves that
## resolve into it. Keep its service list on the same dark/cyan plates as the
## current route screens and preserve the authored neon return control.
func _check_route_dealer_layout(run_store: Node, failures: Array) -> void:
	var prev_phase := String(run_store.runPhase)
	var prev_destination := String(run_store.routeDestination)
	var prev_gold := int(run_store.lucidityCoins)
	run_store.runPhase = "running"
	run_store.routeDestination = RouteCards.ROUTE_DEALER
	run_store.lucidityCoins = 999
	var dealer := (load("res://scenes/route_dealer_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(dealer)
	await process_frame
	for panel_name in ["RouteDealerHeaderPanel", "RouteDealerCatalogPanel"]:
		if dealer.get_node_or_null(panel_name) == null:
			failures.append("route dealer: %s panel is missing" % panel_name)
	var list := dealer.get_node_or_null("ServiceList") as VBoxContainer
	if list == null:
		# The list is intentionally named by the controller at runtime; keep this
		# assertion tolerant of a scene-authored wrapper if that changes later.
		list = dealer.get_node_or_null("VBoxContainer") as VBoxContainer
	if list == null:
		failures.append("route dealer: service list is missing")
	else:
		for child in list.get_children():
			var row := child as Button
			if row == null:
				continue
			if row.get_theme_stylebox("normal") == null \
					or row.get_theme_stylebox("disabled") == null:
				failures.append("route dealer: service row lost its state-specific plate")
	var return_button := dealer.get_node_or_null("ReturnButton") as Button
	if return_button == null or return_button.get_theme_stylebox("normal") == null:
		failures.append("route dealer: return control is missing its painted button style")
	dealer.queue_free()
	run_store.runPhase = prev_phase
	run_store.routeDestination = prev_destination
	run_store.lucidityCoins = prev_gold

func _check_route_build_artwork(build: Node, kind: String, failures: Array) -> void:
	for label_node in build.find_children("*", "Label", true, false):
		var label := label_node as Label
		if label != null and label.text == "ONE CARD / ONE SLOT":
			failures.append("route: %s build scene still shows the redundant one-card subtitle" % kind)
	var credits_row := build.get_node_or_null("CreditsRow") as HBoxContainer
	var credits_label := build.get_node_or_null("CreditsRow/CreditsLabel") as Label
	var credits_coin := build.get_node_or_null("CreditsRow/Coin") as TextureRect
	if credits_row == null or credits_label == null or credits_coin == null:
		failures.append("route: %s build scene is missing its Lucidity display" % kind)
	elif credits_label.get_theme_font_size("font_size") < 7:
		failures.append("route: %s build scene Lucidity number is too small" % kind)
	else:
		if not is_equal_approx(credits_row.offset_top, -14.0) \
				or not is_equal_approx(credits_row.offset_bottom, -2.0):
			failures.append("route: %s Lucidity row still covers the authored slot caption" % kind)
	var card_list := build.get_node_or_null("RouteBuildCards") as Control
	var first_card: Button = null
	if card_list != null:
		for child in card_list.get_children():
			if child is Button:
				first_card = child as Button
				break
	if first_card != null:
		var card_id := first_card.name.trim_prefix("BuildCard_")
		var cost := RunStateStore.route_build_card_cost(card_id)
		var cost_row := first_card.get_node_or_null("CardCost") as HBoxContainer
		var amount := first_card.get_node_or_null("CardCost/Amount") as Label
		var coin := first_card.get_node_or_null("CardCost/Coin") as TextureRect
		if cost_row == null or amount == null:
			failures.append("route: %s build card is missing its Lucidity cost" % kind)
		else:
			if amount.get_theme_font_size("font_size") < 7:
				failures.append("route: %s build card cost is still too small" % kind)
			if cost_row.position.y < first_card.size.y:
				failures.append("route: %s build card cost is still above the card" % kind)
			if cost > 0 and (coin == null or amount.text == "%dG" % cost):
				failures.append("route: %s build card cost is not using a Lucidity coin" % kind)
			if coin != null and not bool(coin.get_meta("skip_drag_shadow", false)):
				failures.append("route: %s card price coin still receives a drag shadow" % kind)
			if cost <= 0 and amount.text != "FREE":
				failures.append("route: %s free build card has the wrong cost label" % kind)
			var card_art := first_card.get_node_or_null("CardArt") as Control
			var card_glint := card_art.get_node_or_null("GoldGlint") as Polygon2D \
				if card_art != null else null
			if card_art == null or card_art.scale != Vector2.ONE \
					or bool(card_art.get_meta("breathing_enabled", false)) \
					or card_glint == null:
				failures.append("route: %s build cards are not static with an idle gold glint" % kind)
	var artwork := build.get_node_or_null("PacteArtwork") as Control
	if artwork == null:
		failures.append("route: %s build scene is missing Pacte artwork" % kind)
		return
	var proposition := artwork.get_node_or_null("PacteProposition") as Sprite2D
	if proposition == null:
		failures.append("route: %s build scene is missing the table proposition node" % kind)
	elif proposition.visible:
		failures.append("route: %s build scene still shows the obsolete proposition overlay" % kind)
	elif first_card != null and first_card.z_index <= proposition.z_index:
		failures.append("route: %s proposition placeholder is not beneath the cards" % kind)
	var augment_deck := artwork.get_node_or_null("AugmentDeck") as Sprite2D
	var power_deck := artwork.get_node_or_null("PowerDeck") as Sprite2D
	var augment_slot := artwork.get_node_or_null("SelectedCardEmplacement") as Sprite2D
	var power_slot := artwork.get_node_or_null("PowerCardEmplacement") as Sprite2D
	if augment_deck == null or power_deck == null or augment_slot == null or power_slot == null:
		failures.append("route: %s build scene is missing Pacte deck/emplacement art" % kind)
		return
	var show_augment := kind == "augment"
	if bool(augment_deck.visible) != show_augment or bool(augment_slot.visible):
		failures.append("route: %s build scene has the wrong augment art visibility" % kind)
	if bool(power_deck.visible) == show_augment or bool(power_slot.visible):
		failures.append("route: %s build scene has the wrong power art visibility" % kind)
	if artwork.process_mode != Node.PROCESS_MODE_DISABLED:
		failures.append("route: %s build scene left Pacte interaction processing" % kind)
	if artwork.get_node_or_null("TutorialOverlay") != null:
		failures.append("route: %s build scene attached the Pacte tutorial overlay" % kind)
	var title_light := artwork.get_node_or_null("PacteTitleLight") as Sprite2D
	if title_light == null or not title_light.region_enabled \
			or not (title_light.material is ShaderMaterial) \
			or (title_light.material as ShaderMaterial).shader == null:
		failures.append("route: %s build scene is missing the additive title flicker" % kind)

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
	# Art mode reparents the button out of MenuColumn; reach it via the scene.
	var start_button := start_menu._start_button as Button
	if start_button == null:
		failures.append("menu: start button is missing")
	elif start_button.text != "CONTINUE":
		failures.append("menu: active run should show CONTINUE")
	run_store.runPhase = "idle"
	start_menu._refresh_start_button()
	if start_button != null and start_button.text != "CLASSIC RUN":
		failures.append("menu: idle state should show CLASSIC RUN")
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
	_check_settings_icon(dealer_options, "dealer", failures)
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
	_check_start_confirm_and_lab_glow_84(dealer, failures)
	dealer.queue_free()
	# The eight checks that used to be chained on here — painting reroll, chip augments,
	# the four #132 pickers, the augment feedback map and the wealth-ending teardown — have
	# nothing to do with the options layout. They were parked on this tail because _run()
	# was a hand-written list and this was a convenient place to append. They are their own
	# table entries now, each with its own isolation instead of inheriting whatever state
	# this check happens to leave behind.

	var machine := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(machine)
	var machine_options := machine.get_node_or_null("options") as TextureButton
	if machine_options == null:
		failures.append("options: machine scene missing options button")
	elif machine_options.position.x > 20.0:
		failures.append("options: machine options button is not top-left")
	_check_settings_icon(machine_options, "machine", failures)
	var bottom_hud := machine.get_node_or_null("BottomHudLayer") as Control
	if machine.get_node_or_null("OptionsOverlay") == null:
		failures.append("options: machine scene missing shared OptionsOverlay")
	else:
		var machine_overlay := machine.get_node("OptionsOverlay") as OptionsOverlay
		if machine_overlay.z_index <= bottom_hud.z_index:
			failures.append("options: machine overlay is not above the gameplay HUD")
		if machine_overlay.mouse_filter != Control.MOUSE_FILTER_STOP:
			failures.append("options: machine overlay does not stop pointer input")
		machine_overlay.show_overlay()
		var underlying_motion := InputEventMouseMotion.new()
		underlying_motion.position = Vector2(105.0, 228.0)
		machine._input(underlying_motion)
		if bool(machine._swap_drag_active) or bool(machine._dealer_drag_active):
			failures.append("options: machine input leaked through the visible modal")
		machine_overlay.hide_overlay()
	var spin_number := machine.get_node_or_null("BottomHudLayer/spin_number") as Label
	var machine_credits_row := machine.get_node_or_null(
		"BottomHudLayer/CreditsRow") as HBoxContainer
	var machine_credits_label := machine.get_node_or_null(
		"BottomHudLayer/CreditsRow/CreditsLabel") as Label
	var machine_credits_coin := machine.get_node_or_null(
		"BottomHudLayer/CreditsRow/Coin") as TextureRect
	var health_bar := machine.get_node_or_null("HealthBar") as Sprite2D
	var health_coin := machine.get_node_or_null("HealthCoin") as Sprite2D
	if bottom_hud == null:
		failures.append("machine: BottomHudLayer is missing")
	else:
		if bottom_hud.size != Vector2(160.0, 320.0):
			failures.append("machine: BottomHudLayer is not full-canvas")
		if bottom_hud.z_index <= 50 or bottom_hud.z_index >= 200:
			failures.append("machine: BottomHudLayer is not layered between cabinet art and options overlay")
	if spin_number == null:
		failures.append("machine: spin_number label is missing")
	else:
		if spin_number.anchor_left != 0.5 or spin_number.anchor_right != 0.5 \
				or spin_number.anchor_top != 1.0 or spin_number.anchor_bottom != 1.0:
			failures.append("machine: spin_number is not anchored Center Bottom")
		if spin_number.offset_top != -14.0 or spin_number.offset_bottom != -4.0:
			failures.append("machine: spin_number is not positioned at the bottom edge")
		if spin_number.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER:
			failures.append("machine: spin_number is not centered inside its label box")
		# Issue #38: the label is the anchor; the pixel-art meter is the readout.
		if spin_number.text != "":
			failures.append("machine: spin_number should render no text (tube readout replaces it)")
		_check_neuron_meter_absent("machine", bottom_hud, failures)
		# The -1 NEURON popup no longer fires during normal play (flatline overlay only).
		if machine.get_node_or_null("BottomHudLayer/NeuronSpendFeedback") != null:
			failures.append("machine: neuron spend feedback should not appear on the normal HUD")
	if machine_credits_row == null or machine_credits_label == null \
			or machine_credits_coin == null:
		failures.append("machine: bottom-left Lucidity display is missing its label or coin")
	elif machine_credits_label.get_theme_font_size("font_size") < 7:
		failures.append("machine: Lucidity number is too small")
	# The shelf number is the only remaining-spin readout.
	if machine.get_node_or_null("HealthLabel") != null:
		failures.append("machine: HealthLabel spins counter should be removed from the TV")
	if health_bar != null:
		failures.append("machine: redundant side spin tube is still active")
	if health_coin != null:
		failures.append("machine: retired HealthCoin drop sheet is still active")
	machine.queue_free()

	var overlay := (load("res://scenes/options_overlay.tscn") as PackedScene).instantiate()
	get_root().add_child(overlay)
	await process_frame
	if overlay.z_index < 1000 or overlay.mouse_filter != Control.MOUSE_FILTER_STOP:
		failures.append("options: overlay is not a topmost full-canvas modal")
	var dim := overlay.get_node_or_null("Dim") as ColorRect
	if dim == null or dim.mouse_filter != Control.MOUSE_FILTER_STOP:
		failures.append("options: modal dimmer does not capture outside-panel input")
	var options_panel := overlay.get_node_or_null("Panel") as PanelContainer
	var options_contour := overlay.get_node_or_null("Contour") as TextureRect
	if options_contour == null or options_contour.texture == null:
		failures.append("options: overlay missing painted frame")
	elif options_contour.size != Vector2(144, 252) \
			or options_contour.texture.get_width() <= 144 \
			or options_contour.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
		failures.append("options: detailed frame must preserve the 144x252 layout footprint")
	var panel_style := options_panel.get_theme_stylebox("panel") as StyleBoxEmpty \
		if options_panel != null else null
	if panel_style == null:
		failures.append("options: panel obscures the painted glass")
	# Issue #105: replaying the tutorial is an ACTION, so it belongs on this menu rather
	# than buried in the audio settings screen behind it.
	for path in ["Panel/Menu/ScoresButton", "Panel/Menu/SettingsButton", "Panel/Menu/CollectionButton", "Panel/Menu/TutorialButton", "Panel/Menu/MenuButton"]:
		var option_button := overlay.get_node_or_null(path) as Button
		if option_button == null:
			failures.append("options: overlay missing %s" % path)
		else:
			if option_button.mouse_filter != Control.MOUSE_FILTER_STOP:
				failures.append("options: %s does not stop modal input" % path)
			var button_style := option_button.get_theme_stylebox("normal") as StyleBoxTexture
			if button_style == null or button_style.texture == null:
				failures.append("options: %s is not using start-menu button art" % path)
	var close_button := overlay.get_node_or_null("CloseButton") as Button
	if close_button == null or close_button.icon == null:
		failures.append("options: overlay close button is missing its painted X")
	elif close_button.mouse_filter != Control.MOUSE_FILTER_STOP:
		failures.append("options: close button does not stop modal input")
	elif options_panel != null and close_button.position.y >= options_panel.position.y + 16.0:
		failures.append("options: close button is not in the panel's top-right corner")
	# All live menu rows must remain inside the painted frame.
	var options_contour_rect := Rect2(options_contour.position, options_contour.size) \
		if options_contour != null else Rect2()
	if options_panel != null and not options_contour_rect.encloses(
			Rect2(options_panel.position, options_panel.size)):
		failures.append("options: the painted frame no longer contains the panel")
	var options_rows := overlay.get_node("Panel/Menu") as Control
	if options_panel != null \
			and options_panel.size.y < options_rows.get_combined_minimum_size().y:
		failures.append("options: the panel is too short for its own rows")
	if options_panel != null and options_panel.mouse_filter != Control.MOUSE_FILTER_STOP:
		failures.append("options: panel does not stop modal input")
	overlay.queue_free()

	var settings := (load("res://scenes/settings_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(settings)
	_check_settings_neon(settings, failures)
	if settings.find_child("TutorialButton", true, false) != null:
		failures.append("settings: the tutorial button moved to the OPTIONS overlay")
	settings.queue_free()


func _check_machine_lucidity_display(machine: Node, run_store: Node,
		failures: Array) -> void:
	var credits_label := machine.get_node_or_null(
		"BottomHudLayer/CreditsRow/CreditsLabel") as Label
	if credits_label == null:
		failures.append("machine: Lucidity display regression check is missing its label")
		return
	var previous_phase := String(run_store.runPhase)
	var previous_lucidity := int(run_store.lucidityCoins)
	var previous_score := int(run_store.scoreEarned)
	var previous_before := int(machine._machine_scene_lucidity_before)
	var previous_score_before := int(machine._machine_scene_score_before)
	var previous_ready := bool(machine._machine_scene_lucidity_snapshot_ready)
	run_store.runPhase = "running"
	run_store.lucidityCoins = 40
	run_store.scoreEarned = 9000
	machine._begin_machine_lucidity_segment()
	if credits_label.text != "40":
		failures.append("machine: Lucidity display did not use the segment's previous balance")
	run_store.lucidityCoins = 73 # net machine Lucidity after gains and deductions
	machine._update_hud()
	if credits_label.text != "40":
		failures.append("machine: Lucidity display updated during the machine segment")
	if int(machine._machine_lucidity_after_deductions()) != 73:
		failures.append("machine: end-of-scene Lucidity used the full score instead of net Lucidity")
	# The segment handoff removes the score-derived balance before applying the
	# settled remainder. This is the 100 - 83 = 17 case with a carried wallet of 42.
	run_store.lucidityCoins = 42
	run_store.scoreEarned = 0
	machine._begin_machine_lucidity_segment()
	run_store.scoreEarned = 100
	run_store.lucidityCoins = 142
	var settled: int = machine._settle_machine_lucidity_after_deductions(
		{"banked": 17}, 100)
	if settled != 59 or int(run_store.lucidityCoins) != 59:
		failures.append("machine: Run Wallet did not receive only the post-deduction remainder")
	if credits_label.text != "59":
		failures.append("machine: Run Wallet did not update at segment handoff")
	run_store.runPhase = previous_phase
	run_store.lucidityCoins = previous_lucidity
	run_store.scoreEarned = previous_score
	machine._machine_scene_lucidity_before = previous_before
	machine._machine_scene_score_before = previous_score_before
	machine._machine_scene_lucidity_snapshot_ready = previous_ready


func _check_scene_nav(failures: Array) -> void:
	var nav: Node = get_root().get_node("SceneNav")
	nav.clear()
	var root_view := get_root()
	if root_view.content_scale_mode != Window.CONTENT_SCALE_MODE_CANVAS_ITEMS \
			or root_view.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_EXPAND \
			or root_view.content_scale_stretch != Window.CONTENT_SCALE_STRETCH_FRACTIONAL \
			or root_view.content_scale_size != Vector2i(160, 320):
		failures.append("scene nav: display-resolution rendering and fractional overscan are not enabled")
	nav.call("_configure_content_scale", "res://scenes/pacte_scene.tscn")
	if root_view.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_EXPAND:
		failures.append("scene nav: Pacte did not opt into the expanded artwork viewport")
	nav.call("_configure_content_scale", "res://scenes/route_build_scene.tscn")
	if root_view.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_EXPAND:
		failures.append("scene nav: Augment/Power build did not opt into the expanded artwork viewport")
	nav.call("_configure_content_scale", "res://scenes/dealer_scene.tscn")
	if root_view.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_EXPAND:
		failures.append("scene nav: dealer shop did not opt into the expanded artwork viewport")
	nav.call("_configure_content_scale", "res://scenes/machine_scene.tscn")
	if root_view.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_EXPAND:
		failures.append("scene nav: machine scene lost its decorative overscan")
	var transition_overlay := nav.call("transition_overlay") as Control
	if transition_overlay == null:
		failures.append("scene nav: global transition overlay is missing")
	else:
		var transition_layer := transition_overlay.get_parent() as CanvasLayer
		if transition_layer == null or transition_layer.layer < 1000:
			failures.append("scene nav: transition cover is not on the top CanvasLayer")
		if transition_overlay.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			failures.append("scene nav: inactive transition cover still captures input")
		if transition_overlay.size != Vector2(160.0, 320.0):
			failures.append("scene nav: transition cover is not native-canvas sized")
		var viewport_size: Vector2 = nav.get_viewport().get_visible_rect().size
		var expected_overlay_position := Vector2(
			maxf(0.0, (viewport_size.x - 160.0) * 0.5),
			maxf(0.0, (viewport_size.y - 320.0) * 0.5))
		if transition_overlay.position != expected_overlay_position:
			failures.append("scene nav: transition cover is not centred in the expanded viewport")
	var nav_source := FileAccess.open("res://autoload/scene_nav.gd", FileAccess.READ)
	if nav_source == null:
		failures.append("scene nav: centralized transition source is unreadable")
	else:
		var source := nav_source.get_as_text()
		if not source.contains("await _load_scene(scene_path)"):
			failures.append("scene nav: destination is not loaded under the transition cover")
		if not source.contains("PROCESS_MODE_DISABLED"):
			failures.append("scene nav: source scene is not suspended during loading")
		if not source.contains("play_transition") \
				or not source.contains("scene_swap_requested") \
				or not source.contains("complete_scene_swap"):
			failures.append("scene nav: scene changes are not owned by one transition lifecycle")
		if source.contains("await _transition_overlay.play_exit") \
				or source.contains("await _play_entrance"):
			failures.append("scene nav: transition still runs separate exit and entrance calls")
	nav.push_scene("res://scenes/dealer_scene.tscn", true)
	if nav.peek_back_scene() != "res://scenes/dealer_scene.tscn":
		failures.append("scene nav: did not retain dealer as return scene")
	if not nav.peek_back_restores_options():
		failures.append("scene nav: did not retain options restore flag")
	nav.clear()
	var transition_script: Script = load("res://autoload/scene_transition.gd")
	var transition := transition_script.new() as Control
	get_root().add_child(transition)
	_scene_transition_swap_count = 0
	_scene_transition_swap_at_midpoint = false
	var swap_callback := Callable(self, "_on_scene_transition_swap").bind(transition)
	transition.scene_swap_requested.connect(swap_callback)
	await transition.play_transition(0)
	if _scene_transition_swap_count != 1:
		failures.append("scene nav: unified transition did not request exactly one scene swap")
	if not _scene_transition_swap_at_midpoint:
		failures.append("scene nav: unified transition did not swap at its covered midpoint")
	if transition.get("_phase") != &"hidden" or transition.visible:
		failures.append("scene nav: unified transition did not finish in its hidden state")
	transition.scene_swap_requested.disconnect(swap_callback)
	await transition.play_exit(0)
	var exit_progress := float(transition.get("_progress"))
	transition.play_exit(0)
	if transition.get("_phase") != &"covered" or not is_equal_approx(
		exit_progress, float(transition.get("_progress"))):
		failures.append("scene nav: repeated exit request restarted the transition")
	await transition.play_entrance()
	transition.play_entrance()
	if transition.get("_phase") != &"hidden":
		failures.append("scene nav: repeated entrance request restarted the transition")
	transition.play_exit(SceneNav.TransitionKind.WALLET, -1, 42, 59)
	var wallet_handoff := transition.get_node_or_null("WalletHandoff") as HBoxContainer
	if transition.get("_phase") != &"covered" or not transition.visible \
			or wallet_handoff == null or not wallet_handoff.visible:
		failures.append("scene nav: wallet handoff did not hold a black cover and wallet row")
	transition.begin_wallet_transfer(42, 59)
	await transition.play_entrance()
	if not transition.visible or transition.mouse_filter != Control.MOUSE_FILTER_STOP:
		failures.append("scene nav: wallet row did not survive the scene reveal")
	await transition.wait_for_wallet_transfer()
	var wallet_handoff_label := transition.get_node_or_null(
		"WalletHandoff/WalletValue") as Label
	if wallet_handoff_label == null or wallet_handoff_label.text != "59":
		failures.append("scene nav: wallet handoff did not reach the settled balance")
	transition.finish_wallet_handoff()
	if transition.visible:
		failures.append("scene nav: wallet handoff did not clear after settlement")
	transition.free()


func _check_issue232_wallet_transfer(run_store: Node, failures: Array) -> void:
	var ps := load("res://scenes/target_reached_overlay.tscn") as PackedScene
	if ps == null:
		failures.append("issue232: target overlay failed to load")
		return
	var overlay := ps.instantiate() as TargetReachedOverlay
	get_root().add_child(overlay)
	await process_frame
	run_store.lucidityCoins = 42
	overlay.present(100, 50, null, "CONTINUE", false, 42)
	var wallet_row := overlay.get_node_or_null("RunWalletDuringDeduction") as HBoxContainer
	var wallet_label := overlay.get_node_or_null(
		"RunWalletDuringDeduction/WalletValue") as Label
	var wallet_coin := overlay.get_node_or_null(
		"RunWalletDuringDeduction/WalletCoin") as TextureRect
	if wallet_row == null or wallet_row.z_index < 50:
		failures.append("issue232: Run Wallet is not on the deduction presentation layer")
	if wallet_label == null or wallet_label.text != "42":
		failures.append("issue232: Run Wallet changed during deductions")
	if wallet_label != null and wallet_coin != null:
		await process_frame
		var wallet_gap := wallet_coin.position.x \
			- (wallet_label.position.x + wallet_label.size.x)
		if wallet_gap > 3.0:
			failures.append("issue232: Run Wallet coin is detached from its value")
	if not overlay.continue_button.disabled:
		failures.append("issue232: CONTINUE was available before deductions finished")
	overlay.call("_skip_to_end")
	if overlay.continue_button.disabled:
		failures.append("issue232: CONTINUE did not unlock after deductions")
	await overlay.animate_wallet_transfer(42, 59)
	if wallet_label == null or wallet_label.text != "59":
		failures.append("issue232: Run Wallet did not animate to the final retained value")
	if run_store.lucidityCoins != 42:
		failures.append("issue232: presentation animation mutated logical wallet state")
	overlay.free()


func _check_machine_ending_flow_source(failures: Array) -> void:
	var file := FileAccess.open("res://scenes/machine_scene.gd", FileAccess.READ)
	if file == null:
		failures.append("machine ending flow: could not read machine_scene.gd")
		return
	var source := file.get_as_text()
	if not source.contains("_start_again_from_wealth"):
		failures.append("machine ending flow: wealth screen is missing Start Again handling")
	if not source.contains("continue_pressed.connect(_continue_from_wealth)"):
		failures.append("machine ending flow: wealth screen is missing CONTINUE handling")
	if not source.contains("_can_resume_after_wealth()"):
		failures.append("machine ending flow: wealth screen is missing continuation gating")
	if not source.contains("GAME_OVER_ENDING_SCENE"):
		failures.append("machine ending flow: dedicated game-over scene is missing")
	if not source.contains("SceneNav.TransitionKind.WALLET"):
		failures.append("machine ending flow: target route does not use wallet handoff")
	if source.contains("await _wealth_target_transition.animate_wallet_transfer"):
		failures.append("machine ending flow: wallet still settles before the route transition")
	if source.contains("EXIT CASINO"):
		failures.append("machine ending flow: old EXIT CASINO wealth action still present")
	if source.contains("BANK & LAB"):
		failures.append("machine ending flow: old bank/lab wealth transition still present")


func _check_issue27_overlay_layout(failures: Array) -> void:
	var ps := load("res://scenes/in_run_dealer_offer.tscn") as PackedScene
	if ps == null:
		failures.append("issue27: in-run dealer overlay failed to load")
		return
	var overlay := ps.instantiate()
	get_root().add_child(overlay)

	var offer_icon: TextureRect = overlay._make_item_icon_on(overlay, "item_water", "offer", Vector2.ZERO, 16.0)
	if not offer_icon.size.is_equal_approx(Vector2(16.0, 16.0)):
		failures.append("live dealer: high-resolution item exceeds its 16x16 offer bounds")
	offer_icon.queue_free()

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
	# Inside the bubble, not pinned to its corner: the label sits on the white BODY the art
	# draws (InRunDealerOffer.BUBBLE_BODY_RECT), which starts a couple of px in and stops
	# above the tail, so the line lands in the middle of the box rather than above it.
	if not Rect2(Vector2.ZERO, bubble.size).encloses(Rect2(speech.position, speech.size)):
		failures.append("issue27: speech text not inside bubble")
	var speech_center := speech.position + speech.size * 0.5
	# Read off the instance, not off the class: naming InRunDealerOffer here would pull that
	# @tool script into this one's compilation, before the autoloads it uses exist.
	var body_rect: Rect2 = overlay.BUBBLE_BODY_RECT
	var body_center := body_rect.get_center()
	if absf(speech_center.x - body_center.x) > 1.0 or absf(speech_center.y - body_center.y) > 1.5:
		failures.append("issue27: speech text is not centred on the bubble body")

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


# The neuron meter left the menu: CONTINUE opens the run-state modal, which
# carries it plus the resume/abandon choice (issue #111 follow-up).
func _check_neuron_meter_on_menu(failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var run_store: Node = get_root().get_node("RunStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	meta_store.is_first_launch = false
	var start_menu := (load("res://scenes/start_menu_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(start_menu)
	await process_frame
	if _find_neuron_meter(start_menu) != null:
		failures.append("menu: the neuron meter should not render on the start menu")

	var prev_phase := String(run_store.runPhase)
	run_store.runPhase = "pre_run"
	start_menu._refresh_start_button()
	if start_menu._start_button == null or (start_menu._start_button as Button).text != "CONTINUE":
		failures.append("menu: pre-run dealer return should show CONTINUE")
	run_store.runPhase = "running"
	run_store.campaignNeuronPending = true
	run_store.lucidityCoins = 200
	run_store.scoreEarned = 40
	meta_store.ownedPermanents = []
	meta_store.lucidityWallet = 0
	meta_store.campaignNeuronsLeft = int(meta_store.campaignNeuronsMax)
	start_menu._show_continue_modal()
	await process_frame
	var meter := _find_neuron_meter(start_menu)
	if meter == null:
		failures.append("menu: CONTINUE modal is missing the neuron meter")
	else:
		var sprite: Sprite2D = null
		for child in meter.get_children():
			if child is Sprite2D:
				sprite = child
				break
		if sprite == null:
			failures.append("menu: modal meter built no sprite (sheet missing?)")
		else:
			if sprite.hframes != meter.frame_count:
				failures.append("menu: meter hframes do not match frame_count")
			if meter.frame_count != 34 or sprite.frame < 0 or sprite.frame >= meter.frame_count:
				failures.append("menu: meter is not using the 34-frame idle neuron animation")
		var death_sprites: Array[Sprite2D] = [
			meter.get_node_or_null("Death") as Sprite2D,
			meter.get_node_or_null("Death2") as Sprite2D,
			meter.get_node_or_null("Death3") as Sprite2D,
		]
		for index: int in range(death_sprites.size()):
			var death_sprite := death_sprites[index]
			if death_sprite == null or death_sprite.hframes != 3 or death_sprite.visible:
				failures.append("menu: meter is missing its hidden three-frame death overlay %d" % (index + 1))
		# Each loss finishes on frame 3 and remains as a permanent overlay. Later
		# losses must not clear the earlier damage (issue #176 feedback).
		var health_before_animation := int(meta_store.campaignNeuronsLeft)
		for remaining: int in [2, 1, 0]:
			meta_store.campaignNeuronsLeft = remaining
			meter.play_loss_animation()
			await create_timer(NeuronMeter.LOSS_ANIM_DELAY + 0.65).timeout
			var lost_count := int(meta_store.campaignNeuronsMax) - remaining
			for index: int in range(death_sprites.size()):
				var death_sprite := death_sprites[index]
				var expected_visible := index < lost_count
				if death_sprite == null or death_sprite.visible != expected_visible:
					failures.append("menu: neuron death overlay %d did not persist" % (index + 1))
				elif expected_visible and death_sprite.frame != NeuronMeter.DEATH_FRAME_COUNT - 1:
					failures.append("menu: neuron death overlay %d did not stop on frame 3" % (index + 1))
		meta_store.campaignNeuronsLeft = health_before_animation
		meter.refresh()
		var count := meter.get_node_or_null("CountLabel") as Label
		if count == null:
			failures.append("menu: modal meter is missing the numeric neuron count")
		elif count.text != "%d/%d" % [int(meta_store.campaignNeuronsLeft), int(meta_store.campaignNeuronsMax)]:
			failures.append("menu: modal neuron count reads '%s'" % count.text)
	var stats := start_menu.get_node_or_null("ContinueModal/Panel/Stats") as Label
	if stats == null or stats.text != "CURRENT COINS : 200":
		failures.append("menu: CONTINUE modal should show current coins only")
	if stats != null and (stats.text.contains("SCORE") or stats.text.contains("LUCIDITY") \
			or stats.text.contains("L-COIN")):
		failures.append("menu: CONTINUE modal still shows the old score/coin label")
	# A dealer/pre-run session shows the same banked wallet that the dealer spends.
	var wallet_before_preview := int(meta_store.lucidityWallet)
	start_menu._hide_continue_modal()
	await process_frame
	run_store.runPhase = "pre_run"
	run_store.lucidityCoins = 222
	meta_store.lucidityWallet = 321
	start_menu._show_continue_modal()
	var pre_run_stats := start_menu.get_node_or_null("ContinueModal/Panel/Stats") as Label
	if pre_run_stats == null or pre_run_stats.text != "CURRENT COINS : 321":
		failures.append("menu: CONTINUE modal should show the dealer wallet")
	start_menu._hide_continue_modal()
	await process_frame
	run_store.runPhase = "running"
	meta_store.lucidityWallet = wallet_before_preview
	start_menu._show_continue_modal()
	await process_frame
	var panel := start_menu.get_node_or_null("ContinueModal/Panel") as Panel
	var close := start_menu.get_node_or_null("ContinueModal/Panel/CloseButton") as Button
	if close == null:
		failures.append("menu: CONTINUE modal has no close button")
	elif panel != null and (close.position.x + close.size.x > panel.size.x \
			or close.position.y >= 16.0):
		failures.append("menu: CONTINUE modal close button is not in the top-right corner")
	var resume := start_menu.get_node_or_null("ContinueModal/Panel/ContinueButton") as Button
	if stats != null and stats.position.y < 86.0:
		failures.append("menu: current-coins label is too high under the neuron number")
	if stats != null and resume != null \
			and stats.position.y + stats.size.y + 6.0 > resume.position.y:
		failures.append("menu: current-coins label is too close to CONTINUE")
	if close != null:
		close.pressed.emit()
		if start_menu._continue_modal != null or String(run_store.runPhase) != "running":
			failures.append("menu: modal close did not dismiss without losing the run")
	start_menu._show_continue_modal()
	var give_up := start_menu.get_node_or_null("ContinueModal/Panel/GiveUpButton") as Button
	resume = start_menu.get_node_or_null("ContinueModal/Panel/ContinueButton") as Button
	if resume == null:
		failures.append("menu: CONTINUE modal has no resume button")
	if give_up == null:
		failures.append("menu: CONTINUE modal has no GIVE UP button")
	else:
		# Abandoning resets the run outright: nothing banks, the menu frees up.
		give_up.pressed.emit()
		if String(run_store.runPhase) == "running":
			failures.append("menu: GIVE UP did not end the held run")
		if int(run_store.scoreEarned) != 0 or int(run_store.lucidityCoins) != 0:
			failures.append("menu: GIVE UP did not reset the run state")
		if int(meta_store.campaignNeuronsLeft) != int(meta_store.campaignNeuronsMax):
			failures.append("menu: GIVE UP did not restore the campaign neuron count")
		if int(meta_store.lucidityWallet) != 0:
			failures.append("menu: GIVE UP banked lucidity; abandoning should bank nothing")
		# queue_free is deferred; the scene's reference clears immediately.
		if start_menu._continue_modal != null:
			failures.append("menu: GIVE UP left the run-state modal open")
	run_store.runPhase = "over"
	start_menu._refresh_start_button()
	if start_menu._start_button != null and (start_menu._start_button as Button).text == "CONTINUE":
		failures.append("menu: finished flatline state incorrectly shows CONTINUE")
	run_store.reset_run_state()
	run_store.runPhase = prev_phase
	meta_store._apply(meta_before)
	meta_store.save_state()
	start_menu.queue_free()

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
			var machine_shelf: bool = scene_path == "res://scenes/machine_scene.tscn"
			var expected_stash := Rect2(100, 211, 36, 24) if machine_shelf else Rect2(106, 290, 48, 26)
			if stash.get_rect() != expected_stash:
				failures.append("parity: %s stash tray does not match its authored layout: %s %s" % [scene_path, stash.position, stash.size])
			if stash.z_index < 50:
				failures.append("parity: %s stash tray can draw behind base art" % scene_path)
			for i in range(1, 3):
				var slot := stash.get_node_or_null("StashSlot%d" % i) as Control
				var expected_slot := Vector2(16, 18) if machine_shelf else Vector2(16, 16)
				if slot == null:
					failures.append("parity: %s missing StashSlot%d" % [scene_path, i])
				elif slot.size != expected_slot:
					failures.append("parity: %s StashSlot%d has wrong touch size: %s, expected %s" % [scene_path, i, slot.size, expected_slot])
		scene.queue_free()


func _check_upgrades_scene(failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	# This check mutates ownedPermanents (reward-amp tiers); snapshot the
	# current meta state so later checks see whatever they started with.
	var saved_permanents: Array = meta_store.ownedPermanents.duplicate()
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
		"upgrades_scene_eye_buttons",
		"upgrades_scene_memory_buttons",
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
	if eye_terminal.sprite_frames.get_frame_count(&"default") != 13:
		failures.append("upgrades: eye terminal should use the asset's 13 exact 1280px frames")
	var memory_terminal := scene.get_node("upgrades_scene_memory_upgrades") as AnimatedSprite2D
	if memory_terminal.sprite_frames.get_frame_count(&"default") != 11:
		failures.append("upgrades: memory terminal should use the asset's 11 exact 1280px frames")
	if scene.get_child(13).name != "CanvasLayer":
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
	# Regression check: a later, stop-filtered sibling sitting on top of a
	# hitbox's center silently eats the click even though the hitbox itself
	# is wired up correctly (this is exactly how the empty MemoryUpgradePanel
	# used to swallow every click to MemoryComputerHitbox after its rows were
	# removed). Assert nothing else claims mouse input at either hitbox's center.
	for hitbox in [eye_hitbox, memory_hitbox]:
		var center: Vector2 = hitbox.position + hitbox.size / 2.0
		var seen_hitbox := false
		for sibling in ui_container.get_children():
			if sibling == hitbox:
				seen_hitbox = true
				continue
			if not seen_hitbox or not (sibling is Control):
				continue
			var sib := sibling as Control
			if sib.visible and sib.mouse_filter == Control.MOUSE_FILTER_STOP and sib.get_rect().has_point(center):
				failures.append("upgrades: %s sits on top of %s's center and would swallow its click" % [sib.name, hitbox.name])
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
	var eye_prev := scene.get_node("CanvasLayer/UI_Container/EyePrevButton") as Button
	var eye_next := scene.get_node("CanvasLayer/UI_Container/EyeNextButton") as Button
	var memory_prev := scene.get_node("CanvasLayer/UI_Container/MemoryPrevButton") as Button
	var memory_next := scene.get_node("CanvasLayer/UI_Container/MemoryNextButton") as Button
	if eye_prev.visible or eye_next.visible or memory_prev.visible or memory_next.visible:
		failures.append("upgrades: nav buttons should stay hidden before terminal activation")
	if not bool(scene.get("editor_preview_eye_active")) or not bool(scene.get("editor_preview_memory_active")):
		failures.append("upgrades: editor preview flags are not enabled for WYSIWYG layout")
	var description := scene.get_node("CanvasLayer/UI_Container/DescriptionBubble") as Control
	var description_label := scene.get_node("CanvasLayer/UI_Container/DescriptionBubble/DescriptionCenter/Text") as RichTextLabel
	var power_name_box := scene.get_node("CanvasLayer/UI_Container/PowerNameBox") as Control
	var power_name_label := scene.get_node("CanvasLayer/UI_Container/PowerNameBox/NamePriceRow/PowerNameLabel") as Label
	var context_buy := scene.get_node("CanvasLayer/UI_Container/ContextBuyButton") as Button
	var buy_stele := scene.get_node("CanvasLayer/UI_Container/BuyStele") as Sprite2D
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
	if not buy_stele.visible:
		failures.append("upgrades: buy stele should be visible even before a terminal is open")
	_check_start_menu_button_style(context_buy, ButtonKit.START_MENU_BUTTON_CYAN,
		"upgrades: BUY", failures, true)
	_check_start_menu_press_feedback(context_buy, "upgrades: BUY", failures)
	if context_buy.size != Vector2(22.0, 10.0):
		failures.append("upgrades: contextual buy button should keep its authored 22x10 stele-aligned size (got %s)" % str(context_buy.size))
	var context_buy_disabled_style := context_buy.get_theme_stylebox("disabled")
	if context_buy_disabled_style != null:
		if context_buy_disabled_style.content_margin_left != 0.0 or context_buy_disabled_style.content_margin_right != 0.0:
			failures.append("upgrades: contextual buy button disabled state has asymmetric text margins")
	if context_price.visible:
		failures.append("upgrades: contextual price should be hidden before selecting a power")
	if context_price_coin.texture == null:
		failures.append("upgrades: contextual price is missing lucidity coin icon")
	var back_button := scene.get_node("CanvasLayer/UI_Container/BackButton") as Button
	_check_start_menu_button_style(back_button, ButtonKit.START_MENU_BUTTON_PINK,
		"upgrades: RETURN TO BAR", failures)
	_check_start_menu_press_feedback(back_button, "upgrades: RETURN TO BAR", failures)
	var power_style := power_name_box.get_theme_stylebox(&"panel") as StyleBoxFlat
	if power_style == null or not power_style.border_color.is_equal_approx(ButtonKit.PANEL_BRASS.lerp(Color(0.42, 1.0, 0.95), 0.15)):
		failures.append("upgrades: power name box is missing its brass name contour")
	var description_style := description.get_theme_stylebox(&"panel") as StyleBoxFlat
	if description_style == null or not description_style.border_color.is_equal_approx(ButtonKit.PANEL_BRASS.lerp(Color(1.0, 0.5, 0.7), 0.15)):
		failures.append("upgrades: description bubble is missing its brass description contour")
	if back_button.z_index <= description.z_index:
		failures.append("upgrades: back button should render above description bubble")
	scene._activate_memory()
	if not scene.get_node("upgrade_scene_memory_brain_overlay").visible:
		failures.append("upgrades: memory activation did not reveal memory overlay")
	if scene.get_node("upgrades_scene_eye_brain_overlay").visible:
		failures.append("upgrades: memory activation revealed eye overlay")
	if not memory_prev.visible or not memory_next.visible:
		failures.append("upgrades: memory nav buttons did not appear after activating the memory terminal")
	if not context_buy.visible:
		failures.append("upgrades: contextual buy button did not appear for the memory terminal's first power")
	await process_frame
	if power_name_label.text != "Lock":
		failures.append("upgrades: memory carousel did not open on the Lock power")
	if context_buy.text != "BUY" and context_buy.text != "OWNED":
		failures.append("upgrades: contextual buy button includes price text")
	if context_buy.alignment != HORIZONTAL_ALIGNMENT_CENTER or context_buy.size.x < 22.0:
		failures.append("upgrades: contextual buy button text is not centered with enough width")
	if not context_price.visible:
		failures.append("upgrades: contextual price group did not appear for the memory carousel's first power")
	if context_price.position.x <= power_name_label.position.x:
		failures.append("upgrades: contextual price group is not aligned to the right of the power name")
	scene._memory_next()
	await process_frame
	if power_name_label.text != "Rewards+":
		failures.append("upgrades: reward amp did not show the shortened power name")
	if price_label.text != "30":
		failures.append("upgrades: reward amp tier I price is not shown in PowerNameBox")
	if not description_label.text.contains("[color=#183A8C]tier I[/color]"):
		failures.append("upgrades: reward amp tier I description is not blue BBCode")
	scene._build_reward_amp_picker("corr_reward_amp_1")
	var reward_picker := scene._reward_amp_picker as Control
	_check_symbol_picker_panel_63(reward_picker, 5, true, "issue63: Reward Amp", failures, false)
	if reward_picker != null:
		if reward_picker.find_child("SymbolButtonBrain", true, false) == null:
			failures.append("issue63: Reward Amp picker should include brain")
		if reward_picker.find_child("SymbolButtonFlatline", true, false) != null:
			failures.append("issue63: Reward Amp picker should not include flatline")
		if reward_picker.find_child("TitleLabel", true, false) != null \
			or reward_picker.find_child("CancelButton", true, false) != null:
			failures.append("issue63: Reward Amp picker still shows title/cross chrome")
	if reward_picker != null:
		var outside_reward_tap := InputEventMouseButton.new()
		outside_reward_tap.button_index = MOUSE_BUTTON_LEFT
		outside_reward_tap.pressed = true
		scene._on_reward_amp_picker_input(outside_reward_tap)
		await process_frame
		if scene._reward_amp_picker == null or String(scene._pending_reward_amp_upgrade_id) == "":
			failures.append("issue63: Reward Amp picker can be dismissed outside the mandatory choice")
		# Test cleanup is internal scene teardown, not a player-facing cancel path.
		scene._pending_reward_amp_upgrade_id = ""
		scene._close_reward_amp_picker()
	# Simulate owning tier I/II so the "reward_amp" carousel slot resolves to the
	# next unpurchased tier, mirroring the old row's price/description swap.
	meta_store.ownedPermanents.append("corr_reward_amp_1")
	scene._refresh_all()
	if price_label.text != "55":
		failures.append("upgrades: reward amp tier II price should be 55")
	if not description_label.text.contains("[color=#FBBF24]tier II[/color]"):
		failures.append("upgrades: reward amp tier II description is not orange BBCode")
	meta_store.ownedPermanents.append("corr_reward_amp_2")
	scene._refresh_all()
	if price_label.text != "90":
		failures.append("upgrades: reward amp tier III price should be 90")
	if not description_label.text.contains("[color=#D62828]tier III[/color]"):
		failures.append("upgrades: reward amp tier III description is not red BBCode")
	meta_store.ownedPermanents.append("corr_reward_amp_3")
	scene._refresh_all()
	scene._memory_next()
	if power_name_label.text != "Saving":
		failures.append("upgrades: memory carousel did not advance to the Smart Save power")
	if price_label.text != "30":
		failures.append("upgrades: Smart Save price should be 30")
	scene._memory_next()
	if power_name_label.text != "???":
		failures.append("upgrades: memory carousel did not reach the locked/future slot")
	if context_buy.visible:
		failures.append("upgrades: contextual buy button should be hidden on the locked/future slot")
	if not buy_stele.visible:
		failures.append("upgrades: buy stele should stay visible on the memory locked/future slot")
	scene._memory_next()
	if power_name_label.text != "Lock":
		failures.append("upgrades: memory carousel did not wrap back to the first power")
	brain.frame = 7
	scene._sync_brain_overlay_frames()
	if memory_overlay.frame != 7:
		failures.append("upgrades: memory brain overlay is not synced to brain frame")
	scene._activate_eye()
	if memory_overlay.visible:
		failures.append("upgrades: eye activation did not hide memory overlay")
	if scene.get_node("upgrades_scene_memory_upgrades").frame != 0:
		failures.append("upgrades: eye activation did not reset memory terminal frame")
	if not eye_prev.visible or not eye_next.visible:
		failures.append("upgrades: eye nav buttons did not appear after activating the eye terminal")
	if not context_buy.visible:
		failures.append("upgrades: contextual buy button did not appear for the eye terminal's first power")
	if power_name_label.text != "Pattern Fabrication":
		failures.append("upgrades: eye carousel did not open on Pattern Fabrication")
	if price_label.text != "160":
		failures.append("upgrades: Pattern Fabrication price should be 160")
	scene._eye_next()
	if power_name_label.text != "Book Upgrade":
		failures.append("upgrades: eye carousel did not advance to the Book power")
	if price_label.text != "120":
		failures.append("upgrades: Learning price should be 120")
	scene._eye_next()
	await process_frame
	if power_name_label.text != "Hallucination":
		failures.append("upgrades: Hallucination did not show in the power name box")
	var hallucination_cost := int(Upgrades.upgrade_map()["pos_enlightenment"]["cost"])
	if price_label.text != str(hallucination_cost):
		failures.append("upgrades: Hallucination price should be %d" % hallucination_cost)
	if not description_label.text.contains("Visible pairs count as triples"):
		failures.append("upgrades: Hallucination description does not describe the rework")
	scene._eye_next()
	if power_name_label.text != "???":
		failures.append("upgrades: eye carousel did not reach the locked/future slot")
	if context_buy.visible:
		failures.append("upgrades: contextual buy button should be hidden on the eye locked/future slot")
	if not buy_stele.visible:
		failures.append("upgrades: buy stele should stay visible on the eye locked/future slot")
	scene._eye_prev()
	if power_name_label.text != "Hallucination":
		failures.append("upgrades: eye carousel prev did not step back from the locked slot")
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
	# Issue #109: the closed computer terminals must read as buttons — the
	# contour light blinks on a short cycle, hover/focus holds it on, a press
	# dips it, and an open terminal (active UI, not a button) stays untinted.
	scene._reset_eye_terminal()
	scene._reset_memory_terminal()
	scene._refresh_all()
	for hitbox in [eye_hitbox, memory_hitbox]:
		if hitbox.mouse_entered.get_connections().is_empty() \
				or hitbox.focus_entered.get_connections().is_empty() \
				or hitbox.button_down.get_connections().is_empty():
			failures.append("issue109: %s has no hover/focus/press feedback wiring" % hitbox.name)
	scene._terminal_blink_time = float(scene.TERMINAL_BLINK_TIME) * 0.5
	scene._step_terminal_glow(0.0)
	if eye_terminal.self_modulate.r <= 1.0:
		failures.append("issue109: closed eye terminal contour does not light mid-blink")
	if memory_terminal.self_modulate != Color.WHITE:
		failures.append("issue109: memory terminal should blink on the opposite half-cycle")
	scene._terminal_blink_time = float(scene.TERMINAL_BLINK_MEMORY_OFFSET) \
		+ float(scene.TERMINAL_BLINK_TIME) * 0.5
	scene._step_terminal_glow(0.0)
	if memory_terminal.self_modulate.r <= 1.0:
		failures.append("issue109: closed memory terminal contour does not light mid-blink")
	scene._set_terminal_hot("eye", true)
	scene._step_terminal_glow(0.0)
	if eye_terminal.self_modulate.r <= 1.0:
		failures.append("issue109: hover/focus does not hold the eye terminal light on")
	scene._set_terminal_pressed("eye", true)
	scene._step_terminal_glow(0.0)
	if eye_terminal.self_modulate.r >= 1.0:
		failures.append("issue109: press does not dip the eye terminal light")
	scene._set_terminal_pressed("eye", false)
	scene._set_terminal_hot("eye", false)
	scene._activate_memory()
	scene._step_terminal_glow(0.0)
	if memory_terminal.self_modulate != Color.WHITE:
		failures.append("issue109: open memory terminal should render untinted")
	meta_store.ownedPermanents = saved_permanents
	scene.queue_free()


## The TAP TAP TAP warning must complete fast (under ~0.75s) while each tap stays
## on screen long enough to read.
func _check_tap_duration_161(failures: Array) -> void:
	var script := load("res://scenes/in_run_dealer_offer.gd") as GDScript
	var consts := script.get_script_constant_map()
	var taps := int(consts["TAP_COUNT"])
	var per_tap := float(consts["TAP_ENTRY_TIME"]) + float(consts["TAP_EXIT_TIME"])
	var total := taps * per_tap + (taps - 1) * float(consts["TAP_WAIT"]) \
		+ float(consts["TAP_FINAL_WAIT"])
	if total > 0.75:
		failures.append("pr161: TAP warning too slow (%.2fs > 0.75s)" % total)
	if per_tap < 0.08:
		failures.append("pr161: TAP flash too brief to read (%.2fs per tap)" % per_tap)
