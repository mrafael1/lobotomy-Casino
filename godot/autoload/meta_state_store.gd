extends Node

## Autoload singleton "MetaStateStore" — port of the Godot meta state plus the
## persistence layer (Step 4). Persists to user:// as JSON using the same logical
## shape as the MMKV `lobotomy-meta` save.
##
## schemaVersion: v6 gates the Pacte deck behind the issue #52 unlock rules: the
## starting roster shrinks to CardUnlocks' defaults and the rest is earned through
## the persisted progress counters. v5 added the pending card-unlock presentation
## queue on top of the v4 unlock-aware deck lists.
## A migration seam is kept for future save changes but ships empty — a
## v1->v2 migration is only added if an actual v1 payload is ever found in the wild.

const SAVE_PATH := "user://lobotomy-meta.json"
const CANONICAL_SCHEMA_VERSION := 6

var schemaVersion: int = CANONICAL_SCHEMA_VERSION
var lucidityWallet: int = 0
var ownedPermanents: Array = []
var corruptionEverUsed: bool = false
var endingsReached: Array = []
var pendingConsumables: Dictionary = {}
var history: Dictionary = { "runsPlayed": 0, "bestScoreRun": 0 }
var campaignNeuronsMax: int = EconomyConst.CAMPAIGN_STARTING_NEURONS
var campaignNeuronsLeft: int = EconomyConst.CAMPAIGN_STARTING_NEURONS
var campaignActive: bool = true
var campaignFailed: bool = false
var wealthEndingReached: bool = false
# Augmented Run (issue #111): unlocked permanently the first time the Wealth
# ending is reached; unlike wealthEndingReached it survives new campaigns.
var augmentedRunUnlocked: bool = false
var is_first_launch: bool = true
# Tutorial (issue #105). Separate from is_first_launch, which is cleared by merely READING
# the how-to-play card: this records that the played tutorial was actually seen through, so
# the first-launch prompt can stop offering it while the Settings replay stays available.
var tutorialCompleted: bool = false
## Display language. "" means the player has never chosen one, so the game follows the
## device; once they pick from OPTIONS this holds their choice and the device stops
## mattering. Kept as a plain locale code so an unknown value degrades to English rather
## than to a broken screen.
var locale: String = ""
# Permanent dealer-odds upgrades (symbol -> level). Bought at the post-run odds
# phase, applied to every run, and only reset with a fresh campaign.
var oddsUpgrades: Dictionary = {}
# Odds-menu tokens left unspent when an odds phase was finalized (issue #50);
# the next odds menu starts with these on top of its fresh budget.
var oddsTokensBanked: int = 0
var rewardAmpSymbol: String = ""
# Pacte deck unlocks are meta progression (issue #52). A fresh save owns only the
# CardUnlocks default roster; every other card is earned through the unlock rules
# and stays owned across campaigns. The draw code just reads these lists.
var unlockedAugmentCardIds: Array = []
var unlockedPowerCardIds: Array = []
# Progress counters behind the card-unlock rules (metric ID -> value). Totals
# accumulate for the life of the save; "best" metrics keep the highest run value.
var cardUnlockProgress: Dictionary = {}
# Cards unlocked but not yet shown to the player (issue #52). Each entry is
# { "cardId": String, "pool": "augment"|"power", "presented": bool }; the popup
# drains them in queue order and acknowledges them one at a time. Persisted so an
# unlock earned in the last seconds of a session is still celebrated next launch.
var pendingCardUnlocks: Array = []

# Chip Augments are CAMPAIGN state, not run state (issue #132). They used to live on
# RunStateStore, where opening a Pacte wiped them mid-campaign — a chip bought at the
# first dealer could vanish before it ever paid for itself. They now last until the
# campaign itself ends, on a wealth ending or a game over, and _clear_campaign_augments()
# is the single place that takes them away.
var chipAugmentsPurchased: Dictionary = {}  # augment id -> copies bought this campaign
var symbolAugmentLevels: Dictionary = {}    # symbol -> +levels bought via aug_symbol_level
var pairTripleAugmentChoice: String = ""    # "" | "pair" | "triple" (locked once chosen)
var extraSpinsGranted: int = 0              # aug_extra_spins copies already paid out
# Emergency Reserve fires once per CAMPAIGN, not once per run: the augment's own scope is
# the campaign, so re-arming every run (and every target round break) would have sold one
# rescue and delivered several.
var emergencyReserveUsed: bool = false

@export_group("Run Balance")
@export var max_consumable_slots: int = Consumables.MAX_CONSUMABLE_SLOTS

# Campaign rebalance (issue #38): the starting neuron count is tunable; the const
# stays the canonical default so parity/sacred rules pin the shipped value.
@export_group("Campaign")
@export var campaign_starting_neurons: int = EconomyConst.CAMPAIGN_STARTING_NEURONS

var _campaign_neuron_spend_feedback_pending := false

# Score-table tiers (issue #142): classic plus the augmented suits, in the
# order the authored SCORES symbol sheet frames use.
const SCORE_TIERS: Array[String] = ["classic", "heart", "diamond", "spade", "club", "joker"]

# Playtime tracking (issue #142): sub-millisecond remainder accumulated per
# frame; folded into history["playtimeMs"] whenever state is saved or read.
var _playtime_accum_ms := 0.0

signal meta_changed
## Emitted by unlock_card() the moment a card joins the unlocked list (issue #52).
## Scenes hosting the unlock popup listen for it instead of polling the queue.
signal card_unlocked(card_id: String, pool: String)

func _ready() -> void:
	_initialise_fresh_card_state()
	load_state()

## Canonical first-install state.  Defaults are known content, not achievements:
## they must never enter the pending presentation queue.  Keeping this reset in one
## helper also makes a missing save and reset_to_defaults() behave identically.
func _initialise_fresh_card_state() -> void:
	unlockedAugmentCardIds = CardUnlocks.default_ids("augment")
	unlockedPowerCardIds = CardUnlocks.default_ids("power")
	cardUnlockProgress = CardUnlocks.fresh_progress()
	pendingCardUnlocks = []

