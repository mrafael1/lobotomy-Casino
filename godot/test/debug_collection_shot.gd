extends SceneTree
## Debug helper (issue #52): open the Collection catalog with a couple of cards
## re-locked, plus the unlock popup, and save screenshots for visual inspection.
## Never saves meta.
##
##   SHOT_PATH=/tmp/collection.png SHOT_PATH_LOCKED_MODAL=/tmp/locked.png \
##   SHOT_PATH_POPUP=/tmp/popup.png godot --path godot -s res://test/debug_collection_shot.gd

const LOCKED_AUGMENT := "augment_book"
const LOCKED_POWER := "heart"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var meta: Node = get_root().get_node("MetaStateStore")
	var augments: Array = PacteCards.augment_ids()
	augments.erase(LOCKED_AUGMENT)
	var powers: Array = PacteCards.power_ids()
	powers.erase(LOCKED_POWER)
	meta.unlockedAugmentCardIds = augments
	meta.unlockedPowerCardIds = powers
	meta.pendingCardUnlocks = []

	var scene := (load("res://scenes/collection_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 8:
		await process_frame
	_save(OS.get_environment("SHOT_PATH"))

	scene.highlight_card("swap")
	for i in 4:
		await process_frame
	_save(OS.get_environment("SHOT_PATH_POWERS"))

	scene.show_card_detail(LOCKED_AUGMENT, "augment")
	for i in 4:
		await process_frame
	_save(OS.get_environment("SHOT_PATH_LOCKED_MODAL"))
	scene.queue_free()

	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	var popup := UnlockCardPopup.attach_to(host)
	meta.unlock_card(LOCKED_AUGMENT, "augment", false)
	# Wall time, not frames: the reveal flip is time-based and an uncapped headless
	# frame rate would otherwise screenshot the card edge-on mid-flip.
	await create_timer(1.0).timeout
	await process_frame
	_save(OS.get_environment("SHOT_PATH_POPUP"))
	if popup != null:
		popup.queue_free()
	quit(0)

func _save(path: String) -> void:
	if path.is_empty():
		return
	get_root().get_texture().get_image().save_png(path)
