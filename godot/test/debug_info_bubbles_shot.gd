extends SceneTree
## Temporary debug helper: open the machine mid-run on a joker Augmented run and hold each
## of the three explain-this controls in turn, saving one shot per bubble. What is being
## reviewed is placement — the suit badge's new home left of the wealth plate, and whether
## each description reads as attached to the icon that raised it. Never saves meta.
##
## SHOT_SUIT / SHOT_AUGMENT / SHOT_ITEM name the three files.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	get_root().get_node("MetaStateStore").pendingCardUnlocks = []
	run_store.reset_run_state()
	run_store.start_new_run([], { "cons_cigarette": 1, "cons_tea": 2 }, false)
	# Joker: every restriction is listed, so the suit bubble is at its widest and tallest.
	run_store.augmentedTier = "joker"
	run_store.scoreEarned = 850
	run_store.wealthTargetIndex = 4
	run_store.lucidityCoins = 120
	run_store.neurons = 9
	run_store.dealerCountdown = 4
	run_store.cocktailBoostSpins = 3
	run_store.potionSpins = 5
	run_store.selectedAugmentCardIds = ["augment_reward_1", "augment_book"]
	run_store.ownedPowerIds = ["swap", "heart", "cheat"]
	run_store.abilitiesUsed = []
	run_store.lastResult = {
		"reels": ["brain", "eye", "pill"], "winType": "miss",
		"scoreEarned": 0, "coinsEarned": 0, "freeSpinsGranted": 0, "isFreeSpin": false,
	}
	var scene := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 10:
		await process_frame

	await _shot(scene, "SHOT_SUIT", func() -> void:
		var badge := scene.get_node_or_null("AugmentedBadge") as Button
		if badge != null:
			badge.button_down.emit())

	await _shot(scene, "SHOT_AUGMENT", func() -> void:
		if scene._augments.pacte_badge() != null:
			scene._augments.pacte_badge().button_down.emit())

	await _shot(scene, "SHOT_ITEM", func() -> void:
		scene._refresh_boost_indicators()
		scene._boosts.on_pressed(0))
	quit(0)

## Raises one bubble, captures, then clears every bubble so the next shot starts clean.
func _shot(scene: Node, env_var: String, raise: Callable) -> void:
	raise.call()
	for i in 3:
		await process_frame
	var path := OS.get_environment(env_var)
	if path != "":
		get_root().get_texture().get_image().save_png(path)
	scene._augments.hide_augmented_popup()
	scene._augments.hide_pacte_popup()
	scene._hide_item_info_popup()
	for i in 2:
		await process_frame
