extends Node

## Autoload singleton "RunStateStore" — port of src/state/runState.ts. Exposes the
## same action API; all scoring / ability / dealer / lucidity decisions delegate to
## the parity-verified pure modules (Evaluate, Abilities, Dealer, Lucidity, Economy).
## Scenes call these methods and never mutate gameplay fields directly.
##
## NOTE: this is the Milestone-2 surface (playable run loop). The pure rules it calls
## are pinned by the parity harness; the store plumbing is verified by play-testing.

signal state_changed

const M32 := 0xFFFFFFFF

# RunState fields (mirror types.ts RunState)
var neurons := 0
var startingNeurons := 0
var scoreEarned := 0
var lucidityCoins := 0
var freeSpinsRemaining := 0
var maxFreeSpins := EconomyConst.BASE_MAX_FREE_SPINS
var lucidityMultiplier := EconomyConst.BASE_LUCIDITY_MULTIPLIER
var nextSpinLucidityMultiplier := 1.0
var isSpinning := false
var lastResult: Variant = null
var lockedReels := [false, false, false]
var lockedReelSpins := [0, 0, 0]
var runConsumables: Dictionary = {}
var abilitiesUsed: Array = []
var ownedUpgrades: Array = []
var spinCount := 0
var isFreeSpin := false
var betMultiplier := 1
var lastEffectiveBet := 1 # display only (score-burst colour); not gameplay/parity
var dealerCount := 0
var dealerLastSpinCount := 0
var dealer65SafetyFired := false
var dealer35SafetyFired := false
var dealerIncoming := false
var dealerPending := false
var dealerOfferIds: Variant = null
var brainBoostSpins := 0
var forcedRandomBetSpins := 0
var guaranteedWinSpins := 0
var blockPowersSpins := 0
var hideNeuronsSpins := 0
var cocktailBoostSpins := 0
var compulsiveSpinSkips := 0
var pendingCompulsiveSpinSkips := 0
var decaySkips := 0

# RunStore extras
var runPhase := "idle" # idle | running | over
var lastEnding: Variant = null
var wealthContinued := false
var pendingPowerRestores: Array = []

static func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)

func _seed(mix: int) -> int:
	return (_now_ms() ^ mix) & M32

func _can_act() -> bool:
	return runPhase == "running" and not isSpinning

func _can_use_ability() -> bool:
	return _can_act() and lastResult != null and blockPowersSpins <= 0

func _commit() -> void:
	state_changed.emit()

# ── spin ──────────────────────────────────────────────────────────────────────────

