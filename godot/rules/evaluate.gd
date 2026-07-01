class_name Evaluate
extends RefCounted

## Port of src/game/evaluate.ts — scoreReels() and evaluate(), the single source of
## truth for a spin. Mirrors JS Math.round (half toward +∞) with floor(x + 0.5);
## all scores here are non-negative so this is exact.

static func _round(x: float) -> int:
	return floori(x + 0.5)

# Deterministic non-excluded reel symbol (issue #32, Serum). Picks along the
# canonical visible cycle so it never lands on `book` or the excluded symbol.
static func _pick_non_excluded(excluded: String, rng: LobRNG) -> String:
	var pool: Array = []
	for s in Symbols.BASE_SYMBOL_CYCLE:
		if String(s) != excluded:
			pool.append(String(s))
	if pool.is_empty():
		return excluded
	return String(pool[int(rng.next() * pool.size())])

# Mirrors buildWeights(brainWeightBonus, bookWeight).
static func _build_weights(brain_bonus: int, book_weight: int) -> Array:
	var weights := Symbols.symbol_weights() # fresh array each call
	if brain_bonus > 0:
		var nw := []
		for w in weights:
			if w["value"] == "brain":
				nw.append({ "weight": int(w["weight"]) + brain_bonus, "value": "brain" })
			else:
				nw.append(w)
		weights = nw
	if book_weight > 0:
		weights.append({ "weight": book_weight, "value": "book" })
	return weights

# scoreReels(reels, lucidityMultiplier, allowFreeSpinGrant, pattern23Triple, learningActive)
static func score_reels(reels: Array, lucidity_multiplier: float, allow_free_spin_grant: bool,
		pattern23_triple: bool = false, learning_active: bool = false,
		pair_score_mult: float = 1.0, hidden_reel_count: int = 0) -> Dictionary:
	var a := String(reels[0])
	var b := String(reels[1])
	var c := String(reels[2])

	# Tobacco (issue #32): one or more reels go dark and only the visible remainder
	# scores — no triples, any visible pair pays at pair_score_mult. Gated so the
	# default path (hidden_reel_count == 0) is byte-for-byte the pinned behaviour.
	if hidden_reel_count > 0:
		var visible: Array = reels.slice(0, maxi(1, reels.size() - hidden_reel_count))
		var v_book := 0
		if learning_active:
			var vb := 0
			for r in visible:
				if String(r) == "book":
					vb += 1
			v_book = vb * Payouts.BOOK_BONUS_PER_VISIBLE
		var vmatch := ""
		for i in range(visible.size() - 1):
			if String(visible[i]) == String(visible[i + 1]):
				vmatch = String(visible[i])
				break
		if vmatch != "":
			var vs := _round((int(Payouts.PAIR_SCORE.get(vmatch, 0)) * pair_score_mult + v_book) * lucidity_multiplier)
			return { "winType": "pair", "scoreEarned": vs, "coinsEarned": vs, "freeSpinsGranted": 0 }
		var vms := _round(v_book * lucidity_multiplier) if v_book > 0 else 0
		return { "winType": "miss", "scoreEarned": vms, "coinsEarned": vms, "freeSpinsGranted": 0 }

	var book_bonus := 0
	if learning_active:
		var books := 0
		for r in reels:
			if String(r) == "book":
				books += 1
		book_bonus = books * Payouts.BOOK_BONUS_PER_VISIBLE

	# Triple: all three identical
	if a == b and b == c:
		if a == "brain":
			var score := _round((Payouts.JACKPOT_SCORE + book_bonus) * lucidity_multiplier)
			return {
				"winType": "jackpot", "scoreEarned": score, "coinsEarned": score,
				"freeSpinsGranted": Payouts.JACKPOT_FREE_SPIN_GRANT if allow_free_spin_grant else 0,
			}
		var tscore := _round((int(Payouts.TRIPLE_SCORE.get(a, 0)) + book_bonus) * lucidity_multiplier)
		return { "winType": "triple", "scoreEarned": tscore, "coinsEarned": tscore, "freeSpinsGranted": 0 }

	# Pattern Fabrication: any two identical reels pay as a doubled pair.
	if pattern23_triple:
		var match_sym := ""
		if a == b: match_sym = a
		elif b == c: match_sym = b
		elif a == c: match_sym = a
		if match_sym != "":
			var pscore := _round(((int(Payouts.PAIR_SCORE.get(match_sym, 0)) * 2) + book_bonus) * lucidity_multiplier)
			return { "winType": "pair", "scoreEarned": pscore, "coinsEarned": pscore, "freeSpinsGranted": 0 }
	else:
		# Standard adjacent pair (a==b or b==c; a==c without b match is a miss)
		if a == b or b == c:
			var match_symbol := a if a == b else b
			var pscore2 := _round((int(Payouts.PAIR_SCORE.get(match_symbol, 0)) + book_bonus) * lucidity_multiplier)
			return { "winType": "pair", "scoreEarned": pscore2, "coinsEarned": pscore2, "freeSpinsGranted": 0 }

	# Miss — still pay book bonus if Learning active.
	var miss_score := _round(book_bonus * lucidity_multiplier) if book_bonus > 0 else 0
	return { "winType": "miss", "scoreEarned": miss_score, "coinsEarned": miss_score, "freeSpinsGranted": 0 }

