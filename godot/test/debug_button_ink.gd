extends SceneTree
## Temporary audit helper: where a Button's LABEL actually lands inside the button.
##
## Same method as test/debug_bubble_ink.gd, applied to buttons: strip the plate to an empty
## stylebox so only glyphs render, shoot the button into an offscreen viewport, and scan for
## ink. The gap between the ink and the button's own rect is the centring error in source
## pixels — dx/dy is how far the text would have to move to sit in the middle.
##
## A Button draws its own text (there is no child Label to interrogate), so rendering is the
## only way to find out where the glyphs really are.

const ALPHA_MIN := 0.2
const PAD := 12

var _rows: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().get_node("RunStateStore").reset_run_state()
	await _machine()
	await _odds()
	await _settings()
	await _options()
	print("\n=== BUTTON LABEL CENTRING (source px) ===")
	print("%-30s %-10s %-12s %s" % ["button", "size", "ink", "gaps"])
	for r in _rows:
		print(r)
	quit(0)

func _measure(tag: String, button: Button) -> void:
	if button == null:
		_rows.append("%-30s MISSING" % tag)
		return
	var size := button.size
	if size == Vector2.ZERO:
		size = button.custom_minimum_size
	var parent := button.get_parent()
	var idx := button.get_index()
	var old_pos := button.position
	# FIRST: where the drawn plate is inside the button's rect. The text can be dead centre
	# of the rect and still look off if the authored art does not fill that rect evenly —
	# what the eye judges against is the plate, not the invisible control box.
	# Some buttons draw their label as a CHILD Label rather than as Button.text, so both
	# have to go dark for the plate pass or the "plate" box would include the very text we
	# are trying to measure against it.
	var label := button.text
	button.text = ""
	var hidden: Array[CanvasItem] = []
	for child in button.get_children():
		if child is CanvasItem and (child as CanvasItem).visible:
			hidden.append(child as CanvasItem)
			(child as CanvasItem).visible = false
	var plate := await _shoot(button, size)
	button.text = label
	for item in hidden:
		item.visible = true
	# THEN: the label alone, with every plate stripped to an empty box.
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var vp := SubViewport.new()
	vp.size = Vector2i(ceili(size.x) + PAD * 2, ceili(size.y) + PAD * 2)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	get_root().add_child(vp)
	if parent != null:
		parent.remove_child(button)
	button.position = Vector2(PAD, PAD)
	button.z_index = 0
	vp.add_child(button)
	button.size = size
	await process_frame
	await process_frame
	var box := _ink_box(vp.get_texture().get_image())
	vp.remove_child(button)
	button.position = old_pos
	if parent != null:
		parent.add_child(button)
		parent.move_child(button, idx)
	get_root().remove_child(vp)
	vp.queue_free()
	if box.size == Vector2.ZERO:
		_rows.append("%-30s %-10s NO INK" % [tag, _v(size)])
		return
	var l := box.position.x - float(PAD)
	var t := box.position.y - float(PAD)
	var r := size.x - (box.position.x - float(PAD) + box.size.x)
	var b := size.y - (box.position.y - float(PAD) + box.size.y)
	var flag := ""
	if absf(r - l) > 1.0 or absf(b - t) > 1.0:
		flag = "   <-- off centre in RECT"
	# Against the plate the player actually sees, which is the judgement that matters.
	var plate_note := "  plate n/a"
	if plate.size != Vector2.ZERO:
		var ink_cx := box.position.x + box.size.x * 0.5
		var ink_cy := box.position.y + box.size.y * 0.5
		var plate_cx := plate.position.x + plate.size.x * 0.5
		var plate_cy := plate.position.y + plate.size.y * 0.5
		plate_note = "  plate %s@%.0f,%.0f  vs-plate dx%+.1f dy%+.1f" % [
			_v(plate.size), plate.position.x - float(PAD), plate.position.y - float(PAD),
			plate_cx - ink_cx, plate_cy - ink_cy]
		if absf(plate_cx - ink_cx) > 1.0 or absf(plate_cy - ink_cy) > 1.0:
			flag = "   <-- OFF CENTRE ON PLATE"
	_rows.append("%-30s %-10s %-12s L%.0f R%.0f T%.0f B%.0f  dx%+.1f dy%+.1f%s%s" % [
		tag, _v(size), _v(box.size), l, r, t, b,
		(r - l) * 0.5, (b - t) * 0.5, plate_note, flag])

