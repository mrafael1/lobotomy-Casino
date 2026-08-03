@tool
class_name FlatlineEndingOverlay
extends Control

signal action_pressed
signal continue_animation_finished
signal first_revival_beep

const RED := Color("#ff334d")
const PALE_RED := Color("#ff9aa8")
const SOFT_WHITE := Color("#f4f2f0")
const TRACE_REVEAL_TIME := 1.65
const REVIVAL_REVEAL_TIME := 2.3
const TRACE_CENTER := Vector2(80.0, 201.0)
const REVIVAL_METER_CENTER := Vector2(80.0, 243.0)

@onready var fatal_label: Label = %FatalLabel
@onready var score_label: Label = %ScoreLabel
@onready var kept_label: Label = %KeptLabel
@onready var lost_label: Label = %LostLabel
@onready var trace_root: Control = %TraceRoot
@onready var trace_glow: Line2D = %TraceGlow
@onready var trace_line: Line2D = %TraceLine
@onready var button_host: Control = %ButtonHost
@onready var action_button: Button = %ActionButton

var _trace_tween: Tween = null
var _trace_glow_tween: Tween = null
var _continue_animation_started: bool = false
var _revival_trace_points: PackedVector2Array = PackedVector2Array()
var _revival_trace_lengths: PackedFloat32Array = PackedFloat32Array()
var _revival_trace_total_length: float = 0.0
var _revival_beat_progresses: Array[float] = []
var _next_revival_beat: int = 0


func _ready() -> void:
	_style_text()
	_style_button()
	_connect_button()
	if Engine.is_editor_hint():
		return
	_play_trace_reveal()
	action_button.call_deferred(&"grab_focus")


func present(action_text: String, fatal_copy: String = "") -> void:
	action_button.text = action_text
	fatal_label.text = fatal_copy
	fatal_label.visible = not fatal_copy.is_empty()


func set_kept_percentage(kept_percentage: int) -> void:
	kept_label.text = tr("%d%% kept") % kept_percentage


## Replaces the dead line with three returning beats. The first beat swaps the
## action button for the neuron meter; the trace clears at the end of the sweep.
func play_continue_animation() -> void:
	if _continue_animation_started:
		return
	_continue_animation_started = true
	action_button.disabled = true
	_prepare_revival_trace(_alive_trace_points())
	trace_line.points = _revival_trace_points
	trace_glow.points = _revival_trace_points
	trace_root.visible = false
	trace_root.modulate.a = 1.0
	trace_glow.modulate.a = 0.3
	if _trace_tween != null and _trace_tween.is_valid():
		_trace_tween.kill()
	if _trace_glow_tween != null and _trace_glow_tween.is_valid():
		_trace_glow_tween.kill()
	_trace_tween = create_tween()
	_trace_tween.set_trans(Tween.TRANS_LINEAR)
	_trace_tween.tween_callback(func() -> void:
		trace_root.visible = true
		_set_revival_trace_progress(0.0)
	)
	_trace_tween.tween_method(Callable(self, "_set_revival_trace_progress"),
		0.0, 1.0, REVIVAL_REVEAL_TIME)
	_trace_tween.tween_property(trace_root, "modulate:a", 0.0, 0.16)
	_trace_tween.tween_callback(Callable(self, "_clear_trace"))
	_trace_tween.tween_property(button_host, "modulate:a", 0.0, 0.14)
	_trace_tween.tween_callback(func() -> void:
		button_host.visible = false
		continue_animation_finished.emit()
	)


func _alive_trace_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, 3.0), Vector2(12.0, 3.0),
		Vector2(16.0, -3.0), Vector2(20.0, 11.0), Vector2(24.0, 3.0),
		Vector2(56.0, 3.0),
		Vector2(60.0, -4.0), Vector2(64.0, 12.0), Vector2(68.0, 3.0),
		Vector2(100.0, 3.0),
		Vector2(104.0, -3.0), Vector2(108.0, 11.0), Vector2(112.0, 3.0),
		Vector2(128.0, 3.0),
	])


func _prepare_revival_trace(points: PackedVector2Array) -> void:
	_revival_trace_points = points
	_revival_trace_lengths = PackedFloat32Array([0.0])
	_revival_trace_total_length = 0.0
	for index in range(1, points.size()):
		_revival_trace_total_length += points[index - 1].distance_to(points[index])
		_revival_trace_lengths.append(_revival_trace_total_length)

	_revival_beat_progresses.clear()
	_next_revival_beat = 0
	if is_zero_approx(_revival_trace_total_length):
		return
	for point_index: int in [2, 6, 10]:
		if point_index < _revival_trace_lengths.size():
			_revival_beat_progresses.append(
				_revival_trace_lengths[point_index] / _revival_trace_total_length)


