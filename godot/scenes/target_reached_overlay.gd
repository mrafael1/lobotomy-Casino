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
## Everything the payout costs is then itemised as one receipt under the score: the target
## itself heads the list, and the casino's charges (EconomyConst.overflow_bill) are stamped
## under it one at a time with the reels rolling down beneath each, so the player watches
## the overflow being billed away rather than finding a smaller number in the wallet later.
## The gold line under the rule is what actually banks.
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
# What survives the bill and reaches the wallet. Gold rather than the screen's blue: it
# is the one number on here the player keeps.
const CREDIT_GOLD := Color(1.0, 0.83, 0.36)
const BILL_LABEL_COLOR := Color(0.72, 0.76, 0.82)
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
const PHASE_BUTTON_IN := 0.24

# The receipt under the score: the target paid, then one row per
# EconomyConst.OVERFLOW_TAX_LINES entry — charge and its rate on the left, what it took
# on the right. The target heads the list without a rate: it is a flat debt, not a cut.
const TARGET_PAID_LABEL := "TARGET PAID"
const BILL_ROW_FIRST_Y := 180.0
const BILL_ROW_STEP := 10.0
const BILL_ROW_HEIGHT := 9.0
const BILL_LABEL_X := 22.0
const BILL_LABEL_WIDTH := 86.0
const BILL_AMOUNT_X := 108.0
const BILL_AMOUNT_WIDTH := 30.0
const BILL_FONT_SIZE := 7
# Each row slides in from the right as it is stamped, like a line being printed.
const BILL_ROW_SLIDE := 9.0
# One charge lands and the reels answer it inside the same beat, so the number going
# down is unmistakably that row's doing. The gap is the pause before the next charge.
const PHASE_BILL_ROW := 0.42
const PHASE_BILL_ROW_GAP := 0.12
# The target line is the headline debt and gets a slower beat than the charges under it.
const PHASE_BILL_TARGET := 0.60
const PHASE_BILL_NET := 0.40
# The rule is drawn left to right under the charges before the total lands.
const PHASE_BILL_RULE := 0.22

@onready var top_dim: ColorRect = %TopDim
@onready var bottom_dim: ColorRect = %BottomDim
@onready var left_dim: ColorRect = %LeftDim
@onready var right_dim: ColorRect = %RightDim
@onready var skip_catcher: Button = %SkipCatcher
@onready var title_label: Label = %TitleLabel
@onready var tv_host: Control = %TvHost
@onready var target_group: Control = %TargetGroup
@onready var bill_group: Control = %BillGroup
# The rule under the last charge: what makes the gold line read as a receipt total
# rather than one more row.
@onready var bill_rule: ColorRect = %BillRule
@onready var net_label: Label = %NetLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var button_host: Control = %ButtonHost
@onready var continue_button: Button = %ContinueButton

var _font: FontFile = null
var _score := 0
var _target := 0
var _remaining := 0
var _net := 0
var _final_target := false
var _bill_lines: Array[Dictionary] = []
var _bill_rows: Array[Dictionary] = []
var _presentation_started := false
var _sequence_done := false
var _snapshot: WealthOdometer = null
var _snapshot_to := Vector2.ZERO
var _snapshot_scale := 1.0
var _target_glyphs: Array[Label] = []
var _shards: Array[Dictionary] = []
var _drain_motes: Array[Dictionary] = []
var _sequence_tween: Tween = null
var _shard_tween: Tween = null
var _drain_tween: Tween = null


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
		var preview := EconomyConst.overflow_bill(_remaining, _target)
		_bill_lines.clear()
		_bill_lines.append({"key": "target", "label": TARGET_PAID_LABEL,
			"amount": _target, "roll": false})
		for line: Dictionary in preview["lines"] as Array:
			_bill_lines.append(line)
		_net = int(preview["net"])
		_build_bill_rows()
		_settle_bill_rows()
		return


