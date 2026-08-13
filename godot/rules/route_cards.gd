class_name RouteCards
extends RefCounted

## Deterministic route offers for the between-machine loop.
##
## A route card is deliberately data-only. The destination scenes own presentation
## and the stores own payment/effects, which keeps refusing a route completely free
## and makes the offer safe to serialize in a run snapshot.

const OFFER_COUNT := 3
const ROUTE_PACTE := "pacte"
const ROUTE_SHOP := "shop"
const ROUTE_DEALER := "dealer"
const ROUTE_EVENT := "event"
const CARD_PACTE_ID := "route_pacte"
const CARD_SHOP_ID := "route_shop"
const CARD_DEALER_ID := "route_dealer"

const PACTE_ROUTE_COST := 5
const SHOP_ROUTE_COST := 8
const DEALER_ROUTE_COST := 5

const _CARDS: Array[Dictionary] = [
	{
		"id": CARD_PACTE_ID,
		"routeType": ROUTE_PACTE,
		"displayName": "PACTE",
		"description": "BUY A BUILD CARD AND A POWER FOR THE NEXT MACHINE.",
		"lucidityCost": PACTE_ROUTE_COST,
		"spinSacrificeCost": 0,
		"tier": 1,
	},
	{
		"id": CARD_SHOP_ID,
		"routeType": ROUTE_SHOP,
		"displayName": "SHOP",
		"description": "INVEST IN ODDS, PROTECTION, OR SINGLE-USE ITEMS.",
		"lucidityCost": SHOP_ROUTE_COST,
		"spinSacrificeCost": 0,
		"tier": 1,
	},
	{
		"id": CARD_DEALER_ID,
		"routeType": ROUTE_DEALER,
		"displayName": "DEALER",
		"description": "TAKE TACTICAL ITEMS, REROLL, OR MANIPULATE THE RUN.",
		"lucidityCost": DEALER_ROUTE_COST,
		"spinSacrificeCost": 0,
		"tier": 1,
	},
]

static func _copy_card(card: Dictionary, seed_identity: int, free_loss_route: bool) -> Dictionary:
	var result := card.duplicate(true)
	result["seedIdentity"] = "%08x:%s" % [seed_identity & 0xFFFFFFFF, String(card["id"])]
	result["freeLossRoute"] = free_loss_route and String(card["routeType"]) == ROUTE_PACTE
	if bool(result["freeLossRoute"]):
		result["lucidityCost"] = 0
		result["tier"] = 0
	return result

## Returns exactly three cards in a deterministic order for a given seed. The
## route catalogue is small today, but rotation is seed-driven so adding an Event
## card later will not require inventing a second offer algorithm.
static func offer(seed: int, context: String = "wealth_target") -> Array[Dictionary]:
	var free_loss_route := context == "flatline"
	var rng := LobRNG.new(seed & 0xFFFFFFFF)
	var offset := floori(rng.next() * float(_CARDS.size()))
	var result: Array[Dictionary] = []
	for index in OFFER_COUNT:
		var source_index := (offset + index) % _CARDS.size()
		var identity := (seed ^ ((index + 1) * 0x9E3779B9)) & 0xFFFFFFFF
		result.append(_copy_card(_CARDS[source_index], identity, free_loss_route))
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
	return route_type_value == ROUTE_PACTE or route_type_value == ROUTE_SHOP \
			or route_type_value == ROUTE_DEALER or route_type_value == ROUTE_EVENT
