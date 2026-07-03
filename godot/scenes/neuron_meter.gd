class_name NeuronMeter
extends Control

## Campaign neuron meter (issue #38) — replaces the raw "NEURONS: n/n" text with the
## 11-frame desaturation sheet (assets/images/neurons_meter.png): frame 0 = all
## neurons alive (colored), each frame one neuron grayer, last frame = dead mind.
## The frame is wired to campaign neurons LOST (campaignNeuronsMax - Left) and
## self-refreshes on MetaStateStore.meta_changed.
##
## A numeric "left/max" count renders under the art (show_count) so the meter reads
## exactly even when the desaturation step is subtle.
##
## The art renders at NATIVE resolution — never resampled: each 59px frame draws
## at 59 canvas px (engine scale 1.0), then only the whole-canvas presentation
## scale applies. asset_scale stays as an escape hatch for oversized future sheets.
##
## Autoloads are resolved through /root (not bare identifiers): this script is a
## registered global class, so it can be compiled before the autoloads exist
## (e.g. by the headless test runner).

# The authored art leaves ~6 transparent px at the bottom of each 59px frame
# (opaque bbox y9-53, measured with pngjs) — the count label tucks into that gap.
const COUNT_LABEL_HEIGHT := 8.0
const COUNT_LABEL_OVERLAP := 6.0
const LOSS_ANIM_DELAY := 0.45
const LOSS_ANIM_POP_SCALE := 1.25

@export var frame_count: int = 11
## Divisor applied to the sheet's px (1 = native canvas px, no scaling).
@export var asset_scale: float = 1.0
@export var sheet_asset: String = "neurons_meter.png"
@export var tint: Color = Color.WHITE
## Renders the numeric "left/max" count under the meter art.
@export var show_count: bool = true
@export var count_color: Color = Color(0.8, 0.95, 1.0)
@export var count_font_size: int = 7

var _sprite: Sprite2D = null
var _count_label: Label = null
var _loss_tween: Tween = null

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
	var frame_h := float(tex.get_height())
	# Native px, no resampling to a target size. NEAREST keeps the pixels exact.
	_sprite.scale = Vector2.ONE / maxf(1.0, asset_scale)
	size = Vector2(frame_w, frame_h) / maxf(1.0, asset_scale)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	if show_count:
		_build_count_label(frame_w / maxf(1.0, asset_scale), frame_h / maxf(1.0, asset_scale))
	var meta := get_node_or_null("/root/MetaStateStore")
	if meta != null and not Engine.is_editor_hint():
		var cb := Callable(self, "refresh")
		if not meta.is_connected("meta_changed", cb):
			meta.connect("meta_changed", cb)
	refresh()

func _build_count_label(frame_w: float, frame_h: float) -> void:
	_count_label = Label.new()
	_count_label.name = "CountLabel"
	_count_label.position = Vector2(0.0, frame_h - COUNT_LABEL_OVERLAP)
	_count_label.size = Vector2(frame_w, COUNT_LABEL_HEIGHT)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.add_theme_font_size_override(&"font_size", count_font_size)
	_count_label.add_theme_color_override(&"font_color", count_color)
	_count_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_count_label.add_theme_constant_override(&"outline_size", 1)
	var assets := get_node_or_null("/root/Assets")
	if assets != null:
		var font := assets.call("font") as Font
		if font != null:
			_count_label.add_theme_font_override(&"font", font)
	add_child(_count_label)
	# The count extends the control below the art so callers can reserve its height.
	size.y = frame_h - COUNT_LABEL_OVERLAP + COUNT_LABEL_HEIGHT

func refresh() -> void:
	if _sprite == null:
		return
	_sprite.frame = clampi(_neurons_lost(), 0, maxi(1, frame_count) - 1)
	_refresh_count()

## Flatline-overlay losing animation: shows the meter as it stood BEFORE this run's
## neuron was spent, then pops and switches the frame to reflect the lost neuron.
func play_loss_animation() -> void:
	if _sprite == null:
		return
	var lost := _neurons_lost()
	_sprite.frame = clampi(lost - 1, 0, maxi(1, frame_count) - 1)
	_refresh_count()
	pivot_offset = size * 0.5
	if _loss_tween != null and _loss_tween.is_running():
		_loss_tween.kill()
	_loss_tween = create_tween()
	_loss_tween.tween_interval(LOSS_ANIM_DELAY)
	_loss_tween.tween_property(self, "scale", Vector2.ONE * LOSS_ANIM_POP_SCALE, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_loss_tween.tween_callback(func() -> void:
		if _sprite != null:
			_sprite.frame = clampi(lost, 0, maxi(1, frame_count) - 1)
	)
	_loss_tween.tween_property(self, "scale", Vector2.ONE, 0.16)

func _neurons_lost() -> int:
	var meta := get_node_or_null("/root/MetaStateStore")
	if meta == null or Engine.is_editor_hint():
		return 0
	return int(meta.get("campaignNeuronsMax")) - int(meta.get("campaignNeuronsLeft"))

func _refresh_count() -> void:
	if _count_label == null:
		return
	var meta := get_node_or_null("/root/MetaStateStore")
	if meta == null or Engine.is_editor_hint():
		_count_label.text = ""
		return
	_count_label.text = "%d/%d" % [int(meta.get("campaignNeuronsLeft")), int(meta.get("campaignNeuronsMax"))]
