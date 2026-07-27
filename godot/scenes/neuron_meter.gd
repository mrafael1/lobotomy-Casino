class_name NeuronMeter
extends Control

## Campaign health meter. The idle composition is a 34-frame 64px animation of
## the three campaign neurons; matching three-frame death sheets are overlaid on
## each neuron position as it is spent. A completed death frame remains visible
## for the rest of the run, so the meter tells the story of the campaign's losses.
## The numeric count remains authoritative for saves and for campaigns with fewer
## than three health left.
##
## Autoloads are resolved through /root so this class can still be parsed by the
## headless test runner before the project autoloads are available.

const IDLE_FRAME_COUNT := 34
const DEATH_FRAME_COUNT := 3
# The idle sheet is one signal travelling through the three neurons. As neurons die the
# signal has less of that path left to run, so the loop stops short: the whole sheet while
# all three are alive, up to frame 28 with one lost, up to frame 15 with two. It still
# loops — the pulse simply turns back sooner.
const IDLE_LAST_FRAME_BY_LOSS: Array[int] = [IDLE_FRAME_COUNT - 1, 28, 15]
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
var _death_sprites: Array[Sprite2D] = []
var _count_label: Label = null
var _idle_timer: Timer = null
var _loss_tween: Tween = null
var _active_death_index: int = -1

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

	for index: int in range(death_sheet_assets.size()):
		var death_sprite := Sprite2D.new()
		death_sprite.name = "Death" if index == 0 else "Death%d" % (index + 1)
		death_sprite.centered = false
		death_sprite.hframes = DEATH_FRAME_COUNT
		death_sprite.scale = Vector2.ONE / scale_factor
		death_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		death_sprite.visible = false
		var death_tex := assets.call("texture", death_sheet_assets[index], true) as Texture2D
		death_sprite.texture = death_tex
		add_child(death_sprite)
		_death_sprites.append(death_sprite)
	_death_sprite = _death_sprites[0] if not _death_sprites.is_empty() else null

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
	if _sprite == null:
		return
	var last := _idle_last_frame()
	_sprite.frame = 0 if _sprite.frame >= last else _sprite.frame + 1

## Where the signal turns back, given how many neurons the campaign has lost.
func _idle_last_frame() -> int:
	var last := maxi(1, frame_count) - 1
	var lost := clampi(_neurons_lost(), 0, IDLE_LAST_FRAME_BY_LOSS.size() - 1)
	return clampi(IDLE_LAST_FRAME_BY_LOSS[lost], 0, last)

func refresh() -> void:
	_refresh_count()
	_sync_death_overlays()

## Flatline-overlay losing animation. The idle composition remains underneath so
## the two surviving neurons stay visible while the matching neuron dies.
func play_loss_animation() -> void:
	if _sprite == null or _death_sprites.is_empty():
		return
	var lost := clampi(_neurons_lost(), 1, _death_sprites.size())
	var current_index := lost - 1
	if current_index >= death_sheet_assets.size():
		return
	var current_sprite := _death_sprites[current_index]
	if current_sprite == null or current_sprite.texture == null:
		return
	for index: int in range(_death_sprites.size()):
		var death_sprite := _death_sprites[index]
		if index < current_index:
			death_sprite.frame = DEATH_FRAME_COUNT - 1
			death_sprite.visible = true
		elif index == current_index:
			death_sprite.frame = 0
			death_sprite.visible = true
		else:
			death_sprite.frame = 0
			death_sprite.visible = false
	_active_death_index = current_index
	_refresh_count()
	_sync_death_overlays()
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
	if _active_death_index < 0 or _active_death_index >= _death_sprites.size():
		return
	_death_sprites[_active_death_index].frame = clampi(roundi(value), 0, DEATH_FRAME_COUNT - 1)

func _finish_loss_animation() -> void:
	if _active_death_index >= 0 and _active_death_index < _death_sprites.size():
		_death_sprites[_active_death_index].frame = DEATH_FRAME_COUNT - 1
	_active_death_index = -1
	_sync_death_overlays()

func _sync_death_overlays() -> void:
	var lost := clampi(_neurons_lost(), 0, _death_sprites.size())
	for index: int in range(_death_sprites.size()):
		var death_sprite := _death_sprites[index]
		if index < lost:
			death_sprite.visible = true
			if index != _active_death_index:
				death_sprite.frame = DEATH_FRAME_COUNT - 1
		else:
			death_sprite.visible = false
			death_sprite.frame = 0

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