func _set_revival_trace_progress(progress: float) -> void:
	var clamped_progress := clampf(progress, 0.0, 1.0)
	var reveal_length := _revival_trace_total_length * clamped_progress
	var revealed_points := _points_up_to_length(reveal_length)
	trace_line.points = revealed_points
	trace_glow.points = revealed_points

	while _next_revival_beat < _revival_beat_progresses.size() \
			and clamped_progress >= _revival_beat_progresses[_next_revival_beat]:
		_pulse_trace_glow()
		if _next_revival_beat == 0:
			button_host.visible = false
			button_host.modulate.a = 0.0
			first_revival_beep.emit()
		_next_revival_beat += 1


func _points_up_to_length(reveal_length: float) -> PackedVector2Array:
	var revealed_points := PackedVector2Array()
	if _revival_trace_points.is_empty():
		return revealed_points
	revealed_points.append(_revival_trace_points[0])
	if reveal_length <= 0.0:
		return revealed_points

	for index in range(1, _revival_trace_points.size()):
		var segment_start_length := _revival_trace_lengths[index - 1]
		var segment_end_length := _revival_trace_lengths[index]
		if reveal_length >= segment_end_length:
			revealed_points.append(_revival_trace_points[index])
			continue
		var segment_length := segment_end_length - segment_start_length
		if segment_length > 0.0:
			var segment_progress := clampf(
				(reveal_length - segment_start_length) / segment_length, 0.0, 1.0)
			revealed_points.append(_revival_trace_points[index - 1].lerp(
				_revival_trace_points[index], segment_progress))
		break
	return revealed_points


func _pulse_trace_glow() -> void:
	if _trace_glow_tween != null and _trace_glow_tween.is_running():
		_trace_glow_tween.kill()
	_trace_glow_tween = trace_glow.create_tween()
	_trace_glow_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_trace_glow_tween.tween_property(trace_glow, "modulate:a", 0.95, 0.05)
	_trace_glow_tween.tween_property(trace_glow, "modulate:a", 0.3, 0.15)


func _clear_trace() -> void:
	if _trace_glow_tween != null and _trace_glow_tween.is_running():
		_trace_glow_tween.kill()
	trace_line.points = PackedVector2Array()
	trace_glow.points = PackedVector2Array()
	trace_root.visible = false


func _style_text() -> void:
	var font := Assets.font()
	for label: Label in find_children("*", "Label", true, false):
		if font != null:
			label.add_theme_font_override(&"font", font)
		label.add_theme_color_override(&"font_outline_color", Color("#100306"))
		label.add_theme_constant_override(&"outline_size", 1)
	%TitleLabel.add_theme_color_override(&"font_color", RED)
	%SubtitleLabel.add_theme_color_override(&"font_color", SOFT_WHITE)
	fatal_label.add_theme_color_override(&"font_color", PALE_RED)
	kept_label.add_theme_color_override(&"font_color", PALE_RED)
	score_label.add_theme_color_override(&"font_color", SOFT_WHITE)
	lost_label.add_theme_color_override(&"font_color", RED)


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


func _connect_button() -> void:
	if not action_button.pressed.is_connected(_on_action_pressed):
		action_button.pressed.connect(_on_action_pressed)
	if not action_button.button_down.is_connected(_on_button_down):
		action_button.button_down.connect(_on_button_down)
	if not action_button.button_up.is_connected(_on_button_up):
		action_button.button_up.connect(_on_button_up)
	button_host.pivot_offset = button_host.size * 0.5


func _play_trace_reveal() -> void:
	trace_root.scale.x = 0.0
	_trace_tween = create_tween()
	_trace_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_trace_tween.tween_property(trace_root, "scale:x", 1.0, TRACE_REVEAL_TIME)
	_trace_tween.tween_property(trace_root, "modulate:a", 0.62, 0.18)
	_trace_tween.tween_property(trace_root, "modulate:a", 1.0, 0.24)


func _on_button_down() -> void:
	var tween := button_host.create_tween()
	tween.tween_property(button_host, "scale", Vector2.ONE * 0.94, 0.06)


func _on_button_up() -> void:
	var tween := button_host.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button_host, "scale", Vector2.ONE, 0.13)


func _on_action_pressed() -> void:
	action_pressed.emit()
