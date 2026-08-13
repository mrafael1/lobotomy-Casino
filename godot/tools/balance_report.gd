extends SceneTree

## Diagnostic balance report. This is intentionally a report, not a golden test:
## run it when content, prices, or starting resources change and inspect the trends.
##
##   godot --headless --path godot -s res://tools/balance_report.gd
##
## The exact reel profiles are exhaustive over the current weighted symbol table. The
## run simulation is deterministic Monte Carlo and includes frenzy, free spins, passive
## Lucidity, the 15-spin budget, and the intermediate Wealth reset/overflow bill.

const SIMULATION_RUNS := 1000
const SEGMENT_SPIN_LIMIT := 240
const REPORT_CARDS: Array[Dictionary] = [
	{ "id": "augment_pattern_recognition", "label": "PATTERN" },
	{ "id": "augment_hallucination", "label": "HALLUCINATION" },
	{ "id": "augment_how_to_cheat", "label": "HOW_TO_CHEAT" },
	{ "id": "augment_book", "label": "LEARNING" },
	{ "id": "augment_tunnel_vision", "label": "TUNNEL" },
	{ "id": "augment_reward_1", "label": "REWARD+" },
]
const REALISTIC_BUILDS: Array[Dictionary] = [
	{ "name": "BASELINE", "cards": [] },
	{ "name": "CONTROL", "cards": ["augment_pattern_recognition", "augment_reward_1"] },
	{ "name": "HALLUCINATION", "cards": ["augment_hallucination", "augment_how_to_cheat"] },
	{ "name": "SURVIVAL", "cards": ["augment_tunnel_vision", "augment_book"] },
	{ "name": "COMPOSABLE", "cards": ["augment_pattern_recognition", "augment_hallucination", "augment_reward_1"] },
]

func _init() -> void:
	call_deferred("_run_report")

func _run_report() -> void:
	var report: Dictionary = _build_report()
	_print_report(report)
	quit(0)

func _config_for(card_ids: Array, reward_symbol := "brain") -> Dictionary:
	var owned: Array = []
	var reward_card_owned := false
	for raw_card_id in card_ids:
		var card: Dictionary = PacteCards.card(String(raw_card_id))
		var effect: Dictionary = card.get("effect", {}) as Dictionary
		var upgrade_id := String(effect.get("upgrade_id", ""))
		if upgrade_id != "":
			owned.append(upgrade_id)
		if String(effect.get("type", "")) == "owned_upgrade" \
				and upgrade_id.begins_with("corr_reward_amp_"):
			reward_card_owned = true
	var reward_bonuses: Dictionary = {}
	if reward_card_owned:
		reward_bonuses[reward_symbol] = Economy.compute_symbol_reward_amp_bonus(owned)
	var book_weight := Economy.compute_book_weight(owned)
	return {
		"cards": card_ids.duplicate(),
		"owned": owned,
		"reward_symbol": reward_symbol,
		"pattern": Economy.has_pattern23_triple(owned),
		"learning": book_weight > 0,
		"book_weight": book_weight,
		"hallucination": Economy.has_hallucination(owned),
		"solo": Economy.has_solo_as_pair(owned),
		"hidden": 1 if Economy.has_tunnel_vision(owned) else 0,
		"reward_scale": Economy.compute_tunnel_vision_reward_scale(owned),
		"hallucination_scale": Economy.compute_hallucination_reward_scale(owned),
		"book_scale": Economy.compute_book_reward_scale(owned),
		"pair_mult": Economy.compute_pair_score_multiplier(owned),
		"lucidity_multiplier": Economy.compute_lucidity_multiplier(owned),
		"passive": Economy.compute_passive_lucidity(owned),
		"starting_neurons": Economy.compute_starting_neurons(owned),
		"reward_bonuses": reward_bonuses,
	}

func _weights(config: Dictionary) -> Array:
	return Evaluate._build_weights(0, int(config["book_weight"]), {})

func _score(config: Dictionary, reels: Array, allow_free_spin := false,
		spin_multiplier := 1.0) -> int:
	var result: Dictionary = Evaluate.score_reels(reels,
		float(config["lucidity_multiplier"]) * spin_multiplier, allow_free_spin,
		bool(config["pattern"]), bool(config["learning"]), float(config["pair_mult"]),
		int(config["hidden"]), bool(config["hallucination"]), float(config["reward_scale"]),
		config["reward_bonuses"] as Dictionary, bool(config["solo"]),
		float(config["book_scale"]), float(config["hallucination_scale"]))
	return int(result.get("scoreEarned", 0))

