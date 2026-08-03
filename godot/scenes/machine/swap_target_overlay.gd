class_name SwapTargetOverlay
extends RefCounted

## The cues Swap draws on the reels while it is armed: an amber frame with corner
## ticks on every slot that takes part, a green frame on the reel the dragged
## symbol may legally land on, and a red cross on the source reel it may not go
## back onto (issue #181).
##
## Seam 4.6b, and it is the ART only. Which reel is the source, whether a drag is
## in flight and what a drop actually does all stay in the machine — this is told
## where to draw and told which reel is currently under the pointer.
##
## The targeting layer these parent into is the machine's too, and is passed in
## rather than owned: four different arming paths (reel picker, shift, cheat,
## swap) build into that one layer, and _clear_targeting frees the lot. A
## component that owned it would be arbitrating between those four, which is the
## coordinator shape the TV stack was struck for in 4.4c.

## The full reel a Swap cue covers: the hole's column, grown to take in the strip
## symbols above and below, because what the power moves is the reel and not the
## window.
const REEL_HALF_HEIGHT := ReelSymbols.OFFSET + ReelSymbols.CENTER_H * 0.5

const SLOT_FRAME_FILL := Color(1.0, 0.82, 0.42, 0.05)
const SLOT_FRAME_BORDER := Color(1.0, 0.82, 0.42, 0.55)
## Corner ticks: the pixel-art shorthand for "slot" at this size.
const SLOT_TICK_SIZE := Vector2(3.0, 1.0)

const SLOT_PULSE_TIME := 0.9
const SLOT_PULSE_LOW := 0.45
const SLOT_PULSE_HIGH := 0.9

const VALID_FILL := Color(0.30, 0.90, 0.52, 0.16)
const VALID_BORDER := Color(0.45, 1.0, 0.62, 0.9)
const INVALID_FILL := Color(0.72, 0.04, 0.10, 0.28)
const INVALID_BORDER := Color(1.0, 0.22, 0.28, 0.95)
## Two rotated 1px bars, not a font glyph: a DTM-Sans "X" crammed into a 17x26
## panel was the least legible thing on the machine.
const CROSS_COLOR := Color(1.0, 0.30, 0.34, 0.95)
const CROSS_THICKNESS := 1.0
const CROSS_ANGLE_DEG := 38.0

var _view: MachineView = null
var _holes: Array = []
var _window: Dictionary = {}

var _slot_hints: Array = []
var _invalid_overlay: Panel = null
var _valid_overlay: Panel = null
var _feedback_reel := -1
var _pulse_tween: Tween = null

func _init(view: MachineView, holes: Array, window: Dictionary) -> void:
	_view = view
	_holes = holes
	_window = window

func reel_rect(reel_index: int) -> Rect2:
	var hole: Dictionary = _holes[reel_index]
	var centre_y: float = float(_window["top"]) + float(_window["height"]) * 0.5
	return Rect2(float(hole["left"]), centre_y - REEL_HALF_HEIGHT,
		float(hole["width"]), REEL_HALF_HEIGHT * 2.0)

## --- the slot frames ------------------------------------------------------------------

## Marks one reel hole as a slot that takes part in the swap: a thin amber frame with
## corner ticks. Replaces the old brown wash and three hand-placed shard rectangles,
## which were programmer art and read as damage rather than as a target (issue #181).
## The node keeps its historical name — the scene smoke looks it up by it.
func build_slot_hint(layer: Control, reel_index: int) -> void:
	if layer == null or reel_index < 0 or reel_index >= _holes.size():
		return
	var column := reel_rect(reel_index)
	var frame := Panel.new()
	frame.name = "SwapRubbleHint%d" % reel_index
	frame.position = column.position
	frame.size = column.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.z_index = -1
	var style := StyleBoxFlat.new()
	style.bg_color = SLOT_FRAME_FILL
	style.border_color = SLOT_FRAME_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(1)
	frame.add_theme_stylebox_override("panel", style)
	layer.add_child(frame)
	for corner in [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0)]:
		var tick := ColorRect.new()
		tick.color = SLOT_FRAME_BORDER
		tick.size = SLOT_TICK_SIZE
		tick.position = Vector2(
			corner.x * (frame.size.x - SLOT_TICK_SIZE.x),
			corner.y * (frame.size.y - SLOT_TICK_SIZE.y))
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(tick)
	_slot_hints.append(frame)

func slot_hints() -> Array:
	return _slot_hints

