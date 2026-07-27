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

## Pacte owns the run's power loadout. No power is granted by default; legacy
## callers that skip the ritual still receive only the permanent powers they own.
const PACTE_CAMPAIGN_NEURON_THRESHOLDS: Array[int] = [2, 1]
const PACTE_WEALTH_TARGETS: Array[int] = [500, 1500]
const PACTE_INITIAL_DRAW_SEED := 0x50414354
const PACTE_THRESHOLD_DRAW_SEED := 0x54485245
const HERO_POWER_IDS: Array[String] = []
const WIN_BOOST_RATES := [0.0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45]
const JOKER_DEALER_HELP_CHANCE := 0.35
const JOKER_DEALER_HELP_POWERS: Array[String] = ["cheat", "shift", "reroll", "memory"]

@export_group("Run Balance")
@export var max_consumable_slots: int = Consumables.MAX_CONSUMABLE_SLOTS
@export var coins_per_power_restore: int = EconomyConst.LUCIDITY_COINS_PER_RESTORE

@export_group("Dealer Interruptions")
# Issue #76: no hard 3-per-run cap anymore — the dealer is a pressure system. Kept as a
# high sentinel so the guard still has a ceiling; the countdown paces visits, not this.
@export var dealer_max_count: int = 99
# Issue #155: dealer randomness is gone. The dealer runs on a fixed, visible countdown:
# it starts at dealer_countdown_start, every completed spin advances it by the
# inverse multiplier used at spin start (x1/x2/x3 → -3/-2/-1), 0 triggers the visit,
# and the countdown resets once the offer resolves. No overflow carry (a spin that
# reaches 0 lands the dealer). The augmented club modifier halves visits by doubling
# the reset.
@export var dealer_countdown_start: int = 12

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
# What the reels currently on screen are worth on their own, before any store-level
# boost. Abilities report a rescore difference; this is what turns that back into the
# new combination's own value so each one can pay on top of the last (issue #181).
var lastPureWinScore := 0
var lastPureWinCoins := 0
var dealerCount := 0
var dealerLastSpinCount := 0
var dealerCountdown := 12 # issue #155: steps until the dealer (start value re-applied per run)
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
## items/consumables and untouched by the painting reroll. Purchased bonuses
## persist for the whole campaign (flatline continuations included); they clear
## only when a fresh Pacte run starts or on a full reset. All fields have
## safe defaults, so older saves/sessions simply start with no augments.
var chipAugmentsPurchased := {}       # augment id -> copies bought this campaign
var dealerAugmentOfferId := ""        # current visit's dedicated offer ("" = none)
var symbolAugmentLevels := {}         # symbol -> +levels bought via aug_symbol_level
var pairTripleAugmentChoice := ""     # "" | "pair" | "triple" (locked once chosen)
var extraSpinsGranted := 0            # aug_extra_spins copies already paid out
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
# Card-unlock tracking (issue #52): paying pairs seen this run, and how many times
# each symbol paid as a triple this run. Both feed "best single run" meta metrics.
var runPairCount := 0
var runTripleCounts: Dictionary = {}
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
var runPhase := "idle" # idle | pre_run | pacte_initial | pacte_threshold | running | over
var lastEnding: Variant = null
var wealthContinued := false
## Intermediate Wealth targets are paid out from the run score in sequence. The
## final target still hands the full run to the Wealth ending screen.
var wealthTargetIndex := 0
var wealthTargetPending := false
var wealthTargetPendingValue := 0
## A beaten intermediate target sends the player to the persistent dealer shop and
## then starts a fresh machine run (issue #176). This flag survives the dealer visit
## so the next start keeps augments/powers/consumables + the advanced target while
## resetting score and the run-spin budget; a campaign neuron is NOT spent.
var roundContinuationPending := false
## Distinguishes a threshold Pacte opened by a Wealth target (routes to the target
## round break) from one opened by a campaign-health crossing (post-flatline visit).
var pacteTargetRoundVisit := false
var campaignNeuronPending := false # consumed when the machine run ends
var pendingPowerRestores: Array = []
## Restore charges left (0 .. EconomyConst.POWER_RESTORE_CHARGE_MAX). Every score-driven
## restore spends one — plan_gain crossings and the gauge's own completion — and each spin
## launched gives one back, so a run can restore one power per spin on average and at most
## two on any single spin. A consumable that hands a power back is an item effect and
## spends nothing here.
var powerRestoreCharges := EconomyConst.POWER_RESTORE_CHARGE_MAX

# Pacte run snapshot. Offers and temporary selections are saved so leaving the
# scene or restarting the game never silently discards a reserved run.
var pacteSeed := 0
var pacteOfferAugmentIds: Variant = null
var pacteOfferPowerIds: Variant = null
var pacteSelectedAugmentId := ""
var pacteSelectedPowerId := ""
var selectedAugmentCardIds: Array = []
var selectedPowerCardIds: Array = []
var ownedPowerIds: Array = []
var pacteThresholdPending := false
var pacteThresholdOpened := false
var pacteAfterFlatlinePending := false
## Number of the two campaign Pacte threshold visits already completed. A target
## milestone and a campaign-health crossing share this sequence, so whichever
## event happens first consumes the corresponding visit.
var pacteThresholdVisits := 0
var pacteJokerArmed := false
var pacteJokerActive := false
var winBoostEnabled := false
var winBoostCombo := 0
var glitchDealerStepActive := false
var dealerHelpSpinCount := -1

# Rewind stores the pre-spin state, not rewards. That lets the power restore the
# immediately previous board/currency state while preserving score and Lucidity
# already earned by the player.
var previousSpinSnapshot: Variant = null
var rewindHistoryAvailable := false
var heartPowerArmed := false

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

func _neuron_cap() -> int:
	return maxi(0, Economy.compute_neuron_cap(ownedUpgrades))

func _clamp_neurons() -> void:
	neurons = clampi(neurons, 0, _neuron_cap())

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

func has_power(power_id: String) -> bool:
	var normalised := PacteCards.normalise_card_id(power_id)
	if not ownedPowerIds.is_empty():
		return ownedPowerIds.has(normalised)
	# Compatibility for a save made before Pacte: old permanent power flags still
	# grant the equivalent run power until that run is replaced.
	return (normalised == "shift" and ownedUpgrades.has("perm_shift")) \
		or (normalised == "memory" and ownedUpgrades.has("perm_memory"))

func power_loadout() -> Array[String]:
	var result: Array[String] = []
	for id in HERO_POWER_IDS:
		if not result.has(id):
			result.append(id)
	for id in ownedPowerIds:
		var normalised := PacteCards.normalise_card_id(String(id))
		if not result.has(normalised):
			result.append(normalised)
	return result

## Powers that can rescue the current reveal, plus Heart's guaranteed next-spin
## rescue, are valid choices while a combo defeat is pending. Memory is also
## available here so the player can lock a reel before confirming the loss.
func pending_combo_power_ids() -> Array[String]:
	var ids: Array[String] = []
	if not comboDefeatPending or not _can_use_ability():
		return ids
	for id in ["reroll", "shift", "memory", "rewind", "cheat", "swap", "heart"]:
		if has_power(id) and not abilitiesUsed.has(id) and not pendingPowerRestores.has(id):
			ids.append(id)
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
	if not rescued and winBoostEnabled:
		# The COMBO display is recoverable for the duration of the warning. Only
		# the player's explicit loss confirmation breaks its streak.
		winBoostCombo = 0
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
		# No live or resumable post-run session: a stale file (or a stale backup of
		# one) must not offer CONTINUE.
		SaveIO.remove(RUN_SAVE_PATH)
		return
	var out := { "schemaVersion": RUN_SAVE_SCHEMA_VERSION }
	for prop in _run_state_properties():
		out[prop] = get(prop)
	SaveIO.write_text(RUN_SAVE_PATH, var_to_str(out))

## A snapshot is worth loading only when it parses into a dictionary AND was written by
## a schema this build understands. A file from a newer build is rejected rather than
## half-applied over the current state.
func _run_snapshot_is_readable(text: String) -> bool:
	var data: Variant = str_to_var(text)
	if not (data is Dictionary):
		return false
	return int((data as Dictionary).get("schemaVersion", RUN_SAVE_SCHEMA_VERSION)) \
		<= RUN_SAVE_SCHEMA_VERSION

## Whether `value` can stand in for a property currently holding `current`. A field
## whose type changed between builds must not be forced onto the property: set() would
## reject it and leave the run half-restored, so keeping the reset default is the
## recoverable outcome. Variant fields (lastResult, dealerOfferIds, …) sit at null
## between uses and accept anything.
func _restorable(current: Variant, value: Variant) -> bool:
	if current == null or value == null:
		return true
	var current_type := typeof(current)
	var value_type := typeof(value)
	if current_type == value_type:
		return true
	# Numbers interchange cleanly (a float snapshot into an int counter); nothing else does.
	return (current_type == TYPE_INT or current_type == TYPE_FLOAT) \
		and (value_type == TYPE_INT or value_type == TYPE_FLOAT)

## Restores a live run snapshot, if one exists. Unknown keys (removed fields)
## are skipped; missing keys (new fields) keep their reset defaults.
func load_run_state() -> void:
	if Engine.is_editor_hint():
		return
	# An unreadable primary falls through to the backup copy; when neither is usable the
	# file is dropped so a corrupt snapshot cannot fail every launch from now on.
	var text := SaveIO.read_text(RUN_SAVE_PATH, _run_snapshot_is_readable)
	if text.is_empty():
		SaveIO.remove(RUN_SAVE_PATH)
		return
	var saved := str_to_var(text) as Dictionary
	var saved_phase := String(saved.get("runPhase", ""))
	var saved_flatline := saved_phase == "over" \
		and str(saved.get("lastEnding", "")) == "flatline" \
		and int(MetaStateStore.campaignNeuronsLeft) > 0
	# A between-target break parks at the shared dealer with runPhase "over" (issue #176).
	var saved_target_break := saved_phase == "over" \
		and bool(saved.get("roundContinuationPending", false))
	if saved_phase != "running" and saved_phase != "pre_run" \
			and saved_phase != "pacte_initial" and saved_phase != "pacte_threshold" \
			and not saved_flatline and not saved_target_break:
		SaveIO.remove(RUN_SAVE_PATH)
		return
	for prop in _run_state_properties():
		if not saved.has(prop):
			continue
		var value: Variant = saved[prop]
		if not _restorable(get(prop), value):
			continue
		set(prop, value)
	# Older live-run saves did not track which of the two campaign Pacte visits
	# had already been completed. The selected card history is enough to recover
	# that count without changing the visible run state.
	if not saved.has("pacteThresholdVisits"):
		pacteThresholdVisits = clampi(selectedAugmentCardIds.size() - 1, 0, PACTE_CAMPAIGN_NEURON_THRESHOLDS.size())
	if not saved.has("wealthTargetIndex"):
		# Pre-milestone saves stored cumulative score. Resume them at the first
		# ladder target they had not already passed instead of replaying TARGET 100.
		wealthTargetIndex = 0
		for target_value: int in EconomyConst.WEALTH_TARGETS:
			if scoreEarned < target_value:
				break
			wealthTargetIndex += 1
	wealthTargetIndex = clampi(int(wealthTargetIndex), 0, EconomyConst.WEALTH_TARGETS.size() - 1)
	wealthTargetPendingValue = maxi(0, int(wealthTargetPendingValue))
	ownedPowerIds = _normalise_power_ids(ownedPowerIds)
	selectedPowerCardIds = _normalise_power_ids(selectedPowerCardIds)
	pacteSelectedPowerId = PacteCards.normalise_card_id(pacteSelectedPowerId)
	pacteOfferPowerIds = _normalise_power_array_or_null(pacteOfferPowerIds)
	abilitiesUsed = _normalise_power_ids(abilitiesUsed)
	pendingPowerRestores = _normalise_power_ids(pendingPowerRestores)
	_reapply_pacte_runtime_effects()
	_clamp_neurons()
	_commit()

