class_name WealthOdometer
extends Control

## Four mechanically linked number reels for the machine's run-wealth readout.
## Each authored reel sheet contains full-canvas frames so its glyph keeps the
## exact placement and pixel treatment from the source art.

const FRAME_COUNT := 11
const DIGIT_COUNT := 4
const PLACE_VALUES: Array[int] = [1000, 100, 10, 1]
# The authored sheets are ordered 0, 9, 7, 8, 6, 5, 4, 3, 2, 1, 0.
const FRAME_FOR_DIGIT: Array[int] = [0, 9, 8, 7, 6, 5, 4, 2, 3, 1]
const REEL_WINDOWS: Array[Rect2] = [
	Rect2(45.0, 258.0, 10.0, 14.0),
	Rect2(57.0, 258.0, 10.0, 14.0),
	Rect2(69.0, 258.0, 10.0, 14.0),
	Rect2(81.0, 258.0, 10.0, 14.0),
]
const ROLL_DISTANCE := 12.0
const MIN_ROLL_TIME := 0.24
const MAX_ROLL_TIME := 0.9
# A caller that asks for a specific roll length (the jackpot's deliberately slow
# payout) is allowed past MAX_ROLL_TIME, but not indefinitely.
const OVERRIDE_MAX_ROLL_TIME := 2.4
const VALUE_MODULUS := 10_000
const MACHINE_ART_TEXTURE_FILTER := CanvasItem.TEXTURE_FILTER_NEAREST

const BAR_TEXTURE: Texture2D = preload(
	"res://assets/images/machine_polished/wealth_crt.svg")
const CASES_TEXTURE: Texture2D = preload(
	"res://assets/images/machine new view/wealth_cases.png")
const REEL_TEXTURES: Array[Texture2D] = [
	preload("res://assets/images/machine new view/wealth_1st_reel.png"),
	preload("res://assets/images/machine new view/wealth_2nd_reel.png"),
	preload("res://assets/images/machine new view/wealth_3rd_reel.png"),
	preload("res://assets/images/machine new view/wealth_4th_reel.png"),
]

var _reels: Array[Dictionary] = []
var _roll_tween: Tween = null
var _value := 0
var _built := false
## A snapshot is a detached copy of the digit reels alone — no cases, no bar frame —
## so an overlay can fly the machine's own number around without the surrounding art
## coming with it. Set before the node enters the tree; _build_art() reads it once.
var snapshot_mode := false
## Starting placement of a lifted copy; the digit art remains in source coordinates.
var snapshot_origin := Vector2.ZERO
## How many digit slots stay visible, counted from the units end. Locking this keeps
## a drain that drops a digit from re-laying-out mid-animation.
var digit_window := DIGIT_COUNT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(160.0, 320.0)
	_build_art()
	_show_static_value(_value)


## `duration_override` lets a caller pace the roll itself (the jackpot rolls slowly on
## purpose); 0.0 keeps the delta-derived default.
func set_value(new_value: int, animated := true, duration_override := 0.0) -> void:
	new_value = maxi(0, new_value)
	if not _built:
		_value = new_value
		return
	if new_value == _value:
		return

	stop_roll()
	var from_value := _value
	_value = new_value
	if not animated:
		_show_static_value(_value)
		return

	var value_delta := absi(_value - from_value)
	var duration := clampf(duration_override, MIN_ROLL_TIME, OVERRIDE_MAX_ROLL_TIME) \
		if duration_override > 0.0 \
		else clampf(
			MIN_ROLL_TIME + log(1.0 + float(value_delta)) * 0.1,
			MIN_ROLL_TIME,
			MAX_ROLL_TIME)
	_roll_tween = create_tween()
	_roll_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_roll_tween.tween_method(
		_drive_roll.bind(from_value, _value), 0.0, 1.0, duration)
	_roll_tween.tween_callback(_finish_roll.bind(_value))


func stop_roll() -> void:
	if _roll_tween != null and _roll_tween.is_valid():
		_roll_tween.kill()
	_roll_tween = null
	if _built:
		_show_static_value(_value)


func get_value() -> int:
	return _value


func is_rolling() -> bool:
	return _roll_tween != null and _roll_tween.is_valid()


## A detached, art-free copy of the digit reels showing `value`. The caller owns it and
## is free to reparent, move and scale it — the per-digit clip Controls keep isolating
## their glyph out of the full-canvas sheet at any transform.
static func make_snapshot(value: int, window := DIGIT_COUNT) -> WealthOdometer:
	var snapshot := WealthOdometer.new()
	snapshot.name = "WealthDigitSnapshot"
	snapshot.snapshot_mode = true
	snapshot.digit_window = clampi(window, 1, DIGIT_COUNT)
	# _built is still false here, so this only seeds the value _ready() will draw.
	snapshot.set_value(value, false)
	return snapshot


