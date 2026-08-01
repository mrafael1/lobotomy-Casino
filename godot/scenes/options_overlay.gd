@tool
class_name OptionsOverlay
extends Control

signal closed
signal scores_requested
signal settings_requested
signal collection_requested
signal tutorial_requested
signal return_to_menu_requested

const SCORES_SCENE := "res://scenes/scores_scene.tscn"
const SETTINGS_SCENE := "res://scenes/settings_scene.tscn"
const COLLECTION_SCENE := "res://scenes/collection_scene.tscn"
const MENU_SCENE := "res://scenes/start_menu_scene.tscn"
const NEON_CYAN := Color(0.42, 1.0, 0.95)
const NEON_PINK := Color(1.0, 0.5, 0.7)
const NEON_YELLOW := Color(1.0, 0.86, 0.36)
## px from the LANGUAGE row's right edge to the flag, matching the row's own text inset.
const LANGUAGE_FLAG_INSET := 8.0

@export var editor_preview_visible := true:
	set(value):
		editor_preview_visible = value
		if Engine.is_editor_hint() and is_inside_tree():
			visible = editor_preview_visible

@onready var _panel := $Panel as PanelContainer
@onready var _title := $Panel/Menu/Title as Label
@onready var _scores_button := $Panel/Menu/ScoresButton as Button
@onready var _settings_button := $Panel/Menu/SettingsButton as Button
@onready var _collection_button := $Panel/Menu/CollectionButton as Button
## Issue #105: replaying the played tutorial belongs to the menu the player opens when
## they want to DO something, not to the audio settings screen behind it.
@onready var _tutorial_button := $Panel/Menu/TutorialButton as Button
## One button rather than a list: the game ships two languages, so tapping the row is the
## whole interaction. It shows the language it is IN, not the one it would switch to.
@onready var _language_button := $Panel/Menu/LanguageButton as Button
@onready var _menu_button := $Panel/Menu/MenuButton as Button
@onready var _close_button := $CloseButton as Button

