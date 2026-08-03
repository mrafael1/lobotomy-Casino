class_name ScoreTable
extends RefCounted

## The full-screen payout table (issue #119) and the two hold-to-peek bubbles on
## its rows: the triple's effect blurb, and the symbol's live draw chance (#153).
##
## Seam 4.3a, and the cleanest boundary the rework has found so far. Of the 19
## functions the score table spans, thirteen have ZERO callers outside it and two
## more are called only by each other; the whole overlay reaches the machine
## through exactly four things, and all four already existed on MachineView. This
## seam grows the view contract by nothing at all.
##
## The plan filed this under "4.3 — score table, wealth, target bar (~52 fns,
## ~1,300 lines)". Measured, that is three clusters again: this table (15 fns,
## ~450 lines), the target readout on the TV (3 fns, 68 lines), and the wealth
## target transition and its ending screen. They share no fields.
##
## Everything drawn here is read live from the stores when the table opens —
## odds levels, symbol reward bonuses, the reward-amp symbol, flatline strike
## count. Nothing is cached between opens, which is why closing frees the
## overlay outright rather than hiding it.

## The authored art is a 1280x2240 sheet covering the full 160x320 canvas, but
## the authored scale is NOT square: x8 horizontally and x7 vertically
## (1280/160 vs 2240/320). Canvas-space rects are source px / 8 on x and source
## px / 7 on y; the information sheet only holds the per-row "i" buttons,
## cropped from their first pixel cluster.
const ART := "TABLE/TABLES SCORE.png"
const INFO_ART := "TABLE/TABLES SCORE_information.png"
const INFO_SRC := Rect2(1032.0, 408.0, 56.0, 56.0)
const INFO_X := 129.0
const INFO_W := 7.0
const INFO_H := 8.0
const INFO_ROW_Y := [58.3, 101.7, 145.1, 188.6, 232.0, 276.6]

## Vertical centers of the art's row bands (dark grid lines sit at canvas y 23.4,
## 68.0, 111.4, 154.9, 198.3, 241.7, 286.3), so the values center inside their cells.
const ROW_CY := [45.5, 89.5, 133.0, 176.5, 220.0, 264.0]

const LVL_CX := 66.0
const PAIR_CX := 99.0
const TRIPLE_CX := 131.5

const GAIN_COLOR := Color(0.75, 1.0, 0.8)
const DIM_COLOR := Color(0.45, 0.48, 0.58)
const LEVEL_COLOR := Color(1.0, 0.86, 0.2)
const REWARD_AMP_COLOR := Color(1.0, 0.86, 0.2)
const MAXED_COLOR := Color(1.0, 0.24, 0.24)
const BRAIN_COLOR := Color(1.0, 0.33, 0.58)
const NEON_GOLD := Color(1.0, 0.86, 0.36)

## Per-symbol bubble colors — keep in sync with OddsTableOverlay.SYMBOL_PERCENT_COLORS.
## Copied rather than referenced on purpose: pulling odds_table_overlay.gd into this
## script's compile chain breaks headless `-s` runs, which compile before autoloads.
const PCT_COLORS := {
	"brain": Color("#e86a73"),
	"eye": Color("#ce3dde"),
	"pill": Color("#e3e6ff"),
	"syringe": Color("#f9a31b"),
	"vial": Color("#b4202a"),
	"flatline": Color("#8f0d16"),
}

## Canvas centers of the 40 baked marquee bulbs (scanned from the art's yellow
## clusters): 14 across the top, 14 across the bottom, 6 per side.
const BULBS: Array[Vector2] = [
	Vector2(20.5, 6.5), Vector2(29.5, 6.5), Vector2(38.5, 6.5), Vector2(47.5, 6.5),
	Vector2(57.5, 6.5), Vector2(66.5, 6.5), Vector2(75.5, 6.5), Vector2(84.5, 6.5),
	Vector2(93.5, 6.5), Vector2(102.5, 6.5), Vector2(112.5, 6.5), Vector2(121.5, 6.5),
	Vector2(130.5, 6.5), Vector2(139.5, 6.5),
	Vector2(7.5, 38.5), Vector2(152.5, 38.5), Vector2(7.5, 90.0), Vector2(152.5, 90.0),
	Vector2(7.5, 133.5), Vector2(152.5, 133.5), Vector2(7.5, 177.0), Vector2(152.5, 177.0),
	Vector2(7.5, 220.0), Vector2(152.5, 220.0), Vector2(7.5, 263.5), Vector2(152.5, 263.5),
	Vector2(20.5, 311.5), Vector2(29.5, 311.5), Vector2(38.5, 311.5), Vector2(47.5, 311.5),
	Vector2(57.5, 311.5), Vector2(66.5, 311.5), Vector2(75.5, 311.5), Vector2(84.5, 311.5),
	Vector2(93.5, 311.5), Vector2(102.5, 311.5), Vector2(112.5, 311.5), Vector2(121.5, 311.5),
	Vector2(130.5, 311.5), Vector2(139.5, 311.5),
]
const BULB_GLOW_SIZE := 13.0

