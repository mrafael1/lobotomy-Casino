@tool
class_name OfferSlotPreview
extends Control

## Editor-only placeholder renderer for authored dealer offer slots.

const ITEM_ICONS := {
	"cons_focus": "items/generated/serum.png",
	"cons_cigarette": "items/generated/tobacco.png",
	"cons_white_powder": "items/generated/white_powder.png",
	"item_energy_drink": "items/generated/energy_drink.png",
	"item_cocktail": "items/generated/cocktail.png",
	"item_water": "items/generated/water.png",
	"item_pill": "items/generated/red_pill.png",
}
const FALLBACK_ICON := "items/consumable_placeholder.png"
const PLACEHOLDER_TINT := Color(1.0, 1.0, 1.0, 0.62)
const OUTLINE_COLOR := Color(0.13, 0.77, 0.37, 0.9)

@export var draw_editor_placeholder := true:
	set(value):
		draw_editor_placeholder = value
		queue_redraw()

@export var placeholder_item_id := "item_water":
	set(value):
		placeholder_item_id = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint() or not draw_editor_placeholder:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var texture := _placeholder_texture()
	if texture != null:
		draw_texture_rect(texture, rect, false, PLACEHOLDER_TINT)
	else:
		draw_rect(rect.grow(-1.0), Color(0.13, 0.77, 0.37, 0.28), true)
	draw_rect(rect, OUTLINE_COLOR, false, 1.0)

func _placeholder_texture() -> Texture2D:
	var rel := String(ITEM_ICONS.get(placeholder_item_id, FALLBACK_ICON))
	return Assets.texture(rel, true)