func _normalise_power_ids(values: Array) -> Array:
	var result: Array = []
	for value in values:
		var power_id := PacteCards.normalise_card_id(String(value))
		if not result.has(power_id):
			result.append(power_id)
	return result

func _normalise_power_array_or_null(value: Variant) -> Variant:
	if value == null:
		return null
	if value is Array:
		return _normalise_power_ids(value as Array)
	return value

# ── spin ──────────────────────────────────────────────────────────────────────────

func _capture_rewind_snapshot() -> Dictionary:
	return {
		"neurons": neurons,
		"freeSpinsRemaining": freeSpinsRemaining,
		"dealerCountdown": dealerCountdown,
		"dealerLastSpinCount": dealerLastSpinCount,
		"dealerIncoming": dealerIncoming,
		"dealerPending": dealerPending,
		"dealerOfferIds": dealerOfferIds.duplicate(true) if dealerOfferIds is Array else dealerOfferIds,
		"dealerAugmentOfferId": dealerAugmentOfferId,
		"comboDefeatPending": comboDefeatPending,
		"pendingComboMultiplier": pendingComboMultiplier,
		"betMultiplier": betMultiplier,
		"lastComboMultiplier": lastComboMultiplier,
		"lastEffectiveBet": lastEffectiveBet,
		# The additive payout baseline belongs to the reels being restored, or a power
		# used after a rewind would pay off the rewound spin's combination.
		"lastPureWinScore": lastPureWinScore,
		"lastPureWinCoins": lastPureWinCoins,
		"spinCount": spinCount,
		"winBoostCombo": winBoostCombo,
		"dealerHelpSpinCount": dealerHelpSpinCount,
		"isFreeSpin": isFreeSpin,
		"lastResult": lastResult.duplicate(true) if lastResult is Dictionary else lastResult,
		"lockedReels": lockedReels.duplicate(),
		"lockedReelSpins": lockedReelSpins.duplicate(),
		"eyeRevealReel": eyeRevealReel,
		"eyeRevealSymbol": eyeRevealSymbol,
		"pacteThresholdPending": pacteThresholdPending,
		"pacteAfterFlatlinePending": pacteAfterFlatlinePending,
		"heartPowerArmed": heartPowerArmed,
		# Powers already spent before this spin belong to the prior reveal. Rewind
		# only refunds powers added after this snapshot, i.e. on the rewound spin.
		"abilitiesUsed": abilitiesUsed.duplicate(),
		"powersUsedThisSpin": powersUsedThisSpin,
		"powerRestoreCharges": powerRestoreCharges,
		"pendingPowerRestores": pendingPowerRestores.duplicate(),
	}

func _restore_rewind_snapshot(snapshot: Dictionary) -> void:
	neurons = int(snapshot.get("neurons", neurons))
	_clamp_neurons()
	freeSpinsRemaining = int(snapshot.get("freeSpinsRemaining", freeSpinsRemaining))
	dealerCountdown = int(snapshot.get("dealerCountdown", dealerCountdown))
	dealerLastSpinCount = int(snapshot.get("dealerLastSpinCount", dealerLastSpinCount))
	dealerIncoming = bool(snapshot.get("dealerIncoming", dealerIncoming))
	dealerPending = bool(snapshot.get("dealerPending", dealerPending))
	dealerOfferIds = snapshot.get("dealerOfferIds", dealerOfferIds)
	dealerAugmentOfferId = String(snapshot.get("dealerAugmentOfferId", dealerAugmentOfferId))
	comboDefeatPending = bool(snapshot.get("comboDefeatPending", comboDefeatPending))
	pendingComboMultiplier = int(snapshot.get("pendingComboMultiplier", pendingComboMultiplier))
	betMultiplier = int(snapshot.get("betMultiplier", betMultiplier))
	lastComboMultiplier = int(snapshot.get("lastComboMultiplier", lastComboMultiplier))
	lastEffectiveBet = int(snapshot.get("lastEffectiveBet", lastEffectiveBet))
	lastPureWinScore = int(snapshot.get("lastPureWinScore", lastPureWinScore))
	lastPureWinCoins = int(snapshot.get("lastPureWinCoins", lastPureWinCoins))
	spinCount = int(snapshot.get("spinCount", spinCount))
	winBoostCombo = int(snapshot.get("winBoostCombo", winBoostCombo))
	dealerHelpSpinCount = int(snapshot.get("dealerHelpSpinCount", dealerHelpSpinCount))
	isFreeSpin = bool(snapshot.get("isFreeSpin", isFreeSpin))
	lastResult = snapshot.get("lastResult", lastResult)
	lockedReels = (snapshot.get("lockedReels", lockedReels) as Array).duplicate()
	lockedReelSpins = (snapshot.get("lockedReelSpins", lockedReelSpins) as Array).duplicate()
	eyeRevealReel = int(snapshot.get("eyeRevealReel", eyeRevealReel))
	eyeRevealSymbol = String(snapshot.get("eyeRevealSymbol", eyeRevealSymbol))
	pacteThresholdPending = bool(snapshot.get("pacteThresholdPending", pacteThresholdPending))
	pacteAfterFlatlinePending = bool(snapshot.get("pacteAfterFlatlinePending", pacteAfterFlatlinePending))
	heartPowerArmed = bool(snapshot.get("heartPowerArmed", heartPowerArmed))
	powersUsedThisSpin = int(snapshot.get("powersUsedThisSpin", 0))
	powerRestoreCharges = int(snapshot.get("powerRestoreCharges",
		EconomyConst.POWER_RESTORE_CHARGE_MAX))
	pendingPowerRestores = (snapshot.get("pendingPowerRestores", pendingPowerRestores) as Array).duplicate()
	isSpinning = false

func rewind() -> bool:
	if not _can_use_ability() or not has_power("rewind") or not rewindHistoryAvailable \
			or previousSpinSnapshot == null or abilitiesUsed.has("rewind"):
		lastPowerFailureReason = "Rewind needs a completed previous spin."
		_commit()
		return false
	var snapshot := previousSpinSnapshot as Dictionary
	if snapshot.get("lastResult", null) == null or int(snapshot.get("spinCount", 0)) <= 0:
		lastPowerFailureReason = "Rewind needs a completed previous spin."
		_commit()
		return false
	var score_before := scoreEarned
	var lucidity_before := lucidityCoins
	var spent: Array = []
	var abilities_before_spin: Array = []
	var snapshot_abilities: Variant = snapshot.get("abilitiesUsed", null)
	var snapshot_heart_armed := bool(snapshot.get("heartPowerArmed", false))
	if snapshot_abilities is Array:
		abilities_before_spin = (snapshot_abilities as Array).duplicate()
	# A legacy snapshot has no per-spin power list. Do not fall back to every power
	# spent in the run: the restore pool is intentionally empty in that case.
	if snapshot_abilities is Array:
		for raw_id in abilitiesUsed:
			var power_id := String(raw_id)
			# Heart is armed before the lever pull, so its chip is already present
			# in the snapshot even though it belongs to the spin being rewound.
			var used_on_rewound_spin := not abilities_before_spin.has(power_id) \
				or (power_id == "heart" and snapshot_heart_armed)
			if power_id != "rewind" and used_on_rewound_spin:
				spent.append(power_id)
	_restore_rewind_snapshot(snapshot)
	scoreEarned = score_before
	lucidityCoins = lucidity_before
	var recovery_rng := LobRNG.new((pacteSeed ^ int(snapshot.get("spinCount", 0)) ^ 0x52455749) & M32)
	var recover_count := 1 + floori(recovery_rng.next() * 3.0)
	var restored_heart := false
	for _i in recover_count:
		if spent.is_empty():
			break
		var index := mini(spent.size() - 1, floori(recovery_rng.next() * spent.size()))
		var restored_id := String(spent[index])
		spent.remove_at(index)
		var used_index := abilitiesUsed.find(restored_id)
		if used_index >= 0:
			abilitiesUsed.remove_at(used_index)
		if restored_id == "heart":
			restored_heart = true
	abilitiesUsed = abilitiesUsed.duplicate()
	# Restoring Heart refunds the chip rather than leaving the old arm state
	# pending. The player can explicitly arm the restored power again, and that
	# follow-up spin keeps Heart's normal +1/+2/+3 result path.
	if restored_heart:
		heartPowerArmed = false
	# Rewind is a one-use chip like every other power. It is deliberately excluded
	# from the recovery pool above, otherwise recovering a random power could restore
	# Rewind itself and let the player rewind forever through the same history.
	if not abilitiesUsed.has("rewind"):
		abilitiesUsed.append("rewind")
	lastPowerFailureReason = ""
	rewindHistoryAvailable = false
	previousSpinSnapshot = null
	powersUsedThisSpin += 1
	_note_card_metric(CardUnlocks.METRIC_REWINDS)
	_commit()
	return true

