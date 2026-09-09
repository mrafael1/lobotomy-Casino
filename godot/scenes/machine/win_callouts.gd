class_name WinCallouts
extends RefCounted

## The TV's win callouts, the wealth-bar COMBO bonus pop, and the combo-loss
## warning art.
##
## Second seam cut out of machine_scene.gd, and like the first it was drawn by
## measuring rather than by the shape of the plan. The plan called this seam
## "flatline / combo / win presentation, ~34 fns / ~900 lines". Measured, that
## name covers three clusters that share not one field between them — the
## callouts here (16 functions, 249 lines), the flatline screen and its countdown
## (12 functions, 177 lines), and the score bursts and jackpot lamp (16 functions,
## 327 lines). They are three seams, and this is the first of them.
##
## What this owns is the presentation only. Whether a defeat is pending, which
## multiplier is at risk and what a win paid all live in RunStateStore; the
## machine still owns the *flow* around the warning — the sequence lock, the
## targeting reset and the pending-defeat overlay — because those reach the spin
## sequence rather than the TV, and hanging them on MachineView would have put
## four flow methods on a contract that exists to stay countable.
##
## Three beats, one cadence: a win callout, a power callout and the loss warning
## all pulse on CalloutCadence. That cadence sat on THIS class from seam 4.2,
## because the win callout was cut first and one of the two had to hold it;
## 4.6a moved it to a home neither of them owns (#197).

## --- the PAIR/TRIPLE callout ---------------------------------------------------
const WIN_ANIM_SHEET := "machine new view/win_animation.png"
const WIN_ANIM_FRAMES := 2
const WIN_ANIM_FRAME := { "pair": 0, "triple": 1 }

## "+ X" payout line under the PAIR/TRIPLE callout (both words centre on x~76 and
## end at y86 in the re-authored art; the TV screen bottom is y108). Child of the
## callout sprite, so it inherits the beep pulse and hides with it.
const WIN_PAYOUT_RECT := Rect2(41.0, 86.0, 70.0, 14.0)
const WIN_PAYOUT_COLOR := Color("#20d6c7")

## --- the COMBO component -------------------------------------------------------
const COMBO_EFFECT_SHEET := "machine_polished/combo.svg"
const COMBO_EFFECT_FRAMES := 9 # gameplay cap; the authored sheet may expose fewer frames
const COMBO_EFFECT_DELAY := 2.55
const COMBO_EFFECT_TIME := 1.05
const COMBO_EFFECT_Z_INDEX := 9
## Native pixel lettering occupies the CRT's score column. Its backing temporarily
## covers the score/multiplier; the portrait and approach row remain readable.
const COMBO_EFFECT_POSITION := Vector2.ZERO

## The bonus line briefly sits over the odometer's digit windows. It is a transient
## payout pop, so the wealth total is readable again as soon as the line fades.
const COMBO_PAYOUT_RECT := Rect2(73.0, 78.0, 48.0, 10.0)
const COMBO_PAYOUT_COLOR := Color("#20d6c7")

## --- the combo-loss warning ----------------------------------------------------
const COMBO_LOSS_2_SHEET := "machine_polished/loss_2.svg"
const COMBO_LOSS_3_SHEET := "machine_polished/loss_3.svg"
## The x3 losing state is an independent 9-frame CRT warning sheet (1440x320)
## stepped at the same cadence as the regular multiplier effects.
const COMBO_LOSS_3_FRAMES := 9
## Presentation stack: machine art → loss overlays (97) → dealer offer (100).
const COMBO_LOSS_OVERLAY_Z_INDEX := 97

## The 160x320 virtual canvas the authored sheets are drawn against.
const SRC_W := 160.0


var _view: MachineView = null

## Every field below is owned here and read nowhere else — the machine reaches
## them through the methods further down, which is the measurement this cut was
## made on.
var _win_anim_sprite: Sprite2D = null
var _win_anim_tween: Tween = null
var _win_payout_label: Label = null # "+ X" line under the PAIR/TRIPLE callout
var _combo_effect_sprite: Sprite2D = null
var _combo_effect_delay_tween: Tween = null
var _combo_effect_tween: Tween = null
var _combo_payout_tween: Tween = null
var _combo_payout_label: Label = null
var _combo_effect_frame_count := COMBO_EFFECT_FRAMES
var _combo_pop_active := false
var _combo_score_pending := -1 # final score held until the COMBO bonus beat lands
var _combo_loss_2_sprite: Sprite2D = null
var _combo_loss_3_sprite: Sprite2D = null
var _combo_loss_beep_tween: Tween = null

