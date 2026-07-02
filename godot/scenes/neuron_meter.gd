class_name NeuronMeter
extends Control

## Campaign neuron meter (issue #38) — replaces the raw "NEURONS: n/n" text with the
## 11-frame desaturation sheet (assets/images/neurons_meter.png): frame 0 = all
## neurons alive (colored), each frame one neuron grayer, last frame = dead mind.
## The frame is wired to campaign neurons LOST (campaignNeuronsMax - Left) and
## self-refreshes on MetaStateStore.meta_changed.
##
## Autoloads are resolved through /root (not bare identifiers): this script is a
## registered global class, so it can be compiled before the autoloads exist
## (e.g. by the headless test runner).

@export var frame_count: int = 11
## On-screen size in source px (the 160x320 canvas).
@export var meter_size: float = 12.0
@export var sheet_asset: String = "neurons_meter.png"
@export var tint: Color = Color.WHITE

var _sprite: Sprite2D = null

## Builds a meter centred on `center` (source px) and parents it. The scenes keep
## their authored `neuron_number` Label as the editor placeholder; this rides on top
## at runtime.
static func attach(parent: Node, center: Vector2, size_px := 12.0) -> NeuronMeter:
	var m := NeuronMeter.new()
	m.meter_size = size_px
	m.position = center - Vector2(size_px, size_px) * 0.5
	m.size = Vector2(size_px, size_px)
	parent.add_child(m)
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
	_sprite.scale = Vector2(meter_size / frame_w, meter_size / float(tex.get_height()))
	# Large source art downscaled onto the canvas: mipmaps + linear keep it crisp.
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