func spin(compulsive := false) -> Variant:
	if runPhase != "running" or isSpinning:
		return null
	# Normalize legacy or externally restored state before charging this spin. The
	# machine never spends from a pool above the current 18-spin cap.
	_clamp_neurons()
	# The gameplay scene normally resolves this through the pending UI. A direct
	# caller that requests another spin has implicitly declined the rescue instead
	# of leaving the store permanently locked.
	if comboDefeatPending:
		if heartPowerArmed:
			# A saved Heart rescue may coexist with an older warning. Preserve the
			# current gauge and let the guaranteed heart win settle it below.
			comboDefeatPending = false
			pendingComboMultiplier = 1
		else:
			resolve_pending_combo_defeat(false)
	previousSpinSnapshot = _capture_rewind_snapshot()
	rewindHistoryAvailable = true
	var is_compulsive: bool = compulsive and compulsiveSpinSkips > 0
	if not is_compulsive and compulsiveSpinSkips > 0:
		return null
	var heart_spin_armed := (not is_compulsive) and heartPowerArmed
	var is_free: bool = (not is_compulsive) and (freeSpinsRemaining > 0 or heart_spin_armed)
	if (not is_free) and neurons < 1:
		return null

	# One restore charge back for the spin. This spin's own payout and every power the
	# player then plays on these reels draw from the same pool, so a pair that gives one
	# power back can only be followed by another restore if a charge was banked.
	_recharge_restores()

	var seed := _seed(spinCount * 0x9e3779b9)
	var rng := LobRNG.new(seed)

	var stasis: bool = (not is_compulsive) and (not is_free) and decaySkips > 0
	var sedative: bool = (not is_compulsive) and (not is_free) and Economy.has_sedative(ownedUpgrades) and (spinCount + 1) % 3 == 0

	# Issue #155: the gauge value this spin runs at. The multiplier no longer costs
	# extra neurons or free spins — its downside is the dealer countdown advancing
	# 3/2/1 steps at x1/x2/x3, so lower gauges pull the dealer in faster.
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
	var result: Dictionary
	if heart_spin_armed:
		# Heart's result is intentionally independent of the normal symbol weights:
		# one seeded draw chooses x1/x2/x3, then every reel lands on that symbol.
		var heart_rng := LobRNG.new((pacteSeed ^ (spinCount * 0x9e3779b9) \
				^ 0x48454152) & M32)
		var heart_tier := 1 + floori(heart_rng.next() * 3.0)
		result = Abilities.resolve_heart_spin(heart_tier, eff_mult,
			_active_reward_scale(), symbolRewardBonuses)
		result["neuronsAfter"] = mini(_neuron_cap(), neurons + int(result["neuronsDelta"]))
		result["freeSpinsAfter"] = freeSpinsRemaining
		result["isFreeSpin"] = true
		result["scoreMultiplier"] = eff_mult
		heartPowerArmed = false
	else:
		result = Evaluate.evaluate({
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
			"pairScoreMult": _pair_score_multiplier(pair_boost_active),
			"hiddenReelCount": hidden_reel_count,
			"visiblePairAsTriple": hallucination_active,
			"rewardScale": _active_reward_scale(),
			"bookRewardScale": _book_reward_scale(),
			"soloAsPair": Economy.has_solo_as_pair(ownedUpgrades),
			"symbolRewardBonuses": symbolRewardBonuses,
			"weightOverrides": oddsWeightOverrides,
		})

	# The Cocktail is pure upside: rarity points on every visible reel, no tax. It used to
	# charge 15% of a pair/triple back, which made the item read as a trap on exactly the
	# spins it was supposed to reward.
	var cocktail_bonus := 0
	if cocktailBoostSpins > 0:
		var rarity_total := 0
		var visible_count := maxi(1, (result["reels"] as Array).size() - hidden_reel_count)
		for i in visible_count:
			rarity_total += int(COCKTAIL_RARITY_POINTS.get(String((result["reels"] as Array)[i]), 0))
		cocktail_bonus = floori(float(rarity_total) * float(result["scoreMultiplier"]) + 0.5)
	# Issue #76: a charged flatline strike multiplies the next winning pair/triple. The
	# bonus rides on top of the pinned score (evaluate() untouched, like cocktail above)
	# so it flows through the lucidity plan; requiring base_score > 0 means misses and
	# 0-score flatline wins never spend the charge — it waits for a real win.
	var base_score := maxi(0, int(result["scoreEarned"]) + cocktail_bonus)
	var flatline_boost := 0
	var flatline_boost_applied := false
	if flatlineWinBoostArmed and base_score > 0 \
			and String(result["winType"]) in ["pair", "triple", "jackpot"]:
		flatline_boost = base_score * (EconomyConst.FLATLINE_WIN_BOOST_MULT - 1)
		flatline_boost_applied = true
	# COMBO is a separate Pacte streak from the flatline strike above. Each
	# successive paying result earns the next 5%-step bonus, then caps at 45%.
	var win_boost_bonus := 0
	var win_boost_percent := 0
	var win_boost_combo := 0
	var win_boost_applied := false
	var paying_result := base_score > 0 and String(result["winType"]) in ["pair", "triple", "jackpot"]
	if winBoostEnabled and paying_result:
		var boost_step := clampi(winBoostCombo + 1, 1, 9)
		win_boost_combo = boost_step
		win_boost_percent = roundi(float(WIN_BOOST_RATES[boost_step]) * 100.0)
		win_boost_bonus = floori(float(base_score) * WIN_BOOST_RATES[boost_step] + 0.5)
		win_boost_applied = true
	# Pair/Triple Specialist (Chip Augment): the chosen win type pays x1.25. Rides on
	# top of the pinned score like the cocktail/flatline boosts (evaluate() untouched).
	var specialist_bonus := ChipAugments.specialist_bonus(
		base_score, String(result["winType"]), pairTripleAugmentChoice)
	# Augmented heart modifier (issue #111): the brain jackpot pays 100 instead of
	# 200 and no longer grants its free spin. Apply it after the other score boosts
	# so the whole jackpot payout remains proportional.
	var complete_score := base_score + flatline_boost + win_boost_bonus + specialist_bonus
	var augmented_jackpot: Dictionary = _apply_augmented_jackpot(
		complete_score, String(result["winType"]))
	var final_score := int(augmented_jackpot["score"])
	var augmented_jackpot_cut := int(augmented_jackpot["cut"])
	var passive_lucidity := _passive_lucidity_per_spin()
	var final_result: Dictionary = result
	if cocktail_bonus > 0 or flatline_boost_applied \
			or win_boost_applied or specialist_bonus > 0 or hidden_reel_count > 0 \
			or augmented_jackpot_cut > 0 or passive_lucidity > 0:
		final_result = result.duplicate(true)
		final_result["scoreEarned"] = final_score
		final_result["coinsEarned"] = final_score
		if hidden_reel_count > 0:
			final_result["hiddenReelCount"] = hidden_reel_count
		if cocktail_bonus > 0:
			final_result["cocktailApplied"] = true
			final_result["cocktailBonus"] = cocktail_bonus
		if flatline_boost_applied:
			final_result["flatlineBoostApplied"] = true
			final_result["flatlineBoostBonus"] = flatline_boost
		if win_boost_applied:
			final_result["winBoostApplied"] = true
			final_result["winBoostPercent"] = win_boost_percent
			final_result["winBoostBonus"] = win_boost_bonus
			final_result["winBoostCombo"] = win_boost_combo
			final_result["winBoostBaseScore"] = maxi(0, final_score - win_boost_bonus)
		if specialist_bonus > 0:
			final_result["specialistBonus"] = specialist_bonus
		if augmented_jackpot_cut > 0:
			# Evaluate only adds freeSpinsGranted on non-free spins; undo exactly that.
			if not bool(final_result["isFreeSpin"]):
				final_result["freeSpinsAfter"] = maxi(0,
					int(final_result["freeSpinsAfter"]) - int(final_result["freeSpinsGranted"]))
			final_result["freeSpinsGranted"] = 0
			final_result["augmentedJackpotCut"] = augmented_jackpot_cut
		if passive_lucidity > 0:
			final_result["passiveLucidity"] = passive_lucidity

	# Heart stays spent like every other power: it waits in the pool until the
	# active power-restore threshold brings it back.
	var lucidity_gain := int(final_result["scoreEarned"]) + passive_lucidity
	var plan := Lucidity.plan_gain(lucidityCoins, lucidity_gain, abilitiesUsed, seed,
		effective_coins_per_power_restore(), restore_budget_left())

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
	_clamp_neurons()
	# Passive gain is wealth, not just power fuel: it feeds the run total (and so the
	# wealth odometer and the target) alongside the Lucidity it already paid out. The
	# per-spin result keeps only the reel payout, so the score popup still announces
	# what the reels won.
	scoreEarned += int(final_result["scoreEarned"]) + passive_lucidity
	lucidityCoins = maxi(0, int(plan["lucidityCoins"]) + potion_lucidity_delta)
	abilitiesUsed = new_abilities
	pendingPowerRestores.append_array(plan["restores"])
	_spend_restore_budget((plan["restores"] as Array).size())
	_note_card_metric(CardUnlocks.METRIC_POWER_RESTORES, (plan["restores"] as Array).size())
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
	# Baseline for the additive power payouts below: what the reels as spun are worth
	# on their own, before any store-level boost. Powers reshape these reels, and each
	# combination they form pays on top rather than replacing this one.
	lastPureWinScore = maxi(0, int(result["scoreEarned"]))
	lastPureWinCoins = maxi(0, int(result["coinsEarned"]))
	_track_spin_card_progress(final_result)
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
		if winBoostEnabled:
			winBoostCombo = mini(9, winBoostCombo + 1)
		betMultiplier = _combo_after(combo_before, final_result)
		if energy_drink_owns_multiplier():
			betMultiplier = 2 # the drink still owns the gauge — no x3 until it ends
		comboDefeatPending = false
		pendingComboMultiplier = 1
	elif decaySkips > 0:
		# Energy Drink protected spin (decaySkips not yet consumed here): the drink
		# owns the x2, so a miss never opens a losing state — the forced spin that
		# follows the rush is the next result that can set one.
		comboDefeatPending = false
		pendingComboMultiplier = 1
		betMultiplier = combo_before
		if winBoostEnabled:
			# Protected spins have no rescue window, so a miss breaks COMBO now.
			winBoostCombo = 0
	else:
		# Keep COMBO at its current stage while the losing-state warning is open.
		# resolve_pending_combo_defeat(false) clears it if the player confirms the
		# loss; a corrective power can still recover it here.
		comboDefeatPending = true
		pendingComboMultiplier = combo_before
		betMultiplier = combo_before
	# Issue #155 dealer countdown: every completed spin advances it by the inverse
	# multiplier actually used this spin. No overflow carry — it just floors at 0.
	var dealer_countdown_step: int = 3 if glitchDealerStepActive else 4 - clampi(eff_bet, 1, 3)
	dealerCountdown = maxi(0, dealerCountdown - dealer_countdown_step)
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

## Issue #155: a result is a combo-sustaining win only when it actually pays,
## except for Heart, whose guaranteed triple pays spins instead of score and still
## advances the frenzy. Flatline pairs/triples come back as winType "pair"/"triple"
## with 0 score and must break the frenzy like any miss.
func _is_winning_result(result: Dictionary) -> bool:
	var win_type := String(result["winType"])
	if win_type == "heart":
		return true
	return win_type in ["pair", "triple", "jackpot"] \
		and int(result["scoreEarned"]) > 0

# ── card-unlock tracking (issue #52) ─────────────────────────────────────────────
# The run only reports events; MetaStateStore owns the counters, the unlock rules,
# and the popup queue. The store is looked up at runtime so this script still
# compiles outside the autoload context used by the headless save checks.

func _meta_store() -> Node:
	return get_node_or_null(^"/root/MetaStateStore") if is_inside_tree() else null

func _note_card_metric(metric: String, amount := 1) -> void:
	if amount <= 0:
		return
	var meta := _meta_store()
	if meta != null:
		meta.add_card_unlock_progress(metric, amount, false)

func _note_best_card_metric(metric: String, value: int) -> void:
	var meta := _meta_store()
	if meta != null:
		meta.record_best_card_unlock_progress(metric, value, false)

## Counts one resolved spin toward the per-run card metrics. Called once per spin
## with the committed result, so powers reshaping the reveal afterwards cannot
## inflate the pair/triple tallies.
func _track_spin_card_progress(result: Dictionary) -> void:
	_note_best_card_metric(CardUnlocks.METRIC_BEST_RUN_SCORE, scoreEarned)
	# Every spin handed back counts as a recovered spin, whatever gave it: the Rewind
	# power, a vial reward, or a consumable. The metric is about spins the player got
	# back, not about which source produced them.
	_note_card_metric(CardUnlocks.METRIC_REWINDS, int(result.get("freeSpinsGranted", 0)))
	if int(result.get("scoreEarned", 0)) <= 0:
		return
	var win_type := String(result.get("winType", ""))
	if win_type == "pair":
		runPairCount += 1
		_note_best_card_metric(CardUnlocks.METRIC_PAIRS_IN_RUN, runPairCount)
		return
	if win_type != "triple" and win_type != "jackpot":
		return
	var reels: Array = result.get("reels", []) as Array
	if reels.size() < 3 or String(reels[0]) != String(reels[1]) or String(reels[1]) != String(reels[2]):
		return
	var symbol := String(reels[0])
	runTripleCounts = runTripleCounts.duplicate()
	runTripleCounts[symbol] = int(runTripleCounts.get(symbol, 0)) + 1
	_note_best_card_metric(CardUnlocks.METRIC_SAME_TRIPLE_IN_RUN, int(runTripleCounts[symbol]))

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
	lastPureWinScore = 0
	lastPureWinCoins = 0
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
	extraSpinsGranted = 0
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
	runPairCount = 0
	runTripleCounts = {}
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
	wealthTargetIndex = 0
	wealthTargetPending = false
	wealthTargetPendingValue = 0
	roundContinuationPending = false
	pacteTargetRoundVisit = false
	campaignNeuronPending = false
	augmentedTier = ""
	powersUsedThisSpin = 0
	powerRestoreCharges = EconomyConst.POWER_RESTORE_CHARGE_MAX
	pacteSeed = 0
	pacteOfferAugmentIds = null
	pacteOfferPowerIds = null
	pacteSelectedAugmentId = ""
	pacteSelectedPowerId = ""
	selectedAugmentCardIds = []
	selectedPowerCardIds = []
	ownedPowerIds = []
	pacteThresholdPending = false
	pacteThresholdOpened = false
	pacteAfterFlatlinePending = false
	pacteThresholdVisits = 0
	pacteJokerArmed = false
	pacteJokerActive = false
	winBoostEnabled = false
	winBoostCombo = 0
	glitchDealerStepActive = false
	dealerHelpSpinCount = -1
	previousSpinSnapshot = null
	rewindHistoryAvailable = false
	heartPowerArmed = false
	_commit()

