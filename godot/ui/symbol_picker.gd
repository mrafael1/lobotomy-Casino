class_name SymbolPicker
extends RefCounted

## The symbol-choosing panel: authored five-slot art when the choice happens to be five
## symbols wide, a drawn fallback otherwise.

const SYMBOL_PICKER_FRAME_REL := "ui/symbol_chosing.png"
const SYMBOL_PICKER_TITLE_COLOR := Color(0.72, 1.0, 0.65)
const SYMBOL_PICKER_PANEL_COLOR := Color(0.05, 0.03, 0.1, 0.94)
const SYMBOL_PICKER_SLOT_COLOR := Color(0.18, 0.13, 0.26, 0.95)
const SYMBOL_PICKER_SLOT_BORDER := Color(0.45, 0.38, 0.62, 0.9)
const SYMBOL_PICKER_SLOT_HOVER := Color(0.28, 0.2, 0.42, 0.9)
const SYMBOL_PICKER_SLOT_PRESSED := Color(0.45, 0.38, 0.62, 0.95)
const SYMBOL_PICKER_ICON_SIZE := 16.0
const SYMBOL_PICKER_FIVE_SLOT_SOURCE_RECTS: Array[Rect2] = [
	Rect2(40.0, 56.0, 88.0, 96.0),
	Rect2(152.0, 56.0, 88.0, 96.0),
	Rect2(264.0, 56.0, 88.0, 96.0),
	Rect2(376.0, 56.0, 88.0, 96.0),
	Rect2(488.0, 56.0, 88.0, 96.0),
]


static func build_symbol_picker_panel(parent: Control, symbols: Array[String], title_text: String, rect: Rect2,
		picked: Callable, cancelled: Callable, use_five_slot_art: bool = false,
		show_title: bool = true, show_cancel: bool = true) -> Control:
	var frame_texture := UiKit.texture(SYMBOL_PICKER_FRAME_REL)
	var uses_frame := use_five_slot_art and symbols.size() == 5 and frame_texture != null

	var panel := Control.new()
	panel.name = "SymbolPickerPanel"
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)

	var content := Rect2(0.0, 12.0, rect.size.x, rect.size.y - 12.0)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = SYMBOL_PICKER_PANEL_COLOR
	background.position = Vector2.ZERO
	background.size = Vector2.ZERO if uses_frame else rect.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(background)

	if uses_frame:
		var frame := TextureRect.new()
		frame.name = "Frame"
		frame.texture = frame_texture
		frame.position = content.position
		frame.size = Vector2(float(frame_texture.get_width()), float(frame_texture.get_height()))
		frame.scale = Vector2(content.size.x / frame.size.x, content.size.y / frame.size.y)
		frame.stretch_mode = TextureRect.STRETCH_KEEP
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(frame)
	else:
		_build_symbol_picker_slots(panel, symbols.size(), content)

	if show_title:
		var title := Label.new()
		title.name = "TitleLabel"
		title.text = title_text
		title.position = Vector2(0.0, content.position.y - 5.0) if uses_frame else Vector2(0.0, 1.0)
		title.size = Vector2(rect.size.x, 11.0)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_theme_font_size_override("font_size", 7)
		title.add_theme_color_override("font_color", SYMBOL_PICKER_TITLE_COLOR)
		title.add_theme_color_override("font_outline_color", Color.BLACK)
		title.add_theme_constant_override("outline_size", 1)
		if UiKit.font() != null:
			title.add_theme_font_override("font", UiKit.font())
		panel.add_child(title)

	if show_cancel:
		var cancel := Button.new()
		cancel.name = "CancelButton"
		cancel.text = ""
		cancel.focus_mode = Control.FOCUS_NONE
		cancel.position = Vector2(rect.size.x - 12.0, content.position.y + 1.0) if uses_frame else Vector2(rect.size.x - 12.0, 1.0)
		cancel.size = Vector2(10.0, 10.0)
		cancel.add_theme_font_size_override("font_size", 6)
		if UiKit.font() != null:
			cancel.add_theme_font_override("font", UiKit.font())
		ButtonKit.skin_cancel_button(cancel)
		cancel.pressed.connect(func() -> void:
			if cancelled.is_valid():
				cancelled.call()
		)
		panel.add_child(cancel)

	var cell_w := content.size.x / float(maxi(1, symbols.size()))
	for i in symbols.size():
		var symbol_id := symbols[i]
		var button := Button.new()
		button.name = "SymbolButton%s" % symbol_id.capitalize()
		button.focus_mode = Control.FOCUS_NONE
		var button_rect := _symbol_picker_button_rect(i, cell_w, content, frame_texture, uses_frame)
		button.position = button_rect.position
		button.size = button_rect.size
		_apply_symbol_picker_button_style(button)
		button.pressed.connect(picked.bind(symbol_id))
		panel.add_child(button)

		var symbol_texture := UiKit.texture("symbols/%s.png" % symbol_id, true)
		if symbol_texture != null:
			var icon_size: float = SYMBOL_PICKER_ICON_SIZE if uses_frame else minf(SYMBOL_PICKER_ICON_SIZE, content.size.y - 8.0)
			var icon := Sprite2D.new()
			icon.name = "SymbolIcon%s" % symbol_id.capitalize()
			icon.texture = symbol_texture
			var icon_center := _symbol_picker_icon_center(i, cell_w, content, frame_texture, uses_frame)
			icon.position = icon_center - button.position
			icon.centered = true
			var texture_max_side := float(maxi(symbol_texture.get_width(), symbol_texture.get_height()))
			var icon_scale := icon_size / texture_max_side
			icon.scale = Vector2(icon_scale, icon_scale)
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			button.add_child(icon)

	return panel

