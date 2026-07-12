class_name OddsTableOverlay
extends Control

## Dealer odds table (issues #36/#50/#130) — the post-run "what's next?" phase.
## Issue #130 rebuilt the screen on the authored ODD-TABLE sheets (x6 full-canvas
## frames): the table background bakes the per-row symbol boxes and token costs,
## ODD-TABLE_tokens shows the wallet count (digit + chip stack) in the header,
## ODD-TABLE_levels renders each row's 8-segment level meter, and
## ODD-TABLE_buttons carries the per-row +/- buttons with pressed frames.
## Tokens display via the sheet's 0..8 frames: the pool starts at the 4-token
## budget and is capped at 8 kept or used (RunStateStore.odds_max_tokens).
## Purchases are staged and undoable (-/+) while the screen is open; DONE commits
## them through RunStateStore.finalize_odds_phase() and locks the screen until the
## next run. All purchases go through RunStateStore, so the parity-locked base
## weights in Symbols are never touched (see Evaluate._build_weights).

signal closed

const SRC_W := 160.0
const SRC_H := 320.0

# Authored sheets (issue #130): x6 full-canvas frames, 960x1920 each.
const ART_DIR := "odd_tab/"
const ART_TABLE := "ODD-TABLE.png"
const ART_BUTTONS := "ODD-TABLE_buttons.png"
const ART_LEVELS := "ODD-TABLE_levels.png"
const ART_TOKENS := "ODD-TABLE_tokens.png"
const ART_SCALE := 6.0
const ART_FRAME_W := 960.0
const TOKEN_FRAMES := 9  # frame N = N tokens, 0..8

# Measured opaque bounds of the sheets (image px, frame 0). The authored sheets
# tighten the pitch after the third row, so keeping these offsets explicit avoids
# cutting into the syringe, vial, and flatline art.
const ROW_OFFSETS_IMG := [0.0, 256.0, 512.0, 760.0, 1008.0, 1256.0]
const BTN_PLUS_IMG := Rect2(656.0, 360.0, 152.0, 80.0)
const BTN_MINUS_Y_OFFSET_IMG := 88.0
const LEVEL_ROW_IMG := Rect2(344.0, 408.0, 264.0, 104.0)
const LEVEL_LAST_ROW_IMG := Rect2(336.0, 1664.0, 264.0, 104.0)
# Lift the authored table slightly so the final row and the DONE action have
# breathing room on the compact canvas. The dimmer remains full-screen.
const TABLE_Y_OFFSET := -8.0
# The outer light-blue frame receives a narrow halo, leaving the pixel art
# itself as the crisp neon core without washing the scene in broad light.
const NEON_FRAME_RECT := Rect2(8.0, 20.0, 144.0, 299.0)
const SYMBOL_HIT_SIZE := Vector2(32.0, 32.0)
const NEON_FRAME_COLOR := Color("#64b5de")
const NEON_PULSE_LOW := 0.42
const NEON_PULSE_HIGH := 0.78
const NEON_PULSE_TIME := 0.9
# Symbol box baked into the table art (source px): the selected symbol renders
# inside it, scaled down slightly so it clears the box outline.
const SYMBOL_BOX_CENTER := Vector2(37.3, 73.3)
const ODD_ICON_SIZE := 24.0
const DONE_BUTTON_SIZE := Vector2(32.0, 8.0)
const DONE_BUTTON_Y := NEON_FRAME_RECT.position.y + NEON_FRAME_RECT.size.y \
	+ TABLE_Y_OFFSET - DONE_BUTTON_SIZE.y * 0.5

# These are the opaque row colors in ODD-TABLE.png. Flatline has no colored
# border, so its waveform red is used for the live percentage.
const SYMBOL_PERCENT_COLORS := {
	"brain": Color("#e86a73"),
	"eye": Color("#ce3dde"),
	"pill": Color("#e3e6ff"),
	"syringe": Color("#f9a31b"),
	"vial": Color("#b4202a"),
	"flatline": Color("#8f0d16"),
}

@export_group("Odds Table Colors")
@export var percent_color: Color = Color(0.0, 0.9, 1.0)