## Marks the pre-run dealer shop as a resumable session without spending a
## campaign neuron. The dealer spends that neuron only when START is confirmed.
func begin_pre_run() -> void:
	if runPhase == "running":
		return
	runPhase = "pre_run"
	lastEnding = null
	campaignNeuronPending = false
	roundContinuationPending = false
	pacteTargetRoundVisit = false
	_commit()

## Closes the current machine run as a between-target break (issue #176): the
## beaten intermediate target hands off to the shared between-run dealer flow
## (odds table -> dealer shop), and the next START begins a fresh run that keeps
## the campaign progress. Uses runPhase "over" so the dealer opens in the SAME
## post-run mode a flatline uses — there is only one between-run dealer. This is
## not a death, so no campaign neuron is finalised; the next run reserves its own.
## The Wealth target has already advanced through complete_wealth_target().
func begin_target_round() -> bool:
	if runPhase != "running" and runPhase != "pacte_threshold" \
			and runPhase != "pacte_initial":
		return false
	roundContinuationPending = true
	pacteTargetRoundVisit = false
	runPhase = "over"
	lastEnding = null
	# A survived target costs no campaign health; release the run's reservation so
	# the next run re-reserves cleanly (health only drops when a run truly dies).
	campaignNeuronPending = false
	dealerIncoming = false
	dealerPending = false
	dealerOfferIds = null
	pacteThresholdPending = false
	pacteThresholdOpened = false
	pacteAfterFlatlinePending = false
	_commit()
	return true

## Restores the post-flatline between-run state after a campaign-health-crossing
## Pacte (3->2 or 2->1). The flatline already spent the neuron and set "over"; the
## Pacte selection flipped runPhase back to "running", so re-enter the shared
## odds -> dealer flow instead of the mid-run dealer offer (issue #176).
func enter_between_run_dealer_after_flatline() -> bool:
	runPhase = "over"
	lastEnding = "flatline"
	pacteTargetRoundVisit = false
	dealerIncoming = false
	dealerPending = false
	dealerOfferIds = null
	pacteThresholdPending = false
	pacteThresholdOpened = false
	pacteAfterFlatlinePending = false
	_commit()
	return int(MetaStateStore.campaignNeuronsLeft) > 0

## Folds the between-round dealer's freshly bought consumables into the run's
## carried stash, never exceeding the run slot cap.
func _merge_run_consumables(base: Dictionary, extra: Dictionary) -> Dictionary:
	var merged := base.duplicate(true)
	var cap := Consumables.MAX_CONSUMABLE_SLOTS
	for id in extra:
		var add := int(extra[id])
		while add > 0 and Consumables.total_copies(merged) < cap:
			merged[id] = int(merged.get(id, 0)) + 1
			add -= 1
	return merged

func has_resume_state() -> bool:
	if runPhase == "pre_run" or runPhase == "pacte_initial" \
			or runPhase == "pacte_threshold" or runPhase == "running":
		return true
	# A between-target break is a resumable post-run dealer visit (issue #176).
	if runPhase == "over" and roundContinuationPending:
		return true
	# A flatline remains a resumable post-run dealer visit until the player
	# starts a fresh run or gives up. Wealth exits go straight to the menu.
	return runPhase == "over" and str(lastEnding) == "flatline" \
		and int(MetaStateStore.campaignNeuronsLeft) > 0

func start_new_run(owned_permanents: Array, pending_consumables: Dictionary,
		consume_campaign_neuron := true, seed_override := -1,
		open_pacte := false) -> bool:
	if runPhase == "running" or runPhase == "pacte_initial" or runPhase == "pacte_threshold":
		return true
	# A flatline continuation stays inside the same campaign: the Pacte cards
	# picked earlier keep their effects for the whole run, not just the machine
	# scene that followed the ritual. A fresh Pacte run (open_pacte) resets them.
	var continuing_campaign := not open_pacte \
		and runPhase == "over" and str(lastEnding) == "flatline"
	# A Wealth-target round (issue #176) begins a fresh machine run but keeps the
	# campaign progress: augments/powers/consumables and the already-advanced
	# target survive, only the score and the run-spin budget reset.
	var continuing_round := not open_pacte and roundContinuationPending
	var continuing := continuing_campaign or continuing_round
	var kept_augment_cards: Array = selectedAugmentCardIds.duplicate() if continuing else []
	var kept_power_cards: Array = selectedPowerCardIds.duplicate() if continuing else []
	var kept_joker_active := pacteJokerActive if continuing else false
	var kept_pacte_threshold_visits := pacteThresholdVisits if continuing else 0
	var kept_consumables := runConsumables.duplicate(true) if continuing_round else {}
	if consume_campaign_neuron:
		if not MetaStateStore.reserve_campaign_neuron_for_run():
			_commit()
			return false
	campaignNeuronPending = consume_campaign_neuron
	startingNeurons = Economy.compute_starting_neurons(owned_permanents)
	neurons = startingNeurons
	# A claim that was made but never paid must be settled before the round rolls over,
	# not dropped by the reset below: dropping it left the overflow unbanked and the
	# target unadvanced, so the same target could be beaten again. Reaching here with
	# one outstanding means the payout screen never got its CONTINUE (the scene was
	# left, the app was closed).
	if continuing_round:
		_settle_pending_wealth_target()
	# Every run starts from zero. What a run made over its target was banked to the
	# wallet when the target was settled, so there is nothing to carry.
	scoreEarned = 0
	lucidityCoins = 0
	# The advanced target survives a round continuation, and a flatline continuation
	# resumes the campaign where it died rather than sending the player back to the
	# first target. Only a genuinely fresh run resets it.
	if not continuing:
		wealthTargetIndex = 0
	wealthTargetPending = false
	wealthTargetPendingValue = 0
	roundContinuationPending = false
	pacteTargetRoundVisit = false
	freeSpinsRemaining = 0
	maxFreeSpins = Economy.compute_max_free_spins(owned_permanents)
	lucidityMultiplier = Economy.compute_lucidity_multiplier(owned_permanents)
	nextSpinLucidityMultiplier = 1.0
	isSpinning = false
	lastResult = null
	lastPureWinScore = 0
	lastPureWinCoins = 0
	lockedReels = [false, false, false]
	lockedReelSpins = [0, 0, 0]
	# The Pacte flow replaces the pre-run shop. Legacy dealer callers still pass
	# their purchased stash, while the player-facing Pacte path starts empty. A
	# round continuation carries the run's consumables and folds in anything bought
	# at the between-round dealer, capped at the run's slot limit.
	if open_pacte:
		runConsumables = {}
	elif continuing_round:
		runConsumables = _merge_run_consumables(kept_consumables, pending_consumables)
	else:
		runConsumables = pending_consumables.duplicate(true)
	# The meta stash is a purchase order, and it has just been delivered into the run.
	# It used to be cleared only when a run banked, which no target break does — so the
	# between-round dealer re-delivered the same purchase every round and a consumable
	# the player had already used came back. Clearing it here means one purchase, one
	# delivery, whichever flow started the run.
	if not MetaStateStore.pendingConsumables.is_empty():
		MetaStateStore.pendingConsumables = {}
		MetaStateStore.save_state()
	abilitiesUsed = []
	# augmentedTier survives: the menu sets it before the pre-run dealer shop, and
	# it applies to the run this call starts (issue #111).
	powersUsedThisSpin = 0
	powerRestoreCharges = EconomyConst.POWER_RESTORE_CHARGE_MAX
	ownedUpgrades = owned_permanents.duplicate()
	selectedAugmentCardIds = kept_augment_cards
	selectedPowerCardIds = kept_power_cards
	pacteThresholdVisits = kept_pacte_threshold_visits
	# The Pacte selection is the source of run powers. A direct/legacy start keeps
	# only the permanent powers the player actually owns; Shift and Reroll are not
	# silently injected into a fresh loadout.
	ownedPowerIds = HERO_POWER_IDS.duplicate()
	if not open_pacte:
		if ownedUpgrades.has("perm_shift"):
			ownedPowerIds.append("shift")
		if ownedUpgrades.has("perm_memory"):
			ownedPowerIds.append("memory")
	pacteJokerArmed = false
	pacteJokerActive = kept_joker_active
	winBoostEnabled = false
	winBoostCombo = 0
	glitchDealerStepActive = false
	dealerHelpSpinCount = -1
	# Re-grant the kept Pacte cards: their powers rejoin the loadout and their
	# persistent augment effects re-apply for a flatline continuation.
	for card_id in kept_power_cards:
		var kept_power := PacteCards.power_id(String(card_id))
		if not ownedPowerIds.has(kept_power):
			ownedPowerIds.append(kept_power)
	for card_id in kept_augment_cards:
		var kept_effect := PacteCards.card(String(card_id)).get("effect", {}) as Dictionary
		if String(kept_effect.get("type", "")) == "owned_upgrade":
			var kept_upgrade := String(kept_effect.get("upgrade_id", ""))
			if kept_upgrade != "" and not ownedUpgrades.has(kept_upgrade):
				ownedUpgrades.append(kept_upgrade)
	_reapply_pacte_runtime_effects()
	if continuing:
		maxFreeSpins = Economy.compute_max_free_spins(ownedUpgrades)
		lucidityMultiplier = Economy.compute_lucidity_multiplier(ownedUpgrades)
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
	runPairCount = 0
	runTripleCounts = {}
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
	symbolRewardBonuses = _symbol_reward_bonuses_from_meta(ownedUpgrades)
	if open_pacte:
		chipAugmentsPurchased = {}
		symbolAugmentLevels = {}
		pairTripleAugmentChoice = ""
		extraSpinsGranted = 0
	_apply_chip_augment_run_overlay()
	pendingPowerRestores = []
	pacteSeed = seed_override if seed_override >= 0 else _seed(PACTE_INITIAL_DRAW_SEED)
	pacteOfferAugmentIds = PacteCards.draw("augment", pacteSeed,
		MetaStateStore.unlocked_augment_cards(), selectedAugmentCardIds, 3)
	pacteOfferPowerIds = PacteCards.draw("power", pacteSeed ^ 0x9e3779b9,
		MetaStateStore.unlocked_power_cards(), selectedPowerCardIds, 3)
	pacteSelectedAugmentId = ""
	pacteSelectedPowerId = ""
	pacteThresholdPending = false
	pacteThresholdOpened = false
	pacteAfterFlatlinePending = false
	previousSpinSnapshot = null
	rewindHistoryAvailable = false
	heartPowerArmed = false
	# The campaign neuron is reserved before Pacte opens, so the save is valid even
	# if the player closes the app halfway through the card ritual.
	runPhase = "pacte_initial" if open_pacte else "running"
	lastEnding = null
	wealthContinued = false
	_commit()
	return true

func pacte_active() -> bool:
	return runPhase == "pacte_initial" or runPhase == "pacte_threshold"

func current_wealth_target() -> int:
	return int(EconomyConst.WEALTH_TARGETS[clampi(wealthTargetIndex,
		0, EconomyConst.WEALTH_TARGETS.size() - 1)])

func wealth_target_due() -> bool:
	if wealthContinued:
		return false
	return wealthTargetPending or scoreEarned >= current_wealth_target()

## Claims the next target before its presentation starts. Claiming makes the
## transition resumable if the scene is closed during the animation.
func begin_wealth_target() -> Dictionary:
	if wealthContinued:
		return {}
	if wealthTargetPending:
		var pending_target := wealthTargetPendingValue if wealthTargetPendingValue > 0 \
			else current_wealth_target()
		return {
			"target": pending_target,
			"final": pending_target >= EconomyConst.WEALTH_SCORE_THRESHOLD,
		}
	var target := current_wealth_target()
	if scoreEarned < target:
		return {}
	wealthTargetPending = true
	wealthTargetPendingValue = target
	_commit()
	return {
		"target": target,
		"final": target >= EconomyConst.WEALTH_SCORE_THRESHOLD,
	}

