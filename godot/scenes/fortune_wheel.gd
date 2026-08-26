class_name FortuneWheelDisplay
extends Control

## Native-resolution wheel art for the Bonus route.  The glow is built from
## layered pixel-sized rings and bulbs instead of a blurred texture, so it stays
## sharp at the game's integer-scaled 160x320 viewport.

signal spin_finished(reward_id: String)

const CANVAS_SIZE := Vector2(160.0, 320.0)
const CENTER := Vector2(80.0, 103.0)
const WHEEL_RADIUS := 42.0
const BULB_RADIUS := 49.0
const POINTER_ANGLE := -PI * 0.5
const SEGMENT_COUNT := 8

const CYAN := Color(0.42, 1.0, 0.95)
const HOT_CYAN := Color(0.72, 1.0, 0.98)
const GOLD := Color(1.0, 0.84, 0.38)
const HOT_GOLD := Color(1.0, 0.95, 0.62)
const ROSE := Color(1.0, 0.35, 0.66)
const INK := Color(0.055, 0.035, 0.105)
const HUB := Color(0.10, 0.055, 0.17)
const SEGMENT_COLORS: Array[Color] = [
	Color(0.16, 0.08, 0.25),
	Color(0.11, 0.16, 0.27),
	Color(0.24, 0.08, 0.24),
	Color(0.11, 0.21, 0.25),
	Color(0.28, 0.14, 0.12),
	Color(0.14, 0.10, 0.29),
	Color(0.25, 0.08, 0.19),
	Color(0.32, 0.18, 0.08),
]

var _font: Font = null
var _wheel_angle := 0.0
var _result_id := ""
var _result_index := -1
var _spinning := false
var _flash_time := 0.0
var _pulse_time := 0.0
var _spin_tween: Tween = null

func _ready() -> void:
	size = CANVAS_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = Assets.font()
	queue_redraw()

func _process(delta: float) -> void:
	_pulse_time += delta
	if _flash_time > 0.0:
		_flash_time = maxf(0.0, _flash_time - delta)
	queue_redraw()

func is_spinning() -> bool:
	return _spinning

func current_result_id() -> String:
	return _result_id

func spin_to_reward(reward_id: String) -> bool:
	if _spinning or not FortuneWheelRules.is_valid_reward(reward_id):
		return false
	if _spin_tween != null and _spin_tween.is_valid():
		_spin_tween.kill()
	_result_id = reward_id
	_result_index = FortuneWheelRules.segment_index(reward_id)
	_spinning = true
	_flash_time = 0.0
	var slice := TAU / float(SEGMENT_COUNT)
	var desired_angle := -float(_result_index + 1) * slice + slice * 0.5
	var target_angle := desired_angle + TAU * 6.0
	while target_angle <= _wheel_angle + TAU * 3.0:
		target_angle += TAU
	_spin_tween = create_tween()
	_spin_tween.tween_method(_set_wheel_angle, _wheel_angle, target_angle, 2.35) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_spin_tween.tween_callback(_finish_spin)
	queue_redraw()
	return true

## Used when a saved route already has a locked result.  It skips the animation
## and places that same segment under the pointer without rolling again.
func present_reward(reward_id: String) -> void:
	if not FortuneWheelRules.is_valid_reward(reward_id):
		return
	if _spin_tween != null and _spin_tween.is_valid():
		_spin_tween.kill()
	_result_id = reward_id
	_result_index = FortuneWheelRules.segment_index(reward_id)
	_spinning = false
	var slice := TAU / float(SEGMENT_COUNT)
	_wheel_angle = -float(_result_index + 1) * slice + slice * 0.5
	queue_redraw()

func _set_wheel_angle(value: float) -> void:
	_wheel_angle = value
	queue_redraw()

func _finish_spin() -> void:
	_spinning = false
	_flash_time = 0.8
	queue_redraw()
	spin_finished.emit(_result_id)

func _draw() -> void:
	_draw_wheel_shadow()
	_draw_segments()
	_draw_bulbs()
	_draw_pointer()
	_draw_sparks()

func _draw_wheel_shadow() -> void:
	draw_circle(CENTER + Vector2(1.0, 2.0), WHEEL_RADIUS + 7.0, Color(0.0, 0.0, 0.0, 0.72))
	# Layered rings read as neon glow at native resolution while retaining hard edges.
	draw_arc(CENTER, WHEEL_RADIUS + 6.0, 0.0, TAU, 64, Color(CYAN.r, CYAN.g, CYAN.b, 0.10), 4.0, false)
	draw_arc(CENTER, WHEEL_RADIUS + 4.0, 0.0, TAU, 64, Color(CYAN.r, CYAN.g, CYAN.b, 0.22), 2.0, false)
	draw_arc(CENTER, WHEEL_RADIUS + 2.0, 0.0, TAU, 64, CYAN, 1.0, false)

