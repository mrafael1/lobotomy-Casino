extends SceneTree

## Native-resolution visual smoke for the three newly integrated scene masters.
const SCENES := {
	"pacte": "res://scenes/pacte_scene.tscn",
	"choice": "res://scenes/dealer_choice_scene.tscn",
	"shop": "res://scenes/dealer_scene.tscn",
}

func _initialize() -> void:
	var output := OS.get_environment("ART_REVIEW_DIR")
	if output.is_empty():
		output = "tmp/scene-masters"
	DirAccess.make_dir_recursive_absolute(output)
	if DisplayServer.get_name().to_lower() == "headless":
		print("Scene master visual review requires a renderer; skipping headless capture")
		quit()
		return
	var capture := SubViewport.new()
	capture.name = "SceneMasterCapture"
	capture.size = Vector2i(160, 320)
	capture.disable_3d = true
	capture.transparent_bg = false
	capture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture)
	for key: String in SCENES:
		var scene := load(SCENES[key]).instantiate() as Node
		capture.add_child(scene)
		await process_frame
		await process_frame
		var texture := capture.get_texture()
		if texture != null:
			var image := texture.get_image()
			if image != null:
				assert(image.save_png(output.path_join("%s.png" % key)) == OK)
			else:
				push_warning("Scene master capture skipped for %s: renderer returned no image" % key)
		else:
			push_warning("Scene master capture skipped for %s: renderer returned no texture" % key)
		scene.queue_free()
		await process_frame
	capture.queue_free()
	print("Scene master review captured")
	quit()
