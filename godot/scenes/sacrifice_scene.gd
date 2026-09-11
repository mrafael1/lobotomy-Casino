extends Control

## Between-machine Sacrifice route. The backdrop supplies the diegetic ritual
## table; this controller supplies the small, readable offering pieces and keeps
## presentation separate from the authoritative resource transaction.

const CANVAS_SIZE := Vector2(160.0, 320.0)
const CYAN := Color(0.42, 1.0, 0.95)
const GOLD := Color(1.0, 0.84, 0.38)
const HOT_GOLD := Color(1.0, 0.95, 0.62)
const MUTED := Color(0.62, 0.70, 0.78)
const ROSE := Color(1.0, 0.35, 0.66)
const RED := Color(1.0, 0.35, 0.42)
const INK := Color(0.055, 0.035, 0.105)
const DEEP_INK := Color(0.025, 0.02, 0.06)

const OFFERING_SLOTS := [
	Vector2(5.0, 230.0), Vector2(82.0, 230.0),
	Vector2(5.0, 259.0), Vector2(82.0, 259.0),
]
const OFFERING_SIZE := Vector2(73.0, 25.0)
const BALANCE_TOKEN_POSITION := Vector2(28.0, 156.0)


## A compact diegetic offering piece. It is a Control rather than a themed Button
## so the interaction can look like a tray of objects instead of a vertical menu.
class RitualToken extends Control:
	signal chosen(option_id: String)

	var option_id := ""
	var option_kind := ""
	var caption := "OFFERING"
	var detail := ""
	var token_font: Font = null
	var accent := Color.WHITE
	var selected := false
	var dimmed := false
	var enabled := true
	var _hovered := false
	var _pressed := false

	func configure(id: String, kind: String, title: String, subtitle: String,
			font: Font, color: Color) -> void:
		option_id = id
		option_kind = kind
		caption = title
		detail = subtitle
		token_font = font
		accent = color
		queue_redraw()

	func set_visual_state(is_selected: bool, is_dimmed: bool, is_enabled: bool) -> void:
		selected = is_selected
		dimmed = is_dimmed
		enabled = is_enabled
		mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(73.0, 25.0)

	func _gui_input(event: InputEvent) -> void:
		if not enabled:
			accept_event()
			return
		var mouse_event := event as InputEventMouseButton
		if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var was_pressed := _pressed
			_pressed = mouse_event.pressed
			if not mouse_event.pressed and was_pressed:
				chosen.emit(option_id)
			queue_redraw()
			accept_event()
			return
		var touch_event := event as InputEventScreenTouch
		if touch_event != null:
			var was_pressed := _pressed
			_pressed = touch_event.pressed
			if not touch_event.pressed and was_pressed:
				chosen.emit(option_id)
			queue_redraw()
			accept_event()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER:
			_hovered = true
			queue_redraw()
		elif what == NOTIFICATION_MOUSE_EXIT:
			_hovered = false
			_pressed = false
			queue_redraw()

	func _draw() -> void:
		var border := accent
		var fill := Color(DEEP_INK.r, DEEP_INK.g, DEEP_INK.b, 0.92)
		var text_color := HOT_GOLD
		if dimmed:
			border = border.darkened(0.55)
			fill = Color(DEEP_INK.r, DEEP_INK.g, DEEP_INK.b, 0.74)
			text_color = MUTED.darkened(0.25)
		elif not enabled:
			border = MUTED.darkened(0.35)
			text_color = MUTED
		elif _pressed:
			fill = Color(ROSE.r, ROSE.g, ROSE.b, 0.28)
			border = HOT_GOLD
		elif _hovered or selected:
			fill = Color(accent.r, accent.g, accent.b, 0.18)
			border = HOT_GOLD if selected else accent.lightened(0.18)

		draw_rect(Rect2(0.0, 0.0, size.x, size.y), fill)
		draw_rect(Rect2(0.5, 0.5, size.x - 1.0, size.y - 1.0), border, false, 1.0)
		if selected:
			draw_line(Vector2(2.0, 3.0), Vector2(2.0, 8.0), HOT_GOLD, 1.0)
			draw_line(Vector2(2.0, 3.0), Vector2(7.0, 3.0), HOT_GOLD, 1.0)
			draw_line(Vector2(size.x - 2.0, size.y - 3.0),
				Vector2(size.x - 7.0, size.y - 3.0), HOT_GOLD, 1.0)
			draw_line(Vector2(size.x - 2.0, size.y - 3.0),
				Vector2(size.x - 2.0, size.y - 8.0), HOT_GOLD, 1.0)

		_draw_symbol(Vector2(9.0, size.y * 0.5), border)
		if token_font != null:
			draw_string(token_font, Vector2(19.0, 10.0), caption,
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 21.0, 5, text_color)
			draw_string(token_font, Vector2(19.0, 19.0), detail,
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 21.0, 4, border)

	func _draw_symbol(center: Vector2, color: Color) -> void:
		match option_kind:
			"coins":
				draw_circle(center + Vector2(-2.0, -1.0), 4.0, color)
				draw_circle(center + Vector2(2.0, 2.0), 4.0, color.darkened(0.3))
				draw_line(center + Vector2(-4.0, -1.0), center + Vector2(0.0, -1.0),
					DEEP_INK, 1.0)
			"neuron":
				draw_circle(center + Vector2(-3.0, -2.0), 2.5, color)
				draw_circle(center + Vector2(3.0, 2.0), 2.5, color)
				draw_line(center + Vector2(-1.0, -1.0), center + Vector2(1.0, 1.0), color, 1.0)
			"augment":
				var diamond := PackedVector2Array([
					center + Vector2(0.0, -6.0), center + Vector2(4.0, 0.0),
					center + Vector2(0.0, 6.0), center + Vector2(-4.0, 0.0),
				])
				draw_colored_polygon(diamond, color)
				draw_line(center + Vector2(-2.0, 0.0), center + Vector2(2.0, 0.0), DEEP_INK, 1.0)
			"power":
				var bolt := PackedVector2Array([
					center + Vector2(1.0, -7.0), center + Vector2(-4.0, 0.0),
					center + Vector2(-1.0, 0.0), center + Vector2(-3.0, 7.0),
					center + Vector2(4.0, -1.0), center + Vector2(1.0, -1.0),
				])
				draw_colored_polygon(bolt, color)
			_:
				draw_circle(center, 4.0, color)


