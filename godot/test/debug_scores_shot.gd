extends SceneTree
## Temporary debug helper (issue #142): open the scores scene with seeded
## history data and save screenshots for visual inspection. Never saves meta.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var meta: Node = get_root().get_node("MetaStateStore")
	meta.history = {
		"runsPlayed": 42,
		"bestScoreRun": 1337,
		"playtimeMs": 5 * 3600 * 1000 + 23 * 60 * 1000,
		"winsByTier": { "classic": 3, "heart": 1, "joker": 2 },
		"runsByTier": { "classic": 30, "heart": 6, "joker": 4 },
		"wealthEndingReachedAt": 1752345600000,
		"wealthEndingPlaytimeMs": 3 * 3600 * 1000 + 12 * 60 * 1000,
		"exitEndingReachedAt": 1752518400000,
		"exitEndingPlaytimeMs": 4 * 3600 * 1000 + 55 * 60 * 1000,
	}
	meta.endingsReached = ["wealth", "exit"]
	var scene := (load("res://scenes/scores_scene.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for i in 8:
		await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_PATH"))
	scene._cycle_tier(5) # joker: wide arrow pair
	for i in 4:
		await process_frame
	get_root().get_texture().get_image().save_png(OS.get_environment("SHOT_PATH_JOKER"))
	quit(0)
