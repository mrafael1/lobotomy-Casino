class_name Evaluate
extends RefCounted

## Evaluation rules: scoreReels() and evaluate(), the single source of truth
## for a spin. Mirrors JS Math.round with floor(x + 0.5).

static func _round(x: float) -> int:
	return floori(x + 0.5)

static func _pick_non_excluded(excluded: String, rng: LobRNG) -> String:
	var pool: Array = []
	for s in Symbols.BASE_SYMBOL_CYCLE:
		if String(s) != excluded:
			pool.append(String(s))
	if pool.is_empty():
		return excluded
	return String(pool[int(rng.next() * pool.size())])

static func _adjacent_symbol(symbol: String, direction: int) -> String:
	var order := Symbols.BASE_SYMBOL_CYCLE
	var current := order.find(symbol)
	if current < 0:
		return symbol
	var n := order.size()
	return String(order[(current + direction + n) % n])

static func _build_weights(brain_bonus: int, book_weight: int, overrides: Dictionary = {}) -> Array:
	var weights := Symbols.symbol_weights()
	if brain_bonus > 0 or not overrides.is_empty():
		var nw := []
		for w in weights:
			var sym := String(w["value"])
			var bonus := int(overrides.get(sym, 0))
			if sym == "brain":
				bonus += brain_bonus
			if bonus > 0:
				nw.append({ "weight": int(w["weight"]) + bonus, "value": sym })
			else:
				nw.append(w)
		weights = nw
	if book_weight > 0:
		weights.append({ "weight": book_weight + int(overrides.get("book", 0)), "value": "book" })
	return weights

static func _reward_bonus(symbol: String, symbol_reward_bonuses: Dictionary) -> float:
	return maxf(0.0, float(symbol_reward_bonuses.get(symbol, 0.0)))

static func _pair_base(symbol: String, pair_score_mult: float, symbol_reward_bonuses: Dictionary) -> int:
	var base := float(int(Payouts.PAIR_SCORE.get(symbol, 0))) * pair_score_mult
	return _round(base * (1.0 + _reward_bonus(symbol, symbol_reward_bonuses)))

static func _triple_base(symbol: String, symbol_reward_bonuses: Dictionary) -> int:
	var base := float(Payouts.JACKPOT_SCORE if symbol == "brain" else int(Payouts.TRIPLE_SCORE.get(symbol, 0)))
	return _round(base * (1.0 + _reward_bonus(symbol, symbol_reward_bonuses)))

static func _score_base(base: int, lucidity_multiplier: float, reward_scale: float) -> int:
	return _round(float(base) * lucidity_multiplier * reward_scale)

static func _score_triple(symbol: String, lucidity_multiplier: float, allow_free_spin_grant: bool,
		reward_scale: float, symbol_reward_bonuses: Dictionary) -> Dictionary:
	var score := _score_base(_triple_base(symbol, symbol_reward_bonuses), lucidity_multiplier, reward_scale)
	if symbol == "brain":
		return {
			"winType": "jackpot", "scoreEarned": score, "coinsEarned": score,
			"freeSpinsGranted": Payouts.JACKPOT_FREE_SPIN_GRANT if allow_free_spin_grant else 0,
		}
	return { "winType": "triple", "scoreEarned": score, "coinsEarned": score, "freeSpinsGranted": 0 }

static func _score_pair(symbol: String, lucidity_multiplier: float, pair_score_mult: float,
		reward_scale: float, symbol_reward_bonuses: Dictionary) -> Dictionary:
	var score := _score_base(_pair_base(symbol, pair_score_mult, symbol_reward_bonuses),
		lucidity_multiplier, reward_scale)
	return { "winType": "pair", "scoreEarned": score, "coinsEarned": score, "freeSpinsGranted": 0 }

static func _highest_pair_symbol(symbols: Array) -> String:
	var selected := ""
	var selected_value := -1
	for raw_symbol in symbols:
		var symbol := String(raw_symbol)
		var value := int(Payouts.PAIR_SCORE.get(symbol, 0))
		if value > selected_value:
			selected = symbol
			selected_value = value
	return selected