func _init(view: MachineView) -> void:
	_view = view

## --- construction --------------------------------------------------------------

## Built from inside the machine's control-art pass, at the point the sprites were
## always created. The position in that pass is load-bearing: these four sheets
## share the machine's z_index 0 by default, so the scene tree order IS the layer
## stack for the win callout, and only the combo and loss sprites override it.
func build() -> void:
	_combo_loss_2_sprite = _view.full_canvas_sheet(COMBO_LOSS_2_SHEET, 1)
	_combo_loss_3_sprite = _view.full_canvas_sheet(COMBO_LOSS_3_SHEET, COMBO_LOSS_3_FRAMES)
	for loss in [_combo_loss_2_sprite, _combo_loss_3_sprite]:
		if loss != null:
			loss.position = Vector2(-9, 30)
	_win_anim_sprite = _view.full_canvas_sheet(WIN_ANIM_SHEET, WIN_ANIM_FRAMES)
	if _win_anim_sprite != null:
		_win_payout_label = _payout_label("WinPayout", WIN_PAYOUT_RECT, 11, WIN_PAYOUT_COLOR)
		_win_anim_sprite.add_child(_win_payout_label)
	# The gameplay cap is nine stages, but the authored sheet is allowed to ship
	# fewer; the frame count comes from the art so a shorter sheet clamps rather
	# than showing a blank frame.
	var combo_texture := _view.texture(COMBO_EFFECT_SHEET, true)
	if combo_texture != null:
		_combo_effect_frame_count = clampi(
			roundi(float(combo_texture.get_width()) / SRC_W), 1, COMBO_EFFECT_FRAMES)
	_combo_effect_sprite = _view.full_canvas_sheet(COMBO_EFFECT_SHEET, _combo_effect_frame_count)
	if _combo_effect_sprite != null:
		_combo_effect_sprite.position = COMBO_EFFECT_POSITION
		_combo_effect_sprite.z_index = COMBO_EFFECT_Z_INDEX
		_combo_payout_label = _payout_label("ComboPayout", COMBO_PAYOUT_RECT, 6, COMBO_PAYOUT_COLOR)
		_combo_payout_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_combo_payout_label.add_theme_constant_override("outline_size", 1)
		_combo_payout_label.visible = false
		_combo_effect_sprite.add_child(_combo_payout_label)
	for sprite in [_combo_loss_2_sprite, _combo_loss_3_sprite, _win_anim_sprite,
			_combo_effect_sprite]:
		if sprite != null:
			(sprite as Sprite2D).visible = false
	for loss_sprite in [_combo_loss_2_sprite, _combo_loss_3_sprite]:
		if loss_sprite != null:
			(loss_sprite as Sprite2D).z_index = COMBO_LOSS_OVERLAY_Z_INDEX

