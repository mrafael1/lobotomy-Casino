class_name ShopItems
extends RefCounted

## Run-scoped investments sold by the route Shop. These are intentionally not
## Upgrades (wallet/Lab) or Chip Augments (campaign/Dealer).

const LIST: Array[Dictionary] = [
	{
		"id": "shop_brain_feed",
		"name": "BRAIN FEED",
		"description": "+3 BRAIN WEIGHT FOR THIS RUN.",
		"cost": 20,
		"kind": "upgrade",
	},
	{
		"id": "shop_pair_guard",
		"name": "PAIR GUARD",
		"description": "THE NEXT 3 PAID SPINS CANNOT MISS NATURALLY.",
		"cost": 28,
		"kind": "upgrade",
	},
	{
		"id": "shop_spin_reserve",
		"name": "SPIN RESERVE",
		"description": "+2 SPINS, SUBJECT TO THE NORMAL CAP.",
		"cost": 24,
		"kind": "upgrade",
	},
	{
		"id": "shop_stasis",
		"name": "STASIS",
		"description": "PROTECT THE NEXT 2 PAID SPIN COSTS.",
		"cost": 22,
		"kind": "upgrade",
	},
]

static func map() -> Dictionary:
	var result: Dictionary = {}
	for item in LIST:
		result[String(item["id"])] = item.duplicate(true)
	for consumable in Consumables.LIST:
		var copy: Dictionary = consumable.duplicate(true)
		copy["cost"] = int(copy.get("shopCost", 0))
		copy["kind"] = "consumable"
		result[String(copy["id"])] = copy
	return result

static func item(item_id: String) -> Dictionary:
	return (map().get(item_id, {}) as Dictionary).duplicate(true)

static func ids() -> Array[String]:
	var result: Array[String] = []
	for item_id in map().keys():
		result.append(String(item_id))
	result.sort()
	return result

static func cost(item_id: String) -> int:
	return maxi(0, int(item(item_id).get("cost", 0)))
