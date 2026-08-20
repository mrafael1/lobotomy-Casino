class_name SaveChecks
extends RefCounted

const MetaStoreScript := preload("res://autoload/meta_state_store.gd")

static func _check(out: Array, cond: bool, label: String) -> void:
	if not cond:
		out.append("SAVE: " + label)

static func run_all() -> Array:
	var out: Array = []
	var store := MetaStoreScript.new()
	_check_fresh_card_save(out)
	var old_save := {
		"schemaVersion": 1,
		"lucidityWallet": 17,
		"ownedPermanents": [],
		"corruptionEverUsed": false,
		"endingsReached": [],
		"pendingConsumables": {},
		"history": { "runsPlayed": 0, "bestScoreRun": 0 },
	}
	var migrated: Dictionary = store._migrate(old_save)
	_check(out, int(migrated["schemaVersion"]) == store.CANONICAL_SCHEMA_VERSION, "schema canonicalizes to campaign schema")
	_check(out, int(migrated["lucidityWallet"]) == 17, "canonicalization preserves wallet")
	_check(out, int(migrated["campaignNeuronsMax"]) == EconomyConst.CAMPAIGN_STARTING_NEURONS, "migration adds campaign max neurons")
	_check(out, int(migrated["campaignNeuronsLeft"]) == EconomyConst.CAMPAIGN_STARTING_NEURONS, "migration adds campaign neurons left")
	_check(out, bool(migrated["campaignActive"]), "migration starts an active campaign")
	_check(out, not bool(migrated["campaignFailed"]), "migration does not fail campaign")
	_check(out, not bool(migrated["wealthEndingReached"]), "migration does not force wealth ending")
	# Issue #38 rebalance: saves from the 12-neuron era reclamp down to the new max.
	var twelve_era := {
		"schemaVersion": store.CANONICAL_SCHEMA_VERSION,
		"campaignNeuronsMax": 12,
		"campaignNeuronsLeft": 12,
	}
	var reclamped: Dictionary = store._migrate(twelve_era)
	_check(out, int(reclamped["campaignNeuronsMax"]) == EconomyConst.CAMPAIGN_STARTING_NEURONS, "reclamp lowers 12-era campaign max")
	_check(out, int(reclamped["campaignNeuronsLeft"]) == EconomyConst.CAMPAIGN_STARTING_NEURONS, "reclamp lowers 12-era neurons left")
	store._apply(migrated)
	_check(out, store.consume_campaign_neuron_for_run(false), "first run consumes a campaign neuron")
	_check(out, store.campaignNeuronsLeft == EconomyConst.CAMPAIGN_STARTING_NEURONS - 1, "campaign neuron consumed exactly once")
	_check(out, store.consume_neuron_spend_feedback(), "spend feedback is queued once")
	_check(out, not store.consume_neuron_spend_feedback(), "spend feedback clears after read")
	store.campaignNeuronsLeft = 0
	_check(out, not store.consume_campaign_neuron_for_run(false), "zero neurons blocks a new run")
	_check(out, store.campaignFailed, "zero-neuron start marks campaign failed")
	store.lucidityWallet = 99
	store.ownedPermanents = ["perm_memory"]
	store.pendingConsumables = { "cons_focus": 1 }
	store.start_new_campaign(false)
	_check(out, store.campaignNeuronsLeft == EconomyConst.CAMPAIGN_STARTING_NEURONS, "fresh campaign restores neurons")
	_check(out, store.lucidityWallet == 0, "fresh campaign resets wallet")
	_check(out, store.ownedPermanents.is_empty(), "fresh campaign resets upgrades")
	_check(out, store.pendingConsumables.is_empty(), "fresh campaign resets consumables")
	_check_card_unlock_queue_52(store, out)
	_check_card_unlock_rules_52(store, out)
	store.free()
	return out

## A first PC launch has no progression history. Defaults are known content,
## every metric is explicitly zero, and the popup queue remains empty after a
## canonical save round trip.
static func _check_fresh_card_save(out: Array) -> void:
	var fresh := MetaStoreScript.new()
	fresh._apply({})
	_check(out, fresh.unlockedAugmentCardIds == CardUnlocks.default_ids("augment"),
		"fresh save owns only default augment cards")
	_check(out, fresh.unlockedPowerCardIds == CardUnlocks.default_ids("power"),
		"fresh save owns only default power cards")
	for metric in CardUnlocks.metric_ids():
		_check(out, fresh.cardUnlockProgress.has(metric)
			and int(fresh.cardUnlockProgress[metric]) == 0,
			"fresh save initializes card metric %s to zero" % metric)
	_check(out, fresh.pending_card_unlocks().is_empty(),
		"fresh save does not queue default cards for presentation")
	var round_trip: Dictionary = fresh._as_dict()
	fresh._apply(round_trip)
	_check(out, fresh.pending_card_unlocks().is_empty(),
		"fresh save round trip does not create an unlock event")
	_check(out, not fresh.unlock_card("reroll", "power", false),
		"default power cards cannot create a fake unlock event")
	fresh.free()

