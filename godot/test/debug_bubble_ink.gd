extends SceneTree
## Temporary audit helper: opens the real scenes, raises every bubble, then re-parents the
## finished bubble into an offscreen viewport with its background stripped so the only
## thing that renders is the text. Scanning that image gives the true glyph box, and the
## gap between it and the bubble's own rect is the centring error in source pixels.
##
## Reported as L/R (left and right gap) and T/B, plus dx/dy = the amount the text would
## have to move to be centred. Anything past ~1px reads as off-centre at 160x320.

const ALPHA_MIN := 0.2
const PAD := 12

var _rows: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	# SHOT_LOCALE lets the same geometry be compared across languages: these bubbles size
	# themselves from the string they measure, so a longer language grows them.
	var locale := OS.get_environment("SHOT_LOCALE")
	if locale != "":
		TranslationServer.set_locale(locale)
	await _machine()
	await _pacte()
	await _dealer()
	await _odds()
	await _tutorial()
	await _upgrades()
	print("\n=== BUBBLE INK CENTRING (source px) ===")
	print("%-24s %-12s %-14s %s" % ["case", "bubble", "ink", "gaps"])
	for r in _rows:
		print(r)
	quit(0)

# ── measurement ──────────────────────────────────────────────────────────────────────

## `bubble` is the rect the text is supposed to be centred in. `hide_nodes` are the
## decorations (panel fills, bubble art) stripped so only glyphs render.
func _ink(tag: String, bubble: Control, hide_nodes: Array = []) -> void:
	if bubble == null:
		_rows.append("%-24s MISSING" % tag)
		return
	var size := bubble.size
	var parent := bubble.get_parent()
	var idx := bubble.get_index()
	var old_pos := bubble.position
	for n in hide_nodes:
		if n is Panel:
			(n as Panel).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		elif n is CanvasItem:
			(n as CanvasItem).visible = false
	var vp := SubViewport.new()
	vp.size = Vector2i(ceili(size.x) + PAD * 2, ceili(size.y) + PAD * 2)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	get_root().add_child(vp)
	if parent != null:
		parent.remove_child(bubble)
	bubble.position = Vector2(PAD, PAD)
	# z_index inside the probe viewport is irrelevant and only risks odd draw order.
	bubble.z_index = 0
	vp.add_child(bubble)
	await process_frame
	await process_frame
	var box := _ink_box(vp.get_texture().get_image())
	vp.remove_child(bubble)
	bubble.position = old_pos
	if parent != null:
		parent.add_child(bubble)
		parent.move_child(bubble, idx)
	get_root().remove_child(vp)
	vp.queue_free()
	if box.size == Vector2.ZERO:
		_rows.append("%-24s %-12s NO INK" % [tag, _v(size)])
		return
	var l := box.position.x - float(PAD)
	var t := box.position.y - float(PAD)
	var r := size.x - (box.position.x - float(PAD) + box.size.x)
	var b := size.y - (box.position.y - float(PAD) + box.size.y)
	var flag := ""
	if absf(r - l) > 2.0 or absf(b - t) > 2.0:
		flag = "   <-- OFF CENTRE"
	if l < 0.0 or t < 0.0 or r < 0.0 or b < 0.0:
		flag = "   <-- SPILLS OUT"
	_rows.append("%-24s %-12s %-14s L%.0f R%.0f T%.0f B%.0f  dx%+.1f dy%+.1f%s" % [
		tag, _v(size), _v(box.size), l, r, t, b,
		(r - l) * 0.5, (b - t) * 0.5, flag])

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

# ── the scenes ───────────────────────────────────────────────────────────────────────

