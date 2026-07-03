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

@export_group("Run Balance")
@export var max_consumable_slots: int = Consumables.MAX_CONSUMABLE_SLOTS
@export var coins_per_power_restore: int = EconomyConst.LUCIDITY_COINS_PER_RESTORE

@export_group("Dealer Interruptions")
@export var dealer_max_count: int = Dealer.MAX_COUNT
@export var dealer_min_spin_gap: int = Dealer.MIN_SPIN_GAP
@export_range(0.0, 1.0, 0.01) var dealer_high_threshold: float = Dealer.THRESHOLD_HIGH
@export_range(0.0, 1.0, 0.01) var dealer_low_threshold: float = Dealer.THRESHOLD_LOW
@export_range(0.0, 1.0, 0.01) var dealer_proc_chance: float = Dealer.PROC_CHANCE

# Dealer odds table (issue #36) — the post-run "what's next?" odds-buying economy.
# probability_increase_per_upgrade is @export by explicit GDD requirement.
@export_group("Dealer Odds Table")
@export var odds_budget: int = 4
@export var odds_token_costs: Dictionary = { "brain": 4, "eye": 3, "pill": 3 }
@export var odds_default_token_cost: int = 2
@export var probability_increase_per_upgrade: int = 1
## Permanent odds upgrades cap out at this many levels per symbol (issue #50: 8 bars).
@export var odds_max_level: int = 8

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
# Consumable roster effects (issue #32).
var pairBoostSpins := 0          # Tobacco: hidden reel + pair multiplier active
var pairBoostMult := 1           # Tobacco: pair payout multiplier while active
var pairBoostHiddenReels := 0    # Tobacco: reels hidden from scoring while active
var guaranteeSymbolSpins := 0    # Serum: force the picked symbol to appear
var guaranteeSymbolId := ""      # Serum: the player-picked symbol (issue #53)
var blurReelsSpins := 0          # Serum: reels render blurry for these spins (display)
var pendingBlurSpins := 0        # Serum: blur queued for after the guaranteed spin
var banBrainSpins := 0           # Serum (legacy): brain banned from the reels
var potionSpins := 0             # Potion: one random pool effect per spin
var forceFlatlineSpins := 0      # Pill: force an all-flatline spin
var guaranteedTripleSpins := 0   # Pill: force a triple the spin after the flatline
var hideResultSpins := 0         # White Powder: hide the next spin's result

const NON_FLATLINE_SYMBOLS := ["brain", "eye", "pill", "syringe", "vial"]

# Machine-reaction state (issue #35). Additive run-flow fields updated by the
# machine's post-reveal reactions AFTER the parity-pinned spin()/power results —
# they never feed evaluate()/spin(), so the pinned vectors stay untouched.
var flatlineResultCount := 0    # count of 3-flatline reel outcomes seen this run
var lastUsedConsumableId := ""  # for the syringe-triple "recover last consumable"
# Presentation-only (issue #34): the Potion pool pick rolled for the last spin, so the
# machine can announce it. Never feeds evaluate()/spin() inputs — parity untouched.
var lastPotionEffect: Variant = null

# 3x eye (issue #53): the player taps a reel and its NEXT-spin symbol is revealed
# instantly. The symbol is rolled through the run's normal weight pipeline at tap
# time, then committed into the next spin via evaluate()'s gated forceReelSymbols.
var eyeRevealReel := -1
var eyeRevealSymbol := ""

