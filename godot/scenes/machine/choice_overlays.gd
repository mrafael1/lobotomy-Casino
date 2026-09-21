class_name ChoiceOverlays
extends RefCounted

## The three in-run overlays that interrupt the machine to ask the player
## something, or to tell them what they just got.
##
##   Serum's symbol picker (issue #53) — pick a symbol, it is guaranteed next spin
##   Book's triple choice — pick which triple the Book resolves as
##   the Eye reveal popup (issue #53) — names the symbol a picked reel will land
##
## They were three hand-built Controls scattered through the file with the same
## bones each time: a full-canvas node, a z_index, a panel, some symbol buttons,
## a close. Only the Serum one used the shared `SymbolPicker` panel; the Book one
## rebuilt an equivalent by hand at a different size.
##
## They are still built separately here, deliberately — the Book row is six 16px
## icons in a strip and the Serum panel is the shared pick grid, and merging two
## layouts that merely rhyme is how a refactor changes what the player sees. What
## this class buys is that all three now live where a fourth would go.
##
## Nothing here decides anything. The pools come in, the picks go out as
## Callables, and the machine keeps the sequence lock, the store writes and the
## reaction flashes that follow a choice.

## Serum's panel: the shared symbol-picker grid, sat over the reel window.
const SERUM_RECT := Rect2(12.0, 132.0, 136.0, 58.0)
const SERUM_Z_INDEX := 95
const SERUM_TITLE := "PICK A SYMBOL"

## Book's row sits slightly wider and lower than Serum's grid — it is six icons in
## one strip rather than a wrapped grid, so it needs the width more than the height.
const BOOK_RECT := Rect2(11.0, 130.0, 138.0, 54.0)
const BOOK_Z_INDEX := 96
const BOOK_PANEL_COLOR := Color(0.05, 0.03, 0.1, 0.94)
const BOOK_TITLE_COLOR := Color(1.0, 0.82, 0.28)
const BOOK_ICON := 16.0

const EYE_POPUP_TIME := 1.1
const EYE_FRAME_ASSET := "ui/premium/eye_reveal_frame.svg"
const EYE_POPUP_SIZE := Vector2(32.0, 32.0)
const EYE_POPUP_Z_INDEX := 40
## Clear of the cabinet edge, and high enough above the reel window that the
## pointer can reach down to the reel it names.
const EYE_EDGE_MARGIN := 2.0
const EYE_POPUP_RISE := 7.0
const EYE_FALLBACK_COLOR := Color(0.05, 0.03, 0.1, 0.92)

var _view: MachineView = null
var _canvas := Vector2.ZERO
var _reel_centers: Array = []
var _reel_window: Dictionary = {}

var _serum: Control = null
var _book: Control = null

func _init(view: MachineView, canvas: Vector2, reel_centers: Array,
		reel_window: Dictionary) -> void:
	_view = view
	_canvas = canvas
	_reel_centers = reel_centers
	_reel_window = reel_window

# --- Serum's symbol picker ----------------------------------------------------

func serum_open() -> bool:
	return _serum != null and is_instance_valid(_serum)

func serum_node() -> Control:
	return _serum

## `on_pick` takes the chosen symbol id. A tap that no button consumed cancels,
## which is why the layer itself is STOP rather than IGNORE — the charge is only
## spent on an actual pick.
func open_serum(pool: Array[String], on_pick: Callable, on_cancel: Callable) -> void:
	_serum = Control.new()
	_serum.set_as_top_level(true)
	_serum.name = "SerumPicker"
	_serum.size = _canvas
	_serum.mouse_filter = Control.MOUSE_FILTER_STOP
	_serum.z_index = SERUM_Z_INDEX
	_serum.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			on_cancel.call())
	_view.add_layer(_serum)
	SymbolPicker.build_symbol_picker_panel(_serum, pool, SERUM_TITLE, SERUM_RECT,
		on_pick, on_cancel, true)

func close_serum() -> void:
	if _serum != null and is_instance_valid(_serum):
		_serum.queue_free()
	_serum = null

# --- Book's triple choice -----------------------------------------------------

func book_node() -> Control:
	return _book

