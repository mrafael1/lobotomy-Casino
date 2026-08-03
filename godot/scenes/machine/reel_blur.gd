class_name ReelBlur
extends RefCounted

## Everything that masks a reel while it is not showing a settled symbol: the
## animated blur strips that play in the reel holes during a spin, the cabinet
## patches that snap over a reel the instant it lands, and the Serum frost covers
## that render a result deliberately unreadable (issue #53).
##
## Seam 4.5a, the leaf half of what the plan called "reel spin & reveal". The
## other half — when a reel starts, when it stops, which symbol it lands on, what
## the result then triggers — is the spin sequence, and it is flow. It stays in
## the machine and drives this through nine calls.
##
## The split is visible in the fields. Not one of the four here is read by the
## sequence: it sets a frame, shows a cover, hides a strip. The sequence's own
## state (_reel_stop_times, _blur_accum, _reel_stop_sfx_played) stays with it,
## and none of it is a sprite.

## Per-reel geometry, handed over at construction: it is the machine's layout and
## it never changes.
var _holes: Array = []
var _asset_scale := 8.0
var _frame_count := 1
## The machine's pixel-art filter, so a strip matches the cabinet it sits in.
var _texture_filter := CanvasItem.TEXTURE_FILTER_NEAREST

var _view: MachineView = null

## The animated strip that plays in a hole while its reel is spinning.
var _spin_sprites: Array[Sprite2D] = []
## Cabinet patch pulled over a hole the moment its reel stops, so the strip
## underneath is never seen halting.
var _covers: Array = []
## Serum's frost (issue #53): the result is on screen but deliberately unreadable.
var _blur_covers: Array = []
var _result_blurred := false

func _init(view: MachineView, holes: Array, asset_scale: float, frame_count: int) -> void:
	_view = view
	_holes = holes
	_asset_scale = asset_scale
	_frame_count = maxi(1, frame_count)

## --- the spin strips ---------------------------------------------------------------

func build_spin_strips(sheet: String) -> void:
	var tex := _view.texture(sheet, true)
	if tex == null:
		return
	for i in 3:
		var spr := _view.authored_sprite("SpinReel%d" % i)
		var authored := spr != null
		if spr == null:
			spr = Sprite2D.new()
			spr.name = "SpinReel%d" % i
			_view.add_layer(spr)
		spr.texture = tex
		spr.centered = false
		spr.region_enabled = true
		if not authored:
			spr.position = Vector2(_holes[i]["left"], _holes[i]["top"])
			spr.scale = Vector2(1.0 / _asset_scale, 1.0 / _asset_scale)
		spr.texture_filter = _texture_filter
		spr.visible = false
		_spin_sprites.append(spr)
		set_spin_frame(i, 0)

## The sheet is one row of SPIN_FRAME_COUNT full-canvas frames, so a frame is
## selected by stepping the region across it — the hole's own left/top then picks
## this reel's window inside that frame.
func set_spin_frame(index: int, frame: int) -> void:
	if index < 0 or index >= _spin_sprites.size():
		return
	var spr: Sprite2D = _spin_sprites[index]
	if spr == null or spr.texture == null:
		return
	var tex := spr.texture
	var frame_w := float(tex.get_width()) / float(_frame_count)
	var hole: Dictionary = _holes[index]
	spr.region_rect = Rect2(
		frame_w * float(frame) + float(hole["left"]) * _asset_scale,
		float(hole["top"]) * _asset_scale,
		float(hole["width"]) * _asset_scale,
		float(hole["height"]) * _asset_scale
	)

func set_spin_visible(index: int, visible: bool) -> void:
	if index >= 0 and index < _spin_sprites.size():
		_spin_sprites[index].visible = visible

func hide_spin_strips() -> void:
	for spr in _spin_sprites:
		spr.visible = false

## --- the landing covers ------------------------------------------------------------

## Built one per hole and slightly oversized (1px each side, 3px top and bottom):
## the patch has to cover the strip's overshoot, not just the hole's own rect.
func build_covers(sheet: String) -> void:
	for i in 3:
		var hole: Dictionary = _holes[i]
		var cover := _view.region_sprite(sheet, {
			"left": float(hole["left"]) - 1.0,
			"top": float(hole["top"]) - 3.0,
			"width": float(hole["width"]) + 2.0,
			"height": float(hole["height"]) + 6.0,
		})
		if cover != null:
			cover.visible = false
		_covers.append(cover)

func set_cover(index: int, visible: bool) -> void:
	if index < _covers.size() and _covers[index] != null:
		_covers[index].visible = visible

## The swap power lifts and shakes the covers along with the symbols under them,
## so it needs the sprites themselves rather than a visibility call.
func cover(index: int) -> Sprite2D:
	return _covers[index] as Sprite2D if index >= 0 and index < _covers.size() else null

func cover_count() -> int:
	return _covers.size()

## --- Serum's frost -----------------------------------------------------------------

## Parented into the machine's FX layer, which the machine owns and sweeps, so it
## is handed in along with the per-hole rects it has already computed.
func build_blur_covers(parent: Control, rects: Array, color: Color) -> void:
	_blur_covers.clear()
	for i in 3:
		var cover := ColorRect.new()
		cover.name = "BlurCover%d" % i
		cover.color = color
		var rect: Rect2 = rects[i]
		cover.position = rect.position
		cover.size = rect.size
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.visible = false
		parent.add_child(cover)
		_blur_covers.append(cover)

func set_blur_cover(index: int, visible_now: bool) -> void:
	if index >= 0 and index < _blur_covers.size():
		(_blur_covers[index] as ColorRect).visible = visible_now

## Arms or disarms the blurred-result state. Either way every cover goes out
## first: the covers are re-shown per reel as the result lands, and one left over
## from the previous spin would frost a symbol that is meant to be readable.
func set_result_blurred(active: bool) -> void:
	_result_blurred = active
	for c in _blur_covers:
		(c as ColorRect).visible = false

func result_blurred() -> bool:
	return _result_blurred

func blur_covers() -> Array:
	return _blur_covers

## Puts the frost back to its resting state for a teardown: every cover hidden and
## the armed flag cleared.
func clear_blur() -> void:
	for cover: CanvasItem in _blur_covers:
		if cover != null:
			cover.visible = false
	_result_blurred = false

## --- what the smoke checks read ------------------------------------------------

func spin_visible(index: int) -> bool:
	return index >= 0 and index < _spin_sprites.size() and _spin_sprites[index].visible
