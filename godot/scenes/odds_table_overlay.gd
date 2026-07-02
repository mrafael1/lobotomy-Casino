class_name OddsTableOverlay
extends Control

## Dealer odds table (issue #36) — the post-run "what's next?" phase. Lists every
## reel-cycle symbol with its PAIR/TRIPLE payout and triple effect, and lets the
## player spend the per-run token budget on additive weight bumps for the NEXT run.
## All purchases go through RunStateStore.buy_odds_upgrade(), so the parity-locked
## base weights in Symbols are never touched (see Evaluate._build_weights).

signal closed

const SRC_W := 160.0
const SRC_H := 320.0
const PANEL_RECT := Rect2(6.0, 22.0, 148.0, 272.0)
const TABLE_TOP := 78.0
const ROW_H := 26.0

@export_group("Odds Table Copy")
## Short triple-effect blurbs shown under each symbol name (display only).
@export var effect_text: Dictionary = {
	"brain": "3X JACKPOT +FREE",
	"eye": "3X REVEALS A REEL",
	"pill": "3X POWERS BACK",
	"syringe": "3X ITEM BACK",
	"vial": "3X FREE SPINS",
	"flatline": "3X KILLS YOU",
}

@export_group("Odds Table Colors")
@export var title_color: Color = Color(1.0, 0.82, 0.28)
@export var header_color: Color = Color(0.0, 0.9, 1.0)
@export var name_color: Color = Color(0.86, 0.9, 0.96)
@export var effect_color: Color = Color(0.58, 0.64, 0.72)
@export var score_color: Color = Color(0.75, 1.0, 0.8)
@export var token_color: Color = Color(0.92, 0.86, 0.56)
@export var bump_color: Color = Color(0.55, 1.0, 0.6)

var _font: FontFile = null
var _tokens_label: Label = null
var _buy_buttons := {}   # symbol -> Button
var _bump_labels := {}   # symbol -> Label ("+N" purchased bumps)

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

## Re-opens the table mid-phase WITHOUT re-granting tokens (keeps purchases).
func reopen_overlay() -> void:
	_rebuild()
	visible = true

func _close() -> void:
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
	_buy_buttons.clear()
	_bump_labels.clear()

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
	_mk_label(self, "A SYMBOL'S ODDS NEXT RUN", Vector2(14.0, 56.0), 6, effect_color)

	_mk_label(self, "SYMBOL", Vector2(14.0, TABLE_TOP - 10.0), 6, header_color)
	_mk_label(self, "PAIR", Vector2(70.0, TABLE_TOP - 10.0), 6, header_color, 20.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_mk_label(self, "3X", Vector2(94.0, TABLE_TOP - 10.0), 6, header_color, 20.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_mk_label(self, "BUY", Vector2(122.0, TABLE_TOP - 10.0), 6, header_color, 26.0, HORIZONTAL_ALIGNMENT_CENTER)

	var y := TABLE_TOP
	for sym in Symbols.BASE_SYMBOL_CYCLE:
		_build_row(String(sym), y)
		y += ROW_H

	_mk_label(self, "BRAIN 3X = JACKPOT", Vector2(14.0, y + 2.0), 6, effect_color)

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

func _build_row(symbol_id: String, y: float) -> void:
	var icon := TextureRect.new()
	icon.texture = Assets.texture("symbols/%s.png" % symbol_id, true)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.position = Vector2(12.0, y - 1.0)
	icon.size = Vector2(16.0, 16.0)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)

	_mk_label(self, symbol_id.to_upper(), Vector2(31.0, y), 7, name_color)
	_bump_labels[symbol_id] = _mk_label(self, "", Vector2(31.0, y), 7, bump_color, 36.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_mk_label(self, String(effect_text.get(symbol_id, "")), Vector2(31.0, y + 10.0), 5, effect_color)

	var pair := int(Payouts.PAIR_SCORE.get(symbol_id, 0))
	var triple := Payouts.JACKPOT_SCORE if symbol_id == "brain" else int(Payouts.TRIPLE_SCORE.get(symbol_id, 0))
	_mk_label(self, "+%d" % pair, Vector2(70.0, y), 7, score_color, 20.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_mk_label(self, "+%d" % triple, Vector2(94.0, y), 7,
		Color(1.0, 0.33, 0.58) if symbol_id == "brain" else score_color, 20.0, HORIZONTAL_ALIGNMENT_RIGHT)

	var buy := Button.new()
	buy.text = "%dt" % RunStateStore.odds_token_cost(symbol_id)
	buy.position = Vector2(124.0, y - 1.0)
	buy.size = Vector2(22.0, 14.0)
	buy.add_theme_font_size_override("font_size", 7)
	if _font != null:
		buy.add_theme_font_override("font", _font)
	buy.pressed.connect(_on_buy_pressed.bind(symbol_id))
	add_child(buy)
	_buy_buttons[symbol_id] = buy

func _on_buy_pressed(symbol_id: String) -> void:
	if RunStateStore.buy_odds_upgrade(symbol_id):
		_refresh()

func _refresh() -> void:
	if _tokens_label != null:
		_tokens_label.text = "%d/%d TOKENS" % [RunStateStore.oddsTokensRemaining, RunStateStore.odds_budget]
	for symbol_id in _buy_buttons:
		var buy: Button = _buy_buttons[symbol_id]
		buy.disabled = RunStateStore.odds_token_cost(String(symbol_id)) > RunStateStore.oddsTokensRemaining
	for symbol_id in _bump_labels:
		var bumps := int(RunStateStore.oddsWeightOverrides.get(symbol_id, 0))
		(_bump_labels[symbol_id] as Label).text = "+%d" % bumps if bumps > 0 else ""
