extends Button

## A small native-resolution wall control for the Fortune Wheel.
##
## The button keeps its hit rectangle comfortably larger than its pixel-art face,
## while drawing the face itself in hard-edged rings so it feels mounted in the
## Bonus room instead of looking like a generic rectangular UI widget.

const CYAN := Color("ac9161")
const HOT_CYAN := Color("fff0c4")
const GOLD := Color("c5a66d")
const HOT_GOLD := Color("f0d9a0")
const WALL := Color("151b15")

var _hovered := false
var _pressed := false

func _ready() -> void:
	flat = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_theme_color_override("font_color", HOT_GOLD)
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", HOT_CYAN)
	add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.64, 0.78))
	add_theme_color_override("font_focus_color", HOT_GOLD)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	queue_redraw()

func _draw() -> void:
	var centre := Vector2(floorf(size.x * 0.5), floorf(size.y * 0.5))
	var radius := floorf(minf(size.x, size.y) * 0.5) - 2.0
	var sink := Vector2(0.0, 1.0) if _pressed else Vector2.ZERO
	var outer := GOLD
	var face := Color("233b2e")
	if disabled:
		outer = Color(0.38, 0.43, 0.49, 0.8)
		face = Color("18231e")
	elif _pressed:
		outer = HOT_CYAN
		face = Color("10261c")
	elif _hovered:
		outer = HOT_GOLD
		face = Color("34523e")

	# Wall mount shadow and a dark outer plate keep the control legible against the
	# authored wall without adding a soft, non-pixel blur.
	draw_circle(centre + Vector2(1.0, 2.0), radius + 1.0, Color(0.0, 0.0, 0.0, 0.72))
	draw_circle(centre, radius + 1.0, WALL)
	draw_arc(centre, radius + 1.0, 0.0, TAU, 32, Color(CYAN.r, CYAN.g, CYAN.b, 0.42), 1.0, false)
	draw_circle(centre + sink, radius - 1.0, face)
	draw_arc(centre + sink, radius - 1.0, 0.0, TAU, 32, outer, 2.0, false)
	draw_arc(centre + sink, radius - 4.0, -PI * 0.82, -PI * 0.18, 12,
		Color(HOT_GOLD.r, HOT_GOLD.g, HOT_GOLD.b, 0.72), 1.0, false)
	draw_rect(Rect2(centre + Vector2(-1.0, -radius + 5.0), Vector2(2.0, 2.0)),
		Color.WHITE if not disabled else Color(0.62, 0.65, 0.70, 0.65))

	# Recessed bezel and four slotted brass screws match the cabinet controls.
	draw_arc(centre + sink, radius - 3.0, 0.0, TAU, 48, Color("57482e"), 0.6, false)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var screw: Vector2 = centre + direction * (radius - 0.5)
		draw_circle(screw, 1.2, Color("967d50"))
		draw_line(screw - Vector2(.6, 0), screw + Vector2(.6, 0), Color("302a1d"), .5)
	_draw_label(centre, sink)

func _draw_label(centre: Vector2, sink: Vector2) -> void:
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	if font == null or text.is_empty() or font_size <= 0:
		return
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var baseline := floorf(centre.y + (ascent - descent) * 0.5 + sink.y)
	var text_position := Vector2(floorf(centre.x - text_width * 0.5), baseline)
	var color := Color(0.55, 0.58, 0.64, 0.78) if disabled \
		else HOT_CYAN if _pressed else Color.WHITE if _hovered else HOT_GOLD
	draw_string(font, text_position + Vector2(1.0, 1.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.82))
	draw_string(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		font_size, color)

func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()

func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()

func _on_button_down() -> void:
	_pressed = true
	queue_redraw()

func _on_button_up() -> void:
	_pressed = false
	queue_redraw()
