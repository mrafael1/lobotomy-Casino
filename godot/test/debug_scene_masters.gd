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
	for key: String in SCENES:
		var scene := load(SCENES[key]).instantiate() as Node
		root.add_child(scene)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join("%s.png" % key)) == OK)
		scene.queue_free()
		await process_frame
	print("Scene master review captured")
	quit()
