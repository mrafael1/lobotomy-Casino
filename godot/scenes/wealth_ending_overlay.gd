@tool
class_name WealthEndingOverlay
extends Control

signal enough_pressed
signal exit_casino_pressed

const CANVAS_SIZE := Vector2(160.0, 320.0)
const GOLD := Color("#ffd75a")
const PALE_GOLD := Color("#fff0a3")
const DEEP_PURPLE := Color("#16091c")
const HOT_MAGENTA := Color("#ff2f87")
const NEON_CYAN := Color("#3ff5eb")

@onready var light_layer: Control = %LightLayer
@onready var title_label: Label = %TitleLabel
@onready var tv_panel: Panel = %TVPanel
@onready var score_title_label: Label = %ScoreTitleLabel
@onready var score_label: Label = %ScoreLabel
@onready var enough_button: Button = %EnoughButton
@onready var exit_button: Button = %ExitButton
@onready var coin_pile: TextureRect = %CoinPile

var _font: FontFile = null


func _ready() -> void:
	set_deferred("size", CANVAS_SIZE)
	_font = load("res://assets/font/DTM-Sans.otf") as FontFile
	_style_labels()
	_style_panels()
	_style_buttons()
	if not enough_button.pressed.is_connected(_on_enough_pressed):
		enough_button.pressed.connect(_on_enough_pressed)
	if not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)
	if Engine.is_editor_hint():
		set_final_score(999999)
		return
	_play_reveal()
	_play_light_pulse()


func present(total_score: int, can_continue: bool) -> void:
	set_final_score(total_score)
	enough_button.disabled = not can_continue


func set_final_score(total_score: int) -> void:
	if score_label != null:
		score_label.text = _score_with_separators(total_score)


func _score_with_separators(value: int) -> String:
	var digits := str(absi(value))
	var groups: Array[String] = []
	while digits.length() > 3:
		groups.push_front(digits.right(3))
		digits = digits.left(digits.length() - 3)
	groups.push_front(digits)
	return ("-" if value < 0 else "") + ",".join(groups)


func _style_labels() -> void:
	for label: Label in [title_label, score_title_label, score_label]:
		if _font != null:
			label.add_theme_font_override("font", _font)
		label.add_theme_color_override("font_outline_color", DEEP_PURPLE)
		label.add_theme_constant_override("outline_size", 2)
	title_label.add_theme_color_override("font_color", GOLD)
	title_label.add_theme_color_override("font_shadow_color", HOT_MAGENTA)
	title_label.add_theme_constant_override("shadow_offset_x", 1)
	title_label.add_theme_constant_override("shadow_offset_y", 1)
	score_title_label.add_theme_color_override("font_color", GOLD)
	score_label.add_theme_color_override("font_color", PALE_GOLD)


func _style_panels() -> void:
	var tv_style := StyleBoxFlat.new()
	tv_style.bg_color = Color(0.025, 0.02, 0.035, 0.98)
	tv_style.border_color = GOLD
	tv_style.set_border_width_all(1)
	tv_style.shadow_color = Color(HOT_MAGENTA, 0.55)
	tv_style.shadow_size = 2
	tv_panel.add_theme_stylebox_override("panel", tv_style)


func _style_buttons() -> void:
	if _font != null:
		enough_button.add_theme_font_override("font", _font)
		exit_button.add_theme_font_override("font", _font)
	enough_button.add_theme_color_override("font_color", PALE_GOLD)
	enough_button.add_theme_color_override("font_hover_color", Color.WHITE)
	enough_button.add_theme_color_override("font_pressed_color", DEEP_PURPLE)
	enough_button.add_theme_color_override("font_disabled_color", Color("#766a72"))
	enough_button.add_theme_stylebox_override("normal", _button_style(DEEP_PURPLE, GOLD, HOT_MAGENTA))
	enough_button.add_theme_stylebox_override("hover", _button_style(Color("#32113c"), PALE_GOLD, NEON_CYAN))
	enough_button.add_theme_stylebox_override("pressed", _button_style(GOLD, PALE_GOLD, HOT_MAGENTA))
	enough_button.add_theme_stylebox_override("disabled", _button_style(Color("#221923"), Color("#665163"), Color.TRANSPARENT))
	enough_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	exit_button.add_theme_color_override("font_color", Color("#d7adc9"))
	exit_button.add_theme_color_override("font_hover_color", Color.WHITE)
	exit_button.add_theme_color_override("font_pressed_color", GOLD)
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		exit_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())


func _button_style(fill: Color, border: Color, shadow: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.shadow_color = Color(shadow, 0.75)
	style.shadow_size = 2
	return style


func _play_reveal() -> void:
	title_label.modulate.a = 0.0
	tv_panel.modulate.a = 0.0
	enough_button.modulate.a = 0.0
	exit_button.modulate.a = 0.0
	title_label.scale = Vector2(0.9, 0.9)
	title_label.pivot_offset = title_label.size * 0.5
	coin_pile.pivot_offset = Vector2(coin_pile.size.x * 0.5, coin_pile.size.y)
	coin_pile.scale = Vector2(1.0, 0.04)

	var ui_tween := create_tween()
	ui_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ui_tween.tween_property(title_label, "modulate:a", 1.0, 0.16)
	ui_tween.parallel().tween_property(title_label, "scale", Vector2.ONE, 0.24)
	ui_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ui_tween.tween_property(tv_panel, "modulate:a", 1.0, 0.18)
	ui_tween.tween_property(enough_button, "modulate:a", 1.0, 0.16)
	ui_tween.tween_property(exit_button, "modulate:a", 1.0, 0.1)

	var coin_tween := create_tween()
	coin_tween.tween_interval(0.28)
	coin_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	coin_tween.tween_property(coin_pile, "scale", Vector2.ONE, 1.15)


func _play_light_pulse() -> void:
	light_layer.modulate.a = 0.72
	var pulse := create_tween().set_loops()
	pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(light_layer, "modulate:a", 1.0, 0.48)
	pulse.tween_property(light_layer, "modulate:a", 0.72, 0.72)


func _on_enough_pressed() -> void:
	enough_pressed.emit()


func _on_exit_pressed() -> void:
	exit_casino_pressed.emit()
