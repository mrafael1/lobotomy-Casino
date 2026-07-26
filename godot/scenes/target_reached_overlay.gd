@tool
class_name TargetReachedOverlay
extends Control

## Intermediate wealth-target payout screen (issues #176, #181).
##
## The beat is deliberately slow and reads top to bottom in one sentence: the machine
## TV goes dark, the beaten target grows huge inside it, the running score is lifted
## off the wealth reels at the bottom of the cabinet and parks just under the TV, the
## score drains by that amount — the money paid to the casino, falling out of the target
## into the reels as it goes — and only then does the spent target disintegrate. The screen reads title / target / score / what it cost.
##
## The number is a real WealthOdometer snapshot rather than a Label, so it is visibly
## the machine's own readout that moved, and the drain is an actual reel roll. The
## machine scene owns the blackout behind it and hides the live reels the moment this
## overlay says it has lifted them.

signal continue_pressed
## The snapshot has left the cabinet — the machine blanks its own digits now, so the
## number is never on screen twice.
signal digits_lifted
signal sequence_finished

const BLUE_NEON := Color(0.36, 0.74, 1.0)
const SOFT_WHITE := Color(0.96, 0.98, 1.0)
const LOSS_RED := Color(0.93, 0.27, 0.27)
const TARGET_NUMBER_COLOR := Color(0.96, 0.98, 1.0)
# The machine stays visible behind, but far enough back that the lifted score is not
# competing with the multiplier strip it parks over.
const DIM_ALPHA := 0.88

# The TV screen is 112x66 at (24, 42). The target owns it — it grows to fill most of it —
# and the lifted score parks well below, leaving the target room to breathe and the drain
# a visible distance to fall. The score's own block (score / deduction / subtitle / button)
# keeps its internal spacing: everything under the TV moves together, which is why the
# scene's y offsets and SCORE_CENTER were shifted by the same 35px (issue #181).
const TARGET_CENTER := Vector2(80.0, 73.0)
const TARGET_FONT_SIZE := 26
const TARGET_GROW_FROM := 0.35
const SCORE_CENTER := Vector2(80.0, 157.0)
const SCORE_SCALE := 1.6
const TITLE_START_Y := 12.0
const TITLE_REST_Y := 18.0

# Disintegration: each glyph of "-500" shatters into a handful of shards on a single
# ballistic driver, and the glyphs themselves fade right to left so the number crumbles
# as a wave rather than vanishing at once. The RNG is seeded so the beat is identical
# every run and a screenshot diff stays meaningful.
const SHARD_PER_GLYPH := 6
const SHARD_SIZE := 2.0
const SHARD_SPEED_MIN := 10.0
const SHARD_SPEED_MAX := 24.0
const SHARD_SPREAD_DEG := 62.0
const SHARD_GRAVITY := 46.0
const SHARD_GLYPH_FADE := 0.18
const SHARD_GLYPH_STAGGER := 0.07
const SHARD_RNG_SEED := 181_0725

# Draining: while the reels roll down, motes fall out of the bottom of the target and
# into the score, so the number going down is visibly being drained INTO by the target
# above it. Each mote is in flight for a fraction of the roll and they are launched in
# order, which makes the stream continuous for the whole drain. Seeded like the shards.
const DRAIN_MOTES := 26
const DRAIN_MOTE_SIZE := 2.0
const DRAIN_MOTE_SPREAD := 30.0 # how wide under the target they fall from
const DRAIN_MOTE_LANDING_SPREAD := 20.0 # ...and how wide across the score they land
const DRAIN_MOTE_FLIGHT := 0.34 # share of PHASE_DRAIN one mote spends falling
const DRAIN_MOTE_SWAY := 4.0
const DRAIN_RNG_SEED := 181_0726
# The first motes are already falling when the reels start to roll — the money leaves the
# target and the score reacts to it, rather than both starting on the same frame.
const DRAIN_LEAD := 0.20

# One phase per beat; the machine scene reuses PHASE_BLACKOUT so the TV fades out on
# exactly the same curve this overlay fades in on.
const PHASE_BLACKOUT := 0.50
const PHASE_TITLE_IN := 0.32
const PHASE_TITLE_HOLD := 0.26
const PHASE_LIFT := 0.90
const PHASE_LIFT_HOLD := 0.22
const PHASE_TARGET_IN := 0.32
const PHASE_TARGET_HOLD := 0.34
const PHASE_SHATTER := 0.55
const PHASE_DRAIN := 1.10
const PHASE_SETTLE := 0.24
# How far under the score the deduction line starts, so it reads as coming out of the digits
# rather than fading in beside them. 18px puts it behind the score's own glyphs, and it takes
# its own slow beat to crawl clear — long enough to watch the money leave.
const LOSS_RISE := 18.0
const LOSS_EMERGE_TIME := 0.75
const PHASE_BUTTON_IN := 0.24