## Pays an intermediate target out of the running score. The final target is
## intentionally not deducted: it belongs to the full-score Wealth ending.
func complete_wealth_target() -> Dictionary:
	var settled := _settle_pending_wealth_target()
	if settled.is_empty():
		return {}
	_commit()
	return settled


## The payout itself, without the commit — the money changing hands. Shared with
## start_new_run so an outstanding claim is always settled exactly once, whether the
## player pressed CONTINUE or the round rolled over without them.
##
## What the run made over the target is winnings the player walks away with, not a head
## start on the next target — so the run's score returns to zero and the overflow goes to
## the persistent wallet, minus what the casino bills for it (EconomyConst.overflow_bill).
## The bill exists because the overflow used to bank 1:1 and uncapped, which let a single
## jackpot (a flat 200) clear the 100 goal and hand over 200+ credits on one machine run.
## Banking happens here rather than at the next start_new_run because the dealer on the
## other side of the break spends that wallet, and he opens before the next run begins.
func _settle_pending_wealth_target() -> Dictionary:
	if not wealthTargetPending:
		return {}
	var target := wealthTargetPendingValue if wealthTargetPendingValue > 0 \
		else current_wealth_target()
	var final_target := target >= EconomyConst.WEALTH_SCORE_THRESHOLD
	var banked := 0
	var overflow := 0
	var bill := {}
	if not final_target:
		overflow = maxi(0, scoreEarned - target)
		bill = EconomyConst.overflow_bill(overflow, target)
		banked = int(bill["net"])
		scoreEarned = 0
		wealthTargetIndex = mini(wealthTargetIndex + 1, EconomyConst.WEALTH_TARGETS.size() - 1)
		if lastResult is Dictionary:
			var updated_result: Dictionary = (lastResult as Dictionary).duplicate(true)
			updated_result["scoreEarned"] = scoreEarned
			lastResult = updated_result
		var meta := _meta_store()
		if meta != null:
			meta.bank_wealth_target_overflow(banked)
	wealthTargetPending = false
	wealthTargetPendingValue = 0
	return {
		"target": target,
		"final": final_target,
		# What the run cleared the target by, and what survived the bill into the wallet.
		"overflow": overflow,
		"banked": banked,
		"bill": bill,
		"remaining": scoreEarned,
	}

func _pacte_threshold_available(milestone_index: int) -> bool:
	return milestone_index >= 0 and milestone_index < PACTE_WEALTH_TARGETS.size() \
		and pacteThresholdVisits <= milestone_index

## Target milestones and campaign-health crossings consume the same two Pacte
## visits. Returning false means that milestone was already consumed earlier.
func arm_pacte_for_wealth_target(target: int) -> bool:
	var milestone_index := PACTE_WEALTH_TARGETS.find(target)
	if not _pacte_threshold_available(milestone_index):
		return false
	# The visit belongs to a Wealth target, so completing it routes to the target
	# round break rather than the post-flatline dealer resume (issue #176).
	pacteTargetRoundVisit = true
	if pacteThresholdPending:
		return true
	pacteThresholdPending = true
	pacteThresholdOpened = false
	pacteAfterFlatlinePending = false
	_commit()
	return true

func _pacte_offer_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value as Array:
			result.append(String(item))
	return result

func _refresh_pacte_derivatives() -> void:
	maxFreeSpins = Economy.compute_max_free_spins(ownedUpgrades)
	lucidityMultiplier = Economy.compute_lucidity_multiplier(ownedUpgrades)
	symbolRewardBonuses = _symbol_reward_bonuses_from_meta(ownedUpgrades)

func effective_coins_per_power_restore() -> int:
	return Economy.compute_power_restore_threshold(ownedUpgrades, coins_per_power_restore)

func _reapply_pacte_runtime_effects() -> void:
	for card_id in selectedAugmentCardIds:
		var effect := PacteCards.card(String(card_id)).get("effect", {}) as Dictionary
		match String(effect.get("type", "")):
			"joker":
				pacteJokerArmed = true
			"win_boost":
				winBoostEnabled = true
			"glitch_dealer":
				glitchDealerStepActive = true

func _apply_pacte_augment(card_id: String) -> bool:
	var entry := PacteCards.card(card_id)
	if entry.is_empty() or String(entry.get("pool", "")) != "augment":
		return false
	var effect := entry.get("effect", {}) as Dictionary
	match String(effect.get("type", "")):
		"owned_upgrade":
			var upgrade_id := String(effect.get("upgrade_id", ""))
			if upgrade_id != "" and not ownedUpgrades.has(upgrade_id):
				ownedUpgrades.append(upgrade_id)
		"joker":
			# Joker is armed by the card and activates only after the first
			# three-flatline strike in this run.
			pacteJokerArmed = true
		"win_boost":
			winBoostEnabled = true
			winBoostCombo = 0
		"glitch_dealer":
			glitchDealerStepActive = true
		_:
			return false
	_refresh_pacte_derivatives()
	return true

func select_pacte_augment(card_id: String) -> bool:
	if not pacte_active() or pacteSelectedAugmentId != "":
		return false
	if not _pacte_offer_array(pacteOfferAugmentIds).has(card_id) \
			or selectedAugmentCardIds.has(card_id):
		return false
	pacteSelectedAugmentId = card_id
	_commit()
	return true

func complete_pacte_selection(augment_id: String, power_id: String) -> bool:
	if not pacte_active():
		return false
	var augment_card_id := augment_id if augment_id != "" else pacteSelectedAugmentId
	var power_card_id := power_id if power_id != "" else pacteSelectedPowerId
	power_card_id = PacteCards.normalise_card_id(power_card_id)
	if augment_card_id == "" or power_card_id == "":
		return false
	if not _pacte_offer_array(pacteOfferAugmentIds).has(augment_card_id) \
			or not _pacte_offer_array(pacteOfferPowerIds).has(power_card_id):
		return false
	if selectedAugmentCardIds.has(augment_card_id) or selectedPowerCardIds.has(power_card_id):
		return false
	if not _apply_pacte_augment(augment_card_id):
		return false
	var runtime_power_id := PacteCards.power_id(power_card_id)
	selectedAugmentCardIds = selectedAugmentCardIds.duplicate()
	selectedAugmentCardIds.append(augment_card_id)
	selectedPowerCardIds = selectedPowerCardIds.duplicate()
	selectedPowerCardIds.append(power_card_id)
	ownedPowerIds = ownedPowerIds.duplicate()
	if not ownedPowerIds.has(runtime_power_id):
		ownedPowerIds.append(runtime_power_id)
	pacteSelectedAugmentId = ""
	pacteSelectedPowerId = ""
	pacteOfferAugmentIds = null
	pacteOfferPowerIds = null
	if runPhase == "pacte_threshold":
		pacteThresholdVisits = mini(pacteThresholdVisits + 1, PACTE_CAMPAIGN_NEURON_THRESHOLDS.size())
		pacteThresholdPending = false
		pacteThresholdOpened = false
		pacteAfterFlatlinePending = false
		lastEnding = null
	runPhase = "running"
	_refresh_pacte_derivatives()
	_commit()
	return true

func stage_pacte_power_selection(card_id: String) -> bool:
	if not pacte_active() or pacteSelectedAugmentId == "":
		return false
	var normalised := PacteCards.normalise_card_id(card_id)
	if not _pacte_offer_array(pacteOfferPowerIds).has(normalised) \
			or selectedPowerCardIds.has(normalised):
		return false
	pacteSelectedPowerId = normalised
	_commit()
	return complete_pacte_selection("", normalised)

func open_threshold_pacte() -> bool:
	var post_flatline_visit: bool = runPhase == "over" and lastEnding == "flatline" \
		and pacteAfterFlatlinePending
	if (runPhase != "running" and not post_flatline_visit) \
			or not pacteThresholdPending or pacteThresholdOpened:
		return false
	# A countdown offer may have arrived on the same reveal as the target. Keep
	# that offer pending so Pacte completion can hand off to its dealer scene.
	if runPhase == "running" and dealerIncoming:
		reveal_dealer()
	var draw_seed := (pacteSeed ^ PACTE_THRESHOLD_DRAW_SEED ^ (spinCount * 0x9e3779b9)) & M32
	pacteOfferAugmentIds = PacteCards.draw("augment", draw_seed,
		MetaStateStore.unlocked_augment_cards(), selectedAugmentCardIds, 3)
	pacteOfferPowerIds = PacteCards.draw("power", draw_seed ^ 0x9e3779b9,
		MetaStateStore.unlocked_power_cards(), selectedPowerCardIds, 3)
	pacteSelectedAugmentId = ""
	pacteSelectedPowerId = ""
	pacteThresholdOpened = true
	pacteAfterFlatlinePending = false
	runPhase = "pacte_threshold"
	_commit()
	return true

## A deterministic fallback used by direct scene smoke setup and accessibility
## automation. A real player always makes these choices in Pacte's card UI.
func skip_pacte_with_defaults() -> bool:
	if not pacte_active():
		return false
	var augment_offers := _pacte_offer_array(pacteOfferAugmentIds)
	var power_offers := _pacte_offer_array(pacteOfferPowerIds)
	if augment_offers.is_empty() or power_offers.is_empty():
		return false
	return complete_pacte_selection(augment_offers[0], power_offers[0])

## Opens the full dealer scene after the threshold Pacte visit. This uses the same
## deterministic offer paths as an automatic machine interruption.
func force_dealer_visit() -> bool:
	if runPhase != "running" or dealerIncoming:
		return false
	if dealerPending:
		return dealerOfferIds is Array and not (dealerOfferIds as Array).is_empty()
	var offers: Variant = Dealer.pick_pool_offer(InRunItems.ids(),
			_seed(spinCount * 0x6b43c7f + 0x168), dealer_offer_count())
	if offers == null:
		return false
	dealerCount += 1
	dealerLastSpinCount = spinCount
	dealerOfferIds = offers
	dealerAugmentOfferId = _roll_augment_offer(_seed(spinCount * 0x51c4a9 + 0xa06))
	dealerPending = true
	dealerCountdown = 0
	_commit()
	return true

## Prepares the full dealer scene for a milestone handoff. A countdown-triggered
## offer may already be incoming; reveal that same offer instead of creating a
## second visit.
func prepare_dealer_scene_visit() -> bool:
	if runPhase != "running":
		return false
	if dealerIncoming:
		reveal_dealer()
	if dealerPending:
		return dealerOfferIds is Array and not (dealerOfferIds as Array).is_empty()
	return force_dealer_visit()

func end_run(ending: String) -> void:
	var campaign_neuron_before := int(MetaStateStore.campaignNeuronsLeft)
	var consumed_campaign_neuron := campaignNeuronPending
	runPhase = "over"
	lastEnding = ending
	if ending == "game_over":
		# A terminal campaign loss removes the run's remaining credits instead of
		# carrying the normal flatline retention into the next campaign.
		lucidityCoins = 0
	if campaignNeuronPending:
		MetaStateStore.finalize_campaign_neuron_for_run()
		campaignNeuronPending = false
	# Threshold Pacte visits belong to the campaign-neuron count, not to the
	# machine's run-spin counter. Arm a visit whenever a flatline crosses one of
	# the campaign thresholds (3 -> 2 or 2 -> 1), unless that visit was already
	# consumed by the matching Wealth target.
	var campaign_neurons_after := int(MetaStateStore.campaignNeuronsLeft)
	var crossed_pacte_threshold := -1
	if ending == "flatline" and consumed_campaign_neuron and campaign_neurons_after > 0:
		for milestone_index: int in range(PACTE_CAMPAIGN_NEURON_THRESHOLDS.size()):
			var threshold := int(PACTE_CAMPAIGN_NEURON_THRESHOLDS[milestone_index])
			if campaign_neuron_before > threshold and campaign_neurons_after <= threshold:
				crossed_pacte_threshold = milestone_index
				break
	if _pacte_threshold_available(crossed_pacte_threshold):
		pacteThresholdPending = true
		pacteThresholdOpened = false
		pacteAfterFlatlinePending = true
		# A health crossing resumes the post-flatline dealer, not a target round.
		pacteTargetRoundVisit = false
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
## only matters on the non-fatal strikes that leave the player still spinning. The
## Pacte Joker unlocks its dealer-help effect on the first such strike.
func register_flatline_result() -> int:
	flatlineResultCount += 1
	flatlineWinBoostArmed = true
	if pacteJokerArmed:
		pacteJokerActive = true
	_commit()
	return flatlineResultCount

