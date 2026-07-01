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
	_check(out, int(migrated["schemaVersion"]) == store.CANONICAL_SCHEMA_VERSION, "schema canonicalizes to v2")
	_check(out, int(migrated["lucidityWallet"]) == 17, "canonicalization preserves wallet")
	store.free()
	return out