# evaluate(input) — `input` is a Dictionary mirroring SpinInput, with "rng": LobRNG.
# Locked reels keep previousReels WITHOUT consuming the RNG (matches the JS &&/ternary
# short-circuit), which is load-bearing for RNG-sequence parity.
static func evaluate(input: Dictionary) -> Dictionary:
	var neurons := int(input["neurons"])
	var neuron_decay := int(input["neuronDecayAmount"])
	var free_spins_remaining := int(input["freeSpinsRemaining"])
	var max_free_spins := int(input["maxFreeSpins"])
	var lucidity_multiplier := float(input["lucidityMultiplier"])
	var is_free_spin: bool = input["isFreeSpin"]
	var locked: Array = input["lockedReels"]
	var prev: Variant = input["previousReels"]
	var rng: LobRNG = input["rng"]
	var book_weight := int(input["bookWeight"])
	var brain_weight_bonus := int(input["brainWeightBonus"])
	var guaranteed_win: bool = input["guaranteedWin"]
	var pattern23: bool = input["pattern23Triple"]
	var learning: bool = input["learningActive"]
	# Consumable reel transforms (issue #32) — all optional, no-op at their defaults so
	# every pinned vector (which omits them) scores exactly as before.
	var force_all_symbol: Variant = input.get("forceAllSymbol", null)
	var force_triple_from: Variant = input.get("forceTripleFrom", null)
	var exclude_symbol: Variant = input.get("excludeSymbol", null)
	var ban_excluded: bool = bool(input.get("banExcluded", false))
	var guarantee_non_excluded: bool = bool(input.get("guaranteeNonExcluded", false))
	var symbol_to_brain_count := int(input.get("symbolToBrainCount", 0))
	var pair_score_mult := float(input.get("pairScoreMult", 1.0))
	var hidden_reel_count := int(input.get("hiddenReelCount", 0))

	var weights := _build_weights(brain_weight_bonus, book_weight)

	var reels := [
		prev[0] if (bool(locked[0]) and prev != null) else LobRNG.weighted_pick(weights, rng),
		prev[1] if (bool(locked[1]) and prev != null) else LobRNG.weighted_pick(weights, rng),
		prev[2] if (bool(locked[2]) and prev != null) else LobRNG.weighted_pick(weights, rng),
	]

	if guaranteed_win:
		var temp := score_reels(reels, 1.0, false, pattern23, learning)
		if temp["winType"] == "miss":
			reels = [reels[0], reels[0], reels[2]]

	# Gated consumable reel transforms, mirroring evaluate.ts.
	if force_all_symbol != null:
		reels = [force_all_symbol, force_all_symbol, force_all_symbol]
	elif force_triple_from != null and (force_triple_from as Array).size() > 0:
		var pool: Array = force_triple_from
		var pick: Variant = pool[int(rng.next() * pool.size())]
		reels = [pick, pick, pick]
	else:
		if ban_excluded and exclude_symbol != null:
			for i in 3:
				if String(reels[i]) == String(exclude_symbol):
					reels[i] = _pick_non_excluded(String(exclude_symbol), rng)
		if symbol_to_brain_count > 0:
			for i in mini(symbol_to_brain_count, 3):
				reels[i] = "brain"
		if guarantee_non_excluded and exclude_symbol != null:
			var all_excluded := true
			for r in reels:
				if String(r) != String(exclude_symbol):
					all_excluded = false
					break
			if all_excluded:
				reels[0] = _pick_non_excluded(String(exclude_symbol), rng)

	var neurons_after := neurons if is_free_spin else maxi(0, neurons - neuron_decay)

	# Free spins NEVER generate free spins (structural enforcement).
	var score := score_reels(reels, lucidity_multiplier, not is_free_spin, pattern23, learning, pair_score_mult, hidden_reel_count)

	var free_spins_after: int
	if is_free_spin:
		free_spins_after = maxi(0, free_spins_remaining - 1)
	else:
		free_spins_after = mini(free_spins_remaining + int(score["freeSpinsGranted"]), max_free_spins)

	return {
		"reels": reels,
		"scoreMultiplier": lucidity_multiplier,
		"scoreEarned": score["scoreEarned"],
		"coinsEarned": score["coinsEarned"],
		"neuronsAfter": neurons_after,
		"freeSpinsGranted": score["freeSpinsGranted"],
		"freeSpinsAfter": free_spins_after,
		"isJackpot": score["winType"] == "jackpot",
		"isFreeSpin": is_free_spin,
		"winType": score["winType"],
	}
