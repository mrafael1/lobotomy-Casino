@tool
extends Control

## Scores / history screen (issue #142). Read-only view of persisted meta
## progression drawn over the authored SCORES cabinet art. The arrow pair under
## "win counter" cycles the counter through classic and the augmented suits;
## the cabinet's X plate returns to the scene that opened this.

const MENU_SCENE := "res://scenes/start_menu_scene.tscn"

const BG_REL := "SCORES/SCORES.png"
const SYMBOLS_REL := "SCORES/SCORES_symbols.png"
const ARROWS_REL := "SCORES/SCORES_arrows.png"

# Tier order matches the authored symbol sheet (960x320: six full-canvas
# 160x320 frames — classic "no tier" glyph, then heart/diamond/spade/club/joker).
const TIERS: Array[String] = ["classic", "heart", "diamond", "spade", "club", "joker"]
const FRAME_W := 160.0
const FRAME_H := 320.0

# The symbol + arrows are authored centered under the win counter row; the pop
# bounce pivots on the symbol's centre so it scales in place.
const SYMBOL_PIVOT := Vector2(76.5, 156.0)
# Tight crops around each authored arrow, so each side squashes on its own centre
# when pressed (start-menu selector feel). The arrows sheet is a single 160x320
# canvas — it used to carry a second, wider pair for the joker tier, but the
# re-export dropped it and one pair now serves every tier.
const ARROW_LEFT_CROP := Rect2(44.0, 149.0, 9.0, 15.0)
const ARROW_RIGHT_CROP := Rect2(101.0, 149.0, 9.0, 15.0)
const CLOSE_BUTTON_RECT := Rect2(52.0, 290.0, 56.0, 14.0)

const STAT_COLOR := Color(0.94, 0.96, 0.86)
const WEALTH_COLOR := Color(1.0, 0.72, 0.4)
const SECRET_COLOR := Color(0.82, 0.9, 1.0)

var _font: FontFile = null
var _symbol_rect: TextureRect = null
var _arrow_left: TextureRect = null
var _arrow_right: TextureRect = null
var _win_counter_label: Label = null
var _tier_idx := 0

func _ready() -> void:
	_font = Assets.font("font/DTM-Sans.otf")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.texture = Assets.texture(BG_REL)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.stretch_mode = TextureRect.STRETCH_KEEP
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# MetaStateStore is not a @tool script, so the editor preview renders the
	# layout with placeholder (empty) data instead of touching the autoload.
	var in_editor := Engine.is_editor_hint()
	var h: Dictionary = {} if in_editor else MetaStateStore.history
	var reached: Array = [] if in_editor else MetaStateStore.endingsReached

	# Values sit a uniform 4px after the colons of the authored stat rows
	# (colon end x measured per row in the background art).
	_value(Vector2(89.0, 106.0), 9, STAT_COLOR, "%d" % int(h.get("bestScoreRun", 0)))
	_value(Vector2(89.0, 118.0), 9, STAT_COLOR, "%d" % int(h.get("runsPlayed", 0)))
	# The win counter shows the selected tier's wins; the arrows cycle it.
	_win_counter_label = _value(Vector2(93.0, 130.0), 9, STAT_COLOR, "0")

	# Per-tier cycler: the symbol is authored as full-canvas frames centered
	# under the win counter, so drawing the whole frame at (0,0) lands it
	# exactly where designed.
	_symbol_rect = _frame_rect(SYMBOLS_REL, 0)
	_symbol_rect.pivot_offset = SYMBOL_PIVOT
	_arrow_left = _arrow_art(ARROW_LEFT_CROP)
	_arrow_right = _arrow_art(ARROW_RIGHT_CROP)
	# Tap targets are padded well past the 9x15 arrows they cover — the art is far
	# too small to hit reliably on a 160px-wide phone canvas.
	_arrow_hit_button("TierPrevButton", Rect2(38.0, 145.0, 21.0, 23.0), -1, _arrow_left)
	_arrow_hit_button("TierNextButton", Rect2(95.0, 145.0, 21.0, 23.0), 1, _arrow_right)
	_refresh_tier()

	# ENDINGS: achieved flag on the row, then the authored dot rows carry the
	# playtime-to-achieve and the date.
	_value(Vector2(75.0, 180.0), 8, WEALTH_COLOR,
		"yes" if reached.has("wealth") else "no")
	_value(Vector2(48.0, 189), 7, WEALTH_COLOR,
		"time  %s" % _fmt_playtime(h.get("wealthEndingPlaytimeMs", null)))
	_value(Vector2(48.0, 197), 7, WEALTH_COLOR,
		"date  %s" % _fmt_date(h.get("wealthEndingReachedAt", null)))
	_value(Vector2(75.0, 204.0), 8, SECRET_COLOR,
		"yes" if reached.has("exit") else "no")
	_value(Vector2(48.0, 214), 7, SECRET_COLOR,
		"time  %s" % _fmt_playtime(h.get("exitEndingPlaytimeMs", null)))
	_value(Vector2(48.0, 222), 7, SECRET_COLOR,
		"date  %s" % _fmt_date(h.get("exitEndingReachedAt", null)))

	# The cabinet button bar's X plate is decorative; the explicit neon button
	# below the cabinet is the only close action.
	_build_close_button()

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _value(pos: Vector2, size: int, color: Color, text: String) -> Label:
	var l := _label(text, size, color)
	l.position = pos
	add_child(l)
	return l

