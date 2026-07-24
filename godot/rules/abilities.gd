class_name Abilities
extends RefCounted

## Pure reel transforms — pure reel transforms returning an AbilityOutcome
## Dictionary { reels, scoreDelta, coinsDelta, isJackpot, winType, freeSpinsGranted }.

# SHIFT steps along the canonical base-symbol cycle.
static func move_order() -> Array:
	return Symbols.BASE_SYMBOL_CYCLE

static func _rescore(before: Array, after: Array, lucidity_multiplier: float,
		pattern23: bool, learning: bool, allow_free_spin_grant: bool,
		pair_score_mult: float = 1.0, hidden_reel_count: int = 0,
		visible_pair_as_triple: bool = false, reward_scale: float = 1.0,
		symbol_reward_bonuses: Dictionary = {}, solo_as_pair: bool = false) -> Dictionary:
	var old := Evaluate.score_reels(before, lucidity_multiplier, false, pattern23, learning,
		pair_score_mult, hidden_reel_count, visible_pair_as_triple, reward_scale,
		symbol_reward_bonuses, solo_as_pair)
	var new := Evaluate.score_reels(after, lucidity_multiplier, allow_free_spin_grant, pattern23, learning,
		pair_score_mult, hidden_reel_count, visible_pair_as_triple, reward_scale,
		symbol_reward_bonuses, solo_as_pair)
	var free_granted := int(new["freeSpinsGranted"]) if old["winType"] != "jackpot" else 0
	var out := {
		"reels": after,
		"scoreDelta": int(new["scoreEarned"]) - int(old["scoreEarned"]),
		"coinsDelta": int(new["coinsEarned"]) - int(old["coinsEarned"]),
		"isJackpot": new["winType"] == "jackpot",
		"winType": new["winType"],
		"freeSpinsGranted": free_granted,
	}
	if new.has("resolvedSymbol"):
		out["resolvedSymbol"] = String(new["resolvedSymbol"])
	if new.has("bookJoker"):
		out["bookJoker"] = bool(new["bookJoker"])
	if new.has("bookTripleChoice"):
		out["bookTripleChoice"] = bool(new["bookTripleChoice"])
	if new.has("soloAsPair"):
		out["soloAsPair"] = true
		out["soloAsPairSymbol"] = String(new.get("soloAsPairSymbol", ""))
	return out

## Issue #118: Random must never redraw the symbol already occupying its target —
## excludes it from the weighted candidate pool before the draw. Returns an empty
## array when nothing else remains to draw (caller must fail safely in that case).
static func random_candidate_weights(symbol_weights: Array, exclude_symbol: String) -> Array:
	return symbol_weights.filter(func(w): return String(w["value"]) != exclude_symbol)

static func apply_reroll(reels: Array, reel_index: int, rng: LobRNG, lucidity_multiplier: float,
		symbol_weights: Array, pattern23: bool = false, learning: bool = false,
		allow_free_spin_grant: bool = false, pair_score_mult: float = 1.0,
		hidden_reel_count: int = 0, visible_pair_as_triple: bool = false,
		reward_scale: float = 1.0, symbol_reward_bonuses: Dictionary = {},
		solo_as_pair: bool = false) -> Dictionary:
	var next := reels.duplicate()
	next[reel_index] = LobRNG.weighted_pick(symbol_weights, rng)
	return _rescore(reels, next, lucidity_multiplier, pattern23, learning, allow_free_spin_grant,
		pair_score_mult, hidden_reel_count, visible_pair_as_triple, reward_scale,
		symbol_reward_bonuses, solo_as_pair)

static func apply_move_column(reels: Array, reel_index: int, direction: int, lucidity_multiplier: float,
		pattern23: bool = false, learning: bool = false, allow_free_spin_grant: bool = false,
		pair_score_mult: float = 1.0, hidden_reel_count: int = 0,
		visible_pair_as_triple: bool = false, reward_scale: float = 1.0,
		symbol_reward_bonuses: Dictionary = {}, solo_as_pair: bool = false) -> Dictionary:
	var order := move_order()
	var current := order.find(reels[reel_index])
	var idx := 0 if current < 0 else current
	var n := order.size()
	var next_symbol: String = order[(idx + direction + n) % n]
	var next := reels.duplicate()
	next[reel_index] = next_symbol
	return _rescore(reels, next, lucidity_multiplier, pattern23, learning, allow_free_spin_grant,
		pair_score_mult, hidden_reel_count, visible_pair_as_triple, reward_scale,
		symbol_reward_bonuses, solo_as_pair)

