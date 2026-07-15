@tool
class_name GameOverEndingOverlay
extends Control

signal try_again_pressed

const CANVAS_SIZE := Vector2(160.0, 320.0)
const TV_SCREEN_RECT := Rect2(24.0, 42.0, 112.0, 66.0)
const RED := Color("#ff334d")
const PALE_RED := Color("#ff9aa8")
const SOFT_WHITE := Color("#f4f2f0")
const DAMAGE_RED := Color("#ff334d")
const DAMAGE_CYAN := Color("#27e8e4")
const TV_SCREEN_CENTER := Vector2(80.0, 75.0)
const JOKER_OPACITY := 0.8

@onready var title_label: Label = %TitleLabel
@onready var fatal_label: Label = %FatalLabel
@onready var money_label: Label = %MoneyLabel
@onready var joker_icon: TextureRect = %JokerIcon
@onready var action_button: Button = %ActionButton
@onready var button_host: Control = %ButtonHost


func _ready() -> void:
	set_deferred(&"size", CANVAS_SIZE)
	_style_text()
	_style_button()
	_setup_joker()
	if not action_button.pressed.is_connected(_on_action_pressed):
		action_button.pressed.connect(_on_action_pressed)
	if Engine.is_editor_hint():
		return
	action_button.call_deferred(&"grab_focus")
	queue_redraw()


func present() -> void:
	# Game over is a hard loss: the visible balance and the committed state are
	# both zero. Keeping this explicit makes the scene safe to preview in isolation.
	money_label.text = "0"
	joker_icon.modulate = Color(1.0, 1.0, 1.0, JOKER_OPACITY)
	queue_redraw()


func _style_text() -> void:
	var font := Assets.font()
	for label: Label in find_children("*", "Label", true, false):
		if font != null:
			label.add_theme_font_override(&"font", font)
		label.add_theme_color_override(&"font_outline_color", Color("#100306"))
		label.add_theme_constant_override(&"outline_size", 1)
	title_label.add_theme_color_override(&"font_color", RED)
	fatal_label.add_theme_color_override(&"font_color", PALE_RED)
	money_label.add_theme_color_override(&"font_color", SOFT_WHITE)


func _style_button() -> void:
	var font := Assets.font()
	if font != null:
		action_button.add_theme_font_override(&"font", font)
	action_button.add_theme_color_override(&"font_color", PALE_RED)
	action_button.add_theme_color_override(&"font_hover_color", Color.WHITE)
	action_button.add_theme_color_override(&"font_pressed_color", Color.WHITE)
	action_button.add_theme_color_override(&"font_focus_color", PALE_RED)
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#21070c") if state != &"hover" else Color("#380a12")
		style.set_content_margin_all(2.0)
		action_button.add_theme_stylebox_override(state, style)
	button_host.pivot_offset = button_host.size * 0.5


func _setup_joker() -> void:
	var texture := Assets.augmented_suit_icon("joker")
	if texture == null:
		joker_icon.visible = false
		return
	joker_icon.texture = texture
	joker_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	joker_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	joker_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	joker_icon.position = TV_SCREEN_CENTER - joker_icon.size * 0.5
	joker_icon.pivot_offset = joker_icon.size * 0.5
	joker_icon.modulate = Color(1.0, 1.0, 1.0, JOKER_OPACITY)


func _draw() -> void:
	_draw_tv_damage()
	_draw_machine_damage()