func _process(delta: float) -> void:
	_playtime_accum_ms += delta * 1000.0

static func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)

func _as_dict() -> Dictionary:
	return {
		"schemaVersion": schemaVersion,
		"lucidityWallet": lucidityWallet,
		"ownedPermanents": ownedPermanents.duplicate(),
		"corruptionEverUsed": corruptionEverUsed,
		"endingsReached": endingsReached.duplicate(),
		"pendingConsumables": pendingConsumables.duplicate(true),
		"history": history.duplicate(true),
		"campaignNeuronsMax": campaignNeuronsMax,
		"campaignNeuronsLeft": campaignNeuronsLeft,
		"campaignActive": campaignActive,
		"campaignFailed": campaignFailed,
		"wealthEndingReached": wealthEndingReached,
		"augmentedRunUnlocked": augmentedRunUnlocked,
		"is_first_launch": is_first_launch,
		"tutorialCompleted": tutorialCompleted,
		"locale": locale,
		"oddsUpgrades": oddsUpgrades.duplicate(true),
		"oddsTokensBanked": oddsTokensBanked,
		"rewardAmpSymbol": rewardAmpSymbol,
		"unlockedAugmentCardIds": unlockedAugmentCardIds.duplicate(),
		"unlockedPowerCardIds": unlockedPowerCardIds.duplicate(),
		"pendingCardUnlocks": pendingCardUnlocks.duplicate(true),
		"cardUnlockProgress": cardUnlockProgress.duplicate(true),
		"chipAugmentsPurchased": chipAugmentsPurchased.duplicate(true),
		"symbolAugmentLevels": symbolAugmentLevels.duplicate(true),
		"pairTripleAugmentChoice": pairTripleAugmentChoice,
		"extraSpinsGranted": extraSpinsGranted,
		"emergencyReserveUsed": emergencyReserveUsed,
	}

func _apply(meta: Dictionary) -> void:
	schemaVersion = int(meta.get("schemaVersion", CANONICAL_SCHEMA_VERSION))
	lucidityWallet = int(meta.get("lucidityWallet", 0))
	ownedPermanents = (meta.get("ownedPermanents", []) as Array).duplicate()
	corruptionEverUsed = bool(meta.get("corruptionEverUsed", false))
	endingsReached = (meta.get("endingsReached", []) as Array).duplicate()
	pendingConsumables = (meta.get("pendingConsumables", {}) as Dictionary).duplicate(true)
	history = (meta.get("history", { "runsPlayed": 0, "bestScoreRun": 0 }) as Dictionary).duplicate(true)
	campaignNeuronsMax = int(meta.get("campaignNeuronsMax", EconomyConst.CAMPAIGN_STARTING_NEURONS))
	campaignNeuronsLeft = clampi(
		int(meta.get("campaignNeuronsLeft", campaignNeuronsMax)),
		0,
		campaignNeuronsMax
	)
	campaignActive = bool(meta.get("campaignActive", true))
	campaignFailed = bool(meta.get("campaignFailed", false))
	wealthEndingReached = bool(meta.get("wealthEndingReached", endingsReached.has("wealth")))
	# Older saves lack the flag: anyone who ever reached wealth gets the unlock.
	augmentedRunUnlocked = bool(meta.get("augmentedRunUnlocked",
		wealthEndingReached or endingsReached.has("wealth")))
	is_first_launch = bool(meta.get("is_first_launch", true))
	# A save from before the played tutorial existed belongs to someone already past
	# needing it: treat a launched game as having had its introduction.
	tutorialCompleted = bool(meta.get("tutorialCompleted", not is_first_launch))
	locale = String(meta.get("locale", ""))
	oddsUpgrades = (meta.get("oddsUpgrades", {}) as Dictionary).duplicate(true)
	oddsTokensBanked = maxi(0, int(meta.get("oddsTokensBanked", 0)))
	rewardAmpSymbol = String(meta.get("rewardAmpSymbol", ""))
	cardUnlockProgress = _normalise_card_progress(meta.get("cardUnlockProgress", {}))
	unlockedAugmentCardIds = _normalise_card_unlocks(
		meta.get("unlockedAugmentCardIds", CardUnlocks.default_ids("augment")),
		PacteCards.augment_ids())
	unlockedPowerCardIds = _normalise_card_unlocks(
		meta.get("unlockedPowerCardIds", CardUnlocks.default_ids("power")),
		PacteCards.power_ids())
	# The default roster is never lost, and progress already banked always owns the
	# cards it earns — a save cannot end up holding a metric with no card to show
	# for it (e.g. after the rules themselves change).
	for pool in PacteCards.POOLS:
		var owned := unlockedAugmentCardIds if pool == "augment" else unlockedPowerCardIds
		for card_id in CardUnlocks.unlocked_ids_for(pool, cardUnlockProgress):
			if not owned.has(card_id):
				owned.append(card_id)
	pendingCardUnlocks = _normalise_pending_card_unlocks(meta.get("pendingCardUnlocks", []))
	chipAugmentsPurchased = (meta.get("chipAugmentsPurchased", {}) as Dictionary).duplicate(true)
	symbolAugmentLevels = (meta.get("symbolAugmentLevels", {}) as Dictionary).duplicate(true)
	pairTripleAugmentChoice = String(meta.get("pairTripleAugmentChoice", ""))
	extraSpinsGranted = maxi(0, int(meta.get("extraSpinsGranted", 0)))
	emergencyReserveUsed = bool(meta.get("emergencyReserveUsed", false))
	meta_changed.emit()