func _percentile(distribution: Dictionary, fraction: float) -> int:
	var keys: Array = distribution.keys()
	keys.sort()
	var running := 0.0
	for raw_key in keys:
		running += float(distribution[raw_key])
		if running >= fraction:
			return int(raw_key)
	return int(keys[keys.size() - 1]) if not keys.is_empty() else 0

func _profile(card_ids: Array, reward_symbol := "brain") -> Dictionary:
	var config: Dictionary = _config_for(card_ids, reward_symbol)
	var weights: Array = _weights(config)
	var total_weight := 0.0
	for entry in weights:
		total_weight += float(entry.get("weight", 0.0))
	var distribution: Dictionary = {}
	var classifications: Dictionary = {}
	var win_types: Dictionary = {}
	var ev := 0.0
	var jackpot_probability := 0.0
	var strike_probability := 0.0
	var miss_probability := 0.0
	for first in weights:
		for second in weights:
			for third in weights:
				var probability := float(first["weight"]) * float(second["weight"]) \
					* float(third["weight"]) / pow(total_weight, 3.0)
				var reels: Array = [String(first["value"]), String(second["value"]), String(third["value"])]
				var score := _score(config, reels)
				ev += float(score) * probability
				distribution[score] = float(distribution.get(score, 0.0)) + probability
				var result: Dictionary = Evaluate.score_reels(reels, 1.0, true,
					bool(config["pattern"]), bool(config["learning"]), float(config["pair_mult"]),
					int(config["hidden"]), bool(config["hallucination"]), float(config["reward_scale"]),
					config["reward_bonuses"] as Dictionary, bool(config["solo"]),
					float(config["book_scale"]), float(config["hallucination_scale"]))
				var win_type := String(result.get("winType", "miss"))
				win_types[win_type] = float(win_types.get(win_type, 0.0)) + probability
				var outcome := Evaluate.resolve_outcome(reels, bool(config["pattern"]),
					int(config["hidden"]), bool(config["hallucination"]), bool(config["solo"]))
				var classification := String(outcome.get("classification", "miss"))
				classifications[classification] = float(classifications.get(classification, 0.0)) + probability
				if win_type == "jackpot":
					jackpot_probability += probability
				if reels[0] == "flatline" and reels[1] == "flatline" and reels[2] == "flatline":
					strike_probability += probability
				if win_type == "miss":
					miss_probability += probability
	var max_score := 0
	for raw_score in distribution.keys():
		max_score = maxi(max_score, int(raw_score))
	return {
		"config": config,
		"ev": ev,
		"free_ev": ev * (1.0 + jackpot_probability),
		"jackpot_probability": jackpot_probability,
		"strike_probability": strike_probability,
		"miss_probability": miss_probability,
		"p50": _percentile(distribution, 0.50),
		"p90": _percentile(distribution, 0.90),
		"p99": _percentile(distribution, 0.99),
		"max": max_score,
		"distribution": distribution,
		"classifications": classifications,
		"win_types": win_types,
	}

