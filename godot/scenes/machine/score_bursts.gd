class_name ScoreBursts
extends RefCounted

## The score popups that rise out of the reels, and the cabinet's jackpot lamp.
##
## Seam 4.2c, the last of the three clusters the plan filed under "flatline /
## combo / win presentation" — and the largest of them at 9 functions and 6
## fields, though smaller than the 16/327 the first measurement suggested,
## because two things that measured into this cluster do not belong to it:
##
##   _emit_score_burst (107 lines) reads the result, decides which burst the win
##   has earned and how long the machine owes it, and drives the odometer. That
##   is the reward sequence, not the popup — it stays and calls in here.
##
##   The jackpot coin fountain shared the coin layer and the coin factory with the
##   power-coin flight. Taking it would have meant putting the coin layer, the
##   coin factory and the cash-tray position on MachineView to serve one caller,
##   with the other caller still on the machine. It now lives in CoinFlights,
##   which was cut afterwards precisely because this seam refused it.
##
## So this is presentation with nothing behind it: hand it a label, an amount, a
## colour and a reel, and it spawns, rises, fades and frees. Nothing here reads
## RunStateStore.

## Reel geometry, handed over at construction rather than reached for. It is the
## machine's, it never changes after _ready, and copying it into a const here
## would have been the second copy of the machine's own layout.
var _reel_cell_centers: Array = []
var _reel_window_top := 0.0
var _canvas_width := 0.0

## --- the bursts ----------------------------------------------------------------
const BURST_TIME := 1.05
const BURST_RISE := 28.0
## The jackpot burst is ALWAYS golden and always centred on the cabinet rather
## than a reel (issue #22).
const JACKPOT_GOLD := Color(1.0, 0.84, 0.18)

## --- the lamp ------------------------------------------------------------------
const JACKPOT_SHEET := "machine_polished/jackpot_beacon.svg"
const JACKPOT_FRAME_COUNT := 3
const JACKPOT_FRAME_OFF := 0
const JACKPOT_FRAME_LIT := 1
const JACKPOT_FRAME_ALT := 2
const JACKPOT_FLASH_TIME := 0.9

var _view: MachineView = null

var _burst_layer: Control = null
var _burst_prev_score := 0 # last announced result score (for power gain)
var _burst_prev_spin := -1 # spin the last announcement belonged to
var _jackpot_sprite: Sprite2D = null
var _jackpot_flash_tween: Tween = null
var _jackpot_flashing := false

func _init(view: MachineView, reel_cell_centers: Array, reel_window_top: float,
		canvas_width: float) -> void:
	_view = view
	_reel_cell_centers = reel_cell_centers
	_reel_window_top = reel_window_top
	_canvas_width = canvas_width

## --- construction --------------------------------------------------------------

## `z_index` comes from the caller because the layer stack is the machine's: this
## layer and the coin layer deliberately share one depth, and that is a fact
## about the machine rather than about bursts.
func build_layer(z_index: int) -> void:
	_burst_layer = _view.authored_control("BurstLayer")
	if _burst_layer == null:
		_burst_layer = Control.new()
		_burst_layer.name = "BurstLayer"
		_view.add_layer(_burst_layer)
	_burst_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_burst_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst_layer.z_index = z_index

## Built from the machine's control-art pass, at the line the lamp has always
## been created on — it sits in the cabinet's tree order, beside the lever.
func build_jackpot_lamp() -> void:
	_jackpot_sprite = _view.full_canvas_sheet(JACKPOT_SHEET, JACKPOT_FRAME_COUNT)
	_view.set_sheet_frame(_jackpot_sprite, JACKPOT_FRAME_OFF)

func burst_layer() -> Control:
	return _burst_layer

## --- the score popups ----------------------------------------------------------

