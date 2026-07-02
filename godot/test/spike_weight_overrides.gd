extends SceneTree

## Issue #36 spike gate — proves the dealer-odds weight-override layering is safe:
##   1. `Evaluate._build_weights` with overrides never mutates the parity-locked base
##      (`Symbols.WEIGHT` / `Symbols.symbol_weights()`).
##   2. An empty override map builds the exact pinned weights array.
##   3. Overrides are additive per symbol and change draw odds at pick time only.
##
##   godot --headless --path godot -s res://test/spike_weight_overrides.gd

const EvaluateScript := preload("res://rules/evaluate.gd")
const SymbolsScript := preload("res://rules/symbols.gd")
const RngScript := preload("res://rules/rng.gd")

func _fail(failures: Array, msg: String) -> void:
	failures.append(msg)

func _init() -> void:
	print("Spike: per-run weight overrides over parity-locked base...")
	var failures: Array = []

	var base_before := SymbolsScript.symbol_weights()
	var pinned := [
		{ "weight": 6, "value": "brain" },
		{ "weight": 8, "value": "eye" },
		{ "weight": 9, "value": "pill" },
		{ "weight": 9, "value": "syringe" },
		{ "weight": 10, "value": "vial" },
		{ "weight": 10, "value": "flatline" },
	]
	if str(base_before) != str(pinned):
		_fail(failures, "base symbol_weights() drifted before the spike even ran")

	# 1+3: overrides layer additively, order preserved.
	var overridden: Array = EvaluateScript._build_weights(0, 0, { "eye": 3, "vial": 2 })
	var expected := [
		{ "weight": 6, "value": "brain" },
		{ "weight": 11, "value": "eye" },
		{ "weight": 9, "value": "pill" },
		{ "weight": 9, "value": "syringe" },
		{ "weight": 12, "value": "vial" },
		{ "weight": 10, "value": "flatline" },
	]
	if str(overridden) != str(expected):
		_fail(failures, "override layering wrong: %s" % str(overridden))

	# Overrides stack WITH the brain bonus and the book row.
	var stacked: Array = EvaluateScript._build_weights(2, 7, { "brain": 1, "book": 1 })
	if str(stacked[0]) != str({ "weight": 9, "value": "brain" }):
		_fail(failures, "brain bonus + override should stack: %s" % str(stacked[0]))
	if str(stacked[6]) != str({ "weight": 8, "value": "book" }):
		_fail(failures, "book weight + override should stack: %s" % str(stacked[6]))

	# 1: the parity-locked base is untouched after building with overrides.
	if str(SymbolsScript.symbol_weights()) != str(pinned):
		_fail(failures, "MUTATION: symbol_weights() changed after override build")
	if int(SymbolsScript.WEIGHT["eye"]) != 8:
		_fail(failures, "MUTATION: Symbols.WEIGHT changed after override build")

	# 2: empty map reproduces the pinned array exactly (vector-parity path).
	if str(EvaluateScript._build_weights(0, 0, {})) != str(pinned):
		_fail(failures, "empty overrides must reproduce the pinned weights")
	if str(EvaluateScript._build_weights(0, 0)) != str(EvaluateScript._build_weights(0, 0, {})):
		_fail(failures, "default arg must equal explicit empty overrides")

	# 3: identical seed, identical inputs — evaluate() with no overrides matches the
	# old behaviour; a heavy override shifts the draw, proving pick-time layering.
	var mk_input := func(overrides: Dictionary, seed: int) -> Dictionary:
		var input := {
			"neurons": 50, "neuronDecayAmount": 1, "freeSpinsRemaining": 0,
			"maxFreeSpins": 3, "lucidityMultiplier": 1.0, "isFreeSpin": false,
			"lockedReels": [false, false, false], "previousReels": null,
			"rng": RngScript.new(seed), "bookWeight": 0, "brainWeightBonus": 0,
			"guaranteedWin": false, "pattern23Triple": false, "learningActive": false,
		}
		if not overrides.is_empty():
			input["weightOverrides"] = overrides
		return input

	var drifted := false
	for seed in range(1, 40):
		var plain: Dictionary = EvaluateScript.evaluate(mk_input.call({}, seed))
		var noop: Dictionary = EvaluateScript.evaluate(mk_input.call({}, seed))
		if str(plain["reels"]) != str(noop["reels"]):
			_fail(failures, "evaluate() not deterministic for seed %d" % seed)
		var heavy: Dictionary = EvaluateScript.evaluate(mk_input.call({ "brain": 1000 }, seed))
		if str(heavy["reels"]) != str(plain["reels"]):
			drifted = true
	if not drifted:
		_fail(failures, "a +1000 brain override never changed a draw — overrides are dead")

	if failures.is_empty():
		print("✓ Spike PASSED: overrides layer additively at pick time; base weights untouched.")
		quit(0)
	else:
		for f in failures:
			printerr("✗ ", f)
		quit(1)