func _build_art() -> void:
	if _built:
		return

	# The cases plate paints only the four digit windows, and the reel glyphs are dark
	# art authored to be read against it — so a snapshot keeps it and the lifted number
	# stays legible. Only the bar frame is dropped: it is cabinet trim.
	var cases := Sprite2D.new()
	cases.name = "WealthCasesArt"
	cases.texture = CASES_TEXTURE
	cases.centered = false
	cases.z_index = 0
	cases.texture_filter = MACHINE_ART_TEXTURE_FILTER
	add_child(cases)

	# The authored frame sits above the white cases and the rolling digits. Its
	# transparent windows leave the number reels visible while its borders stay
	# crisp on top of them.
	var bar: Sprite2D = null
	if not snapshot_mode:
		bar = Sprite2D.new()
		bar.name = "WealthBarArt"
		bar.texture = BAR_TEXTURE
		bar.centered = false
		bar.z_index = 2
		bar.texture_filter = MACHINE_ART_TEXTURE_FILTER

	for i in DIGIT_COUNT:
		var window_rect := REEL_WINDOWS[i]
		var clip := Control.new()
		clip.name = "Reel%d" % i
		clip.position = window_rect.position
		clip.size = window_rect.size
		clip.clip_contents = true
		clip.z_index = 1
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(clip)

		var current := _make_digit_sprite("Current", REEL_TEXTURES[i], window_rect)
		var next := _make_digit_sprite("Next", REEL_TEXTURES[i], window_rect)
		next.visible = false
		clip.add_child(current)
		clip.add_child(next)
		_reels.append({
			"window": window_rect,
			"clip": clip,
			"current": current,
			"next": next,
		})
	if bar != null:
		add_child(bar)
	_built = true
	_apply_digit_window()


## Leading slots outside the window are hidden, so a 3-digit snapshot is three reels
## wide rather than a number with a blank thousands column.
func _apply_digit_window() -> void:
	var first_visible := DIGIT_COUNT - clampi(digit_window, 1, DIGIT_COUNT)
	for i in _reels.size():
		(_reels[i]["clip"] as Control).visible = i >= first_visible


## Canvas-space box of the currently visible reel windows — what an overlay needs to
## centre and scale the number it lifted off the machine.
func visible_digit_bounds() -> Rect2:
	var first_visible := DIGIT_COUNT - clampi(digit_window, 1, DIGIT_COUNT)
	var bounds := REEL_WINDOWS[first_visible]
	for i in range(first_visible + 1, DIGIT_COUNT):
		bounds = bounds.merge(REEL_WINDOWS[i])
	return bounds


## Hides the digits on the REAL odometer while an overlay flies a snapshot of them,
## leaving the cases and bar frame in place so the cabinet keeps its empty windows.
func set_digits_hidden(hidden: bool) -> void:
	if not _built:
		return
	var first_visible := DIGIT_COUNT - clampi(digit_window, 1, DIGIT_COUNT)
	for i in _reels.size():
		(_reels[i]["clip"] as Control).visible = (not hidden) and i >= first_visible


func _make_digit_sprite(
		node_name: String, texture: Texture2D, window_rect: Rect2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.hframes = FRAME_COUNT
	sprite.centered = false
	sprite.position = -window_rect.position
	sprite.texture_filter = MACHINE_ART_TEXTURE_FILTER
	return sprite


func _show_static_value(value: int) -> void:
	for i in DIGIT_COUNT:
		_show_static_digit(i, _digit_at(value, PLACE_VALUES[i]))


func _show_static_digit(reel_index: int, digit: int) -> void:
	var reel := _reels[reel_index]
	var window_rect: Rect2 = reel["window"]
	var current := reel["current"] as Sprite2D
	var next := reel["next"] as Sprite2D
	current.frame = FRAME_FOR_DIGIT[digit]
	current.position = -window_rect.position
	current.visible = true
	next.position = -window_rect.position
	next.visible = false


func _drive_roll(progress: float, from_value: int, to_value: int) -> void:
	for i in DIGIT_COUNT:
		var place := PLACE_VALUES[i]
		var from_quotient := floori(float(from_value) / float(place))
		var to_quotient := floori(float(to_value) / float(place))
		var step_delta := to_quotient - from_quotient
		if step_delta == 0:
			_show_static_digit(i, posmod(from_quotient, 10))
			continue

		var direction := 1 if step_delta > 0 else -1
		var step_count := absi(step_delta)
		var reel_progress := float(step_count) * progress
		var completed_steps := mini(step_count, floori(reel_progress))
		var fraction := 0.0 if completed_steps == step_count \
			else reel_progress - float(completed_steps)
		var current_digit := posmod(
			from_quotient + completed_steps * direction, 10)
		var next_digit := posmod(current_digit + direction, 10)
		_position_reel(i, current_digit, next_digit, fraction, direction)


func _position_reel(
		reel_index: int, current_digit: int, next_digit: int,
		fraction: float, direction: int) -> void:
	var reel := _reels[reel_index]
	var window_rect: Rect2 = reel["window"]
	var current := reel["current"] as Sprite2D
	var next := reel["next"] as Sprite2D
	var origin := -window_rect.position
	current.frame = FRAME_FOR_DIGIT[current_digit]
	next.frame = FRAME_FOR_DIGIT[next_digit]
	current.position = origin + Vector2(0.0, -float(direction) * fraction * ROLL_DISTANCE)
	next.position = origin + Vector2(
		0.0, float(direction) * (1.0 - fraction) * ROLL_DISTANCE)
	current.visible = true
	next.visible = fraction > 0.0


func _finish_roll(value: int) -> void:
	_roll_tween = null
	_show_static_value(value)


func _digit_at(value: int, place: int) -> int:
	return posmod(floori(float(value % VALUE_MODULUS) / float(place)), 10)