var _font: Font = null
var _backdrop: Sprite2D = null
var _options_layer: Control = null
var _wallet: Label = null
var _progress: Label = null
var _preview: Label = null
var _status: Label = null
var _roulette_label: Label = null
var _confirm: Button = null
var _leave: Button = null
var _selected_option_id := ""
var _options_by_id: Dictionary = {}
var _balance_token: RitualToken = null
var _resolving := false
var _last_reward_label := ""
var _last_reward_expiry := 0.0
var _ambient_timer: Timer = null
var _idle_timer: Timer = null
var _ambient_rng := RandomNumberGenerator.new()
var _ambient_phase := 0.0
var _light_pulse := 0.0
var _idle_sway := 0.0
var _scale_settle := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# The Sacrifice room owns the whole native canvas. This also prevents a touch
	# on the ritual backdrop from falling through to a scene underneath it.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = Assets.font()
	_ambient_rng.seed = 0x53414352
	_backdrop = get_node_or_null(^"SacrificeBackdrop") as Sprite2D
	_fit_backdrop_to_native_canvas()
	_build()
	_start_ambient_timers()
	if not Engine.is_editor_hint() and not RunStateStore.state_changed.is_connected(_refresh):
		RunStateStore.state_changed.connect(_refresh)
	_refresh()


func _fit_backdrop_to_native_canvas() -> void:
	if _backdrop == null or _backdrop.texture == null:
		return
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_backdrop.centered = false
	var texture_size := _backdrop.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	# The generated asset is a 1:2 portrait. Use one uniform scale so its pixel
	# art is never stretched, and centre only any harmless source-height rounding.
	var uniform_scale := CANVAS_SIZE.x / texture_size.x
	_backdrop.scale = Vector2.ONE * uniform_scale
	_backdrop.position = Vector2(0.0,
		floorf((CANVAS_SIZE.y - texture_size.y * uniform_scale) * 0.5))