func _normalise_card_progress(value: Variant) -> Dictionary:
	var result := CardUnlocks.fresh_progress()
	var known := CardUnlocks.metric_ids()
	if not (value is Dictionary):
		return result
	for key in value as Dictionary:
		var metric := String(key)
		var amount := maxi(0, int((value as Dictionary)[key]))
		# Keep unknown positive metrics for forward-compatible saves, while every
		# metric known by this build is always present and starts at zero.
		if known.has(metric) or amount > 0:
			result[metric] = amount
	return result

func _normalise_card_unlocks(value: Variant, fallback: Array[String]) -> Array:
	var result: Array = []
	if value is Array:
		for id in value:
			var card_id := PacteCards.normalise_card_id(String(id))
			if fallback.has(card_id) and not result.has(card_id):
				result.append(card_id)
		return result
	if value == null and not fallback.is_empty():
		result = fallback.duplicate()
	return result

func unlocked_augment_cards() -> Array[String]:
	return _normalise_card_unlocks(unlockedAugmentCardIds, PacteCards.augment_ids())

func unlocked_power_cards() -> Array[String]:
	return _normalise_card_unlocks(unlockedPowerCardIds, PacteCards.power_ids())

func unlock_augment_card(card_id: String) -> bool:
	return unlock_card(card_id, "augment")

func unlock_power_card(card_id: String) -> bool:
	return unlock_card(card_id, "power")

## The single card-unlock entry point (issue #52). Every achievement/progression
## unlock routes through here instead of appending to the unlock arrays directly,
## so the presentation queue can never drift from what the player actually owns.
## Returns true only when the card was newly unlocked (and therefore queued).
## `pool` may be left empty to resolve it from the card metadata.
func unlock_card(card_id: String, pool: String = "", save_immediately := true) -> bool:
	var normalised := PacteCards.normalise_card_id(card_id)
	var resolved_pool := PacteCards.pool_of(normalised)
	if resolved_pool == "":
		return false
	# A caller that names a pool must name the right one: a mismatch is a bug in
	# the progression rule, not a reason to unlock the card under the other pool.
	if pool != "" and pool != resolved_pool:
		return false
	# The starting roster is already known.  Treat a malformed save that omitted a
	# default as repairable content, never as a newly earned card that should pop up.
	if CardUnlocks.is_default(normalised):
		return false
	var unlocked := unlockedAugmentCardIds if resolved_pool == "augment" else unlockedPowerCardIds
	if unlocked.has(normalised):
		return false
	unlocked = unlocked.duplicate()
	unlocked.append(normalised)
	if resolved_pool == "augment":
		unlockedAugmentCardIds = unlocked
	else:
		unlockedPowerCardIds = unlocked
	_queue_card_unlock(normalised, resolved_pool)
	meta_changed.emit()
	card_unlocked.emit(normalised, resolved_pool)
	if save_immediately:
		save_state()
	return true

func _queue_card_unlock(card_id: String, pool: String) -> void:
	if CardUnlocks.is_default(card_id):
		return
	for entry in pendingCardUnlocks:
		if String((entry as Dictionary).get("cardId", "")) == card_id:
			return
	pendingCardUnlocks = pendingCardUnlocks.duplicate(true)
	pendingCardUnlocks.append({ "cardId": card_id, "pool": pool, "presented": false })

## Queue entries still waiting to be shown, in unlock order.
func pending_card_unlocks() -> Array:
	var result: Array = []
	for entry in pendingCardUnlocks:
		var record := entry as Dictionary
		if not bool(record.get("presented", false)):
			result.append(record.duplicate(true))
	return result

func has_pending_card_unlocks() -> bool:
	return not pending_card_unlocks().is_empty()

## The card the popup should present next, or {} when the queue is drained.
func next_pending_card_unlock() -> Dictionary:
	var pending := pending_card_unlocks()
	return {} if pending.is_empty() else pending[0] as Dictionary

## Marks one queued card as presented and drops it from the queue. Called by the
## popup for both CONTINUE and VIEW COLLECTION so an acknowledged card is never
## celebrated twice.
func acknowledge_card_unlock(card_id: String, save_immediately := true) -> bool:
	var normalised := PacteCards.normalise_card_id(card_id)
	var next: Array = []
	var acknowledged := false
	for entry in pendingCardUnlocks:
		var record := (entry as Dictionary).duplicate(true)
		if String(record.get("cardId", "")) == normalised \
				and not bool(record.get("presented", false)):
			acknowledged = true
			continue
		next.append(record)
	if not acknowledged:
		return false
	pendingCardUnlocks = next
	meta_changed.emit()
	if save_immediately:
		save_state()
	return true

# ── card-unlock progress (issue #52) ──────────────────────────────────────────────

func card_unlock_progress(metric: String) -> int:
	return int(cardUnlockProgress.get(metric, 0))

func card_unlock_progress_snapshot() -> Dictionary:
	return cardUnlockProgress.duplicate(true)

## Adds to a cumulative metric (consumables used, power restores, wins, ...) and
## unlocks whatever that crosses. Returns the newly unlocked card IDs.
func add_card_unlock_progress(metric: String, amount := 1, save_immediately := true) -> Array[String]:
	if metric == "" or amount <= 0:
		var none: Array[String] = []
		return none
	return _set_card_unlock_progress(metric,
		card_unlock_progress(metric) + amount, save_immediately)

## Raises a "best single run" metric (run score, pairs in a run, ...) to `value`
## when it beats the stored record. Returns the newly unlocked card IDs.
func record_best_card_unlock_progress(metric: String, value: int, save_immediately := true) -> Array[String]:
	if metric == "" or value <= card_unlock_progress(metric):
		var none: Array[String] = []
		return none
	return _set_card_unlock_progress(metric, value, save_immediately)

