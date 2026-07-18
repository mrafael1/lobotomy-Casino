extends Node

## Autoload singleton "RunStateStore" — run state singleton. Exposes the
## same action API; all scoring / ability / dealer / lucidity decisions delegate to
## the parity-verified pure modules (Evaluate, Abilities, Dealer, Lucidity, Economy).
## Scenes call these methods and never mutate gameplay fields directly.
##
## NOTE: this is the Milestone-2 surface (playable run loop). The pure rules it calls
## are pinned by the parity harness; the store plumbing is verified by play-testing.

signal state_changed

const M32 := 0xFFFFFFFF

## Run persistence (issue #111 follow-up): a live run and a resumable flatline
## dealer visit survive app restarts so the menu can offer CONTINUE. The whole
## run state is snapshotted on every commit (var_to_str keeps ints/bools exact,
## unlike JSON) and removed only when no resumable session remains.
const RUN_SAVE_PATH := "user://lobotomy-run.save"
const RUN_SAVE_SCHEMA_VERSION := 1

## Offer reroll pricing: first reroll of a cycle costs the base, each subsequent
## reroll adds the base again (5, 10, 15, …).
const DEALER_REROLL_BASE_COST := 5

## Issue #118: every run starts with these permanent-upgrade-gated powers already
## active, regardless of meta-shop purchases — Reroll ("Random") has always been
## unconditional; Shift now joins it as baseline starting loadout.
const STARTING_POWER_UPGRADE_IDS := ["perm_shift"]

@export_group("Run Balance")
@export var max_consumable_slots: int = Consumables.MAX_CONSUMABLE_SLOTS
@export var coins_per_power_restore: int = EconomyConst.LUCIDITY_COINS_PER_RESTORE

@export_group("Dealer Interruptions")
# Issue #76: no hard 3-per-run cap anymore — the dealer is a pressure system. Kept as a
# high sentinel so the guard still has a ceiling; the countdown paces visits, not this.
@export var dealer_max_count: int = 99
# Issue #155: dealer randomness is gone. The dealer runs on a fixed, visible countdown:
# it starts at dealer_countdown_start, every completed spin ticks it down by the
# multiplier used at spin start (x1/x2/x3 → -1/-2/-3), 0 triggers the visit, and the
# countdown resets once the offer resolves. No overflow carry (an x3 spin at 1 just
# lands the dealer). The augmented club modifier halves visits by doubling the reset.
@export var dealer_countdown_start: int = 8

# Dealer odds table (issue #36) — the post-run "what's next?" odds-buying economy.
# probability_increase_per_upgrade is @export by explicit GDD requirement.
@export_group("Dealer Odds Table")
@export var odds_budget: int = 4
## Hard ceiling on the token pool (issue #130): at most 8 tokens can be kept or
## used — banked leftovers past the cap are forfeited, and the ODD-TABLE_tokens
## art (frames 0..8) can always display the pool.
@export var odds_max_tokens: int = 8
## Per-symbol costs match the numbers baked into the ODD-TABLE art (issue #130).
@export var odds_token_costs: Dictionary = { "brain": 4, "eye": 3, "pill": 3, "syringe": 2, "vial": 2, "flatline": 1 }
@export var odds_default_token_cost: int = 2
@export var probability_increase_per_upgrade: int = 1

# ── Augmented Run (issue #111) ─────────────────────────────────────────────────────
# Post-wealth difficulty mode picked on the start menu: one suit selects a single
# modifier; the joker activates all four at once.
#   heart   (1): jackpot pays 100 instead of 200 and grants no free spin
#   spade   (2): end-of-run lucidity kept is halved (10% -> 5%)
#   diamond (3): only two powers may be used per spin
#   club    (4): dealer visits and spin rewards are halved
const AUGMENTED_TIER_MODIFIERS := { "heart": 1, "spade": 2, "diamond": 3, "club": 4 }
# Selector cycle in the authored frame order of start_menu_augmented symbols.png
# (frame index = position here): no augment, heart, diamond, spade, club, joker.
const AUGMENTED_TIER_CYCLE: Array[String] = ["", "heart", "diamond", "spade", "club", "joker"]
var augmentedTier := ""       # "" (classic) | heart | spade | diamond | club | joker
var powersUsedThisSpin := 0   # diamond modifier: hard cap of 2 power uses per spin
## Permanent odds upgrades cap out at this many levels per symbol (issue #50: 8 bars).
@export var odds_max_level: int = 8
@export_range(0.0, 2.0, 0.01) var odds_max_level_reward_bonus: float = 0.25

# RunState fields (mirror types.ts RunState)
var neurons := 0
var startingNeurons := 0
var scoreEarned := 0
var lucidityCoins := 0
var freeSpinsRemaining := 0
## Presentation event counter: unlike the banked count, this still changes when a
## free-spin grant replaces a free spin that was consumed in the same result.
var freeSpinGrantSerial := 0
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
## Issue #118: set when a power action fails safely (e.g. Random has no valid
## replacement symbol) so the UI can surface why nothing happened. Cleared on the
## next successful use of that power and on run reset.
var lastPowerFailureReason := ""
var spinCount := 0
var isFreeSpin := false
## Issue #155: no longer a player toggle — a frenzy gauge the run drives itself.
## Each paying win steps it x1 → x2 → x3. A losing spin opens a rescue window;
## declining or failing to rescue it decreases the gauge by one level. Powers that
## turn the outcome into a win after the reveal rescue the combo.
var betMultiplier := 1
var lastComboMultiplier := 1 # gauge value the last spin ran at (power-rescue base)
var comboDefeatPending := false # loss awaiting a power-rescue decision
var pendingComboMultiplier := 1 # gauge value held while the rescue window is open
var lastEffectiveBet := 1 # display only (score-burst colour); not gameplay/parity
var dealerCount := 0
var dealerLastSpinCount := 0
var dealerCountdown := 8 # issue #155: spins until the dealer (start value re-applied per run)
var dealerIncoming := false
var dealerPending := false
var dealerOfferIds: Variant = null
## Painting reroll economy: rerolling an offer costs Lucidity, starting at
## DEALER_REROLL_BASE_COST and climbing by the same step each reroll (5, 10, 15…).
## The counter spans one dealer/run cycle: it resets when a fresh pre-run shop
## offer rolls and again when a new run starts. Pre-run rerolls charge the wallet
## (MetaStateStore); in-run rerolls charge the run's lucidityCoins.
var dealerRerollCount := 0
## Pre-run shop offer pair (max two consumables per visit). Rolled lazily on the
## first dealer-scene visit of a cycle and kept across lab round-trips; cleared
## when a run starts so the next pre-run phase rolls fresh.
var prerunOfferIds: Variant = null
## Chip Augments: one dedicated dealer offer per visit, separate from the normal
## items/consumables and untouched by the painting reroll. Purchased bonuses last
## one dealer/run cycle (pre-run purchases carry into the run); everything clears
## when the next cycle's pre-run offer rolls or on a full reset. All fields have
## safe defaults, so older saves/sessions simply start with no augments.
var chipAugmentsPurchased := {}       # augment id -> copies bought this cycle
var dealerAugmentOfferId := ""        # current visit's dedicated offer ("" = none)
var symbolAugmentLevels := {}         # symbol -> +levels bought via aug_symbol_level
var pairTripleAugmentChoice := ""     # "" | "pair" | "triple" (locked once chosen)
var brainBoostSpins := 0
var forcedRandomBetSpins := 0
var guaranteedWinSpins := 0
var blockPowersSpins := 0
var hideNeuronsSpins := 0
var cocktailBoostSpins := 0
var cocktailPairTriplePenalty := 0.0
var compulsiveSpinSkips := 0
var pendingCompulsiveSpinSkips := 0
var decaySkips := 0
# Consumable roster effects (issue #32).
var pairBoostSpins := 0          # Tobacco: hidden reel + pair multiplier active
var pairBoostMult := 1           # Tobacco: pair payout multiplier while active
var pairBoostHiddenReels := 0    # Tobacco: reels hidden from scoring while active
var guaranteeSymbolSpins := 0    # Serum: force the picked symbol to appear
var guaranteeSymbolId := ""      # Serum: the player-picked symbol (issue #53)
var blurReelsSpins := 0          # Serum: adjacent strip symbols hide for these spins
var pendingBlurSpins := 0        # Serum: adjacent hiding queued after the guarantee
var banBrainSpins := 0           # Serum (legacy): brain banned from the reels
var potionSpins := 0             # Potion: one random pool effect per spin
var forceFlatlineSpins := 0      # Pill: force an all-flatline spin
var guaranteedTripleSpins := 0   # Pill: force a triple the spin after the flatline
var hideResultSpins := 0         # White Powder: hide the next spin's result

