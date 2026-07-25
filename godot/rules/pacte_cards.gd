class_name PacteCards
extends RefCounted

## Data for the two Pacte decks.  Card identity is deliberately separate from
## the run-scoped effect it applies: the deck can grow in MetaStateStore while a
## run only records the cards that were actually selected.

const CARD_SHEET := "cards/augment_cards.png"
const POWER_SHEET := "cards/power_cards.png"
const AUGMENT_FRONT_RECT := Rect2(0.0, 61.0, 39.0, 61.0)
# Keep the power proposition at the same authored 39x61 size as augment cards.
# Starting at x40 drops the left red edge and makes the 38px crop upscale.
const POWER_FRONT_RECT := Rect2(39.0, 0.0, 39.0, 61.0)
# Both sheets author their shared card back as the first 39x61 cell. Collection
# renders locked entries with it, and Pacte deals every card face-down with it.
const AUGMENT_BACK_RECT := Rect2(0.0, 0.0, 39.0, 61.0)
const POWER_BACK_RECT := Rect2(0.0, 0.0, 39.0, 61.0)
const CARD_SIZE := Vector2(39.0, 61.0)
const POOLS: Array[String] = ["augment", "power"]

const AUGMENTS: Array[Dictionary] = [
	{
		"id": "augment_pattern_recognition", "name": "PATTERN RECOGNITION",
		"description": "TWO SYMBOLS APART COUNT AS A PAIR.", "pool": "augment",
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
		"description": "KEEP 20% OF LUCIDITY INSTEAD OF 10% ON FLATLINE.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		# The authored saving glyph has one transparent pixel of visual balance on
		# its left edge; include it in the crop so the glyph sits one pixel right,
		# centered like the other augment icons on the 39px card face. The glyph's
		# rightmost column reaches x32, so the crop is 28 wide to keep it uncropped.
		"icon_rect": Rect2(5.0, 324.0, 28.0, 26.0),
		"effect": { "type": "owned_upgrade", "upgrade_id": "pos_smart_save" },
	},
	{
		"id": "augment_reward_1", "name": "REWARD + I",
		"description": "CHOOSE A SYMBOL TO BOOST. TIER I.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		"icon_rect": Rect2(8.0, 386.0, 22.0, 21.0),
		"effect": { "type": "owned_upgrade", "upgrade_id": "corr_reward_amp_1" },
	},
	{
		"id": "augment_reward_2", "name": "REWARD + II",
		"description": "CHOOSE A SYMBOL TO BOOST. TIER II.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		"icon_rect": Rect2(8.0, 447.0, 22.0, 21.0),
		"effect": { "type": "owned_upgrade", "upgrade_id": "corr_reward_amp_2" },
	},
	{
		"id": "augment_reward_3", "name": "REWARD + III",
		"description": "CHOOSE A SYMBOL TO BOOST. TIER III.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		"icon_rect": Rect2(8.0, 508.0, 22.0, 21.0),
		"effect": { "type": "owned_upgrade", "upgrade_id": "corr_reward_amp_3" },
	},
	{
		"id": "augment_joker", "name": "JOKER",
		"description": "AFTER 3 FLATLINES, POWER IS UNLOCKED.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		"icon_rect": Rect2(0.0, 549.0, 39.0, 61.0),
		"effect": { "type": "joker" },
	},
	{
		"id": "augment_win_boost", "name": "COMBO",
		"description": "ADD 5% PER SUCCESSIVE WIN TO BASE REWARD.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		"icon_rect": Rect2(9.0, 623.0, 20.0, 34.0),
		"effect": { "type": "win_boost" },
	},
	{
		"id": "augment_glitch_2", "name": "GLITCH",
		"description": "THE DEALER ALWAYS MOVES 3 STEPS.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		"effect": { "type": "glitch_dealer" },
	},
	{
		"id": "augment_tunnel_vision", "name": "TUNNEL VISION",
		"description": "HIDE THE THIRD REEL. REWARDS +50%.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		# Glyph spans x[3,36) y[685,715); the crop matches so the right column and
		# bottom row are not clipped.
		"icon_rect": Rect2(3.0, 685.0, 33.0, 30.0),
		"effect": { "type": "owned_upgrade", "upgrade_id": "pacte_tunnel_vision" },
	},
	{
		"id": "augment_how_to_cheat", "name": "IS IT CHEATING ?",
		"description": "A SOLO SYMBOL COUNTS AS A PAIR. PAIRS PAY X0.6.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		"icon_rect": Rect2(10.0, 744.0, 18.0, 19.0),
		"effect": { "type": "owned_upgrade", "upgrade_id": "pacte_how_to_cheat" },
	},
	{
		"id": "augment_adrenaline", "name": "ADRENALINE",
		"description": "POWER RESTORE THRESHOLD: 30 LUCIDITY.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		# Glyph spans x[8,32) y[799,845); widen/heighten by one so the right column
		# and bottom row are not clipped.
		"icon_rect": Rect2(8.0, 799.0, 24.0, 46.0),
		"effect": { "type": "owned_upgrade", "upgrade_id": "pacte_adrenaline" },
	},
	{
		"id": "augment_passive_gain", "name": "PASSIVE GAIN",
		"description": "GAIN 10 LUCIDITY EVERY SPIN.", "pool": "augment",
		"sheet": CARD_SHEET, "sheet_rect": AUGMENT_FRONT_RECT,
		# Glyph spans x[8,32) y[868,900); widen/heighten by one so the right column
		# and bottom row are not clipped.
		"icon_rect": Rect2(8.0, 868.0, 24.0, 32.0),
		"effect": { "type": "owned_upgrade", "upgrade_id": "pacte_passive_gain" },
	},
]