func _dealer_help_rank(outcome: Dictionary) -> int:
	if outcome.is_empty():
		return -1000000
	var score_delta := int(outcome.get("scoreDelta", 0))
	if score_delta <= 0:
		return -1000000
	var win_type := String(outcome.get("winType", ""))
	var win_rank := 3 if win_type == "jackpot" else (2 if win_type == "triple" else 1)
	return score_delta * 100 + int(outcome.get("coinsDelta", 0)) + win_rank

func _dealer_help_rescore(reels: Array, reel_index: int, symbol: String) -> Dictionary:
	var book_weight := Economy.compute_book_weight(ownedUpgrades)
	var pair_boost_active := pairBoostSpins > 0
	return Abilities.apply_cheat(reels, reel_index, symbol,
		float(lastResult.get("scoreMultiplier", 1.0)),
		Economy.has_pattern23_triple(ownedUpgrades), book_weight > 0,
		not bool(lastResult.get("isFreeSpin", false)),
		_pair_score_multiplier(pair_boost_active),
		_active_hidden_reel_count(pair_boost_active), Economy.has_hallucination(ownedUpgrades),
		_active_reward_scale(), symbolRewardBonuses, Economy.has_solo_as_pair(ownedUpgrades),
		_book_reward_scale())

func _dealer_help_cheat(reels: Array) -> Dictionary:
	var symbols: Array[String] = []
	for raw_symbol in Symbols.BASE_SYMBOL_CYCLE:
		symbols.append(String(raw_symbol))
	if Economy.compute_book_weight(ownedUpgrades) > 0:
		symbols.append("book")
	var best: Dictionary = {}
	var best_rank := -1000000
	var best_reel := -1
	var best_symbol := ""
	for reel_index in reels.size():
		if bool(lockedReels[reel_index]):
			continue
		for symbol in symbols:
			if symbol == String(reels[reel_index]):
				continue
			var outcome := _dealer_help_rescore(reels, reel_index, symbol)
			var rank := _dealer_help_rank(outcome)
			if rank > best_rank:
				best = outcome
				best_rank = rank
				best_reel = reel_index
				best_symbol = symbol
	if best_reel < 0:
		return {}
	return { "outcome": best, "reel": best_reel, "symbol": best_symbol }