static func apply_copy_reel(reels: Array, source_reel: int, target_reel: int, lucidity_multiplier: float,
		pattern23: bool = false, learning: bool = false, allow_free_spin_grant: bool = false,
		pair_score_mult: float = 1.0, hidden_reel_count: int = 0,
		visible_pair_as_triple: bool = false, reward_scale: float = 1.0,
		symbol_reward_bonuses: Dictionary = {}, solo_as_pair: bool = false) -> Dictionary:
	var next := reels.duplicate()
	next[target_reel] = reels[source_reel]
	return _rescore(reels, next, lucidity_multiplier, pattern23, learning, allow_free_spin_grant,
		pair_score_mult, hidden_reel_count, visible_pair_as_triple, reward_scale,
		symbol_reward_bonuses, solo_as_pair)

## CHEAT replaces one revealed reel with a player-chosen symbol and then uses the
## same scoring path as every other revealed-reel power.
static func apply_cheat(reels: Array, reel_index: int, symbol: String,
		lucidity_multiplier: float, pattern23: bool = false, learning: bool = false,
		allow_free_spin_grant: bool = false, pair_score_mult: float = 1.0,
		hidden_reel_count: int = 0, visible_pair_as_triple: bool = false,
		reward_scale: float = 1.0, symbol_reward_bonuses: Dictionary = {},
		solo_as_pair: bool = false) -> Dictionary:
	var next := reels.duplicate()
	if reel_index < 0 or reel_index >= next.size():
		return {}
	next[reel_index] = symbol
	return _rescore(reels, next, lucidity_multiplier, pattern23, learning,
		allow_free_spin_grant, pair_score_mult, hidden_reel_count,
		visible_pair_as_triple, reward_scale, symbol_reward_bonuses, solo_as_pair)

## SWAP exchanges one selected visible strip symbol with the destination reel's
## centre symbol. The source may be a centre or an adjacent preview symbol; the
## symbol values are not required to be distinct.
static func apply_swap_symbol(reels: Array, source_reel: int, target_reel: int,
		lucidity_multiplier: float, pattern23: bool = false, learning: bool = false,
		allow_free_spin_grant: bool = false, pair_score_mult: float = 1.0,
		hidden_reel_count: int = 0, visible_pair_as_triple: bool = false,
		reward_scale: float = 1.0, symbol_reward_bonuses: Dictionary = {},
		source_symbol_override: String = "", solo_as_pair: bool = false) -> Dictionary:
	var next := reels.duplicate()
	if source_reel < 0 or target_reel < 0 or source_reel >= next.size() \
			or target_reel >= next.size() or source_reel == target_reel:
		return {}
	var source_symbol: Variant = next[source_reel] if source_symbol_override == "" \
		else source_symbol_override
	next[source_reel] = next[target_reel]
	next[target_reel] = source_symbol
	return _rescore(reels, next, lucidity_multiplier, pattern23, learning,
		allow_free_spin_grant, pair_score_mult, hidden_reel_count,
		visible_pair_as_triple, reward_scale, symbol_reward_bonuses, solo_as_pair)

## HEART's three authored symbols carry their own tier. The power does not alter
## the current reveal; it arms a guaranteed free next spin which resolves to one
## of these triples. The payout is spins only (+1/+2/+3 run spins) — a heart
## triple never awards score or Lucidity, but it advances the combo gauge.
static func resolve_heart_spin(tier: int, _score_multiplier: float = 1.0,
		_reward_scale: float = 1.0, _symbol_reward_bonuses: Dictionary = {}) -> Dictionary:
	var selected_tier := clampi(tier, 1, 3)
	var symbol := "heart_x%d" % selected_tier
	return {
		"reels": [symbol, symbol, symbol],
		"heartTier": selected_tier,
		"heartCount": selected_tier,
		"neuronsDelta": selected_tier,
		"scoreEarned": 0,
		"coinsEarned": 0,
		"winType": "heart",
		"isJackpot": false,
		"freeSpinsGranted": 0,
	}

static func resolve_hearts(heart_count: int) -> Dictionary:
	var count := clampi(heart_count, 0, 3)
	return {
		"heartCount": count,
		"neuronsDelta": count,
		"scoreDelta": 0,
		"coinsDelta": 0,
		"winType": "heart" if count > 0 else "miss",
	}

static func apply_heart(reels: Array, heart_count: int = -1) -> Dictionary:
	var count := reels.size() if heart_count < 0 else heart_count
	count = clampi(count, 0, mini(3, reels.size()))
	if count <= 0:
		var miss := resolve_hearts(0)
		miss["reels"] = reels.duplicate()
		miss["isJackpot"] = false
		miss["freeSpinsGranted"] = 0
		return miss
	var result := resolve_hearts(count)
	result["reels"] = ["heart_x%d" % count, "heart_x%d" % count, "heart_x%d" % count]
	result["isJackpot"] = false
	result["freeSpinsGranted"] = 0
	return result
