class_name DealerBar
extends RefCounted

## The dealer's countdown bar on the TV and its three cumulative warning lights.
##
## Seam 4.4a. This is the bar as a DISPLAY DEVICE: it is told which frame to walk
## to and which lights to hold, and it owns getting there — the one-frame-per-
## tick walk toward the target, and the blink the lit warnings share.
##
## What it is deliberately NOT told to do is decide. Which frame the countdown
## has earned, and which of the three lights the current multiplier lights, is a
## hundred lines of rules in _refresh_dealer_countdown reading the bet multiplier,
## the pending combo defeat, the glitch step and the Energy Drink's cap. That is
## not presentation and it stays in the machine; measuring it made the split
## obvious, because every one of those inputs is store state and none of them is
## a sprite.
##
## The five fields that ARE the animation — the displayed frame, the frame being
## walked to, the tick accumulator, the initialised flag and the beep clock — had
## no readers outside the three functions that move them.

const SHEET := "machine new view/dealer_bar.png"
const FRAME_COUNT := 13
const OVERLAY_1_SHEET := "machine new view/dealer_bar_overlay_1.png"
const OVERLAY_2_SHEET := "machine new view/dealer_bar_overlay_2.png"
const OVERLAY_3_SHEET := "machine new view/dealer_bar_overlay_3.png"
const OVERLAY_1_FRAMES := 12
const OVERLAY_2_FRAMES := 11
const OVERLAY_3_FRAMES := 10

## The bar walks one frame per tick rather than jumping, so a Dealer's Tip's head
## start is visible as movement instead of appearing as a different bar.
const PROGRESS_FRAME_TIME := 0.10

## Every lit warning beeps; how fast is what changes. A lone first light beeps on the
## slow period, and from the second light on it tightens to the fast one, so the machine
## audibly speeds up as the dealer closes in.
const OVERLAY_BEEP_PERIOD := 0.9
const OVERLAY_SLOW_BEEP_PERIOD := 1.8
const OVERLAY_BEEP_TIME := 0.5
const OVERLAY_BEEP_MIN_ALPHA := 0.18
const WARNING_FAST_BEEP_LIGHTS := 2

## The dealer interface draws over the cabinet, under the icons.
const Z_INDEX := 11

var _view: MachineView = null

var _bar_sprite: Sprite2D = null
var _overlay_1: Sprite2D = null
var _overlay_2: Sprite2D = null
var _overlay_3: Sprite2D = null

var _display_frame: int = 0
var _target_frame: int = 0
var _progress_time: float = 0.0
var _frame_initialized := false
var _beep_time := 0.0
## How many lights the state earned. Only the beep reads it — the lights
## themselves are set directly — and it gates the tempo, not the visibility.
var _warning_wanted := 0

func _init(view: MachineView) -> void:
	_view = view

## Built from the machine's control-art pass, at the line these four sheets have
## always been created on.
func build() -> void:
	_bar_sprite = _view.full_canvas_sheet(SHEET, FRAME_COUNT)
	_overlay_1 = _view.full_canvas_sheet(OVERLAY_1_SHEET, OVERLAY_1_FRAMES)
	_overlay_2 = _view.full_canvas_sheet(OVERLAY_2_SHEET, OVERLAY_2_FRAMES)
	_overlay_3 = _view.full_canvas_sheet(OVERLAY_3_SHEET, OVERLAY_3_FRAMES)
	for sprite in overlays():
		if sprite != null:
			sprite.z_index = Z_INDEX
			sprite.visible = false
	if _bar_sprite != null:
		_bar_sprite.z_index = Z_INDEX
		_bar_sprite.visible = true

func overlays() -> Array:
	return [_bar_sprite, _overlay_1, _overlay_2, _overlay_3]

func warning_lights() -> Array:
	return [_overlay_1, _overlay_2, _overlay_3]

func bar_sprite() -> Sprite2D:
	return _bar_sprite

## --- the frame walk ----------------------------------------------------------------

