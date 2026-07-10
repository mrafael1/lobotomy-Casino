class_name SacredRules
extends RefCounted

## Native re-statement of the sacred-rule invariants (mirrors
## __tests__/sacred-rules.test.ts). A failure here is a release blocker, not a bug.
## run_all() returns Array[String] of failures (empty == green).

const BRAIN := 0.0   # FixedRNG -> always 'brain' (first weighted symbol)

static func _base_input(overrides: Dictionary = {}) -> Dictionary:
	var input := {
		"neurons": EconomyConst.STARTING_NEURONS,
		"neuronDecayAmount": EconomyConst.NEURON_DECAY_PER_SPIN,
		"freeSpinsRemaining": 0,
		"maxFreeSpins": EconomyConst.BASE_MAX_FREE_SPINS,
		"lucidityMultiplier": 1.0,
		"isFreeSpin": false,
		"lockedReels": [false, false, false],
		"previousReels": null,
		"rng": FixedRNG.new(BRAIN),
		"bookWeight": 0,
		"brainWeightBonus": 0,
		"guaranteedWin": false,
		"pattern23Triple": false,
		"learningActive": false,
	}
	for k in overrides:
		input[k] = overrides[k]
	return input

static func _check(out: Array, cond: bool, label: String) -> void:
	if not cond:
		out.append("SACRED: " + label)

static func run_all() -> Array:
	var out: Array = []

	# 1) Neurons never increase on a regular spin (decay applied). 1 neuron = 1 spin
	# (issue #85), so a regular spin costs exactly NEURON_DECAY_PER_SPIN.
	var expected_after := EconomyConst.STARTING_NEURONS - EconomyConst.NEURON_DECAY_PER_SPIN
	var r1 := Evaluate.evaluate(_base_input({ "rng": FixedRNG.new(BRAIN) }))
	_check(out, int(r1["neuronsAfter"]) == expected_after, "regular spin decays neurons by one spin")

	# 2) Free spins don't consume neurons.
	var r2 := Evaluate.evaluate(_base_input({
		"isFreeSpin": true, "freeSpinsRemaining": 1, "rng": FixedRNG.new(BRAIN),
	}))
	_check(out, int(r2["neuronsAfter"]) == EconomyConst.STARTING_NEURONS, "free spin preserves neurons")

	# 3) Free spins can't chain — a jackpot on a free spin grants no free spin.
	_check(out, int(r2["freeSpinsGranted"]) == 0, "free-spin jackpot grants no free spin")
	# 4) ...but still pays Lucidity (jackpot recognized).
	_check(out, bool(r2["isJackpot"]) and int(r2["scoreEarned"]) > 0, "free-spin jackpot still pays Lucidity")
	# free spin decrements remaining toward 0.
	_check(out, int(r2["freeSpinsAfter"]) == 0, "free spin decrements remaining")

	# 5) A jackpot on a REGULAR spin grants exactly BASE_MAX_FREE_SPINS.
	var r5 := Evaluate.evaluate(_base_input({ "rng": FixedRNG.new(BRAIN) }))
	_check(out, bool(r5["isJackpot"]), "regular brain triple is a jackpot")
	_check(out, int(r5["freeSpinsGranted"]) == Payouts.JACKPOT_FREE_SPIN_GRANT, "regular jackpot grants 1 free spin")
	_check(out, int(r5["freeSpinsAfter"]) == EconomyConst.BASE_MAX_FREE_SPINS, "free spins capped at max")

	# 6) Exit blocked by corruption regardless of banked Lucidity.
	var run := { "lucidityCoins": 10000 }
	_check(out, Endings.check_exit_eligibility(run, { "corruptionEverUsed": true }) == false, "corruption blocks exit")
	_check(out, Endings.check_exit_eligibility(run, { "corruptionEverUsed": false }) == true, "no corruption allows exit when funded")

	# 7) Run-end banks only Lucidity (10%) + history — neurons/score not added to wallet.
	var bank_run := { "neurons": 0, "lucidityCoins": 200, "scoreEarned": 500 }
	var meta := { "schemaVersion": 2, "lucidityWallet": 0, "ownedPermanents": [], "corruptionEverUsed": false, "endingsReached": [], "pendingConsumables": {}, "history": { "runsPlayed": 0, "bestScoreRun": 0 } }
	var banked := Endings.bank_run_to_meta(bank_run, meta, "flatline", 1700000000000)
	_check(out, int(banked["lucidityWallet"]) == 20, "banks 10% of run Lucidity (200 -> 20)")
	_check(out, int(banked["history"]["bestScoreRun"]) == 500, "best score recorded")
	_check(out, int(banked["history"]["runsPlayed"]) == 1, "runsPlayed incremented")
	var smart_meta := meta.duplicate(true)
	smart_meta["ownedPermanents"] = [EconomyConst.SMART_SAVE_UPGRADE_ID]
	var smart_banked := Endings.bank_run_to_meta(bank_run, smart_meta, "flatline", 1700000000000)
	_check(out, int(smart_banked["lucidityWallet"]) == 40, "Smart Save banks 20% of run Lucidity (200 -> 40)")

	# 8) A locked reel keeps its symbol through a forced all-symbol spin (issue
	# #112: Pill flatline must not overwrite a lock into a close call).
	var r8 := Evaluate.evaluate(_base_input({
		"lockedReels": [false, true, false],
		"previousReels": ["eye", "vial", "pill"],
		"forceAllSymbol": "flatline",
		"rng": FixedRNG.new(BRAIN),
	}))
	var r8_reels: Array = r8["reels"]
	_check(out, String(r8_reels[1]) == "vial", "locked reel survives forced flatline")
	_check(out, String(r8_reels[0]) == "flatline" and String(r8_reels[2]) == "flatline",
		"unlocked reels still take the forced symbol")
	_check(out, String(r8["winType"]) != "triple", "lock prevents the forced flatline triple")

	return out