var _font: FontFile = null
var _tokens_sprite: Sprite2D = null
var _plus_buttons := {}     # symbol -> Button (invisible hit area over the art)
var _minus_buttons := {}    # symbol -> Button
var _symbol_buttons := {}   # symbol -> Button (pressable symbol box)
var _symbol_icons := {}     # symbol -> Sprite2D
var _plus_art := {}         # symbol -> Sprite2D (region of the buttons sheet)
var _minus_art := {}        # symbol -> Sprite2D
var _level_sprites := {}    # symbol -> Sprite2D (region of the levels sheet)
var _pct_popup: Control = null
var _neon_glow_layer: Control = null
var _neon_glow_tween: Tween = null

func _ready() -> void:
	_font = Assets.font()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	z_index = 140
	mouse_filter = Control.MOUSE_FILTER_STOP

## Opens the phase: grants banked + fresh tokens (capped at 8), then builds the table.
func open_overlay() -> void:
	RunStateStore.begin_odds_phase()
	_rebuild()
	visible = true

func _close() -> void:
	# Closing finalizes: staged purchases become permanent, leftover tokens are
	# banked for the next odds menu, and the screen locks until the next run.
	_hide_pct_popup()
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
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 1)
	parent.add_child(l)
	return l

## Adds a restrained halo behind the authored modal frame. The panel border sits
## over the art while its shadow spreads only a few source pixels outside it.
func _spawn_neon_glows() -> void:
	var layer := Control.new()
	layer.name = "NeonGlow"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 1
	layer.modulate.a = NEON_PULSE_HIGH
	add_child(layer)
	_neon_glow_layer = layer

	_add_neon_outline(layer, Rect2(NEON_FRAME_RECT.position + Vector2(0.0, TABLE_Y_OFFSET),
		NEON_FRAME_RECT.size), NEON_FRAME_COLOR)

	_neon_glow_tween = create_tween().set_loops()
	_neon_glow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_neon_glow_tween.tween_property(layer, "modulate:a", NEON_PULSE_LOW, NEON_PULSE_TIME)
	_neon_glow_tween.tween_property(layer, "modulate:a", NEON_PULSE_HIGH, NEON_PULSE_TIME)

func _add_neon_outline(parent: Control, rect: Rect2, color: Color) -> void:
	var points := PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		rect.position + Vector2(0.0, rect.size.y),
	])
	var halo := Line2D.new()
	halo.name = "NeonHalo"
	halo.points = points
	halo.closed = true
	halo.width = 3.0
	halo.default_color = Color(color.r, color.g, color.b, 0.24)
	halo.antialiased = false
	parent.add_child(halo)
	var core := Line2D.new()
	core.name = "NeonCore"
	core.points = points
	core.closed = true
	core.width = 1.0
	core.default_color = Color(color.r, color.g, color.b, 0.82)
	core.antialiased = false
	parent.add_child(core)

## Full-canvas sheet sprite (dealer-scene pattern): scaled so one frame covers
## the 160x320 canvas exactly.
func _sheet_sprite(rel: String, hframes: int, frame: int) -> Sprite2D:
	var tex := Assets.texture(ART_DIR + rel, true)
	if tex == null:
		return null
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.hframes = hframes
	spr.frame = frame
	spr.centered = false
	spr.position = Vector2(0.0, TABLE_Y_OFFSET)
	var frame_w := float(tex.get_width()) / float(hframes)
	spr.scale = Vector2(SRC_W / frame_w, SRC_H / float(tex.get_height()))
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(spr)
	return spr

## Region sprite cropping `rect_img` (frame-0 image px) out of a sheet; `frame`
## selects that frame's copy of the same rect. Placed at the source-px position.
func _region_sprite(rel: String, rect_img: Rect2, frame: int) -> Sprite2D:
	var tex := Assets.texture(ART_DIR + rel, true)
	if tex == null:
		return null
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.region_enabled = true
	spr.region_rect = Rect2(rect_img.position + Vector2(ART_FRAME_W * float(frame), 0.0), rect_img.size)
	spr.position = rect_img.position / ART_SCALE + Vector2(0.0, TABLE_Y_OFFSET)
	spr.scale = Vector2.ONE / ART_SCALE
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(spr)
	return spr

