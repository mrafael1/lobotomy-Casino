extends SceneTree

const ParityChecks := preload("res://test/parity_checks.gd")
const SacredRules := preload("res://test/sacred_rules.gd")
const SaveChecks := preload("res://test/save_checks.gd")

## No-dependency parity runner — verify the GDScript rules core against the golden
## vectors WITHOUT installing GUT.
##
##   godot --headless --path godot -s res://test/run_parity_headless.gd
##
## Exits 0 when every parity vector + sacred-rule invariant matches, 1 otherwise.
## This is the canonical Milestone-1 gate; the GUT suite (test/test_*.gd) wraps the
## same checks for editor/CI integration.

func _init() -> void:
	print("Starting Godot parity harness...")
	var failures: Array = []
	print("Running parity vector checks...")
	failures.append_array(ParityChecks.run_all())
	print("Running sacred-rule checks...")
	failures.append_array(SacredRules.run_all())
	print("Running save/migration checks...")
	failures.append_array(SaveChecks.run_all())

	if failures.is_empty():
		print("✓ Parity + sacred-rule checks PASSED (rules/content matches the golden vectors).")
		quit(0)
	else:
		for f in failures:
			printerr("✗ ", f)
		printerr("\nFAILED: %d check(s) diverged from the golden vectors." % failures.size())
		quit(1)
