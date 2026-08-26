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
const RUN_PRICING_SCRIPT := preload("res://rules/run_pricing.gd")

## Run persistence (issue #111 follow-up): a live run and a resumable flatline
## dealer visit survive app restarts so the menu can offer CONTINUE. The whole
## run state is snapshotted on every commit (var_to_str keeps ints/bools exact,
## unlike JSON) and removed only when no resumable session remains.
const RUN_SAVE_PATH := "user://lobotomy-run.save"
const RUN_SAVE_SCHEMA_VERSION := 2
const ROUTE_SCENE := "res://scenes/dealer_choice_scene.tscn"

## Live dealer offer reroll pricing: first reroll of a cycle costs the base, each
## subsequent reroll adds the base again (5, 10, 15, …).
const DEALER_REROLL_BASE_COST := 5
## Between-machine route-door rerolls use their own starting price (10, 20, 30, …)
## so the route choice does not share the live dealer's cheaper service.
const ROUTE_OFFER_REROLL_BASE_COST := 10

## Pacte owns the run's power loadout. No power is granted by default; legacy
## callers that skip the ritual still receive only the permanent powers they own.
const PACTE_CAMPAIGN_NEURON_THRESHOLDS: Array[int] = [2, 1]
const PACTE_WEALTH_TARGETS: Array[int] = [500, 1500]
const PACTE_INITIAL_DRAW_SEED := 0x50414354
const PACTE_THRESHOLD_DRAW_SEED := 0x54485245
const HERO_POWER_IDS: Array[String] = []
## The machine has three authored power positions.  Replacements are explicit
## run-state transactions; a fourth card is never silently appended.
const MAX_ACTIVE_POWERS := 3
const ROUTE_BONUS_LUCIDITY := 10
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
#   heart   (1): a paid spin costs 2 health instead of 1 (the last chip still costs 1)
#   spade   (2): a power restore charge refills only every other spin
#   diamond (3): two powers per spin, and the between-machine Augment route is suppressed
#   club    (4): shop prices +50%, one item fewer per dealer counter, and a HOUSE
#                ANGER row on every target payout
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
## Same idea for the Emergency Reserve: the machine animates on a CHANGE, so the rescue
## reads even though the spin count it restores is only ever one.
var emergencyReserveSerial := 0
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
## persist for the whole campaign (flatline continuations, Pactes and target round
## breaks included) and now live on MetaStateStore, which owns campaign scope — only
## the campaign ending takes them away. What stays here is the CURRENT VISIT's offer,
## which is run state: it opens and closes with the dealer.
var dealerAugmentOfferId := ""        # current visit's dedicated offer ("" = none)
var brainBoostSpins := 0
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
# Joker item effects (issue #111): the four in-run items turned against the player on a
# joker Augmented run. They ride their own counters rather than negative values on the
# normal ones, so nothing reading cocktailBoostSpins/forceFlatlineSpins has to learn a
# second sign — the badges, the reel transforms and the scorer each check their own.
var cocktailMalusSpins := 0      # joker Cocktail: a win is CHARGED its rarity points
var jokerFlatlineSpins := 0      # joker Red Pill: one random reel lands on flatline
var pendingPowerBarDrains := 0   # joker Water: gauges the machine must empty, then clear

const NON_FLATLINE_SYMBOLS := ["brain", "eye", "pill", "syringe", "vial"]
# Kept as an alias so the machine's per-reel Cocktail bursts read the same table the
# scorer does; the table itself lives with the item now (issue #185).
const COCKTAIL_RARITY_POINTS := InRunItems.COCKTAIL_RARITY_POINTS

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

# Tutorial (issue #105): the exact reels the next spin must land on, as a symbol per reel
# (["eye", "eye", "vial"]), or null when nothing is scripted. The tutorial is a showcase
# and its beats have to land the result they are explaining — a real draw that misses
# would leave the coaching talking about something that did not happen. It rides
# evaluate()'s existing forceReelSymbols gate like the eye reveal does, so the scorer and
# the pinned vectors are untouched; nothing but Tutorial ever sets it.
var scriptedReels: Variant = null

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
var runPhase := "idle" # idle | pre_run | pacte_initial | running | over (pacte_threshold is legacy)
var lastEnding: Variant = null
var wealthContinued := false
## Between-machine route state. The offer is separate from runPhase so the
## existing running/over lifecycle remains compatible with older saves.
var routeOfferPending := false
var routeOfferCards: Variant = null
var routeOfferSeed := 0
var routeOfferRerollCount := 0
var routeContext := "" # "wealth_target" | "flatline"
var routeDestination := "" # "shop" | "augment" | "power" | "bonus" | "sacrifice"
var routeSelectedCardId := ""
var routePacteVisit := false
var routePacteFreeTier := false
var pacteCostsActive := false
## Between-machine build state. Selecting a route door is free; the build card is
## paid only when the player confirms it in the destination scene.
var routeBuildKind := ""
var routeBuildOfferIds: Variant = null
var routeBuildFreeTier := false
var routeBuildSelectedId := ""
var routeBonusClaimed := false
## Fortune Wheel outcome is selected before the animation and saved with the route,
## so a close/resume can only reveal the same segment and can never duplicate its payout.
var routeBonusRewardId := ""
var routeBonusSpinSeed := 0
var sacrificeLaterPending := false
## Run-scoped Shop purchases. These are neither persistent Lab upgrades nor
## campaign Chip Augments.
var runShopUpgrades: Array = []
var runDealerServices: Array = []
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
## Legacy threshold marker retained only while older run snapshots migrate to routes.
var pacteTargetRoundVisit := false
var campaignNeuronPending := false # reserved; consumed when the machine run ends
## Explicit run-scoped ownership of the campaign-neuron reservation.  The pending
## flag is cleared as soon as the loss commits, while this flag distinguishes a
## wealth continuation/target break (which must not spend again) from a live paid run.
var campaignNeuronRunActive := false
## Ending settlement is a persisted transaction boundary.  Presentation callbacks
## and save/resume may revisit an ending, but the same run must bank exactly once.
var endingSettlementCommitted := false
var endingBankCommitted := false
## Frozen ending values.  The ending screens and the wallet transaction both read
## these values after the first commit, so an animation callback can never re-read
## a changing machine total or add it a second time.
var endingScoreSnapshot := -1
var endingLuciditySnapshot := -1
var pendingPowerRestores: Array = []
## Restore charges left (0 .. EconomyConst.POWER_RESTORE_CHARGE_MAX). Every score-driven
## restore spends one — plan_gain crossings and the gauge's own completion — and each spin
## launched gives one back, so a run can restore one power per spin on average and at most
## two on any single spin. A consumable that hands a power back is an item effect and
## spends nothing here.
var powerRestoreCharges := EconomyConst.POWER_RESTORE_CHARGE_MAX

## Augmented spade (issue #111): spins counted since the charge was last spent. The
## cycle is anchored to the PLAYER'S spend, not to global spin parity — a countdown the
## player starts is one they can plan around, where a parity gate just makes alternate
## spins feel arbitrary. 0 while a charge is banked, then 1, then 2 (which is the spin
## that hands the charge back). The machine reads it straight as the two pips under the
## restore light.
var powerRestoreProgress := 0

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
## Persisted while a fourth power is awaiting the player's replacement choice.
## The candidate is not charged or added to the loadout until confirmation.
var pendingPowerReplacement: Dictionary = {}
## Runtime powers deliberately removed by a replacement.  This keeps a replaced
## permanent power from being re-granted when a target/flatline segment starts.
var powerReplacementRemovedIds: Array = []
var pacteThresholdPending := false
var pacteThresholdOpened := false
var pacteAfterFlatlinePending := false
## Legacy threshold visit counter retained for save compatibility. New route choices
## never increment or consume it.
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

## Every reel evaluate() must land on a chosen symbol this spin: the 3x eye reveal, plus
## the joker Red Pill's single flatline (issue #111). The pill takes a reel the eye has
## not already promised — a revealed reel was shown to the player before the spin, and
## overwriting it would make the reveal a lie — and skips locked reels, which hold their
## previous symbol. If every reel is spoken for the pill simply does not bite this spin.
func _forced_reel_symbols(seed_val: int) -> Variant:
	var forced := {}
	var eye: Variant = _forced_eye_reveal_symbols()
	if eye != null:
		forced.merge(eye as Dictionary)
	# A scripted tutorial spin outranks everything below: the beat is explaining THIS
	# result, so it lands whole rather than being edged out by a reveal or a pill.
	if scriptedReels is Array:
		var scripted := scriptedReels as Array
		for i in mini(3, scripted.size()):
			forced[i] = String(scripted[i])
		return forced
	if jokerFlatlineSpins > 0:
		var free_reels: Array = []
		for i in 3:
			if not bool(lockedReels[i]) and not forced.has(i):
				free_reels.append(i)
		if not free_reels.is_empty():
			var rng := LobRNG.new((seed_val ^ 0x111f1a7) & M32)
			forced[int(free_reels[mini(free_reels.size() - 1,
				floori(rng.next() * free_reels.size()))])] = "flatline"
	return forced if not forced.is_empty() else null

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
		var hero_id := PacteCards.normalise_card_id(String(id))
		if not result.has(hero_id):
			result.append(hero_id)
	for id in ownedPowerIds:
		var normalised := PacteCards.normalise_card_id(String(id))
		if not result.has(normalised) and result.size() < MAX_ACTIVE_POWERS:
			result.append(normalised)
	return result

func _cap_power_ids(values: Array) -> Array:
	var result: Array = []
	for value in values:
		var power_id := PacteCards.normalise_card_id(String(value))
		if power_id == "" or result.has(power_id):
			continue
		if result.size() >= MAX_ACTIVE_POWERS:
			break
		result.append(power_id)
	return result

func active_power_ids() -> Array[String]:
	var result: Array[String] = []
	for power_id in power_loadout():
		result.append(power_id)
	return result

## True when a new power would exceed the three authored machine slots.
func power_requires_replacement(card_id: String) -> bool:
	var normalised := PacteCards.normalise_card_id(card_id)
	var runtime_id := PacteCards.power_id(normalised)
	return PacteCards.pool_of(normalised) == "power" \
		and not active_power_ids().has(runtime_id) \
		and active_power_ids().size() >= MAX_ACTIVE_POWERS

func begin_power_replacement(card_id: String, source := "") -> bool:
	var normalised := PacteCards.normalise_card_id(card_id)
	if not power_requires_replacement(normalised):
		return false
	if not pendingPowerReplacement.is_empty():
		return String(pendingPowerReplacement.get("cardId", "")) == normalised
	var options := active_power_ids()
	pendingPowerReplacement = {
		"cardId": normalised,
		"runtimeId": PacteCards.power_id(normalised),
		"source": source,
		"options": options,
	}
	_commit()
	return true

func power_replacement_state() -> Dictionary:
	return pendingPowerReplacement.duplicate(true)

func power_replacement_options() -> Array[String]:
	if pendingPowerReplacement.is_empty():
		return []
	var result: Array[String] = []
	var saved_options: Variant = pendingPowerReplacement.get("options", [])
	if not (saved_options is Array):
		return result
	for value in saved_options as Array:
		var power_id := PacteCards.normalise_card_id(String(value))
		if active_power_ids().has(power_id) and not result.has(power_id):
			result.append(power_id)
	return result

func cancel_power_replacement() -> bool:
	if pendingPowerReplacement.is_empty():
		return false
	pendingPowerReplacement = {}
	pacteSelectedPowerId = ""
	_commit()
	return true

