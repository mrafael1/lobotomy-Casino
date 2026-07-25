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
	if unlockedAugmentCardIds.is_empty():
		unlockedAugmentCardIds = CardUnlocks.default_ids("augment")
	if unlockedPowerCardIds.is_empty():
		unlockedPowerCardIds = CardUnlocks.default_ids("power")
	load_state()

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
		"oddsUpgrades": oddsUpgrades.duplicate(true),
		"oddsTokensBanked": oddsTokensBanked,
		"rewardAmpSymbol": rewardAmpSymbol,
		"unlockedAugmentCardIds": unlockedAugmentCardIds.duplicate(),
		"unlockedPowerCardIds": unlockedPowerCardIds.duplicate(),
		"pendingCardUnlocks": pendingCardUnlocks.duplicate(true),
		"cardUnlockProgress": cardUnlockProgress.duplicate(true),
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
	meta_changed.emit()

func _normalise_card_progress(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (value is Dictionary):
		return result
	for key in value as Dictionary:
		var amount := int((value as Dictionary)[key])
		if amount > 0:
			result[String(key)] = amount
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

func bank_run(run: Dictionary, ending: String) -> void:
	_flush_playtime()
	var prev_history: Dictionary = history.duplicate(true)
	var next := Endings.bank_run_to_meta(run, _as_dict(), ending, _now_ms())
	# Augmented spade modifier (issue #111): the end-of-run gain kept is halved
	# (10% -> 5%, or 20% -> 10% with Smart Saving). Adjusted here so the
	# parity-locked banking math in Endings stays untouched. The run store is
	# looked up at runtime: save_checks compiles this script outside the
	# autoload context, where the RunStateStore identifier doesn't resolve.
	var run_store: Node = get_node_or_null(^"/root/RunStateStore") if is_inside_tree() else null
	if run_store != null and run_store.augmented_modifier_active(2):
		var frac := Endings.lucidity_kept_fraction(_as_dict())
		var kept_full := floori(float(run["lucidityCoins"]) * frac)
		var kept_capped := floori(float(run["lucidityCoins"]) * frac * 0.5)
		next["lucidityWallet"] = int(next["lucidityWallet"]) - (kept_full - kept_capped)
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
	meta_changed.emit()
	if save_immediately:
		save_state()

func start_new_campaign(save_immediately := true) -> void:
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

# ── persistence (Step 4) ──────────────────────────────────────────────────────────

func save_state() -> void:
	_flush_playtime()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Could not open save for write: " + SAVE_PATH)
		return
	f.store_string(JSON.stringify(_as_dict()))
	f.close()

func load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return # fresh install — keep canonical v2 defaults
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Corrupt save (not an object); keeping defaults.")
		return
	_apply(_migrate(parsed))

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
