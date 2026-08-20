extends Node

## Minimal scene return stack for menu-like screens opened from multiple contexts.

const DEFAULT_MENU_SCENE := "res://scenes/start_menu_scene.tscn"
const NATIVE_CANVAS_SIZE := Vector2(160.0, 320.0)
const TRANSITION_SCRIPT := preload("res://autoload/scene_transition.gd")

enum TransitionKind {
	NORMAL,
	DOOR,
	FLATLINE,
	WALLET,
}

signal transition_started(kind: int, target_scene: String)
signal transition_finished(kind: int, target_scene: String)

var _back_stack: Array[Dictionary] = []
var _restore_options_scene := ""
# Process-wide PackedScene cache: repeat transitions (menu ↔ machine ↔ lab) skip
# the synchronous disk load, so subsequent opens are noticeably faster on device.
var _scene_cache: Dictionary = {}
var _transition_layer: CanvasLayer = null
var _transition_overlay: Control = null
var _transition_active := false
var _transition_serial := 0
var _transition_kind := TransitionKind.NORMAL
var _transition_target := ""
var _suspended_scene: Node = null
var _suspended_scene_process_mode := Node.PROCESS_MODE_INHERIT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_content_scale()
	_build_transition_layer()
	get_viewport().size_changed.connect(_layout_transition_overlay)
	_layout_transition_overlay()


## Keep ordinary scenes on the original 160x320 canvas. Pacte's new room exports
## are 200x380 and are the one deliberate exception: their decorative bleed may
## occupy the extra phone viewport while their gameplay controls remain native.
## Switching this at the scene boundary prevents the expanded logical bounds from
## moving every other scene's authored controls away from the old canvas.
func _configure_content_scale(scene_path: String = "") -> void:
	var root_view := get_tree().root
	root_view.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var target_path := scene_path
	if target_path.is_empty():
		var current := get_tree().current_scene
		target_path = String(current.scene_file_path) if current != null else ""
	root_view.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND \
		if _uses_expanded_pacte_canvas(target_path) else Window.CONTENT_SCALE_ASPECT_KEEP
	root_view.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
	root_view.content_scale_size = Vector2i(160, 320)

func _uses_expanded_pacte_canvas(scene_path: String) -> bool:
	return scene_path.ends_with("pacte_scene.tscn") \
		or scene_path.ends_with("route_build_scene.tscn")


func _build_transition_layer() -> void:
	_transition_layer = CanvasLayer.new()
	_transition_layer.name = "SceneTransitionLayer"
	_transition_layer.layer = 1000
	_transition_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_transition_layer)
	_transition_overlay = TRANSITION_SCRIPT.new() as Control
	_transition_overlay.name = "SceneTransition"
	_transition_overlay.position = Vector2.ZERO
	_transition_overlay.size = NATIVE_CANVAS_SIZE
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_layer.add_child(_transition_overlay)

func _layout_transition_overlay() -> void:
	if _transition_overlay == null or not is_instance_valid(_transition_overlay):
		return
	var extra_size: Vector2 = get_viewport().get_visible_rect().size - NATIVE_CANVAS_SIZE
	_transition_overlay.position = Vector2(maxf(0.0, extra_size.x * 0.5),
		maxf(0.0, extra_size.y * 0.5))


## True while the persistent transition cover owns the screen and gameplay input.
func is_transition_active() -> bool:
	return _transition_active


## The current transition style is exposed for scene-level guards and smoke checks.
func active_transition_kind() -> int:
	return _transition_kind


func transition_overlay() -> Control:
	return _transition_overlay

func cached_scene(scene_path: String) -> PackedScene:
	var ps: PackedScene = _scene_cache.get(scene_path, null)
	if ps == null:
		ps = load(scene_path) as PackedScene
		if ps != null:
			_scene_cache[scene_path] = ps
	return ps