const NON_FLATLINE_SYMBOLS := ["brain", "eye", "pill", "syringe", "vial"]
const COCKTAIL_RARITY_POINTS := {
	"flatline": 1, "vial": 2, "syringe": 3, "pill": 4, "eye": 5, "brain": 6, "book": 6,
}

# Machine-reaction state (issue #35). Additive run-flow fields updated by the
# machine's post-reveal reactions AFTER the parity-pinned spin()/power results —
# they never feed evaluate()/spin(), so the pinned vectors stay untouched.
var flatlineResultCount := 0    # count of 3-flatline reel outcomes seen this run
var flatlineWinBoostArmed := false  # issue #76: a flatline strike charges the next winning pair/triple
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
var symbolRewardBonuses: Dictionary = {}
var oddsPendingUpgrades: Dictionary = {}  # staged this phase; undoable until finalized
var oddsPhaseCompleted := false           # closed screens stay closed until the next run

# RunStore extras
var runPhase := "idle" # idle | pre_run | running | over
var lastEnding: Variant = null
var wealthContinued := false
var campaignNeuronPending := false # consumed when the machine run ends
var pendingPowerRestores: Array = []

func _forced_eye_reveal_symbols() -> Variant:
	if eyeRevealReel < 0 or eyeRevealReel > 2 or eyeRevealSymbol == "":
		return null
	if bool(lockedReels[eyeRevealReel]):
		return null
	return { eyeRevealReel: eyeRevealSymbol }

static func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)

func _seed(mix: int) -> int:
	return (_now_ms() ^ mix) & M32

func _can_act() -> bool:
	return _can_use_consumable() and not comboDefeatPending

## Consumables stay usable while a combo defeat is pending: the losing state is a
## rescue window, and a corrective item is a legitimate way out of it.
func _can_use_consumable() -> bool:
	return runPhase == "running" and not isSpinning and compulsiveSpinSkips <= 0

func _can_use_ability() -> bool:
	return runPhase == "running" and not isSpinning and lastResult != null \
		and compulsiveSpinSkips <= 0 and blockPowersSpins <= 0 \
		and not _augmented_powers_blocked()

## Powers that can alter the already-revealed reels are the only valid combo-rescue
## choices. Memory affects a future spin and therefore is intentionally not offered
## while the current defeat is pending.
func pending_combo_power_ids() -> Array[String]:
	var ids: Array[String] = []
	if not comboDefeatPending or not _can_use_ability():
		return ids
	if not abilitiesUsed.has("reroll") \
			and not pendingPowerRestores.has("reroll"):
		ids.append("reroll")
	if ownedUpgrades.has("perm_shift") and not abilitiesUsed.has("shift") \
			and not pendingPowerRestores.has("shift"):
		ids.append("shift")
	return ids

## True while the Energy Drink owns the gauge: the protected spins, then the
## queued/active forced spin. The drink pins the multiplier to its forced x2 for
## that whole window — combo losses can't drop it below x2 and wins can't push
## it to x3 until the forced spin has fully resolved.
func energy_drink_owns_multiplier() -> bool:
	return decaySkips > 0 or forcedRandomBetSpins > 0 \
		or pendingCompulsiveSpinSkips > 0 or compulsiveSpinSkips > 0

## Resolves a pending defeat without touching the scored result. A successful power
## action normally resolves the flag through _apply_outcome(); this method handles
## the player's explicit spin confirmation.
func resolve_pending_combo_defeat(rescued: bool = false) -> bool:
	if not comboDefeatPending:
		return false
	var base := clampi(pendingComboMultiplier, 1, 3)
	betMultiplier = mini(3, base + 1) if rescued else maxi(1, base - 1)
	if energy_drink_owns_multiplier():
		betMultiplier = 2
	comboDefeatPending = false
	pendingComboMultiplier = 1
	_commit()
	return true

## Whether a numbered Augmented modifier applies to this run (joker = all four).
func augmented_modifier_active(modifier: int) -> bool:
	if augmentedTier == "joker":
		return true
	return int(AUGMENTED_TIER_MODIFIERS.get(augmentedTier, 0)) == modifier

## Diamond modifier: the third power use of a spin is locked by the game.
func _augmented_powers_blocked() -> bool:
	return augmented_modifier_active(3) and powersUsedThisSpin >= 2

## Heart modifier: how much of a jackpot's evaluated score is cut (200 -> 100 at
## base; halving the whole score keeps reward bonuses/scales proportional).
func _augmented_jackpot_cut(score: int, win_type: String) -> int:
	if not augmented_modifier_active(1) or win_type != "jackpot":
		return 0
	return score - roundi(float(score) * 0.5)

## Applies Heart to the complete post-evaluate score, including any Flatline or
## specialist bonuses that were added after the base evaluation.
func _apply_augmented_jackpot(score: int, win_type: String) -> Dictionary:
	var cut := _augmented_jackpot_cut(score, win_type)
	return {
		"score": maxi(0, score - cut),
		"cut": cut,
	}

func _ready() -> void:
	load_run_state()

func _commit() -> void:
	state_changed.emit()
	_save_run_state()

# ── run persistence ──────────────────────────────────────────────────────────────

## Every non-exported script variable of the store IS the run state; exports are
## balance tunables and stay out of the save.
func _run_state_properties() -> Array[String]:
	var names: Array[String] = []
	for p in get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 \
				and (int(p["usage"]) & PROPERTY_USAGE_EDITOR) == 0:
			names.append(String(p["name"]))
	return names