## Sets the beaten target and running score, then plays the payout. `snapshot` is the
## detached copy of the machine's wealth reels this overlay flies; the caller builds it
## before hiding the live ones. A caller that has no machine to lift from (the debug
## shot) may omit it and the overlay makes its own.
##
## `final_target` is the last rung of the ladder, which is not paid out of the score at
## all — it belongs to the Wealth ending — so nothing is billed and no receipt is shown.
func present(score: int, target: int, snapshot: WealthOdometer = null,
		action_text: String = "CONTINUE", final_target: bool = false) -> void:
	_score = score
	_target = target
	_remaining = maxi(0, score - target)
	_final_target = final_target
	# The bill is derived here rather than passed in: the store settles it from the same
	# EconomyConst helper on CONTINUE, so recomputing cannot drift from what is banked.
	var bill := EconomyConst.overflow_bill(_remaining, _target) if not final_target else {}
	# The target heads the receipt whatever else happens — it explains the drain the
	# player just watched. It carries no rate and does not roll the reels again: the
	# drain phase already took it off them.
	_bill_lines.clear()
	_bill_lines.append({
		"key": "target",
		"label": TARGET_PAID_LABEL,
		"amount": _target,
		"roll": false,
	})
	if not bill.is_empty() and _remaining > 0:
		for line: Dictionary in bill["lines"] as Array:
			var row := (line as Dictionary).duplicate()
			row["roll"] = true
			_bill_lines.append(row)
	_net = int(bill.get("net", _remaining)) if _has_tax_rows() else _remaining
	continue_button.text = action_text
	net_label.text = ""
	net_label.modulate.a = 0.0
	bill_rule.modulate.a = 0.0
	_build_bill_rows()
	for dim: ColorRect in _dims():
		dim.modulate.a = 0.0
	title_label.modulate.a = 0.0
	title_label.position.y = TITLE_START_Y
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


## One receipt row per charge, built invisible up front so the bill is readable state
## rather than something that only exists mid-tween. Each row is a label/amount pair
## tracked together, since they slide and fade as one line.
func _build_bill_rows() -> void:
	for row: Dictionary in _bill_rows:
		for key: String in ["label", "amount"]:
			var node := row[key] as Label
			if is_instance_valid(node):
				node.queue_free()
	_bill_rows.clear()
	for i in _bill_lines.size():
		var line: Dictionary = _bill_lines[i]
		var rest_y := BILL_ROW_FIRST_Y + float(i) * BILL_ROW_STEP
		# The rate is on the charge, not the amount: the player should read WHY the
		# number on the right is that big before they read the number. A row with no
		# rate (the target itself) is a flat debt and shows its name alone.
		var text := String(line["label"])
		if line.has("rate"):
			text += " %d%%" % roundi(float(line["rate"]) * 100.0)
		var label := _make_bill_label(text,
			BILL_LABEL_X, rest_y, BILL_LABEL_WIDTH, HORIZONTAL_ALIGNMENT_LEFT,
			BILL_LABEL_COLOR)
		var amount := _make_bill_label("-%d" % int(line["amount"]),
			BILL_AMOUNT_X, rest_y, BILL_AMOUNT_WIDTH, HORIZONTAL_ALIGNMENT_RIGHT,
			LOSS_RED)
		_bill_rows.append({"label": label, "amount": amount, "rest_y": rest_y})


func _make_bill_label(text: String, x: float, y: float, width: float,
		alignment: HorizontalAlignment, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = Vector2(x, y)
	label.size = Vector2(width, BILL_ROW_HEIGHT)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	label.add_theme_font_size_override(&"font_size", BILL_FONT_SIZE)
	if _font != null:
		label.add_theme_font_override(&"font", _font)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color("#03060c"))
	label.add_theme_constant_override(&"outline_size", 1)
	bill_group.add_child(label)
	return label


## Current text of the receipt, row by row, for callers and the scene smoke.
func bill_text() -> Array[String]:
	var rows: Array[String] = []
	for row: Dictionary in _bill_rows:
		var label := row["label"] as Label
		var amount := row["amount"] as Label
		if is_instance_valid(label) and is_instance_valid(amount):
			rows.append("%s %s" % [label.text, amount.text])
	return rows


## What the payout screen says reaches the wallet.
func net_banked() -> int:
	return _net