## Points a region sprite at another frame's copy of its rect.
func _set_region_frame(spr: Sprite2D, base_x_img: float, frame: int) -> void:
	if spr == null:
		return
	var r := spr.region_rect
	r.position.x = base_x_img + ART_FRAME_W * float(frame)
	spr.region_rect = r

func _rebuild() -> void:
	if _neon_glow_tween != null and _neon_glow_tween.is_valid():
		_neon_glow_tween.kill()
	_neon_glow_tween = null
	_neon_glow_layer = null
	_hide_pct_popup()
	for child in get_children():
		child.queue_free()
	_plus_buttons.clear()
	_minus_buttons.clear()
	_symbol_buttons.clear()
	_symbol_icons.clear()
	_plus_art.clear()
	_minus_art.clear()
	_level_sprites.clear()

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	dim.size = Vector2(SRC_W, SRC_H)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_spawn_neon_glows()
	_sheet_sprite(ART_TABLE, 1, 0)
	_tokens_sprite = _sheet_sprite(ART_TOKENS, TOKEN_FRAMES, 0)

	for i in Symbols.BASE_SYMBOL_CYCLE.size():
		_build_row(String(Symbols.BASE_SYMBOL_CYCLE[i]), i)

	var done := Button.new()
	done.text = "DONE"
	done.position = Vector2((SRC_W - DONE_BUTTON_SIZE.x) * 0.5, DONE_BUTTON_Y)
	done.z_index = 4
	done.add_theme_font_size_override("font_size", 4)
	if _font != null:
		done.add_theme_font_override("font", _font)
	done.add_theme_color_override("font_color", Color.WHITE)
	done.add_theme_color_override("font_hover_color", Color.WHITE)
	done.add_theme_color_override("font_pressed_color", Color.WHITE)
	var done_style := StyleBoxFlat.new()
	done_style.bg_color = Color("#b4202a")
	done_style.border_color = Color("#e86a73")
	done_style.set_border_width_all(1)
	done_style.set_corner_radius_all(1)
	var done_hover := done_style.duplicate() as StyleBoxFlat
	done_hover.bg_color = Color("#d3414d")
	var done_pressed := done_style.duplicate() as StyleBoxFlat
	done_pressed.bg_color = Color("#73172d")
	done.add_theme_stylebox_override(&"normal", done_style)
	done.add_theme_stylebox_override(&"hover", done_hover)
	done.add_theme_stylebox_override(&"pressed", done_pressed)
	done.add_theme_stylebox_override(&"focus", done_hover)
	done.custom_minimum_size = Vector2.ZERO
	done.pressed.connect(_close)
	add_child(done)
	done.size = DONE_BUTTON_SIZE

	_refresh()

## One authored row: the pressable symbol inside the baked box, the level-meter
## region, and invisible hit buttons over the baked +/- art.
func _build_row(symbol_id: String, row: int) -> void:
	var row_offset_img: float = float(ROW_OFFSETS_IMG[row])

	var icon := _add_symbol_icon(symbol_id, SYMBOL_BOX_CENTER + Vector2(0.0,
		row_offset_img / ART_SCALE + TABLE_Y_OFFSET))
	_symbol_icons[symbol_id] = icon
	_symbol_buttons[symbol_id] = _build_symbol_button(symbol_id, row_offset_img, icon)

	var level_rect := LEVEL_LAST_ROW_IMG if row == Symbols.BASE_SYMBOL_CYCLE.size() - 1 \
		else Rect2(LEVEL_ROW_IMG.position + Vector2(0.0, row_offset_img), LEVEL_ROW_IMG.size)
	_level_sprites[symbol_id] = _region_sprite(ART_LEVELS, level_rect, 0)

	var plus_rect := Rect2(BTN_PLUS_IMG.position + Vector2(0.0, row_offset_img), BTN_PLUS_IMG.size)
	var minus_rect := Rect2(plus_rect.position + Vector2(0.0, BTN_MINUS_Y_OFFSET_IMG), plus_rect.size)
	_plus_art[symbol_id] = _region_sprite(ART_BUTTONS, plus_rect, 0)
	_minus_art[symbol_id] = _region_sprite(ART_BUTTONS, minus_rect, 0)
	# The buttons sheet: frame 0 default, frame 1 "+" pressed, frame 2 "-" pressed.
	_plus_buttons[symbol_id] = _hit_button(plus_rect, symbol_id, true)
	_minus_buttons[symbol_id] = _hit_button(minus_rect, symbol_id, false)

