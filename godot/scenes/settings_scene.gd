@tool
extends Control

const MENU_SCENE := "res://scenes/start_menu_scene.tscn"
const MIN_VOLUME_DB := -48.0
const MAX_VOLUME_DB := 0.0

@export var audio_bus_name: StringName = &"Master":
	set(value):
		audio_bus_name = value
		_refresh_controls()

@onready var _volume_slider := $Panel/Rows/VolumeRow/VolumeSlider as HSlider
@onready var _volume_value := $Panel/Rows/VolumeRow/ValueLabel as Label
@onready var _mute_check := $Panel/Rows/MuteCheck as CheckBox
@onready var _back_button := $Panel/Rows/BackButton as Button

func _ready() -> void:
	_apply_font(self)
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
	if _volume_slider != null:
		_volume_slider.min_value = 0.0
		_volume_slider.max_value = 100.0
		_volume_slider.step = 1.0
	if _back_button != null:
		_back_button.add_theme_font_size_override("font_size", 8)
		Assets.skin_negative_button(_back_button)

func _apply_font(node: Node) -> void:
	var font := Assets.font()
	for child in node.get_children():
		if child is Label and font != null:
			(child as Label).add_theme_font_override("font", font)
		elif child is Button and font != null:
			(child as Button).add_theme_font_override("font", font)
		elif child is CheckBox and font != null:
			(child as CheckBox).add_theme_font_override("font", font)
		_apply_font(child)

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