## Stamps one receipt line, rolling the reels down under it in the same beat when that
## line is what takes the money (`roll`). The target line does not roll: the drain phase
## already showed it leaving.
func _tween_bill_row(tween: Tween, index: int, value_after: int, roll: bool,
		duration: float) -> void:
	if index < 0 or index >= _bill_rows.size():
		return
	var row: Dictionary = _bill_rows[index]
	var nodes: Array[Label] = []
	for key: String in ["label", "amount"]:
		var node := row[key] as Label
		if is_instance_valid(node):
			nodes.append(node)
	if nodes.is_empty():
		return
	# The reels start rolling on the frame the charge lands, not after it has finished
	# arriving — the row and the drop are one event.
	if roll:
		tween.tween_callback(func() -> void:
			if _snapshot != null and is_instance_valid(_snapshot):
				_snapshot.set_value(value_after, true, duration))
	var leading := true
	for node: Label in nodes:
		# Read the authored rest position and drive .from() off it: the row must land
		# where _build_bill_rows put it, whatever order the tweeners are built in.
		var rest_x := node.position.x
		var fade := tween.tween_property(node, "modulate:a", 1.0, duration) if leading \
			else tween.parallel().tween_property(node, "modulate:a", 1.0, duration)
		fade.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(node, "position:x", rest_x, duration) \
			.from(rest_x + BILL_ROW_SLIDE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		leading = false
	tween.tween_interval(PHASE_BILL_ROW_GAP)


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
	# Only once the target is gone is the bill written up. It reads as one receipt: the
	# target that was just paid heads the list, then the casino itemises the leftovers,
	# each charge stamped and taken off the reels in turn — so the overflow is watched
	# being billed down to what actually banks. The gold line is the only number kept.
	var running := _remaining
	for i in _bill_rows.size():
		var line: Dictionary = _bill_lines[i]
		var rolls := bool(line.get("roll", true))
		if rolls:
			running -= int(line["amount"])
		_tween_bill_row(_sequence_tween, i, running, rolls,
			PHASE_BILL_TARGET if i == 0 else PHASE_BILL_ROW)
	if _has_tax_rows():
		_sequence_tween.tween_callback(func() -> void: net_label.text = _net_text())
		# Pivot stays at the rect's origin, so scaling x draws the rule out of its left end.
		_sequence_tween.tween_property(bill_rule, "modulate:a", 1.0, PHASE_BILL_RULE)
		_sequence_tween.parallel().tween_property(bill_rule, "scale:x", 1.0, PHASE_BILL_RULE) \
			.from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_sequence_tween.tween_property(net_label, "modulate:a", 1.0, PHASE_BILL_NET) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# The receipt is complete; the line about it and the way out arrive together.
	_sequence_tween.tween_property(subtitle_label, "modulate:a", 1.0, PHASE_SETTLE)
	_sequence_tween.parallel().tween_property(button_host, "modulate:a", 1.0, PHASE_BUTTON_IN) \
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
	# The settled frame is the END of the bill, not the middle of it: the reels rest on
	# what banked. Without a bill (the final target) _net IS the remainder.
	if _snapshot != null and is_instance_valid(_snapshot):
		_snapshot.set_value(_net, false)
	target_group.modulate.a = 0.0
	_settle_bill_rows()
	subtitle_label.modulate.a = 1.0
	button_host.modulate.a = 1.0
	_on_sequence_finished()


## Whether the casino charged anything on top of the target. The final target heads a
## receipt of one line and banks nothing, so it gets no rule and no total.
func _has_tax_rows() -> bool:
	return _bill_lines.size() > 1


## What the payout screen banks, as the player reads it.
func _net_text() -> String:
	return "+%d CREDITS" % _net


## Jumps the receipt to its finished state — every row printed, net line up.
func _settle_bill_rows() -> void:
	for row: Dictionary in _bill_rows:
		for key: String in ["label", "amount"]:
			var node := row[key] as Label
			if is_instance_valid(node):
				node.modulate.a = 1.0
	if not _has_tax_rows():
		return
	bill_rule.scale.x = 1.0
	bill_rule.modulate.a = 1.0
	net_label.text = _net_text()
	net_label.modulate.a = 1.0


func _on_sequence_finished() -> void:
	if _sequence_done:
		return
	_sequence_done = true
	# Stop swallowing presses, or the catcher would eat the real CONTINUE.
	skip_catcher.disabled = true
	skip_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sequence_finished.emit()


func _style_text() -> void:
	for label: Label in [title_label, subtitle_label, net_label]:
		if _font != null:
			label.add_theme_font_override(&"font", _font)
		label.add_theme_color_override(&"font_outline_color", Color("#03060c"))
		label.add_theme_constant_override(&"outline_size", 1)
	net_label.add_theme_color_override(&"font_color", CREDIT_GOLD)
	# Flat neon, no glow shadow: a same-hue 1px shadow under a 1px outline read as a
	# ghosted second copy of the title (issue #181).
	title_label.add_theme_color_override(&"font_color", BLUE_NEON)
	subtitle_label.add_theme_color_override(&"font_color", SOFT_WHITE)


func _style_button() -> void:
	Assets.small_neon_button_style(continue_button, BLUE_NEON, 7, 1.0)


func _on_continue_pressed() -> void:
	continue_pressed.emit()