func _normalise_power_replacement(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var candidate := PacteCards.normalise_card_id(String((value as Dictionary).get("cardId", "")))
	if candidate == "" or PacteCards.pool_of(candidate) != "power":
		return {}
	var options: Array[String] = []
	var saved_options: Variant = (value as Dictionary).get("options", [])
	if not (saved_options is Array):
		return {}
	for raw_id in saved_options as Array:
		var power_id := PacteCards.normalise_card_id(String(raw_id))
		if not options.has(power_id):
			options.append(power_id)
	if options.size() < MAX_ACTIVE_POWERS:
		return {}
	return {
		"cardId": candidate,
		"runtimeId": PacteCards.power_id(candidate),
		"source": String((value as Dictionary).get("source", "")),
		"options": options.slice(0, MAX_ACTIVE_POWERS),
	}

func _valid_power_replacement(card_id: String, removed_power_id: String) -> bool:
	if pendingPowerReplacement.is_empty():
		return false
	var candidate := PacteCards.normalise_card_id(card_id)
	var removed := PacteCards.normalise_card_id(removed_power_id)
	if String(pendingPowerReplacement.get("cardId", "")) != candidate:
		return false
	if not power_replacement_options().has(removed):
		return false
	return active_power_ids().has(removed) \
		and not active_power_ids().has(PacteCards.power_id(candidate))

func _replace_active_power(card_id: String, removed_power_id: String) -> bool:
	if not _valid_power_replacement(card_id, removed_power_id):
		return false
	var candidate := PacteCards.normalise_card_id(card_id)
	var candidate_runtime := PacteCards.power_id(candidate)
	var removed := PacteCards.normalise_card_id(removed_power_id)
	var replacement_index := ownedPowerIds.find(removed)
	if replacement_index < 0:
		# A legacy hero can be represented by HERO_POWER_IDS instead of the owned
		# array.  The normal loadout still has to be replaceable, so materialize the
		# active order before replacing its slot.
		ownedPowerIds = active_power_ids()
		replacement_index = ownedPowerIds.find(removed)
	if replacement_index < 0:
		return false
	ownedPowerIds = ownedPowerIds.duplicate()
	ownedPowerIds[replacement_index] = candidate_runtime
	ownedPowerIds = _cap_power_ids(ownedPowerIds)
	var next_selected: Array = []
	for value in selectedPowerCardIds:
		var selected_id := PacteCards.normalise_card_id(String(value))
		if PacteCards.power_id(selected_id) == removed:
			continue
		if not next_selected.has(selected_id):
			next_selected.append(selected_id)
	if not next_selected.has(candidate):
		next_selected.append(candidate)
	selectedPowerCardIds = next_selected
	powerReplacementRemovedIds = powerReplacementRemovedIds.duplicate()
	if not powerReplacementRemovedIds.has(removed):
		powerReplacementRemovedIds.append(removed)
	pendingPowerReplacement = {}
	return true

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

## True while a queued or running compulsory spin owns the gauge: it is capped at x2, so
## combo losses can't drop it below x2 and wins can't push it to x3 until the forced spin
## has fully resolved. Only the joker Energy Drink queues one now — the classic drink's
## protected spins no longer touch the multiplier at all, so they are not counted here.
func energy_drink_owns_multiplier() -> bool:
	return pendingCompulsiveSpinSkips > 0 or compulsiveSpinSkips > 0

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

## Joker runs deal the four in-run items in their turned-against-you form (see
## InRunItems.JOKER_EFFECTS). This is joker's own fifth trait rather than one of the four
## numbered modifiers, so it asks for the tier by name instead of going through
## augmented_modifier_active() — which answers true for all four on a joker run.
func augmented_joker_items_active() -> bool:
	return augmentedTier == "joker"

## The item a joker visit forces on the player, or "" when this run still gets to choose.
## Derived from the visit itself (its index and the spin it landed on) rather than from a
## wall-clock seed, so asking twice about the same visit always names the same item — the
## overlay picks it for the animation and the machine applies exactly that one.
func joker_forced_offer_id() -> String:
	if not augmented_joker_items_active() or dealerOfferIds == null:
		return ""
	var ids := dealerOfferIds as Array
	if ids.is_empty():
		return ""
	var rng := LobRNG.new(((dealerCount * 0x9e3779b9) ^ (spinCount * 0x85ebca6b)) & M32)
	return String(ids[mini(ids.size() - 1, floori(rng.next() * ids.size()))])

## The machine claims a queued joker-Water drain and empties its gauge. Returns false when
## none is queued, so the caller can ask unconditionally after any item use.
func consume_power_bar_drain() -> bool:
	if pendingPowerBarDrains <= 0:
		return false
	pendingPowerBarDrains -= 1
	_commit()
	return true

## Club modifier: the casino is angry, so everything costs more. The markup rides the
## two price chokepoints (chip_augment_price / consumable_price) and the target payout's
## HOUSE ANGER row — never dealer_reroll_price(), which stays at its normal escalating
## cost. Applied BEFORE the Chip Augment discounts, so the two -10% chips still bite
## (x1.5 x 0.8 = x1.2 at two stacks) and become the run's natural counterplay.
const AUGMENTED_CLUB_PRICE_MULTIPLIER := 1.5

func augmented_price_multiplier() -> float:
	return AUGMENTED_CLUB_PRICE_MULTIPLIER if augmented_modifier_active(4) else 1.0

## Club modifier: the angry casino also puts less on the counter. Both dealer counters —
## the pre-run consumable shop and the in-run visit — roll one item fewer, so the run's
## squeeze is visible the moment the counter is opened rather than only in the prices.
## Expanded Selection is bought back to the classic two rather than negated, which keeps
## it worth owning on a club run; the floor of one is enforced in dealer_offer_count().
const AUGMENTED_CLUB_OFFER_PENALTY := 1

func augmented_offer_penalty() -> int:
	return AUGMENTED_CLUB_OFFER_PENALTY if augmented_modifier_active(4) else 0

## The club charge on a beaten target's overflow, or 0.0 when no club run is armed.
func augmented_anger_tax_rate() -> float:
	return EconomyConst.OVERFLOW_ANGER_RATE if augmented_modifier_active(4) else 0.0

## Diamond modifier: the between-machine Augment route is suppressed. Keeping this
## rule explicit prevents a missing unlock from being mistaken for modifier behavior.
func augmented_pacte_augment_suppressed() -> bool:
	return augmented_modifier_active(3)

## Heart modifier: what one paid spin costs in health. Doubling the decay halves the
## run's length proportionally, which bites a long run as hard as a short one — the
## old "jackpot pays half" only ever touched one rare result. Spins the run never
## charges for (free, compulsive, Energy Drink) are exempt: the caller's
## `stasis or sedative or is_free` guard zeroes the cost before this is consulted.
func _augmented_health_cost_multiplier() -> int:
	return 2 if augmented_modifier_active(1) else 1

func _ready() -> void:
	load_run_state()

func _commit() -> void:
	state_changed.emit()
	_save_run_state()

# ── run persistence ──────────────────────────────────────────────────────────────

## Tutorial sandbox (issue #105): while this is set the store still behaves exactly as it
## always does — it just never reaches the disk. The tutorial plays on the real machine
## with scripted state, and none of that may land on the player's save; quitting halfway
## through must leave the campaign they actually have. Tutorial owns setting and clearing
## it, and restores the state it snapshotted on the way out.
var sandboxed := false

## What the augment deck must not deal. Always the cards already taken this run; during the
## tutorial (issue #105) also the reward-amplification tier, because taking one opens a
## symbol picker in the middle of a scripted beat and asks a two-minute-old player to pick
## a symbol to boost — a decision they have nothing to base an answer on yet.
func _augment_draw_exclusions() -> Array:
	if not sandboxed:
		return selectedAugmentCardIds
	var excluded: Array = selectedAugmentCardIds.duplicate()
	for card_id in PacteCards.reward_amp_ids():
		if not excluded.has(card_id):
			excluded.append(card_id)
	return excluded

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
	if sandboxed:
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
	_normalise_route_offer_after_load()
	ownedPowerIds = _normalise_power_ids(ownedPowerIds)
	ownedPowerIds = _cap_power_ids(ownedPowerIds)
	selectedPowerCardIds = _normalise_power_ids(selectedPowerCardIds)
	powerReplacementRemovedIds = _normalise_power_ids(powerReplacementRemovedIds)
	pendingPowerReplacement = _normalise_power_replacement(pendingPowerReplacement)
	pacteSelectedPowerId = PacteCards.normalise_card_id(pacteSelectedPowerId)
	pacteOfferPowerIds = _normalise_power_array_or_null(pacteOfferPowerIds)
	abilitiesUsed = _normalise_power_ids(abilitiesUsed)
	pendingPowerRestores = _normalise_power_ids(pendingPowerRestores)
	_reapply_pacte_runtime_effects()
	_clamp_neurons()
	_commit()

func _normalise_route_offer_after_load() -> void:
	if not routeOfferPending:
		return
	if routeContext != "wealth_target" and routeContext != "flatline":
		routeOfferPending = false
		routeOfferCards = null
		routeOfferRerollCount = 0
		return
	routeOfferRerollCount = maxi(0, int(routeOfferRerollCount))
	if _route_offer_array().size() == RouteCards.OFFER_COUNT:
		return
	# Older saves contain the previous five-card catalogue offer. Rebuild from
	# the persisted seed so the new dealer pair is deterministic and the held
	# route remains resumable instead of leaving a stale five-card state behind.
	routeOfferCards = RouteCards.offer(routeOfferSeed, routeContext)
	routeOfferPending = _route_offer_array().size() == RouteCards.OFFER_COUNT
	routeOfferRerollCount = 0

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
		"powerRestoreProgress": powerRestoreProgress,
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
	powerRestoreProgress = int(snapshot.get("powerRestoreProgress", 0))
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

## Everything one spin needs to know about itself. It exists because the five
## stages below used to be a single function sharing thirty locals — this is that
## shared frame, named, so each stage can state what it reads and what it fills in.
## Nothing here outlives the spin that made it.
class SpinContext extends RefCounted:
	var is_compulsive := false
	var is_free := false
	var heart_armed := false
	var spin_seed := 0
	var rng: LobRNG = null
	var stasis := false
	var sedative := false
	var combo_before := 1
	var eff_bet := 1
	var base_decay := 0
	var decay_amt := 0
	var brain_bonus := 0
	var eff_mult := 0.0
	var book_weight := 0
	# Potion pool roll (issue #32), drawn on its own seed so the pick is
	# independent of the reel roll.
	var potion_pick: Variant = null
	var potion_lucidity_delta := 0
	var potion_symbol_to_brain := 0
	var potion_free_reroll := false
	var potion_restore_spins := 0
	var potion_restore_power := false
	var potion_adjacent_symbols := 0
	# Consumable reel transforms.
	var force_all: Variant = null
	var force_triple: Variant = null
	var pair_boost_active := false
	var hallucination_active := false
	var hidden_reel_count := 0
	# Filled in by the stages that follow.
	var result: Dictionary = {}       # the reels as evaluated, before any store boost
	var final_result: Dictionary = {} # what the caller is handed
	var passive_lucidity := 0
	var flatline_boost_applied := false

## One spin, start to finish. Each stage takes the context and either fills it in
## or acts on it; the order they run in is the order the rules resolve in, and it
## is load-bearing — the outcome stage reads decisions the score stage made.
func spin(compulsive := false) -> Variant:
	var ctx := _open_spin(compulsive)
	if ctx == null:
		return null
	_roll_potion(ctx)
	_resolve_reel_transforms(ctx)
	_evaluate_spin(ctx)
	_apply_score_bonuses(ctx)
	_settle_spin(ctx)
	_commit()
	return ctx.final_result

## The gate, and the per-spin numbers that follow from passing it. Returns null
## when this spin is refused, having changed nothing the caller can observe apart
## from the legacy-state normalisation and combo-defeat resolution that a refused
## spin used to perform too.
func _open_spin(compulsive: bool) -> SpinContext:
	if runPhase != "running" or isSpinning:
		return null
	# Normalize legacy or externally restored state before charging this spin. The
	# machine never spends from a pool above the current MAX_NEURONS cap.
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
	var ctx := SpinContext.new()
	ctx.is_compulsive = compulsive and compulsiveSpinSkips > 0
	if not ctx.is_compulsive and compulsiveSpinSkips > 0:
		return null
	ctx.heart_armed = (not ctx.is_compulsive) and heartPowerArmed
	ctx.is_free = (not ctx.is_compulsive) and (freeSpinsRemaining > 0 or ctx.heart_armed)
	if (not ctx.is_free) and neurons < 1:
		return null

	# One restore charge back for the spin. This spin's own payout and every power the
	# player then plays on these reels draw from the same pool, so a pair that gives one
	# power back can only be followed by another restore if a charge was banked.
	_recharge_restores()

	ctx.spin_seed = _seed(spinCount * 0x9e3779b9)
	ctx.rng = LobRNG.new(ctx.spin_seed)

	ctx.stasis = (not ctx.is_compulsive) and (not ctx.is_free) and decaySkips > 0
	ctx.sedative = (not ctx.is_compulsive) and (not ctx.is_free) and Economy.has_sedative(ownedUpgrades) and (spinCount + 1) % 3 == 0

	# Issue #155: the gauge value this spin runs at. The multiplier no longer costs
	# extra neurons or free spins — its downside is the dealer countdown advancing
	# 3/2/1 steps at x1/x2/x3, so lower gauges pull the dealer in faster.
	ctx.combo_before = clampi(betMultiplier, 1, 3)
	# A compulsory spin is NOT dropped to x1 — it runs at x2, so the spin the machine
	# takes from the player is still worth something.
	ctx.eff_bet = ctx.combo_before
	if ctx.is_compulsive and ctx.eff_bet == 3:
		ctx.eff_bet = 2 # the seized spin dulls the frenzy: x3 runs as x2

	# Augmented heart modifier (issue #111): a paid spin costs two health instead of
	# one. The mini() below is what makes the last chip cost a single point rather
	# than refusing the spin — the run gets to play its final health, then ends.
	ctx.base_decay = Economy.compute_neuron_decay(ownedUpgrades) \
		* _augmented_health_cost_multiplier()
	ctx.decay_amt = 0 if (ctx.stasis or ctx.sedative or ctx.is_free) else mini(ctx.base_decay, neurons)

	ctx.brain_bonus = Economy.compute_brain_weight_bonus(ownedUpgrades)
	if brainBoostSpins > 0:
		ctx.brain_bonus += int(Symbols.WEIGHT["brain"]) * 3

	var base_mult := lucidityMultiplier * nextSpinLucidityMultiplier * ctx.eff_bet
	ctx.eff_mult = base_mult * 0.5 if brainBoostSpins > 0 else base_mult
	return ctx

## The potion pool roll (issue #32): one equal-weight effect for this spin.
func _roll_potion(ctx: SpinContext) -> void:
	if potionSpins <= 0:
		return
	var p_rng := LobRNG.new((ctx.spin_seed ^ 0x50710000) & M32)
	var pool: Array = Consumables.POTION_RANDOM_POOL
	var pick: Dictionary = pool[int(p_rng.next() * pool.size())]
	if String(pick["kind"]) == "restorePower" and abilitiesUsed.is_empty():
		var fallback_pool: Array = []
		for candidate in pool:
			if String(candidate["kind"]) != "restorePower":
				fallback_pool.append(candidate)
		if not fallback_pool.is_empty():
			pick = fallback_pool[int(p_rng.next() * fallback_pool.size())]
	ctx.potion_pick = pick
	match String(pick["kind"]):
		"lucidity": ctx.potion_lucidity_delta = int(pick["amount"])
		"symbolToBrain": ctx.potion_symbol_to_brain = 1
		"freeReroll": ctx.potion_free_reroll = true
		"restoreSpin": ctx.potion_restore_spins = int(pick.get("count", 1))
		"restorePower": ctx.potion_restore_power = true
		"adjacentSymbol": ctx.potion_adjacent_symbols = int(pick.get("count", 1))

## Consumable reel transforms (issue #32). Pill forces a flatline spin, then a
## guaranteed non-flatline triple the spin after; Serum bans/guarantees a symbol.
func _resolve_reel_transforms(ctx: SpinContext) -> void:
	ctx.force_all = "flatline" if forceFlatlineSpins > 0 else null
	ctx.force_triple = NON_FLATLINE_SYMBOLS if (forceFlatlineSpins <= 0 and guaranteedTripleSpins > 0) else null
	ctx.pair_boost_active = pairBoostSpins > 0
	ctx.hallucination_active = Economy.has_hallucination(ownedUpgrades)
	ctx.hidden_reel_count = _active_hidden_reel_count(ctx.pair_boost_active)
	ctx.book_weight = Economy.compute_book_weight(ownedUpgrades)

## The reels themselves: either a Heart spin, which ignores the symbol weights
## entirely, or a normal weighted evaluation.
func _evaluate_spin(ctx: SpinContext) -> void:
	var result: Dictionary
	if ctx.heart_armed:
		# Heart's result is intentionally independent of the normal symbol weights:
		# one seeded draw chooses x1/x2/x3, then every reel lands on that symbol.
		var heart_rng := LobRNG.new((pacteSeed ^ (spinCount * 0x9e3779b9) \
				^ 0x48454152) & M32)
		var heart_tier := 1 + floori(heart_rng.next() * 3.0)
		result = Abilities.resolve_heart_spin(heart_tier, ctx.eff_mult,
			_active_reward_scale(), symbolRewardBonuses)
		result[SpinResult.NEURONS_AFTER] = mini(_neuron_cap(), neurons + int(result["neuronsDelta"]))
		result[SpinResult.FREE_SPINS_AFTER] = freeSpinsRemaining
		result[SpinResult.IS_FREE_SPIN] = true
		result[SpinResult.SCORE_MULTIPLIER] = ctx.eff_mult
		heartPowerArmed = false
	else:
		result = Evaluate.evaluate({
			"neurons": neurons,
			"neuronDecayAmount": ctx.decay_amt,
			"freeSpinsRemaining": freeSpinsRemaining,
			"maxFreeSpins": maxFreeSpins,
			"lucidityMultiplier": ctx.eff_mult,
			"isFreeSpin": ctx.is_free,
			"freeSpinCost": 1, # issue #155: the auto gauge never drains banked free spins faster
			"lockedReels": lockedReels,
			"previousReels": (lastResult["reels"] if lastResult != null else null),
			"rng": ctx.rng,
			"bookWeight": ctx.book_weight,
			"brainWeightBonus": ctx.brain_bonus,
			"guaranteedWin": guaranteedWinSpins > 0,
			"pattern23Triple": Economy.has_pattern23_triple(ownedUpgrades),
			"learningActive": ctx.book_weight > 0,
			"forceAllSymbol": ctx.force_all,
			"forceTripleFrom": ctx.force_triple,
			"excludeSymbol": ("brain" if banBrainSpins > 0 else null),
			"banExcluded": banBrainSpins > 0,
			"guaranteeSymbolId": (guaranteeSymbolId if (guaranteeSymbolSpins > 0 and guaranteeSymbolId != "") else null),
			"forceReelSymbols": _forced_reel_symbols(ctx.spin_seed),
			"symbolToBrainCount": ctx.potion_symbol_to_brain,
			"adjacentSymbolCount": ctx.potion_adjacent_symbols,
			"pairScoreMult": _pair_score_multiplier(ctx.pair_boost_active),
			"hiddenReelCount": ctx.hidden_reel_count,
			"visiblePairAsTriple": ctx.hallucination_active,
			"rewardScale": _active_reward_scale(),
			"bookRewardScale": _book_reward_scale(),
			"hallucinationRewardScale": _hallucination_reward_scale(),
			"soloAsPair": Economy.has_solo_as_pair(ownedUpgrades),
			"symbolRewardBonuses": symbolRewardBonuses,
			"weightOverrides": oddsWeightOverrides,
		})
	ctx.result = result

## Everything that pays on top of the pinned reel score. Each of these rides above
## evaluate() rather than inside it, so the parity vectors keep pinning the reels
## themselves while the store layers its own boosts on the total.
func _apply_score_bonuses(ctx: SpinContext) -> void:
	var result := ctx.result
	# The Cocktail is pure upside: rarity points on every visible reel, no tax and no
	# win-type gate — pairs and triples collect exactly like a miss does. It used to
	# charge 15% of a pair/triple back, which made the item read as a trap on exactly the
	# spins it was supposed to reward. The maths lives in InRunItems so parity can pin it.
	var cocktail_bonus := 0
	if cocktailBoostSpins > 0:
		cocktail_bonus = InRunItems.cocktail_bonus(result[SpinResult.REELS] as Array,
			ctx.hidden_reel_count, float(result[SpinResult.SCORE_MULTIPLIER]))
	# The joker Cocktail (issue #111) is that same total, charged rather than paid, and
	# ONLY on a spin that won something: a miss pays nothing, so there is nothing to take
	# and the item would otherwise be a tax on standing still. The win is floored at zero
	# below rather than going negative — the drink takes the winnings, not the run.
	var cocktail_malus := 0
	if cocktailMalusSpins > 0 and int(result[SpinResult.SCORE_EARNED]) > 0 \
			and SpinResult.is_paying_type(result):
		cocktail_malus = InRunItems.cocktail_bonus(result[SpinResult.REELS] as Array,
			ctx.hidden_reel_count, float(result[SpinResult.SCORE_MULTIPLIER]))
	# Issue #76: a charged flatline strike multiplies the next winning pair/triple. The
	# bonus rides on top of the pinned score (evaluate() untouched, like cocktail above)
	# so it flows through the lucidity plan; requiring base_score > 0 means misses and
	# 0-score flatline wins never spend the charge — it waits for a real win.
	var base_score := maxi(0, int(result[SpinResult.SCORE_EARNED]) + cocktail_bonus - cocktail_malus)
	var flatline_boost := 0
	if flatlineWinBoostArmed and base_score > 0 and SpinResult.is_paying_type(result):
		flatline_boost = base_score * (EconomyConst.FLATLINE_WIN_BOOST_MULT - 1)
		ctx.flatline_boost_applied = true
	# COMBO is a separate Pacte streak from the flatline strike above. Each
	# successive paying result earns the next 5%-step bonus, then caps at 45%.
	var win_boost_bonus := 0
	var win_boost_percent := 0
	var win_boost_combo := 0
	var win_boost_applied := false
	var paying_result := base_score > 0 and SpinResult.is_paying_type(result)
	if winBoostEnabled and paying_result:
		var boost_step := clampi(winBoostCombo + 1, 1, 9)
		win_boost_combo = boost_step
		win_boost_percent = roundi(float(WIN_BOOST_RATES[boost_step]) * 100.0)
		win_boost_bonus = floori(float(base_score) * WIN_BOOST_RATES[boost_step] + 0.5)
		win_boost_applied = true
	# Pair/Triple Specialist (Chip Augment): the chosen win type pays x1.25. Rides on
	# top of the pinned score like the cocktail/flatline boosts (evaluate() untouched).
	var specialist_bonus := ChipAugments.specialist_bonus(
		base_score, String(result[SpinResult.WIN_TYPE]), MetaStateStore.pairTripleAugmentChoice)
	var final_score := base_score + flatline_boost + win_boost_bonus + specialist_bonus
	ctx.passive_lucidity = _passive_lucidity_per_spin()
	var passive_lucidity := ctx.passive_lucidity
	var final_result: Dictionary = result
	if cocktail_bonus > 0 or cocktail_malus > 0 or ctx.flatline_boost_applied \
			or win_boost_applied or specialist_bonus > 0 or ctx.hidden_reel_count > 0 \
			or passive_lucidity > 0:
		final_result = result.duplicate(true)
		final_result[SpinResult.SCORE_EARNED] = final_score
		final_result[SpinResult.COINS_EARNED] = final_score
		if ctx.hidden_reel_count > 0:
			final_result[SpinResult.HIDDEN_REEL_COUNT] = ctx.hidden_reel_count
		if cocktail_bonus > 0:
			final_result[SpinResult.COCKTAIL_APPLIED] = true
			final_result[SpinResult.COCKTAIL_BONUS] = cocktail_bonus
		if cocktail_malus > 0:
			final_result[SpinResult.COCKTAIL_MALUS_APPLIED] = true
			final_result[SpinResult.COCKTAIL_MALUS] = cocktail_malus
		if ctx.flatline_boost_applied:
			final_result[SpinResult.FLATLINE_BOOST_APPLIED] = true
			final_result[SpinResult.FLATLINE_BOOST_BONUS] = flatline_boost
		if win_boost_applied:
			final_result[SpinResult.WIN_BOOST_APPLIED] = true
			final_result[SpinResult.WIN_BOOST_PERCENT] = win_boost_percent
			final_result[SpinResult.WIN_BOOST_BONUS] = win_boost_bonus
			final_result[SpinResult.WIN_BOOST_COMBO] = win_boost_combo
			final_result[SpinResult.WIN_BOOST_BASE_SCORE] = maxi(0, final_score - win_boost_bonus)
		if specialist_bonus > 0:
			final_result[SpinResult.SPECIALIST_BONUS] = specialist_bonus
		if passive_lucidity > 0:
			final_result[SpinResult.PASSIVE_LUCIDITY] = passive_lucidity
	# The one place every spin's result is finished, and so the one place worth
	# checking its shape. Compiles out of export builds.
	SpinResult.validate(final_result)
	ctx.final_result = final_result

## Committing the spin to the run: the lucidity plan, the potion's after-effects,
## then every field this spin moves and every per-spin counter it ticks down.
func _settle_spin(ctx: SpinContext) -> void:
	var result := ctx.result
	var final_result := ctx.final_result
	var passive_lucidity := ctx.passive_lucidity
	# Heart stays spent like every other power: it waits in the pool until the
	# active power-restore threshold brings it back.
	var lucidity_gain := int(final_result[SpinResult.SCORE_EARNED]) + passive_lucidity
	var plan := Lucidity.plan_gain(lucidityCoins, lucidity_gain, abilitiesUsed, ctx.spin_seed,
		effective_coins_per_power_restore(), restore_budget_left())

	# A queued compulsion lands on the spin after the one that queued it. It used to wait
	# for the classic drink's protected spins to run out; only the joker drink queues one
	# now, and it brings no protected spins with it, so the wait is a single spin.
	var was_energy_last: bool = pendingCompulsiveSpinSkips > 0 and not ctx.is_compulsive

	# Potion pool side effects (issue #32): ± lucidity and a free reroll (restore the
	# reroll ability) resolve after the score plan.
	var new_abilities: Array = plan["abilitiesUsed"]
	if ctx.potion_free_reroll:
		new_abilities = new_abilities.filter(func(a): return String(a) != "reroll")
	var potion_restored_power := ""
	if ctx.potion_restore_power and not new_abilities.is_empty():
		var restore_rng := LobRNG.new((ctx.spin_seed ^ 0x7600babe) & M32)
		var restore_idx := mini(new_abilities.size() - 1, floori(restore_rng.next() * new_abilities.size()))
		potion_restored_power = String(new_abilities[restore_idx])
		new_abilities = new_abilities.duplicate()
		new_abilities.remove_at(restore_idx)

	neurons = int(final_result[SpinResult.NEURONS_AFTER])
	if ctx.potion_restore_spins > 0:
		neurons += ctx.potion_restore_spins * maxi(1, ctx.base_decay)
	_clamp_neurons()
	# Passive gain is wealth, not just power fuel: it feeds the run total (and so the
	# wealth odometer and the target) alongside the Lucidity it already paid out. The
	# per-spin result keeps only the reel payout, so the score popup still announces
	# what the reels won.
	scoreEarned += int(final_result[SpinResult.SCORE_EARNED]) + passive_lucidity
	lucidityCoins = maxi(0, int(plan["lucidityCoins"]) + ctx.potion_lucidity_delta)
	abilitiesUsed = new_abilities
	pendingPowerRestores.append_array(plan["restores"])
	_spend_restore_budget((plan["restores"] as Array).size())
	_note_card_metric(CardUnlocks.METRIC_POWER_RESTORES, (plan["restores"] as Array).size())
	if potion_restored_power != "":
		pendingPowerRestores.append(potion_restored_power)
	# Compulsive spins don't consume banked free spins, but the parity-pinned
	# evaluate() clamps freeSpinsAfter to maxFreeSpins on non-free spins — which
	# would wipe banked vial/tea rewards (issue #66). Keep what the player had.
	freeSpinsRemaining = maxi(int(final_result[SpinResult.FREE_SPINS_AFTER]), freeSpinsRemaining) \
		if ctx.is_compulsive else int(final_result[SpinResult.FREE_SPINS_AFTER])
	isFreeSpin = bool(final_result[SpinResult.IS_FREE_SPIN])
	# Checked here, after the spin's OWN restores (potion spins above, the free-spin
	# tally just settled): the reserve is the last resort, so anything the spin itself
	# gave back is counted first and leaves it untouched.
	_try_emergency_reserve(not ctx.is_free)
	isSpinning = true
	lastResult = final_result
	# Baseline for the additive power payouts below: what the reels as spun are worth
	# on their own, before any store-level boost. Powers reshape these reels, and each
	# combination they form pays on top rather than replacing this one.
	lastPureWinScore = maxi(0, int(result[SpinResult.SCORE_EARNED]))
	lastPureWinCoins = maxi(0, int(result[SpinResult.COINS_EARNED]))
	_track_spin_card_progress(final_result)
	if int(final_result.get(SpinResult.FREE_SPINS_GRANTED, 0)) > 0:
		freeSpinGrantSerial += 1
	lastPotionEffect = ctx.potion_pick
	lastEffectiveBet = clampi(ctx.eff_bet, 1, 3)
	# Issue #155 frenzy gauge: a paying win steps the multiplier up. A defeat keeps
	# the pre-spin value visible until the machine's pending rescue state resolves.
	# The Energy-Drink forced spin drives the gauge like any normal spin — it keeps
	# the current combo and can lose it (no machine-forced x1).
	lastComboMultiplier = ctx.combo_before
	if _is_winning_result(final_result):
		if winBoostEnabled:
			winBoostCombo = mini(9, winBoostCombo + 1)
		betMultiplier = _combo_after(ctx.combo_before, final_result)
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
		betMultiplier = ctx.combo_before
		if winBoostEnabled:
			# Protected spins have no rescue window, so a miss breaks COMBO now.
			winBoostCombo = 0
	else:
		# Keep COMBO at its current stage while the losing-state warning is open.
		# resolve_pending_combo_defeat(false) clears it if the player confirms the
		# loss; a corrective power can still recover it here.
		comboDefeatPending = true
		pendingComboMultiplier = ctx.combo_before
		betMultiplier = ctx.combo_before
	# Issue #155 dealer countdown: every completed spin advances it by the inverse
	# multiplier actually used this spin. No overflow carry — it just floors at 0.
	var dealer_countdown_step: int = 3 if glitchDealerStepActive else 4 - clampi(ctx.eff_bet, 1, 3)
	dealerCountdown = maxi(0, dealerCountdown - dealer_countdown_step)
	spinCount += 1
	powersUsedThisSpin = 0 # diamond modifier counts power uses per spin
	nextSpinLucidityMultiplier = 1.0
	if ctx.stasis:
		decaySkips -= 1
	brainBoostSpins = maxi(0, brainBoostSpins - 1)
	guaranteedWinSpins = maxi(0, guaranteedWinSpins - 1)
	blockPowersSpins = maxi(0, blockPowersSpins - 1)
	hideNeuronsSpins = maxi(0, hideNeuronsSpins - 1)
	cocktailBoostSpins = maxi(0, cocktailBoostSpins - 1)
	cocktailMalusSpins = maxi(0, cocktailMalusSpins - 1)
	jokerFlatlineSpins = maxi(0, jokerFlatlineSpins - 1)
	compulsiveSpinSkips = (maxi(0, compulsiveSpinSkips - 1) if ctx.is_compulsive else compulsiveSpinSkips) \
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
	scriptedReels = null # one scripted spin per beat (issue #105)
	banBrainSpins = maxi(0, banBrainSpins - 1)
	potionSpins = maxi(0, potionSpins - 1)
	# Keep the pending triple until the flatline spin is spent, then consume it.
	var flatline_was_active := forceFlatlineSpins > 0
	forceFlatlineSpins = maxi(0, forceFlatlineSpins - 1)
	guaranteedTripleSpins = guaranteedTripleSpins if flatline_was_active else maxi(0, guaranteedTripleSpins - 1)
	hideResultSpins = maxi(0, hideResultSpins - 1)
	# Issue #76: the charge is spent only when a win actually consumed it above.
	if ctx.flatline_boost_applied:
		flatlineWinBoostArmed = false

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
	var win_type := String(result[SpinResult.WIN_TYPE])
	if win_type == "heart":
		return true
	return win_type in SpinResult.PAYING_WIN_TYPES \
		and int(result[SpinResult.SCORE_EARNED]) > 0

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
	dealerCountdown = dealer_countdown_reset_value() # honours Dealer's Tip (issue #132)
	dealerIncoming = false
	dealerPending = false
	dealerOfferIds = null
	dealerRerollCount = 0
	prerunOfferIds = null
	# Only the visit's offer is run state. The purchased chips belong to the campaign
	# (MetaStateStore) and outlive any number of runs inside it — resetting a run must
	# not confiscate them (issue #132).
	dealerAugmentOfferId = ""
	brainBoostSpins = 0
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
	scriptedReels = null
	banBrainSpins = 0
	potionSpins = 0
	forceFlatlineSpins = 0
	guaranteedTripleSpins = 0
	hideResultSpins = 0
	cocktailMalusSpins = 0
	jokerFlatlineSpins = 0
	pendingPowerBarDrains = 0
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
	routeOfferPending = false
	routeOfferCards = null
	routeOfferSeed = 0
	routeOfferRerollCount = 0
	routeContext = ""
	routeDestination = ""
	routeSelectedCardId = ""
	routePacteVisit = false
	routePacteFreeTier = false
	pacteCostsActive = false
	routeBuildKind = ""
	routeBuildOfferIds = null
	routeBuildFreeTier = false
	routeBuildSelectedId = ""
	routeBonusClaimed = false
	routeBonusRewardId = ""
	routeBonusSpinSeed = 0
	sacrificeLaterPending = false
	runShopUpgrades = []
	runDealerServices = []
	wealthTargetIndex = 0
	wealthTargetPending = false
	wealthTargetPendingValue = 0
	roundContinuationPending = false
	pacteTargetRoundVisit = false
	campaignNeuronPending = false
	campaignNeuronRunActive = false
	endingSettlementCommitted = false
	endingBankCommitted = false
	endingScoreSnapshot = -1
	endingLuciditySnapshot = -1
	augmentedTier = ""
	powersUsedThisSpin = 0
	powerRestoreCharges = EconomyConst.POWER_RESTORE_CHARGE_MAX
	powerRestoreProgress = 0
	pacteSeed = 0
	pacteOfferAugmentIds = null
	pacteOfferPowerIds = null
	pacteSelectedAugmentId = ""
	pacteSelectedPowerId = ""
	selectedAugmentCardIds = []
	selectedPowerCardIds = []
	ownedPowerIds = []
	pendingPowerReplacement = {}
	powerReplacementRemovedIds = []
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
	campaignNeuronRunActive = false
	endingSettlementCommitted = false
	endingBankCommitted = false
	endingScoreSnapshot = -1
	endingLuciditySnapshot = -1
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
	campaignNeuronRunActive = false
	endingSettlementCommitted = false
	endingBankCommitted = false
	endingScoreSnapshot = -1
	endingLuciditySnapshot = -1
	dealerIncoming = false
	dealerPending = false
	dealerOfferIds = null
	pacteThresholdPending = false
	pacteThresholdOpened = false
	pacteAfterFlatlinePending = false
	_commit()
	prepare_route_offer("wealth_target")
	return true

func _route_offer_array() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if routeOfferCards is Array:
		for value in routeOfferCards as Array:
			if value is Dictionary:
				result.append((value as Dictionary).duplicate(true))
	return result

func current_route_offer() -> Array[Dictionary]:
	return _route_offer_array()

func route_offer_card(card_id: String) -> Dictionary:
	for card_entry in _route_offer_array():
		if String(card_entry.get("id", "")) == card_id:
			return card_entry
	return {}

func route_card_affordable(card_id: String) -> bool:
	# Route doors are choices, not purchases. Any Lucidity check belongs to the
	# destination itself: route build cards, Shop items, or a paid reroll.
	if not routeOfferPending:
		return false
	var card := route_offer_card(card_id)
	if card.is_empty():
		return false
	return RouteCards.affordable(card, int(lucidityCoins))

## The current machine segment determines all run-scoped purchase prices.  The
## target index is zero-based, so a fresh run is round 1.
func run_round_index() -> int:
	return maxi(1, int(wealthTargetIndex) + 1)

func calculate_run_price(base_price: int, round_index := -1) -> int:
	var selected_round := run_round_index() if int(round_index) < 1 else int(round_index)
	return RUN_PRICING_SCRIPT.calculate_run_price(base_price, selected_round)

func run_price_markup_percent(round_index := -1) -> int:
	var selected_round := run_round_index() if int(round_index) < 1 else int(round_index)
	return RUN_PRICING_SCRIPT.markup_percent(selected_round)

func run_price_label(round_index := -1) -> String:
	var selected_round := run_round_index() if int(round_index) < 1 else int(round_index)
	return RUN_PRICING_SCRIPT.progression_label(selected_round)

## The next route-door reroll costs 10G, then 20G, then 30G. It belongs to this
## prepared offer and is persisted beside the two doors until one door is selected
## or refused.
func route_offer_reroll_price() -> int:
	var base := ROUTE_OFFER_REROLL_BASE_COST * (int(routeOfferRerollCount) + 1)
	return calculate_run_price(base)

func route_offer_reroll_affordable() -> bool:
	return routeOfferPending and int(lucidityCoins) >= route_offer_reroll_price()

func reroll_route_offer() -> bool:
	if not routeOfferPending or routeContext == "":
		return false
	var price := route_offer_reroll_price()
	if int(lucidityCoins) < price:
		return false
	var previous := _route_offer_array()
	var next_count := int(routeOfferRerollCount) + 1
	var rerolled := RouteCards.reroll_offer(routeOfferSeed, routeContext,
		next_count, previous)
	if rerolled.size() != RouteCards.OFFER_COUNT:
		return false
	lucidityCoins -= price
	routeOfferRerollCount = next_count
	routeOfferCards = rerolled
	_commit()
	return true

func _route_build_offers(kind: String) -> Array[String]:
	var max_tier := 0 if routeContext == "flatline" else -1
	var draw_seed := (routeOfferSeed ^ 0x524F5554 ^ spinCount \
			^ (0xA670 if kind == RouteCards.ROUTE_AUGMENT else 0x504F)) & M32
	if kind == RouteCards.ROUTE_AUGMENT:
		if augmented_modifier_active(3):
			return []
		return PacteCards.draw("augment", draw_seed,
			MetaStateStore.unlocked_augment_cards(), _augment_draw_exclusions(), 3, max_tier)
	if kind == RouteCards.ROUTE_POWER:
		return PacteCards.draw("power", draw_seed ^ 0x9E3779B9,
			MetaStateStore.unlocked_power_cards(), selectedPowerCardIds, 3, max_tier)
	return []

func _route_build_offer_array() -> Array[String]:
	var result: Array[String] = []
	if routeBuildOfferIds is Array:
		for value in routeBuildOfferIds as Array:
			result.append(PacteCards.normalise_card_id(String(value)))
	return result

func route_build_card_cost(card_id: String) -> int:
	if routeBuildFreeTier or routeContext == "flatline":
		return 0
	return calculate_run_price(PacteCards.cost_for(card_id))

func route_build_card_requires_symbol(card_id: String) -> bool:
	return PacteCards.reward_amp_ids().has(PacteCards.normalise_card_id(card_id))

func route_build_remaining_after(card_id: String) -> int:
	return maxi(0, int(lucidityCoins) - route_build_card_cost(card_id))

func route_build_card_affordable(card_id: String) -> bool:
	return routeDestination == routeBuildKind \
			and _route_build_offer_array().has(PacteCards.normalise_card_id(card_id)) \
			and int(lucidityCoins) >= route_build_card_cost(card_id)

## Creates the exact two-card dealer offer after a target or a survivable loss.
## A prepared offer is never rerolled on scene re-entry or save/resume.
func prepare_route_offer(context: String, seed_override := -1) -> bool:
	if routeOfferPending:
		return true
	if context != "wealth_target" and context != "flatline":
		return false
	if context == "flatline" and int(MetaStateStore.campaignNeuronsLeft) <= 0:
		return false
	var seed := seed_override if seed_override >= 0 else _seed(
		0x524F5554 ^ (wealthTargetIndex * 0x9E3779B9) ^ spinCount)
	routeOfferSeed = seed & M32
	routeOfferCards = RouteCards.offer(routeOfferSeed, context)
	routeOfferRerollCount = 0
	routeContext = context
	routeOfferPending = _route_offer_array().size() == RouteCards.OFFER_COUNT
	routeDestination = ""
	routeSelectedCardId = ""
	routePacteVisit = false
	routePacteFreeTier = false
	pacteCostsActive = false
	routeBuildKind = ""
	routeBuildOfferIds = null
	routeBuildFreeTier = false
	routeBuildSelectedId = ""
	routeBonusClaimed = false
	routeBonusRewardId = ""
	routeBonusSpinSeed = 0
	_commit()
	return routeOfferPending

## Converts a pre-route build from an older save. Previous builds parked the
## player in pacte_threshold; the current build resumes that save at the shared
## route offer so Pacte remains start-only without losing the run.
func migrate_legacy_pacte_to_route() -> bool:
	if runPhase != "pacte_threshold" and not pacteThresholdPending \
			and not pacteAfterFlatlinePending:
		return false
	var context := "flatline" if lastEnding == "flatline" or pacteAfterFlatlinePending \
			else "wealth_target"
	if context == "wealth_target":
		roundContinuationPending = true
	runPhase = "over"
	lastEnding = "flatline" if context == "flatline" else null
	pacteThresholdPending = false
	pacteThresholdOpened = false
	pacteAfterFlatlinePending = false
	pacteTargetRoundVisit = false
	return prepare_route_offer(context)

func _open_route_build(kind: String, card: Dictionary) -> bool:
	var offers := _route_build_offers(kind)
	if offers.is_empty():
		return false
	routeDestination = kind
	routePacteVisit = false
	routePacteFreeTier = routeContext == "flatline" or bool(card.get("freeLossRoute", false))
	pacteCostsActive = false
	routeBuildKind = kind
	routeBuildOfferIds = offers
	routeBuildFreeTier = routePacteFreeTier
	routeBuildSelectedId = ""
	routeBonusClaimed = false
	routeBonusRewardId = ""
	routeBonusSpinSeed = 0
	# This is a between-machine investment, not a second Pacte phase. Keeping
	# runPhase over makes save/resume and the next machine use the existing lifecycle.
	runPhase = "over"
	lastEnding = "flatline" if routeContext == "flatline" else null
	_commit()
	return true

func _open_route_bonus() -> bool:
	routeDestination = RouteCards.ROUTE_BONUS
	routePacteVisit = false
	pacteCostsActive = false
	routeBuildKind = ""
	routeBuildOfferIds = null
	routeBuildFreeTier = false
	routeBuildSelectedId = ""
	routeBonusClaimed = false
	routeBonusRewardId = ""
	routeBonusSpinSeed = 0
	runPhase = "over"
	lastEnding = "flatline" if routeContext == "flatline" else null
	_commit()
	return true

func _open_route_sacrifice() -> bool:
	routeDestination = RouteCards.ROUTE_SACRIFICE
	routePacteVisit = false
	pacteCostsActive = false
	routeBuildKind = ""
	routeBuildOfferIds = null
	routeBuildFreeTier = false
	routeBuildSelectedId = ""
	routeBonusClaimed = false
	routeBonusRewardId = ""
	routeBonusSpinSeed = 0
	sacrificeLaterPending = true
	runPhase = "over"
	lastEnding = "flatline" if routeContext == "flatline" else null
	_commit()
	return true

func select_route(card_id: String) -> bool:
	if not routeOfferPending or not route_card_affordable(card_id):
		return false
	var card := route_offer_card(card_id)
	var offered_cards := _route_offer_array()
	var offered_reroll_count := int(routeOfferRerollCount)
	routeOfferPending = false
	routeOfferCards = null
	routeOfferRerollCount = 0
	routeSelectedCardId = card_id
	var route_type := String(card.get("routeType", ""))
	var opened := false
	match route_type:
		RouteCards.ROUTE_SHOP:
			routeDestination = RouteCards.ROUTE_SHOP
			routePacteVisit = false
			pacteCostsActive = false
			runPhase = "over"
			lastEnding = "flatline" if routeContext == "flatline" else null
			opened = true
		RouteCards.ROUTE_AUGMENT, RouteCards.ROUTE_POWER:
			opened = _open_route_build(route_type, card)
		RouteCards.ROUTE_BONUS:
			opened = _open_route_bonus()
		RouteCards.ROUTE_SACRIFICE:
			opened = _open_route_sacrifice()
		_:
			opened = false
	if not opened:
		routeOfferPending = true
		routeOfferCards = offered_cards
		routeOfferRerollCount = offered_reroll_count
		routeSelectedCardId = ""
		routeDestination = ""
		routePacteVisit = false
		routePacteFreeTier = false
		pacteCostsActive = false
		routeBuildKind = ""
		routeBuildOfferIds = null
		routeBuildFreeTier = false
		routeBuildSelectedId = ""
		routeBonusClaimed = false
		routeBonusRewardId = ""
		routeBonusSpinSeed = 0
		_commit()
		return false
	_commit()
	return true

## Refusing all routes does not spend Lucidity or spins. The current target/loss
## continuation is then handed directly to the next machine segment.
func refuse_routes() -> bool:
	if not routeOfferPending:
		return false
	routeOfferPending = false
	routeOfferCards = null
	routeOfferRerollCount = 0
	routeSelectedCardId = ""
	_open_route_sacrifice()
	return finish_route_destination()

func complete_route_build_selection(card_id: String, reward_symbol := "",
		replacement_power_id := "") -> bool:
	if routeBuildKind != RouteCards.ROUTE_AUGMENT and routeBuildKind != RouteCards.ROUTE_POWER:
		return false
	var normalised := PacteCards.normalise_card_id(card_id)
	if not _route_build_offer_array().has(normalised) or routeBuildSelectedId != "":
		return false
	if not route_build_card_affordable(normalised):
		return false
	var runtime_power_id := PacteCards.power_id(normalised)
	var removed_power_id := PacteCards.normalise_card_id(replacement_power_id)
	var needs_replacement := routeBuildKind == RouteCards.ROUTE_POWER \
		and power_requires_replacement(normalised)
	if needs_replacement:
		if removed_power_id == "":
			begin_power_replacement(normalised, "route_build")
			return false
		if not _valid_power_replacement(normalised, removed_power_id):
			return false
	elif removed_power_id != "":
		return false
	if routeBuildKind == RouteCards.ROUTE_AUGMENT and route_build_card_requires_symbol(normalised):
		if reward_symbol == "" or reward_symbol == "flatline" \
				or not Symbols.BASE_SYMBOL_CYCLE.has(reward_symbol):
			return false
	var cost := route_build_card_cost(normalised)
	if cost > 0:
		lucidityCoins -= cost
	if routeBuildKind == RouteCards.ROUTE_AUGMENT:
		if route_build_card_requires_symbol(normalised):
			MetaStateStore.set_reward_amp_symbol(reward_symbol)
		if not _apply_pacte_augment(normalised):
			lucidityCoins += cost
			return false
		selectedAugmentCardIds = selectedAugmentCardIds.duplicate()
		selectedAugmentCardIds.append(normalised)
	else:
		selectedPowerCardIds = selectedPowerCardIds.duplicate()
		if needs_replacement:
			if not _replace_active_power(normalised, removed_power_id):
				lucidityCoins += cost
				return false
		else:
			selectedPowerCardIds.append(normalised)
			ownedPowerIds = ownedPowerIds.duplicate()
			if not ownedPowerIds.has(runtime_power_id):
				ownedPowerIds.append(runtime_power_id)
			ownedPowerIds = _cap_power_ids(ownedPowerIds)
	routeBuildSelectedId = normalised
	routeBuildOfferIds = null
	_refresh_pacte_derivatives()
	_commit()
	return true

## Returns the selected wheel reward, or an empty dictionary before the turn is
## prepared.  The scene reads this instead of recreating reward data locally.
func route_bonus_reward() -> Dictionary:
	if not FortuneWheelRules.is_valid_reward(routeBonusRewardId):
		return {}
	return FortuneWheelRules.reward_for_id(routeBonusRewardId)

## Locks one deterministic segment before the wheel animation starts.  The result
## is saved immediately, which makes a mid-animation close safe to resume.
func prepare_route_bonus_spin() -> Dictionary:
	if routeDestination != RouteCards.ROUTE_BONUS or routeBonusClaimed:
		return {}
	if FortuneWheelRules.is_valid_reward(routeBonusRewardId):
		return route_bonus_reward()
	var seed := (int(routeOfferSeed) ^ (int(spinCount) * 0x9E3779B9) ^ 0x57484545) & 0xFFFFFFFF
	var reward := FortuneWheelRules.roll(seed)
	var reward_id := String(reward.get("id", ""))
	if not FortuneWheelRules.is_valid_reward(reward_id):
		return {}
	routeBonusSpinSeed = seed
	routeBonusRewardId = reward_id
	_commit()
	return reward

## Pays the chosen wheel segment exactly once. Run Gold stays on the current run
## and wallet credits go through MetaStateStore so the jackpot survives the next
## machine and future campaigns.
func claim_route_bonus_reward(reward_id: String = "") -> bool:
	if routeDestination != RouteCards.ROUTE_BONUS or routeBonusClaimed:
		return false
	var resolved_id := routeBonusRewardId if reward_id.is_empty() else reward_id
	if not FortuneWheelRules.is_valid_reward(resolved_id):
		return false
	if not routeBonusRewardId.is_empty() and routeBonusRewardId != resolved_id:
		return false
	var reward := FortuneWheelRules.reward_for_id(resolved_id)
	var run_lucidity := maxi(0, int(reward.get("runLucidity", 0)))
	var wallet_credits := maxi(0, int(reward.get("walletCredits", 0)))
	var meta := _meta_store()
	if wallet_credits > 0 and (meta == null or not meta.has_method("grant_lucidity_wallet")):
		return false
	if run_lucidity > 0:
		lucidityCoins += run_lucidity
	if wallet_credits > 0:
		meta.grant_lucidity_wallet(wallet_credits)
	routeBonusRewardId = resolved_id
	routeBonusClaimed = true
	_commit()
	return true

## Compatibility entry point for older route checks and saves.  Direct callers
## that do not use the wheel retain the original +10 run-Gold bonus; the scene
## always uses prepare_route_bonus_spin() and claim_route_bonus_reward().
func claim_route_bonus() -> bool:
	if not FortuneWheelRules.is_valid_reward(routeBonusRewardId):
		return claim_route_bonus_reward(FortuneWheelRules.REWARD_RUN_10)
	return claim_route_bonus_reward()

## Leaves the selected route and starts the next machine without spending a
## campaign neuron. The selected route is cleared only after the new machine has
## been successfully prepared, so a failed start remains resumable.
func finish_route_destination() -> bool:
	if routeOfferPending:
		return false
	if routeDestination == "" and routeContext == "":
		return false
	if (routeDestination == RouteCards.ROUTE_AUGMENT \
			or routeDestination == RouteCards.ROUTE_POWER) and routeBuildSelectedId == "":
		return false
	if routeDestination == RouteCards.ROUTE_BONUS and not routeBonusClaimed:
		return false
	if routeDestination != "":
		runPhase = "over"
		lastEnding = "flatline" if routeContext == "flatline" else null
	if not start_new_run([], {}, false):
		_commit()
		return false
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
	if routeOfferPending or routeDestination != "":
		return true
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
	var kept_shop_upgrades: Array = runShopUpgrades.duplicate() if continuing else []
	var kept_dealer_services: Array = runDealerServices.duplicate() if continuing else []
	var kept_augment_cards: Array = selectedAugmentCardIds.duplicate() if continuing else []
	var kept_power_cards: Array = selectedPowerCardIds.duplicate() if continuing else []
	var kept_removed_power_ids: Array = powerReplacementRemovedIds.duplicate() if continuing else []
	var kept_abilities_used: Array = abilitiesUsed.duplicate() if continuing else []
	var kept_guaranteed_win_spins := guaranteedWinSpins if continuing else 0
	var kept_joker_active := pacteJokerActive if continuing else false
	var kept_pacte_threshold_visits := pacteThresholdVisits if continuing else 0
	var kept_sacrifice_later := sacrificeLaterPending if continuing else false
	var kept_consumables := runConsumables.duplicate(true) if continuing else {}
	var kept_lucidity := lucidityCoins if continuing else 0
	if consume_campaign_neuron:
		if not MetaStateStore.reserve_campaign_neuron_for_run():
			_commit()
			return false
	campaignNeuronPending = consume_campaign_neuron
	campaignNeuronRunActive = consume_campaign_neuron
	endingSettlementCommitted = false
	endingBankCommitted = false
	endingScoreSnapshot = -1
	endingLuciditySnapshot = -1
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
	lucidityCoins = kept_lucidity
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
	elif continuing:
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
	abilitiesUsed = kept_abilities_used
	# augmentedTier survives: the menu sets it before the pre-run dealer shop, and
	# it applies to the run this call starts (issue #111).
	powersUsedThisSpin = 0
	powerRestoreCharges = EconomyConst.POWER_RESTORE_CHARGE_MAX
	powerRestoreProgress = 0
	ownedUpgrades = owned_permanents.duplicate()
	selectedAugmentCardIds = kept_augment_cards
	selectedPowerCardIds = kept_power_cards
	powerReplacementRemovedIds = kept_removed_power_ids
	pacteThresholdVisits = kept_pacte_threshold_visits
	runShopUpgrades = kept_shop_upgrades
	runDealerServices = kept_dealer_services
	sacrificeLaterPending = kept_sacrifice_later
	# The Pacte selection is the source of run powers. A direct/legacy start keeps
	# only the permanent powers the player actually owns; Shift and Reroll are not
	# silently injected into a fresh loadout.
	ownedPowerIds = HERO_POWER_IDS.duplicate()
	if not open_pacte:
		if ownedUpgrades.has("perm_shift") and not kept_removed_power_ids.has("shift"):
			ownedPowerIds.append("shift")
		if ownedUpgrades.has("perm_memory") and not kept_removed_power_ids.has("memory"):
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
		if not kept_removed_power_ids.has(kept_power) and not ownedPowerIds.has(kept_power):
			ownedPowerIds.append(kept_power)
	ownedPowerIds = _cap_power_ids(ownedPowerIds)
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
	# Chip Augments survive every new run, Pacte included: they are campaign state now
	# (issue #132). Pre-run purchases are FOR this run and the overlay below applies them.
	brainBoostSpins = 0
	guaranteedWinSpins = kept_guaranteed_win_spins
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
	scriptedReels = null
	banBrainSpins = 0
	potionSpins = 0
	forceFlatlineSpins = 0
	guaranteedTripleSpins = 0
	hideResultSpins = 0
	cocktailMalusSpins = 0
	jokerFlatlineSpins = 0
	pendingPowerBarDrains = 0
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
	_apply_chip_augment_run_overlay()
	_apply_route_shop_upgrades()
	_apply_route_dealer_services()
	pendingPowerRestores = []
	pacteSeed = seed_override if seed_override >= 0 else _seed(PACTE_INITIAL_DRAW_SEED)
	pacteOfferAugmentIds = PacteCards.draw("augment", pacteSeed,
		MetaStateStore.unlocked_augment_cards(), _augment_draw_exclusions(), 3)
	pacteOfferPowerIds = PacteCards.draw("power", pacteSeed ^ 0x9e3779b9,
		MetaStateStore.unlocked_power_cards(), selectedPowerCardIds, 3)
	pacteSelectedAugmentId = ""
	pacteSelectedPowerId = ""
	pendingPowerReplacement = {}
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
	routeOfferPending = false
	routeOfferCards = null
	routeOfferSeed = 0
	routeOfferRerollCount = 0
	routeContext = ""
	routeDestination = ""
	routeSelectedCardId = ""
	routePacteVisit = false
	routePacteFreeTier = false
	pacteCostsActive = false
	routeBuildKind = ""
	routeBuildOfferIds = null
	routeBuildFreeTier = false
	routeBuildSelectedId = ""
	routeBonusClaimed = false
	routeBonusRewardId = ""
	routeBonusSpinSeed = 0
	_commit()
	return true

func pacte_active() -> bool:
	# The full two-deck ritual is a run-start ceremony only. Between-machine
	# build routes use routeBuildKind and never reopen this scene.
	return runPhase == "pacte_initial"

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

## Commit the Run Wallet after a machine segment's payout screen has finished. The
## machine calculates the net remainder first; this setter is the only handoff point
## that rewrites the spendable run balance, so score-derived Lucidity is never moved
## into the wallet early and deducted afterward.
func settle_run_lucidity_after_deductions(amount: int) -> int:
	lucidityCoins = maxi(0, amount)
	_commit()
	return lucidityCoins


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
		bill = EconomyConst.overflow_bill(overflow, target, augmented_anger_tax_rate())
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
	# Threshold Pacte visits were removed from the player-facing route loop. Keep
	# the method as a save/API compatibility stub so older callers fail closed.
	return false

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

func pacte_card_cost(card_id: String) -> int:
	if not pacteCostsActive or routePacteFreeTier:
		return 0
	return calculate_run_price(PacteCards.cost_for(card_id))

func pacte_remaining_after(card_ids: Array[String]) -> int:
	var total := 0
	for card_id in card_ids:
		total += pacte_card_cost(card_id)
	return maxi(0, int(lucidityCoins) - total)

func select_pacte_augment(card_id: String) -> bool:
	if not pacte_active() or pacteSelectedAugmentId != "":
		return false
	if not _pacte_offer_array(pacteOfferAugmentIds).has(card_id) \
			or selectedAugmentCardIds.has(card_id):
		return false
	pacteSelectedAugmentId = card_id
	_commit()
	return true

func complete_pacte_selection(augment_id: String, power_id: String,
		replacement_power_id := "") -> bool:
	if not pacte_active():
		return false
	var augment_card_id := augment_id if augment_id != "" else pacteSelectedAugmentId
	var power_card_id := power_id if power_id != "" else pacteSelectedPowerId
	power_card_id = PacteCards.normalise_card_id(power_card_id)
	# Diamond (issue #111) deals no augment at the threshold visit, so an empty
	# augment is legitimate exactly when the offer itself is empty. Everywhere else
	# a blank augment is still a caller bug and still refused.
	var augment_offer := _pacte_offer_array(pacteOfferAugmentIds)
	var augment_skipped := augment_card_id == "" and augment_offer.is_empty()
	if (augment_card_id == "" and not augment_skipped) or power_card_id == "":
		return false
	if not augment_skipped and not augment_offer.has(augment_card_id):
		return false
	if not _pacte_offer_array(pacteOfferPowerIds).has(power_card_id):
		return false
	if selectedAugmentCardIds.has(augment_card_id) or selectedPowerCardIds.has(power_card_id):
		return false
	var removed_power_id := PacteCards.normalise_card_id(replacement_power_id)
	var needs_replacement := power_requires_replacement(power_card_id)
	if needs_replacement:
		if removed_power_id == "":
			begin_power_replacement(power_card_id, "pacte")
			pacteSelectedPowerId = power_card_id
			_commit()
			return false
		if not _valid_power_replacement(power_card_id, removed_power_id):
			return false
	elif removed_power_id != "":
		return false
	var purchase_ids: Array[String] = []
	if not augment_skipped:
		purchase_ids.append(augment_card_id)
	purchase_ids.append(power_card_id)
	var purchase_cost := 0
	for purchase_id in purchase_ids:
		purchase_cost += pacte_card_cost(purchase_id)
	if purchase_cost > lucidityCoins:
		return false
	if purchase_cost > 0:
		lucidityCoins -= purchase_cost
	if not augment_skipped and not _apply_pacte_augment(augment_card_id):
		lucidityCoins += purchase_cost
		return false
	var runtime_power_id := PacteCards.power_id(power_card_id)
	if not augment_skipped:
		selectedAugmentCardIds = selectedAugmentCardIds.duplicate()
		selectedAugmentCardIds.append(augment_card_id)
	selectedPowerCardIds = selectedPowerCardIds.duplicate()
	if not ownedPowerIds.has(runtime_power_id):
		if needs_replacement:
			if not _replace_active_power(power_card_id, removed_power_id):
				lucidityCoins += purchase_cost
				return false
		else:
			ownedPowerIds = ownedPowerIds.duplicate()
			ownedPowerIds.append(runtime_power_id)
			ownedPowerIds = _cap_power_ids(ownedPowerIds)
	if not needs_replacement and not selectedPowerCardIds.has(power_card_id):
		selectedPowerCardIds.append(power_card_id)
	pacteSelectedAugmentId = ""
	pacteSelectedPowerId = ""
	pacteOfferAugmentIds = null
	pacteOfferPowerIds = null
	if runPhase == "pacte_threshold" and not routePacteVisit:
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
	# A staged augment is the normal precondition — the power row only opens once the
	# augment is chosen. Diamond's suppressed offer is the one case with no augment to
	# stage, so the power row is the whole ritual and gates on the empty offer instead.
	if not pacte_active():
		return false
	if pacteSelectedAugmentId == "" and not _pacte_offer_array(pacteOfferAugmentIds).is_empty():
		return false
	var normalised := PacteCards.normalise_card_id(card_id)
	if not _pacte_offer_array(pacteOfferPowerIds).has(normalised) \
			or selectedPowerCardIds.has(normalised):
		return false
	pacteSelectedPowerId = normalised
	_commit()
	return complete_pacte_selection("", normalised)

func open_threshold_pacte() -> bool:
	# A full Pacte scene is available only from start_new_run(..., open_pacte=true).
	# Older saved threshold flags are converted to route offers on menu resume.
	return false

## A deterministic fallback used by direct scene smoke setup and accessibility
## automation. A real player always makes these choices in Pacte's card UI.
func skip_pacte_with_defaults() -> bool:
	if not pacte_active():
		return false
	var augment_offers := _pacte_offer_array(pacteOfferAugmentIds)
	var power_offers := _pacte_offer_array(pacteOfferPowerIds)
	if power_offers.is_empty():
		return false
	# An empty augment offer is diamond's suppressed threshold visit (issue #111),
	# not a broken draw: take the power alone rather than refusing the whole ritual.
	if augment_offers.is_empty():
		return complete_pacte_selection("", power_offers[0])
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

## Returns true only when this ending was committed for the current run.  A queued
## animation, a scene rebuild, or an app resume may call the entry point again; the
## persisted transaction flag makes those repeats presentation-only.
func end_run(ending: String, score_snapshot := -1, lucidity_snapshot := -1) -> bool:
	if runPhase == "over" and String(lastEnding) == ending and endingSettlementCommitted:
		return false
	# Capture before any terminal cleanup changes the live run balance.  Callers
	# pass the values they read from the authoritative machine state; direct
	# callers fall back to the store itself.
	endingScoreSnapshot = maxi(0, int(score_snapshot if score_snapshot >= 0 else scoreEarned))
	endingLuciditySnapshot = maxi(0,
		int(lucidity_snapshot if lucidity_snapshot >= 0 else lucidityCoins))
	runPhase = "over"
	lastEnding = ending
	if ending == "game_over":
		# A terminal campaign loss removes the run's remaining credits instead of
		# carrying the normal flatline retention into the next campaign.
		lucidityCoins = 0
	# A normal run reserves one neuron at launch.  The explicit active flag also
	# covers a live paid run whose reservation flag was lost by an older snapshot;
	# wealth continuations and target breaks set it false, so neither can spend twice.
	var should_consume_neuron := campaignNeuronPending
	if not should_consume_neuron and campaignNeuronRunActive \
			and (ending == "flatline" or ending == "game_over") \
			and not wealthContinued:
		should_consume_neuron = true
	if should_consume_neuron:
		MetaStateStore.finalize_campaign_neuron_for_run()
		if ending == "game_over" and int(MetaStateStore.campaignNeuronsLeft) <= 0:
			# The terminal loss is committed here, before any ending scene or route
			# transition can run.  This keeps direct state/save-resume callers in the
			# same campaign-failed state as the machine presentation path.
			MetaStateStore.mark_campaign_failed()
	campaignNeuronPending = false
	campaignNeuronRunActive = false
	endingSettlementCommitted = true
	endingBankCommitted = false
	# An in-run dealer is part of the segment that just ended.  Clear its persisted
	# offer so a terminal/route resume cannot resurrect an intentionally dismissed UI.
	dealerIncoming = false
	dealerPending = false
	dealerOfferIds = null
	dealerAugmentOfferId = ""
	var campaign_neurons_after := int(MetaStateStore.campaignNeuronsLeft)
	# Campaign-health crossings no longer open a second Pacte ritual. The same
	# between-machine offer is used after every survivable loss.
	pacteThresholdPending = false
	pacteThresholdOpened = false
	pacteAfterFlatlinePending = false
	pacteTargetRoundVisit = false
	if ending == "flatline" and campaign_neurons_after > 0:
		# The route offer is prepared with the ending snapshot, then the flatline
		# overlay gets time to present before the route scene opens.
		prepare_route_offer("flatline")
	_commit()
	return true

## Claims the one meta-bank transaction belonging to the committed ending.  The
## machine calls this immediately for flatline/game-over and on START AGAIN for
## Wealth, so the animation itself never mutates the authoritative amount.
func claim_ending_bank() -> bool:
	if not endingSettlementCommitted or endingBankCommitted:
		return false
	endingBankCommitted = true
	_commit()
	return true

func continue_run() -> void:
	if runPhase != "over" or lastEnding != "wealth":
		return
	runPhase = "running"
	lastEnding = null
	wealthContinued = true
	# Wealth continuation is the same paid run, not a second campaign-neuron claim.
	campaignNeuronPending = false
	campaignNeuronRunActive = false
	endingSettlementCommitted = false
	endingBankCommitted = false
	endingScoreSnapshot = -1
	endingLuciditySnapshot = -1
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
		_book_reward_scale(), _hallucination_reward_scale())

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
				_book_reward_scale(), _hallucination_reward_scale())
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
		_book_reward_scale(), _hallucination_reward_scale())
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

