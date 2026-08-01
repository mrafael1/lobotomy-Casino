extends SceneTree
## Temporary debug helper: the OPTIONS overlay with its five rows, so the panel resize that
## made room for TUTORIAL can be checked against the contour drawn behind it.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().get_node("RunStateStore").reset_run_state()
	var overlay := (load("res://scenes/options_overlay.tscn") as PackedScene).instantiate()
	get_root().add_child(overlay)
	for i in 8:
		await process_frame
	overlay.show_overlay()
	for i in 4:
		await process_frame
	var path := OS.get_environment("SHOT_OPTIONS")
	if path != "":
		get_root().get_texture().get_image().save_png(path)
	var panel := overlay.get_node("Panel") as Control
	var contour := overlay.get_node("Contour") as Control
	var menu := overlay.get_node("Panel/Menu") as Control
	print("panel  %s size %s" % [panel.position, panel.size])
	print("contour %s size %s" % [contour.position, contour.size])
	print("menu min %s" % menu.get_combined_minimum_size())
	print("close  %s" % (overlay.get_node("CloseButton") as Control).position)
	print("tutorial can_start=%s disabled=%s" % [
		get_root().get_node("Tutorial").can_start(),
		(overlay.get_node("Panel/Menu/TutorialButton") as Button).disabled])
	quit(0)