func _build() -> void:
	_options_layer = Control.new()
	_options_layer.name = "RitualOfferings"
	_options_layer.position = Vector2.ZERO
	_options_layer.size = CANVAS_SIZE
	_options_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_options_layer.z_index = 20
	add_child(_options_layer)

	var title := _label("SACRIFICE", Rect2(5.0, 6.0, 150.0, 9.0), 7, ROSE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	_wallet = _label("", Rect2(5.0, 17.0, 150.0, 8.0), 5, GOLD)
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_wallet)
	_progress = _label("", Rect2(5.0, 27.0, 150.0, 8.0), 5, CYAN)
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_progress)

	_preview = _label("", Rect2(6.0, 43.0, 148.0, 22.0), 5, HOT_GOLD)
	_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_preview)
	_status = _label("", Rect2(6.0, 214.0, 148.0, 14.0), 4, MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)

	_roulette_label = _label("?", Rect2(101.0, 157.0, 38.0, 15.0), 5, HOT_GOLD)
	_roulette_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_roulette_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_roulette_label)

	_confirm = _action_button("SEAL OFFER", Rect2(7.0, 290.0, 68.0, 21.0), 5, CYAN)
	_confirm.name = "ConfirmSacrificeButton"
	_confirm.pressed.connect(_on_confirm_pressed)
	add_child(_confirm)
	_leave = _action_button("LEAVE", Rect2(85.0, 290.0, 68.0, 21.0), 5, ROSE)
	_leave.name = "LeaveSacrificeButton"
	_leave.pressed.connect(_on_leave_pressed)
	add_child(_leave)


func _refresh() -> void:
	var route_open := RunStateStore.routeDestination == RouteCards.ROUTE_SACRIFICE
	var visit_count := int(RunStateStore.sacrificesUsedThisVisit)
	if _wallet != null:
		_wallet.text = "RUN COINS %d   NEURONS %d" % [
			int(RunStateStore.lucidityCoins), int(MetaStateStore.campaignNeuronsLeft)
		]
	if _progress != null:
		_progress.text = "VISIT %d/%d   RUN %d/%d" % [
			visit_count, SacrificeRules.MAX_USES_PER_VISIT,
			int(RunStateStore.sacrificeCount), SacrificeRules.MAX_USES,
		]
	_clear_offering_tokens()
	_options_by_id.clear()
	if not route_open:
		_preview.text = "SACRIFICE ROUTE CLOSED"
		_status.text = "THE MACHINE IS WAITING"
		_confirm.disabled = true
		_leave.disabled = true
		return

	var claimed := bool(RunStateStore.sacrificeClaimed)
	var maxed := int(RunStateStore.sacrificeCount) >= SacrificeRules.MAX_USES \
			or visit_count >= SacrificeRules.MAX_USES_PER_VISIT
	var choices: Array[Dictionary] = RunStateStore.sacrifice_options()
	if claimed:
		var reward := RunStateStore.resolve_sacrifice_reward()
		_preview.text = "OFFERING TAKEN\nRECEIVE %s" % String(reward.get("label", "+5 RUN SPINS"))
		_status.text = "REWARD REVEAL IN PROGRESS" if _resolving \
			else "REWARD LOCKED — TAP ACKNOWLEDGE"
		_confirm.disabled = true
		_leave.disabled = _resolving
		_leave.text = "RETURN" if _resolving else "ACKNOWLEDGE"
		if not _resolving:
			_roulette_label.text = String(reward.get("label", "+5 SPINS"))
		return
	if maxed:
		_preview.text = "THE SCALE IS FULL\nNO THIRD OFFERING"
		_status.text = "THE MACHINE WILL TAKE YOU BACK"
		_confirm.disabled = true
		_leave.disabled = false
		_leave.text = "RETURN"
		_roulette_label.text = "+5" if visit_count > 0 else "?"
		return
	if choices.is_empty():
		_preview.text = "NO ELIGIBLE OFFERING\nKEEP WHAT REMAINS"
		_status.text = "NOTHING ELSE CAN BE TRADED"
		_confirm.disabled = true
		_leave.disabled = false
		_leave.text = "RETURN"
		_roulette_label.text = "+5" if visit_count > 0 else "?"
		return

	var selected_is_available := false
	for option in choices:
		if String(option.get("id", "")) == _selected_option_id:
			selected_is_available = true
			break
	if not _selected_option_id.is_empty() and not selected_is_available:
		_selected_option_id = ""
	if _selected_option_id.is_empty():
		_preview.text = "CHOOSE AN OFFERING\nTHE SCALE WILL ANSWER"
	else:
		_preview.text = "GIVE %s\nRECEIVE +%d RUN SPINS" % [
			_selected_option_name(_selected_option_id), SacrificeRules.BONUS_SPINS,
		]
	_status.text = _last_reward_label if not _last_reward_label.is_empty() \
		else "SELECT → PREVIEW → CONFIRM"
	_confirm.disabled = _selected_option_id.is_empty()
	_confirm.text = "SEAL OFFER"
	_leave.disabled = false
	_leave.text = "RETURN" if visit_count > 0 else "LEAVE"
	_roulette_label.text = "+5" if visit_count > 0 else "?"

	for index in mini(choices.size(), OFFERING_SLOTS.size()):
		var option: Dictionary = choices[index]
		var option_id := String(option.get("id", ""))
		_options_by_id[option_id] = option
		var kind := String(option.get("kind", ""))
		var token := RitualToken.new()
		token.name = "Offering_%s" % option_id.replace(":", "_")
		token.position = OFFERING_SLOTS[index]
		token.size = OFFERING_SIZE
		token.configure(option_id, kind, _option_caption(option), _option_detail(option),
			_font, _option_accent(kind))
		token.set_visual_state(option_id == _selected_option_id,
			(not _selected_option_id.is_empty() and option_id != _selected_option_id), true)
		token.chosen.connect(_on_option_pressed)
		_options_layer.add_child(token)