func spin(compulsive := false) -> Variant:
	if runPhase != "running" or isSpinning:
		return null
	var is_compulsive: bool = compulsive and compulsiveSpinSkips > 0
	var is_free: bool = (not is_compulsive) and freeSpinsRemaining > 0
	if (not is_free) and neurons < 1:
		return null

	var seed := _seed(spinCount * 0x9e3779b9)
	var rng := LobRNG.new(seed)

	var stasis: bool = (not is_compulsive) and (not is_free) and decaySkips > 0
	var sedative: bool = (not is_compulsive) and (not is_free) and Economy.has_sedative(ownedUpgrades) and (spinCount + 1) % 3 == 0

	var eff_bet := betMultiplier
	if is_compulsive:
		eff_bet = 1
	elif forcedRandomBetSpins > 0 and eff_bet == 3:
		eff_bet = 2
	if (not stasis) and (not sedative) and (not is_free):
		var budget := maxi(1, ceili(float(neurons) / EconomyConst.NEURON_DECAY_PER_SPIN))
		eff_bet = mini(eff_bet, budget)

	var base_decay := Economy.compute_neuron_decay(ownedUpgrades)
	var decay_amt := 0 if (stasis or sedative or is_free) else mini(eff_bet * base_decay, neurons)

	var brain_bonus := Economy.compute_brain_weight_bonus(ownedUpgrades)
	if brainBoostSpins > 0:
		brain_bonus += int(Symbols.WEIGHT["brain"]) * 3

	var base_mult := lucidityMultiplier * nextSpinLucidityMultiplier * eff_bet
	var eff_mult: float = base_mult * 0.5 if brainBoostSpins > 0 else base_mult

	var book_w := Economy.compute_book_weight(ownedUpgrades)
	var result := Evaluate.evaluate({
		"neurons": neurons,
		"neuronDecayAmount": decay_amt,
		"freeSpinsRemaining": freeSpinsRemaining,
		"maxFreeSpins": maxFreeSpins,
		"lucidityMultiplier": eff_mult,
		"isFreeSpin": is_free,
		"lockedReels": lockedReels,
		"previousReels": (lastResult["reels"] if lastResult != null else null),
		"rng": rng,
		"bookWeight": book_w,
		"brainWeightBonus": brain_bonus,
		"guaranteedWin": guaranteedWinSpins > 0,
		"pattern23Triple": Economy.has_pattern23_triple(ownedUpgrades),
		"learningActive": book_w > 0,
	})

	var cocktail_bonus := 0
	if cocktailBoostSpins > 0:
		for sym in result["reels"]:
			cocktail_bonus += int(Symbols.RARITY.get(sym, 0))
	var final_result: Dictionary = result
	if cocktail_bonus > 0:
		final_result = result.duplicate(true)
		final_result["scoreEarned"] = int(result["scoreEarned"]) + cocktail_bonus
		final_result["cocktailApplied"] = true

	var plan := Lucidity.plan_gain(lucidityCoins, int(final_result["scoreEarned"]), abilitiesUsed, seed)

	var was_cocktail_last: bool = cocktailBoostSpins == 1

	neurons = int(final_result["neuronsAfter"])
	scoreEarned += int(final_result["scoreEarned"])
	lucidityCoins = int(plan["lucidityCoins"])
	abilitiesUsed = plan["abilitiesUsed"]
	pendingPowerRestores.append_array(plan["restores"])
	freeSpinsRemaining = int(final_result["freeSpinsAfter"])
	isFreeSpin = bool(final_result["isFreeSpin"])
	isSpinning = true
	lastResult = final_result
	lastEffectiveBet = clampi(eff_bet, 1, 3)
	spinCount += 1
	nextSpinLucidityMultiplier = 1.0
	if stasis:
		decaySkips -= 1
	brainBoostSpins = maxi(0, brainBoostSpins - 1)
	forcedRandomBetSpins = maxi(0, forcedRandomBetSpins - 1)
	guaranteedWinSpins = maxi(0, guaranteedWinSpins - 1)
	blockPowersSpins = maxi(0, blockPowersSpins - 1)
	hideNeuronsSpins = maxi(0, hideNeuronsSpins - 1)
	cocktailBoostSpins = maxi(0, cocktailBoostSpins - 1)
	compulsiveSpinSkips = (maxi(0, compulsiveSpinSkips - 1) if is_compulsive else compulsiveSpinSkips) \
		+ (pendingCompulsiveSpinSkips if was_cocktail_last else 0)
	pendingCompulsiveSpinSkips = 0 if was_cocktail_last else pendingCompulsiveSpinSkips

	_commit()
	return final_result

func set_spinning(v: bool) -> void:
	if v:
		isSpinning = true
	else:
		var spins := [maxi(0, int(lockedReelSpins[0]) - 1), maxi(0, int(lockedReelSpins[1]) - 1), maxi(0, int(lockedReelSpins[2]) - 1)]
		lockedReelSpins = spins
		lockedReels = [spins[0] > 0, spins[1] > 0, spins[2] > 0]
		isSpinning = false
	_commit()

func set_bet_multiplier(m: int) -> void:
	if m == 3 and forcedRandomBetSpins > 0:
		return
	betMultiplier = m
	_commit()

# ── run lifecycle ──────────────────────────────────────────────────────────────────

