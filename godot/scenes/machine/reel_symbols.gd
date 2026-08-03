class_name ReelSymbols
extends RefCounted

## The nine symbol sprites in the reel windows: the three that landed, and the
## six dimmed neighbours above and below them that make each window read as a
## strip rather than a single tile.
##
## Seam 4.5b, the second leaf out of "reel spin & reveal" — this one is what a
## reel SHOWS, where 4.5a (#207) was what hides it. The spin sequence still owns
## when either happens.
##
## Two things here are not sprite work and are here anyway, because both are
## answers about what the strip displays rather than about the run:
##
##   neighbours_of() picks the symbols above and below the landed one. It reads
##   the canonical cycle, and hearts get their own rule so a heart strip cycles
##   x1 -> x2 -> x3 around the tier and never shows nine of one.
##
##   the adjacent-hidden flag is what Tunnel Vision and its relatives set, and
##   every reel's visibility passes through it. It is display state; the powers
##   that set it stay in the machine.
##
## apply_symbol() is public because the cheat preview and the swap drag paint the
## same symbols onto their own sprites, and they should not each re-derive the
## texture lookup and the downscale.

## Symbols are authored large and drawn at 12-16px. The centre is full alpha and
## its neighbours are dimmed, so the eye reads which one is the result.
const STRIP_ADJ_ALPHA := 0.5
const CENTER_H := 16.0
const ADJ_H := 12.0
const OFFSET := 14.0 # vertical gap between symbol centres ((center+adj)/2)

var _view: MachineView = null

## Reel geometry and the heart asset table: the machine's, static after load.
var _cell_centers: Array = []
var _window: Dictionary = {}
var _heart_assets: Dictionary = {}
var _texture_filter := CanvasItem.TEXTURE_FILTER_NEAREST

var _center: Array[Sprite2D] = []
var _top: Array[Sprite2D] = []
var _bottom: Array[Sprite2D] = []
## While set, the dimmed neighbours stay hidden however the centres are shown —
## Tunnel Vision and the blinding items narrow the window to one tile.
var _adjacent_hidden := false

func _init(view: MachineView, cell_centers: Array, window: Dictionary,
		heart_assets: Dictionary, texture_filter: int) -> void:
	_view = view
	_cell_centers = cell_centers
	_window = window
	_heart_assets = heart_assets
	_texture_filter = texture_filter

## --- construction ------------------------------------------------------------------

func build() -> void:
	var cy: float = float(_window["top"]) + float(_window["height"]) * 0.5
	for i in 3:
		var cx: float = _cell_centers[i]
		# Add neighbours first, centre last so it draws on top where they meet.
		_top.append(_new_sprite("Reel%dTop" % i, Vector2(cx, cy - OFFSET), STRIP_ADJ_ALPHA))
		_bottom.append(_new_sprite("Reel%dBottom" % i, Vector2(cx, cy + OFFSET), STRIP_ADJ_ALPHA))
		_center.append(_new_sprite("Reel%dCenter" % i, Vector2(cx, cy), 1.0))

func _new_sprite(node_name: String, pos: Vector2, alpha: float) -> Sprite2D:
	var s := _view.authored_sprite(node_name)
	var authored := s != null
	if s == null:
		s = Sprite2D.new()
		s.name = node_name
		_view.add_layer(s)
	_configure(s, pos, alpha, not authored)
	return s

func _configure(s: Sprite2D, pos: Vector2, alpha: float, apply_position := true) -> void:
	s.centered = true
	if apply_position:
		s.position = pos
	s.modulate = Color(1, 1, 1, alpha)
	# Symbols are authored large and drawn at 12-16px, so keep their downscale
	# pixel-perfect with the rest of the machine art.
	s.texture_filter = _texture_filter

## --- what a window shows -------------------------------------------------------------

