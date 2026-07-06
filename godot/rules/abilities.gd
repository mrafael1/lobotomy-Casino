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
		symbol_reward_bonuses: Dictionary = {}) -> Dictionary:
	var old := Evaluate.score_reels(before, lucidity_multiplier, false, pattern23, learning,
		pair_score_mult, hidden_reel_count, visible_pair_as_triple, reward_scale,
		symbol_reward_bonuses)
	var new := Evaluate.score_reels(after, lucidity_multiplier, allow_free_spin_grant, pattern23, learning,
		pair_score_mult, hidden_reel_count, visible_pair_as_triple, reward_scale,
		symbol_reward_bonuses)
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
	return out

static func apply_reroll(reels: Array, reel_index: int, rng: LobRNG, lucidity_multiplier: float,
		symbol_weights: Array, pattern23: bool = false, learning: bool = false,
		allow_free_spin_grant: bool = false, pair_score_mult: float = 1.0,
		hidden_reel_count: int = 0, visible_pair_as_triple: bool = false,
		reward_scale: float = 1.0, symbol_reward_bonuses: Dictionary = {}) -> Dictionary:
	var next := reels.duplicate()
	next[reel_index] = LobRNG.weighted_pick(symbol_weights, rng)
	return _rescore(reels, next, lucidity_multiplier, pattern23, learning, allow_free_spin_grant,
		pair_score_mult, hidden_reel_count, visible_pair_as_triple, reward_scale,
		symbol_reward_bonuses)

static func apply_move_column(reels: Array, reel_index: int, direction: int, lucidity_multiplier: float,
		pattern23: bool = false, learning: bool = false, allow_free_spin_grant: bool = false,
		pair_score_mult: float = 1.0, hidden_reel_count: int = 0,
		visible_pair_as_triple: bool = false, reward_scale: float = 1.0,
		symbol_reward_bonuses: Dictionary = {}) -> Dictionary:
	var order := move_order()
	var current := order.find(reels[reel_index])
	var idx := 0 if current < 0 else current
	var n := order.size()
	var next_symbol: String = order[(idx + direction + n) % n]
	var next := reels.duplicate()
	next[reel_index] = next_symbol
	return _rescore(reels, next, lucidity_multiplier, pattern23, learning, allow_free_spin_grant,
		pair_score_mult, hidden_reel_count, visible_pair_as_triple, reward_scale,
		symbol_reward_bonuses)

static func apply_copy_reel(reels: Array, source_reel: int, target_reel: int, lucidity_multiplier: float,
		pattern23: bool = false, learning: bool = false, allow_free_spin_grant: bool = false,
		pair_score_mult: float = 1.0, hidden_reel_count: int = 0,
		visible_pair_as_triple: bool = false, reward_scale: float = 1.0,
		symbol_reward_bonuses: Dictionary = {}) -> Dictionary:
	var next := reels.duplicate()
	next[target_reel] = reels[source_reel]
	return _rescore(reels, next, lucidity_multiplier, pattern23, learning, allow_free_spin_grant,
		pair_score_mult, hidden_reel_count, visible_pair_as_triple, reward_scale,
		symbol_reward_bonuses)