func _machine() -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	get_root().get_node("MetaStateStore").pendingCardUnlocks = []
	run_store.reset_run_state()
	run_store.start_new_run([], { "cons_cigarette": 1, "cons_tea": 2 }, false)
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

	var badge := scene.get_node_or_null("AugmentedBadge") as Button
	if badge != null:
		badge.button_down.emit()
		await process_frame
		var p := scene.get_node_or_null("AugmentedPopup") as Control
		if p != null:
			await _ink("M1 suit (7 rows)", p, [p.get_child(0)])
		scene._augments.hide_augmented_popup()
	await process_frame

	scene._refresh_boost_indicators()
	scene._boosts.on_pressed(0)
	await process_frame
	var ip := scene.get_node_or_null("ItemInfoPopup") as Control
	if ip != null:
		await _ink("M1 item (3 rows)", ip, [ip.get_child(0)])
	scene._hide_item_info_popup()
	await process_frame

	# A one-row description: the shape the height maths is most likely to get wrong.
	var one: Control = scene._make_info_bubble("OneRow", "COCKTAIL", Color.CYAN, Color.WHITE, 0.0)
	scene.add_child(one)
	await process_frame
	await _ink("M1 one row", one, [one.get_child(0)])
	one.queue_free()
	await process_frame

	scene._show_score_table()
	for i in 4:
		await process_frame
	if not scene._score_table.pct_buttons().is_empty():
		scene._score_table.show_pct_popup("brain", scene._score_table.pct_buttons()[0])
		await process_frame
		var pp := scene._score_table.info_popup() as Control
		if pp != null:
			await _ink("M2 pct", pp.get_child(0) as Control, [pp.get_child(0)])
		scene._score_table.hide_info_popup()
	await process_frame
	if not scene._score_table.info_buttons().is_empty():
		scene._score_table.show_info_popup("flatline", scene._score_table.info_buttons()[0])
		await process_frame
		var tp := scene._score_table.info_popup() as Control
		if tp != null:
			# The blurb's panel is child 0; the per-line labels are siblings of it.
			var bg := tp.get_child(0) as Panel
			bg.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			tp.size = bg.size
			await _ink("M3 triple (2 rows)", tp, [])
		scene._score_table.hide_info_popup()
	get_root().remove_child(scene)
	scene.queue_free()
	await process_frame