@onready var top_dim: ColorRect = %TopDim
@onready var bottom_dim: ColorRect = %BottomDim
@onready var left_dim: ColorRect = %LeftDim
@onready var right_dim: ColorRect = %RightDim
@onready var skip_catcher: Button = %SkipCatcher
@onready var title_label: Label = %TitleLabel
@onready var tv_host: Control = %TvHost
@onready var target_group: Control = %TargetGroup
@onready var lost_label: Label = %LostLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var button_host: Control = %ButtonHost
@onready var continue_button: Button = %ContinueButton

var _font: FontFile = null
var _score := 0
var _target := 0
var _remaining := 0
var _presentation_started := false
var _sequence_done := false
var _snapshot: WealthOdometer = null
var _snapshot_to := Vector2.ZERO
var _snapshot_scale := 1.0
var _target_glyphs: Array[Label] = []
var _shards: Array[Dictionary] = []
var _drain_motes: Array[Dictionary] = []
var _lost_label_rest_y := 0.0 # authored position; the line slides down to it out of the score
var _sequence_tween: Tween = null
var _shard_tween: Tween = null
var _drain_tween: Tween = null


func _ready() -> void:
	_font = Assets.font()
	_lost_label_rest_y = lost_label.position.y
	_style_text()
	_style_button()
	if not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)
	if not skip_catcher.pressed.is_connected(_skip_to_end):
		skip_catcher.pressed.connect(_skip_to_end)
	Assets.start_menu_button_press_feedback(continue_button)
	button_host.pivot_offset = button_host.size * 0.5
	if Engine.is_editor_hint():
		_score = 650
		_target = 500
		_remaining = 150
		lost_label.text = "-%d" % _target
		return


## Sets the beaten target and running score, then plays the payout. `snapshot` is the
## detached copy of the machine's wealth reels this overlay flies; the caller builds it
## before hiding the live ones. A caller that has no machine to lift from (the debug
## shot) may omit it and the overlay makes its own.
func present(score: int, target: int, snapshot: WealthOdometer = null,
		action_text: String = "CONTINUE") -> void:
	_score = score
	_target = target
	_remaining = maxi(0, score - target)
	continue_button.text = action_text
	lost_label.text = ""
	for dim: ColorRect in _dims():
		dim.modulate.a = 0.0
	title_label.modulate.a = 0.0
	title_label.position.y = TITLE_START_Y
	lost_label.position.y = _lost_label_rest_y
	lost_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	button_host.modulate.a = 0.0
	target_group.modulate.a = 0.0
	_snapshot = snapshot if snapshot != null else WealthOdometer.make_snapshot(_score)
	_prepare_snapshot()
	# The glyphs exist from the start (invisible) so the target being paid is readable
	# state, not something that only appears part way through a tween.
	_build_target_glyphs()
	if _presentation_started or Engine.is_editor_hint():
		return
	_presentation_started = true
	_play()


## The four rects that black the cabinet out around the TV. The band beside the TV needs
## covering too, or the neon spins tube and power gauge keep glowing at full brightness
## either side of the payout (issue #181).
func _dims() -> Array[ColorRect]:
	return [top_dim, bottom_dim, left_dim, right_dim]


func _prepare_snapshot() -> void:
	if _snapshot == null:
		return
	if _snapshot.get_parent() != tv_host:
		if _snapshot.get_parent() != null:
			_snapshot.get_parent().remove_child(_snapshot)
		tv_host.add_child(_snapshot)
	var bounds := _snapshot.visible_digit_bounds()
	_snapshot_scale = SCORE_SCALE
	# Scale about the digits themselves; the snapshot's own rect is the whole canvas.
	_snapshot.pivot_offset = bounds.get_center()
	_snapshot.position = Vector2.ZERO # sits exactly over the machine's live reels
	_snapshot.scale = Vector2.ONE
	_snapshot_to = SCORE_CENTER - bounds.get_center()


