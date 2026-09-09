class_name MachineDealerPortrait
extends TextureRect

## Reactions consume visible screen time, so a payout can temporarily own the CRT.
const HOLD_TIME := 2.5
const FADE_TIME := 0.4
const LETTERS_PER_SECOND := 20.0

var _caption: Label = null
var _elapsed := 0.0

func build_caption(pixel_font: Font) -> void:
	_caption = Label.new()
	_caption.name = "DealerReaction"
	_caption.position = Vector2(-1, 33)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_font_override("font", pixel_font)
	_caption.add_theme_font_size_override("font_size", 5)
	_caption.add_theme_color_override("font_color", Color("dce3b7"))
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color("081712")
	backing.border_color = Color("526e58")
	backing.border_width_top = 1
	backing.border_width_bottom = 1
	_caption.add_theme_stylebox_override("normal", backing)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.visible = false
	add_child(_caption)
	# Theme minima resolve on tree entry; shrink only after the real pixel font is active.
	_caption.size = Vector2(32, 11)
	set_process(false)

func react(win_type: String) -> void:
	if _caption == null:
		return
	_caption.text = "AGAIN?" if win_type == "miss" else "NICE."
	if win_type == "jackpot":
		_caption.text = "WELL..."
	_caption.size = Vector2(32, 11)
	_elapsed = 0.0
	_caption.visible_characters = 0
	_caption.modulate.a = 1.0
	_caption.show()
	set_process(true)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_elapsed += delta
	_caption.visible_characters = mini(_caption.text.length(), int(_elapsed * LETTERS_PER_SECOND))
	_caption.modulate.a = clampf(1.0 - (_elapsed - HOLD_TIME) / FADE_TIME, 0.0, 1.0)
	if _elapsed >= HOLD_TIME + FADE_TIME:
		_caption.hide()
		set_process(false)
