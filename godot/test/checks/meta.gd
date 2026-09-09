extends "res://test/checks/_base.gd"

## Saves, resume, the card collection and the played tutorial.
##
## Cut from scene_smoke.gd unchanged. The suite's runner owns the order and the isolation;
## this file owns nothing but the assertions. See test/checks/_base.gd for why the check
## bodies can still call get_root(), create_timer() and `await process_frame` bare.


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
		for phrase in ["The Objective", "Dealer Scene", "Upgrades Scene", "Machine Scene", "15 spins", "50 coins"]:
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


## Some store fields are named by DATA rather than by code: machine_scene's
## DURATION_BOOSTS table gives each item a "counter" (and sometimes a
## "symbolField") that is looked up with RunStateStore.get(name), and the tutorial
## script pins beat state the same way. A field named only from a table is
## invisible to any search for `RunStateStore.fieldName`, so renaming one looks
## safe and is not: the boost row starts reading null (int(null) throws every
## frame the HUD refreshes) and the tutorial's pinned state silently stops
## applying, because _pin skips properties the store does not have.
##
## That is exactly how the phase-3 rename broke the boost indicators. These names
## are part of an external contract, so this check holds them to it: every name
## any table hands to get() must resolve to a real property.
func _check_dynamic_store_field_names(machine: Node, run_store: Node, failures: Array) -> void:
	var wanted: Array[String] = []
	for boost: Dictionary in machine.DURATION_BOOSTS:
		for key in ["counter", "symbolField"]:
			var name := String(boost.get(key, ""))
			if name != "" and not wanted.has(name):
				wanted.append(name)
		for phase: Dictionary in boost.get("phases", []):
			var phase_name := String(phase.get("counter", ""))
			if phase_name != "" and not wanted.has(phase_name):
				wanted.append(phase_name)
	if wanted.is_empty():
		failures.append("dynamic fields: no boost counters found to check")
	for beat: Dictionary in TutorialScript.BEATS:
		for key in (beat.get("state", {}) as Dictionary):
			var state_name := String(key)
			if not wanted.has(state_name):
				wanted.append(state_name)
	for name in wanted:
		if not (name in run_store):
			failures.append("dynamic fields: '%s' is named by a table but is not a store property" % name)

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
	if int(banked["lucidityWallet"]) != 100:
		failures.append("upgrades: Smart Save did not retain 50% of run lucidity")

	# Smart Saving's OTHER door: the Pacte augment card grants pos_smart_save into the
	# run's ownedUpgrades, never into ownedPermanents. Endings only reads the permanents,
	# so the card used to bank at the plain 10% while promising 50% on its face.
	var run_store: Node = get_root().get_node("RunStateStore")
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	var prev_upgrades: Array = (run_store.ownedUpgrades as Array).duplicate()
	var prev_tier := String(run_store.augmentedTier)

	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.augmentedTier = ""
	run_store.ownedUpgrades = []
	meta_store.ownedPermanents = []
	meta_store.lucidityWallet = 0
	if not run_store._apply_pacte_augment("augment_smart_saving"):
		failures.append("pacte: the SMART SAVING augment card did not apply")
	if not is_equal_approx(meta_store.effective_lucidity_kept_fraction(),
			EconomyConst.SMART_SAVE_LUCIDITY_KEPT):
		failures.append("pacte: a card-granted Smart Saving did not raise the kept fraction")
	meta_store.bank_run({ "lucidityCoins": 200, "scoreEarned": 0, "neurons": 0 }, "flatline")
	if int(meta_store.lucidityWallet) != 100:
		failures.append("pacte: card-granted Smart Saving banked %d of 200, expected 100"
			% int(meta_store.lucidityWallet))

	# Without the card the same run banks the plain 10% — the fix must not hand the
	# raised fraction to every run.
	run_store.ownedUpgrades = []
	meta_store.lucidityWallet = 0
	meta_store.bank_run({ "lucidityCoins": 200, "scoreEarned": 0, "neurons": 0 }, "flatline")
	if int(meta_store.lucidityWallet) != 20:
		failures.append("pacte: a run without Smart Saving banked %d of 200, expected 20"
			% int(meta_store.lucidityWallet))

	run_store.ownedUpgrades = prev_upgrades
	run_store.augmentedTier = prev_tier
	run_store.reset_run_state()
	meta_store._apply(meta_before)
	meta_store.save_state()


# Issue #151: a save written after the final neuron drain but before the post-spin
# ending check must resolve to an ending when the machine scene is rebuilt.
func _check_save_resume_151(machine: Node, run_store: Node, failures: Array) -> void:
	var meta_store: Node = get_root().get_node("MetaStateStore")
	var meta_before: Dictionary = meta_store._as_dict()
	meta_store.campaignActive = true
	meta_store.campaignFailed = false
	meta_store.wealthEndingReached = false
	meta_store.campaignNeuronsLeft = maxi(1, int(meta_store.campaignNeuronsMax))
	# campaignNeuronsLeft >= 1 and campaignNeuronPending == false keep this as flatline.

	run_store.reset_run_state()
	run_store.runPhase = "running"
	run_store.neurons = 0
	run_store.wealthTargetIndex = 1
	run_store.freeSpinsRemaining = 0
	run_store.isSpinning = false
	run_store.scoreEarned = 123
	run_store.lastResult = {
		"reels": ["brain", "eye", "vial"],
		"winType": "miss",
		"freeSpinsGranted": 0,
	}
	run_store._commit()
	if not FileAccess.file_exists(run_store.RUN_SAVE_PATH):
		failures.append("issue151: exhausted running save was not written")

	# Re-enter through the same autoload load path used after an app restart.
	run_store.runPhase = "idle"
	run_store.neurons = 10
	run_store.lastResult = null
	run_store.load_run_state()
	machine._sync_visuals()

	if String(run_store.runPhase) == "running":
		failures.append("issue151: exhausted save left a running zero-spin machine")
	if String(run_store.lastEnding) != "flatline":
		failures.append("issue151: exhausted save ended as %s, expected flatline"
			% str(run_store.lastEnding))
	if machine._overlay == null:
		failures.append("issue151: exhausted save showed no ending overlay")
	if machine._overlay != null:
		machine._overlay.queue_free()
		machine._overlay = null
	machine._stop_flatline_countdown()

	run_store.reset_run_state()
	meta_store._apply(meta_before)
	meta_store.save_state()

