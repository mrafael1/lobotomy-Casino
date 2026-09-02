extends Control

## Persistent pixel-art transition cover owned by SceneNav.
##
## The transition intentionally uses a few cheap CanvasItem primitives rather than a
## generic fullscreen shader. At the game's 160x320 resolution the shutter, door edge,
## and dying trace read as authored machine presentation while keeping scene loading
## completely hidden underneath the cover. The live scene-change animation is a single
## edge-to-edge curtain pass; the scene swap happens at its covered midpoint.

signal scene_swap_requested

const CANVAS_SIZE := Vector2(160.0, 320.0)
const NORMAL_EXIT_TIME := 0.42
const NORMAL_ENTER_TIME := 0.34
const DOOR_EXIT_TIME := 0.52
const DOOR_ENTER_TIME := 0.44
const FLATLINE_EXIT_TIME := 0.92
const FLATLINE_ENTER_TIME := 0.66
const WALLET_KIND := 3
const WALLET_ROW_POSITION := Vector2(7.0, 294.0)
const WALLET_ROW_SIZE := Vector2(42.0, 12.0)
const WALLET_COIN_SIZE := Vector2(9.0, 9.0)
const WALLET_TRANSFER_MIN_TIME := 0.35
const WALLET_TRANSFER_PER_CREDIT := 0.012
const WALLET_TRANSFER_MAX_TIME := 1.5
const WALLET_COIN_ASSET := "ui/coin.png"
const WALLET_COLOR := Color(0.92, 0.86, 0.56, 1.0)

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
var _swap_pending := false
var _animation_token := 0
var _wallet_row: HBoxContainer = null
var _wallet_label: Label = null
var _wallet_coin: TextureRect = null
var _wallet_tween: Tween = null
var _wallet_transfer_active := false
var _wallet_transfer_start := 0
var _wallet_transfer_end := 0


func _ready() -> void:
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	position = Vector2.ZERO
	size = CANVAS_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_build_wallet_display()
	visible = false


func configure(kind: int, door_side: int = -1, wallet_start: int = -1,
		wallet_end: int = -1) -> void:
	_kind = kind
	_door_side = -1 if door_side <= 0 else 1
	_kill_wallet_tween()
	_wallet_transfer_active = false
	_wallet_transfer_start = maxi(0, wallet_start)
	_wallet_transfer_end = maxi(0, wallet_end)
	if _wallet_row != null:
		_wallet_row.visible = kind == WALLET_KIND
	if kind == WALLET_KIND and wallet_start >= 0:
		_set_wallet_display(_wallet_transfer_start)
	queue_redraw()


## Plays the whole scene change as one owned animation. One curtain crosses the canvas,
## asks SceneNav to replace the scene when it fully covers the canvas, and continues in
## the same direction until it clears the destination. Keeping the swap point inside
## this method prevents the visible animation from being started once by the old scene
## and then restarted by the destination scene.
func play_transition(kind: int, door_side: int = -1, wallet_start: int = -1,
		wallet_end: int = -1) -> void:
	if _phase != &"hidden":
		return
	configure(kind, door_side, wallet_start, wallet_end)
	_animation_token += 1
	_swap_pending = false
	_phase = &"transition"
	_progress = 0.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

	if _kind == WALLET_KIND:
		# Wallet transitions use the same persistent black handoff as before, but still
		# travel through this one scene-swap lifecycle.
		_phase = &"covered"
		_set_progress(1.0)
	else:
		var half_duration := _transition_duration() * 0.5
		var curtain_arrived := await _animate_progress(
			0.0, 0.5, half_duration, Tween.TRANS_LINEAR)
		if not curtain_arrived or _phase != &"transition":
			return
		_set_progress(0.5)
	_swap_pending = true
	# Direct overlay tests can exercise the animation without a SceneNav listener.
	# Normal gameplay always has one listener and waits here until the destination has
	# been loaded, swapped, and allowed two frames to finish its deferred setup.
	if get_signal_connection_list(&"scene_swap_requested").is_empty():
		_swap_pending = false
	else:
		scene_swap_requested.emit()
	while _swap_pending and (_phase == &"transition" or _phase == &"covered"):
		await get_tree().process_frame
	if _phase != &"transition" and _phase != &"covered":
		return

	if _kind == WALLET_KIND:
		# Wallet handoffs deliberately stay black until the balance animation finishes;
		# the route screen is already present underneath the persistent cover.
		while _wallet_transfer_active and _phase == &"covered":
			await get_tree().process_frame
		if _phase != &"covered":
			return
		_complete_transition()
		return

	var curtain_left := await _animate_progress(
		0.5, 1.0, _transition_duration() * 0.5, Tween.TRANS_LINEAR)
	if not curtain_left:
		return
	if _phase != &"transition":
		return
	_set_progress(1.0)
	_complete_transition()