func _set_card_unlock_progress(metric: String, value: int, save_immediately: bool) -> Array[String]:
	# The tutorial (issue #105) plays on the real machine, so it lands real spins, real wins
	# and real consumable uses — but none of it is the player's play, and none of it may
	# count. Nothing accrues and nothing unlocks: not just because the progress would be
	# unearned, but because an unlock takes the whole screen to celebrate itself and would
	# do it on top of a beat that is mid-sentence.
	if sandboxed:
		var none: Array[String] = []
		return none
	cardUnlockProgress = cardUnlockProgress.duplicate(true)
	cardUnlockProgress[metric] = value
	var unlocked := _evaluate_card_unlocks(false)
	meta_changed.emit()
	# An unlock always hits the disk: callers pass save_immediately = false for the
	# per-spin counters, but a card the player just earned must survive a crash.
	if save_immediately or not unlocked.is_empty():
		save_state()
	return unlocked

## Unlocks every card whose rule the current progress satisfies. Each one goes
## through unlock_card(), so it is queued for the popup exactly once.
func _evaluate_card_unlocks(save_immediately := true) -> Array[String]:
	var unlocked: Array[String] = []
	for card_id in CardUnlocks.satisfied_ids(cardUnlockProgress):
		if unlock_card(card_id, "", false):
			unlocked.append(card_id)
	if not unlocked.is_empty() and save_immediately:
		save_state()
	return unlocked

func clear_pending_card_unlocks() -> void:
	if pendingCardUnlocks.is_empty():
		return
	pendingCardUnlocks = []
	meta_changed.emit()
	save_state()