## Issue #52: the pending card-unlock queue is persisted meta state, so it has to
## survive the JSON round trip that save_state()/load_state() perform and it has
## to migrate in empty for saves written before the queue existed.
static func _check_card_unlock_queue_52(store: Object, out: Array) -> void:
	var pre_queue_save := {
		"schemaVersion": 4,
		"unlockedAugmentCardIds": PacteCards.augment_ids(),
		"unlockedPowerCardIds": PacteCards.power_ids(),
	}
	# Fresh saves start on the default roster only, listed in catalog order.
	for pool in PacteCards.POOLS:
		var fresh: Array = CardUnlocks.unlocked_ids_for(pool, {})
		var defaults: Array = CardUnlocks.default_ids(pool)
		var sorted_fresh := fresh.duplicate()
		sorted_fresh.sort()
		var sorted_defaults := defaults.duplicate()
		sorted_defaults.sort()
		_check(out, str(sorted_fresh) == str(sorted_defaults),
			"a fresh save owns only the default %s roster" % pool)
		var catalog: Array = PacteCards.ids_for_pool(pool)
		var in_order := true
		var last := -1
		for card_id in fresh:
			var index := catalog.find(card_id)
			if index <= last:
				in_order = false
			last = index
		_check(out, in_order, "the default %s roster is listed in catalog order" % pool)

	# Progress already banked pulls its cards into the starting roster.
	var earned: Array = CardUnlocks.unlocked_ids_for("power",
		{ CardUnlocks.METRIC_WINS: 1 })
	_check(out, earned.has("cheat"), "a recorded win owns the Cheat power")
	_check(out, not CardUnlocks.unlocked_ids_for("power", {}).has("cheat"),
		"Cheat is locked without a win")
	var migrated: Dictionary = store._migrate(pre_queue_save)
	_check(out, int(migrated["schemaVersion"]) == store.CANONICAL_SCHEMA_VERSION,
		"card queue migration canonicalizes the schema version")
	_check(out, migrated.has("pendingCardUnlocks") and (migrated["pendingCardUnlocks"] as Array).is_empty(),
		"pre-queue saves migrate to an empty pending card-unlock queue")

	# A card removed from the unlock list and re-earned queues exactly once.
	var card_id := "augment_hallucination"
	var without_card: Array = PacteCards.augment_ids()
	without_card.erase(card_id)
	store._apply({
		"schemaVersion": store.CANONICAL_SCHEMA_VERSION,
		"unlockedAugmentCardIds": without_card,
		"unlockedPowerCardIds": PacteCards.power_ids(),
		"pendingCardUnlocks": [],
	})
	_check(out, not store.unlockedAugmentCardIds.has(card_id), "probe card starts locked")
	_check(out, store.unlock_card(card_id, "augment", false), "unlock_card unlocks a locked card")
	_check(out, store.unlockedAugmentCardIds.has(card_id), "unlock_card updates the unlocked list")
	_check(out, store.pending_card_unlocks().size() == 1, "unlock_card queues exactly one entry")
	_check(out, not store.unlock_card(card_id, "augment", false), "re-unlocking an owned card is a no-op")
	_check(out, store.pending_card_unlocks().size() == 1, "duplicate unlocks add no queue entry")
	_check(out, not store.unlock_card(card_id, "power", false), "a mismatched pool is rejected")
	_check(out, not store.unlock_card("not_a_card", "augment", false), "an unknown card ID is rejected")

	# Save/load round trip: exactly what save_state()/load_state() do to the queue.
	var written: String = JSON.stringify(store._as_dict())
	var reloaded: Variant = JSON.parse_string(written)
	_check(out, typeof(reloaded) == TYPE_DICTIONARY, "meta save round trips as an object")
	if typeof(reloaded) == TYPE_DICTIONARY:
		var record: Dictionary = store._migrate(reloaded as Dictionary)
		store._apply(record)
		var pending: Array = store.pending_card_unlocks()
		_check(out, pending.size() == 1, "pending card unlocks survive save/load")
		if pending.size() == 1:
			var entry: Dictionary = pending[0]
			_check(out, String(entry.get("cardId", "")) == card_id,
				"the reloaded queue keeps the unlocked card ID")
			_check(out, String(entry.get("pool", "")) == "augment",
				"the reloaded queue keeps the card's pool")
			_check(out, not bool(entry.get("presented", true)),
				"the reloaded queue is still awaiting presentation")
	_check(out, store.acknowledge_card_unlock(card_id, false), "acknowledging drops the queued card")
	_check(out, store.pending_card_unlocks().is_empty(), "the queue drains after acknowledgement")
	_check(out, not store.acknowledge_card_unlock(card_id, false), "acknowledging twice is a no-op")

	# A queued card that is not actually unlocked never reaches the popup.
	store._apply({
		"schemaVersion": store.CANONICAL_SCHEMA_VERSION,
		"unlockedAugmentCardIds": without_card,
		"unlockedPowerCardIds": PacteCards.power_ids(),
		"pendingCardUnlocks": [
			{ "cardId": card_id, "pool": "augment", "presented": false },
			{ "cardId": "not_a_card", "pool": "augment", "presented": false },
		],
	})
	_check(out, store.pending_card_unlocks().is_empty(),
		"locked and unknown cards are dropped from a hand-edited queue")

	# Draw filtering keeps consuming the unlocked ID lists unchanged.
	var drawn: Array = PacteCards.draw("augment", 4242, without_card, [], 3)
	var leaked := false
	for drawn_id in drawn:
		if not without_card.has(String(drawn_id)):
			leaked = true
	_check(out, not leaked, "Pacte draw filtering still respects the unlocked list")