## Central scene-change API. Existing callers remain valid; priority paths can pass a
## TransitionKind and the selected route-door side (0 = left, 1 = right). A WALLET
## transition also carries the visible balance before and after machine deductions.
func change_to(scene_path: String, kind: int = -1, door_side: int = -1,
		wallet_start: int = -1, wallet_end: int = -1) -> void:
	if scene_path.is_empty() or _transition_active:
		return
	_transition_kind = _resolve_transition_kind(scene_path, kind)
	_transition_target = scene_path
	_transition_active = true
	_transition_serial += 1
	var serial := _transition_serial
	transition_started.emit(_transition_kind, scene_path)
	_run_transition(scene_path, _transition_kind, door_side, wallet_start, wallet_end,
		serial)


func _resolve_transition_kind(scene_path: String, requested_kind: int) -> int:
	if requested_kind >= 0:
		return requested_kind
	var current := get_tree().current_scene
	var current_path := String(current.scene_file_path) if current != null else ""
	var is_route_choice := current_path.ends_with("dealer_choice_scene.tscn") \
		or current_path.ends_with("route_scene.tscn")
	if is_route_choice and not scene_path.ends_with("dealer_choice_scene.tscn") \
		and not scene_path.ends_with("route_scene.tscn"):
		return TransitionKind.DOOR
	return TransitionKind.NORMAL