## Stage one of evaluation: classify the visible reels without assigning a value.
## The classification records why a win exists so later modifiers can charge only
## invented or joker-derived wins.
static func resolve_outcome(reels: Array, pattern23_triple: bool = false,
		hidden_reel_count: int = 0, visible_pair_as_triple: bool = false,
		solo_as_pair: bool = false) -> Dictionary:
	if reels.size() < 3:
		return { "classification": "miss", "symbol": "" }
	var a := String(reels[0])
	var b := String(reels[1])
	var c := String(reels[2])
	if hidden_reel_count > 0:
		var visible: Array = reels.slice(0, maxi(1, reels.size() - hidden_reel_count))
		for i in range(visible.size() - 1):
			if String(visible[i]) == String(visible[i + 1]):
				var visible_symbol := String(visible[i])
				return { "classification": "hallucination_created_triple" if visible_pair_as_triple \
					else "natural_pair", "symbol": visible_symbol }
		if solo_as_pair:
			var hidden_solo := _highest_pair_symbol(visible)
			if hidden_solo != "":
				return { "classification": "cheat_solo_pair", "symbol": hidden_solo }
		return { "classification": "miss", "symbol": "" }

	if a == b and b == c:
		return {
			"classification": "jackpot" if a == "brain" else "natural_triple",
			"symbol": a,
		}
	if visible_pair_as_triple:
		var hallucinated := ""
		if a == b:
			hallucinated = a
		elif b == c:
			hallucinated = b
		elif pattern23_triple and a == c:
			hallucinated = a
		if hallucinated != "":
			return { "classification": "hallucination_created_triple", "symbol": hallucinated }
	if pattern23_triple:
		var pattern_symbol := ""
		if a == b:
			pattern_symbol = a
		elif b == c:
			pattern_symbol = b
		elif a == c:
			pattern_symbol = a
		if pattern_symbol != "":
			return { "classification": "pattern_recognition_pair", "symbol": pattern_symbol }
	elif a == b or b == c:
		return { "classification": "natural_pair", "symbol": a if a == b else b }
	if solo_as_pair:
		var solo_symbol := _highest_pair_symbol(reels)
		if solo_symbol != "":
			return { "classification": "cheat_solo_pair", "symbol": solo_symbol }
	return { "classification": "miss", "symbol": "" }

## Stage two of evaluation: apply the value modifiers to a classified outcome.
static func value_outcome(outcome: Dictionary, lucidity_multiplier: float,
		allow_free_spin_grant: bool, pair_score_mult: float = 1.0,
		reward_scale: float = 1.0, symbol_reward_bonuses: Dictionary = {},
		book_reward_scale: float = 1.0, hallucination_reward_scale: float = 1.0) -> Dictionary:
	var classification := String(outcome.get("classification", "miss"))
	var symbol := String(outcome.get("symbol", ""))
	var pair_multiplier := pair_score_mult
	if classification == "pattern_recognition_pair":
		pair_multiplier *= 2.0
	match classification:
		"jackpot", "natural_triple":
			return _score_triple(symbol, lucidity_multiplier, allow_free_spin_grant,
				reward_scale, symbol_reward_bonuses)
		"hallucination_created_triple":
			var hallucinated := _score_triple(symbol, lucidity_multiplier,
				allow_free_spin_grant, reward_scale * hallucination_reward_scale,
				symbol_reward_bonuses)
			hallucinated["hallucinatedTriple"] = true
			return hallucinated
		"natural_pair", "pattern_recognition_pair", "cheat_solo_pair":
			var pair := _score_pair(symbol, lucidity_multiplier, pair_multiplier,
				reward_scale, symbol_reward_bonuses)
			if classification == "cheat_solo_pair":
				pair["soloAsPair"] = true
				pair["soloAsPairSymbol"] = symbol
			return pair
	return { "winType": "miss", "scoreEarned": 0, "coinsEarned": 0, "freeSpinsGranted": 0 }

static func _score_reels_without_book(reels: Array, lucidity_multiplier: float,
		allow_free_spin_grant: bool, pattern23_triple: bool,
		pair_score_mult: float, hidden_reel_count: int, visible_pair_as_triple: bool,
		reward_scale: float, symbol_reward_bonuses: Dictionary,
		solo_as_pair: bool, hallucination_reward_scale: float = 1.0) -> Dictionary:
	return value_outcome(resolve_outcome(reels, pattern23_triple, hidden_reel_count,
		visible_pair_as_triple, solo_as_pair), lucidity_multiplier, allow_free_spin_grant,
		pair_score_mult, reward_scale, symbol_reward_bonuses, 1.0,
		hallucination_reward_scale)