## Issue #52 unlock rules: the deck is gated behind CardUnlocks, progress counters
## drive the unlocks, and a pre-v6 save is re-gated from the history it carries.
static func _check_card_unlock_rules_52(store: Object, out: Array) -> void:
	# Every card is either a default or has exactly one unlock rule — no card can
	# be stranded with no way to earn it.
	var rules := CardUnlocks.rule_map()
	var catalog: Array[String] = []
	catalog.append_array(PacteCards.augment_ids())
	catalog.append_array(PacteCards.power_ids())
	for card_id in catalog:
		var reachable := CardUnlocks.is_default(card_id) or rules.has(card_id)
		_check(out, reachable, "card %s is either a default or has an unlock rule" % card_id)
		_check(out, not (CardUnlocks.is_default(card_id) and rules.has(card_id)),
			"card %s is not both a default and a rule" % card_id)
	for card_id in rules:
		_check(out, String((rules[card_id] as Dictionary)["pool"]) == PacteCards.pool_of(String(card_id)),
			"rule for %s names the card's real pool" % card_id)

	# Progress crosses a threshold -> the card unlocks and queues exactly once.
	store._apply({
		"schemaVersion": store.CANONICAL_SCHEMA_VERSION,
		"unlockedAugmentCardIds": CardUnlocks.default_ids("augment"),
		"unlockedPowerCardIds": CardUnlocks.default_ids("power"),
		"pendingCardUnlocks": [],
		"cardUnlockProgress": {},
	})
	_check(out, not store.unlockedPowerCardIds.has("cheat"), "Cheat starts locked")
	_check(out, not store.unlockedAugmentCardIds.has("augment_hallucination"),
		"Hallucination starts locked")

	var unlocked: Array = store.add_card_unlock_progress(CardUnlocks.METRIC_CONSUMABLES_USED, 9, false)
	_check(out, unlocked.is_empty(), "9 consumables does not unlock Hallucination")
	_check(out, not store.unlockedAugmentCardIds.has("augment_hallucination"),
		"Hallucination stays locked below its threshold")
	unlocked = store.add_card_unlock_progress(CardUnlocks.METRIC_CONSUMABLES_USED, 1, false)
	_check(out, unlocked == ["augment_hallucination"], "the 10th consumable unlocks Hallucination")
	_check(out, store.unlockedAugmentCardIds.has("augment_hallucination"),
		"the unlocked card joins the augment list")
	_check(out, store.pending_card_unlocks().size() == 1, "a rule unlock queues one popup entry")
	unlocked = store.add_card_unlock_progress(CardUnlocks.METRIC_CONSUMABLES_USED, 5, false)
	_check(out, unlocked.is_empty(), "further progress past the threshold unlocks nothing new")
	_check(out, store.pending_card_unlocks().size() == 1, "further progress queues no duplicate")

	# "Best single run" metrics only move upward.
	store.record_best_card_unlock_progress(CardUnlocks.METRIC_BEST_RUN_SCORE, 2100, false)
	_check(out, store.unlockedAugmentCardIds.has("augment_reward_2"),
		"a 2100 run unlocks REWARD + II")
	_check(out, not store.unlockedAugmentCardIds.has("augment_reward_3"),
		"a 2100 run does not unlock REWARD + III")
	store.record_best_card_unlock_progress(CardUnlocks.METRIC_BEST_RUN_SCORE, 900, false)
	_check(out, store.card_unlock_progress(CardUnlocks.METRIC_BEST_RUN_SCORE) == 2100,
		"a weaker run does not lower the best-run record")
	store.record_best_card_unlock_progress(CardUnlocks.METRIC_BEST_RUN_SCORE, 4000, false)
	_check(out, store.unlockedAugmentCardIds.has("augment_reward_3"),
		"a 4000 run unlocks REWARD + III")

	# Unlocks and their progress survive a fresh campaign; the defaults are re-asserted.
	store.start_new_campaign(false)
	_check(out, store.unlockedAugmentCardIds.has("augment_hallucination"),
		"a new campaign keeps earned cards")
	_check(out, store.card_unlock_progress(CardUnlocks.METRIC_CONSUMABLES_USED) == 15,
		"a new campaign keeps unlock progress")
	for card_id in CardUnlocks.DEFAULT_AUGMENT_IDS:
		_check(out, store.unlockedAugmentCardIds.has(card_id),
			"a new campaign keeps default augment %s" % card_id)

	# A pre-#52 save (whole catalog unlocked) is re-gated, keeping what its history earned.
	var legacy := {
		"schemaVersion": 4,
		"unlockedAugmentCardIds": PacteCards.augment_ids(),
		"unlockedPowerCardIds": PacteCards.power_ids(),
		"endingsReached": ["wealth", "flatline"],
		"history": { "bestScoreRun": 2500, "winsByTier": { "classic": 1, "joker": 1 } },
	}
	var migrated: Dictionary = store._migrate(legacy)
	var augments: Array = migrated["unlockedAugmentCardIds"]
	var powers: Array = migrated["unlockedPowerCardIds"]
	_check(out, not augments.has("augment_adrenaline"),
		"migration re-locks a card the old save never earned")
	_check(out, not powers.has("rewind"), "migration re-locks Rewind")
	for card_id in CardUnlocks.DEFAULT_AUGMENT_IDS:
		_check(out, augments.has(card_id), "migration keeps default augment %s" % card_id)
	for card_id in CardUnlocks.DEFAULT_POWER_IDS:
		_check(out, powers.has(card_id), "migration keeps default power %s" % card_id)
	_check(out, augments.has("augment_reward_2"), "migration credits the recorded best run")
	_check(out, augments.has("augment_joker"), "migration credits a recorded joker-tier win")
	_check(out, augments.has("augment_glitch_2"), "migration credits a recorded flatline death")
	_check(out, powers.has("cheat"), "migration credits a recorded win")
	_check(out, not powers.has("heart"), "migration does not credit an unearned heart-tier win")
	# Re-applying a migrated save is stable: nothing re-locks and nothing re-queues.
	store._apply(migrated)
	var after_augments: Array = store.unlockedAugmentCardIds.duplicate()
	store._apply(store._migrate(store._as_dict()))
	_check(out, str(store.unlockedAugmentCardIds) == str(after_augments),
		"re-loading a migrated save keeps the same unlocked cards")

	# Locked-card hints describe the condition and never the card itself. The two
	# tier-win cards are the documented exception: their condition is a named
	# Augmented Run tier that happens to share the card's name, and the player
	# cannot act on the hint without it.
	var tier_named: Array[String] = ["augment_joker", "heart"]
	for card_id in rules:
		var hint := CardUnlocks.hint_for(String(card_id), {})
		var card := PacteCards.card(String(card_id))
		_check(out, hint != "", "card %s exposes an unlock hint" % card_id)
		if not tier_named.has(String(card_id)):
			_check(out, not hint.contains(String(card["name"])),
				"the hint for %s does not name the card" % card_id)
		_check(out, not hint.contains(String(card["description"])),
			"the hint for %s does not leak its description" % card_id)
