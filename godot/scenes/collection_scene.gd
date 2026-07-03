@tool
extends Control

const MENU_SCENE := "res://scenes/start_menu_scene.tscn"
const POWER_ITEMS := [
	{ "id": "power_reroll", "name": "Reroll", "icon": "powers/power_reroll.png", "description": "Unlocked during the run by lucidity coin restores." },
	{ "id": "perm_shift", "name": "Shift", "icon": "powers/power_shift.png", "description": "Requires 1 Lucidity Coin." },
	{ "id": "perm_memory", "name": "Memory", "icon": "powers/power_memory.png", "description": "Requires 1 Lucidity Coin." },
	{ "id": "pos_learning", "name": "Learning", "icon": "symbols/book_32.png", "description": "Requires 300 Lucidity Coins." },
	{ "id": "pos_enlightenment", "name": "Hallucination", "icon": "ui/power_coin.png", "description": "Requires 350 Lucidity Coins." },
	{ "id": "pos_smart_save", "name": "Smart Save", "icon": "ui/coin.png", "description": "Requires 220 Lucidity Coins." },
]

@export var editor_preview_unlocked := false:
	set(value):
		editor_preview_unlocked = value
		_rebuild_grid()

@onready var _grid := $Panel/Rows/Grid as GridContainer
@onready var _modal := $UnlockModal as PanelContainer
@onready var _modal_name := $UnlockModal/Rows/NameLabel as Label
@onready var _modal_description := $UnlockModal/Rows/DescriptionLabel as Label
@onready var _modal_close := $UnlockModal/Rows/CloseButton as Button
@onready var _back_button := $Panel/Rows/BackButton as Button

func _ready() -> void:
	_apply_font(self)
	_connect_button(_modal_close, _hide_modal)
	_connect_button(_back_button, _go_back)
	_style_button(_modal_close, true)
	_style_button(_back_button, true)
	_rebuild_grid()
	_hide_modal()

func _rebuild_grid() -> void:
	if not is_inside_tree() or _grid == null:
		return
	for child in _grid.get_children():
		child.queue_free()
	for item in POWER_ITEMS:
		_grid.add_child(_make_item_button(item))

func _make_item_button(item: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(38.0, 42.0)
	button.text = String(item["name"]).to_upper()
	button.icon = Assets.texture(String(item["icon"]), true)
	button.expand_icon = true
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 5)
	var font := Assets.font()
	if font != null:
		button.add_theme_font_override("font", font)
	Assets.skin_sheet_button(button, "ui/green_button.png", 4)
	var unlocked := _is_unlocked(String(item["id"]))
	button.modulate = Color.WHITE if unlocked else Color(0.38, 0.38, 0.42, 0.78)
	button.pressed.connect(_show_item_modal.bind(item))
	return button

func _is_unlocked(item_id: String) -> bool:
	if Engine.is_editor_hint():
		return editor_preview_unlocked
	if item_id == "power_reroll":
		return true
	return MetaStateStore.ownedPermanents.has(item_id)

func _show_item_modal(item: Dictionary) -> void:
	inject_modal_data(String(item["name"]), String(item["description"]))

func inject_modal_data(item_name: String, unlock_description: String) -> void:
	if _modal_name != null:
		_modal_name.text = item_name.to_upper()
	if _modal_description != null:
		_modal_description.text = unlock_description
	if _modal != null:
		_modal.visible = true

func _hide_modal() -> void:
	if _modal != null:
		_modal.visible = false

func _connect_button(button: Button, cb: Callable) -> void:
	if button == null:
		return
	if not button.pressed.is_connected(cb):
		button.pressed.connect(cb)

func _style_button(button: Button, negative := false) -> void:
	if button == null:
		return
	button.add_theme_font_size_override("font_size", 8)
	if negative:
		Assets.skin_negative_button(button)
	else:
		Assets.skin_sheet_button(button, "ui/green_button.png", 4)

func _apply_font(node: Node) -> void:
	var font := Assets.font()
	for child in node.get_children():
		if child is Label and font != null:
			(child as Label).add_theme_font_override("font", font)
		elif child is Button and font != null:
			(child as Button).add_theme_font_override("font", font)
		_apply_font(child)

func _go_back() -> void:
	if Engine.is_editor_hint():
		return
	SceneNav.go_back(MENU_SCENE)
