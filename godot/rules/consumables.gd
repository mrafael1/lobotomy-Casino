class_name Consumables
extends RefCounted

## Port of src/content/consumables.ts (pre-run shop consumables).

const MAX_CONSUMABLE_SLOTS := 2

## Potion (resetPowersRandomEffect) rolls ONE of these per boosted spin, equal-weight
## with a deterministic per-spin seed (issue #32). Mirrors POTION_RANDOM_POOL in
## src/content/consumables.ts.
const POTION_RANDOM_POOL := [
	{ "kind": "multNextSpin", "multiplier": 0.75 },
	{ "kind": "multNextSpin", "multiplier": 1.25 },
	{ "kind": "multNextSpin", "multiplier": 1.5 },
	{ "kind": "lucidity", "amount": 10 },
	{ "kind": "lucidity", "amount": -5 },
	{ "kind": "freeReroll" },
	{ "kind": "symbolToBrain" },
]

const LIST := [
	{ "id": "cons_cigarette", "name": "Tobacco", "shopCost": 20, "corrupt": true,
	  "effect": { "type": "hideReelPairBoost", "spins": 3, "hiddenReels": 1, "pairMult": 3 } },
	{ "id": "cons_focus", "name": "Serum", "shopCost": 15,
	  "effect": { "type": "guaranteeSymbol", "excludes": ["brain"], "appearSpins": 1, "banSpins": 2 } },
	{ "id": "cons_white_powder", "name": "White Powder", "shopCost": 10, "corrupt": true,
	  "effect": { "type": "scrambleThenHide", "hideNextSpin": true } },
	{ "id": "cons_syringe", "name": "Potion", "shopCost": 40,
	  "effect": { "type": "resetPowersRandomEffect", "spins": 3, "pool": POTION_RANDOM_POOL } },
	{ "id": "cons_tea", "name": "Tea", "shopCost": 8,
	  "effect": { "type": "restoreAbilityOrSpins", "fallbackSpins": 3 } },
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