func _draw_tv_damage() -> void:
	# Thin pixel glitches and cracks leave the TV art visible underneath; there is
	# deliberately no opaque panel or dim rectangle inside the screen.
	var glitch_color := Color(DAMAGE_RED, 0.72)
	var cyan_glitch := Color(DAMAGE_CYAN, 0.58)
	for glitch: Rect2 in [
		Rect2(31.0, 55.0, 28.0, 1.0),
		Rect2(98.0, 62.0, 25.0, 2.0),
		Rect2(42.0, 91.0, 17.0, 1.0),
		Rect2(87.0, 96.0, 31.0, 1.0),
	]:
		draw_rect(glitch, glitch_color)
	for glitch: Rect2 in [
		Rect2(27.0, 72.0, 17.0, 1.0),
		Rect2(69.0, 52.0, 21.0, 1.0),
		Rect2(103.0, 84.0, 26.0, 1.0),
	]:
		draw_rect(glitch, cyan_glitch)

	_draw_crack(PackedVector2Array([
		Vector2(46.0, 45.0), Vector2(51.0, 57.0), Vector2(48.0, 66.0),
		Vector2(55.0, 75.0), Vector2(52.0, 88.0), Vector2(59.0, 103.0),
	]))
	_draw_crack(PackedVector2Array([
		Vector2(112.0, 46.0), Vector2(106.0, 57.0), Vector2(110.0, 68.0),
		Vector2(102.0, 78.0), Vector2(105.0, 89.0), Vector2(98.0, 104.0),
	]), DAMAGE_CYAN)
	_draw_crack(PackedVector2Array([
		Vector2(75.0, 44.0), Vector2(71.0, 55.0), Vector2(75.0, 63.0),
		Vector2(70.0, 70.0),
	]), Color(DAMAGE_RED, 0.84))

	# A few short breaks on the inner bezel sell the failed tube without covering it.
	draw_line(Vector2(TV_SCREEN_RECT.position.x + 4.0, TV_SCREEN_RECT.position.y),
		Vector2(TV_SCREEN_RECT.position.x + 16.0, TV_SCREEN_RECT.position.y),
		Color(DAMAGE_RED, 0.85), 1.0, false)
	draw_line(Vector2(TV_SCREEN_RECT.end.x - 17.0, TV_SCREEN_RECT.end.y),
		Vector2(TV_SCREEN_RECT.end.x - 5.0, TV_SCREEN_RECT.end.y),
		Color(DAMAGE_RED, 0.85), 1.0, false)


func _draw_machine_damage() -> void:
	# Jagged breaks are placed on the cabinet's cyan neck and lower shell instead
	# of replacing the authored machine texture.
	_draw_crack(PackedVector2Array([
		Vector2(18.0, 110.0), Vector2(25.0, 117.0), Vector2(22.0, 124.0),
		Vector2(30.0, 132.0), Vector2(26.0, 141.0),
	]), DAMAGE_RED)
	_draw_crack(PackedVector2Array([
		Vector2(143.0, 111.0), Vector2(136.0, 119.0), Vector2(140.0, 126.0),
		Vector2(132.0, 135.0), Vector2(135.0, 145.0),
	]), DAMAGE_CYAN)

	var broken_part := Rect2(119.0, 138.0, 13.0, 6.0)
	draw_rect(broken_part, Color("#100306"))
	draw_line(broken_part.position, broken_part.position + Vector2(7.0, -3.0),
		Color(DAMAGE_RED, 0.9), 1.0, false)
	draw_line(broken_part.position + Vector2(5.0, broken_part.size.y),
		broken_part.end, Color(DAMAGE_CYAN, 0.75), 1.0, false)

	_draw_crack(PackedVector2Array([
		Vector2(18.0, 244.0), Vector2(27.0, 251.0), Vector2(23.0, 259.0),
		Vector2(32.0, 269.0),
	]), Color(DAMAGE_RED, 0.76))
	_draw_crack(PackedVector2Array([
		Vector2(138.0, 246.0), Vector2(132.0, 254.0), Vector2(138.0, 262.0),
		Vector2(131.0, 274.0),
	]), Color(DAMAGE_CYAN, 0.62))


func _draw_crack(points: PackedVector2Array, color: Color = DAMAGE_RED) -> void:
	if points.size() < 2:
		return
	draw_polyline(points, Color(color, 0.18), 4.0, false)
	draw_polyline(points, color, 1.0, false)


func _on_action_pressed() -> void:
	action_button.disabled = true
	try_again_pressed.emit()