## Whether the campaign still holds its one rescue: the chip is owned and unspent. The
## augment is campaign-scoped, so this does NOT re-arm on a new run, a Pacte or a Wealth
## target round break — one purchase buys exactly one save.
func emergency_reserve_armed() -> bool:
	return int(MetaStateStore.chipAugmentsPurchased.get("aug_emergency_reserve", 0)) > 0 \
		and not MetaStateStore.emergencyReserveUsed

## Emergency Reserve (issue #132). A PAID spin that leaves the run with nothing left to
## play — no neurons and no free spins — gets exactly one paid spin back. Resource
## exhaustion only: a flatline strike kills the run through flatlineResultCount and a
## combo loss through comboDefeatPending, neither of which is read here, so neither can
## spend the reserve. Returns whether it fired; the caller owns the commit.
func _try_emergency_reserve(paid_spin: bool) -> bool:
	if not paid_spin or neurons > 0 or freeSpinsRemaining > 0:
		return false
	if not emergency_reserve_armed():
		return false
	MetaStateStore.emergencyReserveUsed = true
	MetaStateStore.save_state() # losing this flag would hand out a second free rescue
	var decay := maxi(1, Economy.compute_neuron_decay(ownedUpgrades))
	neurons = mini(_neuron_cap(),
		neurons + ChipAugments.EMERGENCY_RESERVE_SPINS * decay)
	emergencyReserveSerial += 1 # the machine animates on a change, like free-spin grants
	return true

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
	# The spade cycle starts the moment the light goes out, so the pips read empty on
	# the spin the power actually came back rather than already part-way along.
	powerRestoreProgress = 0