func _place_snapshot_at_tv(t: float) -> void:
	if _snapshot == null or not is_instance_valid(_snapshot):
		return
	_snapshot.position = Vector2.ZERO.lerp(_snapshot_to, t)
	var s := lerpf(1.0, _snapshot_scale, t)
	_snapshot.scale = Vector2(s, s)


## One Label per character of "-500", laid out centred on TARGET_CENTER so each can
## fade on its own beat when the number shatters.
func _build_target_glyphs() -> void:
	for glyph in _target_glyphs:
		if is_instance_valid(glyph):
			glyph.queue_free()
	_target_glyphs.clear()
	# The target itself, unsigned: the minus belongs to the deduction line under the
	# score, which is what the payout actually took.
	var text := str(_target)
	var glyph_width := float(TARGET_FONT_SIZE) * 0.62
	var total := glyph_width * float(text.length())
	for i in text.length():
		var glyph := Label.new()
		glyph.text = text[i]
		glyph.position = Vector2(
			TARGET_CENTER.x - total * 0.5 + float(i) * glyph_width,
			TARGET_CENTER.y - float(TARGET_FONT_SIZE) * 0.5)
		glyph.size = Vector2(glyph_width, float(TARGET_FONT_SIZE))
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.add_theme_font_size_override(&"font_size", TARGET_FONT_SIZE)
		if _font != null:
			glyph.add_theme_font_override(&"font", _font)
		glyph.add_theme_color_override(&"font_color", TARGET_NUMBER_COLOR)
		glyph.add_theme_color_override(&"font_outline_color", Color("#03060c"))
		glyph.add_theme_constant_override(&"outline_size", 1)
		target_group.add_child(glyph)
		_target_glyphs.append(glyph)


## Current text of the target line, so a caller (and the scene smoke) can read what is
## being paid without reaching into the glyph nodes.
func target_text() -> String:
	var text := ""
	for glyph in _target_glyphs:
		if is_instance_valid(glyph):
			text += glyph.text
	return text