func _option_caption(option: Dictionary) -> String:
	var kind := String(option.get("kind", "OFFERING"))
	var name := String(option.get("name", "OFFERING")).to_upper()
	if kind == "coins":
		return "COINS"
	if kind == "neuron":
		return "NEURON"
	if name.length() <= 11:
		return name
	return "AUGMENT" if kind == "augment" else "POWER"


func _option_detail(option: Dictionary) -> String:
	match String(option.get("kind", "")):
		"coins":
			return "%dG" % SacrificeRules.COIN_COST
		"neuron":
			return "-1 CAMPAIGN"
		"augment":
			return "REMOVE CARD"
		"power":
			return "REMOVE POWER"
	return "TRADE"


func _option_accent(kind: String) -> Color:
	match kind:
		"coins":
			return GOLD
		"neuron":
			return ROSE
		"augment":
			return CYAN
		"power":
			return Color(0.64, 0.52, 1.0)
	return MUTED


func _selected_option_name(option_id: String) -> String:
	if option_id == SacrificeRules.OPTION_COINS:
		return "100 RUN COINS"
	if option_id == SacrificeRules.OPTION_NEURON:
		return "1 CAMPAIGN NEURON"
	if option_id.begins_with(SacrificeRules.OPTION_AUGMENT_PREFIX):
		var card_id := option_id.substr(SacrificeRules.OPTION_AUGMENT_PREFIX.length())
		return "AUGMENT / %s" % String(PacteCards.card(card_id).get("name", card_id))
	if option_id.begins_with(SacrificeRules.OPTION_POWER_PREFIX):
		var power_id := option_id.substr(SacrificeRules.OPTION_POWER_PREFIX.length())
		return "POWER / %s" % String(PacteCards.card(power_id).get("name", power_id.to_upper()))
	return "RESOURCE"


