extends SceneTree

## Reduce generated masters to the native canvas, or the declared UI asset size.
## Nearest sampling preserves their authored pixel clusters for runtime filtering.
const JOBS := [
	["res://assets/images/options_polished/menu_panel_painted.png", "res://assets/images/options_polished/menu_panel_native.png", Vector2i(144, 252)],
	["res://assets/images/settings_polished/audio_console_painted.png", "res://assets/images/settings_polished/audio_console_native.png"],
	["res://assets/images/pacte_polished/pacte_scene_painted.png", "res://assets/images/pacte_polished/pacte_scene_native.png"],
	["res://assets/images/dealer_choice_polished/choice_scene_painted.png", "res://assets/images/dealer_choice_polished/choice_scene_native.png"],
	["res://assets/images/dealer_shop_polished/pre_dealer_shop_painted.png", "res://assets/images/dealer_shop_polished/pre_dealer_shop_native.png"],
]

func _initialize() -> void:
	for job: Array in JOBS:
		var source := Image.load_from_file(ProjectSettings.globalize_path(String(job[0])))
		assert(source != null, "Missing scene master: %s" % job[0])
		source.convert(Image.FORMAT_RGBA8)
		var target_size: Vector2i = job[2] if job.size() > 2 else Vector2i(160, 320)
		source.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
		assert(source.save_png(ProjectSettings.globalize_path(String(job[1]))) == OK)
	print("Scene masters reduced with nearest sampling")
	quit()
