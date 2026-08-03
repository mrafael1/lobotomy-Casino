extends SceneTree
## Temporary debug helper: open the machine scene's score table and save a
## screenshot (full view + close-button crop) for visual inspection.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var machine := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(machine)
	for i in 5:
		await process_frame
	machine._show_score_table()
	for i in 10:
		await process_frame
	if OS.get_environment("PCT_SYMBOL") != "" and not machine._score_table.pct_buttons().is_empty():
		var idx := Symbols.BASE_SYMBOL_CYCLE.find(StringName(OS.get_environment("PCT_SYMBOL")))
		machine._score_table.show_pct_popup(OS.get_environment("PCT_SYMBOL"),
			machine._score_table.pct_buttons()[maxi(idx, 0)])
	elif not machine._score_table.info_buttons().is_empty():
		var forced := OS.get_environment("FLATLINE_COUNT")
		if forced != "":
			get_root().get_node("RunStateStore").flatlineResultCount = int(forced)
		machine._score_table.show_info_popup("flatline", machine._score_table.info_buttons()[5])
	for i in 5:
		await process_frame
	var popup: Control = machine._score_table.info_popup()
	if popup != null:
		print("popup pos=", popup.position, " size=", popup.size)
		for c in popup.get_children():
			print("  ", c.get_class(), " ", c.name, " pos=", c.position, " size=", c.size)
	var img: Image = get_root().get_texture().get_image()
	img.save_png(OS.get_environment("SHOT_PATH"))
	quit(0)
