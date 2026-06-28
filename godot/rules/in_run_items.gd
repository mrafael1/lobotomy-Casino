class_name InRunItems
extends RefCounted

## Port of src/content/inRunItems.ts (dealer-offered items). The effect deltas are
## pinned in dealer_vectors.json -> inRunItems.

const LIST := [
	{ "id": "item_energy_drink", "name": "Energy Drink",
	  "effect": { "type": "skipDecay", "spins": 5, "forcedRandomBetSpins": 5 } },
	{ "id": "item_cocktail", "name": "Cocktail",
	  "effect": { "type": "cocktailBoost", "spins": 3, "compulsiveSpins": 2 } },
	{ "id": "item_water", "name": "Water",
	  "effect": { "type": "addLucidity", "amount": 40 } },
	{ "id": "item_pill", "name": "Red Pill",
	  "effect": { "type": "guaranteedWin", "spins": 3, "blockPowersSpins": 5 } },
]

static func ids() -> Array:
	var out := []
	for i in LIST:
		out.append(i["id"])
	return out

static func map() -> Dictionary:
	var m := {}
	for i in LIST:
		m[i["id"]] = i
	return m