## The curtain's total travel time remains comparable to the previous cover/reveal
## pair, but it is now one directional pass instead of a shutter reversing direction.
func _transition_duration() -> float:
	match _kind:
		1:
			return DOOR_EXIT_TIME + DOOR_ENTER_TIME
		2:
			return FLATLINE_EXIT_TIME + FLATLINE_ENTER_TIME
		_:
			return NORMAL_EXIT_TIME + NORMAL_ENTER_TIME


## Called by SceneNav after the destination is safely underneath the cover.
func complete_scene_swap() -> void:
	if _phase == &"transition" or _phase == &"covered":
		_swap_pending = false


func play_exit(kind: int, door_side: int = -1, wallet_start: int = -1,
		wallet_end: int = -1) -> void:
	# Legacy direct-cover API retained for low-level callers. SceneNav uses the unified
	# play_transition() method above, so real scene changes never run this separately.
	# SceneNav owns the request lock, but the presentation is also deliberately
	# idempotent. A second caller joining the same phase must not kill the running
	# tween and restart the shutter from frame zero.
	if _phase == &"covered":
		return
	if _phase == &"exit":
		if _tween != null and _tween.is_valid():
			await _tween.finished
		return
	configure(kind, door_side, wallet_start, wallet_end)
	_kill_tween()
	_phase = &"exit"
	_progress = 0.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()
	if _kind == WALLET_KIND:
		_set_progress(1.0)
		_tween = null
		_phase = &"covered"
		return
	var duration := _duration(false)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(Callable(self, "_set_progress"), 0.0, 1.0, duration)
	await _tween.finished
	_set_progress(1.0)
	_tween = null
	_phase = &"covered"

func play_entrance() -> void:
	if _phase == &"hidden":
		return
	if _phase == &"entrance":
		if _tween != null and _tween.is_valid():
			await _tween.finished
		return
	if _kind == WALLET_KIND:
		_phase = &"hidden"
		_progress = 0.0
		visible = _wallet_transfer_active
		mouse_filter = Control.MOUSE_FILTER_STOP if _wallet_transfer_active \
			else Control.MOUSE_FILTER_IGNORE
		queue_redraw()
		return
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
	_tween = null
	_phase = &"hidden"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func cancel() -> void:
	_animation_token += 1
	_swap_pending = false
	_kill_tween()
	_kill_wallet_tween()
	_wallet_transfer_active = false
	if _wallet_row != null:
		_wallet_row.visible = false
	_phase = &"hidden"
	_progress = 0.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _animate_progress(from_value: float, to_value: float, duration: float,
		transition_type: Tween.TransitionType = Tween.TRANS_SINE) -> bool:
	_kill_tween()
	var token := _animation_token
	var tween := create_tween()
	_tween = tween
	tween.set_trans(transition_type).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(Callable(self, "_set_progress"), from_value, to_value, duration)
	await tween.finished
	if token != _animation_token or _tween != tween:
		return false
	_set_progress(to_value)
	_tween = null
	return true


