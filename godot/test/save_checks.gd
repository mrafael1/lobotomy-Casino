class_name SaveChecks
extends RefCounted

const MetaStoreScript := preload("res://autoload/meta_state_store.gd")

static func _check(out: Array, cond: bool, label: String) -> void:
	if not cond:
		out.append("SAVE: " + label)

static func run_all() -> Array:
	var out: Array = []
	var store := MetaStoreScript.new()
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
	store.free()
	return out

## Issue #52: the pending card-unlock queue is persisted meta state, so it has to
## survive the JSON round trip that save_state()/load_state() perform and it has
## to migrate in empty for saves written before the queue existed.
static func _check_card_unlock_queue_52(store: Object, out: Array) -> void:
	var pre_queue_save := {
		"schemaVersion": 4,
		"unlockedAugmentCardIds": PacteCards.augment_ids(),
		"unlockedPowerCardIds": PacteCards.power_ids(),
	}
	var migrated: Dictionary = store._migrate(pre_queue_save)
	_check(out, int(migrated["schemaVersion"]) == store.CANONICAL_SCHEMA_VERSION,
		"card queue migration canonicalizes the schema version")
	_check(out, migrated.has("pendingCardUnlocks") and (migrated["pendingCardUnlocks"] as Array).is_empty(),
		"pre-queue saves migrate to an empty pending card-unlock queue")

	# A card removed from the unlock list and re-earned queues exactly once.
	var card_id := "augment_book"
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