func start_new_run(owned_permanents: Array, pending_consumables: Dictionary) -> void:
	startingNeurons = Economy.compute_starting_neurons(owned_permanents)
	neurons = startingNeurons
	scoreEarned = 0
	lucidityCoins = 0
	freeSpinsRemaining = 0
	maxFreeSpins = Economy.compute_max_free_spins(owned_permanents)
	lucidityMultiplier = Economy.compute_lucidity_multiplier(owned_permanents)
	nextSpinLucidityMultiplier = 1.0
	isSpinning = false
	lastResult = null
	lockedReels = [false, false, false]
	lockedReelSpins = [0, 0, 0]
	runConsumables = pending_consumables.duplicate(true)
	abilitiesUsed = []
	ownedUpgrades = owned_permanents.duplicate()
	spinCount = 0
	isFreeSpin = false
	betMultiplier = 1
	dealerCount = 0
	dealerLastSpinCount = 0
	dealer65SafetyFired = false
	dealer35SafetyFired = false
	dealerIncoming = false
	dealerPending = false
	dealerOfferIds = null
	brainBoostSpins = 0
	forcedRandomBetSpins = 0
	guaranteedWinSpins = 0
	blockPowersSpins = 0
	hideNeuronsSpins = 0
	cocktailBoostSpins = 0
	compulsiveSpinSkips = 0
	pendingCompulsiveSpinSkips = 0
	decaySkips = 0
	pendingPowerRestores = []
	runPhase = "running"
	lastEnding = null
	wealthContinued = false
	_commit()

func end_run(ending: String) -> void:
	runPhase = "over"
	lastEnding = ending
	_commit()

func continue_run() -> void:
	if runPhase != "over" or lastEnding != "wealth":
		return
	runPhase = "running"
	lastEnding = null
	wealthContinued = true
	_commit()

# Public: delegate to the parity-verified pure planner (run action surface).
func plan_lucidity_gain(prev_coins: int, gain: int, abilities: Array, seed: int) -> Dictionary:
	return Lucidity.plan_gain(prev_coins, gain, abilities, seed)

func commit_power_restore(power_id: String) -> void:
	var idx := pendingPowerRestores.find(power_id)
	if idx < 0:
		return
	pendingPowerRestores.remove_at(idx)
	_commit()

# ── abilities ──────────────────────────────────────────────────────────────────────

func _weights_with_bonuses(brain_bonus: int, book_weight: int) -> Array:
	var weights := Symbols.symbol_weights()
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

func _apply_outcome(outcome: Dictionary, marked_used: Array, seed: int) -> void:
	var plan := Lucidity.plan_gain(lucidityCoins, int(outcome["coinsDelta"]), marked_used, seed)
	var free_after := mini(freeSpinsRemaining + int(outcome["freeSpinsGranted"]), maxFreeSpins)
	abilitiesUsed = plan["abilitiesUsed"]
	scoreEarned = maxi(0, scoreEarned + int(outcome["scoreDelta"]))
	lucidityCoins = int(plan["lucidityCoins"])
	pendingPowerRestores.append_array(plan["restores"])
	var lr: Dictionary = (lastResult as Dictionary).duplicate(true)
	lr["reels"] = outcome["reels"]
	lr["isJackpot"] = outcome["isJackpot"]
	lr["winType"] = outcome["winType"]
	lr["scoreEarned"] = maxi(0, int(lastResult["scoreEarned"]) + int(outcome["scoreDelta"]))
	lr["coinsEarned"] = maxi(0, int(lastResult["coinsEarned"]) + int(outcome["coinsDelta"]))
	lr["freeSpinsGranted"] = int(lastResult["freeSpinsGranted"]) + (free_after - freeSpinsRemaining)
	lr["freeSpinsAfter"] = free_after
	freeSpinsRemaining = free_after
	lastResult = lr

func reroll_reel(reel_index: int) -> bool:
	if not _can_use_ability() or lastResult == null:
		return false
	if abilitiesUsed.has("reroll"):
		return false
	var seed := _seed(spinCount * 0x5bd1e995 + reel_index)
	var rng := LobRNG.new(seed)
	var brain_bonus := Economy.compute_brain_weight_bonus(ownedUpgrades)
	if brainBoostSpins > 0:
		brain_bonus += int(Symbols.WEIGHT["brain"]) * 4
	var book_w := Economy.compute_book_weight(ownedUpgrades)
	var weights := _weights_with_bonuses(brain_bonus, book_w)
	var outcome := Abilities.apply_reroll(lastResult["reels"], reel_index, rng, float(lastResult["scoreMultiplier"]),
		weights, Economy.has_pattern23_triple(ownedUpgrades), book_w > 0, not bool(lastResult["isFreeSpin"]))
	var marked := abilitiesUsed.duplicate()
	marked.append("reroll")
	_apply_outcome(outcome, marked, seed)
	_commit()
	return true

