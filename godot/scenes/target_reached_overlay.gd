@tool
class_name TargetReachedOverlay
extends Control

## Intermediate wealth-target payout screen (issue #176). It borrows the flatline
## overlay's focused layout — dim, big title, subtitle, a large draining number and
## a red loss line — but drops the flatline trace and neuron-loss animations. The
## beaten target pops in beside the score, flies onto it, and the score counts down
## by that amount (the money paid to the casino). A normal neon button advances.

signal continue_pressed

const BLUE_NEON := Color(0.36, 0.74, 1.0)
const BLUE_GLOW := Color(0.36, 0.74, 1.0, 0.7)
const SOFT_WHITE := Color(0.96, 0.98, 1.0)
const MUTED_BLUE := Color(0.56, 0.66, 0.82)
const LOSS_RED := Color(0.93, 0.27, 0.27)

const HOLD_TIME := 0.42
const POP_TIME := 0.16
const FLY_HOLD := 0.10
const DRAIN_TIME := 0.52
const TARGET_POP_REST_X := 96.0
const TARGET_POP_FLY_X := 58.0

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var caption_label: Label = %CaptionLabel
@onready var score_label: Label = %ScoreLabel
@onready var target_label: Label = %TargetLabel
@onready var lost_label: Label = %LostLabel
@onready var button_host: Control = %ButtonHost
@onready var continue_button: Button = %ContinueButton

var _font: FontFile = null
var _score := 0
var _target := 0
var _remaining := 0
var _presentation_started := false


func _ready() -> void:
	_font = Assets.font()
	_style_text()
	_style_button()
	if not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)
	Assets.start_menu_button_press_feedback(continue_button)
	button_host.pivot_offset = button_host.size * 0.5
	if Engine.is_editor_hint():
		_score = 650
		_target = 500
		_remaining = 150
		score_label.text = str(_score)
		lost_label.text = "-%d" % _target
		return


## Sets the beaten target and running score, then plays the payout animation. The
## remaining money is the score minus the target — the same value the store commits
## when the run resumes after CONTINUE.
func present(score: int, target: int, action_text: String = "CONTINUE") -> void:
	_score = score
	_target = target
	_remaining = maxi(0, score - target)
	continue_button.text = action_text
	score_label.text = str(_score)
	lost_label.text = ""
	target_label.text = "-%d" % _target
	target_label.position.x = TARGET_POP_REST_X
	target_label.scale = Vector2(0.5, 0.5)
	target_label.modulate.a = 0.0
	button_host.modulate.a = 0.0
	if _presentation_started or Engine.is_editor_hint():
		return
	_presentation_started = true
	_play()


func _play() -> void:
	target_label.pivot_offset = target_label.size * 0.5
	var seq := create_tween()
	seq.tween_interval(HOLD_TIME)
	# The target pops in to the right of the score number.
	seq.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	seq.tween_property(target_label, "modulate:a", 1.0, POP_TIME)
	seq.parallel().tween_property(target_label, "scale", Vector2.ONE, POP_TIME)
	seq.tween_interval(FLY_HOLD)
	# It flies onto the score and vanishes while the score drains by the target.
	seq.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	seq.tween_property(target_label, "position:x", TARGET_POP_FLY_X, DRAIN_TIME)
	seq.parallel().tween_property(target_label, "modulate:a", 0.0, DRAIN_TIME)
	seq.parallel().tween_method(_set_score_display,
		float(_score), float(_remaining), DRAIN_TIME)
	seq.tween_callback(func() -> void:
		score_label.text = str(_remaining)
		lost_label.text = "-%d" % _target)
	# A normal neon CONTINUE button fades in once the money has settled.
	seq.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	seq.tween_property(button_host, "modulate:a", 1.0, 0.2)


func _set_score_display(value: float) -> void:
	if score_label != null:
		score_label.text = str(int(round(value)))


func _style_text() -> void:
	for label: Label in [title_label, subtitle_label, caption_label,
			score_label, target_label, lost_label]:
		if _font != null:
			label.add_theme_font_override(&"font", _font)
		label.add_theme_color_override(&"font_outline_color", Color("#03060c"))
		label.add_theme_constant_override(&"outline_size", 1)
	title_label.add_theme_color_override(&"font_color", BLUE_NEON)
	title_label.add_theme_color_override(&"font_shadow_color", BLUE_GLOW)
	title_label.add_theme_constant_override(&"shadow_offset_x", 1)
	title_label.add_theme_constant_override(&"shadow_offset_y", 1)
	subtitle_label.add_theme_color_override(&"font_color", SOFT_WHITE)
	caption_label.add_theme_color_override(&"font_color", MUTED_BLUE)
	score_label.add_theme_color_override(&"font_color", SOFT_WHITE)
	target_label.add_theme_color_override(&"font_color", LOSS_RED)
	lost_label.add_theme_color_override(&"font_color", LOSS_RED)


func _style_button() -> void:
	Assets.small_neon_button_style(continue_button, BLUE_NEON, 7, 1.0)


func _on_continue_pressed() -> void:
	continue_pressed.emit()
