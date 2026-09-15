extends Node

## Layout units remain stable while canvas_items renders art at display resolution.
## The centered safe area owns gameplay; the decorative backdrop covers all overscan.
const SAFE_SIZE := Vector2(160.0, 320.0)
const BACKDROP := "res://assets/images/presentation/casino_overscan.png"
var _backdrop: TextureRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = -1000
	add_child(layer)
	_backdrop = TextureRect.new()
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if ResourceLoader.exists(BACKDROP):
		_backdrop.texture = load(BACKDROP)
	layer.add_child(_backdrop)
	get_tree().scene_changed.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()

func safe_origin(viewport_size: Vector2) -> Vector2:
	return (viewport_size - SAFE_SIZE).max(Vector2.ZERO) * 0.5

func _layout() -> void:
	var viewport := get_viewport()
	var visible_size := viewport.get_visible_rect().size
	var origin := safe_origin(visible_size)
	viewport.canvas_transform = Transform2D(0.0, origin)
	_backdrop.position = Vector2.ZERO
	_backdrop.size = visible_size
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene is Control:
		var control := scene as Control
		control.set_anchors_preset(Control.PRESET_TOP_LEFT)
		control.size = SAFE_SIZE
	for node in scene.find_children("*", "Control", true, false):
		var control := node as Control
		if control.get_parent() is Control:
			continue
		if control.anchor_right == 1.0 and control.anchor_bottom == 1.0:
			control.set_anchors_preset(Control.PRESET_TOP_LEFT)
			control.position = Vector2.ZERO
			control.size = SAFE_SIZE
	# CanvasLayers bypass the default canvas transform (the Lab uses one for UI).
	for node in scene.find_children("*", "CanvasLayer", true, false):
		var canvas := node as CanvasLayer
		if not canvas.has_meta(&"safe_base_offset"):
			canvas.set_meta(&"safe_base_offset", canvas.offset)
		canvas.offset = Vector2(canvas.get_meta(&"safe_base_offset")) + origin
