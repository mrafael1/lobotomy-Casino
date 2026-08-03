extends SceneTree
## Verification helper for seam 4.5b: dumps the nine reel symbol sprites' actual
## transforms, which is the part of this seam the smoke suite cannot see.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_store: Node = get_root().get_node("RunStateStore")
	run_store.start_new_run([], {}, false)
	var scene := (load("res://scenes/machine_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 4:
		await process_frame
	var rs = scene._reel_symbols
	rs.set_symbol(0, "eye")
	rs.set_visible(0, true)
	for slot in [["center", rs.center(0)], ["top", rs.top(0)], ["bottom", rs.bottom(0)]]:
		var s: Sprite2D = slot[1]
		print("%s pos=%s scale=%.4f alpha=%.2f tex=%s" % [
			slot[0], str(s.position), s.scale.y, s.modulate.a,
			s.texture.resource_path.get_file()])
	print("heart neighbours of heart_x2: %s" % str(rs.neighbours_of("heart_x2")))
	print("book neighbours: %s" % str(rs.neighbours_of("book")))
	quit(0)
