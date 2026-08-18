extends Control

## Persistent pixel-art transition cover owned by SceneNav.
##
## The transition intentionally uses a few cheap CanvasItem primitives rather than a
## generic fullscreen shader. At the game's 160x320 resolution the shutter, door edge,
## and dying trace read as authored machine presentation while keeping scene loading
## completely hidden underneath the cover.

const CANVAS_SIZE := Vector2(160.0, 320.0)
const NORMAL_EXIT_TIME := 0.42
const NORMAL_ENTER_TIME := 0.34
const DOOR_EXIT_TIME := 0.52
const DOOR_ENTER_TIME := 0.44
const FLATLINE_EXIT_TIME := 0.92
const FLATLINE_ENTER_TIME := 0.66

const DARK := Color(0.008, 0.012, 0.026, 1.0)
const DEEP_BLUE := Color(0.04, 0.10, 0.18, 1.0)
const MACHINE_BLUE := Color(0.33, 0.78, 1.0, 1.0)
const DOOR_ROSE := Color(1.0, 0.32, 0.72, 1.0)
const FLATLINE_RED := Color(1.0, 0.16, 0.24, 1.0)

var _kind := 0
var _door_side := -1
var _progress := 0.0
var _phase: StringName = &"hidden"
var _tween: Tween = null


func _ready() -> void:
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	position = Vector2.ZERO
	size = CANVAS_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false


func configure(kind: int, door_side: int = -1) -> void:
	_kind = kind
	_door_side = -1 if door_side <= 0 else 1
	queue_redraw()


func play_exit(kind: int, door_side: int = -1) -> void:
	configure(kind, door_side)
	_kill_tween()
	_phase = &"exit"
	_progress = 0.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()
	var duration := _duration(false)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(Callable(self, "_set_progress"), 0.0, 1.0, duration)
	await _tween.finished
	_set_progress(1.0)


func play_entrance() -> void:
	_kill_tween()
	_phase = &"entrance"
	_progress = 1.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()
	var duration := _duration(true)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_method(Callable(self, "_set_progress"), 1.0, 0.0, duration)
	await _tween.finished
	_set_progress(0.0)
	_phase = &"hidden"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func cancel() -> void:
	_kill_tween()
	_phase = &"hidden"
	_progress = 0.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _duration(entrance: bool) -> float:
	match _kind:
		1:
			return DOOR_ENTER_TIME if entrance else DOOR_EXIT_TIME
		2:
			return FLATLINE_ENTER_TIME if entrance else FLATLINE_EXIT_TIME
		_:
			return NORMAL_ENTER_TIME if entrance else NORMAL_EXIT_TIME


func _set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _cover_progress() -> float:
	return _progress if _phase == &"exit" else 1.0 - _progress


func _draw() -> void:
	var cover := clampf(_cover_progress(), 0.0, 1.0)
	match _kind:
		1:
			_draw_door(cover)
		2:
			_draw_flatline(cover)
		_:
			_draw_normal(cover)


func _draw_normal(cover: float) -> void:
	var dark_alpha := lerpf(0.0, 0.97, cover)
	draw_rect(Rect2(Vector2.ZERO, CANVAS_SIZE), Color(DARK, dark_alpha))
	# A narrow shutter rolls down over the cabinet before the destination is loaded.
	var shutter_y := lerpf(-24.0, CANVAS_SIZE.y + 24.0, cover)
	for index in range(7):
		var y := shutter_y - float(index) * 11.0
		var alpha := clampf(0.20 + cover * 0.60 - float(index) * 0.05, 0.0, 0.82)
		draw_rect(Rect2(0.0, y, CANVAS_SIZE.x, 2.0), Color(DEEP_BLUE, alpha))
	# These small lamps fade with the machine power-down and relight on entry.
	var lamp_alpha := clampf(1.0 - cover * 1.25, 0.0, 1.0)
	for x in [22.0, 45.0, 80.0, 115.0, 138.0]:
		draw_circle(Vector2(x, 160.0), 1.0, Color(MACHINE_BLUE, lamp_alpha))
	if cover > 0.02:
		draw_line(Vector2(14.0, 160.0), Vector2(146.0, 160.0),
			Color(MACHINE_BLUE, (1.0 - cover) * 0.55), 1.0)


func _draw_door(cover: float) -> void:
	var accent := DOOR_ROSE
	var dark_alpha := lerpf(0.03, 0.98, cover)
	draw_rect(Rect2(Vector2.ZERO, CANVAS_SIZE), Color(DARK, dark_alpha))
	var opening_width := lerpf(0.0, CANVAS_SIZE.x, cover)
	var opening_rect := Rect2(Vector2.ZERO, Vector2.ZERO)
	if _door_side < 0:
		opening_rect = Rect2(0.0, 0.0, opening_width, CANVAS_SIZE.y)
	else:
		opening_rect = Rect2(CANVAS_SIZE.x - opening_width, 0.0,
			opening_width, CANVAS_SIZE.y)
	draw_rect(opening_rect, Color(DEEP_BLUE, 0.38 + cover * 0.55))
	var edge_x := lerpf(0.0 if _door_side < 0 else CANVAS_SIZE.x,
		CANVAS_SIZE.x * 0.5, cover)
	var edge_alpha := clampf(0.92 - cover * 0.35, 0.0, 1.0)
	draw_line(Vector2(edge_x, 0.0), Vector2(edge_x, CANVAS_SIZE.y),
		Color(accent, edge_alpha), 2.0)
	var door_x := 12.0 if _door_side < 0 else CANVAS_SIZE.x - 12.0
	draw_line(Vector2(door_x, 64.0), Vector2(door_x, 256.0),
		Color(accent, clampf(0.35 + cover * 0.65, 0.0, 1.0)), 1.0)
	draw_line(Vector2(door_x, 64.0), Vector2(80.0, 160.0),
		Color(accent, (1.0 - cover) * 0.7), 1.0)
	draw_line(Vector2(door_x, 256.0), Vector2(80.0, 160.0),
		Color(accent, (1.0 - cover) * 0.7), 1.0)
	draw_circle(Vector2(80.0, 160.0), 2.0, Color(accent, (1.0 - cover) * 0.8))


func _draw_flatline(cover: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_progress * PI * 7.0)
	var dark_alpha := lerpf(0.04, 0.99, cover)
	draw_rect(Rect2(Vector2.ZERO, CANVAS_SIZE), Color(DARK, dark_alpha))
	var line_alpha := clampf(0.35 + pulse * 0.65, 0.0, 1.0) * (0.3 + cover * 0.7)
	var points := PackedVector2Array([
		Vector2(12.0, 160.0), Vector2(47.0, 160.0), Vector2(52.0, 151.0),
		Vector2(57.0, 174.0), Vector2(63.0, 160.0), Vector2(148.0, 160.0),
	])
	draw_polyline(points, Color(FLATLINE_RED, line_alpha), 2.0)
	draw_line(Vector2(12.0, 160.0), Vector2(148.0, 160.0),
		Color(FLATLINE_RED, line_alpha * 0.25), 1.0)
	# A slower red ring gives the failure path its own cadence without adding a
	# heavyweight fullscreen effect.
	draw_circle(Vector2(80.0, 160.0), 12.0 + pulse * 5.0,
		Color(FLATLINE_RED, line_alpha * 0.18), false, 1.0)


func _gui_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func _input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()
