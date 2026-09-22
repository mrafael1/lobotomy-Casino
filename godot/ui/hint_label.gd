class_name HintLabel
extends Control

## Reusable animated two-line "+/-" hint (issue #33). Shows a green (+) and a red
## (-) line with an optional item name above them, scales up over `grow_time`,
## fades out in the final stretch, then frees itself. The corrupted-name colour is
## the shared purple rule from the upgrade work (issue #7 / PR #37).

## Item ids whose NAME reads as corrupted (purple). Explicit and DECOUPLED from any
## mechanical "corrupted" category, matching the #7 approach. Kept forward-compatible
## with the #2 roster — `cons_cigarette` lands there but flagging it early is inert.
## The Energy Drink left this list when it lost its downside: a purple name for an item
## that is now two free spins and nothing else read as a warning with nothing behind it.
## A joker Augmented run turns all four in-run items purple, but that is the RUN talking,
## not the item — the machine adds it at the call site (issue #111).
const LINE_WIDTH := 140.0
const MIN_FONT_SIZE := 5

const CORRUPTED_ITEM_IDS: Array[String] = [
	"cons_cigarette", "cons_white_powder", "item_pill",
]

@export var grow_time: float = 1.5
@export var positive_color: Color = Color(0.13, 0.77, 0.37)
@export var negative_color: Color = Color(0.94, 0.27, 0.27)
## Shared purple corrupted-name colour (issue #7 / #37).
@export var corrupt_color: Color = Color(0.66, 0.33, 0.86)
@export var name_color: Color = Color(0.9, 0.95, 1.0)
@export var font_size: int = 8
@export_range(0.1, 1.0, 0.05) var start_scale: float = 0.5
## Fraction of `grow_time` spent fading out at the tail of the animation.
@export_range(0.05, 0.95, 0.05) var fade_fraction: float = 0.3

var _name_label: Label = null
var _pos_label: Label = null
var _neg_label: Label = null
var _font: Font = null
var _tween: Tween = null

## True when the item's name should render in `corrupt_color`.
static func item_is_corrupted(id: String) -> bool:
	return CORRUPTED_ITEM_IDS.has(id)

## Assign before `play()` so the pixel font applies to the spawned lines.
func set_font(font: Font) -> void:
	_font = font
	if _name_label != null and _font != null:
		for label: Label in [_name_label, _pos_label, _neg_label]:
			label.add_theme_font_override(&"font", _font)

## Animate the hint. `item_name` (optional) appears above the +/- lines and turns
## purple when `corrupted`. An empty `pos_text` or `neg_text` hides that line, so a
## caller can show only the upside on use and pop the downside later when it actually
## activates (issue #76). Frees itself once the animation completes.
func play(pos_text: String, neg_text: String, item_name: String = "", corrupted: bool = false) -> void:
	_ensure_labels()
	_pos_label.visible = not pos_text.is_empty()
	_neg_label.visible = not neg_text.is_empty()
	# The hint is translated before the sign goes on; "+ EASY" as a whole is not a key.
	var positive := tr(pos_text)
	_pos_label.text = positive if positive.begins_with("+") else "+ %s" % positive
	var negative := tr(neg_text)
	_neg_label.text = negative if negative.begins_with("-") else "- %s" % negative
	_pos_label.add_theme_color_override(&"font_color", positive_color)
	_neg_label.add_theme_color_override(&"font_color", negative_color)
	if item_name.is_empty():
		_name_label.visible = false
	else:
		_name_label.visible = true
		_name_label.text = item_name
		_name_label.add_theme_color_override(&"font_color", corrupt_color if corrupted else name_color)
	for label in [_name_label, _pos_label, _neg_label]:
		_fit_line(label)
	# Children straddle the origin, so scaling around pivot (0,0) keeps the hint
	# visually centred on wherever the caller placed this node.
	scale = Vector2(start_scale, start_scale)
	modulate.a = 1.0
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2.ONE, grow_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var fade_time: float = maxf(0.05, grow_time * fade_fraction)
	_tween.tween_property(self, "modulate:a", 0.0, fade_time).set_delay(grow_time - fade_time)
	_tween.chain().tween_callback(queue_free)

func _ensure_labels() -> void:
	if _name_label != null:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label = _make_line(-11.0, name_color)
	_pos_label = _make_line(-1.0, positive_color)
	_neg_label = _make_line(9.0, negative_color)

func _make_line(y: float, color: Color) -> Label:
	var line := Label.new()
	line.position = Vector2(-LINE_WIDTH * 0.5, y)
	line.size = Vector2(LINE_WIDTH, 10.0)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override(&"font_size", font_size)
	line.add_theme_color_override(&"font_color", color)
	line.add_theme_color_override(&"font_outline_color", Color.BLACK)
	line.add_theme_constant_override(&"outline_size", 1)
	if _font != null:
		line.add_theme_font_override(&"font", _font)
	add_child(line)
	return line

## Keep long translated hints inside the safe area, including the existing pop overshoot.
func _fit_line(line: Label) -> void:
	var fitted := font_size
	var font := line.get_theme_font("font")
	var display_text := tr(line.text)
	while fitted > MIN_FONT_SIZE and font.get_string_size(display_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > LINE_WIDTH:
		fitted -= 1
	line.add_theme_font_size_override("font_size", fitted)
	line.size = Vector2(LINE_WIDTH, 10.0)
	line.set_deferred("size", Vector2(LINE_WIDTH, 10.0))