## One charge back per spin launched (never past the cap): the restore economy refills
## with play rather than resetting whole, so a spin cannot repeat the previous spin's
## double restore.
##
## Augmented spade modifier (issue #111) halves that throughput: the charge takes
## EconomyConst.SPADE_RESTORE_CYCLE_SPINS spins to come back, counted from the spend rather than from
## global spin parity, so the wait is something the player started and can plan around.
## It is a spin counter rather than a smaller POWER_RESTORE_RECHARGE_PER_SPIN because the
## cap is 1 and a fractional charge has nowhere to live.
func _recharge_restores() -> void:
	if not augmented_modifier_active(2):
		powerRestoreProgress = 0
		powerRestoreCharges = mini(EconomyConst.POWER_RESTORE_CHARGE_MAX,
			restore_budget_left() + EconomyConst.POWER_RESTORE_RECHARGE_PER_SPIN)
		return
	if restore_budget_left() >= EconomyConst.POWER_RESTORE_CHARGE_MAX:
		# Nothing owed: the pips stay dark so a full light never shows a countdown.
		powerRestoreProgress = 0
		return
	powerRestoreProgress = mini(EconomyConst.SPADE_RESTORE_CYCLE_SPINS, powerRestoreProgress + 1)
	if powerRestoreProgress >= EconomyConst.SPADE_RESTORE_CYCLE_SPINS:
		# The charge lands on the same spin the last pip lights, so the player sees the
		# countdown complete and the light come back as one event.
		powerRestoreCharges = mini(EconomyConst.POWER_RESTORE_CHARGE_MAX,
			restore_budget_left() + EconomyConst.POWER_RESTORE_RECHARGE_PER_SPIN)

