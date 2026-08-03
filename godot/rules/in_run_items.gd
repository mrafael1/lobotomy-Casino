class_name InRunItems
extends RefCounted

## Dealer-offered items (dealer-offered items). The effect deltas are
## pinned in dealer_vectors.json -> inRunItems.

const LIST := [
	# The Energy Drink is two free spins and nothing else. It used to pin the gauge at x2
	# and queue a compulsory spin afterwards, which made the run's most common item a
	# trade the player kept declining; the rush is now simply the item.
	{ "id": "item_energy_drink", "name": "Energy Drink",
	  "effect": { "type": "skipDecay", "spins": 2 } },
	{ "id": "item_cocktail", "name": "Cocktail",
	  "effect": { "type": "cocktailBoost", "spins": 2 } },
	{ "id": "item_water", "name": "Water",
	  "effect": { "type": "addLucidity", "amount": 40 } },
	{ "id": "item_pill", "name": "Red Pill", "corrupt": true,
	  "effect": { "type": "forceFlatlinesThenTriple", "flatSpins": 1, "guaranteedTripleNext": true } },
]

## Joker Augmented runs (issue #111) deal these four instead: the same four items with
## the same ids, turned against the player. Keeping the ids means the stash, the icons,
## the badges and the save format need no second pool — only the effect looked up here
## and the inverted colour the art renders in differ.
##
## Each is the mirror of what the item normally does: the drink's rush becomes the
## compulsion alone, Water drains the gauge it should have filled, the Red Pill's forced
## flatline shrinks to a single reel with no triple owed back, and the Cocktail's rarity
## points are charged instead of paid.
const JOKER_EFFECTS := {
	"item_energy_drink": { "type": "compulsion", "compulsiveSpins": 1 },
	"item_cocktail": { "type": "cocktailMalus", "spins": 2 },
	"item_water": { "type": "drainPowerBar" },
	"item_pill": { "type": "flatlineOneReel", "spins": 1 },
}

## The effect an item actually applies. `joker` is the run asking, not the item: the same
## stashed Water is a gift on a classic run and a drain on a joker one.
static func effect_for(item_id: String, joker: bool) -> Variant:
	var entry: Variant = map().get(item_id, null)
	if entry == null:
		return null
	if joker and JOKER_EFFECTS.has(item_id):
		return JOKER_EFFECTS[item_id]
	return (entry as Dictionary)["effect"]

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
