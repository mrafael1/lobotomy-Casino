class_name Economy
extends RefCounted

## Economy rules — derives run parameters from owned upgrades.

static func _map() -> Dictionary:
	return Upgrades.upgrade_map()

static func compute_neuron_decay(owned: Array) -> int:
	var m := _map()
	var decay := EconomyConst.NEURON_DECAY_PER_SPIN
	for id in owned:
		var u: Variant = m.get(id, null)
		if u != null and u["effect"]["type"] == "neuronDecayReduction":
			decay -= int(u["effect"]["amount"])
	return maxi(EconomyConst.MIN_NEURON_DECAY, decay)

static func compute_neuron_cap(owned: Array) -> int:
	var m := _map()
	var bonus := 0
	for id in owned:
		var u: Variant = m.get(id, null)
		if u != null and u["effect"]["type"] == "startingNeuronBonus":
			bonus += int(u["effect"]["amount"])
	return mini(EconomyConst.MAX_NEURONS + bonus, EconomyConst.MAX_NEURONS_ACT2)

static func compute_starting_neurons(owned: Array) -> int:
	var m := _map()
	var neurons := EconomyConst.STARTING_NEURONS
	for id in owned:
		var u: Variant = m.get(id, null)
		if u != null and u["effect"]["type"] == "startingNeuronBonus":
			neurons += int(u["effect"]["amount"])
	return mini(neurons, compute_neuron_cap(owned))

static func compute_lucidity_multiplier(owned: Array) -> float:
	var m := _map()
	var multiplicative := EconomyConst.BASE_LUCIDITY_MULTIPLIER
	for id in owned:
		var u: Variant = m.get(id, null)
		if u == null:
			continue
		var e: Dictionary = u["effect"]
		if e["type"] == "lucidityMultiplier":
			multiplicative *= float(e["multiplier"])
	return multiplicative

static func compute_symbol_reward_amp_bonus(owned: Array) -> float:
	var m := _map()
	var bonus := 0.0
	for id in owned:
		var u: Variant = m.get(id, null)
		if u != null and u["effect"]["type"] == "symbolRewardAmpBonus":
			bonus += float(u["effect"]["bonus"])
	return bonus

static func compute_hallucination_reward_scale(owned: Array) -> float:
	var m := _map()
	var scale := 1.0
	for id in owned:
		var u: Variant = m.get(id, null)
		if u != null and u["effect"]["type"] == "hallucination":
			scale *= float(u["effect"].get("rewardScale", 1.0))
	return scale

static func compute_jackpot_multiplier(owned: Array) -> float:
	var m := _map()
	var mult := 1.0
	for id in owned:
		var u: Variant = m.get(id, null)
		if u != null and u["effect"]["type"] == "jackpotLucidityMultiplier":
			mult *= float(u["effect"]["multiplier"])
	return mult

static func compute_max_free_spins(_owned: Array) -> int:
	return EconomyConst.BASE_MAX_FREE_SPINS

static func compute_passive_lucidity(owned: Array) -> int:
	var m := _map()
	var passive := 0
	for id in owned:
		var u: Variant = m.get(id, null)
		if u != null and u["effect"]["type"] == "passiveLucidityPerSpin":
			passive += int(u["effect"]["amount"])
	return passive

static func compute_book_weight(owned: Array) -> int:
	var m := _map()
	for id in owned:
		var u: Variant = m.get(id, null)
		if u != null and u["effect"]["type"] == "bookSymbol":
			return int(u["effect"]["weight"])
	return 0

static func compute_brain_weight_bonus(owned: Array) -> int:
	var m := _map()
	var bonus := 0
	for id in owned:
		var u: Variant = m.get(id, null)
		if u != null and u["effect"]["type"] == "brainWeightBonus":
			bonus += int(u["effect"]["amount"])
	return bonus

static func has_sedative(owned: Array) -> bool:
	var m := _map()
	for id in owned:
		var u: Variant = m.get(id, null)
		if u != null and u["effect"]["type"] == "sedativeBonusSpin":
			return true
	return false

static func has_pattern23_triple(owned: Array) -> bool:
	var m := _map()
	for id in owned:
		var u: Variant = m.get(id, null)
		if u != null and u["effect"]["type"] == "pattern23Triple":
			return true
	return false

static func has_hallucination(owned: Array) -> bool:
	var m := _map()
	for id in owned:
		var u: Variant = m.get(id, null)
		if u != null and u["effect"]["type"] == "hallucination":
			return true
	return false