func _on_option_pressed(option_id: String) -> void:
	if _resolving or RunStateStore.sacrificeClaimed or not _options_by_id.has(option_id):
		return
	_selected_option_id = option_id
	_last_reward_label = ""
	_last_reward_expiry = 0.0
	_show_balance_token(option_id)
	var settle_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	settle_tween.tween_property(self, "_scale_settle", 1.0, 0.18)
	# The option signal is emitted by a RitualToken while its input callback is
	# still on the stack. Defer the rebuild until that callback returns; freeing
	# the pressed token synchronously makes Godot reject it as a locked object.
	call_deferred("_refresh")


func _show_balance_token(option_id: String) -> void:
	if is_instance_valid(_balance_token):
		_balance_token.free()
		_balance_token = null
	var option: Dictionary = _options_by_id.get(option_id, {}) as Dictionary
	if option.is_empty():
		return
	var token := RitualToken.new()
	_balance_token = token
	token.name = "BalanceOffering"
	token.size = Vector2(40.0, 17.0)
	token.pivot_offset = token.size * 0.5
	token.configure(option_id, String(option.get("kind", "")),
		_option_caption(option), "", _font, _option_accent(String(option.get("kind", ""))))
	token.set_visual_state(true, false, false)
	token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token.z_index = 30
	token.position = Vector2(59.0, 107.0)
	token.rotation = 0.05
	token.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(token)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(token, "position", BALANCE_TOKEN_POSITION, 0.34)
	tween.tween_property(token, "rotation", -0.035, 0.34)
	tween.tween_property(token, "modulate:a", 1.0, 0.12)


func _on_confirm_pressed() -> void:
	if _resolving or _selected_option_id.is_empty():
		return
	var option_id := _selected_option_id
	_resolving = true
	if not RunStateStore.claim_sacrifice(option_id):
		_resolving = false
		_status.text = "THE SCALE REFUSED THAT OFFERING"
		_refresh()
		return
	_selected_option_id = ""
	var reward := RunStateStore.resolve_sacrifice_reward()
	_play_reward_roulette(reward)


## The logical trade is already committed before this coroutine starts. The
## cycling labels are presentation only and never call an RNG function.
func _play_reward_roulette(reward: Dictionary) -> void:
	var final_label := String(reward.get("label", "+5 RUN SPINS"))
	var cycle := ["+1 SPIN", "+3 SPINS", "???", "+8 SPINS", "DEBT", "+2 SPINS"]
	var elapsed := 0.0
	var duration := 1.28
	var index := 0
	while elapsed < duration:
		if not is_inside_tree():
			return
		_roulette_label.text = String(cycle[index % cycle.size()])
		_roulette_label.modulate = HOT_GOLD if index % 2 == 0 else Color(1.0, 0.72, 0.45)
		var progress := clampf(elapsed / duration, 0.0, 1.0)
		var interval := lerpf(0.045, 0.21, progress * progress)
		await get_tree().create_timer(interval).timeout
		elapsed += interval
		index += 1
	_roulette_label.text = final_label
	_roulette_label.modulate = Color.WHITE
	var settle := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	settle.tween_property(_roulette_label, "scale", Vector2(1.16, 1.16), 0.1)
	settle.tween_property(_roulette_label, "scale", Vector2.ONE, 0.16)
	# Use a timer for the short settle window instead of awaiting Tween.finished;
	# a scene refresh can replace a tween while the saved transaction remains valid.
	await get_tree().create_timer(0.3).timeout
	_roulette_label.scale = Vector2.ONE
	if not is_inside_tree():
		return
	_resolving = false
	_last_reward_label = "RECEIVED %s" % final_label
	_last_reward_expiry = Time.get_ticks_msec() * 0.001 + 2.4
	# This clears only the pending presentation marker. The +5 was applied in
	# claim_sacrifice(), so a resume or duplicate tap cannot award it twice.
	RunStateStore.acknowledge_sacrifice()
	_refresh()


