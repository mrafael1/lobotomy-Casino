extends Control

## Scores / history screen (Milestone 3). Read-only view of the persisted meta
## progression in MetaStateStore. Reached from the shop; BACK returns there.

const SHOP_SCENE := "res://scenes/shop_scene.tscn"

var _font: FontFile = null

func _ready() -> void:
	_font = _load_font("font/DTM-Mono.otf")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _load_font(rel: String) -> FontFile:
	var path := ProjectSettings.globalize_path("res://").path_join("../assets").path_join(rel)
	var f := FontFile.new()
	if f.load_dynamic_font(path) != OK:
		return null
	return f

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

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var v := VBoxContainer.new()
	v.position = Vector2(8, 10)
	v.custom_minimum_size = Vector2(144, 0)
	add_child(v)

	var h: Dictionary = MetaStateStore.history
	var reached: Array = MetaStateStore.endingsReached

	v.add_child(_label("SCORES", 13, Color(0.85, 0.9, 1.0)))
	v.add_child(_label("", 4, Color.WHITE))
	v.add_child(_label("Runs played:  %d" % int(h.get("runsPlayed", 0)), 9, Color(0.9, 0.9, 0.8)))
	v.add_child(_label("Best run:     %d" % int(h.get("bestScoreRun", 0)), 9, Color(0.9, 0.9, 0.8)))
	v.add_child(_label("Wallet:       %d" % MetaStateStore.lucidityWallet, 9, Color(0.9, 0.9, 0.8)))
	v.add_child(_label("Upgrades:     %d" % MetaStateStore.ownedPermanents.size(), 9, Color(0.9, 0.9, 0.8)))
	v.add_child(_label("Corrupted:    %s" % ("yes" if MetaStateStore.corruptionEverUsed else "no"), 9, Color(0.9, 0.7, 0.7)))
	v.add_child(_label("", 4, Color.WHITE))
	v.add_child(_label("— ENDINGS —", 9, Color(1.0, 0.7, 0.5)))
	v.add_child(_label("Reached:  %s" % ("none" if reached.is_empty() else ", ".join(PackedStringArray(reached))), 8, Color(0.8, 0.85, 0.95)))
	v.add_child(_label("Wealth at: %s" % _when(h.get("wealthEndingReachedAt", null)), 8, Color(0.7, 0.9, 0.7)))
	v.add_child(_label("Exit at:   %s" % _when(h.get("exitEndingReachedAt", null)), 8, Color(0.7, 0.9, 0.9)))

	var back := Button.new()
	back.text = "BACK"
	back.position = Vector2(8, 296)
	back.size = Vector2(70, 18)
	back.add_theme_font_size_override("font_size", 9)
	if _font != null:
		back.add_theme_font_override("font", _font)
	back.pressed.connect(func(): get_tree().change_scene_to_file(SHOP_SCENE))
	add_child(back)
