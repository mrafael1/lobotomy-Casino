class_name TargetingLayer
extends RefCounted

## The full-canvas layer a power's target pickers live on, and nothing else.
##
## Four powers arm a picker — the reel picker, Shift's arrows, Cheat's mini-reel
## and Swap's drag surface — and all four were opening the same node by hand:
## a Control at canvas size, z 97, with a mouse filter, parented into the machine.
## Four copies of five lines, and four assignments to one field that a single
## `_clear_targeting` then freed.
##
## This class owns exactly that node's LIFE: opening one (closing whatever was
## armed first, because arming a power always replaces the last), handing it out
## as a parent, converting a global point into its space, and freeing it.
##
## It deliberately does NOT own what goes on the layer. That was measured and
## struck once already (seam 4.6b): the four contenders build completely different
## things onto it, and a class that knew about all four would be arbitrating
## between them — the coordinator shape 4.4c was struck for. The contenders keep
## building into `node()`, exactly as SwapTargetOverlay already does, and the
## machine keeps tearing their own state down beside `close()`.
##
## So: a node's lifetime, held in one place. It decides nothing.

## Above everything the machine draws, including the TV blackout (45) — a picker
## is the frontmost thing on the cabinet while it is armed.
const Z_INDEX := 97

var _view: MachineView = null
var _canvas_size := Vector2.ZERO

var _layer: Control = null

func _init(view: MachineView, canvas_size: Vector2) -> void:
	_view = view
	_canvas_size = canvas_size

## Opens a fresh layer, replacing any that was already armed.
##
## `mouse_filter` is the caller's because it is the difference between a picker
## whose BUTTONS take the clicks (IGNORE, so a tap that misses falls through) and
## one where the layer itself swallows a miss to cancel (STOP — Cheat, where
## tapping off the mini-reel backs out). `on_input` is only meaningful with the
## latter.
func open(layer_name: String, mouse_filter: int, on_input := Callable()) -> Control:
	close()
	_layer = Control.new()
	_layer.name = layer_name
	_layer.size = _canvas_size
	_layer.mouse_filter = mouse_filter as Control.MouseFilter
	_layer.z_index = Z_INDEX
	if on_input.is_valid():
		_layer.gui_input.connect(on_input)
	_view.add_layer(_layer)
	return _layer

## The armed layer, or null. Callers parent into this rather than being handed a
## slot on this class — what they build is their own business.
func node() -> Control:
	return _layer

func is_open() -> bool:
	return _layer != null and is_instance_valid(_layer)

func close() -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null

## A global point in the layer's own space — what a drag gesture needs, since the
## pointer arrives in screen coordinates and the ghost lives on the layer. Only
## meaningful while a layer is armed; where a point lives when none is belongs to
## the caller's coordinate space, not this class's.
func local_position(global_position: Vector2) -> Vector2:
	if not is_open():
		return global_position
	return _layer.get_global_transform_with_canvas().affine_inverse() * global_position
