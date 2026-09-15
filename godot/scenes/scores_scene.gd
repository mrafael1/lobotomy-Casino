@tool
extends Control

## Read-only campaign ledger. All values remain backed by MetaStateStore.
const MENU_SCENE := "res://scenes/start_menu_scene.tscn"
const TIERS: Array[String] = ["classic", "heart", "diamond", "spade", "club", "joker"]
const GOLD := Color("#dfc48a")
const INK := Color("#edf0d9")
var _win_counter_label: Label
var _tier_label: Label
var _symbol_rect: TextureRect
var _tier_idx := 0
var _symbol_tween: Tween

func _ready() -> void:
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.texture = Assets.texture("scores_polished/ledger.svg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(160, 320)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_line("SCORES", Rect2(24, 33, 112, 16), 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var history: Dictionary = {} if Engine.is_editor_hint() else MetaStateStore.history
	var reached: Array = [] if Engine.is_editor_hint() else MetaStateStore.endingsReached
	_stat("SCORES_BEST", str(int(history.get("bestScoreRun", 0))), 66)
	_stat("SCORES_RUNS", str(int(history.get("runsPlayed", 0))), 84)
	_win_counter_label = _stat("SCORES_WINS", "0", 102)
	_symbol_rect = TextureRect.new()
	_symbol_rect.name = "TierEmblem"
	var atlas := AtlasTexture.new()
	atlas.atlas = Assets.texture("scores_polished/suits.svg")
	atlas.region = Rect2(0, 0, 128, 128)
	_symbol_rect.texture = atlas
	_symbol_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_symbol_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_symbol_rect.size = Vector2(24, 24)
	_symbol_rect.position = Vector2(68, 125)
	_symbol_rect.pivot_offset = Vector2(12, 12)
	_symbol_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_symbol_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_symbol_rect)
	_tier_label = _line("", Rect2(48, 150, 64, 8), 8, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_button("TierPrevButton", "<", Rect2(28, 130, 24, 24), _cycle_tier.bind(-1))
	_button("TierNextButton", ">", Rect2(108, 130, 24, 24), _cycle_tier.bind(1))
	_refresh_tier()
	_ending("SCORES_WEALTH", reached.has("wealth"), 178,
		history.get("wealthEndingPlaytimeMs"), history.get("wealthEndingReachedAt"))
	_ending("SCORES_SECRET", reached.has("exit"), 229,
		history.get("exitEndingPlaytimeMs"), history.get("exitEndingReachedAt"))
	_button("CloseButton", "CLOSE", Rect2(44, 276, 72, 18), _go_back)

func _line(text: String, rect: Rect2, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = align
	label.clip_text = true
	label.add_theme_font_override("font", UiKit.control_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	# Apply the box after the font and clipping invalidate the initial minimum size.
	label.set_deferred("size", rect.size)
	return label

func _stat(key: String, value: String, y: float) -> Label:
	_line(key, Rect2(29, y, 66, 10), 8, GOLD)
	var result := _line(value, Rect2(86, y, 45, 10), 8, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	result.name = key + "Value"
	result.tooltip_text = value
	return result

func _ending(key: String, reached: bool, y: float, time: Variant, date: Variant) -> void:
	_line(key, Rect2(29, y, 101, 9), 8, GOLD)
	_line("SCORES_YES" if reached else "SCORES_NO", Rect2(29, y + 10, 101, 8), 8,
		Color("#9cd9b7") if reached else Color("#879492"))
	_line(tr("time  %s") % _fmt_playtime(time), Rect2(29, y + 21, 101, 8), 8, INK)
	_line(tr("date  %s") % _fmt_date(date), Rect2(29, y + 30, 101, 8), 8, INK)

func _button(node_name: String, text: String, rect: Rect2, callback: Callable) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.position = rect.position
	button.size = rect.size
	ButtonKit.start_menu_button_style(button, ButtonKit.START_MENU_BUTTON_YELLOW, 8)
	ButtonKit.start_menu_button_press_feedback(button)
	button.pressed.connect(callback)
	add_child(button)

func _cycle_tier(step: int) -> void:
	_tier_idx = posmod(_tier_idx + step, TIERS.size())
	_refresh_tier()
	if _symbol_tween != null:
		_symbol_tween.kill()
	_symbol_rect.scale = Vector2.ONE * 0.8
	_symbol_tween = create_tween()
	_symbol_tween.tween_property(_symbol_rect, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _refresh_tier() -> void:
	var tier := TIERS[_tier_idx]
	(_symbol_rect.texture as AtlasTexture).region = Rect2(_tier_idx * 128, 0, 128, 128)
	_tier_label.text = "SCORES_" + tier.to_upper()
	_win_counter_label.text = str(0 if Engine.is_editor_hint() else MetaStateStore.tier_wins(tier))

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
	if not Engine.is_editor_hint():
		SceneNav.go_back(MENU_SCENE)