func _play() -> void:
	target_group.pivot_offset = TARGET_CENTER
	# Built sequentially; parallel() attaches a tweener to the beat before it. Do not
	# reach for set_parallel(true) here — it latches on for every following tweener and
	# collapses the whole timeline into one beat.
	_sequence_tween = create_tween()
	# The TV goes dark first; the machine fades its own blackout over the same window.
	_sequence_tween.tween_property(top_dim, "modulate:a", DIM_ALPHA, PHASE_BLACKOUT) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for dim: ColorRect in [bottom_dim, left_dim, right_dim]:
		_sequence_tween.parallel().tween_property(dim, "modulate:a", DIM_ALPHA,
			PHASE_BLACKOUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_sequence_tween.tween_property(title_label, "modulate:a", 1.0, PHASE_TITLE_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence_tween.parallel().tween_property(title_label, "position:y", TITLE_REST_Y,
		PHASE_TITLE_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sequence_tween.tween_interval(PHASE_TITLE_HOLD)
	# The target the run just beat grows to fill the dead TV — it is what this screen
	# is about, so it gets the screen.
	_sequence_tween.tween_property(target_group, "modulate:a", 1.0, PHASE_TARGET_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence_tween.parallel().tween_property(target_group, "scale", Vector2.ONE,
		PHASE_TARGET_IN).from(Vector2(TARGET_GROW_FROM, TARGET_GROW_FROM)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sequence_tween.tween_interval(PHASE_LIFT_HOLD)
	# The score then leaves the cabinet and parks under the TV, below the target.
	_sequence_tween.tween_callback(digits_lifted.emit)
	_sequence_tween.tween_method(_place_snapshot_at_tv, 0.0, 1.0, PHASE_LIFT) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sequence_tween.tween_interval(PHASE_TARGET_HOLD)
	# The target starts raining into the score, and a beat later the reels answer it and
	# roll down. The target still hangs there, so the number being taken is on screen for
	# the whole drain...
	_sequence_tween.tween_callback(_play_drain_stream)
	_sequence_tween.tween_interval(DRAIN_LEAD)
	_sequence_tween.tween_callback(_start_drain)
	_sequence_tween.tween_interval(PHASE_DRAIN)
	_sequence_tween.tween_callback(_clear_drain_stream)
	# ...and only once the reels have settled on the remainder does it disintegrate. The
	# target must not leave before the money has finished moving (issue #181).
	_sequence_tween.tween_callback(_shatter_target)
	_sequence_tween.tween_interval(PHASE_SHATTER)
	_sequence_tween.tween_callback(_clear_shards)
	# Only once the target is gone does what it cost come OUT of the score: the red line
	# starts hidden behind the digits and slides down clear of them.
	_sequence_tween.tween_callback(func() -> void:
		lost_label.text = "-%d" % _target
		lost_label.position.y = _lost_label_rest_y - LOSS_RISE)
	_sequence_tween.tween_property(lost_label, "modulate:a", 1.0, LOSS_EMERGE_TIME)
	_sequence_tween.parallel().tween_property(lost_label, "position:y",
		_lost_label_rest_y, LOSS_EMERGE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sequence_tween.parallel().tween_property(subtitle_label, "modulate:a", 1.0, PHASE_SETTLE)
	_sequence_tween.tween_property(button_host, "modulate:a", 1.0, PHASE_BUTTON_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence_tween.tween_callback(_on_sequence_finished)


func _start_drain() -> void:
	if _snapshot != null and is_instance_valid(_snapshot):
		_snapshot.set_value(_remaining, true, PHASE_DRAIN)


## The money falling out of the target and into the score: it starts DRAIN_LEAD before the
## roll and runs to the end of it. Parented to the overlay itself (after the snapshot) so
## the motes land in front of the digits they are feeding.
func _play_drain_stream() -> void:
	_clear_drain_stream()
	var rng := RandomNumberGenerator.new()
	rng.seed = DRAIN_RNG_SEED
	var from_y := TARGET_CENTER.y + float(TARGET_FONT_SIZE) * 0.34
	var to_y := SCORE_CENTER.y - 5.0
	# The last mote must still land inside the roll, so the launches share the window
	# that is left once one flight is subtracted.
	var launch_window := 1.0 - DRAIN_MOTE_FLIGHT
	for i in DRAIN_MOTES:
		var mote := ColorRect.new()
		mote.size = Vector2(DRAIN_MOTE_SIZE, DRAIN_MOTE_SIZE)
		mote.color = TARGET_NUMBER_COLOR.lerp(BLUE_NEON, rng.randf() * 0.75)
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mote.modulate.a = 0.0
		add_child(mote)
		_drain_motes.append({
			"node": mote,
			"from": Vector2(TARGET_CENTER.x
				+ rng.randf_range(-0.5, 0.5) * DRAIN_MOTE_SPREAD, from_y),
			"to": Vector2(SCORE_CENTER.x
				+ rng.randf_range(-0.5, 0.5) * DRAIN_MOTE_LANDING_SPREAD, to_y),
			"sway": rng.randf_range(-DRAIN_MOTE_SWAY, DRAIN_MOTE_SWAY),
			"launch": float(i) / float(DRAIN_MOTES) * launch_window,
		})
	if _drain_tween != null and _drain_tween.is_valid():
		_drain_tween.kill()
	_drain_tween = create_tween()
	_drain_tween.tween_method(_drive_drain_stream, 0.0, 1.0, PHASE_DRAIN + DRAIN_LEAD)


func _drive_drain_stream(t: float) -> void:
	for mote: Dictionary in _drain_motes:
		var node := mote["node"] as ColorRect
		if not is_instance_valid(node):
			continue
		var flight := (t - float(mote["launch"])) / DRAIN_MOTE_FLIGHT
		if flight <= 0.0 or flight >= 1.0:
			node.modulate.a = 0.0
			continue
		# Falling money accelerates; the sway keeps the column from reading as a ruler.
		var from: Vector2 = mote["from"]
		var to: Vector2 = mote["to"]
		node.position = from.lerp(to, flight * flight) \
			+ Vector2(sin(flight * PI) * float(mote["sway"]), 0.0)
		node.modulate.a = sin(flight * PI)


func _clear_drain_stream() -> void:
	if _drain_tween != null and _drain_tween.is_valid():
		_drain_tween.kill()
	_drain_tween = null
	for mote: Dictionary in _drain_motes:
		var node := mote["node"] as ColorRect
		if is_instance_valid(node):
			node.queue_free()
	_drain_motes.clear()


func _shatter_target() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SHARD_RNG_SEED
	for glyph_index in _target_glyphs.size():
		var glyph: Label = _target_glyphs[glyph_index]
		if not is_instance_valid(glyph):
			continue
		for _s in SHARD_PER_GLYPH:
			var shard := ColorRect.new()
			shard.size = Vector2(SHARD_SIZE, SHARD_SIZE)
			shard.color = TARGET_NUMBER_COLOR.lerp(BLUE_NEON, rng.randf() * 0.6)
			shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var origin := glyph.position + Vector2(
				rng.randf_range(0.0, maxf(1.0, glyph.size.x - SHARD_SIZE)),
				rng.randf_range(0.0, maxf(1.0, glyph.size.y - SHARD_SIZE)))
			shard.position = origin
			target_group.add_child(shard)
			var angle := deg_to_rad(-90.0
				+ rng.randf_range(-SHARD_SPREAD_DEG, SHARD_SPREAD_DEG))
			var speed := rng.randf_range(SHARD_SPEED_MIN, SHARD_SPEED_MAX)
			_shards.append({
				"node": shard,
				"origin": origin,
				"velocity": Vector2(cos(angle), sin(angle)) * speed,
			})
	if _shard_tween != null and _shard_tween.is_valid():
		_shard_tween.kill()
	_shard_tween = create_tween()
	_shard_tween.set_parallel(true)
	for glyph_index in _target_glyphs.size():
		var glyph: Label = _target_glyphs[glyph_index]
		if not is_instance_valid(glyph):
			continue
		# Right to left: the last digit goes first, so "-500" crumbles as a wave.
		_shard_tween.tween_property(glyph, "modulate:a", 0.0, SHARD_GLYPH_FADE) \
			.set_delay(float(_target_glyphs.size() - 1 - glyph_index) * SHARD_GLYPH_STAGGER)
	_shard_tween.tween_method(_drive_target_shards, 0.0, 1.0, PHASE_SHATTER)


func _drive_target_shards(t: float) -> void:
	var elapsed := t * PHASE_SHATTER
	for shard: Dictionary in _shards:
		var node := shard["node"] as ColorRect
		if not is_instance_valid(node):
			continue
		node.position = (shard["origin"] as Vector2) + (shard["velocity"] as Vector2) * elapsed \
			+ Vector2(0.0, 0.5 * SHARD_GRAVITY * elapsed * elapsed)
		node.modulate.a = clampf(1.0 - t * t, 0.0, 1.0)


func _clear_shards() -> void:
	for shard: Dictionary in _shards:
		var node := shard["node"] as ColorRect
		if is_instance_valid(node):
			node.queue_free()
	_shards.clear()


## Jumps to the settled frame. The payout screen is seen several times a run, so the
## whole 5.5s beat is skippable — this only fast-forwards the presentation, the state
## commit still waits for CONTINUE.
func _skip_to_end() -> void:
	if _sequence_done:
		return
	if _sequence_tween != null and _sequence_tween.is_valid():
		_sequence_tween.kill()
	if _shard_tween != null and _shard_tween.is_valid():
		_shard_tween.kill()
	_clear_shards()
	_clear_drain_stream()
	for dim: ColorRect in _dims():
		dim.modulate.a = DIM_ALPHA
	title_label.modulate.a = 1.0
	title_label.position.y = TITLE_REST_Y
	digits_lifted.emit()
	_place_snapshot_at_tv(1.0)
	if _snapshot != null and is_instance_valid(_snapshot):
		_snapshot.set_value(_remaining, false)
	target_group.modulate.a = 0.0
	lost_label.text = "-%d" % _target
	lost_label.position.y = _lost_label_rest_y
	lost_label.modulate.a = 1.0
	subtitle_label.modulate.a = 1.0
	button_host.modulate.a = 1.0
	_on_sequence_finished()


func _on_sequence_finished() -> void:
	if _sequence_done:
		return
	_sequence_done = true
	# Stop swallowing presses, or the catcher would eat the real CONTINUE.
	skip_catcher.disabled = true
	skip_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sequence_finished.emit()


func _style_text() -> void:
	for label: Label in [title_label, subtitle_label, lost_label]:
		if _font != null:
			label.add_theme_font_override(&"font", _font)
		label.add_theme_color_override(&"font_outline_color", Color("#03060c"))
		label.add_theme_constant_override(&"outline_size", 1)
	# Flat neon, no glow shadow: a same-hue 1px shadow under a 1px outline read as a
	# ghosted second copy of the title (issue #181).
	title_label.add_theme_color_override(&"font_color", BLUE_NEON)
	subtitle_label.add_theme_color_override(&"font_color", SOFT_WHITE)
	lost_label.add_theme_color_override(&"font_color", LOSS_RED)


func _style_button() -> void:
	Assets.small_neon_button_style(continue_button, BLUE_NEON, 7, 1.0)


func _on_continue_pressed() -> void:
	continue_pressed.emit()
