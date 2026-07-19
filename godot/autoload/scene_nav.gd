extends Node

## Minimal scene return stack for menu-like screens opened from multiple contexts.

const DEFAULT_MENU_SCENE := "res://scenes/start_menu_scene.tscn"

var _back_stack: Array[Dictionary] = []
var _restore_options_scene := ""
# Process-wide PackedScene cache: repeat transitions (menu ↔ machine ↔ lab) skip
# the synchronous disk load, so subsequent opens are noticeably faster on device.
var _scene_cache: Dictionary = {}

func cached_scene(scene_path: String) -> PackedScene:
	var ps: PackedScene = _scene_cache.get(scene_path, null)
	if ps == null:
		ps = load(scene_path) as PackedScene
		if ps != null:
			_scene_cache[scene_path] = ps
	return ps

## Cached replacement for get_tree().change_scene_to_file().
func change_to(scene_path: String) -> void:
	var ps := cached_scene(scene_path)
	if ps != null:
		get_tree().change_scene_to_packed(ps)
	else:
		get_tree().change_scene_to_file(scene_path)

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
	_back_stack.clear()
	_restore_options_scene = ""

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