const SRC_W := 160.0
const SRC_H := 320.0

## Above HUD extras, below the options overlay (140).
const OVERLAY_Z_INDEX := 130

var _view: MachineView = null

## The triple-effect blurb and its per-segment colouring stay the machine's: both
## read tuning exports (the brain/vial free-spin counts, the fatal strike count,
## the flatline tint) that the smoke checks reassign at runtime. Handed over as
## Callables by the one caller rather than earning four MachineView entries for
## values this component only ever prints.
var _triple_effect_text: Callable
var _info_line_segments: Callable

var _overlay: Control = null
var _info_popup: Control = null
var _info_buttons: Array[Button] = []
var _pct_buttons: Array[Button] = []
var _bulb_tween: Tween = null

func _init(view: MachineView, triple_effect_text: Callable,
		info_line_segments: Callable) -> void:
	_view = view
	_triple_effect_text = triple_effect_text
	_info_line_segments = info_line_segments

func is_open() -> bool:
	return _overlay != null

func overlay() -> Control:
	return _overlay

## --- opening the table ---------------------------------------------------------
##
## The machine decides WHETHER the table may open — a live spin, an armed power or
## the dealer's offer all refuse it — and calls this once it has cleared the way.

func open() -> void:
	_info_buttons.clear()
	_pct_buttons.clear()
	_overlay = Control.new()
	_overlay.size = Vector2(SRC_W, SRC_H)
	_overlay.z_index = OVERLAY_Z_INDEX
	_view.add_layer(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.size = Vector2(SRC_W, SRC_H)
	_overlay.add_child(dim)

	# Authored full-canvas table art (issue #119): SYMBOL|LVL|PAIR|TRIPLE header,
	# row grid and symbol icons are baked in; only the live values are labels.
	var art := TextureRect.new()
	art.name = "TableArt"
	art.texture = _view.texture(ART, true)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = Vector2(SRC_W, SRC_H)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(art)
	_spawn_bulb_glows()

	_build_rows()
	var close := _build_close_button()
	_wire_focus_chain(close)

func _build_rows() -> void:
	var reward_amp_symbol := String(MetaStateStore.rewardAmpSymbol)
	var reward_amp_bonus := Economy.compute_symbol_reward_amp_bonus(RunStateStore.ownedUpgrades)
	for i in Symbols.BASE_SYMBOL_CYCLE.size():
		var symbol_id := String(Symbols.BASE_SYMBOL_CYCLE[i])
		var btn_y := float(INFO_ROW_Y[i])
		var row_cy := float(ROW_CY[i])

		# Permanent odds level: the same levels bought at the dealer's odds table;
		# dimmed when the symbol was never upgraded.
		var level := RunStateStore.odds_upgrade_level(symbol_id)
		var is_maxed := level >= int(RunStateStore.odds_max_level)
		var level_color := MAXED_COLOR if is_maxed else (
			LEVEL_COLOR if level > 0 else DIM_COLOR)
		_label_cell(str(level), LVL_CX, row_cy, 12, level_color)
		if is_maxed:
			_label_cell("(%s)" % reward_bonus_text(
				float(RunStateStore.odds_max_level_reward_bonus)),
				LVL_CX, row_cy + 10.0, 4, MAXED_COLOR)

		var reward_bonus := float(RunStateStore.symbolRewardBonuses.get(symbol_id, 0.0))
		var pair := floori(float(int(Payouts.PAIR_SCORE.get(symbol_id, 0))) * (1.0 + reward_bonus) + 0.5)
		var triple_base := Payouts.JACKPOT_SCORE if symbol_id == "brain" else int(Payouts.TRIPLE_SCORE.get(symbol_id, 0))
		var triple := floori(float(triple_base) * (1.0 + reward_bonus) + 0.5)
		var reward_amp_active := reward_amp_bonus > 0.0 and reward_amp_symbol == symbol_id
		var pair_color := REWARD_AMP_COLOR if reward_amp_active else GAIN_COLOR
		var triple_color := REWARD_AMP_COLOR if reward_amp_active else (
			BRAIN_COLOR if symbol_id == "brain" else GAIN_COLOR)
		_label_cell("+%d" % pair, PAIR_CX, row_cy, 12, pair_color)
		_label_cell("+%d" % triple, TRIPLE_CX, row_cy, 12, triple_color)
		if is_maxed:
			_label_right(_overlay, reward_bonus_text(
				float(RunStateStore.odds_max_level_reward_bonus)),
				INFO_X - 2.0, btn_y, 4, MAXED_COLOR)

		# Hold-to-peek info button (issue #119): the triple's special effect only
		# shows while the button is held (button_down/button_up also fire from
		# ui_accept, so keyboard/controller holds work the same as pointer holds).
		_info_buttons.append(_build_info_button(symbol_id, btn_y))
		# Hold-to-peek draw chance on the "i" under the LVL value (issue #153),
		# sharing the triple info button's row baseline.
		_pct_buttons.append(_build_pct_button(symbol_id, btn_y))

## BACK close button: a wide rounded rectangle centered in the bottom red band
## with the text in its middle. The text lives on a child Label: Button text
## inflates the minimum size well past the art-sized box (font metrics), which
## would bleed over the art's baked grid.
func _build_close_button() -> Button:
	var close := Button.new()
	close.name = "CloseButton"
	close.size = Vector2(56.0, 14.0)
	# Vertically centered in the bottom red band (canvas y ~287..308 between the
	# last row's grid line and the marquee bulbs).
	close.position = Vector2(SRC_W * 0.5 - close.size.x * 0.5, 290.0)
	var close_label := _view.score_label(close, "BACK", Vector2.ZERO, 9,
		NEON_GOLD, close.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	close_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# ANCHORED to the button rather than given a size. `close` is not in the scene tree at
	# this point, and a Label outside the tree measures its own minimum with the DEFAULT
	# 16px theme font — so the 56x14 assigned here was silently clamped up to 63x23, which
	# centred BACK on a box wider than its own plate and put it 3px right. The old -4px lift
	# was compensating for the height half of that same clamp. Anchors are recomputed from
	# the parent once the metrics settle, so the rect fixes itself when the button lands.
	close_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	var close_nudge := Assets.centered_text_nudge(9)
	close_label.offset_left = 0.0
	close_label.offset_top = close_nudge
	close_label.offset_right = 0.0
	close_label.offset_bottom = close_nudge
	close_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ButtonKit.small_neon_button_style(close, NEON_GOLD, 6, 2.0)
	# Pressed squash: shrink around the centre while held, spring back on release
	# (same feel as the row info buttons).
	close.pivot_offset = close.size * 0.5
	close.button_down.connect(func() -> void:
		var tw := _view.tween()
		tw.tween_property(close, "scale", Vector2(0.9, 0.9), 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	close.button_up.connect(func() -> void:
		if is_instance_valid(close):
			var tw := _view.tween()
			tw.tween_property(close, "scale", Vector2.ONE, 0.1) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	close.pressed.connect(close_table)
	_overlay.add_child(close)
	return close

## Vertical focus chain (close -> rows -> close, wrapping) so keyboard and
## controller navigation can reach every interactive element (issue #119).
func _wire_focus_chain(close: Button) -> void:
	var chain: Array[Button] = [close]
	# Interleave per row: the LVL column's pct peek, then the row's info button.
	for i in _info_buttons.size():
		if i < _pct_buttons.size():
			chain.append(_pct_buttons[i])
		chain.append(_info_buttons[i])
	for c in chain.size():
		var node := chain[c]
		var up := chain[(c - 1 + chain.size()) % chain.size()]
		var down := chain[(c + 1) % chain.size()]
		node.focus_neighbor_top = node.get_path_to(up)
		node.focus_neighbor_bottom = node.get_path_to(down)
		node.focus_next = node.get_path_to(down)
		node.focus_previous = node.get_path_to(up)
	close.grab_focus()

func close_table() -> void:
	hide_info_popup()
	_info_buttons.clear()
	_pct_buttons.clear()
	if _bulb_tween != null:
		_bulb_tween.kill()
		_bulb_tween = null
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null

## --- the marquee -----------------------------------------------------------------

## Warm additive glow behind every baked marquee bulb, chased in two alternating
## phases like a casino sign (issue #119 feedback). Drawn between the art and
## the value labels; the looping tween is killed on close.
func _spawn_bulb_glows() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.92, 0.45, 0.85))
	grad.set_color(1, Color(1.0, 0.82, 0.25, 0.0))
	var glow_tex := GradientTexture2D.new()
	glow_tex.gradient = grad
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(0.5, 0.0)
	glow_tex.width = 32
	glow_tex.height = 32
	var add_material := CanvasItemMaterial.new()
	add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var phases: Array[Control] = []
	for p in 2:
		var layer := Control.new()
		layer.name = "BulbGlowPhase%d" % p
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.add_child(layer)
		phases.append(layer)
	for i in BULBS.size():
		var glow := TextureRect.new()
		glow.texture = glow_tex
		glow.material = add_material
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_SCALE
		glow.size = Vector2.ONE * BULB_GLOW_SIZE
		glow.position = BULBS[i] - glow.size * 0.5
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		phases[i % 2].add_child(glow)

	phases[0].modulate.a = 1.0
	phases[1].modulate.a = 0.25
	_bulb_tween = _view.tween().set_loops()
	_bulb_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bulb_tween.set_parallel(true)
	_bulb_tween.tween_property(phases[0], "modulate:a", 0.25, 0.55)
	_bulb_tween.tween_property(phases[1], "modulate:a", 1.0, 0.55)
	_bulb_tween.chain().tween_property(phases[0], "modulate:a", 1.0, 0.55)
	_bulb_tween.parallel().tween_property(phases[1], "modulate:a", 0.25, 0.55)

## --- the row "i" buttons ---------------------------------------------------------

## The cropped "i" button from the information sheet (issue #119): the authored
## icon with a slightly larger invisible hit/focus box around it. Shared by the
## effect-info peek (row right edge) and the draw-chance peek (LVL column, #153).
func _make_i_button(node_name: String, icon_top_left: Vector2) -> Button:
	var b := Button.new()
	b.name = node_name
	b.position = icon_top_left - Vector2(3.0, 3.0)
	b.size = Vector2(INFO_W + 6.0, INFO_H + 6.0)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(0.0, 0.9, 1.0)
	focus.set_border_width_all(1)
	b.add_theme_stylebox_override("focus", focus)

	var atlas := AtlasTexture.new()
	atlas.atlas = _view.texture(INFO_ART, true)
	atlas.region = INFO_SRC
	var icon := TextureRect.new()
	icon.name = "InfoIcon"
	icon.texture = atlas
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.position = Vector2(3.0, 3.0)
	icon.size = Vector2(INFO_W, INFO_H)
	icon.pivot_offset = icon.size * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	_overlay.add_child(b)
	return b

func _build_info_button(symbol_id: String, art_y: float) -> Button:
	var b := _make_i_button("InfoButton_%s" % symbol_id, Vector2(INFO_X, art_y))
	var icon := b.get_node("InfoIcon") as TextureRect
	b.button_down.connect(_on_info_down.bind(symbol_id, b, icon))
	b.button_up.connect(_on_info_up.bind(icon))
	return b

## "i" under a row's LVL value (issue #153): while held, a bubble shows the
## symbol's live draw chance — the peek that used to sit on the baked symbol
## box, now matching the dealer odds table's under-the-meter info buttons.
## Sits on the same y as the row's triple-effect "i" so the pair reads aligned.
func _build_pct_button(symbol_id: String, art_y: float) -> Button:
	var b := _make_i_button("PctButton_%s" % symbol_id,
		Vector2(LVL_CX - INFO_W * 0.5, art_y))
	var icon := b.get_node("InfoIcon") as TextureRect
	b.button_down.connect(_on_pct_down.bind(symbol_id, b, icon))
	b.button_up.connect(_on_info_up.bind(icon))
	return b

func _on_pct_down(symbol_id: String, button: Button, icon: TextureRect) -> void:
	icon.scale = Vector2(0.7, 0.7)
	var tw := _view.tween()
	tw.tween_property(icon, "scale", Vector2(0.82, 0.82), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	show_pct_popup(symbol_id, button)

## Pressed state (issue #119): squash the "i" icon and pop up the triple-effect
## blurb next to the row for as long as the button is held.
func _on_info_down(symbol_id: String, button: Button, icon: TextureRect) -> void:
	icon.scale = Vector2(0.7, 0.7)
	var tw := _view.tween()
	tw.tween_property(icon, "scale", Vector2(0.82, 0.82), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	show_info_popup(symbol_id, button)

func _on_info_up(icon: TextureRect) -> void:
	if is_instance_valid(icon):
		var tw := _view.tween()
		tw.tween_property(icon, "scale", Vector2.ONE, 0.1) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hide_info_popup()

## --- the peek bubbles ------------------------------------------------------------

func show_pct_popup(symbol_id: String, button: Button) -> void:
	hide_info_popup()
	if _overlay == null:
		return
	_info_popup = Control.new()
	_info_popup.name = "PctPopup"
	_info_popup.z_index = 5
	_info_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color_v: Variant = PCT_COLORS.get(symbol_id, Color(0.0, 0.9, 1.0))
	var color: Color = color_v if color_v is Color else Color(0.0, 0.9, 1.0)
	var text := "%.1f%%" % symbol_draw_percent(symbol_id)
	var font := _font()
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x
	var popup_size := Vector2(maxf(text_width + 8.0, 24.0), 14.0)
	var bg_style := StyleBoxFlat.new()
	# Deep black body for flatline (same as the odds table's bubble) so the
	# dark-red contour and text stay legible.
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.97) if symbol_id == "flatline" \
		else Color(0.045, 0.035, 0.075, 0.97)
	bg_style.border_color = color
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(3)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.size = popup_size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_popup.add_child(bg)
	var label := Label.new()
	label.text = text
	# Inset from the TOP by twice the cap-height nudge: that moves the rect's centre — and
	# so the glyphs — down by one without letting the label hang past the bubble it belongs
	# to. Godot centres the font's ascent+descent box, and this percentage never uses the
	# descent, so it renders a pixel high without this.
	var nudge := Assets.centered_text_nudge(5)
	label.position = Vector2(0.0, nudge * 2.0)
	label.size = Vector2(popup_size.x, popup_size.y - nudge * 2.0)
	label.custom_minimum_size = Vector2.ZERO
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 5)
	var machine_font := _view.font()
	if machine_font != null:
		label.add_theme_font_override("font", machine_font)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	bg.add_child(label)
	# Re-asserted once the label is in the tree: out of the tree a Label measures its own
	# minimum with the default 16px theme font and the size above gets clamped up to it.
	label.set_deferred("size", Vector2(popup_size.x, popup_size.y - nudge * 2.0))
	# Right of the symbol box, vertically centered on the row.
	var pos := button.position + Vector2(button.size.x + 3.0,
		button.size.y * 0.5 - popup_size.y * 0.5)
	pos.x = clampf(pos.x, 2.0, SRC_W - popup_size.x - 2.0)
	pos.y = clampf(pos.y, 2.0, SRC_H - popup_size.y - 2.0)
	_info_popup.position = pos.round() # off-grid blurs the pixel font
	_overlay.add_child(_info_popup)

func show_info_popup(symbol_id: String, button: Button) -> void:
	hide_info_popup()
	if _overlay == null:
		return
	_info_popup = Control.new()
	_info_popup.name = "InfoPopup"
	_info_popup.z_index = 5
	_info_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Size from the actual font: Label.get_minimum_size() before the popup is in
	# the tree measures with the fallback theme font and comes out huge.
	# Already display text (the machine's blurb builder translates before it substitutes
	# its counts). It is measured below to size the panel, so what is measured and what the
	# per-line labels draw have to be this same string.
	var text: String = _triple_effect_text.call(symbol_id)
	var font := _font()
	var text_size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 5)
	# Center each line inside the bubble as its own label, positioned from the
	# font's measured line width: a single aligned Label can't do it because its
	# minimum size clamps to the theme font's metrics, not the small pixel font.
	var lines := text.split("\n")
	for li in lines.size():
		var line_w := font.get_string_size(lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x
		# Snap to whole pixels: a fractional offset knocks the pixel font off the
		# grid and blurs the glyphs.
		var line_x := roundf(4.0 + (text_size.x - line_w) * 0.5)
		# +nudge: these lines are top-aligned, so the gap the font's ascent leaves above the
		# caps is not matched at the bottom, and the blurb reads a pixel high without it.
		var line_y := 3.0 + Assets.centered_text_nudge(5) + float(li) * 10.0
		for seg in _info_line_segments.call(symbol_id, lines[li]):
			# Segments are FRAGMENTS of an already-translated line; letting each one
			# translate itself again would look up half a sentence as a key.
			var seg_label := _view.score_label(
				_info_popup, seg[0], Vector2(line_x, line_y), 5, seg[1])
			seg_label.auto_translate_mode = Control.AUTO_TRANSLATE_MODE_DISABLED
			line_x = roundf(line_x + font.get_string_size(seg[0],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x)
	# Rounded box: dark panel with a thin gold outline and soft corners.
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.045, 0.035, 0.075, 0.97)
	bg_style.border_color = Color(1.0, 0.82, 0.28)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(3)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", bg_style)
	# Height by line count: the Label's rendered line height exceeds the font's
	# measured extent, so metric-based heights clip multi-line blurbs.
	var line_count := text.split("\n").size()
	bg.size = Vector2(text_size.x + 8.0, float(line_count) * 10.0 + 4.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_popup.add_child(bg)
	_info_popup.move_child(bg, 0)
	# Anchored left of the held button, clamped onto the canvas.
	var pos := button.position + Vector2(-bg.size.x - 2.0, button.size.y * 0.5 - bg.size.y * 0.5)
	pos.x = clampf(pos.x, 2.0, SRC_W - bg.size.x - 2.0)
	pos.y = clampf(pos.y, 2.0, SRC_H - bg.size.y - 2.0)
	_info_popup.position = pos.round() # off-grid blurs the pixel font
	_overlay.add_child(_info_popup)

func hide_info_popup() -> void:
	if _info_popup != null:
		_info_popup.queue_free()
		_info_popup = null

func info_popup() -> Control:
	return _info_popup

## --- what the smoke checks and the shot scripts read ------------------------------

func info_buttons() -> Array[Button]:
	return _info_buttons

func pct_buttons() -> Array[Button]:
	return _pct_buttons

## --- the values the table quotes -------------------------------------------------

func reward_bonus_text(bonus: float) -> String:
	return "+%d%%" % int(round(bonus * 100.0))

## A symbol's current draw chance (percent) with all persisted levels applied —
## mirrors OddsTableOverlay._symbol_percent / Evaluate._build_weights.
func symbol_draw_percent(symbol_id: String) -> float:
	var total := 0.0
	var weight := 0.0
	for sym in Symbols.BASE_SYMBOL_CYCLE:
		var s := String(sym)
		# Symbol Level augments bought from the in-run dealer are live weights, so
		# the score table has to quote the level the reels roll on, not just the
		# permanent one (see RunStateStore.effective_symbol_level).
		var w := float(int(Symbols.WEIGHT[s])
			+ RunStateStore.effective_symbol_level(s)
				* RunStateStore.probability_increase_per_upgrade)
		total += w
		if s == symbol_id:
			weight = w
	return (weight / total) * 100.0 if total > 0.0 else 0.0

## --- label placement -------------------------------------------------------------
##
## Labels sized by their text and placed from the right edge / centre — the only
## reliable way to align DTM-Sans columns (min size = text width, no shrinking).

func _font() -> Font:
	var f := _view.font()
	return f if f != null else ThemeDB.fallback_font

func _label_right(parent: Control, text: String, right_x: float, y: float,
		font_size: int, color: Color) -> Label:
	var l := _view.score_label(parent, text, Vector2.ZERO, font_size, color)
	l.position = Vector2(right_x - l.get_minimum_size().x, y)
	return l

## A table value centered on its cell's midpoint (both axes), so numbers sit in
## the middle of the art's baked boxes (issue #119 feedback).
func _label_cell(text: String, center_x: float, center_y: float,
		font_size: int, color: Color) -> Label:
	var l := _view.score_label(_overlay, text, Vector2.ZERO, font_size, color)
	var min_size := l.get_minimum_size()
	l.position = Vector2(center_x - min_size.x * 0.5, center_y - min_size.y * 0.5)
	return l
