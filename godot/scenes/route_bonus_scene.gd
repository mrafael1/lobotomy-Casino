extends Control

## The small free Bonus destination. Claiming it is a separate persisted action
## so closing the game before returning cannot duplicate the payout.

const CANVAS_SIZE := Vector2(160.0, 320.0)
const GOLD := Color(1.0, 0.84, 0.38)
const CYAN := Color(0.42, 1.0, 0.95)
const MUTED := Color(0.62, 0.70, 0.78)
const RED := Color(1.0, 0.35, 0.42)

var _font: FontFile = null
var _status: Label = null
var _claim: Button = null
var _message: Label = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = Assets.font()
	_build()
	_refresh()

func _build() -> void:
	var background := ColorRect.new()
	background.color = Color(0.035, 0.025, 0.08, 1.0)
	background.size = CANVAS_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var title := _label("BONUS SCENE", Rect2(5.0, 7.0, 150.0, 14.0), 10, CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var gold := _label("RUN LUCIDITY / GOLD: %d" % int(RunStateStore.lucidityCoins), \
			Rect2(5.0, 27.0, 150.0, 12.0), 7, GOLD)
	gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(gold)
	_status = _label("", Rect2(10.0, 78.0, 140.0, 50.0), 8, GOLD)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_claim = _button("TAKE BONUS", Rect2(24.0, 154.0, 112.0, 28.0), 8)
	_claim.name = "TakeBonusButton"
	_claim.pressed.connect(_on_claim_pressed)
	add_child(_claim)
	_message = _label("", Rect2(5.0, 212.0, 150.0, 18.0), 5, RED)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message)
	var leave := _button("RETURN TO MACHINE", Rect2(20.0, 274.0, 120.0, 25.0), 7)
	leave.name = "ReturnButton"
	leave.pressed.connect(_on_return_pressed)
	add_child(leave)

func _refresh() -> void:
	var claimed := RunStateStore.routeBonusClaimed
	if claimed:
		_status.text = "BONUS CLAIMED\n+%d RUN LUCIDITY" % RunStateStore.ROUTE_BONUS_LUCIDITY
	else:
		_status.text = "THE MACHINE OFFERS\n+%d RUN LUCIDITY" % RunStateStore.ROUTE_BONUS_LUCIDITY
	_claim.disabled = claimed
	_claim.text = "BONUS CLAIMED" if claimed else "TAKE BONUS"

func _on_claim_pressed() -> void:
	if not RunStateStore.claim_route_bonus():
		_message.text = "BONUS ALREADY CLAIMED"
		return
	_message.text = "THE BONUS IS YOURS"
	_refresh()

func _on_return_pressed() -> void:
	if not RunStateStore.routeBonusClaimed:
		_message.text = "TAKE THE BONUS FIRST"
		return
	if not RunStateStore.finish_route_destination():
		_message.text = "NEXT MACHINE UNAVAILABLE"
		return
	SceneNav.change_to("res://scenes/machine_scene.tscn")

func _label(text_value: String, rect: Rect2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	if _font != null:
		label.add_theme_font_override("font", _font)
	return label

func _button(text_value: String, rect: Rect2, size: int) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", size)
	if _font != null:
		button.add_theme_font_override("font", _font)
	return button