# Whole authored 160x320 frame of a horizontal sheet, drawn at the canvas origin.
func _frame_rect(rel: String, frame: int) -> TextureRect:
	var tr := TextureRect.new()
	var tex := Assets.texture(rel)
	if tex != null:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(float(frame) * FRAME_W, 0.0, FRAME_W, FRAME_H)
		tr.texture = at
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_KEEP
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr

# One arrow of the pair, cropped from the sheet so it can squash independently
# on press (start-menu selector feel). Positioned at its authored canvas spot.
func _arrow_art(crop: Rect2) -> TextureRect:
	var tr := TextureRect.new()
	var tex := Assets.texture(ARROWS_REL)
	if tex != null:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(crop.position, crop.size)
		tr.texture = at
	tr.position = crop.position
	tr.pivot_offset = crop.size * 0.5
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_KEEP
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr

func _set_frame(tr: TextureRect, frame: int) -> void:
	if tr != null and tr.texture is AtlasTexture:
		(tr.texture as AtlasTexture).region = Rect2(float(frame) * FRAME_W, 0.0, FRAME_W, FRAME_H)

# Invisible click area over authored art (the X plate).
func _hit_button(node_name: String, rect: Rect2, cb: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = rect.position
	b.size = rect.size
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(String(state), empty)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	add_child(b)
	return b

func _build_close_button() -> void:
	var close := Button.new()
	close.name = "CloseButton"
	close.text = "CLOSE"
	close.position = CLOSE_BUTTON_RECT.position
	close.size = CLOSE_BUTTON_RECT.size
	close.focus_mode = Control.FOCUS_NONE
	Assets.small_neon_button_style(close, Assets.START_MENU_BUTTON_PINK, 6, 2.0)
	Assets.start_menu_button_press_feedback(close)
	close.pressed.connect(_go_back)
	add_child(close)

# Arrow hit area: pressing squashes the arrow art, release springs it back as
# the tier cycles — same feel as the start-menu selector arrows.
func _arrow_hit_button(node_name: String, rect: Rect2, step: int, art: TextureRect) -> Button:
	var b := _hit_button(node_name, rect, _cycle_tier.bind(step))
	b.button_down.connect(_on_arrow_down.bind(art))
	b.button_up.connect(_on_arrow_up.bind(art))
	return b

func _on_arrow_down(art: TextureRect) -> void:
	if art == null or not is_instance_valid(art):
		return
	var tw := create_tween()
	tw.tween_property(art, "scale", Vector2.ONE * 0.8, 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_arrow_up(art: TextureRect) -> void:
	if art == null or not is_instance_valid(art):
		return
	var tw := create_tween()
	tw.tween_property(art, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _cycle_tier(step: int) -> void:
	_tier_idx = posmod(_tier_idx + step, TIERS.size())
	_refresh_tier()
	_bounce_symbol()

## Bounce the incoming suit: the symbol pops from small to rest, pivoting on
## its own centre (same feel as the start-menu selector).
func _bounce_symbol() -> void:
	if _symbol_rect == null:
		return
	var tw := create_tween()
	tw.tween_property(_symbol_rect, "scale", Vector2.ONE, 0.18) \
		.from(Vector2.ONE * 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _refresh_tier() -> void:
	var tier := TIERS[_tier_idx]
	# Only the suit symbol changes per tier now; the arrows are one authored pair.
	_set_frame(_symbol_rect, _tier_idx)
	if _win_counter_label != null:
		_win_counter_label.text = "%d" % \
			(0 if Engine.is_editor_hint() else MetaStateStore.tier_wins(tier))

func _fmt_playtime(ms: Variant) -> String:
	if ms == null or int(ms) <= 0:
		return "--"
	var total_s := int(ms) / 1000
	if total_s < 60:
		return "%ds" % total_s
	var minutes := total_s / 60
	if minutes < 60:
		return "%dm %02ds" % [minutes, total_s % 60]
	return "%dh %02dm" % [minutes / 60, minutes % 60]

func _fmt_date(ms: Variant) -> String:
	if ms == null or int(ms) <= 0:
		return "--"
	var d := Time.get_datetime_dict_from_unix_time(int(ms) / 1000)
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]

func _go_back() -> void:
	if Engine.is_editor_hint():
		return
	SceneNav.go_back(MENU_SCENE)
