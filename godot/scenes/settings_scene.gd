@tool
extends Control

const MENU_SCENE := "res://scenes/start_menu_scene.tscn"
const MIN_VOLUME_DB := -48.0
const MAX_VOLUME_DB := 0.0
const NEON_CYAN := Color(0.65, 0.95, 0.83)
const NEON_PINK := Color(0.86, 0.71, 0.43)
const MUTE_ROW_MIN_SIZE := Vector2(88.0, 24.0)

@export var audio_bus_name: StringName = &"Master":
	set(value):
		audio_bus_name = value
		_refresh_controls()

@onready var _volume_slider := $Panel/Rows/VolumeRow/VolumeSlider as HSlider
@onready var _volume_value := $Panel/Rows/VolumeRow/ValueLabel as Label
@onready var _mute_check := $Panel/Rows/MuteCheck as CheckBox
@onready var _back_button := $BackButton as Button
@onready var _panel := $Panel as PanelContainer
@onready var _title := $Panel/Rows/Title as Label
@onready var _volume_title := $Panel/Rows/VolumeTitle as Label

## This screen is audio settings only. Replaying the tutorial (issue #105) lives on the
## OPTIONS overlay one level up, with the other things a player comes here to DO.

func _ready() -> void:
	UiKit.apply_font(self)
	_style_controls()
	_connect_controls()
	_refresh_controls()

func _connect_controls() -> void:
	if _volume_slider != null and not _volume_slider.value_changed.is_connected(_on_volume_changed):
		_volume_slider.value_changed.connect(_on_volume_changed)
	if _mute_check != null and not _mute_check.toggled.is_connected(_on_mute_toggled):
		_mute_check.toggled.connect(_on_mute_toggled)
	if _back_button != null and not _back_button.pressed.is_connected(_go_back):
		_back_button.pressed.connect(_go_back)

func _style_controls() -> void:
	if _panel != null:
		_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_style_label(_title, NEON_PINK, 10)
	_style_label(_volume_title, NEON_PINK, 8)
	_style_label(_volume_value, NEON_CYAN, 8)
	if _volume_slider != null:
		_volume_slider.min_value = 0.0
		_volume_slider.max_value = 100.0
		_volume_slider.step = 1.0
		_volume_slider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var track_style := StyleBoxFlat.new()
		track_style.bg_color = Color(0.03, 0.01, 0.05, 0.95)
		track_style.border_color = NEON_PINK
		track_style.set_border_width_all(1)
		track_style.set_corner_radius_all(1)
		track_style.content_margin_top = 2.0
		track_style.content_margin_bottom = 2.0
		_volume_slider.add_theme_stylebox_override("slider", track_style)
		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.72)
		fill_style.border_color = NEON_CYAN
		fill_style.set_border_width_all(1)
		fill_style.set_corner_radius_all(1)
		fill_style.content_margin_top = 2.0
		fill_style.content_margin_bottom = 2.0
		_volume_slider.add_theme_stylebox_override("grabber_area", fill_style)
		_volume_slider.add_theme_stylebox_override("grabber_area_highlight", fill_style)
		var grabber := _make_slider_grabber()
		_volume_slider.add_theme_icon_override("grabber", grabber)
		_volume_slider.add_theme_icon_override("grabber_highlight", grabber)
		_volume_slider.add_theme_icon_override("grabber_disabled", grabber)
	if _mute_check != null:
		# Keep the toggle visually distinct from BACK; only keyboard focus outlines it.
		_mute_check.custom_minimum_size = MUTE_ROW_MIN_SIZE
		_mute_check.add_theme_font_override("font", UiKit.control_font())
		_mute_check.add_theme_font_size_override("font_size", 8)
		# Left, so the label sits against the box it belongs to instead of floating in the
		# middle of a row with no plate to centre it in.
		_mute_check.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_mute_check.add_theme_constant_override("icon_max_width", 9)
		for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			_mute_check.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		# Preserve the brass lettering through hover and press.
		for color_state in ["font_color", "font_hover_color", "font_pressed_color",
				"font_hover_pressed_color", "font_focus_color"]:
			_mute_check.add_theme_color_override(color_state, NEON_PINK)
		_mute_check.focus_mode = Control.FOCUS_ALL
		var focus_style := StyleBoxFlat.new()
		focus_style.bg_color = Color.TRANSPARENT
		focus_style.border_color = NEON_CYAN
		focus_style.set_border_width_all(1)
		_mute_check.add_theme_stylebox_override("focus", focus_style)
		_mute_check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var unchecked_icon := _make_checkbox_icon(false)
		var checked_icon := _make_checkbox_icon(true)
		_mute_check.add_theme_icon_override("unchecked", unchecked_icon)
		_mute_check.add_theme_icon_override("checked", checked_icon)
		_mute_check.add_theme_icon_override("unchecked_disabled", unchecked_icon)
		_mute_check.add_theme_icon_override("checked_disabled", checked_icon)
	if _back_button != null:
		ButtonKit.small_neon_button_style(_back_button, ButtonKit.START_MENU_BUTTON_YELLOW, 8)
		ButtonKit.start_menu_button_press_feedback(_back_button)