func _ready() -> void:
	size = Vector2(160.0, 320.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_font(self)
	_style_panel()
	_style_menu_button(_scores_button, NEON_PINK)
	_style_menu_button(_settings_button, NEON_YELLOW)
	_style_menu_button(_collection_button, NEON_CYAN)
	_style_menu_button(_tutorial_button, NEON_PINK)
	_style_menu_button(_language_button, NEON_YELLOW)
	_style_menu_button(_menu_button, NEON_CYAN)
	_style_close_button(_close_button)
	_connect_button(_scores_button, _open_scores)
	_connect_button(_settings_button, _open_settings)
	_connect_button(_collection_button, _open_collection)
	_connect_button(_tutorial_button, _start_tutorial)
	_connect_button(_language_button, _cycle_language)
	_connect_button(_menu_button, _return_to_menu)
	_connect_button(_close_button, hide_overlay)
	_refresh_tutorial_button()
	_refresh_language_button()
	visible = editor_preview_visible if Engine.is_editor_hint() else false

func show_overlay() -> void:
	# Whether the tutorial can be replayed depends on whether a run is held, which changes
	# between one opening of this menu and the next.
	_refresh_tutorial_button()
	_refresh_language_button()
	visible = true

func hide_overlay() -> void:
	visible = false
	closed.emit()

func toggle_overlay() -> void:
	if not visible:
		_refresh_tutorial_button()
	visible = not visible

## Greyed out while a run is held: the tutorial seals the player's campaign off and starts
## its own, and it will not do that over a run in progress (see Tutorial.can_start).
func _refresh_tutorial_button() -> void:
	if _tutorial_button == null or Engine.is_editor_hint():
		return
	_tutorial_button.disabled = not Tutorial.can_start()

## The row reads "LANGUE" with the flag of the language it is IN pinned to its right edge.
##
## The flag is a child TextureRect rather than the Button's own icon: an icon participates
## in the Button's internal layout and would shove the centred label off its middle, which
## is exactly the kind of not-quite-centred text this UI has been cleaned of.
##
## While a flag is missing (the art is authored separately) the row falls back to the plain
## "LANGUAGE  FR" text, so the language is always readable and never a blank strip.
func _refresh_language_button() -> void:
	if _language_button == null:
		return
	_language_button.auto_translate_mode = Control.AUTO_TRANSLATE_MODE_DISABLED
	var code := "en" if Engine.is_editor_hint() else Language.current()
	var flag: Texture2D = Language.flag_for(code)
	_language_button.text = tr("LANGUAGE") if flag != null \
		else "%s  %s" % [tr("LANGUAGE"), Language.label_for(code)]
	var icon := _language_button.get_node_or_null("Flag") as TextureRect
	if flag == null:
		if icon != null:
			icon.visible = false
		return
	if icon == null:
		icon = TextureRect.new()
		icon.name = "Flag"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_language_button.add_child(icon)
	icon.visible = true
	icon.texture = flag
	# The flag's OWN size, 1:1. The two flags are authored at different sizes, and forcing
	# them to a shared box would resample one of them — pixel art in this project is always
	# blitted at native resolution, never scaled to fit.
	var flag_size := flag.get_size()
	icon.size = flag_size
	# Right edge, on the button's middle line. Rounded: a fractional offset lands the art
	# off the pixel grid and blurs it.
	icon.position = Vector2(
		_language_button.custom_minimum_size.x - flag_size.x - LANGUAGE_FLAG_INSET,
		roundf((_language_button.custom_minimum_size.y - flag_size.y) * 0.5))

## Switching re-renders every Control on screen by itself (Godot translates `text` at draw
## time), so there is nothing to rebuild here — except this button, whose text was built by
## hand and is therefore the one thing auto-translation cannot fix.
func _cycle_language() -> void:
	if Engine.is_editor_hint():
		return
	Language.choose(Language.next_of(Language.current()))
	_refresh_language_button()

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

func _style_panel() -> void:
	if _panel == null:
		return
	var panel_style: StyleBoxFlat = Assets.neon_panel_style(NEON_CYAN, 8.0)
	panel_style.shadow_color = Color(NEON_PINK.r, NEON_PINK.g, NEON_PINK.b, 0.42)
	panel_style.shadow_size = 3
	_panel.add_theme_stylebox_override("panel", panel_style)
	if _title != null:
		_title.add_theme_color_override("font_color", NEON_CYAN)
		_title.add_theme_color_override("font_outline_color", Color.BLACK)
		_title.add_theme_constant_override("outline_size", 1)

func _style_menu_button(button: Button, border_color: Color) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(104.0, 20.0)
	Assets.start_menu_button_style(button, border_color, 7)
	button.pivot_offset = button.custom_minimum_size * 0.5
	if not button.button_down.is_connected(_on_menu_button_down):
		button.button_down.connect(_on_menu_button_down.bind(button))
		button.button_up.connect(_on_menu_button_up.bind(button))

func _style_close_button(button: Button) -> void:
	if button == null:
		return
	button.text = "X"
	button.position = Vector2(_panel.position.x + _panel.size.x - 16.0, _panel.position.y + 3.0)
	button.size = Vector2(12.0, 12.0)
	button.custom_minimum_size = Vector2.ZERO
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 7)
	button.add_theme_color_override("font_color", NEON_CYAN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(String(state), StyleBoxEmpty.new())
	button.pivot_offset = button.size * 0.5
	if not button.button_down.is_connected(_on_menu_button_down):
		button.button_down.connect(_on_menu_button_down.bind(button))
		button.button_up.connect(_on_menu_button_up.bind(button))

func _on_menu_button_down(button: Button) -> void:
	if not is_instance_valid(button):
		return
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * 0.92, 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_menu_button_up(button: Button) -> void:
	if not is_instance_valid(button):
		return
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, 0.1) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _open_scores() -> void:
	scores_requested.emit()
	if Engine.is_editor_hint():
		return
	SceneNav.push_current_scene(true)
	SceneNav.change_to(SCORES_SCENE)

func _open_settings() -> void:
	settings_requested.emit()
	if Engine.is_editor_hint():
		return
	SceneNav.push_current_scene(true)
	SceneNav.change_to(SETTINGS_SCENE)

func _open_collection() -> void:
	collection_requested.emit()
	if Engine.is_editor_hint():
		return
	SceneNav.push_current_scene(true)
	SceneNav.change_to(COLLECTION_SCENE)

## The overlay goes away FIRST: the tutorial drives the game from the Pacte onwards and
## must not open behind the modal menu that asked for it.
func _start_tutorial() -> void:
	tutorial_requested.emit()
	if Engine.is_editor_hint():
		return
	hide_overlay()
	Tutorial.start()

func _return_to_menu() -> void:
	return_to_menu_requested.emit()
	if Engine.is_editor_hint():
		return
	SceneNav.go_to_menu(MENU_SCENE)