func _add_symbol_icon(symbol_id: String, center: Vector2) -> Sprite2D:
	var tex := Assets.texture("symbols/%s.png" % symbol_id, true)
	if tex == null:
		return null
	var icon := Sprite2D.new()
	icon.texture = tex
	icon.centered = true
	icon.position = center
	# Scaled down slightly so the symbol fits cleanly inside the baked box (#130).
	icon.scale = Vector2.ONE * (ODD_ICON_SIZE / float(maxi(tex.get_width(), tex.get_height())))
	icon.set_meta("rest_scale", icon.scale)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.z_index = 2
	add_child(icon)
	return icon

## Invisible hit area over a symbol box. Holding it uses the same squash-and-pop
## interaction as the score-table information buttons, while the popup reports
## the current staged draw chance for that symbol.
func _build_symbol_button(symbol_id: String, row_offset_img: float, icon: Sprite2D) -> Button:
	var b := Button.new()
	b.name = "SymbolButton_%s" % symbol_id
	b.position = SYMBOL_BOX_CENTER - SYMBOL_HIT_SIZE * 0.5 + Vector2(0.0,
		row_offset_img / ART_SCALE + TABLE_Y_OFFSET)
	b.size = SYMBOL_HIT_SIZE
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.z_index = 3
	for state in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.button_down.connect(_on_symbol_button_down.bind(symbol_id, b, icon))
	b.button_up.connect(_on_symbol_button_up.bind(icon))
	add_child(b)
	return b

## Invisible hit button over a baked button's art; pressing swaps the art region
## to the sheet's pressed frame for tactile feedback.
func _hit_button(rect_img: Rect2, symbol_id: String, is_plus: bool) -> Button:
	var b := Button.new()
	b.position = rect_img.position / ART_SCALE + Vector2(0.0, TABLE_Y_OFFSET)
	b.size = rect_img.size / ART_SCALE
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.z_index = 3
	for state in [&"normal", &"pressed", &"hover", &"disabled", &"focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var art: Sprite2D = _plus_art[symbol_id] if is_plus else _minus_art[symbol_id]
	var pressed_frame := 1 if is_plus else 2
	var base_x := rect_img.position.x
	b.button_down.connect(_set_region_frame.bind(art, base_x, pressed_frame))
	b.button_up.connect(_set_region_frame.bind(art, base_x, 0))
	if is_plus:
		b.pressed.connect(_on_plus_pressed.bind(symbol_id))
	else:
		b.pressed.connect(_on_minus_pressed.bind(symbol_id))
	add_child(b)
	return b

func _on_symbol_button_down(symbol_id: String, button: Button, icon: Sprite2D) -> void:
	if icon != null:
		var rest_scale: Vector2 = icon.get_meta("rest_scale", Vector2.ONE)
		icon.scale = rest_scale * 0.7
		var tw := create_tween()
		var scale_tween := tw.tween_property(icon, "scale", rest_scale * 0.82, 0.08)
		scale_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_show_pct_popup(symbol_id, button)

func _on_symbol_button_up(icon: Sprite2D) -> void:
	if is_instance_valid(icon):
		var rest_scale: Vector2 = icon.get_meta("rest_scale", Vector2.ONE)
		var tw := create_tween()
		var scale_tween := tw.tween_property(icon, "scale", rest_scale, 0.1)
		scale_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hide_pct_popup()

func _show_pct_popup(symbol_id: String, button: Button) -> void:
	_hide_pct_popup()
	_pct_popup = Control.new()
	_pct_popup.name = "PctPopup"
	_pct_popup.z_index = 5
	_pct_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := "%.1f%%" % _symbol_percent(symbol_id)
	var font: Font = _font if _font != null else ThemeDB.fallback_font
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x
	var popup_size := Vector2(text_width + 8.0, 14.0)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.045, 0.035, 0.075, 0.97)
	bg_style.border_color = Color(1.0, 0.82, 0.28)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(3)
	var bg := Panel.new()
	bg.name = "PctBubble"
	bg.add_theme_stylebox_override(&"panel", bg_style)
	bg.size = popup_size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pct_popup.add_child(bg)
	var label := _mk_label(bg, text, Vector2(4.0, 2.0), 5, _percent_color(symbol_id),
		text_width, HORIZONTAL_ALIGNMENT_CENTER)
	label.name = "PctLabel"
	label.z_index = 1
	_pct_popup.size = popup_size
	var pos := button.position + Vector2(button.size.x * 0.5 - popup_size.x * 0.5,
		-popup_size.y - 3.0)
	pos.x = clampf(pos.x, 2.0, SRC_W - popup_size.x - 2.0)
	pos.y = clampf(pos.y, 2.0, SRC_H - popup_size.y - 2.0)
	_pct_popup.position = pos.round()
	add_child(_pct_popup)