func _complete_transition() -> void:
	_swap_pending = false
	_kill_tween()
	_phase = &"hidden"
	_progress = 0.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func begin_wallet_transfer(start_value: int, end_value: int) -> void:
	if _kind != WALLET_KIND:
		return
	_kill_wallet_tween()
	_wallet_transfer_start = maxi(0, start_value)
	_wallet_transfer_end = maxi(0, end_value)
	_wallet_transfer_active = true
	_wallet_row.visible = true
	_set_wallet_display(_wallet_transfer_start)
	var amount := absi(_wallet_transfer_end - _wallet_transfer_start)
	if amount == 0:
		_finish_wallet_transfer()
		return
	var duration := clampf(WALLET_TRANSFER_MIN_TIME
			+ float(amount) * WALLET_TRANSFER_PER_CREDIT,
			WALLET_TRANSFER_MIN_TIME, WALLET_TRANSFER_MAX_TIME)
	_wallet_tween = create_tween()
	_wallet_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wallet_tween.tween_method(
		Callable(self, "_drive_wallet_transfer"), 0.0, 1.0, duration)
	_wallet_tween.finished.connect(_finish_wallet_transfer)


func wait_for_wallet_transfer() -> void:
	while _wallet_transfer_active:
		await get_tree().process_frame


func finish_wallet_handoff() -> void:
	_kill_wallet_tween()
	_wallet_transfer_active = false
	if _wallet_row != null:
		_wallet_row.visible = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _build_wallet_display() -> void:
	_wallet_row = HBoxContainer.new()
	_wallet_row.name = "WalletHandoff"
	_wallet_row.position = WALLET_ROW_POSITION
	_wallet_row.size = WALLET_ROW_SIZE
	_wallet_row.add_theme_constant_override("separation", 2)
	_wallet_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_wallet_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wallet_row.z_index = 20
	_wallet_row.visible = false
	add_child(_wallet_row)

	_wallet_label = Label.new()
	_wallet_label.name = "WalletValue"
	_wallet_label.custom_minimum_size = Vector2(0.0, WALLET_ROW_SIZE.y)
	_wallet_label.add_theme_font_size_override("font_size", 7)
	_wallet_label.add_theme_color_override("font_color", WALLET_COLOR)
	_wallet_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_wallet_label.add_theme_constant_override("outline_size", 1)
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_wallet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wallet_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_wallet_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var assets := get_node_or_null("/root/Assets")
	var shared_font: FontFile = null
	if assets != null:
		shared_font = assets.call("font") as FontFile
	if shared_font != null:
		_wallet_label.add_theme_font_override("font", shared_font)
		_wallet_row.add_child(_wallet_label)

	_wallet_coin = TextureRect.new()
	_wallet_coin.name = "WalletCoin"
	if assets != null:
		_wallet_coin.texture = assets.call("texture", WALLET_COIN_ASSET, true) as Texture2D
	else:
		_wallet_coin.texture = load("res://assets/images/ui/coin.png") as Texture2D
	_wallet_coin.custom_minimum_size = WALLET_COIN_SIZE
	_wallet_coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wallet_coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_wallet_coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wallet_coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_wallet_coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wallet_row.add_child(_wallet_coin)


func _set_wallet_display(value: int) -> void:
	if _wallet_label != null and is_instance_valid(_wallet_label):
		_wallet_label.text = str(maxi(0, value))


func _drive_wallet_transfer(progress: float) -> void:
	var clamped := clampf(progress, 0.0, 1.0)
	_set_wallet_display(roundi(lerpf(float(_wallet_transfer_start),
		float(_wallet_transfer_end), clamped)))


func _finish_wallet_transfer() -> void:
	_set_wallet_display(_wallet_transfer_end)
	_wallet_transfer_active = false
	_wallet_tween = null
	if _phase == &"hidden":
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func _kill_wallet_tween() -> void:
	if _wallet_tween != null and _wallet_tween.is_valid():
		_wallet_tween.kill()
	_wallet_tween = null


