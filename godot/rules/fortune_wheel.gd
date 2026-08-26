class_name FortuneWheelRules
extends RefCounted

## The Bonus route is a single persisted turn of the house wheel. The segment
## order is also the authored order used by the scene, so the visual and the
## deterministic outcome can never drift apart.

const M32 := 0xFFFFFFFF

const REWARD_COINS_50 := "coins_50"
const REWARD_GAIN_125 := "gain_125"
const REWARD_JACKPOT := "jackpot"
const REWARD_ODDS_8 := "odds_8"
const REWARD_ODDS_4 := "odds_4"

const SEGMENT_IDS: Array[String] = [
	REWARD_COINS_50,
	REWARD_GAIN_125,
	REWARD_JACKPOT,
	REWARD_ODDS_8,
	REWARD_ODDS_4,
]

const REWARDS := {
	REWARD_COINS_50: {
		"id": REWARD_COINS_50,
		"wheelLabel": "+50G",
		"description": "+50 RUN COINS",
		"runLucidity": 50,
		"walletCredits": 0,
	},
	REWARD_GAIN_125: {
		"id": REWARD_GAIN_125,
		"wheelLabel": "x1.25",
		"description": "x1.25 NEXT ROUND GAINS",
		"runLucidity": 0,
		"walletCredits": 0,
		"gainMultiplier": 1.25,
	},
	REWARD_JACKPOT: {
		"id": REWARD_JACKPOT,
		"wheelLabel": "JACKPOT",
		"description": "NO FLATLINE CAP\nHALF SCORE / +100 COINS",
		"runLucidity": 100,
		"walletCredits": 0,
		"jackpot": true,
		"flatlineRestrictionRemoved": true,
		"startingScoreFraction": 0.5,
	},
	REWARD_ODDS_8: {
		"id": REWARD_ODDS_8,
		"wheelLabel": "ODDS 8",
		"description": "ODDS TABLE // 8 TOKENS",
		"runLucidity": 0,
		"walletCredits": 0,
		"oddsTokens": 8,
	},
	REWARD_ODDS_4: {
		"id": REWARD_ODDS_4,
		"wheelLabel": "ODDS 4",
		"description": "ODDS TABLE // 4 TOKENS",
		"runLucidity": 0,
		"walletCredits": 0,
		"oddsTokens": 4,
	},
}

## The five visible slices are equally likely. Keeping the weights explicit makes
## future balance changes possible without changing the visual segment order.
const ROLL_TABLE: Array[Dictionary] = [
	{ "value": REWARD_COINS_50, "weight": 1.0 },
	{ "value": REWARD_GAIN_125, "weight": 1.0 },
	{ "value": REWARD_JACKPOT, "weight": 1.0 },
	{ "value": REWARD_ODDS_8, "weight": 1.0 },
	{ "value": REWARD_ODDS_4, "weight": 1.0 },
]

static func reward_for_id(reward_id: String) -> Dictionary:
	var reward: Variant = REWARDS.get(reward_id, null)
	return reward.duplicate(true) if reward is Dictionary else {}

static func roll(seed: int) -> Dictionary:
	var rng := LobRNG.new((seed ^ 0x57484545) & M32)
	var reward_id := LobRNG.weighted_pick(ROLL_TABLE, rng)
	return reward_for_id(reward_id)

static func segment_index(reward_id: String) -> int:
	return SEGMENT_IDS.find(reward_id)

static func is_valid_reward(reward_id: String) -> bool:
	return segment_index(reward_id) >= 0