# Dealer odds table (issue #36): additive weight overrides bought with a token
# budget at the post-run "what's next?" phase. Upgrades are PERMANENT — staged
# purchases commit into MetaStateStore.oddsUpgrades when the phase is finalized,
# and every run derives oddsWeightOverrides from the persisted levels. Applied at
# pick time only — the parity-locked base weights in Symbols are never mutated,
# and the pinned vectors (which pass no overrides) are untouched.
var oddsTokensRemaining := 0
var oddsWeightOverrides: Dictionary = {}
var oddsPendingUpgrades: Dictionary = {}  # staged this phase; undoable until finalized
var oddsPhaseCompleted := false           # closed screens stay closed until the next run

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

	# Potion (issue #32): roll one equal-weight pool effect for this spin, with a
	# dedicated seed so the pick is independent of the reel roll.
	var potion_mult := 1.0
	var potion_lucidity_delta := 0
	var potion_symbol_to_brain := 0
	var potion_free_reroll := false
	var potion_pick: Variant = null
	if potionSpins > 0:
		var p_rng := LobRNG.new((seed ^ 0x50710000) & M32)
		var pool: Array = Consumables.POTION_RANDOM_POOL
		var pick: Dictionary = pool[int(p_rng.next() * pool.size())]
		potion_pick = pick
		match String(pick["kind"]):
			"multNextSpin": potion_mult = float(pick["multiplier"])
			"lucidity": potion_lucidity_delta = int(pick["amount"])
			"symbolToBrain": potion_symbol_to_brain = 1
			"freeReroll": potion_free_reroll = true

	# Consumable reel transforms (issue #32). Pill forces a flatline spin, then a
	# guaranteed non-flatline triple the spin after; Serum bans/guarantees a symbol.
	var force_all: Variant = "flatline" if forceFlatlineSpins > 0 else null
	var force_triple: Variant = NON_FLATLINE_SYMBOLS if (forceFlatlineSpins <= 0 and guaranteedTripleSpins > 0) else null
	var pair_boost_active := pairBoostSpins > 0

	var book_w := Economy.compute_book_weight(ownedUpgrades)
	var result := Evaluate.evaluate({
		"neurons": neurons,
		"neuronDecayAmount": decay_amt,
		"freeSpinsRemaining": freeSpinsRemaining,
		"maxFreeSpins": maxFreeSpins,
		"lucidityMultiplier": eff_mult * potion_mult,
		"isFreeSpin": is_free,
		"lockedReels": lockedReels,
		"previousReels": (lastResult["reels"] if lastResult != null else null),
		"rng": rng,
		"bookWeight": book_w,
		"brainWeightBonus": brain_bonus,
		"guaranteedWin": guaranteedWinSpins > 0,
		"pattern23Triple": Economy.has_pattern23_triple(ownedUpgrades),
		"learningActive": book_w > 0,
		"forceAllSymbol": force_all,
		"forceTripleFrom": force_triple,
		"excludeSymbol": ("brain" if banBrainSpins > 0 else null),
		"banExcluded": banBrainSpins > 0,
		"guaranteeSymbolId": (guaranteeSymbolId if (guaranteeSymbolSpins > 0 and guaranteeSymbolId != "") else null),
		"forceReelSymbols": ({ eyeRevealReel: eyeRevealSymbol } if (eyeRevealReel >= 0 and eyeRevealSymbol != "") else null),
		"symbolToBrainCount": potion_symbol_to_brain,
		"pairScoreMult": (float(pairBoostMult) if pair_boost_active else 1.0),
		"hiddenReelCount": (pairBoostHiddenReels if pair_boost_active else 0),
		"weightOverrides": oddsWeightOverrides,
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

	var plan := Lucidity.plan_gain(lucidityCoins, int(final_result["scoreEarned"]), abilitiesUsed, seed, coins_per_power_restore)

	var was_cocktail_last: bool = cocktailBoostSpins == 1

	# Potion pool side effects (issue #32): ± lucidity and a free reroll (restore the
	# reroll ability) resolve after the score plan.
	var new_abilities: Array = plan["abilitiesUsed"]
	if potion_free_reroll:
		new_abilities = new_abilities.filter(func(a): return String(a) != "reroll")

	neurons = int(final_result["neuronsAfter"])
	scoreEarned += int(final_result["scoreEarned"])
	lucidityCoins = maxi(0, int(plan["lucidityCoins"]) + potion_lucidity_delta)
	abilitiesUsed = new_abilities
	pendingPowerRestores.append_array(plan["restores"])
	freeSpinsRemaining = int(final_result["freeSpinsAfter"])
	isFreeSpin = bool(final_result["isFreeSpin"])
	isSpinning = true
	lastResult = final_result
	lastPotionEffect = potion_pick
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
	pairBoostSpins = maxi(0, pairBoostSpins - 1)
	# Serum (issue #53): the spin AFTER the guaranteed one renders blurry — queued
	# blur moves in when the guarantee is consumed (mirrors the cocktail pattern).
	var guarantee_was_last := guaranteeSymbolSpins == 1
	guaranteeSymbolSpins = maxi(0, guaranteeSymbolSpins - 1)
	if guaranteeSymbolSpins <= 0:
		guaranteeSymbolId = ""
	blurReelsSpins = pendingBlurSpins if guarantee_was_last else maxi(0, blurReelsSpins - 1)
	pendingBlurSpins = 0 if guarantee_was_last else pendingBlurSpins
	# 3x eye (issue #53): the revealed reel was committed into this spin — consume it.
	eyeRevealReel = -1
	eyeRevealSymbol = ""
	banBrainSpins = maxi(0, banBrainSpins - 1)
	potionSpins = maxi(0, potionSpins - 1)
	# Keep the pending triple until the flatline spin is spent, then consume it.
	var flatline_was_active := forceFlatlineSpins > 0
	forceFlatlineSpins = maxi(0, forceFlatlineSpins - 1)
	guaranteedTripleSpins = guaranteedTripleSpins if flatline_was_active else maxi(0, guaranteedTripleSpins - 1)
	hideResultSpins = maxi(0, hideResultSpins - 1)

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

func reset_run_state() -> void:
	neurons = 0
	startingNeurons = 0
	scoreEarned = 0
	lucidityCoins = 0
	freeSpinsRemaining = 0
	maxFreeSpins = EconomyConst.BASE_MAX_FREE_SPINS
	lucidityMultiplier = EconomyConst.BASE_LUCIDITY_MULTIPLIER
	nextSpinLucidityMultiplier = 1.0
	isSpinning = false
	lastResult = null
	lockedReels = [false, false, false]
	lockedReelSpins = [0, 0, 0]
	runConsumables = {}
	abilitiesUsed = []
	ownedUpgrades = []
	spinCount = 0
	isFreeSpin = false
	betMultiplier = 1
	lastEffectiveBet = 1
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
	pairBoostSpins = 0
	pairBoostMult = 1
	pairBoostHiddenReels = 0
	guaranteeSymbolSpins = 0
	guaranteeSymbolId = ""
	blurReelsSpins = 0
	pendingBlurSpins = 0
	eyeRevealReel = -1
	eyeRevealSymbol = ""
	banBrainSpins = 0
	potionSpins = 0
	forceFlatlineSpins = 0
	guaranteedTripleSpins = 0
	hideResultSpins = 0
	flatlineResultCount = 0
	lastUsedConsumableId = ""
	lastPotionEffect = null
	oddsTokensRemaining = 0
	oddsWeightOverrides = {}
	oddsPendingUpgrades = {}
	oddsPhaseCompleted = false
	pendingPowerRestores = []
	runPhase = "idle"
	lastEnding = null
	wealthContinued = false
	_commit()

func start_new_run(owned_permanents: Array, pending_consumables: Dictionary, consume_campaign_neuron := true) -> bool:
	if runPhase == "running":
		return true
	if consume_campaign_neuron and not MetaStateStore.consume_campaign_neuron_for_run():
		_commit()
		return false
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
	pairBoostSpins = 0
	pairBoostMult = 1
	pairBoostHiddenReels = 0
	guaranteeSymbolSpins = 0
	guaranteeSymbolId = ""
	blurReelsSpins = 0
	pendingBlurSpins = 0
	eyeRevealReel = -1
	eyeRevealSymbol = ""
	banBrainSpins = 0
	potionSpins = 0
	forceFlatlineSpins = 0
	guaranteedTripleSpins = 0
	hideResultSpins = 0
	flatlineResultCount = 0
	lastUsedConsumableId = ""
	lastPotionEffect = null
	# Odds upgrades are permanent: every run derives its overrides from the
	# persisted levels. Unspent phase tokens were banked into meta on finalize
	# (issue #50) and carry into the next odds menu; the screen unlocks again
	# for the phase after this run.
	oddsTokensRemaining = 0
	oddsPendingUpgrades = {}
	oddsPhaseCompleted = false
	oddsWeightOverrides = _odds_overrides_from_meta()
	pendingPowerRestores = []
	runPhase = "running"
	lastEnding = null
	wealthContinued = false
	_commit()
	return true

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

# ── machine reactions (issue #35) ────────────────────────────────────────────────
# Additive effects the machine applies AFTER a spin/power result. They are NOT part
# of the parity-pinned spin()/evaluate() path, so they never shift the vectors.

## Records one 3-flatline reel outcome and returns the new running count.
func register_flatline_result() -> int:
	flatlineResultCount += 1
	_commit()
	return flatlineResultCount

## Adds free spins (clamped to maxFreeSpins). Used by the brains/vial triples.
func grant_free_spins(count: int) -> void:
	if count <= 0:
		return
	freeSpinsRemaining = mini(freeSpinsRemaining + count, maxFreeSpins)
	_commit()

## Pill triple: makes every power usable again this spin.
func restore_all_powers() -> void:
	if abilitiesUsed.is_empty():
		return
	abilitiesUsed = []
	_commit()

## 3x eye (issue #53): rolls what the tapped reel WILL show next spin — drawn from
## the run's normal weight pipeline (brain boosts, book, purchased odds all apply)
## with a fresh seed — and commits it so the next spin's evaluate() honours it.
## Returns the revealed symbol ("" outside a running, non-spinning state).
func reveal_next_reel_symbol(reel_index: int) -> String:
	if runPhase != "running" or reel_index < 0 or reel_index > 2:
		return ""
	var brain_bonus := Economy.compute_brain_weight_bonus(ownedUpgrades)
	if brainBoostSpins > 0:
		brain_bonus += int(Symbols.WEIGHT["brain"]) * 3
	var book_w := Economy.compute_book_weight(ownedUpgrades)
	var weights := _weights_with_bonuses(brain_bonus, book_w)
	var rng := LobRNG.new(_seed(spinCount * 0x85ebca6b + reel_index))
	eyeRevealReel = reel_index
	eyeRevealSymbol = String(LobRNG.weighted_pick(weights, rng))
	_commit()
	return eyeRevealSymbol

## Syringe triple: puts the last-used consumable back if a stash slot is free.
func recover_last_consumable(max_slots: int) -> bool:
	if lastUsedConsumableId == "":
		return false
	if Consumables.total_copies(runConsumables) >= max_slots:
		return false
	runConsumables = runConsumables.duplicate(true)
	runConsumables[lastUsedConsumableId] = int(runConsumables.get(lastUsedConsumableId, 0)) + 1
	_commit()
	return true

# Public: delegate to the parity-verified pure planner (run action surface).
func plan_lucidity_gain(prev_coins: int, gain: int, abilities: Array, seed: int) -> Dictionary:
	return Lucidity.plan_gain(prev_coins, gain, abilities, seed, coins_per_power_restore)

func commit_power_restore(power_id: String) -> void:
	var idx := pendingPowerRestores.find(power_id)
	if idx < 0:
		return
	pendingPowerRestores.remove_at(idx)
	_commit()

# ── abilities ──────────────────────────────────────────────────────────────────────

# Reroll draws share the spin's weight pipeline, so purchased odds (issue #36)
# apply to every draw of the run — delegating keeps the two paths identical.
func _weights_with_bonuses(brain_bonus: int, book_weight: int) -> Array:
	return Evaluate._build_weights(brain_bonus, book_weight, oddsWeightOverrides)

func _apply_outcome(outcome: Dictionary, marked_used: Array, seed: int) -> void:
	var plan := Lucidity.plan_gain(lucidityCoins, int(outcome["coinsDelta"]), marked_used, seed, coins_per_power_restore)
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

## `serum_symbol` (issue #53): the player-picked symbol for the Serum guarantee;
## ignored by every other consumable. Falls back to the first non-excluded cycle
## symbol when empty or not in the pickable pool.
func use_consumable(consumable_id: String, serum_symbol := "") -> bool:
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
	lastUsedConsumableId = consumable_id  # syringe-triple recovery target (issue #35)
	runConsumables = runConsumables.duplicate(true)
	runConsumables[consumable_id] = charges - 1

	if in_run != null:
		var e: Dictionary = in_run["effect"]
		match String(e["type"]):
			"skipDecay":
				# Energy Drink: neurons preserved for N spins; blockBet "x3" locks the
				# x3 bet for those spins (reuses the forced-random-bet demotion).
				decaySkips += int(e["spins"])
				forcedRandomBetSpins += int(e["spins"])
				if betMultiplier == 3:
					betMultiplier = 2
			"addLucidity":
				var plan := Lucidity.plan_gain(lucidityCoins, int(e["amount"]), abilitiesUsed, _seed(spinCount * 0x2545f491), coins_per_power_restore)
				lucidityCoins = int(plan["lucidityCoins"])
				abilitiesUsed = plan["abilitiesUsed"]
				pendingPowerRestores.append_array(plan["restores"])
			"cocktailBoost":
				cocktailBoostSpins += int(e["spins"])
				pendingCompulsiveSpinSkips += int(e["compulsiveSpins"])
			"forceFlatlinesThenTriple":
				# Red Pill: force flatlines for flatSpins, then a guaranteed triple.
				forceFlatlineSpins += int(e["flatSpins"])
				guaranteedTripleSpins += 1 if bool(e["guaranteedTripleNext"]) else 0
		_commit()
		return true

	var ce: Dictionary = consumable["effect"]
	match String(ce["type"]):
		"hideReelPairBoost":
			# Tobacco: hide a reel and boost pairs for N spins.
			pairBoostSpins = int(ce["spins"])
			pairBoostMult = int(ce["pairMult"])
			pairBoostHiddenReels = int(ce["hiddenReels"])
		"guaranteeSymbol":
			# Serum (issue #53): the PICKED non-excluded symbol appears at least once
			# next spin, and the spin after renders blurry.
			var excludes: Array = ce.get("excludes", [])
			var pool: Array = []
			for s in Symbols.BASE_SYMBOL_CYCLE:
				if not excludes.has(String(s)):
					pool.append(String(s))
			var picked := serum_symbol if pool.has(serum_symbol) else (String(pool[0]) if not pool.is_empty() else "")
			guaranteeSymbolSpins += int(ce["appearSpins"])
			guaranteeSymbolId = picked
			pendingBlurSpins += int(ce.get("blurSpins", 0))
		"scrambleThenHide":
			# White Powder: the scramble is the copy_reel UI flow; hide the next spin.
			hideResultSpins += 1 if bool(ce["hideNextSpin"]) else 0
		"resetPowersRandomEffect":
			# Potion: restore ALL powers now, then roll a random pool effect per spin.
			abilitiesUsed = []
			potionSpins += int(ce["spins"])
		"restoreAbilityOrSpins":
			# Tea: restore a used ability, or grant fallback free spins if none used.
			if abilitiesUsed.is_empty():
				freeSpinsRemaining = mini(freeSpinsRemaining + int(ce["fallbackSpins"]), maxFreeSpins)
			else:
				var rng := LobRNG.new(_seed(spinCount * 0xdeadbeef))
				var idx := floori(rng.next() * abilitiesUsed.size())
				var restored_id := String(abilitiesUsed[idx])
				abilitiesUsed = abilitiesUsed.duplicate()
				abilitiesUsed.remove_at(idx)
				pendingPowerRestores.append(restored_id)
	_commit()
	return true

# ── dealer odds table (issue #36) ──────────────────────────────────────────────────
# Post-run "what's next?" phase: a fresh token budget buys PERMANENT odds levels.
# Purchases are staged (undoable) while the screen is open, then committed into
# MetaStateStore.oddsUpgrades on finalize. Base weights stay parity-locked
# (see Evaluate._build_weights).

## Opens the odds phase between runs: grants the fresh token budget on top of any
## tokens banked unspent from previous menus (issue #50), and clears staged
## purchases. No-op while a run is live or once this phase was already finalized.
func begin_odds_phase() -> void:
	if runPhase == "running" or oddsPhaseCompleted:
		return
	oddsTokensRemaining = int(MetaStateStore.oddsTokensBanked) + maxi(0, odds_budget)
	oddsPendingUpgrades = {}
	_commit()

func odds_token_cost(symbol: String) -> int:
	return int(odds_token_costs.get(symbol, odds_default_token_cost))

## Persisted level + purchases staged in the currently open odds screen.
func odds_upgrade_level(symbol: String) -> int:
	return int(MetaStateStore.odds_upgrade_level(symbol)) + int(oddsPendingUpgrades.get(symbol, 0))

## Stages one permanent level for `symbol`. Only reel-cycle symbols are buyable;
## returns false when unaffordable, capped, or outside the odds phase.
func buy_odds_upgrade(symbol: String) -> bool:
	if runPhase == "running" or oddsPhaseCompleted:
		return false
	if not Symbols.BASE_SYMBOL_CYCLE.has(symbol):
		return false
	if odds_upgrade_level(symbol) >= odds_max_level:
		return false
	var cost := odds_token_cost(symbol)
	if cost <= 0 or oddsTokensRemaining < cost:
		return false
	oddsTokensRemaining -= cost
	oddsPendingUpgrades = oddsPendingUpgrades.duplicate()
	oddsPendingUpgrades[symbol] = int(oddsPendingUpgrades.get(symbol, 0)) + 1
	_commit()
	return true

## Undoes one purchase staged THIS phase (refunds its cost). Levels committed in
## previous runs can never be undone.
func undo_odds_upgrade(symbol: String) -> bool:
	if oddsPhaseCompleted:
		return false
	if int(oddsPendingUpgrades.get(symbol, 0)) <= 0:
		return false
	oddsPendingUpgrades = oddsPendingUpgrades.duplicate()
	oddsPendingUpgrades[symbol] = int(oddsPendingUpgrades[symbol]) - 1
	if int(oddsPendingUpgrades[symbol]) <= 0:
		oddsPendingUpgrades.erase(symbol)
	oddsTokensRemaining += odds_token_cost(symbol)
	_commit()
	return true

## Commits the staged purchases permanently and locks the screen until the next
## run. Unspent tokens are banked into meta so the next odds menu starts with
## them on top of its fresh budget (issue #50).
func finalize_odds_phase() -> void:
	if oddsPhaseCompleted:
		return
	if not oddsPendingUpgrades.is_empty():
		MetaStateStore.add_odds_upgrades(oddsPendingUpgrades, odds_max_level)
	MetaStateStore.set_odds_tokens_banked(oddsTokensRemaining)
	oddsPendingUpgrades = {}
	oddsTokensRemaining = 0
	oddsPhaseCompleted = true
	_commit()

## Weight overrides for a new run, derived from the persisted permanent levels.
func _odds_overrides_from_meta() -> Dictionary:
	var out: Dictionary = {}
	for symbol in Symbols.BASE_SYMBOL_CYCLE:
		var level := int(MetaStateStore.odds_upgrade_level(String(symbol)))
		if level > 0:
			out[String(symbol)] = level * probability_increase_per_upgrade
	return out

func check_dealer_trigger() -> void:
	if runPhase != "running" or dealerPending or dealerIncoming:
		return
	if startingNeurons <= 0:
		return
	if dealerCount >= dealer_max_count:
		return
	if spinCount - dealerLastSpinCount < dealer_min_spin_gap:
		return
	var decision := Dealer.evaluate_dealer_trigger({
		"neurons": neurons, "startingNeurons": startingNeurons, "spinCount": spinCount,
		"dealerCount": dealerCount, "dealerLastSpinCount": dealerLastSpinCount,
		"dealer65SafetyFired": dealer65SafetyFired, "dealer35SafetyFired": dealer35SafetyFired,
		"procSeed": _seed(spinCount * 0x9e3779b9 + 0xdeadbeef),
		"maxCount": dealer_max_count,
		"minSpinGap": dealer_min_spin_gap,
		"highThreshold": dealer_high_threshold,
		"lowThreshold": dealer_low_threshold,
		"procChance": dealer_proc_chance,
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
	accept_dealer_offer_with_limit(item_id, max_consumable_slots)

func accept_dealer_offer_with_limit(item_id: String, slot_limit: int) -> void:
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
	if Consumables.total_copies(runConsumables) >= maxi(1, slot_limit):
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