static func _win_rank(win_type: String) -> int:
	match win_type:
		"jackpot":
			return 3
		"triple":
			return 2
		"pair":
			return 1
	return 0

## book_reward_scale is Learning's price for the joker and is charged ONLY to the wins the
## joker actually makes: a spin with no book on its reels pays in full, so owning Learning
## never taxes a win the book had nothing to do with. It multiplies the general
## reward_scale inside the joker branch below, so the two stack the same way they did when
## the book cut was folded into reward_scale upstream.
static func score_reels(reels: Array, lucidity_multiplier: float, allow_free_spin_grant: bool,
		pattern23_triple: bool = false, learning_active: bool = false,
		pair_score_mult: float = 1.0, hidden_reel_count: int = 0,
		visible_pair_as_triple: bool = false, reward_scale: float = 1.0,
		symbol_reward_bonuses: Dictionary = {}, solo_as_pair: bool = false,
		book_reward_scale: float = 1.0,
		hallucination_reward_scale: float = 1.0) -> Dictionary:
	var has_book := false
	for reel_value in reels:
		if String(reel_value) == "book":
			has_book = true
			break
	if not learning_active or not has_book:
		return _score_reels_without_book(reels, lucidity_multiplier, allow_free_spin_grant,
			pattern23_triple, pair_score_mult, hidden_reel_count, visible_pair_as_triple,
			reward_scale, symbol_reward_bonuses, solo_as_pair, hallucination_reward_scale)
	var book_scale := reward_scale * book_reward_scale

	var candidates: Array[String] = []
	for candidate_reel in reels:
		var symbol := String(candidate_reel)
		if symbol != "book" and not candidates.has(symbol):
			candidates.append(symbol)
	if candidates.is_empty():
		candidates.append("eye")

	var best: Dictionary = {}
	for candidate in candidates:
		var resolved := []
		for resolved_reel in reels:
			resolved.append(candidate if String(resolved_reel) == "book" else String(resolved_reel))
		var scored := _score_reels_without_book(resolved, lucidity_multiplier, allow_free_spin_grant,
			pattern23_triple, pair_score_mult, hidden_reel_count, visible_pair_as_triple,
			book_scale, symbol_reward_bonuses, solo_as_pair, hallucination_reward_scale)
		scored["bookJoker"] = true
		scored["resolvedSymbol"] = candidate
		if reels.count("book") == reels.size() and candidate == "eye":
			scored["bookTripleChoice"] = true
		if best.is_empty() \
				or int(scored["scoreEarned"]) > int(best["scoreEarned"]) \
				or (int(scored["scoreEarned"]) == int(best["scoreEarned"]) \
					and _win_rank(String(scored["winType"])) > _win_rank(String(best["winType"]))):
			best = scored
	return best