## How many pips under the restore light are lit: 0 while a charge is banked, then one
## per spin waited. Only ever non-zero on a spade/joker run.
func restore_cycle_progress() -> int:
	if not augmented_modifier_active(2):
		return 0
	return clampi(powerRestoreProgress, 0, EconomyConst.SPADE_RESTORE_CYCLE_SPINS)

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
	return Economy.compute_tunnel_vision_reward_scale(ownedUpgrades)

## Learning's cut is NOT part of the general scale: it is charged only to wins the Book
## joker actually made, so a spin that never saw a book pays in full. The scorer applies
## it on top of _active_reward_scale inside its joker branch.
func _book_reward_scale() -> float:
	return Economy.compute_book_reward_scale(ownedUpgrades)

## Hallucination's cut is charged the same way (issue #185): only to the triples the
## card itself promotes a visible pair into. It was in _active_reward_scale, which
## taxed natural triples — the syringe triple included — pairs, and every other reward
## the run made, so owning the card was a flat -70% on everything it never touched.
func _hallucination_reward_scale() -> float:
	return Economy.compute_hallucination_reward_scale(ownedUpgrades)

func _pair_score_multiplier(pair_boost_active: bool) -> float:
	var multiplier := Economy.compute_pair_score_multiplier(ownedUpgrades)
	if pair_boost_active:
		multiplier *= float(pairBoostMult)
	return multiplier

