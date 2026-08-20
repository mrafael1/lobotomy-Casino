class_name PowerReplacementPicker
extends Control

## Modal used by both Pacte and the between-machine Power route.  The run store
## owns the pending candidate and only charges it after `power_selected` is
## confirmed by the host scene.

signal power_selected(power_id: String)
signal cancelled

const CANVAS_SIZE := Vector2(160.0, 320.0)
const PANEL_RECT := Rect2(12.0, 76.0, 136.0, 168.0)
const GOLD := Color(1.0, 0.84, 0.38)
const CYAN := Color(0.42, 1.0, 0.95)
const RED := Color(1.0, 0.35, 0.42)
const TEXT := Color(0.88, 0.98, 1.0)
const MUTED := Color(0.62, 0.70, 0.78)

var _candidate_id := ""
var _options: Array[String] = []
var _used := false

func present(candidate_id: String, options: Array[String]) -> void:
	_candidate_id = PacteCards.normalise_card_id(candidate_id)
	_options = []
	for value in options:
		var power_id := PacteCards.normalise_card_id(String(value))
		if not _options.has(power_id):
			_options.append(power_id)
	_used = false
	_build()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process_input(true)

func _build() -> void:
	for child in get_children():
		child.queue_free()
	size = CANVAS_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 80
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.size = CANVAS_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := Panel.new()
	panel.name = "ReplacementPanel"
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", ButtonKit.neon_panel_style(GOLD, 5.0))
	add_child(panel)
	_add_label(panel, "REPLACE POWER", Rect2(5.0, 8.0, 126.0, 12.0), 7, GOLD)
	var candidate_entry := PacteCards.card(_candidate_id)
	var candidate_name := String(candidate_entry.get("name", _candidate_id)).to_upper()
	_add_label(panel, "NEW: %s" % candidate_name, Rect2(5.0, 24.0, 126.0, 11.0), 5, CYAN)
	_add_label(panel, "CHOOSE A POWER TO REMOVE", Rect2(5.0, 38.0, 126.0, 10.0), 4, MUTED)
	var y := 52.0
	for power_id in _options:
		var entry := PacteCards.card(power_id)
		var name := String(entry.get("name", power_id)).to_upper()
		var button := Button.new()
		button.name = "Remove_%s" % power_id
		button.position = Vector2(8.0, y)
		button.size = Vector2(120.0, 19.0)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.text = name
		button.add_theme_font_size_override("font_size", 5)
		button.add_theme_color_override("font_color", TEXT)
		button.add_theme_color_override("font_hover_color", CYAN)
		button.add_theme_color_override("font_pressed_color", GOLD)
		if Assets.font() != null:
			button.add_theme_font_override("font", Assets.font())
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state,
				ButtonKit.neon_panel_style(CYAN if state == "hover" else MUTED, 2.0))
		button.pressed.connect(_on_power_pressed.bind(power_id))
		panel.add_child(button)
		y += 22.0
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.position = Vector2(37.0, 143.0)
	cancel.size = Vector2(62.0, 18.0)
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.text = "CANCEL"
	cancel.add_theme_font_size_override("font_size", 5)
	cancel.add_theme_color_override("font_color", RED)
	if Assets.font() != null:
		cancel.add_theme_font_override("font", Assets.font())
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		cancel.add_theme_stylebox_override(state,
			ButtonKit.neon_panel_style(RED if state != "disabled" else MUTED, 2.0))
	cancel.pressed.connect(_on_cancel_pressed)
	panel.add_child(cancel)

func _add_label(parent: Control, text: String, rect: Rect2, font_size: int,
		color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Assets.font() != null:
		label.add_theme_font_override("font", Assets.font())
	parent.add_child(label)
	return label

func _on_power_pressed(power_id: String) -> void:
	if _used:
		return
	_used = true
	power_selected.emit(power_id)

func _on_cancel_pressed() -> void:
	if _used:
		return
	_used = true
	cancelled.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()