## Drops malformed/unknown/duplicate entries and any queued card that is no longer
## unlocked, so a hand-edited or downgraded save can never surface a locked card's
## metadata through the popup.
func _normalise_pending_card_unlocks(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	var seen: Array[String] = []
	for entry in value as Array:
		if not (entry is Dictionary):
			continue
		var record := entry as Dictionary
		var card_id := PacteCards.normalise_card_id(String(record.get("cardId", "")))
		var pool := PacteCards.pool_of(card_id)
		if pool == "" or seen.has(card_id):
			continue
		# Defaults have no unlock condition and therefore can never be a real
		# acknowledgement event.  Drop stale entries from pre-queue/legacy saves.
		if CardUnlocks.is_default(card_id):
			continue
		var unlocked := unlockedAugmentCardIds if pool == "augment" else unlockedPowerCardIds
		if not unlocked.has(card_id):
			continue
		seen.append(card_id)
		result.append({
			"cardId": card_id,
			"pool": pool,
			"presented": bool(record.get("presented", false)),
		})
	return result

# ── action API (mirrors metaState.ts) ────────────────────────────────────────────

## The share of run Lucidity the player actually keeps.
##
## Smart Saving has two doors: the shop sells it as a permanent, and the Pacte offers it
## as the SMART SAVING augment card. The card grants pos_smart_save into the RUN's
## ownedUpgrades and never touches ownedPermanents, which is all Endings can see — so the
## card's whole promise ("KEEP 50% OF LUCIDITY INSTEAD OF 10% ON FLATLINE") was silently
## banked at 10%. Either door counts here.
func effective_lucidity_kept_fraction() -> float:
	var frac := Endings.lucidity_kept_fraction(_as_dict())
	if frac >= EconomyConst.SMART_SAVE_LUCIDITY_KEPT:
		return frac
	var run_store: Node = get_node_or_null(^"/root/RunStateStore") if is_inside_tree() else null
	if run_store != null \
			and (run_store.ownedUpgrades as Array).has(EconomyConst.SMART_SAVE_UPGRADE_ID):
		return EconomyConst.SMART_SAVE_LUCIDITY_KEPT
	return frac

func bank_run(run: Dictionary, ending: String) -> void:
	_flush_playtime()
	var prev_history: Dictionary = history.duplicate(true)
	var next := Endings.bank_run_to_meta(run, _as_dict(), ending, _now_ms())
	# Endings banks off the meta permanents alone, so a Pacte-granted SMART SAVING is
	# corrected here rather than in the parity-locked banking math itself.
	var banked_frac := Endings.lucidity_kept_fraction(_as_dict())
	var owed_frac := effective_lucidity_kept_fraction()
	if not is_equal_approx(owed_frac, banked_frac):
		var coins := float(run["lucidityCoins"])
		var banked_kept := 0 if ending == "game_over" else floori(coins * banked_frac)
		var owed_kept := 0 if ending == "game_over" else floori(coins * owed_frac)
		next["lucidityWallet"] = int(next["lucidityWallet"]) + (owed_kept - banked_kept)
	# Score-table history (issue #142): the parity-locked banking math rebuilds
	# the history dict from only the keys it owns, so the tracking-only fields
	# (playtime, per-tier counters, ending playtimes) are re-merged here.
	var next_history: Dictionary = (next["history"] as Dictionary).duplicate(true)
	for key in prev_history:
		if not next_history.has(key):
			next_history[key] = prev_history[key]
	var tier := _current_run_tier()
	var runs_by_tier: Dictionary = (next_history.get("runsByTier", {}) as Dictionary).duplicate(true)
	runs_by_tier[tier] = int(runs_by_tier.get(tier, 0)) + 1
	next_history["runsByTier"] = runs_by_tier
	# Tier wins are registered in mark_ending_reached (the moment the goal is
	# hit), not here: the wealth bank is deferred to the Start Again button, and
	# a wealth CONTINUE later banks as "flatline" — both would drop the win.
	if ending == "wealth":
		if not next_history.has("wealthEndingPlaytimeMs"):
			next_history["wealthEndingPlaytimeMs"] = int(next_history.get("playtimeMs", 0))
	elif ending == "exit" and not next_history.has("exitEndingPlaytimeMs"):
		next_history["exitEndingPlaytimeMs"] = int(next_history.get("playtimeMs", 0))
	next["history"] = next_history
	_apply(next)
	if ending == "wealth":
		wealthEndingReached = true
		augmentedRunUnlocked = true
		campaignActive = false
		campaignFailed = false
	pendingConsumables = {} # cleared on bank, cleared on bank
	meta_changed.emit()
	save_state()

func buy_upgrade(upgrade_id: String) -> void:
	var umap := Upgrades.upgrade_map()
	var upgrade: Variant = umap.get(upgrade_id, null)
	if upgrade == null:
		return
	if ownedPermanents.has(upgrade_id):
		return
	if upgrade.has("requiresId") and not ownedPermanents.has(upgrade["requiresId"]):
		return
	if lucidityWallet < int(upgrade["cost"]):
		return
	lucidityWallet -= int(upgrade["cost"])
	ownedPermanents = ownedPermanents.duplicate()
	ownedPermanents.append(upgrade_id)
	if String(upgrade["category"]) == "corrupted":
		corruptionEverUsed = true
	meta_changed.emit()
	save_state()

func set_reward_amp_symbol(symbol: String) -> void:
	if not Symbols.BASE_SYMBOL_CYCLE.has(symbol):
		return
	if rewardAmpSymbol == symbol:
		return
	rewardAmpSymbol = symbol
	meta_changed.emit()
	save_state()

## Banks what a run made over its wealth target. Unlike the end-of-run bank this is
## paid in full and immediately: the money is the player's the moment the target is
## settled, and the dealer waiting on the other side of the break spends this wallet.
## Deliberately separate from bank_run_to_meta, whose kept-fraction math is parity
## locked and is about a run that has ended.
func bank_wealth_target_overflow(amount: int) -> int:
	if amount <= 0:
		return 0
	lucidityWallet += amount
	meta_changed.emit()
	save_state()
	return amount

## Direct wallet payout used by between-run rewards such as the Fortune Wheel.
## Keeping it here makes the persistent currency transaction explicit instead of
## having a destination scene mutate campaign state itself.
func grant_lucidity_wallet(amount: int) -> int:
	if amount <= 0:
		return 0
	lucidityWallet += amount
	meta_changed.emit()
	save_state()
	return amount

# Generic wallet spend (pre-run shop reroll etc.). Returns false without side
# effects when the wallet can't cover it.
func spend_lucidity(amount: int) -> bool:
	if amount <= 0 or lucidityWallet < amount:
		return false
	lucidityWallet -= amount
	meta_changed.emit()
	save_state()
	return true

func buy_consumable_charge(consumable_id: String) -> void:
	buy_consumable_charge_with_limit(consumable_id, max_consumable_slots)

# `price_override` (>= 0) lets callers charge a discounted price (Chip Augment
# consumable discount) instead of the base shopCost.
func buy_consumable_charge_with_limit(consumable_id: String, slot_limit: int, price_override := -1) -> void:
	var cmap := Consumables.map()
	var consumable: Variant = cmap.get(consumable_id, null)
	if consumable == null:
		return
	var price := price_override if price_override >= 0 else int(consumable["shopCost"])
	if lucidityWallet < price:
		return
	if Consumables.total_copies(pendingConsumables) >= maxi(1, slot_limit):
		return
	lucidityWallet -= price
	pendingConsumables = pendingConsumables.duplicate(true)
	pendingConsumables[consumable_id] = int(pendingConsumables.get(consumable_id, 0)) + 1
	meta_changed.emit()
	save_state()

# `refund_override` mirrors buy's price_override so a discounted purchase never
# sells back for more than it cost.
func discard_pending_consumable(consumable_id: String, refund_override := -1) -> void:
	var current := int(pendingConsumables.get(consumable_id, 0))
	if current <= 0:
		return
	var cmap := Consumables.map()
	var consumable: Variant = cmap.get(consumable_id, null)
	pendingConsumables = pendingConsumables.duplicate(true)
	if current <= 1:
		pendingConsumables.erase(consumable_id)
	else:
		pendingConsumables[consumable_id] = current - 1
	if refund_override >= 0:
		lucidityWallet += refund_override
	else:
		lucidityWallet += (int(consumable["shopCost"]) if consumable != null else 0)
	meta_changed.emit()
	save_state()

func mark_ending_reached(ending: String) -> void:
	if not endingsReached.has(ending):
		endingsReached = endingsReached.duplicate()
		endingsReached.append(ending)
	_record_ending_card_progress(ending)
	if ending == "wealth":
		wealthEndingReached = true
		campaignActive = false
		campaignFailed = false
		# Win counter (issue #142): the win is counted for the active tier the
		# moment the goal is reached. Banking can't own this — the wealth bank
		# waits for Start Again (a quit there never banks), and a wealth
		# CONTINUE that later dies banks as "flatline".
		var tier := _current_run_tier()
		var wins_by_tier: Dictionary = (history.get("winsByTier", {}) as Dictionary).duplicate(true)
		wins_by_tier[tier] = int(wins_by_tier.get(tier, 0)) + 1
		history = history.duplicate(true)
		history["winsByTier"] = wins_by_tier
		if not history.has("wealthEndingReachedAt"):
			history = history.duplicate(true)
			history["wealthEndingReachedAt"] = _now_ms()
		if not history.has("wealthEndingPlaytimeMs"):
			# total_playtime_ms() flushes and swaps the history dict; read it
			# into a local before writing the ending field.
			var wealth_playtime := total_playtime_ms()
			history = history.duplicate(true)
			history["wealthEndingPlaytimeMs"] = wealth_playtime
		# Last, once every ending consumer above has recorded what it needs. The tier
		# itself lives on RunStateStore so clearing early was harmless in practice, but
		# the accounting reads first and the campaign teardown follows it — not the
		# other way round, where a future consumer of campaign augment state would
		# silently read an already-emptied campaign.
		_clear_campaign_augments() # the campaign is over: the chips go with it
	elif ending == "exit":
		if not history.has("exitEndingReachedAt"):
			history = history.duplicate(true)
			history["exitEndingReachedAt"] = _now_ms()
		if not history.has("exitEndingPlaytimeMs"):
			var exit_playtime := total_playtime_ms()
			history = history.duplicate(true)
			history["exitEndingPlaytimeMs"] = exit_playtime
	elif ending == "game_over":
		campaignActive = false
		campaignFailed = true
		campaignNeuronsLeft = 0
		lucidityWallet = 0
		_clear_campaign_augments() # the campaign is over: the chips go with it
	meta_changed.emit()
	save_state()

## Card-unlock metrics an ending settles (issue #52): winning at all, winning a
## specific augmented tier, winning without ever flatlining, and dying of flatline.
## The run store is looked up at runtime — save_checks compiles this script outside
## the autoload context, where the RunStateStore identifier does not resolve.
func _record_ending_card_progress(ending: String) -> void:
	var run_store: Node = get_node_or_null(^"/root/RunStateStore") if is_inside_tree() else null
	if ending == "wealth":
		add_card_unlock_progress(CardUnlocks.METRIC_WINS, 1, false)
		var tier := _current_run_tier()
		if tier == "joker":
			add_card_unlock_progress(CardUnlocks.METRIC_JOKER_TIER_WINS, 1, false)
		elif tier == "heart":
			add_card_unlock_progress(CardUnlocks.METRIC_HEART_TIER_WINS, 1, false)
		# "Without a flatline" is the run's flatline reel results, not the ending:
		# the win has to be clean all the way through.
		if run_store != null and int(run_store.flatlineResultCount) <= 0:
			add_card_unlock_progress(CardUnlocks.METRIC_FLAWLESS_WINS, 1, false)
	elif ending == "flatline" or ending == "game_over":
		add_card_unlock_progress(CardUnlocks.METRIC_FLATLINE_DEATHS, 1, false)

func get_pending_consumables() -> Dictionary:
	return pendingConsumables.duplicate(true)

# ── score-table history (issue #142) ──────────────────────────────────────────────

## Folds the per-frame playtime accumulator into the persisted counter. Called
## before every save and before any read of the playtime fields.
func _flush_playtime() -> void:
	var whole := int(_playtime_accum_ms)
	if whole <= 0:
		return
	_playtime_accum_ms -= float(whole)
	history = history.duplicate(true)
	history["playtimeMs"] = int(history.get("playtimeMs", 0)) + whole

func total_playtime_ms() -> int:
	_flush_playtime()
	return int(history.get("playtimeMs", 0))

# The tier the current run counts under: the augmented suit when one is armed,
# "classic" otherwise. The run store is looked up at runtime: save_checks
# compiles this script outside the autoload context, where the RunStateStore
# identifier doesn't resolve.
func _current_run_tier() -> String:
	var run_store: Node = get_node_or_null(^"/root/RunStateStore") if is_inside_tree() else null
	if run_store != null and String(run_store.augmentedTier) != "":
		return String(run_store.augmentedTier)
	return "classic"

func tier_wins(tier: String) -> int:
	return int((history.get("winsByTier", {}) as Dictionary).get(tier, 0))

func tier_runs(tier: String) -> int:
	return int((history.get("runsByTier", {}) as Dictionary).get(tier, 0))

func total_wins() -> int:
	var total := 0
	for count in (history.get("winsByTier", {}) as Dictionary).values():
		total += int(count)
	return total

# ── permanent dealer-odds upgrades ─────────────────────────────────────────────────

func odds_upgrade_level(symbol: String) -> int:
	return int(oddsUpgrades.get(symbol, 0))

## Commits finalized odds purchases (symbol -> bought levels), clamped to max_level.
func add_odds_upgrades(bought: Dictionary, max_level: int) -> void:
	if bought.is_empty():
		return
	oddsUpgrades = oddsUpgrades.duplicate(true)
	for symbol in bought:
		var next_level := int(oddsUpgrades.get(symbol, 0)) + int(bought[symbol])
		oddsUpgrades[symbol] = clampi(next_level, 0, maxi(0, max_level))
	meta_changed.emit()
	save_state()

## Banks the tokens left unspent when an odds phase closes (issue #50); the next
## odds menu grants these on top of its fresh budget.
func set_odds_tokens_banked(count: int) -> void:
	oddsTokensBanked = maxi(0, count)
	meta_changed.emit()
	save_state()

func campaign_status_text() -> String:
	return "NEURONS: %d/%d" % [campaignNeuronsLeft, campaignNeuronsMax]

func can_start_campaign_run() -> bool:
	return campaignActive and not campaignFailed and not wealthEndingReached and campaignNeuronsLeft > 0

## Validates a new run without spending its campaign neuron. The run store
## finalizes the cost when the machine run reaches an ending.
func reserve_campaign_neuron_for_run() -> bool:
	if not campaignActive and not wealthEndingReached:
		start_new_campaign(false)
	if not can_start_campaign_run():
		if campaignNeuronsLeft <= 0 and not wealthEndingReached:
			mark_campaign_failed()
		return false
	return true

func finalize_campaign_neuron_for_run(save_immediately := true) -> bool:
	return consume_campaign_neuron_for_run(save_immediately)

func consume_campaign_neuron_for_run(save_immediately := true) -> bool:
	if not campaignActive and not wealthEndingReached:
		start_new_campaign(false)
	if not can_start_campaign_run():
		if campaignNeuronsLeft <= 0 and not wealthEndingReached:
			mark_campaign_failed(save_immediately)
		return false
	campaignNeuronsLeft -= 1
	_campaign_neuron_spend_feedback_pending = true
	meta_changed.emit()
	if save_immediately:
		save_state()
	return true

func consume_neuron_spend_feedback() -> bool:
	var pending := _campaign_neuron_spend_feedback_pending
	_campaign_neuron_spend_feedback_pending = false
	return pending

func mark_campaign_failed(save_immediately := true) -> void:
	if wealthEndingReached:
		return
	campaignActive = false
	campaignFailed = true
	campaignNeuronsLeft = 0
	pendingConsumables = {}
	_clear_campaign_augments() # the campaign is over: the chips go with it
	meta_changed.emit()
	if save_immediately:
		save_state()

## The only place Chip Augments are taken away. Called when the campaign ends (wealth or
## game over) and when a fresh one starts, so the buff spans exactly one campaign — a
## Pacte, a flatline continuation or a target round break all leave it standing.
func _clear_campaign_augments() -> void:
	chipAugmentsPurchased = {}
	symbolAugmentLevels = {}
	pairTripleAugmentChoice = ""
	extraSpinsGranted = 0
	emergencyReserveUsed = false

func start_new_campaign(save_immediately := true) -> void:
	_clear_campaign_augments()
	lucidityWallet = 0
	ownedPermanents = []
	corruptionEverUsed = false
	pendingConsumables = {}
	campaignNeuronsMax = campaign_starting_neurons
	campaignNeuronsLeft = campaignNeuronsMax
	campaignActive = true
	campaignFailed = false
	wealthEndingReached = false
	oddsUpgrades = {}
	oddsTokensBanked = 0
	rewardAmpSymbol = ""
	# Card unlocks and their progress are achievements, not campaign state: a new
	# campaign keeps every card the player earned, and the pending popup queue with
	# it. Only the default roster is re-asserted, in case an older save lost it.
	for card_id in CardUnlocks.DEFAULT_AUGMENT_IDS:
		if not unlockedAugmentCardIds.has(card_id):
			unlockedAugmentCardIds.append(card_id)
	for card_id in CardUnlocks.DEFAULT_POWER_IDS:
		if not unlockedPowerCardIds.has(card_id):
			unlockedPowerCardIds.append(card_id)
	# Acknowledged entries are removed by acknowledge_card_unlock(); this second
	# normalization protects a fresh campaign from malformed/default queue records
	# while preserving genuine earned cards across campaigns.
	pendingCardUnlocks = _normalise_pending_card_unlocks(pendingCardUnlocks)
	_campaign_neuron_spend_feedback_pending = false
	meta_changed.emit()
	if save_immediately:
		save_state()

func mark_tutorial_seen(save_immediately := true) -> void:
	if not is_first_launch:
		return
	is_first_launch = false
	meta_changed.emit()
	if save_immediately:
		save_state()

## The played tutorial (issue #105) was seen through — or deliberately skipped, which is
## the same answer to "should we offer it again". The Settings replay ignores this.
func mark_tutorial_completed(save_immediately := true) -> void:
	if tutorialCompleted:
		return
	tutorialCompleted = true
	meta_changed.emit()
	if save_immediately:
		save_state()

# ── persistence (Step 4) ──────────────────────────────────────────────────────────

## Tutorial sandbox (issue #105): set while the played tutorial is running, so its scripted
## campaign never reaches the disk. See RunStateStore.sandboxed — Tutorial owns both.
var sandboxed := false

## Returns every field to the state a fresh install starts from, in memory only —
## nothing is written to or removed from disk, so a caller that also wants the save
## gone removes SAVE_PATH itself (SaveIO.remove takes the backup with it).
##
## `_apply({})` is reused deliberately instead of writing a second list of defaults:
## every key it reads already documents its own fresh-install value, so a field added
## there is reset here for free and the two can never disagree about what "default"
## means. Only the handful of fields _apply does not own are listed below.
##
## RunStateStore.reset_run_state() is the run-scoped counterpart; the smoke suite
## calls both to stop one check inheriting the campaign another one left behind.
func reset_to_defaults() -> void:
	_apply({})
	max_consumable_slots = Consumables.MAX_CONSUMABLE_SLOTS
	campaign_starting_neurons = EconomyConst.CAMPAIGN_STARTING_NEURONS
	_campaign_neuron_spend_feedback_pending = false
	_playtime_accum_ms = 0.0
	sandboxed = false

func save_state() -> void:
	if sandboxed:
		return
	_flush_playtime()
	SaveIO.write_text(SAVE_PATH, JSON.stringify(_as_dict()))

func load_state() -> void:
	# A truncated or non-object primary falls through to the backup copy rather than
	# silently starting the player over on a fresh campaign.
	var txt := SaveIO.read_text(SAVE_PATH, _save_text_is_readable)
	if txt.is_empty():
		# Materialize the canonical first save. Defaults are known content, so a
		# first PC launch cannot resurrect a pending card presentation.
		_initialise_fresh_card_state()
		save_state()
		return # fresh install (or nothing usable) — keep canonical defaults
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Corrupt save (not an object); keeping defaults.")
		return
	_apply(_migrate(parsed))

func _save_text_is_readable(text: String) -> bool:
	return typeof(JSON.parse_string(text)) == TYPE_DICTIONARY

## Playtime accumulated since the last write, and anything else banked in memory,
## would otherwise die with the process. The close request (and the mobile
## background/pause notifications) is the last chance to flush it to disk.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_WM_GO_BACK_REQUEST \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		save_state()

# Migration seam mirroring the save migration seam. Ships empty: v2 is the
# only shape known to have shipped, so no speculative v1->v2 migration is written.
# If a real v1 payload is ever found, register it in _MIGRATIONS keyed by version.
const _MIGRATIONS := {}

## Best-effort card-unlock progress reconstructed from what an older save already
## recorded. Only metrics the pre-#52 save actually tracked can be recovered; the
## rest legitimately start at zero.
func _card_progress_from_history(record: Dictionary) -> Dictionary:
	var progress: Dictionary = {}
	var record_history: Dictionary = record.get("history", {}) as Dictionary
	var best_score := int(record_history.get("bestScoreRun", 0))
	if best_score > 0:
		progress[CardUnlocks.METRIC_BEST_RUN_SCORE] = best_score
	var wins_by_tier: Dictionary = record_history.get("winsByTier", {}) as Dictionary
	var total_wins := 0
	for tier in wins_by_tier:
		total_wins += int(wins_by_tier[tier])
	var reached: Array = record.get("endingsReached", []) as Array
	# A wealth ending recorded before the per-tier counters existed still counts.
	if total_wins <= 0 and (bool(record.get("wealthEndingReached", false)) or reached.has("wealth")):
		total_wins = 1
	if total_wins > 0:
		progress[CardUnlocks.METRIC_WINS] = total_wins
	var joker_wins := int(wins_by_tier.get("joker", 0))
	if joker_wins > 0:
		progress[CardUnlocks.METRIC_JOKER_TIER_WINS] = joker_wins
	var heart_wins := int(wins_by_tier.get("heart", 0))
	if heart_wins > 0:
		progress[CardUnlocks.METRIC_HEART_TIER_WINS] = heart_wins
	if reached.has("flatline") or reached.has("game_over"):
		progress[CardUnlocks.METRIC_FLATLINE_DEATHS] = 1
	return progress

func _migrate(record: Dictionary) -> Dictionary:
	var current := record
	var version := int(current.get("schemaVersion", 0))
	while version < CANONICAL_SCHEMA_VERSION:
		if not _MIGRATIONS.has(version):
			break
		var fn: Callable = _MIGRATIONS[version]
		current = fn.call(current)
		version = int(current.get("schemaVersion", version))
	if int(current.get("schemaVersion", 0)) != CANONICAL_SCHEMA_VERSION:
		current = current.duplicate(true)
		current["schemaVersion"] = CANONICAL_SCHEMA_VERSION
	if not current.has("campaignNeuronsMax"):
		current["campaignNeuronsMax"] = EconomyConst.CAMPAIGN_STARTING_NEURONS
	if not current.has("campaignNeuronsLeft"):
		current["campaignNeuronsLeft"] = int(current["campaignNeuronsMax"])
	# Campaign rebalance (issue #38): reclamp saves from the 12-neuron era down to
	# the new starting count; neurons-left may never exceed the reclamped max.
	if int(current["campaignNeuronsMax"]) > EconomyConst.CAMPAIGN_STARTING_NEURONS:
		current["campaignNeuronsMax"] = EconomyConst.CAMPAIGN_STARTING_NEURONS
	current["campaignNeuronsLeft"] = clampi(
		int(current["campaignNeuronsLeft"]), 0, int(current["campaignNeuronsMax"])
	)
	if not current.has("campaignActive"):
		current["campaignActive"] = true
	if not current.has("campaignFailed"):
		current["campaignFailed"] = false
	if not current.has("wealthEndingReached"):
		var reached: Array = current.get("endingsReached", []) as Array
		current["wealthEndingReached"] = reached.has("wealth")
	if not current.has("is_first_launch"):
		current["is_first_launch"] = true
	if not current.has("oddsUpgrades"):
		current["oddsUpgrades"] = {}
	if not current.has("oddsTokensBanked"):
		current["oddsTokensBanked"] = 0
	if not current.has("rewardAmpSymbol"):
		current["rewardAmpSymbol"] = ""
	# Issue #132: Chip Augments moved off the run save onto the campaign. A save from
	# before the move has no keys here; starting the campaign's chips empty is the
	# recoverable outcome (the run save that held them is not consulted for meta state).
	if not current.has("chipAugmentsPurchased"):
		current["chipAugmentsPurchased"] = {}
	if not current.has("symbolAugmentLevels"):
		current["symbolAugmentLevels"] = {}
	if not current.has("pairTripleAugmentChoice"):
		current["pairTripleAugmentChoice"] = ""
	if not current.has("extraSpinsGranted"):
		current["extraSpinsGranted"] = 0
	if not current.has("emergencyReserveUsed"):
		current["emergencyReserveUsed"] = false
	# Issue #52 gates the deck. Saves written before v6 hold either nothing or the
	# whole catalog (the pre-#52 default), so their unlock lists are rebuilt from
	# the new rules: the default roster plus whatever their existing history has
	# already earned. Progress the old save never tracked starts at zero.
	if int(record.get("schemaVersion", 0)) < 6 or not current.has("cardUnlockProgress"):
		current = current.duplicate(true)
		current["cardUnlockProgress"] = _card_progress_from_history(current)
		var progress: Dictionary = current["cardUnlockProgress"]
		current["unlockedAugmentCardIds"] = CardUnlocks.unlocked_ids_for("augment", progress)
		current["unlockedPowerCardIds"] = CardUnlocks.unlocked_ids_for("power", progress)
	if not current.has("unlockedAugmentCardIds"):
		current["unlockedAugmentCardIds"] = CardUnlocks.default_ids("augment")
	if not current.has("unlockedPowerCardIds"):
		current["unlockedPowerCardIds"] = CardUnlocks.default_ids("power")
	# Issue #52: pre-v5 saves predate the presentation queue. It migrates in empty —
	# cards already owned before the popup existed are not retroactively celebrated.
	if not current.has("pendingCardUnlocks"):
		current["pendingCardUnlocks"] = []
	# Issue #53: cons_syringe was renamed cons_potion — migrate stashed copies.
	var pending: Dictionary = current.get("pendingConsumables", {}) as Dictionary
	if pending.has("cons_syringe"):
		pending = pending.duplicate(true)
		pending["cons_potion"] = int(pending.get("cons_potion", 0)) + int(pending["cons_syringe"])
		pending.erase("cons_syringe")
		current = current.duplicate(true)
		current["pendingConsumables"] = pending
	# Campaign rebalance: saves from an older health-count era reclamp down to the
	# current starting count, and Left re-clamps to the new Max.
	current["campaignNeuronsMax"] = mini(int(current["campaignNeuronsMax"]), campaign_starting_neurons)
	current["campaignNeuronsLeft"] = mini(int(current["campaignNeuronsLeft"]), int(current["campaignNeuronsMax"]))
	return current