## One icon per choice in a single strip. `on_pick` takes the chosen symbol id;
## what each choice then means (including "flatline", which is a result rather
## than a triple) is the machine's.
func open_book(choices: Array, on_pick: Callable) -> void:
	close_book()
	_book = Control.new()
	_book.set_as_top_level(true)
	_book.name = "BookTripleChoice"
	_book.size = _canvas
	_book.mouse_filter = Control.MOUSE_FILTER_STOP
	_book.z_index = BOOK_Z_INDEX
	_view.add_layer(_book)

	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", ButtonKit.neon_panel_style(BOOK_TITLE_COLOR))
	panel.position = BOOK_RECT.position
	panel.size = BOOK_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(panel)

	var title := _view.reaction_label(_book, "BOOK EFFECT",
		Vector2(BOOK_RECT.position.x, BOOK_RECT.position.y + 3.0), 7, BOOK_TITLE_COLOR)
	title.size = Vector2(BOOK_RECT.size.x, 9.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var cell_w := BOOK_RECT.size.x / float(choices.size())
	for i in choices.size():
		var sym := String(choices[i])
		var b := Button.new()
		SymbolPicker._apply_symbol_picker_button_style(b)
		b.add_theme_stylebox_override("normal", SymbolPicker._symbol_picker_style(
			SymbolPicker.SYMBOL_PICKER_SLOT_COLOR, SymbolPicker.SYMBOL_PICKER_SLOT_BORDER))
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(BOOK_RECT.position.x + float(i) * cell_w + 2.0,
			BOOK_RECT.position.y + 17.0)
		b.size = Vector2(cell_w - 4.0, 30.0)
		b.pressed.connect(on_pick.bind(sym))
		_book.add_child(b)
		var tex := _view.texture("symbols/%s.png" % sym, true)
		if tex == null:
			continue
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = tex
		icon.size = Vector2(BOOK_ICON, BOOK_ICON)
		icon.position = Vector2((cell_w - 4.0 - BOOK_ICON) * 0.5, 6.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)

func close_book() -> void:
	if _book != null and is_instance_valid(_book):
		_book.queue_free()
	_book = null

# --- the Eye reveal popup -----------------------------------------------------

## Names the symbol a picked reel will land, over that reel. Pops in, holds, fades
## and frees itself — there is nothing to close, so nothing is kept.
##
## `fx_group` is the machine's transient-effects group: an ending sweeps it, and a
## popup still counting down when the run ends must go with it.
func show_eye_reveal(reel_index: int, symbol_id: String, pointer_color: Color,
		fx_group: StringName) -> void:
	if reel_index < 0 or reel_index >= _reel_centers.size():
		return
	var size := EYE_POPUP_SIZE
	var popup := Control.new()
	popup.add_to_group(fx_group)
	popup.z_index = EYE_POPUP_Z_INDEX
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cx := float(_reel_centers[reel_index])
	popup.position = Vector2(
		clampf(cx - size.x * 0.5, EYE_EDGE_MARGIN, _canvas.x - size.x - EYE_EDGE_MARGIN),
		float(_reel_window["top"]) - size.y - EYE_POPUP_RISE)
	popup.size = size
	_view.add_layer(popup)

	var frame_tex := _view.texture(EYE_FRAME_ASSET, true)
	if frame_tex != null:
		var frame := TextureRect.new()
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.texture = frame_tex
		frame.size = popup.size
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.add_child(frame)
	else:
		var bg := ColorRect.new()
		bg.color = EYE_FALLBACK_COLOR
		bg.size = popup.size
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.add_child(bg)

	var pointer := ColorRect.new()
	pointer.color = pointer_color
	pointer.position = Vector2(size.x * 0.5 - 1.0, size.y - 1.0)
	pointer.size = Vector2(2.0, 8.0)
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(pointer)

	var tex := _view.texture("symbols/%s.png" % symbol_id, true)
	if tex != null:
		var icon := Sprite2D.new()
		icon.texture = tex
		icon.position = popup.size * 0.5
		icon.centered = true
		var icon_scale := minf(1.0, ReelSymbols.CENTER_H / float(tex.get_height()))
		icon.scale = Vector2(icon_scale, icon_scale)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		popup.add_child(icon)
	else:
		var sym := _view.reaction_label(popup, symbol_id.to_upper(),
			Vector2(0.0, 8.0), 6, Color(0.1, 0.08, 0.2))
		sym.size = Vector2(size.x, 14.0)
		sym.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	popup.pivot_offset = popup.size * 0.5
	popup.scale = Vector2(0.4, 0.4)
	var tw := popup.create_tween()
	tw.tween_property(popup, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(EYE_POPUP_TIME)
	tw.tween_property(popup, "modulate:a", 0.0, 0.3)
	tw.tween_callback(popup.queue_free)
