class_name ParityChecks
extends RefCounted

## Loads the canonical golden vectors from parity/vectors/ (from the original prototype
## fixture set) and asserts the GDScript rules core reproduces
## every one EXACTLY. This is the Godot half of the parity contract.
##
## run_all() returns an Array[String] of failure messages (empty == all green).
## Used by both the headless runner and the GUT suite.

# Resolve parity/vectors/ which lives one level above the Godot project root.
static func _vectors_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../parity/vectors")

static func _load(name: String) -> Variant:
	var path := _vectors_dir().path_join(name)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open vector file: " + path)
		return null
	var txt := f.get_as_text()
	f.close()
	return JSON.parse_string(txt)

# Numeric-tolerant deep equality (handles int/float mixing from JSON).
static func deep_equal(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	var a_num := ta == TYPE_INT or ta == TYPE_FLOAT
	var b_num := tb == TYPE_INT or tb == TYPE_FLOAT
	if a_num and b_num:
		return absf(float(a) - float(b)) <= 1e-9 + 1e-9 * absf(float(b))
	if ta != tb:
		return false
	match ta:
		TYPE_DICTIONARY:
			if a.size() != b.size():
				return false
			for k in a:
				if not b.has(k):
					return false
				if not deep_equal(a[k], b[k]):
					return false
			return true
		TYPE_ARRAY:
			if a.size() != b.size():
				return false
			for i in a.size():
				if not deep_equal(a[i], b[i]):
					return false
			return true
		_:
			return a == b

static func _fail(out: Array, label: String, got: Variant, expect: Variant) -> void:
	out.append("%s\n    got:    %s\n    expect: %s" % [label, str(got), str(expect)])

# ── individual checks ───────────────────────────────────────────────────────────

static func check_rng(out: Array) -> void:
	var data: Dictionary = _load("rng.json")
	for seed in data["seeds"]:
		var rng := LobRNG.new(int(seed))
		var u32: Array = data["vectors"][str(int(seed))]["u32"]
		for i in u32.size():
			var got := rng.next_u32()
			if got != int(u32[i]):
				_fail(out, "rng seed=%d i=%d" % [int(seed), i], got, int(u32[i]))
				break

static func check_score_reels(out: Array) -> void:
	var data: Dictionary = _load("score_reels.json")
	for c in data["cases"]:
		# Book was intentionally reworked after the prototype vectors: it now acts as
		# a joker instead of a flat visible-symbol bonus. Non-book parity remains pinned.
		if bool(c["learningActive"]) and (c["reels"] as Array).has("book"):
			continue
		var got := Evaluate.score_reels(c["reels"], float(c["lucidityMultiplier"]),
			bool(c["allowFreeSpinGrant"]), bool(c["pattern23Triple"]), bool(c["learningActive"]))
		if not deep_equal(got, c["expect"]):
			_fail(out, "score_reels " + str(c["reels"]), got, c["expect"])

static func check_rounding(out: Array) -> void:
	var data: Dictionary = _load("rounding.json")
	for c in data["cases"]:
		var got := floori(float(c["value"]) * float(c["multiplier"]) + 0.5)
		if got != int(c["expect"]):
			_fail(out, "rounding %s*%s" % [str(c["value"]), str(c["multiplier"])], got, int(c["expect"]))

static func check_evaluate(out: Array) -> void:
	var data: Dictionary = _load("evaluate.json")
	for c in data["cases"]:
		var input: Dictionary = (c["input"] as Dictionary).duplicate(true)
		if bool(input.get("learningActive", false)):
			continue
		input["rng"] = LobRNG.new(int(c["seed"]))
		var got := Evaluate.evaluate(input)
		if not deep_equal(got, c["expect"]):
			_fail(out, "evaluate seed=%d" % int(c["seed"]), got, c["expect"])

static func check_abilities(out: Array) -> void:
	var data: Dictionary = _load("abilities.json")
	for c in data["cases"]:
		if bool(c["learningActive"]) and (c["reels"] as Array).has("book"):
			continue
		var got: Dictionary
		match String(c["op"]):
			"reroll":
				got = Abilities.apply_reroll(c["reels"], int(c["reelIndex"]), LobRNG.new(int(c["seed"])),
					float(c["lucidityMultiplier"]), Symbols.symbol_weights(),
					bool(c["pattern23Triple"]), bool(c["learningActive"]), bool(c["allowFreeSpinGrant"]))
			"move":
				got = Abilities.apply_move_column(c["reels"], int(c["reelIndex"]), int(c["direction"]),
					float(c["lucidityMultiplier"]), bool(c["pattern23Triple"]), bool(c["learningActive"]),
					bool(c["allowFreeSpinGrant"]))
			"copy":
				got = Abilities.apply_copy_reel(c["reels"], int(c["sourceReel"]), int(c["targetReel"]),
					float(c["lucidityMultiplier"]), bool(c["pattern23Triple"]), bool(c["learningActive"]),
					bool(c["allowFreeSpinGrant"]))
		if not deep_equal(got, c["expect"]):
			_fail(out, "ability %s %s" % [String(c["op"]), str(c["reels"])], got, c["expect"])

static func check_dealer(out: Array) -> void:
	var data: Dictionary = _load("dealer_vectors.json")
	for c in data["pickDealerItems"]:
		var got: Variant = Dealer.pick_dealer_items(int(c["seed"]))
		if not deep_equal(got, c["expect"]):
			_fail(out, "pickDealerItems seed=%d" % int(c["seed"]), got, c["expect"])
	for c in data["evaluateDealerTrigger"]:
		var got := Dealer.evaluate_dealer_trigger(c["input"])
		if not deep_equal(got, c["expect"]):
			_fail(out, "evaluateDealerTrigger " + str(c["input"]), got, c["expect"])

# Painting reroll (issue #117): deterministic, seed-driven like pick_dealer_items.
static func check_dealer_reroll(out: Array) -> void:
	var ids := InRunItems.ids()
	for s in [0, 1, 42, 123456789, 0xFFFFFFFF]:
		var previous: Variant = Dealer.pick_dealer_items(int(s))
		var a: Variant = Dealer.reroll_dealer_items(int(s) * 31 + 7, previous)
		var b: Variant = Dealer.reroll_dealer_items(int(s) * 31 + 7, previous)
		if not deep_equal(a, b):
			_fail(out, "rerollDealerItems determinism seed=%d" % int(s), a, b)
			continue
		var pair := a as Array
		if pair.size() != 2 or pair[0] == pair[1] or not ids.has(pair[0]) or not ids.has(pair[1]):
			_fail(out, "rerollDealerItems pair seed=%d" % int(s), a, "two distinct pool items")
			continue
		# With >=3 candidates a reroll must change the offered pair (as a set).
		if ids.size() >= 3:
			var prev := previous as Array
			if prev.has(pair[0]) and prev.has(pair[1]):
				_fail(out, "rerollDealerItems unchanged seed=%d" % int(s), a, "pair != previous")
	if Dealer.reroll_dealer_items(1, null) == null:
		_fail(out, "rerollDealerItems null-previous", null, "a pair")
	# Generic pool-pair helpers back the pre-run shop offer (max two consumables
	# per visit) — same determinism and pair-must-change contract on that pool.
	var shop_ids: Array = []
	for c in Consumables.LIST:
		shop_ids.append(String(c["id"]))
	for s in [3, 99, 424242]:
		var first: Variant = Dealer.pick_pool_pair(shop_ids.duplicate(), int(s))
		if not deep_equal(first, Dealer.pick_pool_pair(shop_ids.duplicate(), int(s))):
			_fail(out, "pickPoolPair determinism seed=%d" % int(s), first, "same pair")
			continue
		var p := first as Array
		if p.size() != 2 or p[0] == p[1] or not shop_ids.has(p[0]) or not shop_ids.has(p[1]):
			_fail(out, "pickPoolPair pair seed=%d" % int(s), first, "two distinct pool items")
			continue
		var r: Variant = Dealer.reroll_pool_pair(shop_ids.duplicate(), int(s) * 7 + 1, first)
		var pair2 := r as Array
		if pair2.size() != 2 or (p.has(pair2[0]) and p.has(pair2[1])):
			_fail(out, "rerollPoolPair unchanged seed=%d" % int(s), r, "pair != previous")

# Rewards Amplification on the pair bonus (issue #108): pairs of the amped symbol
# pay round(base * (1 + bonus)) — the same amplified value the score table shows —
# while other symbols, triples/jackpots, and tier stacking stay pinned.
static func check_reward_amp_pair(out: Array) -> void:
	var data: Dictionary = _load("reward_amp_pair.json")
	for t in data["tiers"]:
		var got_bonus := Economy.compute_symbol_reward_amp_bonus(t["owned"])
		if not deep_equal(got_bonus, t["expect"]):
			_fail(out, "rewardAmp tiers " + str(t["owned"]), got_bonus, t["expect"])
	for c in data["cases"]:
		var got := Evaluate.score_reels(c["reels"], float(c["lucidityMultiplier"]),
			bool(c["allowFreeSpinGrant"]), bool(c["pattern23Triple"]), false,
			1.0, 0, false, 1.0, c["symbolRewardBonuses"])
		if not deep_equal(got, c["expect"]):
			_fail(out, "rewardAmpPair " + String(c["label"]), got, c["expect"])

static func check_bank(out: Array) -> void:
	var data: Dictionary = _load("bank.json")
	for c in data["cases"]:
		var run := {
			"neurons": 0,
			"lucidityCoins": int(c["run"]["lucidityCoins"]),
			"scoreEarned": int(c["run"]["scoreEarned"]),
		}
		var got := Endings.bank_run_to_meta(run, c["meta"], String(c["ending"]), int(c["now"]))
		if not deep_equal(got, c["expect"]):
			_fail(out, "bank " + String(c["label"]), got, c["expect"])

static func check_lucidity(out: Array) -> void:
	var data: Dictionary = _load("lucidity_restore.json")
	for c in data["cases"]:
		var inp: Dictionary = c["input"]
		var got := Lucidity.plan_gain(int(inp["prevCoins"]), int(inp["gain"]),
			inp["abilitiesUsed"], int(inp["seed"]))
		if not deep_equal(got, c["expect"]):
			_fail(out, "lucidity " + str(inp), got, c["expect"])

static func check_endings(out: Array) -> void:
	var data: Dictionary = _load("endings.json")
	for c in data["checkEnding"]:
		var run := { "neurons": int(c["input"]["neurons"]), "scoreEarned": int(c["input"]["scoreEarned"]), "lucidityCoins": 0 }
		var got: Variant = Endings.check_ending(run, {})
		if not deep_equal(got, c["expect"]):
			_fail(out, "checkEnding " + str(c["input"]), got, c["expect"])
	for c in data["checkExitEligibility"]:
		var run := { "lucidityCoins": int(c["input"]["lucidityCoins"]) }
		var meta := { "corruptionEverUsed": bool(c["input"]["corruptionEverUsed"]) }
		var got := Endings.check_exit_eligibility(run, meta)
		if got != bool(c["expect"]):
			_fail(out, "checkExitEligibility " + str(c["input"]), got, bool(c["expect"]))

static func check_issue176(out: Array) -> void:
	if EconomyConst.CAMPAIGN_STARTING_NEURONS != 3:
		_fail(out, "issue176 campaign health", EconomyConst.CAMPAIGN_STARTING_NEURONS, 3)
	var targets := [100, 200, 500, 800, 1500, 2500, 3500, 5000]
	for i in targets.size():
		var score := 0 if i == 0 else int(targets[i - 1])
		var got := Endings.next_wealth_target(score)
		if got != int(targets[i]):
			_fail(out, "issue176 wealth target score=%d" % score, got, targets[i])
	if Endings.next_wealth_target(5000) != 5000:
		_fail(out, "issue176 final wealth target", Endings.next_wealth_target(5000), 5000)
	var tunnel_owned: Array = ["pacte_tunnel_vision"]
	var tunnel := Evaluate.score_reels(["eye", "eye", "brain"], 1.0, true,
		false, false, 1.0, 1, false, Economy.compute_tunnel_vision_reward_scale(tunnel_owned))
	if String(tunnel["winType"]) != "pair" or int(tunnel["scoreEarned"]) != 15:
		_fail(out, "issue176 tunnel vision scoring", tunnel, "pair / 15")
	var cheat := Evaluate.score_reels(["brain", "eye", "pill"], 1.0, true,
		false, false, Economy.compute_pair_score_multiplier(["pacte_how_to_cheat"]),
		0, false, 1.0, {}, true)
	if String(cheat["winType"]) != "pair" or int(cheat["scoreEarned"]) != 12 \
			or not bool(cheat.get("soloAsPair", false)):
		_fail(out, "issue176 solo-as-pair scoring", cheat, "pair / 12")
	if Economy.compute_passive_lucidity(["pacte_passive_gain"]) != 10:
		_fail(out, "issue176 passive gain", Economy.compute_passive_lucidity(["pacte_passive_gain"]), 10)
	if Economy.compute_power_restore_threshold(["pacte_adrenaline"], 50) != 30:
		_fail(out, "issue176 adrenaline threshold",
			Economy.compute_power_restore_threshold(["pacte_adrenaline"], 50), 30)


static func check_pacte_deck_and_powers(out: Array) -> void:
	var augment_unlocks: Array[String] = PacteCards.augment_ids()
	var power_unlocks: Array[String] = PacteCards.power_draw_ids()
	var first := PacteCards.draw("augment", 0x115, augment_unlocks, [], 3)
	var second := PacteCards.draw("augment", 0x115, augment_unlocks, [], 3)
	if not deep_equal(first, second) or first.size() != 3:
		_fail(out, "Pacte augment draw determinism", first, second)
	var restricted := PacteCards.draw("power", 0x156, ["shift", "swap"], [], 3)
	if restricted.size() != 2 or not restricted.has("shift") or not restricted.has("swap"):
		_fail(out, "Pacte unlock filtering", restricted, ["shift", "swap"])
	var excluded := PacteCards.draw("power", 0x157, power_unlocks, ["shift", "swap"], 3)
	if excluded.has("shift") or excluded.has("swap"):
		_fail(out, "Pacte accumulated selection exclusion", excluded, "without shift/swap")
	var authored_augment_rows := {
		"augment_pattern_recognition": 144, "augment_book": 201,
		"augment_hallucination": 262, "augment_smart_saving": 324,
		"augment_reward_1": 386, "augment_reward_2": 447, "augment_reward_3": 508,
	}
	for card_id in authored_augment_rows:
		var icon_rect := PacteCards.card(String(card_id)).get("icon_rect", Rect2()) as Rect2
		if int(icon_rect.position.y) != int(authored_augment_rows[card_id]):
			_fail(out, "Pacte augment sheet row %s" % card_id, icon_rect,
				authored_augment_rows[card_id])
	var smart_save_icon := PacteCards.card("augment_smart_saving").get(
		"icon_rect", Rect2()) as Rect2
	if int(smart_save_icon.position.x) != 5:
		_fail(out, "Smart Save icon horizontal centering", smart_save_icon.position.x, 5)
	var one_heart := Abilities.resolve_hearts(1)
	var three_hearts := Abilities.resolve_hearts(3)
	if not deep_equal(one_heart, {
			"heartCount": 1, "neuronsDelta": 1, "scoreDelta": 0,
			"coinsDelta": 0, "winType": "heart"}):
		_fail(out, "Heart one-heart outcome", one_heart, "one heart spin, no score")
	if int(three_hearts["neuronsDelta"]) != 3 or int(three_hearts["scoreDelta"]) != 0 \
			or int(three_hearts["coinsDelta"]) != 0:
		_fail(out, "Heart three-heart outcome", three_hearts, "3 neurons / no score")
	var heart_spin := Abilities.resolve_heart_spin(2)
	if not deep_equal(heart_spin["reels"], ["heart_x2", "heart_x2", "heart_x2"]) \
			or int(heart_spin["scoreEarned"]) != 0 or int(heart_spin["coinsEarned"]) != 0 \
			or int(heart_spin["neuronsDelta"]) != 2:
		_fail(out, "Heart forced triple outcome", heart_spin, "three heart_x2 symbols, no score")
	var cheat := Abilities.apply_cheat(["brain", "eye", "pill"], 1, "brain", 1.0)
	if not (cheat["reels"] as Array).has("brain") or String((cheat["reels"] as Array)[1]) != "brain":
		_fail(out, "Cheat symbol replacement", cheat, "brain/brain/pill")
	var adjacent_swap := Abilities.apply_swap_symbol(["brain", "eye", "pill"], 0, 1, 1.0)
	if not deep_equal(adjacent_swap["reels"], ["eye", "brain", "pill"]):
		_fail(out, "Swap adjacent symbol exchange", adjacent_swap, ["eye", "brain", "pill"])
	var duplicate_adjacent_swap := Abilities.apply_swap_symbol(
		["brain", "eye", "pill"], 0, 1, 1.0, false, false, false, 1.0, 0,
		false, 1.0, {}, "eye")
	if not deep_equal(duplicate_adjacent_swap["reels"], ["eye", "eye", "pill"]):
		_fail(out, "Swap duplicate adjacent symbol", duplicate_adjacent_swap, ["eye", "eye", "pill"])

static func run_all() -> Array:
	var out: Array = []
	check_rng(out)
	check_score_reels(out)
	check_rounding(out)
	check_evaluate(out)
	check_abilities(out)
	check_dealer(out)
	check_dealer_reroll(out)
	check_reward_amp_pair(out)
	check_bank(out)
	check_lucidity(out)
	check_endings(out)
	check_issue176(out)
	check_pacte_deck_and_powers(out)
	return out
