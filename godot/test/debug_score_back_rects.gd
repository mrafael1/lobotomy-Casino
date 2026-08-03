extends SceneTree
## Temporary audit helper: the score table's BACK close button, rect by rect. Its label is a
## hand-placed child rather than the Button's own text, so the question "why is it 3px right
## and 4px high" is answered by the numbers, not by reading the construction code.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	run_store.reset_run_state()
	run_store.start_new_run([], {}, false)
	var scene := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 10:
		await process_frame
	scene._show_score_table()
	for i in 5:
		await process_frame
	var close := scene._score_overlay.get_node("CloseButton") as Button
	var label := close.get_child(0) as Label
	var font := label.get_theme_font(&"font")
	var fs := label.get_theme_font_size(&"font_size")
	print("\n=== score-table BACK ===")
	print("button   pos %s size %s  text %s" % [close.position, close.size, close.text])
	print("label    pos %s size %s  text '%s'" % [label.position, label.size, label.text])
	print("label    halign %d valign %d  font_size %d" % [
		label.horizontal_alignment, label.vertical_alignment, fs])
	print("text     measured width %.1f  height %.1f" % [
		font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x,
		font.get_height(fs)])
	print("centred x would be %.1f ; label spans %.1f..%.1f" % [
		(close.size.x - font.get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x) * 0.5,
		label.position.x, label.position.x + label.size.x])
	quit(0)