func _simulated_build(card_ids: Array, reward_symbol: String, runs: int) -> Dictionary:
	var config: Dictionary = _config_for(card_ids, reward_symbol)
	var target_hits: Array[int] = []
	for _index in EconomyConst.WEALTH_TARGETS:
		target_hits.append(0)
	var wealth_count := 0
	var flatline_count := 0
	var final_targets: Array[int] = []
	var final_lucidity: Array[int] = []
	var overflow_banked := 0
	for run_index in range(runs):
		var rng := LobRNG.new(0x41BADC00 ^ run_index)
		var score := 0
		var lucidity := 0
		var neurons := int(config["starting_neurons"])
		var free_spins := 0
		var bet := 1
		var reached := 0
		var wealth := false
		var flatline := false
		for segment in range(EconomyConst.WEALTH_TARGETS.size()):
			var target := int(EconomyConst.WEALTH_TARGETS[segment])
			var segment_complete := false
			for _spin_index in range(SEGMENT_SPIN_LIMIT):
				if neurons <= 0 and free_spins <= 0:
					flatline = true
					break
				var is_free := free_spins > 0
				var result: Dictionary = Evaluate.evaluate({
					"neurons": neurons,
					"neuronDecayAmount": EconomyConst.NEURON_DECAY_PER_SPIN,
					"freeSpinsRemaining": free_spins,
					"maxFreeSpins": EconomyConst.BASE_MAX_FREE_SPINS,
					"lucidityMultiplier": float(config["lucidity_multiplier"]) * bet,
					"isFreeSpin": is_free,
					"lockedReels": [false, false, false],
					"previousReels": null,
					"rng": rng,
					"bookWeight": int(config["book_weight"]),
					"brainWeightBonus": 0,
					"guaranteedWin": false,
					"pattern23Triple": bool(config["pattern"]),
					"learningActive": bool(config["learning"]),
					"pairScoreMult": float(config["pair_mult"]),
					"hiddenReelCount": int(config["hidden"]),
					"visiblePairAsTriple": bool(config["hallucination"]),
					"rewardScale": float(config["reward_scale"]),
					"symbolRewardBonuses": config["reward_bonuses"] as Dictionary,
					"soloAsPair": bool(config["solo"]),
					"bookRewardScale": float(config["book_scale"]),
					"hallucinationRewardScale": float(config["hallucination_scale"]),
				})
				var payout := int(result.get("scoreEarned", 0))
				var passive := int(config["passive"])
				score += payout + passive
				lucidity += int(result.get("coinsEarned", 0)) + passive
				neurons = int(result.get("neuronsAfter", neurons))
				free_spins = int(result.get("freeSpinsAfter", free_spins))
				if score >= target:
					target_hits[segment] += 1
					reached = segment + 1
					segment_complete = true
					if segment == EconomyConst.WEALTH_TARGETS.size() - 1:
						wealth = true
					else:
						var overflow := maxi(0, score - target)
						overflow_banked += EconomyConst.overflow_after_tax(overflow, target)
						score = 0
						neurons = int(config["starting_neurons"])
						free_spins = 0
						bet = 1
					break
				if payout > 0:
					bet = mini(3, bet + 1)
				else:
					bet = maxi(1, bet - 1)
			if flatline or wealth:
				break
			if not segment_complete:
				flatline = true
				break
		if wealth:
			wealth_count += 1
		if flatline:
			flatline_count += 1
		final_targets.append(reached)
		final_lucidity.append(lucidity)
	var target_probabilities: Array[float] = []
	for count in target_hits:
		target_probabilities.append(float(count) / float(runs))
	final_targets.sort()
	final_lucidity.sort()
	return {
		"runs": runs,
		"target_probabilities": target_probabilities,
		"wealth_probability": float(wealth_count) / float(runs),
		"flatline_probability": float(flatline_count) / float(runs),
		"median_target": final_targets[floori(runs * 0.50)],
		"median_lucidity": final_lucidity[floori(runs * 0.50)],
		"overflow_banked_average": float(overflow_banked) / float(runs),
	}

func _pair_matrix(card_ids: Array) -> Dictionary:
	var matrix: Dictionary = {}
	for first_index in range(card_ids.size()):
		for second_index in range(first_index + 1, card_ids.size()):
			var ids: Array = [card_ids[first_index], card_ids[second_index]]
			var profile: Dictionary = _profile(ids)
			matrix["%s + %s" % [card_ids[first_index], card_ids[second_index]]] = profile["ev"]
	return matrix

func _triple_matrix(card_ids: Array) -> Dictionary:
	var matrix: Dictionary = {}
	for first_index in range(card_ids.size()):
		for second_index in range(first_index + 1, card_ids.size()):
			for third_index in range(second_index + 1, card_ids.size()):
				var ids: Array = [card_ids[first_index], card_ids[second_index], card_ids[third_index]]
				var profile: Dictionary = _profile(ids)
				matrix["%s + %s + %s" % [card_ids[first_index], card_ids[second_index], card_ids[third_index]]] = profile["ev"]
	return matrix

