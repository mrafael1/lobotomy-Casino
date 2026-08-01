extends SceneTree
## Temporary debug helper: renders a scene under a chosen locale so the translated copy can
## be checked against the boxes it has to fit in. SHOT_LOCALE picks the language, SHOT_PATH
## the file. Also prints, for every Label and Button on screen, the source string next to
## what actually got drawn and whether it overflowed its own rect — French runs longer than
## English and the canvas is 160x320, so overflow is the thing to watch.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var locale := OS.get_environment("SHOT_LOCALE")
	if locale != "":
		TranslationServer.set_locale(locale)
	get_root().get_node("RunStateStore").reset_run_state()
	var scene_path := OS.get_environment("SHOT_SCENE")
	if scene_path == "":
		scene_path = "res://scenes/options_overlay.tscn"
	var scene := (load(scene_path) as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 12:
		await process_frame
	if scene.has_method("show_overlay"):
		scene.call("show_overlay")
	for i in 6:
		await process_frame
	print("\n=== %s @ %s ===" % [scene_path, TranslationServer.get_locale()])
	_report(scene)
	var path := OS.get_environment("SHOT_PATH")
	if path != "":
		get_root().get_texture().get_image().save_png(path)
	quit(0)

## Walks the tree and flags any Label/Button whose translated text is wider than the box it
## was given. A Label without clip_text just spills; one with it silently loses characters.
func _report(node: Node) -> void:
	for child in node.get_children():
		var source := ""
		var control := child as Control
		if child is Label:
			source = (child as Label).text
		elif child is Button:
			source = (child as Button).text
		if source != "" and control != null and control.visible:
			var drawn := TranslationServer.translate(source)
			var font := control.get_theme_font(&"font")
			var fs := control.get_theme_font_size(&"font_size")
			if font != null:
				var w := font.get_string_size(drawn, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var room := control.size.x
				var flag := ""
				if w > room + 0.5:
					flag = "   <-- OVERFLOWS by %.0fpx" % (w - room)
				if source != drawn or flag != "":
					print("  %-34s -> %-34s %.0f/%.0f%s" % [
						source.replace("\n", "\\n"), drawn.replace("\n", "\\n"),
						w, room, flag])
		_report(child)
