class_name CheatMiniReel
extends RefCounted

## Cheat's symbol chooser: a mini-reel laid over the picked reel's hole, with
## up/down arrows that step a candidate symbol and a tap on the symbol itself to
## commit.
##
## The ART only. What may be chosen and what happens when it is chosen both stay
## in the machine: the pool comes from `Symbols.BASE_SYMBOL_CYCLE` plus a Book if
## the run has earned one, the starting symbol comes from the last result, and
## committing runs `cheat_symbol()`, the combo-defeat rescue and the reward
## sequence. This class is handed a finished pool and reports which entry the
## player landed on — it never asks the store anything.
##
## It builds into a parent it is given (TargetingLayer's node), the same
## arrangement SwapTargetOverlay uses: the layer's lifetime is not this class's,
## so `close()` only forgets what the layer already freed.

## The arrows' visible art comes off the authored selection sheet; these are the
## transparent hit targets that flank the mini-reel. The touch pad is generous
## because the arrows are 17x9 on a 160-wide canvas.
const ARROW_SIZE := Vector2(17.0, 9.0)
const ARROW_UP_RISE := 14.0   # arrow top above the hole's top edge
const ARROW_DOWN_DROP := 7.0  # arrow top below the hole's bottom edge
const ARROW_TOUCH_PAD := Vector2(1.5, 2.0)

## Nine frames: three per reel — resting, down-arrow held, up-arrow held.
const SELECTION_SHEET := "machine new view/cheat_selection.png"
const SELECTION_FRAMES := 9
const SELECTION_Z_INDEX := 98
const STATES_PER_REEL := 3

## The candidate pops when it changes, so a step reads as a flick rather than a
## silent swap.
const POP_SCALE := 1.25
const POP_TIME := 0.1

var _view: MachineView = null
var _symbols: ReelSymbols = null
var _art_filter := CanvasItem.TEXTURE_FILTER_NEAREST
## The machine's shared transparent-button builder; every picker uses it, so it
## stays there and comes in as a Callable.
var _make_hit_button := Callable()
## Called with the chosen symbol id when the player taps the mini-reel.
var _on_commit := Callable()

var _selection_sprite: Sprite2D = null
var _preview_sprite: Sprite2D = null
var _pool: Array[String] = []
var _index := 0
var _reel := -1

func _init(view: MachineView, symbols: ReelSymbols, art_filter: int,
		make_hit_button: Callable, on_commit: Callable) -> void:
	_view = view
	_symbols = symbols
	_art_filter = art_filter as CanvasItem.TextureFilter
	_make_hit_button = make_hit_button
	_on_commit = on_commit

## The authored selection sheet — full-canvas art that draws the selected reel's
## frame and the arrows. Built at the machine's own point in the layer stack.
func build_sheet() -> void:
	_selection_sprite = _view.full_canvas_sheet(SELECTION_SHEET, SELECTION_FRAMES)
	if _selection_sprite == null:
		return
	_selection_sprite.visible = false
	_selection_sprite.z_index = SELECTION_Z_INDEX

func selection_sprite() -> Sprite2D:
	return _selection_sprite

## Lays the mini-reel over `hole` on the picker layer. `pool` and `start_symbol`
## are the machine's answers; this only builds what they describe.
func open(parent: Control, reel_index: int, hole: Rect2, pool: Array[String],
		start_symbol: String) -> void:
	if parent == null:
		return
	_reel = reel_index
	_pool = pool.duplicate()
	_index = maxi(0, _pool.find(start_symbol))
	show_selection(0)
	_preview_sprite = Sprite2D.new()
	_preview_sprite.name = "CheatPreviewSymbol"
	_preview_sprite.centered = true
	_preview_sprite.position = hole.get_center()
	_preview_sprite.z_index = 2
	_preview_sprite.texture_filter = _art_filter
	parent.add_child(_preview_sprite)
	_refresh_preview(false)
	var confirm: Button = _make_hit_button.call({
		"left": hole.position.x, "top": hole.position.y,
		"width": hole.size.x, "height": hole.size.y,
	}, func() -> void: _commit())
	confirm.name = "CheatConfirmButton"
	parent.add_child(confirm)
	_build_arrow(parent, hole, true)
	_build_arrow(parent, hole, false)

## The layer that held the preview and the buttons has been freed by whoever owns
## it, so this drops the reference rather than freeing anything, and puts the
## authored sheet back to its resting frame.
func close() -> void:
	_preview_sprite = null
	if _selection_sprite != null:
		_selection_sprite.visible = false
		_view.set_sheet_frame(_selection_sprite, 0)
	_reel = -1

## `state` is 0 resting, 1 down-arrow held, 2 up-arrow held — three frames per
## reel, so the sheet shows which reel is picked and which arrow is under a finger
## at the same time.
func show_selection(state: int) -> void:
	if _selection_sprite == null or _reel < 0:
		return
	var frame := clampi(_reel * STATES_PER_REEL + state, 0, SELECTION_FRAMES - 1)
	_view.set_sheet_frame(_selection_sprite, frame)
	_selection_sprite.visible = true

func selected_symbol() -> String:
	if _pool.is_empty():
		return ""
	return _pool[_index]

func _build_arrow(parent: Control, hole: Rect2, up: bool) -> void:
	var cx := hole.get_center().x
	var top := hole.position.y - ARROW_UP_RISE if up else hole.end.y + ARROW_DOWN_DROP
	var b: Button = _make_hit_button.call({
		"left": cx - ARROW_SIZE.x * 0.5 - ARROW_TOUCH_PAD.x,
		"top": top - ARROW_TOUCH_PAD.y,
		"width": ARROW_SIZE.x + ARROW_TOUCH_PAD.x * 2.0,
		"height": ARROW_SIZE.y + ARROW_TOUCH_PAD.y * 2.0,
	}, func() -> void: _cycle(-1 if up else 1))
	b.name = "CheatArrowUp" if up else "CheatArrowDown"
	b.button_down.connect(show_selection.bind(2 if up else 1))
	b.button_up.connect(show_selection.bind(0))
	parent.add_child(b)

## Steps match the strip: the up arrow rolls toward the symbol shown above the
## hole (cycle -1), the down arrow toward the one below (+1).
func _cycle(step: int) -> void:
	if _pool.is_empty():
		return
	_index = posmod(_index + step, _pool.size())
	_refresh_preview(true)

func _refresh_preview(pop: bool) -> void:
	if _preview_sprite == null or not is_instance_valid(_preview_sprite):
		return
	_symbols.apply_symbol(_preview_sprite, _pool[_index], ReelSymbols.CENTER_H)
	if not pop:
		return
	var rest := _preview_sprite.scale
	_preview_sprite.scale = rest * POP_SCALE
	var tw := _view.tween()
	tw.tween_property(_preview_sprite, "scale", rest, POP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _commit() -> void:
	if _pool.is_empty():
		return
	_on_commit.call(_pool[_index])
