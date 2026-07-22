class_name PacteCards
extends RefCounted

## Data for the two Pacte decks.  Card identity is deliberately separate from
## the run-scoped effect it applies: the deck can grow in MetaStateStore while a
## run only records the cards that were actually selected.

const CARD_SHEET := "cards/augment_cards.png"
const POWER_SHEET := "cards/power_cards.png"
const AUGMENT_FRONT_RECT := Rect2(0.0, 61.0, 39.0, 61.0)
const POWER_FRONT_RECT := Rect2(40.0, 0.0, 38.0, 61.0)

const AUGMENTS: Array[Dictionary] = [
	{
		"id": "augment_pattern_recognition", "name": "PATTERN RECOGNITION",
		"description": "BOOKS CAN COMPLETE A TRIPLE.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		"icon_rect": Rect2(5.0, 144.0, 30.0, 18.0),
		"effect": { "type": "owned_upgrade", "upgrade_id": "corr_pattern_23" },
	},
	{
		"id": "augment_book", "name": "BOOK",
		"description": "LEARNING ADDS BOOKS TO THE REELS.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		"icon_rect": Rect2(9.0, 201.0, 22.0, 27.0),
		"effect": { "type": "owned_upgrade", "upgrade_id": "pos_learning" },
	},
	{
		"id": "augment_hallucination", "name": "HALLUCINATION",
		"description": "VISIBLE PAIRS COUNT AS TRIPLES; REWARDS -30%.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		"icon_rect": Rect2(5.0, 262.0, 30.0, 28.0),
		"effect": { "type": "owned_upgrade", "upgrade_id": "pos_enlightenment" },
	},
	{
		"id": "augment_smart_saving", "name": "SMART SAVING",
		"description": "KEEP 20% OF LUCIDITY ON FLATLINE.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		"icon_rect": Rect2(6.0, 324.0, 27.0, 26.0),
		"effect": { "type": "owned_upgrade", "upgrade_id": "pos_smart_save" },
	},
	{
		"id": "augment_reward_1", "name": "REWARD + I",
		"description": "CHOOSE A SYMBOL AT THE NEXT DEALER VISIT.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		"icon_rect": Rect2(8.0, 386.0, 22.0, 21.0),
		"effect": { "type": "owned_upgrade", "upgrade_id": "corr_reward_amp_1" },
	},
	{
		"id": "augment_reward_2", "name": "REWARD + II",
		"description": "STACKS WITH REWARD + I.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		"icon_rect": Rect2(8.0, 447.0, 22.0, 21.0),
		"effect": { "type": "owned_upgrade", "upgrade_id": "corr_reward_amp_2" },
	},
	{
		"id": "augment_reward_3", "name": "REWARD + III",
		"description": "THE COMPLETE REWARD AMPLIFICATION STACK.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		"icon_rect": Rect2(8.0, 508.0, 22.0, 21.0),
		"effect": { "type": "owned_upgrade", "upgrade_id": "corr_reward_amp_3" },
	},
	{
		"id": "augment_joker", "name": "JOKER",
		"description": "A SEEDED CHAOS EFFECT: +3 SPINS OR A GUARANTEED WIN.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		"icon_rect": Rect2(0.0, 549.0, 39.0, 61.0),
		"effect": { "type": "joker" },
	},
	{
		"id": "augment_win_boost", "name": "WIN BOOST",
		"description": "THE NEXT PAYING WIN RECEIVES A FLATLINE STRIKE BONUS.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		"icon_rect": Rect2(0.0, 623.0, 20.0, 34.0),
		"effect": { "type": "win_boost" },
	},
	{
		"id": "augment_glitch_2", "name": "GLITCH 2",
		"description": "THE NEXT TWO PAYING RESULTS GAIN LUCIDITY.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		"icon_rect": Rect2(0.0, 623.0, 20.0, 34.0),
		"effect": { "type": "glitch_lucidity", "spins": 2, "multiplier": 2.0 },
	},
]