func _save_run_state() -> void:
	if Engine.is_editor_hint():
		return
	if not has_resume_state():
		# No live or resumable post-run session: a stale file must not offer CONTINUE.
		if FileAccess.file_exists(RUN_SAVE_PATH):
			DirAccess.remove_absolute(RUN_SAVE_PATH)
		return
	var out := { "schemaVersion": RUN_SAVE_SCHEMA_VERSION }
	for prop in _run_state_properties():
		out[prop] = get(prop)
	var f := FileAccess.open(RUN_SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(var_to_str(out))

## Restores a live run snapshot, if one exists. Unknown keys (removed fields)
## are skipped; missing keys (new fields) keep their reset defaults.
func load_run_state() -> void:
	if Engine.is_editor_hint() or not FileAccess.file_exists(RUN_SAVE_PATH):
		return
	var f := FileAccess.open(RUN_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = str_to_var(f.get_as_text())
	if not (data is Dictionary):
		return
	var saved := data as Dictionary
	var saved_phase := String(saved.get("runPhase", ""))
	var saved_flatline := saved_phase == "over" \
		and str(saved.get("lastEnding", "")) == "flatline" \
		and int(MetaStateStore.campaignNeuronsLeft) > 0
	if saved_phase != "running" and saved_phase != "pre_run" and not saved_flatline:
		DirAccess.remove_absolute(RUN_SAVE_PATH)
		return
	for prop in _run_state_properties():
		if saved.has(prop):
			set(prop, saved[prop])
	_commit()

# ── spin ──────────────────────────────────────────────────────────────────────────

func spin(compulsive := false) -> Variant:
	if runPhase != "running" or isSpinning:
		return null
	# The gameplay scene normally resolves this through the pending UI. A direct
	# caller that requests another spin has implicitly declined the rescue instead
	# of leaving the store permanently locked.
	if comboDefeatPending:
		resolve_pending_combo_defeat(false)
	var is_compulsive: bool = compulsive and compulsiveSpinSkips > 0
	if not is_compulsive and compulsiveSpinSkips > 0:
		return null
	var is_free: bool = (not is_compulsive) and freeSpinsRemaining > 0
	if (not is_free) and neurons < 1:
		return null

	var seed := _seed(spinCount * 0x9e3779b9)
	var rng := LobRNG.new(seed)

	var stasis: bool = (not is_compulsive) and (not is_free) and decaySkips > 0
	var sedative: bool = (not is_compulsive) and (not is_free) and Economy.has_sedative(ownedUpgrades) and (spinCount + 1) % 3 == 0

	# Issue #155: the gauge value this spin runs at. The multiplier no longer costs
	# extra neurons or free spins — its downside is the dealer countdown ticking
	# faster (x2/x3 pull the dealer in 2x/3x as fast).
	var combo_before := clampi(betMultiplier, 1, 3)
	# The Energy-Drink forced spin is NOT dropped to x1 — it runs the drink's
	# forced x2 like the protected spins before it.
	var eff_bet := combo_before
	if (forcedRandomBetSpins > 0 or is_compulsive) and eff_bet == 3:
		eff_bet = 2 # Energy Drink dulls the frenzy: x3 runs as x2 for its duration

	var base_decay := Economy.compute_neuron_decay(ownedUpgrades)
	var decay_amt := 0 if (stasis or sedative or is_free) else mini(base_decay, neurons)

	var brain_bonus := Economy.compute_brain_weight_bonus(ownedUpgrades)
	if brainBoostSpins > 0:
		brain_bonus += int(Symbols.WEIGHT["brain"]) * 3

	var base_mult := lucidityMultiplier * nextSpinLucidityMultiplier * eff_bet
	var eff_mult: float = base_mult * 0.5 if brainBoostSpins > 0 else base_mult

	# Potion (issue #32): roll one equal-weight pool effect for this spin, with a
	# dedicated seed so the pick is independent of the reel roll.
	var potion_lucidity_delta := 0
	var potion_symbol_to_brain := 0
	var potion_free_reroll := false
	var potion_restore_spins := 0
	var potion_restore_power := false
	var potion_adjacent_symbols := 0
	var potion_pick: Variant = null
	if potionSpins > 0:
		var p_rng := LobRNG.new((seed ^ 0x50710000) & M32)
		var pool: Array = Consumables.POTION_RANDOM_POOL
		var pick: Dictionary = pool[int(p_rng.next() * pool.size())]
		if String(pick["kind"]) == "restorePower" and abilitiesUsed.is_empty():
			var fallback_pool: Array = []
			for candidate in pool:
				if String(candidate["kind"]) != "restorePower":
					fallback_pool.append(candidate)
			if not fallback_pool.is_empty():
				pick = fallback_pool[int(p_rng.next() * fallback_pool.size())]
		potion_pick = pick
		match String(pick["kind"]):
			"lucidity": potion_lucidity_delta = int(pick["amount"])
			"symbolToBrain": potion_symbol_to_brain = 1
			"freeReroll": potion_free_reroll = true
			"restoreSpin": potion_restore_spins = int(pick.get("count", 1))
			"restorePower": potion_restore_power = true
			"adjacentSymbol": potion_adjacent_symbols = int(pick.get("count", 1))

	# Consumable reel transforms (issue #32). Pill forces a flatline spin, then a
	# guaranteed non-flatline triple the spin after; Serum bans/guarantees a symbol.
	var force_all: Variant = "flatline" if forceFlatlineSpins > 0 else null
	var force_triple: Variant = NON_FLATLINE_SYMBOLS if (forceFlatlineSpins <= 0 and guaranteedTripleSpins > 0) else null
	var pair_boost_active := pairBoostSpins > 0
	var hallucination_active := Economy.has_hallucination(ownedUpgrades)
	var hidden_reel_count := _active_hidden_reel_count(pair_boost_active)

	var book_w := Economy.compute_book_weight(ownedUpgrades)
	var result := Evaluate.evaluate({
		"neurons": neurons,
		"neuronDecayAmount": decay_amt,
		"freeSpinsRemaining": freeSpinsRemaining,
		"maxFreeSpins": maxFreeSpins,
		"lucidityMultiplier": eff_mult,
		"isFreeSpin": is_free,
		"freeSpinCost": 1, # issue #155: the auto gauge never drains banked free spins faster
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
		"forceReelSymbols": _forced_eye_reveal_symbols(),
		"symbolToBrainCount": potion_symbol_to_brain,
		"adjacentSymbolCount": potion_adjacent_symbols,
		"pairScoreMult": (float(pairBoostMult) if pair_boost_active else 1.0),
		"hiddenReelCount": hidden_reel_count,
		"visiblePairAsTriple": hallucination_active,
		"rewardScale": _active_reward_scale(),
		"symbolRewardBonuses": symbolRewardBonuses,
		"weightOverrides": oddsWeightOverrides,
	})

	var cocktail_bonus := 0
	var cocktail_penalty := 0
	if cocktailBoostSpins > 0:
		var rarity_total := 0
		var visible_count := maxi(1, (result["reels"] as Array).size() - hidden_reel_count)
		for i in visible_count:
			rarity_total += int(COCKTAIL_RARITY_POINTS.get(String((result["reels"] as Array)[i]), 0))
		cocktail_bonus = floori(float(rarity_total) * float(result["scoreMultiplier"]) + 0.5)
		if String(result["winType"]) in ["pair", "triple"] and cocktailPairTriplePenalty > 0.0:
			cocktail_penalty = floori(float(result["scoreEarned"]) * cocktailPairTriplePenalty + 0.5)
	# Issue #76: a charged flatline strike multiplies the next winning pair/triple. The
	# bonus rides on top of the pinned score (evaluate() untouched, like cocktail above)
	# so it flows through the lucidity plan; requiring base_score > 0 means misses and
	# 0-score flatline wins never spend the charge — it waits for a real win.
	var base_score := maxi(0, int(result["scoreEarned"]) + cocktail_bonus - cocktail_penalty)
	var flatline_boost := 0
	var flatline_boost_applied := false
	if flatlineWinBoostArmed and base_score > 0 \
			and String(result["winType"]) in ["pair", "triple", "jackpot"]:
		flatline_boost = base_score * (EconomyConst.FLATLINE_WIN_BOOST_MULT - 1)
		flatline_boost_applied = true
	# Pair/Triple Specialist (Chip Augment): the chosen win type pays x1.25. Rides on
	# top of the pinned score like the cocktail/flatline boosts (evaluate() untouched).
	var specialist_bonus := ChipAugments.specialist_bonus(
		base_score, String(result["winType"]), pairTripleAugmentChoice)
	# Augmented heart modifier (issue #111): the brain jackpot pays 100 instead of
	# 200 and no longer grants its free spin. Apply it after the other score boosts
	# so the whole jackpot payout remains proportional.
	var complete_score := base_score + flatline_boost + specialist_bonus
	var augmented_jackpot: Dictionary = _apply_augmented_jackpot(
		complete_score, String(result["winType"]))
	var final_score := int(augmented_jackpot["score"])
	var augmented_jackpot_cut := int(augmented_jackpot["cut"])
	var final_result: Dictionary = result
	if cocktail_bonus > 0 or cocktail_penalty > 0 or flatline_boost_applied \
			or specialist_bonus > 0 or hidden_reel_count > 0 or augmented_jackpot_cut > 0:
		final_result = result.duplicate(true)
		final_result["scoreEarned"] = final_score
		final_result["coinsEarned"] = final_score
		if hidden_reel_count > 0:
			final_result["hiddenReelCount"] = hidden_reel_count
		if cocktail_bonus > 0:
			final_result["cocktailApplied"] = true
			final_result["cocktailBonus"] = cocktail_bonus
		if cocktail_penalty > 0:
			final_result["cocktailPenalty"] = cocktail_penalty
		if flatline_boost_applied:
			final_result["flatlineBoostApplied"] = true
			final_result["flatlineBoostBonus"] = flatline_boost
		if specialist_bonus > 0:
			final_result["specialistBonus"] = specialist_bonus
		if augmented_jackpot_cut > 0:
			# Evaluate only adds freeSpinsGranted on non-free spins; undo exactly that.
			if not bool(final_result["isFreeSpin"]):
				final_result["freeSpinsAfter"] = maxi(0,
					int(final_result["freeSpinsAfter"]) - int(final_result["freeSpinsGranted"]))
			final_result["freeSpinsGranted"] = 0
			final_result["augmentedJackpotCut"] = augmented_jackpot_cut

	var plan := Lucidity.plan_gain(lucidityCoins, int(final_result["scoreEarned"]), abilitiesUsed, seed, coins_per_power_restore)

	var was_energy_last: bool = stasis and decaySkips == 1

	# Potion pool side effects (issue #32): ± lucidity and a free reroll (restore the
	# reroll ability) resolve after the score plan.
	var new_abilities: Array = plan["abilitiesUsed"]
	if potion_free_reroll:
		new_abilities = new_abilities.filter(func(a): return String(a) != "reroll")
	var potion_restored_power := ""
	if potion_restore_power and not new_abilities.is_empty():
		var restore_rng := LobRNG.new((seed ^ 0x7600babe) & M32)
		var restore_idx := mini(new_abilities.size() - 1, floori(restore_rng.next() * new_abilities.size()))
		potion_restored_power = String(new_abilities[restore_idx])
		new_abilities = new_abilities.duplicate()
		new_abilities.remove_at(restore_idx)

	neurons = int(final_result["neuronsAfter"])
	if potion_restore_spins > 0:
		neurons += potion_restore_spins * maxi(1, base_decay)
	scoreEarned += int(final_result["scoreEarned"])
	lucidityCoins = maxi(0, int(plan["lucidityCoins"]) + potion_lucidity_delta)
	abilitiesUsed = new_abilities
	pendingPowerRestores.append_array(plan["restores"])
	if potion_restored_power != "":
		pendingPowerRestores.append(potion_restored_power)
	# Compulsive spins don't consume banked free spins, but the parity-pinned
	# evaluate() clamps freeSpinsAfter to maxFreeSpins on non-free spins — which
	# would wipe banked vial/tea rewards (issue #66). Keep what the player had.
	freeSpinsRemaining = maxi(int(final_result["freeSpinsAfter"]), freeSpinsRemaining) \
		if is_compulsive else int(final_result["freeSpinsAfter"])
	isFreeSpin = bool(final_result["isFreeSpin"])
	isSpinning = true
	lastResult = final_result
	if int(final_result.get("freeSpinsGranted", 0)) > 0:
		freeSpinGrantSerial += 1
	lastPotionEffect = potion_pick
	lastEffectiveBet = clampi(eff_bet, 1, 3)
	# Issue #155 frenzy gauge: a paying win steps the multiplier up. A defeat keeps
	# the pre-spin value visible until the machine's pending rescue state resolves.
	# The Energy-Drink forced spin drives the gauge like any normal spin — it keeps
	# the current combo and can lose it (no machine-forced x1).
	lastComboMultiplier = combo_before
	if _is_winning_result(final_result):
		betMultiplier = _combo_after(combo_before, final_result)
		if energy_drink_owns_multiplier():
			betMultiplier = 2 # the drink still owns the gauge — no x3 until it ends
		comboDefeatPending = false
		pendingComboMultiplier = 1
	else:
		comboDefeatPending = true
		pendingComboMultiplier = combo_before
		betMultiplier = combo_before
	# Issue #155 dealer countdown: every completed spin ticks it by the multiplier
	# actually used this spin. No overflow carry — it just floors at 0.
	dealerCountdown = maxi(0, dealerCountdown - clampi(eff_bet, 1, 3))
	spinCount += 1
	powersUsedThisSpin = 0 # diamond modifier counts power uses per spin
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
		+ (pendingCompulsiveSpinSkips if was_energy_last else 0)
	pendingCompulsiveSpinSkips = 0 if was_energy_last else pendingCompulsiveSpinSkips
	pairBoostSpins = maxi(0, pairBoostSpins - 1)
	# Serum (issue #53): the spin AFTER the guaranteed one renders blurry — queued
	# blur moves in when the guarantee is consumed.
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
	# Issue #76: the charge is spent only when a win actually consumed it above.
	if flatline_boost_applied:
		flatlineWinBoostArmed = false

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

## Issue #155: a result is a combo-sustaining win only when it actually pays —
## flatline pairs/triples come back as winType "pair"/"triple" with 0 score and
## must break the frenzy like any miss.
func _is_winning_result(result: Dictionary) -> bool:
	return String(result["winType"]) in ["pair", "triple", "jackpot"] \
		and int(result["scoreEarned"]) > 0

func _combo_after(prev: int, result: Dictionary) -> int:
	return mini(3, prev + 1) if _is_winning_result(result) else maxi(1, prev - 1)

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
	lastPowerFailureReason = ""
	spinCount = 0
	isFreeSpin = false
	betMultiplier = 1
	lastComboMultiplier = 1
	comboDefeatPending = false
	pendingComboMultiplier = 1
	lastEffectiveBet = 1
	dealerCount = 0
	dealerLastSpinCount = 0
	dealerCountdown = dealer_countdown_start
	dealerIncoming = false
	dealerPending = false
	dealerOfferIds = null
	dealerRerollCount = 0
	prerunOfferIds = null
	chipAugmentsPurchased = {}
	dealerAugmentOfferId = ""
	symbolAugmentLevels = {}
	pairTripleAugmentChoice = ""
	brainBoostSpins = 0
	forcedRandomBetSpins = 0
	guaranteedWinSpins = 0
	blockPowersSpins = 0
	hideNeuronsSpins = 0
	cocktailBoostSpins = 0
	cocktailPairTriplePenalty = 0.0
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
	flatlineWinBoostArmed = false
	lastUsedConsumableId = ""
	lastPotionEffect = null
	oddsTokensRemaining = 0
	oddsWeightOverrides = {}
	symbolRewardBonuses = {}
	oddsPendingUpgrades = {}
	oddsPhaseCompleted = false
	pendingPowerRestores = []
	runPhase = "idle"
	lastEnding = null
	wealthContinued = false
	campaignNeuronPending = false
	augmentedTier = ""
	powersUsedThisSpin = 0
	_commit()

## Marks the pre-run dealer shop as a resumable session without spending a
## campaign neuron. The dealer spends that neuron only when START is confirmed.
func begin_pre_run() -> void:
	if runPhase == "running":
		return
	runPhase = "pre_run"
	lastEnding = null
	campaignNeuronPending = false
	_commit()

func has_resume_state() -> bool:
	if runPhase == "pre_run" or runPhase == "running":
		return true
	# A flatline remains a resumable post-run dealer visit until the player
	# starts a fresh run or gives up. Wealth exits go straight to the menu.
	return runPhase == "over" and str(lastEnding) == "flatline" \
		and int(MetaStateStore.campaignNeuronsLeft) > 0

func start_new_run(owned_permanents: Array, pending_consumables: Dictionary, consume_campaign_neuron := true) -> bool:
	if runPhase == "running":
		return true
	if consume_campaign_neuron:
		if not MetaStateStore.reserve_campaign_neuron_for_run():
			_commit()
			return false
	campaignNeuronPending = consume_campaign_neuron
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
	# augmentedTier survives: the menu sets it before the pre-run dealer shop, and
	# it applies to the run this call starts (issue #111).
	powersUsedThisSpin = 0
	ownedUpgrades = owned_permanents.duplicate()
	# Issue #118: Shift joins Reroll ("Random") as an unconditional starting power —
	# grant it every run regardless of meta-shop purchases, consistently across
	# fresh runs, restarts, and save/load (this is the single choke point all three
	# paths route through).
	for starting_id in STARTING_POWER_UPGRADE_IDS:
		if not ownedUpgrades.has(starting_id):
			ownedUpgrades.append(starting_id)
	lastPowerFailureReason = ""
	spinCount = 0
	isFreeSpin = false
	betMultiplier = 1
	lastComboMultiplier = 1
	comboDefeatPending = false
	pendingComboMultiplier = 1
	dealerCount = 0
	dealerLastSpinCount = 0
	dealerCountdown = dealer_countdown_reset_value() # augmentedTier already set (issue #111)
	dealerIncoming = false
	dealerPending = false
	dealerOfferIds = null
	dealerRerollCount = 0
	prerunOfferIds = null # new run => the next pre-run shop rolls a fresh offer
	dealerAugmentOfferId = "" # the shop's augment offer closes with the shop
	# chipAugmentsPurchased / symbolAugmentLevels / pairTripleAugmentChoice survive:
	# pre-run purchases are FOR this run; the overlay below applies them.
	brainBoostSpins = 0
	forcedRandomBetSpins = 0
	guaranteedWinSpins = 0
	blockPowersSpins = 0
	hideNeuronsSpins = 0
	cocktailBoostSpins = 0
	cocktailPairTriplePenalty = 0.0
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
	flatlineWinBoostArmed = false
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
	symbolRewardBonuses = _symbol_reward_bonuses_from_meta(owned_permanents)
	_apply_chip_augment_run_overlay()
	pendingPowerRestores = []
	runPhase = "running"
	lastEnding = null
	wealthContinued = false
	_commit()
	return true

func end_run(ending: String) -> void:
	runPhase = "over"
	lastEnding = ending
	if ending == "game_over":
		# A terminal campaign loss removes the run's remaining credits instead of
		# carrying the normal flatline retention into the next campaign.
		lucidityCoins = 0
	if campaignNeuronPending:
		MetaStateStore.finalize_campaign_neuron_for_run()
		campaignNeuronPending = false
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

## Records one 3-flatline reel outcome and returns the new running count. Also charges
## the next winning pair/triple (issue #76) — a fatal strike ends the run, so the charge
## only matters on the non-fatal strikes that leave the player still spinning.
func register_flatline_result() -> int:
	flatlineResultCount += 1
	flatlineWinBoostArmed = true
	_commit()
	return flatlineResultCount

## Adds real free-spin credits. Used by brain triples when the pure spin result
## did not already grant one.
func grant_free_spins(count: int) -> void:
	if count <= 0:
		return
	freeSpinsRemaining += count
	freeSpinGrantSerial += 1
	_commit()

## Restores normal spins-left budget by replenishing neurons.
func restore_spins(count: int) -> void:
	if count <= 0:
		return
	var decay := maxi(1, Economy.compute_neuron_decay(ownedUpgrades))
	neurons += count * decay
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

## Bar-driven restore (issue #76 follow-up): when the power gauge fills and no plan_gain
## restore is queued, it restores one spent ability directly — random pick removed from
## abilitiesUsed so its button re-enables. Same selection shape as Lucidity.plan_gain.
## Returns the restored id ("" if nothing is spent).
func bar_restore_power(seed: int) -> String:
	if abilitiesUsed.is_empty():
		return ""
	var rng := LobRNG.new(seed & M32)
	var idx := mini(abilitiesUsed.size() - 1, floori(rng.next() * abilitiesUsed.size()))
	var id := String(abilitiesUsed[idx])
	abilitiesUsed = abilitiesUsed.duplicate()
	abilitiesUsed.remove_at(idx)
	_commit()
	return id

# ── abilities ──────────────────────────────────────────────────────────────────────

# Reroll draws share the spin's weight pipeline, so purchased odds (issue #36)
# apply to every draw of the run — delegating keeps the two paths identical.
func _weights_with_bonuses(brain_bonus: int, book_weight: int) -> Array:
	return Evaluate._build_weights(brain_bonus, book_weight, oddsWeightOverrides)

func _active_hidden_reel_count(pair_boost_active: bool) -> int:
	var hidden := pairBoostHiddenReels if pair_boost_active else 0
	if Economy.has_hallucination(ownedUpgrades):
		hidden = maxi(hidden, 1)
	return clampi(hidden, 0, 2)

func _active_reward_scale() -> float:
	var scale := Economy.compute_hallucination_reward_scale(ownedUpgrades)
	# Augmented club modifier (issue #111): all spin rewards/gains are halved.
	if augmented_modifier_active(4):
		scale *= 0.5
	return scale

func _apply_outcome(outcome: Dictionary, marked_used: Array, seed: int) -> void:
	var plan := Lucidity.plan_gain(lucidityCoins, int(outcome["coinsDelta"]), marked_used, seed, coins_per_power_restore)
	# The cap only tops up, it never cuts: banked spins above maxFreeSpins
	# (vial/tea rewards, issue #66) survive power use.
	var free_after := mini(freeSpinsRemaining + int(outcome["freeSpinsGranted"]),
		maxi(freeSpinsRemaining, maxFreeSpins))
	abilitiesUsed = plan["abilitiesUsed"]
	scoreEarned = maxi(0, scoreEarned + int(outcome["scoreDelta"]))
	lucidityCoins = int(plan["lucidityCoins"])
	pendingPowerRestores.append_array(plan["restores"])
	var lr: Dictionary = (lastResult as Dictionary).duplicate(true)
	lr["reels"] = outcome["reels"]
	lr["isJackpot"] = outcome["isJackpot"]
	lr["winType"] = outcome["winType"]
	var hidden_reel_count := _active_hidden_reel_count(pairBoostSpins > 0)
	if hidden_reel_count > 0:
		lr["hiddenReelCount"] = hidden_reel_count
	else:
		lr.erase("hiddenReelCount")
	if outcome.has("resolvedSymbol"):
		lr["resolvedSymbol"] = String(outcome["resolvedSymbol"])
	else:
		lr.erase("resolvedSymbol")
	if outcome.has("bookJoker"):
		lr["bookJoker"] = bool(outcome["bookJoker"])
	else:
		lr.erase("bookJoker")
	if outcome.has("bookTripleChoice"):
		lr["bookTripleChoice"] = bool(outcome["bookTripleChoice"])
	else:
		lr.erase("bookTripleChoice")
	lr["scoreEarned"] = maxi(0, int(lastResult["scoreEarned"]) + int(outcome["scoreDelta"]))
	lr["coinsEarned"] = maxi(0, int(lastResult["coinsEarned"]) + int(outcome["coinsDelta"]))
	lr["freeSpinsGranted"] = int(lastResult["freeSpinsGranted"]) + (free_after - freeSpinsRemaining)
	lr["freeSpinsAfter"] = free_after
	freeSpinsRemaining = free_after
	if int(outcome.get("freeSpinsGranted", 0)) > 0:
		freeSpinGrantSerial += 1
	lastResult = lr
	# Issue #155: powers can rescue the frenzy by turning the pending reveal into a
	# paying pair/triple. A non-paying power result keeps the rescue window open so
	# the next spin, rather than the failed power, confirms the one-level loss.
	var combo_base := pendingComboMultiplier if comboDefeatPending else lastComboMultiplier
	if comboDefeatPending and not _is_winning_result(lr):
		betMultiplier = combo_base
		pendingComboMultiplier = combo_base
	else:
		betMultiplier = _combo_after(combo_base, lr)
		if energy_drink_owns_multiplier():
			betMultiplier = 2 # the drink still owns the gauge — no x3 until it ends
		comboDefeatPending = false
		pendingComboMultiplier = 1

func reroll_reel(reel_index: int) -> bool:
	if not _can_use_ability() or lastResult == null:
		return false
	if abilitiesUsed.has("reroll"):
		return false
	var brain_bonus := Economy.compute_brain_weight_bonus(ownedUpgrades)
	if brainBoostSpins > 0:
		brain_bonus += int(Symbols.WEIGHT["brain"]) * 4
	var book_w := Economy.compute_book_weight(ownedUpgrades)
	var weights := _weights_with_bonuses(brain_bonus, book_w)
	# Issue #118: Random must always change the targeted reel — exclude the symbol
	# currently occupying it from the candidate pool before drawing, so it can
	# never redraw a no-op. If nothing else is left to draw (e.g. every weighted
	# symbol collapsed onto the current one), fail safely without consuming the
	# power's charge or seed, and record why for the UI to surface.
	var current_symbol := String(lastResult["reels"][reel_index])
	var candidates := Abilities.random_candidate_weights(weights, current_symbol)
	if candidates.is_empty():
		lastPowerFailureReason = "Random has no other symbol to draw into this reel."
		_commit()
		return false
	lastPowerFailureReason = ""
	var seed := _seed(spinCount * 0x5bd1e995 + reel_index)
	var rng := LobRNG.new(seed)
	var pair_boost_active := pairBoostSpins > 0
	var hidden_reel_count := _active_hidden_reel_count(pair_boost_active)
	var outcome := Abilities.apply_reroll(lastResult["reels"], reel_index, rng, float(lastResult["scoreMultiplier"]),
		candidates, Economy.has_pattern23_triple(ownedUpgrades), book_w > 0, not bool(lastResult["isFreeSpin"]),
		(float(pairBoostMult) if pair_boost_active else 1.0),
		hidden_reel_count, Economy.has_hallucination(ownedUpgrades), _active_reward_scale(),
		symbolRewardBonuses)
	var marked := abilitiesUsed.duplicate()
	marked.append("reroll")
	powersUsedThisSpin += 1
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
	var pair_boost_active := pairBoostSpins > 0
	var hidden_reel_count := _active_hidden_reel_count(pair_boost_active)
	var outcome := Abilities.apply_move_column(lastResult["reels"], reel_index, direction, float(lastResult["scoreMultiplier"]),
		Economy.has_pattern23_triple(ownedUpgrades), book_w > 0, not bool(lastResult["isFreeSpin"]),
		(float(pairBoostMult) if pair_boost_active else 1.0),
		hidden_reel_count, Economy.has_hallucination(ownedUpgrades), _active_reward_scale(),
		symbolRewardBonuses)
	var seed := _seed(spinCount * 0x27d4eb2f + reel_index)
	var marked := abilitiesUsed.duplicate()
	marked.append("shift")
	powersUsedThisSpin += 1
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
	if eyeRevealReel == reel_index:
		eyeRevealReel = -1
		eyeRevealSymbol = ""
	abilitiesUsed = abilitiesUsed.duplicate()
	abilitiesUsed.append("memory")
	powersUsedThisSpin += 1
	_commit()

func copy_reel(source_reel: int, target_reel: int) -> bool:
	if not _can_use_ability() or lastResult == null:
		return false
	if _augmented_powers_blocked():
		return false
	var book_w := Economy.compute_book_weight(ownedUpgrades)
	var pair_boost_active := pairBoostSpins > 0
	var hidden_reel_count := _active_hidden_reel_count(pair_boost_active)
	var outcome := Abilities.apply_copy_reel(lastResult["reels"], source_reel, target_reel, float(lastResult["scoreMultiplier"]),
		Economy.has_pattern23_triple(ownedUpgrades), book_w > 0, not bool(lastResult["isFreeSpin"]),
		(float(pairBoostMult) if pair_boost_active else 1.0),
		hidden_reel_count, Economy.has_hallucination(ownedUpgrades), _active_reward_scale(),
		symbolRewardBonuses)

	var seed := _seed(spinCount * 0x165667b1)
	powersUsedThisSpin += 1
	_apply_outcome(outcome, abilitiesUsed.duplicate(), seed)
	_commit()
	return true

# ── consumables / dealer ───────────────────────────────────────────────────────────

## `serum_symbol` (issue #53): the player-picked symbol for the Serum guarantee;
## ignored by every other consumable. Falls back to the first non-excluded cycle
## symbol when empty or not in the pickable pool.
func use_consumable(consumable_id: String, serum_symbol := "") -> bool:
	if not _can_use_consumable():
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
				# x3 bet for those spins, then queues the forced x1 spin.
				decaySkips += int(e["spins"])
				forcedRandomBetSpins += int(e["spins"])
				# Issue #97: stacking Energy Drinks stacks the free-spin rush
				# (decaySkips) but NOT the compulsion — the negative debuff caps at
				# a single forced spin no matter how many are used at once.
				pendingCompulsiveSpinSkips = maxi(pendingCompulsiveSpinSkips, int(e["compulsiveSpins"]))
				# The drink pins the gauge at x2 even while a combo defeat is pending;
				# taken during an x3 defeat it also clears the defeat outright — the x3
				# frenzy it would break is traded for the forced x2 rush.
				if comboDefeatPending and clampi(pendingComboMultiplier, 1, 3) == 3:
					comboDefeatPending = false
					pendingComboMultiplier = 1
				betMultiplier = 2
			"addLucidity":
				var plan := Lucidity.plan_gain(lucidityCoins, int(e["amount"]), abilitiesUsed, _seed(spinCount * 0x2545f491), coins_per_power_restore)
				lucidityCoins = int(plan["lucidityCoins"])
				abilitiesUsed = plan["abilitiesUsed"]
				pendingPowerRestores.append_array(plan["restores"])
			"cocktailBoost":
				cocktailBoostSpins += int(e["spins"])
				cocktailPairTriplePenalty = float(e.get("pairTriplePenalty", 0.0))
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
			# next spins, then adjacent strip symbols hide for the negative duration.
			var excludes: Array = ce.get("excludes", [])
			var pool: Array = []
			for s in Symbols.BASE_SYMBOL_CYCLE:
				if not excludes.has(String(s)):
					pool.append(String(s))
			var picked := serum_symbol if pool.has(serum_symbol) else (String(pool[0]) if not pool.is_empty() else "")
			guaranteeSymbolSpins += int(ce["appearSpins"])
			guaranteeSymbolId = picked
			# Issue #97: stacking Serums stacks the guarantee window (appearSpins)
			# but NOT the negative blur — it caps at a single item's duration.
			pendingBlurSpins = maxi(pendingBlurSpins, int(ce.get("blurSpins", 0)))
		"scrambleThenHide":
			# White Powder: the scramble is the copy_reel UI flow; hide the next spin.
			hideResultSpins += 1 if bool(ce["hideNextSpin"]) else 0
		"resetPowersRandomEffect":
			# Potion: restore ALL powers now, then roll a random pool effect per spin.
			abilitiesUsed = []
			potionSpins += int(ce["spins"])
		"restoreAbilityOrSpins":
			# Tea: restore a used ability, or restore normal spins if none were used.
			if abilitiesUsed.is_empty():
				restore_spins(int(ce["fallbackSpins"]))
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
	# Re-entering the dealer scene before DONE re-opens the same phase: keep the
	# staged picks (and the tokens already spent on them) instead of resetting.
	if not oddsPendingUpgrades.is_empty():
		return
	# Banked + fresh, capped at odds_max_tokens (issue #130): at most 8 tokens
	# can ever be held or spent in one menu.
	oddsTokensRemaining = mini(
		int(MetaStateStore.oddsTokensBanked) + maxi(0, odds_budget), odds_max_tokens)
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
	MetaStateStore.set_odds_tokens_banked(mini(oddsTokensRemaining, odds_max_tokens))
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

func _symbol_reward_bonuses_from_meta(owned: Array) -> Dictionary:
	var out: Dictionary = {}
	var amp_symbol := String(MetaStateStore.rewardAmpSymbol)
	var amp_bonus := Economy.compute_symbol_reward_amp_bonus(owned)
	if amp_bonus > 0.0 and Symbols.BASE_SYMBOL_CYCLE.has(amp_symbol):
		out[amp_symbol] = float(out.get(amp_symbol, 0.0)) + amp_bonus
	for symbol in Symbols.BASE_SYMBOL_CYCLE:
		var symbol_id := String(symbol)
		if int(MetaStateStore.odds_upgrade_level(symbol_id)) >= odds_max_level:
			out[symbol_id] = float(out.get(symbol_id, 0.0)) + odds_max_level_reward_bonus
	return out

## Issue #155: what the countdown resets to once an offer resolves. The augmented
## club modifier keeps its "dealer visits halved" intent by doubling the wait.
func dealer_countdown_reset_value() -> int:
	return dealer_countdown_start * (2 if augmented_modifier_active(4) else 1)

## Issue #155: the dealer runs on the fixed countdown — no randomness. The pure
## Dealer trigger module (65%/35% safeties, proc rolls) stays parity-pinned but is
## no longer consulted; the offer picks are still the vector-pinned Dealer rolls.
func check_dealer_trigger() -> void:
	if runPhase != "running" or dealerPending or dealerIncoming:
		return
	if startingNeurons <= 0:
		return
	if dealerCount >= dealer_max_count:
		return
	if dealerCountdown > 0:
		return
	var offers: Variant = Dealer.pick_pool_offer(
		InRunItems.ids(), _seed(spinCount * 0x6b43c7f), dealer_offer_count())
	if offers == null:
		_commit()
		return
	dealerCount += 1
	dealerLastSpinCount = spinCount
	dealerIncoming = true
	dealerOfferIds = offers
	# One dedicated Chip Augment offer per visit, rolled separately from the
	# item offer (and never touched by the painting reroll).
	dealerAugmentOfferId = _roll_augment_offer(_seed(spinCount * 0x51c4a9 + 0xa06))
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
	dealerAugmentOfferId = "" # the visit's augment offer closes with the visit
	dealerCountdown = dealer_countdown_reset_value() # issue #155: visit resolved
	_commit()

func accept_dealer_offer(item_id: String) -> void:
	accept_dealer_offer_with_limit(item_id, max_consumable_slots)

func accept_dealer_offer_with_limit(item_id: String, slot_limit: int) -> void:
	if not dealerPending or dealerOfferIds == null:
		return
	if not (dealerOfferIds as Array).has(item_id):
		return
	var imap := InRunItems.map()
	if imap.has(item_id) and Consumables.total_copies(runConsumables) < maxi(1, slot_limit):
		runConsumables = runConsumables.duplicate(true)
		runConsumables[item_id] = int(runConsumables.get(item_id, 0)) + 1
	dealerPending = false
	dealerOfferIds = null
	dealerAugmentOfferId = ""
	dealerCountdown = dealer_countdown_reset_value() # issue #155: visit resolved
	_commit()

# Current price of the next offer reroll — shared by the pre-run shop and the
# in-run dealer visit (one escalating counter per dealer/run cycle).
func dealer_reroll_price() -> int:
	return DEALER_REROLL_BASE_COST * (dealerRerollCount + 1)

# Painting reroll (issue #117, repriced): replace the pending offer pair with a
# fresh deterministic pick. Costs dealer_reroll_price() run Lucidity and the price
# climbs by DEALER_REROLL_BASE_COST each reroll; available every visit as long as
# the coins hold out. Returns whether the reroll happened.
func reroll_dealer_offer() -> bool:
	if runPhase != "running" or not dealerPending or dealerOfferIds == null:
		return false
	var price := dealer_reroll_price()
	if lucidityCoins < price:
		return false
	var offers: Variant = Dealer.reroll_pool_offer(InRunItems.ids(),
		_seed(spinCount * 0x6b43c7f + 0x117117), dealer_offer_count(), dealerOfferIds)
	if offers == null:
		return false
	lucidityCoins -= price
	dealerOfferIds = offers
	dealerRerollCount += 1
	# dealerAugmentOfferId is deliberately untouched: rerolls never swap the augment.
	_commit()
	return true

# ── pre-run shop offer (max two consumables, rerollable) ───────────────────────────

func _prerun_candidate_ids() -> Array:
	var ids: Array = []
	for c in Consumables.LIST:
		ids.append(String(c["id"]))
	return ids

# Lazily roll (or return) the current pre-run shop offer. A fresh roll starts a
# new dealer cycle, so the escalating reroll price resets here and the previous
# cycle's Chip Augments expire. `seed_override` keeps tests deterministic.
func ensure_prerun_offer(seed_override := -1) -> Array:
	if prerunOfferIds is Array and (prerunOfferIds as Array).size() >= 2:
		return (prerunOfferIds as Array).duplicate()
	# New cycle: last run's augment bonuses expire before the offer count is read.
	chipAugmentsPurchased = {}
	symbolAugmentLevels = {}
	pairTripleAugmentChoice = ""
	var roll_seed := seed_override if seed_override >= 0 else _seed(0x21117)
	var offers: Variant = Dealer.pick_pool_offer(_prerun_candidate_ids(), roll_seed, dealer_offer_count())
	if offers == null:
		return []
	prerunOfferIds = offers
	dealerRerollCount = 0 # fresh pre-run offer => new cycle, price back to base
	dealerAugmentOfferId = _roll_augment_offer(roll_seed ^ 0xa06a06)
	_commit()
	return (offers as Array).duplicate()

# Pre-run painting reroll: same escalating price, paid from the wallet
# (MetaStateStore) since no run currency exists yet. Never swaps the augment offer.
func reroll_prerun_offer(seed_override := -1) -> bool:
	if runPhase == "running" or not (prerunOfferIds is Array):
		return false
	var roll_seed := seed_override if seed_override >= 0 else _seed(0x117 * 977)
	var offers: Variant = Dealer.reroll_pool_offer(
		_prerun_candidate_ids(), roll_seed, dealer_offer_count(), prerunOfferIds)
	if offers == null:
		return false
	if not MetaStateStore.spend_lucidity(dealer_reroll_price()):
		return false
	prerunOfferIds = offers
	dealerRerollCount += 1
	_commit()
	return true

# ── Chip Augments (data in rules/chip_augments.gd) ──────────────────────────────────

## Items/consumables generated per dealer visit: 2, or 3 with Expanded Selection.
func dealer_offer_count() -> int:
	if int(chipAugmentsPurchased.get("aug_offer_expand", 0)) > 0:
		return ChipAugments.EXPANDED_OFFER_COUNT
	return 2

## One random eligible augment (stock left) for a fresh visit; "" when the pool
## is exhausted.
func _roll_augment_offer(seed_val: int) -> String:
	var pool := ChipAugments.eligible_ids(chipAugmentsPurchased)
	if pool.is_empty():
		return ""
	var rng := LobRNG.new(seed_val & M32)
	return String(pool[mini(pool.size() - 1, floori(rng.next() * pool.size()))])

## Chip Discount applies to augment ("chip") prices; project rounding rules.
func chip_augment_price(augment_id: String) -> int:
	var entry: Variant = ChipAugments.map().get(augment_id, null)
	if entry == null:
		return 0
	return ChipAugments.discounted_price(int(entry["cost"]),
		int(chipAugmentsPurchased.get("aug_chip_discount", 0)))

## Consumable Discount applies to the (pre-run) consumable shop prices.
func consumable_price(consumable_id: String) -> int:
	var cmap := Consumables.map()
	if not cmap.has(consumable_id):
		return 0
	return ChipAugments.discounted_price(int(cmap[consumable_id]["shopCost"]),
		int(chipAugmentsPurchased.get("aug_consumable_discount", 0)))

## Effective symbol level = persisted odds level + this cycle's augment levels.
## Augments may push past odds_max_level, up to the hard cap of 9.
func augment_symbol_level(symbol: String) -> int:
	return int(MetaStateStore.odds_upgrade_level(symbol)) + int(symbolAugmentLevels.get(symbol, 0))

## Purchase the offered augment. `choice` carries the selector result: a symbol id
## for aug_symbol_level, "pair"/"triple" for aug_pair_triple. All validation runs
## BEFORE any charge, so a cancelled/invalid selection can never spend anything.
## Charges run Lucidity in-run, the wallet pre-run. Returns whether it went through.
func purchase_chip_augment(augment_id: String, choice := "") -> bool:
	if augment_id == "" or dealerAugmentOfferId != augment_id:
		return false
	if ChipAugments.stock_left(augment_id, chipAugmentsPurchased) <= 0:
		return false
	match augment_id:
		"aug_symbol_level":
			if not Symbols.BASE_SYMBOL_CYCLE.has(choice) or choice == "flatline":
				return false
			if augment_symbol_level(choice) >= ChipAugments.SYMBOL_LEVEL_HARD_CAP:
				return false
		"aug_pair_triple":
			if choice != "pair" and choice != "triple":
				return false
	var price := chip_augment_price(augment_id)
	if runPhase == "running":
		if lucidityCoins < price:
			return false
		lucidityCoins -= price
	elif not MetaStateStore.spend_lucidity(price):
		return false
	chipAugmentsPurchased = chipAugmentsPurchased.duplicate(true)
	chipAugmentsPurchased[augment_id] = int(chipAugmentsPurchased.get(augment_id, 0)) + 1
	match augment_id:
		"aug_symbol_level":
			_apply_symbol_augment(choice)
		"aug_extra_spins":
			# In-run: replenish now via the spin/neuron model. Pre-run copies are
			# folded in by _apply_chip_augment_run_overlay at run start.
			if runPhase == "running":
				neurons += ChipAugments.EXTRA_SPINS_PER_COPY \
					* maxi(1, Economy.compute_neuron_decay(ownedUpgrades))
		"aug_pair_triple":
			pairTripleAugmentChoice = choice # locked — cannot be changed afterwards
	dealerAugmentOfferId = "" # one dedicated offer per visit; it is now consumed
	_commit()
	return true

## +1 augment level for `symbol`. Weight rises like a permanent odds level; the
## max-level reward bonus is granted on crossing odds_max_level AND again at the
## augment-only level 9 (the "additional scaling" for level-9 symbols).
func _apply_symbol_augment(symbol: String) -> void:
	var new_level := augment_symbol_level(symbol) + 1
	symbolAugmentLevels = symbolAugmentLevels.duplicate(true)
	symbolAugmentLevels[symbol] = int(symbolAugmentLevels.get(symbol, 0)) + 1
	if runPhase != "running":
		return # pre-run: folded into the run overlay at start_new_run
	oddsWeightOverrides = oddsWeightOverrides.duplicate(true)
	oddsWeightOverrides[symbol] = float(oddsWeightOverrides.get(symbol, 0.0)) \
		+ probability_increase_per_upgrade
	if new_level == odds_max_level or new_level == ChipAugments.SYMBOL_LEVEL_HARD_CAP:
		symbolRewardBonuses = symbolRewardBonuses.duplicate(true)
		symbolRewardBonuses[symbol] = float(symbolRewardBonuses.get(symbol, 0.0)) \
			+ odds_max_level_reward_bonus

## Folds pre-run augment purchases into a freshly started run: symbol levels into
## the derived weight/reward tables, Extra Spins into the starting spin budget.
func _apply_chip_augment_run_overlay() -> void:
	for symbol in symbolAugmentLevels:
		var added := int(symbolAugmentLevels[symbol])
		if added <= 0:
			continue
		oddsWeightOverrides[String(symbol)] = float(oddsWeightOverrides.get(String(symbol), 0.0)) \
			+ added * probability_increase_per_upgrade
		var base_level := int(MetaStateStore.odds_upgrade_level(String(symbol)))
		for lvl in range(base_level + 1, base_level + added + 1):
			if lvl == odds_max_level or lvl == ChipAugments.SYMBOL_LEVEL_HARD_CAP:
				symbolRewardBonuses[String(symbol)] = float(symbolRewardBonuses.get(String(symbol), 0.0)) \
					+ odds_max_level_reward_bonus
	var spin_copies := int(chipAugmentsPurchased.get("aug_extra_spins", 0))
	if spin_copies > 0:
		var bonus := spin_copies * ChipAugments.EXTRA_SPINS_PER_COPY \
			* maxi(1, Economy.compute_neuron_decay(ownedUpgrades))
		neurons += bonus

func decline_dealer_offer() -> void:
	dealerPending = false
	dealerOfferIds = null
	dealerAugmentOfferId = "" # the visit's augment offer closes with the visit
	dealerCountdown = dealer_countdown_reset_value() # issue #155: visit resolved
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
