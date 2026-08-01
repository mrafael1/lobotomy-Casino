extends SceneTree
## Temporary debug helper: the settings MUTE toggle in both states. With the button plate
## removed, the tick is the ONLY thing that says whether mute is on, so both states have to
## be checked — an unchecked box and a checked one must read differently at a glance.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := (load("res://scenes/settings_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 10:
		await process_frame
	var check := scene.get_node("Panel/Rows/MuteCheck") as CheckBox
	for state in [false, true]:
		check.set_pressed_no_signal(state)
		for i in 4:
			await process_frame
		var path := OS.get_environment("SHOT_ON" if state else "SHOT_OFF")
		if path != "":
			get_root().get_texture().get_image().save_png(path)
	print("mute row rect %s size %s   icon_max_width %d" % [
		check.position, check.size, check.get_theme_constant(&"icon_max_width")])
	# The plate is what we removed; prove no stylebox is drawing anything any more.
	for state in ["normal", "hover", "pressed"]:
		var sb := check.get_theme_stylebox(state)
		print("  %-8s stylebox: %s" % [state, sb.get_class()])
	quit(0)