func _payout_label(node_name: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	var font := _view.font()
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", color)
	label.text = ""
	return label

## --- the PAIR/TRIPLE callout ---------------------------------------------------

## The matching win_animation frame beeps (alpha pulse, loss-warning cadence)
## CalloutCadence.BEEP_COUNT times after the win is identified, then hides. The "+ score" payout
## line rides along as a child of the callout sprite.
func play_win(win_type: String, score: int, payout_text := "") -> void:
	if _win_anim_sprite == null or not WIN_ANIM_FRAME.has(win_type):
		return
	stop_win()
	_view.begin_tv_info_pop(&"win")
	_view.set_sheet_frame(_win_anim_sprite, int(WIN_ANIM_FRAME[win_type]))
	if _win_payout_label != null:
		_win_payout_label.text = payout_text if payout_text != "" else "+ %d" % score
	_win_anim_sprite.modulate.a = 1.0
	_win_anim_sprite.visible = true
	_win_anim_tween = _view.tween().set_loops(CalloutCadence.BEEP_COUNT)
	_win_anim_tween.tween_property(_win_anim_sprite, "modulate:a", 0.18,
		CalloutCadence.BEEP_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_win_anim_tween.tween_property(_win_anim_sprite, "modulate:a", 1.0,
		CalloutCadence.BEEP_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_win_anim_tween.tween_interval(CalloutCadence.BEEP_PAUSE)
	_win_anim_tween.finished.connect(stop_win)

func stop_win() -> void:
	if _win_anim_tween != null and _win_anim_tween.is_valid():
		_win_anim_tween.kill()
	_win_anim_tween = null
	if _win_anim_sprite != null:
		_win_anim_sprite.visible = false
		_win_anim_sprite.modulate.a = 1.0
	_view.end_tv_info_pop(&"win")

func win_sprite() -> Sprite2D:
	return _win_anim_sprite

## --- the COMBO component -------------------------------------------------------

## A paying PAIR/TRIPLE result gives COMBO a second beat: the authored stage pops
## on the Wealth bar and its separate bonus flies out after the base payout callout.
## The pop is transient and disappears when the bonus has landed.
## Returns how long that beat occupies the machine.
func queue_combo(combo_number: int, bonus: int, percent: int) -> float:
	if _combo_effect_sprite == null:
		return 0.0
	stop_combo()
	var frame := clampi(combo_number - 1, 0, maxi(0, _combo_effect_frame_count - 1))
	_combo_effect_delay_tween = _view.tween()
	_combo_effect_delay_tween.tween_interval(COMBO_EFFECT_DELAY)
	_combo_effect_delay_tween.tween_callback(show_combo.bind(frame, bonus, percent))
	return COMBO_EFFECT_DELAY + COMBO_EFFECT_TIME

func show_combo(frame: int, bonus: int, percent: int) -> void:
	_combo_effect_delay_tween = null
	if _combo_effect_sprite == null or not RunStateStore.winBoostEnabled:
		return
	stop_win()
	_combo_pop_active = true
	_view.set_sheet_frame(_combo_effect_sprite,
		clampi(frame, 0, maxi(0, _combo_effect_frame_count - 1)))
	if _combo_payout_label != null:
		_combo_payout_label.text = "+ %d (%d%%)" % [maxi(0, bonus), clampi(percent, 0, 45)]
		_combo_payout_label.position = COMBO_PAYOUT_RECT.position
		_combo_payout_label.modulate.a = 1.0
		_combo_payout_label.visible = true
	_combo_effect_sprite.modulate.a = 1.0
	_combo_effect_sprite.visible = true
	flush_held_score()
	if _combo_effect_tween != null and _combo_effect_tween.is_valid():
		_combo_effect_tween.kill()
	_combo_effect_tween = _view.tween()
	var origin := _combo_effect_sprite.position
	for offset in [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(-1.0, 0.0),
			Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(1.0, 0.0)]:
		_combo_effect_tween.tween_property(_combo_effect_sprite, "position",
			origin + offset, 0.06)
	_combo_effect_tween.tween_property(_combo_effect_sprite, "position", origin, 0.06)
	_combo_effect_tween.tween_interval(maxf(0.0, COMBO_EFFECT_TIME - 0.42))
	_combo_effect_tween.finished.connect(_finish_combo)
	if _combo_payout_tween != null and _combo_payout_tween.is_valid():
		_combo_payout_tween.kill()
	if _combo_payout_label != null:
		_combo_payout_tween = _view.tween()
		_combo_payout_tween.tween_property(_combo_payout_label, "position:y",
			COMBO_PAYOUT_RECT.position.y - 3.0, 0.72)
		_combo_payout_tween.parallel().tween_property(_combo_payout_label, "modulate:a",
			0.0, 0.72).set_delay(0.18)

func _finish_combo() -> void:
	_combo_effect_tween = null
	_combo_pop_active = false
	if _combo_effect_sprite != null:
		_combo_effect_sprite.position = COMBO_EFFECT_POSITION
		_combo_effect_sprite.modulate.a = 1.0
		_combo_effect_sprite.visible = false
	_reset_combo_payout_label()
	flush_held_score()

func stop_combo() -> void:
	for tween in [_combo_effect_delay_tween, _combo_effect_tween, _combo_payout_tween]:
		if tween != null and (tween as Tween).is_valid():
			(tween as Tween).kill()
	_combo_effect_delay_tween = null
	_combo_effect_tween = null
	_combo_payout_tween = null
	_combo_pop_active = false
	if _combo_effect_sprite != null:
		_combo_effect_sprite.position = COMBO_EFFECT_POSITION
		_combo_effect_sprite.modulate.a = 1.0
		_combo_effect_sprite.visible = false
	_reset_combo_payout_label()
	flush_held_score()

func _reset_combo_payout_label() -> void:
	if _combo_payout_label == null:
		return
	_combo_payout_label.position = COMBO_PAYOUT_RECT.position
	_combo_payout_label.modulate.a = 1.0
	_combo_payout_label.visible = false
	_combo_payout_label.text = ""

func combo_frame(stage: int) -> int:
	var zero_based := maxi(0, stage - 1) if stage > 0 else 0
	return clampi(zero_based, 0, maxi(0, _combo_effect_frame_count - 1))

## COMBO is hidden between bonus payouts. This refresh hook only clears a stale pop
## when the HUD is rebuilt; an active pop owns its own short animation.
func refresh_combo() -> void:
	if _combo_effect_sprite == null:
		return
	if not RunStateStore.winBoostEnabled:
		stop_combo()
		return
	if _combo_pop_active:
		return
	_combo_effect_sprite.visible = false

## Explicitly hides an in-flight Wealth-bar pop without changing the combo state.
func hide_combo() -> void:
	if _combo_effect_sprite != null:
		_combo_effect_sprite.visible = false

func combo_sprite() -> Sprite2D:
	return _combo_effect_sprite

func combo_payout_label() -> Label:
	return _combo_payout_label

## --- the held final score ------------------------------------------------------
##
## A combo bonus arrives on its own beat two and a half seconds after the base
## payout, so the odometer must NOT jump to the final score with the base one. The
## final figure is parked here and released when the bonus beat lands — or by
## whatever interrupts it first, since a power or a scene change can cut the beat
## off and the odometer still owes the player the number.

func hold_score(score: int) -> void:
	_combo_score_pending = score

func pending_score() -> int:
	return _combo_score_pending

func flush_held_score() -> void:
	if _combo_score_pending < 0:
		return
	_view.raise_display_lucidity(_combo_score_pending)
	_combo_score_pending = -1

## --- the combo-loss warning ----------------------------------------------------

func set_loss_display(multiplier: int) -> void:
	if _combo_loss_2_sprite != null:
		_combo_loss_2_sprite.visible = multiplier == 2
	if _combo_loss_3_sprite != null:
		_combo_loss_3_sprite.visible = multiplier == 3
		if multiplier == 3:
			_combo_loss_3_sprite.frame = 0
	# The loss overlay replaces the regular gauge effects; closing it (0) brings
	# the sparks / glitch + fire straight back for the surviving multiplier.
	_view.apply_multiplier_fx_visibility()

func start_loss_beep() -> void:
	stop_loss_beep()
	# The authored x2 loss marker keeps its existing pulse; x3 remains a steady
	# diminished CRT warning. COMBO has already disappeared after its payout pop.
	var loss_sprite: Sprite2D = _combo_loss_2_sprite \
		if int(RunStateStore.pendingComboMultiplier) == 2 else null
	if loss_sprite == null:
		return
	if loss_sprite != null:
		loss_sprite.modulate = Color.WHITE
	_combo_loss_beep_tween = _view.tween().set_loops()
	_combo_loss_beep_tween.set_parallel(true)
	if loss_sprite != null:
		_combo_loss_beep_tween.tween_property(loss_sprite, "modulate:a", 0.18,
			CalloutCadence.BEEP_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_combo_loss_beep_tween.set_parallel(false)
	_combo_loss_beep_tween.set_parallel(true)
	if loss_sprite != null:
		_combo_loss_beep_tween.tween_property(loss_sprite, "modulate:a", 1.0,
			CalloutCadence.BEEP_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_combo_loss_beep_tween.set_parallel(false)
	_combo_loss_beep_tween.tween_interval(CalloutCadence.BEEP_PAUSE)

func stop_loss_beep() -> void:
	if _combo_loss_beep_tween != null and _combo_loss_beep_tween.is_valid():
		_combo_loss_beep_tween.kill()
		_combo_loss_beep_tween = null
	for sprite in [_combo_loss_2_sprite, _combo_loss_3_sprite]:
		if sprite != null:
			(sprite as Sprite2D).modulate = Color.WHITE

func loss_beeping() -> bool:
	return _combo_loss_beep_tween != null

func loss_sprite(multiplier: int) -> Sprite2D:
	return _combo_loss_2_sprite if multiplier == 2 else _combo_loss_3_sprite

## True while either loss sheet is up. The frenzy-gauge effects step aside for it
## rather than drawing through it.
func loss_showing() -> bool:
	return (_combo_loss_2_sprite != null and _combo_loss_2_sprite.visible) \
		or (_combo_loss_3_sprite != null and _combo_loss_3_sprite.visible)

## The x3 sheet is an animation, and it runs on the multiplier-effect cadence
## rather than one of its own — so the machine's frenzy stepper drives it, and
## this reports whether there is anything to drive.
func loss_3_showing() -> bool:
	return _combo_loss_3_sprite != null and _combo_loss_3_sprite.visible

func step_loss_3_frame() -> void:
	if _combo_loss_3_sprite == null:
		return
	_combo_loss_3_sprite.frame = (_combo_loss_3_sprite.frame + 1) % COMBO_LOSS_3_FRAMES