func _style_label(label: Label, color: Color, font_size: int) -> void:
	if label == null:
		return
	label.add_theme_font_override("font", UiKit.control_font())
	label.add_theme_font_size_override("font_size", UiKit.control_font_size(font_size))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 0)

func _make_slider_grabber() -> ImageTexture:
	var image := Image.create(7, 9, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.13, 0.10, 0.07))
	image.fill_rect(Rect2i(1, 1, 5, 7), NEON_PINK)
	image.fill_rect(Rect2i(1, 1, 5, 1), Color(1.0, 0.89, 0.62))
	image.fill_rect(Rect2i(3, 3, 1, 3), Color(0.28, 0.21, 0.12))
	return ImageTexture.create_from_image(image)

func _make_checkbox_icon(checked: bool) -> Texture2D:
	if checked:
		return UiKit.texture("ui/premium/confirm.png")
	var image := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	for x in range(9):
		image.set_pixel(x, 0, NEON_PINK)
		image.set_pixel(x, 8, NEON_PINK)
	for y in range(9):
		image.set_pixel(0, y, NEON_PINK)
		image.set_pixel(8, y, NEON_PINK)
	return ImageTexture.create_from_image(image)


func _bus_index() -> int:
	var index := AudioServer.get_bus_index(audio_bus_name)
	return 0 if index < 0 else index

func _refresh_controls() -> void:
	if not is_inside_tree():
		return
	var index := _bus_index()
	var volume_percent := 100.0
	if not Engine.is_editor_hint():
		volume_percent = db_to_linear(AudioServer.get_bus_volume_db(index)) * 100.0
	if _volume_slider != null:
		_volume_slider.set_value_no_signal(clampf(volume_percent, 0.0, 100.0))
	if _mute_check != null:
		_mute_check.set_pressed_no_signal(false if Engine.is_editor_hint() else AudioServer.is_bus_mute(index))
	_update_volume_label(volume_percent)

func _on_volume_changed(value: float) -> void:
	_update_volume_label(value)
	if Engine.is_editor_hint():
		return
	var linear := clampf(value / 100.0, 0.0, 1.0)
	AudioServer.set_bus_volume_db(_bus_index(), MIN_VOLUME_DB if linear <= 0.0 else clampf(linear_to_db(linear), MIN_VOLUME_DB, MAX_VOLUME_DB))

func _on_mute_toggled(enabled: bool) -> void:
	if Engine.is_editor_hint():
		return
	AudioServer.set_bus_mute(_bus_index(), enabled)

func _update_volume_label(value: float) -> void:
	if _volume_value != null:
		_volume_value.text = "%d%%" % roundi(value)

func _go_back() -> void:
	if Engine.is_editor_hint():
		return
	SceneNav.go_back(MENU_SCENE)