## One shared breath across all three slot frames, replacing the old flash on the whole
## targeting layer so the drag ghost and buttons keep a steady opacity.
func start_pulse() -> void:
	stop_pulse()
	if _slot_hints.is_empty():
		return
	_pulse_tween = _view.tween().set_loops()
	for target_alpha in [SLOT_PULSE_LOW, SLOT_PULSE_HIGH]:
		_pulse_tween.set_parallel(true)
		for hint: Panel in _slot_hints:
			_pulse_tween.tween_property(hint, "modulate:a", target_alpha,
				SLOT_PULSE_TIME * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse_tween.chain()

## Stops the breathing only. The hint list belongs to the targeting layer that owns the
## frames and is cleared with it — clearing it here made start_pulse (which stops before
## it starts) find an empty list and return, so the frames never pulsed at all.
func stop_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null

## --- the destination cues ---------------------------------------------------------------

func _make_panel(layer: Control, node_name: String, reel_index: int, fill: Color,
		border: Color) -> Panel:
	var column := reel_rect(reel_index)
	var overlay := Panel.new()
	overlay.name = node_name
	overlay.position = column.position + Vector2(2.0, 2.0)
	overlay.size = column.size - Vector2(4.0, 4.0)
	overlay.z_index = 1
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(1)
	overlay.add_theme_stylebox_override("panel", style)
	layer.add_child(overlay)
	return overlay

func build_destination_cues(layer: Control, reel_index: int) -> void:
	if layer == null or reel_index < 0 or reel_index >= _holes.size():
		return
	if _invalid_overlay != null and is_instance_valid(_invalid_overlay):
		_invalid_overlay.queue_free()
	if _valid_overlay != null and is_instance_valid(_valid_overlay):
		_valid_overlay.queue_free()
	var overlay := _make_panel(layer, "SwapInvalidTarget", reel_index,
		INVALID_FILL, INVALID_BORDER)
	var span := minf(overlay.size.x, overlay.size.y) - 6.0
	for angle_deg in [CROSS_ANGLE_DEG, -CROSS_ANGLE_DEG]:
		var bar := ColorRect.new()
		bar.color = CROSS_COLOR
		bar.size = Vector2(span, CROSS_THICKNESS)
		bar.pivot_offset = bar.size * 0.5
		bar.position = overlay.size * 0.5 - bar.size * 0.5
		bar.rotation = deg_to_rad(angle_deg)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(bar)
	# Visible but fully transparent: update_feedback owns the alpha.
	overlay.modulate.a = 0.0
	_invalid_overlay = overlay
	var valid := _make_panel(layer, "SwapValidTarget", reel_index, VALID_FILL, VALID_BORDER)
	valid.visible = false
	_valid_overlay = valid
	_feedback_reel = reel_index

## Exactly one destination cue is live at a time: a green frame on a legal reel, a red
## cross on the source reel the symbol may not go back onto, and nothing at all while
## the pointer is off the reels.
##
## `source_reel` is passed rather than read: which reel the drag started from is the
## machine's, and it is the only thing that makes a target illegal.
func update_feedback(target_reel: int, source_reel: int) -> void:
	_feedback_reel = target_reel
	var invalid := target_reel == source_reel
	if _invalid_overlay != null and is_instance_valid(_invalid_overlay):
		_invalid_overlay.modulate.a = 1.0 if invalid else 0.0
	if _valid_overlay == null or not is_instance_valid(_valid_overlay):
		return
	var legal := target_reel >= 0 and target_reel < _holes.size() and not invalid
	_valid_overlay.visible = legal
	if legal:
		# Same rect the panel was built with, so the green cue sits on the reel exactly
		# like the red one — following the hole alone left it hanging off the bottom once
		# the cues grew to cover the whole reel.
		_valid_overlay.position = reel_rect(target_reel).position + Vector2(2.0, 2.0)

func feedback_reel() -> int:
	return _feedback_reel

## Frees the two destination cues outright. The drag can be cancelled without the
## targeting layer going with it — the slot frames stay up for the next grab — so
## these cannot wait to die with their parent.
func free_destination_cues() -> void:
	if _invalid_overlay != null and is_instance_valid(_invalid_overlay):
		_invalid_overlay.queue_free()
	_invalid_overlay = null
	if _valid_overlay != null and is_instance_valid(_valid_overlay):
		_valid_overlay.queue_free()
	_valid_overlay = null
	_feedback_reel = -1

## The frames and cues are children of the targeting layer and die with it, so this
## drops the references rather than freeing anything.
func forget() -> void:
	stop_pulse()
	_slot_hints.clear()
	_invalid_overlay = null
	_valid_overlay = null
	_feedback_reel = -1

## --- what the smoke checks read ------------------------------------------------

func invalid_overlay() -> Panel:
	return _invalid_overlay

func valid_overlay() -> Panel:
	return _valid_overlay
