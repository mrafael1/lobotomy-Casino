class_name InRunItems
extends RefCounted

## Dealer-offered items (dealer-offered items). The effect deltas are
## pinned in dealer_vectors.json -> inRunItems.

const LIST := [
	{ "id": "item_energy_drink", "name": "Energy Drink", "corrupt": true,
	  "effect": { "type": "skipDecay", "spins": 2, "blockBet": "x3", "compulsiveSpins": 1 } },
	{ "id": "item_cocktail", "name": "Cocktail",
	  "effect": { "type": "cocktailBoost", "spins": 2 } },
	{ "id": "item_water", "name": "Water",
	  "effect": { "type": "addLucidity", "amount": 40 } },
	{ "id": "item_pill", "name": "Red Pill", "corrupt": true,
	  "effect": { "type": "forceFlatlinesThenTriple", "flatSpins": 1, "guaranteedTripleNext": true } },
]

## Rarity points the Cocktail pays per VISIBLE reel. Rarer symbol, bigger point.
const COCKTAIL_RARITY_POINTS := {
	"flatline": 1, "vial": 2, "syringe": 3, "pill": 4, "eye": 5, "brain": 6, "book": 6,
}

## The Cocktail is pure upside and win-type blind: it pays rarity points for every
## visible reel on the spin, whatever the reels did. Misses, pairs and triples all
## collect — a pair or triple must never be the one result that loses the bonus, which
## is what the old 15% pair/triple tax amounted to. It used to be private to
## RunStateStore, where no parity check could reach it (issue #185).
##
## `hidden_reel_count` follows evaluate()'s own slice: a reel Tobacco hides from scoring
## is not visible, so it pays nothing. The multiplier is the spin's score multiplier, and
## the result rounds with the project rule (floor(x + 0.5)).
static func cocktail_bonus(reels: Array, hidden_reel_count: int,
		score_multiplier: float) -> int:
	var visible_count := maxi(1, reels.size() - maxi(0, hidden_reel_count))
	var rarity_total := 0
	for i in mini(visible_count, reels.size()):
		rarity_total += int(COCKTAIL_RARITY_POINTS.get(String(reels[i]), 0))
	return floori(float(rarity_total) * score_multiplier + 0.5)

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
