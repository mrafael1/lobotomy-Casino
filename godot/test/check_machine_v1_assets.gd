extends SceneTree

## Validate the new art as an independent Godot consumer, without run mutations.
const BASE := "res://assets/art_direction/house_remembers/machine_v1/"

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASE + "manifest.json"))
	if not parsed is Dictionary:
		_fail("Missing or invalid v1 package manifest")
		return
	var manifest := parsed as Dictionary
	var files := manifest["files"] as Dictionary
	var images: Dictionary = {}
	for relative: String in files:
		var texture := load(BASE + relative) as Texture2D
		if texture == null:
			_fail("Godot cannot import " + relative)
			return
		var image := texture.get_image()
		if image == null or texture.get_size() != Vector2(image.get_size()):
			_fail("Imported texture dimensions differ: " + relative)
			return
		if image.is_compressed() and image.decompress() != OK:
			_fail("Cannot inspect imported texture: " + relative)
			return
		image.convert(Image.FORMAT_RGBA8)
		images[relative] = image
	var states := manifest["states"] as Dictionary
	var checks := 0
	for key: String in ["x1_0", "x2_0", "x3_0", "rescue_x2", "rescue_x3", "win_x1"]:
		var assembled := Image.create_empty(640, 1280, false, Image.FORMAT_RGBA8)
		var state := states[key] as Dictionary
		for value: Dictionary in state["layers"]:
			var source := images[String(value["file"])] as Image
			var bounds := value["source_rect"] as Array
			if source.get_size() != Vector2i(int(bounds[2]), int(bounds[3])):
				_fail("Invalid crop registration in " + key)
				return
			assembled.blend_rect(source, Rect2i(Vector2i.ZERO, source.get_size()),
				Vector2i(int(bounds[0]), int(bounds[1])))
		var reference := load(BASE + "review/runtime_" + key + ".png") as Texture2D
		if reference == null:
			_fail("Missing assembly reference: " + key)
			return
		var expected := reference.get_image()
		if expected.is_compressed() and expected.decompress() != OK:
			_fail("Cannot inspect assembly reference: " + key)
			return
		expected.convert(Image.FORMAT_RGBA8)
		if assembled.get_data() != expected.get_data():
			_fail("Godot layer composition differs: " + key)
			return
		checks += 1
	print("V1 ASSET CHECK PASSED: %d imported textures; %d exact registered assemblies; no run mutations." % [files.size(), checks])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