func _power_values(config: Dictionary) -> Dictionary:
	var weights: Array = _weights(config)
	var total_weight := 0.0
	for entry in weights:
		total_weight += float(entry["weight"])
	var totals := { "reroll": 0.0, "shift": 0.0, "cheat": 0.0, "swap": 0.0 }
	for first in weights:
		for second in weights:
			for third in weights:
				var probability := float(first["weight"]) * float(second["weight"]) \
					* float(third["weight"]) / pow(total_weight, 3.0)
				var reels: Array = [String(first["value"]), String(second["value"]), String(third["value"])]
				var base := _score(config, reels)
				var best_reroll := 0.0
				for reel_index in range(3):
					var expected := 0.0
					for candidate in weights:
						var rerolled: Array = reels.duplicate()
						rerolled[reel_index] = String(candidate["value"])
						expected += float(candidate["weight"]) / total_weight * _score(config, rerolled)
					best_reroll = maxf(best_reroll, expected - float(base))
				var best_shift := 0
				var best_cheat := 0
				var best_swap := 0
				for reel_index in range(3):
					var current := Symbols.BASE_SYMBOL_CYCLE.find(reels[reel_index])
					if current >= 0:
						for direction in [-1, 1]:
							var shifted: Array = reels.duplicate()
							shifted[reel_index] = Symbols.BASE_SYMBOL_CYCLE[
								(current + direction + Symbols.BASE_SYMBOL_CYCLE.size()) \
								% Symbols.BASE_SYMBOL_CYCLE.size()]
							best_shift = maxi(best_shift, _score(config, shifted) - base)
					for candidate in Symbols.BASE_SYMBOL_CYCLE:
						var cheated: Array = reels.duplicate()
						cheated[reel_index] = String(candidate)
						best_cheat = maxi(best_cheat, _score(config, cheated) - base)
				for source in range(3):
					for destination in range(3):
						if source == destination:
							continue
						var swapped: Array = reels.duplicate()
						var source_symbol: Variant = swapped[source]
						swapped[source] = swapped[destination]
						swapped[destination] = source_symbol
						best_swap = maxi(best_swap, _score(config, swapped) - base)
				totals["reroll"] += maxf(0.0, best_reroll) * probability
				totals["shift"] += float(best_shift) * probability
				totals["cheat"] += float(best_cheat) * probability
				totals["swap"] += float(best_swap) * probability
	return totals

func _build_report() -> Dictionary:
	var single: Dictionary = {}
	for card in REPORT_CARDS:
		var card_id := String(card["id"])
		var profile: Dictionary = _profile([card_id])
		var reward_choices: Dictionary = {}
		if card_id == "augment_reward_1":
			for symbol in Symbols.BASE_SYMBOL_CYCLE:
				reward_choices[symbol] = _profile([card_id], symbol)["ev"]
		profile["route_card_cost"] = PacteCards.cost_for(card_id)
		profile["reward_choices"] = reward_choices
		single[card_id] = profile
	var catalog_ids: Array = []
	for card in REPORT_CARDS:
		catalog_ids.append(String(card["id"]))
	var baseline: Dictionary = _profile([])
	var full_ids: Array = catalog_ids.duplicate()
	var full: Dictionary = _profile(full_ids)
	var simulations: Dictionary = {}
	for build in REALISTIC_BUILDS:
		var ids: Array = build["cards"] as Array
		simulations[String(build["name"])] = _simulated_build(ids, "brain", SIMULATION_RUNS)
	var power_values := _power_values(baseline["config"] as Dictionary)
	return {
		"single": single,
		"baseline": baseline,
		"pairs": _pair_matrix(catalog_ids),
		"triples": _triple_matrix(catalog_ids),
		"full": full,
		"powers": power_values,
		"simulations": simulations,
		"route_costs": {
			"pacte": RouteCards.PACTE_ROUTE_COST,
			"shop": RouteCards.SHOP_ROUTE_COST,
			"dealer": RouteCards.DEALER_ROUTE_COST,
			"pacte_card_costs": {
				"augment_pattern_recognition": PacteCards.cost_for("augment_pattern_recognition"),
				"augment_hallucination": PacteCards.cost_for("augment_hallucination"),
				"augment_tunnel_vision": PacteCards.cost_for("augment_tunnel_vision"),
				"augment_reward_1": PacteCards.cost_for("augment_reward_1"),
			},
			"shop_items": ShopItems.map(),
		},
	}

func _print_profile(name: String, profile: Dictionary) -> void:
	print("  %-18s EV %7.2f  p50 %3d  p90 %3d  p99 %3d  max %3d  miss %5.1f%%  strike %5.2f%%" % [
		name, float(profile["ev"]), int(profile["p50"]), int(profile["p90"]), int(profile["p99"]),
		int(profile["max"]), float(profile["miss_probability"]) * 100.0,
		float(profile["strike_probability"]) * 100.0])

