class_name OddsTableOverlay
extends Control

## Dealer odds table (issue #36) — the post-run "what's next?" phase. One compact
## "SYMBOL | LVL" row per reel-cycle symbol: a small icon, five vertical level bars
## that fill yellow per PERMANENT upgrade (max 5), and -/+ controls with the token
## cost between them. Purchases are staged and undoable (-/+) while the screen is
## open; DONE commits them through RunStateStore.finalize_odds_phase() and locks
## the screen until the next run. All purchases go through RunStateStore, so the
## parity-locked base weights in Symbols are never touched
## (see Evaluate._build_weights).

signal closed

const SRC_W := 160.0
const SRC_H := 320.0
const PANEL_RECT := Rect2(6.0, 22.0, 148.0, 272.0)
const TABLE_TOP := 80.0
const ROW_H := 26.0
const SYMBOL_BOX := Rect2(14.0, 0.0, 24.0, 24.0)
const SYMBOL_BOX_COLOR := Color(0.085, 0.105, 0.16, 0.95)
const ICON_SIZE := 14.0
# Video-game stat-upgrade row: [ - ]  ▮▮▮▯▯  [ + ] — big square buttons flanking
# the five level bars, cost centered underneath.
const BAR_W := 5.0
const BAR_GAP := 2.0
const BAR_H := 12.0
const BARS_X := 64.0
const CONTROL_MINUS_X := 44.0
const CONTROL_PLUS_X := 101.0
const CONTROL_BTN := Vector2(16.0, 16.0)
const GLYPH_LEN := 8.0
const GLYPH_THICK := 2.0

@export_group("Odds Table Colors")
@export var title_color: Color = Color(1.0, 0.82, 0.28)
@export var header_color: Color = Color(0.0, 0.9, 1.0)
@export var effect_color: Color = Color(0.58, 0.64, 0.72)
@export var token_color: Color = Color(0.92, 0.86, 0.56)
@export var bar_fill_color: Color = Color(1.0, 0.86, 0.2)
@export var bar_empty_color: Color = Color(0.2, 0.2, 0.28)
@export var minus_color: Color = Color(0.94, 0.27, 0.27)
@export var plus_color: Color = Color(0.13, 0.77, 0.37)

var _font: FontFile = null
var _tokens_label: Label = null
var _plus_buttons := {}   # symbol -> Button
var _minus_buttons := {}  # symbol -> Button
var _level_bars := {}     # symbol -> Array[ColorRect] (5 vertical bars)

func _ready() -> void:
	_font = Assets.font()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	z_index = 140
	mouse_filter = Control.MOUSE_FILTER_STOP

## Opens the phase: grants the fresh token budget, then builds the table.
func open_overlay() -> void:
	RunStateStore.begin_odds_phase()
	_rebuild()
	visible = true

func _close() -> void:
	# Closing finalizes: staged purchases become permanent and the screen locks
	# until the next run.
	RunStateStore.finalize_odds_phase()
	visible = false
	closed.emit()