static func _symbol_picker_button_rect(index: int, cell_w: float, content: Rect2, frame_texture: Texture2D,
		uses_frame: bool) -> Rect2:
	if uses_frame and frame_texture != null and index < SYMBOL_PICKER_FIVE_SLOT_SOURCE_RECTS.size():
		var slot_rect := _symbol_picker_slot_rect(index, content, frame_texture)
		var pad := Vector2(1.0, 1.0)
		return Rect2(slot_rect.position - pad, slot_rect.size + pad * 2.0)
	return Rect2(Vector2(content.position.x + float(index) * cell_w, content.position.y),
		Vector2(cell_w, content.size.y))

static func _symbol_picker_icon_center(index: int, cell_w: float, content: Rect2, frame_texture: Texture2D,
		uses_frame: bool) -> Vector2:
	if uses_frame and frame_texture != null and index < SYMBOL_PICKER_FIVE_SLOT_SOURCE_RECTS.size():
		return _symbol_picker_slot_rect(index, content, frame_texture).get_center()
	return Vector2(content.position.x + (float(index) + 0.5) * cell_w, content.position.y + content.size.y * 0.5)

static func _symbol_picker_slot_rect(index: int, content: Rect2, frame_texture: Texture2D) -> Rect2:
	var source_rect := SYMBOL_PICKER_FIVE_SLOT_SOURCE_RECTS[index]
	var scale := Vector2(content.size.x / float(frame_texture.get_width()),
		content.size.y / float(frame_texture.get_height()))
	return Rect2(content.position + source_rect.position * scale, source_rect.size * scale)

static func _build_symbol_picker_slots(parent: Control, count: int, content: Rect2) -> void:
	var cell_w := content.size.x / float(maxi(1, count))
	for i in count:
		var slot := ColorRect.new()
		slot.name = "Slot%d" % i
		slot.color = SYMBOL_PICKER_SLOT_COLOR
		slot.position = Vector2(content.position.x + float(i) * cell_w + 2.0, content.position.y + 5.0)
		slot.size = Vector2(maxf(1.0, cell_w - 4.0), maxf(1.0, content.size.y - 10.0))
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(slot)

static func _apply_symbol_picker_button_style(button: Button) -> void:
	var states := {
		"normal": _symbol_picker_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0)),
		"hover": _symbol_picker_style(SYMBOL_PICKER_SLOT_HOVER, SYMBOL_PICKER_SLOT_BORDER),
		"pressed": _symbol_picker_style(SYMBOL_PICKER_SLOT_PRESSED, Color(0.72, 1.0, 0.65, 1.0)),
		"focus": _symbol_picker_style(Color(0.0, 0.0, 0.0, 0.0), SYMBOL_PICKER_SLOT_BORDER),
		"disabled": _symbol_picker_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0)),
	}
	for state in states:
		button.add_theme_stylebox_override(String(state), states[state])
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

static func _symbol_picker_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	return style
