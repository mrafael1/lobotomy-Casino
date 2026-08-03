extends SceneTree
## Temporary audit helper: asks the translation table directly for a handful of awkward
## keys — multi-line ones above all, since a CSV field that spans lines is the format's
## easiest thing to get wrong and the tutorial's copy is nothing but multi-line strings.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	TranslationServer.set_locale("fr")
	var keys := [
		"PULL THE LEVER.",
		"EVERY RUN OPENS WITH A PACTE.\nTHE HOUSE DEALS, YOU KEEP ONE.",
		"SETTINGS",
		"EACH RETURN COSTS YOU",
		"EACH RETURN COSTS YOU. REACH WEALTH BEFORE DEATH.",
		"A KEY THAT IS NOT IN THE TABLE",
	]
	print("\n=== fr lookups ===")
	for k in keys:
		var got := TranslationServer.translate(k)
		print("%-12s %s -> %s" % [
			"MISS" if got == k else "hit", k.replace("\n", "\\n"), got.replace("\n", "\\n")])
	quit(0)