## Symbol above/below `sym` in the canonical cycle (book sits outside it).
func neighbours_of(sym: String) -> Dictionary:
	if sym.begins_with("heart"):
		# A heart strip cycles x1 -> x2 -> x3 around the landed tier, so the
		# display shows exactly three of each heart symbol — never nine of one.
		var tier := clampi(int(sym.trim_prefix("heart_x")), 1, 3) \
			if sym.begins_with("heart_x") else 1
		return {
			"top": "heart_x%d" % (((tier - 2) + 3) % 3 + 1),
			"bottom": "heart_x%d" % (tier % 3 + 1),
		}
	var cyc: Array = Symbols.BASE_SYMBOL_CYCLE
	var n := cyc.size()
	var i := cyc.find(sym)
	if i < 0:
		if sym == "book":
			# Shift treats out-of-cycle symbols as index 0, so book up -> eye and down -> flatline.
			return { "top": cyc[n - 1], "bottom": cyc[1] }
		return { "top": cyc[n - 1], "bottom": cyc[0] }
	return { "top": cyc[(i - 1 + n) % n], "bottom": cyc[(i + 1) % n] }

## Paints one symbol onto any sprite, scaled to `target_h` and never scaled UP —
## the art is authored large and this only ever shrinks it. Public because the
## cheat preview and the swap drag paint onto sprites this component does not own.
func apply_symbol(s: Sprite2D, symbol_id: String, target_h: float) -> void:
	var heart_asset := String(_heart_assets.get(symbol_id, ""))
	if symbol_id == "heart" and heart_asset == "":
		heart_asset = String(_heart_assets["heart_x1"])
	if heart_asset != "":
		var heart_tex := _view.texture(heart_asset, true)
		if heart_tex == null:
			return
		s.region_enabled = false
		s.texture = heart_tex
		var heart_scale := minf(1.0, target_h / float(heart_tex.get_height()))
		s.scale = Vector2(heart_scale, heart_scale)
		return
	var tex := _view.texture("symbols/%s.png" % symbol_id, true) # mipmaps for crisp downscale
	if tex == null:
		return
	s.region_enabled = false
	s.texture = tex
	var k := minf(1.0, target_h / float(tex.get_height()))
	s.scale = Vector2(k, k)

func set_symbol(index: int, symbol_id: String) -> void:
	apply_symbol(_center[index], symbol_id, CENTER_H)
	var nb := neighbours_of(symbol_id)
	apply_symbol(_top[index], String(nb["top"]), ADJ_H)
	apply_symbol(_bottom[index], String(nb["bottom"]), ADJ_H)
	refresh_adjacent(index)

## --- visibility ------------------------------------------------------------------------

func set_visible(index: int, visible: bool) -> void:
	_center[index].visible = visible
	_top[index].visible = visible and not _adjacent_hidden
	_bottom[index].visible = visible and not _adjacent_hidden

func set_all_visible(visible: bool) -> void:
	for i in _center.size():
		set_visible(i, visible)

func refresh_adjacent(index: int) -> void:
	if index < 0 or index >= _center.size():
		return
	var visible := bool(_center[index].visible) and not _adjacent_hidden
	_top[index].visible = visible
	_bottom[index].visible = visible

func set_adjacent_hidden(active: bool) -> void:
	_adjacent_hidden = active
	for i in _center.size():
		refresh_adjacent(i)

func adjacent_hidden() -> bool:
	return _adjacent_hidden

## --- the sprites themselves --------------------------------------------------------------
##
## The swap power lifts, shakes and drags these, and the reveal reads one back.
## Handed out rather than wrapped: those are transforms on a specific sprite, not
## a display state this component has an opinion about.

func center(index: int) -> Sprite2D:
	return _center[index] if index >= 0 and index < _center.size() else null

func top(index: int) -> Sprite2D:
	return _top[index] if index >= 0 and index < _top.size() else null

func bottom(index: int) -> Sprite2D:
	return _bottom[index] if index >= 0 and index < _bottom.size() else null

func count() -> int:
	return _center.size()

func centers() -> Array[Sprite2D]:
	return _center