func _mk_label(parent: Control, text: String, pos: Vector2, font_size: int, color: Color,
		width := 0.0, halign := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	if width > 0.0:
		l.size = Vector2(width, float(font_size) + 4.0)
	l.horizontal_alignment = halign
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_plus_buttons.clear()
	_minus_buttons.clear()
	_level_bars.clear()

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	dim.size = Vector2(SRC_W, SRC_H)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := ColorRect.new()
	panel.color = Color(0.045, 0.035, 0.075, 0.96)
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	_mk_label(self, "THE ODDS", Vector2(14.0, 30.0), 12, title_color)
	_tokens_label = _mk_label(self, "", Vector2(90.0, 33.0), 8, token_color, 58.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_mk_label(self, "SPEND TOKENS TO RAISE", Vector2(14.0, 48.0), 6, effect_color)
	_mk_label(self, "A SYMBOL'S ODDS FOR GOOD", Vector2(14.0, 56.0), 6, effect_color)

	var bars_w := _bars_width()
	_mk_label(self, "SYMBOL", Vector2(14.0, TABLE_TOP - 10.0), 6, header_color)
	_mk_label(self, "LVL", Vector2(BARS_X, TABLE_TOP - 10.0), 6, header_color, bars_w, HORIZONTAL_ALIGNMENT_CENTER)

	var y := TABLE_TOP
	for sym in Symbols.BASE_SYMBOL_CYCLE:
		_build_row(String(sym), y)
		y += ROW_H

	var done := Button.new()
	done.text = "DONE"
	done.position = Vector2(50.0, y + 14.0)
	done.size = Vector2(60.0, 16.0)
	done.add_theme_font_size_override("font_size", 7)
	if _font != null:
		done.add_theme_font_override("font", _font)
	Assets.skin_negative_button(done)
	done.pressed.connect(_close)
	add_child(done)

	_refresh()

func _bars_width() -> float:
	var max_level := maxi(1, RunStateStore.odds_max_level)
	return float(max_level) * BAR_W + float(max_level - 1) * BAR_GAP

## One compact "SYMBOL | LVL" row: small icon, five level bars, -/+ with the cost
## between them. No names, no payout columns.
func _build_row(symbol_id: String, y: float) -> void:
	var box := ColorRect.new()
	box.color = SYMBOL_BOX_COLOR
	box.position = Vector2(SYMBOL_BOX.position.x, y + SYMBOL_BOX.position.y)
	box.size = SYMBOL_BOX.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_add_symbol_icon(symbol_id, box.position + box.size * 0.5)

	# 5 vertical level bars, one filled yellow per permanent upgrade, flanked by
	# the big -/+ buttons (stat-upgrade style); the cost sits centered below.
	var max_level := maxi(1, RunStateStore.odds_max_level)
	var bars: Array = []
	var bars_y := y + 3.0
	for i in max_level:
		var bar := ColorRect.new()
		bar.position = Vector2(BARS_X + float(i) * (BAR_W + BAR_GAP), bars_y)
		bar.size = Vector2(BAR_W, BAR_H)
		bar.color = bar_empty_color
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.z_index = 1
		add_child(bar)
		bars.append(bar)
	_level_bars[symbol_id] = bars

	# Buttons vertically centered on the bars; the cost is centered below them.
	var controls_y := bars_y + BAR_H * 0.5 - CONTROL_BTN.y * 0.5
	var minus := _control_button("minus", Vector2(CONTROL_MINUS_X, controls_y))
	minus.pressed.connect(_on_minus_pressed.bind(symbol_id))
	_minus_buttons[symbol_id] = minus
	var bars_w := _bars_width()
	var cost := _mk_label(self, str(RunStateStore.odds_token_cost(symbol_id)),
		Vector2(BARS_X, bars_y + BAR_H + 2.0), 6, token_color, bars_w,
		HORIZONTAL_ALIGNMENT_CENTER)
	cost.z_index = 2
	var plus := _control_button("plus", Vector2(CONTROL_PLUS_X, controls_y))
	plus.pressed.connect(_on_plus_pressed.bind(symbol_id))
	_plus_buttons[symbol_id] = plus

func _add_symbol_icon(symbol_id: String, center: Vector2) -> void:
	var tex := Assets.texture("symbols/%s.png" % symbol_id, true)
	if tex == null:
		return
	var icon := Sprite2D.new()
	icon.texture = tex
	icon.centered = true
	icon.position = center
	icon.scale = Vector2.ONE * (ICON_SIZE / float(maxi(tex.get_width(), tex.get_height())))
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.z_index = 2
	add_child(icon)

## Big boxed stat-upgrade button. `kind` is "minus" (red) or "plus" (green); the
## glyph is drawn from ColorRects so it stays chunky and pixel-crisp at any size.
func _control_button(kind: String, pos: Vector2) -> Button:
	var accent := minus_color if kind == "minus" else plus_color
	var b := Button.new()
	b.position = pos
	b.size = CONTROL_BTN
	b.custom_minimum_size = CONTROL_BTN
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.z_index = 3

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.09, 0.17)
	normal.border_color = accent
	normal.set_border_width_all(1)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.17, 0.14, 0.25)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.darkened(0.55)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.09, 0.08, 0.13)
	disabled.border_color = Color(0.3, 0.3, 0.38)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	# Drawn glyph: a fat horizontal bar, plus a vertical one for "+".
	var glyph_h := ColorRect.new()
	glyph_h.name = "GlyphH"
	glyph_h.color = accent
	glyph_h.position = (CONTROL_BTN - Vector2(GLYPH_LEN, GLYPH_THICK)) * 0.5
	glyph_h.size = Vector2(GLYPH_LEN, GLYPH_THICK)
	glyph_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(glyph_h)
	if kind == "plus":
		var glyph_v := ColorRect.new()
		glyph_v.name = "GlyphV"
		glyph_v.color = accent
		glyph_v.position = (CONTROL_BTN - Vector2(GLYPH_THICK, GLYPH_LEN)) * 0.5
		glyph_v.size = Vector2(GLYPH_THICK, GLYPH_LEN)
		glyph_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(glyph_v)
	add_child(b)
	return b

## Dims a control button's drawn glyph to match its disabled state.
func _sync_control_glyphs(b: Button) -> void:
	if b == null:
		return
	var alpha := 0.35 if b.disabled else 1.0
	for child in b.get_children():
		if child is ColorRect:
			(child as ColorRect).modulate = Color(1.0, 1.0, 1.0, alpha)

func _on_plus_pressed(symbol_id: String) -> void:
	if RunStateStore.buy_odds_upgrade(symbol_id):
		_refresh()

func _on_minus_pressed(symbol_id: String) -> void:
	if RunStateStore.undo_odds_upgrade(symbol_id):
		_refresh()

func _refresh() -> void:
	if _tokens_label != null:
		_tokens_label.text = "%d/%d TOKENS" % [RunStateStore.oddsTokensRemaining, RunStateStore.odds_budget]
	for symbol_id in _level_bars:
		var level := RunStateStore.odds_upgrade_level(String(symbol_id))
		var bars: Array = _level_bars[symbol_id]
		for i in bars.size():
			(bars[i] as ColorRect).color = bar_fill_color if i < level else bar_empty_color
		var plus := _plus_buttons.get(symbol_id) as Button
		if plus != null:
			plus.disabled = level >= RunStateStore.odds_max_level \
				or RunStateStore.odds_token_cost(String(symbol_id)) > RunStateStore.oddsTokensRemaining
			_sync_control_glyphs(plus)
		var minus := _minus_buttons.get(symbol_id) as Button
		if minus != null:
			minus.disabled = int(RunStateStore.oddsPendingUpgrades.get(symbol_id, 0)) <= 0
			_sync_control_glyphs(minus)