## Point the bar at the frame the countdown has earned. The FIRST call and any
## BACKWARD move snap — a dealer visit or a new run resets the countdown, and
## walking a reset backwards frame by frame would read as the bar draining rather
## than starting over. Everything else is walked forward by step_progress.
func seek(progress_frame: int) -> void:
	if _bar_sprite == null:
		return
	if not _frame_initialized or progress_frame < _display_frame:
		_frame_initialized = true
		_display_frame = progress_frame
		_target_frame = progress_frame
		_progress_time = 0.0
		_set_progress_frame(progress_frame)
		return
	_target_frame = progress_frame
	if _display_frame == _target_frame:
		_progress_time = 0.0

## Re-applies the current displayed frame to the warning sheets. They follow the
## bar's progress, and their shorter tails clamp to their own final frame.
func sync_overlay_frames() -> void:
	_set_overlay_progress_frame(_display_frame)

func step_progress(delta: float) -> void:
	if not _frame_initialized or _bar_sprite == null \
			or _display_frame == _target_frame:
		_progress_time = 0.0
		return
	_progress_time += maxf(0.0, delta)
	if _progress_time < PROGRESS_FRAME_TIME:
		return
	_progress_time -= PROGRESS_FRAME_TIME
	var direction := 1 if _target_frame > _display_frame else -1
	_display_frame += direction
	_set_progress_frame(_display_frame)
	if _display_frame == _target_frame:
		_progress_time = 0.0

func _set_progress_frame(progress_frame: int) -> void:
	var frame := clampi(progress_frame, 0, FRAME_COUNT - 1)
	_view.set_sheet_frame(_bar_sprite, frame)
	_set_overlay_progress_frame(frame)

func _set_overlay_progress_frame(progress_frame: int) -> void:
	for overlay in warning_lights():
		if overlay != null:
			(overlay as Sprite2D).frame = clampi(progress_frame, 0, overlay.hframes - 1)

## --- the warning lights --------------------------------------------------------------

## `wanted` is how many lights the state earned; the beep tempo reads it. The
## three booleans are which sheets actually draw, which the caller has already
## resolved against the spin gates — a light that is earned but not yet allowed
## is still counted for the tempo and simply not shown.
func set_warning_lights(wanted: int, show_1: bool, show_2: bool, show_3: bool) -> void:
	_warning_wanted = wanted
	var wants := [show_1, show_2, show_3]
	var lights := warning_lights()
	for i in lights.size():
		var overlay := lights[i] as Sprite2D
		if overlay == null:
			continue
		var was_visible := overlay.visible
		overlay.visible = bool(wants[i])
		# The alpha is the beep's, and a light that has just appeared or just gone
		# must not inherit whatever dim the last blink left on it.
		if overlay.visible != was_visible or not overlay.visible:
			overlay.modulate.a = 1.0

func _beep_period() -> float:
	return OVERLAY_BEEP_PERIOD if _warning_wanted >= WARNING_FAST_BEEP_LIGHTS \
		else OVERLAY_SLOW_BEEP_PERIOD

func step_beep(delta: float) -> void:
	var active := false
	for overlay in warning_lights():
		if overlay != null and (overlay as Sprite2D).visible:
			active = true
			break
	if not active:
		_beep_time = 0.0
		for overlay in warning_lights():
			if overlay != null:
				(overlay as Sprite2D).modulate.a = 1.0
		return
	_beep_time = fmod(_beep_time + delta, _beep_period())
	# One state change per beep, not a fade: the lights drop to the dim alpha for
	# OVERLAY_BEEP_TIME and snap back for the rest of the period. Interpolating between
	# the two read as a second, breathing animation on top of the blink.
	var alpha := 1.0
	if _beep_time < OVERLAY_BEEP_TIME:
		alpha = OVERLAY_BEEP_MIN_ALPHA
	for overlay in warning_lights():
		if overlay != null and (overlay as Sprite2D).visible:
			(overlay as Sprite2D).modulate.a = alpha

## --- what the smoke checks read --------------------------------------------------------

func beep_period() -> float:
	return _beep_period()

## Puts the blink back to the start of its period, so a check can drive it a
## known distance rather than from wherever the last one left it.
func reset_beep() -> void:
	_beep_time = 0.0

func warning_light(index: int) -> Sprite2D:
	var lights := warning_lights()
	return lights[index] as Sprite2D if index >= 0 and index < lights.size() else null

func display_frame() -> int:
	return _display_frame

func target_frame() -> int:
	return _target_frame