const POWERS: Array[Dictionary] = [
	{
		"id": "reroll", "name": "REROLL", "description": "REROLL ONE REVEALED REEL.",
		"pool": "power", "power_id": "reroll",
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
		"id": "rewind", "name": "REWIND", "description": "RESTORE THE PREVIOUS SPIN AND RECOVER 1–3 OTHER POWER CHIPS.",
		"pool": "power", "power_id": "rewind",
		"sheet": POWER_SHEET, "sheet_rect": POWER_FRONT_RECT,
		"icon_rect": Rect2(207.0, 0.0, 15.0, 61.0),
	},
	{
		"id": "heart", "name": "HEART", "description": "NEXT SPIN: GUARANTEED HEART x1/x2/x3 TRIPLE; +1/+2/+3 SPINS; ADVANCES COMBO.",
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
		"id": "swap", "name": "SWAP", "description": "SWAP ONE REVEALED SYMBOL WITH ANOTHER REEL.",
		"pool": "power", "power_id": "swap",
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

static func newly_shipped_augment_ids() -> Array[String]:
	return [
		"augment_tunnel_vision", "augment_how_to_cheat",
		"augment_adrenaline", "augment_passive_gain",
	]

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
	var value: Variant = map().get(normalise_card_id(card_id), {})
	return (value as Dictionary).duplicate(true)

## Card IDs are persisted in MetaStateStore and in resumable run snapshots. Keep
## the old names readable so a pre-rename save becomes the canonical card ID the
## next time it is loaded, without exposing the removed name to new draws.
static func normalise_card_id(card_id: String) -> String:
	if card_id == "lock":
		return "memory"
	if card_id == "move":
		return "swap"
	return card_id

static func draw(pool: String, seed: int, unlocked: Array, excluded: Array = [], count := 3) -> Array[String]:
	var candidates: Array = []
	var source := augment_ids() if pool == "augment" else power_draw_ids()
	var unlocked_ids: Array[String] = []
	for raw_id in unlocked:
		var normalised := normalise_card_id(String(raw_id))
		if not unlocked_ids.has(normalised):
			unlocked_ids.append(normalised)
	var excluded_ids: Array[String] = []
	for raw_id in excluded:
		var normalised := normalise_card_id(String(raw_id))
		if not excluded_ids.has(normalised):
			excluded_ids.append(normalised)
	for id in source:
		if unlocked_ids.has(id) and not excluded_ids.has(id):
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

## Pool ("augment" / "power") a card ID belongs to, or "" when it is unknown.
## Collection and the unlock popup resolve every display value through here so a
## renamed or removed card can never be presented as the wrong pool.
static func pool_of(card_id: String) -> String:
	var entry := card(card_id)
	return String(entry.get("pool", "")) if not entry.is_empty() else ""

static func ids_for_pool(pool: String) -> Array[String]:
	if pool == "augment":
		return augment_ids()
	if pool == "power":
		return power_ids()
	var empty: Array[String] = []
	return empty

static func sheet_for_pool(pool: String) -> String:
	return CARD_SHEET if pool == "augment" else POWER_SHEET

static func front_rect_for_pool(pool: String) -> Rect2:
	return AUGMENT_FRONT_RECT if pool == "augment" else POWER_FRONT_RECT

static func back_rect_for_pool(pool: String) -> Rect2:
	return AUGMENT_BACK_RECT if pool == "augment" else POWER_BACK_RECT

static func power_id(card_id: String) -> String:
	var normalised := normalise_card_id(card_id)
	var entry := power_map().get(normalised, {}) as Dictionary
	return String(entry.get("power_id", normalised))