# Score-scene win counter (issue #142): a win registers under the active tier
# the moment the wealth goal is hit — surviving the deferred Start Again bank,
# the wealth-CONTINUE-then-flatline path — and the scores scene shows the
# number for the tier the arrows have selected.
func _check_tier_win_counter_142(run_store: Node, meta_store: Node, failures: Array) -> void:
	var meta_before: Dictionary = meta_store._as_dict()
	var prev_tier := String(run_store.augmentedTier)
	meta_store.history = { "runsPlayed": 0, "bestScoreRun": 0 }
	meta_store.endingsReached = []

	# Classic win: counted when the ending resolves, before any bank.
	run_store.augmentedTier = ""
	meta_store.mark_ending_reached("wealth")
	if int(meta_store.tier_wins("classic")) != 1:
		failures.append("issue142: classic wealth did not register a classic win")
	# The deferred Start Again bank must not count the same win twice.
	meta_store.bank_run({ "lucidityCoins": 0, "scoreEarned": 5000, "neurons": 1 }, "wealth")
	if int(meta_store.tier_wins("classic")) != 1:
		failures.append("issue142: the wealth bank double-counted the win")

	# Augmented win taken through CONTINUE: the run later banks as flatline,
	# but the heart win is already on the books.
	run_store.augmentedTier = "heart"
	meta_store.mark_ending_reached("wealth")
	meta_store.bank_run({ "lucidityCoins": 50, "scoreEarned": 2400, "neurons": 0 }, "flatline")
	if int(meta_store.tier_wins("heart")) != 1:
		failures.append("issue142: a wealth-continued heart run lost its win")
	if int(meta_store.tier_wins("classic")) != 1:
		failures.append("issue142: the heart win leaked into the classic counter")

	# The scene opens on classic and the arrows move the counter to the
	# selected tier's number.
	var scene: Control = (load("res://scenes/scores_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	var shown: Array = []
	for i in 3: # classic -> heart -> diamond
		shown.append(String(scene._win_counter_label.text))
		scene._cycle_tier(1)
	if shown != ["1", "1", "0"]:
		failures.append("issue142: win counter cycled %s, expected [1, 1, 0]" % str(shown))
	scene.queue_free()

	run_store.augmentedTier = prev_tier
	meta_store._apply(meta_before)
	meta_store.save_state()

# ── issue #52: Collection card catalog and the unlock popup ──────────────────────

func _check_card_collection_52(meta_store: Node, failures: Array) -> void:
	var saved_augments: Array = meta_store.unlockedAugmentCardIds.duplicate()
	var saved_powers: Array = meta_store.unlockedPowerCardIds.duplicate()
	var saved_pending: Array = meta_store.pendingCardUnlocks.duplicate(true)
	var saved_progress: Dictionary = meta_store.cardUnlockProgress.duplicate(true)
	var locked_augment := "augment_hallucination"
	var locked_power := "heart"
	var unlocked_augment := "augment_book"

	var augments: Array = PacteCards.augment_ids()
	augments.erase(locked_augment)
	var powers: Array = PacteCards.power_ids()
	powers.erase(locked_power)
	meta_store.unlockedAugmentCardIds = augments
	meta_store.unlockedPowerCardIds = powers
	meta_store.pendingCardUnlocks = []

	var collection := (load("res://scenes/collection_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(collection)

	# The catalog is complete and ordered by PacteCards, locked cards included.
	var expected: Array[String] = []
	expected.append_array(PacteCards.augment_ids())
	expected.append_array(PacteCards.power_ids())
	if str(collection.catalog_card_ids()) != str(expected):
		failures.append("issue52: Collection catalog order/contents drifted from PacteCards")

	# An unlocked card shows its authored front, icon, and name.
	var unlocked_entry := collection.card_entry(unlocked_augment) as Button
	if unlocked_entry == null:
		failures.append("issue52: unlocked augment has no catalog entry")
	else:
		var art := unlocked_entry.get_node_or_null("CardArt") as TextureRect
		var atlas := art.texture as AtlasTexture if art != null else null
		if atlas == null or atlas.region != PacteCards.AUGMENT_FRONT_RECT:
			failures.append("issue52: unlocked augment did not render the card front")
		if unlocked_entry.get_node_or_null("CardIcon") == null:
			failures.append("issue52: unlocked augment did not render its icon")
		var name_label := unlocked_entry.get_node_or_null("NameLabel") as Label
		if name_label == null or name_label.text != String(PacteCards.card(unlocked_augment)["name"]).to_upper():
			failures.append("issue52: unlocked augment did not show its name")

	# A locked card keeps its slot but shows only the card back.
	for locked in [
		{ "id": locked_augment, "back": PacteCards.AUGMENT_BACK_RECT, "name": "HALLUCINATION" },
		{ "id": locked_power, "back": PacteCards.POWER_BACK_RECT, "name": "HEART" },
	]:
		var locked_id := String(locked["id"])
		var locked_entry := collection.card_entry(locked_id) as Button
		if locked_entry == null:
			failures.append("issue52: locked card %s lost its catalog slot" % locked_id)
			continue
		var locked_art := locked_entry.get_node_or_null("CardArt") as TextureRect
		var locked_atlas := locked_art.texture as AtlasTexture if locked_art != null else null
		if locked_atlas == null or locked_atlas.region != (locked["back"] as Rect2):
			failures.append("issue52: locked card %s did not render the card back" % locked_id)
		if locked_entry.get_node_or_null("CardIcon") != null:
			failures.append("issue52: locked card %s leaked its icon" % locked_id)
		var locked_label := locked_entry.get_node_or_null("NameLabel") as Label
		if locked_label == null or locked_label.text != "":
			failures.append("issue52: locked card %s leaked a readable name" % locked_id)
		if locked_entry.modulate == Color.WHITE:
			failures.append("issue52: locked card %s was not muted" % locked_id)

	# Selecting a card opens the matching modal state.
	var unlocked_button := collection.card_entry(unlocked_augment) as Button
	if unlocked_button != null:
		unlocked_button.pressed.emit()
	var unlocked_card := PacteCards.card(unlocked_augment)
	if collection.modal_state() != "unlocked" or collection.modal_card_id() != unlocked_augment:
		failures.append("issue52: selecting an unlocked card did not open the unlocked modal")
	if collection._modal_description.text != String(unlocked_card["description"]):
		failures.append("issue52: the unlocked modal did not show the authored description")
	if not collection._modal.visible:
		failures.append("issue52: the detail modal stayed hidden for an unlocked card")

	var locked_button := collection.card_entry(locked_augment) as Button
	if locked_button != null:
		locked_button.pressed.emit()
	if collection.modal_state() != "locked" or collection.modal_card_id() != locked_augment:
		failures.append("issue52: selecting a locked card did not open the LOCKED modal")
	var locked_meta := PacteCards.card(locked_augment)
	if collection._modal_name.text != collection.LOCKED_NAME \
			or collection._modal_description.text == String(locked_meta["description"]) \
			or collection._modal_description.text.contains(String(locked_meta["name"])):
		failures.append("issue52: the LOCKED modal revealed the card's metadata")
	if collection._modal_card_icon != null and collection._modal_card_icon.visible:
		failures.append("issue52: the LOCKED modal revealed the card icon")
	collection.queue_free()

	# ── unlock popup ─────────────────────────────────────────────────────────────
	var host := Control.new()
	get_root().add_child(host)
	var popup := UnlockCardPopup.attach_to(host)
	if popup == null:
		failures.append("issue52: the unlock popup did not attach to its host")
		host.queue_free()
		_restore_card_unlock_state(meta_store, saved_augments, saved_powers, saved_pending, saved_progress)
		return
	if popup.visible:
		failures.append("issue52: the unlock popup opened with an empty queue")

	# A new unlock queues exactly one entry and opens the popup on that card.
	if not meta_store.unlock_card(locked_augment, "augment", false):
		failures.append("issue52: unlock_card refused a locked card")
	if meta_store.pending_card_unlocks().size() != 1:
		failures.append("issue52: a new unlock did not create exactly one popup entry")
	if not popup.visible or popup._card_id != locked_augment:
		failures.append("issue52: the popup did not present the newly unlocked card")
	if popup._name_label.text != String(PacteCards.card(locked_augment)["name"]).to_upper() \
			or popup._description_label.text != String(PacteCards.card(locked_augment)["description"]):
		failures.append("issue52: the popup did not show the card's authored name/description")
	if popup._front.texture == null or (popup._front.texture as AtlasTexture).region != PacteCards.AUGMENT_FRONT_RECT:
		failures.append("issue52: the popup did not show the enlarged card front")
	if popup._front.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		failures.append("issue52: the popup card front is not nearest-filtered")
	if popup._heading.text != "CARD UNLOCKED":
		failures.append("issue52: the popup is missing its CARD UNLOCKED heading")
	if popup._dim == null or popup.mouse_filter != Control.MOUSE_FILTER_STOP:
		failures.append("issue52: the popup does not block the scene behind it")

	# A duplicate unlock attempt changes nothing.
	if meta_store.unlock_card(locked_augment, "augment", false):
		failures.append("issue52: an already-unlocked card unlocked twice")
	if meta_store.pending_card_unlocks().size() != 1:
		failures.append("issue52: a duplicate unlock added a second popup entry")

	# A second unlock waits its turn behind the card on screen.
	if not meta_store.unlock_card(locked_power, "power", false):
		failures.append("issue52: unlock_card refused a locked power card")
	if meta_store.pending_card_unlocks().size() != 2:
		failures.append("issue52: a second unlock was not queued")
	if popup._card_id != locked_augment:
		failures.append("issue52: a second unlock interrupted the card being presented")

	# CONTINUE acknowledges the presented card and advances to the next one.
	popup._on_continue_pressed()
	if meta_store.pending_card_unlocks().size() != 1:
		failures.append("issue52: CONTINUE did not acknowledge the presented card")
	if meta_store.pending_card_unlocks().size() == 1 \
			and String((meta_store.pending_card_unlocks()[0] as Dictionary)["cardId"]) != locked_power:
		failures.append("issue52: CONTINUE acknowledged the wrong card")
	if not popup.visible or popup._card_id != locked_power:
		failures.append("issue52: multiple pending unlocks did not present sequentially")

	# VIEW COLLECTION acknowledges the card and hands its ID to Collection. The
	# popup is detached first so the check exercises the acknowledgement/highlight
	# handoff without changing the harness's scene out from under the run.
	host.remove_child(popup)
	popup._on_view_collection_pressed()
	if not meta_store.pending_card_unlocks().is_empty():
		failures.append("issue52: VIEW COLLECTION did not acknowledge the presented card")
	if UnlockCardPopup.pending_highlight_card_id != locked_power:
		failures.append("issue52: VIEW COLLECTION did not hand the card to Collection")
	if popup.visible:
		failures.append("issue52: the popup stayed open after VIEW COLLECTION")
	if popup.COLLECTION_SCENE != "res://scenes/collection_scene.tscn":
		failures.append("issue52: VIEW COLLECTION does not route to the Collection scene")
	popup.queue_free()
	host.queue_free()

	var highlighted := (load("res://scenes/collection_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(highlighted)
	if highlighted.highlighted_card_id() != locked_power:
		failures.append("issue52: Collection did not highlight the newly unlocked card")
	if highlighted.card_entry(locked_power) == null \
			or not bool(highlighted.card_entry(locked_power).get_meta(&"unlocked")):
		failures.append("issue52: the unlocked card is still locked in Collection")
	if UnlockCardPopup.pending_highlight_card_id != "":
		failures.append("issue52: the Collection highlight handoff was not consumed")
	highlighted.queue_free()

	# Draw filtering keeps reading the unlocked lists.
	var draw_pool: Array = PacteCards.augment_ids()
	draw_pool.erase(locked_augment)
	for drawn_id in PacteCards.draw("augment", 991, draw_pool, [], 3):
		if String(drawn_id) == locked_augment:
			failures.append("issue52: Pacte draw offered a card outside the unlocked list")

	_restore_card_unlock_state(meta_store, saved_augments, saved_powers, saved_pending, saved_progress)
	await process_frame


# ── issue #105: the played tutorial ──────────────────────────────────────────────
# Two things have to hold or the tutorial is worse than none: it must never leave the
# player behind a mask with nothing to tap, and it must never touch their save.

func _check_tutorial_105(machine: Node, run_store: Node, meta_store: Node, failures: Array) -> void:
	var tutorial: Node = get_root().get_node("Tutorial")
	# An unlock popup left visible by an earlier check IS a blocking modal, and the tutorial
	# now correctly stands down for one. Clear it so these checks see a quiet machine.
	if machine._unlock_popup != null and is_instance_valid(machine._unlock_popup):
		machine._unlock_popup.visible = false
	meta_store.pendingCardUnlocks = []

	# Every anchor the script names must resolve on the scene it names it for. A renamed
	# anchor otherwise rings nothing and the beat points the player at empty screen. The
	# other two scenes are stood up here rather than trusted: this check is worthless if
	# it only ever looks at the machine.
	var anchor_hosts := { "machine": machine }
	for kind in ["pacte", "dealer"]:
		var path := "res://scenes/%s_scene.tscn" % kind
		var host: Node = (load(path) as PackedScene).instantiate()
		get_root().add_child(host)
		anchor_hosts[kind] = host
	for scene_kind in TutorialScript.scenes():
		var host: Node = anchor_hosts.get(scene_kind) as Node
		if host == null or not host.has_method("tutorial_anchor"):
			failures.append("issue105: no scene answers anchors for '%s'" % scene_kind)
			continue
		for anchor_id in TutorialScript.anchors_for(scene_kind):
			var rect: Rect2 = host.call("tutorial_anchor", anchor_id)
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				failures.append("issue105: %s cannot anchor '%s'" % [scene_kind, anchor_id])
			elif not Rect2(0.0, 0.0, 160.0, 320.0).encloses(rect):
				failures.append("issue105: %s anchors '%s' off the canvas: %s" \
					% [scene_kind, anchor_id, rect])

	# An anchor naming a control must land ON that control. The stash is the one that bit:
	# its slots are authored in the machine's .tscn, so the shared computed layout put the
	# ring in the middle of the stash rather than on the slot the beat asks for.
	if not machine._stash.icons().is_empty():
		var first_slot: Control = machine._stash.icons()[0] as Control
		var stash_anchor: Rect2 = machine.call("tutorial_anchor", "stash")
		var slot_rect := Rect2(machine.call("_canvas_position_of", first_slot), first_slot.size)
		if not stash_anchor.encloses(slot_rect):
			failures.append("issue105: the stash ring %s is not on the first slot %s" \
				% [stash_anchor, slot_rect])

	# Beats are well formed: every one says something, names a scene the script visits,
	# and advances by a rule the director knows.
	for i in TutorialScript.count():
		var beat: Dictionary = TutorialScript.beat(i)
		if String(beat.get("text", "")) == "":
			failures.append("issue105: beat %d has nothing to say" % i)
		if not TutorialScript.scenes().has(String(beat.get("scene", ""))):
			failures.append("issue105: beat %d names an unknown scene" % i)
		if not ["tap", "anchor", "spin", "scene"].has(String(beat.get("advance", ""))):
			failures.append("issue105: beat %d advances by an unknown rule" % i)
		# A beat that hands a control through must have one to hand through.
		var advance := String(beat.get("advance", ""))
		var anchor := String(beat.get("anchor", ""))
		if advance == "anchor" and anchor == "":
			failures.append("issue105: beat %d waits on a control it never rings" % i)
		# The softlock shape: a beat that ends because the player DID something, while the
		# mask covers the thing they have to do it with. A spin beat must open the lever;
		# an action beat must open whatever it is waiting on.
		if advance == "spin" and anchor != "spin_button":
			failures.append("issue105: beat '%s' waits for a spin but does not open the lever" \
				% String(beat.get("id", i)))
		if advance != "tap" and anchor == "":
			failures.append("issue105: beat '%s' waits for an action behind a full mask" \
				% String(beat.get("id", i)))

	# The sandbox: the tutorial plays a whole scripted campaign and gives the player's own
	# state back untouched. This is the check that matters most — a tutorial that eats a
	# campaign is a bug report, not a first impression.
	var prev_phase := String(run_store.runPhase)
	var meta_before: Dictionary = meta_store._as_dict()
	var run_before: Dictionary = {}
	for prop in run_store._run_state_properties():
		run_before[String(prop)] = run_store.get(prop)
	var save_before := FileAccess.get_modified_time("user://lobotomy-meta.json")

	if not tutorial.can_start():
		failures.append("issue105: the tutorial refused to start from a clean state")
	if not tutorial.start():
		failures.append("issue105: start() failed")
	if not bool(tutorial.active) or not bool(meta_store.sandboxed) or not bool(run_store.sandboxed):
		failures.append("issue105: the tutorial did not seal the stores off from the disk")
	if tutorial.can_start():
		failures.append("issue105: a running tutorial offered to start a second one")

	# Nothing the tutorial does counts. It plays the real machine, so it lands real wins and
	# real consumable uses, but none of that is the player's play — and an unlock would take
	# the whole screen to celebrate itself on top of a beat that is mid-sentence.
	var progress_before: Dictionary = meta_store.card_unlock_progress_snapshot()
	var earned: Array = meta_store.add_card_unlock_progress(CardUnlocks.METRIC_WINS, 99)
	earned.append_array(meta_store.record_best_card_unlock_progress(
		CardUnlocks.METRIC_BEST_RUN_SCORE, 999999))
	if not earned.is_empty():
		failures.append("issue105: the tutorial unlocked cards: %s" % str(earned))
	if not _deep_equal_variants(meta_store.card_unlock_progress_snapshot(), progress_before):
		failures.append("issue105: the tutorial moved card-unlock progress")
	if meta_store.has_pending_card_unlocks():
		failures.append("issue105: the tutorial queued an unlock popup over its own beats")

	# ...and the deck it deals from leaves out the reward-amplification tier: taking one
	# opens a symbol picker the script never planned for, and asks a player two minutes old
	# to choose a symbol to boost with nothing to base the answer on.
	var tutorial_offer: Array = run_store.pacteOfferAugmentIds if \
		run_store.pacteOfferAugmentIds is Array else []
	if tutorial_offer.is_empty():
		failures.append("issue105: the tutorial's Pacte dealt no augments to check")
	for amp_id in PacteCards.reward_amp_ids():
		if tutorial_offer.has(amp_id):
			failures.append("issue105: the tutorial's Pacte offered '%s'" % amp_id)
	# Attaching the machine is what a real scene does on _ready; the beats that belong to
	# it then present for real, pinning their scripted state.
	tutorial.attach(machine, "machine")
	if machine.get_node_or_null("TutorialOverlay") == null:
		failures.append("issue105: attaching a scene did not mount the coach overlay")
	# Walk to the first machine beat and confirm it actually PRESENTED: pinned its scripted
	# state and rang a real control. Without this the walk below would pass on a director
	# that silently shows nothing.
	var guard := 0
	while bool(tutorial.active) and guard < TutorialScript.count():
		if String(TutorialScript.beat(int(tutorial.beat_index)).get("id", "")) == "health":
			break
		tutorial._advance()
		guard += 1
	if int(run_store.neurons) != 12:
		failures.append("issue105: the health beat did not pin its scripted state (neurons %d)" \
			% int(run_store.neurons))
	var overlay: Control = machine.get_node_or_null("TutorialOverlay") as Control
	if overlay == null or not overlay.visible:
		failures.append("issue105: the coach overlay is not up on a machine beat")
	elif overlay._ring_rect.size == Vector2.ZERO:
		failures.append("issue105: the health beat rang nothing")
	elif overlay.get_node_or_null("SkipButton") == null:
		failures.append("issue105: no way out of the tutorial")

	# A read-and-continue beat still SPOTLIGHTS what it names: the mask is cut around the
	# anchor whether or not the tap is handed through. Pointing at a health bar dimmed to
	# the same grey as everything else highlights nothing.
	var lit := false
	for panel: ColorRect in overlay._mask_panels:
		if panel.size.x >= 160.0 and panel.size.y >= 320.0:
			lit = false
			break
		lit = true
	if not lit:
		failures.append("issue105: the health beat dimmed the bar it was naming")
	# ...but the tap still belongs to the tutorial, not to the control underneath.
	if overlay._tap_catcher.mouse_filter != Control.MOUSE_FILTER_STOP:
		failures.append("issue105: a read-and-continue beat handed its tap to the machine")

	# The coaching text has to fit inside its own box, at the longest line the script has.
	var longest := ""
	for i in TutorialScript.count():
		var line := String(TutorialScript.beat(i).get("text", ""))
		if line.length() > longest.length():
			longest = line
	overlay.show_beat(longest, Rect2(), false)
	var box: Control = overlay._box
	var text_label: Label = overlay._label
	if box != null and text_label != null:
		var needed := text_label.get_theme_font("font").get_multiline_string_size(
			text_label.text, HORIZONTAL_ALIGNMENT_CENTER, text_label.size.x,
			overlay.FONT_SIZE).y
		if needed > text_label.size.y + 1.0:
			failures.append("issue105: the longest line does not fit its box (%.1f > %.1f)" \
				% [needed, text_label.size.y])
		if box.size.x > 160.0 or box.position.x < 0.0 \
				or box.position.x + box.size.x > 160.0:
			failures.append("issue105: the coach box runs off the canvas: %s at %s" \
				% [box.size, box.position])

	# SKIP asks before it throws the tutorial away.
	var skipped := [false]
	overlay.skip_pressed.connect(func() -> void: skipped[0] = true)
	(overlay.get_node("SkipButton") as Button).pressed.emit()
	if overlay.get_node_or_null("SkipConfirm") == null:
		failures.append("issue105: SKIP did not ask first")
	elif skipped[0]:
		failures.append("issue105: SKIP left before the player answered")
	else:
		var confirm: Control = overlay.get_node("SkipConfirm")
		(confirm.find_child("NOButton", true, false) as Button).pressed.emit()
		if overlay.get_node_or_null("SkipConfirm") != null or skipped[0]:
			failures.append("issue105: answering NO did not put the player back")
		(overlay.get_node("SkipButton") as Button).pressed.emit()
		confirm = overlay.get_node_or_null("SkipConfirm") as Control
		if confirm == null:
			failures.append("issue105: SKIP could not be asked a second time")
		else:
			(confirm.find_child("YESButton", true, false) as Button).pressed.emit()
			if not skipped[0]:
				failures.append("issue105: answering YES did not leave the tutorial")

	var walked := 0
	while bool(tutorial.active) and walked <= TutorialScript.count() + 2:
		# Every action beat must leave a real hole over the control it is asking for. This
		# is the Pacte softlock: the beat rang the cards while the mask still covered them,
		# so there was no way to choose one and only SKIP got out. Judged on what the
		# DIRECTOR did with the live beat, not on a mask the check drove itself.
		var beat: Dictionary = TutorialScript.beat(int(tutorial.beat_index))
		if String(beat.get("scene", "")) == "machine" \
				and String(beat.get("advance", "")) != "tap" \
				and overlay != null and overlay.visible:
			var sealed := false
			for panel: ColorRect in overlay._mask_panels:
				if panel.size.x >= 160.0 and panel.size.y >= 320.0:
					sealed = true
			if sealed:
				failures.append("issue105: beat '%s' masks the control it asks for" \
					% String(beat.get("id", "?")))
				break
		tutorial._advance()
		walked += 1
	if bool(tutorial.active):
		failures.append("issue105: walking every beat never ended the tutorial")
		tutorial.stop(false)
	if bool(meta_store.sandboxed) or bool(run_store.sandboxed):
		failures.append("issue105: the sandbox outlived the tutorial")
	if not bool(meta_store.tutorialCompleted):
		failures.append("issue105: finishing the tutorial did not record it")

	# Restored, field by field. tutorialCompleted is the one deliberate exception: it is
	# the record that the tutorial happened and must survive its own restore.
	var meta_after: Dictionary = meta_store._as_dict()
	for key in meta_before:
		if String(key) == "tutorialCompleted":
			continue
		if not _deep_equal_variants(meta_after.get(key), meta_before[key]):
			failures.append("issue105: the tutorial changed meta '%s': %s -> %s" \
				% [String(key), str(meta_before[key]), str(meta_after.get(key))])
			break
	for prop in run_before:
		if not _deep_equal_variants(run_store.get(String(prop)), run_before[prop]):
			failures.append("issue105: the tutorial changed run state '%s'" % String(prop))
			break
	if FileAccess.get_modified_time("user://lobotomy-meta.json") != save_before \
			and save_before != 0:
		# The restore writes once on the way out, which is expected; what must NOT happen
		# is the scripted campaign being written mid-tutorial. Checked by the sandbox flags
		# above — this only guards against the save being left holding tutorial state.
		var reloaded: Dictionary = meta_store._as_dict()
		if int(reloaded.get("lucidityWallet", -1)) == int(tutorial.SANDBOX_WALLET):
			failures.append("issue105: the tutorial's scripted wallet reached the save")

	# Whatever the beat wants, a modal the script does NOT own must never be masked. Every
	# post-run dealer visit opens the odds table — the target break as well as a flatline —
	# and a coaching mask over it left the player unable to spend their tokens, unable to
	# close the table, and unable to reach the START it was standing in front of.
	var dealer_host: Node = anchor_hosts["dealer"] as Node
	if not dealer_host.has_method("tutorial_blocking_modal"):
		failures.append("issue105: the dealer cannot tell the tutorial a modal is up")
	else:
		tutorial.start()
		dealer_host.set("_odds_overlay", null)
		dealer_host.set("_augment_picker", null)
		tutorial.attach(dealer_host, "dealer")
		var dealer_overlay_ui: Control = tutorial._overlay as Control
		# Walk to a dealer beat that is NOT the one about the odds table: `over_modal` beats
		# are meant to be shown over it, so they would fail this check by design.
		for i in TutorialScript.count():
			var candidate: Dictionary = TutorialScript.beat(int(tutorial.beat_index))
			if String(candidate.get("scene", "")) == "dealer" \
					and not bool(candidate.get("over_modal", false)):
				break
			tutorial._advance()
		# Stand up a modal the way a post-run visit does, then re-present the beat.
		var fake_modal := Control.new()
		fake_modal.visible = true
		dealer_host.add_child(fake_modal)
		dealer_host.set("_augment_picker", fake_modal)
		tutorial._present_beat()
		if not bool(tutorial._awaiting_modal):
			failures.append("issue105: the tutorial did not stand down for a blocking modal")
		for panel: ColorRect in dealer_overlay_ui._mask_panels:
			if panel.size.x > 0.0 and panel.size.y > 0.0:
				failures.append("issue105: a modal the tutorial does not own is masked")
				break
		if dealer_overlay_ui._tap_catcher.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			failures.append("issue105: the tutorial ate the taps meant for another modal")
		if not (dealer_overlay_ui.get_node("SkipButton") as Button).visible:
			failures.append("issue105: no way out while another modal is up")
		# Modal gone: the coaching comes back on its own.
		dealer_host.set("_augment_picker", null)
		fake_modal.queue_free()
		tutorial._process(0.016)
		if bool(tutorial._awaiting_modal):
			failures.append("issue105: the tutorial stayed down after the modal closed")
		tutorial.stop(false)

	# The post-flatline flow visits a second Pacte and the odds table before the shop, and
	# the tutorial has to cover both: a player dropped onto a second Pacte with no word
	# about it just sits there, and the odds table is a whole screen of its own.
	var flow_ids: Array[String] = []
	for i in TutorialScript.count():
		flow_ids.append(String(TutorialScript.beat(i).get("id", "")))
	for expected in ["pacte_again", "odds"]:
		if not flow_ids.has(expected):
			failures.append("issue105: the script skips the '%s' step" % expected)
	if flow_ids.has("odds") and flow_ids.has("shop") \
			and flow_ids.find("odds") > flow_ids.find("shop"):
		failures.append("issue105: the odds table is explained after the shop it precedes")
	# The odds beat must be shown OVER the table rather than standing down for it, and must
	# not take the taps the table needs.
	var odds_beat: Dictionary = TutorialScript.beat(flow_ids.find("odds"))
	if not bool(odds_beat.get("over_modal", false)):
		failures.append("issue105: the odds beat stands down instead of explaining the table")
	if String(odds_beat.get("advance", "")) == "tap":
		failures.append("issue105: the odds beat would eat the taps the table needs")
	if String(odds_beat.get("anchor", "")) != "screen":
		failures.append("issue105: the odds beat would mask the table it explains")

	# A tap does not count until the beat has been readable for a moment. Tapping through
	# one line used to carry into the next, so a double tap skipped a beat unseen.
	tutorial.start()
	tutorial.attach(machine, "machine")
	# A tap beat ON THE MACHINE: a beat waiting for another scene is not armed at all, so it
	# would "pass" this check for the wrong reason.
	while bool(tutorial.active) and not (
			String(TutorialScript.beat(int(tutorial.beat_index)).get("advance", "")) == "tap"
			and String(TutorialScript.beat(int(tutorial.beat_index)).get("scene", "")) == "machine"):
		tutorial._advance()
	var tap_beat := int(tutorial.beat_index)
	tutorial._on_overlay_tapped()
	if int(tutorial.beat_index) != tap_beat:
		failures.append("issue105: a tap landing with the beat skipped it unread")
	tutorial._process(float(tutorial.TAP_GRACE) + 0.02)
	tutorial._on_overlay_tapped()
	if int(tutorial.beat_index) == tap_beat:
		failures.append("issue105: the beat could not be tapped through at all")
	tutorial.stop(false)

	# Beating a target parks the run at the dealer for a break; the tutorial has a losing
	# run left to show, so it carries the player back to the machine itself rather than
	# leaving them at a counter with the showcase half finished.
	var target_beat := -1
	for i in TutorialScript.count():
		if String(TutorialScript.beat(i).get("id", "")) == "target_hit":
			target_beat = i
			break
	if target_beat < 0:
		failures.append("issue105: the script no longer has a target beat")
	elif String(TutorialScript.beat(target_beat).get("go", "")) != "machine":
		failures.append("issue105: the target beat does not hand back to the machine")
	elif String(TutorialScript.beat(target_beat + 1).get("scene", "")) != "machine":
		failures.append("issue105: the beat after the win is not on the machine")

	# A gift ADDS to the pocket rather than replacing what is in it — taking away the item
	# the player chose one beat after being congratulated for choosing it is not a lesson —
	# and it lands in the FIRST slot, which is the one the beat rings. A full pocket must
	# not leave the gift in a slot the stash does not draw.
	tutorial.start()
	run_store.runConsumables = { "item_energy_drink": 1, "cons_tea": 1 }
	tutorial._give({ "cons_white_powder": 1 })
	var pocket: Dictionary = run_store.runConsumables as Dictionary
	if not pocket.has("cons_white_powder"):
		failures.append("issue105: the tutorial's gift never arrived")
	if not pocket.has("item_energy_drink") or not pocket.has("cons_tea"):
		failures.append("issue105: the gift replaced what the player was holding: %s" % str(pocket))
	if pocket.keys().is_empty() or String(pocket.keys()[0]) != "cons_white_powder":
		failures.append("issue105: the gift is not in the slot the beat rings: %s" % str(pocket.keys()))
	# Handing over a second copy of something already held must not stack it up.
	run_store.runConsumables = { "cons_white_powder": 1 }
	tutorial._give({ "cons_white_powder": 1 })
	if int((run_store.runConsumables as Dictionary).get("cons_white_powder", 0)) != 1:
		failures.append("issue105: the gift stacked onto a copy the player already had")
	tutorial.stop(false)

	# A beat whose SCREEN never opens must not park the tutorial. The overlay stands down
	# so the game underneath is playable, SKIP stays live — hiding it was the trap: a
	# tutorial that cannot be ended keeps the player's save sealed behind its sandbox —
	# and the wait is bounded, so the beat is eventually dropped rather than waited on
	# forever. This is what happened after the target was beaten.
	tutorial.start()
	tutorial.attach(machine, "machine")
	var waiting_beat := -1
	for i in TutorialScript.count():
		if String(TutorialScript.beat(int(tutorial.beat_index)).get("scene", "")) == "dealer":
			waiting_beat = int(tutorial.beat_index)
			break
		tutorial._advance()
	if waiting_beat < 0:
		failures.append("issue105: the script never waits on another scene")
	else:
		var waiting_overlay: Control = tutorial._overlay as Control
		if waiting_overlay == null or not waiting_overlay.visible:
			failures.append("issue105: waiting for a scene took the whole overlay away")
		elif waiting_overlay.get_node_or_null("SkipButton") == null \
				or not (waiting_overlay.get_node("SkipButton") as Button).visible:
			failures.append("issue105: no way out while waiting for a scene that may never open")
		else:
			for panel: ColorRect in waiting_overlay._mask_panels:
				if panel.size.x > 0.0 and panel.size.y > 0.0:
					failures.append("issue105: a waiting beat still masks the game underneath")
					break
		# Bounded: the beat is dropped rather than waited on forever.
		tutorial._process(float(tutorial.SCENE_WAIT_TIMEOUT) + 1.0)
		if int(tutorial.beat_index) == waiting_beat:
			failures.append("issue105: waiting for a scene never timed out")
	tutorial.stop(false)

	# The dealer beat, played at the machine's real timing: the spin that summons him
	# resolves BEFORE check_dealer_trigger runs, so the beat opens with no dealer in sight.
	# It must hold rather than arm against an empty counter — armed early, "did they take
	# one?" was measured against a counter with no dealer on it and the beat could never
	# complete, which is a stuck tutorial with a live-looking dealer in front of it.
	tutorial.start()
	tutorial.attach(machine, "machine")
	run_store.dealerPending = false
	run_store.dealerIncoming = false
	run_store.runConsumables = {}
	var reached_dealer := false
	for i in TutorialScript.count():
		if String(TutorialScript.beat(int(tutorial.beat_index)).get("id", "")) == "dealer_take":
			reached_dealer = true
			break
		tutorial._advance()
	if not reached_dealer:
		failures.append("issue105: never reached the dealer beat")
	else:
		if bool(tutorial._armed):
			failures.append("issue105: the dealer beat armed before the dealer arrived")
		# Standing down, not vanishing: the overlay carries the only way out.
		var waiting_ui: Control = tutorial._overlay as Control
		if waiting_ui == null or not waiting_ui.visible \
				or not (waiting_ui.get_node("SkipButton") as Button).visible:
			failures.append("issue105: no way out while a beat waits for the dealer")
		# He walks in; the beat wakes up on the next frame.
		run_store.dealerPending = true
		run_store.dealerOfferIds = ["item_water", "item_cocktail"]
		tutorial._process(0.016)
		if not bool(tutorial._armed):
			failures.append("issue105: the dealer beat did not open once he was in")
		# Taking an item is what completes it — not the dealer leaving, which also happens
		# when the offer is waved off.
		run_store.runConsumables = { "item_water": 1 }
		run_store.dealerPending = false
		var before_take := int(tutorial.beat_index)
		tutorial._process(0.016)
		if int(tutorial.beat_index) == before_take:
			failures.append("issue105: taking an item from the dealer did nothing")
	tutorial.stop(false)

	# The same hole check on the Pacte, whose beats never present while the machine is the
	# attached scene — and the Pacte pick is exactly where the mask sealed the player in.
	# Its cards are DRAGGED into slots, so the hole has to span the row and the slots.
	tutorial.start()
	tutorial.attach(anchor_hosts["pacte"] as Node, "pacte")
	var pacte_overlay: Control = (anchor_hosts["pacte"] as Node) \
		.get_node_or_null("TutorialOverlay") as Control
	var pacte_guard := 0
	while bool(tutorial.active) and pacte_guard < TutorialScript.count():
		var pacte_beat: Dictionary = TutorialScript.beat(int(tutorial.beat_index))
		if String(pacte_beat.get("id", "")) == "pacte_pick":
			var sealed_in := false
			for panel: ColorRect in pacte_overlay._mask_panels:
				if panel.size.x >= 160.0 and panel.size.y >= 320.0:
					sealed_in = true
			if sealed_in:
				failures.append("issue105: the Pacte pick is masked — nothing can be chosen")
			var hole: Rect2 = (anchor_hosts["pacte"] as Node).call("tutorial_anchor", "cards")
			if not hole.has_point(Vector2(40.0, 274.0)):
				failures.append("issue105: the Pacte hole misses the card slots: %s" % hole)
			break
		tutorial._advance()
		pacte_guard += 1
	tutorial.stop(false)

	# Skipping unwinds exactly like finishing does.
	tutorial.start()
	tutorial.attach(machine, "machine")
	tutorial._advance()
	tutorial.stop(false)
	if bool(tutorial.active) or bool(run_store.sandboxed) or bool(meta_store.sandboxed):
		failures.append("issue105: skipping left the tutorial half up")
	for prop in run_before:
		if not _deep_equal_variants(run_store.get(String(prop)), run_before[prop]):
			failures.append("issue105: skipping did not restore run state '%s'" % String(prop))
			break

	# A held run is the one refusal: the sandbox would have to snapshot over a live one.
	run_store.runPhase = "running"
	run_store.neurons = 5
	if tutorial.can_start():
		failures.append("issue105: the tutorial offered to start over a held run")
	run_store.runPhase = prev_phase
	for prop in run_before:
		run_store.set(String(prop), run_before[prop])
	meta_store._apply(meta_before)
	for kind in ["pacte", "dealer"]:
		(anchor_hosts[kind] as Node).queue_free()

# ── issue #52: the deck is gated and the run feeds the unlock counters ───────────

func _check_card_unlock_rules_52(machine: Node, run_store: Node, meta_store: Node, failures: Array) -> void:
	var saved_augments: Array = meta_store.unlockedAugmentCardIds.duplicate()
	var saved_powers: Array = meta_store.unlockedPowerCardIds.duplicate()
	var saved_pending: Array = meta_store.pendingCardUnlocks.duplicate(true)
	var saved_progress: Dictionary = meta_store.cardUnlockProgress.duplicate(true)

	meta_store.unlockedAugmentCardIds = CardUnlocks.default_ids("augment")
	meta_store.unlockedPowerCardIds = CardUnlocks.default_ids("power")
	meta_store.pendingCardUnlocks = []
	meta_store.cardUnlockProgress = {}

	# The Pacte only ever draws from the gated roster.
	for pool in PacteCards.POOLS:
		var unlocked: Array = meta_store.unlocked_augment_cards() if pool == "augment" \
			else meta_store.unlocked_power_cards()
		for card_id in unlocked:
			if not CardUnlocks.default_ids(pool).has(String(card_id)):
				failures.append("issue52 rules: %s starts outside the default %s roster" % [card_id, pool])
		for drawn_id in PacteCards.draw(pool, 7331, unlocked, [], 3):
			if not unlocked.has(String(drawn_id)):
				failures.append("issue52 rules: a %s draw offered a locked card" % pool)

	# Collection shows the unlock condition on a locked card, never its effect.
	var collection := (load("res://scenes/collection_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(collection)
	collection.show_card_detail("augment_adrenaline", "augment")
	var adrenaline := PacteCards.card("augment_adrenaline")
	if collection.modal_state() != "locked":
		failures.append("issue52 rules: a gated card did not open the LOCKED modal")
	if collection._modal_description.text == String(adrenaline["description"]) \
			or collection._modal_description.text.contains(String(adrenaline["name"])):
		failures.append("issue52 rules: the LOCKED modal leaked a gated card's metadata")
	if not collection._modal_description.text.contains("30"):
		failures.append("issue52 rules: the LOCKED modal did not show the unlock condition")
	collection.queue_free()

	# The run feeds the counters. Spin results are fed through the tracker directly:
	# the counters are the unit under test, not the parity-pinned spin math.
	run_store.runPairCount = 0
	run_store.runTripleCounts = {}
	run_store.scoreEarned = 2100
	run_store._track_spin_card_progress(_card_progress_result(["brain", "brain", "eye"], "pair", 40))
	if meta_store.card_unlock_progress(CardUnlocks.METRIC_PAIRS_IN_RUN) != 1:
		failures.append("issue52 rules: a paying pair was not counted")
	if not meta_store.unlockedAugmentCardIds.has("augment_reward_2"):
		failures.append("issue52 rules: a 2100 run did not unlock REWARD + II")
	run_store._track_spin_card_progress(_card_progress_result(["eye", "eye", "eye"], "triple", 90))
	run_store._track_spin_card_progress(_card_progress_result(["eye", "eye", "eye"], "triple", 90))
	if meta_store.card_unlock_progress(CardUnlocks.METRIC_SAME_TRIPLE_IN_RUN) != 2:
		failures.append("issue52 rules: repeated same-symbol triples were not counted")
	run_store._track_spin_card_progress(_card_progress_result(["pill", "pill", "pill"], "triple", 90))
	if meta_store.card_unlock_progress(CardUnlocks.METRIC_SAME_TRIPLE_IN_RUN) != 2:
		failures.append("issue52 rules: a different triple advanced the same-triple metric")
	run_store._track_spin_card_progress(_card_progress_result(["eye", "eye", "eye"], "triple", 90))
	if meta_store.card_unlock_progress(CardUnlocks.METRIC_SAME_TRIPLE_IN_RUN) != 3 \
			or not meta_store.unlockedAugmentCardIds.has("augment_tunnel_vision"):
		failures.append("issue52 rules: the third same triple did not unlock Tunnel Vision")
	run_store._track_spin_card_progress(_card_progress_result(["brain", "eye", "pill"], "miss", 0))
	if meta_store.card_unlock_progress(CardUnlocks.METRIC_PAIRS_IN_RUN) != 1:
		failures.append("issue52 rules: a losing spin counted as a pair")

	# Per-run counters reset with the run; the meta record keeps the best.
	run_store.reset_run_state()
	if int(run_store.runPairCount) != 0 or not (run_store.runTripleCounts as Dictionary).is_empty():
		failures.append("issue52 rules: per-run card counters survived a run reset")
	if meta_store.card_unlock_progress(CardUnlocks.METRIC_SAME_TRIPLE_IN_RUN) != 3:
		failures.append("issue52 rules: a run reset cleared the banked best-run metric")

	# Endings settle the win/death metrics.
	meta_store.cardUnlockProgress = {}
	meta_store.unlockedPowerCardIds = CardUnlocks.default_ids("power")
	meta_store.unlockedAugmentCardIds = CardUnlocks.default_ids("augment")
	run_store.flatlineResultCount = 0
	run_store.augmentedTier = ""
	meta_store._record_ending_card_progress("wealth")
	if meta_store.card_unlock_progress(CardUnlocks.METRIC_WINS) != 1 \
			or not meta_store.unlockedPowerCardIds.has("cheat"):
		failures.append("issue52 rules: a win did not unlock the Cheat power")
	if meta_store.card_unlock_progress(CardUnlocks.METRIC_FLAWLESS_WINS) != 1 \
			or not meta_store.unlockedAugmentCardIds.has("augment_win_boost"):
		failures.append("issue52 rules: a flatline-free win did not unlock COMBO")
	run_store.flatlineResultCount = 2
	meta_store.cardUnlockProgress = {}
	meta_store.unlockedAugmentCardIds = CardUnlocks.default_ids("augment")
	meta_store._record_ending_card_progress("wealth")
	if meta_store.card_unlock_progress(CardUnlocks.METRIC_FLAWLESS_WINS) != 0:
		failures.append("issue52 rules: a win after a flatline counted as flawless")
	meta_store._record_ending_card_progress("flatline")
	if not meta_store.unlockedAugmentCardIds.has("augment_glitch_2"):
		failures.append("issue52 rules: dying of flatline did not unlock GLITCH")
	run_store.flatlineResultCount = 0

	# An unlock earned during the run raises the blocking popup over the machine, but
	# only once the spin it was earned on has finished playing out.
	meta_store.cardUnlockProgress = {}
	meta_store.unlockedAugmentCardIds = CardUnlocks.default_ids("augment")
	meta_store.pendingCardUnlocks = []
	var popup := machine.get_node_or_null("UnlockCardPopup") as UnlockCardPopup
	if popup == null:
		failures.append("issue52 rules: the machine scene has no unlock popup attached")
	else:
		# The Collection check earlier in the run drove this same attached popup (both
		# popups answer card_unlocked). Put it back down so this block starts from a
		# quiet machine rather than a card left on screen there.
		popup._dismiss()
		var previous_spinning: bool = run_store.isSpinning
		run_store.isSpinning = true
		meta_store.add_card_unlock_progress(CardUnlocks.METRIC_CONSUMABLES_USED, 10, false)
		if popup.visible:
			failures.append("issue52 rules: an unlock interrupted a spin in progress")
		run_store.isSpinning = previous_spinning
		machine._maybe_present_card_unlocks()
		if not popup.visible or popup._card_id != "augment_hallucination":
			failures.append("issue52 rules: a held unlock was not raised once the spin ended")
		popup._on_continue_pressed()
		# An ending screen owns the scene until the player leaves it, so the card a
		# wealth/flatline run just earned is celebrated afterwards (on the menu). The
		# ending host is claimed before the commits that earn the card, so a live
		# _overlay is enough to hold the queue.
		var previous_overlay: Control = machine._overlay
		machine._overlay = Control.new()
		if machine._can_present_card_unlock():
			failures.append("issue52 rules: an unlock could interrupt an ending screen")
		machine._overlay.queue_free()
		machine._overlay = previous_overlay

	_restore_card_unlock_state(meta_store, saved_augments, saved_powers, saved_pending, saved_progress)

