class_name WealthReadout
extends RefCounted

## What the machine is currently claiming the player is worth: the wealth
## odometer's digits, and the TV's objective plate with its fill bar, shimmer and
## goal number (issue #181).
##
## Seam 4.3b. The plan had these as two entries — "wealth" and "target bar" — and
## measuring says they are one thing. _set_display_lucidity writes the odometer
## and then refreshes the target bar; _refresh_target_readout reads back the
## odometer's shown value to decide how full the bar is. Neither half can be cut
## without the other following it across the seam, so they are cut together.
##
## Three seams pointed at this odometer before it had a home: 4.2 reached it
## through MachineView.raise_display_lucidity, 4.2c left _emit_score_burst
## driving it, and 4.3a passed over it. It lives here now.
##
## The distinction that keeps this component honest: it owns what the readout
## SHOWS, never what the run IS worth. RunStateStore.scoreEarned is the truth;
## the number on the glass lags it deliberately, because a payout has to be
## announced before it is displayed.

## Legacy goal and progress frames are registered into the CRT's right column.
## The title remains runtime text; all values and frame timing remain independent.
const BAR_SHEET := "machine_polished/target_progress.svg"
const BAR_FRAME_COUNT := 12
const BAR_ANIM_SHEET := "machine_polished/target_shimmer.svg"
const BAR_ANIM_FRAME_COUNT := 6
const BAR_ANIM_FRAME_TIME := 0.12
const TV_Z_INDEX := 8 # above the cabinet and callout sheets, below the icons
const ODOMETER_OFFSET := Vector2(29.0, -194.0)

var _view: MachineView = null

var _odometer: WealthOdometer = null
## The score the glass is showing. Legacy name in the store's terms was
## "display lucidity"; it has been the cumulative score since #181.
var _display_score := 0
var _bar_sprite: Sprite2D = null
var _goals_sprite: Label = null
var _bar_anim_sprite: Sprite2D = null
var _bar_anim_time := 0.0
var _target_title: Label = null

func _init(view: MachineView) -> void:
	_view = view

func build() -> void:
	_odometer = WealthOdometer.new()
	_odometer.name = "WealthOdometer"
	_view.add_layer(_odometer)
	_odometer.position = ODOMETER_OFFSET
	_odometer.z_index = TV_Z_INDEX
	_target_title = Label.new()
	_target_title.name = "CrtTargetTitle"
	_target_title.position = Vector2(74, 49)
	_target_title.text = "TARGET:"
	_target_title.add_theme_font_override("font", _view.font())
	_target_title.add_theme_font_size_override("font_size", 6)
	_target_title.add_theme_color_override("font_color", Color("b7c7a5"))
	_target_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_title.z_index = TV_Z_INDEX
	_view.add_layer(_target_title)
	_bar_sprite = _view.full_canvas_sheet(BAR_SHEET, BAR_FRAME_COUNT)
	if _bar_sprite != null:
		_bar_sprite.z_index = TV_Z_INDEX

	_goals_sprite = Label.new()
	_goals_sprite.name = "CrtTargetNumber"
	_goals_sprite.position = Vector2(103, 49)
	_goals_sprite.size = Vector2(17, 8)
	_goals_sprite.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_goals_sprite.add_theme_font_override("font", _view.font())
	_goals_sprite.add_theme_font_size_override("font_size", 6)
	_goals_sprite.add_theme_color_override("font_color", Color("b7c7a5"))
	_goals_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goals_sprite.z_index = TV_Z_INDEX
	_view.add_layer(_goals_sprite)
	# The shimmer plays underneath the bar, so the authored fill always reads on top
	# of it rather than being animated over.
	_bar_anim_sprite = _view.full_canvas_sheet(BAR_ANIM_SHEET, BAR_ANIM_FRAME_COUNT)
	if _bar_anim_sprite != null:
		_bar_anim_sprite.z_index = TV_Z_INDEX - 1


## --- the odometer ----------------------------------------------------------------

## `duration_override` lets a payout pace its own roll (the jackpot); 0.0 keeps
## the delta-derived default.
##
## Does NOT refresh the target bar, even though the bar reads this value: the
## caller does, because it is the caller that knows whether the machine is still
## holding its deltas back. Doing it here would have needed a way back to the
## machine for an answer this component cannot give.
func set_score(value: int, animated := true, duration_override := 0.0) -> void:
	_display_score = maxi(0, value)
	if _odometer != null:
		_odometer.set_value(_display_score, animated, duration_override)

func display_score() -> int:
	return _display_score

func odometer() -> WealthOdometer:
	return _odometer

func stop_roll() -> void:
	if _odometer != null:
		_odometer.stop_roll()

func set_digits_hidden(hidden: bool) -> void:
	if _odometer != null:
		_odometer.set_digits_hidden(hidden)

## --- the objective plate -----------------------------------------------------------

## The goal frames are authored one per WEALTH_TARGETS entry, so the frame index IS
## the target index. The bar fills with progress toward the CURRENT target and
## therefore empties again each time one is paid — complete_wealth_target()
## subtracts the target from the score and advances the index together.
##
## `shown_score` is handed in rather than read, and it is the whole reason this
## split works: the bar has to track the score the odometer is SHOWING, not the
## score the state already holds, and only the machine knows whether a reward is
## still being held back. A bar that filled from the store announced the payout
## before the number did.
##
## `callout_active` blanks the whole readout — a win callout or a power animation
## owns the TV outright. `content_muted` is weaker: the lit FREE SPIN banner takes
## only the goal number and title at y47..54, and leaves the
## fill bar and its shimmer running underneath (issue #185 follow-up). Progress
## toward the target is exactly what free spins are being spent on, so blanking it
## during them hid the one readout the player was watching.
func refresh_target(shown_score: int, callout_active: bool, content_muted: bool) -> void:
	if _odometer != null:
		_odometer.visible = not callout_active
	if _target_title != null:
		_target_title.visible = not content_muted
	if _goals_sprite == null and _bar_sprite == null:
		return
	var should_show := not callout_active
	if _bar_sprite != null:
		_bar_sprite.visible = should_show
	if _bar_anim_sprite != null:
		_bar_anim_sprite.visible = should_show
	if _goals_sprite != null:
		_goals_sprite.visible = not content_muted
	if not should_show:
		return
	_goals_sprite.text = str(RunStateStore.current_wealth_target())
	var target := maxi(1, RunStateStore.current_wealth_target())
	var progress := clampf(float(shown_score) / float(target), 0.0, 1.0)
	_view.set_sheet_frame(_bar_sprite, clampi(
		floori(progress * float(BAR_FRAME_COUNT - 1)), 0, BAR_FRAME_COUNT - 1))

## Two-frame loop over the fill bar. Driven from _process rather than a tween so it
## survives the tween sweeps that clear the run's transient effects.
func step_bar_animation(delta: float) -> void:
	if _bar_anim_sprite == null or not _bar_anim_sprite.visible:
		return
	_bar_anim_time += delta
	if _bar_anim_time < BAR_ANIM_FRAME_TIME:
		return
	_bar_anim_time = fmod(_bar_anim_time, BAR_ANIM_FRAME_TIME)
	_view.set_sheet_frame(_bar_anim_sprite,
		(_bar_anim_sprite.frame + 1) % BAR_ANIM_FRAME_COUNT)

## --- what the smoke checks read ----------------------------------------------------

func bar_sprite() -> Sprite2D:
	return _bar_sprite

func goals_sprite() -> Label:
	return _goals_sprite

func bar_anim_sprite() -> Sprite2D:
	return _bar_anim_sprite
