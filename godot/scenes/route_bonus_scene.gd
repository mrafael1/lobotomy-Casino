extends Control

## The Bonus route is a single persisted Fortune Wheel turn.  The destination
## remains the existing route_bonus_scene so older route offers and saves keep
## their navigation seam.

const CANVAS_SIZE := Vector2(160.0, 320.0)
const WHEEL_SCRIPT := preload("res://scenes/fortune_wheel.gd")
const ODDS_OVERLAY_SCENE := preload("res://scenes/odds_table_overlay.tscn")
const CYAN := Color(0.42, 1.0, 0.95)
const GOLD := Color(1.0, 0.84, 0.38)
const HOT_GOLD := Color(1.0, 0.95, 0.62)
const MUTED := Color(0.62, 0.70, 0.78)
const ROSE := Color(1.0, 0.35, 0.66)
const INK := Color(0.055, 0.035, 0.105)

var _font: FontFile = null
var _wheel: FortuneWheelDisplay = null
var _balance: Label = null
var _status: Label = null
var _hint: Label = null
var _message: Label = null
var _spin: Button = null
var _return: Button = null
var _odds_overlay: Control = null
var _animating_reward_id := ""
var _spin_requesting := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = Assets.font()
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

	var result_panel := _panel(Rect2(5.0, 148.0, 150.0, 36.0),
		Color(INK.r, INK.g, INK.b, 0.90), Color(GOLD.r, GOLD.g, GOLD.b, 0.55))
	result_panel.z_index = 6
	add_child(result_panel)
	_status = _label("", Rect2(8.0, 150.0, 144.0, 12.0), 6, CYAN)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.z_index = 20
	add_child(_status)
	_message = _label("", Rect2(8.0, 163.0, 144.0, 20.0), 5, HOT_GOLD)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.z_index = 20
	add_child(_message)

	_hint = _label("ONE TURN // NO TAKEBACKS", Rect2(8.0, 214.0, 144.0, 10.0), 4, MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_spin = _button("SPIN THE WHEEL", _centered_rect(231.0, Vector2(96.0, 22.0)), 6)
	_spin.name = "TakeBonusButton"
	_spin.pressed.connect(_on_spin_pressed)
	add_child(_spin)

	_return = _button("RETURN TO MACHINE", _centered_rect(286.0, Vector2(100.0, 18.0)), 5)
	_return.name = "ReturnButton"
	_return.pressed.connect(_on_return_pressed)
	add_child(_return)

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
		_spin.text = "SPINNING..."
		_return.disabled = true
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
		_status.text = "PRIZE CLAIMED" if not jackpot else "JACKPOT CLAIMED"
		_message.text = String(reward.get("description", "BONUS PAID"))
		_spin.disabled = true
		_spin.text = "PRIZE CLAIMED"
		_return.disabled = odds_reward and not RunStateStore.oddsPhaseCompleted
		_hint.text = "UPGRADE THE ODDS" if odds_reward and not RunStateStore.oddsPhaseCompleted \
			else "THE MACHINE WILL REMEMBER"
		if odds_open:
			_hint.text = "ODDS TABLE OPEN"
	elif reward_valid:
		_status.text = "FATE LOCKED // COLLECT"
		_message.text = String(reward.get("description", "COLLECT YOUR PRIZE"))
		_spin.disabled = false
		_spin.text = "COLLECT PRIZE"
		_return.disabled = true
		_hint.text = "ONE TURN // NO TAKEBACKS"
	else:
		_status.text = "SPIN FOR YOUR FATE"
		_message.text = "FIVE REWARDS // ONE JACKPOT"
		_spin.disabled = false
		_spin.text = "SPIN THE WHEEL"
		_return.disabled = true
		_hint.text = "ONE TURN // NO TAKEBACKS"

func _on_spin_pressed() -> void:
	if _animating_reward_id != "" or RunStateStore.routeBonusClaimed:
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
	_refresh()

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

func _on_return_pressed() -> void:
	if not RunStateStore.routeBonusClaimed:
		_message.text = "COLLECT THE PRIZE FIRST"
		return
	var reward := RunStateStore.route_bonus_reward()
	if int(reward.get("oddsTokens", 0)) > 0 and not RunStateStore.oddsPhaseCompleted:
		_message.text = "FINISH THE ODDS TABLE FIRST"
		return
	if not RunStateStore.finish_route_destination():
		_message.text = "NEXT MACHINE UNAVAILABLE"
		return
	SceneNav.change_to("res://scenes/machine_scene.tscn")

func _centered_rect(top: float, dimensions: Vector2) -> Rect2:
	return Rect2(Vector2(roundf((CANVAS_SIZE.x - dimensions.x) * 0.5), top), dimensions)

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

func _button(text_value: String, rect: Rect2, font_size: int) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", CYAN)
	button.add_theme_color_override("font_hover_color", HOT_GOLD)
	button.add_theme_color_override("font_pressed_color", HOT_GOLD)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 1)
	if _font != null:
		button.add_theme_font_override("font", _font)
	button.add_theme_stylebox_override("normal", _button_style(Color(INK.r, INK.g, INK.b, 0.96), CYAN))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.11, 0.06, 0.18, 0.98), HOT_GOLD))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.18, 0.08, 0.20, 1.0), ROSE))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.07, 0.06, 0.11, 0.95), MUTED))
	return button

func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 2.0
	style.content_margin_right = 2.0
	style.shadow_color = Color(border.r, border.g, border.b, 0.24)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0.0, 1.0)
	return style