const POWERS: Array[Dictionary] = [
	{
		"id": "reroll", "name": "REROLL", "description": "REROLL ONE REVEALED REEL.",
		"pool": "power", "hero": true, "power_id": "reroll",
		"sheet": POWER_SHEET, "sheet_rect": POWER_FRONT_RECT,
		"icon_rect": Rect2(81.0, 0.0, 33.0, 61.0),
	},
	{
		"id": "shift", "name": "SHIFT", "description": "STEP ONE REVEALED REEL ALONG THE SYMBOL CYCLE.",
		"pool": "power", "power_id": "shift",
		"sheet": POWER_SHEET, "sheet_rect": POWER_FRONT_RECT,
		"icon_rect": Rect2(129.0, 0.0, 15.0, 61.0),
	},
	{
		"id": "memory", "name": "LOCK", "description": "LOCK ONE REEL THROUGH THE NEXT SPINS.",
		"pool": "power", "power_id": "memory",
		"sheet": POWER_SHEET, "sheet_rect": POWER_FRONT_RECT,
		"icon_rect": Rect2(165.0, 0.0, 21.0, 61.0),
	},
	{
		"id": "rewind", "name": "REWIND", "description": "RESTORE THE PREVIOUS SPIN AND RECOVER 1–3 POWER CHIPS.",
		"pool": "power", "power_id": "rewind",
		"sheet": POWER_SHEET, "sheet_rect": POWER_FRONT_RECT,
		"icon_rect": Rect2(207.0, 0.0, 15.0, 61.0),
	},
	{
		"id": "heart", "name": "HEART", "description": "HEARTS PAY +1/+2/+3 NEURONS AND +10/+20/+30 SCORE.",
		"pool": "power", "power_id": "heart",
		"sheet": POWER_SHEET, "sheet_rect": POWER_FRONT_RECT,
		"icon_rect": Rect2(242.0, 0.0, 23.0, 61.0),
	},
	{
		"id": "cheat", "name": "CHEAT", "description": "REPLACE ONE REVEALED SYMBOL WITH A CHOSEN SYMBOL.",
		"pool": "power", "power_id": "cheat",
		"sheet": POWER_SHEET, "sheet_rect": POWER_FRONT_RECT,
		"icon_rect": Rect2(285.0, 0.0, 15.0, 61.0),
	},
	{
		"id": "move", "name": "MOVE", "description": "DRAG ANY REVEALED SYMBOL TO ANOTHER REEL.",
		"pool": "power", "power_id": "move",
		"sheet": POWER_SHEET, "sheet_rect": POWER_FRONT_RECT,
		"icon_rect": Rect2(318.0, 0.0, 27.0, 61.0),
	},
]

static func augment_map() -> Dictionary:
	return _map_for(AUGMENTS)

static func power_map() -> Dictionary:
	return _map_for(POWERS)

static func map() -> Dictionary:
	var result := augment_map()
	for card in POWERS:
		result[String(card["id"])] = card
	return result

static func _map_for(cards: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for card in cards:
		result[String(card["id"])] = card
	return result

static func augment_ids() -> Array[String]:
	return _ids(AUGMENTS)

static func power_ids() -> Array[String]:
	return _ids(POWERS)

static func power_draw_ids() -> Array[String]:
	var result: Array[String] = []
	for card in POWERS:
		if not bool(card.get("hero", false)):
			result.append(String(card["id"]))
	return result

static func _ids(cards: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for card in cards:
		result.append(String(card["id"]))
	return result

static func card(card_id: String) -> Dictionary:
	var value: Variant = map().get(card_id, {})
	return (value as Dictionary).duplicate(true)

static func draw(pool: String, seed: int, unlocked: Array, excluded: Array = [], count := 3) -> Array[String]:
	var candidates: Array = []
	var source := augment_ids() if pool == "augment" else power_draw_ids()
	for id in source:
		if unlocked.has(id) and not excluded.has(id):
			candidates.append(id)
	if candidates.size() < count:
		var all_ids: Array[String] = []
		for value in candidates:
			all_ids.append(String(value))
		return all_ids
	var picked: Variant = Dealer.pick_pool_offer(candidates, seed, count)
	if picked == null:
		return []
	var result: Array[String] = []
	for id in picked:
		result.append(String(id))
	return result

static func power_id(card_id: String) -> String:
	var entry := power_map().get(card_id, {}) as Dictionary
	return String(entry.get("power_id", card_id))