static func evaluate(input: Dictionary) -> Dictionary:
	var neurons := int(input["neurons"])
	var neuron_decay := int(input["neuronDecayAmount"])
	var free_spins_remaining := int(input["freeSpinsRemaining"])
	var max_free_spins := int(input["maxFreeSpins"])
	var lucidity_multiplier := float(input["lucidityMultiplier"])
	var is_free_spin: bool = input["isFreeSpin"]
	var free_spin_cost := maxi(1, int(input.get("freeSpinCost", 1)))
	var locked: Array = input["lockedReels"]
	var prev: Variant = input["previousReels"]
	var rng: LobRNG = input["rng"]
	var book_weight := int(input["bookWeight"])
	var brain_weight_bonus := int(input["brainWeightBonus"])
	var guaranteed_win: bool = input["guaranteedWin"]
	var pattern23: bool = input["pattern23Triple"]
	var learning: bool = input["learningActive"]
	var force_all_symbol: Variant = input.get("forceAllSymbol", null)
	var force_triple_from: Variant = input.get("forceTripleFrom", null)
	var exclude_symbol: Variant = input.get("excludeSymbol", null)
	var ban_excluded: bool = bool(input.get("banExcluded", false))
	var guarantee_non_excluded: bool = bool(input.get("guaranteeNonExcluded", false))
	var symbol_to_brain_count := int(input.get("symbolToBrainCount", 0))
	var adjacent_symbol_count := int(input.get("adjacentSymbolCount", 0))
	var pair_score_mult := float(input.get("pairScoreMult", 1.0))
	var hidden_reel_count := int(input.get("hiddenReelCount", 0))
	var visible_pair_as_triple := bool(input.get("visiblePairAsTriple", false))
	var reward_scale := float(input.get("rewardScale", 1.0))
	var book_reward_scale := float(input.get("bookRewardScale", 1.0))
	var hallucination_reward_scale := float(input.get("hallucinationRewardScale", 1.0))
	var symbol_reward_bonuses: Dictionary = input.get("symbolRewardBonuses", {})
	var solo_as_pair := bool(input.get("soloAsPair", false))
	var guarantee_symbol_id: Variant = input.get("guaranteeSymbolId", null)
	var force_reel_symbols: Variant = input.get("forceReelSymbols", null)
	var weight_overrides: Dictionary = input.get("weightOverrides", {})

	var weights := _build_weights(brain_weight_bonus, book_weight, weight_overrides)
	var reels := [
		prev[0] if (bool(locked[0]) and prev != null) else LobRNG.weighted_pick(weights, rng),
		prev[1] if (bool(locked[1]) and prev != null) else LobRNG.weighted_pick(weights, rng),
		prev[2] if (bool(locked[2]) and prev != null) else LobRNG.weighted_pick(weights, rng),
	]

	if guaranteed_win:
		var temp := score_reels(reels, 1.0, false, pattern23, learning, pair_score_mult,
			hidden_reel_count, visible_pair_as_triple, reward_scale, symbol_reward_bonuses,
			solo_as_pair, book_reward_scale, hallucination_reward_scale)
		if temp["winType"] == "miss":
			reels = [reels[0], reels[0], reels[2]]

	if force_all_symbol != null:
		# Issue #112: a locked reel keeps its symbol even through a forced
		# all-symbol spin (Pill flatline) — the lock wins, preventing a locked
		# reel from rolling into a flatline close call.
		for i in 3:
			if not (bool(locked[i]) and prev != null):
				reels[i] = force_all_symbol
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
		if guarantee_symbol_id != null and String(guarantee_symbol_id) != "" \
				and not reels.has(String(guarantee_symbol_id)):
			reels[int(rng.next() * 3.0)] = String(guarantee_symbol_id)
		if adjacent_symbol_count > 0:
			for _i in mini(adjacent_symbol_count, 3):
				var reel_index := int(rng.next() * 3.0)
				var direction := 1 if rng.next() >= 0.5 else -1
				reels[reel_index] = _adjacent_symbol(String(reels[reel_index]), direction)

	if force_reel_symbols != null:
		for idx in (force_reel_symbols as Dictionary):
			var i := int(idx)
			if i >= 0 and i < 3:
				reels[i] = String((force_reel_symbols as Dictionary)[idx])

	var neurons_after := neurons if is_free_spin else maxi(0, neurons - neuron_decay)
	var score := score_reels(reels, lucidity_multiplier, not is_free_spin, pattern23, learning,
		pair_score_mult, hidden_reel_count, visible_pair_as_triple, reward_scale,
		symbol_reward_bonuses, solo_as_pair, book_reward_scale, hallucination_reward_scale)

	var free_spins_after: int
	if is_free_spin:
		free_spins_after = maxi(0, free_spins_remaining - free_spin_cost)
	else:
		free_spins_after = mini(free_spins_remaining + int(score["freeSpinsGranted"]), max_free_spins)

	var out := {
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
	if score.has("resolvedSymbol"):
		out["resolvedSymbol"] = String(score["resolvedSymbol"])
	if score.has("bookJoker"):
		out["bookJoker"] = bool(score["bookJoker"])
	if score.has("bookTripleChoice"):
		out["bookTripleChoice"] = bool(score["bookTripleChoice"])
	if score.has("soloAsPair"):
		out["soloAsPair"] = true
		out["soloAsPairSymbol"] = String(score.get("soloAsPairSymbol", ""))
	# Marks the triple as one Hallucination invented, so the machine can tell it apart
	# from a natural one — only the promoted payout carries the card's cut.
	if score.has("hallucinatedTriple"):
		out["hallucinatedTriple"] = true
	return out
