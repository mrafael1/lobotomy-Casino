class_name DragShadow
extends RefCounted

## Drop shadow under an item/card while it is being dragged. Builds a black
## silhouette from every visible TextureRect inside the item (nested one level or
## more), parents it to the dragged node so it follows every drag update, and
## draws it behind the item. remove_drag_shadow() clears it when the drag ends or
## is cancelled; adding twice replaces the previous shadow.
const DRAG_SHADOW_NAME := "DragShadow"
const DRAG_SHADOW_OFFSET := Vector2(2.0, 3.0)
const DRAG_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.5)

static func add_drag_shadow(item: Control) -> void:
	if item == null or not is_instance_valid(item):
		return
	remove_drag_shadow(item)
	var shadow := Control.new()
	shadow.name = DRAG_SHADOW_NAME
	shadow.position = DRAG_SHADOW_OFFSET
	shadow.size = item.size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.modulate = DRAG_SHADOW_COLOR
	shadow.show_behind_parent = true
	_copy_shadow_textures(item, item, shadow)
	if item is TextureRect and (item as TextureRect).texture != null:
		shadow.add_child(_shadow_texture_copy(item as TextureRect, Vector2.ZERO))
	if shadow.get_child_count() == 0:
		shadow.free()
		return
	item.add_child(shadow)
	item.move_child(shadow, 0)

static func remove_drag_shadow(item: Control) -> void:
	if item == null or not is_instance_valid(item):
		return
	var shadow := item.get_node_or_null(NodePath(DRAG_SHADOW_NAME))
	if shadow != null:
		shadow.queue_free()

static func _copy_shadow_textures(node: Control, base: Control, shadow: Control) -> void:
	for child in node.get_children():
		if not (child is Control) or not (child as Control).visible:
			continue
		if child is TextureRect and (child as TextureRect).texture != null:
			var offset: Vector2 = (child as Control).global_position - base.global_position
			shadow.add_child(_shadow_texture_copy(child as TextureRect, offset))
		_copy_shadow_textures(child as Control, base, shadow)

static func _shadow_texture_copy(source: TextureRect, offset: Vector2) -> TextureRect:
	var copy := TextureRect.new()
	copy.texture = source.texture
	copy.position = offset
	copy.size = source.size
	copy.expand_mode = source.expand_mode
	copy.stretch_mode = source.stretch_mode
	copy.texture_filter = source.texture_filter
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return copy

