extends SceneTree
## Temporary audit helper: stands up every scene under a locale and reports two things per
## Label/Button/RichTextLabel it finds.
##
##   OVERFLOW — the drawn string is wider than the box it was given. French runs longer
##              than English and this canvas is 160x320, so this is the thing that breaks.
##   UNTRANSLATED — the string came back identical from the translation table. Some of
##              those are legitimately identical in both languages (OPTIONS, COMBO, "%d"),
##              so this is a list to read, not a list of failures.
##
## Only counts what is VISIBLE: a scene carries editor-preview text and hidden states that
## the player never sees, and flagging those buries the real hits.

const SCENES: Array[String] = [
	"res://scenes/start_menu_scene.tscn",
	"res://scenes/options_overlay.tscn",
	"res://scenes/settings_scene.tscn",
	"res://scenes/scores_scene.tscn",
	"res://scenes/collection_scene.tscn",
	"res://scenes/shop_scene.tscn",
	"res://scenes/upgrades_scene.tscn",
	"res://scenes/dealer_scene.tscn",
	"res://scenes/pacte_scene.tscn",
	"res://scenes/machine_scene.tscn",
	"res://scenes/in_run_dealer_offer.tscn",
	"res://scenes/odds_table_overlay.tscn",
]

var _overflow: Array[String] = []
var _untranslated: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var locale := OS.get_environment("SHOT_LOCALE")
	TranslationServer.set_locale(locale if locale != "" else "fr")
	get_root().get_node("RunStateStore").reset_run_state()
	for path in SCENES:
		if not ResourceLoader.exists(path):
			print("missing scene: %s" % path)
			continue
		var scene: Node = (load(path) as PackedScene).instantiate()
		get_root().add_child(scene)
		for i in 10:
			await process_frame
		if scene.has_method("show_overlay"):
			scene.call("show_overlay")
			for i in 4:
				await process_frame
		_walk(path, scene)
		get_root().remove_child(scene)
		scene.queue_free()
		await process_frame
	print("\n=== OVERFLOW @ %s ===" % TranslationServer.get_locale())
	if _overflow.is_empty():
		print("  (none)")
	for row in _overflow:
		print(row)
	print("\n=== UNTRANSLATED (%d distinct) ===" % _untranslated.size())
	for key in _untranslated:
		print("  %-40s %s" % [String(key).replace("\n", "\\n"), _untranslated[key]])
	quit(0)

func _walk(scene_path: String, node: Node) -> void:
	var control := node as Control
	if control != null and control.is_visible_in_tree():
		var source := ""
		if node is Label:
			source = (node as Label).text
		elif node is Button:
			source = (node as Button).text
		elif node is RichTextLabel:
			source = (node as RichTextLabel).text
		if source.strip_edges() != "":
			_check(scene_path, control, source)
	for child in node.get_children():
		_walk(scene_path, child)

func _check(scene_path: String, control: Control, source: String) -> void:
	var drawn := source
	if control.auto_translate_mode != Control.AUTO_TRANSLATE_MODE_DISABLED:
		drawn = TranslationServer.translate(source)
	if drawn == source and not _is_language_neutral(source):
		_untranslated[source] = scene_path.get_file()
	# A wrapping label is allowed to be wider than its box — it wraps. Only a single-line
	# one actually loses or spills its text, and only that is worth reporting.
	if control is RichTextLabel:
		return
	var label := control as Label
	if label != null and label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return
	var font := control.get_theme_font(&"font")
	if font == null:
		return
	var fs := control.get_theme_font_size(&"font_size")
	var widest := 0.0
	for line in drawn.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	if widest > control.size.x + 0.5:
		_overflow.append("  %-26s %-22s %-24s %.0f > %.0f%s" % [
			scene_path.get_file(), control.name,
			drawn.replace("\n", "\\n").left(24), widest, control.size.x,
			"  (CLIPPED)" if label != null and label.clip_text else ""])

## Strings that are the same in both languages by nature rather than by omission: numbers,
## money, symbols, and single letters. Listing those as untranslated is noise.
func _is_language_neutral(text: String) -> bool:
	var stripped := text.strip_edges()
	if stripped.length() <= 1:
		return true
	for i in stripped.length():
		var c := stripped[i]
		if c >= "A" and c <= "Z":
			return false
		if c >= "a" and c <= "z":
			return false
	return true
