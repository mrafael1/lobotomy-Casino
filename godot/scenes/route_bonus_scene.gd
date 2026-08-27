extends Control

## The Bonus route is a single persisted Fortune Wheel turn.  The destination
## remains the existing route_bonus_scene so older route offers and saves keep
## their navigation seam.

const CANVAS_SIZE := Vector2(160.0, 320.0)
const WHEEL_SCRIPT := preload("res://scenes/fortune_wheel.gd")
const ROUND_WALL_BUTTON_SCRIPT := preload("res://ui/round_wall_button.gd")
const ODDS_OVERLAY_SCENE := preload("res://scenes/odds_table_overlay.tscn")
const CYAN := Color(0.42, 1.0, 0.95)
const GOLD := Color(1.0, 0.84, 0.38)
const HOT_GOLD := Color(1.0, 0.95, 0.62)
const MUTED := Color(0.62, 0.70, 0.78)
const INK := Color(0.055, 0.035, 0.105)
const AMBIENT_CYAN := Color(0.42, 1.0, 0.95, 0.08)
const AMBIENT_GOLD := Color(1.0, 0.84, 0.38, 0.06)
const AMBIENT_LIGHT_FIRST_DELAY := 1.9
const AMBIENT_LIGHT_MIN_DELAY := 1.7
const AMBIENT_LIGHT_MAX_DELAY := 3.3
const AMBIENT_REFLECTION_FIRST_DELAY := 4.6
const AMBIENT_REFLECTION_MIN_DELAY := 4.4
const AMBIENT_REFLECTION_MAX_DELAY := 7.0
const RESULT_PANEL_RECT := Rect2(12.0, 157.0, 136.0, 42.0)
const ROUND_BUTTON_RECT := Rect2(59.0, 207.0, 42.0, 42.0)
const HINT_RECT := Rect2(8.0, 253.0, 144.0, 10.0)

var _font: FontFile = null
var _wheel: FortuneWheelDisplay = null
var _balance: Label = null
var _status: Label = null
var _hint: Label = null
var _message: Label = null
var _spin: Button = null
var _result_panel: Panel = null
var _odds_overlay: Control = null
var _animating_reward_id := ""
var _spin_requesting := false
var _leaving := false
var _ambient_layer: Control = null
var _ambient_light: ColorRect = null
var _ambient_reflection: ColorRect = null
var _ambient_light_timer: Timer = null
var _ambient_reflection_timer: Timer = null
var _ambient_rng := RandomNumberGenerator.new()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# This scene owns the full viewport while it is open. Child controls still
	# receive their normal GUI events, but taps cannot fall through to a scene
	# underneath during a route transition or when the wheel is idle.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = Assets.font()
	_build_ambient()
	_wheel = WHEEL_SCRIPT.new() as FortuneWheelDisplay
	_wheel.name = "FortuneWheel"
	_wheel.position = Vector2.ZERO
	_wheel.size = CANVAS_SIZE
	_wheel.z_index = 5
	add_child(_wheel)
	_wheel.spin_finished.connect(_on_wheel_finished)
	_build()
	if not Engine.is_editor_hint() and not RunStateStore.state_changed.is_connected(_refresh):
		RunStateStore.state_changed.connect(_refresh)
	_refresh()
	call_deferred("_open_odds_table_if_needed")