func _dealer_help_shift(reels: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_rank := -1000000
	var best_reel := -1
	var best_direction := 0
	for reel_index in reels.size():
		if bool(lockedReels[reel_index]):
			continue
		for direction in [-1, 1]:
			var outcome := Abilities.apply_move_column(reels, reel_index, direction,
				float(lastResult.get("scoreMultiplier", 1.0)),
				Economy.has_pattern23_triple(ownedUpgrades),
				Economy.compute_book_weight(ownedUpgrades) > 0,
				not bool(lastResult.get("isFreeSpin", false)),
				_pair_score_multiplier(pairBoostSpins > 0),
				_active_hidden_reel_count(pairBoostSpins > 0), Economy.has_hallucination(ownedUpgrades),
				_active_reward_scale(), symbolRewardBonuses, Economy.has_solo_as_pair(ownedUpgrades),
				_book_reward_scale())
			var rank := _dealer_help_rank(outcome)
			if rank > best_rank:
				best = outcome
				best_rank = rank
				best_reel = reel_index
				best_direction = direction
	if best_reel < 0:
		return {}
	return { "outcome": best, "reel": best_reel, "direction": best_direction }

func _dealer_help_reroll(reels: Array) -> Dictionary:
	var brain_bonus := Economy.compute_brain_weight_bonus(ownedUpgrades)
	if brainBoostSpins > 0:
		brain_bonus += int(Symbols.WEIGHT["brain"]) * 4
	var book_weight := Economy.compute_book_weight(ownedUpgrades)
	var weights := _weights_with_bonuses(brain_bonus, book_weight)
	var candidates := Abilities.random_candidate_weights(weights, "")
	var best: Dictionary = {}
	var best_rank := -1000000
	var best_reel := -1
	var best_symbol := ""
	for reel_index in reels.size():
		if bool(lockedReels[reel_index]):
			continue
		var current_symbol := String(reels[reel_index])
		for raw_candidate in candidates:
			var candidate := raw_candidate as Dictionary
			var symbol := String(candidate.get("value", ""))
			if symbol == current_symbol:
				continue
			var outcome := _dealer_help_rescore(reels, reel_index, symbol)
			var rank := _dealer_help_rank(outcome)
			if rank > best_rank:
				best = outcome
				best_rank = rank
				best_reel = reel_index
				best_symbol = symbol
	if best_reel < 0:
		return {}
	var selected_weights: Array = [{ "value": best_symbol, "weight": 1.0 }]
	var reroll_outcome := Abilities.apply_reroll(reels, best_reel,
		LobRNG.new((pacteSeed ^ spinCount * 0x5bd1e995 ^ 0x4a4f4b45) & M32),
		float(lastResult.get("scoreMultiplier", 1.0)), selected_weights,
		Economy.has_pattern23_triple(ownedUpgrades), book_weight > 0,
		not bool(lastResult.get("isFreeSpin", false)),
		_pair_score_multiplier(pairBoostSpins > 0),
		_active_hidden_reel_count(pairBoostSpins > 0), Economy.has_hallucination(ownedUpgrades),
		_active_reward_scale(), symbolRewardBonuses, Economy.has_solo_as_pair(ownedUpgrades),
		_book_reward_scale())
	return { "outcome": reroll_outcome, "reel": best_reel, "symbol": best_symbol }

func _dealer_help_lock(reels: Array, rng: LobRNG) -> Dictionary:
	var available: Array[int] = []
	for reel_index in reels.size():
		if not bool(lockedReels[reel_index]):
			available.append(reel_index)
	if available.is_empty():
		return {}
	var chosen := available[0]
	for reel_index in available:
		if (reels[reel_index] == reels[(reel_index + 1) % reels.size()]) \
				or (reels[reel_index] == reels[(reel_index + reels.size() - 1) % reels.size()]):
			chosen = reel_index
			break
	if chosen == available[0] and available.size() > 1 and rng.next() > 0.5:
		chosen = available[mini(available.size() - 1, floori(rng.next() * available.size()))]
	var locks := lockedReels.duplicate()
	var spins := lockedReelSpins.duplicate()
	locks[chosen] = true
	spins[chosen] = 2
	lockedReels = locks
	lockedReelSpins = spins
	if eyeRevealReel == chosen:
		eyeRevealReel = -1
		eyeRevealSymbol = ""
	return { "reel": chosen }

func _mark_dealer_help(power_id: String, reel_index: int, symbol := "") -> Dictionary:
	var marked_result := (lastResult as Dictionary).duplicate(true)
	marked_result["dealerHelpPower"] = power_id
	marked_result["dealerHelpReel"] = reel_index
	if symbol != "":
		marked_result["dealerHelpSymbol"] = symbol
	lastResult = marked_result
	dealerHelpSpinCount = spinCount
	_commit()
	return {
		"power": power_id,
		"reel": reel_index,
		"symbol": symbol,
		"reels": (marked_result["reels"] as Array).duplicate(),
	}

## Joker's dealer help is a deterministic occasional assist. It evaluates the
## helpful symbol/direction before applying it, never adds the dealer's power to
## abilitiesUsed, and never increments the player's per-spin power-use counter.
func maybe_dealer_help() -> Dictionary:
	if not pacteJokerActive or runPhase != "running" or isSpinning or lastResult == null \
			or dealerIncoming or dealerPending or compulsiveSpinSkips > 0 \
			or dealerHelpSpinCount == spinCount:
		return {}
	var rng := LobRNG.new((pacteSeed ^ spinCount * 0x6d2b79f5 ^ 0x4a4f4b45) & M32)
	if rng.next() >= JOKER_DEALER_HELP_CHANCE:
		dealerHelpSpinCount = spinCount
		_commit()
		return {}
	var reels := (lastResult["reels"] as Array).duplicate()
	var start := floori(rng.next() * JOKER_DEALER_HELP_POWERS.size())
	for offset in JOKER_DEALER_HELP_POWERS.size():
		var power_id := JOKER_DEALER_HELP_POWERS[(start + offset) % JOKER_DEALER_HELP_POWERS.size()]
		var selection: Dictionary = {}
		match power_id:
			"cheat":
				selection = _dealer_help_cheat(reels)
			"shift":
				selection = _dealer_help_shift(reels)
			"reroll":
				selection = _dealer_help_reroll(reels)
			"memory":
				selection = _dealer_help_lock(reels, rng)
		if selection.is_empty():
			continue
		if power_id == "memory":
			return _mark_dealer_help(power_id, int(selection["reel"]))
		var outcome := selection.get("outcome", {}) as Dictionary
		if outcome.is_empty():
			continue
		var reel_index := int(selection.get("reel", -1))
		var symbol := String(selection.get("symbol", ""))
		if power_id == "shift":
			# The chosen shift outcome already contains the best direction; keep the
			# direction in the result for a possible presentation/debug overlay.
			var shift_result := _apply_dealer_help_outcome(outcome, power_id, reel_index)
			shift_result["direction"] = int(selection.get("direction", 0))
			return shift_result
		return _apply_dealer_help_outcome(outcome, power_id, reel_index, symbol)
	dealerHelpSpinCount = spinCount
	_commit()
	return {}

func _apply_dealer_help_outcome(outcome: Dictionary, power_id: String,
		reel_index: int, symbol := "") -> Dictionary:
	if outcome.is_empty() or lastResult == null:
		return {}
	_apply_outcome(outcome, abilitiesUsed.duplicate(),
		(pacteSeed ^ spinCount * 0x165667b1 ^ 0x4445414c) & M32,
		[reel_index] if reel_index >= 0 else [])
	return _mark_dealer_help(power_id, reel_index, symbol)

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
	neurons = mini(_neuron_cap(), neurons + count * decay)
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
	return Lucidity.plan_gain(prev_coins, gain, abilities, seed,
		effective_coins_per_power_restore(), restore_budget_left())

## How many more powers the score economy may bring back right now. The power gauge reads
## this too: with no charge left it stops one frame short of full instead of completing,
## the same as having no spent power to give back.
func restore_budget_left() -> int:
	return clampi(powerRestoreCharges, 0, EconomyConst.POWER_RESTORE_CHARGE_MAX)

## Spend charges on score-driven restores. Called with the size of a plan's restore list,
## so a plan that gave nothing back costs nothing.
func _spend_restore_budget(count: int) -> void:
	if count <= 0:
		return
	powerRestoreCharges = maxi(0, restore_budget_left() - count)

## One charge back per spin launched (never past the cap): the restore economy refills
## with play rather than resetting whole, so a spin cannot repeat the previous spin's
## double restore.
func _recharge_restores() -> void:
	powerRestoreCharges = mini(EconomyConst.POWER_RESTORE_CHARGE_MAX,
		restore_budget_left() + EconomyConst.POWER_RESTORE_RECHARGE_PER_SPIN)

func commit_power_restore(power_id: String) -> void:
	var idx := pendingPowerRestores.find(power_id)
	if idx < 0:
		return
	pendingPowerRestores.remove_at(idx)
	_commit()

## Bar-driven restore (issue #76 follow-up): when the power gauge fills and no plan_gain
## restore is queued, it restores one spent ability directly — random pick removed from
## abilitiesUsed so its button re-enables. Same selection shape as Lucidity.plan_gain.
## Returns the restored id ("" if nothing is spent, or the per-spin cap is used up).
func bar_restore_power(seed: int) -> String:
	if abilitiesUsed.is_empty() or restore_budget_left() <= 0:
		return ""
	var rng := LobRNG.new(seed & M32)
	var idx := mini(abilitiesUsed.size() - 1, floori(rng.next() * abilitiesUsed.size()))
	var id := String(abilitiesUsed[idx])
	abilitiesUsed = abilitiesUsed.duplicate()
	abilitiesUsed.remove_at(idx)
	_spend_restore_budget(1)
	_commit()
	return id

# ── abilities ──────────────────────────────────────────────────────────────────────

# Reroll draws share the spin's weight pipeline, so purchased odds (issue #36)
# apply to every draw of the run — delegating keeps the two paths identical.
func _weights_with_bonuses(brain_bonus: int, book_weight: int) -> Array:
	return Evaluate._build_weights(brain_bonus, book_weight, oddsWeightOverrides)

func _active_hidden_reel_count(pair_boost_active: bool) -> int:
	var hidden := pairBoostHiddenReels if pair_boost_active else 0
	if Economy.has_tunnel_vision(ownedUpgrades):
		hidden = maxi(hidden, 1)
	return clampi(hidden, 0, 2)

func _active_reward_scale() -> float:
	var scale := Economy.compute_hallucination_reward_scale(ownedUpgrades) \
		* Economy.compute_tunnel_vision_reward_scale(ownedUpgrades)
	# Augmented club modifier (issue #111): all spin rewards/gains are halved.
	if augmented_modifier_active(4):
		scale *= 0.5
	return scale

## Learning's cut is NOT part of the general scale: it is charged only to wins the Book
## joker actually made, so a spin that never saw a book pays in full. The scorer applies
## it on top of _active_reward_scale inside its joker branch.
func _book_reward_scale() -> float:
	return Economy.compute_book_reward_scale(ownedUpgrades)

func _pair_score_multiplier(pair_boost_active: bool) -> float:
	var multiplier := Economy.compute_pair_score_multiplier(ownedUpgrades)
	if pair_boost_active:
		multiplier *= float(pairBoostMult)
	return multiplier

func _passive_lucidity_per_spin() -> int:
	var passive := Economy.compute_passive_lucidity(ownedUpgrades)
	if augmented_modifier_active(4):
		passive = floori(float(passive) * 0.5 + 0.5)
	return passive

## The reels a scored result is actually made of — the symbols the payout is for. Used to
## tell a power that formed a NEW combination from one that merely left an existing win
## standing: changing the odd reel out of a pair pays nothing, because the pair on the other
## two reels is the same pair that already paid.
func _winning_reel_indices(result: Dictionary) -> Array[int]:
	var reels: Array = result.get("reels", [])
	if reels.size() < 3:
		return []
	var win := String(result.get("winType", ""))
	if win == "" or win == "miss":
		return []
	# A book stands in for the symbol it resolved to, so the reel holding it is part of the
	# combination it completed.
	var resolved := String(result.get("resolvedSymbol", ""))
	if bool(result.get("bookJoker", false)) and resolved != "":
		var joined: Array[int] = []
		for i in 3:
			if String(reels[i]) == resolved or String(reels[i]) == "book":
				joined.append(i)
		return joined
	if bool(result.get("soloAsPair", false)):
		var solo := String(result.get("soloAsPairSymbol", ""))
		for i in 3:
			if String(reels[i]) == solo:
				return [i]
		return []
	var a := String(reels[0])
	var b := String(reels[1])
	var c := String(reels[2])
	if a == b and b == c:
		return [0, 1, 2]
	if a == b:
		return [0, 1]
	if b == c:
		return [1, 2]
	if a == c:
		return [0, 2] # Pattern 23
	return []


## Did a power form a combination the run has not already been paid for? True when it
## touched at least one of the winning reels — a reroll that lands the same pair counts,
## because that symbol was played again — and false when the win it leaves behind sits
## entirely on reels the power never touched.
func _forms_new_combination(after: Dictionary, acted_reels: Array) -> bool:
	if acted_reels.is_empty():
		return true # caller did not say what it touched (heart, dealer help without a reel)
	var win_reels := _winning_reel_indices(after)
	if win_reels.is_empty():
		return true # nothing standing; the normal (possibly negative) delta path applies
	for reel in acted_reels:
		if win_reels.has(int(reel)):
			return true
	return false


func _apply_outcome(outcome: Dictionary, marked_used: Array, seed: int,
		acted_reels: Array = []) -> void:
	var flatline_boost_bonus := 0
	var flatline_boost_applied := false
	var win_boost_bonus := 0
	var win_boost_percent := 0
	var win_boost_combo := 0
	var win_boost_applied := false
	var outcome_win_type := String(outcome.get("winType", ""))
	# Abilities report the difference between the reels before and after, because a
	# rescore replaces one combination with another. The run pays additively instead:
	# a combination the player already won is never taken back, and whatever a power
	# forms pays on top of it. So the delta is turned back into the new combination's
	# own value, which is also what the boosts below take their cut of.
	# ...but only for a combination the run has not been paid for yet: a power that changes a
	# reel the win does not use leaves the same win standing, and that pays nothing.
	var new_combination := _forms_new_combination(outcome, acted_reels)
	var win_score := 0
	var win_coins := 0
	if new_combination:
		win_score = maxi(0, lastPureWinScore + int(outcome.get("scoreDelta", 0)))
		win_coins = maxi(0, lastPureWinCoins + int(outcome.get("coinsDelta", 0)))
		lastPureWinScore = win_score
		lastPureWinCoins = win_coins
	outcome = outcome.duplicate(true)
	outcome["scoreDelta"] = win_score
	outcome["coinsDelta"] = win_coins
	if flatlineWinBoostArmed and win_score > 0 \
			and outcome_win_type in ["pair", "triple", "jackpot"]:
		flatline_boost_bonus = win_score * (EconomyConst.FLATLINE_WIN_BOOST_MULT - 1)
		flatline_boost_applied = true
		outcome["scoreDelta"] = int(outcome["scoreDelta"]) + flatline_boost_bonus
		outcome["coinsDelta"] = int(outcome["coinsDelta"]) + flatline_boost_bonus
	if winBoostEnabled and int(outcome.get("scoreDelta", 0)) > 0 \
			and outcome_win_type in ["pair", "triple", "jackpot"]:
		var boost_step := clampi(winBoostCombo + 1, 1, 9)
		win_boost_combo = boost_step
		win_boost_percent = roundi(float(WIN_BOOST_RATES[boost_step]) * 100.0)
		win_boost_bonus = floori(float(int(outcome["scoreDelta"])) \
			* WIN_BOOST_RATES[boost_step] + 0.5)
		win_boost_applied = true
		if win_boost_bonus > 0:
			outcome["scoreDelta"] = int(outcome["scoreDelta"]) + win_boost_bonus
			outcome["coinsDelta"] = int(outcome["coinsDelta"]) + win_boost_bonus
	var plan := Lucidity.plan_gain(lucidityCoins, int(outcome["coinsDelta"]), marked_used, seed,
		effective_coins_per_power_restore(), restore_budget_left())
	# The cap only tops up, it never cuts: banked spins above maxFreeSpins
	# (vial/tea rewards, issue #66) survive power use.
	var free_after := mini(freeSpinsRemaining + int(outcome["freeSpinsGranted"]),
		maxi(freeSpinsRemaining, maxFreeSpins))
	abilitiesUsed = plan["abilitiesUsed"]
	# Additive and never negative: the score cannot go down because a power reshaped
	# the reels into something worth less than what was already won.
	scoreEarned = maxi(0, scoreEarned + maxi(0, int(outcome["scoreDelta"])))
	lucidityCoins = int(plan["lucidityCoins"])
	pendingPowerRestores.append_array(plan["restores"])
	_spend_restore_budget((plan["restores"] as Array).size())
	_note_card_metric(CardUnlocks.METRIC_POWER_RESTORES, (plan["restores"] as Array).size())
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
	if outcome.has("soloAsPair"):
		lr["soloAsPair"] = true
		lr["soloAsPairSymbol"] = String(outcome.get("soloAsPairSymbol", ""))
	else:
		lr.erase("soloAsPair")
		lr.erase("soloAsPairSymbol")
	# The presentation layer reads this to keep its reactions (flatline strikes, triple
	# bonuses) on new combinations only, exactly like the payout above.
	if new_combination:
		lr.erase("combinationReplayed")
	else:
		lr["combinationReplayed"] = true
	lr["scoreEarned"] = maxi(0, int(lastResult["scoreEarned"]) + int(outcome["scoreDelta"]))
	lr["coinsEarned"] = maxi(0, int(lastResult["coinsEarned"]) + int(outcome["coinsDelta"]))
	if flatline_boost_applied:
		lr["flatlineBoostApplied"] = true
		lr["flatlineBoostBonus"] = flatline_boost_bonus
	else:
		lr.erase("flatlineBoostApplied")
		lr.erase("flatlineBoostBonus")
	if win_boost_applied:
		lr["winBoostApplied"] = true
		lr["winBoostPercent"] = win_boost_percent
		lr["winBoostBonus"] = win_boost_bonus
		lr["winBoostCombo"] = win_boost_combo
		lr["winBoostBaseScore"] = maxi(0, int(outcome.get("scoreDelta", 0)) - win_boost_bonus)
	else:
		lr.erase("winBoostApplied")
		lr.erase("winBoostPercent")
		lr.erase("winBoostBonus")
		lr.erase("winBoostCombo")
		lr.erase("winBoostBaseScore")
	# Spins a power's reshaped result hands back count as recovered spins too.
	var power_spins_granted := free_after - freeSpinsRemaining
	lr["freeSpinsGranted"] = int(lastResult["freeSpinsGranted"]) + power_spins_granted
	lr["freeSpinsAfter"] = free_after
	freeSpinsRemaining = free_after
	_note_card_metric(CardUnlocks.METRIC_REWINDS, power_spins_granted)
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
	if winBoostEnabled and int(outcome.get("scoreDelta", 0)) > 0 \
			and outcome_win_type in ["pair", "triple", "jackpot"]:
		winBoostCombo = mini(9, winBoostCombo + 1)
	elif winBoostEnabled and outcome_win_type != "heart" and not comboDefeatPending \
			and new_combination:
		# A power that only left an existing win standing neither extends the streak nor
		# breaks it — nothing was played.
		winBoostCombo = 0
	if flatline_boost_applied:
		flatlineWinBoostArmed = false

func _apply_revealed_power_outcome(outcome: Dictionary, power_id: String,
		seed: int, neuron_delta: int = 0, acted_reels: Array = []) -> bool:
	if outcome.is_empty() or lastResult == null:
		return false
	var marked := abilitiesUsed.duplicate()
	marked.append(power_id)
	powersUsedThisSpin += 1
	_apply_outcome(outcome, marked, seed, acted_reels)
	if neuron_delta != 0:
		neurons = mini(_neuron_cap(), neurons + neuron_delta)
	lastPowerFailureReason = ""
	_commit()
	return true

func reroll_reel(reel_index: int) -> bool:
	if not _can_use_ability() or lastResult == null or not has_power("reroll"):
		return false
	if reel_index < 0 or reel_index >= (lastResult["reels"] as Array).size():
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
		_pair_score_multiplier(pair_boost_active),
		hidden_reel_count, Economy.has_hallucination(ownedUpgrades), _active_reward_scale(),
		symbolRewardBonuses, Economy.has_solo_as_pair(ownedUpgrades), _book_reward_scale())
	var marked := abilitiesUsed.duplicate()
	marked.append("reroll")
	powersUsedThisSpin += 1
	_apply_outcome(outcome, marked, seed, [reel_index])
	_commit()
	return true

