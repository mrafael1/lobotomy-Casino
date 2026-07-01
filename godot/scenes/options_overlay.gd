@tool
class_name OptionsOverlay
extends Control

signal closed
signal scores_requested
signal settings_requested
signal collection_requested
signal return_to_menu_requested

const SCORES_SCENE := "res://scenes/scores_scene.tscn"
const SETTINGS_SCENE := "res://scenes/settings_scene.tscn"
const COLLECTION_SCENE := "res://scenes/collection_scene.tscn"
const MENU_SCENE := "res://scenes/start_menu_scene.tscn"

@export var editor_preview_visible := true:
	set(value):
		editor_preview_visible = value
		if Engine.is_editor_hint() and is_inside_tree():
			visible = editor_preview_visible

@onready var _panel := $Panel as PanelContainer
@onready var _scores_button := $Panel/Menu/ScoresButton as Button
@onready var _settings_button := $Panel/Menu/SettingsButton as Button
@onready var _collection_button := $Panel/Menu/CollectionButton as Button
@onready var _menu_button := $Panel/Menu/MenuButton as Button
@onready var _close_button := $CloseButton as Button

func _ready() -> void:
	size = Vector2(160.0, 320.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_font(self)
	_style_menu_button(_scores_button)
	_style_menu_button(_settings_button)
	_style_menu_button(_collection_button)
	_style_menu_button(_menu_button)
	_style_close_button(_close_button)
	_connect_button(_scores_button, _open_scores)
	_connect_button(_settings_button, _open_settings)
	_connect_button(_collection_button, _open_collection)
	_connect_button(_menu_button, _return_to_menu)
	_connect_button(_close_button, hide_overlay)
	visible = editor_preview_visible if Engine.is_editor_hint() else false

func show_overlay() -> void:
	visible = true

func hide_overlay() -> void:
	visible = false
	closed.emit()

func toggle_overlay() -> void:
	visible = not visible

func _connect_button(button: Button, cb: Callable) -> void:
	if button == null:
		return
	if not button.pressed.is_connected(cb):
		button.pressed.connect(cb)

func _apply_font(node: Node) -> void:
	var font := Assets.font()
	for child in node.get_children():
		if child is Button and font != null:
			(child as Button).add_theme_font_override("font", font)
		elif child is Label and font != null:
			(child as Label).add_theme_font_override("font", font)
		_apply_font(child)

func _style_menu_button(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(104.0, 20.0)
	button.add_theme_font_size_override("font_size", 7)
	Assets.skin_sheet_button(button, "ui/green_button.png", 4)

func _style_close_button(button: Button) -> void:
	if button == null:
		return
	button.add_theme_font_size_override("font_size", 6)
	Assets.skin_negative_button(button)

func _open_scores() -> void:
	scores_requested.emit()
	if Engine.is_editor_hint():
		return
	SceneNav.push_current_scene(true)
	get_tree().change_scene_to_file(SCORES_SCENE)

func _open_settings() -> void:
	settings_requested.emit()
	if Engine.is_editor_hint():
		return
	SceneNav.push_current_scene(true)
	get_tree().change_scene_to_file(SETTINGS_SCENE)

func _open_collection() -> void:
	collection_requested.emit()
	if Engine.is_editor_hint():
		return
	SceneNav.push_current_scene(true)
	get_tree().change_scene_to_file(COLLECTION_SCENE)

func _return_to_menu() -> void:
	return_to_menu_requested.emit()
	if Engine.is_editor_hint():
		return
	SceneNav.go_to_menu(MENU_SCENE)
