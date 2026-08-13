class_name RouteCards
extends RefCounted

## Deterministic between-machine choices.
##
## The initial Pacte ritual is deliberately not one of these destinations.  A
## between-machine augment or power stop opens only the relevant card pool, so
## the player never has to repeat the full two-part Pacte ceremony mid-run.

const OFFER_COUNT := 5

const ROUTE_SHOP := "shop"
const ROUTE_AUGMENT := "augment"
const ROUTE_POWER := "power"
const ROUTE_BONUS := "bonus"
const ROUTE_SACRIFICE := "sacrifice"

# Kept readable for older snapshots and callers. They are no longer included in
# newly generated offers.
const ROUTE_PACTE := "pacte"
const ROUTE_DEALER := "dealer"
const ROUTE_EVENT := "event"

const CARD_SHOP_ID := "route_shop"
const CARD_AUGMENT_ID := "route_augment"
const CARD_POWER_ID := "route_power"
const CARD_BONUS_ID := "route_bonus"
const CARD_SACRIFICE_ID := "route_sacrifice"

const SHOP_ROUTE_COST := 8
const AUGMENT_ROUTE_COST := 5
const POWER_ROUTE_COST := 5
const BONUS_ROUTE_COST := 0
const SACRIFICE_ROUTE_COST := 0

const _CARDS: Array[Dictionary] = [
	{
		"id": CARD_SHOP_ID,
		"routeType": ROUTE_SHOP,
		"displayName": "SHOP",
		"description": "IMPROVE MACHINE ODDS, PROTECTION, OR SINGLE-USE ITEMS.",
		"lucidityCost": SHOP_ROUTE_COST,
		"spinSacrificeCost": 0,
		"tier": 1,
	},
	{
		"id": CARD_AUGMENT_ID,
		"routeType": ROUTE_AUGMENT,
		"displayName": "AUGMENT",
		"description": "OPEN THE AUGMENT DECK. CHOOSE ONE BUILD CARD.",
		"lucidityCost": AUGMENT_ROUTE_COST,
		"spinSacrificeCost": 0,
		"tier": 1,
	},
	{
		"id": CARD_POWER_ID,
		"routeType": ROUTE_POWER,
		"displayName": "POWER",
		"description": "OPEN THE POWER DECK. CHOOSE ONE TACTICAL POWER.",
		"lucidityCost": POWER_ROUTE_COST,
		"spinSacrificeCost": 0,
		"tier": 1,
	},
	{
		"id": CARD_BONUS_ID,
		"routeType": ROUTE_BONUS,
		"displayName": "BONUS",
		"description": "TAKE A SMALL LUCIDITY BONUS BEFORE THE NEXT MACHINE.",
		"lucidityCost": BONUS_ROUTE_COST,
		"spinSacrificeCost": 0,
		"tier": 0,
	},
	{
		"id": CARD_SACRIFICE_ID,
		"routeType": ROUTE_SACRIFICE,
		"displayName": "SACRIFICE LATER",
		"description": "KEEP YOUR SPINS. DEFER THE SACRIFICE DECISION TO A LATER MILESTONE.",
		"lucidityCost": SACRIFICE_ROUTE_COST,
		"spinSacrificeCost": 0,
		"tier": 0,
	},
]

static func _copy_card(card: Dictionary, seed_identity: int, free_loss_route: bool) -> Dictionary:
	var result := card.duplicate(true)
	result["seedIdentity"] = "%08x:%s" % [seed_identity & 0xFFFFFFFF, String(card["id"])]
	var route_type := String(card["routeType"])
	result["freeLossRoute"] = free_loss_route \
			and (route_type == ROUTE_AUGMENT or route_type == ROUTE_POWER)
	if bool(result["freeLossRoute"]):
		result["lucidityCost"] = 0
		result["tier"] = 0
	return result

## Returns exactly five deterministic choices. The catalogue order is stable so
## every choice is always visible; the seed still gives each card a stable identity
## for save/debug/replay tooling.
static func offer(seed: int, context: String = "wealth_target") -> Array[Dictionary]:
	var free_loss_route := context == "flatline"
	var result: Array[Dictionary] = []
	for index in _CARDS.size():
		var identity := (seed ^ ((index + 1) * 0x9E3779B9)) & 0xFFFFFFFF
		result.append(_copy_card(_CARDS[index], identity, free_loss_route))
	return result

static func card(card_id: String) -> Dictionary:
	for card_entry in _CARDS:
		if String(card_entry["id"]) == card_id:
			return card_entry.duplicate(true)
	return {}

static func route_type(card_id: String) -> String:
	return String(card(card_id).get("routeType", ""))

static func card_cost(card: Dictionary) -> int:
	return maxi(0, int(card.get("lucidityCost", 0)))

static func affordable(card: Dictionary, lucidity: int) -> bool:
	return lucidity >= card_cost(card) and int(card.get("spinSacrificeCost", 0)) <= 0

static func is_valid_route_type(route_type_value: String) -> bool:
	return route_type_value == ROUTE_SHOP or route_type_value == ROUTE_AUGMENT \
			or route_type_value == ROUTE_POWER or route_type_value == ROUTE_BONUS \
			or route_type_value == ROUTE_SACRIFICE \
			or route_type_value == ROUTE_PACTE or route_type_value == ROUTE_DEALER \
			or route_type_value == ROUTE_EVENT
