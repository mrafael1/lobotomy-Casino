class_name HintPopups
extends RefCounted

## The transient two-line +/- popups that name what an item just did (issue #33),
## and the layer they live on.
##
## This is the spawning only. WHICH lines a use shows is a run question and stays
## in the machine: whether the item's downside is deferred to the moment it
## actually bites (issue #76), whether a joker run has inverted its vocabulary
## (issue #111), whether the losing state is suppressing text altogether. By the
## time anything reaches here the answer is two strings and a name.
##
## The layer is rebuilt on demand rather than only at startup, because the HUD it
## hangs from is rebuilt on some run transitions and a popup that arrived in that
## window used to find a freed parent.

## Popups originate from the machine centre — the reel window's midpoint — rather
## than from the HUD anchor they are parented to.
const Z_INDEX := 20

var _view: MachineView = null
var _center := Vector2.ZERO

var _layer: Control = null

func _init(view: MachineView, center: Vector2) -> void:
	_view = view
	_center = center

## `bottom_hud` is the machine's HUD row; the layer reuses an authored HintLayer
## under it when the scene already has one.
func build(bottom_hud: Control) -> void:
	if bottom_hud == null:
		return
	_layer = bottom_hud.get_node_or_null("HintLayer") as Control
	if _layer != null:
		return
	_layer = Control.new()
	_layer.name = "HintLayer"
	bottom_hud.add_child(_layer)
	_layer.position = _center
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.z_index = Z_INDEX

func layer() -> Control:
	return _layer

func has_layer() -> bool:
	return _layer != null and is_instance_valid(_layer)

## One self-freeing popup. Either line may be empty — that is how a deferred
## downside pops alone later, and how an upside-only hint reads on use.
func spawn(positive: String, negative: String, item_name: String,
		corrupted: bool, grow_time: float) -> HintLabel:
	if not has_layer():
		return null
	var hint_label := HintLabel.new()
	hint_label.grow_time = grow_time
	hint_label.set_font(_view.font())
	_layer.add_child(hint_label)
	hint_label.play(positive, negative, item_name, corrupted)
	return hint_label

## Hides whatever is still counting down without freeing it, matching how the
## machine sweeps its other transient layers when a run ends.
func hide_pending() -> void:
	if not has_layer():
		return
	for child: Node in _layer.get_children():
		var item := child as CanvasItem
		if item != null:
			item.visible = false
			item.modulate.a = 0.0
