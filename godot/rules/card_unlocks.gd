class_name CardUnlocks
extends RefCounted

## Which Pacte cards the player starts with, and what earns the rest (issue #52).
##
## Every rule is a threshold on one named progress metric that MetaStateStore
## accumulates. Keeping the rules as data here means the unlock conditions, the
## Collection hints, and the card-unlock evaluation can never disagree, and adding
## a card is a one-line change rather than new branching in the stores.

## The roster the player owns from the first launch.
const DEFAULT_AUGMENT_IDS: Array[String] = [
	"augment_reward_1",
	"augment_smart_saving",
	"augment_passive_gain",
	"augment_book",
]
const DEFAULT_POWER_IDS: Array[String] = ["reroll", "shift", "memory"]

# Progress metric IDs. "total" metrics accumulate for the lifetime of the save;
# "best" metrics keep the highest single-run value ever reached.
const METRIC_BEST_RUN_SCORE := "best_run_score"        # best
const METRIC_CONSUMABLES_USED := "consumables_used"    # total
const METRIC_PAIRS_IN_RUN := "pairs_in_run"            # best
const METRIC_SAME_TRIPLE_IN_RUN := "same_triple_in_run" # best
const METRIC_POWER_RESTORES := "power_restores"        # total
const METRIC_JOKER_TIER_WINS := "joker_tier_wins"      # total
const METRIC_HEART_TIER_WINS := "heart_tier_wins"      # total
const METRIC_FLAWLESS_WINS := "flawless_wins"          # total
const METRIC_FLATLINE_DEATHS := "flatline_deaths"      # total
const METRIC_WINS := "wins"                            # total
const METRIC_REWINDS := "rewinds"                      # total
const METRIC_SHIFT_WINS := "shift_wins"                # total
const METRIC_CHEATS_USED := "cheats_used"              # total

const MODE_TOTAL := "total"
const MODE_BEST := "best"

## card_id -> unlock rule. `hint` is safe to show on a locked card: it describes
## the condition only, never the card's own name, description, or effect.
const RULES: Array[Dictionary] = [
	{
		"id": "augment_reward_2", "pool": "augment",
		"metric": METRIC_BEST_RUN_SCORE, "mode": MODE_BEST, "threshold": 2000,
		"hint": "REACH A RUN TARGET OF 2000.",
	},
	{
		"id": "augment_reward_3", "pool": "augment",
		"metric": METRIC_BEST_RUN_SCORE, "mode": MODE_BEST, "threshold": 4000,
		"hint": "REACH A RUN TARGET OF 4000.",
	},
	{
		"id": "augment_hallucination", "pool": "augment",
		"metric": METRIC_CONSUMABLES_USED, "mode": MODE_TOTAL, "threshold": 10,
		"hint": "USE 10 CONSUMABLES.",
	},
	{
		"id": "augment_pattern_recognition", "pool": "augment",
		"metric": METRIC_PAIRS_IN_RUN, "mode": MODE_BEST, "threshold": 20,
		"hint": "LAND 20 PAIRS IN ONE RUN.",
	},
	{
		"id": "augment_tunnel_vision", "pool": "augment",
		"metric": METRIC_SAME_TRIPLE_IN_RUN, "mode": MODE_BEST, "threshold": 3,
		"hint": "LAND THE SAME TRIPLE 3 TIMES IN ONE RUN.",
	},
	{
		"id": "augment_adrenaline", "pool": "augment",
		"metric": METRIC_POWER_RESTORES, "mode": MODE_TOTAL, "threshold": 30,
		"hint": "RESTORE POWER 30 TIMES.",
	},
	{
		"id": "augment_joker", "pool": "augment",
		"metric": METRIC_JOKER_TIER_WINS, "mode": MODE_TOTAL, "threshold": 1,
		"hint": "WIN A JOKER AUGMENTED RUN.",
	},
	{
		"id": "augment_win_boost", "pool": "augment",
		"metric": METRIC_FLAWLESS_WINS, "mode": MODE_TOTAL, "threshold": 1,
		"hint": "WIN A RUN WITHOUT A SINGLE FLATLINE.",
	},
	{
		"id": "augment_glitch_2", "pool": "augment",
		"metric": METRIC_FLATLINE_DEATHS, "mode": MODE_TOTAL, "threshold": 1,
		"hint": "DIE OF FLATLINE.",
	},
	# Issue #52 lists no condition for this card. It is gated on the Cheat power so
	# it is neither free nor unreachable; change the rule here if the design wants
	# a different trigger.
	{
		"id": "augment_how_to_cheat", "pool": "augment",
		"metric": METRIC_CHEATS_USED, "mode": MODE_TOTAL, "threshold": 10,
		"hint": "USE THE CHEAT POWER 10 TIMES.",
	},
	{
		"id": "heart", "pool": "power",
		"metric": METRIC_HEART_TIER_WINS, "mode": MODE_TOTAL, "threshold": 1,
		"hint": "WIN A HEART AUGMENTED RUN.",
	},
	{
		"id": "cheat", "pool": "power",
		"metric": METRIC_WINS, "mode": MODE_TOTAL, "threshold": 1,
		"hint": "WIN A RUN.",
	},
	{
		"id": "rewind", "pool": "power",
		"metric": METRIC_REWINDS, "mode": MODE_TOTAL, "threshold": 20,
		"hint": "RECOVER 20 SPENT SPINS.",
	},
	{
		"id": "swap", "pool": "power",
		"metric": METRIC_SHIFT_WINS, "mode": MODE_TOTAL, "threshold": 10,
		"hint": "TURN 10 SPINS INTO A WIN WITH SHIFT.",
	},
]

