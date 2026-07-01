class_name Consumables
extends RefCounted

## Port of src/content/consumables.ts (pre-run shop consumables).

const MAX_CONSUMABLE_SLOTS := 2

const LIST := [
	{ "id": "cons_focus", "name": "Serum", "shopCost": 12,
	  "effect": { "type": "lucidityMultiplierNextSpin", "multiplier": 3.0, "hideNeuronsSpins": 5 } },
	{ "id": "cons_white_powder", "name": "White Powder", "shopCost": 14,
	  "effect": { "type": "copyReel" } },
	{ "id": "cons_syringe", "name": "test", "shopCost": 18,
	  "effect": { "type": "brainBoost", "spins": 5 } },
	{ "id": "cons_tea", "name": "Tea", "shopCost": 10,
	  "effect": { "type": "restoreAbility" } },
]

static func map() -> Dictionary:
	var m := {}
	for c in LIST:
		m[c["id"]] = c
	return m

static func total_copies(stash: Dictionary) -> int:
	var sum := 0
	for k in stash:
		sum += int(stash[k])
	return sum
