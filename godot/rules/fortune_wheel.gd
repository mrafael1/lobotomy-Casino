class_name FortuneWheelRules
extends RefCounted

## The Bonus route is a single persisted turn of the house wheel.  The segment
## order is also the authored order used by the scene, so the visual and the
## deterministic outcome can never drift apart.

const M32 := 0xFFFFFFFF

const REWARD_RUN_5 := "run_5"
const REWARD_RUN_10 := "run_10"
const REWARD_CREDITS_15 := "credits_15"
const REWARD_RUN_20 := "run_20"
const REWARD_CREDITS_25 := "credits_25"
const REWARD_RUN_30 := "run_30"
const REWARD_CREDITS_50 := "credits_50"
const REWARD_JACKPOT := "jackpot"

const SEGMENT_IDS: Array[String] = [
	REWARD_RUN_5,
	REWARD_RUN_10,
	REWARD_CREDITS_15,
	REWARD_RUN_20,
	REWARD_CREDITS_25,
	REWARD_RUN_30,
	REWARD_CREDITS_50,
	REWARD_JACKPOT,
]

const REWARDS := {
	REWARD_RUN_5: {
		"id": REWARD_RUN_5,
		"wheelLabel": "+5G",
		"description": "+5 RUN GOLD",
		"runLucidity": 5,
		"walletCredits": 0,
	},
	REWARD_RUN_10: {
		"id": REWARD_RUN_10,
		"wheelLabel": "+10G",
		"description": "+10 RUN GOLD",
		"runLucidity": 10,
		"walletCredits": 0,
	},
	REWARD_CREDITS_15: {
		"id": REWARD_CREDITS_15,
		"wheelLabel": "+15C",
		"description": "+15 WALLET CREDITS",
		"runLucidity": 0,
		"walletCredits": 15,
	},
	REWARD_RUN_20: {
		"id": REWARD_RUN_20,
		"wheelLabel": "+20G",
		"description": "+20 RUN GOLD",
		"runLucidity": 20,
		"walletCredits": 0,
	},
	REWARD_CREDITS_25: {
		"id": REWARD_CREDITS_25,
		"wheelLabel": "+25C",
		"description": "+25 WALLET CREDITS",
		"runLucidity": 0,
		"walletCredits": 25,
	},
	REWARD_RUN_30: {
		"id": REWARD_RUN_30,
		"wheelLabel": "+30G",
		"description": "+30 RUN GOLD",
		"runLucidity": 30,
		"walletCredits": 0,
	},
	REWARD_CREDITS_50: {
		"id": REWARD_CREDITS_50,
		"wheelLabel": "+50C",
		"description": "+50 WALLET CREDITS",
		"runLucidity": 0,
		"walletCredits": 50,
	},
	REWARD_JACKPOT: {
		"id": REWARD_JACKPOT,
		"wheelLabel": "JACKPOT",
		"description": "+100 CREDITS / +50 RUN GOLD",
		"runLucidity": 50,
		"walletCredits": 100,
		"jackpot": true,
	},
}

## The jackpot is deliberately rare, but it is still a real segment rather than
## a hidden multiplier.  A seed is stored before the animation starts, so closing
## the route scene cannot reroll the player's result.
const ROLL_TABLE: Array[Dictionary] = [
	{ "value": REWARD_RUN_5, "weight": 26.0 },
	{ "value": REWARD_RUN_10, "weight": 20.0 },
	{ "value": REWARD_CREDITS_15, "weight": 15.0 },
	{ "value": REWARD_RUN_20, "weight": 13.0 },
	{ "value": REWARD_CREDITS_25, "weight": 10.0 },
	{ "value": REWARD_RUN_30, "weight": 8.0 },
	{ "value": REWARD_CREDITS_50, "weight": 5.0 },
	{ "value": REWARD_JACKPOT, "weight": 3.0 },
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