func _run_transition(scene_path: String, kind: int, door_side: int,
		wallet_start: int, wallet_end: int, serial: int) -> void:
	if _transition_overlay != null and is_instance_valid(_transition_overlay):
		await _transition_overlay.play_exit(kind, door_side, wallet_start, wallet_end)
	if serial != _transition_serial:
		return
	if kind == TransitionKind.WALLET and _transition_overlay != null \
			and is_instance_valid(_transition_overlay):
		_transition_overlay.begin_wallet_transfer(wallet_start, wallet_end)
	_suspend_current_scene()
	var packed_scene := await _load_scene(scene_path)
	if serial != _transition_serial:
		return
	if packed_scene == null:
		_restore_suspended_scene()
		await _play_entrance(kind)
		if serial != _transition_serial:
			return
		_finish_transition(serial)
		return
	var change_error := get_tree().change_scene_to_packed(packed_scene)
	if change_error != OK:
		_configure_content_scale()
		_restore_suspended_scene()
		await _play_entrance(kind)
		if serial != _transition_serial:
			return
		_finish_transition(serial)
		return
	# change_scene_to_packed() swaps at the frame boundary. Waiting twice keeps the
	# entrance transition from revealing a scene before its _ready() and deferred HUD
	# setup have completed.
	_configure_content_scale(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	if serial != _transition_serial:
		return
	await _play_entrance(kind)
	if serial != _transition_serial:
		return
	_finish_transition(serial)


func _play_entrance(kind: int) -> void:
	if _transition_overlay == null or not is_instance_valid(_transition_overlay):
		return
	await _transition_overlay.play_entrance()
	if kind != TransitionKind.WALLET:
		return
	await _transition_overlay.wait_for_wallet_transfer()
	_transition_overlay.finish_wallet_handoff()


func _suspend_current_scene() -> void:
	_suspended_scene = get_tree().current_scene
	if _suspended_scene == null:
		return
	_suspended_scene_process_mode = _suspended_scene.process_mode
	_suspended_scene.process_mode = Node.PROCESS_MODE_DISABLED


func _restore_suspended_scene() -> void:
	if _suspended_scene != null and is_instance_valid(_suspended_scene):
		_suspended_scene.process_mode = _suspended_scene_process_mode
	_suspended_scene = null


func _finish_transition(serial: int) -> void:
	if serial != _transition_serial:
		return
	_restore_suspended_scene()
	_transition_active = false
	transition_finished.emit(_transition_kind, _transition_target)


func _load_scene(scene_path: String) -> PackedScene:
	var cached: PackedScene = _scene_cache.get(scene_path, null)
	if cached != null:
		return cached
	var request_error := ResourceLoader.load_threaded_request(scene_path, "PackedScene", true)
	if request_error != OK:
		return load(scene_path) as PackedScene
	while true:
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(scene_path, progress)
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await get_tree().process_frame
			ResourceLoader.THREAD_LOAD_LOADED:
				var threaded_scene := ResourceLoader.load_threaded_get(scene_path) as PackedScene
				if threaded_scene != null:
					_scene_cache[scene_path] = threaded_scene
				return threaded_scene
			_:
				push_error("SceneNav: failed to load transition destination %s" % scene_path)
				return load(scene_path) as PackedScene
	return null


func _input(_event: InputEvent) -> void:
	if _transition_active:
		get_viewport().set_input_as_handled()

func push_current_scene(restore_options: bool = false) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	push_scene(String(current_scene.scene_file_path), restore_options)

func push_scene(scene_path: String, restore_options: bool = false) -> void:
	if scene_path.is_empty():
		return
	if not _back_stack.is_empty() and String(_back_stack.back().get("scene", "")) == scene_path:
		return
	_back_stack.append({
		"scene": scene_path,
		"restore_options": restore_options,
	})

func go_back(fallback_scene: String = DEFAULT_MENU_SCENE) -> void:
	var target_scene: String = fallback_scene
	var restore_options := false
	while not _back_stack.is_empty():
		var entry: Dictionary = _back_stack.pop_back()
		var candidate := String(entry.get("scene", ""))
		if not candidate.is_empty():
			target_scene = candidate
			restore_options = bool(entry.get("restore_options", false))
			break
	_restore_options_scene = target_scene if restore_options else ""
	change_to(target_scene)

func go_to_menu(menu_scene: String = DEFAULT_MENU_SCENE) -> void:
	_back_stack.clear()
	_restore_options_scene = ""
	change_to(menu_scene)

func clear() -> void:
	cancel_transition()
	_back_stack.clear()
	_restore_options_scene = ""
	_pending_feedback.clear()


func cancel_transition() -> void:
	_transition_serial += 1
	_transition_active = false
	_restore_suspended_scene()
	if _transition_overlay != null and is_instance_valid(_transition_overlay):
		_transition_overlay.cancel()

func peek_back_scene() -> String:
	return "" if _back_stack.is_empty() else String(_back_stack.back().get("scene", ""))

func peek_back_restores_options() -> bool:
	return false if _back_stack.is_empty() else bool(_back_stack.back().get("restore_options", false))

func consume_restore_options(scene_path: String) -> bool:
	if _restore_options_scene.is_empty():
		return false
	if not scene_path.is_empty() and _restore_options_scene != scene_path:
		return false
	_restore_options_scene = ""
	return true

# ── Pending scene feedback (issue #132) ────────────────────────────────────────────
# Some purchases pay off on a screen the player is not looking at: buying Extra Spins at
# the dealer has to animate the machine's spin tube, which only exists after the dealer
# closes. The buyer leaves a note here and the target scene reads it once on entry.
#
# This is PRESENTATION state and deliberately lives nowhere near a save: a note that is
# never collected (the player quits at the dealer) must evaporate, not resurface next
# session and replay an animation for a purchase made an hour ago. Gameplay state that
# has to survive — emergencyReserveUsed, the purchased chips — is on MetaStateStore.
var _pending_feedback: Array[Dictionary] = []

## Leaves a note for whichever scene handles `id` next. Extra calls stack in order.
func queue_feedback(id: String, data: Dictionary = {}) -> void:
	if id.is_empty():
		return
	_pending_feedback.append({ "id": id, "data": data.duplicate(true) })

## Takes every queued note and empties the queue — a note is delivered at most once.
func take_pending_feedback() -> Array[Dictionary]:
	var out := _pending_feedback.duplicate()
	_pending_feedback.clear()
	return out

func has_pending_feedback() -> bool:
	return not _pending_feedback.is_empty()