func _on_leave_pressed() -> void:
	if _resolving:
		return
	if RunStateStore.sacrificeClaimed:
		# A save can be closed during the roulette. The transaction is already
		# paid; returning acknowledges it and then exits without replaying a reward.
		if not RunStateStore.acknowledge_sacrifice():
			_status.text = "THE OFFERING IS ALREADY SEALED"
			return
		_last_reward_label = "RECEIVED +%d RUN SPINS" % SacrificeRules.BONUS_SPINS
		if int(RunStateStore.sacrificesUsedThisVisit) >= SacrificeRules.MAX_USES_PER_VISIT:
			_finish_route()
		else:
			_refresh()
		return
	if RunStateStore.routeDestination != RouteCards.ROUTE_SACRIFICE:
		return
	if int(RunStateStore.sacrificesUsedThisVisit) <= 0:
		if not RunStateStore.refuse_sacrifice():
			_status.text = "THE MACHINE IS UNAVAILABLE"
			return
		SceneNav.change_to("res://scenes/machine_scene.tscn")
		return
	_finish_route()


func _finish_route() -> void:
	if _resolving:
		return
	if RunStateStore.routeDestination != RouteCards.ROUTE_SACRIFICE:
		return
	if not RunStateStore.finish_route_destination():
		_status.text = "THE MACHINE IS UNAVAILABLE"
		return
	SceneNav.change_to("res://scenes/machine_scene.tscn")


func _clear_offering_tokens() -> void:
	if _options_layer == null:
		return
	for child in _options_layer.get_children():
		# queue_free() is safe even when a refresh is requested from a token signal.
		# The refresh itself is deferred in _on_option_pressed, so old children are
		# removed before the next input cycle and never accumulate in the tray.
		child.queue_free()


func _start_ambient_timers() -> void:
	if Engine.is_editor_hint():
		return
	_ambient_timer = Timer.new()
	_ambient_timer.name = "RitualLightTimer"
	_ambient_timer.one_shot = true
	_ambient_timer.timeout.connect(_on_ambient_light_tick)
	add_child(_ambient_timer)
	_idle_timer = Timer.new()
	_idle_timer.name = "RitualBalanceTimer"
	_idle_timer.one_shot = true
	_idle_timer.timeout.connect(_on_idle_tick)
	add_child(_idle_timer)
	_schedule_ambient_light()
	_schedule_idle_motion()


func _schedule_ambient_light() -> void:
	if _ambient_timer == null:
		return
	_ambient_timer.wait_time = _ambient_rng.randf_range(0.9, 2.25)
	_ambient_timer.start()


func _schedule_idle_motion() -> void:
	if _idle_timer == null:
		return
	_idle_timer.wait_time = _ambient_rng.randf_range(0.65, 1.55)
	_idle_timer.start()


func _on_ambient_light_tick() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "_light_pulse", 1.0, 0.07)
	tween.tween_property(self, "_light_pulse", 0.0, 0.24)
	_schedule_ambient_light()


func _on_idle_tick() -> void:
	var target := _ambient_rng.randf_range(-0.9, 0.9)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "_idle_sway", target, 0.32)
	tween.tween_property(self, "_idle_sway", 0.0, 0.48)
	_schedule_idle_motion()


