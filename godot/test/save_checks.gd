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
	store.free()
	return out