static func default_ids(pool: String) -> Array[String]:
	if pool == "augment":
		return DEFAULT_AUGMENT_IDS.duplicate()
	if pool == "power":
		return DEFAULT_POWER_IDS.duplicate()
	var empty: Array[String] = []
	return empty

static func is_default(card_id: String) -> bool:
	var normalised := PacteCards.normalise_card_id(card_id)
	return DEFAULT_AUGMENT_IDS.has(normalised) or DEFAULT_POWER_IDS.has(normalised)

static func rule_map() -> Dictionary:
	var result: Dictionary = {}
	for rule in RULES:
		result[String(rule["id"])] = rule
	return result

static func rule_for(card_id: String) -> Dictionary:
	var value: Variant = rule_map().get(PacteCards.normalise_card_id(card_id), {})
	return (value as Dictionary).duplicate(true)

static func is_total_metric(metric: String) -> bool:
	for rule in RULES:
		if String(rule["metric"]) == metric:
			return String(rule["mode"]) == MODE_TOTAL
	return true

## Cards whose condition `progress` already satisfies, in authored card order so
## a batch of simultaneous unlocks is presented deterministically.
static func satisfied_ids(progress: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var by_id := rule_map()
	for card_id in _catalog_ids():
		var rule: Variant = by_id.get(card_id, null)
		if rule == null:
			continue
		var record := rule as Dictionary
		if int(progress.get(String(record["metric"]), 0)) >= int(record["threshold"]):
			result.append(card_id)
	return result

## The full starting roster for a fresh save: the defaults plus anything the given
## progress already earns (used when migrating a save that carries history).
static func unlocked_ids_for(pool: String, progress: Dictionary) -> Array[String]:
	var result := default_ids(pool)
	for card_id in satisfied_ids(progress):
		if PacteCards.pool_of(card_id) == pool and not result.has(card_id):
			result.append(card_id)
	# Keep the authored catalog order rather than defaults-then-earned order.
	var ordered: Array[String] = []
	for card_id in PacteCards.ids_for_pool(pool):
		if result.has(card_id):
			ordered.append(card_id)
	return ordered

## Progress hint for a locked catalog entry, or "" when the card has no rule.
static func hint_for(card_id: String, progress: Dictionary) -> String:
	var rule := rule_for(card_id)
	if rule.is_empty():
		return ""
	var threshold := int(rule["threshold"])
	if threshold <= 1:
		return String(rule["hint"])
	var current := mini(int(progress.get(String(rule["metric"]), 0)), threshold)
	return "%s  (%d/%d)" % [String(rule["hint"]), current, threshold]

static func _catalog_ids() -> Array[String]:
	var result: Array[String] = []
	result.append_array(PacteCards.augment_ids())
	result.append_array(PacteCards.power_ids())
	return result
