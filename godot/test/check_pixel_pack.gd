extends SceneTree

## Run with --main-pack to prove the runtime has no source-art dependency.
const MANIFEST := preload("res://art/generated_pixel_manifest.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	for source: String in MANIFEST.TEXTURES:
		var generated := "res://assets/images/" + String(MANIFEST.TEXTURES[source])
		if not ResourceLoader.exists(generated):
			failures.append("Missing generated resource: " + generated)
		if ResourceLoader.exists("res://assets/images/" + source):
			failures.append("Source art was packaged: " + source)
	if not ResourceLoader.exists("res://assets/font/pixel/casino.fnt"):
		failures.append("Bitmap font was not packaged")
	for failure in failures:
		push_error(failure)
	print("Pixel resource pack: ", "PASS" if failures.is_empty() else "FAIL",
		"; ", MANIFEST.TEXTURES.size(), " generated resources; original art excluded")
	quit(0 if failures.is_empty() else 1)
