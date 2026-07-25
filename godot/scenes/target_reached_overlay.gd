@tool
class_name TargetReachedOverlay
extends Control

## Intermediate wealth-target payout screen (issues #176, #181).
##
## The beat is deliberately slow and reads left to right in one sentence: the machine
## TV goes dark, the running score is lifted off the wealth reels at the bottom of the
## cabinet and flies up into the middle of the TV at three quarters of its width, the
## beaten target appears underneath and disintegrates, and the score then drains by
## that amount — the money paid to the casino.
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
const MUTED_BLUE := Color(0.56, 0.66, 0.82)
const LOSS_RED := Color(0.93, 0.27, 0.27)
const DIM_ALPHA := 0.72

# Where the lifted number parks, and how much of the TV it fills. The TV screen is
# 112x66 at (24, 42); three quarters of that is the issue's brief.
const TV_CENTER := Vector2(80.0, 72.0)
const TV_SIZE := Vector2(112.0, 66.0)
const TV_FILL := 0.75
const SNAPSHOT_SCALE_MIN := 1.4
const SNAPSHOT_SCALE_MAX := 3.0
const TARGET_CENTER := Vector2(80.0, 96.0)
const TARGET_FONT_SIZE := 14
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
const PHASE_DRAIN := 0.75
const PHASE_SETTLE := 0.24
const PHASE_BUTTON_IN := 0.24

@onready var top_dim: ColorRect = %TopDim
@onready var bottom_dim: ColorRect = %BottomDim
@onready var skip_catcher: Button = %SkipCatcher
@onready var title_label: Label = %TitleLabel
@onready var tv_host: Control = %TvHost
@onready var target_group: Control = %TargetGroup
@onready var caption_label: Label = %CaptionLabel
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
var _sequence_tween: Tween = null
var _shard_tween: Tween = null


func _ready() -> void:
	_font = Assets.font()
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
	top_dim.modulate.a = 0.0
	bottom_dim.modulate.a = 0.0
	title_label.modulate.a = 0.0
	title_label.position.y = TITLE_START_Y
	caption_label.modulate.a = 0.0
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


func _prepare_snapshot() -> void:
	if _snapshot == null:
		return
	if _snapshot.get_parent() != tv_host:
		if _snapshot.get_parent() != null:
			_snapshot.get_parent().remove_child(_snapshot)
		tv_host.add_child(_snapshot)
	var bounds := _snapshot.visible_digit_bounds()
	_snapshot_scale = clampf(minf(
		TV_SIZE.x * TV_FILL / maxf(1.0, bounds.size.x),
		TV_SIZE.y * TV_FILL / maxf(1.0, bounds.size.y)),
		SNAPSHOT_SCALE_MIN, SNAPSHOT_SCALE_MAX)
	# Scale about the digits themselves; the snapshot's own rect is the whole canvas.
	_snapshot.pivot_offset = bounds.get_center()
	_snapshot.position = Vector2.ZERO # sits exactly over the machine's live reels
	_snapshot.scale = Vector2.ONE
	_snapshot_to = TV_CENTER - bounds.get_center()


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
	var text := "-%d" % _target
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
		glyph.add_theme_color_override(&"font_color", LOSS_RED)
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
	_sequence_tween.parallel().tween_property(bottom_dim, "modulate:a", DIM_ALPHA,
		PHASE_BLACKOUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_sequence_tween.tween_property(title_label, "modulate:a", 1.0, PHASE_TITLE_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence_tween.parallel().tween_property(title_label, "position:y", TITLE_REST_Y,
		PHASE_TITLE_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sequence_tween.tween_interval(PHASE_TITLE_HOLD)
	# The score leaves the cabinet and grows into the middle of the dead TV.
	_sequence_tween.tween_callback(digits_lifted.emit)
	_sequence_tween.tween_method(_place_snapshot_at_tv, 0.0, 1.0, PHASE_LIFT) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sequence_tween.parallel().tween_property(caption_label, "modulate:a", 1.0,
		PHASE_LIFT * 0.5).set_delay(PHASE_LIFT * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence_tween.tween_interval(PHASE_LIFT_HOLD)
	# The bill pops in under it...
	_sequence_tween.tween_property(target_group, "modulate:a", 1.0, PHASE_TARGET_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence_tween.parallel().tween_property(target_group, "scale", Vector2.ONE,
		PHASE_TARGET_IN).from(Vector2(0.6, 0.6)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sequence_tween.tween_interval(PHASE_TARGET_HOLD)
	# ...and disintegrates, with the drain starting while the shards are still in the
	# air so the money leaving and the score dropping read as one event.
	_sequence_tween.tween_callback(_shatter_target)
	_sequence_tween.tween_interval(PHASE_SHATTER * 0.55)
	_sequence_tween.tween_callback(_start_drain)
	_sequence_tween.tween_interval(PHASE_DRAIN)
	_sequence_tween.tween_callback(_clear_shards)
	_sequence_tween.tween_callback(func() -> void: lost_label.text = "-%d" % _target)
	_sequence_tween.tween_property(lost_label, "modulate:a", 1.0, PHASE_SETTLE)
	_sequence_tween.parallel().tween_property(subtitle_label, "modulate:a", 1.0, PHASE_SETTLE)
	_sequence_tween.tween_property(button_host, "modulate:a", 1.0, PHASE_BUTTON_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence_tween.tween_callback(_on_sequence_finished)


func _start_drain() -> void:
	if _snapshot != null and is_instance_valid(_snapshot):
		_snapshot.set_value(_remaining, true, PHASE_DRAIN)


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
			shard.color = LOSS_RED.lerp(Color(1.0, 0.72, 0.62), rng.randf() * 0.5)
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
## whole 4.6s beat is skippable — this only fast-forwards the presentation, the state
## commit still waits for CONTINUE.
func _skip_to_end() -> void:
	if _sequence_done:
		return
	if _sequence_tween != null and _sequence_tween.is_valid():
		_sequence_tween.kill()
	if _shard_tween != null and _shard_tween.is_valid():
		_shard_tween.kill()
	_clear_shards()
	top_dim.modulate.a = DIM_ALPHA
	bottom_dim.modulate.a = DIM_ALPHA
	title_label.modulate.a = 1.0
	title_label.position.y = TITLE_REST_Y
	digits_lifted.emit()
	_place_snapshot_at_tv(1.0)
	if _snapshot != null and is_instance_valid(_snapshot):
		_snapshot.set_value(_remaining, false)
	target_group.modulate.a = 0.0
	caption_label.modulate.a = 1.0
	lost_label.text = "-%d" % _target
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
	for label: Label in [title_label, subtitle_label, caption_label, lost_label]:
		if _font != null:
			label.add_theme_font_override(&"font", _font)
		label.add_theme_color_override(&"font_outline_color", Color("#03060c"))
		label.add_theme_constant_override(&"outline_size", 1)
	# Flat neon, no glow shadow: a same-hue 1px shadow under a 1px outline read as a
	# ghosted second copy of the title (issue #181).
	title_label.add_theme_color_override(&"font_color", BLUE_NEON)
	subtitle_label.add_theme_color_override(&"font_color", SOFT_WHITE)
	caption_label.add_theme_color_override(&"font_color", MUTED_BLUE)
	lost_label.add_theme_color_override(&"font_color", LOSS_RED)


func _style_button() -> void:
	Assets.small_neon_button_style(continue_button, BLUE_NEON, 7, 1.0)


func _on_continue_pressed() -> void:
	continue_pressed.emit()