func move_reel(reel_index: int, direction: int) -> bool:
	if not _can_use_ability() or lastResult == null:
		return false
	if not ownedUpgrades.has("perm_shift"):
		return false
	if abilitiesUsed.has("shift"):
		return false
	var book_w := Economy.compute_book_weight(ownedUpgrades)
	var outcome := Abilities.apply_move_column(lastResult["reels"], reel_index, direction, float(lastResult["scoreMultiplier"]),
		Economy.has_pattern23_triple(ownedUpgrades), book_w > 0, not bool(lastResult["isFreeSpin"]))
	var seed := _seed(spinCount * 0x27d4eb2f + reel_index)
	var marked := abilitiesUsed.duplicate()
	marked.append("shift")
	_apply_outcome(outcome, marked, seed)
	_commit()
	return true

func lock_reel(reel_index: int) -> void:
	if not _can_use_ability():
		return
	if not ownedUpgrades.has("perm_memory"):
		return
	if abilitiesUsed.has("memory"):
		return
	var locks := lockedReels.duplicate()
	locks[reel_index] = true
	var spins := lockedReelSpins.duplicate()
	spins[reel_index] = 2
	lockedReels = locks
	lockedReelSpins = spins
	abilitiesUsed = abilitiesUsed.duplicate()
	abilitiesUsed.append("memory")
	_commit()

func copy_reel(source_reel: int, target_reel: int) -> bool:
	if not _can_act() or lastResult == null:
		return false
	var book_w := Economy.compute_book_weight(ownedUpgrades)
	var outcome := Abilities.apply_copy_reel(lastResult["reels"], source_reel, target_reel, float(lastResult["scoreMultiplier"]),
		Economy.has_pattern23_triple(ownedUpgrades), book_w > 0, not bool(lastResult["isFreeSpin"]))

	var others := []
	for id in runConsumables:
		if id != "cons_white_powder" and int(runConsumables[id]) > 0:
			others.append(id)
	runConsumables = runConsumables.duplicate(true)
	if others.size() > 0:
		var rng := LobRNG.new(_seed(spinCount))
		var victim: String = others[floori(rng.next() * others.size())]
		runConsumables[victim] = int(runConsumables[victim]) - 1
	else:
		neurons = maxi(0, neurons - 20)

	var seed := _seed(spinCount * 0x165667b1)
	_apply_outcome(outcome, abilitiesUsed.duplicate(), seed)
	_commit()
	return true

# ── consumables / dealer ───────────────────────────────────────────────────────────

