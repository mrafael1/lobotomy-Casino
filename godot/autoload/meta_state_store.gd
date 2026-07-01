extends Node

## Autoload singleton "MetaStateStore" — port of src/state/metaState.ts plus the
## persistence layer (Step 4). Persists to user:// as JSON using the same logical
## shape as the MMKV `lobotomy-meta` save.
##
## schemaVersion: v2 is canonical (matches INITIAL_META_STATE.schemaVersion on the
## Expo side; the code-constant-says-1 mismatch is resolved here in favour of v2).
## A migration seam mirrors src/persistence/migrations.ts but ships empty — a
## v1->v2 migration is only added if an actual v1 payload is ever found in the wild.

const SAVE_PATH := "user://lobotomy-meta.json"
const CANONICAL_SCHEMA_VERSION := 2

var schemaVersion: int = CANONICAL_SCHEMA_VERSION
var lucidityWallet: int = 0
var ownedPermanents: Array = []
var corruptionEverUsed: bool = false
var endingsReached: Array = []
var pendingConsumables: Dictionary = {}
var history: Dictionary = { "runsPlayed": 0, "bestScoreRun": 0 }

signal meta_changed

func _ready() -> void:
	load_state()

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
	}

func _apply(meta: Dictionary) -> void:
	schemaVersion = int(meta.get("schemaVersion", CANONICAL_SCHEMA_VERSION))
	lucidityWallet = int(meta.get("lucidityWallet", 0))
	ownedPermanents = (meta.get("ownedPermanents", []) as Array).duplicate()
	corruptionEverUsed = bool(meta.get("corruptionEverUsed", false))
	endingsReached = (meta.get("endingsReached", []) as Array).duplicate()
	pendingConsumables = (meta.get("pendingConsumables", {}) as Dictionary).duplicate(true)
	history = (meta.get("history", { "runsPlayed": 0, "bestScoreRun": 0 }) as Dictionary).duplicate(true)
	meta_changed.emit()

# ── action API (mirrors metaState.ts) ────────────────────────────────────────────

func bank_run(run: Dictionary, ending: String) -> void:
	var next := Endings.bank_run_to_meta(run, _as_dict(), ending, _now_ms())
	_apply(next)
	pendingConsumables = {} # cleared on bank, matching the Expo store
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

func buy_consumable_charge(consumable_id: String) -> void:
	var cmap := Consumables.map()
	var consumable: Variant = cmap.get(consumable_id, null)
	if consumable == null:
		return
	if lucidityWallet < int(consumable["shopCost"]):
		return
	if Consumables.total_copies(pendingConsumables) >= Consumables.MAX_CONSUMABLE_SLOTS:
		return
	lucidityWallet -= int(consumable["shopCost"])
	pendingConsumables = pendingConsumables.duplicate(true)
	pendingConsumables[consumable_id] = int(pendingConsumables.get(consumable_id, 0)) + 1
	meta_changed.emit()
	save_state()

func discard_pending_consumable(consumable_id: String) -> void:
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
	lucidityWallet += (int(consumable["shopCost"]) if consumable != null else 0)
	meta_changed.emit()
	save_state()

func mark_ending_reached(ending: String) -> void:
	if not endingsReached.has(ending):
		endingsReached = endingsReached.duplicate()
		endingsReached.append(ending)
	if ending == "wealth" and not history.has("wealthEndingReachedAt"):
		history = history.duplicate(true)
		history["wealthEndingReachedAt"] = _now_ms()
	elif ending == "exit" and not history.has("exitEndingReachedAt"):
		history = history.duplicate(true)
		history["exitEndingReachedAt"] = _now_ms()
	meta_changed.emit()
	save_state()

func get_pending_consumables() -> Dictionary:
	return pendingConsumables.duplicate(true)

# ── persistence (Step 4) ──────────────────────────────────────────────────────────

func save_state() -> void:
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

# Migration seam mirroring src/persistence/migrations.ts. Ships empty: v2 is the
# only shape known to have shipped, so no speculative v1->v2 migration is written.
# If a real v1 payload is ever found, register it in _MIGRATIONS keyed by version.
const _MIGRATIONS := {}

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
	return current
