@tool
class_name GameOverEndingOverlay
extends Control

signal try_again_pressed

const CANVAS_SIZE := Vector2(160.0, 320.0)
const RED := Color("#ff334d")
const PALE_RED := Color("#ff9aa8")
const SOFT_WHITE := Color("#f4f2f0")

@onready var title_label: Label = %TitleLabel
@onready var fatal_label: Label = %FatalLabel
@onready var money_label: Label = %MoneyLabel
@onready var action_button: Button = %ActionButton
@onready var button_host: Control = %ButtonHost


func _ready() -> void:
	set_deferred(&"size", CANVAS_SIZE)
	_style_text()
	_style_button()
	if not action_button.pressed.is_connected(_on_action_pressed):
		action_button.pressed.connect(_on_action_pressed)
	if Engine.is_editor_hint():
		return
	action_button.call_deferred(&"grab_focus")


func present() -> void:
	# Game over is a hard loss: the visible balance and the committed state are
	# both zero. Keeping this explicit makes the scene safe to preview in isolation.
	money_label.text = "0"


func _style_text() -> void:
	var font := Assets.font()
	for label: Label in find_children("*", "Label", true, false):
		if font != null:
			label.add_theme_font_override(&"font", font)
		label.add_theme_color_override(&"font_outline_color", Color("#100306"))
		label.add_theme_constant_override(&"outline_size", 1)
	title_label.add_theme_color_override(&"font_color", RED)
	fatal_label.add_theme_color_override(&"font_color", PALE_RED)
	money_label.add_theme_color_override(&"font_color", SOFT_WHITE)


func _style_button() -> void:
	var font := Assets.font()
	if font != null:
		action_button.add_theme_font_override(&"font", font)
	action_button.add_theme_color_override(&"font_color", PALE_RED)
	action_button.add_theme_color_override(&"font_hover_color", Color.WHITE)
	action_button.add_theme_color_override(&"font_pressed_color", Color.WHITE)
	action_button.add_theme_color_override(&"font_focus_color", PALE_RED)
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#21070c") if state != &"hover" else Color("#380a12")
		style.set_content_margin_all(2.0)
		action_button.add_theme_stylebox_override(state, style)
	button_host.pivot_offset = button_host.size * 0.5


func _on_action_pressed() -> void:
	action_button.disabled = true
	try_again_pressed.emit()