func use_consumable(consumable_id: String) -> bool:
	if not _can_act():
		return false
	if dealerIncoming or dealerPending:
		return false
	var cmap := Consumables.map()
	var imap := InRunItems.map()
	var consumable: Variant = cmap.get(consumable_id, null)
	var in_run: Variant = imap.get(consumable_id, null)
	if consumable == null and in_run == null:
		return false
	var charges := int(runConsumables.get(consumable_id, 0))
	if charges < 1:
		return false
	runConsumables = runConsumables.duplicate(true)
	runConsumables[consumable_id] = charges - 1

	if in_run != null:
		var e: Dictionary = in_run["effect"]
		match String(e["type"]):
			"skipDecay":
				decaySkips += int(e["spins"])
				forcedRandomBetSpins += int(e["forcedRandomBetSpins"])
				if betMultiplier == 3:
					betMultiplier = 2
			"addLucidity":
				var plan := Lucidity.plan_gain(lucidityCoins, int(e["amount"]), abilitiesUsed, _seed(spinCount * 0x2545f491))
				lucidityCoins = int(plan["lucidityCoins"])
				abilitiesUsed = plan["abilitiesUsed"]
				pendingPowerRestores.append_array(plan["restores"])
			"cocktailBoost":
				cocktailBoostSpins += int(e["spins"])
				pendingCompulsiveSpinSkips += int(e["compulsiveSpins"])
			"guaranteedWin":
				guaranteedWinSpins += int(e["spins"])
				blockPowersSpins += int(e["blockPowersSpins"])
		_commit()
		return true

	var ce: Dictionary = consumable["effect"]
	match String(ce["type"]):
		"skipDecay":
			decaySkips += int(ce["spins"])
		"lucidityMultiplierNextSpin":
			nextSpinLucidityMultiplier = float(ce["multiplier"])
			hideNeuronsSpins += int(ce.get("hideNeuronsSpins", 0))
		"restoreAbility":
			if abilitiesUsed.is_empty():
				return false
			var rng := LobRNG.new(_seed(spinCount * 0xdeadbeef))
			var idx := floori(rng.next() * abilitiesUsed.size())
			abilitiesUsed = abilitiesUsed.duplicate()
			abilitiesUsed.remove_at(idx)
		"brainBoost":
			var all_abilities := ["reroll", "shift", "memory"]
			var available := []
			for a in all_abilities:
				if not abilitiesUsed.has(a):
					available.append(a)
			abilitiesUsed = abilitiesUsed.duplicate()
			if available.size() > 0:
				var rng := LobRNG.new(_seed(spinCount))
				abilitiesUsed.append(available[floori(rng.next() * available.size())])
			brainBoostSpins = int(ce["spins"])
		"copyReel":
			pass # handled via copy_reel UI flow
	_commit()
	return true

func check_dealer_trigger() -> void:
	if runPhase != "running" or dealerPending or dealerIncoming:
		return
	if startingNeurons <= 0:
		return
	if dealerCount >= Dealer.MAX_COUNT:
		return
	if spinCount - dealerLastSpinCount < Dealer.MIN_SPIN_GAP:
		return
	var decision := Dealer.evaluate_dealer_trigger({
		"neurons": neurons, "startingNeurons": startingNeurons, "spinCount": spinCount,
		"dealerCount": dealerCount, "dealerLastSpinCount": dealerLastSpinCount,
		"dealer65SafetyFired": dealer65SafetyFired, "dealer35SafetyFired": dealer35SafetyFired,
		"procSeed": _seed(spinCount * 0x9e3779b9 + 0xdeadbeef),
	})
	dealer65SafetyFired = decision["dealer65SafetyFired"]
	dealer35SafetyFired = decision["dealer35SafetyFired"]
	if decision["shouldTrigger"]:
		var offers: Variant = Dealer.pick_dealer_items(_seed(spinCount * 0x6b43c7f))
		if offers == null:
			_commit()
			return
		dealerCount += 1
		dealerLastSpinCount = spinCount
		dealerIncoming = true
		dealerOfferIds = offers
	_commit()

func reveal_dealer() -> void:
	if not dealerIncoming or runPhase != "running":
		return
	dealerIncoming = false
	dealerPending = true
	_commit()

func decline_dealer_visit() -> void:
	dealerIncoming = false
	dealerPending = false
	dealerOfferIds = null
	_commit()

func accept_dealer_offer(item_id: String) -> void:
	if not dealerPending or dealerOfferIds == null:
		return
	if not (dealerOfferIds as Array).has(item_id):
		return
	var imap := InRunItems.map()
	if not imap.has(item_id):
		dealerPending = false
		dealerOfferIds = null
		_commit()
		return
	if Consumables.total_copies(runConsumables) >= Consumables.MAX_CONSUMABLE_SLOTS:
		dealerPending = false
		dealerOfferIds = null
		_commit()
		return
	runConsumables = runConsumables.duplicate(true)
	runConsumables[item_id] = int(runConsumables.get(item_id, 0)) + 1
	dealerPending = false
	dealerOfferIds = null
	_commit()

func decline_dealer_offer() -> void:
	dealerPending = false
	dealerOfferIds = null
	_commit()

func discard_run_consumable(discard_id: String) -> void:
	var current := int(runConsumables.get(discard_id, 0))
	if current <= 0:
		return
	runConsumables = runConsumables.duplicate(true)
	if current <= 1:
		runConsumables.erase(discard_id)
	else:
		runConsumables[discard_id] = current - 1
	_commit()