func _hide_pct_popup() -> void:
	if _pct_popup != null:
		_pct_popup.queue_free()
		_pct_popup = null

func _percent_color(symbol_id: String) -> Color:
	var color: Variant = SYMBOL_PERCENT_COLORS.get(symbol_id, percent_color)
	return color if color is Color else percent_color

## A symbol's current draw chance (percent) with all persisted + staged levels
## applied — the same additive weight layering Evaluate._build_weights uses for
## the reel roll, minus run-only modifiers (book/brain boosts).
func _symbol_percent(symbol_id: String) -> float:
	var total := 0.0
	var weight := 0.0
	for sym in Symbols.BASE_SYMBOL_CYCLE:
		var s := String(sym)
		var w := float(int(Symbols.WEIGHT[s])
			+ RunStateStore.odds_upgrade_level(s) * RunStateStore.probability_increase_per_upgrade)
		total += w
		if s == symbol_id:
			weight = w
	return (weight / total) * 100.0 if total > 0.0 else 0.0

func _on_plus_pressed(symbol_id: String) -> void:
	if RunStateStore.buy_odds_upgrade(symbol_id):
		_refresh()

func _on_minus_pressed(symbol_id: String) -> void:
	if RunStateStore.undo_odds_upgrade(symbol_id):
		_refresh()

func _refresh() -> void:
	if _tokens_sprite != null:
		# Token wallet on the sheet's 0..8 frames — the pool itself is capped at
		# odds_max_tokens (8) by the store, so the art can always show it.
		_tokens_sprite.frame = clampi(RunStateStore.oddsTokensRemaining, 0, TOKEN_FRAMES - 1)
	for symbol_id in _level_sprites:
		var level := RunStateStore.odds_upgrade_level(String(symbol_id))
		var spr := _level_sprites[symbol_id] as Sprite2D
		if spr != null:
			var base_x := LEVEL_LAST_ROW_IMG.position.x \
				if String(symbol_id) == String(Symbols.BASE_SYMBOL_CYCLE[Symbols.BASE_SYMBOL_CYCLE.size() - 1]) \
				else LEVEL_ROW_IMG.position.x
			_set_region_frame(spr, base_x, clampi(level, 0, 9))
		var plus := _plus_buttons.get(symbol_id) as Button
		if plus != null:
			plus.disabled = level >= RunStateStore.odds_max_level \
				or RunStateStore.odds_token_cost(String(symbol_id)) > RunStateStore.oddsTokensRemaining
			_dim_button_art(_plus_art.get(symbol_id) as Sprite2D, plus.disabled)
		var minus := _minus_buttons.get(symbol_id) as Button
		if minus != null:
			minus.disabled = int(RunStateStore.oddsPendingUpgrades.get(symbol_id, 0)) <= 0
			_dim_button_art(_minus_art.get(symbol_id) as Sprite2D, minus.disabled)

## Disabled buttons dim their baked art so the state reads without a stylebox.
func _dim_button_art(spr: Sprite2D, disabled: bool) -> void:
	if spr != null:
		spr.modulate = Color(0.45, 0.45, 0.5) if disabled else Color.WHITE