func move_reel(reel_index: int, direction: int) -> bool:
	if not _can_use_ability() or lastResult == null:
		return false
	if not has_power("shift"):
		return false
	if abilitiesUsed.has("shift"):
		return false
	var book_w := Economy.compute_book_weight(ownedUpgrades)
	var pair_boost_active := pairBoostSpins > 0
	var hidden_reel_count := _active_hidden_reel_count(pair_boost_active)
	var outcome := Abilities.apply_move_column(lastResult["reels"], reel_index, direction, float(lastResult["scoreMultiplier"]),
		Economy.has_pattern23_triple(ownedUpgrades), book_w > 0, not bool(lastResult["isFreeSpin"]),
		_pair_score_multiplier(pair_boost_active),
		hidden_reel_count, Economy.has_hallucination(ownedUpgrades), _active_reward_scale(),
		symbolRewardBonuses, Economy.has_solo_as_pair(ownedUpgrades), _book_reward_scale())
	var seed := _seed(spinCount * 0x27d4eb2f + reel_index)
	var marked := abilitiesUsed.duplicate()
	marked.append("shift")
	powersUsedThisSpin += 1
	_apply_outcome(outcome, marked, seed, [reel_index])
	if lastResult is Dictionary and _is_winning_result(lastResult as Dictionary):
		_note_card_metric(CardUnlocks.METRIC_SHIFT_WINS)
	_commit()
	return true

func lock_reel(reel_index: int) -> void:
	if not _can_use_ability():
		return
	if not has_power("memory"):
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
		_pair_score_multiplier(pair_boost_active),
		hidden_reel_count, Economy.has_hallucination(ownedUpgrades), _active_reward_scale(),
		symbolRewardBonuses, Economy.has_solo_as_pair(ownedUpgrades), _book_reward_scale())

	var seed := _seed(spinCount * 0x165667b1)
	powersUsedThisSpin += 1
	# Copy writes into the target reel; the source is only read, so it is not "played".
	_apply_outcome(outcome, abilitiesUsed.duplicate(), seed, [target_reel])
	_commit()
	return true

func heart_power(_heart_count: int = -1) -> bool:
	if not _can_use_ability() or lastResult == null \
			or not has_power("heart") or abilitiesUsed.has("heart") \
			or heartPowerArmed:
		return false
	# Heart is also a combo-loss rescue: it does not alter the current reveal, but
	# replaces the pending decline with a guaranteed winning next spin. Keep the
	# current gauge value so that the heart result advances it exactly one step.
	if comboDefeatPending:
		comboDefeatPending = false
		pendingComboMultiplier = 1
	# The power is a preparation action. The next lever pull selects one of the
	# three heart symbols and resolves its matching +1/+2/+3 spin, with no score.
	heartPowerArmed = true
	abilitiesUsed = abilitiesUsed.duplicate()
	abilitiesUsed.append("heart")
	powersUsedThisSpin += 1
	lastPowerFailureReason = ""
	_commit()
	return true

func use_heart_power(heart_count: int = -1) -> bool:
	return heart_power(heart_count)

func cheat_symbol(reel_index: int, symbol: String) -> bool:
	if not _can_use_ability() or lastResult == null or not has_power("cheat") \
			or abilitiesUsed.has("cheat"):
		return false
	var valid_symbols: Array = Symbols.BASE_SYMBOL_CYCLE.duplicate()
	if Economy.compute_book_weight(ownedUpgrades) > 0:
		valid_symbols.append("book")
	if not valid_symbols.has(symbol):
		return false
	var reels: Array = lastResult["reels"] as Array
	var pair_boost_active := pairBoostSpins > 0
	var hidden_reel_count := _active_hidden_reel_count(pair_boost_active)
	var outcome := Abilities.apply_cheat(reels, reel_index, symbol,
			float(lastResult["scoreMultiplier"]), Economy.has_pattern23_triple(ownedUpgrades),
			Economy.compute_book_weight(ownedUpgrades) > 0, not bool(lastResult["isFreeSpin"]),
			_pair_score_multiplier(pair_boost_active), hidden_reel_count,
			Economy.has_hallucination(ownedUpgrades), _active_reward_scale(), symbolRewardBonuses,
			Economy.has_solo_as_pair(ownedUpgrades), _book_reward_scale())
	var cheated := _apply_revealed_power_outcome(outcome, "cheat",
			_seed(spinCount * 0x165667b1 + reel_index), 0, [reel_index])
	if cheated:
		_note_card_metric(CardUnlocks.METRIC_CHEATS_USED)
	return cheated

func swap_symbol(source_reel: int, target_reel: int, source_symbol: String = "") -> bool:
	if not _can_use_ability() or lastResult == null or not has_power("swap") \
			or abilitiesUsed.has("swap") or source_reel == target_reel:
		return false
	var reels: Array = lastResult["reels"] as Array
	var pair_boost_active := pairBoostSpins > 0
	var hidden_reel_count := _active_hidden_reel_count(pair_boost_active)
	var outcome := Abilities.apply_swap_symbol(reels, source_reel, target_reel,
			float(lastResult["scoreMultiplier"]), Economy.has_pattern23_triple(ownedUpgrades),
			Economy.compute_book_weight(ownedUpgrades) > 0, not bool(lastResult["isFreeSpin"]),
			_pair_score_multiplier(pair_boost_active), hidden_reel_count,
			Economy.has_hallucination(ownedUpgrades), _active_reward_scale(), symbolRewardBonuses,
			source_symbol, Economy.has_solo_as_pair(ownedUpgrades), _book_reward_scale())
	return _apply_revealed_power_outcome(outcome, "swap",
			_seed(spinCount * 0x27d4eb2f + source_reel * 7 + target_reel), 0,
			[source_reel, target_reel])

func cheat_reel(reel_index: int, symbol: String) -> bool:
	return cheat_symbol(reel_index, symbol)

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
	_note_card_metric(CardUnlocks.METRIC_CONSUMABLES_USED)
	runConsumables = runConsumables.duplicate(true)
	# Spending the last charge drops the entry rather than leaving a zero behind, the
	# same way discarding does. A spent stack is gone, not an empty slot that rides
	# along into the next round's stash.
	if charges <= 1:
		runConsumables.erase(consumable_id)
	else:
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
				var plan := Lucidity.plan_gain(lucidityCoins, int(e["amount"]), abilitiesUsed,
					_seed(spinCount * 0x2545f491), effective_coins_per_power_restore(),
					restore_budget_left())
				lucidityCoins = int(plan["lucidityCoins"])
				abilitiesUsed = plan["abilitiesUsed"]
				pendingPowerRestores.append_array(plan["restores"])
				_spend_restore_budget((plan["restores"] as Array).size())
				_note_card_metric(CardUnlocks.METRIC_POWER_RESTORES, (plan["restores"] as Array).size())
				# Water is a direct score event as well as a Lucidity refresh. Keep the
				# current result's running score in sync so a same-spin power only pops
				# its own gain after the drink has been used.
				_apply_direct_score_gain(int(e["amount"]))
			"cocktailBoost":
				cocktailBoostSpins += int(e["spins"])
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

## Commit score earned outside the normal spin outcome pipeline. The current
## result carries the running score used by machine_scene's rescore burst delta,
## so direct score events must advance both values together.
func _apply_direct_score_gain(score_gain: int) -> void:
	var gain: int = maxi(0, score_gain)
	if gain <= 0:
		return
	scoreEarned += gain
	if not lastResult is Dictionary:
		return
	var updated_result: Dictionary = (lastResult as Dictionary).duplicate(true)
	updated_result["scoreEarned"] = maxi(0, int(updated_result.get("scoreEarned", 0)) + gain)
	lastResult = updated_result

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
# new dealer cycle and resets the escalating reroll price. Chip Augments are NOT
# cleared here: they persist for the whole campaign (fresh Pacte runs and full
# resets own the clear). `seed_override` keeps tests deterministic.
func ensure_prerun_offer(seed_override := -1) -> Array:
	if prerunOfferIds is Array and (prerunOfferIds as Array).size() >= 2:
		return (prerunOfferIds as Array).duplicate()
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

## The level every readout must show: the persisted permanent level, the levels
## staged in an open odds phase, and this campaign's Symbol Level augments.
## Augments fold into oddsWeightOverrides the moment they are bought, so a table
## that leaves them out shows a level — and a draw chance — the reels no longer
## roll on. Augments may push past odds_max_level, up to the hard cap of 9.
func effective_symbol_level(symbol: String) -> int:
	return odds_upgrade_level(symbol) + int(symbolAugmentLevels.get(symbol, 0))

## Same level, under the name the augment picker and its purchase validation use.
func augment_symbol_level(symbol: String) -> int:
	return effective_symbol_level(symbol)

## Augment levels bought for `symbol` alone (0 or 1 — see AUGMENT_LEVELS_PER_SYMBOL),
## as opposed to the effective level the two functions above report.
func symbol_augment_levels(symbol: String) -> int:
	return int(symbolAugmentLevels.get(symbol, 0))

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
			# One augment level per symbol, ever: a second copy has to be spent on a
			# different symbol rather than stacking on the same one.
			if symbol_augment_levels(choice) >= ChipAugments.AUGMENT_LEVELS_PER_SYMBOL:
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
				neurons = mini(_neuron_cap(), neurons \
					+ ChipAugments.EXTRA_SPINS_PER_COPY \
					* maxi(1, Economy.compute_neuron_decay(ownedUpgrades)))
				extraSpinsGranted += 1 # already paid; the run-start overlay skips it
		"aug_offer_expand":
			_expand_current_offer()
		"aug_pair_triple":
			pairTripleAugmentChoice = choice # locked — cannot be changed afterwards
	dealerAugmentOfferId = "" # one dedicated offer per visit; it is now consumed
	_commit()
	return true

## Expanded Selection procs immediately: the offer already on the counter grows
## to the new count with fresh picks instead of waiting for the next visit's roll.
func _expand_current_offer() -> void:
	var target := dealer_offer_count()
	if runPhase == "running":
		if dealerPending and dealerOfferIds is Array and (dealerOfferIds as Array).size() < target:
			dealerOfferIds = _extended_offer(dealerOfferIds as Array, InRunItems.ids(),
				_seed(spinCount * 0x6b43c7f + 0x3aa), target)
	elif prerunOfferIds is Array and (prerunOfferIds as Array).size() < target:
		prerunOfferIds = _extended_offer(prerunOfferIds as Array, _prerun_candidate_ids(),
			_seed(0x21117 + 0x3aa), target)

## `current` plus deterministic fresh picks (never duplicating the counter) up
## to `target` items. Falls back to `current` when the pool has no spares.
func _extended_offer(current: Array, pool: Array, seed_val: int, target: int) -> Array:
	var spares: Array = pool.filter(func(id): return not current.has(id))
	var extra: Variant = Dealer.pick_pool_offer(spares, seed_val, target - current.size())
	return current + (extra as Array) if extra is Array else current

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
	# Augments persist for the whole campaign, so only copies not yet paid out
	# grant spins here — a flatline continuation must not re-grant old copies.
	var spin_copies := int(chipAugmentsPurchased.get("aug_extra_spins", 0)) - extraSpinsGranted
	if spin_copies > 0:
		var bonus := spin_copies * ChipAugments.EXTRA_SPINS_PER_COPY \
			* maxi(1, Economy.compute_neuron_decay(ownedUpgrades))
		neurons = mini(_neuron_cap(), neurons + bonus)
		extraSpinsGranted += spin_copies

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
