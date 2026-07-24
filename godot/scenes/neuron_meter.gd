class_name NeuronMeter
extends Control

## Campaign health meter. The idle composition is a 34-frame 64px animation of
## the three campaign neurons; a matching three-frame death sheet is overlaid on
## the neuron position spent by the current flatline. The numeric count remains
## authoritative for saves and for campaigns with fewer than three health left.
##
## Autoloads are resolved through /root so this class can still be parsed by the
## headless test runner before the project autoloads are available.

const IDLE_FRAME_COUNT := 34
const DEATH_FRAME_COUNT := 3
const IDLE_FRAME_TIME := 0.08
const COUNT_LABEL_HEIGHT := 8.0
const COUNT_LABEL_OVERLAP := 6.0
const LOSS_ANIM_DELAY := 0.45
const LOSS_ANIM_POP_SCALE := 1.25

@export var frame_count: int = IDLE_FRAME_COUNT
## Divisor applied to the sheet's px (1 = native canvas px, no scaling).
@export var asset_scale: float = 1.0
@export var sheet_asset: String = "neurons_animation.png"
@export var death_sheet_assets: Array[String] = [
	"1st_neuron_death.png", "2nd_neuron_death.png", "3rd_neuron_death.png",
]
@export var tint: Color = Color.WHITE
@export var show_count: bool = true
@export var count_color: Color = Color(0.8, 0.95, 1.0)
@export var count_font_size: int = 7

var _sprite: Sprite2D = null
var _death_sprite: Sprite2D = null
var _count_label: Label = null
var _idle_timer: Timer = null
var _loss_tween: Tween = null

## Builds a meter centred on `center` (source px) and parents it. The scenes keep
## their authored `neuron_number` Label as an editor placeholder; this rides on top
## at runtime. Size comes from the authored frame, never from a target rectangle.
static func attach(parent: Node, center: Vector2) -> NeuronMeter:
	var meter := NeuronMeter.new()
	parent.add_child(meter)
	meter.position = center - meter.size * 0.5
	return meter

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return
	var tex := assets.call("texture", sheet_asset, true) as Texture2D
	if tex == null:
		return
	var scale_factor := maxf(1.0, asset_scale)
	var idle_frames := maxi(1, frame_count)
	var frame_w := float(tex.get_width()) / float(idle_frames)
	var frame_h := float(tex.get_height())

	_sprite = Sprite2D.new()
	_sprite.name = "Idle"
	_sprite.texture = tex
	_sprite.hframes = idle_frames
	_sprite.centered = false
	_sprite.modulate = tint
	_sprite.scale = Vector2.ONE / scale_factor
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

	size = Vector2(frame_w, frame_h) / scale_factor
	if show_count:
		_build_count_label(size.x, size.y)

	_death_sprite = Sprite2D.new()
	_death_sprite.name = "Death"
	_death_sprite.centered = false
	_death_sprite.hframes = DEATH_FRAME_COUNT
	_death_sprite.scale = Vector2.ONE / scale_factor
	_death_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_death_sprite.visible = false
	add_child(_death_sprite)

	_idle_timer = Timer.new()
	_idle_timer.name = "IdleTimer"
	_idle_timer.wait_time = IDLE_FRAME_TIME
	_idle_timer.one_shot = false
	_idle_timer.timeout.connect(_advance_idle_frame)
	add_child(_idle_timer)
	_idle_timer.start()

	var meta := get_node_or_null("/root/MetaStateStore")
	if meta != null and not Engine.is_editor_hint():
		var callback := Callable(self, "refresh")
		if not meta.is_connected("meta_changed", callback):
			meta.connect("meta_changed", callback)
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
	size.y = frame_h - COUNT_LABEL_OVERLAP + COUNT_LABEL_HEIGHT

func _advance_idle_frame() -> void:
	if _sprite == null or _death_sprite == null or _death_sprite.visible:
		return
	_sprite.frame = (_sprite.frame + 1) % maxi(1, frame_count)

func refresh() -> void:
	_refresh_count()

## Flatline-overlay losing animation. The idle composition remains underneath so
## the two surviving neurons stay visible while the matching neuron dies.
func play_loss_animation() -> void:
	if _sprite == null or _death_sprite == null:
		return
	var lost := clampi(_neurons_lost(), 1, DEATH_FRAME_COUNT)
	var assets := get_node_or_null("/root/Assets")
	if assets == null or lost > death_sheet_assets.size():
		return
	var death_tex := assets.call("texture", death_sheet_assets[lost - 1], true) as Texture2D
	if death_tex == null:
		return
	_death_sprite.texture = death_tex
	_death_sprite.hframes = DEATH_FRAME_COUNT
	_death_sprite.frame = 0
	_death_sprite.visible = true
	_refresh_count()
	pivot_offset = size * 0.5
	if _loss_tween != null and _loss_tween.is_valid():
		_loss_tween.kill()
	_loss_tween = create_tween()
	_loss_tween.tween_interval(LOSS_ANIM_DELAY)
	_loss_tween.tween_method(_set_death_frame, 0.0, float(DEATH_FRAME_COUNT - 1), 0.10)
	_loss_tween.tween_property(self, "scale", Vector2.ONE * LOSS_ANIM_POP_SCALE, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_loss_tween.tween_callback(_finish_loss_animation)
	_loss_tween.tween_property(self, "scale", Vector2.ONE, 0.16)

func _set_death_frame(value: float) -> void:
	if _death_sprite != null:
		_death_sprite.frame = clampi(roundi(value), 0, DEATH_FRAME_COUNT - 1)

func _finish_loss_animation() -> void:
	if _death_sprite != null:
		_death_sprite.visible = false

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