func _duration(entrance: bool) -> float:
	match _kind:
		1:
			return DOOR_ENTER_TIME if entrance else DOOR_EXIT_TIME
		2:
			return FLATLINE_ENTER_TIME if entrance else FLATLINE_EXIT_TIME
		WALLET_KIND:
			return 0.0
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
	match _phase:
		&"exit":
			return _progress
		&"covered":
			return 1.0
		&"entrance":
			return 1.0 - _progress
		_:
			return 0.0


func _draw() -> void:
	if _phase == &"transition":
		_draw_single_pass(_progress)
		return
	var cover := clampf(_cover_progress(), 0.0, 1.0)
	match _kind:
		1:
			_draw_door(cover)
		2:
			_draw_flatline(cover)
		WALLET_KIND:
			_draw_wallet(cover)
		_:
			_draw_normal(cover)


func _draw_single_pass(progress: float) -> void:
	var travel := clampf(progress, 0.0, 1.0)
	if travel <= 0.0 or travel >= 1.0:
		return
	# The curtain is exactly one canvas wide. It starts just outside one edge, fully
	# covers the canvas at 0.5 (the scene-swap point), and exits through the opposite
	# edge. Unlike the old shutter, it never reverses direction on the destination.
	var moves_right := _door_side <= 0
	var curtain_x := lerpf(-CANVAS_SIZE.x, CANVAS_SIZE.x, travel) \
		if moves_right else lerpf(CANVAS_SIZE.x, -CANVAS_SIZE.x, travel)
	var curtain_rect := Rect2(curtain_x, 0.0, CANVAS_SIZE.x, CANVAS_SIZE.y)
	var accent := MACHINE_BLUE
	if _kind == 1:
		accent = DOOR_ROSE
	elif _kind == 2:
		accent = FLATLINE_RED
	draw_rect(curtain_rect, Color(DARK, 0.99))

	# Sparse pixel bands keep the transition readable without adding a shader or a
	# second animated object. The two edges are intentionally asymmetric: one is the
	# leading scan edge, the other is the quiet tail left behind it.
	var leading_x := curtain_x + CANVAS_SIZE.x if moves_right else curtain_x
	var trailing_x := curtain_x if moves_right else curtain_x + CANVAS_SIZE.x
	var leading_alpha := 0.5 + 0.45 * absf(sin(travel * PI))
	var trailing_alpha := 0.25 + 0.25 * absf(sin(travel * PI))
	if leading_x > -2.0 and leading_x < CANVAS_SIZE.x + 2.0:
		draw_line(Vector2(leading_x, 0.0), Vector2(leading_x, CANVAS_SIZE.y),
			Color(accent, leading_alpha), 2.0)
	if trailing_x > -2.0 and trailing_x < CANVAS_SIZE.x + 2.0:
		draw_line(Vector2(trailing_x, 0.0), Vector2(trailing_x, CANVAS_SIZE.y),
			Color(DEEP_BLUE, trailing_alpha), 1.0)
	var stripe_left := maxf(curtain_rect.position.x, 0.0)
	var stripe_right := minf(curtain_rect.end.x, CANVAS_SIZE.x)
	if stripe_right > stripe_left:
		for y in [72.0, 160.0, 248.0]:
			draw_line(Vector2(stripe_left, y), Vector2(stripe_right, y),
				Color(DEEP_BLUE, 0.55), 1.0)
		if _kind == 2:
			draw_line(Vector2(stripe_left, 160.0), Vector2(stripe_right, 160.0),
				Color(accent, 0.8), 1.0)


func _draw_wallet(cover: float) -> void:
	if cover > 0.0:
		draw_rect(Rect2(Vector2.ZERO, CANVAS_SIZE), Color.BLACK)


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
