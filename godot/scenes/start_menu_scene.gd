extends Control

## Start-run menu (issue #21) — the game's launch screen. From here the player
## either begins a run (which routes FIRST through the dealer scene running in its
## pre-run consumable-shop mode) or opens the upgrade hub. The upgrade system is
## still the existing shop scene and stays as-is/unfinished for now.
##
## Flow: launch -> this menu -> START RUN -> dealer (pre-run shop) -> machine run.
## The dealer scene self-detects pre-run mode from RunStateStore.runPhase, so no
## state has to be threaded through the scene change here.

const DEALER_SCENE := "res://scenes/dealer_scene.tscn"
const SHOP_SCENE := "res://scenes/shop_scene.tscn"
const SCORES_SCENE := "res://scenes/scores_scene.tscn"

var _font: FontFile = null

func _ready() -> void:
	_font = Assets.font()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_menu()

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.03, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var tex := Assets.texture("dealer_shop_bg.png", true)
	if tex != null:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.position = Vector2.ZERO
		spr.scale = Vector2(160.0 / tex.get_width(), 320.0 / tex.get_height())
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(spr)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.04, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

func _label(text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(148.0, 0.0)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_color_override("font_color", color)
	return l

func _menu_button(text: String, size: int, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120.0, 22.0)
	b.add_theme_font_size_override("font_size", size)
	if _font != null:
		b.add_theme_font_override("font", _font)
	b.pressed.connect(cb)
	return b

func _build_menu() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(6.0, 96.0)
	col.custom_minimum_size = Vector2(148.0, 0.0)
	col.add_theme_constant_override("separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(col)

	col.add_child(_label("LOBOTOMY", 16, Color(0.85, 0.9, 1.0)))
	col.add_child(_label("CASINO", 16, Color(0.85, 0.9, 1.0)))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 18.0)
	col.add_child(spacer)

	var start := _menu_button("START RUN", 11, _start_run)
	col.add_child(start)
	col.add_child(_menu_button("UPGRADES", 9, _open_upgrades))
	col.add_child(_menu_button("SCORES", 8, _open_scores))

func _start_run() -> void:
	# Begin a run by visiting the dealer FIRST; the dealer scene runs in pre-run
	# shop mode (it detects this from RunStateStore having no active run) and the
	# run itself is started there once the player leaves the counter.
	get_tree().change_scene_to_file(DEALER_SCENE)

func _open_upgrades() -> void:
	# The upgrade system is the existing shop hub; left as-is/unfinished for now.
	get_tree().change_scene_to_file(SHOP_SCENE)

func _open_scores() -> void:
	get_tree().change_scene_to_file(SCORES_SCENE)
