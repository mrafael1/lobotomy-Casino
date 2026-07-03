@tool
extends Control

## Scores / history screen (Milestone 3). Read-only view of persisted meta
## progression. BACK returns to the scene that opened this screen.

const MENU_SCENE := "res://scenes/start_menu_scene.tscn"

var _font: FontFile = null
var _stats_list: VBoxContainer = null
var _back_button: Button = null

func _ready() -> void:
	_font = Assets.font("font/DTM-Sans.otf")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_stats_list = get_node_or_null("StatsList")
	_back_button = get_node_or_null("BackButton")
	_build()

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_color_override("font_color", color)
	return l

func _when(ms: Variant) -> String:
	if ms == null or int(ms) <= 0:
		return "—"
	return Time.get_datetime_string_from_unix_time(int(ms) / 1000, true)

const BORDER := Color(0.36, 0.78, 1.0, 0.95) # cyan border, matches overlay accents
const PANEL_FILL := Color(0.05, 0.06, 0.11, 0.98)
const TITLE_FILL := Color(0.11, 0.16, 0.30, 1.0)

# A 1px-bordered panel (outer border rect + inset fill rect).
func _panel(rect: Rect2, border: Color, fill: Color) -> void:
	var b := ColorRect.new()
	b.color = border
	b.position = rect.position
	b.size = rect.size
	add_child(b)
	var f := ColorRect.new()
	f.color = fill
	f.position = rect.position + Vector2(1, 1)
	f.size = rect.size - Vector2(2, 2)
	add_child(f)

func _build() -> void:
	if _stats_list != null:
		_populate_scores(_stats_list)
		if _back_button != null:
			Assets.skin_negative_button(_back_button)
			var cb := Callable(self, "_go_menu")
			if not _back_button.pressed.is_connected(cb):
				_back_button.pressed.connect(cb)
		return
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Framed panel + title bar (pixel-art overlay style).
	_panel(Rect2(5, 6, 150, 308), BORDER, PANEL_FILL)
	_panel(Rect2(5, 6, 150, 18), BORDER, TITLE_FILL)
	var title := _label("SCORES", 12, Color(0.85, 0.95, 1.0))
	title.position = Vector2(13, 8)
	add_child(title)

	var v := VBoxContainer.new()
	v.position = Vector2(13, 30)
	v.custom_minimum_size = Vector2(134, 0)
	add_child(v)

	var h: Dictionary = MetaStateStore.history
	var reached: Array = MetaStateStore.endingsReached

	v.add_child(_label("Runs played:  %d" % int(h.get("runsPlayed", 0)), 9, Color(0.9, 0.92, 0.82)))
	v.add_child(_label("Best run:     %d" % int(h.get("bestScoreRun", 0)), 9, Color(0.9, 0.92, 0.82)))
	v.add_child(_label("Credits:      %d" % MetaStateStore.lucidityWallet, 9, Color(0.98, 0.85, 0.45)))
	v.add_child(_label("Upgrades:     %d" % MetaStateStore.ownedPermanents.size(), 9, Color(0.9, 0.92, 0.82)))
	v.add_child(_label("Corrupted:    %s" % ("yes" if MetaStateStore.corruptionEverUsed else "no"), 9, Color(0.92, 0.6, 0.6)))
	v.add_child(_label("", 4, Color.WHITE))
	v.add_child(_label("— ENDINGS —", 9, Color(1.0, 0.7, 0.5)))
	v.add_child(_label("Reached:  %s" % ("none" if reached.is_empty() else ", ".join(PackedStringArray(reached))), 8, Color(0.8, 0.85, 0.95)))
	v.add_child(_label("Wealth at: %s" % _when(h.get("wealthEndingReachedAt", null)), 8, Color(0.7, 0.95, 0.75)))
	v.add_child(_label("Exit at:   %s" % _when(h.get("exitEndingReachedAt", null)), 8, Color(0.7, 0.92, 0.95)))

	var back := Button.new()
	back.text = "BACK"
	back.position = Vector2(13, 295)
	back.size = Vector2(70, 16)
	back.add_theme_font_size_override("font_size", 9)
	if _font != null:
		back.add_theme_font_override("font", _font)
	Assets.skin_negative_button(back)
	back.pressed.connect(_go_back)
	add_child(back)

func _populate_scores(v: VBoxContainer) -> void:
	var h: Dictionary = MetaStateStore.history
	var reached: Array = MetaStateStore.endingsReached
	_set_stat_label(v, "RunsLabel", "Runs played:  %d" % int(h.get("runsPlayed", 0)), 9, Color(0.9, 0.92, 0.82))
	_set_stat_label(v, "BestLabel", "Best run:     %d" % int(h.get("bestScoreRun", 0)), 9, Color(0.9, 0.92, 0.82))
	_set_stat_label(v, "CreditsLabel", "Credits:      %d" % MetaStateStore.lucidityWallet, 9, Color(0.98, 0.85, 0.45))
	_set_stat_label(v, "UpgradesLabel", "Upgrades:     %d" % MetaStateStore.ownedPermanents.size(), 9, Color(0.9, 0.92, 0.82))
	_set_stat_label(v, "CorruptedLabel", "Corrupted:    %s" % ("yes" if MetaStateStore.corruptionEverUsed else "no"), 9, Color(0.92, 0.6, 0.6))
	_set_stat_label(v, "SpacerLabel", "", 4, Color.WHITE)
	_set_stat_label(v, "EndingsTitleLabel", "-- ENDINGS --", 9, Color(1.0, 0.7, 0.5))
	_set_stat_label(v, "ReachedLabel", "Reached:  %s" % ("none" if reached.is_empty() else ", ".join(PackedStringArray(reached))), 8, Color(0.8, 0.85, 0.95))
	_set_stat_label(v, "WealthLabel", "Wealth at: %s" % _when(h.get("wealthEndingReachedAt", null)), 8, Color(0.7, 0.95, 0.75))
	_set_stat_label(v, "ExitLabel", "Exit at:   %s" % _when(h.get("exitEndingReachedAt", null)), 8, Color(0.7, 0.92, 0.95))

func _set_stat_label(parent: VBoxContainer, node_name: String, text: String, size: int, color: Color) -> void:
	var l := parent.get_node_or_null(node_name) as Label
	if l == null:
		l = _label(text, size, color)
		l.name = node_name
		parent.add_child(l)
	else:
		l.text = text
		l.add_theme_font_size_override("font_size", size)
		if _font != null:
			l.add_theme_font_override("font", _font)
		l.add_theme_color_override("font_color", color)

func _go_menu() -> void:
	_go_back()

func _go_back() -> void:
	if Engine.is_editor_hint():
		return
	SceneNav.go_back(MENU_SCENE)
