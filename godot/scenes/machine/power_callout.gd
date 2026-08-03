class_name PowerCallout
extends RefCounted

## The power name across the TV while its targeting is armed (issue #119 family):
## the authored power_animation frame for the seven known powers, and a typed
## fallback label for anything the sheet does not have a frame for.
##
## Seam 4.6a, and the smallest useful piece of power targeting: this is the
## ANNOUNCEMENT, not the targeting. Which reels are pickable, what a pick does and
## when the arming ends all stay in the machine — this only says the power's name
## and beeps while it is up.
##
## Cutting it settles the debt #197 recorded. The beep cadence lived on
## WinCallouts because 4.2 cut the win callout while this one was still in the
## machine; both now read it from CalloutCadence and neither owns the other's
## timing.

const SHEET := "machine new view/power_animation.png"
const FRAMES := 7
const FRAME := {
	"reroll": 0, "shift": 1, "memory": 2,
	"rewind": 3, "heart": 4, "cheat": 5, "swap": 6,
}

## Centred band: the x follows the width so a resize can't leave it off-centre.
const LABEL_SIZE := Vector2(90.0, 18.0)
const LABEL_Y := 43.0
const NEON_CYAN := Color(0.42, 1.0, 0.95)

## The source that this callout holds on the TV priority stack while it is up.
const TV_SOURCE := &"power"

var _view: MachineView = null
var _canvas_width := 160.0

var _sprite: Sprite2D = null
var _label: Label = null
var _tween: Tween = null

func _init(view: MachineView, canvas_width: float) -> void:
	_view = view
	_canvas_width = canvas_width

## Built from the machine's control-art pass, at the line this sheet has always
## been created on — it shares the callout layer's tree order.
func build() -> void:
	_sprite = _view.full_canvas_sheet(SHEET, FRAMES)
	if _sprite != null:
		_sprite.visible = false

func sprite() -> Sprite2D:
	return _sprite

func label() -> Label:
	return _label

## Beeps the power's frame a few times and then holds while its targeting stays
## armed — the machine's _clear_targeting is what takes it down.
func show_power(id: String) -> void:
	if _sprite == null:
		return
	stop()
	_view.begin_tv_info_pop(TV_SOURCE)
	_view.set_sheet_frame(_sprite, int(FRAME.get(id, 0)))
	if not FRAME.has(id):
		_ensure_label()
		_label.text = id.to_upper()
		_label.visible = true
	elif _label != null:
		_label.visible = false
	_sprite.modulate.a = 1.0
	_sprite.visible = true
	_tween = _view.tween().set_loops(CalloutCadence.BEEP_COUNT)
	_tween.tween_property(_sprite, "modulate:a", CalloutCadence.BEEP_MIN_ALPHA,
		CalloutCadence.BEEP_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_sprite, "modulate:a", 1.0,
		CalloutCadence.BEEP_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_interval(CalloutCadence.BEEP_PAUSE)

## Built on first need rather than with the sprite: only a power the authored
## sheet has no frame for ever raises it, and most runs never see one.
func _ensure_label() -> void:
	if _label != null:
		return
	_label = Label.new()
	_label.name = "PowerCalloutName"
	_label.size = LABEL_SIZE
	_label.position = Vector2((_canvas_width - LABEL_SIZE.x) * 0.5, LABEL_Y)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", NEON_CYAN)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 1)
	var font := _view.font()
	if font != null:
		_label.add_theme_font_override("font", font)
	_sprite.add_child(_label)

func stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if _sprite != null:
		_sprite.visible = false
		_sprite.modulate.a = 1.0
	if _label != null:
		_label.visible = false
	_view.end_tv_info_pop(TV_SOURCE)