func _print_report(report: Dictionary) -> void:
	print("BALANCE REPORT / DIAGNOSTIC — current rules, no golden thresholds")
	print("Exact reel EV is weighted exhaustive; target probabilities use %d deterministic runs per build." % SIMULATION_RUNS)
	print("Wealth model: each intermediate target zeroes scoreEarned, taxes/banks overflow, then resets the machine segment.")
	print("")
	print("SINGLE-CARD EV AND SCORE DISTRIBUTION (x1, one spin)")
	_print_profile("BASELINE", report["baseline"])
	for card in REPORT_CARDS:
		var card_id := String(card["id"])
		_print_profile(String(card["label"]), report["single"][card_id])
		var choices: Dictionary = report["single"][card_id]["reward_choices"]
		if not choices.is_empty():
			print("    Reward+ choices: ", choices)
	print("")
	print("PAIR SYNERGY MATRIX (EV; diagonal omitted)")
	for key in report["pairs"]:
		print("  %-70s %7.2f" % [key, float(report["pairs"][key])])
	print("")
	print("THREE-CARD SYNERGY MATRIX")
	for key in report["triples"]:
		print("  %-70s %7.2f" % [key, float(report["triples"][key])])
	print("")
	print("VALUE LAYERS / POWER DELTAS ON AVERAGE REVEAL")
	var baseline: Dictionary = report["baseline"]
	print("  Free-spin value (one free reveal): %.3f" % (float(baseline["free_ev"]) - float(baseline["ev"])))
	for power_id in report["powers"]:
		print("  %-18s +%7.2f score" % [power_id, float(report["powers"][power_id])])
	print("  Water direct event: +40 score / +40 Lucidity")
	print("  Cocktail two-spin rarity value: %.2f expected score before frenzy" % (float(baseline["ev"]) * 0.0 + 2.0 * _expected_cocktail_value(baseline["config"] as Dictionary)))
	print("  Energy Drink two protected reveals: %.2f expected score before frenzy" % (2.0 * float(baseline["ev"])))
	print("  Dealer BUY TIME (+3 spins): %.2f expected score before frenzy" % (3.0 * float(baseline["ev"])))
	print("")
	print("MARGINAL VALUE AFTER ROUTE/CARD COST")
	for card in REPORT_CARDS:
		var card_id := String(card["id"])
		var card_profile: Dictionary = report["single"][card_id]
		var marginal := (float(card_profile["free_ev"]) - float(baseline["free_ev"])) \
			* float(EconomyConst.STARTING_NEURONS) - float(card_profile["route_card_cost"]) \
			- float(RouteCards.PACTE_ROUTE_COST)
		print("  %-18s net segment score after %dG route + %dG card: %7.2f" % [
			String(card["label"]), RouteCards.PACTE_ROUTE_COST, int(card_profile["route_card_cost"]), marginal])
	print("")
	print("WEALTH TARGET REACH AND FLATLINE PROBABILITY")
	for build_name in report["simulations"]:
		var simulation: Dictionary = report["simulations"][build_name]
		var target_text := ""
		for index in range((simulation["target_probabilities"] as Array).size()):
			target_text += "%d:%.1f%% " % [EconomyConst.WEALTH_TARGETS[index],
				float((simulation["target_probabilities"] as Array)[index]) * 100.0]
		print("  %-12s wealth %5.1f%% flatline %5.1f%% median target %d median gold %d" % [
			build_name, float(simulation["wealth_probability"]) * 100.0,
			float(simulation["flatline_probability"]) * 100.0,
			int(simulation["median_target"]), int(simulation["median_lucidity"])])
		print("    targets: ", target_text)
	print("")
	print("FULL-BUILD CEILING / REALISTIC MEDIANS")
	print("  Full-build one-spin ceiling: %d; loose 15-paid + 15-free upper bound: %d" % [
		int(report["full"]["max"]), int(report["full"]["max"]) * 30])
	for build in REALISTIC_BUILDS:
		var simulation: Dictionary = report["simulations"][String(build["name"])]
		print("  %-12s median reaches target %d with %d gold" % [String(build["name"]),
			int(simulation["median_target"]), int(simulation["median_lucidity"])])
	print("")
	print("ROUTE COSTS / SHOP INVENTORY")
	print("  Route cards: PACTE %dG, SHOP %dG, DEALER %dG; refusal is free." % [
		RouteCards.PACTE_ROUTE_COST, RouteCards.SHOP_ROUTE_COST, RouteCards.DEALER_ROUTE_COST])
	for item_id in report["route_costs"]["shop_items"]:
		var item: Dictionary = report["route_costs"]["shop_items"][item_id]
		print("  Shop %-24s %dG" % [String(item.get("name", item_id)), int(item.get("cost", 0))])

func _expected_cocktail_value(config: Dictionary) -> float:
	var weights: Array = _weights(config)
	var total_weight := 0.0
	for entry in weights:
		total_weight += float(entry["weight"])
	var expected := 0.0
	for entry in weights:
		expected += float(entry["weight"]) / total_weight \
			* float(InRunItems.COCKTAIL_RARITY_POINTS.get(String(entry["value"]), 0))
	return expected * float(3 - int(config["hidden"]))
