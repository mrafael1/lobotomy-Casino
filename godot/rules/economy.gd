class_name Economy
extends RefCounted

## Economy rules — derives run parameters from owned upgrades.
##
## Nearly every rule here is the same walk: look at each owned upgrade, keep the ones
## whose effect is of one type, and fold one of their fields together. Only the fold
## differs — sum, product, presence, and in two places a minimum and a first match — so
## the walk is written once below and each rule says which fold it wants. Reading a rule
## should be reading its arithmetic, not re-reading the loop.

static func _map() -> Dictionary:
	return Upgrades.upgrade_map()

## Every effect Dictionary among the owned upgrades that is of `type`.
static func _effects(owned: Array, type: String) -> Array:
	var out: Array = []
	var m := _map()
	for id in owned:
		var u: Variant = m.get(id, null)
		if u != null and u["effect"]["type"] == type:
			out.append(u["effect"])
	return out

## One field off one effect.
##
## `default` of null means the field is REQUIRED, and the read stays a hard index so that
## malformed content fails loudly right here. That is what the hand-written loops did, and
## it is worth keeping: an upgrade that silently defaults to a no-op is a balance bug that
## ships, where a missing key is a content bug that gets fixed. Rules whose field is
## genuinely optional pass the default they want instead.
static func _field(effect: Dictionary, key: String, default: Variant) -> float:
	if default == null:
		return float(effect[key])
	return float(effect.get(key, default))

static func _sum_effect(owned: Array, type: String, key: String, base: float,
		default: Variant = null) -> float:
	var total := base
	for e in _effects(owned, type):
		total += _field(e, key, default)
	return total

static func _product_effect(owned: Array, type: String, key: String, base: float,
		default: Variant = null) -> float:
	var total := base
	for e in _effects(owned, type):
		total *= _field(e, key, default)
	return total

static func _has_effect(owned: Array, type: String) -> bool:
	return not _effects(owned, type).is_empty()

static func compute_neuron_decay(owned: Array) -> int:
	var reduction := int(_sum_effect(owned, "neuronDecayReduction", "amount", 0.0))
	return maxi(EconomyConst.MIN_NEURON_DECAY,
		EconomyConst.NEURON_DECAY_PER_SPIN - reduction)

static func compute_neuron_cap(owned: Array) -> int:
	var bonus := int(_sum_effect(owned, "startingNeuronBonus", "amount", 0.0))
	return mini(EconomyConst.MAX_NEURONS + bonus, EconomyConst.MAX_NEURONS_ACT2)

static func compute_starting_neurons(owned: Array) -> int:
	var neurons := int(_sum_effect(owned, "startingNeuronBonus", "amount",
		float(EconomyConst.STARTING_NEURONS)))
	return mini(neurons, compute_neuron_cap(owned))

static func compute_lucidity_multiplier(owned: Array) -> float:
	return _product_effect(owned, "lucidityMultiplier", "multiplier",
		EconomyConst.BASE_LUCIDITY_MULTIPLIER)

static func compute_symbol_reward_amp_bonus(owned: Array) -> float:
	return _sum_effect(owned, "symbolRewardAmpBonus", "bonus", 0.0)

static func compute_hallucination_reward_scale(owned: Array) -> float:
	return _product_effect(owned, "hallucination", "rewardScale", 1.0, 1.0)

## Learning pays for the Book joker the same way Hallucination pays for its promoted
## pair: a flat cut on every reward while it is owned. Defaults to 1.0 so a bookSymbol
## effect without a rewardScale stays free.
static func compute_book_reward_scale(owned: Array) -> float:
	return _product_effect(owned, "bookSymbol", "rewardScale", 1.0, 1.0)

static func compute_tunnel_vision_reward_scale(owned: Array) -> float:
	return _product_effect(owned, "tunnelVision", "rewardMultiplier", 1.0, 1.0)

## The tightest threshold wins rather than the last one read, so owning two of these is
## never worse than owning one.
static func compute_power_restore_threshold(owned: Array, base_threshold: int) -> int:
	var threshold := maxi(1, base_threshold)
	for e in _effects(owned, "powerRestoreThreshold"):
		threshold = mini(threshold, maxi(1, int(e["amount"])))
	return threshold

static func compute_jackpot_multiplier(owned: Array) -> float:
	return _product_effect(owned, "jackpotLucidityMultiplier", "multiplier", 1.0)

static func compute_max_free_spins(_owned: Array) -> int:
	return EconomyConst.BASE_MAX_FREE_SPINS

static func compute_passive_lucidity(owned: Array) -> int:
	return int(_sum_effect(owned, "passiveLucidityPerSpin", "amount", 0.0))

static func compute_pair_score_multiplier(owned: Array) -> float:
	return _product_effect(owned, "soloAsPair", "pairMultiplier", 1.0, 1.0)

static func has_solo_as_pair(owned: Array) -> bool:
	return _has_effect(owned, "soloAsPair")

static func has_tunnel_vision(owned: Array) -> bool:
	return _has_effect(owned, "tunnelVision")

## The first one owned, not a fold: the book occupies a reel slot, and two of them would
## not make it occupy two.
static func compute_book_weight(owned: Array) -> int:
	var effects := _effects(owned, "bookSymbol")
	return int(effects[0]["weight"]) if not effects.is_empty() else 0

static func compute_brain_weight_bonus(owned: Array) -> int:
	return int(_sum_effect(owned, "brainWeightBonus", "amount", 0.0))

static func has_sedative(owned: Array) -> bool:
	return _has_effect(owned, "sedativeBonusSpin")

static func has_pattern23_triple(owned: Array) -> bool:
	return _has_effect(owned, "pattern23Triple")

static func has_hallucination(owned: Array) -> bool:
	return _has_effect(owned, "hallucination")
