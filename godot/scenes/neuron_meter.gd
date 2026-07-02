class_name NeuronMeter
extends Control

## Campaign neuron meter (issue #38) — replaces the raw "NEURONS: n/n" text with the
## 11-frame desaturation sheet (assets/images/neurons_meter.png): frame 0 = all
## neurons alive (colored), each frame one neuron grayer, last frame = dead mind.
## The frame is wired to campaign neurons LOST (campaignNeuronsMax - Left) and
## self-refreshes on MetaStateStore.meta_changed.
##
## The art renders at NATIVE resolution — never resampled: each 59px frame draws
## at 59 canvas px (engine scale 1.0), then only the whole-canvas presentation
## scale applies. asset_scale stays as an escape hatch for oversized future sheets.
##
## Autoloads are resolved through /root (not bare identifiers): this script is a
## registered global class, so it can be compiled before the autoloads exist
## (e.g. by the headless test runner).

@export var frame_count: int = 11
## Divisor applied to the sheet's px (1 = native canvas px, no scaling).
@export var asset_scale: float = 1.0
@export var sheet_asset: String = "neurons_meter.png"
@export var tint: Color = Color.WHITE

var _sprite: Sprite2D = null

## Builds a meter centred on `center` (source px) and parents it. The scenes keep
## their authored `neuron_number` Label as the editor placeholder; this rides on top
## at runtime. Size comes from the art (authored px / asset_scale), never a target.
static func attach(parent: Node, center: Vector2) -> NeuronMeter:
	var m := NeuronMeter.new()
	parent.add_child(m) # _ready sizes the control to the authored frame
	m.position = center - m.size * 0.5
	return m

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return
	var tex := assets.call("texture", sheet_asset, true) as Texture2D
	if tex == null:
		return
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.hframes = maxi(1, frame_count)
	_sprite.centered = false
	_sprite.modulate = tint
	var frame_w := float(tex.get_width()) / float(maxi(1, frame_count))
	# Native px, no resampling to a target size. NEAREST keeps the pixels exact.
	_sprite.scale = Vector2.ONE / maxf(1.0, asset_scale)
	size = Vector2(frame_w, float(tex.get_height())) / maxf(1.0, asset_scale)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	var meta := get_node_or_null("/root/MetaStateStore")
	if meta != null and not Engine.is_editor_hint():
		var cb := Callable(self, "refresh")
		if not meta.is_connected("meta_changed", cb):
			meta.connect("meta_changed", cb)
	refresh()

func refresh() -> void:
	if _sprite == null:
		return
	var lost := 0
	var meta := get_node_or_null("/root/MetaStateStore")
	if meta != null and not Engine.is_editor_hint():
		lost = int(meta.get("campaignNeuronsMax")) - int(meta.get("campaignNeuronsLeft"))
	_sprite.frame = clampi(lost, 0, maxi(1, frame_count) - 1)
