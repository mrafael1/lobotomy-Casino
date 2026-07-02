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
const TABLE_TOP := 78.0
const ROW_H := 26.0
const ICON_SIZE := 4.0   # 3x smaller than the previous odds table icons
const ICON_X := 22.0
const BAR_W := 6.0
const BAR_GAP := 2.0
const BAR_H := 10.0
const BARS_X := 60.0
const CONTROL_BTN := Vector2(9.0, 9.0)

@export_group("Odds Table Colors")
@export var title_color: Color = Color(1.0, 0.82, 0.28)
@export var header_color: Color = Color(0.0, 0.9, 1.0)
@export var effect_color: Color = Color(0.58, 0.64, 0.72)
@export var token_color: Color = Color(0.92, 0.86, 0.56)
@export var bar_fill_color: Color = Color(1.0, 0.86, 0.2)
@export var bar_empty_color: Color = Color(0.2, 0.2, 0.28)

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
	var icon := TextureRect.new()
	icon.texture = Assets.texture("symbols/%s.png" % symbol_id, true)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.position = Vector2(ICON_X, y + (ROW_H - ICON_SIZE) * 0.5 - 3.0)
	icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)

	# 5 vertical level bars, one filled yellow per permanent upgrade.
	var max_level := maxi(1, RunStateStore.odds_max_level)
	var bars: Array = []
	for i in max_level:
		var bar := ColorRect.new()
		bar.position = Vector2(BARS_X + float(i) * (BAR_W + BAR_GAP), y)
		bar.size = Vector2(BAR_W, BAR_H)
		bar.color = bar_empty_color
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		bars.append(bar)
	_level_bars[symbol_id] = bars

	# -/+ controls under the bars, with the token cost between them (plain number).
	var bars_w := _bars_width()
	var controls_y := y + BAR_H + 2.0
	var minus := _control_button("-", Vector2(BARS_X, controls_y))
	minus.pressed.connect(_on_minus_pressed.bind(symbol_id))
	_minus_buttons[symbol_id] = minus
	_mk_label(self, str(RunStateStore.odds_token_cost(symbol_id)), Vector2(BARS_X + CONTROL_BTN.x, controls_y), 6,
		token_color, bars_w - CONTROL_BTN.x * 2.0, HORIZONTAL_ALIGNMENT_CENTER)
	var plus := _control_button("+", Vector2(BARS_X + bars_w - CONTROL_BTN.x, controls_y))
	plus.pressed.connect(_on_plus_pressed.bind(symbol_id))
	_plus_buttons[symbol_id] = plus

func _control_button(text: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = CONTROL_BTN
	b.add_theme_font_size_override("font_size", 7)
	if _font != null:
		b.add_theme_font_override("font", _font)
	add_child(b)
	return b

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
		var minus := _minus_buttons.get(symbol_id) as Button
		if minus != null:
			minus.disabled = int(RunStateStore.oddsPendingUpgrades.get(symbol_id, 0)) <= 0
