class_name FlatlineScreen
extends RefCounted

## The flatline ending screen and the credit drain that runs on it.
##
## Seam 4.2b, the second of the three clusters the plan filed under one name. It
## is the smallest of them — 6 functions, ~90 lines, 8 fields — and the size is
## the finding, not an apology for it: what the plan called "flatline
## presentation" is mostly not presentation. The fatal-strike check, the delayed
## hand-off to _show_ending and the CONTINUE button's routing to the dealer, the
## Pacte or the menu are run flow, and they stay in the machine. What is left
## once those are set aside is this: build the screen, drain the number on it,
## and put the neuron meter somewhere.
##
## Worth its own cut anyway, because of the eighth field. The drain is one of the
## eight hand-rolled steppers _process calls every frame, and phase 5 replaces
## that pattern with a registry — a stepper whose whole state is already boxed
## behind counting_down() and step() is one that can register itself. The other
## seven still cannot.

## The number holds for a beat before it starts falling, so the player reads what
## they had before watching it go.
const HOLD_TIME := 0.7
const DRAIN_TIME := 1.6

const ENDING_SCENE := preload("res://scenes/flatline_ending_overlay.tscn")

var _view: MachineView = null

var _countdown_active := false
var _countdown_elapsed := 0.0
var _total := 0
var _kept := 0
var _display := 0
var _score_label: Label = null
var _lost_label: Label = null
var _meter: NeuronMeter = null

func _init(view: MachineView) -> void:
	_view = view

## The dedicated ending scene, parented into whatever overlay the machine has
## already claimed for the ending. `on_action` is the machine's — where CONTINUE
## goes next is a run-flow decision (dealer, threshold Pacte, or menu) and stays
## on that side of the seam.
func build_screen(run: Dictionary, action_text: String, fatal_copy: String,
		on_action: Callable) -> FlatlineEndingOverlay:
	var overlay := _view.ending_overlay()
	if overlay == null:
		return null
	var screen := ENDING_SCENE.instantiate() as FlatlineEndingOverlay
	overlay.add_child(screen)
	screen.present(action_text, fatal_copy)
	screen.action_pressed.connect(on_action)
	build_countdown(run, screen)
	return screen

## `screen` null means the legacy fallback ending, which has no authored screen
## and gets its own labels and the neuron-loss treatment instead.
func build_countdown(run: Dictionary, screen: FlatlineEndingOverlay = null) -> void:
	var overlay := _view.ending_overlay()
	_total = int(run["lucidityCoins"])
	_kept = floori(float(_total) * _kept_fraction())
	_display = _total
	_countdown_elapsed = 0.0
	_countdown_active = _kept < _total

	# Retained-percent line only ("10% kept", or "50% kept" with Smart Saving);
	# the draining number below it is the whole story.
	var kept_pct := roundi(_kept_fraction() * 100.0)
	if screen != null:
		screen.set_kept_percentage(kept_pct)
		_score_label = screen.score_label
		_lost_label = screen.lost_label
	else:
		_view.score_label(overlay, "%d%% kept" % kept_pct, Vector2(20.0, 96.0), 8,
			Color(0.58, 0.64, 0.72), 120.0, HORIZONTAL_ALIGNMENT_CENTER)
		_score_label = _view.score_label(overlay, str(_display),
			Vector2(20.0, 110.0), 28, Color(0.97, 0.98, 1.0), 120.0,
			HORIZONTAL_ALIGNMENT_CENTER)
		_lost_label = _view.score_label(overlay, "", Vector2(20.0, 148.0), 10,
			Color(0.93, 0.27, 0.27), 120.0, HORIZONTAL_ALIGNMENT_CENTER)
	_update_labels()

	# Keep the neuron-loss treatment only for the legacy fallback. The dedicated
	# flatline screen intentionally stays focused on the money drain and trace.
	if screen == null and overlay != null:
		_meter = NeuronMeter.attach(overlay, Vector2(80.0, 198.0))
		_meter.play_loss_animation()
		_view.show_neuron_spend_feedback(overlay, Vector2(80.0, 190.0))

## Asks the store rather than reading ownedPermanents directly, so a
## Pacte-granted SMART SAVING counts here exactly as it does in the bank.
func _kept_fraction() -> float:
	return MetaStateStore.effective_lucidity_kept_fraction()

func counting_down() -> bool:
	return _countdown_active

func step(delta: float) -> void:
	_countdown_elapsed += delta
	if _countdown_elapsed < HOLD_TIME:
		return
	var drain_elapsed := _countdown_elapsed - HOLD_TIME
	var p := clampf(drain_elapsed / DRAIN_TIME, 0.0, 1.0)
	var eased := 1.0 - (1.0 - p) * (1.0 - p)
	_display = _kept if p >= 1.0 else int(round(float(_total) - float(_total - _kept) * eased))
	_update_labels()
	if p >= 1.0:
		_countdown_active = false

func _update_labels() -> void:
	if _score_label != null:
		_score_label.text = str(_display)
	if _lost_label != null:
		var lost := _total - _display
		_lost_label.text = tr("-%d lost") % lost if lost > 0 else ""

## The neuron meter, placed once. Two callers with different centres — the
## fallback ending puts it under its own labels, and the authored screen puts it
## where the revival beat lands — and whichever arrives first wins, which is why
## this refuses rather than moves an existing meter.
func attach_meter(center: Vector2, feedback_center: Vector2) -> void:
	var overlay := _view.ending_overlay()
	if overlay == null:
		return
	if _meter != null and is_instance_valid(_meter):
		return
	_meter = NeuronMeter.attach(overlay, center)
	_meter.play_loss_animation()
	_view.show_neuron_spend_feedback(overlay, feedback_center)

## Where the authored screen's own revival beat puts it.
func attach_revival_meter() -> void:
	attach_meter(FlatlineEndingOverlay.REVIVAL_METER_CENTER,
		FlatlineEndingOverlay.REVIVAL_METER_CENTER + Vector2(0.0, 27.0))

## The labels and the meter are children of the overlay and die with it, so this
## drops the references rather than freeing anything.
func stop() -> void:
	_countdown_active = false
	_countdown_elapsed = 0.0
	_total = 0
	_kept = 0
	_display = 0
	_score_label = null
	_lost_label = null
	_meter = null

## --- what the smoke checks read ------------------------------------------------

func score_label() -> Label:
	return _score_label

func lost_label() -> Label:
	return _lost_label

## Fast-forwards the drain to its end, which is the only reason a check ever
## touches the elapsed clock.
func seek_to_end() -> void:
	_countdown_elapsed = HOLD_TIME + DRAIN_TIME