func _pacte() -> void:
	var scene := (load("res://scenes/pacte_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 8:
		await process_frame
	var bubble := scene.get_node_or_null("OddsTableDescriptionBubble") as Panel
	if bubble != null:
		# Every real card, through the real preview path: the longest blurbs are the ones
		# that can wrap past the bottom of a fixed-height bubble.
		var ids: Array[String] = PacteCards.augment_ids()
		ids.append_array(PacteCards.power_ids())
		for card_id in ids:
			scene._offer_ids.clear()
			scene._offer_ids.append(card_id)
			scene._preview_card(card_id)
			bubble.visible = true
			await process_frame
			await _ink("P1 %s" % card_id, bubble, [bubble])
	get_root().remove_child(scene)
	scene.queue_free()
	await process_frame

func _dealer() -> void:
	var scene := (load("res://scenes/in_run_dealer_offer.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 8:
		await process_frame
	var bubble := scene._speech_bubble as Control
	if bubble != null:
		bubble.visible = true
		scene._set_speech_text("I'VE GOT SOMETHING FOR YA")
		await process_frame
		_body_rect(scene)
		await _ink("D1 speech body", bubble, [scene._bubble_graphic])
		scene._set_speech_hints("cons_cigarette")
		await process_frame
		await _ink("D1 speech hints", bubble, [scene._bubble_graphic])
		scene._set_speech_hints("cons_tea")
		await process_frame
		await _ink("D1 hints (short)", bubble, [scene._bubble_graphic])
	get_root().remove_child(scene)
	scene.queue_free()
	await process_frame

## Where the WHITE BODY of the drawn speech bubble actually is, in the control's own units.
## The text is centred against a rect the code assumes; this says what the art draws.
func _body_rect(scene: Node) -> void:
	var tex: Texture2D = scene._bubble_graphic.texture
	if tex == null:
		return
	var img := tex.get_image()
	var ctrl_size: Vector2 = scene._speech_bubble.size
	var sx := ctrl_size.x / float(img.get_width())
	var sy := ctrl_size.y / float(img.get_height())
	# The body is the bubble's opaque light fill; the tail is a narrow spur under it.
	var top := -1
	var bottom := -1
	var left := img.get_width()
	var right := -1
	for y in img.get_height():
		var run := 0
		var first := -1
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and c.r > 0.7 and c.g > 0.7 and c.b > 0.7:
				if first < 0:
					first = x
				run += 1
		# A body row is wide; the tail's rows are only a few px across.
		if run > img.get_width() / 3:
			if top < 0:
				top = y
			bottom = y
			left = mini(left, first)
			right = maxi(right, first + run - 1)
	if top < 0:
		return
	_rows.append("%-24s art body x%.1f..%.1f y%.1f..%.1f (control units)" % [
		"D1 bubble art", float(left) * sx, float(right + 1) * sx,
		float(top) * sy, float(bottom + 1) * sy])

func _odds() -> void:
	var overlay := (load("res://scenes/odds_table_overlay.tscn") as PackedScene).instantiate()
	get_root().add_child(overlay)
	for i in 8:
		await process_frame
	for t in ["12.5%", "8.3%", "+1.4%"]:
		var bubble := overlay._make_pct_bubble(t, "brain") as Control
		get_root().add_child(bubble)
		await process_frame
		await process_frame
		await _ink("O1 pct %s" % t, bubble, [bubble.get_node("PctBubble")])
		bubble.queue_free()
		await process_frame
	get_root().remove_child(overlay)
	overlay.queue_free()
	await process_frame

func _upgrades() -> void:
	var scene := (load("res://scenes/upgrades_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 10:
		await process_frame
	var bubble := scene._description_bubble as Control
	# Make the panel invisible WITHOUT replacing it: a PanelContainer lays its child out
	# from the stylebox's content margins, so swapping in an empty box would move the text
	# we are trying to measure.
	var clear := bubble.get_theme_stylebox(&"panel").duplicate() as StyleBox
	if clear is StyleBoxFlat:
		var flat := clear as StyleBoxFlat
		flat.bg_color = Color(0, 0, 0, 0)
		flat.border_color = Color(0, 0, 0, 0)
		flat.shadow_color = Color(0, 0, 0, 0)
		flat.draw_center = false
	bubble.add_theme_stylebox_override(&"panel", clear)
	for t in ["Select a lab terminal.", "Lock a reel before spinning.",
			"Removes one reel. Visible pairs count as triples, but rewards are cut by 70%."]:
		scene._description_label.text = "[center]%s[/center]" % t
		for i in 3:
			await process_frame
		await _ink("U1 upgrades desc", bubble, [])
	get_root().remove_child(scene)
	scene.queue_free()
	await process_frame

func _tutorial() -> void:
	var overlay := (load("res://ui/tutorial_overlay.gd") as Script).new() as Control
	get_root().add_child(overlay)
	for i in 4:
		await process_frame
	for beat_index in TutorialScript.count():
		var text := String(TutorialScript.beat(beat_index)["text"])
		overlay.show_beat(text, Rect2(20.0, 200.0, 40.0, 20.0), false)
		await process_frame
		var box := overlay.get_node("CoachBox") as Control
		await _ink("T1 beat %02d" % beat_index, box, [box.get_node("Panel")])
	overlay._show_skip_confirm()
	await process_frame
	var confirm := overlay.get_node("SkipConfirm") as Control
	var panel := confirm.get_child(1) as Panel
	panel.get_node("YESButton").visible = false
	panel.get_node("NOButton").visible = false
	await _ink("T2 skip-ask", panel, [panel])
	get_root().remove_child(overlay)
	overlay.queue_free()
	await process_frame