## Renders `button` as it stands into an offscreen viewport and returns its ink box, in
## viewport coordinates (so PAD still has to come off). Used for the plate pass, where the
## button keeps its real stylebox and only its text has been emptied.
func _shoot(button: Button, size: Vector2) -> Rect2:
	var parent := button.get_parent()
	var idx := button.get_index()
	var old_pos := button.position
	var vp := SubViewport.new()
	vp.size = Vector2i(ceili(size.x) + PAD * 2, ceili(size.y) + PAD * 2)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	get_root().add_child(vp)
	if parent != null:
		parent.remove_child(button)
	button.position = Vector2(PAD, PAD)
	button.z_index = 0
	vp.add_child(button)
	button.size = size
	await process_frame
	await process_frame
	var box := _ink_box(vp.get_texture().get_image())
	vp.remove_child(button)
	button.position = old_pos
	if parent != null:
		parent.add_child(button)
		parent.move_child(button, idx)
	get_root().remove_child(vp)
	vp.queue_free()
	return box

func _ink_box(img: Image) -> Rect2:
	var min_x := img.get_width()
	var min_y := img.get_height()
	var max_x := -1
	var max_y := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a < ALPHA_MIN:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2()
	return Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _v(v: Vector2) -> String:
	return "%.0fx%.0f" % [v.x, v.y]

func _machine() -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	run_store.start_new_run([], {}, false)
	var scene := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 10:
		await process_frame
	await _measure("machine TABLES", scene.get_node_or_null("ScoreButton") as Button)
	# The score table's own BACK: its label is a child Label with a hand-tuned offset, so
	# it is measured separately from the buttons whose text the Button itself draws.
	scene._show_score_table()
	for i in 4:
		await process_frame
	var close := scene._score_overlay.get_node_or_null("CloseButton") as Button \
		if scene._score_overlay != null else null
	await _measure("score-table BACK", close)
	get_root().remove_child(scene)
	scene.queue_free()
	await process_frame

func _odds() -> void:
	var overlay := (load("res://scenes/odds_table_overlay.tscn") as PackedScene).instantiate()
	get_root().add_child(overlay)
	for i in 10:
		await process_frame
	# The DONE button is rebuilt by the overlay's own refresh pass, so ask for it after it.
	if overlay.has_method("_refresh"):
		overlay.call("_refresh")
		await process_frame
	await _measure("odds DONE", overlay._done_button as Button)
	get_root().remove_child(overlay)
	overlay.queue_free()
	await process_frame

func _settings() -> void:
	var scene := (load("res://scenes/settings_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 8:
		await process_frame
	await _measure("settings BACK", scene.get_node_or_null("Panel/Rows/BackButton") as Button)
	get_root().remove_child(scene)
	scene.queue_free()
	await process_frame

## The OPTIONS rows use the same shared plate helper, so they say whether an error is in
## these three buttons or in the helper every button in the game goes through.
func _options() -> void:
	var overlay := (load("res://scenes/options_overlay.tscn") as PackedScene).instantiate()
	get_root().add_child(overlay)
	for i in 8:
		await process_frame
	overlay.show_overlay()
	await process_frame
	for row in ["ScoresButton", "SettingsButton", "MenuButton"]:
		await _measure("options %s" % row,
			overlay.get_node_or_null("Panel/Menu/%s" % row) as Button)
	get_root().remove_child(overlay)
	overlay.queue_free()
	await process_frame
