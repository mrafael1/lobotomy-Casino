extends SceneTree
## Temporary audit helper: the tutorial's SKIP button in both languages. It is the smallest
## labelled button in the game (30x12), so it is the first place a longer language runs out
## of room — and a clipped label reads as a typo ("passer" losing its r) rather than as a
## layout problem, which is exactly how it was reported.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var overlay_script := load("res://ui/tutorial_overlay.gd") as Script
	for locale in ["en", "fr"]:
		TranslationServer.set_locale(locale)
		var overlay := overlay_script.new() as Control
		get_root().add_child(overlay)
		for i in 4:
			await process_frame
		var skip := overlay.get_node("SkipButton") as Button
		var font := skip.get_theme_font(&"font")
		var fs := skip.get_theme_font_size(&"font_size")
		var drawn := TranslationServer.translate(skip.text)
		var style := skip.get_theme_stylebox(&"normal")
		var inner := skip.size.x - style.content_margin_left - style.content_margin_right
		var w := font.get_string_size(drawn, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		print("\n[%s] button %s  text '%s' -> '%s' @font %d" % [
			locale, skip.size, skip.text, drawn, fs])
		print("  text width %.1f   content box %.1f (margins L%.1f R%.1f)   %s" % [
			w, inner, style.content_margin_left, style.content_margin_right,
			"CLIPPED by %.1fpx" % (w - inner) if w > inner else "fits"])
		print("  vertical: box top %.1f bottom %.1f in %.0fpx  -> label centre offset %+.1f" % [
			style.content_margin_top, style.content_margin_bottom, skip.size.y,
			(style.content_margin_top - style.content_margin_bottom) * 0.5])
		# A beat is raised so the overlay draws its mask behind the button, which is how the
		# player actually sees it — a bare button on black hides a clipping problem.
		overlay.show_beat("...", Rect2(20.0, 200.0, 40.0, 20.0), false)
		for i in 3:
			await process_frame
		var path := OS.get_environment("SHOT_%s" % locale.to_upper())
		if path != "":
			get_root().get_texture().get_image().save_png(path)
		get_root().remove_child(overlay)
		overlay.queue_free()
		await process_frame
	quit(0)