func _passive_lucidity_per_spin() -> int:
	return Economy.compute_passive_lucidity(ownedUpgrades)

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
			and outcome_win_type in SpinResult.PAYING_WIN_TYPES:
		flatline_boost_bonus = win_score * (EconomyConst.FLATLINE_WIN_BOOST_MULT - 1)
		flatline_boost_applied = true
		outcome["scoreDelta"] = int(outcome["scoreDelta"]) + flatline_boost_bonus
		outcome["coinsDelta"] = int(outcome["coinsDelta"]) + flatline_boost_bonus
	if winBoostEnabled and int(outcome.get("scoreDelta", 0)) > 0 \
			and outcome_win_type in SpinResult.PAYING_WIN_TYPES:
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
			and outcome_win_type in SpinResult.PAYING_WIN_TYPES:
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
		symbolRewardBonuses, Economy.has_solo_as_pair(ownedUpgrades), _book_reward_scale(),
		_hallucination_reward_scale())
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
		symbolRewardBonuses, Economy.has_solo_as_pair(ownedUpgrades), _book_reward_scale(),
		_hallucination_reward_scale())
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
		symbolRewardBonuses, Economy.has_solo_as_pair(ownedUpgrades), _book_reward_scale(),
		_hallucination_reward_scale())

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
			Economy.has_solo_as_pair(ownedUpgrades), _book_reward_scale(),
			_hallucination_reward_scale())
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
			source_symbol, Economy.has_solo_as_pair(ownedUpgrades), _book_reward_scale(),
			_hallucination_reward_scale())
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
	# A queued or walking-in dealer used to refuse every consumable here while the stash
	# still read enabled, so the tap was a silent no-op — worst of all for an item that
	# would have beaten the Wealth target on the spot. The dealer is a presentation
	# event, not a lock: he already stands down for a beaten target, so the item lands.
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
		# A joker run deals these items in their inverted form; everything else about
		# using one (the charge spent, the stash, the hint) is identical (issue #111).
		var e: Dictionary = InRunItems.effect_for(consumable_id,
			augmented_joker_items_active()) as Dictionary
		match String(e["type"]):
			"skipDecay":
				# Energy Drink: neurons preserved for N spins, and nothing else. Stacking
				# two stacks the rush (issue #97). The gauge lock and the compulsory spin
				# that used to be the price are gone — the joker version below is the only
				# place the drink still costs anything.
				decaySkips += int(e["spins"])
			"compulsion":
				# Joker Energy Drink: the bill with no rush in front of it. Capped at one
				# forced spin however many are drunk at once, like the old debuff was.
				pendingCompulsiveSpinSkips = maxi(pendingCompulsiveSpinSkips,
					int(e["compulsiveSpins"]))
			"cocktailMalus":
				# Joker Cocktail: the same rarity points, charged instead of paid.
				cocktailMalusSpins += int(e["spins"])
			"drainPowerBar":
				# Joker Water: the gauge progress toward the next power restore is
				# forfeited. The machine owns the gauge, so this queues the drain for it
				# and nothing here touches the banked score or the wallet.
				pendingPowerBarDrains += 1
			"flatlineOneReel":
				# Joker Red Pill: one reel is dragged to flatline, with no triple owed back.
				jokerFlatlineSpins += int(e["spins"])
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