func _process(delta: float) -> void:
	_ambient_phase += delta
	if _last_reward_expiry > 0.0 and Time.get_ticks_msec() * 0.001 >= _last_reward_expiry:
		_last_reward_expiry = 0.0
		_last_reward_label = ""
		_refresh()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _resolving:
		return
	if event is InputEventMouseButton or event is InputEventScreenTouch \
			or event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var shimmer := 0.5 + 0.5 * sin(_ambient_phase * 1.7)
	var light_alpha := 0.04 + _light_pulse * 0.12 + shimmer * 0.025
	# Small framing plates keep the code-driven text readable while leaving the
	# generated scale, pans, and altar fully visible between them.
	draw_rect(Rect2(3.0, 3.0, 154.0, 34.0), Color(DEEP_INK.r, DEEP_INK.g, DEEP_INK.b, 0.62))
	draw_rect(Rect2(3.5, 3.5, 153.0, 33.0), Color(ROSE.r, ROSE.g, ROSE.b, 0.64), false, 1.0)
	draw_rect(Rect2(4.0, 41.0, 152.0, 24.0), Color(DEEP_INK.r, DEEP_INK.g, DEEP_INK.b, 0.36))
	draw_rect(Rect2(5.0, 42.0, 150.0, 22.0), Color(CYAN.r, CYAN.g, CYAN.b, 0.20), false, 1.0)
	draw_rect(Rect2(4.0, 212.0, 152.0, 17.0), Color(DEEP_INK.r, DEEP_INK.g, DEEP_INK.b, 0.46))
	draw_rect(Rect2(5.0, 213.0, 150.0, 15.0), Color(GOLD.r, GOLD.g, GOLD.b, 0.18), false, 1.0)

	# Asynchronous reflected light reads as a living room without making the
	# selection objects pulse in lockstep with it.
	draw_circle(Vector2(20.0, 221.0), 8.0, Color(CYAN.r, CYAN.g, CYAN.b, light_alpha))
	draw_circle(Vector2(140.0, 221.0), 8.0, Color(ROSE.r, ROSE.g, ROSE.b, light_alpha))
	draw_rect(Rect2(18.0, 224.0, 5.0, 1.0), Color(CYAN.r, CYAN.g, CYAN.b, light_alpha + 0.08))
	draw_rect(Rect2(137.0, 224.0, 5.0, 1.0), Color(ROSE.r, ROSE.g, ROSE.b, light_alpha + 0.08))

	var pan_y := 168.0 + _scale_settle * 1.5 + sin(_ambient_phase * 0.7) * 0.25
	var idle_reflection_x := 80.0 + _idle_sway * 0.7
	draw_circle(Vector2(idle_reflection_x, 128.0), 2.0,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.08 + shimmer * 0.04))
	if not _selected_option_id.is_empty() or _balance_token != null:
		draw_circle(Vector2(48.0, pan_y + 8.0), 13.0,
			Color(ROSE.r, ROSE.g, ROSE.b, 0.04 + _scale_settle * 0.035))
		draw_arc(Vector2(48.0, pan_y + 8.0), 14.0, 0.15, PI - 0.15, 10,
			Color(HOT_GOLD.r, HOT_GOLD.g, HOT_GOLD.b, 0.30), 1.0)

	# The right pan begins unknown and becomes a tiny illuminated reward window.
	if _roulette_label != null and not _resolving and _selected_option_id.is_empty() \
			and int(RunStateStore.sacrificesUsedThisVisit) <= 0:
		draw_circle(Vector2(120.0, 166.0), 10.0,
			Color(CYAN.r, CYAN.g, CYAN.b, 0.025 + shimmer * 0.02))


func _label(text_value: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	if _font != null:
		label.add_theme_font_override("font", _font)
	return label


func _action_button(text_value: String, rect: Rect2, font_size: int, accent: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.clip_text = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", accent)
	button.add_theme_color_override("font_hover_color", HOT_GOLD)
	button.add_theme_color_override("font_pressed_color", HOT_GOLD)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 1)
	if _font != null:
		button.add_theme_font_override("font", _font)
	button.add_theme_stylebox_override("normal", _style(Color(DEEP_INK.r,
		DEEP_INK.g, DEEP_INK.b, 0.88), Color(accent.r, accent.g, accent.b, 0.72)))
	button.add_theme_stylebox_override("hover", _style(Color(accent.r, accent.g,
		accent.b, 0.20), HOT_GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color(ROSE.r, ROSE.g,
		ROSE.b, 0.36), HOT_GOLD))
	button.add_theme_stylebox_override("disabled", _style(Color(DEEP_INK.r,
		DEEP_INK.g, DEEP_INK.b, 0.62), MUTED.darkened(0.35)))
	return button


func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 1
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_left = 1
	style.corner_radius_bottom_right = 1
	style.content_margin_left = 2.0
	style.content_margin_right = 2.0
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
	style.shadow_color = Color(border.r, border.g, border.b, 0.22)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0.0, 1.0)
	return style