func _draw_segments() -> void:
	var slice := TAU / float(SEGMENT_COUNT)
	for index in SEGMENT_COUNT:
		var start_angle := POINTER_ANGLE + _wheel_angle + float(index) * slice
		var end_angle := start_angle + slice
		var points := PackedVector2Array()
		points.append(CENTER)
		for step in 9:
			var angle := lerpf(start_angle, end_angle, float(step) / 8.0)
			points.append(_point_on_ring(angle, WHEEL_RADIUS))
		var segment_color: Color = SEGMENT_COLORS[index]
		draw_colored_polygon(points, segment_color)
		var edge_color := Color(GOLD.r, GOLD.g, GOLD.b, 0.52) if index % 2 == 0 \
			else Color(CYAN.r, CYAN.g, CYAN.b, 0.46)
		draw_line(CENTER, _point_on_ring(start_angle, WHEEL_RADIUS), edge_color, 1.0, false)
		if index == _result_index and not _spinning:
			draw_arc(CENTER, WHEEL_RADIUS - 2.0, start_angle + 0.025,
				end_angle - 0.025, 12, HOT_GOLD, 3.0, false)
		_draw_segment_label(index, start_angle + slice * 0.5)

	draw_circle(CENTER, WHEEL_RADIUS - 6.0, Color(INK.r, INK.g, INK.b, 0.56))
	draw_arc(CENTER, WHEEL_RADIUS - 6.0, 0.0, TAU, 48, Color(HOT_CYAN.r, HOT_CYAN.g, HOT_CYAN.b, 0.64), 1.0, false)
	# The hub is intentionally tiny and mechanical: a bright ring, a dark cap, and a
	# four-pixel glint echo the machine's authored meter highlights.
	draw_circle(CENTER, 10.0, Color(CYAN.r, CYAN.g, CYAN.b, 0.17))
	draw_circle(CENTER, 8.0, HUB)
	draw_arc(CENTER, 8.0, 0.0, TAU, 32, GOLD, 1.0, false)
	draw_rect(Rect2(CENTER - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), HOT_GOLD)
	draw_line(CENTER + Vector2(-4.0, 0.0), CENTER + Vector2(4.0, 0.0), Color(ROSE.r, ROSE.g, ROSE.b, 0.75), 1.0, false)

func _draw_segment_label(index: int, angle: float) -> void:
	if _font == null:
		return
	var reward := FortuneWheelRules.reward_for_id(FortuneWheelRules.SEGMENT_IDS[index])
	var label := String(reward.get("wheelLabel", ""))
	var label_radius := 27.0
	var label_center := CENTER + Vector2.from_angle(angle) * label_radius
	var label_color := HOT_GOLD if index == _result_index and not _spinning else Color(0.92, 0.92, 0.88)
	draw_string(_font, Vector2(roundf(label_center.x - 17.0), roundf(label_center.y + 2.0)),
		label, HORIZONTAL_ALIGNMENT_CENTER, 34.0, 4, label_color)

func _draw_bulbs() -> void:
	for index in 16:
		var angle := POINTER_ANGLE + TAU * float(index) / 16.0
		var position := _point_on_ring(angle, BULB_RADIUS)
		var base_color := CYAN if index % 2 == 0 else GOLD
		var wave := (sin(_pulse_time * 7.0 + float(index) * 0.85) + 1.0) * 0.5
		var alpha := 0.23 + wave * 0.42
		draw_circle(position, 3.2, _with_alpha(base_color, alpha * 0.24))
		draw_rect(Rect2(Vector2(floorf(position.x), floorf(position.y)), Vector2(2.0, 2.0)),
			_with_alpha(base_color, alpha))
		draw_rect(Rect2(Vector2(floorf(position.x), floorf(position.y)), Vector2(1.0, 1.0)),
			_with_alpha(HOT_CYAN if base_color == CYAN else HOT_GOLD, minf(1.0, alpha + 0.25)))

func _draw_pointer() -> void:
	var tip := CENTER + Vector2.from_angle(POINTER_ANGLE) * (WHEEL_RADIUS + 9.0)
	var left := tip + Vector2(-5.0, 9.0)
	var right := tip + Vector2(5.0, 9.0)
	var triangle := PackedVector2Array([tip, left, right])
	draw_colored_polygon(triangle, Color(ROSE.r, ROSE.g, ROSE.b, 0.20))
	draw_colored_polygon(PackedVector2Array([tip, left + Vector2(1.0, -1.0), right + Vector2(-1.0, -1.0)]), GOLD)
	draw_line(tip, left, HOT_GOLD, 1.0, false)
	draw_line(tip, right, HOT_GOLD, 1.0, false)
	draw_rect(Rect2(tip - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), HOT_CYAN)

func _draw_sparks() -> void:
	if _flash_time <= 0.0 or _spinning:
		return
	var strength := clampf(_flash_time / 0.8, 0.0, 1.0)
	for index in 8:
		var angle := POINTER_ANGLE + TAU * float(index) / 8.0
		var start := _point_on_ring(angle, WHEEL_RADIUS + 9.0)
		var length := 5.0 + float((index * 3) % 5)
		var end := _point_on_ring(angle, WHEEL_RADIUS + 9.0 + length * strength)
		draw_line(start, end, _with_alpha(HOT_GOLD if index % 2 == 0 else HOT_CYAN, strength), 1.0, false)

func _point_on_ring(angle: float, radius: float) -> Vector2:
	return CENTER + Vector2.from_angle(angle) * radius

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))