func _burst_text(text: String, size: int, color: Color, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.size = Vector2(width, float(size) + 2.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	var font := _view.font()
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l

func spawn(label: String, amount: int, color: Color, reel: int) -> void:
	if _burst_layer == null:
		return
	var cx: float = _reel_cell_centers[reel]
	var box_w := 64.0 if label != "" else 28.0
	var top := _reel_window_top - 10.0
	var burst := Control.new()
	burst.position = Vector2(cx - box_w * 0.5, top)
	burst.size = Vector2(box_w, 16.0)
	burst.pivot_offset = Vector2(box_w * 0.5, 8.0)
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst_layer.add_child(burst)
	var y := 0.0
	if label != "":
		var lab := _burst_text(label, 8, color, box_w)
		lab.position = Vector2(0, y)
		burst.add_child(lab)
		y += 8.0
	var amt := _burst_text("+%d" % amount, 7, color, box_w)
	amt.position = Vector2(0, y)
	burst.add_child(amt)
	var tw := _view.tween()
	tw.tween_method(_drive_burst.bind(burst, top), 0.0, 1.0, BURST_TIME)
	tw.tween_callback(burst.queue_free)

## Jackpot burst (issue #22): a large, always-golden number centred on the machine
## (not anchored to a reel) that rises out of the cabinet. Display only.
func spawn_jackpot(amount: int) -> void:
	if _burst_layer == null:
		return
	var cx := _canvas_width * 0.5
	var box_w := 140.0
	var top := _reel_window_top - 18.0
	var burst := Control.new()
	burst.position = Vector2(cx - box_w * 0.5, top)
	burst.size = Vector2(box_w, 30.0)
	burst.pivot_offset = Vector2(box_w * 0.5, 15.0)
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst_layer.add_child(burst)
	var lab := _burst_text("JACKPOT", 13, JACKPOT_GOLD, box_w)
	lab.position = Vector2(0.0, 0.0)
	burst.add_child(lab)
	var amt := _burst_text("+%d" % amount, 20, JACKPOT_GOLD, box_w)
	amt.position = Vector2(0.0, 12.0)
	burst.add_child(amt)
	var tw := _view.tween()
	tw.tween_method(_drive_burst.bind(burst, top), 0.0, 1.0, BURST_TIME * 1.25)
	tw.tween_callback(burst.queue_free)

func _drive_burst(t: float, burst: Control, base_y: float) -> void:
	if not is_instance_valid(burst):
		return
	burst.position.y = base_y - BURST_RISE * t
	var s: float
	if t < 0.18:
		s = lerpf(0.5, 1.1, t / 0.18)
	else:
		s = lerpf(1.1, 1.0, (t - 0.18) / 0.82)
	burst.scale = Vector2(s, s)
	var o: float
	if t < 0.12:
		o = t / 0.12
	elif t < 0.7:
		o = 1.0
	else:
		o = 1.0 - (t - 0.7) / 0.3
	burst.modulate.a = clampf(o, 0.0, 1.0)

## A teardown mid-payout leaves live popups on the layer. Hidden rather than
## freed, matching how the machine sweeps its other transient layers — the
## tweens that own them still hold valid nodes and will free them on schedule.
func hide_pending() -> void:
	if _burst_layer == null:
		return
	for child: Node in _burst_layer.get_children():
		var item := child as CanvasItem
		if item != null:
			item.visible = false
			item.modulate.a = 0.0

## --- what the last announcement was --------------------------------------------
##
## Which spin the previous burst belonged to and what it announced, so a rescore
## on the same spin pops only the difference. The reward sequence owns the
## comparison; this only remembers.

func remember(spin: int, score: int) -> void:
	_burst_prev_spin = spin
	_burst_prev_score = score

func prev_spin() -> int:
	return _burst_prev_spin

func prev_score() -> int:
	return _burst_prev_score

## --- the jackpot lamp ----------------------------------------------------------

## `held` is the machine's HUD delta hold: while it is up the lamp waits with the
## other aftereffects, so it pops with the score rather than ahead of it.
func refresh_jackpot_lamp(lit: bool, held: bool) -> void:
	if _jackpot_sprite == null or _jackpot_flashing:
		return # don't fight an active flash
	if held:
		return
	_view.set_sheet_frame(_jackpot_sprite, JACKPOT_FRAME_LIT if lit else JACKPOT_FRAME_OFF)

## `on_finished` is the machine's lamp refresh. Whether the lamp settles lit or
## dark afterwards depends on the last result and the HUD hold, neither of which
## this component reads — so the answer is asked for rather than derived, and
## MachineView does not grow an entry to serve one callback.
func flash_jackpot_lamp(on_finished: Callable) -> void:
	if _jackpot_sprite == null:
		return
	if _jackpot_flash_tween != null and _jackpot_flash_tween.is_valid():
		_jackpot_flash_tween.kill()
	_jackpot_flashing = true
	_jackpot_flash_tween = _view.tween()
	_jackpot_flash_tween.tween_method(_drive_jackpot_flash, 0.0, 1.0, JACKPOT_FLASH_TIME)
	_jackpot_flash_tween.tween_callback(_end_jackpot_flash.bind(on_finished))

func _end_jackpot_flash(on_finished: Callable) -> void:
	_jackpot_flashing = false
	on_finished.call()

func _drive_jackpot_flash(t: float) -> void:
	if _jackpot_sprite == null:
		return
	_view.set_sheet_frame(_jackpot_sprite,
		JACKPOT_FRAME_LIT if (int(t * 12.0) % 2 == 0) else JACKPOT_FRAME_ALT)

## Kills a running flash and puts the lamp out. Used by the presentation
## teardown, which must not leave the cabinet lit into the next run.
func reset_jackpot_lamp() -> void:
	if _jackpot_flash_tween != null and _jackpot_flash_tween.is_valid():
		_jackpot_flash_tween.kill()
	_jackpot_flash_tween = null
	_jackpot_flashing = false
	_view.set_sheet_frame(_jackpot_sprite, JACKPOT_FRAME_OFF)
