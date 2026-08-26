class_name RouteCards
extends RefCounted

## Deterministic between-machine choices.
##
## The initial Pacte ritual is deliberately not one of these destinations.  A
## between-machine augment or power stop opens only the relevant card pool, so
## the player never has to repeat the full two-part Pacte ceremony mid-run.

const OFFER_COUNT := 2

const ROUTE_SHOP := "shop"
const ROUTE_AUGMENT := "augment"
const ROUTE_POWER := "power"
const ROUTE_BONUS := "bonus"
const ROUTE_SACRIFICE := "sacrifice"

# Route entry is always free. These named constants remain as compatibility
# surfaces for older callers and saved card dictionaries; content selected after
# entering a destination owns its own price.
const ROUTE_PACTE := "pacte"
const ROUTE_DEALER := "dealer"
const ROUTE_EVENT := "event"

const CARD_SHOP_ID := "route_shop"
const CARD_AUGMENT_ID := "route_augment"
const CARD_POWER_ID := "route_power"
const CARD_BONUS_ID := "route_bonus"
const CARD_SACRIFICE_ID := "route_sacrifice"

const SHOP_ROUTE_COST := 0
const AUGMENT_ROUTE_COST := 0
const POWER_ROUTE_COST := 0
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
		"description": "SPIN THE FORTUNE WHEEL FOR RUN GOLD OR WALLET CREDITS.",
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

## Returns exactly two deterministic choices from the route catalogue. A target
## offer always includes one investment route; a loss offer always includes one
## free tier-capped build route. The second card is drawn from the remaining
## catalogue, so Bonus and Sacrifice Later remain possible without presenting the
## whole catalogue at once.
static func offer(seed: int, context: String = "wealth_target") -> Array[Dictionary]:
	var free_loss_route := context == "flatline"
	var rng := LobRNG.new((seed ^ 0x524F5554) & 0xFFFFFFFF)
	var first_pool: Array[int] = []
	if free_loss_route:
		first_pool.append(1)
		first_pool.append(2)
	else:
		first_pool.append(0)
		first_pool.append(1)
		first_pool.append(2)
	var first_index := first_pool[mini(first_pool.size() - 1,
		int(rng.next() * float(first_pool.size())))]
	var remaining_indices: Array[int] = []
	for index in _CARDS.size():
		if index != first_index:
			remaining_indices.append(index)
	var second_index := remaining_indices[mini(remaining_indices.size() - 1,
		int(rng.next() * float(remaining_indices.size())))]
	var selected_indices: Array[int] = []
	selected_indices.append(first_index)
	selected_indices.append(second_index)
	var result: Array[Dictionary] = []
	for offer_index in selected_indices.size():
		var catalog_index := selected_indices[offer_index]
		var identity := (seed ^ ((catalog_index + 1) * 0x9E3779B9) \
			^ ((offer_index + 1) * 0x45D9F3B)) & 0xFFFFFFFF
		result.append(_copy_card(_CARDS[catalog_index], identity, free_loss_route))
	return result

static func _offer_signature(cards: Array) -> String:
	var ids: Array[String] = []
	for value in cards:
		if value is Dictionary:
			ids.append(String((value as Dictionary).get("id", "")))
	return "|".join(ids)

## Returns the next deterministic pair for a route-door reroll. The original
## offer seed remains the save anchor; the reroll index and a small collision
## walk derive a new pair without introducing runtime randomness. A reroll is
## guaranteed to change the visible route pair whenever the catalogue permits it.
static func reroll_offer(seed: int, context: String, reroll_index: int,
		previous: Array = []) -> Array[Dictionary]:
	var step := maxi(1, reroll_index)
	var candidate_seed := (seed ^ 0x5245524F ^ (step * 0x9E3779B9)) & 0xFFFFFFFF
	var previous_signature := _offer_signature(previous)
	for attempt in 8:
		var candidate := offer(candidate_seed, context)
		if _offer_signature(candidate) != previous_signature:
			return candidate
		candidate_seed = (candidate_seed + 0x45D9F3B) & 0xFFFFFFFF
	return offer(candidate_seed, context)

static func card(card_id: String) -> Dictionary:
	for card_entry in _CARDS:
		if String(card_entry["id"]) == card_id:
			return card_entry.duplicate(true)
	return {}

static func route_type(card_id: String) -> String:
	return String(card(card_id).get("routeType", ""))

static func card_cost(card: Dictionary) -> int:
	# Old saves may still carry the former 5G/8G field. Route cards are choices,
	# not purchases, so never charge that serialized value at the door.
	return 0

static func affordable(card: Dictionary, lucidity: int) -> bool:
	# `lucidity` is kept in the signature for callers compiled against the old
	# route-economy API. Neither Lucidity nor spins are charged to enter a route.
	return is_valid_route_type(String(card.get("routeType", "")))

static func is_valid_route_type(route_type_value: String) -> bool:
	return route_type_value == ROUTE_SHOP or route_type_value == ROUTE_AUGMENT \
			or route_type_value == ROUTE_POWER or route_type_value == ROUTE_BONUS \
			or route_type_value == ROUTE_SACRIFICE \
			or route_type_value == ROUTE_PACTE or route_type_value == ROUTE_DEALER \
			or route_type_value == ROUTE_EVENT