## The countdown's full length — what the dealer bar measures its progress against. The
## Tip must NOT shorten this: the whole point is that the player sees the bar start at
## 2/12 rather than at 0/10, which only reads as a head start if the scale stays put.
func dealer_countdown_cycle_length() -> int:
	return maxi(1, dealer_countdown_start)

## What a resolved visit resets the countdown TO. Dealer's Tip takes its head start off
## the top, so the very next cycle begins part-way along instead of empty.
func dealer_countdown_reset_value() -> int:
	var length := dealer_countdown_cycle_length()
	return clampi(length - dealer_tip_head_start(), 1, length)

## Countdown units the Tip skips at every reset (0 without the augment).
func dealer_tip_head_start() -> int:
	if int(MetaStateStore.chipAugmentsPurchased.get("aug_dealer_tip", 0)) <= 0:
		return 0
	return ChipAugments.DEALER_TIP_HEAD_START

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
	return calculate_run_price(DEALER_REROLL_BASE_COST * (dealerRerollCount + 1))

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
	# A club shop's counter is legitimately one item short, so the "already rolled"
	# bar is the smaller of the classic pair and this run's count — otherwise every
	# open would re-roll the offer and reset the reroll price with it.
	if prerunOfferIds is Array \
			and (prerunOfferIds as Array).size() >= mini(2, dealer_offer_count()):
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
## A club run stocks one fewer at both counters (see AUGMENTED_CLUB_OFFER_PENALTY),
## never fewer than one — an empty counter would read as a bug, not as a modifier.
func dealer_offer_count() -> int:
	var count := ChipAugments.EXPANDED_OFFER_COUNT \
		if int(MetaStateStore.chipAugmentsPurchased.get("aug_offer_expand", 0)) > 0 else 2
	return maxi(1, count - augmented_offer_penalty())

