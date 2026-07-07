extends SceneTree

const CANVAS_SIZE := Vector2i(160, 320)
const DEFAULT_SCENES_DIR := "res://scenes"
const DEFAULT_OUTPUT_DIR := "res://.tmp/scene_renders_1to1"
const IMAGE_EXTENSION := ".png"
const SCENE_EXTENSION := ".tscn"
const SETTLE_FRAMES := 3

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := _arg_value("--output", DEFAULT_OUTPUT_DIR)
	var scenes_dir := _arg_value("--scenes", DEFAULT_SCENES_DIR)
	var scene_paths := _find_scene_paths(scenes_dir)

	if scene_paths.is_empty():
		_fail("No .tscn files found under %s" % scenes_dir)
	else:
		_prepare_output_dir(output_dir)
		for scene_path in scene_paths:
			await _render_scene(scene_path, output_dir)

	if _failures.is_empty():
		print("Rendered %d scene(s) at %dx%d into %s" % [
			scene_paths.size(),
			CANVAS_SIZE.x,
			CANVAS_SIZE.y,
			ProjectSettings.globalize_path(output_dir),
		])
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _arg_value(flag: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == flag and i + 1 < args.size():
			return args[i + 1]
		if args[i].begins_with("%s=" % flag):
			return args[i].trim_prefix("%s=" % flag)
	return fallback


func _find_scene_paths(dir_path: String) -> Array[String]:
	var paths: Array[String] = []
	_collect_scene_paths(dir_path.trim_suffix("/"), paths)
	paths.sort()
	return paths


func _collect_scene_paths(dir_path: String, paths: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		_fail("Could not open scene directory: %s" % dir_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		var child_path := "%s/%s" % [dir_path, file_name]
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_collect_scene_paths(child_path, paths)
		elif file_name.ends_with(SCENE_EXTENSION):
			paths.append(child_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _prepare_output_dir(output_dir: String) -> void:
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if err != OK:
		_fail("Could not create output directory %s: %s" % [output_dir, error_string(err)])


func _render_scene(scene_path: String, output_dir: String) -> void:
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		_fail("%s failed to load as PackedScene" % scene_path)
		return

	var scene := packed_scene.instantiate()
	if scene == null:
		_fail("%s failed to instantiate" % scene_path)
		return

	var viewport := _build_viewport()
	root.add_child(viewport)
	viewport.add_child(scene)
	_prepare_scene_root(scene)

	for i in range(SETTLE_FRAMES):
		await process_frame

	var texture := viewport.get_texture()
	if texture == null:
		_fail("%s produced no viewport texture" % scene_path)
		viewport.queue_free()
		return

	var image := texture.get_image()
	if image == null or image.is_empty():
		_fail("%s produced an empty image" % scene_path)
		viewport.queue_free()
		return

	if image.get_size() != CANVAS_SIZE:
		_fail("%s rendered at %s, expected %s" % [scene_path, image.get_size(), CANVAS_SIZE])
		viewport.queue_free()
		return

	var output_path := "%s/%s%s" % [
		output_dir.trim_suffix("/"),
		scene_path.get_file().get_basename(),
		IMAGE_EXTENSION,
	]
	var err := image.save_png(output_path)
	if err != OK:
		_fail("%s could not save %s: %s" % [scene_path, output_path, error_string(err)])
	else:
		print("%s -> %s" % [scene_path, ProjectSettings.globalize_path(output_path)])

	viewport.queue_free()
	await process_frame


func _build_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = CANVAS_SIZE
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return viewport


func _prepare_scene_root(scene: Node) -> void:
	if scene is Window:
		var window := scene as Window
		window.size = CANVAS_SIZE
	elif scene is Control:
		var control := scene as Control
		control.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		control.position = Vector2.ZERO
		control.size = Vector2(CANVAS_SIZE)
	elif scene is Node2D:
		var node_2d := scene as Node2D
		node_2d.position = Vector2.ZERO


func _fail(message: String) -> void:
	_failures.append("render_scenes_1to1: %s" % message)