func _build() -> void:
	var header := _panel(Rect2(3.0, 3.0, 154.0, 32.0),
		Color(INK.r, INK.g, INK.b, 0.93), Color(CYAN.r, CYAN.g, CYAN.b, 0.62))
	header.z_index = 2
	add_child(header)

	var title := _label("FORTUNE // BONUS", Rect2(5.0, 6.0, 150.0, 10.0), 7, CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	_balance = _label("", Rect2(5.0, 22.0, 150.0, 9.0), 5, GOLD)
	_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_balance)

	_result_panel = _panel(RESULT_PANEL_RECT,
		Color(INK.r, INK.g, INK.b, 0.90), Color(GOLD.r, GOLD.g, GOLD.b, 0.55))
	_result_panel.z_index = 6
	add_child(_result_panel)
	_status = _label("", Rect2(16.0, 160.0, 128.0, 10.0), 6, CYAN)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.z_index = 20
	add_child(_status)
	_message = _label("", Rect2(16.0, 173.0, 128.0, 21.0), 5, HOT_GOLD)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.z_index = 20
	add_child(_message)

	_hint = _label("PRESS THE PLATE TO SPIN", HINT_RECT, 4, MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_spin = ROUND_WALL_BUTTON_SCRIPT.new() as Button
	_spin.name = "TakeBonusButton"
	_spin.position = ROUND_BUTTON_RECT.position
	_spin.size = ROUND_BUTTON_RECT.size
	_spin.custom_minimum_size = ROUND_BUTTON_RECT.size
	_spin.text = "SPIN"
	_spin.z_index = 20
	_spin.mouse_filter = Control.MOUSE_FILTER_STOP
	_spin.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spin.add_theme_font_size_override("font_size", 5)
	if _font != null:
		_spin.add_theme_font_override("font", _font)
	_spin.pressed.connect(_on_spin_pressed)
	add_child(_spin)

func _refresh() -> void:
	if _balance != null:
		_balance.text = "CREDITS %d   RUN COINS %d" % [
			int(MetaStateStore.lucidityWallet), int(RunStateStore.lucidityCoins)
		]
	if _status == null or _spin == null:
		return

	if _spin_requesting or not _animating_reward_id.is_empty():
		_status.text = "THE HOUSE DECIDES"
		_message.text = "THE WHEEL IS HOT..."
		_status.add_theme_color_override("font_color", CYAN)
		_message.add_theme_color_override("font_color", HOT_GOLD)
		_spin.disabled = true
		_spin.text = "WAIT"
		_hint.text = "THE HOUSE IS WATCHING"
		_spin.queue_redraw()
		return

	var reward_id := String(RunStateStore.routeBonusRewardId)
	var reward := RunStateStore.route_bonus_reward()
	var reward_valid := FortuneWheelRules.is_valid_reward(reward_id) and not reward.is_empty()
	if reward_valid and _wheel.current_result_id() != reward_id:
		_wheel.present_reward(reward_id)

	var jackpot := reward_valid and bool(reward.get("jackpot", false))
	var odds_reward := reward_valid and int(reward.get("oddsTokens", 0)) > 0
	var odds_open := _odds_overlay != null and is_instance_valid(_odds_overlay) \
			and _odds_overlay.visible
	_status.add_theme_color_override("font_color", HOT_GOLD if jackpot else CYAN)
	_message.add_theme_color_override("font_color", HOT_GOLD if jackpot else GOLD)
	if RunStateStore.routeBonusClaimed and reward_valid:
		_status.text = "YOU WON" if not jackpot else "JACKPOT"
		_message.text = String(reward.get("description", "BONUS PAID"))
		_spin.disabled = odds_reward and not RunStateStore.oddsPhaseCompleted
		_spin.text = "ODDS" if odds_reward and not RunStateStore.oddsPhaseCompleted else "OK"
		_hint.text = "UPGRADE THE ODDS" if odds_reward and not RunStateStore.oddsPhaseCompleted \
			else "TAP TO CONTINUE"
		if odds_open:
			_hint.text = "ODDS TABLE OPEN"
	elif reward_valid:
		_status.text = "PRIZE READY"
		_message.text = String(reward.get("description", "COLLECT YOUR PRIZE"))
		_spin.disabled = false
		_spin.text = "CLAIM"
		_hint.text = "PRESS TO CLAIM"
	else:
		_status.text = "SPIN FOR YOUR FATE"
		_message.text = "FIVE REWARDS // ONE JACKPOT"
		_spin.disabled = false
		_spin.text = "SPIN"
		_hint.text = "PRESS THE PLATE TO SPIN"
	# Button text/disabled changes are stateful drawing inputs for the custom wall
	# control, so refresh its face after every non-animating state transition.
	_spin.queue_redraw()

func _on_spin_pressed() -> void:
	if _leaving or not _animating_reward_id.is_empty():
		return
	if RunStateStore.routeBonusClaimed:
		_continue_to_machine()
		return
	if FortuneWheelRules.is_valid_reward(String(RunStateStore.routeBonusRewardId)):
		_collect_prize()
		return
	_spin_requesting = true
	var reward := RunStateStore.prepare_route_bonus_spin()
	_spin_requesting = false
	var reward_id := String(reward.get("id", ""))
	if not FortuneWheelRules.is_valid_reward(reward_id):
		_message.text = "WHEEL UNAVAILABLE"
		return
	_animating_reward_id = reward_id
	if not _wheel.spin_to_reward(reward_id):
		_animating_reward_id = ""
		_message.text = "WHEEL JAMMED"
		_refresh()
		return
	_refresh()

func _on_wheel_finished(reward_id: String) -> void:
	if reward_id != _animating_reward_id:
		return
	_animating_reward_id = ""
	# The wheel result is the prize. Claim it as soon as the authored reveal lands,
	# leaving the round control free to become the acknowledgement/continue action.
	if not RunStateStore.routeBonusClaimed:
		_collect_prize()
	else:
		_refresh()
	_settle_reward_visuals()

func _settle_reward_visuals() -> void:
	if _result_panel == null or not is_instance_valid(_result_panel):
		return
	# The wheel already supplies the strong reveal. A short panel pulse makes the
	# saved selection feel acknowledged without swapping the whole background.
	_result_panel.self_modulate = Color(1.12, 1.08, 1.02, 1.0)
	var tween := create_tween()
	tween.tween_property(_result_panel, "self_modulate", Color.WHITE, 0.28) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _collect_prize() -> void:
	if not _animating_reward_id.is_empty() or RunStateStore.routeBonusClaimed:
		return
	if not RunStateStore.claim_route_bonus_reward():
		_message.text = "PRIZE COULD NOT BE CLAIMED"
		return
	_refresh()
	call_deferred("_open_odds_table_if_needed")

func _open_odds_table_if_needed() -> void:
	if _odds_overlay != null and is_instance_valid(_odds_overlay):
		return
	var reward := RunStateStore.route_bonus_reward()
	if not RunStateStore.routeBonusClaimed or int(reward.get("oddsTokens", 0)) <= 0 \
			or RunStateStore.oddsPhaseCompleted:
		return
	_odds_overlay = ODDS_OVERLAY_SCENE.instantiate() as Control
	_odds_overlay.name = "FortuneWheelOddsTable"
	_odds_overlay.z_index = 100
	add_child(_odds_overlay)
	_odds_overlay.connect("closed", _on_odds_table_closed)
	_odds_overlay.call_deferred("open_overlay")
	_refresh()

func _on_odds_table_closed() -> void:
	if _odds_overlay != null and is_instance_valid(_odds_overlay):
		_odds_overlay.queue_free()
	_odds_overlay = null
	_refresh()

func _continue_to_machine() -> void:
	if _leaving:
		return
	if not RunStateStore.routeBonusClaimed:
		_message.text = "WAIT FOR THE RESULT"
		return
	var reward := RunStateStore.route_bonus_reward()
	if int(reward.get("oddsTokens", 0)) > 0 and not RunStateStore.oddsPhaseCompleted:
		_message.text = "FINISH THE ODDS TABLE FIRST"
		return
	_leaving = true
	if not RunStateStore.finish_route_destination():
		_leaving = false
		_refresh()
		_message.text = "NEXT MACHINE UNAVAILABLE"
		return
	SceneNav.change_to("res://scenes/machine_scene.tscn")

func _can_continue_from_tap() -> bool:
	if _leaving or not _animating_reward_id.is_empty() or not RunStateStore.routeBonusClaimed:
		return false
	var reward := RunStateStore.route_bonus_reward()
	return int(reward.get("oddsTokens", 0)) <= 0 or RunStateStore.oddsPhaseCompleted

func _gui_input(event: InputEvent) -> void:
	# Empty wall space is also a comfortable acknowledgement target. Child buttons
	# get first refusal; the root handles a tap/click that lands on the room itself.
	var activate := false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		activate = mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed
	elif event is InputEventScreenTouch:
		activate = not (event as InputEventScreenTouch).pressed
	if activate and _can_continue_from_tap():
		_continue_to_machine()
	get_viewport().set_input_as_handled()

func _build_ambient() -> void:
	_ambient_layer = Control.new()
	_ambient_layer.name = "BonusAmbient"
	_ambient_layer.size = CANVAS_SIZE
	_ambient_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ambient_layer.z_index = -5
	add_child(_ambient_layer)

	_ambient_light = ColorRect.new()
	_ambient_light.name = "LightFlicker"
	_ambient_light.position = Vector2(13.0, 38.0)
	_ambient_light.size = Vector2(134.0, 1.0)
	_ambient_light.color = AMBIENT_CYAN
	_ambient_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ambient_layer.add_child(_ambient_light)

	_ambient_reflection = ColorRect.new()
	_ambient_reflection.name = "ReflectionSweep"
	_ambient_reflection.position = Vector2(16.0, 54.0)
	_ambient_reflection.size = Vector2(2.0, 82.0)
	_ambient_reflection.color = Color(AMBIENT_GOLD.r, AMBIENT_GOLD.g,
		AMBIENT_GOLD.b, 0.0)
	_ambient_reflection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ambient_layer.add_child(_ambient_reflection)

	_ambient_rng.seed = 0xB0A05 + Time.get_ticks_msec()
	_ambient_light_timer = _ambient_timer(
		"LightTimer", AMBIENT_LIGHT_FIRST_DELAY, Callable(self, "_on_ambient_light_timeout"))
	_ambient_reflection_timer = _ambient_timer(
		"ReflectionTimer", AMBIENT_REFLECTION_FIRST_DELAY,
		Callable(self, "_on_ambient_reflection_timeout"))
	if Engine.is_editor_hint():
		return
	_ambient_light_timer.start()
	_ambient_reflection_timer.start()

func _ambient_timer(timer_name: String, delay: float, callback: Callable) -> Timer:
	var timer := Timer.new()
	timer.name = timer_name
	timer.one_shot = true
	timer.wait_time = delay
	timer.timeout.connect(callback)
	_ambient_layer.add_child(timer)
	return timer

func _on_ambient_light_timeout() -> void:
	if _ambient_light != null:
		var tween := create_tween()
		tween.tween_property(_ambient_light, "color:a", 0.15, 0.07)
		tween.tween_property(_ambient_light, "color:a", 0.05, 0.20)
	if _ambient_light_timer != null:
		_ambient_light_timer.start(_ambient_rng.randf_range(
			AMBIENT_LIGHT_MIN_DELAY, AMBIENT_LIGHT_MAX_DELAY))

func _on_ambient_reflection_timeout() -> void:
	if _ambient_reflection != null:
		_ambient_reflection.position.x = 16.0
		_ambient_reflection.color.a = 0.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_ambient_reflection, "position:x", 142.0, 0.58)
		tween.tween_property(_ambient_reflection, "color:a", 0.10, 0.11)
		tween.tween_property(_ambient_reflection, "color:a", 0.0, 0.27).set_delay(0.28)
		tween.set_parallel(false)
	if _ambient_reflection_timer != null:
		_ambient_reflection_timer.start(_ambient_rng.randf_range(
			AMBIENT_REFLECTION_MIN_DELAY, AMBIENT_REFLECTION_MAX_DELAY))

func _panel(rect: Rect2, background: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	panel.add_theme_stylebox_override("panel", style)
	return panel

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