## One random eligible augment (stock left) for a fresh visit; "" when the pool
## is exhausted.
func _roll_augment_offer(seed_val: int) -> String:
	var pool := ChipAugments.eligible_ids(MetaStateStore.chipAugmentsPurchased)
	if pool.is_empty():
		return ""
	var rng := LobRNG.new(seed_val & M32)
	return String(pool[mini(pool.size() - 1, floori(rng.next() * pool.size()))])

## Chip Discount applies to augment ("chip") prices; project rounding rules.
func chip_augment_price(augment_id: String) -> int:
	var entry: Variant = ChipAugments.map().get(augment_id, null)
	if entry == null:
		return 0
	var progressed := calculate_run_price(int(entry["cost"]))
	return ChipAugments.discounted_price(_augmented_marked_up(progressed),
		int(MetaStateStore.chipAugmentsPurchased.get("aug_chip_discount", 0)))

## Consumable Discount applies to the (pre-run) consumable shop prices.
func consumable_price(consumable_id: String) -> int:
	var cmap := Consumables.map()
	if not cmap.has(consumable_id):
		return 0
	var progressed := calculate_run_price(int(cmap[consumable_id]["shopCost"]))
	return ChipAugments.discounted_price(
		_augmented_marked_up(progressed),
		int(MetaStateStore.chipAugmentsPurchased.get("aug_consumable_discount", 0)))

func route_shop_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in ShopItems.ids():
		var item := ShopItems.item(item_id)
		item["cost"] = route_shop_item_cost(item_id)
		result.append(item)
	return result

func route_shop_item_cost(item_id: String) -> int:
	return _augmented_marked_up(calculate_run_price(ShopItems.cost(item_id)))

func route_shop_item_purchased(item_id: String) -> bool:
	return runShopUpgrades.has(item_id) if ShopItems.item(item_id).get("kind", "") == "upgrade" else false

func buy_route_shop_item(item_id: String) -> bool:
	if routeDestination != RouteCards.ROUTE_SHOP:
		return false
	var item := ShopItems.item(item_id)
	var cost := route_shop_item_cost(item_id)
	if item.is_empty() or lucidityCoins < cost:
		return false
	var kind := String(item.get("kind", ""))
	if kind == "upgrade" and runShopUpgrades.has(item_id):
		return false
	if kind == "consumable" and Consumables.total_copies(runConsumables) >= max_consumable_slots:
		return false
	lucidityCoins -= cost
	if kind == "consumable":
		runConsumables = runConsumables.duplicate(true)
		runConsumables[item_id] = int(runConsumables.get(item_id, 0)) + 1
	else:
		runShopUpgrades = runShopUpgrades.duplicate()
		runShopUpgrades.append(item_id)
	_commit()
	return true

func route_dealer_services() -> Array[Dictionary]:
	return [
		{ "id": "dealer_route_spins", "name": "BUY TIME", "description": "+3 SPINS.",
			"baseCost": 18, "cost": calculate_run_price(18) },
		{ "id": "dealer_route_guard", "name": "STACK THE DECK",
			"description": "THE NEXT 2 PAID SPINS CANNOT MISS.",
			"baseCost": 16, "cost": calculate_run_price(16) },
		{ "id": "dealer_route_power", "name": "POWER CHIP",
			"description": "RECOVER ONE RANDOM SPENT POWER.",
			"baseCost": 20, "cost": calculate_run_price(20) },
	]

func buy_route_dealer_service(service_id: String) -> bool:
	if routeDestination != RouteCards.ROUTE_DEALER:
		return false
	var service: Dictionary = {}
	for candidate in route_dealer_services():
		if String(candidate["id"]) == service_id:
			service = candidate
			break
	if service.is_empty() or lucidityCoins < int(service["cost"]):
		return false
	lucidityCoins -= int(service["cost"])
	match service_id:
		"dealer_route_spins":
			runDealerServices = runDealerServices.duplicate()
			runDealerServices.append(service_id)
		"dealer_route_guard":
			runDealerServices = runDealerServices.duplicate()
			runDealerServices.append(service_id)
		"dealer_route_power":
			var spent: Array[String] = []
			for power_id in ownedPowerIds:
				if abilitiesUsed.has(power_id):
					spent.append(String(power_id))
			if not spent.is_empty():
				var pick := spent[mini(spent.size() - 1, floori(
					LobRNG.new((routeOfferSeed ^ spinCount) & M32).next() * spent.size()))]
				abilitiesUsed.erase(pick)
	_commit()
	return true

func _apply_route_shop_upgrade(item_id: String) -> void:
	match item_id:
		"shop_brain_feed":
			oddsWeightOverrides = oddsWeightOverrides.duplicate(true)
			oddsWeightOverrides["brain"] = float(oddsWeightOverrides.get("brain", 0.0)) + 3.0
		"shop_pair_guard":
			guaranteedWinSpins += 3
		"shop_spin_reserve":
			neurons = mini(_neuron_cap(), neurons + 2)
		"shop_stasis":
			decaySkips += 2

func _apply_route_shop_upgrades() -> void:
	for item_id in runShopUpgrades:
		_apply_route_shop_upgrade(String(item_id))

func _apply_route_dealer_services() -> void:
	for service_id in runDealerServices:
		match String(service_id):
			"dealer_route_spins":
				neurons = mini(_neuron_cap(), neurons + 3)
			"dealer_route_guard":
				guaranteedWinSpins += 2
	runDealerServices = []

## A base cost after the club markup, on the project rounding rule. Every price the
## dealer shows and charges runs through the two functions above, so buying, selling
## back and the displayed number can never disagree about what a club run costs.
func _augmented_marked_up(base_cost: int) -> int:
	var multiplier := augmented_price_multiplier()
	if is_equal_approx(multiplier, 1.0):
		return base_cost
	return floori(float(base_cost) * multiplier + 0.5)

## The level every readout must show: the persisted permanent level, the levels
## staged in an open odds phase, and this campaign's Symbol Level augments.
## Augments fold into oddsWeightOverrides the moment they are bought, so a table
## that leaves them out shows a level — and a draw chance — the reels no longer
## roll on. Augments may push past odds_max_level, up to the hard cap of 9.
func effective_symbol_level(symbol: String) -> int:
	return odds_upgrade_level(symbol) + int(MetaStateStore.symbolAugmentLevels.get(symbol, 0))

## Same level, under the name the augment picker and its purchase validation use.
func augment_symbol_level(symbol: String) -> int:
	return effective_symbol_level(symbol)

## Augment levels bought for `symbol` alone (0 or 1 — see AUGMENT_LEVELS_PER_SYMBOL),
## as opposed to the effective level the two functions above report.
func symbol_augment_levels(symbol: String) -> int:
	return int(MetaStateStore.symbolAugmentLevels.get(symbol, 0))

## Purchase the offered augment. `choice` carries the selector result: a symbol id
## for aug_symbol_level, "pair"/"triple" for aug_pair_triple. All validation runs
## BEFORE any charge, so a cancelled/invalid selection can never spend anything.
## Charges run Lucidity in-run, the wallet pre-run. Returns whether it went through.
func purchase_chip_augment(augment_id: String, choice := "") -> bool:
	if augment_id == "" or dealerAugmentOfferId != augment_id:
		return false
	if ChipAugments.stock_left(augment_id, MetaStateStore.chipAugmentsPurchased) <= 0:
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
	MetaStateStore.chipAugmentsPurchased = MetaStateStore.chipAugmentsPurchased.duplicate(true)
	MetaStateStore.chipAugmentsPurchased[augment_id] = int(MetaStateStore.chipAugmentsPurchased.get(augment_id, 0)) + 1
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
				MetaStateStore.extraSpinsGranted += 1 # already paid; the run-start overlay skips it
		"aug_offer_expand":
			_expand_current_offer()
		"aug_pair_triple":
			MetaStateStore.pairTripleAugmentChoice = choice # locked — cannot be changed afterwards
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
	MetaStateStore.symbolAugmentLevels = MetaStateStore.symbolAugmentLevels.duplicate(true)
	MetaStateStore.symbolAugmentLevels[symbol] = int(MetaStateStore.symbolAugmentLevels.get(symbol, 0)) + 1
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
	for symbol in MetaStateStore.symbolAugmentLevels:
		var added := int(MetaStateStore.symbolAugmentLevels[symbol])
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
	var spin_copies := int(MetaStateStore.chipAugmentsPurchased.get("aug_extra_spins", 0)) - MetaStateStore.extraSpinsGranted
	if spin_copies > 0:
		var bonus := spin_copies * ChipAugments.EXTRA_SPINS_PER_COPY \
			* maxi(1, Economy.compute_neuron_decay(ownedUpgrades))
		neurons = mini(_neuron_cap(), neurons + bonus)
		MetaStateStore.extraSpinsGranted += spin_copies

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
