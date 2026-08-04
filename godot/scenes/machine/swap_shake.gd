class_name SwapShake
extends RefCounted

## The loose-in-the-cabinet shake the reels do while Swap is armed (issue #181).
##
## It is told WHICH nodes to move and knows nothing else — not what a reel is, not
## which reels are grabbable, not that the things in group 2 happen to be a blur
## cover, three symbol sprites and a slot frame owned by three different
## components. That is the whole reason this class is separable at all: "a reel"
## is not a thing anything owns, so a component that went and collected one would
## have to reach into three siblings and know the rules for a dead reel. Groups of
## nodes in, orbit out.
##
## Each group orbits on its own phase, which is what makes three loose reels rather
## than one juddering screen. The caller's group ORDER is the stagger, so handing
## the groups over in reel order is what keeps neighbouring reels out of step.

## A slow 1px orbit rather than a jitter: the reels should look loose in the
## cabinet, not broken (issue #181).
const STEP := 0.09
const OFFSETS: Array[Vector2] = [
	Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0), Vector2(-1.0, 0.0),
]

var _view: MachineView = null

var _tween: Tween = null
var _nodes: Array[CanvasItem] = []
var _base: Array[Vector2] = []
## Where each node starts along the orbit — its group's index.
var _phase: Array[int] = []

func _init(view: MachineView) -> void:
	_view = view

func start(groups: Array) -> void:
	stop()
	for group_index in groups.size():
		for node in (groups[group_index] as Array):
			var item := node as CanvasItem
			if item == null:
				continue
			_nodes.append(item)
			_base.append(_position_of(item))
			_phase.append(group_index)
	if _nodes.is_empty():
		return
	_tween = _view.tween().set_loops()
	for step in OFFSETS.size():
		_tween.tween_callback(set_step.bind(step))
		_tween.tween_interval(STEP)

## Puts every node back where it started. Safe to call when nothing is shaking,
## which is what lets the caller pair it with its own teardown unconditionally.
func stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	for i in _nodes.size():
		_move(_nodes[i], _base[i])
	_nodes.clear()
	_base.clear()
	_phase.clear()

func running() -> bool:
	return _tween != null and _tween.is_valid()

## The three arrays the smoke check walks in parallel to prove a reel moves as one
## piece and that neighbouring reels do not. Read-only by convention; they are the
## shake's own working state, exposed because "each group moved together, and the
## groups moved differently" is not answerable from the outside any other way.
func nodes() -> Array[CanvasItem]:
	return _nodes

func bases() -> Array[Vector2]:
	return _base

func phases() -> Array[int]:
	return _phase

## `step` walks the orbit; each group is offset along it by its own index, which is
## what staggers them.
func set_step(step: int) -> void:
	var steps := OFFSETS.size()
	for i in _nodes.size():
		_move(_nodes[i], _base[i] + OFFSETS[posmod(step + _phase[i], steps)])

## Node2D and Control both have a `position`, but not through a shared base — the
## reels mix sprites and slot frames, so both cases are handled once here rather
## than at each of the three places that move a node.
func _position_of(node: CanvasItem) -> Vector2:
	var node_2d := node as Node2D
	if node_2d != null:
		return node_2d.position
	var control := node as Control
	return control.position if control != null else Vector2.ZERO

func _move(node: CanvasItem, to: Vector2) -> void:
	if not is_instance_valid(node):
		return
	var node_2d := node as Node2D
	if node_2d != null:
		node_2d.position = to
		return
	var control := node as Control
	if control != null:
		control.position = to
