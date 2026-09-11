extends SceneTree

## Reduce generated scene masters once to the game's native 160x320 canvas.
## Nearest sampling preserves their authored pixel clusters for runtime filtering.
const JOBS := [
	["res://assets/images/pacte_polished/pacte_scene_painted.png", "res://assets/images/pacte_polished/pacte_scene_native.png"],
	["res://assets/images/dealer_choice_polished/choice_scene_painted.png", "res://assets/images/dealer_choice_polished/choice_scene_native.png"],
	["res://assets/images/dealer_shop_polished/pre_dealer_shop_painted.png", "res://assets/images/dealer_shop_polished/pre_dealer_shop_native.png"],
]

func _initialize() -> void:
	for job: Array in JOBS:
		var source := Image.load_from_file(ProjectSettings.globalize_path(String(job[0])))
		assert(source != null, "Missing scene master: %s" % job[0])
		source.convert(Image.FORMAT_RGBA8)
		source.resize(160, 320, Image.INTERPOLATE_NEAREST)
		assert(source.save_png(ProjectSettings.globalize_path(String(job[1]))) == OK)
	print("Scene masters reduced with nearest sampling")
	quit()
