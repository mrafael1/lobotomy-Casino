class_name ChipAugments
extends RefCounted

## Chip Augments: small permanent bonuses for the current dealer/run cycle, sold
## as ONE dedicated dealer-scene offer per visit, separate from the normal
## item/consumable offer (and untouched by the painting reroll). Data-driven:
## every augment is a LIST entry; behaviour keys off `effect`.
##
## Rarity is display metadata (panel colour); availability is governed only by
## `stock` — an augment leaves the eligible pool when its copies are bought.

const DISCOUNT_PER_STACK := 0.10       # each discount copy: -10%, two stack to -20%
const SYMBOL_LEVEL_HARD_CAP := 9       # augments may push past odds_max_level, to 9
const AUGMENT_LEVELS_PER_SYMBOL := 1   # ...but only one augment level per symbol, ever
const PAIR_TRIPLE_MULT := 1.25         # legendary specialist: chosen win type x1.25
const EXTRA_SPINS_PER_COPY := 3
const EXPANDED_OFFER_COUNT := 3        # dealer visits generate 3 consumables, not 2

# Authored chip art: one 6-frame horizontal sheet, one unique chip per augment
# (`frame` indexes into it).
const ICON_SHEET := "items/chips_upgrade.png"
const ICON_HFRAMES := 6

# Every chip presents under the same "Augment" name (rarity colours it); the TV
# shows only beneficial green `hints` — one word each, up to two lines for
# context (the window fits ~7 chars). `blurb` is the full effect text shown in
# the dealer message strip on selection.
const LIST := [
	{ "id": "aug_consumable_discount", "name": "Augment", "rarity": "common",
	  "stock": 2, "cost": 25, "effect": "consumableDiscount", "hints": ["SALE", "ITEMS"],
	  "blurb": "CONSUMABLES COST -10%", "frame": 0 },
	{ "id": "aug_chip_discount", "name": "Augment", "rarity": "common",
	  "stock": 2, "cost": 25, "effect": "chipDiscount", "hints": ["SALE", "CHIPS"],
	  "blurb": "CHIPS COST -10%", "frame": 1 },
	{ "id": "aug_symbol_level", "name": "Augment", "rarity": "common",
	  "stock": 2, "cost": 40, "effect": "symbolLevel", "hints": ["SYMBOL", "LEVEL"],
	  "blurb": "ONE SYMBOL +1 LEVEL (MAX 9)", "frame": 2 },
	{ "id": "aug_extra_spins", "name": "Augment", "rarity": "common",
	  "stock": 1, "cost": 35, "effect": "extraSpins", "hints": ["SPINS"],
	  "blurb": "+3 SPINS THIS RUN", "frame": 3 },
	{ "id": "aug_offer_expand", "name": "Augment", "rarity": "rare",
	  "stock": 1, "cost": 50, "effect": "offerExpand", "hints": ["MORE", "ITEMS"],
	  "blurb": "DEALER OFFERS 3 ITEMS", "frame": 4 },
	{ "id": "aug_pair_triple", "name": "Augment", "rarity": "legendary",
	  "stock": 1, "cost": 80, "effect": "pairTripleSpecialist", "hints": ["WINS", "x1.25"],
	  "blurb": "PAIR OR TRIPLE WINS x1.25", "frame": 5 },
]

static func map() -> Dictionary:
	var m := {}
	for a in LIST:
		m[a["id"]] = a
	return m

static func ids() -> Array:
	var out: Array = []
	for a in LIST:
		out.append(String(a["id"]))
	return out

static func stock_left(augment_id: String, purchased: Dictionary) -> int:
	var entry: Variant = map().get(augment_id, null)
	if entry == null:
		return 0
	return maxi(0, int(entry["stock"]) - int(purchased.get(augment_id, 0)))

## Pool the dealer draws the dedicated offer from: anything with stock remaining.
static func eligible_ids(purchased: Dictionary) -> Array:
	var out: Array = []
	for a in LIST:
		if stock_left(String(a["id"]), purchased) > 0:
			out.append(String(a["id"]))
	return out

## Price after `stacks` discount copies, using the project rounding rule
## (JS Math.round = floor(x + 0.5), same as Evaluate._round).
static func discounted_price(base_cost: int, stacks: int) -> int:
	var factor := maxf(0.0, 1.0 - DISCOUNT_PER_STACK * float(stacks))
	return floori(float(base_cost) * factor + 0.5)

## Pair/Triple Specialist bonus riding on top of the pinned spin score (added
## after evaluate(), like the cocktail/flatline boosts, so vectors never shift).
static func specialist_bonus(base_score: int, win_type: String, choice: String) -> int:
	if choice == "" or base_score <= 0 or win_type != choice:
		return 0
	return floori(float(base_score) * (PAIR_TRIPLE_MULT - 1.0) + 0.5)
